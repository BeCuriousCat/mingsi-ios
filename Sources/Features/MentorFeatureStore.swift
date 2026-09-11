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
    private var requestTask: Task<Void, Never>?

    init(repository: MentorRepository, transport: MentorTransport, catalog: MentorLessonCatalog? = nil,
         timeZone: TimeZone = .current) {
        self.repository = repository
        self.transport = transport
        self.catalog = catalog
        self.timeZone = timeZone
    }

    deinit { requestTask?.cancel() }

    func start(entry: String, initialText: String = "") {
        requestTask?.cancel()
        requestTask = Task { [weak self] in await self?.startTask(entry: entry, initialText: initialText) }
    }

    func submit(intent: String = "reply", text: String? = nil) {
        guard let session = state.session, [.editing, .showingResponse, .reading].contains(state.phase) else { return }
        let value = text ?? state.inputText
        state.inputText = value
        state.phase = .submitting
        requestTask?.cancel()
        requestTask = Task { [weak self] in await self?.submitTask(session: session, intent: intent, text: value) }
    }

    func finish() {
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

    func acknowledgeLesson() {
        guard let session = state.session, let lesson = state.lesson else { return }
        requestTask = Task { [weak self] in
            do {
                try await self?.repository.acknowledgePresentation(sessionID: session.id, itemID: lesson.id, at: .now, timeZone: self?.timeZone ?? .current)
                self?.state.timeline = try await self?.repository.items(sessionID: session.id) ?? []
            } catch { self?.state.phase = .failed(String(describing: error)) }
        }
    }

    private func startTask(entry: String, initialText: String) async {
        do {
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
        catch { state.phase = .failed(String(describing: error)) }
    }

    private func submitTask(session: MentorSession, intent: String, text: String) async {
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
            guard let current = try await repository.session(id: session.id) else { throw MentorFeatureError.missingSession }
            let items = try await repository.items(sessionID: session.id)
            let built = try MentorContextBuilder().build(session: current, items: items, intent: intent,
                currentLesson: state.lesson, eligibleLessons: catalog?.lessonsInEditorialOrder ?? [])
            var request = LLMRequest(prompt: PromptTemplate(id: .singleNudge, version: "mentor.m1", systemText: "Return the mentor JSON contract.", userText: built.json, outputSchemaVersion: 1),
                inputSummary: built.json, sourceRecordIDs: built.payload.sources.map { $0.ref.value }, contextVersion: 1,
                contextRecordIDs: built.payload.sources.map { $0.ref.value })
            request.mentorExecutionPolicy = .m1
            request.mentorAuditToken = .init(sessionID: current.id, requestID: requestID, requestEpoch: current.requestEpoch, semanticRevision: current.semanticRevision)
            let data = try await transport.complete(request)
            let validated = try MentorResponseParser().parseTurn(data, context: built.validation)
            _ = try await repository.commitResponse(sessionID: current.id, requestID: requestID,
                payloadJSON: String(decoding: data, as: UTF8.self))
            state.timeline = try await repository.items(sessionID: current.id)
            state.response = validated
            state.phase = .showingResponse
        } catch is CancellationError { return }
        catch { state.phase = .failed(String(describing: error)) }
    }
}

enum MentorFeatureError: Error { case missingSession, lessonCatalogUnavailable }
