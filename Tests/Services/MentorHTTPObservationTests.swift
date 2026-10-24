import Foundation
import XCTest
import GRDB
@testable import MingSi

final class MentorHTTPObservationTests: XCTestCase {
    func testV75DatabaseUpgradesWithoutRewritingExistingMetricsOrDraft() async throws {
        let queue = try DatabaseQueue()
        var migrator = Self.baseMigrator()
        SQLiteMentorHTTPObservationStore.registerMigration(on: &migrator)
        try migrator.migrate(queue, upTo: "v75_mentor_http_attempts")
        let old = try seed(queue)
        let json = String(decoding: try JSONEncoder().encode(MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0)), as: UTF8.self)
        try await queue.write { db in
            let columns = Set(try db.columns(in: "mentor_http_attempts").map(\.name))
            XCTAssertFalse(columns.contains("output_budget_field"))
            XCTAssertFalse(columns.contains("output_budget"))
            try db.execute(sql: """
                INSERT INTO mentor_http_attempts
                (attempt_id, trace_id, session_id, request_id, request_epoch, semantic_revision, protocol_kind,
                 dispatch_registered_at, terminal_state, elapsed_ms, metrics_state, metrics_json)
                VALUES (?, ?, ?, ?, 0, 0, 'responses', '2026-10-24T00:00:00Z', 'cancelled', 25, 'received', ?)
                """, arguments: [old.attemptID.uuidString, old.traceID.uuidString, old.sessionID.uuidString, old.requestID.uuidString, json])
        }
        try migrator.migrate(queue)
        let store = SQLiteMentorHTTPObservationStore(queue: queue)
        let beforeNewAttempt = try await store.attempts(requestID: old.requestID)
        let migrated = try XCTUnwrap(beforeNewAttempt.first)
        XCTAssertEqual(migrated.identity, old)
        XCTAssertEqual(migrated.exactNetworkTransactionCount, 1)
        XCTAssertEqual(migrated.terminalState, "cancelled")
        XCTAssertEqual(migrated.elapsedMilliseconds, 25)
        XCTAssertNil(migrated.outputBudgetField)
        XCTAssertNil(migrated.outputBudget, "Historical requests have no known budget")
        let new = copy(old, attemptID: UUID())
        try await store.beginAttempt(new, protocolKind: .responses, at: .now,
            outputBudgetField: "max_output_tokens", outputBudget: 16_000)
        let after = try await store.attempts(requestID: old.requestID)
        XCTAssertEqual(after.count, 2)
        XCTAssertEqual(after.last?.outputBudgetField, "max_output_tokens")
        XCTAssertEqual(after.last?.outputBudget, 16_000)
        let draft = try await queue.read { try String.fetchOne($0, sql: "SELECT draft_text FROM mentor_sessions") }
        XCTAssertEqual(draft, "preserve draft")
    }

    func testBudgetColumnsFromIntermediateCandidateCanUpgradeWithoutErasure() async throws {
        let queue = try DatabaseQueue()
        var migrator = Self.baseMigrator()
        SQLiteMentorHTTPObservationStore.registerMigration(on: &migrator)
        try migrator.migrate(queue, upTo: "v75_mentor_http_attempts")
        let identity = try seed(queue)
        try await queue.write { db in
            try db.execute(sql: "ALTER TABLE mentor_http_attempts ADD COLUMN output_budget_field TEXT")
            try db.execute(sql: "ALTER TABLE mentor_http_attempts ADD COLUMN output_budget INTEGER")
            try db.execute(sql: """
                INSERT INTO mentor_http_attempts
                (attempt_id, trace_id, session_id, request_id, request_epoch, semantic_revision, protocol_kind,
                 dispatch_registered_at, output_budget_field, output_budget)
                VALUES (?, ?, ?, ?, 0, 0, 'responses', '2026-10-24T00:00:00Z', 'max_output_tokens', 16000)
                """, arguments: [identity.attemptID.uuidString, identity.traceID.uuidString, identity.sessionID.uuidString, identity.requestID.uuidString])
        }
        try migrator.migrate(queue)
        let records = try await SQLiteMentorHTTPObservationStore(queue: queue).attempts(requestID: identity.requestID)
        XCTAssertEqual(records.first?.outputBudgetField, "max_output_tokens")
        XCTAssertEqual(records.first?.outputBudget, 16_000)
    }

    func testBudgetMetadataRejectsPrivateStringsMismatchedFieldsAndInvalidAmounts() async throws {
        let (_, store, identity) = try fixture()
        let invalid: [(MentorHTTPProtocol, String?, Int?)] = [
            (.responses, "PRIVATE_TEXT_SENTINEL", 1), (.responses, "max_output_tokens", nil),
            (.responses, nil, 1), (.responses, "max_tokens", 1),
            (.openAICompatible, "max_output_tokens", 1), (.responses, "max_output_tokens", 0),
            (.responses, "max_output_tokens", -1), (.responses, "max_output_tokens", 100_001)
        ]
        for (kind, field, amount) in invalid {
            do {
                try await store.beginAttempt(copy(identity, attemptID: UUID()), protocolKind: kind, at: .now,
                    outputBudgetField: field, outputBudget: amount)
                XCTFail("Invalid numeric metadata")
            } catch MentorHTTPObservationError.invalidIdentity { }
        }
        let records = try await store.attempts(requestID: identity.requestID)
        XCTAssertTrue(records.isEmpty)
    }

    func testMissingParentGraphCannotSilentlyMarkMigrationApplied() throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        SQLiteMentorHTTPObservationStore.registerMigration(on: &migrator)
        XCTAssertThrowsError(try migrator.migrate(queue))
        try queue.read { db in
            XCTAssertFalse(try db.tableExists("mentor_http_attempts"))
            XCTAssertFalse(try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations").contains("v75_mentor_http_attempts"))
        }
    }

    func testObservationWriteFailureIsSurfacedAndPendingRecordCannotMasqueradeAsComplete() async throws {
        let (queue, store, owner) = try fixture()
        let channel = MentorHTTPObservation(traceID: owner.traceID, sessionID: owner.sessionID, requestID: owner.requestID,
            requestEpoch: owner.requestEpoch, semanticRevision: owner.semanticRevision, store: store)
        let attempt = try await channel.beginAttempt(protocolKind: .responses)
        try await queue.write { db in
            try db.execute(sql: "CREATE TRIGGER reject_observation_update BEFORE UPDATE ON mentor_http_attempts BEGIN SELECT RAISE(ABORT, 'PRIVATE_DATABASE_DIAGNOSTIC'); END")
        }
        do { try await attempt.finish(.returnedData); XCTFail("Accounting write failure") }
        catch MentorHTTPObservationError.unavailable { }
        XCTAssertTrue(attempt.observationWriteFailed)
        do { try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0), identity: attempt.identity); XCTFail("Metrics write failure") }
        catch { }
        let records = try await store.attempts(requestID: owner.requestID)
        XCTAssertEqual(records.first?.terminalState, "pending")
        XCTAssertEqual(records.first?.metricsState, "pending")
        XCTAssertNil(records.first?.exactNetworkTransactionCount)
        XCTAssertNil(records.first?.elapsedMilliseconds)
    }

    func testRegistrationRejectsForeignOrStaleIdentityAndConflictingReuse() async throws {
        let (queue, store, identity) = try fixture()
        let date = Date(timeIntervalSince1970: 1_000)
        for bad in [copy(identity, sessionID: UUID()), copy(identity, epoch: 1), copy(identity, revision: 1)] {
            do { try await store.beginAttempt(bad, protocolKind: .responses, at: date); XCTFail("Must reject foreign/stale request") }
            catch MentorHTTPObservationError.staleRequest { }
        }
        try await store.beginAttempt(identity, protocolKind: .responses, at: date)
        try await store.beginAttempt(identity, protocolKind: .responses, at: date)
        do { try await store.beginAttempt(copy(identity, traceID: UUID()), protocolKind: .responses, at: date); XCTFail("Conflicting attempt ID") }
        catch MentorHTTPObservationError.conflict { }
        let count = try await queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_http_attempts") }
        XCTAssertEqual(count, 1)
    }

    func testIndependentAttemptsAndDuplicateCallbacksDoNotCollapseOrInflateNetworkCount() async throws {
        let (_, store, first) = try fixture()
        let second = copy(first, attemptID: UUID())
        for id in [first, second] { try await store.beginAttempt(id, protocolKind: .openAICompatible, at: .now) }
        let redirects = MentorHTTPMetrics(fetchKinds: [.network, .cache, .network], redirectCount: 1)
        try await store.finishAttempt(first, outcome: .returnedData, elapsedMilliseconds: 17)
        try await store.recordMetrics(redirects, identity: first)
        try await store.recordMetrics(redirects, identity: first)
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0), identity: second)
        try await store.finishAttempt(second, outcome: .failed, elapsedMilliseconds: 20)
        let records = try await store.attempts(requestID: first.requestID)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.exactNetworkTransactionCount), [2, 1])
        XCTAssertEqual(records.map(\.terminalState), ["returned_data", "failed"])
        XCTAssertEqual(records.first?.metrics?.transactionCount, 3)
    }

    func testLateMetricsAfterCancellationStayWithOldRequestAndCannotModifyNewTurn() async throws {
        let (queue, store, old) = try fixture()
        try await store.beginAttempt(old, protocolKind: .responses, at: .now)
        try await store.finishAttempt(old, outcome: .cancelled, elapsedMilliseconds: 50)
        let newRequest = UUID()
        try await queue.write { db in
            try db.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE id = ?", arguments: [old.requestID.uuidString])
            try db.execute(sql: "UPDATE mentor_sessions SET request_epoch = 1, draft_text = 'new draft' WHERE id = ?", arguments: [old.sessionID.uuidString])
            try db.execute(sql: "INSERT INTO mentor_requests (id, session_id, state, epoch, expected_revision) VALUES (?, ?, 'in_flight', 1, 0)",
                arguments: [newRequest.uuidString, old.sessionID.uuidString])
        }
        let current = MentorHTTPAttemptIdentity(attemptID: UUID(), traceID: UUID(), sessionID: old.sessionID,
            requestID: newRequest, requestEpoch: 1, semanticRevision: 0)
        try await store.beginAttempt(current, protocolKind: .responses, at: .now)
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network, .network], redirectCount: 1), identity: old)
        let previous = try await store.attempts(requestID: old.requestID)
        let latest = try await store.attempts(requestID: newRequest)
        XCTAssertEqual(previous.first?.terminalState, "cancelled")
        XCTAssertEqual(previous.first?.exactNetworkTransactionCount, 2)
        XCTAssertEqual(latest.first?.metricsState, "pending")
        XCTAssertNil(latest.first?.exactNetworkTransactionCount)
        let unaffected = try await queue.read { db in
            (try String.fetchOne(db, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [old.requestID.uuidString]),
             try String.fetchOne(db, sql: "SELECT draft_text FROM mentor_sessions WHERE id = ?", arguments: [old.sessionID.uuidString]))
        }
        XCTAssertEqual(unaffected.0, "cancelled")
        XCTAssertEqual(unaffected.1, "new draft")
    }

    func testDeletionCascadesAndLateCallbacksCannotResurrectRecords() async throws {
        let (queue, store, identity) = try fixture()
        try await store.beginAttempt(identity, protocolKind: .responses, at: .now)
        try await queue.write { try $0.execute(sql: "DELETE FROM mentor_requests WHERE id = ?", arguments: [identity.requestID.uuidString]) }
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0), identity: identity)
        try await store.finishAttempt(identity, outcome: .returnedData, elapsedMilliseconds: 5)
        let afterRequestDelete = try await store.attempts(requestID: identity.requestID)
        XCTAssertTrue(afterRequestDelete.isEmpty)
        try await queue.write { try $0.execute(sql: "DELETE FROM mentor_sessions WHERE id = ?", arguments: [identity.sessionID.uuidString]) }
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0), identity: identity)
        do { try await store.beginAttempt(identity, protocolKind: .responses, at: .now); XCTFail("Deleted identity") }
        catch MentorHTTPObservationError.staleRequest { }
        let count = try await queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_http_attempts") }
        XCTAssertEqual(count, 0)
    }

    func testConflictingMetricsRemainUnknownAndOriginalCountersRemainAvailable() async throws {
        let (_, store, identity) = try fixture()
        try await store.beginAttempt(identity, protocolKind: .responses, at: .now)
        let original = MentorHTTPMetrics(fetchKinds: [.network], redirectCount: 0)
        try await store.recordMetrics(original, identity: identity)
        do { try await store.recordMetrics(original, identity: copy(identity, traceID: UUID())); XCTFail("Foreign callback") }
        catch MentorHTTPObservationError.conflict { }
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network, .network], redirectCount: 1), identity: identity)
        try await store.recordMetrics(original, identity: identity)
        try await store.finishAttempt(identity, outcome: .cancelled, elapsedMilliseconds: 10)
        try await store.finishAttempt(identity, outcome: .returnedData, elapsedMilliseconds: 11)
        let records = try await store.attempts(requestID: identity.requestID)
        XCTAssertEqual(records.first?.metricsState, "conflict")
        XCTAssertNil(records.first?.exactNetworkTransactionCount)
        XCTAssertEqual(records.first?.metrics, original)
        XCTAssertEqual(records.first?.terminalState, "conflict")
    }

    func testCompletedTransportWithoutNativeMetricsNeverBecomesOneHTTP() async throws {
        let (_, store, identity) = try fixture()
        try await store.beginAttempt(identity, protocolKind: .responses, at: .now)
        try await store.finishAttempt(identity, outcome: .returnedData, elapsedMilliseconds: 3)
        var records = try await store.attempts(requestID: identity.requestID)
        XCTAssertEqual(records.first?.metricsState, "pending")
        XCTAssertNil(records.first?.exactNetworkTransactionCount)
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [], redirectCount: 0), identity: identity)
        records = try await store.attempts(requestID: identity.requestID)
        XCTAssertEqual(records.first?.metricsState, "received")
        XCTAssertNil(records.first?.exactNetworkTransactionCount)
    }

    func testMigrationPreservesOldDataAndReopenKeepsCountersAndIdentity() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("observations.sqlite")
        let queue = try DatabaseQueue(path: file.path)
        var migrator = Self.baseMigrator()
        SQLiteMentorHTTPObservationStore.registerMigration(on: &migrator)
        try migrator.migrate(queue, upTo: "fixture_graph")
        let identity = try seed(queue)
        try migrator.migrate(queue)
        let store = SQLiteMentorHTTPObservationStore(queue: queue)
        let before = try await store.attempts(requestID: identity.requestID)
        XCTAssertTrue(before.isEmpty, "No guessed metrics for historical requests")
        try await store.beginAttempt(identity, protocolKind: .responses, at: .now)
        try await store.recordMetrics(MentorHTTPMetrics(fetchKinds: [.network, .cache, .network], redirectCount: 1), identity: identity)
        try await store.finishAttempt(identity, outcome: .cancelled, elapsedMilliseconds: 25)
        let reopenedQueue = try DatabaseQueue(path: file.path)
        let reopened = try await SQLiteMentorHTTPObservationStore(queue: reopenedQueue).attempts(requestID: identity.requestID)
        XCTAssertEqual(reopened.first?.identity, identity)
        XCTAssertEqual(reopened.first?.exactNetworkTransactionCount, 2)
        XCTAssertEqual(reopened.first?.terminalState, "cancelled")
        let draft = try await reopenedQueue.read { try String.fetchOne($0, sql: "SELECT draft_text FROM mentor_sessions") }
        XCTAssertEqual(draft, "preserve draft")
    }

    private func fixture() throws -> (DatabaseQueue, SQLiteMentorHTTPObservationStore, MentorHTTPAttemptIdentity) {
        let queue = try DatabaseQueue()
        var migrator = Self.baseMigrator()
        SQLiteMentorHTTPObservationStore.registerMigration(on: &migrator)
        try migrator.migrate(queue)
        return (queue, SQLiteMentorHTTPObservationStore(queue: queue), try seed(queue))
    }

    private static func baseMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("fixture_graph") { db in
            try db.execute(sql: """
                CREATE TABLE mentor_sessions (id TEXT PRIMARY KEY, request_epoch INTEGER NOT NULL, semantic_revision INTEGER NOT NULL, draft_text TEXT NOT NULL);
                CREATE TABLE mentor_requests (id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES mentor_sessions(id) ON DELETE CASCADE,
                    state TEXT NOT NULL, epoch INTEGER NOT NULL, expected_revision INTEGER NOT NULL, UNIQUE(session_id, id));
                """)
        }
        return migrator
    }

    private func seed(_ queue: DatabaseQueue) throws -> MentorHTTPAttemptIdentity {
        let identity = MentorHTTPAttemptIdentity(attemptID: UUID(), traceID: UUID(), sessionID: UUID(), requestID: UUID(), requestEpoch: 0, semanticRevision: 0)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO mentor_sessions VALUES (?, 0, 0, 'preserve draft')", arguments: [identity.sessionID.uuidString])
            try db.execute(sql: "INSERT INTO mentor_requests VALUES (?, ?, 'in_flight', 0, 0)", arguments: [identity.requestID.uuidString, identity.sessionID.uuidString])
        }
        return identity
    }

    private func copy(_ value: MentorHTTPAttemptIdentity, attemptID: UUID? = nil, sessionID: UUID? = nil,
                      traceID: UUID? = nil, epoch: Int? = nil, revision: Int? = nil) -> MentorHTTPAttemptIdentity {
        MentorHTTPAttemptIdentity(attemptID: attemptID ?? value.attemptID, traceID: traceID ?? value.traceID,
            sessionID: sessionID ?? value.sessionID, requestID: value.requestID,
            requestEpoch: epoch ?? value.requestEpoch, semanticRevision: revision ?? value.semanticRevision)
    }
}
