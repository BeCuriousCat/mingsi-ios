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
    /// Non-nil only for the one Mentor session that wraps a legacy nudge root.
    /// The old nudge rows remain the source of truth for their historical text.
    var originLegacyRootID: UUID? = nil
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
    let originLegacyRootID: UUID?

    init(id: UUID, initialEntry: String, lifecycle: MentorSessionLifecycle, activityAt: Date,
         preview: String, originLegacyRootID: UUID? = nil) {
        self.id = id
        self.initialEntry = initialEntry
        self.lifecycle = lifecycle
        self.activityAt = activityAt
        self.preview = preview
        self.originLegacyRootID = originLegacyRootID
    }

    var isLegacyNudge: Bool { originLegacyRootID != nil }
}

struct MentorSessionPage: Equatable {
    let sessions: [MentorSessionSummary]
    let nextCursor: MentorSessionCursor?
}

enum MentorUnderstandingState: String, Codable { case draft, confirmed }

enum MentorUnderstandingOrigin: String, Codable {
    case userNote = "user_note"
    case aiDraft = "ai_draft"
}

struct MentorUnderstanding: Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let groupID: UUID
    let revision: Int
    let previousRevisionID: UUID?
    let state: MentorUnderstandingState
    let text: String
    let origin: String
    let editRevision: Int
    let confirmedAt: Date?

    var isAIDraft: Bool { origin == MentorUnderstandingOrigin.aiDraft.rawValue }
}

enum MentorLessonFeedback: String { case notRelevant = "not_relevant", alreadyKnown = "already_known" }
enum MentorReadingSection: String, CaseIterable { case title, claim, example, boundary, observation }

/// Voluntary, session-level feedback about whether the exchange changed
/// something for the user. The optional note stays in the owned feedback table;
/// only the enum is copied to coarse usage events.
enum MentorBenefitFeedbackKind: String, Codable, CaseIterable, Hashable {
    case helped = "benefit_helped"
    case partlyHelped = "benefit_partly_helped"
    case notHelpful = "benefit_not_helpful"
    case unknown = "benefit_unknown"

    var title: String {
        switch self {
        case .helped: return "看清了一件事"
        case .partlyHelped: return "有一点帮助"
        case .notHelpful: return "暂时没帮助"
        case .unknown: return "还不确定"
        }
    }
}

struct MentorBenefitFeedback: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let kind: MentorBenefitFeedbackKind
    let note: String?
    let createdAt: Date
}

struct MentorSavedLesson: Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let lesson: MentorLesson
    let readingSection: MentorReadingSection
    let readingRevision: Int
    let readingOffset: Double
    let readingLayoutKey: String?

    init(id: UUID, sessionID: UUID, lesson: MentorLesson, readingSection: MentorReadingSection,
         readingRevision: Int, readingOffset: Double = 0, readingLayoutKey: String? = nil) {
        self.id = id
        self.sessionID = sessionID
        self.lesson = lesson
        self.readingSection = readingSection
        self.readingRevision = readingRevision
        self.readingOffset = readingOffset
        self.readingLayoutKey = readingLayoutKey
    }
}

enum MentorSourceOwnerKind: String, Codable { case request, item, understanding }
enum MentorSourceAvailability: String, Codable { case available, unavailable, deleted }

struct MentorSourceLink: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let ownerKind: MentorSourceOwnerKind
    let ownerID: UUID
    let sourceKind: String
    let sourceID: String
    let sourceVersion: String?
    let contentHash: String?
    let availability: MentorSourceAvailability
}

struct MentorRetryableRequest: Equatable {
    let id: UUID
    let text: String?
    let intent: String
    let contextSnapshotJSON: String
}

/// Coarse, local-only usage facts. These events deliberately carry no user
/// text; private benefit descriptions remain in the session feedback tables.
enum MentorUsageEventKind: String, Codable, CaseIterable {
    case entryStarted = "entry_started"
    case contentPresented = "content_presented"
    case requestFinished = "request_finished"
    case sessionLeft = "session_left"
    case understandingConfirmed = "understanding_confirmed"
    case benefitFeedback = "benefit_feedback"
}

struct MentorUsageEvent: Codable, Equatable, Identifiable {
    static let entries: Set<String> = [
        "listen", "discuss", "recall", "capture", "continue", "history",
        "legacy-nudge", "legacy-nudge-selection", "unknown"
    ]
    let id: UUID
    let attemptID: UUID
    let sessionID: UUID?
    let kind: MentorUsageEventKind
    let occurredAt: Date
    let attributes: [String: String]

    init(id: UUID = UUID(), attemptID: UUID, sessionID: UUID? = nil,
         kind: MentorUsageEventKind, occurredAt: Date, attributes: [String: String] = [:]) {
        self.id = id
        self.attemptID = attemptID
        self.sessionID = sessionID
        self.kind = kind
        self.occurredAt = occurredAt
        self.attributes = attributes
    }
}

protocol MentorRepository {
    func recordUsageEvent(_ event: MentorUsageEvent) async throws
    func attachUsageEvent(_ eventID: UUID, to sessionID: UUID) async throws
    func selectNextLesson(sessionID: UUID, itemID: UUID, expectedEpoch: Int, catalog: MentorLessonCatalog, at date: Date, timeZone: TimeZone) async throws -> MentorSavedLesson?
    func savedLesson(sessionID: UUID, itemID: UUID) async throws -> MentorSavedLesson?
    func listeningResume(at date: Date, timeZone: TimeZone) async throws -> MentorSavedLesson?
    func saveReadingPosition(sessionID: UUID, itemID: UUID, revision: Int, section: MentorReadingSection,
                             offset: Double, layoutKey: String?) async throws
    func recordLessonFeedback(sessionID: UUID, itemID: UUID, commandID: UUID, kind: MentorLessonFeedback, at date: Date) async throws
    func recordBenefitFeedback(sessionID: UUID, commandID: UUID, kind: MentorBenefitFeedbackKind,
                               note: String?, at date: Date) async throws -> MentorBenefitFeedback
    func benefitFeedback(sessionID: UUID) async throws -> MentorBenefitFeedback?
    func resetKnownLessonFeedback(commandID: UUID, at date: Date) async throws
    func beginUserUnderstanding(sessionID: UUID, draftID: UUID, previousRevisionID: UUID?) async throws -> MentorUnderstanding
    func beginAIUnderstanding(sessionID: UUID, draftID: UUID, text: String, sourceRefs: [MentorSourceReference]) async throws -> MentorUnderstanding
    func saveUnderstandingDraft(sessionID: UUID, draftID: UUID, editRevision: Int, text: String) async throws -> MentorUnderstanding
    func confirmUnderstanding(sessionID: UUID, draftID: UUID, expectedEditRevision: Int) async throws -> MentorUnderstanding
    func understandings(sessionID: UUID) async throws -> [MentorUnderstanding]
    func deleteUnderstandingGroup(sessionID: UUID, groupID: UUID) async throws
    func saveSourceLink(_ link: MentorSourceLink) async throws
    func sourceLinks(sessionID: UUID, ownerID: UUID) async throws -> [MentorSourceLink]
    func sourceLinks(sessionID: UUID) async throws -> [MentorSourceLink]
    func beginCaptureSession(captureID: UUID, sessionID: UUID, at date: Date) async throws -> MentorSession
    func createSession(_ session: MentorSession) async throws
    func session(id: UUID) async throws -> MentorSession?
    @discardableResult
    func acknowledgePresentation(sessionID: UUID, itemID: UUID, at date: Date, timeZone: TimeZone) async throws -> Bool
    func recentSessions(after cursor: MentorSessionCursor?, limit: Int) async throws -> MentorSessionPage
    func latestUnfinishedSession() async throws -> MentorSessionSummary?
    func saveDraft(sessionID: UUID, revision: Int, text: String) async throws
    func appendItem(_ item: MentorTimelineItem) async throws
    func items(sessionID: UUID) async throws -> [MentorTimelineItem]
    func methodSnapshots(sessionID: UUID) async throws -> [UUID: CoachMethodSnapshot]
    func deleteSession(id: UUID) async throws
    func retryableRequest(sessionID: UUID) async throws -> MentorRetryableRequest?
    func submitTurn(_ command: MentorSubmitTurn) async throws -> UUID
    func prepareRequestContext(token: LLMRequest.MentorAuditToken, json: String) async throws
    func recoverInterruptedRequests() async throws -> Int
    /// Invalidates requests owned by the current process when model configuration changes.
    /// The session remains open, but its epoch advances so a late response cannot commit.
    func interruptPendingRequests(sessionID: UUID) async throws -> Int
    func finishRequest(sessionID: UUID, requestID: UUID, reason: MentorRequestEndReason) async throws
    /// Reads only owned terminal metadata; never returns private request context.
    func requestOutcome(sessionID: UUID, requestID: UUID) async throws -> MentorRequestOutcome?
    func completeUnderstandingRequest(sessionID: UUID, requestID: UUID) async throws
    func suspendSession(id: UUID, ending: Bool, draftRevision: Int, draftText: String) async throws
    func resumeSession(id: UUID) async throws
    func continueRecall(sessionID: UUID, commandID: UUID, expectedEpoch: Int) async throws
    func correctUserItem(sessionID: UUID, itemID: UUID, commandID: UUID, expectedRevision: Int, text: String) async throws -> MentorTimelineItem
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String,
                        consumingDraft: MentorConsumedDraft?) async throws -> MentorTimelineItem
}

extension MentorRepository {
    func methodSnapshots(sessionID: UUID) async throws -> [UUID: CoachMethodSnapshot] { [:] }
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String) async throws -> MentorTimelineItem {
        try await commitResponse(sessionID: sessionID, requestID: requestID, payloadJSON: payloadJSON, consumingDraft: nil)
    }

    /// Existing section-only callers intentionally restore to the section start.
    func saveReadingPosition(sessionID: UUID, itemID: UUID, revision: Int, section: MentorReadingSection) async throws {
        try await saveReadingPosition(sessionID: sessionID, itemID: itemID, revision: revision,
                                      section: section, offset: 0, layoutKey: nil)
    }
}

enum MentorRequestEndReason: String { case failed, cancelled, timedOut = "timed_out" }

/// An unchanged composer may be consumed only with its committed response.
/// The revision remains a watermark: delayed writes at that same revision
/// cannot restore different text; subsequent user edits advance it normally.
struct MentorConsumedDraft: Equatable, Sendable {
    let revision: Int
    let text: String
}

enum MentorRequestOutcome: String {
    case succeeded = "committed", failed, cancelled, interrupted, timedOut = "timed_out"
    var usageReason: String { self == .succeeded ? "succeeded" : rawValue }
}

struct MentorSubmitTurn: Equatable {
    let commandID: UUID
    let sessionID: UUID
    let text: String?
    let intent: String
    let contextSnapshotJSON: String
    var retryOf: UUID? = nil
    /// The coordinator uses this identity for preflight context, then the
    /// transaction creates that exact user source before any network call.
    var userItemID: UUID? = nil
}

final class SQLiteMentorRepository: MentorRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    /// One explicit selection borrows one immutable capture. Session, original
    /// text snapshot and provenance either all commit or all roll back.
    func beginCaptureSession(captureID: UUID, sessionID: UUID, at date: Date) async throws -> MentorSession {
        try await database.dbQueue.write { db in
            guard let capture = try Row.fetchOne(db, sql: "SELECT raw_text FROM capture_fragments WHERE id = ?", arguments: [captureID.uuidString]) else {
                throw PersistenceError.validationFailed("capture source missing")
            }
            let text: String = capture["raw_text"]
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PersistenceError.validationFailed("capture source empty")
            }
            if let existing = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) {
                let linked = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM mentor_source_links l JOIN mentor_items i ON i.id = l.owner_uuid AND i.session_id = l.session_id
                    WHERE l.session_id = ? AND l.owner_kind = 'item' AND l.source_kind = 'capture' AND l.source_id = ? AND l.content_hash = ?
                    """, arguments: [sessionID.uuidString, captureID.uuidString, MentorSourceResolver.hash(text)]) ?? 0
                guard existing.initialEntry == "capture", linked == 1 else {
                    throw PersistenceError.validationFailed("capture session command conflict")
                }
                return try existing.model()
            }
            let session = MentorSession(id: sessionID, initialEntry: "capture", lifecycle: .draft,
                draftText: "", draftRevision: 0, activityAt: date)
            try MentorSessionRow(session).insert(db)
            let item = MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: 1, kind: .user,
                payloadJSON: String(decoding: try JSONEncoder().encode(["text": text]), as: UTF8.self))
            try MentorItemRow(item).insert(db)
            try db.execute(sql: """
                INSERT INTO mentor_source_links
                (id, session_id, owner_id, owner_kind, owner_uuid, source_kind, source_id, content_hash, availability)
                VALUES (?, ?, ?, 'item', ?, 'capture', ?, ?, 'available')
                """, arguments: [UUID().uuidString, sessionID.uuidString, item.id.uuidString, item.id.uuidString,
                    captureID.uuidString, MentorSourceResolver.hash(text)])
            return session
        }
    }

    func recordUsageEvent(_ event: MentorUsageEvent) async throws {
        guard event.occurredAt.timeIntervalSince1970.isFinite else {
            throw PersistenceError.validationFailed("invalid mentor usage event")
        }
        let attributesJSON = try Self.usageAttributesJSON(event.attributes)
        try await database.dbQueue.write { db in
            if let existing = try Row.fetchOne(db, sql: "SELECT attempt_id, session_id, event_kind, occurred_at, attributes_json FROM mentor_usage_events WHERE event_id = ?", arguments: [event.id.uuidString]) {
                let existingSession: String? = existing["session_id"]
                let incomingSession = event.sessionID?.uuidString
                guard (existing["attempt_id"] as String) == event.attemptID.uuidString,
                      existingSession == incomingSession,
                      (existing["event_kind"] as String) == event.kind.rawValue,
                      (existing["occurred_at"] as String) == ISO8601DateFormatter().string(from: event.occurredAt),
                      (existing["attributes_json"] as String) == attributesJSON else {
                    throw PersistenceError.validationFailed("mentor usage event conflict")
                }
                return
            }
            try db.execute(sql: """
                INSERT INTO mentor_usage_events
                (event_id, attempt_id, session_id, event_kind, occurred_at, attributes_json)
                VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [event.id.uuidString, event.attemptID.uuidString, event.sessionID?.uuidString,
                    event.kind.rawValue, ISO8601DateFormatter().string(from: event.occurredAt), attributesJSON])
        }
    }

    func attachUsageEvent(_ eventID: UUID, to sessionID: UUID) async throws {
        try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("usage event session missing")
            }
            guard let event = try Row.fetchOne(db, sql: "SELECT session_id FROM mentor_usage_events WHERE event_id = ?", arguments: [eventID.uuidString]) else {
                throw PersistenceError.validationFailed("usage event missing")
            }
            let current: String? = event["session_id"]
            guard current == nil || current == sessionID.uuidString else {
                throw PersistenceError.validationFailed("usage event session conflict")
            }
            try db.execute(sql: "UPDATE mentor_usage_events SET session_id = ? WHERE event_id = ?",
                           arguments: [sessionID.uuidString, eventID.uuidString])
        }
    }

    private static let usageAttributeKeys: Set<String> = [
        "entry", "switched_entry", "has_material", "content_version",
        "schema_version", "duration_ms", "timing_scope", "first_content",
        "content_kind", "presentation", "exit_phase", "exit_action", "reason", "feedback"
    ]

    private static func validUsageValue(_ value: String, for key: String) -> Bool {
        switch key {
        case "entry", "switched_entry": return MentorUsageEvent.entries.contains(value)
        case "has_material", "first_content": return ["true", "false"].contains(value)
        case "schema_version": return value == "1.0.0"
        case "content_version":
            if ["mentor-m1", "unavailable", "model-only"].contains(value) { return true }
            return value.count <= 32 && value.range(of: #"\A[0-9]+\.[0-9]+(?:\.[0-9]+)?\z"#, options: .regularExpression) != nil
        case "duration_ms":
            return !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) } && UInt64(value) != nil
        case "timing_scope": return ["entry_to_content", "request", "attempt"].contains(value)
        case "content_kind": return ["lesson", "response"].contains(value)
        case "presentation": return ["new", "revisit"].contains(value)
        case "exit_phase":
            return ["entry", "history", "understanding", "idle", "editing", "reading", "selecting_lesson",
                    "lesson_exhausted", "submitting", "showing_response", "paused", "ended", "failed"].contains(value)
        case "exit_action": return ["finish", "pause", "switch"].contains(value)
        case "reason":
            return ["user", "switch", "entry_failed", "entry_cancelled", "succeeded", "failed",
                    "cancelled", "interrupted", "timed_out"].contains(value)
        case "feedback":
            return ["unknown", "benefit_unknown", "benefit_helped", "benefit_partly_helped", "benefit_not_helpful",
                    "not_relevant", "already_known"].contains(value)
        default: return false
        }
    }

    private static func usageAttributesJSON(_ attributes: [String: String]) throws -> String {
        guard attributes.keys.allSatisfy({ usageAttributeKeys.contains($0) }),
              attributes.allSatisfy({ validUsageValue($0.value, for: $0.key) }) else {
            throw PersistenceError.validationFailed("invalid mentor usage attributes")
        }
        let data = try JSONSerialization.data(withJSONObject: attributes, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    func saveSourceLink(_ link: MentorSourceLink) async throws {
        guard !link.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("empty mentor source")
        }
        try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: link.sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("source link session missing")
            }
            let owned: Bool
            switch link.ownerKind {
            case .request:
                owned = try MentorRequestRow.fetchOne(db, key: link.ownerID.uuidString).map { $0.sessionID == link.sessionID.uuidString } ?? false
            case .item:
                owned = try MentorItemRow.fetchOne(db, key: link.ownerID.uuidString).map { $0.sessionID == link.sessionID.uuidString } ?? false
            case .understanding:
                owned = try MentorUnderstandingRow.fetchOne(db, key: link.ownerID.uuidString).map { $0.sessionID == link.sessionID.uuidString } ?? false
            }
            guard owned else { throw PersistenceError.validationFailed("source link owner is not owned") }
            try db.execute(sql: """
                INSERT INTO mentor_source_links
                (id, session_id, owner_id, source_kind, source_id, owner_kind, owner_uuid, source_version, content_hash, availability)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [link.id.uuidString, link.sessionID.uuidString, link.ownerID.uuidString,
                    link.sourceKind, link.sourceID, link.ownerKind.rawValue, link.ownerID.uuidString,
                    link.sourceVersion, link.contentHash, link.availability.rawValue])
        }
    }

    func sourceLinks(sessionID: UUID, ownerID: UUID) async throws -> [MentorSourceLink] {
        try await database.dbQueue.read { db in
            try MentorSourceLinkRow.fetchAll(db, sql: "SELECT * FROM mentor_source_links WHERE session_id = ? AND owner_uuid = ? ORDER BY id", arguments: [sessionID.uuidString, ownerID.uuidString]).map { try $0.model() }
        }
    }

    func sourceLinks(sessionID: UUID) async throws -> [MentorSourceLink] {
        try await database.dbQueue.read { db in
            try MentorSourceLinkRow.fetchAll(db, sql: "SELECT * FROM mentor_source_links WHERE session_id = ? AND owner_kind IN ('request', 'item', 'understanding') AND owner_uuid IS NOT NULL ORDER BY id", arguments: [sessionID.uuidString]).map { try $0.model() }
        }
    }

    /// Stable draft identity makes repeated UI commands harmless, including after confirmation.
    /// This entry point is exclusively for user-authored notes, never model-generated text.
    func beginUserUnderstanding(sessionID: UUID, draftID: UUID, previousRevisionID: UUID? = nil) async throws -> MentorUnderstanding {
        try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("mentor session missing")
            }
            if let existing = try MentorUnderstandingRow.fetchOne(db, key: draftID.uuidString) {
                guard existing.sessionID == sessionID.uuidString,
                      existing.previousRevisionID == previousRevisionID?.uuidString,
                      existing.origin == MentorUnderstandingOrigin.userNote.rawValue else {
                    throw PersistenceError.validationFailed("understanding command conflict")
                }
                return try existing.model()
            }
            var groupID = draftID.uuidString
            var revision = 1
            var text = ""
            if let previousRevisionID {
                guard let previous = try MentorUnderstandingRow.fetchOne(db, key: previousRevisionID.uuidString),
                      previous.sessionID == sessionID.uuidString, previous.state == "confirmed",
                      [MentorUnderstandingOrigin.userNote.rawValue, MentorUnderstandingOrigin.aiDraft.rawValue].contains(previous.origin),
                      try Int.fetchOne(db, sql: "SELECT MAX(revision) FROM mentor_understandings WHERE group_id = ?", arguments: [previous.groupID]) == previous.revision else {
                    throw PersistenceError.validationFailed("understanding requires latest confirmed user note")
                }
                groupID = previous.groupID
                revision = previous.revision + 1
                text = previous.text
            }
            let row = MentorUnderstandingRow(id: draftID.uuidString, sessionID: sessionID.uuidString,
                groupID: groupID, revision: revision, state: "draft", text: text,
                previousRevisionID: previousRevisionID?.uuidString, origin: MentorUnderstandingOrigin.userNote.rawValue, confirmedAt: nil, editRevision: 0)
            try row.insert(db)
            return try row.model()
        }
    }

    /// Creates a model-generated understanding as an unconfirmed draft and
    /// stores its user-source edges in the same transaction.
    func beginAIUnderstanding(sessionID: UUID, draftID: UUID, text: String, sourceRefs: [MentorSourceReference]) async throws -> MentorUnderstanding {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !sourceRefs.isEmpty else { throw PersistenceError.validationFailed("empty AI understanding") }
        try sourceRefs.forEach { reference in
            guard reference.value.hasPrefix("item:"), UUID(uuidString: String(reference.value.dropFirst("item:".count))) != nil else {
                throw PersistenceError.validationFailed("AI understanding source must be a user item")
            }
        }
        return try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("mentor session missing")
            }
            if let existing = try MentorUnderstandingRow.fetchOne(db, key: draftID.uuidString) {
                guard existing.sessionID == sessionID.uuidString,
                      existing.origin == MentorUnderstandingOrigin.aiDraft.rawValue,
                      existing.text == text else {
                    throw PersistenceError.validationFailed("AI understanding command conflict")
                }
                return try existing.model()
            }
            let row = MentorUnderstandingRow(id: draftID.uuidString, sessionID: sessionID.uuidString,
                groupID: draftID.uuidString, revision: 1, state: MentorUnderstandingState.draft.rawValue,
                text: text, previousRevisionID: nil, origin: MentorUnderstandingOrigin.aiDraft.rawValue,
                confirmedAt: nil, editRevision: 1)
            try row.insert(db)
            for reference in sourceRefs {
                let sourceID = String(reference.value.dropFirst("item:".count))
                guard let item = try MentorItemRow.fetchOne(db, key: sourceID), item.sessionID == sessionID.uuidString,
                      item.kind == MentorItemKind.user.rawValue else {
                    throw PersistenceError.validationFailed("AI understanding source is not an owned user item")
                }
                try db.execute(sql: """
                    INSERT INTO mentor_source_links
                    (id, session_id, owner_id, source_kind, source_id, owner_kind, owner_uuid, source_version, content_hash, availability)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [UUID().uuidString, sessionID.uuidString, draftID.uuidString, "item", sourceID,
                        MentorSourceOwnerKind.understanding.rawValue, draftID.uuidString, nil, nil,
                        MentorSourceAvailability.available.rawValue])
            }
            try db.execute(sql: "UPDATE mentor_sessions SET activity_at = ? WHERE id = ?",
                           arguments: [ISO8601DateFormatter().string(from: .now), sessionID.uuidString])
            return try row.model()
        }
    }

    func saveUnderstandingDraft(sessionID: UUID, draftID: UUID, editRevision: Int, text: String) async throws -> MentorUnderstanding {
        try await database.dbQueue.write { db in
            guard var row = try MentorUnderstandingRow.fetchOne(db, key: draftID.uuidString),
                  row.sessionID == sessionID.uuidString, row.state == "draft",
                  [MentorUnderstandingOrigin.userNote.rawValue, MentorUnderstandingOrigin.aiDraft.rawValue].contains(row.origin),
                  editRevision >= 0, editRevision >= row.editRevision else {
                throw PersistenceError.validationFailed("stale or closed understanding draft")
            }
            if editRevision == row.editRevision {
                guard text == row.text else { throw PersistenceError.validationFailed("understanding edit conflict") }
                return try row.model()
            }
            row.text = text
            row.editRevision = editRevision
            try row.update(db)
            try db.execute(sql: "UPDATE mentor_sessions SET activity_at = ? WHERE id = ?",
                           arguments: [ISO8601DateFormatter().string(from: .now), sessionID.uuidString])
            return try row.model()
        }
    }

    /// Confirmation is local and explicit. Frozen revisions can only be changed by copying a new draft.
    func confirmUnderstanding(sessionID: UUID, draftID: UUID, expectedEditRevision: Int) async throws -> MentorUnderstanding {
        try await database.dbQueue.write { db in
            guard var row = try MentorUnderstandingRow.fetchOne(db, key: draftID.uuidString),
                  row.sessionID == sessionID.uuidString,
                  [MentorUnderstandingOrigin.userNote.rawValue, MentorUnderstandingOrigin.aiDraft.rawValue].contains(row.origin),
                  row.editRevision == expectedEditRevision,
                  !row.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PersistenceError.validationFailed("understanding confirmation conflict")
            }
            if row.state == "confirmed" { return try row.model() }
            guard row.state == "draft" else { throw PersistenceError.validationFailed("invalid understanding state") }
            row.state = "confirmed"
            row.confirmedAt = ISO8601DateFormatter().string(from: .now)
            try row.update(db)
            try db.execute(sql: "UPDATE mentor_sessions SET activity_at = ? WHERE id = ?",
                           arguments: [row.confirmedAt, sessionID.uuidString])
            return try row.model()
        }
    }

    func understandings(sessionID: UUID) async throws -> [MentorUnderstanding] {
        try await database.dbQueue.read { db in
            try MentorUnderstandingRow.filter(Column("session_id") == sessionID.uuidString)
                .order(Column("group_id"), Column("revision")).fetchAll(db).map { try $0.model() }
        }
    }

    /// Delete a version group and model-owned copies derived from its references.
    /// Original user items and independently authored understanding groups are retained.
    func deleteUnderstandingGroup(sessionID: UUID, groupID: UUID) async throws {
        try await database.dbQueue.write { db in
            let notes = try MentorUnderstandingRow.fetchAll(db)
            let group = notes.filter { $0.groupID == groupID.uuidString }
            guard !group.isEmpty, group.allSatisfy({ $0.sessionID == sessionID.uuidString }) else {
                throw PersistenceError.validationFailed("understanding group is not owned")
            }
            let requests = try MentorRequestRow.fetchAll(db)
            let items = try MentorItemRow.fetchAll(db)
            let links = try MentorSourceLinkRow.fetchAll(db, sql: "SELECT * FROM mentor_source_links")
            let results = try Row.fetchAll(db, sql: "SELECT request_id, item_id FROM mentor_request_results")
            let audits = try PromptRunRow.fetchAll(db)
            var auditIDs = Set<String>()
            let noteIDs = Set(group.map(\.id))
            var requestIDs = Set<String>()
            var itemIDs = Set<String>()
            var affectedSessions: Set<String> = [sessionID.uuidString]

            func references(_ json: String?) -> Set<String> {
                guard let json, let data = json.data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data) else { return [] }
                if let array = value as? [String] { return Set(array.map { $0.lowercased() }) }
                guard let object = value as? [String: Any] else { return [] }
                let sources = (object["sources"] as? [[String: Any]] ?? []).compactMap { $0["ref"] as? String }
                let direct = object["source_refs"] as? [String] ?? []
                return Set((sources + direct).map { $0.lowercased() })
            }
            // Follow actual source edges and retry/result ownership to a fixed point.
            while true {
                let count = noteIDs.count + requestIDs.count + itemIDs.count + auditIDs.count
                let removedRefs = Set(noteIDs.map { "understanding:" + $0.lowercased() } +
                                      itemIDs.map { "item:" + $0.lowercased() })
                for request in requests where !requestIDs.contains(request.id) {
                    if !references(request.contextSnapshotJSON).isDisjoint(with: removedRefs) ||
                       !references(request.registrationContextJSON).isDisjoint(with: removedRefs) ||
                       request.retryOf.map({ requestIDs.contains($0) }) == true {
                        requestIDs.insert(request.id)
                        affectedSessions.insert(request.sessionID)
                    }
                }
                for result in results {
                    let requestID: String = result["request_id"]
                    let itemID: String = result["item_id"]
                    if requestIDs.contains(requestID) { itemIDs.insert(itemID) }
                    if itemIDs.contains(itemID) { requestIDs.insert(requestID) }
                }
                for audit in audits {
                    let refs = references(audit.requestSummary).union(references(audit.responseJson))
                        .union(references(audit.sourceRecordIdsJson)).union(references(audit.contextRecordIdsJson))
                    if !refs.isDisjoint(with: removedRefs) {
                        auditIDs.insert(audit.id)
                        if let requestID = audit.mentorRequestId { requestIDs.insert(requestID) }
                        if let owner = audit.mentorSessionId { affectedSessions.insert(owner) }
                    }
                }
                for item in items where item.kind == "assistant" &&
                    !references(item.payloadJSON).isDisjoint(with: removedRefs) {
                    itemIDs.insert(item.id)
                    affectedSessions.insert(item.sessionID)
                }
                for link in links {
                    let ref = (link.sourceKind + ":" + link.sourceID).lowercased()
                    guard removedRefs.contains(ref), let owner = link.ownerUUID else { continue }
                    affectedSessions.insert(link.sessionID)
                    switch link.ownerKind {
                    case "request": requestIDs.insert(owner)
                    case "item":
                        if items.contains(where: { $0.id == owner && $0.kind == "assistant" }) { itemIDs.insert(owner) }
                    case "understanding":
                        // Other groups may contain user writing, including legacy rows
                        // of unknown authorship. Retain them with unavailable sources.
                        break
                    default: break
                    }
                }
                if count == noteIDs.count + requestIDs.count + itemIDs.count + auditIDs.count { break }
            }
            // Request results may identify a derived item even if its payload has no refs.
            affectedSessions.formUnion(items.filter { itemIDs.contains($0.id) }.map(\.sessionID))
            affectedSessions.formUnion(notes.filter { noteIDs.contains($0.id) }.map(\.sessionID))
            affectedSessions.formUnion(requests.filter { requestIDs.contains($0.id) }.map(\.sessionID))
            func placeholders(_ ids: Set<String>) -> String { Array(repeating: "?", count: ids.count).joined(separator: ",") }
            func delete(_ table: String, column: String, ids: Set<String>) throws {
                guard !ids.isEmpty else { return }
                try db.execute(sql: "DELETE FROM \(table) WHERE \(column) IN (\(placeholders(ids)))",
                               arguments: StatementArguments(Array(ids)))
            }
            let removedRefs = Set(noteIDs.map { "understanding:" + $0.lowercased() } + itemIDs.map { "item:" + $0.lowercased() })
            for link in links where removedRefs.contains((link.sourceKind + ":" + link.sourceID).lowercased()) {
                try db.execute(sql: "UPDATE mentor_source_links SET availability = 'deleted' WHERE id = ?", arguments: [link.id])
            }
            for (kind, ids) in [("understanding", noteIDs), ("request", requestIDs), ("item", itemIDs)] where !ids.isEmpty {
                try db.execute(sql: "DELETE FROM mentor_source_links WHERE owner_kind = ? AND owner_uuid IN (\(placeholders(ids)))",
                               arguments: StatementArguments([kind] + Array(ids)))
            }
            try delete("prompt_runs", column: "id", ids: auditIDs)
            try delete("prompt_runs", column: "mentor_request_id", ids: requestIDs)
            try delete("mentor_requests", column: "id", ids: requestIDs)
            try delete("mentor_items", column: "id", ids: itemIDs)
            try delete("mentor_understandings", column: "id", ids: noteIDs)
            // Invalidate in-flight audits/commits based on the pre-deletion graph.
            try db.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE session_id IN (\(placeholders(affectedSessions))) AND state IN ('prepared','in_flight','response_received')",
                           arguments: StatementArguments(Array(affectedSessions)))
            try db.execute(sql: "UPDATE mentor_sessions SET request_epoch = request_epoch + 1, semantic_revision = semantic_revision + 1 WHERE id IN (\(placeholders(affectedSessions)))",
                           arguments: StatementArguments(Array(affectedSessions)))
        }
    }

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
        try await sessionPage(after: cursor, limit: limit, unfinishedOnly: false)
    }

    /// Independent of history pagination: ended sessions must not hide resumable work.
    func latestUnfinishedSession() async throws -> MentorSessionSummary? {
        try await sessionPage(after: nil, limit: 1, unfinishedOnly: true).sessions.first
    }

    private func sessionPage(after cursor: MentorSessionCursor?, limit: Int,
                             unfinishedOnly: Bool) async throws -> MentorSessionPage {
        guard (1...20).contains(limit) else {
            throw PersistenceError.validationFailed("mentor page size must be between 1 and 20")
        }
        return try await database.dbQueue.read { db in
            var arguments: StatementArguments = []
            var boundary = unfinishedOnly ? "AND s.lifecycle != 'ended'" : ""
            if let cursor {
                boundary += " AND (s.activity_at, s.id) < (?, ?)"
                arguments += [cursor.storedActivityAt, cursor.id]
            }
            arguments += [limit + 1]
            // Never load complete conversation, draft or request JSON into a list.
            let rows = try Row.fetchAll(db, sql: """
                SELECT s.id, s.initial_entry, s.lifecycle, s.activity_at,
                    s.origin_legacy_root_id,
                    CASE WHEN length(trim(s.draft_text)) > 0
                         THEN substr(s.draft_text, 1, 80)
                         ELSE COALESCE((
                             SELECT substr(CASE WHEN json_valid(i.payload_json)
                                 THEN COALESCE(json_extract(i.payload_json, '$.text'), json_extract(i.payload_json, '$.title'), '')
                                 ELSE i.payload_json END, 1, 80)
                             FROM mentor_items i WHERE i.session_id = s.id AND i.kind IN ('user', 'lesson')
                             ORDER BY i.sequence LIMIT 1
                         ), (
                             SELECT substr(u.text, 1, 80) FROM mentor_understandings u
                             WHERE u.session_id = s.id AND length(trim(u.text)) > 0
                             ORDER BY u.revision DESC, u.id DESC LIMIT 1
                         ), '') END AS preview
                FROM mentor_sessions s
                WHERE (length(trim(s.draft_text)) > 0 OR EXISTS (
                    SELECT 1 FROM mentor_items i WHERE i.session_id = s.id
                ) OR EXISTS (
                    SELECT 1 FROM mentor_understandings u WHERE u.session_id = s.id AND length(trim(u.text)) > 0
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
                let rawOrigin: String? = row["origin_legacy_root_id"]
                guard rawOrigin == nil || UUID(uuidString: rawOrigin!) != nil else {
                    throw PersistenceError.invalidStoredValue("mentor session summary origin")
                }
                return MentorSessionSummary(id: id, initialEntry: row["initial_entry"], lifecycle: lifecycle,
                    activityAt: date, preview: row["preview"], originLegacyRootID: rawOrigin.flatMap(UUID.init(uuidString:)))
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
        try await database.dbQueue.write { db in
            let legacyRootID = try String.fetchOne(
                db,
                sql: "SELECT origin_legacy_root_id FROM mentor_sessions WHERE id = ?",
                arguments: [id.uuidString]
            )
            // Prompt runs intentionally do not have a foreign key to the
            // Mentor graph. Remove only runs explicitly owned by this session
            // or one of its requests; unrelated model audits remain intact.
            if try db.tableExists("prompt_runs") {
                let columns = Set(try db.columns(in: "prompt_runs").map(\.name))
                if columns.contains("mentor_session_id"), columns.contains("mentor_request_id") {
                    try db.execute(sql: """
                        DELETE FROM prompt_runs
                        WHERE mentor_session_id = ?
                           OR mentor_request_id IN (
                               SELECT id FROM mentor_requests WHERE session_id = ?
                           )
                        """, arguments: [id.uuidString, id.uuidString])
                }
                if let legacyRootID, try db.tableExists("single_nudge_sessions") {
                    let legacyPromptIDs = try String.fetchAll(db, sql: """
                        SELECT prompt_run_id FROM single_nudge_sessions
                        WHERE (id = ? OR root_session_id = ?) AND prompt_run_id IS NOT NULL
                        UNION
                        SELECT review_prompt_run_id FROM single_nudge_sessions
                        WHERE (id = ? OR root_session_id = ?) AND review_prompt_run_id IS NOT NULL
                        """, arguments: [legacyRootID, legacyRootID, legacyRootID, legacyRootID])
                    if !legacyPromptIDs.isEmpty {
                        let placeholders = Array(repeating: "?", count: legacyPromptIDs.count).joined(separator: ",")
                        try db.execute(sql: "DELETE FROM prompt_runs WHERE id IN (\(placeholders))",
                                       arguments: StatementArguments(legacyPromptIDs))
                    }
                }
            }
            if let legacyRootID, try db.tableExists("single_nudge_sessions") {
                try db.execute(sql: "DELETE FROM single_nudge_sessions WHERE id = ? OR root_session_id = ?",
                               arguments: [legacyRootID, legacyRootID])
            }
            // All Mentor-owned child rows use session foreign keys with
            // ON DELETE CASCADE. Keeping the parent delete in this same
            // transaction makes a failure roll back the audit cleanup too.
            _ = try MentorSessionRow.deleteOne(db, key: id.uuidString)
        }
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
            guard ["draft", "active"].contains(session.lifecycle), session.semanticRevision == expectedRevision,
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

    /// Freeze the exact outgoing context before network execution. A second call
    /// may replay the same context but cannot replace an already frozen request.
    func prepareRequestContext(token: LLMRequest.MentorAuditToken, json: String) async throws {
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(json.utf8))
        guard context.sessionID == token.sessionID, context.requestEpoch == token.requestEpoch,
              context.semanticRevision == token.semanticRevision else {
            throw PersistenceError.validationFailed("mentor context ownership mismatch")
        }
        try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: token.sessionID.uuidString),
                  let request = try MentorRequestRow.fetchOne(db, key: token.requestID.uuidString),
                  request.sessionID == session.id, request.intent == context.intent,
                  request.epoch == token.requestEpoch, request.expectedRevision == token.semanticRevision,
                  session.requestEpoch == token.requestEpoch, session.semanticRevision == token.semanticRevision,
                  ["prepared", "in_flight"].contains(request.state),
                  request.contextSnapshotJSON == json || (request.state == "prepared" &&
                    (request.contextSnapshotJSON == "{}" || Self.isRetryContextRebase(request, context: context))) else {
                throw PersistenceError.validationFailed("mentor context is stale or already frozen")
            }
            try db.execute(sql: "UPDATE mentor_requests SET registration_context_json = COALESCE(registration_context_json, context_snapshot_json), context_snapshot_json = ?, state = 'in_flight' WHERE id = ?", arguments: [json, request.id])
        }
    }

    private static func isRetryContextRebase(_ request: MentorRequestRow, context: MentorContextPayload) -> Bool {
        guard request.retryOf != nil,
              var original = try? JSONDecoder().decode(MentorContextPayload.self, from: Data(request.contextSnapshotJSON.utf8)) else { return false }
        original.requestEpoch = request.epoch
        return original == context
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

    /// Only an explicit user choice may invoke this command, never a model action.
    func continueRecall(sessionID: UUID, commandID: UUID, expectedEpoch: Int) async throws {
        try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) else {
                throw PersistenceError.validationFailed("mentor session missing")
            }
            if let receipt = try Row.fetchOne(db, sql: "SELECT session_id, previous_epoch FROM mentor_recall_continuations WHERE command_id = ?", arguments: [commandID.uuidString]) {
                let owner: String = receipt["session_id"]
                let epoch: Int = receipt["previous_epoch"]
                guard owner == session.id, epoch == expectedEpoch else {
                    throw PersistenceError.validationFailed("conflicting recall continuation")
                }
                return
            }
            guard session.lifecycle == "active", session.requestEpoch == expectedEpoch,
                  session.recallCount >= 2 else {
                throw PersistenceError.validationFailed("recall continuation requires the current exhausted budget")
            }
            let unseen = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_request_results r JOIN mentor_items i ON i.id = r.item_id WHERE r.session_id = ? AND i.presented_at IS NULL", arguments: [session.id]) ?? 0
            guard unseen == 0 else { throw PersistenceError.validationFailed("acknowledge prior content before continuing recall") }
            try db.execute(sql: "INSERT INTO mentor_recall_continuations (command_id, session_id, previous_epoch, created_at) VALUES (?, ?, ?, ?)", arguments: [commandID.uuidString, session.id, expectedEpoch, ISO8601DateFormatter().string(from: .now)])
            try db.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [session.id])
            try db.execute(sql: "UPDATE mentor_sessions SET recall_count = 0, request_epoch = request_epoch + 1 WHERE id = ?", arguments: [session.id])
        }
    }

    @discardableResult
    func acknowledgePresentation(sessionID: UUID, itemID: UUID, at date: Date, timeZone: TimeZone) async throws -> Bool {
        guard date.timeIntervalSince1970.isFinite else { throw PersistenceError.validationFailed("invalid presentation date") }
        return try await database.dbQueue.write { db in
            guard let item = try MentorItemRow.fetchOne(db, key: itemID.uuidString),
                  item.sessionID == sessionID.uuidString, ["assistant", "lesson"].contains(item.kind),
                  try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("invalid presentation owner or kind")
            }
            let row = try Row.fetchOne(db, sql: "SELECT presented_at, requires_material FROM mentor_items WHERE id = ?", arguments: [item.id])!
            let presented: String? = row["presented_at"]
            guard presented == nil else { return false }
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
            return true
        }
    }

    /// Read the original method from each owned, committed request. Never
    /// rebuild historical guidance from the current mutable catalog.
    func methodSnapshots(sessionID: UUID) async throws -> [UUID: CoachMethodSnapshot] {
        try await database.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT r.item_id, q.context_snapshot_json
                FROM mentor_request_results r JOIN mentor_requests q
                ON q.id = r.request_id AND q.session_id = r.session_id
                WHERE r.session_id = ? AND q.state = 'committed'
                """, arguments: [sessionID.uuidString])
            var snapshots: [UUID: CoachMethodSnapshot] = [:]
            for row in rows {
                let raw: String = row["context_snapshot_json"]
                let itemID: String = row["item_id"]
                if let id = UUID(uuidString: itemID),
                   let payload = try? JSONDecoder().decode(MentorContextPayload.self, from: Data(raw.utf8)),
                   let method = payload.selectedMethod { snapshots[id] = method }
            }
            return snapshots
        }
    }

    /// Storage boundary only: caller validates protocol and source/intent rules.
    /// Does not mark content as presented.
    func commitResponse(sessionID: UUID, requestID: UUID, payloadJSON: String,
                        consumingDraft: MentorConsumedDraft? = nil) async throws -> MentorTimelineItem {
        guard let data = payloadJSON.data(using: .utf8),
              let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw PersistenceError.validationFailed("invalid mentor response JSON")
        }
        let question = response["question"] as? String
        let asksForMaterial = question?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (response["question_purpose"] as? String == "material" || response["material_status"] as? String == "missing")
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
            // The first empty review doorway starts recall; its presentation
            // leaves both follow-up material questions available.
            let isReviewOpening = session.initialEntry == "review" && request.intent == "review"
                && request.userItemID == nil && next == 1
            let consumesMaterial = asksForMaterial && !isReviewOpening
            let item = MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: next, kind: .assistant, payloadJSON: payloadJSON)
            guard !consumesMaterial || session.recallCount < 2 else {
                throw PersistenceError.validationFailed("mentor material question budget exhausted")
            }
            try MentorItemRow(item).insert(db)
            try db.execute(sql: "UPDATE mentor_items SET requires_material = ? WHERE id = ?", arguments: [consumesMaterial, item.id.uuidString])
            try db.execute(sql: "INSERT INTO mentor_request_results (request_id, session_id, item_id) VALUES (?, ?, ?)", arguments: [request.id, session.id, item.id.uuidString])
            try db.execute(sql: "UPDATE mentor_requests SET state = 'committed' WHERE id = ?", arguments: [request.id])
            if let draft = consumingDraft, draft.revision == session.draftRevision, draft.text == session.draftText,
               let userItemID = request.userItemID, let user = try MentorItemRow.fetchOne(db, key: userItemID),
               user.sessionID == session.id, user.kind == "user",
               let original = try JSONDecoder().decode([String: String].self, from: Data(user.payloadJSON.utf8))["text"],
               original == draft.text {
                // Clear only this submitted composer, in the response transaction.
                // Newer drafts and intent-only teaching actions remain untouched.
                try db.execute(sql: "UPDATE mentor_sessions SET draft_text = '' WHERE id = ?", arguments: [session.id])
            }
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

    func interruptPendingRequests(sessionID: UUID) async throws -> Int {
        try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("mentor session missing")
            }
            try db.execute(sql: "UPDATE mentor_requests SET state = 'interrupted' WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [sessionID.uuidString])
            let count = db.changesCount
            guard count > 0 else { return 0 }
            try db.execute(sql: "UPDATE mentor_sessions SET request_epoch = request_epoch + 1, activity_at = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: .now), sessionID.uuidString])
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

    func requestOutcome(sessionID: UUID, requestID: UUID) async throws -> MentorRequestOutcome? {
        try await database.dbQueue.read { db in
            guard let state = try String.fetchOne(db,
                sql: "SELECT state FROM mentor_requests WHERE session_id = ? AND id = ?",
                arguments: [sessionID.uuidString, requestID.uuidString]) else { return nil }
            return MentorRequestOutcome(rawValue: state)
        }
    }

    /// Marks an audited understanding-generation request complete without
    /// creating an assistant timeline item. The generated text is owned by the
    /// understanding draft instead.
    func completeUnderstandingRequest(sessionID: UUID, requestID: UUID) async throws {
        try await database.dbQueue.write { db in
            guard let request = try MentorRequestRow.fetchOne(db, key: requestID.uuidString),
                  request.sessionID == sessionID.uuidString,
                  request.intent == "draft_understanding" else {
                throw PersistenceError.validationFailed("invalid understanding request")
            }
            if request.state == "committed" { return }
            guard ["prepared", "in_flight", "response_received"].contains(request.state) else {
                throw PersistenceError.validationFailed("understanding request already terminal")
            }
            try db.execute(sql: "UPDATE mentor_requests SET state = 'committed' WHERE id = ?", arguments: [request.id])
        }
    }

    func retryableRequest(sessionID: UUID) async throws -> MentorRetryableRequest? {
        try await database.dbQueue.read { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString),
                  let row = try MentorRequestRow.fetchOne(db, sql: "SELECT * FROM mentor_requests WHERE session_id = ? ORDER BY rowid DESC LIMIT 1", arguments: [session.id]),
                  ["failed", "cancelled", "timed_out", "interrupted"].contains(row.state),
                  row.expectedRevision == session.semanticRevision,
                  let id = UUID(uuidString: row.id) else { return nil }
            let original = try row.userItemID.flatMap { try MentorItemRow.fetchOne(db, key: $0) }
            let text = try original.map { item -> String in
                guard item.sessionID == session.id, item.kind == "user",
                      let text = try JSONDecoder().decode([String: String].self, from: Data(item.payloadJSON.utf8))["text"] else {
                    throw PersistenceError.invalidStoredValue("retry user item")
                }
                return text
            }
            return MentorRetryableRequest(id: id, text: text, intent: row.intent, contextSnapshotJSON: row.contextSnapshotJSON)
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
                      (existing.registrationContextJSON ?? existing.contextSnapshotJSON) == command.contextSnapshotJSON,
                      previousPayload == payload,
                      command.userItemID == nil || existing.userItemID == command.userItemID?.uuidString,
                      existing.retryOf == command.retryOf?.uuidString,
                      let requestID = UUID(uuidString: existing.id) else {
                    throw PersistenceError.validationFailed("mentor command reused with different content")
                }
                return requestID
            }
            let unacknowledged = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM mentor_request_results r
                JOIN mentor_items i ON i.id = r.item_id
                JOIN mentor_requests q ON q.id = r.request_id AND q.session_id = r.session_id
                WHERE r.session_id = ? AND i.presented_at IS NULL AND q.expected_revision = ?
                """, arguments: [session.id, session.semanticRevision]) ?? 0
            guard unacknowledged == 0 else { throw PersistenceError.validationFailed("mentor presentation must be acknowledged before continuing") }
            let pending = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_requests WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [command.sessionID.uuidString]) ?? 0
            guard pending == 0 else { throw PersistenceError.validationFailed("mentor request already pending") }
            var retryItemID: String?
            if let retryOf = command.retryOf {
                guard let previous = try MentorRequestRow.fetchOne(db, key: retryOf.uuidString),
                      previous.sessionID == session.id,
                      try String.fetchOne(db, sql: "SELECT id FROM mentor_requests WHERE session_id = ? ORDER BY rowid DESC LIMIT 1", arguments: [session.id]) == previous.id,
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
                let item = MentorTimelineItem(id: command.userItemID ?? UUID(), sessionID: command.sessionID, sequence: next, kind: .user, payloadJSON: payload)
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

extension SQLiteMentorRepository: MentorPromptAudit {
    var httpObservationStore: (any MentorHTTPObservationStore)? {
        SQLiteMentorHTTPObservationStore(queue: database.dbQueue)
    }
    /// Validates the request's ownership and semantic snapshot immediately before
    /// PromptRun insertion. Prepared and in-flight requests are auditable; terminal,
    /// deleted, or superseded requests cannot receive a late trace.
    func validate(_ token: LLMRequest.MentorAuditToken) async throws {
        try await database.dbQueue.read { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: token.sessionID.uuidString),
                  let request = try MentorRequestRow.fetchOne(db, key: token.requestID.uuidString),
                  request.sessionID == session.id,
                  ["prepared", "in_flight", "response_received"].contains(request.state),
                  request.epoch == token.requestEpoch,
                  request.expectedRevision == token.semanticRevision,
                  session.requestEpoch == token.requestEpoch,
                  session.semanticRevision == token.semanticRevision else {
                throw PersistenceError.validationFailed("mentor prompt audit request is stale or not owned")
            }
        }
    }

    func savePromptRun(_ run: PromptRun, token: LLMRequest.MentorAuditToken) async throws {
        try await database.dbQueue.write { db in
            guard let session = try MentorSessionRow.fetchOne(db, key: token.sessionID.uuidString),
                  let request = try MentorRequestRow.fetchOne(db, key: token.requestID.uuidString),
                  request.sessionID == session.id,
                  ["prepared", "in_flight", "response_received"].contains(request.state),
                  request.epoch == token.requestEpoch,
                  request.expectedRevision == token.semanticRevision,
                  session.requestEpoch == token.requestEpoch,
                  session.semanticRevision == token.semanticRevision else {
                throw PersistenceError.validationFailed("mentor prompt audit request is stale or not owned")
            }
            var row = PromptRunRow(run: run)
            row.mentorSessionId = session.id
            row.mentorRequestId = request.id
            row.mentorRequestEpoch = token.requestEpoch
            row.mentorSemanticRevision = token.semanticRevision
            try row.upsert(db)
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
    var registrationContextJSON: String? = nil
    enum CodingKeys: String, CodingKey { case registrationContextJSON = "registration_context_json", id, sessionID = "session_id", commandID = "command_id", userItemID = "user_item_id", intent, contextSnapshotJSON = "context_snapshot_json", state, createdAt = "created_at", expectedRevision = "expected_revision", epoch, retryOf = "retry_of" }
}

private struct MentorSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, initialEntry, lifecycle, draftText: String
    var draftRevision: Int
    var activityAt: String
    var semanticRevision, requestEpoch, recallCount: Int
    var originLegacyRootID: String?
    enum CodingKeys: String, CodingKey { case id, initialEntry = "initial_entry", lifecycle, draftText = "draft_text", draftRevision = "draft_revision", activityAt = "activity_at", semanticRevision = "semantic_revision", requestEpoch = "request_epoch", recallCount = "recall_count", originLegacyRootID = "origin_legacy_root_id" }
    init(_ value: MentorSession) { id = value.id.uuidString; initialEntry = value.initialEntry; lifecycle = value.lifecycle.rawValue; draftText = value.draftText; draftRevision = value.draftRevision; activityAt = ISO8601DateFormatter().string(from: value.activityAt); semanticRevision = value.semanticRevision; requestEpoch = value.requestEpoch; recallCount = value.recallCount; originLegacyRootID = value.originLegacyRootID?.uuidString }
    func model() throws -> MentorSession { guard let id = UUID(uuidString: id), let lifecycle = MentorSessionLifecycle(rawValue: lifecycle), let date = ISO8601DateFormatter().date(from: activityAt), originLegacyRootID == nil || UUID(uuidString: originLegacyRootID!) != nil else { throw PersistenceError.invalidStoredValue("mentor_sessions") }; return MentorSession(id: id, initialEntry: initialEntry, lifecycle: lifecycle, draftText: draftText, draftRevision: draftRevision, activityAt: date, semanticRevision: semanticRevision, recallCount: recallCount, requestEpoch: requestEpoch, originLegacyRootID: originLegacyRootID.flatMap(UUID.init(uuidString:))) }
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

private struct MentorUnderstandingRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mentor_understandings"
    var id, sessionID, groupID: String
    var revision: Int
    var state, text: String
    var previousRevisionID: String?
    var origin: String
    var confirmedAt: String?
    var editRevision: Int
    enum CodingKeys: String, CodingKey {
        case id, sessionID = "session_id", groupID = "group_id", revision, state, text
        case previousRevisionID = "previous_revision_id", origin, confirmedAt = "confirmed_at", editRevision = "edit_revision"
    }
    func model() throws -> MentorUnderstanding {
        guard let id = UUID(uuidString: id), let sessionID = UUID(uuidString: sessionID),
              let groupID = UUID(uuidString: groupID), let state = MentorUnderstandingState(rawValue: state),
              previousRevisionID == nil || UUID(uuidString: previousRevisionID!) != nil,
              confirmedAt == nil || ISO8601DateFormatter().date(from: confirmedAt!) != nil else {
            throw PersistenceError.invalidStoredValue("mentor understanding")
        }
        return MentorUnderstanding(id: id, sessionID: sessionID, groupID: groupID, revision: revision,
            previousRevisionID: previousRevisionID.flatMap(UUID.init(uuidString:)), state: state, text: text,
            origin: origin, editRevision: editRevision, confirmedAt: confirmedAt.flatMap { ISO8601DateFormatter().date(from: $0) })
    }
}

private struct MentorSourceLinkRow: Codable, FetchableRecord {
    var id, sessionID, ownerID, sourceKind, sourceID: String
    var ownerKind: String
    var ownerUUID: String?
    var sourceVersion: String?
    var contentHash: String?
    var availability: String
    enum CodingKeys: String, CodingKey {
        case id, sessionID = "session_id", ownerID = "owner_id", sourceKind = "source_kind", sourceID = "source_id"
        case ownerKind = "owner_kind", ownerUUID = "owner_uuid", sourceVersion = "source_version", contentHash = "content_hash", availability
    }
    func model() throws -> MentorSourceLink {
        guard let id = UUID(uuidString: id), let sessionID = UUID(uuidString: sessionID),
              let ownerID = UUID(uuidString: ownerUUID ?? ownerID),
              let kind = MentorSourceOwnerKind(rawValue: ownerKind),
              let availability = MentorSourceAvailability(rawValue: availability) else {
            throw PersistenceError.invalidStoredValue("mentor_source_links")
        }
        return MentorSourceLink(id: id, sessionID: sessionID, ownerKind: kind, ownerID: ownerID,
            sourceKind: sourceKind, sourceID: sourceID, sourceVersion: sourceVersion,
            contentHash: contentHash, availability: availability)
    }
}

extension SQLiteMentorRepository {
    /// Selection and snapshot persistence share one transaction, so parallel selections cannot
    /// consume stale eligibility. Actual presentation remains a separate view acknowledgement.
    func selectNextLesson(sessionID: UUID, itemID: UUID, expectedEpoch: Int, catalog: MentorLessonCatalog, at date: Date, timeZone: TimeZone) async throws -> MentorSavedLesson? {
        try MentorLessonCatalog.validate(catalog.pack)
        let cutoff = try Self.lessonDay(date, timeZone: timeZone, offset: -13)
        return try await database.dbQueue.write { db in
            if let row = try Row.fetchOne(db, sql: "SELECT epoch FROM mentor_lesson_snapshots WHERE item_id = ?", arguments: [itemID.uuidString]) {
                let epoch: Int = row["epoch"]
                guard epoch == expectedEpoch, let saved = try Self.readLesson(db, sessionID: sessionID, itemID: itemID) else {
                    throw PersistenceError.validationFailed("conflicting lesson selection replay")
                }
                return saved
            }
            guard let session = try MentorSessionRow.fetchOne(db, key: sessionID.uuidString),
                  ["draft", "active"].contains(session.lifecycle), session.requestEpoch == expectedEpoch else {
                throw PersistenceError.validationFailed("lesson selection requires current active session")
            }
            let pendingRequests = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_requests WHERE session_id = ? AND state IN ('prepared', 'in_flight', 'response_received')", arguments: [session.id]) ?? 0
            let unpresented = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_items WHERE session_id = ? AND kind IN ('lesson', 'assistant') AND presented_at IS NULL", arguments: [session.id]) ?? 0
            guard pendingRequests == 0, unpresented == 0 else { throw PersistenceError.validationFailed("finish pending mentor work before selecting a lesson") }
            let excluded = try Self.excludedLessons(db, sessionID: sessionID, cutoff: cutoff)
            let themes = try Self.excludedThemes(db, sessionID: sessionID)
            var ordered = catalog.lessonsInEditorialOrder
            let hasPresentedLesson = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_lesson_snapshots l JOIN mentor_items i ON i.id = l.item_id WHERE i.presented_at IS NOT NULL") != 0
            if !hasPresentedLesson, let first = ordered.firstIndex(where: { $0.id == "L01" }) {
                ordered.insert(ordered.remove(at: first), at: 0)
            }
            guard let lesson = ordered.first(where: { !excluded.contains($0.id) && !themes.contains($0.theme.rawValue) }) else { return nil }
            let conflicting = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_lesson_snapshots WHERE lesson_id = ? AND version = ? AND content_hash != ?", arguments: [lesson.id, lesson.version, lesson.contentHash]) ?? 0
            guard conflicting == 0 else { throw PersistenceError.validationFailed("lesson version changed since historical presentation") }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payload = String(decoding: try encoder.encode(lesson), as: UTF8.self)
            let sequence = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sequence), 0) + 1 FROM mentor_items WHERE session_id = ?", arguments: [session.id]) ?? 1
            try MentorItemRow(MentorTimelineItem(id: itemID, sessionID: sessionID, sequence: sequence, kind: .lesson, payloadJSON: payload)).insert(db)
            try db.execute(sql: "INSERT INTO mentor_lesson_snapshots (item_id, session_id, lesson_id, version, content_hash, theme, epoch) VALUES (?, ?, ?, ?, ?, ?, ?)", arguments: [itemID.uuidString, session.id, lesson.id, lesson.version, lesson.contentHash, lesson.theme.rawValue, expectedEpoch])
            try db.execute(sql: "UPDATE mentor_sessions SET lifecycle = 'active', activity_at = ? WHERE id = ?", arguments: [ISO8601DateFormatter().string(from: date), session.id])
            // Return exactly the persisted snapshot (including date precision),
            // so immediate discussion uses the same version as later restoration.
            return try Self.readLesson(db, sessionID: sessionID, itemID: itemID)
        }
    }

    /// History always reads the saved payload, independent of the installed content pack.
    func savedLesson(sessionID: UUID, itemID: UUID) async throws -> MentorSavedLesson? {
        try await database.dbQueue.read { try Self.readLesson($0, sessionID: sessionID, itemID: itemID) }
    }

    func listeningResume(at date: Date, timeZone: TimeZone) async throws -> MentorSavedLesson? {
        let day = try Self.lessonDay(date, timeZone: timeZone)
        return try await database.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT l.item_id, l.session_id, l.lesson_id, l.theme
                FROM mentor_lesson_snapshots l JOIN mentor_items i ON i.id = l.item_id
                JOIN mentor_sessions s ON s.id = l.session_id
                WHERE s.initial_entry = 'listen' AND i.presentation_day = ?
                ORDER BY i.presented_at DESC, i.sequence DESC, i.id DESC LIMIT 1
                """, arguments: [day]),
                  let itemID = UUID(uuidString: row["item_id"]), let sessionID = UUID(uuidString: row["session_id"]) else { return nil }
            let lessonID: String = row["lesson_id"], theme: String = row["theme"]
            let known = try String.fetchAll(db, sql: "SELECT lesson_id FROM mentor_feedback WHERE kind = 'already_known' AND revoked_at IS NULL")
            guard !known.contains(lessonID), try !Self.excludedThemes(db, sessionID: sessionID).contains(theme) else { return nil }
            // Reading an ended session does not reactivate it or issue any model work.
            return try Self.readLesson(db, sessionID: sessionID, itemID: itemID)
        }
    }

    func saveReadingPosition(sessionID: UUID, itemID: UUID, revision: Int, section: MentorReadingSection,
                             offset: Double = 0, layoutKey: String? = nil) async throws {
        guard offset.isFinite, offset >= 0,
              layoutKey.map({ !$0.isEmpty && $0.unicodeScalars.count <= 256 }) ?? true else {
            throw PersistenceError.validationFailed("invalid reading position geometry")
        }
        try await database.dbQueue.write { db in
            guard let saved = try Self.readLesson(db, sessionID: sessionID, itemID: itemID),
                  revision >= 0, revision >= saved.readingRevision,
                  section != .observation || saved.lesson.observation != nil else {
                throw PersistenceError.validationFailed("invalid reading position")
            }
            if revision == saved.readingRevision {
                guard section == saved.readingSection, offset == saved.readingOffset,
                      layoutKey == saved.readingLayoutKey else {
                    throw PersistenceError.validationFailed("reading revision conflict")
                }
                return
            }
            try db.execute(sql: """
                UPDATE mentor_lesson_snapshots
                SET reading_section = ?, reading_revision = ?, reading_offset = ?, reading_layout_key = ?
                WHERE item_id = ?
                """, arguments: [section.rawValue, revision, offset, layoutKey, itemID.uuidString])
        }
    }

    func recordLessonFeedback(sessionID: UUID, itemID: UUID, commandID: UUID, kind: MentorLessonFeedback, at date: Date) async throws {
        guard date.timeIntervalSince1970.isFinite else { throw PersistenceError.validationFailed("invalid feedback time") }
        try await database.dbQueue.write { db in
            guard let saved = try Self.readLesson(db, sessionID: sessionID, itemID: itemID),
                  try String.fetchOne(db, sql: "SELECT presented_at FROM mentor_items WHERE id = ?", arguments: [itemID.uuidString]) != nil else {
                throw PersistenceError.validationFailed("feedback requires an owned, presented lesson")
            }
            if let old = try Row.fetchOne(db, sql: "SELECT session_id, item_id, kind FROM mentor_feedback WHERE id = ?", arguments: [commandID.uuidString]) {
                let owner: String = old["session_id"], item: String? = old["item_id"], oldKind: String = old["kind"]
                guard owner == sessionID.uuidString, item == itemID.uuidString, oldKind == kind.rawValue else {
                    throw PersistenceError.validationFailed("conflicting lesson feedback")
                }
                return
            }
            try db.execute(sql: "INSERT INTO mentor_feedback (id, session_id, item_id, lesson_id, kind, created_at) VALUES (?, ?, ?, ?, ?, ?)", arguments: [commandID.uuidString, sessionID.uuidString, itemID.uuidString, saved.lesson.id, kind.rawValue, ISO8601DateFormatter().string(from: date)])
        }
    }

    func recordBenefitFeedback(sessionID: UUID, commandID: UUID, kind: MentorBenefitFeedbackKind,
                               note: String?, at date: Date) async throws -> MentorBenefitFeedback {
        guard date.timeIntervalSince1970.isFinite else { throw PersistenceError.validationFailed("invalid feedback time") }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.map({ $0.count <= 2_000 }) ?? true else {
            throw PersistenceError.validationFailed("benefit feedback note is too long")
        }
        return try await database.dbQueue.write { db in
            guard try MentorSessionRow.fetchOne(db, key: sessionID.uuidString) != nil else {
                throw PersistenceError.validationFailed("benefit feedback session missing")
            }
            if let old = try Row.fetchOne(db, sql: "SELECT session_id, item_id, lesson_id, kind, note, created_at FROM mentor_feedback WHERE id = ?", arguments: [commandID.uuidString]) {
                let owner: String = old["session_id"]
                let oldItem: String? = old["item_id"]
                let oldLesson: String? = old["lesson_id"]
                let oldKind: String = old["kind"]
                let oldNote: String? = old["note"]
                guard owner == sessionID.uuidString, oldItem == nil, oldLesson == nil,
                      oldKind == kind.rawValue, oldNote == trimmed else {
                    throw PersistenceError.validationFailed("conflicting benefit feedback")
                }
                let createdAt: String = old["created_at"]
                guard let created = ISO8601DateFormatter().date(from: createdAt) else {
                    throw PersistenceError.invalidStoredValue("mentor feedback")
                }
                return MentorBenefitFeedback(id: commandID, sessionID: sessionID, kind: kind,
                    note: trimmed, createdAt: created)
            }
            let createdAt = ISO8601DateFormatter().string(from: date)
            try db.execute(sql: "INSERT INTO mentor_feedback (id, session_id, item_id, lesson_id, kind, note, created_at) VALUES (?, ?, NULL, NULL, ?, ?, ?)",
                arguments: [commandID.uuidString, sessionID.uuidString, kind.rawValue, trimmed, createdAt])
            return MentorBenefitFeedback(id: commandID, sessionID: sessionID, kind: kind,
                note: trimmed, createdAt: date)
        }
    }

    func benefitFeedback(sessionID: UUID) async throws -> MentorBenefitFeedback? {
        try await database.dbQueue.read { db in
            let kinds = MentorBenefitFeedbackKind.allCases.map(\.rawValue)
            let placeholders = Array(repeating: "?", count: kinds.count).joined(separator: ",")
            guard let row = try Row.fetchOne(db, sql: """
                SELECT id, session_id, kind, note, created_at
                FROM mentor_feedback
                WHERE session_id = ? AND item_id IS NULL AND lesson_id IS NULL
                  AND kind IN (\(placeholders))
                ORDER BY created_at DESC, id DESC LIMIT 1
                """, arguments: StatementArguments([sessionID.uuidString] + kinds)) else { return nil }
            guard let id = UUID(uuidString: row["id"] as String),
                  let owner = UUID(uuidString: row["session_id"] as String), owner == sessionID,
                  let kind = MentorBenefitFeedbackKind(rawValue: row["kind"] as String),
                  let date = ISO8601DateFormatter().date(from: row["created_at"] as String) else {
                throw PersistenceError.invalidStoredValue("mentor benefit feedback")
            }
            return MentorBenefitFeedback(id: id, sessionID: owner, kind: kind,
                note: row["note"], createdAt: date)
        }
    }

    func resetKnownLessonFeedback(commandID: UUID, at date: Date) async throws {
        guard date.timeIntervalSince1970.isFinite else { throw PersistenceError.validationFailed("invalid feedback reset time") }
        try await database.dbQueue.write { db in
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_feedback_resets WHERE command_id = ?", arguments: [commandID.uuidString]) == 0 else { return }
            let timestamp = ISO8601DateFormatter().string(from: date)
            try db.execute(sql: "INSERT INTO mentor_feedback_resets (command_id, created_at) VALUES (?, ?)", arguments: [commandID.uuidString, timestamp])
            try db.execute(sql: "UPDATE mentor_feedback SET revoked_at = ? WHERE kind = 'already_known' AND revoked_at IS NULL", arguments: [timestamp])
        }
    }

    private static func readLesson(_ db: Database, sessionID: UUID, itemID: UUID) throws -> MentorSavedLesson? {
        guard let row = try Row.fetchOne(db, sql: """
            SELECT i.payload_json, l.reading_section, l.reading_revision, l.reading_offset,
                   l.reading_layout_key, l.lesson_id, l.version, l.content_hash
            FROM mentor_lesson_snapshots l JOIN mentor_items i ON i.id = l.item_id AND i.session_id = l.session_id
            WHERE l.item_id = ? AND l.session_id = ?
            """, arguments: [itemID.uuidString, sessionID.uuidString]) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let lesson = try decoder.decode(MentorLesson.self, from: Data((row["payload_json"] as String).utf8))
        let lessonID: String = row["lesson_id"], version: String = row["version"], hash: String = row["content_hash"]
        let offset: Double = row["reading_offset"], layoutKey: String? = row["reading_layout_key"]
        guard let section = MentorReadingSection(rawValue: row["reading_section"]), lesson.id == lessonID,
              offset.isFinite, offset >= 0,
              layoutKey.map({ !$0.isEmpty && $0.unicodeScalars.count <= 256 }) ?? true,
              lesson.version == version, lesson.contentHash == hash, MentorLessonCatalog.contentHash(for: lesson) == hash else {
            throw PersistenceError.invalidStoredValue("mentor lesson snapshot")
        }
        return MentorSavedLesson(id: itemID, sessionID: sessionID, lesson: lesson, readingSection: section,
                                 readingRevision: row["reading_revision"], readingOffset: offset, readingLayoutKey: layoutKey)
    }

    private static func excludedLessons(_ db: Database, sessionID: UUID, cutoff: String) throws -> Set<String> {
        // No upper date bound: clock rollback must not erase future-dated presentation facts.
        Set(try String.fetchAll(db, sql: """
            SELECT l.lesson_id FROM mentor_lesson_snapshots l JOIN mentor_items i ON i.id = l.item_id
            WHERE i.presented_at IS NOT NULL AND (l.session_id = ? OR i.presentation_day >= ?)
            UNION SELECT lesson_id FROM mentor_feedback WHERE kind = 'already_known' AND revoked_at IS NULL AND lesson_id IS NOT NULL
            """, arguments: [sessionID.uuidString, cutoff]))
    }

    private static func excludedThemes(_ db: Database, sessionID: UUID) throws -> Set<String> {
        Set(try String.fetchAll(db, sql: """
            SELECT l.theme FROM mentor_feedback f JOIN mentor_lesson_snapshots l ON l.item_id = f.item_id AND l.session_id = f.session_id
            WHERE f.session_id = ? AND f.kind = 'not_relevant' AND f.revoked_at IS NULL
            """, arguments: [sessionID.uuidString]))
    }

    private static func lessonDay(_ date: Date, timeZone: TimeZone, offset: Int = 0) throws -> String {
        guard date.timeIntervalSince1970.isFinite else { throw PersistenceError.validationFailed("invalid lesson date") }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        guard let shifted = calendar.date(byAdding: .day, value: offset, to: date) else { throw PersistenceError.validationFailed("invalid lesson date") }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar; formatter.timeZone = timeZone; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: shifted)
    }
}
