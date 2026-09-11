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
