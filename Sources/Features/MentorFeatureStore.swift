import Foundation
import Combine

protocol MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data
}

struct MentorFeatureState: Equatable {
    enum Phase: Equatable { case idle, editing, reading, submitting, showingResponse, paused, ended, failed(String) }
    var phase: Phase = .idle
    var session: MentorSession?
    var timeline: [MentorTimelineItem] = []
    var lesson: MentorSavedLesson?
    var response: MentorValidatedTurn?
    var responseItemID: UUID?
    var acknowledgedResponseItemID: UUID?
    var presentationError: String?
    var understanding: MentorUnderstanding?
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
    private let catalog: MentorLessonCatalog?
    private let timeZone: TimeZone
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
    private var presentationTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var historyGeneration = UUID()

    init(repository: MentorRepository, transport: MentorTransport, catalog: MentorLessonCatalog? = nil,
         timeZone: TimeZone = .current) {
        self.repository = repository
        self.transport = transport
        self.catalog = catalog
        self.timeZone = timeZone
    }

    deinit { requestTask?.cancel(); historyTask?.cancel(); presentationTask?.cancel() }

    func start(entry: String, initialText: String = "") {
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
        pendingResponse = nil
        pendingRequestEnd = nil
        state.canRetryRequestFinalization = false
        state.requestFinalizationError = nil
        state.canRetryResponseSave = false
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            do {
                guard let self, let session = try await self.repository.session(id: id) else {
                    throw MentorFeatureError.missingSession
                }
                if session.lifecycle != .active { try await self.repository.resumeSession(id: id) }
                let current = try await self.repository.session(id: id) ?? session
                self.state = MentorFeatureState(phase: .editing, session: current,
                    timeline: try await self.repository.items(sessionID: id), inputText: current.draftText,
                    draftRevision: current.draftRevision)
            } catch is CancellationError { return }
            catch { self?.state.phase = .failed(String(describing: error)) }
        }
    }

    func submit(intent: String = "reply", text: String? = nil) {
        guard let session = state.session, [.editing, .showingResponse, .reading].contains(state.phase) else { return }
        if state.phase == .showingResponse, state.acknowledgedResponseItemID != state.responseItemID { return }
        let value = text ?? state.inputText
        state.inputText = value
        state.phase = .submitting
        requestTask?.cancel()
        requestTask = Task { [weak self] in await self?.submitTask(session: session, intent: intent, text: value) }
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
                    at: .now, timeZone: timeZone)
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

    /// Starts a user-owned understanding draft. This path is intentionally local:
    /// confirmation never requires a model request or changes prior revisions.
    func beginUnderstanding(previousRevisionID: UUID? = nil) {
        guard let session = state.session else { return }
        requestTask?.cancel()
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                let draft = try await self.repository.beginUserUnderstanding(sessionID: session.id, draftID: UUID(), previousRevisionID: previousRevisionID)
                self.state.understanding = draft
            } catch { self?.state.phase = .failed(String(describing: error)) }
        }
    }

    func saveUnderstanding(text: String) {
        guard let session = state.session, let draft = state.understanding, draft.state == .draft else { return }
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                self.state.understanding = try await self.repository.saveUnderstandingDraft(
                    sessionID: session.id, draftID: draft.id, editRevision: draft.editRevision + 1, text: text)
            } catch { self?.state.phase = .failed(String(describing: error)) }
        }
    }

    func confirmUnderstanding() {
        guard let session = state.session, let draft = state.understanding else { return }
        requestTask = Task { [weak self] in
            do {
                guard let self else { return }
                self.state.understanding = try await self.repository.confirmUnderstanding(
                    sessionID: session.id, draftID: draft.id, expectedEditRevision: draft.editRevision)
            } catch { self?.state.phase = .failed(String(describing: error)) }
        }
    }

    private func startTask(entry: String, initialText: String) async {
        do {
            // Process recovery belongs to application bootstrap, never a new
            // session: other stores may still own active requests.
            let id = UUID()
            try await repository.createSession(MentorSession(id: id, initialEntry: entry, lifecycle: .draft,
                draftText: initialText, draftRevision: initialText.isEmpty ? 0 : 1, activityAt: .now))
            guard let session = try await repository.session(id: id) else { throw MentorFeatureError.missingSession }
            state = MentorFeatureState(phase: .editing, session: session, inputText: initialText,
                draftRevision: session.draftRevision)
            if entry == "listen" {
                guard let catalog else { throw MentorFeatureError.lessonCatalogUnavailable }
                guard let lesson = try await repository.selectNextLesson(sessionID: id, itemID: UUID(), expectedEpoch: session.requestEpoch,
                    catalog: catalog, at: .now, timeZone: timeZone) else { state.phase = .failed("no_lesson"); return }
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
                currentLesson: state.lesson, eligibleLessons: catalog?.lessonsInEditorialOrder ?? [])
            var request = LLMRequest(prompt: PromptTemplate(id: .singleNudge, version: "mentor.m1", systemText: "Return the mentor JSON contract.", userText: built.json, outputSchemaVersion: 1),
                inputSummary: built.json, sourceRecordIDs: built.payload.sources.map { $0.ref.value }, contextVersion: 1,
                contextRecordIDs: built.payload.sources.map { $0.ref.value })
            request.mentorExecutionPolicy = .m1
            request.mentorAuditToken = .init(sessionID: current.id, requestID: requestID, requestEpoch: current.requestEpoch, semanticRevision: current.semanticRevision)
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

enum MentorFeatureError: Error { case missingSession, lessonCatalogUnavailable }
