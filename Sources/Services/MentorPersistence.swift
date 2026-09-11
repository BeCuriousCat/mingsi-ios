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
}

struct MentorTimelineItem: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let sequence: Int
    let kind: MentorItemKind
    let payloadJSON: String
}

protocol MentorRepository {
    func createSession(_ session: MentorSession) async throws
    func session(id: UUID) async throws -> MentorSession?
    func saveDraft(sessionID: UUID, revision: Int, text: String) async throws
    func appendItem(_ item: MentorTimelineItem) async throws
    func items(sessionID: UUID) async throws -> [MentorTimelineItem]
    func deleteSession(id: UUID) async throws
    func submitTurn(_ command: MentorSubmitTurn) async throws -> UUID
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
        try await database.dbQueue.write { db in try MentorSessionRow(session).insert(db) }
    }

    func session(id: UUID) async throws -> MentorSession? {
        try await database.dbQueue.read { db in try MentorSessionRow.fetchOne(db, key: id.uuidString)?.model() }
    }

    func saveDraft(sessionID: UUID, revision: Int, text: String) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "UPDATE mentor_sessions SET draft_text = ?, draft_revision = ?, activity_at = ? WHERE id = ? AND draft_revision <= ?", arguments: [text, revision, ISO8601DateFormatter().string(from: .now), sessionID.uuidString, revision])
            guard db.changesCount > 0 else { throw PersistenceError.validationFailed("stale or missing mentor draft") }
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

    func submitTurn(_ command: MentorSubmitTurn) async throws -> UUID {
        try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: command.sessionID.uuidString) != nil else { throw PersistenceError.validationFailed("mentor session missing") }
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
            let request = MentorRequestRow(id: UUID().uuidString, sessionID: command.sessionID.uuidString, commandID: command.commandID.uuidString, userItemID: itemID, intent: command.intent, contextSnapshotJSON: command.contextSnapshotJSON, state: "prepared", createdAt: ISO8601DateFormatter().string(from: .now))
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
    enum CodingKeys: String, CodingKey { case id, sessionID = "session_id", commandID = "command_id", userItemID = "user_item_id", intent, contextSnapshotJSON = "context_snapshot_json", state, createdAt = "created_at" }
}

private struct MentorSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, initialEntry, lifecycle, draftText: String
    var draftRevision: Int
    var activityAt: String
    enum CodingKeys: String, CodingKey { case id, initialEntry = "initial_entry", lifecycle, draftText = "draft_text", draftRevision = "draft_revision", activityAt = "activity_at" }
    init(_ value: MentorSession) { id = value.id.uuidString; initialEntry = value.initialEntry; lifecycle = value.lifecycle.rawValue; draftText = value.draftText; draftRevision = value.draftRevision; activityAt = ISO8601DateFormatter().string(from: value.activityAt) }
    func model() throws -> MentorSession { guard let id = UUID(uuidString: id), let lifecycle = MentorSessionLifecycle(rawValue: lifecycle), let date = ISO8601DateFormatter().date(from: activityAt) else { throw PersistenceError.invalidStoredValue("mentor_sessions") }; return MentorSession(id: id, initialEntry: initialEntry, lifecycle: lifecycle, draftText: draftText, draftRevision: draftRevision, activityAt: date) }
}

private struct MentorItemRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_items"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, sessionID: String
    var sequence: Int
    var kind, payloadJSON: String
    enum CodingKeys: String, CodingKey { case id, sessionID = "session_id", sequence, kind, payloadJSON = "payload_json" }
    init(_ value: MentorTimelineItem) { id = value.id.uuidString; sessionID = value.sessionID.uuidString; sequence = value.sequence; kind = value.kind.rawValue; payloadJSON = value.payloadJSON }
    func model() throws -> MentorTimelineItem { guard let id = UUID(uuidString: id), let sessionID = UUID(uuidString: sessionID), let kind = MentorItemKind(rawValue: kind) else { throw PersistenceError.invalidStoredValue("mentor_items") }; return MentorTimelineItem(id: id, sessionID: sessionID, sequence: sequence, kind: kind, payloadJSON: payloadJSON) }
}
