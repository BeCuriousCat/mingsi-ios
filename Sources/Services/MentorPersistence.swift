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
    var recallCount: Int = 0
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

/// Cursor retains the exact stored timestamp, avoiding date round-trip drift.
struct MentorSessionCursor: Equatable {
    fileprivate let storedActivityAt: String
    fileprivate let id: String
}

struct MentorSessionSummary: Equatable, Identifiable {
    let id: UUID
    let initialEntry: String
    let lifecycle: MentorSessionLifecycle
    let activityAt: Date
    let preview: String
}

struct MentorSessionPage: Equatable {
    let sessions: [MentorSessionSummary]
    let nextCursor: MentorSessionCursor?
}

protocol MentorRepository {
    func createSession(_ session: MentorSession) async throws
    func session(id: UUID) async throws -> MentorSession?
    func acknowledgePresentation(sessionID: UUID, itemID: UUID, at date: Date, timeZone: TimeZone) async throws
    func recentSessions(after cursor: MentorSessionCursor?, limit: Int) async throws -> MentorSessionPage
    func saveDraft(sessionID: UUID, revision: Int, text: String) async throws
    func appendItem(_ item: MentorTimelineItem) async throws
    func items(sessionID: UUID) async throws -> [MentorTimelineItem]
    func deleteSession(id: UUID) async throws
    func submitTurn(_ command: MentorSubmitTurn) async throws -> UUID
    func recoverInterruptedRequests() async throws -> Int
    func finishRequest(sessionID: UUID, requestID: UUID, reason: MentorRequestEndReason) async throws
    func suspendSession(id: UUID, ending: Bool, draftRevision: Int, draftText: String) async throws
    func resumeSession(id: UUID) async throws
    func correctUserItem(sessionID: UUID, itemID: UUID, commandID: UUID, expectedRevision: Int, text: String) async throws -> MentorTimelineItem
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String) async throws -> MentorTimelineItem
}

enum MentorRequestEndReason: String { case failed, cancelled, timedOut = "timed_out" }

struct MentorSubmitTurn: Equatable {
    let commandID: UUID
    let sessionID: UUID
    let text: String?
    let intent: String
    let contextSnapshotJSON: String
    var retryOf: UUID? = nil
}

final class SQLiteMentorRepository: MentorRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    func createSession(_ session: MentorSession) async throws {
        guard session.draftRevision >= 0, session.semanticRevision == 0, session.requestEpoch == 0, session.recallCount == 0 else { throw PersistenceError.validationFailed("negative mentor draft revision") }
        try await database.dbQueue.write { db in try MentorSessionRow(session).insert(db) }
    }

    func session(id: UUID) async throws -> MentorSession? {
        try await database.dbQueue.read { db in try MentorSessionRow.fetchOne(db, key: id.uuidString)?.model() }
    }

    /// Keyset pagination over live records. Refresh from the first page after
    /// edits; records whose activity changes may move ahead of an existing cursor.
    func recentSessions(after cursor: MentorSessionCursor? = nil, limit: Int = 20) async throws -> MentorSessionPage {
        guard (1...20).contains(limit) else {
            throw PersistenceError.validationFailed("mentor page size must be between 1 and 20")
        }
        return try await database.dbQueue.read { db in
            var arguments: StatementArguments = []
            var boundary = ""
            if let cursor {
                boundary = "AND (s.activity_at, s.id) < (?, ?)"
                arguments += [cursor.storedActivityAt, cursor.id]
            }
            arguments += [limit + 1]
            // Never load complete conversation, draft or request JSON into a list.
            let rows = try Row.fetchAll(db, sql: """
                SELECT s.id, s.initial_entry, s.lifecycle, s.activity_at,
                    CASE WHEN length(trim(s.draft_text)) > 0
                         THEN substr(s.draft_text, 1, 80)
                         ELSE COALESCE((
                             SELECT substr(CASE WHEN json_valid(i.payload_json)
                                 THEN COALESCE(json_extract(i.payload_json, '$.text'), json_extract(i.payload_json, '$.title'), '')
                                 ELSE i.payload_json END, 1, 80)
                             FROM mentor_items i WHERE i.session_id = s.id AND i.kind IN ('user', 'lesson')
                             ORDER BY i.sequence LIMIT 1
                         ), '') END AS preview
                FROM mentor_sessions s
                WHERE (length(trim(s.draft_text)) > 0 OR EXISTS (
                    SELECT 1 FROM mentor_items i WHERE i.session_id = s.id
                )) \(boundary)
                ORDER BY s.activity_at DESC, s.id DESC LIMIT ?
                """, arguments: arguments)
            let visible = Array(rows.prefix(limit))
            let summaries = try visible.map { row -> MentorSessionSummary in
                let rawID: String = row["id"]
                let rawLifecycle: String = row["lifecycle"]
                let timestamp: String = row["activity_at"]
                guard let id = UUID(uuidString: rawID),
                      let lifecycle = MentorSessionLifecycle(rawValue: rawLifecycle),
                      let date = ISO8601DateFormatter().date(from: timestamp) else {
                    throw PersistenceError.invalidStoredValue("mentor session summary")
                }
                return MentorSessionSummary(id: id, initialEntry: row["initial_entry"], lifecycle: lifecycle, activityAt: date, preview: row["preview"])
            }
            let next = rows.count > limit ? visible.last.map {
                MentorSessionCursor(storedActivityAt: $0["activity_at"], id: $0["id"])
            } : nil
            return MentorSessionPage(sessions: summaries, nextCursor: next)
        }
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

    func acknowledgePresentation(sessionID: UUID, itemID: UUID, at date: Date, timeZone: TimeZone) async throws {
        guard date.timeIntervalSince1970.isFinite else { throw PersistenceError.validationFailed("invalid presentation date") }
        try await database.dbQueue.write { db in
            guard let item = try MentorItemRow.fetchOne(db, key: itemID.uuidString),
                  item.sessionID == sessionID.uuidString, ["assistant", "lesson"].contains(item.kind),
                  try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("invalid presentation owner or kind")
            }
            let row = try Row.fetchOne(db, sql: "SELECT presented_at, requires_material FROM mentor_items WHERE id = ?", arguments: [item.id])!
            let presented: String? = row["presented_at"]
            guard presented == nil else { return }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            try db.execute(sql: "UPDATE mentor_items SET presented_at = ?, presentation_day = ?, presentation_time_zone = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: date), formatter.string(from: date), timeZone.identifier, item.id])
            let consumesMaterial: Bool = row["requires_material"]
            if consumesMaterial {
                try db.execute(sql: "UPDATE mentor_sessions SET recall_count = recall_count + 1 WHERE id = ?", arguments: [sessionID.uuidString])
            }
        }
    }

    /// Storage boundary only: caller must first validate the mentor response protocol
    /// and dynamic source/intent rules. Does not mark content as presented.
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String) async throws -> MentorTimelineItem {
        guard let data = payloadJSON.data(using: .utf8),
              let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
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
            let question = response["question"] as? String
            let consumesMaterial = question?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && (response["question_purpose"] as? String == "material" || response["material_status"] as? String == "missing")
            guard !consumesMaterial || session.recallCount < 2 else {
                throw PersistenceError.validationFailed("mentor material question budget exhausted")
            }
            try MentorItemRow(item).insert(db)
            try db.execute(sql: "UPDATE mentor_items SET requires_material = ? WHERE id = ?", arguments: [consumesMaterial, item.id.uuidString])
            try db.execute(sql: "INSERT INTO mentor_request_results (request_id, session_id, item_id) VALUES (?, ?, ?)", arguments: [request.id, session.id, item.id.uuidString])
            try db.execute(sql: "UPDATE mentor_requests SET state = 'committed' WHERE id = ?", arguments: [request.id])
            try db.execute(sql: "UPDATE mentor_sessions SET activity_at = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: .now), session.id])
            return item
        }
    }

    /// Call once at startup before allowing new transport work, never on ordinary
    /// foreground entry while this process still owns a live request.
    func recoverInterruptedRequests() async throws -> Int {
        try await database.dbQueue.write { db in
            let owners = try String.fetchAll(db, sql: "SELECT DISTINCT session_id FROM mentor_requests WHERE state IN ('prepared', 'in_flight', 'response_received')")
            try db.execute(sql: "UPDATE mentor_requests SET state = 'interrupted' WHERE state IN ('prepared', 'in_flight', 'response_received')")
            let count = db.changesCount
            for owner in owners {
                try db.execute(sql: "UPDATE mentor_sessions SET request_epoch = request_epoch + 1, lifecycle = CASE WHEN lifecycle = 'active' THEN 'paused' ELSE lifecycle END WHERE id = ?", arguments: [owner])
            }
            return count
        }
    }

    func finishRequest(sessionID: UUID, requestID: UUID, reason: MentorRequestEndReason) async throws {
        try await database.dbQueue.write { db in
            guard let request = try MentorRequestRow.fetchOne(db, key: requestID.uuidString), request.sessionID == sessionID.uuidString else {
                throw PersistenceError.validationFailed("mentor request owner missing")
            }
            if request.state == reason.rawValue { return }
            guard ["prepared", "in_flight", "response_received"].contains(request.state) else {
                throw PersistenceError.validationFailed("mentor request already terminal")
            }
            try db.execute(sql: "UPDATE mentor_requests SET state = ? WHERE id = ?", arguments: [reason.rawValue, request.id])
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
                      existing.retryOf == command.retryOf?.uuidString,
                      let requestID = UUID(uuidString: existing.id) else {
                    throw PersistenceError.validationFailed("mentor command reused with different content")
                }
                return requestID
            }
            let unacknowledged = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_request_results r JOIN mentor_items i ON i.id = r.item_id WHERE r.session_id = ? AND i.presented_at IS NULL", arguments: [session.id]) ?? 0
            guard unacknowledged == 0 else { throw PersistenceError.validationFailed("mentor presentation must be acknowledged before continuing") }
            let pending = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_requests WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [command.sessionID.uuidString]) ?? 0
            guard pending == 0 else { throw PersistenceError.validationFailed("mentor request already pending") }
            var retryItemID: String?
            if let retryOf = command.retryOf {
                guard let previous = try MentorRequestRow.fetchOne(db, key: retryOf.uuidString),
                      previous.sessionID == session.id,
                      ["failed", "cancelled", "timed_out", "interrupted"].contains(previous.state),
                      previous.expectedRevision == session.semanticRevision,
                      previous.intent == command.intent,
                      previous.contextSnapshotJSON == command.contextSnapshotJSON else {
                    throw PersistenceError.validationFailed("retry source no longer valid")
                }
                let original = try previous.userItemID.flatMap { try MentorItemRow.fetchOne(db, key: $0) }
                guard original?.payloadJSON == payload,
                      original == nil || (original?.sessionID == session.id && original?.kind == "user") else {
                    throw PersistenceError.validationFailed("retry must preserve original user input")
                }
                retryItemID = previous.userItemID
            }
            let next = (try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sequence), 0) + 1 FROM mentor_items WHERE session_id = ?", arguments: [command.sessionID.uuidString])) ?? 1
            var itemID: String? = retryItemID
            if let payload, command.retryOf == nil {
                guard command.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw PersistenceError.validationFailed("empty mentor submission")
                }
                let item = MentorTimelineItem(id: UUID(), sessionID: command.sessionID, sequence: next, kind: .user, payloadJSON: payload)
                try MentorItemRow(item).insert(db)
                itemID = item.id.uuidString
            }
            let request = MentorRequestRow(id: UUID().uuidString, sessionID: command.sessionID.uuidString, commandID: command.commandID.uuidString, userItemID: itemID, intent: command.intent, contextSnapshotJSON: command.contextSnapshotJSON, state: "prepared", createdAt: ISO8601DateFormatter().string(from: .now), expectedRevision: session.semanticRevision, epoch: session.requestEpoch, retryOf: command.retryOf?.uuidString)
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
    var retryOf: String?
    enum CodingKeys: String, CodingKey { case id, sessionID = "session_id", commandID = "command_id", userItemID = "user_item_id", intent, contextSnapshotJSON = "context_snapshot_json", state, createdAt = "created_at", expectedRevision = "expected_revision", epoch, retryOf = "retry_of" }
}

private struct MentorSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, initialEntry, lifecycle, draftText: String
    var draftRevision: Int
    var activityAt: String
    var semanticRevision, requestEpoch, recallCount: Int
    enum CodingKeys: String, CodingKey { case id, initialEntry = "initial_entry", lifecycle, draftText = "draft_text", draftRevision = "draft_revision", activityAt = "activity_at", semanticRevision = "semantic_revision", requestEpoch = "request_epoch", recallCount = "recall_count" }
    init(_ value: MentorSession) { id = value.id.uuidString; initialEntry = value.initialEntry; lifecycle = value.lifecycle.rawValue; draftText = value.draftText; draftRevision = value.draftRevision; activityAt = ISO8601DateFormatter().string(from: value.activityAt); semanticRevision = value.semanticRevision; requestEpoch = value.requestEpoch; recallCount = value.recallCount }
    func model() throws -> MentorSession { guard let id = UUID(uuidString: id), let lifecycle = MentorSessionLifecycle(rawValue: lifecycle), let date = ISO8601DateFormatter().date(from: activityAt) else { throw PersistenceError.invalidStoredValue("mentor_sessions") }; return MentorSession(id: id, initialEntry: initialEntry, lifecycle: lifecycle, draftText: draftText, draftRevision: draftRevision, activityAt: date, semanticRevision: semanticRevision, recallCount: recallCount, requestEpoch: requestEpoch) }
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
