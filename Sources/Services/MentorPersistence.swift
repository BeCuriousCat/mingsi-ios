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
