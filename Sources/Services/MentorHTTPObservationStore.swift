import Foundation
import GRDB

struct MentorHTTPAttemptRecord: Sendable {
    let identity: MentorHTTPAttemptIdentity
    let protocolKind: MentorHTTPProtocol
    let terminalState: String
    let elapsedMilliseconds: Int64?
    let metricsState: String
    let metrics: MentorHTTPMetrics?
    let outputBudgetField: String?
    let outputBudget: Int?
    let usageState: String
    let serviceUsage: MentorServiceUsage?
    var exactNetworkTransactionCount: Int? {
        metricsState == "received" ? metrics?.exactNetworkTransactionCount : nil
    }
    var usableServiceUsage: MentorServiceUsage? {
        usageState == "received" && serviceUsage?.hasInvalidFields == false ? serviceUsage : nil
    }
}

/// Only the thread-safe queue crosses the callback boundary; AppDatabase and
/// mutable UI/repository objects do not. Every late write updates an existing row.
final class SQLiteMentorHTTPObservationStore: MentorHTTPObservationStore {
    private let queue: DatabaseQueue
    init(queue: DatabaseQueue) { self.queue = queue }

    static func registerMigration(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v75_mentor_http_attempts") { db in
            // AppDatabase registers this only with the Mentor migrations. Do
            // not mark it applied if the required parent graph is missing.
            guard try db.tableExists("mentor_requests") else { throw MentorHTTPObservationError.unavailable }
            try db.create(table: "mentor_http_attempts") { t in
                t.column("attempt_id", .text).primaryKey()
                t.column("schema_version", .integer).notNull().defaults(to: 1)
                t.column("trace_id", .text).notNull()
                t.column("session_id", .text).notNull().indexed().references("mentor_sessions", onDelete: .cascade)
                t.column("request_id", .text).notNull().indexed()
                t.foreignKey(["session_id", "request_id"], references: "mentor_requests", columns: ["session_id", "id"], onDelete: .cascade)
                t.column("request_epoch", .integer).notNull().check { $0 >= 0 }
                t.column("semantic_revision", .integer).notNull().check { $0 >= 0 }
                t.column("protocol_kind", .text).notNull()
                t.column("dispatch_registered_at", .text).notNull()
                t.column("terminal_state", .text).notNull().defaults(to: "pending")
                t.column("elapsed_ms", .integer).check { $0 >= 0 }
                t.column("metrics_state", .text).notNull().defaults(to: "pending")
                t.column("metrics_json", .text)
            }
        }
        // v75 shipped without these columns. Keep its definition intact and
        // upgrade existing files; a fresh database is not an upgrade test.
        migrator.registerMigration("v76_mentor_http_output_budget") { db in
            let columns = Set(try db.columns(in: "mentor_http_attempts").map(\.name))
            try db.alter(table: "mentor_http_attempts") { t in
                // Some intermediate candidates created these columns in v75.
                // Add only missing columns, without rewriting existing rows.
                if !columns.contains("output_budget_field") {
                    t.add(column: "output_budget_field", .text)
                }
                if !columns.contains("output_budget") {
                    t.add(column: "output_budget", .integer).check { $0 > 0 && $0 <= 100_000 }
                }
            }
        }
        migrator.registerMigration("v77_mentor_service_usage") { db in
            try db.alter(table: "mentor_http_attempts") { t in
                t.add(column: "usage_state", .text).notNull().defaults(to: "pending")
                t.add(column: "usage_json", .text)
            }
        }
    }

    func beginAttempt(_ identity: MentorHTTPAttemptIdentity, protocolKind: MentorHTTPProtocol, at date: Date,
                      outputBudgetField: String?, outputBudget: Int?) async throws {
        let validBudget: Bool
        switch (outputBudgetField, outputBudget) {
        case (nil, nil): validBudget = true
        case (let field?, let value?):
            let allowedFields: Set<String> = protocolKind == .responses
                ? ["max_output_tokens"] : ["max_tokens", "max_completion_tokens"]
            validBudget = allowedFields.contains(field) && (1...100_000).contains(value)
        default: validBudget = false
        }
        guard identity.requestEpoch >= 0, identity.semanticRevision >= 0, date.timeIntervalSince1970.isFinite,
              validBudget else {
            throw MentorHTTPObservationError.invalidIdentity
        }
        let timestamp = ISO8601DateFormatter().string(from: date)
        try await queue.write { db in
            guard try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM mentor_requests r JOIN mentor_sessions s ON s.id = r.session_id
                WHERE r.id = ? AND r.session_id = ? AND r.epoch = ? AND r.expected_revision = ?
                  AND s.request_epoch = ? AND s.semantic_revision = ?
                  AND r.state IN ('prepared', 'in_flight', 'response_received')
                """, arguments: [identity.requestID.uuidString, identity.sessionID.uuidString,
                    identity.requestEpoch, identity.semanticRevision, identity.requestEpoch, identity.semanticRevision]) == 1 else {
                throw MentorHTTPObservationError.staleRequest
            }
            if let row = try Self.ownedRow(identity, db: db) {
                guard (row["protocol_kind"] as String) == protocolKind.rawValue,
                      (row["dispatch_registered_at"] as String) == timestamp,
                      (row["output_budget_field"] as String?) == outputBudgetField,
                      (row["output_budget"] as Int?) == outputBudget else { throw MentorHTTPObservationError.conflict }
                return
            }
            try db.execute(sql: """
                INSERT INTO mentor_http_attempts
                (attempt_id, trace_id, session_id, request_id, request_epoch, semantic_revision, protocol_kind, dispatch_registered_at, output_budget_field, output_budget)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [identity.attemptID.uuidString, identity.traceID.uuidString, identity.sessionID.uuidString,
                    identity.requestID.uuidString, identity.requestEpoch, identity.semanticRevision, protocolKind.rawValue, timestamp,
                    outputBudgetField, outputBudget])
        }
    }

    func recordMetrics(_ metrics: MentorHTTPMetrics, identity: MentorHTTPAttemptIdentity) async throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(metrics), as: UTF8.self)
        try await queue.write { db in
            // Missing means deleted/not registered. Never insert in a callback.
            guard let row = try Self.ownedRow(identity, db: db) else { return }
            let state: String = row["metrics_state"]
            if state == "pending" {
                try db.execute(sql: "UPDATE mentor_http_attempts SET metrics_state = 'received', metrics_json = ? WHERE attempt_id = ?",
                    arguments: [json, identity.attemptID.uuidString])
            } else if state == "received", (row["metrics_json"] as String?) != json {
                // Retain the original counters but stop reporting an exact total.
                try db.execute(sql: "UPDATE mentor_http_attempts SET metrics_state = 'conflict' WHERE attempt_id = ?",
                    arguments: [identity.attemptID.uuidString])
            }
        }
    }

    func finishAttempt(_ identity: MentorHTTPAttemptIdentity, outcome: MentorHTTPAttemptOutcome, elapsedMilliseconds: Int64) async throws {
        guard elapsedMilliseconds >= 0 else { throw MentorHTTPObservationError.invalidIdentity }
        try await queue.write { db in
            guard let row = try Self.ownedRow(identity, db: db) else { return }
            let state: String = row["terminal_state"]
            if state == "pending" {
                try db.execute(sql: "UPDATE mentor_http_attempts SET terminal_state = ?, elapsed_ms = ? WHERE attempt_id = ?",
                    arguments: [outcome.rawValue, elapsedMilliseconds, identity.attemptID.uuidString])
            } else if state != outcome.rawValue || (row["elapsed_ms"] as Int64?) != elapsedMilliseconds {
                try db.execute(sql: "UPDATE mentor_http_attempts SET terminal_state = 'conflict' WHERE attempt_id = ?",
                    arguments: [identity.attemptID.uuidString])
            }
        }
    }

    func recordServiceUsage(_ usage: MentorServiceUsage, identity: MentorHTTPAttemptIdentity) async throws {
        guard [usage.inputTokens, usage.outputTokens, usage.totalTokens, usage.reasoningTokens].allSatisfy({ $0 == nil || $0! >= 0 }) else {
            throw MentorHTTPObservationError.invalidIdentity
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(usage), as: UTF8.self)
        try await queue.write { db in
            guard let row = try Self.ownedRow(identity, db: db) else { return }
            guard (row["protocol_kind"] as String) == usage.source.protocolKind.rawValue else {
                throw MentorHTTPObservationError.invalidIdentity
            }
            let state: String = row["usage_state"]
            if state == "pending" {
                try db.execute(sql: "UPDATE mentor_http_attempts SET usage_state = ?, usage_json = ? WHERE attempt_id = ?",
                    arguments: [usage.hasInvalidFields ? "invalid" : (usage.hasReportedCounts ? "received" : "empty"), json, identity.attemptID.uuidString])
            } else if state != "conflict", (row["usage_json"] as String?) != json {
                // Preserve the first report without summing or silently replacing
                // contradictory reports. A conflict is not usable billing data.
                try db.execute(sql: "UPDATE mentor_http_attempts SET usage_state = 'conflict' WHERE attempt_id = ?",
                    arguments: [identity.attemptID.uuidString])
            }
        }
    }

    func attempts(requestID: UUID) async throws -> [MentorHTTPAttemptRecord] {
        try await queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM mentor_http_attempts WHERE request_id = ? ORDER BY rowid",
                arguments: [requestID.uuidString]).map { row in
                guard let attemptID = UUID(uuidString: row["attempt_id"]), let traceID = UUID(uuidString: row["trace_id"]),
                      let sessionID = UUID(uuidString: row["session_id"]), let requestID = UUID(uuidString: row["request_id"]),
                      let kind = MentorHTTPProtocol(rawValue: row["protocol_kind"]) else { throw MentorHTTPObservationError.invalidIdentity }
                let metricsJSON: String? = row["metrics_json"]
                let usageJSON: String? = row["usage_json"]
                return MentorHTTPAttemptRecord(identity: MentorHTTPAttemptIdentity(attemptID: attemptID, traceID: traceID,
                    sessionID: sessionID, requestID: requestID, requestEpoch: row["request_epoch"], semanticRevision: row["semantic_revision"]),
                    protocolKind: kind, terminalState: row["terminal_state"], elapsedMilliseconds: row["elapsed_ms"],
                    metricsState: row["metrics_state"], metrics: try metricsJSON.map { try JSONDecoder().decode(MentorHTTPMetrics.self, from: Data($0.utf8)) },
                    outputBudgetField: row["output_budget_field"], outputBudget: row["output_budget"],
                    usageState: row["usage_state"], serviceUsage: try usageJSON.map {
                        try JSONDecoder().decode(MentorServiceUsage.self, from: Data($0.utf8))
                    })
            }
        }
    }

    private static func ownedRow(_ identity: MentorHTTPAttemptIdentity, db: Database) throws -> Row? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM mentor_http_attempts WHERE attempt_id = ?",
            arguments: [identity.attemptID.uuidString]) else { return nil }
        guard (row["session_id"] as String) == identity.sessionID.uuidString,
              (row["request_id"] as String) == identity.requestID.uuidString,
              (row["trace_id"] as String) == identity.traceID.uuidString,
              (row["request_epoch"] as Int) == identity.requestEpoch,
              (row["semantic_revision"] as Int) == identity.semanticRevision else { throw MentorHTTPObservationError.conflict }
        return row
    }
}
