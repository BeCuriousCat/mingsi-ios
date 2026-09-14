import Foundation
import Combine

protocol MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data
}

// The application can pass its shared gateway without constructing a feature-specific client.
extension CentralLLMDecisionCenter: MentorTransport {}

struct MentorFeatureState: Equatable {
    enum Phase: Equatable { case idle, editing, reading, selectingLesson, lessonExhausted, submitting, showingResponse, paused, ended, failed(String) }
    var phase: Phase = .idle
    var session: MentorSession?
    var timeline: [MentorTimelineItem] = []
    var lesson: MentorSavedLesson?
    var lessonError: String?
    var readingPositionError: String?
    var pendingReadingPositionSaves = 0
    var lessonFeedbackError: String?
    var isSavingLessonFeedback = false
    var response: MentorValidatedTurn?
    var responseItemID: UUID?
    var acknowledgedResponseItemID: UUID?
    var presentationError: String?
    var understandings: [MentorUnderstanding] = []
    var understanding: MentorUnderstanding?
    var understandingInputText = ""
    var hasUnsavedUnderstanding = false
    var understandingError: String?
    var pendingUnderstandingOperations = 0
    var isConfirmingUnderstanding = false
    var recentSessions: [MentorSessionSummary] = []
    var recentSessionsCursor: MentorSessionCursor?
    var historyError: String?
    var isLoadingHistory = false
    var canRetryResponseSave = false
    var requestFinalizationError: String?
    var canRetryRequestFinalization = false
    var retryableRequest: MentorRetryableRequest?
    var retryError: String?
    var inputText = ""
    var draftRevision = 0
    var hasUnsavedDraft = false
    var isSavingDraft = false
    var draftSaveError: String?
    var isTransitioningSession = false
}

/// The M1 flow coordinator. Persistence commands remain the authority for lifecycle
/// and ownership; this store only owns foreground intent and presentation state.
@MainActor
final class MentorFeatureStore: ObservableObject {
    @Published private(set) var state = MentorFeatureState()
    private let repository: MentorRepository
    private var transport: MentorTransport
    private var promptProvider: PromptProvider
    private let catalog: MentorLessonCatalog?
    private let timeZone: TimeZone
    private let now: () -> Date
    private struct PendingResponse {
        let sessionID: UUID
        let requestID: UUID
        let payload: String
        let validated: MentorValidatedTurn
    }
    private struct PendingRequestEnd {
        let sessionID: UUID
        let requestID: UUID
        let reason: MentorRequestEndReason
    }
    private var pendingRequestEnd: PendingRequestEnd?
    private var pendingResponse: PendingResponse?
    private var requestTask: Task<Void, Never>?
    private struct DraftSnapshot: Equatable {
        let sessionID: UUID
        let revision: Int
        let text: String
    }
    private var draftDebounceTask: Task<Void, Never>?
    private var draftWriteTask: Task<Bool, Never>?
    private var draftWritingSnapshot: DraftSnapshot?
    private var sessionTransitionID: UUID?
    private var understandingDebounceTask: Task<Void, Never>?
    private var pendingUnderstandingText: String?
    private var understandingTask: Task<Void, Never>?
    private var understandingGeneration = UUID()
    private var pendingUnderstandingCreation: (id: UUID, previousRevisionID: UUID?)?
    private var readingPositionTask: Task<Void, Never>?
    private var lessonFeedbackTask: Task<Void, Never>?
    private var presentationTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var historyGeneration = UUID()

    init(repository: MentorRepository, transport: MentorTransport, catalog: MentorLessonCatalog? = nil,
         promptProvider: PromptProvider = LocalPromptProvider(), timeZone: TimeZone = .current, now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.transport = transport
        self.promptProvider = promptProvider
        self.catalog = catalog
        self.timeZone = timeZone
        self.now = now
    }

    deinit { understandingDebounceTask?.cancel(); draftDebounceTask?.cancel(); draftWriteTask?.cancel(); readingPositionTask?.cancel(); lessonFeedbackTask?.cancel(); requestTask?.cancel(); historyTask?.cancel(); presentationTask?.cancel(); understandingTask?.cancel() }

    /// Configuration refresh affects future turns; each submitted turn captures
    /// the dependencies it started with and retains its own cancellation handle.
    func updateDependencies(transport: MentorTransport, promptProvider: PromptProvider) {
        self.transport = transport
        self.promptProvider = promptProvider
    }

    func updateInputText(_ text: String) {
        guard let sessionID = state.session?.id, sessionTransitionID == nil,
              state.phase != .paused, state.phase != .ended, text != state.inputText else { return }
        state.inputText = text
        state.draftRevision += 1
        state.hasUnsavedDraft = true
        state.draftSaveError = nil
        draftDebounceTask?.cancel()
        let revision = state.draftRevision
        draftDebounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self, !Task.isCancelled, state.session?.id == sessionID,
                  state.draftRevision == revision else { return }
            draftDebounceTask = nil
            _ = await flushDraft()
        }
    }

    /// Flush before navigation/background or submission. Failure leaves the buffer intact.
    @discardableResult
    func flushDraft() async -> Bool {
        draftDebounceTask?.cancel()
        draftDebounceTask = nil
        guard let sessionID = state.session?.id else { return true }
        while state.hasUnsavedDraft, state.session?.id == sessionID {
            guard !Task.isCancelled else { return false }
            let snapshot = DraftSnapshot(sessionID: sessionID, revision: state.draftRevision, text: state.inputText)
            let task: Task<Bool, Never>
            if draftWritingSnapshot == snapshot, let existing = draftWriteTask {
                task = existing
            } else {
                let previous = draftWriteTask
                state.isSavingDraft = true
                draftWritingSnapshot = snapshot
                task = Task { [weak self] in
                    _ = await previous?.value
                    guard let self else { return false }
                    defer {
                        if draftWritingSnapshot == snapshot {
                            draftWritingSnapshot = nil
                            if state.session?.id == snapshot.sessionID { state.isSavingDraft = false }
                        }
                    }
                    do {
                        try await repository.saveDraft(sessionID: snapshot.sessionID, revision: snapshot.revision, text: snapshot.text)
                        if state.session?.id == snapshot.sessionID, state.draftRevision == snapshot.revision {
                            state.hasUnsavedDraft = false
                            state.draftSaveError = nil
                        }
                        return true
                    } catch {
                        if state.session?.id == snapshot.sessionID, state.draftRevision == snapshot.revision {
                            state.draftSaveError = "草稿尚未保存，请重试。"
                        }
                        return false
                    }
                }
                draftWriteTask = task
            }
            guard await task.value else { return false }
        }
        return !Task.isCancelled && state.session?.id == sessionID
    }

    /// Wait for both independent editing queues before leaving or backgrounding.
    @discardableResult
    func flushPendingEdits() async -> Bool {
        let sessionID = state.session?.id
        while !Task.isCancelled {
            guard await flushDraft(), state.session?.id == sessionID else { return false }
            let generation = understandingGeneration
            flushScheduledUnderstanding()
            await understandingTask?.value
            guard !Task.isCancelled, state.session?.id == sessionID,
                  understandingGeneration == generation, state.understandingError == nil else { return false }
            if !state.hasUnsavedDraft, !state.hasUnsavedUnderstanding,
               pendingUnderstandingText == nil, state.pendingUnderstandingOperations == 0 { return true }
        }
        return false
    }

    private func beginSessionTransition() -> UUID {
        let id = UUID()
        sessionTransitionID = id
        state.isTransitioningSession = true
        return id
    }

    private func endSessionTransition(_ id: UUID) {
        guard sessionTransitionID == id else { return }
        sessionTransitionID = nil
        state.isTransitioningSession = false
    }

    func start(entry: String, initialText: String = "") {
        guard pendingResponse == nil, pendingRequestEnd == nil else { return }
        requestTask?.cancel()
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endSessionTransition(transition) }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            await startTask(entry: entry, initialText: initialText)
        }
    }

    func loadRecentSessions(limit: Int = 3) {
        historyTask?.cancel()
        let generation = UUID()
        historyGeneration = generation
        state.isLoadingHistory = true
        state.historyError = nil
        historyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await repository.recentSessions(after: nil, limit: limit)
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.recentSessions = page.sessions
                state.recentSessionsCursor = page.nextCursor
            } catch {
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.historyError = String(describing: error)
            }
            state.isLoadingHistory = false
        }
    }

    func loadMoreRecentSessions(limit: Int = 20) {
        guard !state.isLoadingHistory, let cursor = state.recentSessionsCursor else { return }
        let generation = historyGeneration
        state.isLoadingHistory = true
        state.historyError = nil
        historyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await repository.recentSessions(after: cursor, limit: limit)
                guard !Task.isCancelled, historyGeneration == generation else { return }
                let existing = Set(state.recentSessions.map(\.id))
                state.recentSessions.append(contentsOf: page.sessions.filter { !existing.contains($0.id) })
                state.recentSessionsCursor = page.nextCursor
            } catch {
                guard !Task.isCancelled, historyGeneration == generation else { return }
                state.historyError = String(describing: error)
            }
            state.isLoadingHistory = false
        }
    }

    func continueSession(id: UUID) {
        guard pendingResponse == nil, pendingRequestEnd == nil else { return }
        requestTask?.cancel()
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endSessionTransition(transition) }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            do {
                await self.readingPositionTask?.value
                try Task.checkCancellation()
                guard let session = try await self.repository.session(id: id) else {
                    throw MentorFeatureError.missingSession
                }
                try Task.checkCancellation()
                var restored = try await self.restoredState(session: session)
                try Task.checkCancellation()
                try await suspendPreviousSession(destinationID: id)
                if session.lifecycle != .active { try await self.repository.resumeSession(id: id) }
                try Task.checkCancellation()
                guard let current = try await self.repository.session(id: id) else { throw MentorFeatureError.missingSession }
                try Task.checkCancellation()
                restored.session = current
                restored.phase = restored.response == nil ? .editing : .showingResponse
                resetSessionBuffers()
                self.state = restored
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                self.state.phase = .failed(String(describing: error))
            }
        }
    }

    func submit(intent: String = "reply", text: String? = nil) {
        if intent == "finish" { finish(); return }
        if intent == "another_lesson" { selectAnotherLesson(); return }
        guard sessionTransitionID == nil, let session = state.session, [.editing, .showingResponse, .reading].contains(state.phase) else { return }
        if state.phase == .showingResponse, state.acknowledgedResponseItemID != state.responseItemID { return }
        // Teaching buttons are intent only; never resubmit the draft as evidence.
        let value = text ?? (intent == "reply" ? state.inputText : "")
        if intent == "reply" || text != nil { updateInputText(value) }
        state.phase = .submitting
        requestTask?.cancel()
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorRespond, mode: .standard)
        requestTask = Task { [weak self] in
            await self?.submitTask(session: session, intent: intent, text: value,
                transport: transport, prompt: prompt)
        }
    }

    /// Explicit network retry; local response-save retries never use this path.
    func retryLastRequest() {
        guard sessionTransitionID == nil, let session = state.session, pendingResponse == nil, pendingRequestEnd == nil,
              state.phase != .submitting, state.phase != .selectingLesson else { return }
        let previousPhase = state.phase
        let transport = self.transport
        let prompt = promptProvider.template(for: .mentorRespond, mode: .standard)
        state.phase = .submitting
        state.retryError = nil
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let candidate = try await repository.retryableRequest(sessionID: session.id)
                try Task.checkCancellation()
                guard let candidate else {
                    state.retryableRequest = nil
                    state.retryError = "当前没有可重试的轮次。"
                    state.phase = previousPhase
                    return
                }
                await submitTask(session: session, intent: candidate.intent, text: candidate.text ?? "",
                    transport: transport, prompt: prompt, retry: candidate)
            } catch {
                guard !Task.isCancelled else { return }
                state.retryError = String(describing: error)
                state.phase = previousPhase
            }
        }
    }

    /// Reading and changing lessons are local actions even when a draft exists.
    func selectAnotherLesson() {
        guard sessionTransitionID == nil, let session = state.session,
              [.editing, .reading, .showingResponse, .lessonExhausted].contains(state.phase) else { return }
        guard let catalog else {
            state.lessonError = "教材暂不可用，请稍后重试。"
            return
        }
        let previousPhase = state.phase
        let receipt = presentationTask
        let feedback = lessonFeedbackTask
        let position = readingPositionTask
        state.phase = .selectingLesson
        state.lessonError = nil
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                await receipt?.value
                await feedback?.value
                await position?.value
                try Task.checkCancellation()
                guard state.lessonFeedbackError == nil else {
                    state.phase = previousPhase
                    return
                }
                guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
                try Task.checkCancellation()
                let lesson = try await repository.selectNextLesson(sessionID: current.id, itemID: UUID(),
                    expectedEpoch: current.requestEpoch, catalog: catalog, at: now(), timeZone: timeZone)
                let items = try await repository.items(sessionID: current.id)
                try Task.checkCancellation()
                guard state.session?.id == current.id else { return }
                state.timeline = items
                state.lesson = lesson
                state.readingPositionError = nil
                state.pendingReadingPositionSaves = 0
                state.phase = lesson == nil ? .lessonExhausted : .reading
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                state.lessonError = String(describing: error)
                state.phase = previousPhase
            }
        }
    }

    /// Feedback records a preference without replacing the current readable snapshot.
    /// A subsequent change of lesson waits for this local write to finish.
    func recordLessonFeedback(_ kind: MentorLessonFeedback) {
        guard let session = state.session, let lesson = state.lesson,
              [.reading, .showingResponse, .paused, .ended].contains(state.phase) else { return }
        saveLessonFeedback(sessionID: session.id, itemID: lesson.id, kind: kind)
    }

    /// Settings can revoke known-item exclusions without deleting reading history.
    func resetKnownLessonFeedback() {
        saveLessonFeedback(sessionID: nil, itemID: nil, kind: nil)
    }

    private func saveLessonFeedback(sessionID: UUID?, itemID: UUID?, kind: MentorLessonFeedback?) {
        guard lessonFeedbackTask == nil else { return }
        let foregroundSessionID = state.session?.id
        let receipt = presentationTask
        let commandID = UUID()
        state.lessonFeedbackError = nil
        state.isSavingLessonFeedback = true
        lessonFeedbackTask = Task { [weak self] in
            guard let self else { return }
            defer {
                lessonFeedbackTask = nil
                if state.session?.id == foregroundSessionID { state.isSavingLessonFeedback = false }
            }
            do {
                await receipt?.value
                try Task.checkCancellation()
                if let sessionID, let itemID, let kind {
                    try await repository.recordLessonFeedback(sessionID: sessionID, itemID: itemID,
                        commandID: commandID, kind: kind, at: now())
                } else {
                    try await repository.resetKnownLessonFeedback(commandID: commandID, at: now())
                }
            } catch {
                guard !Task.isCancelled, state.session?.id == foregroundSessionID else { return }
                state.lessonFeedbackError = String(describing: error)
            }
        }
    }

    func finish() {
        guard let session = state.session else { return }
        requestTask?.cancel()
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endSessionTransition(transition) }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            let revision = state.draftRevision
            let text = state.inputText
            do {
                let current = try await self.repository.session(id: session.id) ?? session
                try Task.checkCancellation()
                try await self.repository.suspendSession(id: current.id, ending: true,
                    draftRevision: revision,
                    draftText: text)
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                pendingResponse = nil
                pendingRequestEnd = nil
                state.canRetryRequestFinalization = false
                state.requestFinalizationError = nil
                state.canRetryResponseSave = false
                self.state.phase = .ended
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                self.state.phase = .failed(String(describing: error))
            }
        }
    }

    func pause() {
        guard let session = state.session else { return }
        requestTask?.cancel()
        let transition = beginSessionTransition()
        requestTask = Task { [weak self] in
            guard let self else { return }
            defer { endSessionTransition(transition) }
            guard await flushPendingEdits(), !Task.isCancelled else { return }
            let revision = state.draftRevision
            let text = state.inputText
            do {
                let current = try await self.repository.session(id: session.id) ?? session
                try Task.checkCancellation()
                try await self.repository.suspendSession(id: current.id, ending: false,
                    draftRevision: revision,
                    draftText: text)
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                pendingResponse = nil
                pendingRequestEnd = nil
                state.canRetryRequestFinalization = false
                state.requestFinalizationError = nil
                state.canRetryResponseSave = false
                self.state.phase = .paused
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                self.state.phase = .failed(String(describing: error))
            }
        }
    }

    /// Called by the view only after this exact response has appeared.
    /// Keeping the item ID in the event prevents an old view acknowledging a new response.
    func acknowledgeResponse(itemID: UUID) {
        guard state.responseItemID == itemID else { return }
        acknowledge(itemID: itemID, isResponse: true)
    }

    /// The visible lesson's identity travels with scroll events, so a disappearing
    /// page cannot move the reading position of its replacement.
    func saveReadingPosition(itemID: UUID, section: MentorReadingSection) {
        guard let lesson = state.lesson, lesson.id == itemID,
              lesson.sessionID == state.session?.id, state.phase != .selectingLesson,
              section != .observation || lesson.lesson.observation != nil else { return }
        guard section != lesson.readingSection || state.readingPositionError != nil else { return }
        let updated = MentorSavedLesson(id: lesson.id, sessionID: lesson.sessionID,
            lesson: lesson.lesson, readingSection: section, readingRevision: lesson.readingRevision + 1)
        state.lesson = updated
        enqueueReadingPosition(updated)
    }

    func retryReadingPositionSave() {
        guard state.pendingReadingPositionSaves == 0, state.readingPositionError != nil,
              let lesson = state.lesson else { return }
        enqueueReadingPosition(lesson)
    }

    private func enqueueReadingPosition(_ lesson: MentorSavedLesson) {
        let previous = readingPositionTask
        state.pendingReadingPositionSaves += 1
        state.readingPositionError = nil
        readingPositionTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            defer {
                if state.session?.id == lesson.sessionID, state.lesson?.id == lesson.id {
                    state.pendingReadingPositionSaves -= 1
                }
            }
            do {
                try Task.checkCancellation()
                try await repository.saveReadingPosition(sessionID: lesson.sessionID, itemID: lesson.id,
                    revision: lesson.readingRevision, section: lesson.readingSection)
                guard state.lesson?.id == lesson.id,
                      state.lesson?.readingRevision == lesson.readingRevision else { return }
                state.readingPositionError = nil
            } catch {
                guard !Task.isCancelled, state.lesson?.id == lesson.id,
                      state.lesson?.readingRevision == lesson.readingRevision else { return }
                state.readingPositionError = String(describing: error)
            }
        }
    }

    func acknowledgeLesson() {
        guard let lesson = state.lesson else { return }
        acknowledge(itemID: lesson.id, isResponse: false)
    }

    private func acknowledge(itemID: UUID, isResponse: Bool) {
        guard let session = state.session, presentationTask == nil else { return }
        state.presentationError = nil
        presentationTask = Task { [weak self] in
            guard let self else { return }
            defer { presentationTask = nil }
            do {
                try await repository.acknowledgePresentation(sessionID: session.id, itemID: itemID,
                    at: now(), timeZone: timeZone)
                // Receipt updates must not overwrite foreground lifecycle or draft edits.
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                if isResponse, state.responseItemID == itemID {
                    state.acknowledgedResponseItemID = itemID
                }
            } catch {
                guard !Task.isCancelled, state.session?.id == session.id else { return }
                state.presentationError = String(describing: error)
            }
        }
    }

    private enum UnderstandingCommand {
        case begin(UUID, UUID?)
        case save(String)
        case confirm
    }

    /// Switching editors is disabled until queued writes finish. A failed edit
    /// must be retried before another draft can replace its in-memory text.
    func selectUnderstandingDraft(id: UUID) {
        guard sessionTransitionID == nil, !state.hasUnsavedUnderstanding,
              state.pendingUnderstandingOperations == 0, state.understandingError == nil,
              let draft = state.understandings.first(where: { $0.id == id }),
              draft.sessionID == state.session?.id, draft.state == .draft else { return }
        understandingGeneration = UUID()
        state.understanding = draft
        state.understandingInputText = draft.text
    }

    func beginUnderstanding(previousRevisionID: UUID? = nil) {
        guard sessionTransitionID == nil, !state.hasUnsavedUnderstanding,
              state.session != nil, state.pendingUnderstandingOperations == 0,
              state.understandingError == nil else { return }
        var initialText = ""
        if let previousRevisionID {
            guard let previous = state.understandings.first(where: { $0.id == previousRevisionID }),
                  previous.state == .confirmed, previous.sessionID == state.session?.id else { return }
            // Resume an existing revision draft rather than creating a second one.
            if let draft = state.understandings.first(where: { $0.previousRevisionID == previousRevisionID && $0.state == .draft }) {
                selectUnderstandingDraft(id: draft.id)
                return
            }
            guard !state.understandings.contains(where: { $0.groupID == previous.groupID && $0.revision > previous.revision }) else { return }
            initialText = previous.text
        }
        understandingGeneration = UUID()
        state.understanding = nil
        state.understandingInputText = initialText
        state.understandingError = nil
        let id = UUID()
        pendingUnderstandingCreation = (id, previousRevisionID)
        enqueueUnderstanding(.begin(id, previousRevisionID))
    }

    /// Text-editor input is immediate in memory and persisted after 500 ms of quiet.
    func updateUnderstandingText(_ text: String) {
        guard sessionTransitionID == nil, !state.isConfirmingUnderstanding,
              state.session != nil, state.understanding?.state != .confirmed,
              state.understanding != nil || pendingUnderstandingCreation != nil,
              text != state.understandingInputText else { return }
        state.understandingInputText = text
        state.hasUnsavedUnderstanding = true
        pendingUnderstandingText = text
        understandingDebounceTask?.cancel()
        let generation = understandingGeneration
        understandingDebounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) }
            catch { return }
            guard let self, !Task.isCancelled, understandingGeneration == generation else { return }
            understandingDebounceTask = nil
            flushScheduledUnderstanding()
        }
    }

    private func flushScheduledUnderstanding() {
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        guard let text = pendingUnderstandingText else { return }
        pendingUnderstandingText = nil
        enqueueUnderstanding(.save(text))
    }

    /// Explicit save bypasses the input debounce and replaces any scheduled text.
    func saveUnderstanding(text: String) {
        guard sessionTransitionID == nil, !state.isConfirmingUnderstanding,
              state.session != nil, state.understanding?.state != .confirmed,
              state.understanding != nil || pendingUnderstandingCreation != nil else { return }
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        pendingUnderstandingText = nil
        state.understandingInputText = text
        state.hasUnsavedUnderstanding = true
        // A failed creation has no writable row yet; retain edits for its retry.
        if state.understanding == nil, state.pendingUnderstandingOperations == 0 { return }
        enqueueUnderstanding(.save(text))
    }

    func retryUnderstandingSave() {
        guard sessionTransitionID == nil, state.pendingUnderstandingOperations == 0, state.understandingError != nil else { return }
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        pendingUnderstandingText = nil
        if let pending = pendingUnderstandingCreation {
            enqueueUnderstanding(.begin(pending.id, pending.previousRevisionID))
            enqueueUnderstanding(.save(state.understandingInputText))
        } else if state.understanding?.state == .draft {
            enqueueUnderstanding(.save(state.understandingInputText))
        }
    }

    func confirmUnderstanding() {
        guard sessionTransitionID == nil, !state.isConfirmingUnderstanding, state.session != nil,
              state.understanding != nil || pendingUnderstandingCreation != nil else { return }
        state.isConfirmingUnderstanding = true
        flushScheduledUnderstanding()
        enqueueUnderstanding(.confirm)
    }

    /// Serialize local edits independently of model work. Confirmation reads the
    /// last successfully saved revision after all earlier commands have finished.
    private func enqueueUnderstanding(_ command: UnderstandingCommand) {
        guard let sessionID = state.session?.id else { return }
        let generation = understandingGeneration
        let previous = understandingTask
        state.pendingUnderstandingOperations += 1
        understandingTask = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled, understandingGeneration == generation,
                  state.session?.id == sessionID else { return }
            defer { if understandingGeneration == generation, state.session?.id == sessionID {
                state.pendingUnderstandingOperations -= 1
                if case .confirm = command { state.isConfirmingUnderstanding = false }
            } }
            do {
                let saved: MentorUnderstanding
                switch command {
                case .begin(let id, let previousID):
                    saved = try await repository.beginUserUnderstanding(sessionID: sessionID,
                        draftID: id, previousRevisionID: previousID)
                case .save(let text):
                    guard let draft = state.understanding else { return }
                    saved = try await repository.saveUnderstandingDraft(sessionID: sessionID,
                        draftID: draft.id, editRevision: draft.editRevision + 1, text: text)
                case .confirm:
                    // A failed preceding edit must not confirm the older text.
                    guard state.understandingError == nil, let draft = state.understanding else { return }
                    saved = try await repository.confirmUnderstanding(sessionID: sessionID,
                        draftID: draft.id, expectedEditRevision: draft.editRevision)
                }
                guard !Task.isCancelled, understandingGeneration == generation,
                      state.session?.id == sessionID else { return }
                if case .begin = command { pendingUnderstandingCreation = nil }
                state.understanding = saved
                state.hasUnsavedUnderstanding = pendingUnderstandingText != nil || saved.text != state.understandingInputText
                if let index = state.understandings.firstIndex(where: { $0.id == saved.id }) {
                    state.understandings[index] = saved
                } else {
                    state.understandings.append(saved)
                }
                state.understandingError = nil
            } catch {
                guard !Task.isCancelled, understandingGeneration == generation,
                      state.session?.id == sessionID else { return }
                state.understandingError = String(describing: error)
            }
        }
    }

    /// Reconstruct from saved versions, never from the current teaching catalog.
    /// Preserve every understanding group; only a unique draft is auto-selected.
    private func restoredState(session: MentorSession, lesson: MentorSavedLesson? = nil) async throws -> MentorFeatureState {
        let items = try await repository.items(sessionID: session.id)
        try Task.checkCancellation()
        var savedLesson = lesson
        if savedLesson == nil, let item = items.last(where: { $0.kind == .lesson }) {
            savedLesson = try await repository.savedLesson(sessionID: session.id, itemID: item.id)
            guard savedLesson != nil else { throw MentorFeatureError.missingSavedLesson }
        }
        try Task.checkCancellation()
        let notes = try await repository.understandings(sessionID: session.id)
        try Task.checkCancellation()
        let drafts = notes.filter { $0.state == .draft }
        let draft = drafts.count == 1 ? drafts.first : nil
        var restored = MentorFeatureState(phase: .editing, session: session, timeline: items,
            lesson: savedLesson, understandings: notes, understanding: draft,
            understandingInputText: draft?.text ?? "", inputText: session.draftText,
            draftRevision: session.draftRevision)
        if let last = items.last, last.kind == .assistant {
            // Replay the committed original, without re-evaluating historical
            // sources against today's context or counting it as presented.
            let response = try JSONDecoder().decode(MentorTurnResponse.self, from: Data(last.payloadJSON.utf8))
            guard response.schemaVersion == "1.0.0" else { throw MentorResponseError.unsupportedSchema }
            restored.response = MentorValidatedTurn(response: response, availableSuggestedActions: response.suggestedActions)
            restored.responseItemID = last.id
        }
        restored.retryableRequest = try await repository.retryableRequest(sessionID: session.id)
        try Task.checkCancellation()
        return restored
    }

    /// The database epoch, rather than transport cancellation alone, rejects late responses.
    private func suspendPreviousSession(destinationID: UUID?) async throws {
        try Task.checkCancellation()
        guard let previous = state.session, previous.id != destinationID else { return }
        let text = state.inputText
        let revision = state.draftRevision
        guard let current = try await repository.session(id: previous.id) else {
            throw MentorFeatureError.missingSession
        }
        try Task.checkCancellation()
        if current.lifecycle != .ended && current.lifecycle != .paused {
            try await repository.suspendSession(id: current.id, ending: false,
                draftRevision: revision, draftText: text)
            try Task.checkCancellation()
            // Keep the old screen truthful if destination activation subsequently fails.
            let suspended = try await repository.session(id: current.id)
            try Task.checkCancellation()
            state.session = suspended
            state.phase = .paused
        }
        try Task.checkCancellation()
    }

    private func resetSessionBuffers() {
        understandingDebounceTask?.cancel()
        understandingDebounceTask = nil
        pendingUnderstandingText = nil
        state.hasUnsavedUnderstanding = false
        understandingGeneration = UUID()
        state.pendingUnderstandingOperations = 0
        pendingUnderstandingCreation = nil
        pendingResponse = nil
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
    }

    private func startTask(entry: String, initialText: String) async {
        do {
            await lessonFeedbackTask?.value
            await readingPositionTask?.value
            try Task.checkCancellation()
            // Process recovery belongs to application bootstrap, never a new
            // session: other stores may still own active requests.
            if entry == "listen", initialText.isEmpty,
               let saved = try await repository.listeningResume(at: now(), timeZone: timeZone) {
                try Task.checkCancellation()
                guard let session = try await repository.session(id: saved.sessionID) else { throw MentorFeatureError.missingSession }
                var restored = try await restoredState(session: session, lesson: saved)
                try Task.checkCancellation()
                try await suspendPreviousSession(destinationID: session.id)
                switch session.lifecycle {
                case .ended: restored.phase = .ended
                case .paused: restored.phase = .paused
                default: restored.phase = restored.response == nil ? .reading : .showingResponse
                }
                resetSessionBuffers()
                state = restored
                return
            }
            try Task.checkCancellation()
            try await suspendPreviousSession(destinationID: nil)
            let id = UUID()
            try await repository.createSession(MentorSession(id: id, initialEntry: entry, lifecycle: .draft,
                draftText: initialText, draftRevision: initialText.isEmpty ? 0 : 1, activityAt: now()))
            guard let session = try await repository.session(id: id) else { throw MentorFeatureError.missingSession }
            try Task.checkCancellation()
            resetSessionBuffers()
            state = MentorFeatureState(phase: .editing, session: session, inputText: initialText,
                draftRevision: session.draftRevision)
            state.isTransitioningSession = sessionTransitionID != nil
            if entry == "listen" {
                guard let catalog else { throw MentorFeatureError.lessonCatalogUnavailable }
                guard let lesson = try await repository.selectNextLesson(sessionID: id, itemID: UUID(), expectedEpoch: session.requestEpoch,
                    catalog: catalog, at: now(), timeZone: timeZone) else { state.phase = .failed("no_lesson"); return }
                state.lesson = lesson
                state.timeline = try await repository.items(sessionID: id)
                state.phase = .reading
            }
        } catch is CancellationError { return }
        catch {
            guard !Task.isCancelled else { return }
            state.phase = .failed(String(describing: error))
        }
    }

    private func submitTask(session: MentorSession, intent: String, text: String,
                            transport: MentorTransport, prompt: PromptTemplate, retry: MentorRetryableRequest? = nil) async {
        var submittedRequestID: UUID?
        do {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard await flushPendingEdits() else { throw MentorFeatureError.draftSaveFailed }
            try Task.checkCancellation()
            let requestID = try await repository.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: session.id,
                text: trimmed.isEmpty ? nil : text,
                intent: intent, contextSnapshotJSON: retry?.contextSnapshotJSON ?? "{}", retryOf: retry?.id))
            submittedRequestID = requestID
            state.retryableRequest = nil
            state.retryError = nil
            guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
            let items = try await repository.items(sessionID: session.id)
            let built: MentorBuiltContext
            if let retry, retry.contextSnapshotJSON != "{}" {
                built = try MentorContextBuilder().replay(json: retry.contextSnapshotJSON, session: current)
            } else {
                built = try MentorContextBuilder().build(session: current, items: items, intent: intent,
                    responseIntent: intent == "explain" ? .directTeaching : .discuss,
                    currentLesson: state.lesson, eligibleLessons: catalog?.lessonsInEditorialOrder ?? [])
            }
            var request = LLMRequest(prompt: prompt,
                inputSummary: built.json, sourceRecordIDs: built.payload.sources.map { $0.ref.value }, contextVersion: 1,
                contextRecordIDs: built.payload.sources.map { $0.ref.value })
            request.mentorExecutionPolicy = .m1
            let token = LLMRequest.MentorAuditToken(sessionID: current.id, requestID: requestID,
                requestEpoch: current.requestEpoch, semanticRevision: current.semanticRevision)
            request.mentorAuditToken = token
            try await repository.prepareRequestContext(token: token, json: built.json)
            try Task.checkCancellation()
            let data = try await transport.complete(request)
            try Task.checkCancellation()
            let validated = try MentorResponseParser().parseTurn(data, context: built.validation)
            let pending = PendingResponse(sessionID: current.id, requestID: requestID,
                payload: String(decoding: data, as: UTF8.self), validated: validated)
            pendingResponse = pending
            try await saveResponse(pending)
        } catch {
            guard !Task.isCancelled else { return }
            if pendingResponse == nil, let requestID = submittedRequestID {
                let reason: MentorRequestEndReason
                switch error {
                case MentorRequestExecutionError.timedOut: reason = .timedOut
                case is CancellationError, MentorRequestExecutionError.cancelled: reason = .cancelled
                default: reason = .failed
                }
                let end = PendingRequestEnd(sessionID: session.id, requestID: requestID, reason: reason)
                pendingRequestEnd = end
                await persistRequestEnd(end)
                guard !Task.isCancelled else { return }
            }
            state.canRetryResponseSave = pendingResponse != nil
            state.phase = .failed(String(describing: error))
        }
    }

    /// Retries only the terminal database write; never invokes transport.
    func retryRequestFinalization() {
        guard state.canRetryRequestFinalization, let end = pendingRequestEnd,
              state.session?.id == end.sessionID else { return }
        state.canRetryRequestFinalization = false
        requestTask = Task { [weak self] in await self?.persistRequestEnd(end) }
    }

    private func persistRequestEnd(_ end: PendingRequestEnd) async {
        do {
            try await repository.finishRequest(sessionID: end.sessionID, requestID: end.requestID, reason: end.reason)
            guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
            pendingRequestEnd = nil
            state.canRetryRequestFinalization = false
            state.requestFinalizationError = nil
            do {
                let candidate = try await repository.retryableRequest(sessionID: end.sessionID)
                guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
                state.retryableRequest = candidate
                state.retryError = nil
            } catch {
                guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
                state.retryError = String(describing: error)
            }
        } catch {
            guard !Task.isCancelled, state.session?.id == end.sessionID else { return }
            state.canRetryRequestFinalization = true
            state.requestFinalizationError = String(describing: error)
        }
    }

    func retryResponseSave() {
        guard state.canRetryResponseSave, let pending = pendingResponse,
              pending.sessionID == state.session?.id else { return }
        state.canRetryResponseSave = false
        state.phase = .submitting
        requestTask = Task { [weak self] in
            guard let self else { return }
            do { try await saveResponse(pending) }
            catch {
                guard !Task.isCancelled else { return }
                state.canRetryResponseSave = pendingResponse != nil
                state.phase = .failed(String(describing: error))
            }
        }
    }

    private func saveResponse(_ pending: PendingResponse) async throws {
        try Task.checkCancellation()
        let item = try await repository.commitResponse(sessionID: pending.sessionID,
            requestID: pending.requestID, payloadJSON: pending.payload)
        let timeline = try await repository.items(sessionID: pending.sessionID)
        try Task.checkCancellation()
        guard state.session?.id == pending.sessionID else { return }
        state.timeline = timeline
        state.retryableRequest = nil
        state.retryError = nil
        state.response = pending.validated
        state.responseItemID = item.id
        state.acknowledgedResponseItemID = nil
        state.canRetryResponseSave = false
        pendingResponse = nil
        state.phase = .showingResponse
    }
}

enum MentorFeatureError: Error { case missingSession, lessonCatalogUnavailable, missingSavedLesson, draftSaveFailed }
