import Foundation
import GRDB

enum LegacyNudgeLineageIssue: Equatable {
    case missingDeclaredRoot(UUID)
    case rootHasParent(rootID: UUID, parentID: UUID)
    case missingParent(roundID: UUID, parentID: UUID)
    case disconnectedRound(UUID)
    case declaredRootMismatch(roundID: UUID, declaredRootID: UUID)
    case cycle([UUID])
}

struct LegacyNudgeRound: Equatable, Identifiable {
    let session: SingleNudgeSession
    let promptRun: PromptRun?
    let reviewPromptRun: PromptRun?

    var id: UUID { session.id }
}

struct LegacyNudgeChain: Equatable, Identifiable {
    let rootID: UUID
    let rounds: [LegacyNudgeRound]
    let issues: [LegacyNudgeLineageIssue]

    var id: UUID { rootID }
    var canContinueAutomatically: Bool { !rounds.isEmpty && issues.isEmpty }
    var activityAt: Date { rounds.map(\.session.updatedAt).max() ?? .distantPast }
    var preview: String {
        rounds.lazy.map(\.session.input)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "旧点拨"
    }
}

struct LegacyNudgeDeletionResult: Equatable {
    let rootID: UUID
    let deletedRoundCount: Int
    let deletedMentorSessionID: UUID
}

enum LegacyNudgeAdapterError: Error, Equatable {
    case missingRoot(UUID)
    case missingRound(UUID)
    case ambiguousLineage(UUID)
    case invalidPageSize
    case invalidStoredValue(String)
    case notLegacyWrapper(UUID)
}

struct LegacyNudgeSummaryCursor: Equatable {
    fileprivate let storedActivityAt: String
    fileprivate let rootID: String
}

struct LegacyNudgeSummaryPage {
    let sessions: [MentorSessionSummary]
    let nextCursor: LegacyNudgeSummaryCursor?
}

/// Reads the append-only `SingleNudgeSession` graph without rewriting it. A
/// Mentor wrapper and its projected timeline are created only when the person
/// explicitly continues an intact legacy chain.
final class LegacyNudgeAdapter {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func chain(rootID: UUID) async throws -> LegacyNudgeChain? {
        try await database.dbQueue.read { db in
            try Self.loadChain(rootID: rootID, db: db)
        }
    }

    /// Read only requested rounds explicitly linked to this Mentor session, or
    /// members of the legacy root currently being inspected without a wrapper.
    func sourceRounds(sessionID: UUID, roundIDs: Set<UUID>, historyRootID: UUID? = nil) async throws -> [LegacyNudgeRound] {
        guard !roundIDs.isEmpty else { return [] }
        guard historyRootID == nil || historyRootID == sessionID else {
            throw LegacyNudgeAdapterError.invalidStoredValue("legacy_source_scope")
        }
        return try await database.dbQueue.read { db in
            let ids = roundIDs.map(\.uuidString).sorted()
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            let rows: [Row]
            if let rootID = historyRootID {
                rows = try Row.fetchAll(db, sql: """
                    SELECT * FROM single_nudge_sessions
                    WHERE (id = ? OR root_session_id = ?) AND id IN (\(placeholders))
                    """, arguments: StatementArguments([rootID.uuidString, rootID.uuidString] + ids))
            } else {
                rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT n.* FROM single_nudge_sessions n
                    JOIN mentor_source_links l ON lower(l.source_id) = lower(n.id)
                    JOIN mentor_items i ON i.id = l.owner_id AND i.id = l.owner_uuid AND i.session_id = l.session_id
                    WHERE l.session_id = ? AND l.source_kind = 'legacy-nudge'
                      AND l.owner_kind = 'item' AND l.availability = 'available'
                      AND n.id IN (\(placeholders))
                    """, arguments: StatementArguments([sessionID.uuidString] + ids))
            }
            let sessions = try rows.map { try Self.storedNudge($0).session }
            let promptIDs = Set(sessions.flatMap { [$0.promptRunID, $0.reviewPromptRunID].compactMap { $0 } })
            let runs = try Self.loadPromptRuns(ids: promptIDs, db: db)
            return sessions.map { session in
                LegacyNudgeRound(session: session, promptRun: session.promptRunID.flatMap { runs[$0] },
                    reviewPromptRun: session.reviewPromptRunID.flatMap { runs[$0] })
            }
        }
    }

    /// Returns one entry per old root and hides roots already represented by a
    /// Mentor wrapper. The wrapper remains the sole recent-list entry.
    func recentChains(limit: Int = 20) async throws -> [LegacyNudgeChain] {
        guard (1...100).contains(limit) else { throw LegacyNudgeAdapterError.invalidPageSize }
        return try await database.dbQueue.read { db in
            guard try db.tableExists("single_nudge_sessions") else { return [] }
            let rows = try Row.fetchAll(db, sql: """
                SELECT COALESCE(NULLIF(root_session_id, ''), id) AS root_id,
                       MAX(updated_at) AS latest_at
                FROM single_nudge_sessions n
                WHERE NOT EXISTS (
                    SELECT 1 FROM mentor_sessions m
                    WHERE m.origin_legacy_root_id = COALESCE(NULLIF(n.root_session_id, ''), n.id)
                )
                GROUP BY COALESCE(NULLIF(root_session_id, ''), id)
                ORDER BY latest_at DESC, root_id DESC
                LIMIT ?
                """, arguments: [limit])
            return try rows.compactMap { row in
                let raw: String = row["root_id"]
                guard let rootID = UUID(uuidString: raw) else {
                    throw LegacyNudgeAdapterError.invalidStoredValue("single_nudge_sessions.root_session_id")
                }
                return try Self.loadChain(rootID: rootID, db: db)
            }
        }
    }

    /// List projections fetch bounded previews, never the chain or its audits.
    /// Each source retains its own exact stored timestamp for keyset pagination.
    func recentSummaries(after cursor: LegacyNudgeSummaryCursor? = nil, limit: Int = 20,
                         unfinishedOnly: Bool = false) async throws -> LegacyNudgeSummaryPage {
        guard (1...20).contains(limit) else { throw LegacyNudgeAdapterError.invalidPageSize }
        return try await database.dbQueue.read { db in
            guard try db.tableExists("single_nudge_sessions") else {
                return LegacyNudgeSummaryPage(sessions: [], nextCursor: nil)
            }
            var boundary = unfinishedOnly ? "AND r.lifecycle != 'ended'" : ""
            var arguments: StatementArguments = []
            if let cursor {
                boundary += " AND (r.latest_at, r.root_id) < (?, ?)"
                arguments += [cursor.storedActivityAt, cursor.rootID]
            }
            arguments += [limit + 1]
            let rows = try Row.fetchAll(db, sql: """
                WITH roots AS (
                    SELECT COALESCE(NULLIF(n.root_session_id, ''), n.id) AS root_id,
                           MAX(n.updated_at) AS latest_at,
                           CASE WHEN MIN(n.lifecycle = 'completed') THEN 'ended' ELSE 'paused' END AS lifecycle
                    FROM single_nudge_sessions n
                    WHERE NOT EXISTS (
                        SELECT 1 FROM mentor_sessions m
                        WHERE m.origin_legacy_root_id = COALESCE(NULLIF(n.root_session_id, ''), n.id)
                    )
                    GROUP BY COALESCE(NULLIF(n.root_session_id, ''), n.id)
                )
                SELECT r.root_id, r.latest_at, r.lifecycle,
                    COALESCE((
                        SELECT substr(trim(n.input), 1, 80) FROM single_nudge_sessions n
                        WHERE n.id = r.root_id AND length(trim(n.input)) > 0
                    ), (
                        SELECT substr(trim(n.input), 1, 80) FROM single_nudge_sessions n
                        WHERE (n.id = r.root_id OR n.root_session_id = r.root_id)
                          AND length(trim(n.input)) > 0
                        ORDER BY n.created_at, n.id
                        LIMIT 1
                    ), '旧点拨') AS preview
                FROM roots r WHERE 1 = 1 \(boundary)
                ORDER BY r.latest_at DESC, r.root_id DESC LIMIT ?
                """, arguments: arguments)
            let visible = Array(rows.prefix(limit))
            let summaries = try visible.map { row -> MentorSessionSummary in
                let rawID: String = row["root_id"]
                let rawDate: String = row["latest_at"]
                let rawLifecycle: String = row["lifecycle"]
                guard let id = UUID(uuidString: rawID),
                      let date = (try? Date(rawDate, strategy: Self.fractionalDateStyle)) ?? (try? Date(rawDate, strategy: Self.basicDateStyle)),
                      let lifecycle = MentorSessionLifecycle(rawValue: rawLifecycle) else {
                    throw LegacyNudgeAdapterError.invalidStoredValue("legacy history summary")
                }
                return MentorSessionSummary(id: id, initialEntry: "legacy-nudge", lifecycle: lifecycle,
                    activityAt: date, preview: row["preview"], originLegacyRootID: id)
            }
            let next = rows.count > limit ? visible.last.map {
                LegacyNudgeSummaryCursor(storedActivityAt: $0["latest_at"], rootID: $0["root_id"])
            } : nil
            return LegacyNudgeSummaryPage(sessions: summaries, nextCursor: next)
        }
    }

    /// Creates exactly one wrapper for an intact root. Replaying the command
    /// returns the existing session and never duplicates projected items.
    func continueChain(rootID: UUID, at date: Date = .now) async throws -> MentorSession {
        guard let chain = try await chain(rootID: rootID) else {
            throw LegacyNudgeAdapterError.missingRoot(rootID)
        }
        guard chain.canContinueAutomatically else {
            throw LegacyNudgeAdapterError.ambiguousLineage(rootID)
        }
        return try await database.dbQueue.write { db in
            if let existing = try Self.wrappedSession(rootID: rootID, db: db) {
                return existing
            }
            let session = MentorSession(id: UUID(), initialEntry: "legacy-nudge", lifecycle: .active,
                draftText: "", draftRevision: 0, activityAt: date, originLegacyRootID: rootID)
            try Self.insert(session: session, db: db)
            try Self.insertProjection(chain: chain, sessionID: session.id, db: db)
            return session
        }
    }

    /// A damaged graph cannot be continued as if its lineage were certain. The
    /// user may explicitly choose one valid round; that new conversation borrows
    /// the old round as a source and therefore does not own or delete it.
    func startIndependentSession(fromRoundID roundID: UUID, at date: Date = .now) async throws -> MentorSession {
        let round = try await database.dbQueue.read { db -> SingleNudgeSession? in
            guard try db.tableExists("single_nudge_sessions") else { return nil }
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM single_nudge_sessions WHERE id = ?", arguments: [roundID.uuidString]) else { return nil }
            return try Self.storedNudge(row).session
        }
        guard let round else { throw LegacyNudgeAdapterError.missingRound(roundID) }
        return try await database.dbQueue.write { db in
            let session = MentorSession(id: UUID(), initialEntry: "legacy-nudge-selection", lifecycle: .active,
                draftText: "", draftRevision: 0, activityAt: date)
            try Self.insert(session: session, db: db)
            let chain = LegacyNudgeChain(rootID: roundID,
                rounds: [LegacyNudgeRound(session: round, promptRun: nil, reviewPromptRun: nil)], issues: [])
            try Self.insertProjection(chain: chain, sessionID: session.id, db: db)
            return session
        }
    }

    func wrappedSession(rootID: UUID) async throws -> MentorSession? {
        try await database.dbQueue.read { db in try Self.wrappedSession(rootID: rootID, db: db) }
    }

    /// Builds the same read-only rows used by a wrapper, without writing them.
    /// This is used while an old root is being viewed before the person chooses
    /// to continue it.
    func projectedItems(rootID: UUID) async throws -> [MentorTimelineItem] {
        guard let chain = try await chain(rootID: rootID) else {
            throw LegacyNudgeAdapterError.missingRoot(rootID)
        }
        return Self.projectionItems(chain: chain, sessionID: rootID)
    }

    /// Deleting a wrapper removes the owned Mentor graph and the old nudge rows
    /// that it uniquely represents. External source records and the legacy audit
    /// runs are not guessed from JSON and remain for F15 ownership governance.
    func deleteWrapper(sessionID: UUID) async throws -> LegacyNudgeDeletionResult {
        try await database.dbQueue.write { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT origin_legacy_root_id FROM mentor_sessions WHERE id = ?", arguments: [sessionID.uuidString]) else {
                throw LegacyNudgeAdapterError.notLegacyWrapper(sessionID)
            }
            let rawRoot: String? = row["origin_legacy_root_id"]
            guard let rawRoot, let rootID = UUID(uuidString: rawRoot) else {
                throw LegacyNudgeAdapterError.notLegacyWrapper(sessionID)
            }
            let count = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM single_nudge_sessions
                WHERE id = ? OR root_session_id = ?
                """, arguments: [rawRoot, rawRoot]) ?? 0
            try Self.deleteOwnedPromptRuns(rootID: rootID, db: db)
            try db.execute(sql: "DELETE FROM mentor_sessions WHERE id = ?", arguments: [sessionID.uuidString])
            try db.execute(sql: "DELETE FROM single_nudge_sessions WHERE id = ? OR root_session_id = ?",
                           arguments: [rawRoot, rawRoot])
            return LegacyNudgeDeletionResult(rootID: rootID, deletedRoundCount: count,
                                             deletedMentorSessionID: sessionID)
        }
    }

    /// Removes an unwrapped legacy root after an explicit delete confirmation.
    /// This path has no Mentor owner; it is kept separate from wrapper deletion
    /// so a borrowed fragment can never delete the old chain by accident.
    func deleteLegacyChain(rootID: UUID) async throws -> Int {
        try await database.dbQueue.write { db in
            let count = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM single_nudge_sessions
                WHERE id = ? OR root_session_id = ?
                """, arguments: [rootID.uuidString, rootID.uuidString]) ?? 0
            guard count > 0 else { throw LegacyNudgeAdapterError.missingRoot(rootID) }
            try Self.deleteOwnedPromptRuns(rootID: rootID, db: db)
            try db.execute(sql: "DELETE FROM single_nudge_sessions WHERE id = ? OR root_session_id = ?",
                           arguments: [rootID.uuidString, rootID.uuidString])
            return count
        }
    }
}

private extension LegacyNudgeAdapter {
    /// Legacy prompt runs are owned by the old chain through explicit UUID
    /// columns. Delete those exact rows during an explicit chain deletion;
    /// never infer ownership from free-form JSON.
    static func deleteOwnedPromptRuns(rootID: UUID, db: Database) throws {
        guard try db.tableExists("prompt_runs") else { return }
        let ids = try String.fetchAll(db, sql: """
            SELECT prompt_run_id FROM single_nudge_sessions
            WHERE (id = ? OR root_session_id = ?) AND prompt_run_id IS NOT NULL
            UNION
            SELECT review_prompt_run_id FROM single_nudge_sessions
            WHERE (id = ? OR root_session_id = ?) AND review_prompt_run_id IS NOT NULL
            """, arguments: [rootID.uuidString, rootID.uuidString, rootID.uuidString, rootID.uuidString])
        guard !ids.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        try db.execute(sql: "DELETE FROM prompt_runs WHERE id IN (\(placeholders))",
                       arguments: StatementArguments(ids))
    }

    struct StoredNudge {
        let session: SingleNudgeSession
        let declaredRootID: UUID
    }

    static func loadChain(rootID: UUID, db: Database) throws -> LegacyNudgeChain? {
        guard try db.tableExists("single_nudge_sessions") else { return nil }
        let rows = try Row.fetchAll(db, sql: """
            SELECT * FROM single_nudge_sessions
            WHERE id = ? OR root_session_id = ?
            """, arguments: [rootID.uuidString, rootID.uuidString])
        guard !rows.isEmpty else { return nil }
        let stored = try rows.map(storedNudge)
        let byID = Dictionary(uniqueKeysWithValues: stored.map { ($0.session.id, $0) })
        var issues: [LegacyNudgeLineageIssue] = []
        if byID[rootID] == nil { issues.append(.missingDeclaredRoot(rootID)) }
        for value in stored where value.declaredRootID != rootID {
            issues.append(.declaredRootMismatch(roundID: value.session.id, declaredRootID: value.declaredRootID))
        }
        if let parent = byID[rootID]?.session.parentSessionID {
            issues.append(.rootHasParent(rootID: rootID, parentID: parent))
        }

        var depths: [UUID: Int] = [:]
        var reportedCycles = Set<String>()
        func depth(_ id: UUID, path: [UUID]) -> Int? {
            if let value = depths[id] { return value }
            guard let value = byID[id] else { return nil }
            if let start = path.firstIndex(of: id) {
                let cycle = Array(path[start...]) + [id]
                let key = cycle.map(\.uuidString).sorted().joined(separator: ":")
                if reportedCycles.insert(key).inserted { issues.append(.cycle(cycle)) }
                return nil
            }
            if id == rootID, value.session.parentSessionID == nil {
                depths[id] = 0
                return 0
            }
            guard let parentID = value.session.parentSessionID else {
                issues.append(.disconnectedRound(id))
                return nil
            }
            guard byID[parentID] != nil else {
                issues.append(.missingParent(roundID: id, parentID: parentID))
                return nil
            }
            guard let parentDepth = depth(parentID, path: path + [id]) else { return nil }
            depths[id] = parentDepth + 1
            return parentDepth + 1
        }
        for id in byID.keys { _ = depth(id, path: []) }

        let ordered = stored.sorted { lhs, rhs in
            let leftDepth = depths[lhs.session.id] ?? Int.max
            let rightDepth = depths[rhs.session.id] ?? Int.max
            if leftDepth != rightDepth { return leftDepth < rightDepth }
            if lhs.session.createdAt != rhs.session.createdAt { return lhs.session.createdAt < rhs.session.createdAt }
            return lhs.session.id.uuidString < rhs.session.id.uuidString
        }
        let promptIDs = Set(ordered.flatMap { [$0.session.promptRunID, $0.session.reviewPromptRunID].compactMap { $0 } })
        let promptRuns = try loadPromptRuns(ids: promptIDs, db: db)
        let rounds = ordered.map {
            LegacyNudgeRound(session: $0.session,
                promptRun: $0.session.promptRunID.flatMap { promptRuns[$0] },
                reviewPromptRun: $0.session.reviewPromptRunID.flatMap { promptRuns[$0] })
        }
        return LegacyNudgeChain(rootID: rootID, rounds: rounds, issues: unique(issues))
    }

    static func loadPromptRuns(ids: Set<UUID>, db: Database) throws -> [UUID: PromptRun] {
        guard !ids.isEmpty else { return [:] }
        let rows = try PromptRunRow.filter(Set(ids.map(\.uuidString)).contains(Column("id"))).fetchAll(db)
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard let run = try? row.domainModel() else { return nil }
            return (run.id, run)
        })
    }

    static func storedNudge(_ row: Row) throws -> StoredNudge {
        let rawID: String = row["id"]
        guard let id = UUID(uuidString: rawID) else {
            throw LegacyNudgeAdapterError.invalidStoredValue("single_nudge_sessions.id")
        }
        let rawLifecycle: String = row["lifecycle"]
        let rawResult: String = row["result"]
        guard let lifecycle = SingleNudgeLifecycle(rawValue: rawLifecycle),
              let result = SingleNudgeResult(rawValue: rawResult) else {
            throw LegacyNudgeAdapterError.invalidStoredValue("single_nudge_sessions.state")
        }
        let rawRoot: String? = row["root_session_id"]
        let declaredRootID = rawRoot.flatMap { UUID(uuidString: $0) } ?? id
        let rawParent: String? = row["parent_session_id"]
        if rawParent != nil, rawParent.flatMap(UUID.init(uuidString:)) == nil {
            throw LegacyNudgeAdapterError.invalidStoredValue("single_nudge_sessions.parent_session_id")
        }
        let rawPrompt: String? = row["prompt_run_id"]
        let rawReviewPrompt: String? = row["review_prompt_run_id"]
        let rawFeedback: String? = row["feedback"]
        if rawFeedback != nil, rawFeedback.flatMap(SingleNudgeFeedback.init(rawValue:)) == nil {
            throw LegacyNudgeAdapterError.invalidStoredValue("single_nudge_sessions.feedback")
        }
        let rawContinuation: String? = row["continuation_kind"]
        if rawContinuation != nil, rawContinuation.flatMap(SingleNudgeContinuationKind.init(rawValue:)) == nil {
            throw LegacyNudgeAdapterError.invalidStoredValue("single_nudge_sessions.continuation_kind")
        }
        let sourceRefsJSON: String? = row["source_refs"]
        let reviewRefsJSON: String? = row["review_source_refs"]
        let createdAt: String = row["created_at"]
        let updatedAt: String = row["updated_at"]
        let input: String = row["input"]
        let question: String? = row["question"]
        let diagnosis: String? = row["diagnosis"]
        let before: String? = row["before_text"]
        let after: String? = row["after_text"]
        let cognitiveShift: String? = row["cognitive_shift"]
        let thinkingAction: String? = row["thinking_action"]
        let unresolvedUncertainty: String? = row["unresolved_uncertainty"]
        let transitionToVerification: Bool? = row["transition_to_verification"]
        let dayKey: String = row["day_key"]
        return StoredNudge(session: SingleNudgeSession(id: id, dayKey: dayKey, input: input,
            question: question, diagnosis: diagnosis, before: before, after: after,
            cognitiveShift: cognitiveShift, thinkingAction: thinkingAction,
            unresolvedUncertainty: unresolvedUncertainty,
            transitionToVerification: transitionToVerification,
            promptRunID: rawPrompt.flatMap(UUID.init(uuidString:)),
            reviewPromptRunID: rawReviewPrompt.flatMap(UUID.init(uuidString:)),
            parentSessionID: rawParent.flatMap(UUID.init(uuidString:)), rootSessionID: declaredRootID,
            continuationKind: rawContinuation.flatMap(SingleNudgeContinuationKind.init(rawValue:)) ?? .initial,
            sourceRefs: decodeStrings(sourceRefsJSON), reviewSourceRefs: decodeStrings(reviewRefsJSON),
            lifecycle: lifecycle, result: result,
            feedback: rawFeedback.flatMap(SingleNudgeFeedback.init(rawValue:)),
            createdAt: date(createdAt), updatedAt: date(updatedAt)), declaredRootID: declaredRootID)
    }

    static func wrappedSession(rootID: UUID, db: Database) throws -> MentorSession? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM mentor_sessions WHERE origin_legacy_root_id = ?",
                                         arguments: [rootID.uuidString]) else { return nil }
        return try mentorSession(row)
    }

    static func mentorSession(_ row: Row) throws -> MentorSession {
        let rawID: String = row["id"]
        let rawLifecycle: String = row["lifecycle"]
        let rawRoot: String? = row["origin_legacy_root_id"]
        let activityAt: String = row["activity_at"]
        guard let id = UUID(uuidString: rawID), let lifecycle = MentorSessionLifecycle(rawValue: rawLifecycle),
              rawRoot == nil || UUID(uuidString: rawRoot!) != nil else {
            throw LegacyNudgeAdapterError.invalidStoredValue("mentor_sessions")
        }
        return MentorSession(id: id, initialEntry: row["initial_entry"], lifecycle: lifecycle,
            draftText: row["draft_text"], draftRevision: row["draft_revision"], activityAt: date(activityAt),
            semanticRevision: row["semantic_revision"], recallCount: row["recall_count"],
            requestEpoch: row["request_epoch"], originLegacyRootID: rawRoot.flatMap(UUID.init(uuidString:)))
    }

    static func insert(session: MentorSession, db: Database) throws {
        try db.execute(sql: """
            INSERT INTO mentor_sessions
            (id, initial_entry, lifecycle, draft_text, draft_revision, activity_at,
             semantic_revision, request_epoch, recall_count, origin_legacy_root_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [session.id.uuidString, session.initialEntry, session.lifecycle.rawValue,
                session.draftText, session.draftRevision, storageString(session.activityAt),
                session.semanticRevision, session.requestEpoch, session.recallCount,
                session.originLegacyRootID?.uuidString])
    }

    static func insertProjection(chain: LegacyNudgeChain, sessionID: UUID, db: Database) throws {
        var sequence = 0
        for round in chain.rounds {
            let reference = try MentorSourceReference("legacy-nudge:\(round.id.uuidString)")
            let input = round.session.input.trimmingCharacters(in: .whitespacesAndNewlines)
            if !input.isEmpty {
                sequence += 1
                let payload = String(decoding: try JSONEncoder().encode(["text": round.session.input]), as: UTF8.self)
                try insertItem(id: UUID(), sessionID: sessionID, sequence: sequence, kind: .user,
                    payload: payload, source: reference, sourceContent: MentorSourceResolver.legacyContent(round.session), db: db)
            }
            if let response = projectedResponse(round: round, source: reference) {
                sequence += 1
                let payload = String(decoding: try JSONEncoder().encode(response), as: UTF8.self)
                try insertItem(id: UUID(), sessionID: sessionID, sequence: sequence, kind: .assistant,
                    payload: payload, source: reference, sourceContent: MentorSourceResolver.legacyContent(round.session), db: db)
            }
        }
    }

    static func projectionItems(chain: LegacyNudgeChain, sessionID: UUID) -> [MentorTimelineItem] {
        var sequence = 0
        var result: [MentorTimelineItem] = []
        for round in chain.rounds {
            let reference = try? MentorSourceReference("legacy-nudge:\(round.id.uuidString)")
            let input = round.session.input.trimmingCharacters(in: .whitespacesAndNewlines)
            if !input.isEmpty {
                sequence += 1
                let payload = String(decoding: (try? JSONEncoder().encode(["text": round.session.input])) ?? Data("{}".utf8), as: UTF8.self)
                result.append(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: sequence,
                    kind: .user, payloadJSON: payload))
            }
            if let reference, let response = projectedResponse(round: round, source: reference),
               let payloadData = try? JSONEncoder().encode(response) {
                sequence += 1
                result.append(MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: sequence,
                    kind: .assistant, payloadJSON: String(decoding: payloadData, as: UTF8.self)))
            }
        }
        return result
    }

    static func insertItem(id: UUID, sessionID: UUID, sequence: Int, kind: MentorItemKind,
                           payload: String, source: MentorSourceReference, sourceContent: String, db: Database) throws {
        try db.execute(sql: """
            INSERT INTO mentor_items (id, session_id, sequence, kind, payload_json)
            VALUES (?, ?, ?, ?, ?)
            """, arguments: [id.uuidString, sessionID.uuidString, sequence, kind.rawValue, payload])
        let sourceID = String(source.value.dropFirst("legacy-nudge:".count))
        try db.execute(sql: """
            INSERT INTO mentor_source_links
            (id, session_id, owner_id, source_kind, source_id, owner_kind, owner_uuid, content_hash, availability)
            VALUES (?, ?, ?, 'legacy-nudge', ?, 'item', ?, ?, 'available')
            """, arguments: [UUID().uuidString, sessionID.uuidString, id.uuidString, sourceID, id.uuidString,
                MentorSourceResolver.hash(sourceContent)])
    }

    static func projectedResponse(round: LegacyNudgeRound, source: MentorSourceReference) -> MentorTurnResponse? {
        var sections: [String] = []
        func append(_ title: String, _ text: String?) {
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            sections.append("\(title)\n\(text)")
        }
        append("你当时的想法", round.session.before)
        append("当时的判断", round.session.diagnosis)
        append("你后来的回答", round.session.after)
        append("当时发生的变化", round.session.cognitiveShift)
        append("当时准备尝试", round.session.thinkingAction)
        append("仍未确定", round.session.unresolvedUncertainty)
        let question = round.session.question?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sections.isEmpty || question?.isEmpty == false else { return nil }
        return MentorTurnResponse(schemaVersion: "1.0.0", action: .explain, materialStatus: .usable,
            body: sections.isEmpty ? "这轮只保留了当时的问题。" : sections.joined(separator: "\n\n"),
            question: question?.isEmpty == false ? question : nil,
            questionPurpose: question?.isEmpty == false ? .reflection : nil,
            sourceRefs: [source], lessonRef: nil, suggestedActions: [])
    }

    static func unique(_ issues: [LegacyNudgeLineageIssue]) -> [LegacyNudgeLineageIssue] {
        var result: [LegacyNudgeLineageIssue] = []
        for issue in issues where !result.contains(issue) { result.append(issue) }
        return result
    }

    static func decodeStrings(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    static func storageString(_ date: Date) -> String {
        // Match MentorSessionRow's existing storage format so wrappers can
        // be reopened through the regular Mentor repository.
        date.formatted(basicDateStyle)
    }

    static func date(_ raw: String) -> Date {
        (try? Date(raw, strategy: fractionalDateStyle)) ?? (try? Date(raw, strategy: basicDateStyle)) ?? .distantPast
    }

    static let fractionalDateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let basicDateStyle = Date.ISO8601FormatStyle()
}
