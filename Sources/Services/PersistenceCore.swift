import CryptoKit
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
    func allPrinciples() async throws -> [PrincipleAsset]
    func activePrinciples() async throws -> [PrincipleAsset]
    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset]
    func updatePrinciple(_ principle: PrincipleAsset) async throws
    func updatePrincipleStatus(_ status: PrincipleStatus, principleId: UUID) async throws
    func deletePrinciple(_ principleId: UUID) async throws
}

protocol PrincipleRecallFeedbackRepository {
    func saveFeedback(_ feedback: PrincipleRecallFeedback) async throws
    func feedback(for principleId: UUID, limit: Int) async throws -> [PrincipleRecallFeedback]
}

protocol PrinciplePracticeEvidenceRepository {
    func saveEvidence(_ evidence: PrinciplePracticeEvidence) async throws
    func evidence(for principleId: UUID, limit: Int) async throws -> [PrinciplePracticeEvidence]
    func evidence(
        for principleId: UUID,
        sourceDailyEntryId: UUID,
        questId: UUID,
        evidenceSource: PrinciplePracticeEvidenceSource
    ) async throws -> PrinciplePracticeEvidence?
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
    func updatePromptRunFeedback(_ feedback: PromptRunFeedback, runId: UUID) async throws
    func promptRunStats(limit: Int) async throws -> PromptRunStats
    func promptAssetRunQualitySummaries(limit: Int) async throws -> [PromptAssetRunQualitySummary]
}

protocol PromptEvalRunRepository {
    func saveEvalRun(_ run: PromptEvalRun) async throws
    func recentEvalRuns(limit: Int) async throws -> [PromptEvalRun]
}

enum PromptAssetSelectionReason: String, Codable, Equatable {
    case rollback
}

struct PromptAssetSelection: Equatable {
    var promptId: PromptID
    var selectedVersion: String
    var baseVersion: String
    var reason: PromptAssetSelectionReason
    var createdAt: Date
    var updatedAt: Date

    init(
        promptId: PromptID,
        selectedVersion: String,
        baseVersion: String,
        reason: PromptAssetSelectionReason,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.promptId = promptId
        self.selectedVersion = selectedVersion
        self.baseVersion = baseVersion
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

protocol PromptAssetSelectionRepository {
    func saveSelection(_ selection: PromptAssetSelection) async throws
    func allSelections() async throws -> [PromptAssetSelection]
}

protocol PromptAssetPackRepository {
    func savePack(_ pack: PromptAssetPack) async throws
    func allPacks() async throws -> [PromptAssetPack]
    func enabledPacks() async throws -> [PromptAssetPack]
}

protocol LensAssetPackRepository {
    func savePack(_ pack: LensAssetPack) async throws
    func allPacks() async throws -> [LensAssetPack]
    func enabledPacks() async throws -> [LensAssetPack]
}

struct AssetPackTrustPolicyRecord: Equatable {
    var id: String
    var sourceURL: URL?
    var document: AssetPackTrustPolicyDocument
    var createdAt: Date
    var updatedAt: Date
}

protocol AssetPackTrustPolicyRepository {
    func saveDocument(_ document: AssetPackTrustPolicyDocument, sourceURL: URL?) async throws
    func allDocuments() async throws -> [AssetPackTrustPolicyRecord]
}

protocol AssetPackRegistrySubscriptionRepository {
    func saveSubscription(_ subscription: AssetPackRegistrySubscription) async throws
    func allSubscriptions() async throws -> [AssetPackRegistrySubscription]
    func enabledSubscriptions() async throws -> [AssetPackRegistrySubscription]
    func recordSyncResult(
        subscriptionId: String,
        status: AssetPackRegistrySyncStatus,
        message: String,
        syncedAt: Date
    ) async throws
}

struct DataExportPackage: Equatable {
    var data: Data
    var counts: [String: Int]
    var createdAt: Date

    var summary: String {
        DataExportSectionName.allCases
            .map { "\($0.rawValue): \(counts[$0.rawValue, default: 0])" }
            .joined(separator: " · ")
    }
}

protocol DataExportRepository {
    func exportJSON() async throws -> Data
    func exportPackage() async throws -> DataExportPackage
}

protocol HistoricalRetryCandidateRepository {
    func saveCandidate(_ candidate: HistoricalRetryCandidate) async throws
    func candidate(id: UUID) async throws -> HistoricalRetryCandidate?
    func candidates(for sourceDailyEntryId: UUID) async throws -> [HistoricalRetryCandidate]
    func attachRepairRun(_ repairPromptRunId: UUID, candidatePayloadJSON: String, to candidateId: UUID) async throws
    func updateStatus(
        _ status: HistoricalRetryCandidateStatus,
        candidateId: UUID,
        error: String?,
        blockedReason: String?
    ) async throws
    func softDelete(candidateId: UUID) async throws
}

extension HistoricalRetryCandidateRepository {
    func updateStatus(
        _ status: HistoricalRetryCandidateStatus,
        candidateId: UUID,
        blockedReason: String?
    ) async throws {
        try await updateStatus(status, candidateId: candidateId, error: nil, blockedReason: blockedReason)
    }

    func updateStatus(
        _ status: HistoricalRetryCandidateStatus,
        candidateId: UUID,
        error: String?
    ) async throws {
        try await updateStatus(status, candidateId: candidateId, error: error, blockedReason: nil)
    }
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
                table.column("prompt_source_kind", .text).notNull().defaults(to: PromptAssetSourceKind.builtin.rawValue)
                table.column("prompt_pack_id", .text).notNull().defaults(to: "mingsi.builtin.prompts")
                table.column("prompt_pack_version", .text).notNull().defaults(to: "builtin.v1")
                table.column("prompt_pack_display_name", .text).notNull().defaults(to: "MingSi Built-in Prompt Pack")
                table.column("system_policy_version", .text).notNull().defaults(to: "system.v1")
                table.column("context_policy_version", .text).notNull().defaults(to: "context.v1")
                table.column("input_schema_version", .integer).notNull()
                table.column("output_schema_version", .integer).notNull()
                table.column("eval_suite_version", .text).notNull().defaults(to: "eval.v1")
                table.column("rollback_target_version", .text)
                table.column("model_provider", .text).notNull()
                table.column("model_name", .text).notNull()
                table.column("session_mode", .text).notNull()
                table.column("source_record_ids_json", .text)
                table.column("context_record_ids_json", .text)
                table.column("request_summary", .text)
                table.column("response_json", .text)
                table.column("error", .text)
                table.column("user_feedback", .text).notNull().defaults(to: PromptRunFeedback.none.rawValue)
                table.column("created_at", .text).notNull()
            }
        }

        migrator.registerMigration("v2_daily_loop_fields") { db in
            try db.alter(table: "daily_entries") { table in
                table.add(column: "has_selected_session_mode", .boolean).notNull().defaults(to: false)
                table.add(column: "selected_lens", .text)
                table.add(column: "selected_custom_lens_id", .text)
                table.add(column: "custom_lens_items_json", .text)
                table.add(column: "custom_lens_questions_json", .text)
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

        migrator.registerMigration("v8_historical_retry_candidates") { db in
            try db.create(table: "historical_retry_candidates", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("failed_prompt_run_id", .text).notNull()
                table.column("repair_prompt_run_id", .text)
                table.column("prompt_id", .text).notNull()
                table.column("source_daily_entry_id", .text).notNull()
                table.column("status", .text).notNull()
                table.column("reconstructed_input_summary", .text).notNull()
                table.column("candidate_payload_json", .text)
                table.column("error", .text)
                table.column("blocked_reason", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_historical_retry_candidates_source_daily_entry_id",
                on: "historical_retry_candidates",
                columns: ["source_daily_entry_id"]
            )
            try db.create(
                index: "idx_historical_retry_candidates_failed_prompt_run_id",
                on: "historical_retry_candidates",
                columns: ["failed_prompt_run_id"]
            )
            try db.create(
                index: "idx_historical_retry_candidates_status",
                on: "historical_retry_candidates",
                columns: ["status"]
            )
            try db.create(
                index: "idx_historical_retry_candidates_updated_at",
                on: "historical_retry_candidates",
                columns: ["updated_at"]
            )
        }

        migrator.registerMigration("v9_daily_entry_custom_lens_id") { db in
            let dailyEntryColumns = Set(try db.columns(in: "daily_entries").map(\.name))
            guard !dailyEntryColumns.contains("selected_custom_lens_id") else { return }

            try db.alter(table: "daily_entries") { table in
                table.add(column: "selected_custom_lens_id", .text)
            }
        }

        migrator.registerMigration("v10_daily_entry_custom_lens_items") { db in
            let dailyEntryColumns = Set(try db.columns(in: "daily_entries").map(\.name))
            guard !dailyEntryColumns.contains("custom_lens_items_json") else { return }

            try db.alter(table: "daily_entries") { table in
                table.add(column: "custom_lens_items_json", .text)
            }
        }

        migrator.registerMigration("v11_daily_entry_custom_lens_questions") { db in
            let dailyEntryColumns = Set(try db.columns(in: "daily_entries").map(\.name))
            guard !dailyEntryColumns.contains("custom_lens_questions_json") else { return }

            try db.alter(table: "daily_entries") { table in
                table.add(column: "custom_lens_questions_json", .text)
            }
        }

        migrator.registerMigration("v12_prompt_run_asset_versions") { db in
            guard try db.tableExists("prompt_runs") else { return }
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))

            try db.alter(table: "prompt_runs") { table in
                if !promptRunColumns.contains("system_policy_version") {
                    table.add(column: "system_policy_version", .text).notNull().defaults(to: "system.v1")
                }
                if !promptRunColumns.contains("context_policy_version") {
                    table.add(column: "context_policy_version", .text).notNull().defaults(to: "context.v1")
                }
                if !promptRunColumns.contains("eval_suite_version") {
                    table.add(column: "eval_suite_version", .text).notNull().defaults(to: "eval.v1")
                }
                if !promptRunColumns.contains("rollback_target_version") {
                    table.add(column: "rollback_target_version", .text)
                }
            }
        }

        migrator.registerMigration("v13_prompt_run_feedback") { db in
            guard try db.tableExists("prompt_runs") else { return }
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
            guard !promptRunColumns.contains("user_feedback") else { return }

            try db.alter(table: "prompt_runs") { table in
                table.add(column: "user_feedback", .text).notNull().defaults(to: PromptRunFeedback.none.rawValue)
            }
        }

        migrator.registerMigration("v14_principle_recall_feedback") { db in
            try db.create(table: "principle_recall_feedback", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("principle_id", .text).notNull()
                table.column("prompt_run_id", .text)
                table.column("source_daily_entry_id", .text)
                table.column("prompt_id", .text).notNull()
                table.column("retrieval_policy_version", .text).notNull()
                table.column("retrieval_reason", .text).notNull()
                table.column("feedback", .text).notNull()
                table.column("note", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_principle_recall_feedback_principle_id",
                on: "principle_recall_feedback",
                columns: ["principle_id"]
            )
            try db.create(
                index: "idx_principle_recall_feedback_prompt_run_id",
                on: "principle_recall_feedback",
                columns: ["prompt_run_id"]
            )
            try db.create(
                index: "idx_principle_recall_feedback_feedback",
                on: "principle_recall_feedback",
                columns: ["feedback"]
            )
        }

        migrator.registerMigration("v15_principle_practice_evidence") { db in
            try db.create(table: "principle_practice_evidence", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("principle_id", .text).notNull()
                table.column("source_daily_entry_id", .text).notNull()
                table.column("quest_id", .text)
                table.column("verification_id", .text)
                table.column("evidence_source", .text).notNull()
                table.column("strength", .text).notNull()
                table.column("evidence_summary", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_principle_practice_evidence_principle_id",
                on: "principle_practice_evidence",
                columns: ["principle_id"]
            )
            try db.create(
                index: "idx_principle_practice_evidence_source_daily_entry_id",
                on: "principle_practice_evidence",
                columns: ["source_daily_entry_id"]
            )
            try db.create(
                index: "idx_principle_practice_evidence_strength",
                on: "principle_practice_evidence",
                columns: ["strength"]
            )
        }

        migrator.registerMigration("v16_prompt_eval_runs") { db in
            try db.create(table: "prompt_eval_runs", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("prompt_id", .text).notNull()
                table.column("prompt_version", .text).notNull()
                table.column("prompt_source_kind", .text).notNull().defaults(to: PromptAssetSourceKind.builtin.rawValue)
                table.column("prompt_pack_id", .text).notNull().defaults(to: "mingsi.builtin.prompts")
                table.column("prompt_pack_version", .text).notNull().defaults(to: "builtin.v1")
                table.column("prompt_pack_display_name", .text).notNull().defaults(to: "MingSi Built-in Prompt Pack")
                table.column("system_policy_version", .text).notNull()
                table.column("context_policy_version", .text).notNull()
                table.column("input_schema_version", .integer).notNull()
                table.column("output_schema_version", .integer).notNull()
                table.column("eval_suite_version", .text).notNull()
                table.column("runner_version", .text).notNull()
                table.column("status", .text).notNull()
                table.column("total_case_count", .integer).notNull()
                table.column("passed_case_count", .integer).notNull()
                table.column("failed_case_count", .integer).notNull()
                table.column("case_results_json", .text).notNull()
                table.column("created_at", .text).notNull()
            }

            try db.create(
                index: "idx_prompt_eval_runs_prompt_id",
                on: "prompt_eval_runs",
                columns: ["prompt_id"]
            )
            try db.create(
                index: "idx_prompt_eval_runs_eval_suite_version",
                on: "prompt_eval_runs",
                columns: ["eval_suite_version"]
            )
            try db.create(
                index: "idx_prompt_eval_runs_created_at",
                on: "prompt_eval_runs",
                columns: ["created_at"]
            )
        }

        migrator.registerMigration("v17_prompt_asset_selections") { db in
            try db.create(table: "prompt_asset_selections", ifNotExists: true) { table in
                table.column("prompt_id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("selected_version", .text).notNull()
                table.column("base_version", .text).notNull()
                table.column("reason", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_prompt_asset_selections_updated_at",
                on: "prompt_asset_selections",
                columns: ["updated_at"]
            )
        }

        migrator.registerMigration("v18_lens_asset_packs") { db in
            try db.create(table: "lens_asset_packs", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("version", .text).notNull()
                table.column("display_name", .text).notNull()
                table.column("source_kind", .text).notNull()
                table.column("is_enabled", .integer).notNull()
                table.column("items_json", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_lens_asset_packs_source_kind",
                on: "lens_asset_packs",
                columns: ["source_kind"]
            )
            try db.create(
                index: "idx_lens_asset_packs_enabled",
                on: "lens_asset_packs",
                columns: ["is_enabled"]
            )
            try db.create(
                index: "idx_lens_asset_packs_updated_at",
                on: "lens_asset_packs",
                columns: ["updated_at"]
            )
        }

        migrator.registerMigration("v19_prompt_asset_packs") { db in
            try db.create(table: "prompt_asset_packs", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("version", .text).notNull()
                table.column("display_name", .text).notNull()
                table.column("source_kind", .text).notNull()
                table.column("is_enabled", .integer).notNull()
                table.column("templates_json", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_prompt_asset_packs_source_kind",
                on: "prompt_asset_packs",
                columns: ["source_kind"]
            )
            try db.create(
                index: "idx_prompt_asset_packs_enabled",
                on: "prompt_asset_packs",
                columns: ["is_enabled"]
            )
            try db.create(
                index: "idx_prompt_asset_packs_updated_at",
                on: "prompt_asset_packs",
                columns: ["updated_at"]
            )
        }

        migrator.registerMigration("v20_asset_pack_trust_metadata") { db in
            try db.alter(table: "prompt_asset_packs") { table in
                table.add(column: "trust_metadata_json", .text)
            }
            try db.alter(table: "lens_asset_packs") { table in
                table.add(column: "trust_metadata_json", .text)
            }
        }

        migrator.registerMigration("v21_prompt_asset_pack_provenance") { db in
            if try db.tableExists("prompt_runs") {
                let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
                try db.alter(table: "prompt_runs") { table in
                    if !promptRunColumns.contains("prompt_source_kind") {
                        table.add(column: "prompt_source_kind", .text)
                            .notNull()
                            .defaults(to: PromptAssetSourceKind.builtin.rawValue)
                    }
                    if !promptRunColumns.contains("prompt_pack_id") {
                        table.add(column: "prompt_pack_id", .text)
                            .notNull()
                            .defaults(to: "mingsi.builtin.prompts")
                    }
                    if !promptRunColumns.contains("prompt_pack_version") {
                        table.add(column: "prompt_pack_version", .text)
                            .notNull()
                            .defaults(to: "builtin.v1")
                    }
                    if !promptRunColumns.contains("prompt_pack_display_name") {
                        table.add(column: "prompt_pack_display_name", .text)
                            .notNull()
                            .defaults(to: "MingSi Built-in Prompt Pack")
                    }
                }
            }

            if try db.tableExists("prompt_eval_runs") {
                let evalRunColumns = Set(try db.columns(in: "prompt_eval_runs").map(\.name))
                try db.alter(table: "prompt_eval_runs") { table in
                    if !evalRunColumns.contains("prompt_source_kind") {
                        table.add(column: "prompt_source_kind", .text)
                            .notNull()
                            .defaults(to: PromptAssetSourceKind.builtin.rawValue)
                    }
                    if !evalRunColumns.contains("prompt_pack_id") {
                        table.add(column: "prompt_pack_id", .text)
                            .notNull()
                            .defaults(to: "mingsi.builtin.prompts")
                    }
                    if !evalRunColumns.contains("prompt_pack_version") {
                        table.add(column: "prompt_pack_version", .text)
                            .notNull()
                            .defaults(to: "builtin.v1")
                    }
                    if !evalRunColumns.contains("prompt_pack_display_name") {
                        table.add(column: "prompt_pack_display_name", .text)
                            .notNull()
                            .defaults(to: "MingSi Built-in Prompt Pack")
                    }
                }
            }
        }

        migrator.registerMigration("v22_asset_pack_trust_policies") { db in
            try db.create(table: "asset_pack_trust_policies", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("source_url", .text)
                table.column("document_json", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_asset_pack_trust_policies_source_url",
                on: "asset_pack_trust_policies",
                columns: ["source_url"]
            )
            try db.create(
                index: "idx_asset_pack_trust_policies_updated_at",
                on: "asset_pack_trust_policies",
                columns: ["updated_at"]
            )
        }

        migrator.registerMigration("v23_asset_pack_registry_subscriptions") { db in
            try db.create(table: "asset_pack_registry_subscriptions", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("display_name", .text).notNull()
                table.column("catalog_url", .text).notNull()
                table.column("sync_policy_version", .text).notNull()
                table.column("is_enabled", .integer).notNull()
                table.column("last_synced_at", .text)
                table.column("last_sync_status", .text).notNull()
                table.column("last_sync_message", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(
                index: "idx_asset_pack_registry_subscriptions_enabled",
                on: "asset_pack_registry_subscriptions",
                columns: ["is_enabled"]
            )
            try db.create(
                index: "idx_asset_pack_registry_subscriptions_updated_at",
                on: "asset_pack_registry_subscriptions",
                columns: ["updated_at"]
            )
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

    func allPrinciples() async throws -> [PrincipleAsset] {
        try await database.dbQueue.read { db in
            try PrincipleAssetRow
                .filter(Column("status") != PrincipleStatus.archived.rawValue)
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
                .filter(Column("status") != PrincipleStatus.archived.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func updatePrinciple(_ principle: PrincipleAsset) async throws {
        try await database.dbQueue.write { db in
            guard var row = try PrincipleAssetRow.fetchOne(db, key: principle.id.uuidString) else { return }
            row.title = principle.title
            row.summary = principle.summary
            row.triggerContext = principle.triggerContext
            row.actionsJson = (try? PersistenceJSON.encode(principle.actions)) ?? "[]"
            row.successCriteria = principle.successCriteria
            row.exceptions = principle.exceptions
            row.status = principle.status.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }

    func updatePrincipleStatus(_ status: PrincipleStatus, principleId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try PrincipleAssetRow.fetchOne(db, key: principleId.uuidString) else { return }
            row.status = status.rawValue
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }

    func deletePrinciple(_ principleId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try PrincipleAssetRow.fetchOne(db, key: principleId.uuidString) else { return }
            let now = Date().mingsiStorageString
            row.updatedAt = now
            row.deletedAt = now
            try row.upsert(db)

            var feedbackRows = try PrincipleRecallFeedbackRow
                .filter(Column("principle_id") == principleId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)
            for index in feedbackRows.indices {
                feedbackRows[index].updatedAt = now
                feedbackRows[index].deletedAt = now
                try feedbackRows[index].upsert(db)
            }

            var evidenceRows = try PrinciplePracticeEvidenceRow
                .filter(Column("principle_id") == principleId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)
            for index in evidenceRows.indices {
                evidenceRows[index].updatedAt = now
                evidenceRows[index].deletedAt = now
                try evidenceRows[index].upsert(db)
            }
        }
    }
}

final class SQLitePrincipleRecallFeedbackRepository: PrincipleRecallFeedbackRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveFeedback(_ feedback: PrincipleRecallFeedback) async throws {
        try await database.dbQueue.write { db in
            var row = PrincipleRecallFeedbackRow(feedback: feedback)
            if let existing = try PrincipleRecallFeedbackRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func feedback(for principleId: UUID, limit: Int) async throws -> [PrincipleRecallFeedback] {
        try await database.dbQueue.read { db in
            try PrincipleRecallFeedbackRow
                .filter(Column("principle_id") == principleId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLitePrinciplePracticeEvidenceRepository: PrinciplePracticeEvidenceRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveEvidence(_ evidence: PrinciplePracticeEvidence) async throws {
        try await database.dbQueue.write { db in
            var row = PrinciplePracticeEvidenceRow(evidence: evidence)
            if let existing = try PrinciplePracticeEvidenceRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func evidence(for principleId: UUID, limit: Int) async throws -> [PrinciplePracticeEvidence] {
        try await database.dbQueue.read { db in
            try PrinciplePracticeEvidenceRow
                .filter(Column("principle_id") == principleId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func evidence(
        for principleId: UUID,
        sourceDailyEntryId: UUID,
        questId: UUID,
        evidenceSource: PrinciplePracticeEvidenceSource
    ) async throws -> PrinciplePracticeEvidence? {
        try await database.dbQueue.read { db in
            try PrinciplePracticeEvidenceRow
                .filter(Column("principle_id") == principleId.uuidString)
                .filter(Column("source_daily_entry_id") == sourceDailyEntryId.uuidString)
                .filter(Column("quest_id") == questId.uuidString)
                .filter(Column("evidence_source") == evidenceSource.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").desc)
                .fetchOne(db)?
                .domainModel()
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
    var selectedCustomLensId: String?
    var customLensItemsJson: String?
    var customLensQuestionsJson: String?
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
        selectedCustomLensId = draft.selectedCustomLensId
        customLensItemsJson = try? PersistenceJSON.encode(draft.customLensItems)
        customLensQuestionsJson = try? PersistenceJSON.encode(draft.customLensQuestions)
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
        let customLensItems: [LensCatalogItem] = try PersistenceJSON.decode(customLensItemsJson) ?? []
        let customLensQuestions: [ReflectionQuestion] = try PersistenceJSON.decode(customLensQuestionsJson) ?? []
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
            selectedCustomLensId: selectedCustomLensId,
            customLensItems: customLensItems,
            customLensQuestions: customLensQuestions,
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

private struct PrincipleRecallFeedbackRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "principle_recall_feedback"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var principleId: String
    var promptRunId: String?
    var sourceDailyEntryId: String?
    var promptId: String
    var retrievalPolicyVersion: String
    var retrievalReason: String
    var feedback: String
    var note: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(feedback: PrincipleRecallFeedback) {
        let now = Date().mingsiStorageString
        id = feedback.id.uuidString
        schemaVersion = feedback.schemaVersion
        principleId = feedback.principleId.uuidString
        promptRunId = feedback.promptRunId?.uuidString
        sourceDailyEntryId = feedback.sourceDailyEntryId?.uuidString
        promptId = feedback.promptId.rawValue
        retrievalPolicyVersion = feedback.retrievalPolicyVersion
        retrievalReason = feedback.retrievalReason
        self.feedback = feedback.feedback.rawValue
        note = feedback.note
        createdAt = feedback.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> PrincipleRecallFeedback {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("principle_recall_feedback.id")
        }
        guard let principleUUID = UUID(uuidString: principleId) else {
            throw PersistenceError.invalidStoredValue("principle_recall_feedback.principle_id")
        }
        let promptRunUUID = try promptRunId.map { value in
            guard let uuid = UUID(uuidString: value) else {
                throw PersistenceError.invalidStoredValue("principle_recall_feedback.prompt_run_id")
            }
            return uuid
        }
        let sourceEntryUUID = try sourceDailyEntryId.map { value in
            guard let uuid = UUID(uuidString: value) else {
                throw PersistenceError.invalidStoredValue("principle_recall_feedback.source_daily_entry_id")
            }
            return uuid
        }
        guard let prompt = PromptID(rawValue: promptId) else {
            throw PersistenceError.invalidStoredValue("principle_recall_feedback.prompt_id")
        }
        guard let feedbackValue = PrincipleRecallFeedbackValue(rawValue: feedback) else {
            throw PersistenceError.invalidStoredValue("principle_recall_feedback.feedback")
        }
        return PrincipleRecallFeedback(
            id: uuid,
            schemaVersion: schemaVersion,
            principleId: principleUUID,
            promptRunId: promptRunUUID,
            sourceDailyEntryId: sourceEntryUUID,
            promptId: prompt,
            retrievalPolicyVersion: retrievalPolicyVersion,
            retrievalReason: retrievalReason,
            feedback: feedbackValue,
            note: note,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct PrinciplePracticeEvidenceRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "principle_practice_evidence"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var principleId: String
    var sourceDailyEntryId: String
    var questId: String?
    var verificationId: String?
    var evidenceSource: String
    var strength: String
    var evidenceSummary: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(evidence: PrinciplePracticeEvidence) {
        let now = Date().mingsiStorageString
        id = evidence.id.uuidString
        schemaVersion = evidence.schemaVersion
        principleId = evidence.principleId.uuidString
        sourceDailyEntryId = evidence.sourceDailyEntryId.uuidString
        questId = evidence.questId?.uuidString
        verificationId = evidence.verificationId?.uuidString
        evidenceSource = evidence.evidenceSource.rawValue
        strength = evidence.strength.rawValue
        evidenceSummary = evidence.evidenceSummary
        createdAt = evidence.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> PrinciplePracticeEvidence {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("principle_practice_evidence.id")
        }
        guard let principleUUID = UUID(uuidString: principleId) else {
            throw PersistenceError.invalidStoredValue("principle_practice_evidence.principle_id")
        }
        guard let sourceEntryUUID = UUID(uuidString: sourceDailyEntryId) else {
            throw PersistenceError.invalidStoredValue("principle_practice_evidence.source_daily_entry_id")
        }
        let questUUID = try questId.map { value in
            guard let uuid = UUID(uuidString: value) else {
                throw PersistenceError.invalidStoredValue("principle_practice_evidence.quest_id")
            }
            return uuid
        }
        let verificationUUID = try verificationId.map { value in
            guard let uuid = UUID(uuidString: value) else {
                throw PersistenceError.invalidStoredValue("principle_practice_evidence.verification_id")
            }
            return uuid
        }
        guard let source = PrinciplePracticeEvidenceSource(rawValue: evidenceSource) else {
            throw PersistenceError.invalidStoredValue("principle_practice_evidence.evidence_source")
        }
        guard let strength = PrinciplePracticeEvidenceStrength(rawValue: strength) else {
            throw PersistenceError.invalidStoredValue("principle_practice_evidence.strength")
        }
        return PrinciplePracticeEvidence(
            id: uuid,
            schemaVersion: schemaVersion,
            principleId: principleUUID,
            sourceDailyEntryId: sourceEntryUUID,
            questId: questUUID,
            verificationId: verificationUUID,
            evidenceSource: source,
            strength: strength,
            evidenceSummary: evidenceSummary,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
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

    func updatePromptRunFeedback(_ feedback: PromptRunFeedback, runId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try PromptRunRow.fetchOne(db, key: runId.uuidString) else { return }
            row.userFeedback = feedback.rawValue
            try row.upsert(db)
        }
    }

    func promptRunStats(limit: Int) async throws -> PromptRunStats {
        try await database.dbQueue.read { db in
            let rows = try PromptRunRow
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
            let total = rows.count
            let failures = rows.filter { $0.responseJson == nil && $0.error != nil }
            let emptyResults = failures.filter { row in
                guard let error = row.error?.lowercased() else { return false }
                return error.contains("emptyresult") || error.contains("empty result")
            }
            let denied = rows.filter { $0.userFeedback == PromptRunFeedback.denied.rawValue }
            return PromptRunStats(
                totalCount: total,
                successCount: rows.filter { $0.responseJson != nil && $0.error == nil }.count,
                failureCount: failures.count,
                emptyResultCount: emptyResults.count,
                userDeniedCount: denied.count
            )
        }
    }

    func promptAssetRunQualitySummaries(limit: Int) async throws -> [PromptAssetRunQualitySummary] {
        try await database.dbQueue.read { db in
            let runs = try PromptRunRow
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { try $0.domainModel() }
            return PromptAssetRunQualitySummary.summaries(for: runs)
        }
    }
}

final class SQLitePromptEvalRunRepository: PromptEvalRunRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveEvalRun(_ run: PromptEvalRun) async throws {
        try await database.dbQueue.write { db in
            try PromptEvalRunRow(run: run).upsert(db)
        }
    }

    func recentEvalRuns(limit: Int) async throws -> [PromptEvalRun] {
        try await database.dbQueue.read { db in
            try PromptEvalRunRow
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLitePromptAssetSelectionRepository: PromptAssetSelectionRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveSelection(_ selection: PromptAssetSelection) async throws {
        guard !selection.selectedVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetSelection requires selectedVersion")
        }
        guard !selection.baseVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetSelection requires baseVersion")
        }
        try await database.dbQueue.write { db in
            var row = PromptAssetSelectionRow(selection: selection)
            if let existing = try PromptAssetSelectionRow.fetchOne(db, key: selection.promptId.rawValue) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func allSelections() async throws -> [PromptAssetSelection] {
        try await database.dbQueue.read { db in
            try PromptAssetSelectionRow
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLitePromptAssetPackRepository: PromptAssetPackRepository {
    private let database: AppDatabase
    private let signatureVerifier: AssetPackSignatureVerifier

    init(
        database: AppDatabase,
        signatureVerifier: AssetPackSignatureVerifier = .default
    ) {
        self.database = database
        self.signatureVerifier = signatureVerifier
    }

    func savePack(_ pack: PromptAssetPack) async throws {
        try await savePack(pack, signatureVerifier: signatureVerifier)
    }

    func savePack(
        _ pack: PromptAssetPack,
        signatureVerifier: AssetPackSignatureVerifier
    ) async throws {
        guard !pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetPack requires id")
        }
        guard !pack.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetPack requires version")
        }
        guard !pack.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetPack requires displayName")
        }
        guard !pack.templates.isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetPack requires at least one template")
        }
        try Self.validateTrustMetadata(pack, signatureVerifier: signatureVerifier)

        try await database.dbQueue.write { db in
            var row = try PromptAssetPackRow(pack: pack)
            if let existing = try PromptAssetPackRow.fetchOne(db, key: pack.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func allPacks() async throws -> [PromptAssetPack] {
        try await database.dbQueue.read { db in
            try PromptAssetPackRow
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func enabledPacks() async throws -> [PromptAssetPack] {
        try await enabledPacks(signatureVerifier: signatureVerifier)
    }

    func enabledPacks(signatureVerifier: AssetPackSignatureVerifier) async throws -> [PromptAssetPack] {
        try await database.dbQueue.read { db in
            try PromptAssetPackRow
                .filter(Column("deleted_at") == nil)
                .filter(Column("is_enabled") == 1)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
                .filter { Self.canUseAsRuntimePack($0, signatureVerifier: signatureVerifier) }
        }
    }

    private static func validateTrustMetadata(
        _ pack: PromptAssetPack,
        signatureVerifier: AssetPackSignatureVerifier
    ) throws {
        guard let metadata = pack.trustMetadata else {
            if pack.sourceKind.requiresTrustMetadata {
                throw PersistenceError.validationFailed("PromptAssetPack requires trust metadata for external sources")
            }
            return
        }

        let missingFields = metadata.missingRequiredFields
        guard missingFields.isEmpty else {
            throw PersistenceError.validationFailed("PromptAssetPack trust metadata missing \(missingFields.joined(separator: ", "))")
        }

        if pack.sourceKind.requiresTrustMetadata {
            guard try AssetPackIntegrity.hasValidContentHash(pack) else {
                throw PersistenceError.validationFailed("PromptAssetPack trust metadata contentHash does not match pack contents")
            }
            guard try signatureVerifier.hasValidSignature(pack) else {
                throw PersistenceError.validationFailed("PromptAssetPack trust metadata signature is invalid")
            }
        }
    }

    private static func canUseAsRuntimePack(
        _ pack: PromptAssetPack,
        signatureVerifier: AssetPackSignatureVerifier
    ) -> Bool {
        guard pack.sourceKind.requiresTrustMetadata else { return true }
        guard let metadata = pack.trustMetadata else { return false }
        guard metadata.missingRequiredFields.isEmpty else { return false }
        guard (try? AssetPackIntegrity.hasValidContentHash(pack)) == true else { return false }
        return (try? signatureVerifier.hasValidSignature(pack)) == true
    }
}

final class SQLiteLensAssetPackRepository: LensAssetPackRepository {
    private let database: AppDatabase
    private let signatureVerifier: AssetPackSignatureVerifier

    init(
        database: AppDatabase,
        signatureVerifier: AssetPackSignatureVerifier = .default
    ) {
        self.database = database
        self.signatureVerifier = signatureVerifier
    }

    func savePack(_ pack: LensAssetPack) async throws {
        try await savePack(pack, signatureVerifier: signatureVerifier)
    }

    func savePack(
        _ pack: LensAssetPack,
        signatureVerifier: AssetPackSignatureVerifier
    ) async throws {
        guard !pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires id")
        }
        guard !pack.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires version")
        }
        guard !pack.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires displayName")
        }
        try Self.validateTrustMetadata(pack, signatureVerifier: signatureVerifier)

        try await database.dbQueue.write { db in
            var row = try LensAssetPackRow(pack: pack)
            if let existing = try LensAssetPackRow.fetchOne(db, key: pack.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func allPacks() async throws -> [LensAssetPack] {
        try await database.dbQueue.read { db in
            try LensAssetPackRow
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func enabledPacks() async throws -> [LensAssetPack] {
        try await enabledPacks(signatureVerifier: signatureVerifier)
    }

    func enabledPacks(signatureVerifier: AssetPackSignatureVerifier) async throws -> [LensAssetPack] {
        try await database.dbQueue.read { db in
            try LensAssetPackRow
                .filter(Column("deleted_at") == nil)
                .filter(Column("is_enabled") == 1)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
                .filter { Self.canUseAsRuntimePack($0, signatureVerifier: signatureVerifier) }
        }
    }

    private static func validateTrustMetadata(
        _ pack: LensAssetPack,
        signatureVerifier: AssetPackSignatureVerifier
    ) throws {
        guard let metadata = pack.trustMetadata else {
            if pack.sourceKind.requiresTrustMetadata {
                throw PersistenceError.validationFailed("LensAssetPack requires trust metadata for external sources")
            }
            return
        }

        let missingFields = metadata.missingRequiredFields
        guard missingFields.isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack trust metadata missing \(missingFields.joined(separator: ", "))")
        }

        if pack.sourceKind.requiresTrustMetadata {
            guard try AssetPackIntegrity.hasValidContentHash(pack) else {
                throw PersistenceError.validationFailed("LensAssetPack trust metadata contentHash does not match pack contents")
            }
            guard try signatureVerifier.hasValidSignature(pack) else {
                throw PersistenceError.validationFailed("LensAssetPack trust metadata signature is invalid")
            }
        }
    }

    private static func canUseAsRuntimePack(
        _ pack: LensAssetPack,
        signatureVerifier: AssetPackSignatureVerifier
    ) -> Bool {
        guard pack.sourceKind.requiresTrustMetadata else { return true }
        guard let metadata = pack.trustMetadata else { return false }
        guard metadata.missingRequiredFields.isEmpty else { return false }
        guard (try? AssetPackIntegrity.hasValidContentHash(pack)) == true else { return false }
        return (try? signatureVerifier.hasValidSignature(pack)) == true
    }
}

final class SQLiteAssetPackTrustPolicyRepository: AssetPackTrustPolicyRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveDocument(_ document: AssetPackTrustPolicyDocument, sourceURL: URL?) async throws {
        let rowId = try Self.id(for: sourceURL, document: document)
        try await database.dbQueue.write { db in
            var row = try AssetPackTrustPolicyRow(
                id: rowId,
                sourceURL: sourceURL,
                document: document
            )
            if let existing = try AssetPackTrustPolicyRow.fetchOne(db, key: rowId) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func allDocuments() async throws -> [AssetPackTrustPolicyRecord] {
        try await database.dbQueue.read { db in
            try AssetPackTrustPolicyRow
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    private static func id(for sourceURL: URL?, document: AssetPackTrustPolicyDocument) throws -> String {
        if let sourceURL {
            return sourceURL.absoluteString
        }

        let documentJSON = try PersistenceJSON.encode(document)
        let digest = SHA256.hash(data: Data(documentJSON.utf8))
        return "inline:" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

final class SQLiteAssetPackRegistrySubscriptionRepository: AssetPackRegistrySubscriptionRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveSubscription(_ subscription: AssetPackRegistrySubscription) async throws {
        guard !subscription.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("AssetPackRegistrySubscription requires id")
        }
        guard !subscription.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("AssetPackRegistrySubscription requires displayName")
        }
        guard subscription.catalogURL.scheme != nil else {
            throw PersistenceError.validationFailed("AssetPackRegistrySubscription requires absolute catalogURL")
        }

        try await database.dbQueue.write { db in
            var row = AssetPackRegistrySubscriptionRow(subscription: subscription)
            if let existing = try AssetPackRegistrySubscriptionRow.fetchOne(db, key: subscription.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func allSubscriptions() async throws -> [AssetPackRegistrySubscription] {
        try await database.dbQueue.read { db in
            try AssetPackRegistrySubscriptionRow
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func enabledSubscriptions() async throws -> [AssetPackRegistrySubscription] {
        try await database.dbQueue.read { db in
            try AssetPackRegistrySubscriptionRow
                .filter(Column("deleted_at") == nil)
                .filter(Column("is_enabled") == 1)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func recordSyncResult(
        subscriptionId: String,
        status: AssetPackRegistrySyncStatus,
        message: String,
        syncedAt: Date
    ) async throws {
        try await database.dbQueue.write { db in
            guard var row = try AssetPackRegistrySubscriptionRow.fetchOne(db, key: subscriptionId) else { return }
            row.lastSyncedAt = syncedAt.mingsiStorageString
            row.lastSyncStatus = status.rawValue
            row.lastSyncMessage = message
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }
}

struct AssetPackSignatureVerifier {
    private struct BuiltInVerificationPolicy {
        let trustedPublisherPublicKeys: [String: [String]]
        let revokedPublisherIds: Set<String>

        init(
            trustedPublisherPublicKeys: [String: [String]],
            revokedPublisherIds: Set<String>
        ) {
            self.trustedPublisherPublicKeys = trustedPublisherPublicKeys
            self.revokedPublisherIds = revokedPublisherIds
        }

        init(
            trustedPublisherPublicKeys: [String: String],
            revokedPublisherIds: Set<String>
        ) {
            self.trustedPublisherPublicKeys = trustedPublisherPublicKeys.mapValues { [$0] }
            self.revokedPublisherIds = revokedPublisherIds
        }

        func publicKeys(for publisherId: String) -> [String] {
            guard !revokedPublisherIds.contains(publisherId) else { return [] }
            return trustedPublisherPublicKeys[publisherId] ?? []
        }
    }

    private static let signaturePrefix = "p256-sha256:"
    private static let testPublisherPublicKey = "3TmqtDQiTBTbdQHJZnqdMNkGY/JYqivqOrPDddCt9wIm01rcx/P0Dm5oLHvDYqA0vuPueGqGmYW+uunV17nuxw=="
    private static let rotatedPublisherPublicKey = "oWMff09DdO3X4j8sTNyVyvkyBPwE1u92V6uWUXwja11I+NWsO9JcXodn+3AKjS5V79HtI/FVX3fObaehVz7zKw=="
    private static let verificationPolicies: [String: BuiltInVerificationPolicy] = [
        "asset-trust.test.v1": BuiltInVerificationPolicy(
            trustedPublisherPublicKeys: [
                "mingsi.test.publisher": testPublisherPublicKey
            ],
            revokedPublisherIds: []
        ),
        "asset-trust.test.revoked.v1": BuiltInVerificationPolicy(
            trustedPublisherPublicKeys: [
                "mingsi.test.publisher": testPublisherPublicKey
            ],
            revokedPublisherIds: ["mingsi.test.publisher"]
        ),
        "asset-trust.test.rotated.v1": BuiltInVerificationPolicy(
            trustedPublisherPublicKeys: [
                "mingsi.test.publisher": [
                    testPublisherPublicKey,
                    rotatedPublisherPublicKey
                ]
            ],
            revokedPublisherIds: []
        )
    ]

    static let `default` = AssetPackSignatureVerifier(
        publicKeysForPublisher: { publisherId, verificationPolicyVersion in
            verificationPolicies[verificationPolicyVersion]?.publicKeys(for: publisherId) ?? []
        }
    )

    static func combining(_ verifiers: [AssetPackSignatureVerifier]) -> AssetPackSignatureVerifier {
        AssetPackSignatureVerifier(
            publicKeysForPublisher: { publisherId, verificationPolicyVersion in
                verifiers.flatMap {
                    $0.publicKeyStrings(
                        for: publisherId,
                        verificationPolicyVersion: verificationPolicyVersion
                    )
                }
            }
        )
    }

    private let publicKeysForPublisher: (String, String) -> [String]

    init(publicKeyForPublisher: @escaping (String, String) -> String?) {
        self.publicKeysForPublisher = { publisherId, verificationPolicyVersion in
            publicKeyForPublisher(publisherId, verificationPolicyVersion).map { [$0] } ?? []
        }
    }

    init(publicKeysForPublisher: @escaping (String, String) -> [String]) {
        self.publicKeysForPublisher = publicKeysForPublisher
    }

    func hasValidSignature(_ pack: PromptAssetPack) throws -> Bool {
        guard let metadata = pack.trustMetadata else { return false }
        return try hasValidSignature(metadata: metadata, signedPayload: AssetPackIntegrity.signaturePayload(for: pack))
    }

    func hasValidSignature(_ pack: LensAssetPack) throws -> Bool {
        guard let metadata = pack.trustMetadata else { return false }
        return try hasValidSignature(metadata: metadata, signedPayload: AssetPackIntegrity.signaturePayload(for: pack))
    }

    func publicKeyStrings(
        for publisherId: String,
        verificationPolicyVersion: String
    ) -> [String] {
        publicKeysForPublisher(publisherId, verificationPolicyVersion)
    }

    private func hasValidSignature(
        metadata: AssetTrustMetadata,
        signedPayload: Data
    ) throws -> Bool {
        guard metadata.signature.hasPrefix(Self.signaturePrefix),
              let signatureData = Data(base64Encoded: String(metadata.signature.dropFirst(Self.signaturePrefix.count)))
        else {
            return false
        }

        let publicKeys = try publicKeys(
                for: metadata.publisherId,
                verificationPolicyVersion: metadata.verificationPolicyVersion
        )
        guard !publicKeys.isEmpty else {
            return false
        }

        let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKeys.contains { $0.isValidSignature(signature, for: signedPayload) }
    }

    private func publicKeys(
        for publisherId: String,
        verificationPolicyVersion: String
    ) throws -> [P256.Signing.PublicKey] {
        try publicKeysForPublisher(publisherId, verificationPolicyVersion).compactMap { publicKeyBase64 in
            guard let publicKeyData = Data(base64Encoded: publicKeyBase64) else { return nil }
            return try P256.Signing.PublicKey(rawRepresentation: publicKeyData)
        }
    }
}

struct AssetPackTrustPolicySignatureVerifier {
    private struct BuiltInVerificationPolicy {
        let trustedRegistryPublicKeys: [String: [String]]

        init(trustedRegistryPublicKeys: [String: [String]]) {
            self.trustedRegistryPublicKeys = trustedRegistryPublicKeys
        }

        func publicKeys(for registryId: String) -> [String] {
            trustedRegistryPublicKeys[registryId] ?? []
        }
    }

    private static let signaturePrefix = "p256-sha256:"
    private static let testRegistryRootPublicKey = "VBEHsDDSoPIZMUwMi5RsxnVESPHEinFu9F+4GQh/uuJF7KAJzPPQmjY/Z5uhG1fhjEe6shSs6wW2xWz6sXHmxQ=="
    private static let verificationPolicies: [String: BuiltInVerificationPolicy] = [
        "asset-trust-policy-root.test.v1": BuiltInVerificationPolicy(
            trustedRegistryPublicKeys: [
                "mingsi.test.registry": [testRegistryRootPublicKey]
            ]
        )
    ]

    static let `default` = AssetPackTrustPolicySignatureVerifier(
        publicKeysForRegistry: { registryId, verificationPolicyVersion in
            verificationPolicies[verificationPolicyVersion]?.publicKeys(for: registryId) ?? []
        }
    )

    private let publicKeysForRegistry: (String, String) -> [String]

    init(publicKeysForRegistry: @escaping (String, String) -> [String]) {
        self.publicKeysForRegistry = publicKeysForRegistry
    }

    func hasValidSignature(_ document: AssetPackTrustPolicyDocument) throws -> Bool {
        guard let metadata = document.trustMetadata,
              metadata.missingRequiredFields.isEmpty,
              metadata.contentHash.hasPrefix("sha256:")
        else {
            return false
        }
        guard metadata.contentHash == (try AssetPackIntegrity.expectedContentHash(for: document)) else {
            return false
        }
        return try hasValidSignature(metadata: metadata, signedPayload: AssetPackIntegrity.signaturePayload(for: document))
    }

    private func hasValidSignature(
        metadata: AssetTrustMetadata,
        signedPayload: Data
    ) throws -> Bool {
        guard metadata.signature.hasPrefix(Self.signaturePrefix),
              let signatureData = Data(base64Encoded: String(metadata.signature.dropFirst(Self.signaturePrefix.count)))
        else {
            return false
        }

        let publicKeys = try publicKeys(
            for: metadata.publisherId,
            verificationPolicyVersion: metadata.verificationPolicyVersion
        )
        guard !publicKeys.isEmpty else {
            return false
        }

        let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKeys.contains { $0.isValidSignature(signature, for: signedPayload) }
    }

    private func publicKeys(
        for registryId: String,
        verificationPolicyVersion: String
    ) throws -> [P256.Signing.PublicKey] {
        try publicKeysForRegistry(registryId, verificationPolicyVersion).compactMap { publicKeyBase64 in
            guard let publicKeyData = Data(base64Encoded: publicKeyBase64) else { return nil }
            return try P256.Signing.PublicKey(rawRepresentation: publicKeyData)
        }
    }
}

struct AssetPackTrustPolicy: Codable, Equatable {
    var version: String
    var trustedPublisherPublicKeys: [String: [String]]
    var revokedPublisherIds: [String]

    init(
        version: String,
        trustedPublisherPublicKeys: [String: [String]],
        revokedPublisherIds: [String] = []
    ) {
        self.version = version
        self.trustedPublisherPublicKeys = trustedPublisherPublicKeys
        self.revokedPublisherIds = revokedPublisherIds
    }

    func publicKeys(for publisherId: String) -> [String] {
        guard !Set(revokedPublisherIds).contains(publisherId) else { return [] }
        return trustedPublisherPublicKeys[publisherId] ?? []
    }
}

struct AssetPackTrustPolicyDocument: Codable, Equatable {
    var policies: [AssetPackTrustPolicy]
    var expiresAt: Date?
    var trustMetadata: AssetTrustMetadata?

    init(
        policies: [AssetPackTrustPolicy],
        expiresAt: Date? = nil,
        trustMetadata: AssetTrustMetadata? = nil
    ) {
        self.policies = policies
        self.expiresAt = expiresAt
        self.trustMetadata = trustMetadata
    }

    func isExpired(at now: Date = .now) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }

    var hasValidTrustSignature: Bool {
        (try? AssetPackTrustPolicySignatureVerifier.default.hasValidSignature(self)) == true
    }

    var signatureVerifier: AssetPackSignatureVerifier {
        guard !isExpired(), hasValidTrustSignature else {
            return AssetPackSignatureVerifier(publicKeysForPublisher: { _, _ in [] })
        }

        let policiesByVersion = policies.reduce(into: [String: AssetPackTrustPolicy]()) { result, policy in
            result[policy.version] = policy
        }
        return AssetPackSignatureVerifier(
            publicKeysForPublisher: { publisherId, verificationPolicyVersion in
                policiesByVersion[verificationPolicyVersion]?.publicKeys(for: publisherId) ?? []
            }
        )
    }
}

struct AssetPackRegistryCatalog: Codable, Equatable {
    var version: String
    var entries: [AssetPackRegistryCatalogEntry]

    init(version: String, entries: [AssetPackRegistryCatalogEntry] = []) {
        self.version = version
        self.entries = entries
    }
}

struct AssetPackRegistryCatalogEntry: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var summary: String
    var manifestURL: URL
    var updatedAt: Date?
    var publisherId: String?
    var publisherDisplayName: String?
    var trustPolicyURL: URL?
    var requiredVerificationPolicyVersion: String?

    init(
        id: String,
        displayName: String,
        summary: String,
        manifestURL: URL,
        updatedAt: Date? = nil,
        publisherId: String? = nil,
        publisherDisplayName: String? = nil,
        trustPolicyURL: URL? = nil,
        requiredVerificationPolicyVersion: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.manifestURL = manifestURL
        self.updatedAt = updatedAt
        self.publisherId = publisherId
        self.publisherDisplayName = publisherDisplayName
        self.trustPolicyURL = trustPolicyURL
        self.requiredVerificationPolicyVersion = requiredVerificationPolicyVersion
    }

    func sourceURL(baseURL: URL) -> URL {
        guard manifestURL.scheme == nil else { return manifestURL }
        return URL(string: manifestURL.relativeString, relativeTo: baseURL)?.absoluteURL ?? manifestURL
    }

    func trustPolicySourceURL(baseURL: URL) -> URL? {
        guard let trustPolicyURL else { return nil }
        guard trustPolicyURL.scheme == nil else { return trustPolicyURL }
        return URL(string: trustPolicyURL.relativeString, relativeTo: baseURL)?.absoluteURL ?? trustPolicyURL
    }
}

enum AssetPackRegistrySyncStatus: String, Codable, Equatable, Identifiable {
    case neverSynced = "never_synced"
    case succeeded
    case failed

    var id: String { rawValue }
}

struct AssetPackRegistrySubscription: Codable, Equatable, Identifiable {
    static let currentSyncPolicyVersion = "asset-pack-registry-sync.v1"

    var id: String
    var schemaVersion: Int
    var displayName: String
    var catalogURL: URL
    var syncPolicyVersion: String
    var isEnabled: Bool
    var lastSyncedAt: Date?
    var lastSyncStatus: AssetPackRegistrySyncStatus
    var lastSyncMessage: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        schemaVersion: Int = 1,
        displayName: String,
        catalogURL: URL,
        syncPolicyVersion: String = Self.currentSyncPolicyVersion,
        isEnabled: Bool = true,
        lastSyncedAt: Date? = nil,
        lastSyncStatus: AssetPackRegistrySyncStatus = .neverSynced,
        lastSyncMessage: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.displayName = displayName
        self.catalogURL = catalogURL
        self.syncPolicyVersion = syncPolicyVersion
        self.isEnabled = isEnabled
        self.lastSyncedAt = lastSyncedAt
        self.lastSyncStatus = lastSyncStatus
        self.lastSyncMessage = lastSyncMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AssetPackRegistrySubscriptionSyncSchedulePolicy: Hashable {
    var minimumSyncInterval: TimeInterval

    init(minimumSyncInterval: TimeInterval = 24 * 60 * 60) {
        self.minimumSyncInterval = minimumSyncInterval
    }

    func dueSubscriptions(
        _ subscriptions: [AssetPackRegistrySubscription],
        now: Date = .now
    ) -> [AssetPackRegistrySubscription] {
        subscriptions.filter { isDue($0, now: now) }
    }

    private func isDue(_ subscription: AssetPackRegistrySubscription, now: Date) -> Bool {
        guard subscription.isEnabled else { return false }
        if subscription.syncPolicyVersion != AssetPackRegistrySubscription.currentSyncPolicyVersion {
            return true
        }
        if subscription.lastSyncStatus == .neverSynced || subscription.lastSyncedAt == nil {
            return true
        }
        guard minimumSyncInterval > 0,
              let lastSyncedAt = subscription.lastSyncedAt
        else { return false }
        return now.timeIntervalSince(lastSyncedAt) >= minimumSyncInterval
    }
}

struct AssetPackInstallManifest: Codable, Equatable {
    var trustPolicyURL: URL?
    var promptPacks: [PromptAssetPack]
    var lensPacks: [LensAssetPack]

    init(
        trustPolicyURL: URL? = nil,
        promptPacks: [PromptAssetPack] = [],
        lensPacks: [LensAssetPack] = []
    ) {
        self.trustPolicyURL = trustPolicyURL
        self.promptPacks = promptPacks
        self.lensPacks = lensPacks
    }
}

protocol AssetPackInstallManifestFetching {
    func fetchInstallManifestData(from url: URL) async throws -> Data
    func fetchTrustPolicyData(from url: URL) async throws -> Data
    func fetchRegistryCatalogData(from url: URL) async throws -> Data
}

struct URLSessionAssetPackInstallManifestFetcher: AssetPackInstallManifestFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchInstallManifestData(from url: URL) async throws -> Data {
        try await fetchData(from: url)
    }

    func fetchTrustPolicyData(from url: URL) async throws -> Data {
        try await fetchData(from: url)
    }

    func fetchRegistryCatalogData(from url: URL) async throws -> Data {
        try await fetchData(from: url)
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            return data
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

enum AssetPackInstallRejectionReason: String, Equatable {
    case missingTrustMetadata
    case incompleteTrustMetadata
    case mismatchedContentHash
    case invalidTrustProof
}

struct AssetPackInstallRejection: Equatable {
    var packId: String
    var packVersion: String
    var displayName: String
    var reason: AssetPackInstallRejectionReason
}

struct AssetPackInstallValidationReport: Equatable {
    var installablePromptPacks: [PromptAssetPack]
    var installableLensPacks: [LensAssetPack]
    var rejectedPromptPacks: [AssetPackInstallRejection]
    var rejectedLensPacks: [AssetPackInstallRejection]
}

struct AssetPackInstallManifestValidator {
    private let signatureVerifier: AssetPackSignatureVerifier

    init(signatureVerifier: AssetPackSignatureVerifier = .default) {
        self.signatureVerifier = signatureVerifier
    }

    func validate(_ manifest: AssetPackInstallManifest) -> AssetPackInstallValidationReport {
        let promptResults = manifest.promptPacks.map(validatePromptPack)
        let lensResults = manifest.lensPacks.map(validateLensPack)
        return AssetPackInstallValidationReport(
            installablePromptPacks: promptResults.compactMap(\.pack),
            installableLensPacks: lensResults.compactMap(\.pack),
            rejectedPromptPacks: promptResults.compactMap(\.rejection),
            rejectedLensPacks: lensResults.compactMap(\.rejection)
        )
    }

    private func validatePromptPack(_ pack: PromptAssetPack) -> (pack: PromptAssetPack?, rejection: AssetPackInstallRejection?) {
        if let reason = rejectionReason(for: pack) {
            return (nil, rejection(pack: pack, reason: reason))
        }
        return (pack, nil)
    }

    private func validateLensPack(_ pack: LensAssetPack) -> (pack: LensAssetPack?, rejection: AssetPackInstallRejection?) {
        if let reason = rejectionReason(for: pack) {
            return (nil, rejection(pack: pack, reason: reason))
        }
        return (pack, nil)
    }

    private func rejectionReason(for pack: PromptAssetPack) -> AssetPackInstallRejectionReason? {
        guard pack.sourceKind.requiresTrustMetadata else { return nil }
        guard let metadata = pack.trustMetadata else { return .missingTrustMetadata }
        guard metadata.missingRequiredFields.isEmpty else { return .incompleteTrustMetadata }
        guard (try? AssetPackIntegrity.hasValidContentHash(pack)) == true else { return .mismatchedContentHash }
        guard (try? signatureVerifier.hasValidSignature(pack)) == true else { return .invalidTrustProof }
        return nil
    }

    private func rejectionReason(for pack: LensAssetPack) -> AssetPackInstallRejectionReason? {
        guard pack.sourceKind.requiresTrustMetadata else { return nil }
        guard let metadata = pack.trustMetadata else { return .missingTrustMetadata }
        guard metadata.missingRequiredFields.isEmpty else { return .incompleteTrustMetadata }
        guard (try? AssetPackIntegrity.hasValidContentHash(pack)) == true else { return .mismatchedContentHash }
        guard (try? signatureVerifier.hasValidSignature(pack)) == true else { return .invalidTrustProof }
        return nil
    }

    private func rejection(pack: PromptAssetPack, reason: AssetPackInstallRejectionReason) -> AssetPackInstallRejection {
        AssetPackInstallRejection(
            packId: pack.id,
            packVersion: pack.version,
            displayName: pack.displayName,
            reason: reason
        )
    }

    private func rejection(pack: LensAssetPack, reason: AssetPackInstallRejectionReason) -> AssetPackInstallRejection {
        AssetPackInstallRejection(
            packId: pack.id,
            packVersion: pack.version,
            displayName: pack.displayName,
            reason: reason
        )
    }
}

struct AssetPackInstallManifestInstaller {
    private let promptAssetPackRepository: PromptAssetPackRepository
    private let lensAssetPackRepository: LensAssetPackRepository
    private let validator: AssetPackInstallManifestValidator
    private let signatureVerifier: AssetPackSignatureVerifier?

    init(
        promptAssetPackRepository: PromptAssetPackRepository,
        lensAssetPackRepository: LensAssetPackRepository,
        validator: AssetPackInstallManifestValidator = AssetPackInstallManifestValidator(),
        signatureVerifier: AssetPackSignatureVerifier? = nil
    ) {
        self.promptAssetPackRepository = promptAssetPackRepository
        self.lensAssetPackRepository = lensAssetPackRepository
        self.validator = validator
        self.signatureVerifier = signatureVerifier
    }

    func install(_ manifest: AssetPackInstallManifest) async throws -> AssetPackInstallValidationReport {
        let report = validator.validate(manifest)
        for pack in report.installablePromptPacks {
            try await savePromptPack(pack)
        }
        for pack in report.installableLensPacks {
            try await saveLensPack(pack)
        }
        return report
    }

    private func savePromptPack(_ pack: PromptAssetPack) async throws {
        guard let signatureVerifier else {
            try await promptAssetPackRepository.savePack(pack)
            return
        }
        guard let repository = promptAssetPackRepository as? SQLitePromptAssetPackRepository else {
            try await promptAssetPackRepository.savePack(pack)
            return
        }
        try await repository.savePack(pack, signatureVerifier: signatureVerifier)
    }

    private func saveLensPack(_ pack: LensAssetPack) async throws {
        guard let signatureVerifier else {
            try await lensAssetPackRepository.savePack(pack)
            return
        }
        guard let repository = lensAssetPackRepository as? SQLiteLensAssetPackRepository else {
            try await lensAssetPackRepository.savePack(pack)
            return
        }
        try await repository.savePack(pack, signatureVerifier: signatureVerifier)
    }
}

enum AssetPackIntegrity {
    private struct PromptContentSnapshot: Encodable {
        let id: String
        let version: String
        let displayName: String
        let sourceKind: PromptAssetSourceKind
        let templates: [PromptTemplate]
    }

    private struct LensContentSnapshot: Encodable {
        let id: String
        let version: String
        let displayName: String
        let sourceKind: LensAssetSourceKind
        let items: [LensCatalogItem]
    }

    private struct TrustPolicyDocumentSnapshot: Encodable {
        let policies: [AssetPackTrustPolicy]
        let expiresAt: Date?
    }

    static func expectedContentHash(for pack: PromptAssetPack) throws -> String {
        try sha256String(
            PromptContentSnapshot(
                id: pack.id,
                version: pack.version,
                displayName: pack.displayName,
                sourceKind: pack.sourceKind,
                templates: pack.templates
            )
        )
    }

    static func expectedContentHash(for pack: LensAssetPack) throws -> String {
        try sha256String(
            LensContentSnapshot(
                id: pack.id,
                version: pack.version,
                displayName: pack.displayName,
                sourceKind: pack.sourceKind,
                items: pack.items
            )
        )
    }

    static func expectedContentHash(for document: AssetPackTrustPolicyDocument) throws -> String {
        try sha256String(
            TrustPolicyDocumentSnapshot(
                policies: document.policies,
                expiresAt: document.expiresAt
            )
        )
    }

    static func hasValidContentHash(_ pack: PromptAssetPack) throws -> Bool {
        guard let metadata = pack.trustMetadata,
              metadata.contentHash.hasPrefix("sha256:")
        else { return false }

        return metadata.contentHash == (try expectedContentHash(for: pack))
    }

    static func hasValidContentHash(_ pack: LensAssetPack) throws -> Bool {
        guard let metadata = pack.trustMetadata,
              metadata.contentHash.hasPrefix("sha256:")
        else { return false }

        return metadata.contentHash == (try expectedContentHash(for: pack))
    }

    static func signaturePayload(for pack: PromptAssetPack) throws -> Data {
        try canonicalEncoder.encode(
            PromptContentSnapshot(
                id: pack.id,
                version: pack.version,
                displayName: pack.displayName,
                sourceKind: pack.sourceKind,
                templates: pack.templates
            )
        )
    }

    static func signaturePayload(for pack: LensAssetPack) throws -> Data {
        try canonicalEncoder.encode(
            LensContentSnapshot(
                id: pack.id,
                version: pack.version,
                displayName: pack.displayName,
                sourceKind: pack.sourceKind,
                items: pack.items
            )
        )
    }

    static func signaturePayload(for document: AssetPackTrustPolicyDocument) throws -> Data {
        try canonicalEncoder.encode(
            TrustPolicyDocumentSnapshot(
                policies: document.policies,
                expiresAt: document.expiresAt
            )
        )
    }

    private static func sha256String<T: Encodable>(_ value: T) throws -> String {
        let data = try canonicalEncoder.encode(value)
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static var canonicalEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if #available(iOS 13.0, *) {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        return encoder
    }
}

enum DataExportSectionName: String, CaseIterable {
    case dailyEntries = "daily_entries"
    case thinkingCards = "thinking_cards"
    case quests
    case principleAssets = "principle_assets"
    case principleRecallFeedback = "principle_recall_feedback"
    case principlePracticeEvidence = "principle_practice_evidence"
    case verifications
    case lensSessions = "lens_sessions"
    case projects
    case projectCandidates = "project_candidates"
    case projectLinks = "project_links"
    case projectMergeCandidates = "project_merge_candidates"
    case projectInsights = "project_insights"
    case metricSnapshots = "metric_snapshots"
    case metricContributions = "metric_contributions"
    case promptRuns = "prompt_runs"
    case promptEvalRuns = "prompt_eval_runs"
    case promptAssetSelections = "prompt_asset_selections"
    case promptAssetPacks = "prompt_asset_packs"
    case lensAssetPacks = "lens_asset_packs"
    case assetPackTrustPolicies = "asset_pack_trust_policies"
    case assetPackRegistrySubscriptions = "asset_pack_registry_subscriptions"
    case historicalRetryCandidates = "historical_retry_candidates"
}

final class SQLiteDataExportRepository: DataExportRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func exportJSON() async throws -> Data {
        try await exportPackage().data
    }

    func exportPackage() async throws -> DataExportPackage {
        let createdAt = Date()
        let sections = try await database.dbQueue.read { db -> [String: [[String: Any]]] in
            var result: [String: [[String: Any]]] = [:]
            for section in DataExportSectionName.allCases {
                result[section.rawValue] = try Self.rows(in: section.rawValue, db: db)
            }
            return result
        }
        let counts = Dictionary(uniqueKeysWithValues: sections.map { ($0.key, $0.value.count) })
        let payload: [String: Any] = [
            "schema_version": 1,
            "created_at": createdAt.mingsiStorageString,
            "sections": sections,
            "counts": counts
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        return DataExportPackage(data: data, counts: counts, createdAt: createdAt)
    }

    private static func rows(in tableName: String, db: Database) throws -> [[String: Any]] {
        let columns = try db.columns(in: tableName).map(\.name)
        guard !columns.isEmpty else { return [] }
        let quotedTable = tableName.replacingOccurrences(of: "\"", with: "\"\"")
        let sql = if tableName == DataExportSectionName.principleAssets.rawValue {
            "SELECT * FROM \"\(quotedTable)\" WHERE deleted_at IS NULL"
        } else {
            "SELECT * FROM \"\(quotedTable)\""
        }
        let rows = try Row.fetchAll(db, sql: sql)
        return rows.map { row in
            var exported = columns.reduce(into: [String: Any]()) { result, column in
                result[column] = exportValue(row[column])
            }
            if tableName == DataExportSectionName.promptEvalRuns.rawValue,
               let caseResultsJSON = exported["case_results_json"] as? String,
               let caseResults = decodeExportJSONValue(caseResultsJSON) {
                exported["case_results"] = caseResults
            }
            if tableName == DataExportSectionName.promptAssetPacks.rawValue,
               let templatesJSON = exported["templates_json"] as? String,
               let templates = decodeExportJSONValue(templatesJSON) {
                exported["templates"] = templates
            }
            return exported
        }
    }

    private static func exportValue(_ value: DatabaseValue) -> Any {
        if value.isNull {
            return NSNull()
        }
        if let string = String.fromDatabaseValue(value) {
            return string
        }
        if let bool = Bool.fromDatabaseValue(value) {
            return bool
        }
        if let int64 = Int64.fromDatabaseValue(value) {
            return int64
        }
        if let double = Double.fromDatabaseValue(value) {
            return double
        }
        if let data = Data.fromDatabaseValue(value) {
            return data.base64EncodedString()
        }
        return "\(value)"
    }

    private static func decodeExportJSONValue(_ json: String) -> Any? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}

final class SQLiteHistoricalRetryCandidateRepository: HistoricalRetryCandidateRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveCandidate(_ candidate: HistoricalRetryCandidate) async throws {
        try await database.dbQueue.write { db in
            var row = HistoricalRetryCandidateRow(candidate: candidate)
            if let existing = try HistoricalRetryCandidateRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func candidate(id: UUID) async throws -> HistoricalRetryCandidate? {
        try await database.dbQueue.read { db in
            try HistoricalRetryCandidateRow
                .filter(Column("id") == id.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func candidates(for sourceDailyEntryId: UUID) async throws -> [HistoricalRetryCandidate] {
        try await database.dbQueue.read { db in
            try HistoricalRetryCandidateRow
                .filter(Column("source_daily_entry_id") == sourceDailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func attachRepairRun(_ repairPromptRunId: UUID, candidatePayloadJSON: String, to candidateId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try HistoricalRetryCandidateRow.fetchOne(db, key: candidateId.uuidString) else { return }
            row.repairPromptRunId = repairPromptRunId.uuidString
            row.candidatePayloadJson = candidatePayloadJSON
            row.status = HistoricalRetryCandidateStatus.candidateReady.rawValue
            row.error = nil
            row.blockedReason = nil
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }

    func updateStatus(
        _ status: HistoricalRetryCandidateStatus,
        candidateId: UUID,
        error: String?,
        blockedReason: String?
    ) async throws {
        try await database.dbQueue.write { db in
            guard var row = try HistoricalRetryCandidateRow.fetchOne(db, key: candidateId.uuidString) else { return }
            row.status = status.rawValue
            row.error = error
            row.blockedReason = blockedReason
            row.updatedAt = Date().mingsiStorageString
            try row.upsert(db)
        }
    }

    func softDelete(candidateId: UUID) async throws {
        try await database.dbQueue.write { db in
            guard var row = try HistoricalRetryCandidateRow.fetchOne(db, key: candidateId.uuidString) else { return }
            let now = Date().mingsiStorageString
            row.updatedAt = now
            row.deletedAt = now
            try row.upsert(db)
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

private struct HistoricalRetryCandidateRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "historical_retry_candidates"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var failedPromptRunId: String
    var repairPromptRunId: String?
    var promptId: String
    var sourceDailyEntryId: String
    var status: String
    var reconstructedInputSummary: String
    var candidatePayloadJson: String?
    var error: String?
    var blockedReason: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(candidate: HistoricalRetryCandidate) {
        let now = Date().mingsiStorageString
        id = candidate.id.uuidString
        schemaVersion = candidate.schemaVersion
        failedPromptRunId = candidate.failedPromptRunId.uuidString
        repairPromptRunId = candidate.repairPromptRunId?.uuidString
        promptId = candidate.promptId.rawValue
        sourceDailyEntryId = candidate.sourceDailyEntryId.uuidString
        status = candidate.status.rawValue
        reconstructedInputSummary = candidate.reconstructedInputSummary
        candidatePayloadJson = candidate.candidatePayloadJSON
        error = candidate.error
        blockedReason = candidate.blockedReason
        createdAt = candidate.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> HistoricalRetryCandidate {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("historical_retry_candidates.id")
        }
        guard let failedPromptRunUUID = UUID(uuidString: failedPromptRunId) else {
            throw PersistenceError.invalidStoredValue("historical_retry_candidates.failed_prompt_run_id")
        }
        let repairPromptRunUUID: UUID?
        if let repairPromptRunId {
            guard let parsed = UUID(uuidString: repairPromptRunId) else {
                throw PersistenceError.invalidStoredValue("historical_retry_candidates.repair_prompt_run_id")
            }
            repairPromptRunUUID = parsed
        } else {
            repairPromptRunUUID = nil
        }
        guard let prompt = PromptID(rawValue: promptId) else {
            throw PersistenceError.invalidStoredValue("historical_retry_candidates.prompt_id")
        }
        guard let sourceDailyEntryUUID = UUID(uuidString: sourceDailyEntryId) else {
            throw PersistenceError.invalidStoredValue("historical_retry_candidates.source_daily_entry_id")
        }
        guard let status = HistoricalRetryCandidateStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("historical_retry_candidates.status")
        }
        return HistoricalRetryCandidate(
            id: uuid,
            schemaVersion: schemaVersion,
            failedPromptRunId: failedPromptRunUUID,
            repairPromptRunId: repairPromptRunUUID,
            promptId: prompt,
            sourceDailyEntryId: sourceDailyEntryUUID,
            status: status,
            reconstructedInputSummary: reconstructedInputSummary,
            candidatePayloadJSON: candidatePayloadJson,
            error: error,
            blockedReason: blockedReason,
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
    var promptSourceKind: String
    var promptPackId: String
    var promptPackVersion: String
    var promptPackDisplayName: String
    var systemPolicyVersion: String
    var contextPolicyVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var evalSuiteVersion: String
    var rollbackTargetVersion: String?
    var modelProvider: String
    var modelName: String
    var sessionMode: String
    var sourceRecordIdsJson: String?
    var contextRecordIdsJson: String?
    var requestSummary: String?
    var responseJson: String?
    var error: String?
    var userFeedback: String
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
        promptSourceKind = run.promptSourceKind.rawValue
        promptPackId = run.promptPackId
        promptPackVersion = run.promptPackVersion
        promptPackDisplayName = run.promptPackDisplayName
        systemPolicyVersion = run.systemPolicyVersion
        contextPolicyVersion = run.contextPolicyVersion
        inputSchemaVersion = run.inputSchemaVersion
        outputSchemaVersion = run.outputSchemaVersion
        evalSuiteVersion = run.evalSuiteVersion
        rollbackTargetVersion = run.rollbackTargetVersion
        modelProvider = run.modelProvider
        modelName = run.modelName
        sessionMode = run.sessionMode
        sourceRecordIdsJson = try? PersistenceJSON.encode(run.sourceRecordIds)
        contextRecordIdsJson = try? PersistenceJSON.encode(run.contextRecordIds)
        requestSummary = run.requestSummary
        responseJson = run.responseJSON
        error = run.error
        userFeedback = run.userFeedback.rawValue
        createdAt = run.createdAt.mingsiStorageString
    }

    func domainModel() throws -> PromptRun {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("prompt_runs.id")
        }
        let sourceIds: [String] = try PersistenceJSON.decode(sourceRecordIdsJson) ?? []
        let contextIds: [String] = try PersistenceJSON.decode(contextRecordIdsJson) ?? sourceIds
        guard let feedback = PromptRunFeedback(rawValue: userFeedback) else {
            throw PersistenceError.invalidStoredValue("prompt_runs.user_feedback")
        }
        guard let sourceKind = PromptAssetSourceKind(rawValue: promptSourceKind) else {
            throw PersistenceError.invalidStoredValue("prompt_runs.prompt_source_kind")
        }
        return PromptRun(
            id: uuid,
            schemaVersion: schemaVersion,
            promptId: promptId,
            promptVersion: promptVersion,
            promptSourceKind: sourceKind,
            promptPackId: promptPackId,
            promptPackVersion: promptPackVersion,
            promptPackDisplayName: promptPackDisplayName,
            systemPolicyVersion: systemPolicyVersion,
            contextPolicyVersion: contextPolicyVersion,
            inputSchemaVersion: inputSchemaVersion,
            outputSchemaVersion: outputSchemaVersion,
            evalSuiteVersion: evalSuiteVersion,
            rollbackTargetVersion: rollbackTargetVersion,
            modelProvider: modelProvider,
            modelName: modelName,
            sessionMode: sessionMode,
            sourceRecordIds: sourceIds,
            contextRecordIds: contextIds,
            requestSummary: requestSummary ?? "",
            responseJSON: responseJson,
            error: error,
            userFeedback: feedback,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now
        )
    }
}

private struct PromptEvalRunRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompt_eval_runs"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var promptId: String
    var promptVersion: String
    var promptSourceKind: String
    var promptPackId: String
    var promptPackVersion: String
    var promptPackDisplayName: String
    var systemPolicyVersion: String
    var contextPolicyVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var evalSuiteVersion: String
    var runnerVersion: String
    var status: String
    var totalCaseCount: Int
    var passedCaseCount: Int
    var failedCaseCount: Int
    var caseResultsJson: String
    var createdAt: String

    init(run: PromptEvalRun) throws {
        id = run.id.uuidString
        schemaVersion = run.schemaVersion
        promptId = run.promptId
        promptVersion = run.promptVersion
        promptSourceKind = run.promptSourceKind.rawValue
        promptPackId = run.promptPackId
        promptPackVersion = run.promptPackVersion
        promptPackDisplayName = run.promptPackDisplayName
        systemPolicyVersion = run.systemPolicyVersion
        contextPolicyVersion = run.contextPolicyVersion
        inputSchemaVersion = run.inputSchemaVersion
        outputSchemaVersion = run.outputSchemaVersion
        evalSuiteVersion = run.evalSuiteVersion
        runnerVersion = run.runnerVersion
        status = run.status.rawValue
        totalCaseCount = run.totalCaseCount
        passedCaseCount = run.passedCaseCount
        failedCaseCount = run.failedCaseCount
        caseResultsJson = try PersistenceJSON.encode(run.caseResults)
        createdAt = run.createdAt.mingsiStorageString
    }

    func domainModel() throws -> PromptEvalRun {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("prompt_eval_runs.id")
        }
        guard PromptEvalStatus(rawValue: status) != nil else {
            throw PersistenceError.invalidStoredValue("prompt_eval_runs.status")
        }
        guard let sourceKind = PromptAssetSourceKind(rawValue: promptSourceKind) else {
            throw PersistenceError.invalidStoredValue("prompt_eval_runs.prompt_source_kind")
        }
        let caseResults: [PromptEvalCaseResult] = try PersistenceJSON.decode(caseResultsJson) ?? []
        return PromptEvalRun(
            id: uuid,
            schemaVersion: schemaVersion,
            promptId: promptId,
            promptVersion: promptVersion,
            promptSourceKind: sourceKind,
            promptPackId: promptPackId,
            promptPackVersion: promptPackVersion,
            promptPackDisplayName: promptPackDisplayName,
            systemPolicyVersion: systemPolicyVersion,
            contextPolicyVersion: contextPolicyVersion,
            inputSchemaVersion: inputSchemaVersion,
            outputSchemaVersion: outputSchemaVersion,
            evalSuiteVersion: evalSuiteVersion,
            runnerVersion: runnerVersion,
            caseResults: caseResults,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now
        )
    }
}

private struct PromptAssetSelectionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompt_asset_selections"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var promptId: String
    var schemaVersion: Int
    var selectedVersion: String
    var baseVersion: String
    var reason: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(selection: PromptAssetSelection) {
        let now = Date().mingsiStorageString
        promptId = selection.promptId.rawValue
        schemaVersion = 1
        selectedVersion = selection.selectedVersion
        baseVersion = selection.baseVersion
        reason = selection.reason.rawValue
        createdAt = selection.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> PromptAssetSelection {
        guard let prompt = PromptID(rawValue: promptId) else {
            throw PersistenceError.invalidStoredValue("prompt_asset_selections.prompt_id")
        }
        guard let selectionReason = PromptAssetSelectionReason(rawValue: reason) else {
            throw PersistenceError.invalidStoredValue("prompt_asset_selections.reason")
        }
        return PromptAssetSelection(
            promptId: prompt,
            selectedVersion: selectedVersion,
            baseVersion: baseVersion,
            reason: selectionReason,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct PromptAssetPackRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompt_asset_packs"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var version: String
    var displayName: String
    var sourceKind: String
    var isEnabled: Int
    var templatesJson: String
    var trustMetadataJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(pack: PromptAssetPack) throws {
        let now = Date().mingsiStorageString
        id = pack.id
        schemaVersion = 1
        version = pack.version
        displayName = pack.displayName
        sourceKind = pack.sourceKind.rawValue
        isEnabled = pack.isEnabled ? 1 : 0
        templatesJson = try PersistenceJSON.encode(pack.templates)
        trustMetadataJson = try PersistenceJSON.encodeOptional(pack.trustMetadata)
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> PromptAssetPack {
        guard let source = PromptAssetSourceKind(rawValue: sourceKind) else {
            throw PersistenceError.invalidStoredValue("prompt_asset_packs.source_kind")
        }
        let templates: [PromptTemplate] = try PersistenceJSON.decode(templatesJson) ?? []
        let trustMetadata: AssetTrustMetadata? = try PersistenceJSON.decode(trustMetadataJson)
        return PromptAssetPack(
            id: id,
            version: version,
            displayName: displayName,
            sourceKind: source,
            isEnabled: isEnabled != 0,
            templates: templates,
            trustMetadata: trustMetadata
        )
    }
}

private struct LensAssetPackRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "lens_asset_packs"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var version: String
    var displayName: String
    var sourceKind: String
    var isEnabled: Int
    var itemsJson: String
    var trustMetadataJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(pack: LensAssetPack) throws {
        let now = Date().mingsiStorageString
        id = pack.id
        schemaVersion = 1
        version = pack.version
        displayName = pack.displayName
        sourceKind = pack.sourceKind.rawValue
        isEnabled = pack.isEnabled ? 1 : 0
        itemsJson = try PersistenceJSON.encode(pack.items)
        trustMetadataJson = try PersistenceJSON.encodeOptional(pack.trustMetadata)
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> LensAssetPack {
        guard let source = LensAssetSourceKind(rawValue: sourceKind) else {
            throw PersistenceError.invalidStoredValue("lens_asset_packs.source_kind")
        }
        let items: [LensCatalogItem] = try PersistenceJSON.decode(itemsJson) ?? []
        let trustMetadata: AssetTrustMetadata? = try PersistenceJSON.decode(trustMetadataJson)
        return LensAssetPack(
            id: id,
            version: version,
            displayName: displayName,
            sourceKind: source,
            isEnabled: isEnabled != 0,
            items: items,
            trustMetadata: trustMetadata
        )
    }
}

private struct AssetPackTrustPolicyRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "asset_pack_trust_policies"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var sourceUrl: String?
    var documentJson: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(
        id: String,
        sourceURL: URL?,
        document: AssetPackTrustPolicyDocument
    ) throws {
        let now = Date().mingsiStorageString
        self.id = id
        schemaVersion = 1
        self.sourceUrl = sourceURL?.absoluteString
        documentJson = try PersistenceJSON.encode(document)
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> AssetPackTrustPolicyRecord {
        guard let document: AssetPackTrustPolicyDocument = try PersistenceJSON.decode(documentJson) else {
            throw PersistenceError.invalidStoredValue("asset_pack_trust_policies.document_json")
        }

        return AssetPackTrustPolicyRecord(
            id: id,
            sourceURL: sourceUrl.flatMap(URL.init(string:)),
            document: document,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private struct AssetPackRegistrySubscriptionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "asset_pack_registry_subscriptions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var displayName: String
    var catalogUrl: String
    var syncPolicyVersion: String
    var isEnabled: Int
    var lastSyncedAt: String?
    var lastSyncStatus: String
    var lastSyncMessage: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(subscription: AssetPackRegistrySubscription) {
        let now = Date().mingsiStorageString
        id = subscription.id
        schemaVersion = subscription.schemaVersion
        displayName = subscription.displayName
        catalogUrl = subscription.catalogURL.absoluteString
        syncPolicyVersion = subscription.syncPolicyVersion
        isEnabled = subscription.isEnabled ? 1 : 0
        lastSyncedAt = subscription.lastSyncedAt?.mingsiStorageString
        lastSyncStatus = subscription.lastSyncStatus.rawValue
        lastSyncMessage = subscription.lastSyncMessage
        createdAt = subscription.createdAt.mingsiStorageString
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> AssetPackRegistrySubscription {
        guard let url = URL(string: catalogUrl) else {
            throw PersistenceError.invalidStoredValue("asset_pack_registry_subscriptions.catalog_url")
        }
        guard let status = AssetPackRegistrySyncStatus(rawValue: lastSyncStatus) else {
            throw PersistenceError.invalidStoredValue("asset_pack_registry_subscriptions.last_sync_status")
        }
        return AssetPackRegistrySubscription(
            id: id,
            schemaVersion: schemaVersion,
            displayName: displayName,
            catalogURL: url,
            syncPolicyVersion: syncPolicyVersion,
            isEnabled: isEnabled != 0,
            lastSyncedAt: lastSyncedAt.flatMap(Date.init(mingsiStorageString:)),
            lastSyncStatus: status,
            lastSyncMessage: lastSyncMessage,
            createdAt: Date(mingsiStorageString: createdAt) ?? .now,
            updatedAt: Date(mingsiStorageString: updatedAt) ?? .now
        )
    }
}

private enum PersistenceJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.invalidStoredValue("json_encoding")
        }
        return string
    }

    static func encodeOptional<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        return try encode(value)
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
