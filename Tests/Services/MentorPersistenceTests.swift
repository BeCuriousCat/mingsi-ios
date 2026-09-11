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

    func testSubmitTurnIsIdempotent() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID()
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let command = MentorSubmitTurn(commandID: UUID(), sessionID: sessionID, text: "A concrete observation", intent: "reply", contextSnapshotJSON: "{}")
        _ = try await repo.submitTurn(command)
        _ = try await repo.submitTurn(command)
        let items = try await repo.items(sessionID: sessionID)
        XCTAssertEqual(items.count, 1)
    }
    func testSubmissionRollbackAndRetryAfterRequestInsertFailure() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .draft, draftText: "keep", draftRevision: 1, activityAt: .now))
        try await db.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_request BEFORE INSERT ON mentor_requests BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        let command = MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "quote \" and newline\n", intent: "reply", contextSnapshotJSON: "{}")
        do { _ = try await repo.submitTurn(command); XCTFail("Expected injected failure") } catch {}
        let empty = try await repo.items(sessionID: id)
        let unchanged = try await repo.session(id: id)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(unchanged?.lifecycle, .draft)
        XCTAssertEqual(unchanged?.draftText, "keep")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_request") }
        let requestID = try await repo.submitTurn(command)
        let replayID = try await repo.submitTurn(command)
        XCTAssertEqual(requestID, replayID)
        let items = try await repo.items(sessionID: id)
        let decoded = try JSONDecoder().decode([String: String].self, from: Data(items[0].payloadJSON.utf8))
        XCTAssertEqual(decoded["text"], command.text)
    }

    func testPendingRequestRejectsNewCommandAndChangedReplay() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let first = MentorSubmitTurn(commandID: UUID(), sessionID: id, text: nil, intent: "explain", contextSnapshotJSON: "{}")
        _ = try await repo.submitTurn(first)
        for commandID in [first.commandID, UUID()] {
            do {
                _ = try await repo.submitTurn(MentorSubmitTurn(commandID: commandID, sessionID: id, text: "changed", intent: "reply", contextSnapshotJSON: "{}"))
                XCTFail("Must reject conflicting or concurrent command")
            } catch {}
        }
        let items = try await repo.items(sessionID: id)
        XCTAssertTrue(items.isEmpty, "Teaching intent must not become user words")
        try await repo.deleteSession(id: id)
        do { _ = try await repo.submitTurn(first); XCTFail("Must not recreate deleted session") } catch {}
    }

    func testSequentialRequestsAllocateDistinctTimelinePositions() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        for index in 1...3 {
            let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "Turn \(index)", intent: "reply", contextSnapshotJSON: "{}"))
            try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_requests SET state = 'committed' WHERE id = ?", arguments: [request.uuidString]) }
        }
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.map(\.sequence), [1, 2, 3])
    }

    func testMigrationPreservesMultipleFoundationRequests() throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue, upTo: "v53_mentor_m1_foundation")
        try queue.write { db in
            try db.execute(sql: "INSERT INTO mentor_sessions (id, initial_entry, lifecycle, activity_at) VALUES ('session', 'topic', 'active', '2026-09-11T00:00:00Z')")
            for id in ["request-a", "request-b"] {
                try db.execute(sql: "INSERT INTO mentor_requests (id, session_id, state, created_at) VALUES (?, 'session', 'failed', '2026-09-11T00:00:00Z')", arguments: [id])
            }
        }
        try AppDatabase.makeMigrator().migrate(queue)
        try queue.read { db in
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT command_id FROM mentor_requests ORDER BY id"), ["request-a", "request-b"])
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT intent FROM mentor_requests ORDER BY id"), ["legacy", "legacy"])
        }
    }

    func testResponseReplayAndPauseRejectLateResponseAfterResume() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let first = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "one", intent: "reply", contextSnapshotJSON: "{}"))
        let result = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: "{\"body\":\"reply\"}")
        let replay = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: result.payloadJSON)
        XCTAssertEqual(result, replay)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: "{}"); XCTFail("Conflicting replay") } catch {}
        let late = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "two", intent: "reply", contextSnapshotJSON: "{}"))
        try await repo.suspendSession(id: id, ending: false, draftRevision: 1, draftText: "saved")
        let paused = try await repo.session(id: id)
        XCTAssertEqual(paused?.lifecycle, .paused)
        XCTAssertEqual(paused?.draftText, "saved")
        _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "resume", intent: "reply", contextSnapshotJSON: "{}"))
        do { _ = try await repo.commitResponse(sessionID: id, requestID: late, payloadJSON: "{}"); XCTFail("Late response survived resume") } catch {}
        try await repo.deleteSession(id: id)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: result.payloadJSON); XCTFail("Deleted response recreated") } catch {}
        let links = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_request_results") }
        XCTAssertEqual(links, 0)
    }

    func testResponseOwnershipAndAtomicRollback() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID(), other = UUID()
        for sessionID in [id, other] {
            try await repo.createSession(MentorSession(id: sessionID, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        }
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "one", intent: "reply", contextSnapshotJSON: "{}"))
        do { _ = try await repo.commitResponse(sessionID: other, requestID: request, payloadJSON: "{}"); XCTFail("Cross-session response") } catch {}
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_result BEFORE INSERT ON mentor_request_results BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}"); XCTFail("Expected failure") } catch {}
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.count, 1)
        let state = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.uuidString]) }
        XCTAssertEqual(state, "prepared")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_result") }
        _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}")
    }

    func testSuspendFailureRollsBackRequestCancellation() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "one", intent: "reply", contextSnapshotJSON: "{}"))
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_pause BEFORE UPDATE ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "new"); XCTFail("Expected failure") } catch {}
        let session = try await repo.session(id: id)
        XCTAssertEqual(session?.lifecycle, .active)
        XCTAssertEqual(session?.draftRevision, 0)
        let state = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.uuidString]) }
        XCTAssertEqual(state, "prepared")
    }

    func testDraftRevisionConflictsAndReplayPreserveStoredText() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        try await repo.saveDraft(sessionID: id, revision: 2, text: "newest")
        let before = try await repo.session(id: id)
        try await repo.saveDraft(sessionID: id, revision: 2, text: "newest")
        let replay = try await repo.session(id: id)
        XCTAssertEqual(before, replay)
        for revision in [-1, 1, 2] {
            do { try await repo.saveDraft(sessionID: id, revision: revision, text: "older"); XCTFail("Rejected stale or conflicting revision") } catch {}
        }
        let saved = try await repo.session(id: id)
        XCTAssertEqual(saved, before)
    }

    func testClosedSessionRejectsDelayedDraftAndSuspendWrites() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        try await repo.suspendSession(id: id, ending: false, draftRevision: 1, draftText: "paused")
        do { try await repo.saveDraft(sessionID: id, revision: 2, text: "late"); XCTFail("Paused draft overwritten") } catch {}
        try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "paused")
        let ended = try await repo.session(id: id)
        try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "paused")
        do { try await repo.suspendSession(id: id, ending: false, draftRevision: 2, draftText: "late"); XCTFail("Ended session reopened by background callback") } catch {}
        do { try await repo.saveDraft(sessionID: id, revision: 2, text: "late"); XCTFail("Ended draft overwritten") } catch {}
        let final = try await repo.session(id: id)
        XCTAssertEqual(final, ended)
        try await repo.resumeSession(id: id)
        try await repo.saveDraft(sessionID: id, revision: 2, text: "explicit continuation")
        let resumed = try await repo.session(id: id)
        XCTAssertEqual(resumed?.lifecycle, .active)
        XCTAssertEqual(resumed?.draftText, "explicit continuation")
    }

    func testCorrectionPreservesOriginalAndInvalidatesOldRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "old fact", intent: "reply", contextSnapshotJSON: "{}"))
        let before = try await repo.items(sessionID: id)
        let command = UUID()
        let correction = try await repo.correctUserItem(sessionID: id, itemID: before[0].id, commandID: command, expectedRevision: 0, text: "correct fact")
        let replay = try await repo.correctUserItem(sessionID: id, itemID: before[0].id, commandID: command, expectedRevision: 0, text: "correct fact")
        XCTAssertEqual(correction, replay)
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0], before[0])
        XCTAssertEqual(items[1].supersedesItemID, before[0].id)
        let session = try await repo.session(id: id)
        XCTAssertEqual(session?.semanticRevision, 1)
        XCTAssertEqual(session?.requestEpoch, 1)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}"); XCTFail("Old facts accepted") } catch {}
        // Even an erroneous state reset cannot bypass the persisted revision check.
        try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_requests SET state = 'prepared' WHERE id = ?", arguments: [request.uuidString]) }
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}"); XCTFail("Revision mismatch accepted") } catch {}
        try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE id = ?", arguments: [request.uuidString]) }
        let fresh = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: nil, intent: "explain", contextSnapshotJSON: "{}"))
        _ = try await repo.commitResponse(sessionID: id, requestID: fresh, payloadJSON: "{}")
        try await repo.deleteSession(id: id)
        let remaining = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_corrections") }
        XCTAssertEqual(remaining, 0)
    }

    func testCorrectionConflictAndFailureRollBackAllEffects() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "old", intent: "reply", contextSnapshotJSON: "{}"))
        let original = try await repo.items(sessionID: id)[0]
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_correction BEFORE UPDATE ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 0, text: "new"); XCTFail("Failure ignored") } catch {}
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items, [original])
        let current = try await repo.session(id: id)
        XCTAssertEqual(current?.semanticRevision, 0)
        let state = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.uuidString]) }
        XCTAssertEqual(state, "prepared")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_correction") }
        _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 0, text: "new")
        do { _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 1, text: "fork"); XCTFail("Correction fork accepted") } catch {}
    }

}
