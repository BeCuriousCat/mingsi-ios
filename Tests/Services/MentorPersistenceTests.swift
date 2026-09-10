import XCTest
import GRDB
@testable import MingSi

final class MentorPersistenceTests: XCTestCase {
    func testSessionDraftItemsAndCascadeDelete() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        try await repo.saveDraft(sessionID: id, revision: 1, text: "latest")
        try await repo.appendItem(MentorTimelineItem(id: UUID(), sessionID: id, sequence: 1, kind: .user, payloadJSON: "{}"))
        let items = try await repo.items(sessionID: id)
        let savedDraft = try await repo.session(id: id)?.draftText
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(savedDraft, "latest")
        try await repo.deleteSession(id: id)
        let deletedSession = try await repo.session(id: id)
        XCTAssertNil(deletedSession)
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_items")! }
        XCTAssertEqual(count, 0)
    }
}
