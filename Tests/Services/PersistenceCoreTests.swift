import XCTest
import GRDB
@testable import MingSi

final class PersistenceCoreTests: XCTestCase {

    private var database: AppDatabase!
    private var dbQueue: DatabaseQueue!

    override func setUp() {
        super.setUp()
        dbQueue = try! DatabaseQueue()
        let migrator = AppDatabase.makeMigrator()
        try! migrator.migrate(dbQueue)
        database = try! AppDatabase(dbQueue: dbQueue)
    }

    override func tearDown() {
        database = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - DailyEntryRepository

    func testSaveDraft_andLoadLatest() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let draft = DailyEntryDraft(
            rawText: "Test raw text for persistence.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .evidenceCheck,
            yesterdayCompletion: .done,
            yesterdayValueRating: .high,
            state: .capture
        )

        try await repo.saveDraft(draft)

        let loaded = try await repo.latestDraft()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.rawText, "Test raw text for persistence.")
        XCTAssertEqual(loaded?.sessionMode, .standard)
        XCTAssertTrue(loaded?.hasSelectedSessionMode == true)
        XCTAssertEqual(loaded?.selectedLens, .evidenceCheck)
        XCTAssertEqual(loaded?.yesterdayCompletion, .done)
        XCTAssertEqual(loaded?.yesterdayValueRating, .high)
        XCTAssertEqual(loaded?.state, .capture)
    }

    func testSaveDraft_upsertPreservesCreatedAt() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let draft = DailyEntryDraft(rawText: "First save", state: .capture)

        try await repo.saveDraft(draft)

        let first = try await repo.latestDraft()
        let firstCreatedAt = first.map { readCreatedAt(for: $0.id) }

        var updatedDraft = draft
        updatedDraft.rawText = "Second save"
        updatedDraft.state = .reviewCards
        try await repo.saveDraft(updatedDraft)

        let second = try await repo.latestDraft()
        XCTAssertEqual(second?.rawText, "Second save")
        XCTAssertEqual(second?.state, .reviewCards)
        XCTAssertEqual(second?.id, draft.id)

        let secondCreatedAt = second.map { readCreatedAt(for: $0.id) }
        XCTAssertEqual(firstCreatedAt, secondCreatedAt)
    }

    func testLatestDraft_returnsMostRecentlyUpdated() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)

        let older = DailyEntryDraft(rawText: "Older entry", state: .capture)
        try await repo.saveDraft(older)

        // Small sleep to ensure different timestamps
        try await Task.sleep(for: .milliseconds(50))

        let newer = DailyEntryDraft(rawText: "Newer entry", state: .reviewCards)
        try await repo.saveDraft(newer)

        let latest = try await repo.latestDraft()
        XCTAssertEqual(latest?.rawText, "Newer entry")
    }

    func testLatestDraft_prefersNewestEntryDateOverLaterUpdateTimestamp() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let today = DailyEntryDraft(rawText: "Today entry", state: .verifyYesterday)
        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: today.date) ?? today.date,
            rawText: "Yesterday entry",
            state: .sessionComplete
        )

        try await repo.saveDraft(today)
        try await Task.sleep(for: .milliseconds(50))
        try await repo.saveDraft(yesterday)

        let latest = try await repo.latestDraft()
        XCTAssertEqual(latest?.id, today.id)
        XCTAssertEqual(latest?.rawText, "Today entry")
    }

    func testLatestDraft_noDrafts_returnsNil() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let result = try await repo.latestDraft()
        XCTAssertNil(result)
    }

    func testSaveDraft_preservesAllLoopFields() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let draft = DailyEntryDraft(
            rawText: "Full loop test",
            sessionMode: .deep,
            hasSelectedSessionMode: true,
            selectedLens: .opposingView,
            yesterdayCompletion: .partial,
            yesterdayValueRating: .medium,
            state: .answerQuestions
        )

        try await repo.saveDraft(draft)
        let loaded = try await repo.latestDraft()
        let unwrapped = try XCTUnwrap(loaded)

        XCTAssertEqual(unwrapped.sessionMode, .deep)
        XCTAssertTrue(unwrapped.hasSelectedSessionMode)
        XCTAssertEqual(unwrapped.selectedLens, .opposingView)
        XCTAssertEqual(unwrapped.yesterdayCompletion, .partial)
        XCTAssertEqual(unwrapped.yesterdayValueRating, .medium)
        XCTAssertEqual(unwrapped.state, .answerQuestions)
    }

    // MARK: - ThinkingCardRepository

    func testSaveCards_andLoad() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Card test", state: .reviewCards)
        try await entryRepo.saveDraft(draft)

        let cards = [
            ThinkingCard(type: .problem, title: "Problem 1", body: "Body 1",
                         priority: .high, sensitivity: .normal, confidence: 0.85, isConfirmed: true),
            ThinkingCard(type: .task, title: "Task 1", body: "Body 2",
                         priority: .medium, sensitivity: .possiblySensitive, confidence: 0.72)
        ]
        try await cardRepo.saveCards(cards, dailyEntryId: draft.id)

        let loaded = try await cardRepo.cards(for: draft.id)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].title, "Problem 1")
        XCTAssertEqual(loaded[0].type, .problem)
        XCTAssertTrue(loaded[0].isConfirmed)
        XCTAssertEqual(loaded[1].sensitivity, .possiblySensitive)
    }

    func testSaveCards_softDeletesRemovedCards() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Delete test", state: .reviewCards)
        try await entryRepo.saveDraft(draft)

        let originalCards = [
            ThinkingCard(type: .fact, title: "Keep", body: "Body"),
            ThinkingCard(type: .fact, title: "Delete", body: "Body"),
            ThinkingCard(type: .fact, title: "Also delete", body: "Body")
        ]
        try await cardRepo.saveCards(originalCards, dailyEntryId: draft.id)

        let keptCards = [originalCards[0]]
        try await cardRepo.saveCards(keptCards, dailyEntryId: draft.id)

        let loaded = try await cardRepo.cards(for: draft.id)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Keep")
    }

    // MARK: - QuestRepository

    func testSaveQuests_andLoad() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Quest test", state: .reviewQuests)
        try await entryRepo.saveDraft(draft)

        let quests = [
            Quest(type: .main, title: "Main quest", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R", status: .active),
            Quest(type: .side, title: "Side quest", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R", status: .draft)
        ]
        try await questRepo.saveQuests(quests, sourceDailyEntryId: draft.id)

        let loaded = try await questRepo.quests(for: draft.id)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].type, .main)
        XCTAssertEqual(loaded[0].status, .active)
        XCTAssertEqual(loaded[1].type, .side)
    }

    func testActiveMainQuest_returnsActiveMainQuest() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Active quest test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let quests = [
            Quest(type: .main, title: "Active main", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R", status: .active)
        ]
        try await questRepo.saveQuests(quests, sourceDailyEntryId: draft.id)

        let active = try await questRepo.activeMainQuest()
        XCTAssertEqual(active?.title, "Active main")
        XCTAssertEqual(active?.type, .main)
        XCTAssertEqual(active?.status, .active)
    }

    func testActiveMainQuest_noActiveQuest_returnsNil() async throws {
        let questRepo = SQLiteQuestRepository(database: database)
        let result = try await questRepo.activeMainQuest()
        XCTAssertNil(result)
    }

    func testUpdateQuestStatus_marksActiveQuestResolved() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Quest status test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let quest = Quest(type: .main, title: "Active main", whyItMatters: "W",
                          completionCriteria: "C", expectedResistance: "E",
                          reflectionQuestion: "R", status: .active)
        try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)

        try await questRepo.updateQuestStatus(.completed, questId: quest.id)

        let active = try await questRepo.activeMainQuest()
        XCTAssertNil(active)

        let loaded = try await questRepo.quests(for: draft.id)
        XCTAssertEqual(loaded.first?.status, .completed)
    }

    // MARK: - PrincipleRepository

    func testSavePrinciples_andLoad() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Principle test", state: .extractPrinciple)
        try await entryRepo.saveDraft(draft)

        let principles = [
            PrincipleAsset(title: "Clarify before execution", summary: "Make ownership explicit.",
                          triggerContext: "Cross-functional work.", actions: ["Write owner.", "Write criteria."],
                          successCriteria: "People know who owns what.", exceptions: "Low-stakes sync.")
        ]
        try await principleRepo.savePrinciples(principles, sourceDailyEntryId: draft.id)

        let loaded = try await principleRepo.principles(for: draft.id)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Clarify before execution")
        XCTAssertEqual(loaded[0].actions.count, 2)
    }

    func testActivePrinciples_returnsOnlyActive() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Active principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let active = PrincipleAsset(title: "Active", summary: "S", triggerContext: "T",
                                     actions: ["A"], successCriteria: "SC", exceptions: "E", status: .active)
        let archived = PrincipleAsset(title: "Archived", summary: "S", triggerContext: "T",
                                       actions: ["A"], successCriteria: "SC", exceptions: "E", status: .archived)
        try await principleRepo.savePrinciples([active, archived], sourceDailyEntryId: draft.id)

        let activePrinciples = try await principleRepo.activePrinciples()
        XCTAssertEqual(activePrinciples.count, 1)
        XCTAssertEqual(activePrinciples[0].title, "Active")
    }

    // MARK: - VerificationRepository

    func testSaveVerification_andLoadByEntryAndQuest() async throws {
        let repo = SQLiteVerificationRepository(database: database)
        let entryId = UUID()
        let questId = UUID()

        let verification = Verification(
            questId: questId,
            questTitle: "Verify ownership",
            sourceDailyEntryId: entryId,
            completion: .partial,
            valueRating: .medium,
            calibrationNote: "Criteria were partly met.",
            likelyIssue: "unclear_criteria",
            recommendation: "Make completion evidence visible."
        )

        try await repo.saveVerification(verification)

        let byEntry = try await repo.verification(for: entryId)
        XCTAssertEqual(byEntry?.questTitle, "Verify ownership")
        XCTAssertEqual(byEntry?.completion, .partial)
        XCTAssertEqual(byEntry?.likelyIssue, "unclear_criteria")

        let byQuest = try await repo.verification(forQuestId: questId)
        XCTAssertEqual(byQuest?.id, verification.id)
    }

    // MARK: - LensSessionRepository

    func testSaveLensSession_persistsQuestionsAndAnswers() async throws {
        let repo = SQLiteLensSessionRepository(database: database)
        let entryId = UUID()
        let questions = [
            ReflectionQuestion(
                question: "What evidence changed?",
                whyItMatters: "It calibrates judgment.",
                answer: "The owner acknowledged the criteria."
            )
        ]

        let session = LensSession(
            dailyEntryId: entryId,
            selectedLens: .evidenceCheck,
            questions: questions
        )

        try await repo.saveLensSession(session)

        let loaded = try await repo.lensSession(for: entryId)
        XCTAssertEqual(loaded?.selectedLens, .evidenceCheck)
        XCTAssertEqual(loaded?.questions.count, 1)
        XCTAssertEqual(loaded?.questions.first?.answer, "The owner acknowledged the criteria.")
    }

    func testSaveLensSession_updatesExistingDailySession() async throws {
        let repo = SQLiteLensSessionRepository(database: database)
        let entryId = UUID()

        try await repo.saveLensSession(
            LensSession(
                dailyEntryId: entryId,
                selectedLens: .evidenceCheck,
                questions: [ReflectionQuestion(question: "Q1", whyItMatters: "M1")]
            )
        )
        try await repo.saveLensSession(
            LensSession(
                dailyEntryId: entryId,
                selectedLens: .opposingView,
                questions: [ReflectionQuestion(question: "Q2", whyItMatters: "M2", answer: "A2")]
            )
        )

        let loaded = try await repo.lensSession(for: entryId)
        XCTAssertEqual(loaded?.selectedLens, .opposingView)
        XCTAssertEqual(loaded?.questions.first?.question, "Q2")

        try await dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM lens_sessions WHERE daily_entry_id = ?", arguments: [entryId.uuidString])
            XCTAssertEqual(count, 1)
        }
    }

    // MARK: - Project Evidence Repositories

    func testSaveProject_andLoadPreservesEvidenceFields() async throws {
        let repo = SQLiteProjectRepository(database: database)
        let project = Project(
            name: "会议效率",
            goal: "减少会议后的执行歧义",
            successCriteria: "每次关键会议都有结论、Action 和负责人",
            currentBottleneck: "会前确认事项不够明确",
            openQuestions: ["哪些会议需要完整模板？"],
            status: .watching,
            createdBy: .user,
            confidence: 0.93,
            mergeHistory: ["merged-old-project"],
            fieldRevisions: ["goal": "从泛泛推进改成降低执行歧义"]
        )

        try await repo.saveProject(project)

        let loaded = try await repo.project(id: project.id)
        XCTAssertEqual(loaded?.name, "会议效率")
        XCTAssertEqual(loaded?.goal, project.goal)
        XCTAssertEqual(loaded?.successCriteria, project.successCriteria)
        XCTAssertEqual(loaded?.currentBottleneck, project.currentBottleneck)
        XCTAssertEqual(loaded?.openQuestions, project.openQuestions)
        XCTAssertEqual(loaded?.status, .watching)
        XCTAssertEqual(loaded?.createdBy, .user)
        XCTAssertEqual(loaded?.confidence, 0.93)
        XCTAssertEqual(loaded?.mergeHistory, ["merged-old-project"])
        XCTAssertEqual(loaded?.fieldRevisions["goal"], "从泛泛推进改成降低执行歧义")
    }

    func testSaveProjectCandidate_preservesSourceRefsAndStatus() async throws {
        let repo = SQLiteProjectCandidateRepository(database: database)
        let acceptedProjectId = UUID()
        let candidate = ProjectCandidate(
            suggestedName: "跨团队协作边界",
            suggestedGoal: "明确协作边界",
            suggestedBottleneck: "责任边界经常在会议后才暴露",
            suggestedSuccessCriteria: "关键交付前确认责任人和验收方式",
            reason: "14 天内多次出现会议后责任不清。",
            sourceRefs: ["card-1", "quest-2"],
            privacyReviewNote: "名称已抽象化",
            status: .renamedAndAccepted,
            acceptedProjectId: acceptedProjectId,
            createdBy: .aiSuggested,
            confidence: 0.82
        )

        try await repo.saveCandidate(candidate)

        let loaded = try await repo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.suggestedName, "跨团队协作边界")
        XCTAssertEqual(loaded?.suggestedBottleneck, "责任边界经常在会议后才暴露")
        XCTAssertEqual(loaded?.reason, "14 天内多次出现会议后责任不清。")
        XCTAssertEqual(loaded?.sourceRefs, ["card-1", "quest-2"])
        XCTAssertEqual(loaded?.privacyReviewNote, "名称已抽象化")
        XCTAssertEqual(loaded?.status, .renamedAndAccepted)
        XCTAssertEqual(loaded?.acceptedProjectId, acceptedProjectId)
        XCTAssertEqual(loaded?.confidence, 0.82)
    }

    func testSaveProjectCandidate_emptySourceRefsThrowsValidation() async throws {
        let repo = SQLiteProjectCandidateRepository(database: database)
        let candidate = ProjectCandidate(
            suggestedName: "无证据候选",
            reason: "Should fail",
            sourceRefs: []
        )

        try await assertValidationFailure {
            try await repo.saveCandidate(candidate)
        }
    }

    func testUpdateProjectCandidateStatus_preservesAuditRecord() async throws {
        let repo = SQLiteProjectCandidateRepository(database: database)
        let candidate = ProjectCandidate(
            suggestedName: "会议效率",
            reason: "Repeated evidence.",
            sourceRefs: ["entry-1"]
        )
        try await repo.saveCandidate(candidate)

        try await repo.updateCandidateStatus(.rejected, candidateId: candidate.id)

        let loaded = try await repo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.status, .rejected)
        XCTAssertEqual(loaded?.sourceRefs, ["entry-1"])
    }

    func testSaveProjectLink_preservesSourceAndConfirmation() async throws {
        let repo = SQLiteProjectLinkRepository(database: database)
        let projectId = UUID()
        let link = ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: "card-123",
            linkType: .blocker,
            confidence: 0.67,
            isUserConfirmed: true
        )

        try await repo.saveLink(link)

        let links = try await repo.links(for: projectId)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.sourceType, .thinkingCard)
        XCTAssertEqual(links.first?.sourceId, "card-123")
        XCTAssertEqual(links.first?.linkType, .blocker)
        XCTAssertEqual(links.first?.confidence, 0.67)
        XCTAssertEqual(links.first?.isUserConfirmed, true)
    }

    func testSaveProjectLink_emptySourceIdThrowsValidation() async throws {
        let repo = SQLiteProjectLinkRepository(database: database)
        let link = ProjectLink(
            projectId: UUID(),
            sourceType: .quest,
            sourceId: "   ",
            linkType: .task
        )

        try await assertValidationFailure {
            try await repo.saveLink(link)
        }
    }

    func testSaveProjectMergeCandidate_preservesEvidenceRefsAndStatusUpdate() async throws {
        let repo = SQLiteProjectMergeCandidateRepository(database: database)
        let candidate = ProjectMergeCandidate(
            sourceProjectId: UUID(),
            targetProjectId: UUID(),
            reason: "目标和阻塞高度重叠。",
            overlappingEvidenceRefs: ["link-1", "verification-2"]
        )

        try await repo.saveMergeCandidate(candidate)
        try await repo.updateMergeCandidateStatus(.dismissed, candidateId: candidate.id)

        let loaded = try await repo.mergeCandidate(id: candidate.id)
        XCTAssertEqual(loaded?.reason, "目标和阻塞高度重叠。")
        XCTAssertEqual(loaded?.overlappingEvidenceRefs, ["link-1", "verification-2"])
        XCTAssertEqual(loaded?.status, .dismissed)
    }

    func testSaveProjectInsight_preservesBeforeAfterAndFeedback() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let projectId = UUID()
        let insight = ProjectInsight(
            projectId: projectId,
            insightType: .thinkingChange,
            title: "问题定义更具体",
            summary: "从推进项目转向验证责任边界。",
            beforeText: "推进项目",
            afterText: "确认当前阻塞是边界问题还是设计问题",
            sourceRefs: ["card-old", "card-new"],
            confidence: 0.8
        )

        try await repo.saveInsight(insight)
        try await repo.updateInsightFeedback(.inaccurate, insightId: insight.id)

        let loaded = try await repo.insights(for: projectId)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.insightType, .thinkingChange)
        XCTAssertEqual(loaded.first?.title, "问题定义更具体")
        XCTAssertEqual(loaded.first?.beforeText, "推进项目")
        XCTAssertEqual(loaded.first?.afterText, "确认当前阻塞是边界问题还是设计问题")
        XCTAssertEqual(loaded.first?.sourceRefs, ["card-old", "card-new"])
        XCTAssertEqual(loaded.first?.userFeedback, .inaccurate)
    }

    func testSaveProjectInsight_thinkingChangeWithoutBeforeAfterThrowsValidation() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let insight = ProjectInsight(
            projectId: UUID(),
            insightType: .thinkingChange,
            title: "证据不足的变化",
            summary: "Should fail",
            sourceRefs: ["card-1"]
        )

        try await assertValidationFailure {
            try await repo.saveInsight(insight)
        }
    }

    func testSaveProjectInsight_blockerChangeWithoutBeforeAfterThrowsValidation() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let insight = ProjectInsight(
            projectId: UUID(),
            insightType: .blockerChange,
            title: "证据不足的阻塞变化",
            summary: "Should fail",
            sourceRefs: ["card-1"]
        )

        try await assertValidationFailure {
            try await repo.saveInsight(insight)
        }
    }

    func testSaveProjectInsight_emptySourceRefsThrowsValidation() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let insight = ProjectInsight(
            projectId: UUID(),
            insightType: .progress,
            title: "无来源进展",
            summary: "Should fail",
            sourceRefs: []
        )

        try await assertValidationFailure {
            try await repo.saveInsight(insight)
        }
    }

    // MARK: - PromptRunRepository

    func testSavePromptRun_andLoadRecent() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let run = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1", "card-1"],
            contextRecordIds: ["entry-1", "card-1", "principle-1"],
            requestSummary: "mode=standard; rawText=demo",
            responseJSON: #"{"cards":[]}"#
        )

        try await repo.savePromptRun(run)

        let recent = try await repo.recentPromptRuns(limit: 5)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.promptId, PromptID.organizeCards.rawValue)
        XCTAssertEqual(recent.first?.modelProvider, "GLM")
        XCTAssertEqual(recent.first?.modelName, "glm-test")
        XCTAssertEqual(recent.first?.sourceRecordIds, ["entry-1", "card-1"])
        XCTAssertEqual(recent.first?.contextRecordIds, ["entry-1", "card-1", "principle-1"])
        XCTAssertEqual(recent.first?.responseJSON, #"{"cards":[]}"#)
        XCTAssertNil(recent.first?.error)
    }

    func testPromptRun_legacyRowsWithoutContextRefsFallbackToSourceRefs() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO prompt_runs (
                        id, schema_version, prompt_id, prompt_version, input_schema_version,
                        output_schema_version, model_provider, model_name, session_mode,
                        source_record_ids_json, context_record_ids_json, request_summary,
                        response_json, error, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    UUID().uuidString,
                    1,
                    PromptID.generateQuestions.rawValue,
                    "1.0.0",
                    1,
                    1,
                    "GLM",
                    "glm-test",
                    SessionMode.standard.rawValue,
                    #"["entry-1","card-1"]"#,
                    nil,
                    "legacy row",
                    #"{"questions":[]}"#,
                    nil,
                    Self.storageString(Date(timeIntervalSince1970: 10))
                ]
            )
        }

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.sourceRecordIds, ["entry-1", "card-1"])
        XCTAssertEqual(recent.first?.contextRecordIds, ["entry-1", "card-1"])
    }

    func testPromptRun_unresolvedFailuresReturnsOnlyFailedRuns() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: ["entry-1"],
                requestSummary: "success",
                responseJSON: #"{"questions":[]}"#,
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: ["entry-1"],
                requestSummary: "failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )

        let failures = try await repo.unresolvedFailures(limit: 10)
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.requestSummary, "failure")
        XCTAssertEqual(failures.first?.error, "HTTP 500")
    }

    func testPromptRun_unresolvedFailuresIgnoresFailureResolvedByLaterSuccess() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let sourceIds = ["entry-1", "card-1"]
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuests.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: sourceIds,
                requestSummary: "older failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuests.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: sourceIds,
                requestSummary: "later success",
                responseJSON: #"{"main_quest":null}"#,
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )

        let failures = try await repo.unresolvedFailures(limit: 10)
        XCTAssertTrue(failures.isEmpty)
    }

    func testPromptTracingLLMClient_recordsSuccessAndFailure() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "1.0.0",
                systemText: "Return JSON only.",
                userText: "Return cards.",
                outputSchemaVersion: 1
            ),
            inputSummary: "mode=standard; rawText=demo",
            jsonPayload: ["sessionMode": SessionMode.standard.rawValue],
            sourceRecordIDs: ["entry-1"],
            contextRecordIDs: ["entry-1", "principle-1"]
        )

        let successClient = PromptTracingLLMClient(
            base: MockLLMClient(),
            repository: repo,
            modelProvider: "mock",
            modelName: "local-mock"
        )
        _ = try await successClient.complete(request)

        let failureClient = PromptTracingLLMClient(
            base: AlwaysFailingLLMClient(),
            repository: repo,
            modelProvider: "GLM",
            modelName: "glm-test"
        )
        do {
            _ = try await failureClient.complete(request)
            XCTFail("Expected failing LLM client to throw")
        } catch {
            // Expected.
        }

        let recent = try await repo.recentPromptRuns(limit: 10)
        XCTAssertEqual(recent.count, 2)
        XCTAssertTrue(recent.contains { $0.modelProvider == "mock" && $0.responseJSON != nil && $0.error == nil })
        XCTAssertTrue(recent.contains { $0.modelProvider == "GLM" && $0.responseJSON == nil && $0.error?.contains("HTTP 503") == true })
        XCTAssertTrue(recent.allSatisfy { $0.sourceRecordIds == ["entry-1"] })
        XCTAssertTrue(recent.allSatisfy { $0.contextRecordIds == ["entry-1", "principle-1"] })
    }

    func testPromptTracingLLMClient_recordsMissingAPIKeyAsFailure() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "1.0.0",
                systemText: "Return JSON only.",
                userText: "Return cards.",
                outputSchemaVersion: 1
            ),
            inputSummary: "connection requires BYOK",
            jsonPayload: ["sessionMode": SessionMode.standard.rawValue],
            sourceRecordIDs: ["entry-missing-key"],
            contextRecordIDs: ["entry-missing-key"]
        )
        let client = PromptTracingLLMClient(
            base: MissingAPIKeyLLMClient(),
            repository: repo,
            modelProvider: "GLM",
            modelName: "missing-api-key"
        )

        do {
            _ = try await client.complete(request)
            XCTFail("Expected missing API key to throw")
        } catch LLMClientError.missingAPIKey {
            // Expected.
        } catch {
            XCTFail("Expected missing API key, got \(error)")
        }

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.modelProvider, "GLM")
        XCTAssertEqual(recent.first?.modelName, "missing-api-key")
        XCTAssertNil(recent.first?.responseJSON)
        XCTAssertTrue(recent.first?.error?.contains("API Key") == true)
    }

    // MARK: - HistoricalRetryCandidateRepository

    func testHistoricalRetryCandidate_createAttachAndQueryByEntry() async throws {
        let repo = SQLiteHistoricalRetryCandidateRepository(database: database)
        let entryId = UUID()
        let failedRunId = UUID()
        let repairRunId = UUID()
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: failedRunId,
            promptId: .organizeCards,
            sourceDailyEntryId: entryId,
            reconstructedInputSummary: "rawText=142 chars"
        )

        try await repo.saveCandidate(candidate)
        try await repo.attachRepairRun(
            repairRunId,
            candidatePayloadJSON: #"{"cards":[{"title":"A"}]}"#,
            to: candidate.id
        )

        let candidates = try await repo.candidates(for: entryId)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.id, candidate.id)
        XCTAssertEqual(candidates.first?.failedPromptRunId, failedRunId)
        XCTAssertEqual(candidates.first?.repairPromptRunId, repairRunId)
        XCTAssertEqual(candidates.first?.promptId, .organizeCards)
        XCTAssertEqual(candidates.first?.sourceDailyEntryId, entryId)
        XCTAssertEqual(candidates.first?.status, .candidateReady)
        XCTAssertEqual(candidates.first?.candidatePayloadJSON, #"{"cards":[{"title":"A"}]}"#)
    }

    func testHistoricalRetryCandidate_statusUpdatesPreserveAuditPayload() async throws {
        let repo = SQLiteHistoricalRetryCandidateRepository(database: database)
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: UUID(),
            promptId: .organizeCards,
            sourceDailyEntryId: UUID(),
            status: .candidateReady,
            reconstructedInputSummary: "rawText=42 chars",
            candidatePayloadJSON: #"{"cards":[]}"#
        )

        try await repo.saveCandidate(candidate)
        try await repo.updateStatus(.blocked, candidateId: candidate.id, blockedReason: "confirmed cards exist")

        let loaded = try await repo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.status, .blocked)
        XCTAssertEqual(loaded?.blockedReason, "confirmed cards exist")
        XCTAssertEqual(loaded?.candidatePayloadJSON, #"{"cards":[]}"#)
    }

    func testHistoricalRetryCandidate_softDeleteDoesNotDeletePromptRuns() async throws {
        let promptRepo = SQLitePromptRunRepository(database: database)
        let candidateRepo = SQLiteHistoricalRetryCandidateRepository(database: database)
        let failedRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1"],
            requestSummary: "failed card organization",
            error: "HTTP 500"
        )
        let repairRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1"],
            requestSummary: "repair success",
            responseJSON: #"{"cards":[]}"#
        )
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: failedRun.id,
            repairPromptRunId: repairRun.id,
            promptId: .organizeCards,
            sourceDailyEntryId: UUID(),
            status: .candidateReady,
            reconstructedInputSummary: "rawText=42 chars",
            candidatePayloadJSON: #"{"cards":[]}"#
        )

        try await promptRepo.savePromptRun(failedRun)
        try await promptRepo.savePromptRun(repairRun)
        try await candidateRepo.saveCandidate(candidate)
        try await candidateRepo.softDelete(candidateId: candidate.id)

        let deletedCandidate = try await candidateRepo.candidate(id: candidate.id)
        XCTAssertNil(deletedCandidate)
        let promptRuns = try await promptRepo.recentPromptRuns(limit: 10)
        XCTAssertTrue(promptRuns.contains { $0.id == failedRun.id })
        XCTAssertTrue(promptRuns.contains { $0.id == repairRun.id })
    }

    // MARK: - Migration

    func testMigration_v1_createsAllTables() throws {
        // Tables created in setUp - verify they exist
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("daily_entries"))
            XCTAssertTrue(try db.tableExists("thinking_cards"))
            XCTAssertTrue(try db.tableExists("quests"))
            XCTAssertTrue(try db.tableExists("principle_assets"))
            XCTAssertTrue(try db.tableExists("prompt_runs"))
            XCTAssertTrue(try db.tableExists("verifications"))
            XCTAssertTrue(try db.tableExists("lens_sessions"))
            XCTAssertTrue(try db.tableExists("projects"))
            XCTAssertTrue(try db.tableExists("project_candidates"))
            XCTAssertTrue(try db.tableExists("project_links"))
            XCTAssertTrue(try db.tableExists("project_merge_candidates"))
            XCTAssertTrue(try db.tableExists("project_insights"))
        }
    }

    func testMigration_v7_addsPromptRunContextRefs() throws {
        try dbQueue.read { db in
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
            XCTAssertTrue(promptRunColumns.contains("source_record_ids_json"))
            XCTAssertTrue(promptRunColumns.contains("context_record_ids_json"))
        }
    }

    func testMigration_v8_addsHistoricalRetryCandidatesTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("historical_retry_candidates"))

            let columns = Set(try db.columns(in: "historical_retry_candidates").map(\.name))
            XCTAssertTrue(columns.contains("failed_prompt_run_id"))
            XCTAssertTrue(columns.contains("repair_prompt_run_id"))
            XCTAssertTrue(columns.contains("prompt_id"))
            XCTAssertTrue(columns.contains("source_daily_entry_id"))
            XCTAssertTrue(columns.contains("candidate_payload_json"))
            XCTAssertTrue(columns.contains("blocked_reason"))

            let indexes = try db.indexes(on: "historical_retry_candidates").map(\.name)
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_source_daily_entry_id"))
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_failed_prompt_run_id"))
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_status"))
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_updated_at"))
        }
    }

    func testMigration_v2_addsDailyLoopFields() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "daily_entries")
            let columnNames = Set(columns.map(\.name))
            XCTAssertTrue(columnNames.contains("has_selected_session_mode"))
            XCTAssertTrue(columnNames.contains("selected_lens"))
            XCTAssertTrue(columnNames.contains("yesterday_completion"))
            XCTAssertTrue(columnNames.contains("yesterday_value_rating"))
        }
    }

    func testMigration_v3_addsVerificationAndLensSessionFields() throws {
        try dbQueue.read { db in
            let verificationColumns = Set(try db.columns(in: "verifications").map(\.name))
            XCTAssertTrue(verificationColumns.contains("quest_id"))
            XCTAssertTrue(verificationColumns.contains("source_daily_entry_id"))
            XCTAssertTrue(verificationColumns.contains("calibration_note"))

            let lensColumns = Set(try db.columns(in: "lens_sessions").map(\.name))
            XCTAssertTrue(lensColumns.contains("daily_entry_id"))
            XCTAssertTrue(lensColumns.contains("selected_lens"))
            XCTAssertTrue(lensColumns.contains("questions_json"))
        }
    }

    func testMigration_v4_addsProjectEvidenceTables() throws {
        try dbQueue.read { db in
            let projectColumns = Set(try db.columns(in: "projects").map(\.name))
            XCTAssertTrue(projectColumns.contains("name"))
            XCTAssertTrue(projectColumns.contains("success_criteria"))
            XCTAssertTrue(projectColumns.contains("current_bottleneck"))
            XCTAssertTrue(projectColumns.contains("merge_history_json"))
            XCTAssertTrue(projectColumns.contains("field_revisions_json"))

            let candidateColumns = Set(try db.columns(in: "project_candidates").map(\.name))
            XCTAssertTrue(candidateColumns.contains("suggested_name"))
            XCTAssertTrue(candidateColumns.contains("reason"))
            XCTAssertTrue(candidateColumns.contains("source_refs_json"))
            XCTAssertTrue(candidateColumns.contains("accepted_project_id"))

            let linkColumns = Set(try db.columns(in: "project_links").map(\.name))
            XCTAssertTrue(linkColumns.contains("source_type"))
            XCTAssertTrue(linkColumns.contains("source_id"))
            XCTAssertTrue(linkColumns.contains("link_type"))
            XCTAssertTrue(linkColumns.contains("is_user_confirmed"))

            let insightColumns = Set(try db.columns(in: "project_insights").map(\.name))
            XCTAssertTrue(insightColumns.contains("insight_type"))
            XCTAssertTrue(insightColumns.contains("before_text"))
            XCTAssertTrue(insightColumns.contains("after_text"))
            XCTAssertTrue(insightColumns.contains("source_refs_json"))
            XCTAssertTrue(insightColumns.contains("user_feedback"))
        }
    }

    // MARK: - Growth Attribution Repositories

    func testSaveSnapshot_andLoadLatestPreservesAttributionFields() async throws {
        let repo = SQLiteMetricSnapshotRepository(database: database)
        let startDate = Date(timeIntervalSince1970: 1_800_000_000)
        let endDate = Date(timeIntervalSince1970: 1_800_604_800)
        let snapshot = MetricSnapshot(
            period: "weekly",
            startDate: startDate,
            endDate: endDate,
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            previousClarity: 3.4,
            previousValueJudgment: 3.2,
            previousExecutionReliability: 3.0,
            previousCalibration: 2.8,
            previousReflectionDepth: 3.3,
            clarityDelta: 0.4,
            valueJudgmentDelta: 0.3,
            executionReliabilityDelta: 0.2,
            calibrationDelta: 0.2,
            reflectionDepthDelta: 0.3,
            summary: "清晰度提升，因为问题定义更具体。",
            metricReasons: [
                GrowthMetric.clarity.rawValue: "问题定义更具体",
                GrowthMetric.valueJudgment.rawValue: "更常选择高杠杆动作"
            ],
            evidenceRefs: ["entry-1", "entry-2", "entry-3"],
            positiveContributionRefs: ["contribution-1", "contribution-2"],
            negativeContributionRefs: ["contribution-3"],
            status: .confirmedTrend,
            completeLoopCount: 3,
            nextTrainingFocus: "继续练习会前确认目标"
        )

        try await repo.saveSnapshot(snapshot)

        let loaded = try await repo.latestSnapshot()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.period, "weekly")
        XCTAssertEqual(loaded?.clarity, 3.8)
        XCTAssertEqual(loaded?.previousClarity, 3.4)
        XCTAssertEqual(loaded?.clarityDelta, 0.4)
        XCTAssertEqual(loaded?.summary, "清晰度提升，因为问题定义更具体。")
        XCTAssertEqual(loaded?.metricReasons[GrowthMetric.clarity.rawValue], "问题定义更具体")
        XCTAssertEqual(loaded?.evidenceRefs, ["entry-1", "entry-2", "entry-3"])
        XCTAssertEqual(loaded?.positiveContributionRefs, ["contribution-1", "contribution-2"])
        XCTAssertEqual(loaded?.negativeContributionRefs, ["contribution-3"])
        XCTAssertEqual(loaded?.status, .confirmedTrend)
        XCTAssertEqual(loaded?.completeLoopCount, 3)
        XCTAssertEqual(loaded?.nextTrainingFocus, "继续练习会前确认目标")
        XCTAssertFalse(loaded?.hasInsufficientEvidence == true)
        XCTAssertTrue(loaded?.canDisplayScores == true)
    }

    func testSaveSnapshot_insufficientEvidenceRoundTrip() async throws {
        let repo = SQLiteMetricSnapshotRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 0,
            valueJudgment: 0,
            executionReliability: 0,
            calibration: 0,
            reflectionDepth: 0,
            summary: "尚未积累证据",
            status: .insufficientEvidence,
            completeLoopCount: 2
        )

        try await repo.saveSnapshot(snapshot)
        let loaded = try await repo.latestSnapshot()
        XCTAssertTrue(loaded?.hasInsufficientEvidence == true)
        XCTAssertFalse(loaded?.canDisplayScores == true)
        XCTAssertEqual(loaded?.metricReasons, [:])
        XCTAssertEqual(loaded?.evidenceRefs, [])
    }

    func testSaveSnapshot_andLoadById() async throws {
        let repo = SQLiteMetricSnapshotRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "monthly",
            clarity: 4.0,
            valueJudgment: 3.8,
            executionReliability: 3.5,
            calibration: 3.2,
            reflectionDepth: 3.9,
            summary: "Monthly snapshot",
            positiveContributionRefs: ["contribution-1"],
            status: .confirmedTrend,
            completeLoopCount: 3
        )

        try await repo.saveSnapshot(snapshot)
        let loaded = try await repo.snapshot(id: snapshot.id)
        XCTAssertEqual(loaded?.id, snapshot.id)
        XCTAssertEqual(loaded?.period, "monthly")
    }

    func testSaveContribution_andLoad() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let sourceDailyEntryId = UUID()
        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            summary: "Test"
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let contribution = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.4,
            title: "问题定义更具体",
            reason: "问题定义更具体",
            sourceType: .thinkingCard,
            sourceId: "card-2",
            sourceDailyEntryId: sourceDailyEntryId,
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(contribution)

        let loaded = try await contributionRepo.contributions(for: snapshotId)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].metric, .clarity)
        XCTAssertEqual(loaded[0].direction, .positive)
        XCTAssertEqual(loaded[0].delta, 0.4)
        XCTAssertEqual(loaded[0].title, "问题定义更具体")
        XCTAssertEqual(loaded[0].reason, "问题定义更具体")
        XCTAssertEqual(loaded[0].sourceType, .thinkingCard)
        XCTAssertEqual(loaded[0].sourceId, "card-2")
        XCTAssertEqual(loaded[0].sourceDailyEntryId, sourceDailyEntryId)
        XCTAssertEqual(loaded[0].userFeedback, .accepted)
        XCTAssertEqual(loaded[0].candidateStatus, .accepted)
    }

    func testSaveContribution_emptySourceIdThrowsValidation() async throws {
        let repo = SQLiteMetricContributionRepository(database: database)
        let contribution = MetricContribution(
            snapshotId: UUID(),
            metric: .clarity,
            direction: .positive,
            delta: 0.1,
            title: "Should fail",
            reason: "Should fail",
            sourceType: .dailyEntry,
            sourceId: "   ",
            sourceDailyEntryId: UUID()
        )

        try await assertValidationFailure {
            try await repo.saveContribution(contribution)
        }
    }

    func testUpdateContributionStatus_retainedAndExcludedFromAccepted() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            summary: "Test"
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let accepted = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.3,
            title: "Positive contribution",
            reason: "Positive contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        let rejected = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Rejected contribution",
            reason: "Rejected contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-2",
            sourceDailyEntryId: UUID()
        )
        try await contributionRepo.saveContribution(accepted)
        try await contributionRepo.saveContribution(rejected)

        try await contributionRepo.updateContributionStatus(.rejected, contributionId: rejected.id)

        let allContributions = try await contributionRepo.contributions(for: snapshotId)
        XCTAssertEqual(allContributions.count, 2)

        let acceptedOnly = try await contributionRepo.acceptedContributions(for: snapshotId, metric: .clarity)
        XCTAssertEqual(acceptedOnly.count, 1)
        XCTAssertEqual(acceptedOnly[0].delta, 0.3)
    }

    func testReconstructionFromAcceptedDeltas() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let previousValue = 3.0
        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3.5,
            valueJudgment: 3.0,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            previousClarity: previousValue,
            summary: "Test reconstruction"
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let c1 = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.3,
            title: "Refined problem statement",
            reason: "Refined problem statement",
            sourceType: .thinkingCard,
            sourceId: "card-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        let c2 = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Completed verification",
            reason: "Completed verification",
            sourceType: .verification,
            sourceId: "verification-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        let c3 = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.5,
            title: "Dismissed outlier",
            reason: "Dismissed outlier",
            sourceType: .dailyEntry,
            sourceId: "entry-3",
            sourceDailyEntryId: UUID(),
            userFeedback: .dismissed,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(c1)
        try await contributionRepo.saveContribution(c2)
        try await contributionRepo.saveContribution(c3)

        let accepted = try await contributionRepo.acceptedContributions(for: snapshotId, metric: .clarity)
        let reconstructedValue = previousValue + accepted.map(\.delta).reduce(0, +)
        XCTAssertEqual(reconstructedValue, 3.5, "Current value must equal previous + sum of accepted deltas")
    }

    // MARK: - History Evidence Repository Helpers

    func testProjectLinks_forSourceIds_returnsMatchingLinks() async throws {
        let repo = SQLiteProjectLinkRepository(database: database)
        let projectA = UUID()
        let projectB = UUID()

        let link1 = ProjectLink(
            projectId: projectA,
            sourceType: .thinkingCard,
            sourceId: "card-1",
            linkType: .evidence,
            confidence: 0.8,
            isUserConfirmed: true
        )
        let link2 = ProjectLink(
            projectId: projectA,
            sourceType: .quest,
            sourceId: "quest-1",
            linkType: .task
        )
        let link3 = ProjectLink(
            projectId: projectB,
            sourceType: .thinkingCard,
            sourceId: "card-2",
            linkType: .blocker
        )

        try await repo.saveLink(link1)
        try await repo.saveLink(link2)
        try await repo.saveLink(link3)

        let matching = try await repo.links(forSourceIds: ["card-1", "quest-1"])
        XCTAssertEqual(matching.count, 2)
        let matchingIds = Set(matching.map(\.id))
        XCTAssertTrue(matchingIds.contains(link1.id))
        XCTAssertTrue(matchingIds.contains(link2.id))

        let noMatch = try await repo.links(forSourceIds: ["nonexistent"])
        XCTAssertEqual(noMatch.count, 0)

        let empty = try await repo.links(forSourceIds: [])
        XCTAssertEqual(empty.count, 0)
    }

    func testMetricContributions_forDailyEntryId_returnsAcceptedOnly() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let entryA = UUID()
        let entryB = UUID()

        try await snapshotRepo.saveSnapshot(
            MetricSnapshot(id: snapshotId, period: "weekly", clarity: 3.0, valueJudgment: 3.0,
                           executionReliability: 3.0, calibration: 3.0, reflectionDepth: 3.0, summary: "Test")
        )

        let accepted = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.3,
            title: "Accepted contribution",
            reason: "Accepted contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-a",
            sourceDailyEntryId: entryA,
            userFeedback: .none,
            candidateStatus: .accepted
        )
        let rejected = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Rejected contribution",
            reason: "Rejected contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-a-2",
            sourceDailyEntryId: entryA,
            userFeedback: .none,
            candidateStatus: .rejected
        )
        let inaccurate = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.1,
            title: "Inaccurate contribution",
            reason: "Inaccurate contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-b-1",
            sourceDailyEntryId: entryB,
            userFeedback: .inaccurate,
            candidateStatus: .accepted
        )

        try await contributionRepo.saveContribution(accepted)
        try await contributionRepo.saveContribution(rejected)
        try await contributionRepo.saveContribution(inaccurate)

        let entryAResults = try await contributionRepo.contributions(forDailyEntryId: entryA)
        XCTAssertEqual(entryAResults.count, 1)
        XCTAssertEqual(entryAResults[0].title, "Accepted contribution")

        let entryBResults = try await contributionRepo.contributions(forDailyEntryId: entryB)
        XCTAssertEqual(entryBResults.count, 0, "Inaccurate contributions excluded")

        let noResults = try await contributionRepo.contributions(forDailyEntryId: UUID())
        XCTAssertEqual(noResults.count, 0)
    }

    func testUpdateContributionFeedback_toInaccurateExcludesFromAccepted() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        try await snapshotRepo.saveSnapshot(
            MetricSnapshot(id: snapshotId, period: "weekly", clarity: 3.0, valueJudgment: 3.0,
                           executionReliability: 3.0, calibration: 3.0, reflectionDepth: 3.0, summary: "Test")
        )

        let contribution = MetricContribution(
            snapshotId: snapshotId,
            metric: .calibration,
            direction: .negative,
            delta: -0.2,
            title: "Initial assessment",
            reason: "Initial assessment",
            sourceType: .dailyEntry,
            sourceId: "entry-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(contribution)
        try await contributionRepo.updateContributionFeedback(.inaccurate, contributionId: contribution.id)

        let all = try await contributionRepo.contributions(for: snapshotId)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].userFeedback, .inaccurate)

        let accepted = try await contributionRepo.acceptedContributions(for: snapshotId, metric: .calibration)
        XCTAssertEqual(accepted.count, 0, "Inaccurate contributions excluded from accepted")
    }

    // MARK: - Migration v5

    func testMigration_v5_addsGrowthAttributionTables() throws {
        try dbQueue.read { db in
            let snapshotColumns = Set(try db.columns(in: "metric_snapshots").map(\.name))
            XCTAssertTrue(snapshotColumns.contains("period"))
            XCTAssertTrue(snapshotColumns.contains("start_date"))
            XCTAssertTrue(snapshotColumns.contains("end_date"))
            XCTAssertTrue(snapshotColumns.contains("clarity"))
            XCTAssertTrue(snapshotColumns.contains("previous_scores_json"))
            XCTAssertTrue(snapshotColumns.contains("delta_scores_json"))
            XCTAssertTrue(snapshotColumns.contains("metric_reasons_json"))
            XCTAssertTrue(snapshotColumns.contains("summary"))
            XCTAssertTrue(snapshotColumns.contains("evidence_refs_json"))
            XCTAssertTrue(snapshotColumns.contains("positive_contribution_refs_json"))
            XCTAssertTrue(snapshotColumns.contains("negative_contribution_refs_json"))
            XCTAssertTrue(snapshotColumns.contains("status"))
            XCTAssertTrue(snapshotColumns.contains("complete_loop_count"))
            XCTAssertTrue(snapshotColumns.contains("next_training_focus"))

            let contributionColumns = Set(try db.columns(in: "metric_contributions").map(\.name))
            XCTAssertTrue(contributionColumns.contains("snapshot_id"))
            XCTAssertTrue(contributionColumns.contains("metric"))
            XCTAssertTrue(contributionColumns.contains("direction"))
            XCTAssertTrue(contributionColumns.contains("delta"))
            XCTAssertTrue(contributionColumns.contains("title"))
            XCTAssertTrue(contributionColumns.contains("reason"))
            XCTAssertTrue(contributionColumns.contains("source_type"))
            XCTAssertTrue(contributionColumns.contains("source_id"))
            XCTAssertTrue(contributionColumns.contains("source_daily_entry_id"))
            XCTAssertTrue(contributionColumns.contains("user_feedback"))
            XCTAssertTrue(contributionColumns.contains("candidate_status"))
        }
    }

    func testMigration_v6_backfillsLegacyMetricContributionSourceDailyEntryId() throws {
        let legacyQueue = try DatabaseQueue()
        try legacyQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE metric_contributions (
                    id TEXT PRIMARY KEY,
                    schema_version INTEGER NOT NULL,
                    snapshot_id TEXT NOT NULL,
                    metric TEXT NOT NULL,
                    direction TEXT NOT NULL,
                    delta DOUBLE NOT NULL,
                    title TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_id TEXT NOT NULL,
                    user_feedback TEXT NOT NULL,
                    candidate_status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT
                )
                """
            )
        }

        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(legacyQueue)

        try legacyQueue.read { db in
            let contributionColumns = Set(try db.columns(in: "metric_contributions").map(\.name))
            XCTAssertTrue(contributionColumns.contains("source_daily_entry_id"))
        }
    }

    // MARK: - Helper

    private func readCreatedAt(for id: UUID) -> String? {
        try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT created_at FROM daily_entries WHERE id = ?", arguments: [id.uuidString])
        }
    }

    private static func storageString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func assertValidationFailure(
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
            XCTFail("Expected validation failure", file: file, line: line)
        } catch let error as MingSi.PersistenceError {
            if case .validationFailed = error {
                return
            }
            XCTFail("Expected validation failure, got \(error)", file: file, line: line)
        } catch {
            XCTFail("Expected validation failure, got \(error)", file: file, line: line)
        }
    }
}

private final class AlwaysFailingLLMClient: LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.httpStatus(503, Data("service unavailable".utf8))
    }
}
