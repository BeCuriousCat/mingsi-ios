import XCTest
import GRDB
@testable import MingSi

@MainActor
final class MentorFeatureStoreTests: XCTestCase {
    func testDirectDiscussionPersistsInputAndValidatedResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(store.state.phase, .editing)
        guard let sessionID = store.state.session?.id else { return XCTFail("session missing") }
        store.submit(text: "今天完成了一个改动")
        try await Task.sleep(for: .milliseconds(150))
        guard case .showingResponse = store.state.phase else { return XCTFail("response was not shown: \(store.state.phase)") }
        XCTAssertEqual(store.state.response?.response.action, .explain)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .user }.count, 1)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .assistant }.count, 1)
        let activeSession = try await repo.session(id: sessionID)
        XCTAssertEqual(activeSession?.lifecycle, .active)
        store.finish()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.state.phase, .ended)
        let endedSession = try await repo.session(id: sessionID)
        XCTAssertEqual(endedSession?.lifecycle, .ended)
    }

    func testListenEntryWorksWithoutNetworkAndFinishCancelsForegroundTask() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(store.state.phase, .reading)
        XCTAssertNotNil(store.state.lesson)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .lesson }.count, 1)
        store.acknowledgeLesson()
        try await Task.sleep(for: .milliseconds(80))
        store.finish()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.phase, .ended)
    }

    func testUnderstandingDraftAndConfirmationStayLocal() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await Task.sleep(for: .milliseconds(50))
        store.beginUnderstanding()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.understanding?.state, .draft)
        store.saveUnderstanding(text: "我会先区分动作和效果")
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.understanding?.text, "我会先区分动作和效果")
        store.confirmUnderstanding()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.understanding?.state, .confirmed)
        XCTAssertEqual(store.state.understanding?.confirmedAt != nil, true)
        let sessionID = try XCTUnwrap(store.state.session?.id)
        let understandings = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(understandings.count, 1)
    }

    func testRecentSessionsLoadAndContinueExistingDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "保留这件事")
        try await Task.sleep(for: .milliseconds(60))
        let id = try XCTUnwrap(store.state.session?.id)
        store.pause()
        try await Task.sleep(for: .milliseconds(80))
        store.loadRecentSessions()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.recentSessions.first?.id, id)
        store.continueSession(id: id)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.session?.id, id)
        XCTAssertEqual(store.state.inputText, "保留这件事")
        XCTAssertEqual(store.state.phase, .editing)
    }

    func testHistoryReadDoesNotCancelTransportAndFinishRejectsLateSuccess() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let id = try XCTUnwrap(store.state.session?.id)
        store.submit(text: "保留原话")
        try await waitUntil { transport.pending != nil }
        store.loadRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertEqual(store.state.phase, .submitting)
        XCTAssertFalse(transport.wasCancelled)
        store.finish()
        try await waitUntil { store.state.phase == .ended }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { transport.didReturn }
        // Drain the transport continuation and the Store's following actor work.
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(store.state.phase, .ended)
        let items = try await repo.items(sessionID: id)
        XCTAssertFalse(items.contains { $0.kind == .assistant })
    }

    func testHistoryReadAllowsCurrentResponseToComplete() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "这次不结束会话")
        try await waitUntil { transport.pending != nil }
        store.loadRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertFalse(transport.wasCancelled)
        XCTAssertNotNil(store.state.response)
    }

    func testNewStoreEntryDoesNotRecoverAnotherLiveRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
            text: "另一个页面的请求", intent: "reply", contextSnapshotJSON: "{}"))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let requestState = try await db.dbQueue.read {
            try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [requestID.uuidString])
        }
        XCTAssertEqual(requestState, "prepared")
        let original = try await repo.session(id: id)
        XCTAssertEqual(original?.lifecycle, .active)
    }

    func testHistoryFailureDoesNotReplaceConversationPhase() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.loadRecentSessions(limit: 0)
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertNotNil(store.state.historyError)
        XCTAssertEqual(store.state.phase, .editing)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected state was not reached")
    }

    private func catalog() throws -> MentorLessonCatalog {
        let lessons = (1...24).map { index in
            let base = MentorLesson(id: String(format: "L%02d", index), version: "1.0", editorialOrder: index,
                title: "Fixture lesson \(index)", theme: MentorLesson.Theme.allCases[(index - 1) / 4],
                applicableContexts: ["fixture context"], claim: "Fixture claim", example: "Fixture example", boundary: "Fixture boundary", observation: nil,
                sourceType: .teachingExample, citations: [], contentHash: "", review: .init(status: .approved, reviewedBy: "fixture", reviewedAt: .now, note: nil))
            return MentorLesson(id: base.id, version: base.version, editorialOrder: base.editorialOrder, title: base.title, theme: base.theme,
                applicableContexts: base.applicableContexts, claim: base.claim, example: base.example, boundary: base.boundary, observation: base.observation,
                sourceType: base.sourceType, citations: base.citations, contentHash: MentorLessonCatalog.contentHash(for: base), review: base.review)
        }
        return try MentorLessonCatalog(pack: MentorLessonPack(schemaVersion: "1.0.0", packID: "fixture", version: "1.0", lessons: lessons))
    }
}

private final class MentorStoreFixtureTransport: MentorTransport, @unchecked Sendable {
    func complete(_ request: LLMRequest) async throws -> Data {
        let source = request.sourceRecordIDs.first ?? "item:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        return try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "explain", "material_status": "usable",
            "body": "把完成动作和实际效果分开看。", "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": [source], "lesson_ref": NSNull(), "suggested_actions": ["finish"]
        ])
    }
}

@MainActor
private final class HeldMentorTransport: MentorTransport {
    var pending: CheckedContinuation<Data, Error>?
    var request: LLMRequest?
    var wasCancelled = false
    var didReturn = false
    func complete(_ request: LLMRequest) async throws -> Data {
        self.request = request
        let data: Data = try await withCheckedThrowingContinuation { pending = $0 }
        wasCancelled = Task.isCancelled
        didReturn = true
        return data
    }
}
