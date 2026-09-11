import Foundation
import GRDB

protocol TrainingCaseRepository {
    func saveCase(_ trainingCase: TrainingCase) async throws
    func caseRecord(id: UUID) async throws -> TrainingCase?
    func cases(for dailyEntryId: UUID) async throws -> [TrainingCase]
    func updateStatus(_ status: TrainingCaseStatus, caseId: UUID) async throws
    func assignCards(_ cardIds: [UUID], to caseId: UUID) async throws
}

protocol TrainingCaseSessionRepository {
    func saveSession(_ session: TrainingCaseSession) async throws
    func session(for caseId: UUID) async throws -> TrainingCaseSession?
}

protocol TrainingCaseRelationshipRepository {
    func saveMerge(_ merge: TrainingCaseMerge) async throws
    func activeMerges(for dailyEntryId: UUID) async throws -> [TrainingCaseMerge]
    func revertMerge(id: UUID) async throws
    func saveLink(_ link: TrainingCaseLink) async throws
}

protocol ProjectClosureReviewRepository {
    func saveReview(_ review: ProjectClosureReview) async throws
    func closeProject(_ project: Project, review: ProjectClosureReview) async throws
    func review(for projectId: UUID) async throws -> ProjectClosureReview?
}

protocol GrowthSettlementRepository {
    func saveSettlement(_ settlement: GrowthSettlement) async throws
    func settlement(for verificationId: UUID) async throws -> GrowthSettlement?
    func recentSettlements(limit: Int) async throws -> [GrowthSettlement]
}

extension GrowthSettlementRepository {
    func recentSettlements(limit: Int) async throws -> [GrowthSettlement] { [] }
}

protocol VerificationSettlementRepository {
    func saveVerification(
        _ verification: Verification,
        questStatus: QuestStatus,
        settlement: GrowthSettlement
    ) async throws
}

protocol GuidanceRepository {
    func saveState(_ state: UserGuidanceState) async throws
    func state(for hintId: String) async throws -> UserGuidanceState?
    func allStates() async throws -> [UserGuidanceState]
    func saveFeedback(_ feedback: CoachTurnFeedback) async throws
}

protocol WeeklyGuidanceReviewRepository {
    func saveReview(_ review: WeeklyGuidanceReviewRecord) async throws
    func review(forWeekKey weekKey: String) async throws -> WeeklyGuidanceReviewRecord?
}

protocol SideQuestRepository {
    func savePhotoMemory(_ memory: SideQuestPhotoMemory) async throws
    func photoMemories(for runId: UUID) async throws -> [SideQuestPhotoMemory]
    func markPhotoMemoryUnavailable(id: UUID) async throws
    func preference() async throws -> SideQuestPreference
    func savePreference(_ preference: SideQuestPreference) async throws
    func lifeContextProfile() async throws -> SideQuestLifeContextProfile
    func saveLifeContextProfile(_ profile: SideQuestLifeContextProfile) async throws
    func run(id: UUID) async throws -> SideQuestRun?
    func openRun() async throws -> SideQuestRun?
    func recentRuns(limit: Int) async throws -> [SideQuestRun]
    func activeSeason(at date: Date) async throws -> SideQuestExplorationSeason?
    func season(id: UUID) async throws -> SideQuestExplorationSeason?
    func latestSeason() async throws -> SideQuestExplorationSeason?
    func seasonCategorySummary(id: UUID) async throws -> [SideQuestCategory: Int]
    func startSeason(title: String, intent: String?, at date: Date) async throws -> SideQuestExplorationSeason
    func closeSeason(status: SideQuestExplorationSeasonStatus, at date: Date) async throws -> SideQuestExplorationSeason?
    func offerHistory() async throws -> [String: Date]
    func planningRecord(forDayKey dayKey: String) async throws -> SideQuestPlanningRecord?
    func offer(_ run: SideQuestRun) async throws
    func recordPlanningResult(
        preference: SideQuestPreference,
        planningRecord: SideQuestPlanningRecord,
        offeredRun: SideQuestRun?
    ) async throws -> Bool
    func accept(runId: UUID, at date: Date) async throws -> SideQuestRun
    func deferRun(runId: UUID, until date: Date, at now: Date) async throws -> SideQuestRun
    func decline(runId: UUID, at date: Date) async throws -> SideQuestRun
    func complete(runId: UUID, reflection: String?, at date: Date) async throws -> SideQuestExperienceEvent
    func experience(for runId: UUID) async throws -> SideQuestExperienceEvent?
    func experienceEvents(limit: Int) async throws -> [SideQuestExperienceEvent]
    func experienceSummary(now: Date) async throws -> SideQuestExperienceSummary
    func trialMetrics(since: Date, through: Date) async throws -> SideQuestTrialMetrics
    func saveCorrection(_ correction: SideQuestCorrectionEvent, resolvingRunId: UUID?) async throws
    func recentCorrections(limit: Int) async throws -> [SideQuestCorrectionEvent]
#if DEBUG
    func clearOpenRunsForVisualQA() async throws
#endif
}

protocol CoachPromptTurnRepository {
    func recordOutcome(
        promptRunId: UUID,
        promptId: PromptID,
        outcome: CoachPromptTurnOutcome,
        detail: String?
    ) async throws
    func markPresented(
        promptRunId: UUID,
        caseSessionId: UUID,
        caseId: UUID,
        promptId: PromptID,
        outputFingerprint: String
    ) async throws
    func presentedTurn(
        caseSessionId: UUID,
        promptId: PromptID,
        outputFingerprint: String
    ) async throws -> CoachPromptTurn?
    func qualitySummaries(limit: Int) async throws -> [CoachPromptQualitySummary]
}

extension AppDatabase {
    static func registerVNextMigrations(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v33_training_cases") { db in
            try db.create(table: "training_cases", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("daily_entry_id", .text).notNull().indexed()
                table.column("title", .text).notNull()
                table.column("status", .text).notNull()
                table.column("sort_order", .integer).notNull().defaults(to: 0)
                table.column("created_by", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
                table.foreignKey(["daily_entry_id"], references: "daily_entries", columns: ["id"], onDelete: .cascade)
            }
            try db.create(table: "training_case_sessions", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("case_id", .text).notNull().unique().indexed()
                table.column("loop_state", .text).notNull()
                table.column("session_mode", .text).notNull()
                table.column("selected_lens_id", .text)
                table.column("training_prescription_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.foreignKey(["case_id"], references: "training_cases", columns: ["id"], onDelete: .cascade)
            }
            try db.create(table: "training_case_merges", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("source_case_id", .text).notNull().indexed()
                table.column("target_case_id", .text).notNull().indexed()
                table.column("status", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("reverted_at", .text)
            }
            try db.create(table: "training_case_links", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("source_case_id", .text).notNull().indexed()
                table.column("target_case_id", .text).notNull().indexed()
                table.column("kind", .text).notNull()
                table.column("created_at", .text).notNull()
            }

            let entries: [Row]
            if try db.tableExists("daily_entries") {
                entries = try Row.fetchAll(
                    db,
                    sql: "SELECT id, raw_text, state, session_mode, selected_lens, training_prescription_json FROM daily_entries WHERE deleted_at IS NULL"
                )
            } else {
                entries = []
            }
            let now = VNextStorage.string(from: .now)
            for entry in entries {
                let entryId: String = entry["id"]
                let rawText: String = entry["raw_text"]
                let state: String = entry["state"]
                let mode: String = entry["session_mode"]
                let lens: String? = entry["selected_lens"]
                let prescription: String? = entry["training_prescription_json"]
                let caseId = UUID().uuidString
                try db.execute(
                    sql: "INSERT INTO training_cases (id, daily_entry_id, title, status, sort_order, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?, ?)",
                    arguments: [caseId, entryId, VNextStorage.defaultCaseTitle(from: rawText), VNextStorage.caseStatus(for: state), TrainingCaseCreatedBy.migration.rawValue, now, now]
                )
                try db.execute(
                    sql: "INSERT INTO training_case_sessions (id, case_id, loop_state, session_mode, selected_lens_id, training_prescription_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    arguments: [UUID().uuidString, caseId, state, mode, lens, prescription, now, now]
                )
            }
        }

        migrator.registerMigration("v34_case_ownership") { db in
            let ownershipColumns = [
                ("thinking_cards", "case_id"),
                ("quests", "case_id"),
                ("lens_sessions", "case_id"),
                ("metric_contributions", "source_case_id")
            ]
            for (tableName, columnName) in ownershipColumns {
                guard try db.tableExists(tableName) else { continue }
                let columns = Set(try db.columns(in: tableName).map(\.name))
                if !columns.contains(columnName) {
                    try db.alter(table: tableName) { table in table.add(column: columnName, .text).indexed() }
                }
            }
            if try db.tableExists("thinking_cards") {
                try db.execute(sql: "UPDATE thinking_cards SET case_id = (SELECT id FROM training_cases WHERE daily_entry_id = thinking_cards.daily_entry_id ORDER BY sort_order LIMIT 1) WHERE case_id IS NULL")
            }
            if try db.tableExists("quests") {
                try db.execute(sql: "UPDATE quests SET case_id = (SELECT id FROM training_cases WHERE daily_entry_id = quests.source_daily_entry_id ORDER BY sort_order LIMIT 1) WHERE case_id IS NULL")
            }
            if try db.tableExists("lens_sessions") {
                try db.execute(sql: "UPDATE lens_sessions SET case_id = (SELECT id FROM training_cases WHERE daily_entry_id = lens_sessions.daily_entry_id ORDER BY sort_order LIMIT 1) WHERE case_id IS NULL")
            }
            if try db.tableExists("metric_contributions") {
                try db.execute(sql: "UPDATE metric_contributions SET source_case_id = (SELECT id FROM training_cases WHERE daily_entry_id = metric_contributions.source_daily_entry_id ORDER BY sort_order LIMIT 1) WHERE source_case_id IS NULL")
            }

            if try db.tableExists("thinking_cards") {
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS validate_thinking_card_case_insert
                BEFORE INSERT ON thinking_cards WHEN NEW.case_id IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.case_id AND c.daily_entry_id = NEW.daily_entry_id
                    ) THEN RAISE(ABORT, 'thinking card case ownership mismatch') END;
                END
                """)
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS validate_thinking_card_case_update
                BEFORE UPDATE OF case_id, daily_entry_id ON thinking_cards WHEN NEW.case_id IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.case_id AND c.daily_entry_id = NEW.daily_entry_id
                    ) THEN RAISE(ABORT, 'thinking card case ownership mismatch') END;
                END
                """)
            }
            if try db.tableExists("quests") {
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS validate_quest_case_insert
                BEFORE INSERT ON quests WHEN NEW.case_id IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.case_id AND c.daily_entry_id = NEW.source_daily_entry_id
                    ) THEN RAISE(ABORT, 'quest case ownership mismatch') END;
                END
                """)
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS validate_quest_case_update
                BEFORE UPDATE OF case_id, source_daily_entry_id ON quests WHEN NEW.case_id IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.case_id AND c.daily_entry_id = NEW.source_daily_entry_id
                    ) THEN RAISE(ABORT, 'quest case ownership mismatch') END;
                END
                """)
            }
            if try db.tableExists("lens_sessions") {
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS validate_lens_case_insert
                BEFORE INSERT ON lens_sessions WHEN NEW.case_id IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.case_id AND c.daily_entry_id = NEW.daily_entry_id
                    ) THEN RAISE(ABORT, 'lens case ownership mismatch') END;
                END
                """)
            }
            if try db.tableExists("metric_contributions") {
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS validate_metric_case_insert
                BEFORE INSERT ON metric_contributions WHEN NEW.source_case_id IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.source_case_id AND c.daily_entry_id = NEW.source_daily_entry_id
                    ) THEN RAISE(ABORT, 'metric case ownership mismatch') END;
                END
                """)
            }
        }

        migrator.registerMigration("v35_vnext_support") { db in
            if try db.tableExists("quests") {
                let questColumns = Set(try db.columns(in: "quests").map(\.name))
                if !questColumns.contains("verification_deferred_until") {
                    try db.alter(table: "quests") { table in table.add(column: "verification_deferred_until", .text) }
                }
            }
            try db.create(table: "project_closure_reviews", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("project_id", .text).notNull().unique().indexed()
                table.column("reason", .text).notNull()
                table.column("outcome", .text).notNull()
                table.column("evidence_refs_json", .text).notNull()
                table.column("transferred_items", .text)
                table.column("review_note", .text)
                table.column("ai_summary", .text)
                table.column("previous_status", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
            try db.create(table: "growth_settlements", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("verification_id", .text).notNull().unique().indexed()
                table.column("case_id", .text).indexed()
                table.column("original_judgment", .text).notNull()
                table.column("actual_result", .text).notNull()
                table.column("judgment_update", .text).notNull()
                table.column("evidence_items_json", .text).notNull()
                table.column("created_at", .text).notNull()
            }
            try db.create(table: "user_guidance_states", ifNotExists: true) { table in
                table.column("hint_id", .text).primaryKey()
                table.column("status", .text).notNull()
                table.column("evidence_count", .integer).notNull()
                table.column("counterexample_count", .integer).notNull()
                table.column("last_shown_at", .text)
                table.column("snoozed_until", .text)
                table.column("evidence_refs_json", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
            try db.create(table: "coach_turn_feedback", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("case_session_id", .text).notNull().indexed()
                table.column("prompt_run_id", .text).indexed()
                table.column("coach_observation_id", .text)
                table.column("value", .text).notNull()
                table.column("note", .text)
                table.column("created_at", .text).notNull()
            }
        }

        migrator.registerMigration("v36_vnext_closure_integrity") { db in
            if try db.tableExists("project_closure_reviews") {
                let columns = Set(try db.columns(in: "project_closure_reviews").map(\.name))
                if !columns.contains("principle_candidates_json") {
                    try db.alter(table: "project_closure_reviews") { table in
                        table.add(column: "principle_candidates_json", .text).notNull().defaults(to: "[]")
                    }
                }
            }
            for (table, caseColumn, entryColumn, label) in [
                ("lens_sessions", "case_id", "daily_entry_id", "lens session"),
                ("metric_contributions", "source_case_id", "source_daily_entry_id", "metric contribution")
            ] {
                guard try db.tableExists(table) else { continue }
                let trigger = "validate_\(table)_case_update"
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS \(trigger)
                BEFORE UPDATE OF \(caseColumn), \(entryColumn) ON \(table) WHEN NEW.\(caseColumn) IS NOT NULL
                BEGIN
                    SELECT CASE WHEN NOT EXISTS (
                        SELECT 1 FROM training_cases c
                        WHERE c.id = NEW.\(caseColumn) AND c.daily_entry_id = NEW.\(entryColumn)
                    ) THEN RAISE(ABORT, '\(label) case ownership mismatch') END;
                END
                """)
            }
        }

        migrator.registerMigration("v37_coach_prompt_turns") { db in
            try db.create(table: "coach_prompt_turns", ifNotExists: true) { table in
                table.column("prompt_run_id", .text).primaryKey()
                table.column("case_session_id", .text).indexed()
                table.column("prompt_id", .text).notNull().indexed()
                table.column("outcome", .text).notNull().indexed()
                table.column("output_fingerprint", .text)
                table.column("detail", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.foreignKey(["prompt_run_id"], references: "prompt_runs", columns: ["id"], onDelete: .cascade)
                table.foreignKey(["case_session_id"], references: "training_case_sessions", columns: ["id"], onDelete: .setNull)
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS coach_prompt_turns_session_prompt_outcome_updated_idx ON coach_prompt_turns(case_session_id, prompt_id, outcome, updated_at DESC)")
        }

        migrator.registerMigration("v38_weekly_guidance_reviews") { db in
            try db.create(table: "weekly_guidance_reviews", ifNotExists: true) { table in
                table.column("week_key", .text).primaryKey()
                table.column("training_focus", .text).notNull()
                table.column("hint_ids_json", .text).notNull()
                table.column("evidence_refs_json", .text).notNull()
                table.column("generated_at", .text).notNull()
            }
        }

        migrator.registerMigration("v39_side_quest_foundation") { db in
            try db.create(table: "side_quest_preferences", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("is_enabled", .boolean).notNull().defaults(to: false)
                table.column("enabled_categories_json", .text).notNull()
                table.column("frequency", .text).notNull()
                table.column("notifications_enabled", .boolean).notNull().defaults(to: false)
                table.column("notification_schedule_json", .text)
                table.column("last_ai_planning_at", .text)
                table.column("last_ai_planning_prompt_run_id", .text)
                table.column("rotation_seed", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
            try db.create(table: "side_quest_runs", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("catalog_id", .text).notNull().indexed()
                table.column("catalog_version", .text).notNull()
                table.column("category", .text).notNull()
                table.column("title", .text).notNull()
                table.column("invitation", .text).notNull()
                table.column("evidence_prompt", .text).notNull()
                table.column("prerequisites_json", .text).notNull()
                table.column("minimum_minutes", .integer).notNull()
                table.column("maximum_minutes", .integer).notNull()
                table.column("reward_track", .text).notNull()
                table.column("completion_experience", .integer).notNull()
                table.column("reflection_bonus_experience", .integer).notNull()
                table.column("status", .text).notNull().indexed()
                table.column("offered_at", .text).notNull().indexed()
                table.column("accepted_at", .text)
                table.column("deferred_until", .text)
                table.column("completed_at", .text)
                table.column("reflection", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
            // A person should never be left to juggle several unresolved invitations.
            try db.execute(sql: "CREATE UNIQUE INDEX side_quest_one_open_run_idx ON side_quest_runs((1)) WHERE status IN ('offered', 'accepted', 'deferred')")
            try db.create(table: "side_quest_experience_events", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("side_quest_run_id", .text).notNull().unique().indexed()
                table.column("track", .text).notNull().indexed()
                table.column("completion_experience", .integer).notNull()
                table.column("reflection_bonus_experience", .integer).notNull()
                table.column("occurred_at", .text).notNull().indexed()
                table.foreignKey(["side_quest_run_id"], references: "side_quest_runs", columns: ["id"])
            }
            try db.execute(sql: """
            CREATE TRIGGER validate_side_quest_experience_event_insert
            BEFORE INSERT ON side_quest_experience_events
            BEGIN
                SELECT CASE WHEN NOT EXISTS (
                    SELECT 1 FROM side_quest_runs
                    WHERE id = NEW.side_quest_run_id AND status = 'completed'
                ) THEN RAISE(ABORT, 'side quest experience requires a completed run') END;
                SELECT CASE WHEN NEW.completion_experience < 0 OR NEW.reflection_bonus_experience < 0
                    OR NEW.completion_experience + NEW.reflection_bonus_experience <= 0
                THEN RAISE(ABORT, 'side quest experience must be positive') END;
            END
            """)
            try db.execute(sql: """
            CREATE TRIGGER prevent_side_quest_experience_event_update
            BEFORE UPDATE ON side_quest_experience_events
            BEGIN SELECT RAISE(ABORT, 'side quest experience is immutable'); END
            """)
            try db.execute(sql: """
            CREATE TRIGGER prevent_side_quest_experience_event_delete
            BEFORE DELETE ON side_quest_experience_events
            BEGIN SELECT RAISE(ABORT, 'side quest experience is immutable'); END
            """)
        }

        migrator.registerMigration("v40_side_quest_orchestrator") { db in
            if try db.tableExists("side_quest_runs") {
                let columns = Set(try db.columns(in: "side_quest_runs").map(\.name))
                if !columns.contains("origin") {
                    try db.alter(table: "side_quest_runs") { table in
                        table.add(column: "origin", .text).notNull().defaults(to: SideQuestRunOrigin.catalogFallback.rawValue)
                    }
                }
                if !columns.contains("prompt_run_id") {
                    try db.alter(table: "side_quest_runs") { table in table.add(column: "prompt_run_id", .text).indexed() }
                }
                if !columns.contains("decision_rationale") {
                    try db.alter(table: "side_quest_runs") { table in table.add(column: "decision_rationale", .text) }
                }
                if !columns.contains("notification_title") {
                    try db.alter(table: "side_quest_runs") { table in table.add(column: "notification_title", .text) }
                }
                if !columns.contains("notification_body") {
                    try db.alter(table: "side_quest_runs") { table in table.add(column: "notification_body", .text) }
                }
            }
            if try db.tableExists("side_quest_preferences") {
                let columns = Set(try db.columns(in: "side_quest_preferences").map(\.name))
                if !columns.contains("last_ai_planning_at") {
                    try db.alter(table: "side_quest_preferences") { table in
                        table.add(column: "last_ai_planning_at", .text)
                    }
                }
                if !columns.contains("last_ai_planning_prompt_run_id") {
                    try db.alter(table: "side_quest_preferences") { table in
                        table.add(column: "last_ai_planning_prompt_run_id", .text)
                    }
                }
            }
            if try db.tableExists("side_quest_experience_events") {
                let columns = Set(try db.columns(in: "side_quest_experience_events").map(\.name))
                if !columns.contains("streak_count") {
                    try db.alter(table: "side_quest_experience_events") { table in
                        table.add(column: "streak_count", .integer).notNull().defaults(to: 0)
                    }
                }
            }
        }

        migrator.registerMigration("v41_side_quest_consent") { db in
            guard try db.tableExists("side_quest_preferences") else { return }
            let columns = Set(try db.columns(in: "side_quest_preferences").map(\.name))
            if !columns.contains("consent_status") {
                try db.alter(table: "side_quest_preferences") { table in
                    table.add(column: "consent_status", .text).notNull().defaults(to: SideQuestConsentStatus.notAsked.rawValue)
                }
                // Existing invitations are durable evidence of prior opt-in;
                // other legacy records must pass through the first-use prompt.
                try db.execute(sql: """
                    UPDATE side_quest_preferences
                    SET consent_status = CASE
                        WHEN is_enabled = 1 OR EXISTS (SELECT 1 FROM side_quest_runs) THEN 'enabled'
                        ELSE 'notAsked'
                    END
                """)
            }
        }

        migrator.registerMigration("v42_side_quest_life_context_profile") { db in
            try db.create(table: "side_quest_life_context_profiles", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("home_label", .text)
                table.column("work_label", .text)
                table.column("floor_count", .integer)
                table.column("commute_modes_json", .text).notNull().defaults(to: "[]")
                table.column("preferred_activity_radius", .text)
                table.column("movement_preferences_json", .text).notNull().defaults(to: "[]")
                table.column("unavailable_categories_json", .text).notNull().defaults(to: "[]")
                table.column("constraints_json", .text).notNull().defaults(to: "[]")
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
        }

        migrator.registerMigration("v43_side_quest_correction_feedback") { db in
            try db.create(table: "side_quest_correction_events", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("side_quest_run_id", .text).indexed()
                table.column("kind", .text).notNull().indexed()
                table.column("note", .text)
                table.column("occurred_at", .text).notNull().indexed()
                table.foreignKey(["side_quest_run_id"], references: "side_quest_runs", columns: ["id"], onDelete: .setNull)
            }
        }

        migrator.registerMigration("v44_side_quest_practical_context_v2") { db in
            guard try db.tableExists("side_quest_life_context_profiles") else { return }
            let columns = Set(try db.columns(in: "side_quest_life_context_profiles").map(\.name))
            try db.alter(table: "side_quest_life_context_profiles") { table in
                if !columns.contains("home_floor_level") { table.add(column: "home_floor_level", .integer) }
                if !columns.contains("home_stairs_available") { table.add(column: "home_stairs_available", .boolean) }
                if !columns.contains("workplace_floor_level") { table.add(column: "workplace_floor_level", .integer) }
                if !columns.contains("workplace_stairs_available") { table.add(column: "workplace_stairs_available", .boolean) }
                if !columns.contains("transition_windows_json") {
                    table.add(column: "transition_windows_json", .text).notNull().defaults(to: "[]")
                }
            }
            // `floor_count` remains as the legacy, unscoped value. It is kept
            // for export and local reassignment, never treated as a place fact.
        }

        migrator.registerMigration("v45_side_quest_planning_audit") { db in
            try db.create(table: "side_quest_planning_records", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("day_key", .text).notNull().unique().indexed()
                table.column("decision", .text).notNull().indexed()
                table.column("prompt_run_id", .text).notNull().unique().indexed()
                table.column("planned_at", .text).notNull().indexed()
            }
        }

        migrator.registerMigration("v46_side_quest_exploration_season") { db in
            try db.create(table: "side_quest_exploration_seasons", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("intent", .text)
                table.column("started_at", .text).notNull().indexed()
                table.column("ends_at", .text).notNull().indexed()
                table.column("status", .text).notNull().indexed()
                table.column("max_days", .integer).notNull().defaults(to: SideQuestExplorationSeason.defaultMaxDays)
                table.column("accepted_count", .integer).notNull().defaults(to: 0)
                table.column("completed_count", .integer).notNull().defaults(to: 0)
                table.column("skipped_count", .integer).notNull().defaults(to: 0)
            }
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS side_quest_one_active_season_idx ON side_quest_exploration_seasons((1)) WHERE status = 'active'")
            guard try db.tableExists("side_quest_runs") else { return }
            let columns = Set(try db.columns(in: "side_quest_runs").map(\.name))
            if !columns.contains("season_id") {
                try db.alter(table: "side_quest_runs") { table in
                    table.add(column: "season_id", .text).indexed()
                    table.add(column: "season_day", .integer)
                    table.add(column: "season_step", .text)
                }
            }
        }

        migrator.registerMigration("v47_side_quest_photo_memories") { db in
            try db.create(table: "side_quest_photo_memories", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("asset_local_identifier", .text).notNull().unique().indexed()
                table.column("run_id", .text).notNull().indexed()
                table.column("created_at", .text).notNull().indexed()
                table.column("unavailable", .boolean).notNull().defaults(to: false)
                table.foreignKey(["run_id"], references: "side_quest_runs", columns: ["id"], onDelete: .cascade)
            }
        }

        migrator.registerMigration("v48_capture_fragments_daily_digests") { db in
            try db.create(table: "capture_fragments", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("raw_text", .text).notNull()
                table.column("source", .text).notNull()
                table.column("status", .text).notNull().indexed()
                table.column("day_key", .text).notNull().indexed()
                table.column("source_id", .text)
                table.column("created_at", .text).notNull().indexed()
                table.column("updated_at", .text).notNull()
            }
            try db.create(table: "daily_capture_digests", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("day_key", .text).notNull().indexed()
                table.column("status", .text).notNull().indexed()
                table.column("summary", .text).notNull()
                table.column("themes_json", .text).notNull().defaults(to: "[]")
                table.column("recommended_question", .text)
                table.column("source_fragment_ids_json", .text).notNull().defaults(to: "[]")
                table.column("created_at", .text).notNull().indexed()
                table.column("updated_at", .text).notNull()
            }
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS daily_capture_one_current_digest_idx ON daily_capture_digests(day_key) WHERE status = 'current'")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS capture_fragment_source_id_idx ON capture_fragments(source, source_id) WHERE source_id IS NOT NULL")
        }
        migrator.registerMigration("v49_single_nudge_sessions") { db in
            try db.create(table: "single_nudge_sessions", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("day_key", .text).notNull().indexed()
                table.column("input", .text).notNull().defaults(to: "")
                table.column("question", .text)
                table.column("diagnosis", .text)
                table.column("before_text", .text)
                table.column("after_text", .text)
                table.column("cognitive_shift", .text)
                table.column("thinking_action", .text)
                table.column("unresolved_uncertainty", .text)
                table.column("transition_to_verification", .boolean)
                table.column("prompt_run_id", .text)
                table.column("source_refs", .text)
                table.column("lifecycle", .text).notNull()
                table.column("result", .text).notNull()
                table.column("feedback", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull().indexed()
            }
            // Multiple nudges may be captured per day; day_key is only a query index.
        }
        migrator.registerMigration("v50_single_nudge_fields") { db in
            let existing = try Row.fetchAll(db, sql: "PRAGMA table_info(single_nudge_sessions)").compactMap { $0["name"] as String? }
            for (name, definition) in [("diagnosis", "TEXT"), ("cognitive_shift", "TEXT"), ("thinking_action", "TEXT"), ("unresolved_uncertainty", "TEXT"), ("transition_to_verification", "INTEGER"), ("prompt_run_id", "TEXT"), ("source_refs", "TEXT")] where !existing.contains(name) {
                try db.execute(sql: "ALTER TABLE single_nudge_sessions ADD COLUMN \(name) \(definition)")
            }
        }
        migrator.registerMigration("v51_single_nudge_audit_rounds") { db in
            let existing = try Row.fetchAll(db, sql: "PRAGMA table_info(single_nudge_sessions)").compactMap { $0["name"] as String? }
            for (name, definition) in [("review_prompt_run_id", "TEXT"), ("review_source_refs", "TEXT")] where !existing.contains(name) {
                try db.execute(sql: "ALTER TABLE single_nudge_sessions ADD COLUMN \(name) \(definition)")
            }
        }
        migrator.registerMigration("v52_single_nudge_round_lineage") { db in
            let existing = try Row.fetchAll(db, sql: "PRAGMA table_info(single_nudge_sessions)").compactMap { $0["name"] as String? }
            for (name, definition) in [
                ("parent_session_id", "TEXT"),
                ("root_session_id", "TEXT"),
                ("continuation_kind", "TEXT NOT NULL DEFAULT 'initial'")
            ] where !existing.contains(name) {
                try db.execute(sql: "ALTER TABLE single_nudge_sessions ADD COLUMN \(name) \(definition)")
            }
            // Existing independent rows are roots. Keeping their own ID makes
            // exports and restores compatible with the pre-lineage shape.
            try db.execute(sql: "UPDATE single_nudge_sessions SET root_session_id = id WHERE root_session_id IS NULL OR root_session_id = ''")
            try db.create(index: "idx_single_nudge_parent_session", on: "single_nudge_sessions", columns: ["parent_session_id"], ifNotExists: true)
            try db.create(index: "idx_single_nudge_root_session", on: "single_nudge_sessions", columns: ["root_session_id"], ifNotExists: true)
        }
        migrator.registerMigration("v53_mentor_m1_foundation") { db in
            try db.create(table: "mentor_sessions", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("initial_entry", .text).notNull()
                t.column("lifecycle", .text).notNull()
                t.column("draft_text", .text).notNull().defaults(to: "")
                t.column("draft_revision", .integer).notNull().defaults(to: 0)
                t.column("activity_at", .text).notNull().indexed()
            }
            try db.create(table: "mentor_items", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().indexed().references("mentor_sessions", onDelete: .cascade)
                t.column("sequence", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("payload_json", .text).notNull()
                t.uniqueKey(["session_id", "sequence"])
            }
            try db.create(table: "mentor_requests", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().indexed().references("mentor_sessions", onDelete: .cascade)
                t.column("state", .text).notNull()
                t.column("created_at", .text).notNull()
            }
            try db.create(table: "mentor_understandings", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().indexed().references("mentor_sessions", onDelete: .cascade)
                t.column("group_id", .text).notNull()
                t.column("revision", .integer).notNull()
                t.column("state", .text).notNull()
                t.column("text", .text).notNull()
                t.uniqueKey(["group_id", "revision"])
            }
            try db.create(table: "mentor_feedback", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().indexed().references("mentor_sessions", onDelete: .cascade)
                t.column("item_id", .text)
                t.column("lesson_id", .text)
                t.column("kind", .text).notNull()
                t.column("created_at", .text).notNull()
            }
            try db.create(table: "mentor_source_links", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().indexed().references("mentor_sessions", onDelete: .cascade)
                t.column("owner_id", .text).notNull()
                t.column("source_kind", .text).notNull()
                t.column("source_id", .text).notNull()
            }
        }
        migrator.registerMigration("v54_mentor_request_idempotency") { db in
            try db.alter(table: "mentor_requests") { t in
                t.add(column: "command_id", .text).notNull().defaults(to: "")
                t.add(column: "user_item_id", .text)
                t.add(column: "context_snapshot_json", .text).notNull().defaults(to: "{}")
            }
            try db.execute(sql: "UPDATE mentor_requests SET command_id = id WHERE command_id = ''")
            try db.create(index: "mentor_requests_command_idx", on: "mentor_requests", columns: ["session_id", "command_id"], unique: true, ifNotExists: true)
        }
        migrator.registerMigration("v55_mentor_request_intent") { db in
            try db.alter(table: "mentor_requests") { t in
                t.add(column: "intent", .text).notNull().defaults(to: "legacy")
            }
        }
        migrator.registerMigration("v56_mentor_response_ownership") { db in
            try db.create(index: "mentor_items_session_identity", on: "mentor_items", columns: ["session_id", "id"], unique: true)
            try db.create(index: "mentor_requests_session_identity", on: "mentor_requests", columns: ["session_id", "id"], unique: true)
            try db.create(table: "mentor_request_results") { t in
                t.column("request_id", .text).primaryKey().references("mentor_requests", onDelete: .cascade)
                t.column("session_id", .text).notNull().references("mentor_sessions", onDelete: .cascade)
                t.column("item_id", .text).notNull().unique()
                t.foreignKey(["session_id", "request_id"], references: "mentor_requests", columns: ["session_id", "id"], onDelete: .cascade)
                t.foreignKey(["session_id", "item_id"], references: "mentor_items", columns: ["session_id", "id"], onDelete: .cascade)
            }
        }
        migrator.registerMigration("v57_mentor_semantic_revisions") { db in
            try db.alter(table: "mentor_sessions") { t in
                t.add(column: "semantic_revision", .integer).notNull().defaults(to: 0)
                t.add(column: "request_epoch", .integer).notNull().defaults(to: 0)
            }
            try db.alter(table: "mentor_requests") { t in
                t.add(column: "expected_revision", .integer).notNull().defaults(to: 0)
                t.add(column: "epoch", .integer).notNull().defaults(to: 0)
            }
            try db.alter(table: "mentor_items") { t in
                t.add(column: "supersedes_item_id", .text).references("mentor_items")
            }
            try db.create(table: "mentor_corrections") { t in
                t.column("command_id", .text).primaryKey()
                t.column("session_id", .text).notNull().references("mentor_sessions", onDelete: .cascade)
                t.column("item_id", .text).notNull().unique()
                t.column("expected_revision", .integer).notNull()
                t.foreignKey(["session_id", "item_id"], references: "mentor_items", columns: ["session_id", "id"], onDelete: .cascade)
            }
        }
        migrator.registerMigration("v58_mentor_recent_sessions_index") { db in
            try db.execute(sql: "CREATE INDEX mentor_sessions_activity_identity ON mentor_sessions(activity_at DESC, id DESC)")
        }
        migrator.registerMigration("v59_mentor_presentation_receipts") { db in
            try db.alter(table: "mentor_sessions") { t in
                t.add(column: "recall_count", .integer).notNull().defaults(to: 0)
            }
            try db.alter(table: "mentor_items") { t in
                t.add(column: "presented_at", .text)
                t.add(column: "presentation_day", .text)
                t.add(column: "presentation_time_zone", .text)
                t.add(column: "requires_material", .boolean).notNull().defaults(to: false)
            }
        }
    }
}

final class SQLiteCaptureFragmentRepository: CaptureFragmentRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    func save(_ fragment: CaptureFragment) async throws -> CaptureFragment {
        try await database.dbQueue.write { db in
            if let sourceID = fragment.sourceID,
               let row = try CaptureFragmentRow.filter(Column("source") == fragment.source.rawValue && Column("source_id") == sourceID).fetchOne(db) {
                return try row.domainModel()
            }
            try CaptureFragmentRow(fragment).insert(db)
            return fragment
        }
    }

    func fragments(forDayKey dayKey: String, statuses: [CaptureFragment.Status]?) async throws -> [CaptureFragment] {
        try await database.dbQueue.read { db in
            var request = CaptureFragmentRow.filter(Column("day_key") == dayKey)
            if let statuses { request = request.filter(statuses.map(\.rawValue).contains(Column("status"))) }
            return try request.order(Column("created_at").asc).fetchAll(db).map { try $0.domainModel() }
        }
    }

    func archive(id: UUID) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "UPDATE capture_fragments SET status = ?, updated_at = ? WHERE id = ?", arguments: [CaptureFragment.Status.archived.rawValue, VNextStorage.string(from: .now), id.uuidString])
        }
    }

    func saveDigest(_ digest: DailyCaptureDigest, markingIncluded fragmentIDs: [UUID]) async throws {
        try await database.dbQueue.write { db in
            let requestedIDs = Set(fragmentIDs.map(\.uuidString))
            let digestIDs = Set(digest.sourceFragmentIDs.map(\.uuidString))
            let fragments = try CaptureFragmentRow
                .filter(requestedIDs.contains(Column("id")))
                .fetchAll(db)
            guard !requestedIDs.isEmpty,
                  requestedIDs.count == fragmentIDs.count,
                  digestIDs == requestedIDs,
                  fragments.count == requestedIDs.count,
                  fragments.allSatisfy({
                      $0.dayKey == digest.dayKey && $0.status == CaptureFragment.Status.pending.rawValue
                  })
            else {
                throw PersistenceError.validationFailed("capture digest sources must be pending fragments from the same day")
            }

            let updatedAt = VNextStorage.string(from: .now)
            try db.execute(
                sql: "UPDATE daily_capture_digests SET status = ?, updated_at = ? WHERE day_key = ? AND status = ?",
                arguments: [DailyCaptureDigest.Status.ignored.rawValue, updatedAt, digest.dayKey, DailyCaptureDigest.Status.current.rawValue]
            )
            try DailyCaptureDigestRow(digest).insert(db)
            for id in fragmentIDs {
                try db.execute(
                    sql: "UPDATE capture_fragments SET status = ?, updated_at = ? WHERE id = ? AND status = ?",
                    arguments: [CaptureFragment.Status.included.rawValue, updatedAt, id.uuidString, CaptureFragment.Status.pending.rawValue]
                )
            }
        }
    }

    func currentDigest(forDayKey dayKey: String) async throws -> DailyCaptureDigest? {
        try await database.dbQueue.read { db in
            try DailyCaptureDigestRow.filter(Column("day_key") == dayKey && Column("status") == DailyCaptureDigest.Status.current.rawValue).fetchOne(db).map { try $0.domainModel() }
        }
    }

    func updateDigestStatus(_ status: DailyCaptureDigest.Status, id: UUID) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "UPDATE daily_capture_digests SET status = ?, updated_at = ? WHERE id = ?", arguments: [status.rawValue, VNextStorage.string(from: .now), id.uuidString])
        }
    }
}

final class SQLiteTrainingCaseRepository: TrainingCaseRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    func saveCase(_ trainingCase: TrainingCase) async throws {
        try await database.dbQueue.write { db in try TrainingCaseRow(trainingCase).upsert(db) }
    }

    func caseRecord(id: UUID) async throws -> TrainingCase? {
        try await database.dbQueue.read { db in try TrainingCaseRow.fetchOne(db, key: id.uuidString)?.domainModel() }
    }

    func cases(for dailyEntryId: UUID) async throws -> [TrainingCase] {
        try await database.dbQueue.read { db in
            try TrainingCaseRow.filter(Column("daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("sort_order").asc, Column("created_at").asc)
                .fetchAll(db).map { try $0.domainModel() }
        }
    }

    func updateStatus(_ status: TrainingCaseStatus, caseId: UUID) async throws {
        try await database.dbQueue.write { db in
            try db.execute(sql: "UPDATE training_cases SET status = ?, updated_at = ? WHERE id = ?", arguments: [status.rawValue, VNextStorage.string(from: .now), caseId.uuidString])
        }
    }

    func assignCards(_ cardIds: [UUID], to caseId: UUID) async throws {
        try await database.dbQueue.write { db in
            for cardId in cardIds {
                try db.execute(sql: "UPDATE thinking_cards SET case_id = ? WHERE id = ?", arguments: [caseId.uuidString, cardId.uuidString])
            }
        }
    }
}

final class SQLiteTrainingCaseSessionRepository: TrainingCaseSessionRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }
    func saveSession(_ session: TrainingCaseSession) async throws {
        try await database.dbQueue.write { db in
            var row = TrainingCaseSessionRow(session)
            if let existing = try TrainingCaseSessionRow
                .filter(Column("case_id") == session.caseId.uuidString)
                .fetchOne(db) {
                row.id = existing.id
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }
    func session(for caseId: UUID) async throws -> TrainingCaseSession? { try await database.dbQueue.read { db in try TrainingCaseSessionRow.filter(Column("case_id") == caseId.uuidString).fetchOne(db)?.domainModel() } }
}

final class SQLiteTrainingCaseRelationshipRepository: TrainingCaseRelationshipRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }
    func saveMerge(_ merge: TrainingCaseMerge) async throws {
        guard merge.sourceCaseId != merge.targetCaseId else { throw PersistenceError.validationFailed("A training case cannot merge into itself") }
        try await database.dbQueue.write { db in
            let sourceDay = try String.fetchOne(
                db,
                sql: "SELECT daily_entry_id FROM training_cases WHERE id = ?",
                arguments: [merge.sourceCaseId.uuidString]
            )
            let targetDay = try String.fetchOne(
                db,
                sql: "SELECT daily_entry_id FROM training_cases WHERE id = ?",
                arguments: [merge.targetCaseId.uuidString]
            )
            guard let sourceDay, sourceDay == targetDay else {
                throw PersistenceError.validationFailed("Only same-day training cases can merge")
            }
            let verificationCount = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*) FROM verifications v
                JOIN quests q ON q.id = v.quest_id
                WHERE q.case_id IN (?, ?) AND v.deleted_at IS NULL
                """,
                arguments: [merge.sourceCaseId.uuidString, merge.targetCaseId.uuidString]
            ) ?? 0
            guard verificationCount == 0 else {
                throw PersistenceError.validationFailed("Verified training cases cannot merge")
            }
            try TrainingCaseMergeRow(merge).upsert(db)
        }
    }
    func activeMerges(for dailyEntryId: UUID) async throws -> [TrainingCaseMerge] {
        try await database.dbQueue.read { db in
            try TrainingCaseMergeRow.fetchAll(db, sql: "SELECT m.* FROM training_case_merges m JOIN training_cases c ON c.id = m.source_case_id WHERE c.daily_entry_id = ? AND m.status = ?", arguments: [dailyEntryId.uuidString, TrainingCaseRelationshipStatus.active.rawValue]).map { try $0.domainModel() }
        }
    }
    func revertMerge(id: UUID) async throws { try await database.dbQueue.write { db in try db.execute(sql: "UPDATE training_case_merges SET status = ?, reverted_at = ? WHERE id = ?", arguments: [TrainingCaseRelationshipStatus.reverted.rawValue, VNextStorage.string(from: .now), id.uuidString]) } }
    func saveLink(_ link: TrainingCaseLink) async throws {
        guard link.sourceCaseId != link.targetCaseId else {
            throw PersistenceError.validationFailed("A training case cannot link to itself")
        }
        try await database.dbQueue.write { db in
            let sourceDay = try String.fetchOne(db, sql: "SELECT daily_entry_id FROM training_cases WHERE id = ?", arguments: [link.sourceCaseId.uuidString])
            let targetDay = try String.fetchOne(db, sql: "SELECT daily_entry_id FROM training_cases WHERE id = ?", arguments: [link.targetCaseId.uuidString])
            guard let sourceDay, let targetDay, sourceDay != targetDay else {
                throw PersistenceError.validationFailed("Cross-day links require different DailyEntry records")
            }
            try TrainingCaseLinkRow(link).upsert(db)
        }
    }
}

final class SQLiteProjectClosureReviewRepository: ProjectClosureReviewRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }
    func saveReview(_ review: ProjectClosureReview) async throws {
        guard !review.outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PersistenceError.validationFailed("Project closure requires an outcome") }
        try await database.dbQueue.write { db in try ProjectClosureReviewRow(review).upsert(db) }
    }
    func closeProject(_ project: Project, review: ProjectClosureReview) async throws {
        guard project.id == review.projectId else {
            throw PersistenceError.validationFailed("Project closure review does not belong to project")
        }
        guard project.status == .archived else {
            throw PersistenceError.validationFailed("Closed project must be archived")
        }
        try await database.dbQueue.write { db in
            try ProjectClosureReviewRow(review).upsert(db)
            var row = ProjectRow(project: project)
            if let existing = try ProjectRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }
    func review(for projectId: UUID) async throws -> ProjectClosureReview? { try await database.dbQueue.read { db in try ProjectClosureReviewRow.filter(Column("project_id") == projectId.uuidString).fetchOne(db)?.domainModel() } }
}

final class SQLiteGrowthSettlementRepository: GrowthSettlementRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }
    func saveSettlement(_ settlement: GrowthSettlement) async throws { try await database.dbQueue.write { db in try GrowthSettlementRow(settlement).upsert(db) } }
    func settlement(for verificationId: UUID) async throws -> GrowthSettlement? { try await database.dbQueue.read { db in try GrowthSettlementRow.filter(Column("verification_id") == verificationId.uuidString).fetchOne(db)?.domainModel() } }
    func recentSettlements(limit: Int) async throws -> [GrowthSettlement] {
        try await database.dbQueue.read { db in
            try GrowthSettlementRow
                .order(Column("created_at").desc)
                .limit(max(0, limit))
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLiteVerificationSettlementRepository: VerificationSettlementRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    func saveVerification(
        _ verification: Verification,
        questStatus: QuestStatus,
        settlement: GrowthSettlement
    ) async throws {
        guard settlement.verificationId == verification.id else {
            throw PersistenceError.validationFailed("Settlement must reference the saved verification")
        }
        try await database.dbQueue.write { db in
            let now = VNextStorage.string(from: .now)
            try db.execute(
                sql: """
                INSERT INTO verifications (
                    id, quest_id, quest_title, source_daily_entry_id, completion, value_rating,
                    judgment_update, evidence_text, calibration_note, likely_issue, recommendation,
                    created_at, updated_at, deleted_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                    quest_title = excluded.quest_title,
                    completion = excluded.completion,
                    value_rating = excluded.value_rating,
                    judgment_update = excluded.judgment_update,
                    evidence_text = excluded.evidence_text,
                    calibration_note = excluded.calibration_note,
                    likely_issue = excluded.likely_issue,
                    recommendation = excluded.recommendation,
                    updated_at = excluded.updated_at,
                    deleted_at = NULL
                """,
                arguments: [
                    verification.id.uuidString,
                    verification.questId.uuidString,
                    verification.questTitle,
                    verification.sourceDailyEntryId.uuidString,
                    verification.completion.rawValue,
                    verification.valueRating.rawValue,
                    verification.judgmentUpdate.rawValue,
                    verification.evidenceText,
                    verification.calibrationNote,
                    verification.likelyIssue,
                    verification.recommendation,
                    VNextStorage.string(from: verification.createdAt),
                    now
                ]
            )
            try db.execute(
                sql: "UPDATE quests SET status = ?, updated_at = ? WHERE id = ?",
                arguments: [questStatus.rawValue, now, verification.questId.uuidString]
            )
            try GrowthSettlementRow(settlement).upsert(db)
        }
    }
}

final class SQLiteGuidanceRepository: GuidanceRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }
    func saveState(_ state: UserGuidanceState) async throws { try await database.dbQueue.write { db in try UserGuidanceStateRow(state).upsert(db) } }
    func state(for hintId: String) async throws -> UserGuidanceState? { try await database.dbQueue.read { db in try UserGuidanceStateRow.fetchOne(db, key: hintId)?.domainModel() } }
    func allStates() async throws -> [UserGuidanceState] { try await database.dbQueue.read { db in try UserGuidanceStateRow.fetchAll(db).map { try $0.domainModel() } } }
    func saveFeedback(_ feedback: CoachTurnFeedback) async throws { try await database.dbQueue.write { db in try CoachTurnFeedbackRow(feedback).insert(db) } }
}

final class SQLiteWeeklyGuidanceReviewRepository: WeeklyGuidanceReviewRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveReview(_ review: WeeklyGuidanceReviewRecord) async throws {
        guard !review.weekKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !review.selection.trainingFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !review.selection.hintIds.isEmpty,
              !review.selection.evidenceRefs.isEmpty
        else {
            throw PersistenceError.validationFailed("Weekly guidance review requires a week, focus, hints, and evidence")
        }
        try await database.dbQueue.write { db in
            try WeeklyGuidanceReviewRow(review).insert(db)
        }
    }

    func review(forWeekKey weekKey: String) async throws -> WeeklyGuidanceReviewRecord? {
        try await database.dbQueue.read { db in
            try WeeklyGuidanceReviewRow.fetchOne(db, key: weekKey)?.domainModel()
        }
    }
}

final class SQLiteSideQuestRepository: SideQuestRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func savePhotoMemory(_ memory: SideQuestPhotoMemory) async throws {
        guard !memory.assetLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("A photo memory requires a local photo identifier")
        }
        try await database.dbQueue.write { db in
            _ = try requiredRun(id: memory.runId, db: db)
            try SideQuestPhotoMemoryRow(memory).insert(db)
        }
    }

    func photoMemories(for runId: UUID) async throws -> [SideQuestPhotoMemory] {
        try await database.dbQueue.read { db in
            try SideQuestPhotoMemoryRow
                .filter(Column("run_id") == runId.uuidString)
                .order(Column("created_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func markPhotoMemoryUnavailable(id: UUID) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE side_quest_photo_memories SET unavailable = 1 WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }

    func preference() async throws -> SideQuestPreference {
        try await database.dbQueue.read { db in
            try SideQuestPreferenceRow.fetchOne(db, key: SideQuestPreference.primaryID)?.domainModel()
                ?? SideQuestPreference()
        }
    }

    func savePreference(_ preference: SideQuestPreference) async throws {
        try validate(preference)
        try await database.dbQueue.write { db in
            var value = preference
            value.updatedAt = .now
            var row = SideQuestPreferenceRow(value)
            if let existing = try SideQuestPreferenceRow.fetchOne(db, key: preference.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func lifeContextProfile() async throws -> SideQuestLifeContextProfile {
        try await database.dbQueue.read { db in
            try SideQuestLifeContextProfileRow.fetchOne(db, key: SideQuestLifeContextProfile.primaryID)?.domainModel()
                ?? SideQuestLifeContextProfile()
        }
    }

    func saveLifeContextProfile(_ profile: SideQuestLifeContextProfile) async throws {
        try validate(profile)
        try await database.dbQueue.write { db in
            var value = profile
            value.updatedAt = .now
            var row = SideQuestLifeContextProfileRow(value)
            if let existing = try SideQuestLifeContextProfileRow.fetchOne(db, key: profile.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func run(id: UUID) async throws -> SideQuestRun? {
        try await database.dbQueue.read { db in
            try SideQuestRunRow.fetchOne(db, key: id.uuidString)?.domainModel()
        }
    }

    func openRun() async throws -> SideQuestRun? {
        try await database.dbQueue.read { db in
            try SideQuestRunRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_runs WHERE status IN ('offered', 'accepted', 'deferred') ORDER BY offered_at DESC LIMIT 1"
            )?.domainModel()
        }
    }

    func recentRuns(limit: Int) async throws -> [SideQuestRun] {
        try await database.dbQueue.read { db in
            try SideQuestRunRow
                .order(Column("offered_at").desc)
                .limit(max(0, limit))
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func activeSeason(at date: Date = .now) async throws -> SideQuestExplorationSeason? {
        try await database.dbQueue.write { db in
            try finishExpiredSeasonIfNeeded(at: date, db: db)
            return try SideQuestExplorationSeasonRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_exploration_seasons WHERE status = 'active' LIMIT 1"
            )?.domainModel()
        }
    }

    func season(id: UUID) async throws -> SideQuestExplorationSeason? {
        try await database.dbQueue.read { db in
            try SideQuestExplorationSeasonRow.fetchOne(db, key: id.uuidString)?.domainModel()
        }
    }

    func latestSeason() async throws -> SideQuestExplorationSeason? {
        try await database.dbQueue.read { db in
            try SideQuestExplorationSeasonRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_exploration_seasons ORDER BY started_at DESC LIMIT 1"
            )?.domainModel()
        }
    }

    func seasonCategorySummary(id: UUID) async throws -> [SideQuestCategory: Int] {
        try await database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT category, COUNT(*) AS count FROM side_quest_runs WHERE season_id = ? GROUP BY category",
                arguments: [id.uuidString]
            )
            return rows.reduce(into: [SideQuestCategory: Int]()) { result, row in
                guard let category = SideQuestCategory(rawValue: row["category"] as String) else { return }
                let count: Int = row["count"]
                result[category] = count
            }
        }
    }

    func startSeason(title: String, intent: String?, at date: Date = .now) async throws -> SideQuestExplorationSeason {
        let candidate = SideQuestExplorationSeason(title: title, intent: intent, startedAt: date)
        try validate(candidate)
        return try await database.dbQueue.write { db in
            try finishExpiredSeasonIfNeeded(at: date, db: db)
            if let existing = try SideQuestExplorationSeasonRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_exploration_seasons WHERE status = 'active' LIMIT 1"
            )?.domainModel() {
                return existing
            }
            try SideQuestExplorationSeasonRow(candidate).insert(db)
            return candidate
        }
    }

    func closeSeason(
        status: SideQuestExplorationSeasonStatus,
        at date: Date = .now
    ) async throws -> SideQuestExplorationSeason? {
        guard status == .completed || status == .abandoned else {
            throw PersistenceError.validationFailed("An exploration season can only be completed or ended early")
        }
        return try await database.dbQueue.write { db in
            guard var season = try SideQuestExplorationSeasonRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_exploration_seasons WHERE status = 'active' LIMIT 1"
            )?.domainModel() else {
                return nil
            }
            season.status = status
            try SideQuestExplorationSeasonRow(season).update(db)
            return season
        }
    }

    func offerHistory() async throws -> [String: Date] {
        try await database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT catalog_id, MAX(offered_at) AS offered_at FROM side_quest_runs GROUP BY catalog_id"
            )
            return rows.reduce(into: [String: Date]()) { result, row in
                let catalogID: String = row["catalog_id"]
                let offeredAt: String = row["offered_at"]
                result[catalogID] = VNextStorage.date(from: offeredAt)
            }
        }
    }

    func planningRecord(forDayKey dayKey: String) async throws -> SideQuestPlanningRecord? {
        try await database.dbQueue.read { db in
            try SideQuestPlanningRecordRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_planning_records WHERE day_key = ? LIMIT 1",
                arguments: [dayKey]
            )?.domainModel()
        }
    }

    func offer(_ run: SideQuestRun) async throws {
        guard run.status == .offered else {
            throw PersistenceError.validationFailed("A new side quest must begin as an offer")
        }
        try validate(run)
        try await database.dbQueue.write { db in
            try rejectIfOpenRunExists(db)
            let linkedRun = try attachToActiveSeason(run, db: db)
            try SideQuestRunRow(linkedRun).insert(db)
        }
    }

    func recordPlanningResult(
        preference: SideQuestPreference,
        planningRecord: SideQuestPlanningRecord,
        offeredRun: SideQuestRun?
    ) async throws -> Bool {
        try await database.dbQueue.write { db in
            // The day key is the idempotency key. A competing launch must
            // preserve the first complete decision rather than updating the
            // preference or attempting a second invitation.
            if try SideQuestPlanningRecordRow.fetchOne(
                db,
                sql: "SELECT * FROM side_quest_planning_records WHERE day_key = ? LIMIT 1",
                arguments: [planningRecord.dayKey]
            ) != nil {
                return false
            }
            try validate(preference)
            try validate(planningRecord: planningRecord, offeredRun: offeredRun, preference: preference)
            var value = preference
            value.updatedAt = .now
            var preferenceRow = SideQuestPreferenceRow(value)
            if let existing = try SideQuestPreferenceRow.fetchOne(db, key: preference.id) {
                preferenceRow.createdAt = existing.createdAt
            }
            try preferenceRow.upsert(db)
            try SideQuestPlanningRecordRow(planningRecord).insert(db)
            if let offeredRun {
                try rejectIfOpenRunExists(db)
                let linkedRun = try attachToActiveSeason(offeredRun, db: db)
                try SideQuestRunRow(linkedRun).insert(db)
            }
            return true
        }
    }

    func accept(runId: UUID, at date: Date = .now) async throws -> SideQuestRun {
        try await database.dbQueue.write { db in
            var run = try requiredRun(id: runId, db: db)
            if run.status == .accepted { return run }
            guard run.status == .offered || run.status == .deferred else {
                throw PersistenceError.validationFailed("Only an offered side quest can be accepted")
            }
            run.status = .accepted
            run.acceptedAt = run.acceptedAt ?? date
            run.deferredUntil = nil
            run.updatedAt = date
            try SideQuestRunRow(run).update(db)
            try synchronizeSeasonProgress(for: run.seasonId, db: db)
            return run
        }
    }

    func deferRun(runId: UUID, until date: Date, at now: Date = .now) async throws -> SideQuestRun {
        guard date > now else {
            throw PersistenceError.validationFailed("A side quest can only be deferred to a future time")
        }
        return try await database.dbQueue.write { db in
            var run = try requiredRun(id: runId, db: db)
            guard run.status == .offered || run.status == .accepted || run.status == .deferred else {
                throw PersistenceError.validationFailed("Only an open side quest can be deferred")
            }
            run.status = .deferred
            run.acceptedAt = run.acceptedAt ?? now
            run.deferredUntil = date
            run.updatedAt = now
            try SideQuestRunRow(run).update(db)
            try synchronizeSeasonProgress(for: run.seasonId, db: db)
            return run
        }
    }

    func decline(runId: UUID, at date: Date = .now) async throws -> SideQuestRun {
        try await database.dbQueue.write { db in
            var run = try requiredRun(id: runId, db: db)
            if run.status == .declined { return run }
            guard run.status.occupiesInvitationSlot else {
                throw PersistenceError.validationFailed("Only an open side quest can be declined")
            }
            run.status = .declined
            run.deferredUntil = nil
            run.updatedAt = date
            try SideQuestRunRow(run).update(db)
            try synchronizeSeasonProgress(for: run.seasonId, db: db)
            return run
        }
    }

    func complete(
        runId: UUID,
        reflection: String?,
        at date: Date = .now
    ) async throws -> SideQuestExperienceEvent {
        let normalizedReflection = reflection?.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await database.dbQueue.write { db in
            var run = try requiredRun(id: runId, db: db)
            if run.status == .completed,
               let existing = try SideQuestExperienceEventRow
                .filter(Column("side_quest_run_id") == runId.uuidString)
                .fetchOne(db)?
                .domainModel() {
                return existing
            }
            guard run.status.canComplete else {
                throw PersistenceError.validationFailed("Only an accepted side quest can earn experience")
            }
            guard try SideQuestExperienceEventRow
                .filter(Column("side_quest_run_id") == runId.uuidString)
                .fetchOne(db) == nil else {
                throw PersistenceError.validationFailed("A side quest can only award experience once")
            }

            run.status = .completed
            run.completedAt = date
            run.deferredUntil = nil
            run.reflection = normalizedReflection?.isEmpty == false ? normalizedReflection : nil
            run.updatedAt = date
            try SideQuestRunRow(run).update(db)

            let event = SideQuestExperienceEvent(
                sideQuestRunId: run.id,
                track: run.reward.track,
                completionExperience: run.reward.completionExperience,
                reflectionBonusExperience: run.reflection == nil ? 0 : run.reward.reflectionBonusExperience,
                streakCount: try nextStreakCount(at: date, db: db),
                occurredAt: date
            )
            try SideQuestExperienceEventRow(event).insert(db)
            try synchronizeSeasonProgress(for: run.seasonId, db: db)
            return event
        }
    }

    func experience(for runId: UUID) async throws -> SideQuestExperienceEvent? {
        try await database.dbQueue.read { db in
            try SideQuestExperienceEventRow
                .filter(Column("side_quest_run_id") == runId.uuidString)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func experienceEvents(limit: Int) async throws -> [SideQuestExperienceEvent] {
        try await database.dbQueue.read { db in
            try SideQuestExperienceEventRow
                .order(Column("occurred_at").desc)
                .limit(max(0, limit))
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func experienceSummary(now: Date = .now) async throws -> SideQuestExperienceSummary {
        try await database.dbQueue.read { db in
            let events = try SideQuestExperienceEventRow
                .order(Column("occurred_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
            guard !events.isEmpty else { return .empty }
            var byTrack: [SideQuestGrowthTrack: Int] = [:]
            for event in events {
                byTrack[event.track, default: 0] += event.totalExperience
            }
            let calendar = Calendar.current
            let latest = events[0]
            let currentStreak = calendar.isDate(latest.occurredAt, inSameDayAs: now) ||
                calendar.isDate(latest.occurredAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
                ? latest.streakCount
                : 0
            return SideQuestExperienceSummary(
                totalExperience: events.reduce(0) { $0 + $1.totalExperience },
                currentStreak: currentStreak,
                longestStreak: events.map(\.streakCount).max() ?? 0,
                experienceByTrack: byTrack
            )
        }
    }

    func trialMetrics(since: Date, through: Date) async throws -> SideQuestTrialMetrics {
        try await database.dbQueue.read { db in
            let planningRecords = try SideQuestPlanningRecordRow
                .filter(Column("planned_at") >= VNextStorage.string(from: since) && Column("planned_at") <= VNextStorage.string(from: through))
                .fetchAll(db)
                .map { try $0.domainModel() }
            let runs = try SideQuestRunRow
                .filter(Column("offered_at") >= VNextStorage.string(from: since) && Column("offered_at") <= VNextStorage.string(from: through))
                .fetchAll(db)
                .map { try $0.domainModel() }
            let corrections = try SideQuestCorrectionEventRow
                .filter(Column("occurred_at") >= VNextStorage.string(from: since) && Column("occurred_at") <= VNextStorage.string(from: through))
                .fetchAll(db)
                .map { try $0.domainModel() }
            let calendar = Calendar.current
            var correctionsByKind: [SideQuestCorrectionKind: Int] = [:]
            for correction in corrections { correctionsByKind[correction.kind, default: 0] += 1 }
            var offersByCategory: [SideQuestCategory: Int] = [:]
            for run in runs { offersByCategory[run.category, default: 0] += 1 }
            return SideQuestTrialMetrics(
                observationStart: since,
                observationEnd: through,
                planningDecisions: planningRecords.count,
                holds: planningRecords.filter { $0.decision == .hold }.count,
                offers: runs.count,
                accepted: runs.filter {
                    $0.acceptedAt != nil && [.accepted, .deferred, .completed].contains($0.status)
                }.count,
                completed: runs.filter { $0.status == .completed }.count,
                deferred: runs.filter { $0.status == .deferred }.count,
                declined: runs.filter { $0.status == .declined }.count,
                expired: runs.filter { $0.status == .expired }.count,
                correctionsByKind: correctionsByKind,
                offersByCategory: offersByCategory,
                completedWithReflection: runs.filter { $0.status == .completed && $0.reflection?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count,
                aiGeneratedOffers: runs.filter { $0.origin == .aiGenerated }.count,
                uniqueOfferDays: Set(runs.map { calendar.startOfDay(for: $0.offeredAt) }).count
            )
        }
    }

    func saveCorrection(_ correction: SideQuestCorrectionEvent, resolvingRunId: UUID? = nil) async throws {
        try await database.dbQueue.write { db in
            if let runId = resolvingRunId {
                var run = try requiredRun(id: runId, db: db)
                if run.status.occupiesInvitationSlot {
                    run.status = run.status == .offered ? .declined : .expired
                    run.deferredUntil = nil
                    run.updatedAt = correction.occurredAt
                    try SideQuestRunRow(run).update(db)
                    try synchronizeSeasonProgress(for: run.seasonId, db: db)
                }
            }
            try SideQuestCorrectionEventRow(correction).insert(db)
        }
    }

    func recentCorrections(limit: Int) async throws -> [SideQuestCorrectionEvent] {
        try await database.dbQueue.read { db in
            try SideQuestCorrectionEventRow
                .order(Column("occurred_at").desc)
                .limit(max(0, min(limit, 20)))
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

#if DEBUG
    func clearOpenRunsForVisualQA() async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE side_quest_runs SET status = 'expired', updated_at = ? WHERE status IN ('offered', 'accepted', 'deferred')",
                arguments: [VNextStorage.string(from: .now)]
            )
        }
    }
#endif

    private func validate(_ preference: SideQuestPreference) throws {
        guard preference.id == SideQuestPreference.primaryID else {
            throw PersistenceError.validationFailed("Only one side quest preference profile is supported")
        }
        guard !preference.rotationSeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("Side quest rotation requires a stable seed")
        }
        if preference.isEnabled && preference.enabledCategories.isEmpty {
            throw PersistenceError.validationFailed("Enabled side quests require at least one category")
        }
        if preference.notificationsEnabled {
            guard preference.notificationSchedule?.isValid == true else {
                throw PersistenceError.validationFailed("Side quest notifications require a valid time window")
            }
        }
    }

    private func validate(_ profile: SideQuestLifeContextProfile) throws {
        guard profile.id == SideQuestLifeContextProfile.primaryID else {
            throw PersistenceError.validationFailed("Only one side quest life context profile is supported")
        }
        let floorLevels = [
            profile.homePracticalContext.floorLevel,
            profile.workplacePracticalContext.floorLevel,
            profile.legacyFloorCount
        ]
        if floorLevels.compactMap({ $0 }).contains(where: { !(0...300).contains($0) }) {
            throw PersistenceError.validationFailed("Floor count must be between 0 and 300")
        }
        guard profile.constraints.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 180 }) else {
            throw PersistenceError.validationFailed("Life context constraints must be nonempty and concise")
        }
    }

    private func validate(_ season: SideQuestExplorationSeason) throws {
        guard !season.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              season.title.count <= 80,
              season.intent?.count ?? 0 <= 240,
              season.maxDays == SideQuestExplorationSeason.defaultMaxDays,
              season.endsAt > season.startedAt
        else {
            throw PersistenceError.validationFailed("An exploration season needs a concise theme and thirty-day range")
        }
    }

    private func attachToActiveSeason(_ run: SideQuestRun, db: Database) throws -> SideQuestRun {
        var linkedRun = run
        try finishExpiredSeasonIfNeeded(at: run.offeredAt, db: db)
        let active = try SideQuestExplorationSeasonRow.fetchOne(
            db,
            sql: "SELECT * FROM side_quest_exploration_seasons WHERE status = 'active' LIMIT 1"
        )?.domainModel()
        guard let active else {
            guard run.seasonId == nil else {
                throw PersistenceError.validationFailed("The exploration season is no longer active")
            }
            return linkedRun
        }
        guard run.offeredAt >= active.startedAt, run.offeredAt < active.endsAt else {
            throw PersistenceError.validationFailed("The exploration season has ended")
        }
        guard run.seasonId == nil || run.seasonId == active.id else {
            throw PersistenceError.validationFailed("A side quest cannot be attached to another exploration season")
        }
        linkedRun.seasonId = active.id
        let elapsedDays = Calendar.current.dateComponents([.day], from: active.startedAt, to: run.offeredAt).day ?? 0
        linkedRun.seasonDay = min(active.maxDays, max(1, elapsedDays + 1))
        linkedRun.seasonStep = linkedRun.seasonStep ?? "invitation"
        return linkedRun
    }

    private func synchronizeSeasonProgress(for seasonId: UUID?, db: Database) throws {
        guard let seasonId else { return }
        let counts = try Row.fetchOne(
            db,
            sql: """
            SELECT
                SUM(CASE WHEN accepted_at IS NOT NULL THEN 1 ELSE 0 END) AS accepted_count,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_count,
                SUM(CASE WHEN status IN ('declined', 'expired') THEN 1 ELSE 0 END) AS skipped_count
            FROM side_quest_runs WHERE season_id = ?
            """,
            arguments: [seasonId.uuidString]
        )
        let accepted: Int = counts?["accepted_count"] ?? 0
        let completed: Int = counts?["completed_count"] ?? 0
        let skipped: Int = counts?["skipped_count"] ?? 0
        try db.execute(
            sql: "UPDATE side_quest_exploration_seasons SET accepted_count = ?, completed_count = ?, skipped_count = ? WHERE id = ?",
            arguments: [accepted, completed, skipped, seasonId.uuidString]
        )
    }

    private func finishExpiredSeasonIfNeeded(at date: Date, db: Database) throws {
        try db.execute(
            sql: "UPDATE side_quest_exploration_seasons SET status = 'completed' WHERE status = 'active' AND ends_at <= ?",
            arguments: [VNextStorage.string(from: date)]
        )
    }

    private func validate(_ run: SideQuestRun) throws {
        guard !run.catalogId.isEmpty,
              !run.catalogVersion.isEmpty,
              !run.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !run.invitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              run.minimumMinutes >= 0,
              run.maximumMinutes >= run.minimumMinutes,
              run.reward.completionExperience > 0,
              run.reward.reflectionBonusExperience >= 0
        else {
            throw PersistenceError.validationFailed("Side quest offer has an invalid catalog snapshot")
        }
        if run.origin == .aiGenerated {
            guard run.promptRunId != nil,
                  run.decisionRationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PersistenceError.validationFailed("AI side quests require a traced decision and rationale")
            }
        }
    }

    private func validate(
        planningRecord: SideQuestPlanningRecord,
        offeredRun: SideQuestRun?,
        preference: SideQuestPreference
    ) throws {
        guard !planningRecord.dayKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              preference.lastAIPlanningAt != nil,
              preference.lastAIPlanningPromptRunId == planningRecord.promptRunId
        else {
            throw PersistenceError.validationFailed("Side quest planning audit must match the saved preference")
        }
        switch planningRecord.decision {
        case .offer:
            guard let offeredRun,
                  offeredRun.origin == .aiGenerated,
                  offeredRun.promptRunId == planningRecord.promptRunId else {
                throw PersistenceError.validationFailed("An offer decision requires its traced invitation")
            }
        case .hold:
            guard offeredRun == nil else {
                throw PersistenceError.validationFailed("A hold decision cannot create an invitation")
            }
        }
    }

    private func requiredRun(id: UUID, db: Database) throws -> SideQuestRun {
        guard let row = try SideQuestRunRow.fetchOne(db, key: id.uuidString) else {
            throw PersistenceError.validationFailed("Side quest run does not exist")
        }
        return try row.domainModel()
    }

    private func rejectIfOpenRunExists(_ db: Database) throws {
        let count = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM side_quest_runs WHERE status IN ('offered', 'accepted', 'deferred')"
        ) ?? 0
        guard count == 0 else {
            throw PersistenceError.validationFailed("Resolve the current side quest before receiving another invitation")
        }
    }

    private func nextStreakCount(at date: Date, db: Database) throws -> Int {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT occurred_at, streak_count FROM side_quest_experience_events ORDER BY occurred_at DESC LIMIT 1"
        ) else {
            return 1
        }
        let latestDate = VNextStorage.date(from: row["occurred_at"] as String)
        let latestStreak: Int = row["streak_count"]
        let calendar = Calendar.current
        guard !calendar.isDate(latestDate, inSameDayAs: date) else {
            return max(1, latestStreak)
        }
        return calendar.isDate(latestDate, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
            ? max(1, latestStreak + 1)
            : 1
    }
}

final class SQLiteCoachPromptTurnRepository: CoachPromptTurnRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func recordOutcome(
        promptRunId: UUID,
        promptId: PromptID,
        outcome: CoachPromptTurnOutcome,
        detail: String?
    ) async throws {
        try await database.dbQueue.write { db in
            guard let run = try PromptRunRow.fetchOne(db, key: promptRunId.uuidString) else {
                throw PersistenceError.validationFailed("Coach turn requires a traced PromptRun")
            }
            guard run.promptId == promptId.rawValue else {
                throw PersistenceError.validationFailed("Coach turn PromptID does not match PromptRun")
            }

            if let existing = try CoachPromptTurnRow.fetchOne(db, key: promptRunId.uuidString),
               CoachPromptTurnOutcome(rawValue: existing.outcome) == .presented {
                return
            }

            let now = VNextStorage.string(from: .now)
            var row = CoachPromptTurnRow(
                CoachPromptTurn(
                    promptRunId: promptRunId,
                    promptId: promptId,
                    outcome: outcome,
                    detail: detail?.trimmingCharacters(in: .whitespacesAndNewlines),
                    createdAt: .now,
                    updatedAt: .now
                )
            )
            if let existing = try CoachPromptTurnRow.fetchOne(db, key: promptRunId.uuidString) {
                row.createdAt = existing.createdAt
            }
            row.updatedAt = now
            try row.upsert(db)
        }
    }

    func markPresented(
        promptRunId: UUID,
        caseSessionId: UUID,
        caseId: UUID,
        promptId: PromptID,
        outputFingerprint: String
    ) async throws {
        let fingerprint = outputFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fingerprint.isEmpty else {
            throw PersistenceError.validationFailed("Presented coach turn requires an output fingerprint")
        }

        try await database.dbQueue.write { db in
            guard let runRow = try PromptRunRow.fetchOne(db, key: promptRunId.uuidString) else {
                throw PersistenceError.validationFailed("Presented coach turn requires a traced PromptRun")
            }
            let run = try runRow.domainModel()
            guard run.promptId == promptId.rawValue,
                  run.sourceRecordIds.contains(caseId.uuidString) else {
                throw PersistenceError.validationFailed("Presented coach turn does not belong to the active case")
            }
            guard let storedCaseId = try String.fetchOne(
                db,
                sql: "SELECT case_id FROM training_case_sessions WHERE id = ?",
                arguments: [caseSessionId.uuidString]
            ), storedCaseId == caseId.uuidString else {
                throw PersistenceError.validationFailed("Coach turn session does not belong to the active case")
            }
            guard var row = try CoachPromptTurnRow.fetchOne(db, key: promptRunId.uuidString),
                  CoachPromptTurnOutcome(rawValue: row.outcome) == .responseReceived else {
                throw PersistenceError.validationFailed("Only a received coach response can be presented")
            }

            row.caseSessionId = caseSessionId.uuidString
            row.promptId = promptId.rawValue
            row.outcome = CoachPromptTurnOutcome.presented.rawValue
            row.outputFingerprint = fingerprint
            row.detail = nil
            row.updatedAt = VNextStorage.string(from: .now)
            try row.upsert(db)
        }
    }

    func presentedTurn(
        caseSessionId: UUID,
        promptId: PromptID,
        outputFingerprint: String
    ) async throws -> CoachPromptTurn? {
        let fingerprint = outputFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fingerprint.isEmpty else { return nil }
        return try await database.dbQueue.read { db in
            try CoachPromptTurnRow
                .filter(Column("case_session_id") == caseSessionId.uuidString)
                .filter(Column("prompt_id") == promptId.rawValue)
                .filter(Column("outcome") == CoachPromptTurnOutcome.presented.rawValue)
                .filter(Column("output_fingerprint") == fingerprint)
                .order(Column("updated_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func qualitySummaries(limit: Int) async throws -> [CoachPromptQualitySummary] {
        let maximum = max(0, limit)
        guard maximum > 0 else { return [] }
        return try await database.dbQueue.read { db in
            let turns = try CoachPromptTurnRow
                .order(Column("updated_at").desc)
                .limit(maximum)
                .fetchAll(db)
                .map { try $0.domainModel() }
            guard !turns.isEmpty else { return [] }

            var records: [CoachPromptQualityRecord] = []
            for turn in turns {
                guard let run = try PromptRunRow.fetchOne(db, key: turn.promptRunId.uuidString)?.domainModel() else {
                    continue
                }
                let feedback = try CoachTurnFeedbackRow
                    .filter(Column("prompt_run_id") == turn.promptRunId.uuidString)
                    .fetchAll(db)
                    .map { try $0.domainModel() }
                records.append(CoachPromptQualityRecord(turn: turn, run: run, feedback: feedback))
            }
            return CoachPromptQualitySummary.summaries(for: records)
        }
    }
}

private struct CaptureFragmentRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "capture_fragments"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, rawText, source, status, dayKey, createdAt, updatedAt: String
    var sourceId: String?
    init(_ value: CaptureFragment) {
        id = value.id.uuidString; rawText = value.rawText; source = value.source.rawValue; status = value.status.rawValue; dayKey = value.dayKey; sourceId = value.sourceID; createdAt = VNextStorage.string(from: value.createdAt); updatedAt = VNextStorage.string(from: value.updatedAt)
    }
    func domainModel() throws -> CaptureFragment {
        guard let id = UUID(uuidString: id), let source = CaptureFragment.Source(rawValue: source), let status = CaptureFragment.Status(rawValue: status) else { throw PersistenceError.invalidStoredValue("capture_fragments") }
        return CaptureFragment(id: id, rawText: rawText, source: source, status: status, dayKey: dayKey, sourceID: sourceId, createdAt: VNextStorage.date(from: createdAt), updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private struct DailyCaptureDigestRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_capture_digests"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, dayKey, status, summary, themesJson, sourceFragmentIdsJson, createdAt, updatedAt: String
    var recommendedQuestion: String?
    init(_ value: DailyCaptureDigest) {
        id = value.id.uuidString; dayKey = value.dayKey; status = value.status.rawValue; summary = value.summary; themesJson = (try? VNextStorage.encode(value.themes)) ?? "[]"; recommendedQuestion = value.recommendedQuestion; sourceFragmentIdsJson = (try? VNextStorage.encode(value.sourceFragmentIDs.map(\.uuidString))) ?? "[]"; createdAt = VNextStorage.string(from: value.createdAt); updatedAt = VNextStorage.string(from: value.updatedAt)
    }
    func domainModel() throws -> DailyCaptureDigest {
        guard let id = UUID(uuidString: id), let status = DailyCaptureDigest.Status(rawValue: status) else { throw PersistenceError.invalidStoredValue("daily_capture_digests") }
        let themes: [String] = try VNextStorage.decode(themesJson) ?? []
        let sourceIDs: [String] = try VNextStorage.decode(sourceFragmentIdsJson) ?? []
        return DailyCaptureDigest(id: id, dayKey: dayKey, status: status, summary: summary, themes: themes, recommendedQuestion: recommendedQuestion, sourceFragmentIDs: sourceIDs.compactMap(UUID.init(uuidString:)), createdAt: VNextStorage.date(from: createdAt), updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private struct TrainingCaseRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "training_cases"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, dailyEntryId, title, status, createdBy, createdAt, updatedAt: String
    var sortOrder: Int
    var deletedAt: String?
    init(_ value: TrainingCase) { id = value.id.uuidString; dailyEntryId = value.dailyEntryId.uuidString; title = value.title; status = value.status.rawValue; sortOrder = value.sortOrder; createdBy = value.createdBy.rawValue; createdAt = VNextStorage.string(from: value.createdAt); updatedAt = VNextStorage.string(from: value.updatedAt); deletedAt = nil }
    func domainModel() throws -> TrainingCase {
        guard let uuid = UUID(uuidString: id), let entry = UUID(uuidString: dailyEntryId), let statusValue = TrainingCaseStatus(rawValue: status), let creator = TrainingCaseCreatedBy(rawValue: createdBy) else { throw PersistenceError.invalidStoredValue("training_cases") }
        return TrainingCase(id: uuid, dailyEntryId: entry, title: title, status: statusValue, sortOrder: sortOrder, createdBy: creator, createdAt: VNextStorage.date(from: createdAt), updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private struct TrainingCaseSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "training_case_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, caseId, loopState, sessionMode, createdAt, updatedAt: String
    var selectedLensId, trainingPrescriptionJson: String?
    init(_ value: TrainingCaseSession) { id = value.id.uuidString; caseId = value.caseId.uuidString; loopState = value.loopState.rawValue; sessionMode = value.sessionMode.rawValue; selectedLensId = value.selectedLensId; trainingPrescriptionJson = value.trainingPrescription.flatMap { try? VNextStorage.encode($0) }; createdAt = VNextStorage.string(from: value.createdAt); updatedAt = VNextStorage.string(from: value.updatedAt) }
    func domainModel() throws -> TrainingCaseSession {
        guard let uuid = UUID(uuidString: id), let caseUUID = UUID(uuidString: caseId), let state = DailyLoopState(rawValue: loopState), let mode = SessionMode(rawValue: sessionMode) else { throw PersistenceError.invalidStoredValue("training_case_sessions") }
        let storedPrescription = trainingPrescriptionJson?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prescription: TrainingPrescription? = storedPrescription == "null"
            ? nil
            : try VNextStorage.decode(storedPrescription)
        return TrainingCaseSession(id: uuid, caseId: caseUUID, loopState: state, sessionMode: mode, selectedLensId: selectedLensId, trainingPrescription: prescription, createdAt: VNextStorage.date(from: createdAt), updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private struct TrainingCaseMergeRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "training_case_merges"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, sourceCaseId, targetCaseId, status, createdAt: String
    var revertedAt: String?
    init(_ value: TrainingCaseMerge) { id = value.id.uuidString; sourceCaseId = value.sourceCaseId.uuidString; targetCaseId = value.targetCaseId.uuidString; status = value.status.rawValue; createdAt = VNextStorage.string(from: value.createdAt); revertedAt = value.revertedAt.map { VNextStorage.string(from: $0) } }
    func domainModel() throws -> TrainingCaseMerge {
        guard let uuid = UUID(uuidString: id), let source = UUID(uuidString: sourceCaseId), let target = UUID(uuidString: targetCaseId), let statusValue = TrainingCaseRelationshipStatus(rawValue: status) else { throw PersistenceError.invalidStoredValue("training_case_merges") }
        return TrainingCaseMerge(id: uuid, sourceCaseId: source, targetCaseId: target, status: statusValue, createdAt: VNextStorage.date(from: createdAt), revertedAt: revertedAt.map { VNextStorage.date(from: $0) })
    }
}

private struct TrainingCaseLinkRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "training_case_links"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, sourceCaseId, targetCaseId, kind, createdAt: String
    init(_ value: TrainingCaseLink) { id = value.id.uuidString; sourceCaseId = value.sourceCaseId.uuidString; targetCaseId = value.targetCaseId.uuidString; kind = value.kind.rawValue; createdAt = VNextStorage.string(from: value.createdAt) }
}

private struct ProjectClosureReviewRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project_closure_reviews"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, projectId, reason, outcome, evidenceRefsJson, previousStatus, createdAt, updatedAt: String
    var transferredItems, reviewNote, aiSummary: String?
    var principleCandidatesJson: String
    init(_ value: ProjectClosureReview) { id = value.id.uuidString; projectId = value.projectId.uuidString; reason = value.reason.rawValue; outcome = value.outcome; evidenceRefsJson = (try? VNextStorage.encode(value.evidenceRefs)) ?? "[]"; transferredItems = value.transferredItems; reviewNote = value.reviewNote; aiSummary = value.aiSummary; principleCandidatesJson = (try? VNextStorage.encode(value.principleCandidates)) ?? "[]"; previousStatus = value.previousStatus.rawValue; createdAt = VNextStorage.string(from: value.createdAt); updatedAt = VNextStorage.string(from: value.updatedAt) }
    func domainModel() throws -> ProjectClosureReview {
        guard let uuid = UUID(uuidString: id), let projectUUID = UUID(uuidString: projectId), let reasonValue = ProjectClosureReason(rawValue: reason), let previous = ProjectStatus(rawValue: previousStatus) else { throw PersistenceError.invalidStoredValue("project_closure_reviews") }
        let refs: [String] = (try VNextStorage.decode(evidenceRefsJson)) ?? []
        let candidates: [ProjectClosurePrincipleCandidate] = (try VNextStorage.decode(principleCandidatesJson)) ?? []
        return ProjectClosureReview(id: uuid, projectId: projectUUID, reason: reasonValue, outcome: outcome, evidenceRefs: refs, transferredItems: transferredItems, reviewNote: reviewNote, aiSummary: aiSummary, principleCandidates: candidates, previousStatus: previous, createdAt: VNextStorage.date(from: createdAt), updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private struct GrowthSettlementRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "growth_settlements"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, verificationId, originalJudgment, actualResult, judgmentUpdate, evidenceItemsJson, createdAt: String
    var caseId: String?
    init(_ value: GrowthSettlement) { id = value.id.uuidString; verificationId = value.verificationId.uuidString; caseId = value.caseId?.uuidString; originalJudgment = value.originalJudgment; actualResult = value.actualResult; judgmentUpdate = value.judgmentUpdate.rawValue; evidenceItemsJson = (try? VNextStorage.encode(value.evidenceItems)) ?? "[]"; createdAt = VNextStorage.string(from: value.createdAt) }
    func domainModel() throws -> GrowthSettlement {
        guard let uuid = UUID(uuidString: id), let verificationUUID = UUID(uuidString: verificationId), let update = YesterdayJudgmentUpdate(rawValue: judgmentUpdate) else { throw PersistenceError.invalidStoredValue("growth_settlements") }
        let items: [GrowthSettlementEvidenceItem] = (try VNextStorage.decode(evidenceItemsJson)) ?? []
        return GrowthSettlement(id: uuid, verificationId: verificationUUID, caseId: caseId.flatMap(UUID.init(uuidString:)), originalJudgment: originalJudgment, actualResult: actualResult, judgmentUpdate: update, evidenceItems: items, createdAt: VNextStorage.date(from: createdAt))
    }
}

private struct UserGuidanceStateRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_guidance_states"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var hintId, status, evidenceRefsJson, updatedAt: String
    var evidenceCount, counterexampleCount: Int
    var lastShownAt, snoozedUntil: String?
    init(_ value: UserGuidanceState) { hintId = value.hintId; status = value.status.rawValue; evidenceCount = value.evidenceCount; counterexampleCount = value.counterexampleCount; lastShownAt = value.lastShownAt.map { VNextStorage.string(from: $0) }; snoozedUntil = value.snoozedUntil.map { VNextStorage.string(from: $0) }; evidenceRefsJson = (try? VNextStorage.encode(value.evidenceRefs)) ?? "[]"; updatedAt = VNextStorage.string(from: value.updatedAt) }
    func domainModel() throws -> UserGuidanceState {
        guard let statusValue = GuidanceMasteryStatus(rawValue: status) else { throw PersistenceError.invalidStoredValue("user_guidance_states") }
        let refs: [String] = (try VNextStorage.decode(evidenceRefsJson)) ?? []
        return UserGuidanceState(hintId: hintId, status: statusValue, evidenceCount: evidenceCount, counterexampleCount: counterexampleCount, lastShownAt: lastShownAt.map { VNextStorage.date(from: $0) }, snoozedUntil: snoozedUntil.map { VNextStorage.date(from: $0) }, evidenceRefs: refs, updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private struct SideQuestPreferenceRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_preferences"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, enabledCategoriesJson, frequency, rotationSeed, createdAt, updatedAt: String
    var consentStatus: String
    var notificationsEnabled: Bool
    var notificationScheduleJson, lastAiPlanningAt, lastAiPlanningPromptRunId: String?

    init(_ value: SideQuestPreference) {
        id = value.id
        consentStatus = value.consentStatus.rawValue
        enabledCategoriesJson = (try? VNextStorage.encode(value.enabledCategories.map(\.rawValue).sorted())) ?? "[]"
        frequency = value.frequency.rawValue
        notificationsEnabled = value.notificationsEnabled
        notificationScheduleJson = value.notificationSchedule.flatMap { try? VNextStorage.encode($0) }
        lastAiPlanningAt = value.lastAIPlanningAt.map { VNextStorage.string(from: $0) }
        lastAiPlanningPromptRunId = value.lastAIPlanningPromptRunId?.uuidString
        rotationSeed = value.rotationSeed
        createdAt = VNextStorage.string(from: value.createdAt)
        updatedAt = VNextStorage.string(from: value.updatedAt)
    }

    func domainModel() throws -> SideQuestPreference {
        let categoryIDs: [String] = (try VNextStorage.decode(enabledCategoriesJson)) ?? []
        let categories = categoryIDs.compactMap(SideQuestCategory.init(rawValue:))
        guard categories.count == categoryIDs.count,
              let consent = SideQuestConsentStatus(rawValue: consentStatus),
              let offerFrequency = SideQuestOfferFrequency(rawValue: frequency) else {
            throw PersistenceError.invalidStoredValue("side_quest_preferences")
        }
        let schedule: SideQuestNotificationSchedule? = try VNextStorage.decode(notificationScheduleJson)
        return SideQuestPreference(
            id: id,
            consentStatus: consent,
            enabledCategories: Set(categories),
            frequency: offerFrequency,
            notificationsEnabled: notificationsEnabled,
            notificationSchedule: schedule,
            lastAIPlanningAt: lastAiPlanningAt.map { VNextStorage.date(from: $0) },
            lastAIPlanningPromptRunId: lastAiPlanningPromptRunId.flatMap(UUID.init(uuidString:)),
            rotationSeed: rotationSeed,
            createdAt: VNextStorage.date(from: createdAt),
            updatedAt: VNextStorage.date(from: updatedAt)
        )
    }
}

private struct SideQuestLifeContextProfileRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_life_context_profiles"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, commuteModesJson, movementPreferencesJson, unavailableCategoriesJson, constraintsJson, createdAt, updatedAt: String
    var homeLabel, workLabel, preferredActivityRadius: String?
    var floorCount, homeFloorLevel, workplaceFloorLevel: Int?
    var homeStairsAvailable, workplaceStairsAvailable: Bool?
    var transitionWindowsJson: String

    init(_ value: SideQuestLifeContextProfile) {
        id = value.id
        homeLabel = value.homeLabel
        workLabel = value.workLabel
        floorCount = value.legacyFloorCount
        homeFloorLevel = value.homePracticalContext.floorLevel
        homeStairsAvailable = value.homePracticalContext.stairsAvailable
        workplaceFloorLevel = value.workplacePracticalContext.floorLevel
        workplaceStairsAvailable = value.workplacePracticalContext.stairsAvailable
        transitionWindowsJson = (try? VNextStorage.encode(value.transitionWindows.map(\.rawValue).sorted())) ?? "[]"
        commuteModesJson = (try? VNextStorage.encode(value.commuteModes.map(\.rawValue).sorted())) ?? "[]"
        preferredActivityRadius = value.preferredActivityRadius?.rawValue
        movementPreferencesJson = (try? VNextStorage.encode(value.movementPreferences.map(\.rawValue).sorted())) ?? "[]"
        unavailableCategoriesJson = (try? VNextStorage.encode(value.unavailableCategories.map(\.rawValue).sorted())) ?? "[]"
        constraintsJson = (try? VNextStorage.encode(value.constraints)) ?? "[]"
        createdAt = VNextStorage.string(from: value.createdAt)
        updatedAt = VNextStorage.string(from: value.updatedAt)
    }

    func domainModel() throws -> SideQuestLifeContextProfile {
        let commuteModeIDs: [String] = (try VNextStorage.decode(commuteModesJson)) ?? []
        let movementPreferenceIDs: [String] = (try VNextStorage.decode(movementPreferencesJson)) ?? []
        let unavailableCategoryIDs: [String] = (try VNextStorage.decode(unavailableCategoriesJson)) ?? []
        let constraints: [String] = (try VNextStorage.decode(constraintsJson)) ?? []
        let transitionWindowIDs: [String] = (try VNextStorage.decode(transitionWindowsJson)) ?? []
        let commuteModes = commuteModeIDs.compactMap(SideQuestCommuteMode.init(rawValue:))
        let movementPreferences = movementPreferenceIDs.compactMap(SideQuestMovementPreference.init(rawValue:))
        let unavailableCategories = unavailableCategoryIDs.compactMap(SideQuestCategory.init(rawValue:))
        let transitionWindows = transitionWindowIDs.compactMap(SideQuestTransitionWindow.init(rawValue:))
        guard commuteModes.count == commuteModeIDs.count,
              movementPreferences.count == movementPreferenceIDs.count,
              unavailableCategories.count == unavailableCategoryIDs.count,
              transitionWindows.count == transitionWindowIDs.count,
              let radius = preferredActivityRadius.map(SideQuestActivityRadius.init(rawValue:)) ?? .some(nil)
        else {
            throw PersistenceError.invalidStoredValue("side_quest_life_context_profiles")
        }
        return SideQuestLifeContextProfile(
            id: id,
            homeLabel: homeLabel,
            workLabel: workLabel,
            homePracticalContext: .init(floorLevel: homeFloorLevel, stairsAvailable: homeStairsAvailable),
            workplacePracticalContext: .init(floorLevel: workplaceFloorLevel, stairsAvailable: workplaceStairsAvailable),
            transitionWindows: Set(transitionWindows),
            legacyFloorCount: floorCount,
            commuteModes: Set(commuteModes),
            preferredActivityRadius: radius,
            movementPreferences: Set(movementPreferences),
            unavailableCategories: Set(unavailableCategories),
            constraints: constraints,
            createdAt: VNextStorage.date(from: createdAt),
            updatedAt: VNextStorage.date(from: updatedAt)
        )
    }
}

private struct SideQuestRunRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_runs"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, catalogId, catalogVersion, origin, category, title, invitation, evidencePrompt: String
    var promptRunId, decisionRationale: String?
    var prerequisitesJson: String
    var minimumMinutes, maximumMinutes: Int
    var rewardTrack: String
    var completionExperience, reflectionBonusExperience: Int
    var status, offeredAt, createdAt, updatedAt: String
    var acceptedAt, deferredUntil, completedAt, reflection, notificationTitle, notificationBody: String?
    var seasonId: String?
    var seasonDay: Int?
    var seasonStep: String?

    init(_ value: SideQuestRun) {
        id = value.id.uuidString
        catalogId = value.catalogId
        catalogVersion = value.catalogVersion
        origin = value.origin.rawValue
        promptRunId = value.promptRunId?.uuidString
        decisionRationale = value.decisionRationale
        category = value.category.rawValue
        title = value.title
        invitation = value.invitation
        evidencePrompt = value.evidencePrompt
        prerequisitesJson = (try? VNextStorage.encode(value.prerequisites)) ?? "[]"
        minimumMinutes = value.minimumMinutes
        maximumMinutes = value.maximumMinutes
        rewardTrack = value.reward.track.rawValue
        completionExperience = value.reward.completionExperience
        reflectionBonusExperience = value.reward.reflectionBonusExperience
        status = value.status.rawValue
        offeredAt = VNextStorage.string(from: value.offeredAt)
        acceptedAt = value.acceptedAt.map { VNextStorage.string(from: $0) }
        deferredUntil = value.deferredUntil.map { VNextStorage.string(from: $0) }
        completedAt = value.completedAt.map { VNextStorage.string(from: $0) }
        reflection = value.reflection
        notificationTitle = value.notificationTitle
        notificationBody = value.notificationBody
        seasonId = value.seasonId?.uuidString
        seasonDay = value.seasonDay
        seasonStep = value.seasonStep
        createdAt = VNextStorage.string(from: value.createdAt)
        updatedAt = VNextStorage.string(from: value.updatedAt)
    }

    func domainModel() throws -> SideQuestRun {
        guard let runID = UUID(uuidString: id),
              let categoryValue = SideQuestCategory(rawValue: category),
              let track = SideQuestGrowthTrack(rawValue: rewardTrack),
              let originValue = SideQuestRunOrigin(rawValue: origin),
              let statusValue = SideQuestRunStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("side_quest_runs")
        }
        let prerequisites: [SideQuestPrerequisite] = (try VNextStorage.decode(prerequisitesJson)) ?? []
        return SideQuestRun(
            id: runID,
            catalogId: catalogId,
            catalogVersion: catalogVersion,
            origin: originValue,
            promptRunId: promptRunId.flatMap(UUID.init(uuidString:)),
            decisionRationale: decisionRationale,
            category: categoryValue,
            title: title,
            invitation: invitation,
            evidencePrompt: evidencePrompt,
            prerequisites: prerequisites,
            minimumMinutes: minimumMinutes,
            maximumMinutes: maximumMinutes,
            reward: SideQuestReward(
                track: track,
                completionExperience: completionExperience,
                reflectionBonusExperience: reflectionBonusExperience
            ),
            status: statusValue,
            offeredAt: VNextStorage.date(from: offeredAt),
            acceptedAt: acceptedAt.map { VNextStorage.date(from: $0) },
            deferredUntil: deferredUntil.map { VNextStorage.date(from: $0) },
            completedAt: completedAt.map { VNextStorage.date(from: $0) },
            reflection: reflection,
            notificationTitle: notificationTitle,
            notificationBody: notificationBody,
            seasonId: seasonId.flatMap(UUID.init(uuidString:)),
            seasonDay: seasonDay,
            seasonStep: seasonStep,
            createdAt: VNextStorage.date(from: createdAt),
            updatedAt: VNextStorage.date(from: updatedAt)
        )
    }
}

private struct SideQuestExplorationSeasonRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_exploration_seasons"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, title, startedAt, endsAt, status: String
    var intent: String?
    var maxDays, acceptedCount, completedCount, skippedCount: Int

    init(_ value: SideQuestExplorationSeason) {
        id = value.id.uuidString
        title = value.title
        intent = value.intent
        startedAt = VNextStorage.string(from: value.startedAt)
        endsAt = VNextStorage.string(from: value.endsAt)
        status = value.status.rawValue
        maxDays = value.maxDays
        acceptedCount = value.acceptedCount
        completedCount = value.completedCount
        skippedCount = value.skippedCount
    }

    func domainModel() throws -> SideQuestExplorationSeason {
        guard let id = UUID(uuidString: id),
              let status = SideQuestExplorationSeasonStatus(rawValue: status),
              maxDays == SideQuestExplorationSeason.defaultMaxDays
        else {
            throw PersistenceError.invalidStoredValue("side_quest_exploration_seasons")
        }
        return SideQuestExplorationSeason(
            id: id,
            title: title,
            intent: intent,
            startedAt: VNextStorage.date(from: startedAt),
            endsAt: VNextStorage.date(from: endsAt),
            status: status,
            maxDays: maxDays,
            acceptedCount: acceptedCount,
            completedCount: completedCount,
            skippedCount: skippedCount
        )
    }
}

private struct SideQuestPlanningRecordRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_planning_records"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, dayKey, decision, promptRunId, plannedAt: String

    init(_ value: SideQuestPlanningRecord) {
        id = value.id.uuidString
        dayKey = value.dayKey
        decision = value.decision.rawValue
        promptRunId = value.promptRunId.uuidString
        plannedAt = VNextStorage.string(from: value.plannedAt)
    }

    func domainModel() throws -> SideQuestPlanningRecord {
        guard let id = UUID(uuidString: id),
              let promptRunId = UUID(uuidString: promptRunId),
              let decision = SideQuestPlanningDecision(rawValue: decision) else {
            throw PersistenceError.invalidStoredValue("side_quest_planning_records")
        }
        return SideQuestPlanningRecord(
            id: id,
            dayKey: dayKey,
            decision: decision,
            promptRunId: promptRunId,
            plannedAt: VNextStorage.date(from: plannedAt)
        )
    }
}

private struct SideQuestExperienceEventRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_experience_events"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, sideQuestRunId, track, occurredAt: String
    var completionExperience, reflectionBonusExperience, streakCount: Int

    init(_ value: SideQuestExperienceEvent) {
        id = value.id.uuidString
        sideQuestRunId = value.sideQuestRunId.uuidString
        track = value.track.rawValue
        completionExperience = value.completionExperience
        reflectionBonusExperience = value.reflectionBonusExperience
        streakCount = value.streakCount
        occurredAt = VNextStorage.string(from: value.occurredAt)
    }

    func domainModel() throws -> SideQuestExperienceEvent {
        guard let eventID = UUID(uuidString: id),
              let runID = UUID(uuidString: sideQuestRunId),
              let trackValue = SideQuestGrowthTrack(rawValue: track) else {
            throw PersistenceError.invalidStoredValue("side_quest_experience_events")
        }
        return SideQuestExperienceEvent(
            id: eventID,
            sideQuestRunId: runID,
            track: trackValue,
            completionExperience: completionExperience,
            reflectionBonusExperience: reflectionBonusExperience,
            streakCount: streakCount,
            occurredAt: VNextStorage.date(from: occurredAt)
        )
    }
}

private struct SideQuestPhotoMemoryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_photo_memories"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id, assetLocalIdentifier, runId, createdAt: String
    var unavailable: Bool

    init(_ value: SideQuestPhotoMemory) {
        id = value.id.uuidString
        assetLocalIdentifier = value.assetLocalIdentifier
        runId = value.runId.uuidString
        createdAt = VNextStorage.string(from: value.createdAt)
        unavailable = value.unavailable
    }

    func domainModel() throws -> SideQuestPhotoMemory {
        guard let id = UUID(uuidString: id), let runId = UUID(uuidString: runId) else {
            throw PersistenceError.invalidStoredValue("side_quest_photo_memories")
        }
        return SideQuestPhotoMemory(
            id: id,
            assetLocalIdentifier: assetLocalIdentifier,
            runId: runId,
            createdAt: VNextStorage.date(from: createdAt),
            unavailable: unavailable
        )
    }
}

private struct SideQuestCorrectionEventRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "side_quest_correction_events"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var sideQuestRunId: String?
    var kind: String
    var note: String?
    var occurredAt: String

    init(_ value: SideQuestCorrectionEvent) {
        id = value.id.uuidString
        sideQuestRunId = value.sideQuestRunId?.uuidString
        kind = value.kind.rawValue
        note = value.note
        occurredAt = VNextStorage.string(from: value.occurredAt)
    }

    func domainModel() throws -> SideQuestCorrectionEvent {
        guard let eventID = UUID(uuidString: id),
              let kindValue = SideQuestCorrectionKind(rawValue: kind) else {
            throw PersistenceError.invalidStoredValue("side_quest_correction_events")
        }
        return SideQuestCorrectionEvent(
            id: eventID,
            sideQuestRunId: sideQuestRunId.flatMap(UUID.init(uuidString:)),
            kind: kindValue,
            note: note,
            occurredAt: VNextStorage.date(from: occurredAt)
        )
    }
}

private struct WeeklyGuidanceReviewRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "weekly_guidance_reviews"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var weekKey: String
    var trainingFocus: String
    var hintIdsJson: String
    var evidenceRefsJson: String
    var generatedAt: String

    init(_ value: WeeklyGuidanceReviewRecord) {
        weekKey = value.weekKey
        trainingFocus = value.selection.trainingFocus
        hintIdsJson = (try? VNextStorage.encode(value.selection.hintIds)) ?? "[]"
        evidenceRefsJson = (try? VNextStorage.encode(value.selection.evidenceRefs)) ?? "[]"
        generatedAt = VNextStorage.string(from: value.generatedAt)
    }

    func domainModel() throws -> WeeklyGuidanceReviewRecord {
        let hintIds: [String] = (try VNextStorage.decode(hintIdsJson)) ?? []
        let evidenceRefs: [String] = (try VNextStorage.decode(evidenceRefsJson)) ?? []
        return WeeklyGuidanceReviewRecord(
            weekKey: weekKey,
            selection: WeeklyGuidanceReviewSelection(
                trainingFocus: trainingFocus,
                hintIds: hintIds,
                evidenceRefs: evidenceRefs
            ),
            generatedAt: VNextStorage.date(from: generatedAt)
        )
    }
}

private struct CoachTurnFeedbackRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "coach_turn_feedback"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    var id, caseSessionId, value, createdAt: String
    var promptRunId, coachObservationId, note: String?
    init(_ value: CoachTurnFeedback) { id = value.id.uuidString; caseSessionId = value.caseSessionId.uuidString; promptRunId = value.promptRunId?.uuidString; coachObservationId = value.coachObservationId; self.value = value.value.rawValue; note = value.note; createdAt = VNextStorage.string(from: value.createdAt) }
    func domainModel() throws -> CoachTurnFeedback {
        guard let uuid = UUID(uuidString: id),
              let sessionId = UUID(uuidString: caseSessionId),
              let feedbackValue = CoachTurnFeedbackValue(rawValue: value) else {
            throw PersistenceError.invalidStoredValue("coach_turn_feedback")
        }
        return CoachTurnFeedback(
            id: uuid,
            caseSessionId: sessionId,
            promptRunId: promptRunId.flatMap(UUID.init(uuidString:)),
            coachObservationId: coachObservationId,
            value: feedbackValue,
            note: note,
            createdAt: VNextStorage.date(from: createdAt)
        )
    }
}

private struct CoachPromptTurnRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "coach_prompt_turns"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var promptRunId, promptId, outcome, createdAt, updatedAt: String
    var caseSessionId, outputFingerprint, detail: String?

    init(_ value: CoachPromptTurn) {
        promptRunId = value.promptRunId.uuidString
        caseSessionId = value.caseSessionId?.uuidString
        promptId = value.promptId.rawValue
        outcome = value.outcome.rawValue
        outputFingerprint = value.outputFingerprint
        detail = value.detail
        createdAt = VNextStorage.string(from: value.createdAt)
        updatedAt = VNextStorage.string(from: value.updatedAt)
    }

    func domainModel() throws -> CoachPromptTurn {
        guard let runId = UUID(uuidString: promptRunId),
              let prompt = PromptID(rawValue: promptId),
              let lifecycle = CoachPromptTurnOutcome(rawValue: outcome) else {
            throw PersistenceError.invalidStoredValue("coach_prompt_turns")
        }
        return CoachPromptTurn(
            promptRunId: runId,
            caseSessionId: caseSessionId.flatMap(UUID.init(uuidString:)),
            promptId: prompt,
            outcome: lifecycle,
            outputFingerprint: outputFingerprint,
            detail: detail,
            createdAt: VNextStorage.date(from: createdAt),
            updatedAt: VNextStorage.date(from: updatedAt)
        )
    }
}

final class SQLiteSingleNudgeSessionRepository: SingleNudgeSessionRepository {
    private let database: AppDatabase
    init(database: AppDatabase) { self.database = database }

    func save(_ session: SingleNudgeSession) async throws {
        try await database.dbQueue.write { db in
            var row = SingleNudgeSessionRow(session)
            if let existing = try SingleNudgeSessionRow.fetchOne(db, key: row.id) { row.createdAt = existing.createdAt }
            try row.upsert(db)
        }
    }

    func session(for dayKey: String) async throws -> SingleNudgeSession? {
        try await database.dbQueue.read { db in
            let rows = try SingleNudgeSessionRow.filter(Column("day_key") == dayKey)
                .order(Column("updated_at").desc)
                .fetchAll(db)
            if let unfinished = rows.first(where: { $0.lifecycle != SingleNudgeLifecycle.completed.rawValue }) {
                return try unfinished.domainModel()
            }
            return try rows.first?.domainModel()
        }
    }

    func latest() async throws -> SingleNudgeSession? {
        try await database.dbQueue.read { db in
            try SingleNudgeSessionRow.order(Column("updated_at").desc).fetchOne(db)?.domainModel()
        }
    }

    func session(id: UUID) async throws -> SingleNudgeSession? {
        try await database.dbQueue.read { db in
            try SingleNudgeSessionRow.fetchOne(db, key: id.uuidString)?.domainModel()
        }
    }
}

private struct SingleNudgeSessionRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "single_nudge_sessions"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    var id, dayKey, input, lifecycle, result, createdAt, updatedAt: String
    var question, diagnosis, beforeText, afterText, cognitiveShift, thinkingAction, unresolvedUncertainty, feedback: String?
    var transitionToVerification: Bool?
    var promptRunID: String?
    var reviewPromptRunID: String?
    var sourceRefs: String?
    var reviewSourceRefs: String?
    var parentSessionID: String?
    var rootSessionID: String?
    var continuationKind: String?
    enum CodingKeys: String, CodingKey {
        case id
        case dayKey = "day_key"
        case input, question, diagnosis
        case beforeText = "before_text"
        case afterText = "after_text"
        case cognitiveShift = "cognitive_shift"
        case thinkingAction = "thinking_action"
        case unresolvedUncertainty = "unresolved_uncertainty"
        case transitionToVerification = "transition_to_verification"
        case promptRunID = "prompt_run_id"
        case reviewPromptRunID = "review_prompt_run_id"
        case sourceRefs = "source_refs"
        case reviewSourceRefs = "review_source_refs"
        case parentSessionID = "parent_session_id"
        case rootSessionID = "root_session_id"
        case continuationKind = "continuation_kind"
        case lifecycle, result, feedback
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    init(_ value: SingleNudgeSession) {
        id = value.id.uuidString; dayKey = value.dayKey; input = value.input
        question = value.question; diagnosis = value.diagnosis; beforeText = value.before; afterText = value.after
        cognitiveShift = value.cognitiveShift; thinkingAction = value.thinkingAction; unresolvedUncertainty = value.unresolvedUncertainty
        transitionToVerification = value.transitionToVerification; promptRunID = value.promptRunID?.uuidString
        reviewPromptRunID = value.reviewPromptRunID?.uuidString
        sourceRefs = try? String(data: JSONEncoder().encode(value.sourceRefs), encoding: .utf8)
        reviewSourceRefs = try? String(data: JSONEncoder().encode(value.reviewSourceRefs), encoding: .utf8)
        parentSessionID = value.parentSessionID?.uuidString
        rootSessionID = value.rootSessionID.uuidString
        continuationKind = value.continuationKind.rawValue
        lifecycle = value.lifecycle.rawValue; result = value.result.rawValue; feedback = value.feedback?.rawValue
        createdAt = VNextStorage.string(from: value.createdAt); updatedAt = VNextStorage.string(from: value.updatedAt)
    }
    func domainModel() throws -> SingleNudgeSession {
        guard let uuid = UUID(uuidString: id), let lifecycle = SingleNudgeLifecycle(rawValue: lifecycle), let result = SingleNudgeResult(rawValue: result) else { throw PersistenceError.invalidStoredValue("single_nudge_sessions") }
        let refs = (sourceRefs?.data(using: .utf8)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let reviewRefs = (reviewSourceRefs?.data(using: .utf8)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        return SingleNudgeSession(id: uuid, dayKey: dayKey, input: input, question: question, diagnosis: diagnosis, before: beforeText, after: afterText, cognitiveShift: cognitiveShift, thinkingAction: thinkingAction, unresolvedUncertainty: unresolvedUncertainty, transitionToVerification: transitionToVerification, promptRunID: promptRunID.flatMap(UUID.init(uuidString:)), reviewPromptRunID: reviewPromptRunID.flatMap(UUID.init(uuidString:)), parentSessionID: parentSessionID.flatMap(UUID.init(uuidString:)), rootSessionID: rootSessionID.flatMap(UUID.init(uuidString:)) ?? uuid, continuationKind: continuationKind.flatMap(SingleNudgeContinuationKind.init(rawValue:)) ?? .initial, sourceRefs: refs, reviewSourceRefs: reviewRefs, lifecycle: lifecycle, result: result, feedback: feedback.flatMap(SingleNudgeFeedback.init(rawValue:)), createdAt: VNextStorage.date(from: createdAt), updatedAt: VNextStorage.date(from: updatedAt))
    }
}

private enum VNextStorage {
    static let formatter: ISO8601DateFormatter = { let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return value }()
    static let encoder: JSONEncoder = { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }()
    static let decoder: JSONDecoder = { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }()
    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from string: String) -> Date { formatter.date(from: string) ?? .now }
    static func encode<T: Encodable>(_ value: T) throws -> String { String(data: try encoder.encode(value), encoding: .utf8) ?? "" }
    static func decode<T: Decodable>(_ value: String?) throws -> T? { guard let value, let data = value.data(using: .utf8) else { return nil }; return try decoder.decode(T.self, from: data) }
    static func defaultCaseTitle(from rawText: String) -> String { let line = rawText.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""; return line.isEmpty ? "历史事项" : String(line.prefix(36)) }
    static func caseStatus(for state: String) -> String { switch DailyLoopState(rawValue: state) { case .sessionComplete: return TrainingCaseStatus.awaitingVerification.rawValue; case .capture, .organizing: return TrainingCaseStatus.pendingConfirmation.rawValue; case .none: return TrainingCaseStatus.ready.rawValue; default: return TrainingCaseStatus.inProgress.rawValue } }
}
