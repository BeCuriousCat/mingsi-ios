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
    var understandingError: String?
    var pendingUnderstandingOperations = 0
    var recentSessions: [MentorSessionSummary] = []
    var recentSessionsCursor: MentorSessionCursor?
    var historyError: String?
    var isLoadingHistory = false
    var canRetryResponseSave = false
    var requestFinalizationError: String?
    var canRetryRequestFinalization = false
    var inputText = ""
    var draftRevision = 0
}

/// The M1 flow coordinator. Persistence commands remain the authority for lifecycle
/// and ownership; this store only owns foreground intent and presentation state.
@MainActor
final class MentorFeatureStore: ObservableObject {
    @Published private(set) var state = MentorFeatureState()
    private let repository: MentorRepository
    private let transport: MentorTransport
    private let promptProvider: PromptProvider
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

    deinit { readingPositionTask?.cancel(); lessonFeedbackTask?.cancel(); requestTask?.cancel(); historyTask?.cancel(); presentationTask?.cancel(); understandingTask?.cancel() }

    func start(entry: String, initialText: String = "") {
        understandingGeneration = UUID()
        state.pendingUnderstandingOperations = 0
        pendingUnderstandingCreation = nil
        pendingResponse = nil
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
        requestTask?.cancel()
        requestTask = Task { [weak self] in await self?.startTask(entry: entry, initialText: initialText) }
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
        understandingGeneration = UUID()
        state.pendingUnderstandingOperations = 0
        pendingUnderstandingCreation = nil
        pendingResponse = nil
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                await self.readingPositionTask?.value
                try Task.checkCancellation()
                guard let session = try await self.repository.session(id: id) else {
                    throw MentorFeatureError.missingSession
                }
                try Task.checkCancellation()
                var restored = try await self.restoredState(session: session)
                try Task.checkCancellation()
                if session.lifecycle != .active { try await self.repository.resumeSession(id: id) }
                try Task.checkCancellation()
                guard let current = try await self.repository.session(id: id) else { throw MentorFeatureError.missingSession }
                try Task.checkCancellation()
                restored.session = current
                restored.phase = restored.response == nil ? .editing : .showingResponse
                self.state = restored
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                self?.state.phase = .failed(String(describing: error))
            }
        }
    }

    func submit(intent: String = "reply", text: String? = nil) {
        if intent == "finish" { finish(); return }
        if intent == "another_lesson" { selectAnotherLesson(); return }
        guard let session = state.session, [.editing, .showingResponse, .reading].contains(state.phase) else { return }
        if state.phase == .showingResponse, state.acknowledgedResponseItemID != state.responseItemID { return }
        // Teaching buttons are intent only; never resubmit the draft as evidence.
        let value = text ?? (intent == "reply" ? state.inputText : "")
        if intent == "reply" || text != nil { state.inputText = value }
        state.phase = .submitting
        requestTask?.cancel()
        requestTask = Task { [weak self] in await self?.submitTask(session: session, intent: intent, text: value) }
    }

    /// Reading and changing lessons are local actions even when a draft exists.
    func selectAnotherLesson() {
        guard let session = state.session,
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
        pendingResponse = nil
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
        guard let session = state.session else { return }
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                let current = try await self.repository.session(id: session.id) ?? session
                try await self.repository.suspendSession(id: current.id, ending: true,
                    draftRevision: self.state.draftRevision,
                    draftText: self.state.inputText)
                self.state.phase = .ended
            } catch { self?.state.phase = .failed(String(describing: error)) }
        }
    }

    func pause() {
        pendingResponse = nil
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
        guard let session = state.session else { return }
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                let current = try await self.repository.session(id: session.id) ?? session
                try await self.repository.suspendSession(id: current.id, ending: false,
                    draftRevision: self.state.draftRevision,
                    draftText: self.state.inputText)
                self.state.phase = .paused
            } catch { self?.state.phase = .failed(String(describing: error)) }
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
        guard state.pendingUnderstandingOperations == 0, state.understandingError == nil,
              let draft = state.understandings.first(where: { $0.id == id }),
              draft.sessionID == state.session?.id, draft.state == .draft else { return }
        understandingGeneration = UUID()
        state.understanding = draft
        state.understandingInputText = draft.text
    }

    func beginUnderstanding(previousRevisionID: UUID? = nil) {
        guard state.session != nil, state.pendingUnderstandingOperations == 0,
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

    func saveUnderstanding(text: String) {
        guard state.session != nil, state.understanding?.state != .confirmed,
              state.understanding != nil || pendingUnderstandingCreation != nil else { return }
        state.understandingInputText = text
        // A failed creation has no writable row yet; retain edits for its retry.
        if state.understanding == nil, state.pendingUnderstandingOperations == 0 { return }
        enqueueUnderstanding(.save(text))
    }

    func retryUnderstandingSave() {
        guard state.pendingUnderstandingOperations == 0, state.understandingError != nil else { return }
        if let pending = pendingUnderstandingCreation {
            enqueueUnderstanding(.begin(pending.id, pending.previousRevisionID))
            enqueueUnderstanding(.save(state.understandingInputText))
        } else if state.understanding?.state == .draft {
            enqueueUnderstanding(.save(state.understandingInputText))
        }
    }

    func confirmUnderstanding() { enqueueUnderstanding(.confirm) }

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
        return restored
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
                switch session.lifecycle {
                case .ended: restored.phase = .ended
                case .paused: restored.phase = .paused
                default: restored.phase = restored.response == nil ? .reading : .showingResponse
                }
                state = restored
                return
            }
            try Task.checkCancellation()
            let id = UUID()
            try await repository.createSession(MentorSession(id: id, initialEntry: entry, lifecycle: .draft,
                draftText: initialText, draftRevision: initialText.isEmpty ? 0 : 1, activityAt: now()))
            guard let session = try await repository.session(id: id) else { throw MentorFeatureError.missingSession }
            try Task.checkCancellation()
            state = MentorFeatureState(phase: .editing, session: session, inputText: initialText,
                draftRevision: session.draftRevision)
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

    private func submitTask(session: MentorSession, intent: String, text: String) async {
        var submittedRequestID: UUID?
        do {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let nextRevision = state.draftRevision + 1
                try await repository.saveDraft(sessionID: session.id, revision: nextRevision, text: text)
                state.draftRevision = nextRevision
            }
            let requestID = try await repository.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: session.id,
                text: trimmed.isEmpty ? nil : text,
                intent: intent, contextSnapshotJSON: "{}"))
            submittedRequestID = requestID
            guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
            let items = try await repository.items(sessionID: session.id)
            let built = try MentorContextBuilder().build(session: current, items: items, intent: intent,
                responseIntent: intent == "explain" ? .directTeaching : .discuss,
                currentLesson: state.lesson, eligibleLessons: catalog?.lessonsInEditorialOrder ?? [])
            var request = LLMRequest(prompt: promptProvider.template(for: .mentorRespond, mode: .standard),
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
        state.response = pending.validated
        state.responseItemID = item.id
        state.acknowledgedResponseItemID = nil
        state.canRetryResponseSave = false
        pendingResponse = nil
        state.phase = .showingResponse
    }
}

enum MentorFeatureError: Error { case missingSession, lessonCatalogUnavailable, missingSavedLesson }
