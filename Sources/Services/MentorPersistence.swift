import Foundation
import GRDB

enum MentorSessionLifecycle: String, Codable { case draft, active, paused, ended }
enum MentorItemKind: String, Codable { case user, assistant, lesson }

struct MentorSession: Codable, Equatable, Identifiable {
    let id: UUID
    let initialEntry: String
    var lifecycle: MentorSessionLifecycle
    var draftText: String
    var draftRevision: Int
    var activityAt: Date
    var semanticRevision: Int = 0
    var requestEpoch: Int = 0
}

struct MentorTimelineItem: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let sequence: Int
    let kind: MentorItemKind
    let payloadJSON: String
    var supersedesItemID: UUID? = nil
}

protocol MentorRepository {
    func createSession(_ session: MentorSession) async throws
    func session(id: UUID) async throws -> MentorSession?
    func saveDraft(sessionID: UUID, revision: Int, text: String) async throws
    func appendItem(_ item: MentorTimelineItem) async throws
    func items(sessionID: UUID) async throws -> [MentorTimelineItem]
    func deleteSession(id: UUID) async throws
    func submitTurn(_ command: MentorSubmitTurn) async throws -> UUID
    func suspendSession(id: UUID, ending: Bool, draftRevision: Int, draftText: String) async throws
    func resumeSession(id: UUID) async throws
    func correctUserItem(sessionID: UUID, itemID: UUID, commandID: UUID, expectedRevision: Int, text: String) async throws -> MentorTimelineItem
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String) async throws -> MentorTimelineItem
}

struct MentorSubmitTurn: Equatable {
    let commandID: UUID
    let sessionID: UUID
    let text: String?
    let intent: String
    let contextSnapshotJSON: String
}

final class SQLiteMentorRepository: MentorRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    func createSession(_ session: MentorSession) async throws {
        guard session.draftRevision >= 0, session.semanticRevision == 0, session.requestEpoch == 0 else { throw PersistenceError.validationFailed("negative mentor draft revision") }
        try await database.dbQueue.write { db in try MentorSessionRow(session).insert(db) }
    }

    func session(id: UUID) async throws -> MentorSession? {
        try await database.dbQueue.read { db in try MentorSessionRow.fetchOne(db, key: id.uuidString)?.model() }
    }

    func saveDraft(sessionID: UUID, revision: Int, text: String) async throws {
        try await database.dbQueue.write { db in
            guard let current = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString),
                  revision >= 0, revision >= current.draftRevision else {
                throw PersistenceError.validationFailed("stale or missing mentor draft")
            }
            if revision == current.draftRevision {
                guard text == current.draftText else {
                    throw PersistenceError.validationFailed("mentor draft revision conflict")
                }
                return // An exact retry must not change activity ordering.
            }
            guard ["draft", "active"].contains(current.lifecycle) else {
                throw PersistenceError.validationFailed("mentor draft requires an active session")
            }
            try db.execute(sql: "UPDATE mentor_sessions SET draft_text = ?, draft_revision = ?, activity_at = ? WHERE id = ?", arguments: [text, revision, ISO8601DateFormatter().string(from: .now), sessionID.uuidString])
        }
    }

    func appendItem(_ item: MentorTimelineItem) async throws {
        try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: item.sessionID.uuidString) != nil else { throw PersistenceError.validationFailed("mentor session missing") }
            try MentorItemRow(item).insert(db)
        }
    }

    func items(sessionID: UUID) async throws -> [MentorTimelineItem] {
        try await database.dbQueue.read { db in
            try MentorItemRow.filter(Column("session_id") == sessionID.uuidString)
                .order(Column("sequence"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    func deleteSession(id: UUID) async throws {
        try await database.dbQueue.write { db in try MentorSessionRow.deleteOne(db, key: id.uuidString) }
    }

    func correctUserItem(sessionID: UUID, itemID: UUID, commandID: UUID, expectedRevision: Int, text: String) async throws -> MentorTimelineItem {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("empty mentor correction")
        }
        let payload = String(decoding: try JSONEncoder().encode(["text": text]), as: UTF8.self)
        return try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString),
                  let original = try MentorItemRow.fetchOne(db, key: itemID.uuidString),
                  original.sessionID == session.id, original.kind == "user" else {
                throw PersistenceError.validationFailed("correction requires owned user text")
            }
            if let row = try Row.fetchOne(db, sql: "SELECT session_id, item_id, expected_revision FROM mentor_corrections WHERE command_id = ?", arguments: [commandID.uuidString]) {
                let owner: String = row["session_id"]
                let revision: Int = row["expected_revision"]
                let savedID: String = row["item_id"]
                guard owner == session.id, revision == expectedRevision,
                      let saved = try MentorItemRow.fetchOne(db, key: savedID),
                      saved.supersedesItemID == original.id, saved.payloadJSON == payload else {
                    throw PersistenceError.validationFailed("conflicting correction command")
                }
                return try saved.model()
            }
            guard session.lifecycle == "active", session.semanticRevision == expectedRevision,
                  try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_items WHERE supersedes_item_id = ?", arguments: [original.id]) == 0 else {
                throw PersistenceError.validationFailed("stale mentor correction")
            }
            let sequence = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sequence), 0) + 1 FROM mentor_items WHERE session_id = ?", arguments: [session.id]) ?? 1
            let correction = MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: sequence, kind: .user, payloadJSON: payload, supersedesItemID: itemID)
            try MentorItemRow(correction).insert(db)
            try db.execute(sql: "INSERT INTO mentor_corrections (command_id, session_id, item_id, expected_revision) VALUES (?, ?, ?, ?)", arguments: [commandID.uuidString, session.id, correction.id.uuidString, expectedRevision])
            try db.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [session.id])
            try db.execute(sql: "UPDATE mentor_sessions SET semantic_revision = semantic_revision + 1, request_epoch = request_epoch + 1, activity_at = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: .now), session.id])
            return correction
        }
    }

    /// Explicit user continuation; cancelled requests remain terminal.
    func resumeSession(id: UUID) async throws {
        try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: id.uuidString) else {
                throw PersistenceError.validationFailed("mentor session missing")
            }
            guard session.lifecycle != "active" else { return }
            try db.execute(sql: "UPDATE mentor_sessions SET lifecycle = 'active', activity_at = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: .now), id.uuidString])
        }
    }

    /// Cancels persisted attempts and flushes the draft in the same transaction.
    /// The caller must cancel its in-memory transport before invoking this command.
    func suspendSession(id: UUID, ending: Bool, draftRevision: Int, draftText: String) async throws {
        try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: id.uuidString),
                  draftRevision >= 0, draftRevision >= session.draftRevision,
                  draftRevision > session.draftRevision || draftText == session.draftText else {
                throw PersistenceError.validationFailed("stale or missing mentor session")
            }
            if session.lifecycle == "ended" {
                guard ending, draftRevision == session.draftRevision, draftText == session.draftText else {
                    throw PersistenceError.validationFailed("ended mentor session cannot be overwritten by suspension")
                }
                return
            }
            try db.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [id.uuidString])
            try db.execute(sql: "UPDATE mentor_sessions SET request_epoch = request_epoch + 1, lifecycle = ?, draft_revision = ?, draft_text = ?, activity_at = ? WHERE id = ?", arguments: [ending ? "ended" : "paused", draftRevision, draftText, ISO8601DateFormatter().string(from: .now), id.uuidString])
        }
    }

    /// Storage boundary only: caller must first validate the mentor response protocol
    /// and dynamic source/intent rules. Does not mark content as presented.
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String) async throws -> MentorTimelineItem {
        guard let data = payloadJSON.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else {
            throw PersistenceError.validationFailed("invalid mentor response JSON")
        }
        return try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString),
                  let request = try MentorRequestRow.fetchOne(db, key: requestID.uuidString),
                  request.sessionID == session.id else {
                throw PersistenceError.validationFailed("mentor response owner missing or mismatched")
            }
            if request.state == "committed" {
                guard let itemID = try String.fetchOne(db, sql: "SELECT item_id FROM mentor_request_results WHERE request_id = ? AND session_id = ?", arguments: [request.id, session.id]),
                      let item = try MentorItemRow.fetchOne(db, key: itemID),
                      item.payloadJSON == payloadJSON else {
                    throw PersistenceError.validationFailed("conflicting mentor response replay")
                }
                return try item.model()
            }
            guard session.lifecycle == "active",
                  request.epoch == session.requestEpoch,
                  request.expectedRevision == session.semanticRevision,
                  ["prepared", "in_flight", "response_received"].contains(request.state) else {
                throw PersistenceError.validationFailed("mentor response is no longer valid")
            }
            let next = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sequence), 0) + 1 FROM mentor_items WHERE session_id = ?", arguments: [session.id]) ?? 1
            let item = MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: next, kind: .assistant, payloadJSON: payloadJSON)
            try MentorItemRow(item).insert(db)
            try db.execute(sql: "INSERT INTO mentor_request_results (request_id, session_id, item_id) VALUES (?, ?, ?)", arguments: [request.id, session.id, item.id.uuidString])
            try db.execute(sql: "UPDATE mentor_requests SET state = 'committed' WHERE id = ?", arguments: [request.id])
            try db.execute(sql: "UPDATE mentor_sessions SET activity_at = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: .now), session.id])
            return item
        }
    }

    func submitTurn(_ command: MentorSubmitTurn) async throws -> UUID {
        try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: command.sessionID.uuidString) else { throw PersistenceError.validationFailed("mentor session missing") }
            guard let contextData = command.contextSnapshotJSON.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: contextData)) is [String: Any],
                  !command.intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PersistenceError.validationFailed("invalid mentor request context or intent")
            }
            let payload = try command.text.map { text -> String in
                let data = try JSONEncoder().encode(["text": text])
                return String(decoding: data, as: UTF8.self)
            }
            if let existing = try MentorRequestRow.filter(Column("session_id") == command.sessionID.uuidString && Column("command_id") == command.commandID.uuidString).fetchOne(db) {
                let previousPayload = try existing.userItemID.flatMap { try MentorItemRow.fetchOne(db, key: $0)?.payloadJSON }
                guard existing.intent == command.intent,
                      existing.contextSnapshotJSON == command.contextSnapshotJSON,
                      previousPayload == payload,
                      let requestID = UUID(uuidString: existing.id) else {
                    throw PersistenceError.validationFailed("mentor command reused with different content")
                }
                return requestID
            }
            let pending = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_requests WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [command.sessionID.uuidString]) ?? 0
            guard pending == 0 else { throw PersistenceError.validationFailed("mentor request already pending") }
            let next = (try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sequence), 0) + 1 FROM mentor_items WHERE session_id = ?", arguments: [command.sessionID.uuidString])) ?? 1
            var itemID: String?
            if let payload {
                guard command.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw PersistenceError.validationFailed("empty mentor submission")
                }
                let item = MentorTimelineItem(id: UUID(), sessionID: command.sessionID, sequence: next, kind: .user, payloadJSON: payload)
                try MentorItemRow(item).insert(db)
                itemID = item.id.uuidString
            }
            let request = MentorRequestRow(id: UUID().uuidString, sessionID: command.sessionID.uuidString, commandID: command.commandID.uuidString, userItemID: itemID, intent: command.intent, contextSnapshotJSON: command.contextSnapshotJSON, state: "prepared", createdAt: ISO8601DateFormatter().string(from: .now), expectedRevision: session.semanticRevision, epoch: session.requestEpoch)
            try request.insert(db)
            try db.execute(sql: "UPDATE mentor_sessions SET lifecycle = 'active', activity_at = ? WHERE id = ?", arguments: [request.createdAt, command.sessionID.uuidString])
            guard let requestID = UUID(uuidString: request.id) else { throw PersistenceError.invalidStoredValue("mentor request ID") }
            return requestID
        }
    }
}

private struct MentorRequestRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_requests"
    var id, sessionID, commandID: String
    var userItemID: String?
    var intent, contextSnapshotJSON, state, createdAt: String
    var expectedRevision, epoch: Int
    enum CodingKeys: String, CodingKey { case id, sessionID = "session_id", commandID = "command_id", userItemID = "user_item_id", intent, contextSnapshotJSON = "context_snapshot_json", state, createdAt = "created_at", expectedRevision = "expected_revision", epoch }
}

private struct MentorSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, initialEntry, lifecycle, draftText: String
    var draftRevision: Int
    var activityAt: String
    var semanticRevision, requestEpoch: Int
    enum CodingKeys: String, CodingKey { case id, initialEntry = "initial_entry", lifecycle, draftText = "draft_text", draftRevision = "draft_revision", activityAt = "activity_at", semanticRevision = "semantic_revision", requestEpoch = "request_epoch" }
    init(_ value: MentorSession) { id = value.id.uuidString; initialEntry = value.initialEntry; lifecycle = value.lifecycle.rawValue; draftText = value.draftText; draftRevision = value.draftRevision; activityAt = ISO8601DateFormatter().string(from: value.activityAt); semanticRevision = value.semanticRevision; requestEpoch = value.requestEpoch }
    func model() throws -> MentorSession { guard let id = UUID(uuidString: id), let lifecycle = MentorSessionLifecycle(rawValue: lifecycle), let date = ISO8601DateFormatter().date(from: activityAt) else { throw PersistenceError.invalidStoredValue("mentor_sessions") }; return MentorSession(id: id, initialEntry: initialEntry, lifecycle: lifecycle, draftText: draftText, draftRevision: draftRevision, activityAt: date, semanticRevision: semanticRevision, requestEpoch: requestEpoch) }
}

private struct MentorItemRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_items"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, sessionID: String
    var sequence: Int
    var kind, payloadJSON: String
    var supersedesItemID: String?
    enum CodingKeys: String, CodingKey { case id, sessionID = "session_id", sequence, kind, payloadJSON = "payload_json", supersedesItemID = "supersedes_item_id" }
    init(_ value: MentorTimelineItem) { id = value.id.uuidString; sessionID = value.sessionID.uuidString; sequence = value.sequence; kind = value.kind.rawValue; payloadJSON = value.payloadJSON; supersedesItemID = value.supersedesItemID?.uuidString }
    func model() throws -> MentorTimelineItem { guard let id = UUID(uuidString: id), let sessionID = UUID(uuidString: sessionID), let kind = MentorItemKind(rawValue: kind) else { throw PersistenceError.invalidStoredValue("mentor_items") }; return MentorTimelineItem(id: id, sessionID: sessionID, sequence: sequence, kind: kind, payloadJSON: payloadJSON, supersedesItemID: supersedesItemID.flatMap(UUID.init(uuidString:))) }
}
