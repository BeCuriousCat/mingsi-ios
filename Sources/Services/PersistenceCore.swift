import Foundation
import GRDB

enum PersistenceError: Error, Equatable {
    case unimplemented
    case invalidStoredValue(String)
    case validationFailed(String)
}

protocol DailyEntryRepository {
    func saveDraft(_ draft: DailyEntryDraft) async throws
    func latestDraft() async throws -> DailyEntryDraft?
    func recentEntries(limit: Int) async throws -> [DailyEntryDraft]
}

protocol ThinkingCardRepository {
    func saveCards(_ cards: [ThinkingCard], dailyEntryId: UUID) async throws
    func cards(for dailyEntryId: UUID) async throws -> [ThinkingCard]
}

protocol QuestRepository {
    func saveQuest(_ quest: Quest, sourceDailyEntryId: UUID) async throws
    func saveQuests(_ quests: [Quest], sourceDailyEntryId: UUID) async throws
    func activeMainQuest() async throws -> Quest?
    func sourceDailyEntryId(forQuestId questId: UUID) async throws -> UUID?
    func quests(for dailyEntryId: UUID) async throws -> [Quest]
    func updateQuestStatus(_ status: QuestStatus, questId: UUID) async throws
}

protocol PrincipleRepository {
    func savePrinciple(_ principle: PrincipleAsset, sourceDailyEntryId: UUID) async throws
    func savePrinciples(_ principles: [PrincipleAsset], sourceDailyEntryId: UUID) async throws
    func activePrinciples() async throws -> [PrincipleAsset]
    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset]
}

protocol VerificationRepository {
    func saveVerification(_ verification: Verification) async throws
    func latestVerification() async throws -> Verification?
    func verification(for dailyEntryId: UUID) async throws -> Verification?
    func verification(forQuestId questId: UUID) async throws -> Verification?
}

protocol LensSessionRepository {
    func saveLensSession(_ session: LensSession) async throws
    func lensSession(for dailyEntryId: UUID) async throws -> LensSession?
}

protocol ProjectRepository {
    func saveProject(_ project: Project) async throws
    func project(id: UUID) async throws -> Project?
    func activeProjects() async throws -> [Project]
}

protocol ProjectCandidateRepository {
    func saveCandidate(_ candidate: ProjectCandidate) async throws
    func candidate(id: UUID) async throws -> ProjectCandidate?
    func pendingCandidates() async throws -> [ProjectCandidate]
    func updateCandidateStatus(_ status: ProjectCandidateStatus, candidateId: UUID) async throws
}

protocol ProjectLinkRepository {
    func saveLink(_ link: ProjectLink) async throws
    func links(for projectId: UUID) async throws -> [ProjectLink]
    func links(forSourceIds sourceIds: [String]) async throws -> [ProjectLink]
    func updateLinkConfirmation(_ isConfirmed: Bool, linkId: UUID) async throws
}

protocol ProjectMergeCandidateRepository {
    func saveMergeCandidate(_ candidate: ProjectMergeCandidate) async throws
    func mergeCandidate(id: UUID) async throws -> ProjectMergeCandidate?
    func pendingMergeCandidates() async throws -> [ProjectMergeCandidate]
    func updateMergeCandidateStatus(_ status: ProjectMergeStatus, candidateId: UUID) async throws
}

protocol ProjectInsightRepository {
    func saveInsight(_ insight: ProjectInsight) async throws
    func insights(for projectId: UUID) async throws -> [ProjectInsight]
    func updateInsightFeedback(_ feedback: ProjectFeedback, insightId: UUID) async throws
}

protocol MetricSnapshotRepository {
    func saveSnapshot(_ snapshot: MetricSnapshot) async throws
    func latestSnapshot() async throws -> MetricSnapshot?
    func snapshot(id: UUID) async throws -> MetricSnapshot?
}

protocol MetricContributionRepository {
    func saveContribution(_ contribution: MetricContribution) async throws
    func contributions(for snapshotId: UUID) async throws -> [MetricContribution]
    func acceptedContributions(for snapshotId: UUID, metric: GrowthMetric) async throws -> [MetricContribution]
    func contributions(forDailyEntryId dailyEntryId: UUID) async throws -> [MetricContribution]
    func updateContributionStatus(_ status: MetricContributionStatus, contributionId: UUID) async throws
    func updateContributionFeedback(_ feedback: MetricContributionFeedback, contributionId: UUID) async throws
}

protocol PromptRunRepository {
    func savePromptRun(_ run: PromptRun) async throws
    func recentPromptRuns(limit: Int) async throws -> [PromptRun]
    func unresolvedFailures(limit: Int) async throws -> [PromptRun]
}

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        dbQueue = try DatabaseQueue(path: url.path)
        let migrator = Self.makeMigrator()
        try migrator.migrate(dbQueue)
    }

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        let migrator = Self.makeMigrator()
        try migrator.migrate(dbQueue)
    }

    static func defaultURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("mingsi.sqlite")
    }

    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_core_records") { db in
            try db.create(table: "daily_entries", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("date", .text).notNull()
                table.column("raw_text", .text).notNull()
                table.column("session_mode", .text).notNull()
                table.column("state", .text).notNull()
                table.column("privacy_flags_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "thinking_cards", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("daily_entry_id", .text).notNull()
                table.column("schema_version", .integer).notNull()
                table.column("type", .text).notNull()
                table.column("title", .text).notNull()
                table.column("body", .text).notNull()
                table.column("importance", .text).notNull()
                table.column("sensitivity", .text).notNull()
                table.column("confidence", .double).notNull()
                table.column("is_confirmed", .integer).notNull()
                table.column("is_excluded_from_model", .integer).notNull()
                table.column("source_refs_json", .text)
                table.column("raw_payload_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "quests", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("source_daily_entry_id", .text).notNull()
                table.column("schema_version", .integer).notNull()
                table.column("type", .text).notNull()
                table.column("title", .text).notNull()
                table.column("why_it_matters", .text).notNull()
                table.column("completion_criteria", .text).notNull()
                table.column("expected_resistance", .text)
                table.column("reflection_question", .text)
                table.column("status", .text).notNull()
                table.column("due_date", .text)
                table.column("reminder_id", .text)
                table.column("linked_card_ids_json", .text)
                table.column("raw_payload_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "principle_assets", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("title", .text).notNull()
                table.column("summary", .text).notNull()
                table.column("trigger_context", .text).notNull()
                table.column("actions_json", .text).notNull()
                table.column("success_criteria", .text).notNull()
                table.column("exceptions", .text)
                table.column("source_daily_entry_ids_json", .text)
                table.column("source_card_ids_json", .text)
                table.column("validation_count", .integer).notNull()
                table.column("last_validated_at", .text)
                table.column("status", .text).notNull()
                table.column("raw_payload_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "prompt_runs", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("prompt_id", .text).notNull()
                table.column("prompt_version", .text).notNull()
                table.column("input_schema_version", .integer).notNull()
                table.column("output_schema_version", .integer).notNull()
                table.column("model_provider", .text).notNull()
                table.column("model_name", .text).notNull()
                table.column("session_mode", .text).notNull()
                table.column("source_record_ids_json", .text)
                table.column("context_record_ids_json", .text)
                table.column("request_summary", .text)
                table.column("response_json", .text)
                table.column("error", .text)
                table.column("created_at", .text).notNull()
            }
        }

        migrator.registerMigration("v2_daily_loop_fields") { db in
            try db.alter(table: "daily_entries") { table in
                table.add(column: "has_selected_session_mode", .boolean).notNull().defaults(to: false)
                table.add(column: "selected_lens", .text)
                table.add(column: "yesterday_completion", .text)
                table.add(column: "yesterday_value_rating", .text)
            }
        }

        migrator.registerMigration("v3_verification_and_lens_sessions") { db in
            try db.create(table: "verifications", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("quest_id", .text).notNull()
                table.column("quest_title", .text).notNull()
                table.column("source_daily_entry_id", .text).notNull()
                table.column("completion", .text).notNull()
                table.column("value_rating", .text).notNull()
                table.column("calibration_note", .text).notNull()
                table.column("likely_issue", .text)
                table.column("recommendation", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "lens_sessions", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("daily_entry_id", .text).notNull()
                table.column("selected_lens", .text).notNull()
                table.column("questions_json", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }
        }

        migrator.registerMigration("v4_project_evidence_layer") { db in
            try db.create(table: "projects", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("name", .text).notNull()
                table.column("goal", .text).notNull()
                table.column("success_criteria", .text).notNull()
                table.column("current_bottleneck", .text)
                table.column("open_questions_json", .text)
                table.column("status", .text).notNull()
                table.column("created_by", .text).notNull()
                table.column("confidence", .double).notNull()
                table.column("merge_history_json", .text)
                table.column("field_revisions_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "project_candidates", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("suggested_name", .text).notNull()
                table.column("suggested_goal", .text)
                table.column("suggested_bottleneck", .text)
                table.column("suggested_success_criteria", .text)
                table.column("reason", .text).notNull()
                table.column("source_refs_json", .text).notNull()
                table.column("privacy_review_note", .text)
                table.column("status", .text).notNull()
                table.column("accepted_project_id", .text)
                table.column("created_by", .text).notNull()
                table.column("confidence", .double).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "project_links", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("project_id", .text).notNull()
                table.column("source_type", .text).notNull()
                table.column("source_id", .text).notNull()
                table.column("link_type", .text).notNull()
                table.column("confidence", .double).notNull()
                table.column("is_user_confirmed", .boolean).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "project_merge_candidates", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("source_project_id", .text).notNull()
                table.column("target_project_id", .text).notNull()
                table.column("reason", .text).notNull()
                table.column("overlapping_evidence_refs_json", .text)
                table.column("status", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "project_insights", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("project_id", .text).notNull()
                table.column("insight_type", .text).notNull()
                table.column("title", .text).notNull()
                table.column("summary", .text).notNull()
                table.column("before_text", .text)
                table.column("after_text", .text)
                table.column("source_refs_json", .text).notNull()
                table.column("period_start", .text)
                table.column("period_end", .text)
                table.column("confidence", .double).notNull()
                table.column("user_feedback", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }
        }

        migrator.registerMigration("v5_growth_attribution_layer") { db in
            try db.create(table: "metric_snapshots", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("period", .text).notNull()
                table.column("start_date", .text)
                table.column("end_date", .text)
                table.column("clarity", .double).notNull()
                table.column("value_judgment", .double).notNull()
                table.column("execution_reliability", .double).notNull()
                table.column("calibration", .double).notNull()
                table.column("reflection_depth", .double).notNull()
                table.column("previous_scores_json", .text)
                table.column("delta_scores_json", .text)
                table.column("metric_reasons_json", .text)
                table.column("summary", .text).notNull()
                table.column("evidence_refs_json", .text)
                table.column("positive_contribution_refs_json", .text)
                table.column("negative_contribution_refs_json", .text)
                table.column("status", .text).notNull()
                table.column("complete_loop_count", .integer).notNull().defaults(to: 0)
                table.column("next_training_focus", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "metric_contributions", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("snapshot_id", .text).notNull()
                table.column("metric", .text).notNull()
                table.column("direction", .text).notNull()
                table.column("delta", .double).notNull()
                table.column("title", .text).notNull()
                table.column("reason", .text).notNull()
                table.column("source_type", .text).notNull()
                table.column("source_id", .text).notNull()
                table.column("source_daily_entry_id", .text).notNull()
                table.column("user_feedback", .text).notNull()
                table.column("candidate_status", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }
        }

        migrator.registerMigration("v6_metric_contribution_source_entry_backfill") { db in
            let contributionColumns = Set(try db.columns(in: "metric_contributions").map(\.name))
            guard !contributionColumns.contains("source_daily_entry_id") else { return }

            try db.alter(table: "metric_contributions") { table in
                table.add(column: "source_daily_entry_id", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v7_prompt_run_context_refs") { db in
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
            guard !promptRunColumns.contains("context_record_ids_json") else { return }

            try db.alter(table: "prompt_runs") { table in
                table.add(column: "context_record_ids_json", .text)
            }

            try db.execute(sql: """
                UPDATE prompt_runs
                SET context_record_ids_json = source_record_ids_json
                WHERE context_record_ids_json IS NULL
                  AND source_record_ids_json IS NOT NULL
                """)
        }

        return migrator
    }
}

final class SQLiteDailyEntryRepository: DailyEntryRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveDraft(_ draft: DailyEntryDraft) async throws {
        try await database.dbQueue.write { db in
            var row = DailyEntryRow(draft: draft)
            if let existing = try DailyEntryRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func latestDraft() async throws -> DailyEntryDraft? {
        try await database.dbQueue.read { db in
            try DailyEntryRow
                .filter(Column("deleted_at") == nil)
                .order(Column("date").desc, Column("updated_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func recentEntries(limit: Int) async throws -> [DailyEntryDraft] {
        try await database.dbQueue.read { db in
            try DailyEntryRow
                .filter(Column("deleted_at") == nil)
                .order(Column("date").desc, Column("updated_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLiteThinkingCardRepository: ThinkingCardRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveCards(_ cards: [ThinkingCard], dailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            let now = Date().mingsiStorageString
            let savedIDs = cards.map { $0.id.uuidString }
            let existingRows = try ThinkingCardRow
                .filter(Column("daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)

            for var row in existingRows where !savedIDs.contains(row.id) {
                row.deletedAt = now
                row.updatedAt = now
                try row.upsert(db)
            }

            for card in cards {
                var row = ThinkingCardRow(card: card, dailyEntryId: dailyEntryId)
                if let existing = try ThinkingCardRow.fetchOne(db, key: row.id) {
                    row.createdAt = existing.createdAt
                }
                try row.upsert(db)
            }
        }
    }

    func cards(for dailyEntryId: UUID) async throws -> [ThinkingCard] {
        try await database.dbQueue.read { db in
            try ThinkingCardRow
                .filter(Column("daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLiteQuestRepository: QuestRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveQuest(_ quest: Quest, sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            var row = QuestRow(quest: quest, sourceDailyEntryId: sourceDailyEntryId)
            if let existing = try QuestRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func saveQuests(_ quests: [Quest], sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            let now = Date().mingsiStorageString
            let savedIDs = quests.map { $0.id.uuidString }
            let existingRows = try QuestRow
                .filter(Column("source_daily_entry_id") == sourceDailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)

            for var row in existingRows where !savedIDs.contains(row.id) {
                row.deletedAt = now
                row.updatedAt = now
                try row.upsert(db)
            }

            for quest in quests {
                var row = QuestRow(quest: quest, sourceDailyEntryId: sourceDailyEntryId)
                if let existing = try QuestRow.fetchOne(db, key: row.id) {
                    row.createdAt = existing.createdAt
                }
                try row.upsert(db)
            }
        }
    }

    func activeMainQuest() async throws -> Quest? {
        try await database.dbQueue.read { db in
            try QuestRow
                .filter(Column("type") == QuestType.main.rawValue)
                .filter(Column("status") == QuestStatus.active.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func sourceDailyEntryId(forQuestId questId: UUID) async throws -> UUID? {
        try await database.dbQueue.read { db in
            guard let row = try QuestRow
                .filter(Column("id") == questId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)
            else { return nil }
            return UUID(uuidString: row.sourceDailyEntryId)
        }
    }

    func quests(for dailyEntryId: UUID) async throws -> [Quest] {
        try await database.dbQueue.read { db in
            try QuestRow
                .filter(Column("source_daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func updateQuestStatus(_ status: QuestStatus, questId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try QuestRow.fetchOne(db, key: questId.uuidString) else { return }
            row.status = status.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

final class SQLitePrincipleRepository: PrincipleRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func savePrinciple(_ principle: PrincipleAsset, sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            var row = PrincipleAssetRow(principle: principle, sourceDailyEntryId: sourceDailyEntryId)
            if let existing = try PrincipleAssetRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func savePrinciples(_ principles: [PrincipleAsset], sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            let now = Date().mingsiStorageString
            let savedIDs = principles.map { $0.id.uuidString }
            let existingRows = try PrincipleAssetRow
                .filter(Column("source_daily_entry_ids_json").like("%\(sourceDailyEntryId.uuidString)%"))
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)

            for var row in existingRows where !savedIDs.contains(row.id) {
                row.deletedAt = now
                row.updatedAt = now
                try row.upsert(db)
            }

            for principle in principles {
                var row = PrincipleAssetRow(principle: principle, sourceDailyEntryId: sourceDailyEntryId)
                if let existing = try PrincipleAssetRow.fetchOne(db, key: row.id) {
                    row.createdAt = existing.createdAt
                }
                try row.upsert(db)
            }
        }
    }

    func activePrinciples() async throws -> [PrincipleAsset] {
        try await database.dbQueue.read { db in
            try PrincipleAssetRow
                .filter(Column("status") == PrincipleStatus.active.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset] {
        try await database.dbQueue.read { db in
            try PrincipleAssetRow
                .filter(Column("source_daily_entry_ids_json").like("%\(dailyEntryId.uuidString)%"))
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLiteVerificationRepository: VerificationRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveVerification(_ verification: Verification) async throws {
        try await database.dbQueue.write { db in
            var row = VerificationRow(verification: verification)
            if let existing = try VerificationRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func latestVerification() async throws -> Verification? {
        try await database.dbQueue.read { db in
            try VerificationRow
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func verification(for dailyEntryId: UUID) async throws -> Verification? {
        try await database.dbQueue.read { db in
            try VerificationRow
                .filter(Column("source_daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func verification(forQuestId questId: UUID) async throws -> Verification? {
        try await database.dbQueue.read { db in
            try VerificationRow
                .filter(Column("quest_id") == questId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }
}

final class SQLiteLensSessionRepository: LensSessionRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveLensSession(_ session: LensSession) async throws {
        try await database.dbQueue.write { db in
            var row = LensSessionRow(session: session)
            if let existing = try LensSessionRow
                .filter(Column("daily_entry_id") == session.dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchOne(db) {
                row.id = existing.id
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func lensSession(for dailyEntryId: UUID) async throws -> LensSession? {
        try await database.dbQueue.read { db in
            try LensSessionRow
                .filter(Column("daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }
}

final class SQLiteProjectRepository: ProjectRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveProject(_ project: Project) async throws {
        try await database.dbQueue.write { db in
            var row = ProjectRow(project: project)
            if let existing = try ProjectRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func project(id: UUID) async throws -> Project? {
        try await database.dbQueue.read { db in
            try ProjectRow
                .filter(Column("id") == id.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func activeProjects() async throws -> [Project] {
        try await database.dbQueue.read { db in
            try ProjectRow
                .filter(Column("status") == ProjectStatus.active.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLiteProjectCandidateRepository: ProjectCandidateRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveCandidate(_ candidate: ProjectCandidate) async throws {
        guard !candidate.sourceRefs.isEmpty else {
            throw PersistenceError.validationFailed("ProjectCandidate requires at least one source ref")
        }
        try await database.dbQueue.write { db in
            var row = ProjectCandidateRow(candidate: candidate)
            if let existing = try ProjectCandidateRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func candidate(id: UUID) async throws -> ProjectCandidate? {
        try await database.dbQueue.read { db in
            try ProjectCandidateRow
                .filter(Column("id") == id.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func pendingCandidates() async throws -> [ProjectCandidate] {
        try await database.dbQueue.read { db in
            try ProjectCandidateRow
                .filter(Column("status") == ProjectCandidateStatus.pending.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func updateCandidateStatus(_ status: ProjectCandidateStatus, candidateId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try ProjectCandidateRow.fetchOne(db, key: candidateId.uuidString) else { return }
            row.status = status.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

final class SQLiteProjectLinkRepository: ProjectLinkRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveLink(_ link: ProjectLink) async throws {
        guard !link.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("ProjectLink requires sourceId")
        }
        try await database.dbQueue.write { db in
            var row = ProjectLinkRow(link: link)
            if let existing = try ProjectLinkRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func links(for projectId: UUID) async throws -> [ProjectLink] {
        try await database.dbQueue.read { db in
            try ProjectLinkRow
                .filter(Column("project_id") == projectId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func links(forSourceIds sourceIds: [String]) async throws -> [ProjectLink] {
        guard !sourceIds.isEmpty else { return [] }
        return try await database.dbQueue.read { db in
            try ProjectLinkRow
                .filter(sourceIds.contains(Column("source_id")))
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func updateLinkConfirmation(_ isConfirmed: Bool, linkId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try ProjectLinkRow.fetchOne(db, key: linkId.uuidString) else { return }
            row.isUserConfirmed = isConfirmed
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

final class SQLiteProjectMergeCandidateRepository: ProjectMergeCandidateRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveMergeCandidate(_ candidate: ProjectMergeCandidate) async throws {
        try await database.dbQueue.write { db in
            var row = ProjectMergeCandidateRow(candidate: candidate)
            if let existing = try ProjectMergeCandidateRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func mergeCandidate(id: UUID) async throws -> ProjectMergeCandidate? {
        try await database.dbQueue.read { db in
            try ProjectMergeCandidateRow
                .filter(Column("id") == id.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func pendingMergeCandidates() async throws -> [ProjectMergeCandidate] {
        try await database.dbQueue.read { db in
            try ProjectMergeCandidateRow
                .filter(Column("status") == ProjectMergeStatus.pending.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func updateMergeCandidateStatus(_ status: ProjectMergeStatus, candidateId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try ProjectMergeCandidateRow.fetchOne(db, key: candidateId.uuidString) else { return }
            row.status = status.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

final class SQLiteProjectInsightRepository: ProjectInsightRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveInsight(_ insight: ProjectInsight) async throws {
        guard !insight.sourceRefs.isEmpty else {
            throw PersistenceError.validationFailed("ProjectInsight requires at least one source ref")
        }
        if insight.insightType.requiresBeforeAfterEvidence {
            guard let before = insight.beforeText?.trimmingCharacters(in: .whitespacesAndNewlines), !before.isEmpty,
                  let after = insight.afterText?.trimmingCharacters(in: .whitespacesAndNewlines), !after.isEmpty else {
                throw PersistenceError.validationFailed("\(insight.insightType.rawValue) insight requires both beforeText and afterText")
            }
        }
        try await database.dbQueue.write { db in
            var row = ProjectInsightRow(insight: insight)
            if let existing = try ProjectInsightRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func insights(for projectId: UUID) async throws -> [ProjectInsight] {
        try await database.dbQueue.read { db in
            try ProjectInsightRow
                .filter(Column("project_id") == projectId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func updateInsightFeedback(_ feedback: ProjectFeedback, insightId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try ProjectInsightRow.fetchOne(db, key: insightId.uuidString) else { return }
            row.userFeedback = feedback.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

private extension ProjectInsightType {
    var requiresBeforeAfterEvidence: Bool {
        switch self {
        case .thinkingChange, .blockerChange:
            return true
        case .progress, .openQuestionClosed, .principlePracticed, .nextBet:
            return false
        }
    }
}

private struct DailyEntryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_entries"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var date: String
    var rawText: String
    var sessionMode: String
    var hasSelectedSessionMode: Bool
    var selectedLens: String?
    var yesterdayCompletion: String?
    var yesterdayValueRating: String?
    var state: String
    var privacyFlagsJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    enum Columns {
        static let id = Column(CodingKeys.id)
    }

    init(draft: DailyEntryDraft) {
        let now = Date().mingsiStorageString
        id = draft.id.uuidString
        schemaVersion = 1
        date = draft.date.mingsiStorageString
        rawText = draft.rawText
        sessionMode = draft.sessionMode.rawValue
        hasSelectedSessionMode = draft.hasSelectedSessionMode
        selectedLens = draft.selectedLens?.rawValue
        yesterdayCompletion = draft.yesterdayCompletion?.rawValue
        yesterdayValueRating = draft.yesterdayValueRating?.rawValue
        state = draft.state.rawValue
        privacyFlagsJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> DailyEntryDraft {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("daily_entries.id")
        }
        guard let mode = SessionMode(rawValue: sessionMode) else {
            throw PersistenceError.invalidStoredValue("daily_entries.session_mode")
        }
        guard let state = DailyLoopState(rawValue: state) else {
            throw PersistenceError.invalidStoredValue("daily_entries.state")
        }
        let lens: ThinkingLens?
        if let selectedLens {
            guard let parsedLens = ThinkingLens(rawValue: selectedLens) else {
                throw PersistenceError.invalidStoredValue("daily_entries.selected_lens")
            }
            lens = parsedLens
        } else {
            lens = nil
        }
        let completion: YesterdayCompletion?
        if let yesterdayCompletion {
            guard let parsedCompletion = YesterdayCompletion(rawValue: yesterdayCompletion) else {
                throw PersistenceError.invalidStoredValue("daily_entries.yesterday_completion")
            }
            completion = parsedCompletion
        } else {
            completion = nil
        }
        let valueRating: YesterdayValueRating?
        if let yesterdayValueRating {
            guard let parsedValueRating = YesterdayValueRating(rawValue: yesterdayValueRating) else {
                throw PersistenceError.invalidStoredValue("daily_entries.yesterday_value_rating")
            }
            valueRating = parsedValueRating
        } else {
            valueRating = nil
        }
        return DailyEntryDraft(
            id: uuid,
            date: Date(mingsiStorageString: date) ?? .now,
            rawText: rawText,
            sessionMode: mode,
            hasSelectedSessionMode: hasSelectedSessionMode,
            selectedLens: lens,
            yesterdayCompletion: completion,
            yesterdayValueRating: valueRating,
            state: state
        )
    }
}

private struct ThinkingCardRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "thinking_cards"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var dailyEntryId: String
    var schemaVersion: Int
    var type: String
    var title: String
    var body: String
    var importance: String
    var sensitivity: String
    var confidence: Double
    var isConfirmed: Bool
    var isExcludedFromModel: Bool
    var sourceRefsJson: String?
    var rawPayloadJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(card: ThinkingCard, dailyEntryId: UUID) {
        let now = Date().mingsiStorageString
        id = card.id.uuidString
        self.dailyEntryId = dailyEntryId.uuidString
        schemaVersion = 1
        type = card.type.rawValue
        title = card.title
        body = card.body
        importance = card.priority.rawValue
        sensitivity = card.sensitivity.storageValue
        confidence = card.confidence
        isConfirmed = card.isConfirmed
        isExcludedFromModel = card.isExcludedFromModel
        sourceRefsJson = try? PersistenceJSON.encode(card.sourceRefs)
        rawPayloadJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> ThinkingCard {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("thinking_cards.id")
        }
        guard let type = ThinkingCardType(rawValue: type) else {
            throw PersistenceError.invalidStoredValue("thinking_cards.type")
        }
        guard let priority = PriorityLevel(rawValue: importance) else {
            throw PersistenceError.invalidStoredValue("thinking_cards.importance")
        }
        let sensitivity = SensitivityLevel(storageValue: sensitivity)
        let refs: [String] = try PersistenceJSON.decode(sourceRefsJson) ?? []
        return ThinkingCard(
            id: uuid,
            type: type,
            title: title,
            body: body,
            priority: priority,
            sensitivity: sensitivity,
            confidence: confidence,
            isConfirmed: isConfirmed,
            isExcludedFromModel: isExcludedFromModel,
            sourceRefs: refs
        )
    }
}

private struct QuestRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "quests"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var sourceDailyEntryId: String
    var schemaVersion: Int
    var type: String
    var title: String
    var whyItMatters: String
    var completionCriteria: String
    var expectedResistance: String?
    var reflectionQuestion: String?
    var status: String
    var dueDate: String?
    var reminderId: String?
    var linkedCardIdsJson: String?
    var rawPayloadJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(quest: Quest, sourceDailyEntryId: UUID) {
        let now = Date().mingsiStorageString
        id = quest.id.uuidString
        self.sourceDailyEntryId = sourceDailyEntryId.uuidString
        schemaVersion = 1
        type = quest.type.rawValue
        title = quest.title
        whyItMatters = quest.whyItMatters
        completionCriteria = quest.completionCriteria
        expectedResistance = quest.expectedResistance
        reflectionQuestion = quest.reflectionQuestion
        status = quest.status.rawValue
        dueDate = nil
        reminderId = nil
        linkedCardIdsJson = nil
        rawPayloadJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> Quest {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("quests.id")
        }
        guard let type = QuestType(rawValue: type) else {
            throw PersistenceError.invalidStoredValue("quests.type")
        }
        guard let status = QuestStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("quests.status")
        }
        return Quest(
            id: uuid,
            type: type,
            title: title,
            whyItMatters: whyItMatters,
            completionCriteria: completionCriteria,
            expectedResistance: expectedResistance ?? "",
            reflectionQuestion: reflectionQuestion ?? "",
            status: status
        )
    }
}

private struct PrincipleAssetRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "principle_assets"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var title: String
    var summary: String
    var triggerContext: String
    var actionsJson: String
    var successCriteria: String
    var exceptions: String?
    var sourceDailyEntryIdsJson: String?
    var sourceCardIdsJson: String?
    var validationCount: Int
    var lastValidatedAt: String?
    var status: String
    var rawPayloadJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(principle: PrincipleAsset, sourceDailyEntryId: UUID) {
        let now = Date().mingsiStorageString
        id = principle.id.uuidString
        schemaVersion = 1
        title = principle.title
        summary = principle.summary
        triggerContext = principle.triggerContext
        actionsJson = (try? PersistenceJSON.encode(principle.actions)) ?? "[]"
        successCriteria = principle.successCriteria
        exceptions = principle.exceptions
        sourceDailyEntryIdsJson = try? PersistenceJSON.encode([sourceDailyEntryId.uuidString])
        sourceCardIdsJson = nil
        validationCount = 0
        lastValidatedAt = nil
        status = principle.status.rawValue
        rawPayloadJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> PrincipleAsset {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("principle_assets.id")
        }
        guard let status = PrincipleStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("principle_assets.status")
        }
        let actions: [String] = try PersistenceJSON.decode(actionsJson) ?? []
        return PrincipleAsset(
            id: uuid,
            title: title,
            summary: summary,
            triggerContext: triggerContext,
            actions: actions,
            successCriteria: successCriteria,
            exceptions: exceptions ?? "",
            status: status
        )
    }
}

private struct VerificationRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "verifications"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var questId: String
    var questTitle: String
    var sourceDailyEntryId: String
    var completion: String
    var valueRating: String
    var calibrationNote: String
    var likelyIssue: String?
    var recommendation: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(verification: Verification) {
        let now = Date().mingsiStorageString
        id = verification.id.uuidString
        questId = verification.questId.uuidString
        questTitle = verification.questTitle
        sourceDailyEntryId = verification.sourceDailyEntryId.uuidString
        completion = verification.completion.rawValue
        valueRating = verification.valueRating.rawValue
        calibrationNote = verification.calibrationNote
        likelyIssue = verification.likelyIssue
        recommendation = verification.recommendation
        createdAt = verification.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> Verification {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("verifications.id")
        }
        guard let questUUID = UUID(uuidString: questId) else {
            throw PersistenceError.invalidStoredValue("verifications.quest_id")
        }
        guard let entryUUID = UUID(uuidString: sourceDailyEntryId) else {
            throw PersistenceError.invalidStoredValue("verifications.source_daily_entry_id")
        }
        guard let completion = YesterdayCompletion(rawValue: completion) else {
            throw PersistenceError.invalidStoredValue("verifications.completion")
        }
        guard let rating = YesterdayValueRating(rawValue: valueRating) else {
            throw PersistenceError.invalidStoredValue("verifications.value_rating")
        }
        return Verification(
            id: uuid,
            questId: questUUID,
            questTitle: questTitle,
            sourceDailyEntryId: entryUUID,
            completion: completion,
            valueRating: rating,
            calibrationNote: calibrationNote,
            likelyIssue: likelyIssue,
            recommendation: recommendation,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct LensSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "lens_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var dailyEntryId: String
    var selectedLens: String
    var questionsJson: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(session: LensSession) {
        let now = Date().mingsiStorageString
        id = session.id.uuidString
        dailyEntryId = session.dailyEntryId.uuidString
        selectedLens = session.selectedLens.rawValue
        questionsJson = (try? PersistenceJSON.encode(session.questions)) ?? "[]"
        createdAt = session.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> LensSession {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("lens_sessions.id")
        }
        guard let entryUUID = UUID(uuidString: dailyEntryId) else {
            throw PersistenceError.invalidStoredValue("lens_sessions.daily_entry_id")
        }
        guard let lens = ThinkingLens(rawValue: selectedLens) else {
            throw PersistenceError.invalidStoredValue("lens_sessions.selected_lens")
        }
        let questions: [ReflectionQuestion] = try PersistenceJSON.decode(questionsJson) ?? []
        return LensSession(
            id: uuid,
            dailyEntryId: entryUUID,
            selectedLens: lens,
            questions: questions,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct ProjectRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "projects"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var name: String
    var goal: String
    var successCriteria: String
    var currentBottleneck: String?
    var openQuestionsJson: String?
    var status: String
    var createdBy: String
    var confidence: Double
    var mergeHistoryJson: String?
    var fieldRevisionsJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(project: Project) {
        let now = Date().mingsiStorageString
        id = project.id.uuidString
        schemaVersion = 1
        name = project.name
        goal = project.goal
        successCriteria = project.successCriteria
        currentBottleneck = project.currentBottleneck
        openQuestionsJson = try? PersistenceJSON.encode(project.openQuestions)
        status = project.status.rawValue
        createdBy = project.createdBy.rawValue
        confidence = project.confidence
        mergeHistoryJson = try? PersistenceJSON.encode(project.mergeHistory)
        fieldRevisionsJson = try? PersistenceJSON.encode(project.fieldRevisions)
        createdAt = project.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> Project {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("projects.id")
        }
        guard let status = ProjectStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("projects.status")
        }
        guard let createdBy = ProjectCreatedBy(rawValue: createdBy) else {
            throw PersistenceError.invalidStoredValue("projects.created_by")
        }
        let openQuestions: [String] = try PersistenceJSON.decode(openQuestionsJson) ?? []
        let mergeHistory: [String] = try PersistenceJSON.decode(mergeHistoryJson) ?? []
        let fieldRevisions: [String: String] = try PersistenceJSON.decode(fieldRevisionsJson) ?? [:]
        return Project(
            id: uuid,
            name: name,
            goal: goal,
            successCriteria: successCriteria,
            currentBottleneck: currentBottleneck,
            openQuestions: openQuestions,
            status: status,
            createdBy: createdBy,
            confidence: confidence,
            mergeHistory: mergeHistory,
            fieldRevisions: fieldRevisions,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct ProjectCandidateRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_candidates"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var suggestedName: String
    var suggestedGoal: String?
    var suggestedBottleneck: String?
    var suggestedSuccessCriteria: String?
    var reason: String
    var sourceRefsJson: String
    var privacyReviewNote: String?
    var status: String
    var acceptedProjectId: String?
    var createdBy: String
    var confidence: Double
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(candidate: ProjectCandidate) {
        let now = Date().mingsiStorageString
        id = candidate.id.uuidString
        schemaVersion = 1
        suggestedName = candidate.suggestedName
        suggestedGoal = candidate.suggestedGoal
        suggestedBottleneck = candidate.suggestedBottleneck
        suggestedSuccessCriteria = candidate.suggestedSuccessCriteria
        reason = candidate.reason
        sourceRefsJson = (try? PersistenceJSON.encode(candidate.sourceRefs)) ?? "[]"
        privacyReviewNote = candidate.privacyReviewNote
        status = candidate.status.rawValue
        acceptedProjectId = candidate.acceptedProjectId?.uuidString
        createdBy = candidate.createdBy.rawValue
        confidence = candidate.confidence
        createdAt = candidate.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> ProjectCandidate {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("project_candidates.id")
        }
        let acceptedProjectUUID: UUID?
        if let acceptedProjectId {
            guard let parsed = UUID(uuidString: acceptedProjectId) else {
                throw PersistenceError.invalidStoredValue("project_candidates.accepted_project_id")
            }
            acceptedProjectUUID = parsed
        } else {
            acceptedProjectUUID = nil
        }
        guard let status = ProjectCandidateStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("project_candidates.status")
        }
        guard let createdBy = ProjectCreatedBy(rawValue: createdBy) else {
            throw PersistenceError.invalidStoredValue("project_candidates.created_by")
        }
        let sourceRefs: [String] = try PersistenceJSON.decode(sourceRefsJson) ?? []
        return ProjectCandidate(
            id: uuid,
            suggestedName: suggestedName,
            suggestedGoal: suggestedGoal,
            suggestedBottleneck: suggestedBottleneck,
            suggestedSuccessCriteria: suggestedSuccessCriteria,
            reason: reason,
            sourceRefs: sourceRefs,
            privacyReviewNote: privacyReviewNote,
            status: status,
            acceptedProjectId: acceptedProjectUUID,
            createdBy: createdBy,
            confidence: confidence,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct ProjectLinkRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_links"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var projectId: String
    var sourceType: String
    var sourceId: String
    var linkType: String
    var confidence: Double
    var isUserConfirmed: Bool
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(link: ProjectLink) {
        let now = Date().mingsiStorageString
        id = link.id.uuidString
        schemaVersion = 1
        projectId = link.projectId.uuidString
        sourceType = link.sourceType.rawValue
        sourceId = link.sourceId
        linkType = link.linkType.rawValue
        confidence = link.confidence
        isUserConfirmed = link.isUserConfirmed
        createdAt = link.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> ProjectLink {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("project_links.id")
        }
        guard let projectUUID = UUID(uuidString: projectId) else {
            throw PersistenceError.invalidStoredValue("project_links.project_id")
        }
        guard let sourceType = ProjectSourceType(rawValue: sourceType) else {
            throw PersistenceError.invalidStoredValue("project_links.source_type")
        }
        guard let linkType = ProjectLinkType(rawValue: linkType) else {
            throw PersistenceError.invalidStoredValue("project_links.link_type")
        }
        return ProjectLink(
            id: uuid,
            projectId: projectUUID,
            sourceType: sourceType,
            sourceId: sourceId,
            linkType: linkType,
            confidence: confidence,
            isUserConfirmed: isUserConfirmed,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct ProjectMergeCandidateRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_merge_candidates"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var sourceProjectId: String
    var targetProjectId: String
    var reason: String
    var overlappingEvidenceRefsJson: String?
    var status: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(candidate: ProjectMergeCandidate) {
        let now = Date().mingsiStorageString
        id = candidate.id.uuidString
        schemaVersion = 1
        sourceProjectId = candidate.sourceProjectId.uuidString
        targetProjectId = candidate.targetProjectId.uuidString
        reason = candidate.reason
        overlappingEvidenceRefsJson = try? PersistenceJSON.encode(candidate.overlappingEvidenceRefs)
        status = candidate.status.rawValue
        createdAt = candidate.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> ProjectMergeCandidate {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("project_merge_candidates.id")
        }
        guard let sourceUUID = UUID(uuidString: sourceProjectId) else {
            throw PersistenceError.invalidStoredValue("project_merge_candidates.source_project_id")
        }
        guard let targetUUID = UUID(uuidString: targetProjectId) else {
            throw PersistenceError.invalidStoredValue("project_merge_candidates.target_project_id")
        }
        guard let status = ProjectMergeStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("project_merge_candidates.status")
        }
        let refs: [String] = try PersistenceJSON.decode(overlappingEvidenceRefsJson) ?? []
        return ProjectMergeCandidate(
            id: uuid,
            sourceProjectId: sourceUUID,
            targetProjectId: targetUUID,
            reason: reason,
            overlappingEvidenceRefs: refs,
            status: status,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct ProjectInsightRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_insights"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var projectId: String
    var insightType: String
    var title: String
    var summary: String
    var beforeText: String?
    var afterText: String?
    var sourceRefsJson: String
    var periodStart: String?
    var periodEnd: String?
    var confidence: Double
    var userFeedback: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(insight: ProjectInsight) {
        let now = Date().mingsiStorageString
        id = insight.id.uuidString
        schemaVersion = 1
        projectId = insight.projectId.uuidString
        insightType = insight.insightType.rawValue
        title = insight.title
        summary = insight.summary
        beforeText = insight.beforeText
        afterText = insight.afterText
        sourceRefsJson = (try? PersistenceJSON.encode(insight.sourceRefs)) ?? "[]"
        periodStart = insight.periodStart?.mingsiStorageString
        periodEnd = insight.periodEnd?.mingsiStorageString
        confidence = insight.confidence
        userFeedback = insight.userFeedback.rawValue
        createdAt = insight.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> ProjectInsight {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("project_insights.id")
        }
        guard let projectUUID = UUID(uuidString: projectId) else {
            throw PersistenceError.invalidStoredValue("project_insights.project_id")
        }
        guard let insightType = ProjectInsightType(rawValue: insightType) else {
            throw PersistenceError.invalidStoredValue("project_insights.insight_type")
        }
        guard let feedback = ProjectFeedback(rawValue: userFeedback) else {
            throw PersistenceError.invalidStoredValue("project_insights.user_feedback")
        }
        let refs: [String] = try PersistenceJSON.decode(sourceRefsJson) ?? []
        return ProjectInsight(
            id: uuid,
            projectId: projectUUID,
            insightType: insightType,
            title: title,
            summary: summary,
            beforeText: beforeText,
            afterText: afterText,
            sourceRefs: refs,
            periodStart: periodStart.flatMap(Date.init(mingsiStorageString:)),
            periodEnd: periodEnd.flatMap(Date.init(mingsiStorageString:)),
            confidence: confidence,
            userFeedback: feedback,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

final class SQLiteMetricSnapshotRepository: MetricSnapshotRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveSnapshot(_ snapshot: MetricSnapshot) async throws {
        try await database.dbQueue.write { db in
            var row = MetricSnapshotRow(snapshot: snapshot)
            if let existing = try MetricSnapshotRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func latestSnapshot() async throws -> MetricSnapshot? {
        try await database.dbQueue.read { db in
            try MetricSnapshotRow
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func snapshot(id: UUID) async throws -> MetricSnapshot? {
        try await database.dbQueue.read { db in
            try MetricSnapshotRow
                .filter(Column("id") == id.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }
}

final class SQLiteMetricContributionRepository: MetricContributionRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveContribution(_ contribution: MetricContribution) async throws {
        guard !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("MetricContribution requires sourceId")
        }
        try await database.dbQueue.write { db in
            var row = MetricContributionRow(contribution: contribution)
            if let existing = try MetricContributionRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func contributions(for snapshotId: UUID) async throws -> [MetricContribution] {
        try await database.dbQueue.read { db in
            try MetricContributionRow
                .filter(Column("snapshot_id") == snapshotId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func acceptedContributions(for snapshotId: UUID, metric: GrowthMetric) async throws -> [MetricContribution] {
        try await database.dbQueue.read { db in
            try MetricContributionRow
                .filter(Column("snapshot_id") == snapshotId.uuidString)
                .filter(Column("metric") == metric.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
                .filter(\.isAcceptedForTrend)
        }
    }

    func contributions(forDailyEntryId dailyEntryId: UUID) async throws -> [MetricContribution] {
        try await database.dbQueue.read { db in
            try MetricContributionRow
                .filter(Column("source_daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
                .filter(\.isAcceptedForTrend)
        }
    }

    func updateContributionStatus(_ status: MetricContributionStatus, contributionId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try MetricContributionRow.fetchOne(db, key: contributionId.uuidString) else { return }
            row.candidateStatus = status.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }

    func updateContributionFeedback(_ feedback: MetricContributionFeedback, contributionId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try MetricContributionRow.fetchOne(db, key: contributionId.uuidString) else { return }
            row.userFeedback = feedback.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

final class SQLitePromptRunRepository: PromptRunRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func savePromptRun(_ run: PromptRun) async throws {
        try await database.dbQueue.write { db in
            try PromptRunRow(run: run).upsert(db)
        }
    }

    func recentPromptRuns(limit: Int) async throws -> [PromptRun] {
        try await database.dbQueue.read { db in
            try PromptRunRow
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func unresolvedFailures(limit: Int) async throws -> [PromptRun] {
        try await database.dbQueue.read { db in
            let rows = try PromptRunRow
                .order(Column("created_at").desc)
                .limit(max(limit * 6, limit))
                .fetchAll(db)

            var resolvedKeys: Set<String> = []
            var failures: [PromptRun] = []

            for row in rows {
                let key = row.resolutionKey
                if row.responseJson != nil, row.error == nil {
                    resolvedKeys.insert(key)
                    continue
                }

                if row.responseJson == nil, row.error != nil, !resolvedKeys.contains(key) {
                    failures.append(try row.domainModel())
                    if failures.count >= limit {
                        break
                    }
                }
            }

            return failures
        }
    }
}

private extension MetricSnapshot {
    var previousScoresStorage: [String: Double] {
        var scores: [String: Double] = [:]
        scores[GrowthMetric.clarity.rawValue] = previousClarity
        scores[GrowthMetric.valueJudgment.rawValue] = previousValueJudgment
        scores[GrowthMetric.executionReliability.rawValue] = previousExecutionReliability
        scores[GrowthMetric.calibration.rawValue] = previousCalibration
        scores[GrowthMetric.reflectionDepth.rawValue] = previousReflectionDepth
        return scores
    }

    var deltaScoresStorage: [String: Double] {
        var scores: [String: Double] = [:]
        scores[GrowthMetric.clarity.rawValue] = clarityDelta
        scores[GrowthMetric.valueJudgment.rawValue] = valueJudgmentDelta
        scores[GrowthMetric.executionReliability.rawValue] = executionReliabilityDelta
        scores[GrowthMetric.calibration.rawValue] = calibrationDelta
        scores[GrowthMetric.reflectionDepth.rawValue] = reflectionDepthDelta
        return scores
    }
}

private struct MetricSnapshotRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "metric_snapshots"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var period: String
    var startDate: String?
    var endDate: String?
    var clarity: Double
    var valueJudgment: Double
    var executionReliability: Double
    var calibration: Double
    var reflectionDepth: Double
    var previousScoresJson: String?
    var deltaScoresJson: String?
    var metricReasonsJson: String?
    var summary: String
    var evidenceRefsJson: String?
    var positiveContributionRefsJson: String?
    var negativeContributionRefsJson: String?
    var status: String
    var completeLoopCount: Int
    var nextTrainingFocus: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(snapshot: MetricSnapshot) {
        let now = Date().mingsiStorageString
        id = snapshot.id.uuidString
        schemaVersion = 1
        period = snapshot.period
        startDate = snapshot.startDate?.mingsiStorageString
        endDate = snapshot.endDate?.mingsiStorageString
        clarity = snapshot.clarity
        valueJudgment = snapshot.valueJudgment
        executionReliability = snapshot.executionReliability
        calibration = snapshot.calibration
        reflectionDepth = snapshot.reflectionDepth
        previousScoresJson = try? PersistenceJSON.encode(snapshot.previousScoresStorage)
        deltaScoresJson = try? PersistenceJSON.encode(snapshot.deltaScoresStorage)
        metricReasonsJson = try? PersistenceJSON.encode(snapshot.metricReasons)
        summary = snapshot.summary
        evidenceRefsJson = try? PersistenceJSON.encode(snapshot.evidenceRefs)
        positiveContributionRefsJson = try? PersistenceJSON.encode(snapshot.positiveContributionRefs)
        negativeContributionRefsJson = try? PersistenceJSON.encode(snapshot.negativeContributionRefs)
        status = snapshot.status.rawValue
        completeLoopCount = snapshot.completeLoopCount
        nextTrainingFocus = snapshot.nextTrainingFocus
        createdAt = snapshot.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> MetricSnapshot {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("metric_snapshots.id")
        }
        guard let status = MetricSnapshotStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("metric_snapshots.status")
        }
        let previousScores: [String: Double] = try PersistenceJSON.decode(previousScoresJson) ?? [:]
        let deltaScores: [String: Double] = try PersistenceJSON.decode(deltaScoresJson) ?? [:]
        let metricReasons: [String: String] = try PersistenceJSON.decode(metricReasonsJson) ?? [:]
        let refs: [String] = try PersistenceJSON.decode(evidenceRefsJson) ?? []
        let positiveRefs: [String] = try PersistenceJSON.decode(positiveContributionRefsJson) ?? []
        let negativeRefs: [String] = try PersistenceJSON.decode(negativeContributionRefsJson) ?? []
        return MetricSnapshot(
            id: uuid,
            period: period,
            startDate: startDate.flatMap(Date.init(mingsiStorageString:)),
            endDate: endDate.flatMap(Date.init(mingsiStorageString:)),
            clarity: clarity,
            valueJudgment: valueJudgment,
            executionReliability: executionReliability,
            calibration: calibration,
            reflectionDepth: reflectionDepth,
            previousClarity: previousScores[GrowthMetric.clarity.rawValue],
            previousValueJudgment: previousScores[GrowthMetric.valueJudgment.rawValue],
            previousExecutionReliability: previousScores[GrowthMetric.executionReliability.rawValue],
            previousCalibration: previousScores[GrowthMetric.calibration.rawValue],
            previousReflectionDepth: previousScores[GrowthMetric.reflectionDepth.rawValue],
            clarityDelta: deltaScores[GrowthMetric.clarity.rawValue],
            valueJudgmentDelta: deltaScores[GrowthMetric.valueJudgment.rawValue],
            executionReliabilityDelta: deltaScores[GrowthMetric.executionReliability.rawValue],
            calibrationDelta: deltaScores[GrowthMetric.calibration.rawValue],
            reflectionDepthDelta: deltaScores[GrowthMetric.reflectionDepth.rawValue],
            summary: summary,
            metricReasons: metricReasons,
            evidenceRefs: refs,
            positiveContributionRefs: positiveRefs,
            negativeContributionRefs: negativeRefs,
            status: status,
            completeLoopCount: completeLoopCount,
            nextTrainingFocus: nextTrainingFocus,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct MetricContributionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "metric_contributions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var snapshotId: String
    var metric: String
    var direction: String
    var delta: Double
    var title: String
    var reason: String
    var sourceType: String
    var sourceId: String
    var sourceDailyEntryId: String
    var userFeedback: String
    var candidateStatus: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(contribution: MetricContribution) {
        let now = Date().mingsiStorageString
        id = contribution.id.uuidString
        schemaVersion = 1
        snapshotId = contribution.snapshotId.uuidString
        metric = contribution.metric.rawValue
        direction = contribution.direction.rawValue
        delta = contribution.delta
        title = contribution.title
        reason = contribution.reason
        sourceType = contribution.sourceType.rawValue
        sourceId = contribution.sourceId
        sourceDailyEntryId = contribution.sourceDailyEntryId.uuidString
        userFeedback = contribution.userFeedback.rawValue
        candidateStatus = contribution.candidateStatus.rawValue
        createdAt = contribution.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> MetricContribution {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.id")
        }
        guard let snapshotUUID = UUID(uuidString: snapshotId) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.snapshot_id")
        }
        guard let metric = GrowthMetric(rawValue: metric) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.metric")
        }
        guard let dir = MetricContributionDirection(rawValue: direction) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.direction")
        }
        guard let sourceType = MetricContributionSourceType(rawValue: sourceType) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.source_type")
        }
        guard let sourceDailyEntryUUID = UUID(uuidString: sourceDailyEntryId) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.source_daily_entry_id")
        }
        guard let feedback = MetricContributionFeedback(rawValue: userFeedback) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.user_feedback")
        }
        guard let candidateStatus = MetricContributionStatus(rawValue: candidateStatus) else {
            throw PersistenceError.invalidStoredValue("metric_contributions.candidate_status")
        }
        return MetricContribution(
            id: uuid,
            snapshotId: snapshotUUID,
            metric: metric,
            direction: dir,
            delta: delta,
            title: title,
            reason: reason,
            sourceType: sourceType,
            sourceId: sourceId,
            sourceDailyEntryId: sourceDailyEntryUUID,
            userFeedback: feedback,
            candidateStatus: candidateStatus,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct PromptRunRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompt_runs"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var promptId: String
    var promptVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var modelProvider: String
    var modelName: String
    var sessionMode: String
    var sourceRecordIdsJson: String?
    var contextRecordIdsJson: String?
    var requestSummary: String?
    var responseJson: String?
    var error: String?
    var createdAt: String

    var resolutionKey: String {
        [
            promptId,
            promptVersion,
            modelProvider,
            modelName,
            sessionMode,
            sourceRecordIdsJson ?? "",
            contextRecordIdsJson ?? ""
        ].joined(separator: "|")
    }

    init(run: PromptRun) {
        id = run.id.uuidString
        schemaVersion = run.schemaVersion
        promptId = run.promptId
        promptVersion = run.promptVersion
        inputSchemaVersion = run.inputSchemaVersion
        outputSchemaVersion = run.outputSchemaVersion
        modelProvider = run.modelProvider
        modelName = run.modelName
        sessionMode = run.sessionMode
        sourceRecordIdsJson = try? PersistenceJSON.encode(run.sourceRecordIds)
        contextRecordIdsJson = try? PersistenceJSON.encode(run.contextRecordIds)
        requestSummary = run.requestSummary
        responseJson = run.responseJSON
        error = run.error
        createdAt = run.createdAt.mingsiStorageString
    }

    func domainModel() throws -> PromptRun {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("prompt_runs.id")
        }
        let sourceIds: [String] = try PersistenceJSON.decode(sourceRecordIdsJson) ?? []
        let contextIds: [String] = try PersistenceJSON.decode(contextRecordIdsJson) ?? sourceIds
        return PromptRun(
            id: uuid,
            schemaVersion: schemaVersion,
            promptId: promptId,
            promptVersion: promptVersion,
            inputSchemaVersion: inputSchemaVersion,
            outputSchemaVersion: outputSchemaVersion,
            modelProvider: modelProvider,
            modelName: modelName,
            sessionMode: sessionMode,
            sourceRecordIds: sourceIds,
            contextRecordIds: contextIds,
            requestSummary: requestSummary ?? "",
            responseJSON: responseJson,
            error: error,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now
        )
    }
}

private enum PersistenceJSON {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.invalidStoredValue("json_encoding")
        }
        return string
    }

    static func decode<T: Decodable>(_ json: String?) throws -> T? {
        guard let json, !json.isEmpty else { return nil }
        guard let data = json.data(using: .utf8) else {
            throw PersistenceError.invalidStoredValue("json_decoding")
        }
        return try decoder.decode(T.self, from: data)
    }

    static func decode<T: Decodable>(_ json: String) throws -> T? {
        try decode(Optional(json))
    }
}

private extension Date {
    static let mingsiStorageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var mingsiStorageString: String {
        Self.mingsiStorageFormatter.string(from: self)
    }

    init?(mingsiStorageString: String) {
        guard let date = Self.mingsiStorageFormatter.date(from: mingsiStorageString) else {
            return nil
        }
        self = date
    }
}

private extension SensitivityLevel {
    var storageValue: String {
        switch self {
        case .normal: return "normal"
        case .possiblySensitive: return "possibly_sensitive"
        case .sensitive: return "sensitive"
        }
    }

    init(storageValue: String) {
        switch storageValue {
        case "possibly_sensitive":
            self = .possiblySensitive
        case "sensitive":
            self = .sensitive
        default:
            self = .normal
        }
    }
}
