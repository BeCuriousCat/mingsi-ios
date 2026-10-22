import GRDB
import XCTest
import EventKit
@testable import MingSi

final class VNextTests: XCTestCase {
    private var database: AppDatabase!

    override func setUpWithError() throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue)
        database = try AppDatabase(dbQueue: queue)
    }

    override func tearDown() {
        database = nil
        super.tearDown()
    }

    @MainActor
    func testVNextQuestTrainingTargetDoesNotAttributeLocalMatchWithoutExplicitSelection() throws {
        let principle = PrincipleAsset(
            title: "会前确认负责人",
            summary: "推进前先确认唯一负责人。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人"],
            successCriteria: "会后没有职责空白。",
            exceptions: "",
            status: .active
        )
        let quest = Quest(
            type: .main,
            title: "明天写出负责人",
            whyItMatters: "减少会议后返工。",
            completionCriteria: "负责人被写入记录。",
            expectedResistance: "可能只口头同步。",
            reflectionQuestion: "负责人确认后，返工是否减少？"
        )
        let store = AppStore(
            quests: [quest],
            principles: [principle],
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        XCTAssertNil(store.questTrainingTarget(for: quest.id))
    }

    @MainActor
    func testVNextQuestTrainingTargetUsesOnlyExplicitUserSelection() throws {
        let selected = PrincipleAsset(
            title: "先写验收标准",
            summary: "先把验收标准写成可检查证据。",
            triggerContext: "acceptance contract",
            actions: ["写出验收标准"],
            successCriteria: "完成时能直接检查。",
            exceptions: "",
            status: .active
        )
        let matching = PrincipleAsset(
            title: "会前确认负责人",
            summary: "推进前先确认唯一负责人。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人"],
            successCriteria: "会后没有职责空白。",
            exceptions: "",
            status: .active
        )
        let quest = Quest(
            type: .main,
            title: "明天写出负责人",
            whyItMatters: "减少会议后返工。",
            completionCriteria: "负责人被写入记录。",
            expectedResistance: "可能只口头同步。",
            reflectionQuestion: "负责人确认后，返工是否减少?",
            trainingPrincipleId: selected.id
        )
        let store = AppStore(
            quests: [quest],
            principles: [selected, matching],
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        let target = try XCTUnwrap(store.questTrainingTarget(for: quest.id))
        XCTAssertEqual(target.principleId, selected.id)
        XCTAssertEqual(target.principleTitle, selected.title)
        XCTAssertEqual(target.matchSignal, "用户选择")
    }

    func testEveryPromptUsesStableGlobalDecisionRoute() {
        XCTAssertEqual(PromptID.organizeCards.decisionRoute, .capture)
        XCTAssertEqual(PromptID.diagnoseTrainingCase.decisionRoute, .coaching)
        XCTAssertEqual(PromptID.verifyQuest.decisionRoute, .calibration)
        XCTAssertEqual(PromptID.generateProjectInsights.decisionRoute, .projects)
        XCTAssertEqual(PromptID.generateSideQuest.decisionRoute, .life)
        XCTAssertEqual(Set(PromptID.allCases.map(\.decisionRoute)), Set(LLMDecisionRoute.allCases))
    }

    func testPromptRunDerivesDecisionRouteWithoutChangingStoredShape() {
        let run = PromptRun(
            promptId: PromptID.generateSideQuest.rawValue,
            promptVersion: "test.v1",
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "test",
            sessionMode: SessionMode.standard.rawValue,
            requestSummary: "route audit"
        )

        XCTAssertEqual(run.decisionRoute, .life)
    }

    func testTrainingCaseCoordinator_assignsCardsAndFallsBackForInvalidGrouping() {
        let entryId = UUID()
        let cards = [
            ThinkingCard(type: .problem, title: "A", body: "A"),
            ThinkingCard(type: .task, title: "B", body: "B")
        ]
        let suggestions = [
            TrainingCaseSuggestion(key: "a", title: "事项 A", cardIds: [cards[0].id]),
            TrainingCaseSuggestion(key: "b", title: "事项 B", cardIds: [cards[1].id])
        ]

        let result = TrainingCaseCoordinator().materialize(
            suggestions: suggestions,
            cards: cards,
            dailyEntryId: entryId
        )

        XCTAssertEqual(result.cases.count, 2)
        XCTAssertEqual(Set(result.cards.compactMap(\.trainingCaseId)).count, 2)

        let invalid = TrainingCaseCoordinator().materialize(
            suggestions: [
                TrainingCaseSuggestion(key: "same", title: "A", cardIds: [cards[0].id]),
                TrainingCaseSuggestion(key: "same", title: "B", cardIds: [cards[1].id])
            ],
            cards: cards,
            dailyEntryId: entryId
        )
        XCTAssertEqual(invalid.cases.count, 1)
        XCTAssertEqual(Set(invalid.cards.compactMap(\.trainingCaseId)).count, 1)
    }

    func testCaseScopedCardAndQuestSavesDoNotDeleteSiblingCaseEvidence() async throws {
        let entry = DailyEntryDraft(rawText: "A and B")
        try await SQLiteDailyEntryRepository(database: database).saveDraft(entry)
        let caseRepo = SQLiteTrainingCaseRepository(database: database)
        let caseA = TrainingCase(dailyEntryId: entry.id, title: "A", status: .ready)
        let caseB = TrainingCase(dailyEntryId: entry.id, title: "B", status: .ready, sortOrder: 1)
        try await caseRepo.saveCase(caseA)
        try await caseRepo.saveCase(caseB)

        let cardRepo = SQLiteThinkingCardRepository(database: database)
        let cardA = ThinkingCard(trainingCaseId: caseA.id, type: .fact, title: "A", body: "A")
        let cardB = ThinkingCard(trainingCaseId: caseB.id, type: .fact, title: "B", body: "B")
        try await cardRepo.saveCards([cardA], dailyEntryId: entry.id, trainingCaseId: caseA.id)
        try await cardRepo.saveCards([cardB], dailyEntryId: entry.id, trainingCaseId: caseB.id)
        try await cardRepo.saveCards([], dailyEntryId: entry.id, trainingCaseId: caseA.id)

        let remainingCardsA = try await cardRepo.cards(forTrainingCaseId: caseA.id)
        let remainingCardsB = try await cardRepo.cards(forTrainingCaseId: caseB.id)
        XCTAssertTrue(remainingCardsA.isEmpty)
        XCTAssertEqual(remainingCardsB.map(\.id), [cardB.id])

        let questRepo = SQLiteQuestRepository(database: database)
        let questA = makeQuest(caseId: caseA.id, title: "Quest A")
        let questB = makeQuest(caseId: caseB.id, title: "Quest B")
        try await questRepo.saveQuests([questA], sourceDailyEntryId: entry.id, trainingCaseId: caseA.id)
        try await questRepo.saveQuests([questB], sourceDailyEntryId: entry.id, trainingCaseId: caseB.id)
        try await questRepo.saveQuests([], sourceDailyEntryId: entry.id, trainingCaseId: caseA.id)

        let remainingQuestsA = try await questRepo.quests(forTrainingCaseId: caseA.id)
        let remainingQuestsB = try await questRepo.quests(forTrainingCaseId: caseB.id)
        XCTAssertTrue(remainingQuestsA.isEmpty)
        XCTAssertEqual(remainingQuestsB.map(\.id), [questB.id])
    }

    func testVerificationSettlementRepositoryCommitsVerificationQuestStatusAndSettlementTogether() async throws {
        let fixture = try await makeQuestFixture()
        let verification = makeVerification(quest: fixture.quest, entryId: fixture.entry.id)
        let settlement = GrowthSettlementPolicy().make(
            verification: verification,
            quest: fixture.quest,
            caseId: fixture.trainingCase.id,
            modelEvidenceItems: [
                GrowthSettlementEvidenceItem(
                    category: .action,
                    metric: .executionReliability,
                    title: "模型确认了可核对的行动结果",
                    sourceRefs: [fixture.quest.id.uuidString, verification.id.uuidString]
                )
            ]
        )

        try await SQLiteVerificationSettlementRepository(database: database).saveVerification(
            verification,
            questStatus: .completed,
            settlement: settlement
        )

        let savedVerification = try await SQLiteVerificationRepository(database: database)
            .verification(forQuestId: fixture.quest.id)
        let savedSettlement = try await SQLiteGrowthSettlementRepository(database: database)
            .settlement(for: verification.id)
        let savedQuests = try await SQLiteQuestRepository(database: database)
            .quests(forTrainingCaseId: fixture.trainingCase.id)
        XCTAssertEqual(savedVerification?.id, verification.id)
        XCTAssertEqual(savedSettlement?.verificationId, verification.id)
        XCTAssertEqual(savedQuests.first?.status, .completed)
    }

    func testCalibrationReceiptRoundTripKeepsModelAssessmentAndSeparateSelfRating() async throws {
        for status in [CalibrationAssessment.JudgmentStatus.supported, .weakened, .unresolved] {
            let fixture = try await makeQuestFixture()
            var verification = makeVerification(quest: fixture.quest, entryId: fixture.entry.id)
            verification.judgmentUpdate = .confirmed
            verification.calibrationAssessment = CalibrationAssessment(evidenceStatus: status == .unresolved ? .conflicting : .observed,
                criteriaStatus: status == .supported ? .met : .notAssessable,
                judgmentStatus: status, evidenceQuotes: ["Observed result"])
            verification.calibrationNote = "只根据本次记录判断，保留其他解释。"
            verification.recommendation = "可自愿核对已有记录。"
            verification.principlePracticeAssessment = PrinciplePracticeAssessment(
                principleId: UUID(), status: .notAssessable, evidenceQuotes: [], reason: "没有行为记录。")
            let settlement = GrowthSettlementPolicy().make(verification: verification, quest: fixture.quest,
                caseId: fixture.trainingCase.id, modelEvidenceItems: [])
            try await SQLiteVerificationSettlementRepository(database: database).saveVerification(
                verification, questStatus: .completed, settlement: settlement)
            let saved = try await SQLiteVerificationRepository(database: database).verification(forQuestId: fixture.quest.id)
            let receipt = try await SQLiteGrowthSettlementRepository(database: database).settlement(for: verification.id)
            XCTAssertEqual(saved?.calibrationAssessment, verification.calibrationAssessment)
            XCTAssertEqual(saved?.principlePracticeAssessment, verification.principlePracticeAssessment)
            XCTAssertEqual(receipt?.calibrationAssessment, verification.calibrationAssessment)
            XCTAssertEqual(saved?.judgmentUpdate, .confirmed)
            XCTAssertEqual(receipt?.judgmentUpdate, .confirmed)
            XCTAssertEqual(receipt?.calibrationNote, verification.calibrationNote)
            XCTAssertEqual(receipt?.recommendation, verification.recommendation)
            // Exercise the independent verification repository update as well.
            verification.calibrationAssessment?.judgmentStatus = .unresolved
            verification.principlePracticeAssessment?.status = .partiallyPracticed
            verification.principlePracticeAssessment?.evidenceQuotes = ["Observed result"]
            verification.principlePracticeAssessment?.reason = "只报告了部分动作。"
            try await SQLiteVerificationRepository(database: database).saveVerification(verification)
            let updated = try await SQLiteVerificationRepository(database: database).verification(forQuestId: fixture.quest.id)
            XCTAssertEqual(updated?.calibrationAssessment?.judgmentStatus, .unresolved)
            XCTAssertEqual(updated?.principlePracticeAssessment, verification.principlePracticeAssessment)
        }
    }

    func testV73MigrationPreservesLegacySelfRatingWithoutInventingAssessment() async throws {
        let queue = try DatabaseQueue()
        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(queue, upTo: "v72_principle_review_drafts")
        let id = UUID(), questID = UUID(), entryID = UUID()
        try await queue.write { db in
            try db.execute(sql: "INSERT INTO verifications (id, quest_id, quest_title, source_daily_entry_id, completion, value_rating, judgment_update, evidence_text, calibration_note, created_at, updated_at) VALUES (?, ?, 'legacy', ?, 'done', 'high', 'confirmed', 'old record', 'old feedback', '2026-10-17T00:00:00Z', '2026-10-17T00:00:00Z')",
                arguments: [id.uuidString, questID.uuidString, entryID.uuidString])
            try db.execute(sql: "INSERT INTO growth_settlements (id, verification_id, original_judgment, actual_result, judgment_update, evidence_items_json, created_at) VALUES (?, ?, 'old target', 'old result', 'confirmed', '[]', '2026-10-17T00:00:00Z')",
                arguments: [UUID().uuidString, id.uuidString])
        }
        let migrated = try AppDatabase(dbQueue: queue)
        let verification = try await SQLiteVerificationRepository(database: migrated).verification(forQuestId: questID)
        let receipt = try await SQLiteGrowthSettlementRepository(database: migrated).settlement(for: id)
        XCTAssertEqual(verification?.judgmentUpdate, .confirmed)
        XCTAssertEqual(verification?.calibrationNote, "old feedback")
        XCTAssertNil(verification?.calibrationAssessment)
        XCTAssertNil(verification?.principlePracticeAssessment)
        XCTAssertEqual(receipt?.judgmentUpdate, .confirmed)
        XCTAssertNil(receipt?.calibrationAssessment)
        XCTAssertEqual(receipt?.calibrationNote, "")
        XCTAssertNil(receipt?.recommendation)
    }

    func testV74MigrationKeepsCalibrationAndDoesNotInventHistoricalPractice() async throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue, upTo: "v73_result_calibration_receipt")
        let id = UUID(), questID = UUID(), entryID = UUID()
        let calibration = CalibrationAssessment(evidenceStatus: .observed, criteriaStatus: .met,
            judgmentStatus: .supported, evidenceQuotes: ["交回没有返工"])
        let encoded = String(decoding: try JSONEncoder().encode(calibration), as: UTF8.self)
        try await queue.write { db in
            try db.execute(sql: "INSERT INTO verifications (id, quest_id, quest_title, source_daily_entry_id, completion, value_rating, judgment_update, evidence_text, calibration_note, calibration_assessment_json, created_at, updated_at) VALUES (?, ?, 'legacy', ?, 'done', 'high', 'confirmed', '交回没有返工', '仅一次观察', ?, '2026-10-17T00:00:00Z', '2026-10-17T00:00:00Z')",
                arguments: [id.uuidString, questID.uuidString, entryID.uuidString, encoded])
        }
        let migrated = try AppDatabase(dbQueue: queue)
        let saved = try await SQLiteVerificationRepository(database: migrated).verification(forQuestId: questID)
        XCTAssertEqual(saved?.id, id)
        XCTAssertEqual(saved?.evidenceText, "交回没有返工")
        XCTAssertEqual(saved?.judgmentUpdate, .confirmed)
        XCTAssertEqual(saved?.calibrationAssessment, calibration)
        XCTAssertNil(saved?.principlePracticeAssessment)
    }

    @MainActor
    func testResultReviewPersistsUnresolvedEvidenceWithoutRecordingSelectedPrinciplePractice() async throws {
        for conflicting in [false, true] {
            let fixture = try await makeQuestFixture()
            let principle = completionFixturePrinciple(title: "先确认结果")
            let principleRepo = SQLitePrincipleRepository(database: database)
            try await principleRepo.savePrinciple(principle, sourceDailyEntryId: fixture.entry.id)
            var quest = fixture.quest
            quest.trainingPrincipleId = principle.id
            try await SQLiteQuestRepository(database: database).saveQuest(quest, sourceDailyEntryId: fixture.entry.id)
            let evidence = conflicting ? "一条记录说完成，另一条记录说没有完成，来源待查。" : "没有记录这次结果。"
            let quotes = conflicting ? ["一条记录说完成", "另一条记录说没有完成"] : []
            let note = conflicting ? "两条记录存在冲突，无法核对验收条件或确认原判断。完成和高价值的自评暂不能解决冲突。" : "没有结果记录，无法核对验收条件或确认原判断。完成和高价值的自评暂不能替代结果。"
            let response = try JSONSerialization.data(withJSONObject: [
                "calibration_assessment": ["evidence_status": conflicting ? "conflicting" : "missing",
                    "criteria_status": "not_assessable", "judgment_status": "unresolved", "evidence_quotes": quotes],
                "calibration_note": note, "likely_issue": "none", "growth_evidence_items": [],
                "recommendation": "如果愿意，可只核对已有记录的来源和时间，不必重新测试。",
                "expected_principle_practice_assessment": "当前结果不足以确认练习过所选原则。",
                "principle_practice_assessment": ["principle_id": principle.id.uuidString, "status": "not_assessable", "evidence_quotes": [], "reason": "没有所选原则具体行为的记录。"]
            ])
            var draft = fixture.entry
            draft.state = .verifyYesterday
            let practiceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)
            let verifyingStore = AppStore(todayDraft: draft, quests: [quest], principles: [principle],
                dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
                questRepository: SQLiteQuestRepository(database: database),
                principleRepository: principleRepo,
                verificationRepository: SQLiteVerificationRepository(database: database),
                principlePracticeEvidenceRepository: practiceRepo,
                growthSettlementRepository: SQLiteGrowthSettlementRepository(database: database),
                verificationSettlementRepository: SQLiteVerificationSettlementRepository(database: database),
                todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: VNextResponseClient(response: response)),
                refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: true)
            verifyingStore.selectYesterdayCompletion(.done)
            verifyingStore.selectYesterdayValueRating(.high)
            verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
            verifyingStore.updateYesterdayEvidence(evidence)
            verifyingStore.submitTodayStep()
            for _ in 0..<300 where verifyingStore.latestGrowthSettlement == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            let receipt = try XCTUnwrap(verifyingStore.latestGrowthSettlement, verifyingStore.todayLoopMessage)
            XCTAssertEqual(receipt.calibrationAssessment?.judgmentStatus, .unresolved)
            XCTAssertEqual(receipt.calibrationNote, note)
            XCTAssertEqual(receipt.judgmentUpdate, .confirmed)
            XCTAssertTrue(receipt.evidenceItems.isEmpty)
            let practice = try await practiceRepo.evidence(for: principle.id, limit: 10)
            XCTAssertTrue(practice.isEmpty)
            let saved = try await SQLiteVerificationRepository(database: database).verification(forQuestId: quest.id)
            XCTAssertEqual(saved?.calibrationAssessment, receipt.calibrationAssessment)
            let savedReceipt = try await SQLiteGrowthSettlementRepository(database: database).settlement(for: receipt.verificationId)
            XCTAssertEqual(savedReceipt?.calibrationAssessment, receipt.calibrationAssessment)
            XCTAssertEqual(savedReceipt?.calibrationNote, note)
        }
    }

    @MainActor
    func testSelectedPrincipleAndObservedResultDoNotProvePractice() async throws {
        let fixture = try await makeQuestFixture()
        var principle = completionFixturePrinciple(title: "动手前请对方复述验收标准")
        principle.triggerContext = "跨人交接、动手之前"
        principle.actions = ["请对方复述验收标准"]
        let principles = SQLitePrincipleRepository(database: database)
        try await principles.savePrinciple(principle, sourceDailyEntryId: fixture.entry.id)
        var quest = fixture.quest
        quest.trainingPrincipleId = principle.id
        let quests = SQLiteQuestRepository(database: database)
        try await quests.saveQuest(quest, sourceDailyEntryId: fixture.entry.id)
        let result = "这次没有请对方复述验收标准；提交后仍返工两次。"
        let response = try JSONSerialization.data(withJSONObject: [
            "calibration_assessment": ["evidence_status": "observed", "criteria_status": "not_met", "judgment_status": "unresolved", "evidence_quotes": ["提交后仍返工两次"]],
            "calibration_note": "记录显示提交后仍返工两次，不能核对原行动已达标，也不能确认原判断。所选原则要求的复述未执行。",
            "likely_issue": "none", "recommendation": "以后若自愿再试，可记录是否先复述标准。",
            "expected_principle_practice_assessment": "用户明确说没有请对方复述，所选原则未实践。",
            "principle_practice_assessment": ["principle_id": principle.id.uuidString, "status": "not_practiced", "evidence_quotes": ["这次没有请对方复述验收标准"], "reason": "记录明确说明没有执行复述动作。"],
            "growth_evidence_items": []
        ])
        let practice = SQLitePrinciplePracticeEvidenceRepository(database: database)
        let subject = AppStore(todayDraft: fixture.entry, quests: [quest], principles: [principle],
            dailyEntryRepository: SQLiteDailyEntryRepository(database: database), questRepository: quests,
            principleRepository: principles, verificationRepository: SQLiteVerificationRepository(database: database),
            principlePracticeEvidenceRepository: practice,
            growthSettlementRepository: SQLiteGrowthSettlementRepository(database: database),
            verificationSettlementRepository: SQLiteVerificationSettlementRepository(database: database),
            todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: VNextResponseClient(response: response)),
            refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: true)
        await subject.beginVerification(quest)
        subject.selectYesterdayCompletion(.done)
        subject.selectYesterdayValueRating(.high)
        subject.selectYesterdayJudgmentUpdate(.confirmed)
        subject.updateYesterdayEvidence(result)
        subject.submitTodayStep()
        for _ in 0..<300 where subject.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(subject.latestGrowthSettlement, subject.todayLoopMessage)
        let recorded = try await practice.evidence(for: principle.id, limit: 20)
        XCTAssertTrue(recorded.isEmpty, "Selecting a principle and reporting a result cannot establish practice of its actions")
    }

    func testLegacyAutomaticPrincipleMatchesDoNotCountAsPracticeOrInternalization() {
        let principle = completionFixturePrinciple(title: "先复述标准")
        let evidence = (0..<3).map { _ in
            PrinciplePracticeEvidence(principleId: principle.id, sourceDailyEntryId: UUID(),
                evidenceSource: .verification, strength: .intentionalPractice,
                evidenceSummary: "用户选择后被自动记为实际练习。", matchSignal: "用户选择",
                attributionPolicyVersion: "principle-practice-attribution.local-match.v1")
        }
        let summary = PrincipleTrainingSummary.summary(for: principle, practiceEvidence: evidence, recallFeedback: [])
        XCTAssertEqual(summary.practiceEvidenceCount, 0)
        XCTAssertEqual(summary.state, .knownButUnused)
        XCTAssertEqual(summary.unassessedPracticeEvidenceCount, 3)
    }

    func testRepeatedPracticeAndHelpfulRecallDoNotEstablishInternalization() {
        let principle = completionFixturePrinciple(title: "先复述标准")
        let evidence = (0..<3).map { index in
            PrinciplePracticeEvidence(schemaVersion: 2, principleId: principle.id, sourceDailyEntryId: UUID(),
                evidenceSource: .verification, strength: .intentionalPractice,
                evidenceSummary: "第\(index)次报告先复述了标准。", matchSignal: "我请对方复述了标准",
                attributionPolicyVersion: PrinciplePracticeEvidence.resultEvidencePolicyVersion)
        }
        let summary = PrincipleTrainingSummary.summary(for: principle, practiceEvidence: evidence, recallFeedback: [])
        XCTAssertEqual(summary.practiceEvidenceCount, 3)
        XCTAssertEqual(summary.state, .consciouslyPracticed)
        let recall = PrincipleRecallFeedback(principleId: principle.id, promptId: .generateQuestions,
            retrievalPolicyVersion: "test", retrievalReason: "Useful reminder", feedback: .helpful)
        let recalled = PrincipleTrainingSummary.summary(for: principle, practiceEvidence: [], recallFeedback: [recall])
        XCTAssertEqual(recalled.state, .knownButUnused)
    }

    @MainActor
    func testGroundedPrinciplePracticePersistsIndependentlyOfOutcomeAndDeduplicates() async throws {
        for partial in [false, true] {
            let fixture = try await makeQuestFixture()
            var principle = completionFixturePrinciple(title: "交接前先复述验收标准")
            principle.triggerContext = "交接开始前"
            principle.actions = ["写出验收标准", "请对方复述确认"]
            let principles = SQLitePrincipleRepository(database: database)
            try await principles.savePrinciple(principle, sourceDailyEntryId: fixture.entry.id)
            var quest = fixture.quest
            quest.trainingPrincipleId = principle.id
            let quests = SQLiteQuestRepository(database: database)
            try await quests.saveQuest(quest, sourceDailyEntryId: fixture.entry.id)
            let result = partial ? "交接前我写出了验收标准，但没有请对方复述；结果还没回来。" : "交接前我写出了验收标准，请对方复述确认；结果还没回来。"
            let quote = partial ? "交接前我写出了验收标准，但没有请对方复述" : "交接前我写出了验收标准，请对方复述确认"
            let response = try JSONSerialization.data(withJSONObject: [
                "calibration_assessment": ["evidence_status": "missing", "criteria_status": "not_assessable", "judgment_status": "unresolved", "evidence_quotes": []],
                "calibration_note": "记录了交接时的动作，但后续结果尚未回来，无法核对结果标准。原判断仍未确定。",
                "likely_issue": "none", "recommendation": "若以后有结果，可自愿补记已有反馈。",
                "expected_principle_practice_assessment": partial ? "只写了标准，没有执行复述动作，部分实践。" : "记录支持这次做过写标准和复述动作，不证明效果。",
                "principle_practice_assessment": ["principle_id": principle.id.uuidString, "status": partial ? "partially_practiced" : "practiced", "evidence_quotes": [quote], "reason": partial ? "只执行了写标准这部分。" : "本次报告写了标准并复述，不代表产生效果。"],
                "growth_evidence_items": []
            ])
            let practice = SQLitePrinciplePracticeEvidenceRepository(database: database)
            let legacy = PrinciplePracticeEvidence(principleId: principle.id,
                sourceDailyEntryId: fixture.entry.id, questId: quest.id,
                evidenceSource: .verification, strength: .intentionalPractice,
                evidenceSummary: "旧版根据选择自动关联", matchSignal: "用户选择",
                createdAt: .now.addingTimeInterval(-60))
            try await practice.saveEvidence(legacy)
            let client = VNextResponseClient(response: response)
            let verificationRepo = SQLiteVerificationRepository(database: database)
            let subject = AppStore(todayDraft: fixture.entry, quests: [quest], principles: [principle],
                dailyEntryRepository: SQLiteDailyEntryRepository(database: database), questRepository: quests,
                principleRepository: principles, verificationRepository: verificationRepo,
                principlePracticeEvidenceRepository: practice,
                growthSettlementRepository: SQLiteGrowthSettlementRepository(database: database),
                verificationSettlementRepository: SQLiteVerificationSettlementRepository(database: database),
                todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client),
                refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: true)
            for _ in 0..<2 {
                await subject.beginVerification(quest)
                subject.selectYesterdayCompletion(.done)
                subject.selectYesterdayValueRating(.high)
                subject.selectYesterdayJudgmentUpdate(.confirmed)
                subject.updateYesterdayEvidence(result)
                subject.submitTodayStep()
                for _ in 0..<300 where subject.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
                XCTAssertNotNil(subject.latestGrowthSettlement, subject.todayLoopMessage)
            }
            let loaded = try await verificationRepo.verification(forQuestId: quest.id)
            let stored = try XCTUnwrap(loaded)
            let assessment = try XCTUnwrap(stored.principlePracticeAssessment)
            XCTAssertEqual(assessment.status, partial ? .partiallyPracticed : .practiced)
            XCTAssertEqual(assessment.evidenceQuotes, [quote])
            XCTAssertEqual(stored.calibrationAssessment?.evidenceStatus, .missing)
            XCTAssertEqual(HistoricalVerificationEvidence(stored).principlePracticeAssessment, assessment)
            let evidence = try await practice.evidence(for: principle.id, limit: 20)
            XCTAssertEqual(evidence.count, 2)
            let retainedLegacy = try XCTUnwrap(evidence.first(where: { $0.id == legacy.id }))
            XCTAssertEqual(retainedLegacy.evidenceSummary, legacy.evidenceSummary)
            XCTAssertEqual(retainedLegacy.matchSignal, legacy.matchSignal)
            XCTAssertEqual(retainedLegacy.schemaVersion, 1)
            XCTAssertEqual(retainedLegacy.attributionPolicyVersion, legacy.attributionPolicyVersion)
            XCTAssertEqual(retainedLegacy.createdAt.timeIntervalSince1970, legacy.createdAt.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(retainedLegacy.updatedAt.timeIntervalSince1970, legacy.updatedAt.timeIntervalSince1970, accuracy: 0.001)
            let supported = evidence.filter(\.supportsPracticeRecord)
            XCTAssertEqual(supported.count, 1)
            XCTAssertEqual(supported.first?.id, supported.first?.verificationId)
            XCTAssertEqual(supported.first?.strength, partial ? .attempted : .intentionalPractice)
            XCTAssertEqual(supported.first?.sourceDailyEntryId, fixture.entry.id)
            XCTAssertEqual(supported.first?.questId, quest.id)
            XCTAssertEqual(supported.first?.matchSignal, quote)
            XCTAssertTrue(supported.first?.evidenceSummary.contains("不证明效果或已经内化") == true)
            XCTAssertEqual(subject.principleTrainingSummaries.first?.state, .consciouslyPracticed)
            XCTAssertEqual(subject.principleTrainingSummaries.first?.practiceEvidenceCount, 1)
            XCTAssertEqual(subject.principleTrainingSummaries.first?.unassessedPracticeEvidenceCount, 1)
        }
    }

    @MainActor
    func testDueVerificationCompletesHistoricalCaseWithoutLoadingItAsTodaysCase() async throws {
        let fixture = try await makeQuestFixture()
        var oldEntry = fixture.entry
        oldEntry.date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        try await SQLiteDailyEntryRepository(database: database).saveDraft(oldEntry)
        let today = DailyEntryDraft(state: .capture)
        try await SQLiteDailyEntryRepository(database: database).saveDraft(today)
        let cases = SQLiteTrainingCaseRepository(database: database)
        let response = Data(#"""
        {"calibration_assessment":{"evidence_status":"missing","criteria_status":"not_assessable","judgment_status":"unresolved","evidence_quotes":[]},"calibration_note":"没有记录实际结果，暂不能核对原验收标准，也不能确认或推翻原判断。完成动作的自评仍保留。","likely_issue":"none","growth_evidence_items":[],"recommendation":"如果以后有结果，可再更新判断；现在无需补做测试。","expected_principle_practice_assessment":"没有结果，不能确认原则实践。"}
        """#.utf8)
        let subject = AppStore(todayDraft: today,
            dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
            questRepository: SQLiteQuestRepository(database: database),
            verificationRepository: SQLiteVerificationRepository(database: database),
            trainingCaseRepository: cases,
            growthSettlementRepository: SQLiteGrowthSettlementRepository(database: database),
            verificationSettlementRepository: SQLiteVerificationSettlementRepository(database: database),
            todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: VNextResponseClient(response: response)),
            refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: true)
        XCTAssertTrue(subject.trainingCases.isEmpty)
        await subject.beginVerification(fixture.quest)
        subject.selectYesterdayCompletion(.done)
        subject.selectYesterdayValueRating(.uncertain)
        subject.selectYesterdayJudgmentUpdate(.unresolved)
        subject.updateYesterdayEvidence("没有记录实际结果。")
        subject.submitTodayStep()
        for _ in 0..<300 where subject.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(subject.isSavingTodayCompletion, subject.todayLoopMessage)
        XCTAssertTrue(subject.isTodayOverviewPresented, subject.todayLoopMessage)
        XCTAssertEqual(subject.todayDraft.id, today.id)
        XCTAssertTrue(subject.trainingCases.isEmpty)
        let savedCase = try await cases.caseRecord(id: fixture.trainingCase.id)
        XCTAssertEqual(savedCase?.status, .completed)
        let saved = try await SQLiteVerificationRepository(database: database).verification(forQuestId: fixture.quest.id)
        XCTAssertEqual(saved?.sourceDailyEntryId, fixture.entry.id)
        XCTAssertEqual(saved?.judgmentUpdate, .unresolved)
    }

    func testGrowthSettlementDoesNotInventEvidenceWhenModelReturnsNone() async throws {
        let fixture = try await makeQuestFixture()
        let verification = makeVerification(quest: fixture.quest, entryId: fixture.entry.id)

        let settlement = GrowthSettlementPolicy().make(
            verification: verification,
            quest: fixture.quest,
            caseId: fixture.trainingCase.id,
            modelEvidenceItems: []
        )

        XCTAssertTrue(settlement.evidenceItems.isEmpty)
    }

    func testVerificationSettlementRejectsMismatchedSettlementWithoutPartialWrite() async throws {
        let fixture = try await makeQuestFixture()
        let verification = makeVerification(quest: fixture.quest, entryId: fixture.entry.id)
        let invalid = GrowthSettlement(
            verificationId: UUID(),
            caseId: fixture.trainingCase.id,
            originalJudgment: "old",
            actualResult: "actual",
            judgmentUpdate: .adjusted,
            evidenceItems: []
        )

        do {
            try await SQLiteVerificationSettlementRepository(database: database).saveVerification(
                verification,
                questStatus: .completed,
                settlement: invalid
            )
            XCTFail("Expected validation failure")
        } catch {}

        let partialVerification = try await SQLiteVerificationRepository(database: database)
            .verification(forQuestId: fixture.quest.id)
        XCTAssertNil(partialVerification)
    }

    func testDeferringVerificationDoesNotCreateVerification() async throws {
        let fixture = try await makeQuestFixture()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let questRepo = SQLiteQuestRepository(database: database)
        try await questRepo.deferVerification(for: fixture.quest.id, until: tomorrow)
        let reloadedQuests = try await questRepo.quests(forTrainingCaseId: fixture.trainingCase.id)
        let reloaded = try XCTUnwrap(reloadedQuests.first)

        XCTAssertEqual(reloaded.verificationDeferredUntil?.timeIntervalSince1970 ?? 0, tomorrow.timeIntervalSince1970, accuracy: 0.01)
        let deferredVerification = try await SQLiteVerificationRepository(database: database)
            .verification(forQuestId: fixture.quest.id)
        XCTAssertNil(deferredVerification)
        XCTAssertTrue(
            VerificationCoordinator().dueQuests(from: [reloaded], verifications: []).isEmpty
        )
    }

    func testPromptContextUsesOnlyCurrentCaseMaterialAndAuditsCaseId() {
        let entry = DailyEntryDraft(rawText: "A material\nB material", sessionMode: .standard, hasSelectedSessionMode: true)
        let trainingCase = TrainingCase(dailyEntryId: entry.id, title: "A", status: .inProgress)
        let card = ThinkingCard(
            trainingCaseId: trainingCase.id,
            type: .fact,
            title: "A fact",
            body: "Only A evidence",
            isConfirmed: true
        )

        let promptContext = DefaultContextAssembler().assemble(
            promptID: .generateQuestions,
            context: TodayAIContext(
                draft: entry,
                currentTrainingCase: trainingCase,
                confirmedCards: [card]
            )
        )

        XCTAssertEqual(promptContext.contextPayload.currentCase?.id, trainingCase.id.uuidString)
        XCTAssertEqual(promptContext.contextPayload.currentInput.rawText, "A fact：Only A evidence")
        XCTAssertFalse(promptContext.contextPayload.currentInput.rawText?.contains("B material") == true)
        XCTAssertTrue(promptContext.sourceRecordIDs.contains(trainingCase.id.uuidString))
    }

    func testGuidanceMasterySuppressesHintUntilCounterexample() {
        let engine = GuidanceEngine()
        let item = BuiltinGuidanceCatalog.items[0]
        let mastered = UserGuidanceState(hintId: item.hintId, status: .mastered)
        XCTAssertNil(
            engine.recommendation(
                stage: item.stage,
                triggerKeys: [item.triggerKey],
                states: [mastered]
            )
        )

        var regressed = mastered
        regressed.counterexampleCount = 1
        XCTAssertEqual(
            engine.recommendation(
                stage: item.stage,
                triggerKeys: [item.triggerKey],
                states: [regressed]
            )?.hintId,
            item.hintId
        )
    }

    func testGuidanceDecisionIsModelSelectedFromEligibleCandidates() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"decision":"show","hint_id":"verification.result_not_completion","reason":"实际结果需要与单纯完成区分。"}
        """)
        let item = try XCTUnwrap(BuiltinGuidanceCatalog.items.first { $0.hintId == "verification.result_not_completion" })
        let service = GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let decision = try await service.choose(
            context: GuidanceDecisionContext(
                stage: .verification,
                triggerKeys: [item.triggerKey],
                candidates: [GuidanceDecisionCandidate(
                    hintId: item.hintId,
                    copy: item.copy,
                    explanation: item.explanation,
                    stage: item.stage,
                    triggerKey: item.triggerKey
                )],
                states: [],
                currentCaseId: UUID().uuidString,
                currentCaseTitle: "验证事项",
                evidenceSummary: "完成记录缺少实际结果"
            )
        )

        XCTAssertEqual(decision.action, .show)
        XCTAssertEqual(decision.hintId, item.hintId)
        XCTAssertEqual(client.promptIDs, [.recommendGuidance])
    }

    func testGuidanceDecisionRejectsHintOutsideCandidateDirectory() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"decision":"show","hint_id":"unknown.hint","reason":"错误候选"}
        """)
        let service = GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        do {
            _ = try await service.choose(
                context: GuidanceDecisionContext(
                    stage: .judgment,
                    triggerKeys: [],
                    candidates: [],
                    states: [],
                    currentCaseId: nil,
                    currentCaseTitle: nil,
                    evidenceSummary: ""
                )
            )
            XCTFail("Expected an invalid candidate decision")
        } catch {
            XCTAssertTrue(error is TodayAIParsingError)
        }
    }

    func testGuidanceRepeatedResultDoesNotCountAgainOrCreateMastery() throws {
        let engine = GuidanceEngine()
        let item = BuiltinGuidanceCatalog.items[0]
        let once = engine.recordingEvidence(for: item, state: nil, evidenceRef: "result-1", isCounterexample: false)
        let duplicate = engine.recordingEvidence(for: item, state: once, evidenceRef: "result-1", isCounterexample: false)
        XCTAssertEqual(duplicate, once)
        let second = engine.recordingEvidence(for: item, state: once, evidenceRef: "result-2", isCounterexample: false)
        XCTAssertEqual(second.evidenceCount, 2)
        XCTAssertEqual(second.status, .practicing, "Two reported occasions do not establish mastery")
        let counterexample = engine.recordingEvidence(for: item, state: once, evidenceRef: "result-1", isCounterexample: true)
        XCTAssertEqual(counterexample, once, "Repeated or contradictory classification of one immutable result cannot count twice")
    }

    func testGuidanceEvidenceRejectsFabricatedBehaviorQuote() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"result":"supports","hint_id":"verification.result_not_completion","reason":"写了具体结果。","evidence_quotes":["我检查了三次结果并比较原因。"]}
        """)
        let item = try XCTUnwrap(BuiltinGuidanceCatalog.items.first { $0.hintId == "verification.result_not_completion" })
        let quest = makeQuest(caseId: UUID(), title: "验证结果")
        var verification = makeVerification(quest: quest, entryId: UUID())
        verification.evidenceText = "只记得完成，没记结果。"
        do {
            _ = try await GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                .evaluateEvidence(item: item, quest: quest, verification: verification)
            XCTFail("Fabricated behavior quotes must not change guidance state")
        } catch { XCTAssertTrue(error is TodayAIParsingError) }
    }

    func testGuidanceEvidenceClassificationIsModelBacked() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"result":"counterexample","hint_id":"verification.result_not_completion","reason":"明确没记录结果。","evidence_quotes":["只记录完成，没有记录任何结果。"]}
        """)
        let item = try XCTUnwrap(BuiltinGuidanceCatalog.items.first { $0.hintId == "verification.result_not_completion" })
        let quest = makeQuest(caseId: UUID(), title: "验证结果")
        var verification = makeVerification(quest: quest, entryId: UUID())
        verification.evidenceText = "只记录完成，没有记录任何结果。"
        let decision = try await GuidanceAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ).evaluateEvidence(item: item, quest: quest, verification: verification)

        XCTAssertEqual(decision.result, .counterexample)
        XCTAssertEqual(decision.hintId, item.hintId)
        XCTAssertEqual(client.promptIDs, [.evaluateGuidanceEvidence])
    }

    func testGuidanceEvidenceContextAndQuoteBoundaries() async throws {
        let item = BuiltinGuidanceCatalog.items[0]
        let quest = makeQuest(caseId: UUID(), title: "交接")
        var verification = makeVerification(quest: quest, entryId: UUID())
        verification.evidenceText = "动手前写了标准，但交回仍返工。"
        verification.calibrationAssessment = CalibrationAssessment(evidenceStatus: .observed,
            criteriaStatus: .notMet, judgmentStatus: .unresolved, evidenceQuotes: ["交回仍返工"])
        let cases: [(String, [String]?, String?, Bool)] = [
            ("supports", ["动手前写了标准"], item.hintId, true),
            ("counterexample", ["交回仍返工"], item.hintId, true), // Provenance only; meaning needs model review.
            ("insufficient", [], item.hintId, true),
            ("supports", [], item.hintId, false),
            ("supports", [" "], item.hintId, false),
            ("supports", ["动手前写了标准", "动手前写了标准"], item.hintId, false),
            ("counterexample", ["编造行为"], item.hintId, false),
            ("insufficient", ["交回仍返工"], item.hintId, false),
            ("supports", ["动手前写了标准"], "unknown", false)
        ]
        for (result, quotes, hint, valid) in cases {
            let raw = try JSONSerialization.data(withJSONObject: ["result": result,
                "hint_id": hint!, "reason": "只描述本次报告。", "evidence_quotes": quotes ?? []])
            let client = GuidanceFixtureLLMClient(response: String(decoding: raw, as: UTF8.self))
            do {
                let decision = try await GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .evaluateEvidence(item: item, quest: quest, verification: verification)
                XCTAssertTrue(valid)
                XCTAssertEqual(decision.evidenceQuotes, quotes)
            } catch { XCTAssertFalse(valid, "Unexpected rejection: \(error)") }
            let request = try XCTUnwrap(client.requests.first)
            let encoded = try XCTUnwrap(request.contextPayload?.currentInput.rawText)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any])
            XCTAssertEqual(payload["judgmentSelfReport"] as? String, "adjusted")
            XCTAssertEqual(payload["completionSelfReport"] as? String, "done")
            XCTAssertEqual(payload["valueSelfReport"] as? String, "high")
            XCTAssertNotNil(payload["calibrationAssessment"])
            XCTAssertEqual(payload["evidenceText"] as? String, verification.evidenceText)
        }
    }

    func testGuidanceRepositoryDeduplicatesAndPreservesUserPreferencesAcrossWriters() async throws {
        let first = SQLiteGuidanceRepository(database: database)
        let second = SQLiteGuidanceRepository(database: database)
        let item = BuiltinGuidanceCatalog.items[0]
        let id = UUID()
        _ = try await first.recordEvidence(for: item, verificationId: id, isCounterexample: false)
        _ = try await second.recordEvidence(for: item, verificationId: id, isCounterexample: true)
        let once = try await first.state(for: item.hintId)
        XCTAssertEqual(once?.evidenceCount, 1)
        XCTAssertEqual(once?.counterexampleCount, 0)
        // Whole-second fixture avoids submillisecond ISO serialization drift.
        let until = Date(timeIntervalSince1970: 2_000_000_000)
        _ = try await second.updatePreference(for: item.hintId, snoozedUntil: until, mastered: false, now: .now)
        // Share GRDB's Sendable queue, and create each non-Sendable repository
        // inside its own task rather than transferring a retained repository.
        let queue = database.dbQueue
        let a = Task.detached {
            let repository = SQLiteGuidanceRepository(database: try AppDatabase(dbQueue: queue))
            _ = try await repository.recordEvidence(for: item, verificationId: UUID(), isCounterexample: false)
        }
        let b = Task.detached {
            let repository = SQLiteGuidanceRepository(database: try AppDatabase(dbQueue: queue))
            _ = try await repository.recordEvidence(for: item, verificationId: UUID(), isCounterexample: false)
        }
        _ = try await (a.value, b.value)
        var loaded = try await first.state(for: item.hintId)
        XCTAssertEqual(loaded?.evidenceCount, 3)
        XCTAssertEqual(loaded?.evidenceRefs.count, 3)
        XCTAssertEqual(loaded?.status, .practicing)
        XCTAssertEqual(try XCTUnwrap(loaded?.snoozedUntil).timeIntervalSince1970, until.timeIntervalSince1970, accuracy: 0.001)
        _ = try await first.updatePreference(for: item.hintId, snoozedUntil: nil, mastered: true, now: .now)
        _ = try await second.recordEvidence(for: item, verificationId: UUID(), isCounterexample: true)
        loaded = try await first.state(for: item.hintId)
        XCTAssertEqual(loaded?.status, .practicing)
        XCTAssertEqual(loaded?.counterexampleCount, 1)
        XCTAssertEqual(loaded?.evidenceCount, 3)
        XCTAssertNotNil(loaded?.snoozedUntil)
    }

    @MainActor
    func testGuidanceAttributionIgnoresLegacyMissingConflictingAndMismatchedResultsWithoutCalls() async throws {
        let quest = makeQuest(caseId: UUID(), title: "交接")
        let client = GuidanceFixtureLLMClient(response: "{}")
        let store = AppStore(guidanceRepository: SQLiteGuidanceRepository(database: database),
            refreshesAIServiceFromKeychain: false,
            guidanceAIService: GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client),
            trainingCasesVNextEnabled: true)
        var verification = makeVerification(quest: quest, entryId: UUID())
        await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification)
        for status in [CalibrationAssessment.EvidenceStatus.missing, .conflicting] {
            verification.calibrationAssessment = CalibrationAssessment(evidenceStatus: status,
                criteriaStatus: .notAssessable, judgmentStatus: .unresolved, evidenceQuotes: [])
            await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification)
        }
        verification.calibrationAssessment = CalibrationAssessment(evidenceStatus: .observed,
            criteriaStatus: .met, judgmentStatus: .supported, evidenceQuotes: ["编造记录"])
        await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification)
        verification.calibrationAssessment?.evidenceQuotes = ["Observed result"]
        verification.questId = UUID()
        await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification)
        XCTAssertTrue(client.promptIDs.isEmpty)
        XCTAssertTrue(store.guidanceStates.isEmpty)
    }

    @MainActor
    func testGuidanceAttributionCoalescesDuplicateWorkAndIgnoresCancelledOrReconfiguredResponse() async throws {
        for changeConfiguration in [false, true] {
            let quest = makeQuest(caseId: UUID(), title: "交接")
            var verification = makeVerification(quest: quest, entryId: UUID())
            verification.evidenceText = "动手前写了验收标准，交回后没有返工。"
            verification.calibrationAssessment = CalibrationAssessment(evidenceStatus: .observed,
                criteriaStatus: .met, judgmentStatus: .unresolved, evidenceQuotes: ["交回后没有返工"])
            let client = GuidanceFixtureLLMClient(response: """
            {"result":"supports","hint_id":"action.completion_criteria","reason":"明确报告写了标准。","evidence_quotes":["动手前写了验收标准"]}
            """)
            client.suspendBeforeResponse = true
            let repo = SQLiteGuidanceRepository(database: database)
            let store = AppStore(guidanceRepository: repo,
                refreshesAIServiceFromKeychain: changeConfiguration,
                guidanceAIService: GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client),
                trainingCasesVNextEnabled: true)
            let first = Task { await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification) }
            for _ in 0..<100 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertNotNil(client.responseGate)
            await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification)
            XCTAssertEqual(client.promptIDs.count, 1)
            if changeConfiguration { store.refreshAPIKeyStatus() } else { first.cancel() }
            client.responseGate?.resume()
            client.responseGate = nil
            await first.value
            let states = try await repo.allStates()
            XCTAssertTrue(states.isEmpty)
            XCTAssertTrue(store.guidanceStates.isEmpty)
            XCTAssertEqual(client.promptIDs.count, 1)
        }
    }

    @MainActor
    func testGuidanceAttributionPersistsOnceAcrossStoreRecreationAndStopsOnWriteFailure() async throws {
        for failWrite in [false, true] {
            let queue = try DatabaseQueue()
            let localDatabase = try AppDatabase(dbQueue: queue)
            let repo = SQLiteGuidanceRepository(database: localDatabase)
            let client = GuidanceEvidenceEchoTestClient()
            let quest = makeQuest(caseId: UUID(), title: "交接")
            var verification = makeVerification(quest: quest, entryId: UUID())
            verification.evidenceText = "动手前写了标准，交回仍返工两次。"
            verification.calibrationAssessment = CalibrationAssessment(evidenceStatus: .observed,
                criteriaStatus: .met, judgmentStatus: .unresolved, evidenceQuotes: ["交回仍返工两次"])
            if failWrite {
                try await queue.write { db in
                    try db.execute(sql: "CREATE TRIGGER reject_guidance BEFORE INSERT ON user_guidance_states BEGIN SELECT RAISE(ABORT, 'synthetic guidance failure'); END")
                }
            }
            for _ in 0..<2 {
                let store = AppStore(guidanceRepository: repo, refreshesAIServiceFromKeychain: false,
                    guidanceAIService: GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client),
                    trainingCasesVNextEnabled: true)
                let page = store.todayDraft.id
                let message = store.todayLoopMessage
                await store.recordGuidanceEvidenceAfterVerification(quest: quest, verification: verification)
                XCTAssertEqual(store.todayDraft.id, page)
                XCTAssertEqual(store.todayLoopMessage, message)
            }
            let states = try await repo.allStates()
            if failWrite {
                XCTAssertTrue(states.isEmpty)
                XCTAssertEqual(client.requests.count, 2, "One request per attempt, no subsequent catalog calls after storage failure")
            } else {
                XCTAssertEqual(states.count, BuiltinGuidanceCatalog.items.count)
                XCTAssertTrue(states.allSatisfy { $0.evidenceCount == 1 && $0.evidenceRefs == [verification.id.uuidString] && $0.status == .practicing })
                XCTAssertEqual(client.requests.count, BuiltinGuidanceCatalog.items.count, "Persisted source IDs avoid model calls on a repeated result")
            }
        }
    }

    func testCoachTrainingDecisionPreservesModelGapRatherThanInferringFromPhase() async throws {
        let card = ThinkingCard(type: .fact, title: "已观察", body: "两次提交都在上传时超时；暂不清楚权限是否影响重试。", isConfirmed: true)
        let context = CoachDecisionContext(caseId: UUID(), caseTitle: "重试", mode: .standard, cards: [card])
        let client = GuidanceFixtureLLMClient(response: try coachDecisionJSON(gaps: ["missing_constraint"], refs: [card.id.uuidString]))
        let result = try await CoachDecisionAIService(promptProvider: LocalPromptProvider(), llmClient: client).decide(context: context)
        XCTAssertEqual(result.diagnosis.phase, .fillEvidenceGap)
        XCTAssertEqual(result.diagnosis.openEvidenceGaps, [.missingConstraint])
        XCTAssertEqual(result.diagnosis.sourceRefs, [card.id.uuidString])
        let turn = CoachTurnPolicy().makeInitialTurn(cards: [card], diagnosis: result.diagnosis)
        XCTAssertEqual(turn.openEvidenceGaps, [.missingConstraint], "Observed material must not become missing observation or baseline because of its phase")
        XCTAssertEqual(result.prescription.recommendedLensId, "evidenceCheck")
        XCTAssertEqual(client.promptIDs, [.diagnoseTrainingCase])
        let roundTrip = try JSONDecoder().decode(CoachDiagnosis.self, from: JSONEncoder().encode(result.diagnosis))
        XCTAssertEqual(roundTrip, result.diagnosis)
    }

    func testCoachTrainingDecisionAllowsUnknownWithoutInventingRepair() async throws {
        let card = ThinkingCard(type: .idea, title: "先停下", body: "我知道提交超时，但原因不明；今天先记录，不再调查。", isConfirmed: true)
        let client = GuidanceFixtureLLMClient(response: try coachDecisionJSON(gaps: [], refs: [card.id.uuidString]))
        let result = try await CoachDecisionAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            .decide(context: .init(caseId: nil, caseTitle: nil, mode: .deep, cards: [card]))
        XCTAssertEqual(result.diagnosis.readiness, .notReady)
        XCTAssertEqual(CoachTurnPolicy().makeInitialTurn(cards: [card], diagnosis: result.diagnosis).openEvidenceGaps, [])
        var legacy = result.diagnosis
        legacy.policyVersion = "coach-decision.llm.v1"
        legacy.openEvidenceGaps = nil
        legacy.sourceRefs = nil
        XCTAssertTrue(CoachTurnPolicy().makeInitialTurn(cards: [card], diagnosis: legacy).openEvidenceGaps.isEmpty,
                      "An old model phase cannot establish new missing materials")
        legacy.policyVersion = CoachEngine.policyVersion
        XCTAssertFalse(CoachTurnPolicy().makeInitialTurn(cards: [card], diagnosis: legacy).openEvidenceGaps.isEmpty,
                       "Explicit preview policies retain historical behavior")
    }

    func testCoachTrainingDecisionRejectsUngroundedOrContradictoryCurrentContract() async throws {
        let caseID = UUID()
        let card = ThinkingCard(type: .fact, title: "已确认", body: "观察到一次超时。", isConfirmed: true)
        let valid = try coachDecisionJSON(gaps: ["missing_constraint"], refs: [card.id.uuidString])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(valid.utf8)) as? [String: Any])
        var invalid: [[String: Any]] = []
        for field in ["open_evidence_gaps", "source_refs"] {
            var copy = object; copy.removeValue(forKey: field); invalid.append(copy)
            copy = object; copy[field] = NSNull(); invalid.append(copy)
        }
        for gaps in [["none"], ["unknown"], ["missing_observation", "missing_constraint"]] {
            var copy = object; copy["open_evidence_gaps"] = gaps; invalid.append(copy)
        }
        for refs in [[], [UUID().uuidString], [caseID.uuidString], [card.id.uuidString, card.id.uuidString]] {
            var copy = object; copy["source_refs"] = refs; invalid.append(copy)
        }
        object["readiness"] = "ready"; invalid.append(object)
        for (index, response) in invalid.enumerated() {
            let json = String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
            let client = GuidanceFixtureLLMClient(response: json)
            do {
                _ = try await CoachDecisionAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .decide(context: .init(caseId: caseID, caseTitle: nil, mode: .standard, cards: [card]))
                XCTFail("Accepted invalid decision \(index)")
            } catch { XCTAssertEqual(client.promptIDs, [.diagnoseTrainingCase], "No automatic retry") }
        }
    }

    func testCoachTrainingDecisionDoesNotTransmitUnconfirmedExcludedOrOtherCaseMaterial() async throws {
        let caseID = UUID()
        var own = ThinkingCard(type: .fact, title: "确认来源", body: "观察到一次超时。", isConfirmed: true)
        own.trainingCaseId = caseID
        let unconfirmed = ThinkingCard(type: .idea, title: "未确认", body: "UNCONFIRMED_PRIVATE_MARKER")
        var excluded = ThinkingCard(type: .idea, title: "已排除", body: "EXCLUDED_PRIVATE_MARKER", isConfirmed: true)
        excluded.isExcludedFromModel = true
        var other = ThinkingCard(type: .idea, title: "其他事项", body: "OTHER_CASE_PRIVATE_MARKER", isConfirmed: true)
        other.trainingCaseId = UUID()
        for invalidRef in [unconfirmed.id, excluded.id, other.id] {
            let client = RecordingCoachDecisionClient(response: try coachDecisionJSON(gaps: [], refs: [invalidRef.uuidString]))
            do {
                _ = try await CoachDecisionAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .decide(context: .init(caseId: caseID, caseTitle: nil, mode: .standard, cards: [own, unconfirmed, excluded, other]))
                XCTFail("Unconfirmed, excluded or foreign source was accepted")
            } catch {}
            let request = try XCTUnwrap(client.requests.first)
            let payload = String(decoding: try JSONEncoder().encode(request.contextPayload), as: UTF8.self)
            for marker in ["UNCONFIRMED_PRIVATE_MARKER", "EXCLUDED_PRIVATE_MARKER", "OTHER_CASE_PRIVATE_MARKER"] {
                XCTAssertFalse(payload.contains(marker))
            }
            XCTAssertEqual(request.contextPayload?.currentCase?.evidenceRefs, [own.id.uuidString])
        }
    }

    private func coachDecisionJSON(gaps: [String], refs: [String]) throws -> String {
        let response: [String: Any] = ["phase": "fill_evidence_gap", "readiness": "not_ready",
            "recommended_move": "surface_evidence_gap", "training_dimension": "evidence_discipline",
            "recommended_lens_id": "evidenceCheck", "reason": "已有超时观察，权限限制仍未知；可以先保留这个未知。",
            "open_evidence_gaps": gaps, "source_refs": refs, "confidence": 0.84]
        return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
    }

    private final class RecordingCoachDecisionClient: LLMClient {
        let response: String
        var requests: [LLMRequest] = []
        init(response: String) { self.response = response }
        func complete(_ request: LLMRequest) async throws -> Data {
            requests.append(request)
            return Data(response.utf8)
        }
    }

    func testCoachAnswerReviewUsesCentralModelAndCurrentMatterReferences() async throws {
        let caseId = UUID()
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人没有确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "会议纪要没有负责人。")
        let client = GuidanceFixtureLLMClient(response: coachAnswerReviewJSON(refs: [card.id.uuidString, question.id.uuidString]))

        let result = try await CoachAnswerReviewAIService(
            promptProvider: LocalPromptProvider(), llmClient: client
        ).review(context: coachAnswerReviewContext(caseId: caseId, card: card, question: question))

        XCTAssertEqual(result.turn.readiness, .notReady)
        XCTAssertEqual(result.feedback.nextRepairQuestion, "哪条记录能直接核对这个判断？")
        XCTAssertEqual(client.promptIDs, [.reviewCoachAnswer])
    }

    func testCoachAnswerReviewReadyAllowsEmptyRepairQuestion() async throws {
        let caseId = UUID()
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人已确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "负责人在会议纪要中确认了交付时间。")
        let refs = [card.id.uuidString, question.id.uuidString].map { "\"\($0)\"" }.joined(separator: ",")
        let client = GuidanceFixtureLLMClient(response: """
        {"readiness":"ready","recommended_move":"generate_quest","open_evidence_gaps":[],"reason":"回答给出了可核对事实，可以进入一个可观察的验证行动。","turn_summary":"证据缺口已闭合。","coach_critique":"这次回答把判断和来源连起来了。","repaired_material":"会议纪要中的负责人确认。","missing_material":"当前材料已足以设计明日验证。","proceed_line":"可以设计明日验证。","ability_gap":"把判断和事实连起来。","training_output":"留下一个可观察的验证信号。","self_check":"别人能找到你引用的事实。","training_target":"证据纪律。","next_repair_question":"","experience_replay_decision":"比较旧经验条件。","experience_replay_prompt":"旧经验的哪个条件不同？","judgment_sentence_prompt":"基于「事实」，我暂时判断「……」。","reference_suggestion":"","reference_example":"","source_refs":[\(refs)]}
        """)

        let result = try await CoachAnswerReviewAIService(
            promptProvider: LocalPromptProvider(), llmClient: client
        ).review(context: coachAnswerReviewContext(caseId: caseId, card: card, question: question))

        XCTAssertEqual(result.turn.readiness, .ready)
        XCTAssertTrue(result.feedback.canProceedToValidation)
        XCTAssertTrue(result.feedback.nextRepairQuestion.isEmpty)
        XCTAssertTrue(result.feedback.teachingPlan.repairQuestion.isEmpty)
    }

    func testCoachAnswerReviewRejectsReadyWithRepairQuestion() async throws {
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人已确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "负责人已确认。")
        let response = coachAnswerReviewJSON(refs: [card.id.uuidString, question.id.uuidString])
            .replacingOccurrences(of: "\"readiness\":\"not_ready\"", with: "\"readiness\":\"ready\"")
            .replacingOccurrences(of: "\"recommended_move\":\"surface_evidence_gap\"", with: "\"recommended_move\":\"generate_quest\"")
            .replacingOccurrences(of: "\"open_evidence_gaps\":[\"missing_observation\"]", with: "\"open_evidence_gaps\":[]")
        let client = GuidanceFixtureLLMClient(response: response)

        do {
            _ = try await CoachAnswerReviewAIService(
                promptProvider: LocalPromptProvider(), llmClient: client
            ).review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
            XCTFail("Expected ready response with a repair question to be rejected")
        } catch {
            XCTAssertTrue(error is TodayAIParsingError)
        }
    }

    func testCoachAnswerReviewRejectsMultipleOpenEvidenceGaps() async throws {
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人没有确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "会议纪要没有负责人。")
        let response = coachAnswerReviewJSON(refs: [card.id.uuidString, question.id.uuidString])
            .replacingOccurrences(
                of: "\"open_evidence_gaps\":[\"missing_observation\"]",
                with: "\"open_evidence_gaps\":[\"missing_observation\",\"missing_baseline\"]"
            )
        let client = GuidanceFixtureLLMClient(response: response)

        do {
            _ = try await CoachAnswerReviewAIService(
                promptProvider: LocalPromptProvider(), llmClient: client
            ).review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
            XCTFail("Expected multiple open evidence gaps to be rejected")
        } catch {
            XCTAssertEqual(
                error as? TodayAIParsingError,
                .qualityGateFailed(["回答复盘只能保留一个最重要的证据缺口。"])
            )
        }
    }

    func testCoachAnswerReviewStopsWhenUserExplicitlyDeclinesRepairQuestion() async throws {
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人没有确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "我现在不知道，也不想继续回答了。")
        let response = try reviewJSONWithEmptyOptionalGuidance(
            coachAnswerReviewJSON(refs: [card.id.uuidString, question.id.uuidString], userBoundary: "stop"))
        let client = GuidanceFixtureLLMClient(response: response)

        let result = try await CoachAnswerReviewAIService(
            promptProvider: LocalPromptProvider(), llmClient: client
        ).review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))

        XCTAssertEqual(result.turn.readiness, .notReady)
        XCTAssertTrue(result.feedback.nextRepairQuestion.isEmpty)
        XCTAssertFalse(result.feedback.canProceedToValidation)
        XCTAssertTrue(result.feedback.experienceReplayPrompt.isEmpty,
            "An intentionally empty prompt must not become a local recall task")
        XCTAssertTrue(result.feedback.judgmentSentencePrompt.isEmpty)
        XCTAssertTrue(result.feedback.teachingPlan.experienceReplayPrompt.isEmpty)
        XCTAssertNil(result.referenceSuggestion)
        XCTAssertTrue(result.feedback.hasStopped)
        let encoded = try JSONEncoder().encode(result.feedback)
        XCTAssertTrue(try JSONDecoder().decode(CoachAnswerTrainingFeedback.self, from: encoded).hasStopped)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "userBoundary")
        let old = try JSONDecoder().decode(CoachAnswerTrainingFeedback.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(old.userBoundary)
        XCTAssertFalse(old.hasStopped)
    }

    private func reviewJSONWithEmptyOptionalGuidance(_ response: String) throws -> String {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
        for field in ["next_repair_question", "experience_replay_prompt", "judgment_sentence_prompt", "reference_suggestion", "reference_example"] {
            object[field] = ""
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    func testCoachAnswerReviewRejectsAlternateAssignmentsAfterStop() async throws {
        let card = ThinkingCard(type: .fact, title: "事实", body: "仅一次未完成。", isConfirmed: true)
        let question = ReflectionQuestion(question: "看到什么？", whyItMatters: "区分原因。", answer: "不记得了，先不继续。")
        let stopped = try reviewJSONWithEmptyOptionalGuidance(coachAnswerReviewJSON(refs: [question.id.uuidString], userBoundary: "stop"))
        for field in ["experience_replay_prompt", "judgment_sentence_prompt", "reference_suggestion", "reference_example"] {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stopped.utf8)) as? [String: Any])
            object[field] = "再回想一次，然后补写一条判断。"
            let response = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
            do {
                _ = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(),
                    llmClient: GuidanceFixtureLLMClient(response: response)).review(
                        context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
                XCTFail("Stopped review must reject a disguised assignment in \(field)")
            } catch {
                XCTAssertEqual(error as? TodayAIParsingError,
                    .qualityGateFailed(["用户已停止回答时不得通过其他提示继续安排练习。"]))
            }
        }
    }

    func testCoachAnswerReviewRejectsRepairQuestionWhenUserBoundaryIsStop() async throws {
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人没有确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "不想继续回答了。")
        for readiness in ["not_ready", "partially_ready", "ready"] {
            var response = coachAnswerReviewJSON(refs: [question.id.uuidString], userBoundary: "stop")
                .replacingOccurrences(of: "\"readiness\":\"not_ready\"", with: "\"readiness\":\"\(readiness)\"")
            if readiness == "ready" {
                response = response.replacingOccurrences(of: "\"open_evidence_gaps\":[\"missing_observation\"]", with: "\"open_evidence_gaps\":[]")
            }
            do {
                _ = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(),
                    llmClient: GuidanceFixtureLLMClient(response: response))
                    .review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
                XCTFail("A stopped \(readiness) review must not ask another question")
            } catch {
                XCTAssertEqual(error as? TodayAIParsingError,
                    .qualityGateFailed(["用户已停止回答时不得制造额外追问。"]))
            }
        }
    }

    func testCoachAnswerReviewRejectsMatterIdentityAsEvidenceEvenAlongsideValidAnswer() async throws {
        let caseId = UUID()
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人没有确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "会议纪要没有负责人。")
        for refs in [[caseId.uuidString], [question.id.uuidString, caseId.uuidString]] {
            let client = GuidanceFixtureLLMClient(response: coachAnswerReviewJSON(refs: refs))
            do {
                _ = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .review(context: coachAnswerReviewContext(caseId: caseId, card: card, question: question))
                XCTFail("The matter ID is routing context, not card or answer evidence")
            } catch {
                XCTAssertEqual(error as? TodayAIParsingError,
                    .qualityGateFailed(["回答复盘只能引用当前事项的卡片和回答。"]))
            }
        }
    }

    func testCoachAnswerReviewCanKeepUncertaintyWithoutAnotherQuestionOrStopClaim() async throws {
        let card = ThinkingCard(type: .fact, title: "报告晚交两天", body: "只知道晚交，原因未知。", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪些是观察，哪些是推测？", whyItMatters: "分开事实和动机。", answer: "晚交是事实，故意是推测；我现在已能分开这两点。")
        for readiness in ["not_ready", "partially_ready"] {
            let response = try reviewJSONWithEmptyOptionalGuidance(
                coachAnswerReviewJSON(refs: [question.id.uuidString], userBoundary: "continue"))
                .replacingOccurrences(of: "\"readiness\":\"not_ready\"", with: "\"readiness\":\"\(readiness)\"")
            let client = GuidanceFixtureLLMClient(response: response)
            let result = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                .review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
            XCTAssertEqual(result.turn.readiness.rawValue, readiness)
            XCTAssertEqual(result.turn.openEvidenceGaps, [.missingObservation])
            XCTAssertFalse(result.feedback.canProceedToValidation)
            XCTAssertFalse(result.feedback.hasStopped, "No useful follow-up must not be mislabeled as user refusal")
            XCTAssertTrue(result.feedback.nextRepairQuestion.isEmpty)
            XCTAssertEqual(client.promptIDs, [.reviewCoachAnswer])
        }
    }

    func testCoachAnswerReviewRejectsClarificationMoveWithoutActualQuestion() async throws {
        let card = ThinkingCard(type: .fact, title: "晚交", body: "原因未知。", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪些是观察？", whyItMatters: "区分原因。", answer: "晚交是观察。")
        let response = try reviewJSONWithEmptyOptionalGuidance(coachAnswerReviewJSON(refs: [question.id.uuidString]))
            .replacingOccurrences(of: "surface_evidence_gap", with: "ask_clarifying_question")
        do {
            _ = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: GuidanceFixtureLLMClient(response: response))
                .review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
            XCTFail("An empty question must not be presented as a clarification request")
        } catch { XCTAssertTrue(error is TodayAIParsingError) }
    }

    func testCoachAnswerReviewDoesNotInventTrainingStandardsInEmptyModelFields() async throws {
        let card = ThinkingCard(type: .fact, title: "报告晚交两天", body: "原因未知。", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪些是推测？", whyItMatters: "保留边界。", answer: "故意是推测。")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(coachAnswerReviewJSON(refs: [question.id.uuidString]).utf8)) as? [String: Any])
        for field in ["ability_gap", "training_output", "self_check", "training_target", "experience_replay_decision", "experience_replay_prompt", "judgment_sentence_prompt", "reference_suggestion", "reference_example", "repaired_material"] { object[field] = "" }
        let response = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        let result = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: GuidanceFixtureLLMClient(response: response))
            .review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
        XCTAssertTrue([result.feedback.abilityGapLine, result.feedback.trainingOutputLine,
            result.feedback.selfCheckLine, result.feedback.trainingTargetLine,
            result.feedback.experienceReplayDecisionLine, result.feedback.repairedLine,
            result.feedback.teachingPlan.trainingTargetTitle, result.feedback.teachingPlan.proceedStandard].allSatisfy { $0.isEmpty })
        XCTAssertNil(result.referenceSuggestion)
    }

    func testCoachAnswerReviewRejectsReferencesOutsideCurrentMatter() async throws {
        let card = ThinkingCard(type: .fact, title: "事实", body: "负责人没有确认", isConfirmed: true)
        let question = ReflectionQuestion(question: "哪个事实支持判断？", whyItMatters: "补齐证据。", answer: "会议纪要没有负责人。")
        let client = GuidanceFixtureLLMClient(response: coachAnswerReviewJSON(refs: [UUID().uuidString]))

        do {
            _ = try await CoachAnswerReviewAIService(
                promptProvider: LocalPromptProvider(), llmClient: client
            ).review(context: coachAnswerReviewContext(caseId: UUID(), card: card, question: question))
            XCTFail("Expected cross-matter source references to be rejected")
        } catch {
            XCTAssertTrue(error is TodayAIParsingError)
        }
    }

    func testSideQuestPolicyRequiresExplicitOptIn() {
        let policy = SideQuestOfferPolicy()
        let enabledCategories: Set<SideQuestCategory> = [.making]

        let notOptedIn = SideQuestOfferContext(
            isEnabled: false,
            enabledCategories: enabledCategories
        )
        XCTAssertTrue(policy.candidates(for: notOptedIn).isEmpty)
    }

    func testSideQuestPreferenceRequiresFirstUseConsent() {
        let preference = SideQuestPreference()

        XCTAssertFalse(preference.isEnabled)
        XCTAssertEqual(preference.consentStatus, .notAsked)
        XCTAssertEqual(preference.enabledCategories, Set(SideQuestCategory.allCases))
        XCTAssertFalse(preference.notificationsEnabled)
        XCTAssertNil(preference.notificationSchedule)
    }

    func testSideQuestPolicyIsCategoryScopedAndStableForOneDay() {
        let noon = Date(timeIntervalSince1970: 1_767_355_200)
        let policy = SideQuestOfferPolicy()
        let recentlyOffered = try! XCTUnwrap(
            BuiltinSideQuestCatalog.items.first { $0.id == "making.ten-minute-artifact" }
        )
        let context = SideQuestOfferContext(
            isEnabled: true,
            enabledCategories: [.making],
            offerHistory: [recentlyOffered.id: noon],
            now: noon
        )

        let candidates = policy.candidates(for: context)
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.allSatisfy { $0.category == .making })
        XCTAssertFalse(candidates.contains { $0.id == recentlyOffered.id })
        XCTAssertEqual(
            policy.shouldSurface(for: context),
            policy.shouldSurface(for: context)
        )
    }

    func testSideQuestRewardsExperienceWithoutPenaltyPath() {
        let item = try! XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.category == .vitality })
        XCTAssertEqual(item.completionReward.track, .vitality)
        XCTAssertGreaterThan(item.completionReward.completionExperience, 0)
        XCTAssertGreaterThan(item.completionReward.reflectionBonusExperience, 0)
    }

    func testSideQuestFoundationPersistsExplicitPreferencesAndAwardsExperienceOnce() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let preference = SideQuestPreference(
            isEnabled: true,
            enabledCategories: [.making, .vitality],
            frequency: .rare,
            notificationsEnabled: true,
            notificationSchedule: SideQuestNotificationSchedule(startMinute: 600, endMinute: 1_260),
            rotationSeed: "fixture-seed"
        )
        try await repository.savePreference(preference)

        let storedPreference = try await repository.preference()
        XCTAssertTrue(storedPreference.isEnabled)
        XCTAssertEqual(storedPreference.enabledCategories, [.making, .vitality])
        XCTAssertEqual(storedPreference.frequency, .rare)
        XCTAssertEqual(storedPreference.notificationSchedule, preference.notificationSchedule)

        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.id == "making.ten-minute-artifact" })
        let offeredAt = Date(timeIntervalSince1970: 1_767_355_200)
        let run = SideQuestRun.offered(from: item, at: offeredAt)
        try await repository.offer(run)
        let openRun = try await repository.openRun()
        XCTAssertEqual(openRun?.id, run.id)

        let accepted = try await repository.accept(runId: run.id, at: offeredAt.addingTimeInterval(60))
        XCTAssertEqual(accepted.status, .accepted)
        let event = try await repository.complete(
            runId: run.id,
            reflection: "我真的做出了一个可见的小版本。",
            at: offeredAt.addingTimeInterval(120)
        )
        XCTAssertEqual(event.track, item.completionReward.track)
        XCTAssertEqual(event.completionExperience, item.completionReward.completionExperience)
        XCTAssertEqual(event.reflectionBonusExperience, item.completionReward.reflectionBonusExperience)
        XCTAssertGreaterThan(event.totalExperience, event.completionExperience)
        let completedRun = try await repository.run(id: run.id)
        XCTAssertEqual(completedRun?.status, .completed)

        let repeatedEvent = try await repository.complete(runId: run.id, reflection: nil, at: offeredAt.addingTimeInterval(180))
        XCTAssertEqual(repeatedEvent.id, event.id)

        let events = try await repository.experienceEvents(limit: 10)
        XCTAssertEqual(events.map(\.sideQuestRunId), [run.id])
        let metricCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM metric_contributions")
        }
        XCTAssertEqual(metricCount, 0)
    }

    func testSideQuestDatesReadLegacyMillisecondsAndTimeZoneOffsets() async throws {
        let timestamp = "2026-10-03T01:02:03.125Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedDate = try XCTUnwrap(formatter.date(from: timestamp))
        let repository = SQLiteSideQuestRepository(database: database)
        let run = SideQuestRun.offered(from: try XCTUnwrap(BuiltinSideQuestCatalog.items.first), at: expectedDate)
        try await repository.offer(run)
        let storedTimestamp = try await database.dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT offered_at FROM side_quest_runs WHERE id = ?", arguments: [run.id.uuidString])
        }
        XCTAssertEqual(storedTimestamp, timestamp)

        try await database.dbQueue.write { db in
            try db.execute(sql: "UPDATE side_quest_runs SET offered_at = ?, updated_at = ? WHERE id = ?",
                           arguments: [timestamp, "2026-10-03T09:02:03.125+08:00", run.id.uuidString])
        }
        let storedRun = try await repository.run(id: run.id)
        let loaded = try XCTUnwrap(storedRun)
        XCTAssertEqual(loaded.offeredAt.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 0.000001)
        XCTAssertEqual(loaded.updatedAt.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 0.000001)
    }

    func testSideQuestPhotoMemoryRoundTripsAndCanBeMarkedUnavailable() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let run = SideQuestRun.offered(from: try XCTUnwrap(BuiltinSideQuestCatalog.items.first))
        try await repository.offer(run)
        let createdAt = Date(timeIntervalSince1970: 1_767_355_320)
        let memory = SideQuestPhotoMemory(
            assetLocalIdentifier: "A1B2C3/L0/001",
            runId: run.id,
            createdAt: createdAt
        )

        try await repository.savePhotoMemory(memory)
        let persistedMemories = try await repository.photoMemories(for: run.id)
        XCTAssertEqual(persistedMemories, [memory])

        try await repository.markPhotoMemoryUnavailable(id: memory.id)
        let unavailableMemories = try await repository.photoMemories(for: run.id)
        let stored = try XCTUnwrap(unavailableMemories.first)
        XCTAssertEqual(stored.id, memory.id)
        XCTAssertEqual(stored.assetLocalIdentifier, memory.assetLocalIdentifier)
        XCTAssertEqual(stored.createdAt, createdAt)
        XCTAssertTrue(stored.unavailable)

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["side_quest_photo_memories"], 1)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: export.data) as? [String: Any])
        let sections = try XCTUnwrap(payload["sections"] as? [String: Any])
        let memories = try XCTUnwrap(sections["side_quest_photo_memories"] as? [[String: Any]])
        let exportedMemory = try XCTUnwrap(memories.first)
        XCTAssertEqual(exportedMemory["asset_local_identifier"] as? String, memory.assetLocalIdentifier)
        XCTAssertEqual(
            Set(exportedMemory.keys),
            ["id", "asset_local_identifier", "run_id", "created_at", "unavailable"]
        )
    }

    func testSideQuestPhotoMemoryCodableRoundTrip() throws {
        let memory = SideQuestPhotoMemory(
            assetLocalIdentifier: "A1B2C3/L0/001",
            runId: UUID(uuidString: "B0D9F832-0F59-4BE6-8828-F3307B0A35C9")!,
            createdAt: Date(timeIntervalSince1970: 1_767_355_320),
            unavailable: true
        )
        let decoded = try JSONDecoder().decode(
            SideQuestPhotoMemory.self,
            from: JSONEncoder().encode(memory)
        )
        XCTAssertEqual(decoded, memory)
    }

    func testSideQuestLifeContextProfilePersistsAndExportsUserProvidedValues() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let profile = SideQuestLifeContextProfile(
            homeLabel: "家附近",
            workLabel: "办公室附近",
            homePracticalContext: .init(floorLevel: 12, stairsAvailable: true),
            workplacePracticalContext: .init(floorLevel: 8, stairsAvailable: false),
            transitionWindows: [.afterLunch, .leavingWork],
            commuteModes: [.walking, .publicTransit],
            preferredActivityRadius: .nearby,
            movementPreferences: [.gentle, .quiet],
            unavailableCategories: [.vitality],
            constraints: ["不安排需要消费的活动", "不晚于傍晚"]
        )
        try await repository.saveLifeContextProfile(profile)

        let stored = try await repository.lifeContextProfile()
        XCTAssertEqual(stored.homeLabel, "家附近")
        XCTAssertEqual(stored.workLabel, "办公室附近")
        XCTAssertEqual(stored.homePracticalContext, .init(floorLevel: 12, stairsAvailable: true))
        XCTAssertEqual(stored.workplacePracticalContext, .init(floorLevel: 8, stairsAvailable: false))
        XCTAssertEqual(stored.transitionWindows, [.afterLunch, .leavingWork])
        XCTAssertEqual(stored.commuteModes, [.walking, .publicTransit])
        XCTAssertEqual(stored.preferredActivityRadius, .nearby)
        XCTAssertEqual(stored.movementPreferences, [.gentle, .quiet])
        XCTAssertEqual(stored.unavailableCategories, [.vitality])
        XCTAssertEqual(stored.constraints, profile.constraints)

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["side_quest_life_context_profiles"], 1)
    }

    func testLegacySideQuestFloorCountRemainsAvailableLocallyAfterPracticalContextMigration() async throws {
        let createdAt = "2026-01-01T00:00:00.000Z"
        try await database.dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO side_quest_life_context_profiles (
                    id, home_label, work_label, floor_count, commute_modes_json,
                    movement_preferences_json, unavailable_categories_json, constraints_json,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, '[]', '[]', '[]', '[]', ?, ?)
                """, arguments: [
                    SideQuestLifeContextProfile.primaryID,
                    "旧家的称呼",
                    "旧工作的称呼",
                    12,
                    createdAt,
                    createdAt
                ])
        }

        let profile = try await SQLiteSideQuestRepository(database: database).lifeContextProfile()
        XCTAssertEqual(profile.legacyFloorCount, 12)
        XCTAssertEqual(profile.homePracticalContext, .init())
        XCTAssertEqual(profile.workplacePracticalContext, .init())

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["side_quest_life_context_profiles"], 1)
        let retainedFloor = try await database.dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT floor_count FROM side_quest_life_context_profiles WHERE id = ?",
                arguments: [SideQuestLifeContextProfile.primaryID]
            )
        }
        XCTAssertEqual(retainedFloor, 12)
    }

    func testSideQuestDeclineHasNoPenaltyAndPreventsRepeatedOpenOffers() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let first = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.id == "self-care.leave-a-clear-ending" })
        let second = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.id == "vitality.gentle-movement" })
        let now = Date(timeIntervalSince1970: 1_767_355_200)
        let firstRun = SideQuestRun.offered(from: first, at: now)
        try await repository.offer(firstRun)

        do {
            try await repository.offer(SideQuestRun.offered(from: second, at: now))
            XCTFail("An unresolved invitation must not be joined by another one")
        } catch {}

        let declined = try await repository.decline(runId: firstRun.id, at: now.addingTimeInterval(60))
        XCTAssertEqual(declined.status, .declined)
        let declinedExperience = try await repository.experience(for: firstRun.id)
        let remainingOpenRun = try await repository.openRun()
        XCTAssertNil(declinedExperience)
        XCTAssertNil(remainingOpenRun)

        let secondRun = SideQuestRun.offered(from: second, at: now.addingTimeInterval(120))
        try await repository.offer(secondRun)
        let history = try await repository.offerHistory()
        XCTAssertEqual(history[first.id]?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(history[second.id]?.timeIntervalSince1970 ?? 0, now.addingTimeInterval(120).timeIntervalSince1970, accuracy: 0.01)
    }

    func testSideQuestCorrectionResolvesOpenRunPersistsAndExportsEvent() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.category == .making })
        let offeredAt = Date(timeIntervalSince1970: 1_767_355_200)
        let run = SideQuestRun.offered(from: item, at: offeredAt)
        try await repository.offer(run)

        let correction = SideQuestCorrectionEvent(
            sideQuestRunId: run.id,
            kind: .wrongJudgment,
            note: "这条邀请不符合我现在的真实情况。",
            occurredAt: offeredAt.addingTimeInterval(60)
        )
        try await repository.saveCorrection(correction, resolvingRunId: run.id)

        let resolvedRun = try await repository.run(id: run.id)
        XCTAssertEqual(resolvedRun?.status, .declined)
        let openRun = try await repository.openRun()
        XCTAssertNil(openRun)

        let savedCorrections = try await repository.recentCorrections(limit: 10)
        XCTAssertEqual(savedCorrections, [correction])

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["side_quest_correction_events"], 1)
        XCTAssertTrue(String(decoding: export.data, as: UTF8.self).contains("side_quest_correction_events"))
    }

    func testSideQuestTrialMetricsUsesInclusiveWindowAndExcludesCorrectionsOutsideIt() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.category == .making })
        let start = Date(timeIntervalSince1970: 1_767_355_200)
        let end = start.addingTimeInterval(7 * 86_400)

        let completedRun = SideQuestRun.offered(from: item, at: start)
        try await repository.offer(completedRun)
        _ = try await repository.accept(runId: completedRun.id, at: start.addingTimeInterval(60))
        _ = try await repository.complete(runId: completedRun.id, reflection: "留下了一条观察", at: start.addingTimeInterval(120))

        let declinedRun = SideQuestRun.offered(from: item, at: start.addingTimeInterval(86_400))
        try await repository.offer(declinedRun)
        _ = try await repository.decline(runId: declinedRun.id, at: declinedRun.offeredAt.addingTimeInterval(60))

        let acceptedRun = SideQuestRun.offered(from: item, at: end)
        try await repository.offer(acceptedRun)
        _ = try await repository.accept(runId: acceptedRun.id, at: end)

        try await repository.saveCorrection(
            SideQuestCorrectionEvent(kind: .wrongJudgment, occurredAt: start),
            resolvingRunId: nil
        )
        try await repository.saveCorrection(
            SideQuestCorrectionEvent(kind: .inconvenientNow, occurredAt: start.addingTimeInterval(-1)),
            resolvingRunId: nil
        )
        try await repository.saveCorrection(
            SideQuestCorrectionEvent(kind: .notHere, occurredAt: end.addingTimeInterval(1)),
            resolvingRunId: nil
        )

        let metrics = try await repository.trialMetrics(since: start, through: end)

        XCTAssertEqual(metrics.offers, 3)
        XCTAssertEqual(metrics.accepted, 2)
        XCTAssertEqual(metrics.completed, 1)
        XCTAssertEqual(metrics.declined, 1)
        XCTAssertEqual(metrics.correctionsByKind, [.wrongJudgment: 1])
        XCTAssertEqual(metrics.acceptanceRate, 2.0 / 3.0, accuracy: 0.000_1)
        XCTAssertEqual(metrics.completionRate, 1.0 / 3.0, accuracy: 0.000_1)
    }

    func testSideQuestTrialMetricsCountsAcceptedStatusesOnlyWhenAcceptedAtExists() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.category == .vitality })
        let start = Date(timeIntervalSince1970: 1_767_355_200)
        let end = start.addingTimeInterval(7 * 86_400)

        let completedRun = SideQuestRun.offered(from: item, at: start)
        try await repository.offer(completedRun)
        _ = try await repository.accept(runId: completedRun.id, at: start.addingTimeInterval(60))
        _ = try await repository.complete(runId: completedRun.id, reflection: nil, at: start.addingTimeInterval(120))

        let deferredRun = SideQuestRun.offered(from: item, at: start.addingTimeInterval(86_400))
        try await repository.offer(deferredRun)
        _ = try await repository.accept(runId: deferredRun.id, at: deferredRun.offeredAt.addingTimeInterval(60))
        _ = try await repository.deferRun(
            runId: deferredRun.id,
            until: deferredRun.offeredAt.addingTimeInterval(172_800),
            at: deferredRun.offeredAt.addingTimeInterval(120)
        )

        var metrics = try await repository.trialMetrics(since: start, through: end)
        XCTAssertEqual(metrics.accepted, 2)

        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE side_quest_runs SET accepted_at = NULL WHERE id = ?",
                arguments: [deferredRun.id.uuidString]
            )
        }

        metrics = try await repository.trialMetrics(since: start, through: end)
        XCTAssertEqual(metrics.accepted, 1)
        XCTAssertEqual(metrics.completed, 1)
        XCTAssertEqual(metrics.acceptanceRate, 0.5, accuracy: 0.000_1)
    }

    func testSideQuestPlanningAuditTracksHoldAndOfferInTrialMetricsAndExport() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let promptRepository = SQLitePromptRunRepository(database: database)
        let start = Date(timeIntervalSince1970: 1_767_355_200)
        let end = start.addingTimeInterval(7 * 86_400)

        var holdPreference = SideQuestPreference(isEnabled: true, enabledCategories: [.making])
        let holdPrompt = PromptRun(
            promptId: PromptID.generateSideQuest.rawValue,
            promptVersion: "test.v1",
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "test",
            sessionMode: SessionMode.standard.rawValue,
            requestSummary: "hold fixture",
            createdAt: start
        )
        try await promptRepository.savePromptRun(holdPrompt)
        holdPreference.lastAIPlanningAt = start
        holdPreference.lastAIPlanningPromptRunId = holdPrompt.id
        _ = try await repository.recordPlanningResult(
            preference: holdPreference,
            planningRecord: SideQuestPlanningRecord(
                dayKey: SideQuestPlanningRecord.dayKey(for: start),
                decision: .hold,
                promptRunId: holdPrompt.id,
                plannedAt: start
            ),
            offeredRun: nil
        )

        let offerDate = start.addingTimeInterval(86_400)
        let offerPrompt = PromptRun(
            promptId: PromptID.generateSideQuest.rawValue,
            promptVersion: "test.v1",
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "test",
            sessionMode: SessionMode.standard.rawValue,
            requestSummary: "offer fixture",
            createdAt: offerDate
        )
        try await promptRepository.savePromptRun(offerPrompt)
        var offerPreference = holdPreference
        offerPreference.lastAIPlanningAt = offerDate
        offerPreference.lastAIPlanningPromptRunId = offerPrompt.id
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.category == .making })
        var offeredRun = SideQuestRun.offered(from: item, at: offerDate)
        offeredRun.origin = .aiGenerated
        offeredRun.promptRunId = offerPrompt.id
        offeredRun.decisionRationale = "今天适合一件轻量体验。"
        _ = try await repository.recordPlanningResult(
            preference: offerPreference,
            planningRecord: SideQuestPlanningRecord(
                dayKey: SideQuestPlanningRecord.dayKey(for: offerDate),
                decision: .offer,
                promptRunId: offerPrompt.id,
                plannedAt: offerDate
            ),
            offeredRun: offeredRun
        )

        let metrics = try await repository.trialMetrics(since: start, through: end)
        XCTAssertEqual(metrics.planningDecisions, 2)
        XCTAssertEqual(metrics.holds, 1)
        XCTAssertEqual(metrics.offers, 1)
        XCTAssertEqual(metrics.holdRate, 0.5, accuracy: 0.000_1)

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["side_quest_planning_records"], 2)
        XCTAssertTrue(String(decoding: export.data, as: UTF8.self).contains("side_quest_planning_records"))
    }

    func testSideQuestPlanningTransactionRollsBackAuditAndPreferenceWhenOfferCannotBeSaved() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first { $0.category == .making })
        let now = Date(timeIntervalSince1970: 1_767_355_200)
        try await repository.offer(SideQuestRun.offered(from: item, at: now.addingTimeInterval(-60)))

        var preference = SideQuestPreference(isEnabled: true, enabledCategories: [.making])
        let promptRunID = UUID()
        preference.lastAIPlanningAt = now
        preference.lastAIPlanningPromptRunId = promptRunID
        var secondRun = SideQuestRun.offered(from: item, at: now)
        secondRun.origin = .aiGenerated
        secondRun.promptRunId = promptRunID
        secondRun.decisionRationale = "会被打开邀请约束拒绝。"

        do {
            _ = try await repository.recordPlanningResult(
                preference: preference,
                planningRecord: SideQuestPlanningRecord(
                    dayKey: SideQuestPlanningRecord.dayKey(for: now),
                    decision: .offer,
                    promptRunId: promptRunID,
                    plannedAt: now
                ),
                offeredRun: secondRun
            )
            XCTFail("Expected the second unresolved invitation to reject the transaction")
        } catch {}

        let persistedPreference = try await repository.preference()
        XCTAssertNil(persistedPreference.lastAIPlanningAt)
        let metrics = try await repository.trialMetrics(since: now.addingTimeInterval(-86_400), through: now.addingTimeInterval(86_400))
        XCTAssertEqual(metrics.planningDecisions, 0)
        XCTAssertEqual(metrics.offers, 1)
    }

    func testSideQuestPlanningResultIsIdempotentForOneDay() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let now = Date(timeIntervalSince1970: 1_767_355_200)
        let dayKey = SideQuestPlanningRecord.dayKey(for: now)
        let firstPromptRunID = UUID()
        let secondPromptRunID = UUID()
        var firstPreference = SideQuestPreference(isEnabled: true, enabledCategories: [.making])
        firstPreference.lastAIPlanningAt = now
        firstPreference.lastAIPlanningPromptRunId = firstPromptRunID

        let didRecordFirstResult = try await repository.recordPlanningResult(
            preference: firstPreference,
            planningRecord: SideQuestPlanningRecord(
                dayKey: dayKey,
                decision: .hold,
                promptRunId: firstPromptRunID,
                plannedAt: now
            ),
            offeredRun: nil
        )
        XCTAssertTrue(didRecordFirstResult)

        var duplicatePreference = firstPreference
        duplicatePreference.lastAIPlanningPromptRunId = secondPromptRunID
        let didRecordDuplicateResult = try await repository.recordPlanningResult(
            preference: duplicatePreference,
            planningRecord: SideQuestPlanningRecord(
                dayKey: dayKey,
                decision: .hold,
                promptRunId: secondPromptRunID,
                plannedAt: now.addingTimeInterval(60)
            ),
            offeredRun: nil
        )
        XCTAssertFalse(didRecordDuplicateResult)

        let storedPreference = try await repository.preference()
        let storedPlanningRecord = try await repository.planningRecord(forDayKey: dayKey)
        XCTAssertEqual(storedPreference.lastAIPlanningPromptRunId, firstPromptRunID)
        XCTAssertEqual(storedPlanningRecord?.promptRunId, firstPromptRunID)
        let metrics = try await repository.trialMetrics(
            since: now.addingTimeInterval(-86_400),
            through: now.addingTimeInterval(86_400)
        )
        XCTAssertEqual(metrics.planningDecisions, 1)
    }

    func testMigrationV39CreatesSideQuestTablesAndExportIncludesTheirRecords() async throws {
        let queue = try DatabaseQueue()
        let legacyDatabase = try AppDatabase(dbQueue: queue, includesVNextMigrations: false)
        try await SQLiteDailyEntryRepository(database: legacyDatabase).saveDraft(DailyEntryDraft(rawText: "Legacy fixture"))
        try AppDatabase.makeMigrator().migrate(queue)
        let migratedDatabase = try AppDatabase(dbQueue: queue)
        let repository = SQLiteSideQuestRepository(database: migratedDatabase)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first)
        let run = SideQuestRun.offered(from: item)
        try await repository.offer(run)
        _ = try await repository.accept(runId: run.id, at: .now)
        _ = try await repository.complete(runId: run.id, reflection: nil, at: .now)

        let export = try await SQLiteDataExportRepository(database: migratedDatabase).exportPackage()
        XCTAssertEqual(export.counts["side_quest_preferences"], 0)
        XCTAssertEqual(export.counts["side_quest_runs"], 1)
        XCTAssertEqual(export.counts["side_quest_experience_events"], 1)
        try await migratedDatabase.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("side_quest_preferences"))
            XCTAssertTrue(try db.tableExists("side_quest_runs"))
            XCTAssertTrue(try db.tableExists("side_quest_experience_events"))
        }
    }

    func testSideQuestAIPlanRecordsOfferDecisionAndPromptTrace() async throws {
        let preference = SideQuestPreference(
            isEnabled: true,
            enabledCategories: [.making]
        )
        let service = SideQuestAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: MockLLMClient()
        )
        let plan = try await service.plan(for: SideQuestPlanningContext(
            preference: preference,
            lifeContextProfile: SideQuestLifeContextProfile(),
            now: .now,
            rawTodayText: "今天完成了一段工作记录。",
            trainingCases: [],
            recentRuns: [],
            experienceSummary: .empty
        ))

        XCTAssertTrue(plan.shouldOffer)
        let run = try XCTUnwrap(plan.run)
        XCTAssertEqual(run.origin, .aiGenerated)
        XCTAssertEqual(run.promptRunId, plan.promptRunId)
        XCTAssertFalse(run.decisionRationale?.isEmpty == true)
        XCTAssertEqual(run.catalogVersion, "life-orchestrator.v1")
    }

    func testSideQuestPlanningContextSerializesOnlyExplicitLifeContextConstraints() async throws {
        let profile = SideQuestLifeContextProfile(
            homeLabel: "家附近",
            workLabel: "办公室附近",
            homePracticalContext: .init(floorLevel: 8, stairsAvailable: true),
            workplacePracticalContext: .init(floorLevel: 17, stairsAvailable: false),
            transitionWindows: [.afterLunch],
            commuteModes: [.walking],
            preferredActivityRadius: .nearby,
            movementPreferences: [.gentle],
            unavailableCategories: [.vitality],
            constraints: ["不安排需要消费的活动"]
        )
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"hold","reason":"保留今天的自主安排。","grounding_refs":[]}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        _ = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true),
            lifeContextProfile: profile,
            now: .now,
            rawTodayText: "今天有一段工作记录。",
            trainingCases: [],
            recentRuns: [],
            experienceSummary: .empty,
            contextSnapshot: .init(scene: .home, availability: .unknown, knownContext: [], constraints: [])
        ))

        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertTrue(serialized.contains("\"life_context\""))
        XCTAssertTrue(serialized.contains("不安排需要消费的活动"))
        XCTAssertTrue(serialized.contains("\"unavailable_categories\":[\"vitality\"]"))
        XCTAssertTrue(serialized.contains("practical_place_home_floor"))
        XCTAssertTrue(serialized.contains("\"place\":\"home\""))
        XCTAssertFalse(serialized.contains("practical_place_workplace"))
        XCTAssertFalse(serialized.contains("\"place\":\"workplace\""))
        XCTAssertFalse(serialized.contains("家附近"))
        XCTAssertFalse(serialized.contains("办公室附近"))
        XCTAssertFalse(serialized.contains("home_label"))
        XCTAssertFalse(serialized.contains("work_label"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("latitude"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("calendar_event"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("health_sample"))
    }

    func testSideQuestExplorationSeasonMigrationAndOldRunRead() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first)
        let oldRun = SideQuestRun.offered(from: item, at: Date(timeIntervalSince1970: 1_767_355_200))
        try await repository.offer(oldRun)
        let loaded = try await repository.run(id: oldRun.id)
        XCTAssertEqual(loaded?.id, oldRun.id)
        XCTAssertNil(loaded?.seasonId)
        try await database.dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("side_quest_exploration_seasons"))
            let columns = Set(try db.columns(in: "side_quest_runs").map(\.name))
            XCTAssertTrue(columns.contains("season_id"))
            XCTAssertTrue(columns.contains("season_day"))
            XCTAssertTrue(columns.contains("season_step"))
        }
    }

    func testSideQuestExplorationSeasonLifecycleIsIdempotentAndTracksRunProgress() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let start = Date(timeIntervalSince1970: 1_767_355_200)
        let season = try await repository.startSeason(title: "城市漫游", intent: "在熟悉范围内多一点好奇", at: start)
        let repeatedStart = try await repository.startSeason(title: "另一个主题", intent: nil, at: start.addingTimeInterval(60))
        XCTAssertEqual(repeatedStart.id, season.id)

        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first)
        let completedRun = SideQuestRun.offered(from: item, at: start.addingTimeInterval(120))
        try await repository.offer(completedRun)
        let linkedCompletedRun = try await repository.run(id: completedRun.id)
        XCTAssertEqual(linkedCompletedRun?.seasonId, season.id)
        _ = try await repository.accept(runId: completedRun.id, at: start.addingTimeInterval(180))
        _ = try await repository.deferRun(runId: completedRun.id, until: start.addingTimeInterval(3_600), at: start.addingTimeInterval(240))
        _ = try await repository.complete(runId: completedRun.id, reflection: nil, at: start.addingTimeInterval(300))

        let skippedRun = SideQuestRun.offered(from: item, at: start.addingTimeInterval(600))
        try await repository.offer(skippedRun)
        _ = try await repository.decline(runId: skippedRun.id, at: start.addingTimeInterval(660))

        let persistedSeason = try await repository.season(id: season.id)
        let progress = try XCTUnwrap(persistedSeason)
        XCTAssertEqual(progress.acceptedCount, 1)
        XCTAssertEqual(progress.completedCount, 1)
        XCTAssertEqual(progress.skippedCount, 1)

        let endedSeason = try await repository.closeSeason(status: .abandoned, at: start.addingTimeInterval(700))
        let ended = try XCTUnwrap(endedSeason)
        XCTAssertEqual(ended.status, .abandoned)
        let repeatedClose = try await repository.closeSeason(status: .abandoned, at: start.addingTimeInterval(701))
        XCTAssertNil(repeatedClose)
    }

    func testSideQuestPlanningLinksOfferToActiveSeasonButHoldDoesNot() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        let start = Date(timeIntervalSince1970: 1_767_355_200)
        let season = try await repository.startSeason(title: "重新连接", intent: "", at: start)
        let holdPrompt = UUID()
        var holdPreference = SideQuestPreference(isEnabled: true)
        holdPreference.lastAIPlanningAt = start
        holdPreference.lastAIPlanningPromptRunId = holdPrompt
        _ = try await repository.recordPlanningResult(
            preference: holdPreference,
            planningRecord: SideQuestPlanningRecord(dayKey: "2026-01-01", decision: .hold, promptRunId: holdPrompt, plannedAt: start),
            offeredRun: nil
        )
        let heldRun = try await repository.openRun()
        XCTAssertNil(heldRun)
        let item = try XCTUnwrap(BuiltinSideQuestCatalog.items.first)
        let offerPrompt = UUID()
        var offerPreference = SideQuestPreference(isEnabled: true)
        offerPreference.lastAIPlanningAt = start.addingTimeInterval(86_400)
        offerPreference.lastAIPlanningPromptRunId = offerPrompt
        var offer = SideQuestRun.offered(from: item, at: start.addingTimeInterval(86_400))
        offer.origin = .aiGenerated
        offer.promptRunId = offerPrompt
        offer.decisionRationale = "适合一件轻量的重新连接。"
        _ = try await repository.recordPlanningResult(
            preference: offerPreference,
            planningRecord: SideQuestPlanningRecord(dayKey: "2026-01-02", decision: .offer, promptRunId: offerPrompt, plannedAt: start.addingTimeInterval(86_400)),
            offeredRun: offer
        )
        let linkedOffer = try await repository.openRun()
        XCTAssertEqual(linkedOffer?.seasonId, season.id)
    }

    func testSideQuestPlanningContextIncludesSeasonProgressWithoutReflectionContent() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"hold","reason":"这一季今天先保留自主安排。","grounding_refs":[]}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let started = Date(timeIntervalSince1970: 1_767_355_200)
        let season = SideQuestExplorationSeason(title: "城市漫游", intent: "只在熟悉的范围内寻找一点新鲜感", startedAt: started, endsAt: started.addingTimeInterval(30 * 86_400), acceptedCount: 2, completedCount: 1, skippedCount: 1)
        let run = SideQuestRun(
            catalogId: "fixture", catalogVersion: "v1", category: .exploration, title: "已有邀请", invitation: "邀请", evidencePrompt: "观察", prerequisites: [], minimumMinutes: 5, maximumMinutes: 10,
            reward: .init(track: .exploration, completionExperience: 10, reflectionBonusExperience: 0), status: .completed, offeredAt: started, reflection: "PRIVATE_REFLECTION_DO_NOT_SEND", seasonId: season.id
        )
        _ = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true), now: started, rawTodayText: "", trainingCases: [], recentRuns: [run], experienceSummary: .empty, season: season
        ))
        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertTrue(serialized.contains("城市漫游"))
        XCTAssertTrue(serialized.contains("accepted_count"))
        XCTAssertTrue(serialized.contains("category_history"))
        XCTAssertFalse(serialized.contains("PRIVATE_REFLECTION_DO_NOT_SEND"))
    }

    func testSideQuestPromptRequiresThemeContinuityOrHoldForExplorationSeason() {
        let prompt = LocalPromptProvider().template(for: .generateSideQuest, mode: .standard).userText
        XCTAssertTrue(prompt.contains("exploration_season"))
        XCTAssertTrue(prompt.contains("title and optional intent guide an offer"))
        XCTAssertTrue(prompt.contains("category_history"))
        XCTAssertTrue(prompt.contains("return `hold`"))
    }

    func testSideQuestPlanningContextOmitsPracticalPlaceFactsWhenSceneIsUnknown() async throws {
        let profile = SideQuestLifeContextProfile(
            homePracticalContext: .init(floorLevel: 8, stairsAvailable: true),
            workplacePracticalContext: .init(floorLevel: 17, stairsAvailable: true)
        )
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"hold","reason":"保留今天的自主安排。","grounding_refs":[]}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        _ = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true),
            lifeContextProfile: profile,
            now: .now,
            rawTodayText: "",
            trainingCases: [],
            recentRuns: [],
            experienceSummary: .empty,
            contextSnapshot: .empty
        ))

        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertFalse(serialized.contains("practical_place_home"))
        XCTAssertFalse(serialized.contains("practical_place_workplace"))
        XCTAssertFalse(serialized.contains("\"place\":\"home\""))
        XCTAssertFalse(serialized.contains("\"place\":\"workplace\""))
        XCTAssertTrue(serialized.contains("\"practical_places\":[]"))
    }

    func testSideQuestPlanningContextSerializesCorrectionMetadataWithoutNoteContent() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"hold","reason":"今天先保留你的自主安排。","grounding_refs":[]}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let occurredAt = Date(timeIntervalSince1970: 1_767_355_200)
        let privateNote = "PRIVATE_CORRECTION_NOTE_DO_NOT_SEND"
        let correction = SideQuestCorrectionEvent(
            kind: .bodyNotSuitable,
            note: privateNote,
            occurredAt: occurredAt
        )

        _ = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true),
            now: occurredAt,
            rawTodayText: "",
            trainingCases: [],
            recentRuns: [],
            recentCorrections: [correction],
            experienceSummary: .empty
        ))

        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertFalse(serialized.contains(privateNote))
        XCTAssertTrue(serialized.contains("\"kind\":\"body_not_suitable\""))
        XCTAssertTrue(serialized.contains("\"has_note\":true"))
        XCTAssertTrue(serialized.contains("\"occurred_at\":\""))
        XCTAssertFalse(serialized.contains("\"note\":"))
    }

    func testManualSceneOverridesSystemSceneInPlanningContextAndExpiresAtEndOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_767_355_200)
        let manual = SideQuestManualSceneContext.throughEndOfDay(
            scene: .home,
            now: now,
            calendar: calendar
        )
        let systemSnapshot = SideQuestContextSnapshot(
            scene: .work,
            availability: .openWindow,
            knownContext: [],
            constraints: []
        )

        XCTAssertEqual(systemSnapshot.applying(manualScene: manual, now: now).scene, .home)
        XCTAssertEqual(
            systemSnapshot.applying(manualScene: manual, now: manual.expiresAt).scene,
            .work
        )
        XCTAssertEqual(manual.scene.manualSelectionTitle, "在家")
    }

    func testManualSceneSerializesAsCoarseSceneWithoutPlaceData() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"hold","reason":"今天暂时保留你的自主安排。","grounding_refs":[]}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let snapshot = SideQuestContextSnapshot(
            scene: .work,
            availability: .openWindow,
            knownContext: [],
            constraints: []
        ).applying(
            manualScene: .init(scene: .home, expiresAt: .distantFuture),
            now: .now
        )
        _ = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true),
            now: .now,
            rawTodayText: "",
            trainingCases: [],
            recentRuns: [],
            experienceSummary: .empty,
            contextSnapshot: snapshot
        ))

        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertTrue(serialized.contains("\"scene\":\"home\""))
        XCTAssertTrue(serialized.contains("scene_home"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("latitude"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("longitude"))
    }

    @MainActor
    func testAppStoreDoesNotRefreshContextProviderBeforeSideQuestConsent() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        try await repository.savePreference(SideQuestPreference(isEnabled: false))
        let provider = StaticSideQuestContextProvider(
            snapshot: .init(scene: .work, availability: .openWindow, knownContext: [], constraints: [])
        )
        let store = AppStore(
            sideQuestRepository: repository,
            refreshesAIServiceFromKeychain: false,
            sideQuestContextProvider: provider,
            trainingCasesVNextEnabled: true
        )

        await store.refreshSideQuestInvitation()

        XCTAssertEqual(provider.snapshotRequestCount, 0)
        XCTAssertEqual(store.sideQuestContextSnapshot, .empty)
    }

    func testSideQuestRationaleDisplayTextShowsOnlySafeAIGeneratedRationale() {
        let aiRun = SideQuestRun(
            catalogId: "ai.test",
            catalogVersion: "test",
            origin: .aiGenerated,
            promptRunId: UUID(),
            decisionRationale: "你现在在家且有一段空闲，适合做一个很小的整理。",
            category: .making,
            title: "整理桌面一角",
            invitation: "整理一个小角落。",
            evidencePrompt: "有什么变化？",
            prerequisites: [],
            minimumMinutes: 5,
            maximumMinutes: 10,
            reward: .init(track: .craft, completionExperience: 10, reflectionBonusExperience: 0)
        )
        XCTAssertEqual(sideQuestRationaleDisplayText(for: aiRun), aiRun.decisionRationale)

        var fallbackRun = aiRun
        fallbackRun.origin = .catalogFallback
        XCTAssertNil(sideQuestRationaleDisplayText(for: fallbackRun))
        var tokenRun = aiRun
        tokenRun.decisionRationale = "依据 scene_home 推荐。"
        XCTAssertNil(sideQuestRationaleDisplayText(for: tokenRun))
    }

    func testSideQuestOfferRequiresGroundingFromItsActualSituation() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"offer","reason":"你正在家且有空闲，因此适合这段轻度移动。","grounding_refs":["scene_home","availability_openWindow","practical_place_home_stairs"],"offer":{"category":"vitality","title":"走楼梯回家","invitation":"如果身体允许，走楼梯回到家。","evidence_prompt":"完成后身体感觉如何？","minimum_minutes":10,"maximum_minutes":20,"prerequisite_ids":["bodyAppropriate","noRequiredSpending"],"completion_experience":20,"reflection_bonus_experience":2}}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let profile = SideQuestLifeContextProfile(
            homePracticalContext: .init(floorLevel: 15, stairsAvailable: true),
            movementPreferences: [.gentle]
        )
        let snapshot = SideQuestContextSnapshot(
            scene: .home,
            availability: .openWindow,
            knownContext: [],
            constraints: []
        )

        let plan = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true, enabledCategories: [.vitality]),
            lifeContextProfile: profile,
            now: .now,
            rawTodayText: "晚饭后回家。",
            trainingCases: [],
            recentRuns: [],
            experienceSummary: .empty,
            contextSnapshot: snapshot
        ))

        XCTAssertTrue(plan.shouldOffer)
        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertTrue(serialized.contains("\"place\":\"home\""))
        XCTAssertFalse(serialized.contains("\"place\":\"workplace\""))
        XCTAssertTrue(serialized.contains("\"available_grounding_refs\""))
        XCTAssertTrue(serialized.contains("scene_home"))
        XCTAssertTrue(serialized.contains("availability_openWindow"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("latitude"))
    }

    func testSideQuestOfferCanGroundWorkplaceFloorAndStairsWhenSceneIsWork() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"offer","reason":"工作地点有楼层且方便走楼梯，适合一段轻度活动。","grounding_refs":["practical_place_workplace_floor","practical_place_workplace_stairs"],"offer":{"category":"vitality","title":"走一层楼梯","invitation":"如果身体允许，在工作地点走一层楼梯后再继续安排。","evidence_prompt":"完成后身体感觉如何？","minimum_minutes":5,"maximum_minutes":10,"prerequisite_ids":["bodyAppropriate","noRequiredSpending"],"completion_experience":10,"reflection_bonus_experience":1}}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let profile = SideQuestLifeContextProfile(
            workplacePracticalContext: .init(floorLevel: 16, stairsAvailable: true)
        )

        let plan = try await service.plan(for: SideQuestPlanningContext(
            preference: SideQuestPreference(isEnabled: true, enabledCategories: [.vitality]),
            lifeContextProfile: profile,
            now: .now,
            rawTodayText: "",
            trainingCases: [],
            recentRuns: [],
            experienceSummary: .empty,
            contextSnapshot: .init(scene: .work, availability: .unknown, knownContext: [], constraints: [])
        ))

        XCTAssertTrue(plan.shouldOffer)
        let serialized = try XCTUnwrap(client.lastRequest?.contextPayload?.currentInput.rawText)
        XCTAssertTrue(serialized.contains("\"place\":\"workplace\""))
        XCTAssertFalse(serialized.contains("\"place\":\"home\""))
    }

    func testSideQuestRejectsStairsInvitationGroundedOnlyByHomeScene() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"offer","reason":"你正在家且有空闲。","grounding_refs":["scene_home","availability_openWindow"],"offer":{"category":"vitality","title":"走楼梯","invitation":"如果身体允许，走一段楼梯。","evidence_prompt":"完成后身体感觉如何？","minimum_minutes":5,"maximum_minutes":10,"prerequisite_ids":["bodyAppropriate"],"completion_experience":10,"reflection_bonus_experience":0}}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        do {
            _ = try await service.plan(for: SideQuestPlanningContext(
                preference: SideQuestPreference(isEnabled: true, enabledCategories: [.vitality]),
                lifeContextProfile: .init(homePracticalContext: .init(floorLevel: 15, stairsAvailable: true)),
                now: .now,
                rawTodayText: "晚饭后回家。",
                trainingCases: [],
                recentRuns: [],
                experienceSummary: .empty,
                contextSnapshot: .init(scene: .home, availability: .openWindow, knownContext: [], constraints: [])
            ))
            XCTFail("Expected a stairs invitation without stairs grounding to be rejected")
        } catch {
            guard case SideQuestPlanningError.ungroundedDecision = error else {
                return XCTFail("Expected an ungrounded-decision error, got \(error)")
            }
        }
    }

    func testSideQuestRejectsPoolInvitationWithGenericGrounding() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"offer","reason":"你今天有空。","grounding_refs":["current_day"],"offer":{"category":"vitality","title":"去游泳","invitation":"去泳池游泳一会儿。","evidence_prompt":"完成后感觉如何？","minimum_minutes":20,"maximum_minutes":30,"prerequisite_ids":["bodyAppropriate"],"completion_experience":20,"reflection_bonus_experience":2}}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        do {
            _ = try await service.plan(for: SideQuestPlanningContext(
                preference: SideQuestPreference(isEnabled: true, enabledCategories: [.vitality]),
                now: .now,
                rawTodayText: "",
                trainingCases: [],
                recentRuns: [],
                experienceSummary: .empty,
                contextSnapshot: .empty
            ))
            XCTFail("Expected a pool invitation without facility grounding to be rejected")
        } catch {
            guard case SideQuestPlanningError.ungroundedDecision = error else {
                return XCTFail("Expected an ungrounded-decision error, got \(error)")
            }
        }
    }

    func testSideQuestRejectsUnsupportedPlaceAndUnavailableStairsGrounding() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"offer","reason":"这里有楼梯。","grounding_refs":["practical_place_workplace_stairs"],"offer":{"category":"vitality","title":"走楼梯","invitation":"如果身体允许，走一段楼梯。","evidence_prompt":"完成后身体感觉如何？","minimum_minutes":5,"maximum_minutes":10,"prerequisite_ids":["bodyAppropriate"],"completion_experience":10,"reflection_bonus_experience":0}}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let profile = SideQuestLifeContextProfile(
            workplacePracticalContext: .init(floorLevel: 16, stairsAvailable: false)
        )

        do {
            _ = try await service.plan(for: SideQuestPlanningContext(
                preference: SideQuestPreference(isEnabled: true, enabledCategories: [.vitality]),
                lifeContextProfile: profile,
                now: .now,
                rawTodayText: "",
                trainingCases: [],
                recentRuns: [],
                experienceSummary: .empty,
                contextSnapshot: .init(scene: .work, availability: .unknown, knownContext: [], constraints: [])
            ))
            XCTFail("Expected unsupported workplace stairs grounding to be rejected")
        } catch {
            guard case SideQuestPlanningError.ungroundedDecision = error else {
                return XCTFail("Expected an ungrounded-decision error, got \(error)")
            }
        }
    }

    func testSideQuestRejectsOfferThatClaimsUnsupportedFacilityOrContext() async throws {
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"offer","reason":"附近泳池适合今天。","grounding_refs":["scene_pool"],"offer":{"category":"vitality","title":"去游泳","invitation":"去附近泳池游泳。","evidence_prompt":"完成后感觉如何？","minimum_minutes":20,"maximum_minutes":30,"prerequisite_ids":["bodyAppropriate"],"completion_experience":20,"reflection_bonus_experience":2}}
        """)
        let service = SideQuestAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        do {
            _ = try await service.plan(for: SideQuestPlanningContext(
                preference: SideQuestPreference(isEnabled: true, enabledCategories: [.vitality]),
                now: .now,
                rawTodayText: "今天下班。",
                trainingCases: [],
                recentRuns: [],
                experienceSummary: .empty,
                contextSnapshot: .empty
            ))
            XCTFail("Expected an unsupported situational offer to be rejected")
        } catch {
            guard case SideQuestPlanningError.ungroundedDecision = error else {
                return XCTFail("Expected an ungrounded-decision error, got \(error)")
            }
        }
    }

    func testSystemContextProviderReducesInjectedSignalsToCoarseSnapshot() async throws {
        let provider = SystemSideQuestContextProvider(
            locationSceneProvider: { .work },
            calendarAvailabilityProvider: { _ in .busy },
            healthSummaryProvider: { ["health_available"] }
        )
        let snapshot = await provider.snapshot(now: .now)
        XCTAssertEqual(snapshot.scene, .work)
        XCTAssertEqual(snapshot.availability, .busy)
        XCTAssertEqual(snapshot.knownContext, ["health_available"])
        XCTAssertEqual(snapshot.dynamicConstraints, ["calendar_busy"])
    }

    func testHealthSummaryAggregatesCoarseThresholdTokens() async {
        struct Query: SideQuestHealthQuerying {
            let values: [SideQuestHealthMetric: Double]
            func aggregate(metric: SideQuestHealthMetric, start: Date, end: Date) async -> Double? { values[metric] }
        }
        let provider = AggregatingSideQuestHealthSummaryProvider(query: Query(values: [.steps: 24_000, .activeEnergy: 600, .sleepDuration: 21_600]))
        let tokens = await provider.summary(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(tokens, ["health_activity_moderate", "health_sleep_short", "health_steps_high"])
    }

    func testHealthSummaryOmitsTokensForUnavailableAndPartialMeasurements() async {
        struct Query: SideQuestHealthQuerying {
            let values: [SideQuestHealthMetric: Double]
            func aggregate(metric: SideQuestHealthMetric, start: Date, end: Date) async -> Double? { values[metric] }
        }
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let unavailable = AggregatingSideQuestHealthSummaryProvider(query: Query(values: [:]))
        let unavailableTokens = await unavailable.summary(now: now)
        XCTAssertEqual(unavailableTokens, [])

        let partial = AggregatingSideQuestHealthSummaryProvider(query: Query(values: [.steps: 12_000]))
        let partialTokens = await partial.summary(now: now)
        XCTAssertEqual(partialTokens, ["health_steps_moderate"])
    }

    func testHealthSummaryOmitsTokensForNegativeMeasurements() async {
        struct Query: SideQuestHealthQuerying {
            let values: [SideQuestHealthMetric: Double]
            func aggregate(metric: SideQuestHealthMetric, start: Date, end: Date) async -> Double? { values[metric] }
        }
        let provider = AggregatingSideQuestHealthSummaryProvider(
            query: Query(values: [.steps: -1, .activeEnergy: -1, .sleepDuration: -1])
        )

        let tokens = await provider.summary(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(tokens, [])
    }

    func testStaticContextProviderPermissionRequestsAreExplicitAndCounted() async {
        let provider = StaticSideQuestContextProvider()
        provider.requestLocationAuthorization()
        _ = await provider.requestCalendarAuthorization()
        _ = await provider.requestHealthAuthorization()
        XCTAssertEqual(provider.locationRequestCount, 1)
        XCTAssertEqual(provider.calendarRequestCount, 1)
        XCTAssertEqual(provider.healthRequestCount, 1)
    }

    func testSystemAvailabilityAndCalendarWriteOnlyDoNotClaimReadPermission() {
        XCTAssertEqual(SystemSideQuestContextProvider.calendarReadAuthorizationStatus(.writeOnly), .writeOnly)
        XCTAssertEqual(SystemSideQuestContextProvider.calendarReadAuthorizationStatus(.fullAccess), .authorized)
        XCTAssertEqual(SystemSideQuestContextProvider.calendarReadAuthorizationStatus(.denied), .denied)
        XCTAssertEqual(SystemSideQuestContextProvider.healthReadAuthorizationStatus(isAvailable: true), .readAccessUnknown)
        XCTAssertEqual(SystemSideQuestContextProvider.healthReadAuthorizationStatus(isAvailable: false), .unavailable)
    }

    func testContextSnapshotCannotContainRawSystemFields() async {
        let provider = SystemSideQuestContextProvider(
            locationSceneProvider: { .familiarPlace },
            calendarAvailabilityProvider: { _ in .openWindow },
            healthSummaryProvider: { ["health_available"] }
        )
        let snapshot = await provider.snapshot(now: .now)
        let encoded = String(describing: snapshot)
        XCTAssertFalse(encoded.contains("latitude"))
        XCTAssertFalse(encoded.contains("longitude"))
        XCTAssertFalse(encoded.contains("title"))
        XCTAssertFalse(encoded.contains("sample"))
    }

    @MainActor
    func testAppStoreDoesNotCreateLocalFallbackWithoutSideQuestAIService() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        try await repository.savePreference(
            SideQuestPreference(isEnabled: true, enabledCategories: [.making])
        )
        let store = AppStore(
            sideQuestRepository: repository,
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        await store.refreshSideQuestInvitation()

        XCTAssertNil(store.sideQuestRun)
        XCTAssertTrue(store.sideQuestMessage.contains("连接模型"))
    }

    @MainActor
    func testAppStoreDoesNotReplanAfterPersistingSameDayHold() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        try await repository.savePreference(
            SideQuestPreference(isEnabled: true, enabledCategories: [.making])
        )
        let client = SideQuestRecordingLLMClient(response: """
        {"decision":"hold","reason":"保留今天的自主安排。","grounding_refs":[]}
        """)
        let store = AppStore(
            sideQuestRepository: repository,
            refreshesAIServiceFromKeychain: false,
            sideQuestAIService: SideQuestAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            trainingCasesVNextEnabled: true
        )

        await store.refreshSideQuestInvitation()
        await store.refreshSideQuestInvitation()

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertNil(store.sideQuestRun)
        XCTAssertEqual(store.sideQuestMessage, "")
        let metrics = try await repository.trialMetrics(
            since: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            through: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        )
        XCTAssertEqual(metrics.planningDecisions, 1)
        XCTAssertEqual(metrics.holds, 1)
    }

    @MainActor
    func testVNextGrowthDoesNotPersistLocalHeuristicSnapshotWithoutCentralModel() async throws {
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        let questRepository = SQLiteQuestRepository(database: database)
        let verificationRepository = SQLiteVerificationRepository(database: database)
        let snapshotRepository = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepository = SQLiteMetricContributionRepository(database: database)

        for dayOffset in 1...3 {
            let entry = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -dayOffset, to: .now) ?? .now,
                rawText: "Completed growth loop \(dayOffset)",
                state: .sessionComplete
            )
            try await entryRepository.saveDraft(entry)
            let quest = Quest(
                type: .main,
                title: "验证行动 \(dayOffset)",
                whyItMatters: "Fixture",
                completionCriteria: "可观察结果",
                expectedResistance: "none",
                reflectionQuestion: "what changed?",
                status: .completed
            )
            try await questRepository.saveQuests([quest], sourceDailyEntryId: entry.id)
            try await verificationRepository.saveVerification(
                Verification(
                    questId: quest.id,
                    questTitle: quest.title,
                    sourceDailyEntryId: entry.id,
                    completion: .done,
                    valueRating: .high,
                    evidenceText: "Observed \(dayOffset)",
                    calibrationNote: "Calibrated"
                )
            )
        }

        let store = AppStore(
            dailyEntryRepository: entryRepository,
            questRepository: questRepository,
            verificationRepository: verificationRepository,
            metricSnapshotRepository: snapshotRepository,
            metricContributionRepository: contributionRepository,
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        await store.loadPersistedState()

        let persistedSnapshot = try await snapshotRepository.latestSnapshot()
        XCTAssertNil(persistedSnapshot)
        let contributionCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM metric_contributions") ?? 0
        }
        XCTAssertEqual(contributionCount, 0)
        XCTAssertFalse(store.growthSnapshot.canDisplayScores)
        XCTAssertEqual(store.growthSnapshot.completeLoopCount, 0)
    }

    @MainActor
    func testVNextProductionNeverPromotesLocalCaptureWithoutCentralModel() async throws {
        let store = AppStore(
            apiKeyStore: KeychainAPIKeyStore(service: "com.codex.mingsi.tests.missing-key.\(UUID().uuidString)"),
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )
        store.todayDraft.state = .capture
        store.selectTodayMode(.standard)
        store.updateTodayCapture("今天有一个需要验证的判断。")

        store.submitTodayStep()

        XCTAssertEqual(store.todayDraft.state, .organizing)
        XCTAssertTrue(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.trainingCases.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("配置中央模型 API Key"))
        XCTAssertGreaterThan(store.pendingAIRepairCount, 0)
    }

    func testSideQuestPlanningEligibilityIsLimitedByConsentFrequencyAndDay() {
        let now = Date(timeIntervalSince1970: 1_767_355_200)
        let policy = SideQuestPlanningEligibility(calendar: Calendar(identifier: .gregorian))
        let enabled = SideQuestPreference(
            isEnabled: true,
            enabledCategories: [.making],
            frequency: .regular
        )
        XCTAssertTrue(policy.permitsPlanning(preference: enabled, mostRecentRun: nil, now: now))

        var planned = enabled
        planned.lastAIPlanningAt = now
        XCTAssertFalse(policy.permitsPlanning(preference: planned, mostRecentRun: nil, now: now))

        let recentRun = SideQuestRun(
            catalogId: "ai.test",
            catalogVersion: "test",
            origin: .aiGenerated,
            promptRunId: UUID(),
            decisionRationale: "test",
            category: .making,
            title: "test",
            invitation: "test",
            evidencePrompt: "test",
            prerequisites: [],
            minimumMinutes: 5,
            maximumMinutes: 10,
            reward: SideQuestReward(track: .craft, completionExperience: 10, reflectionBonusExperience: 0),
            offeredAt: now
        )
        XCTAssertFalse(policy.permitsPlanning(preference: enabled, mostRecentRun: recentRun, now: now))
    }

    @MainActor
    func testSideQuestNotificationPermissionIsRequestedOnlyByExplicitSetting() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        try await repository.savePreference(
            SideQuestPreference(isEnabled: true, enabledCategories: [.making])
        )
        let reminder = RecordingReminderService()
        let store = AppStore(
            sideQuestRepository: repository,
            reminderService: reminder,
            refreshesAIServiceFromKeychain: false,
            sideQuestAIService: SideQuestAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            trainingCasesVNextEnabled: true
        )

        await store.refreshSideQuestInvitation()
        _ = try XCTUnwrap(store.sideQuestRun)
        XCTAssertEqual(reminder.permissionRequestCount, 0)
        XCTAssertEqual(reminder.scheduled.count, 0)

        await store.setSideQuestNotificationsEnabled(true)
        XCTAssertEqual(reminder.permissionRequestCount, 1)
        XCTAssertEqual(reminder.scheduled.count, 1)
        XCTAssertTrue(store.sideQuestPreference.notificationsEnabled)

        await store.moveCurrentSideQuestToNextTime()
        XCTAssertEqual(reminder.cancelled.count, 1)
    }

    @MainActor
    func testAppStoreSurfacesAnOptedInSideQuestAndCompletesItWithoutMetricContribution() async throws {
        let repository = SQLiteSideQuestRepository(database: database)
        try await repository.savePreference(
            SideQuestPreference(
                isEnabled: true,
                enabledCategories: [.making]
            )
        )
        let sideQuestAIService = SideQuestAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: MockLLMClient()
        )

        let store = AppStore(
            sideQuestRepository: repository,
            refreshesAIServiceFromKeychain: false,
            sideQuestAIService: sideQuestAIService,
            trainingCasesVNextEnabled: true
        )
        await store.refreshSideQuestInvitation()
        _ = try XCTUnwrap(store.sideQuestRun)
        let offered = try XCTUnwrap(store.sideQuestRun)
        XCTAssertEqual(offered.status, .offered)
        XCTAssertEqual(offered.category, .making)

        await store.acceptCurrentSideQuest()
        XCTAssertEqual(store.sideQuestRun?.status, .accepted)
        await store.completeCurrentSideQuest(reflection: "做出了一个可见版本")
        XCTAssertEqual(store.sideQuestRun?.status, .completed)
        XCTAssertGreaterThan(store.latestSideQuestExperience?.totalExperience ?? 0, 0)

        let metricCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM metric_contributions")
        }
        XCTAssertEqual(metricCount, 0)
    }

    func testProjectClosureReviewPersistsRequiredOutcomeAndPreviousStatus() async throws {
        let project = Project(name: "P", goal: "G", successCriteria: "S", status: .paused)
        try await SQLiteProjectRepository(database: database).saveProject(project)
        let review = ProjectClosureReview(
            projectId: project.id,
            reason: .stopped,
            outcome: "Stopped after validating the constraint.",
            previousStatus: .paused
        )
        let repo = SQLiteProjectClosureReviewRepository(database: database)
        try await repo.saveReview(review)

        let storedReview = try await repo.review(for: project.id)
        let loaded = try XCTUnwrap(storedReview)
        XCTAssertEqual(loaded.reason, .stopped)
        XCTAssertEqual(loaded.previousStatus, .paused)
        XCTAssertEqual(loaded.outcome, review.outcome)
    }

    func testClosingProjectPersistsReviewAndArchivedProjectTogether() async throws {
        var project = Project(name: "P", goal: "G", successCriteria: "S", status: .active)
        try await SQLiteProjectRepository(database: database).saveProject(project)
        project.status = .archived
        let review = ProjectClosureReview(
            projectId: project.id,
            reason: .achieved,
            outcome: "The agreed result was delivered.",
            previousStatus: .active
        )

        let repository = SQLiteProjectClosureReviewRepository(database: database)
        try await repository.closeProject(project, review: review)

        let savedProject = try await SQLiteProjectRepository(database: database).project(id: project.id)
        let savedReview = try await repository.review(for: project.id)
        XCTAssertEqual(savedProject?.status, .archived)
        XCTAssertEqual(savedReview?.id, review.id)
    }

    @MainActor
    func testFreshDayLaunchRestoresLinkedProjectClosureReview() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let entry = DailyEntryDraft(date: yesterday, rawText: "Closed project evidence", state: .sessionComplete)
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        let projectRepository = SQLiteProjectRepository(database: database)
        let projectLinkRepository = SQLiteProjectLinkRepository(database: database)
        let closureRepository = SQLiteProjectClosureReviewRepository(database: database)
        try await entryRepository.saveDraft(entry)

        let project = Project(
            name: "Closed project",
            goal: "Finish the outcome",
            successCriteria: "Outcome is recorded",
            status: .archived
        )
        try await projectRepository.saveProject(project)
        try await projectLinkRepository.saveLink(
            ProjectLink(
                projectId: project.id,
                sourceType: .dailyEntry,
                sourceId: entry.id.uuidString,
                linkType: .evidence,
                isUserConfirmed: true
            )
        )
        let review = ProjectClosureReview(
            projectId: project.id,
            reason: .achieved,
            outcome: "The planned outcome was delivered.",
            previousStatus: .active
        )
        try await closureRepository.saveReview(review)

        let store = AppStore(
            dailyEntryRepository: entryRepository,
            projectLinkRepository: projectLinkRepository,
            projectRepository: projectRepository,
            projectClosureReviewRepository: closureRepository,
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        await store.loadPersistedState()

        XCTAssertEqual(store.projectsById[project.id]?.status, .archived)
        XCTAssertEqual(store.projectClosureReviews[project.id]?.id, review.id)
    }

    func testClosureReviewPersistsEvidenceBackedPrincipleCandidates() async throws {
        let project = Project(name: "P", goal: "G", successCriteria: "S")
        try await SQLiteProjectRepository(database: database).saveProject(project)
        let candidate = ProjectClosurePrincipleCandidate(
            title: "Confirm ownership before execution",
            summary: "Explicit ownership makes the handoff testable.",
            triggerContext: "Before a cross-team handoff",
            actions: ["Name an owner"],
            successCriteria: "The owner confirms in writing",
            exceptions: "Urgent incident response",
            evidenceRefs: [UUID().uuidString, UUID().uuidString]
        )
        let review = ProjectClosureReview(
            projectId: project.id,
            reason: .achieved,
            outcome: "Done",
            principleCandidates: [candidate],
            previousStatus: .active
        )
        let repository = SQLiteProjectClosureReviewRepository(database: database)
        try await repository.saveReview(review)

        let savedReview = try await repository.review(for: project.id)
        XCTAssertEqual(savedReview?.principleCandidates, [candidate])
    }

    func testWeeklyGuidanceReviewPolicyRequiresThreeVerificationsAcrossTwoDays() {
        let now = Date()
        let first = Verification(questId: UUID(), questTitle: "A", sourceDailyEntryId: UUID(), completion: .done, valueRating: .high, judgmentUpdate: .confirmed, evidenceText: "A", calibrationNote: "A", createdAt: now)
        let second = Verification(questId: UUID(), questTitle: "B", sourceDailyEntryId: UUID(), completion: .done, valueRating: .high, judgmentUpdate: .confirmed, evidenceText: "B", calibrationNote: "B", createdAt: now)
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let third = Verification(questId: UUID(), questTitle: "C", sourceDailyEntryId: UUID(), completion: .done, valueRating: .high, judgmentUpdate: .confirmed, evidenceText: "C", calibrationNote: "C", createdAt: previousDay)

        XCTAssertTrue(WeeklyGuidanceReviewPolicy().isEligible(verifications: [first, second, third], now: now))
        XCTAssertFalse(WeeklyGuidanceReviewPolicy().isEligible(verifications: [first, second], now: now))
    }

    func testWeeklyGuidanceReviewReadinessReportsBothEvidenceRequirements() {
        let now = Date()
        let verification = Verification(
            questId: UUID(),
            questTitle: "A",
            sourceDailyEntryId: UUID(),
            completion: .done,
            valueRating: .high,
            judgmentUpdate: .confirmed,
            evidenceText: "A",
            calibrationNote: "A",
            createdAt: now
        )

        let readiness = WeeklyGuidanceReviewPolicy().readiness(verifications: [verification], now: now)

        XCTAssertEqual(readiness.recentVerificationCount, 1)
        XCTAssertEqual(readiness.coveredDayCount, 1)
        XCTAssertEqual(readiness.remainingVerificationCount, 2)
        XCTAssertEqual(readiness.remainingDayCount, 1)
        XCTAssertFalse(readiness.isEligible)
    }

    func testWeeklyGuidanceReviewRepositoryPersistsOneImmutableReviewPerNaturalWeek() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let repository = SQLiteWeeklyGuidanceReviewRepository(database: database)
        let weekKey = WeeklyGuidanceReviewPolicy().weekKey()
        let selection = WeeklyGuidanceReviewSelection(
            trainingFocus: "先写清核心判断",
            hintIds: ["judgment.observable_evidence"],
            evidenceRefs: [UUID().uuidString]
        )
        let record = WeeklyGuidanceReviewRecord(weekKey: weekKey, selection: selection)

        try await repository.saveReview(record)

        let stored = try await repository.review(forWeekKey: weekKey)
        XCTAssertEqual(stored?.weekKey, weekKey)
        XCTAssertEqual(stored?.selection, selection)

        do {
            try await repository.saveReview(
                WeeklyGuidanceReviewRecord(
                    weekKey: weekKey,
                    selection: WeeklyGuidanceReviewSelection(
                        trainingFocus: "不应覆盖已有结果",
                        hintIds: ["action.completion_criteria"],
                        evidenceRefs: [UUID().uuidString]
                    )
                )
            )
            XCTFail("A natural week must have only one immutable guidance review")
        } catch {
            // Expected: the week key is the database uniqueness boundary.
        }

        let unchanged = try await repository.review(forWeekKey: weekKey)
        XCTAssertEqual(unchanged?.selection, selection)
    }

    func testProjectClosureAIKeepsOnlyEvidenceBackedPrincipleCandidates() async throws {
        let project = Project(name: "P", goal: "G", successCriteria: "S", status: .archived)
        let review = ProjectClosureReview(projectId: project.id, reason: .achieved, outcome: "Done", previousStatus: .active)
        let evidence = [
            ProjectInsightEvidenceContext(id: UUID().uuidString, type: "verification", title: "A", body: "A"),
            ProjectInsightEvidenceContext(id: UUID().uuidString, type: "verification", title: "B", body: "B")
        ]
        let result = try await ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: MockLLMClient()
        ).generateClosureReview(project: project, closure: review, confirmedEvidence: evidence)

        XCTAssertNil(result.insufficientEvidenceReason)
        XCTAssertEqual(result.principleCandidates.count, 1)
        XCTAssertEqual(Set(result.principleCandidates[0].evidenceRefs), Set(evidence.map(\.id)))
    }

    func testWeeklyGuidanceAISelectsOnlyCatalogHintIDsAndVerificationEvidence() async throws {
        let now = Date()
        let dates = [now, now, Calendar.current.date(byAdding: .day, value: -1, to: now)!]
        let verifications = dates.enumerated().map { index, date in
            Verification(
                questId: UUID(), questTitle: "Q\(index)", sourceDailyEntryId: UUID(),
                completion: .done, valueRating: .high, judgmentUpdate: .confirmed,
                evidenceText: "Evidence \(index)", calibrationNote: "Calibration \(index)", createdAt: date
            )
        }
        let selection = try await GrowthAIService(
            promptProvider: LocalPromptProvider(), llmClient: MockLLMClient()
        ).generateWeeklyGuidanceReview(verifications: verifications, now: now)

        XCTAssertEqual(selection?.hintIds, ["action.completion_criteria"])
        XCTAssertTrue(Set(selection?.evidenceRefs ?? []).isSubset(of: Set(verifications.map { $0.id.uuidString })))
    }

    func testMigrationFromV1CreatesDefaultCaseAndPreservesCardAndQuest() async throws {
        let queue = try DatabaseQueue()
        let entryId = UUID()
        let cardId = UUID()
        let questId = UUID()
        let now = Self.fixtureTimestamp

        try createV1FixtureSchema(in: queue)
        try await queue.write { db in
            try db.execute(
                sql: "INSERT INTO daily_entries (id, schema_version, date, raw_text, session_mode, state, created_at, updated_at) VALUES (?, 1, ?, ?, 'standard', 'review_cards', ?, ?)",
                arguments: [entryId.uuidString, now, "Legacy decision", now, now]
            )
            try db.execute(
                sql: "INSERT INTO thinking_cards (id, daily_entry_id, schema_version, type, title, body, importance, sensitivity, confidence, is_confirmed, is_excluded_from_model, created_at, updated_at) VALUES (?, ?, 1, 'fact', 'Legacy fact', 'The historical observation remains available.', 'medium', 'normal', 0.9, 1, 0, ?, ?)",
                arguments: [cardId.uuidString, entryId.uuidString, now, now]
            )
            try db.execute(
                sql: "INSERT INTO quests (id, source_daily_entry_id, schema_version, type, title, why_it_matters, completion_criteria, status, created_at, updated_at) VALUES (?, ?, 1, 'main', 'Legacy action', 'It tests the decision.', 'Record the observed result.', 'active', ?, ?)",
                arguments: [questId.uuidString, entryId.uuidString, now, now]
            )
        }

        try AppDatabase.makeMigrator().migrate(queue)

        try await queue.read { db in
            let caseId = try XCTUnwrap(String.fetchOne(
                db,
                sql: "SELECT id FROM training_cases WHERE daily_entry_id = ?",
                arguments: [entryId.uuidString]
            ))
            XCTAssertEqual(
                try String.fetchOne(db, sql: "SELECT case_id FROM thinking_cards WHERE id = ?", arguments: [cardId.uuidString]),
                caseId
            )
            XCTAssertEqual(
                try String.fetchOne(db, sql: "SELECT case_id FROM quests WHERE id = ?", arguments: [questId.uuidString]),
                caseId
            )
            XCTAssertEqual(
                try String.fetchOne(db, sql: "SELECT title FROM thinking_cards WHERE id = ?", arguments: [cardId.uuidString]),
                "Legacy fact"
            )
            XCTAssertEqual(
                try String.fetchOne(db, sql: "SELECT title FROM quests WHERE id = ?", arguments: [questId.uuidString]),
                "Legacy action"
            )
        }
    }

    func testMigrationFromV32ComplexHistoryBackfillsOwnershipAndExportsVNextRecords() async throws {
        let queue = try DatabaseQueue()
        let legacyDatabase = try AppDatabase(dbQueue: queue, includesVNextMigrations: false)
        let entry = DailyEntryDraft(rawText: "Complex historical record", state: .sessionComplete)
        let cardId = UUID()
        let questId = UUID()
        let lensId = UUID()
        let verificationId = UUID()
        let snapshotId = UUID()
        let contributionId = UUID()
        let project = Project(name: "Historical project", goal: "Keep evidence", successCriteria: "All links survive")
        let principle = PrincipleAsset(
            title: "Historical principle",
            summary: "Keep the evidence chain.",
            triggerContext: "During migration",
            actions: ["Verify ownership"],
            successCriteria: "Every source remains reachable",
            exceptions: "None"
        )
        let now = Self.fixtureTimestamp

        try await SQLiteDailyEntryRepository(database: legacyDatabase).saveDraft(entry)
        try await SQLiteProjectRepository(database: legacyDatabase).saveProject(project)
        try await SQLitePrincipleRepository(database: legacyDatabase).savePrinciple(principle, sourceDailyEntryId: entry.id)
        try await SQLiteProjectLinkRepository(database: legacyDatabase).saveLink(ProjectLink(
            projectId: project.id,
            sourceType: .quest,
            sourceId: questId.uuidString,
            linkType: .evidence,
            isUserConfirmed: true
        ))
        try await SQLiteMetricSnapshotRepository(database: legacyDatabase).saveSnapshot(MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3,
            valueJudgment: 3,
            executionReliability: 3,
            calibration: 3,
            reflectionDepth: 3,
            summary: "Historical snapshot",
            completeLoopCount: 3
        ))
        try await queue.write { db in
            try db.execute(
                sql: "INSERT INTO thinking_cards (id, daily_entry_id, schema_version, type, title, body, importance, sensitivity, confidence, is_confirmed, is_excluded_from_model, created_at, updated_at) VALUES (?, ?, 1, 'fact', 'Historical card', 'Confirmed historical evidence.', 'high', 'normal', 0.9, 1, 0, ?, ?)",
                arguments: [cardId.uuidString, entry.id.uuidString, now, now]
            )
            try db.execute(
                sql: "INSERT INTO quests (id, source_daily_entry_id, schema_version, type, title, why_it_matters, completion_criteria, expected_resistance, reflection_question, status, due_date, created_at, updated_at) VALUES (?, ?, 1, 'main', 'Historical quest', 'Tests the historical judgment.', 'Capture a concrete result.', 'Time pressure', 'What changed?', 'completed', ?, ?, ?)",
                arguments: [questId.uuidString, entry.id.uuidString, now, now, now]
            )
            try db.execute(
                sql: "INSERT INTO lens_sessions (id, daily_entry_id, selected_lens, questions_json, created_at, updated_at) VALUES (?, ?, 'evidence_check', '[]', ?, ?)",
                arguments: [lensId.uuidString, entry.id.uuidString, now, now]
            )
            try db.execute(
                sql: "INSERT INTO verifications (id, quest_id, quest_title, source_daily_entry_id, completion, value_rating, judgment_update, evidence_text, calibration_note, created_at, updated_at) VALUES (?, ?, 'Historical quest', ?, 'done', 'high', 'adjusted', 'The result changed the estimate.', 'Update the original judgment.', ?, ?)",
                arguments: [verificationId.uuidString, questId.uuidString, entry.id.uuidString, now, now]
            )
            try db.execute(
                sql: "INSERT INTO metric_contributions (id, schema_version, snapshot_id, metric, direction, delta, title, reason, source_type, source_id, source_daily_entry_id, user_feedback, candidate_status, practice_role, created_at, updated_at) VALUES (?, 1, ?, 'calibration', 'positive', 0.2, 'Historical calibration', 'Result updated the judgment.', 'verification', ?, ?, 'accepted', 'accepted', 'targetedPractice', ?, ?)",
                arguments: [contributionId.uuidString, snapshotId.uuidString, verificationId.uuidString, entry.id.uuidString, now, now]
            )
        }

        try AppDatabase.makeMigrator().migrate(queue)
        let migratedDatabase = try AppDatabase(dbQueue: queue)

        let defaultCaseId = try await queue.read { db in
            try XCTUnwrap(String.fetchOne(
                db,
                sql: "SELECT id FROM training_cases WHERE daily_entry_id = ?",
                arguments: [entry.id.uuidString]
            ))
        }
        try await queue.read { db in
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT case_id FROM thinking_cards WHERE id = ?", arguments: [cardId.uuidString]), defaultCaseId)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT case_id FROM quests WHERE id = ?", arguments: [questId.uuidString]), defaultCaseId)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT case_id FROM lens_sessions WHERE id = ?", arguments: [lensId.uuidString]), defaultCaseId)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT source_case_id FROM metric_contributions WHERE id = ?", arguments: [contributionId.uuidString]), defaultCaseId)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM verifications WHERE id = ?", arguments: [verificationId.uuidString]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM projects WHERE id = ?", arguments: [project.id.uuidString]), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM principle_assets WHERE id = ?", arguments: [principle.id.uuidString]), 1)
        }

        let export = try await SQLiteDataExportRepository(database: migratedDatabase).exportPackage()
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: export.data) as? [String: Any])
        let sections = try XCTUnwrap(payload["sections"] as? [String: Any])
        for section in ["training_cases", "training_case_sessions", "project_closure_reviews", "growth_settlements", "user_guidance_states", "weekly_guidance_reviews", "coach_turn_feedback"] {
            XCTAssertNotNil(sections[section], "Export must include \(section)")
        }
        XCTAssertFalse(String(decoding: export.data, as: UTF8.self).localizedCaseInsensitiveContains("api_key"))
    }

    func testLegacyMigrationModeStopsBeforeVNextTables() throws {
        let queue = try DatabaseQueue()
        _ = try AppDatabase(dbQueue: queue, includesVNextMigrations: false)

        try queue.read { db in
            XCTAssertFalse(try db.tableExists("training_cases"))
            XCTAssertFalse(try db.tableExists("growth_settlements"))
            XCTAssertFalse(try db.tableExists("project_closure_reviews"))
            XCTAssertFalse(try db.tableExists("weekly_guidance_reviews"))
        }
    }

    func testPreVNextFileDatabaseCreatesConsistentBackupBeforeMigration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("mingsi.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            let queue = try DatabaseQueue(path: url.path)
            let legacyDatabase = try AppDatabase(dbQueue: queue, includesVNextMigrations: false)
            try await SQLiteDailyEntryRepository(database: legacyDatabase).saveDraft(
                DailyEntryDraft(rawText: "Legacy database requiring backup")
            )
            try queue.close()
        }

        _ = try AppDatabase(url: url)
        let backupURL = url.deletingPathExtension().appendingPathExtension("pre-vnext.sqlite")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))

        let backupQueue = try DatabaseQueue(path: backupURL.path)
        try await backupQueue.read { db in
            XCTAssertFalse(try db.tableExists("training_cases"))
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_entries"), 1)
        }
    }

    func testAlreadyMigratedFileDoesNotCreateLatePreVNextBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("mingsi.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        _ = try AppDatabase(url: url)
        _ = try AppDatabase(url: url)

        let backupURL = url.deletingPathExtension().appendingPathExtension("pre-vnext.sqlite")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testOpenPreVNextConnectionDoesNotStartMigrationAndLeavesLegacyDatabaseUntouched() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("mingsi.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let legacyDatabase = try AppDatabase(url: url, includesVNextMigrations: false)
        let queue = legacyDatabase.dbQueue
        let entry = DailyEntryDraft(rawText: "Keep this legacy record intact")
        try await SQLiteDailyEntryRepository(database: legacyDatabase).saveDraft(entry)

        try withExtendedLifetime(legacyDatabase) {
            XCTAssertThrowsError(try AppDatabase(url: url)) { error in
                XCTAssertEqual(error as? AppDatabaseBootstrapError, .preVNextBackupUnavailable)
            }
        }

        try await queue.read { db in
            XCTAssertFalse(try db.tableExists("training_cases"))
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_entries"), 1)
        }
    }

    func testFailedVNextMigrationLeavesThePreVNextDatabaseIntact() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("mingsi.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let entry = DailyEntryDraft(rawText: "Do not partially migrate this entry")
        do {
            let queue = try DatabaseQueue(path: url.path)
            let legacyDatabase = try AppDatabase(dbQueue: queue, includesVNextMigrations: false)
            try await SQLiteDailyEntryRepository(database: legacyDatabase).saveDraft(entry)
            try await queue.write { db in
                try db.execute(
                    sql: "INSERT INTO thinking_cards (id, daily_entry_id, schema_version, type, title, body, importance, sensitivity, confidence, is_confirmed, is_excluded_from_model, created_at, updated_at) VALUES (?, ?, 1, 'fact', 'Fixture', 'Migration failure fixture', 'medium', 'normal', 1, 1, 0, ?, ?)",
                    arguments: [UUID().uuidString, entry.id.uuidString, Self.fixtureTimestamp, Self.fixtureTimestamp]
                )
                try db.execute(sql: "CREATE TRIGGER reject_vnext_case_backfill BEFORE UPDATE ON thinking_cards BEGIN SELECT RAISE(ABORT, 'fixture rejects v34 backfill'); END")
            }
            try queue.close()
        }

        XCTAssertThrowsError(try AppDatabase(url: url)) { error in
            XCTAssertEqual(error as? AppDatabaseBootstrapError, .vNextMigrationFailed)
        }

        let restoredQueue = try DatabaseQueue(path: url.path)
        try await restoredQueue.read { db in
            XCTAssertFalse(try db.tableExists("training_cases"))
            XCTAssertFalse(Set(try db.columns(in: "thinking_cards").map(\.name)).contains("case_id"))
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_entries"), 1)
        }
        let backupURL = url.deletingPathExtension().appendingPathExtension("pre-vnext.sqlite")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testOwnershipUpdateTriggersRejectMovingLensAndGrowthEvidenceAcrossCases() async throws {
        let firstEntry = DailyEntryDraft(rawText: "First")
        let secondEntry = DailyEntryDraft(rawText: "Second")
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        try await entryRepository.saveDraft(firstEntry)
        try await entryRepository.saveDraft(secondEntry)

        let firstCase = TrainingCase(dailyEntryId: firstEntry.id, title: "First", status: .ready)
        let secondCase = TrainingCase(dailyEntryId: secondEntry.id, title: "Second", status: .ready)
        let caseRepository = SQLiteTrainingCaseRepository(database: database)
        try await caseRepository.saveCase(firstCase)
        try await caseRepository.saveCase(secondCase)

        let lens = LensSession(
            dailyEntryId: firstEntry.id,
            trainingCaseId: firstCase.id,
            selectedLens: .evidenceCheck,
            questions: []
        )
        try await SQLiteLensSessionRepository(database: database).saveLensSession(lens)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3,
            valueJudgment: 3,
            executionReliability: 3,
            calibration: 3,
            reflectionDepth: 3,
            summary: "Fixture"
        )
        try await SQLiteMetricSnapshotRepository(database: database).saveSnapshot(snapshot)
        let contribution = MetricContribution(
            snapshotId: snapshot.id,
            metric: .clarity,
            direction: .positive,
            delta: 0.1,
            title: "Fixture contribution",
            reason: "Evidence is clear.",
            sourceType: .dailyEntry,
            sourceId: firstEntry.id.uuidString,
            sourceDailyEntryId: firstEntry.id,
            sourceCaseId: firstCase.id
        )
        try await SQLiteMetricContributionRepository(database: database).saveContribution(contribution)

        do {
            try await database.dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE lens_sessions SET daily_entry_id = ? WHERE id = ?",
                    arguments: [secondEntry.id.uuidString, lens.id.uuidString]
                )
            }
            XCTFail("Expected lens ownership trigger to reject the update")
        } catch {}
        do {
            try await database.dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE metric_contributions SET source_daily_entry_id = ? WHERE id = ?",
                    arguments: [secondEntry.id.uuidString, contribution.id.uuidString]
                )
            }
            XCTFail("Expected growth ownership trigger to reject the update")
        } catch {}
    }

    @MainActor
    func testCoachFeedbackBindsOnlyPresentedQuestionsTurnForMatchingCaseSessionAndOutput() async throws {
        let fixture = try await makeCoachFeedbackStore()
        fixture.store.todayDraft.state = .answerQuestions
        let visibleQuestions = [
            ReflectionQuestion(
                question: "What evidence would change this decision?",
                whyItMatters: "It keeps the judgment falsifiable."
            )
        ]
        fixture.store.questions = visibleQuestions

        let presentedRun = makeCoachPromptRun(
            promptID: .generateQuestions,
            caseId: fixture.trainingCase.id,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newestUnpresentedRun = makeCoachPromptRun(
            promptID: .generateQuestions,
            caseId: fixture.trainingCase.id,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let otherCaseRun = makeCoachPromptRun(
            promptID: .generateQuestions,
            caseId: UUID(),
            createdAt: Date(timeIntervalSince1970: 300)
        )
        try await fixture.promptRunRepository.savePromptRun(presentedRun)
        try await fixture.promptRunRepository.savePromptRun(newestUnpresentedRun)
        try await fixture.promptRunRepository.savePromptRun(otherCaseRun)

        let storedSession = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        let session = try XCTUnwrap(storedSession)
        let fingerprint = CoachPromptOutputFingerprint.questions(visibleQuestions)
        try await markCoachTurnPresented(
            fixture.coachPromptTurnRepository,
            run: presentedRun,
            session: session,
            caseId: fixture.trainingCase.id,
            promptID: .generateQuestions,
            outputFingerprint: fingerprint
        )

        await fixture.store.recordCoachTurnFeedback(.tooAbstract)

        let feedback = try database.dbQueue.read { db in
            try Row.fetchOne(db, sql: "SELECT case_session_id, prompt_run_id, value FROM coach_turn_feedback")
        }
        XCTAssertEqual(feedback?["case_session_id"] as String?, session.id.uuidString)
        XCTAssertEqual(feedback?["prompt_run_id"] as String?, presentedRun.id.uuidString)
        XCTAssertEqual(feedback?["value"] as String?, CoachTurnFeedbackValue.tooAbstract.rawValue)

        let runs = try await fixture.promptRunRepository.recentPromptRuns(limit: 10)
        XCTAssertEqual(runs.first(where: { $0.id == presentedRun.id })?.userFeedback, .denied)
        XCTAssertEqual(runs.first(where: { $0.id == newestUnpresentedRun.id })?.userFeedback, PromptRunFeedback.none)
        XCTAssertEqual(runs.first(where: { $0.id == otherCaseRun.id })?.userFeedback, PromptRunFeedback.none)

        await fixture.store.loadCoachPromptQualitySummaries()
        let summary = try XCTUnwrap(fixture.store.coachPromptQualitySummaries.first)
        XCTAssertEqual(summary.presentedCount, 1)
        XCTAssertEqual(summary.tooAbstractCount, 1)
    }

    @MainActor
    func testCoachFeedbackRequiresMatchingPresentedOutputAndDoesNotAttributeLocalLensFeedback() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let questsRun = makeCoachPromptRun(
            promptID: .generateQuests,
            caseId: fixture.trainingCase.id,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        try await fixture.promptRunRepository.savePromptRun(questsRun)
        let visibleQuests = [makeQuest(caseId: fixture.trainingCase.id, title: "Confirm the decision owner")]
        fixture.store.quests = visibleQuests
        let storedSession = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        let session = try XCTUnwrap(storedSession)
        try await markCoachTurnPresented(
            fixture.coachPromptTurnRepository,
            run: questsRun,
            session: session,
            caseId: fixture.trainingCase.id,
            promptID: .generateQuests,
            outputFingerprint: CoachPromptOutputFingerprint.quests(visibleQuests)
        )

        fixture.store.todayDraft.state = .reviewQuests
        await fixture.store.recordCoachTurnFeedback(.wrongTarget)
        fixture.store.todayDraft.state = .selectLens
        await fixture.store.recordCoachTurnFeedback(.useful)

        let feedbackRows = try database.dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT prompt_run_id, value FROM coach_turn_feedback ORDER BY created_at ASC"
            )
        }
        XCTAssertEqual(feedbackRows.count, 1)
        XCTAssertEqual(feedbackRows[0]["prompt_run_id"] as String?, questsRun.id.uuidString)
        XCTAssertEqual(feedbackRows[0]["value"] as String?, CoachTurnFeedbackValue.wrongTarget.rawValue)

        let runs = try await fixture.promptRunRepository.recentPromptRuns(limit: 10)
        XCTAssertEqual(runs.first(where: { $0.id == questsRun.id })?.userFeedback, .denied)
    }

    @MainActor
    func testCoachFeedbackRejectsOutputThatDoesNotMatchPresentedTurn() async throws {
        let fixture = try await makeCoachFeedbackStore()
        fixture.store.todayDraft.state = .answerQuestions
        let presentedQuestions = [
            ReflectionQuestion(question: "What would disprove this assumption?", whyItMatters: "It guards calibration.")
        ]
        let visibleQuestions = [
            ReflectionQuestion(question: "What evidence is still missing?", whyItMatters: "It keeps the next move concrete.")
        ]
        let run = makeCoachPromptRun(
            promptID: .generateQuestions,
            caseId: fixture.trainingCase.id,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        try await fixture.promptRunRepository.savePromptRun(run)
        let storedSession = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        let session = try XCTUnwrap(storedSession)
        try await markCoachTurnPresented(
            fixture.coachPromptTurnRepository,
            run: run,
            session: session,
            caseId: fixture.trainingCase.id,
            promptID: .generateQuestions,
            outputFingerprint: CoachPromptOutputFingerprint.questions(presentedQuestions)
        )
        fixture.store.questions = visibleQuestions

        await fixture.store.recordCoachTurnFeedback(.useful)

        let count = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM coach_turn_feedback")
        }
        XCTAssertEqual(count, 0)
        let storedRuns = try await fixture.promptRunRepository.recentPromptRuns(limit: 1)
        XCTAssertEqual(storedRuns.first?.userFeedback, PromptRunFeedback.none)
    }

    @MainActor
    func testRestoringMultipleCasesKeepsResultsWithoutAutomaticGrowthScores() async throws {
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        let caseRepository = SQLiteTrainingCaseRepository(database: database)
        let sessionRepository = SQLiteTrainingCaseSessionRepository(database: database)
        let cardRepository = SQLiteThinkingCardRepository(database: database)
        let questRepository = SQLiteQuestRepository(database: database)
        let verificationRepository = SQLiteVerificationRepository(database: database)
        let lensRepository = SQLiteLensSessionRepository(database: database)
        let snapshotRepository = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepository = SQLiteMetricContributionRepository(database: database)
        var caseIDs = Set<UUID>()
        var secondCaseID: UUID?

        for dayOffset in 1...3 {
            let entry = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -dayOffset, to: .now) ?? .now,
                rawText: "Multi-case growth \(dayOffset)",
                state: .sessionComplete
            )
            try await entryRepository.saveDraft(entry)
            let count = dayOffset == 1 ? 2 : 1

            for index in 0..<count {
                let trainingCase = TrainingCase(
                    dailyEntryId: entry.id,
                    title: "事项 \(dayOffset)-\(index)",
                    status: .awaitingVerification,
                    sortOrder: index
                )
                try await caseRepository.saveCase(trainingCase)
                caseIDs.insert(trainingCase.id)
                if dayOffset == 1, index == 1 {
                    secondCaseID = trainingCase.id
                }

                let quest = Quest(
                    trainingCaseId: trainingCase.id,
                    type: .main,
                    title: "验证 \(dayOffset)-\(index)",
                    whyItMatters: "Fixture",
                    completionCriteria: "可以观察到的结果",
                    expectedResistance: "none",
                    reflectionQuestion: "what changed?",
                    status: .completed
                )
                try await questRepository.saveQuests(
                    [quest],
                    sourceDailyEntryId: entry.id,
                    trainingCaseId: trainingCase.id
                )
                try await verificationRepository.saveVerification(
                    Verification(
                        questId: quest.id,
                        questTitle: quest.title,
                        sourceDailyEntryId: entry.id,
                        completion: .done,
                        valueRating: .high,
                        evidenceText: "Observed \(dayOffset)-\(index)",
                        calibrationNote: "Calibration \(dayOffset)-\(index)"
                    )
                )
            }
        }

        let store = AppStore(
            dailyEntryRepository: entryRepository,
            thinkingCardRepository: cardRepository,
            questRepository: questRepository,
            verificationRepository: verificationRepository,
            lensSessionRepository: lensRepository,
            metricSnapshotRepository: snapshotRepository,
            metricContributionRepository: contributionRepository,
            trainingCaseRepository: caseRepository,
            trainingCaseSessionRepository: sessionRepository,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        await store.loadPersistedState()

        XCTAssertFalse(store.growthSnapshot.canDisplayScores)
        let snapshot = try await snapshotRepository.latestSnapshot()
        XCTAssertNil(snapshot)
        let results = store.historyRecords.flatMap(\.allVerifications)
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.allSatisfy { $0.valueRating == .high })
        XCTAssertEqual(Set(store.historyRecords.flatMap { $0.caseRecords.map { $0.trainingCase.id } }), caseIDs)
        for record in store.historyRecords {
            let contributions = try await contributionRepository.contributions(forDailyEntryId: record.draft.id)
            XCTAssertTrue(contributions.isEmpty)
        }
        let expectedSecondCaseID = try XCTUnwrap(secondCaseID)
        XCTAssertTrue(store.historyRecords.contains { record in
            record.allVerifications.contains { verification in
                record.caseRecords.contains { caseRecord in
                    caseRecord.trainingCase.id == expectedSecondCaseID &&
                        caseRecord.verifications.contains(where: { $0.id == verification.id })
                }
            }
        })
    }

    @MainActor
    func testLegacyCrossDayVerificationAndMigratedLensKeepCanonicalCaseAttribution() async throws {
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        let caseRepository = SQLiteTrainingCaseRepository(database: database)
        let sessionRepository = SQLiteTrainingCaseSessionRepository(database: database)
        let cardRepository = SQLiteThinkingCardRepository(database: database)
        let questRepository = SQLiteQuestRepository(database: database)
        let verificationRepository = SQLiteVerificationRepository(database: database)
        let lensRepository = SQLiteLensSessionRepository(database: database)
        let snapshotRepository = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepository = SQLiteMetricContributionRepository(database: database)

        var entries: [DailyEntryDraft] = []
        var cases: [TrainingCase] = []
        var quests: [Quest] = []
        for dayOffset in 1...3 {
            let entry = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -dayOffset, to: .now) ?? .now,
                rawText: "Legacy cross-day verification \(dayOffset)",
                state: .sessionComplete
            )
            try await entryRepository.saveDraft(entry)
            entries.append(entry)

            let trainingCase = TrainingCase(
                dailyEntryId: entry.id,
                title: "事项 \(dayOffset)",
                status: .completed
            )
            try await caseRepository.saveCase(trainingCase)
            cases.append(trainingCase)

            let quest = Quest(
                trainingCaseId: trainingCase.id,
                type: .main,
                title: "验证 \(dayOffset)",
                whyItMatters: "Fixture",
                completionCriteria: "记录一个可检查结果",
                expectedResistance: "none",
                reflectionQuestion: "what changed?",
                status: .completed
            )
            try await questRepository.saveQuests(
                [quest],
                sourceDailyEntryId: entry.id,
                trainingCaseId: trainingCase.id
            )
            quests.append(quest)
        }

        for index in quests.indices {
            let verificationSourceEntry = index == 0 ? entries[1].id : entries[index].id
            try await verificationRepository.saveVerification(
                Verification(
                    questId: quests[index].id,
                    questTitle: quests[index].title,
                    sourceDailyEntryId: verificationSourceEntry,
                    completion: .done,
                    valueRating: .high,
                    evidenceText: "Observed \(index)",
                    calibrationNote: "Calibration \(index)"
                )
            )
        }

        try await lensRepository.saveLensSession(
            LensSession(
                dailyEntryId: entries[0].id,
                trainingCaseId: cases[0].id,
                selectedLens: .evidenceCheck,
                questions: [
                    ReflectionQuestion(
                        question: "What evidence changed the judgment?",
                        whyItMatters: "It keeps the evidence traceable.",
                        answer: "A concrete result."
                    )
                ]
            )
        )

        let store = AppStore(
            dailyEntryRepository: entryRepository,
            thinkingCardRepository: cardRepository,
            questRepository: questRepository,
            verificationRepository: verificationRepository,
            lensSessionRepository: lensRepository,
            metricSnapshotRepository: snapshotRepository,
            metricContributionRepository: contributionRepository,
            trainingCaseRepository: caseRepository,
            trainingCaseSessionRepository: sessionRepository,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        await store.loadPersistedState()

        let firstRecord = try XCTUnwrap(store.historyRecords.first { $0.draft.id == entries[0].id })
        let secondRecord = try XCTUnwrap(store.historyRecords.first { $0.draft.id == entries[1].id })
        XCTAssertTrue(firstRecord.caseRecords.contains { record in
            record.trainingCase.id == cases[0].id &&
                record.verifications.contains { $0.questId == quests[0].id }
        })
        XCTAssertFalse(secondRecord.allVerifications.contains { $0.questId == quests[0].id })

        XCTAssertFalse(store.growthSnapshot.canDisplayScores)
        let snapshot = try await snapshotRepository.latestSnapshot()
        XCTAssertNil(snapshot)
        let firstCase = try XCTUnwrap(firstRecord.caseRecords.first { $0.trainingCase.id == cases[0].id })
        XCTAssertEqual(firstCase.lensSession?.selectedLens, .evidenceCheck)
        XCTAssertEqual(firstCase.lensSession?.questions.first?.answer, "A concrete result.")
        XCTAssertTrue(firstRecord.growthContributions.isEmpty)
    }

    @MainActor
    func testManualTrainingCaseRepairsMissingPrescriptionAndKeepsLocalQuestionsCaseScoped() async throws {
        let entry = DailyEntryDraft(
            rawText: "Do not leak this unrelated sibling material.",
            state: .capture
        )
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        let cardRepository = SQLiteThinkingCardRepository(database: database)
        let caseRepository = SQLiteTrainingCaseRepository(database: database)
        let sessionRepository = SQLiteTrainingCaseSessionRepository(database: database)
        let lensRepository = SQLiteLensSessionRepository(database: database)
        try await entryRepository.saveDraft(entry)

        let store = AppStore(
            todayDraft: entry,
            dailyEntryRepository: entryRepository,
            thinkingCardRepository: cardRepository,
            questRepository: SQLiteQuestRepository(database: database),
            lensSessionRepository: lensRepository,
            trainingCaseRepository: caseRepository,
            trainingCaseSessionRepository: sessionRepository,
            trainingCaseRelationshipRepository: SQLiteTrainingCaseRelationshipRepository(database: database),
            guidanceRepository: SQLiteGuidanceRepository(database: database),
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false,
            trainingCasesVNextEnabled: true
        )

        await store.addManualTrainingCase(title: "Signup flow")
        let trainingCase = try XCTUnwrap(store.trainingCases.first)
        let createdSession = try await sessionRepository.session(for: trainingCase.id)
        var brokenSession = try XCTUnwrap(createdSession)
        XCTAssertNotNil(brokenSession.trainingPrescription)
        brokenSession.trainingPrescription = nil
        try await sessionRepository.saveSession(brokenSession)

        await store.openTrainingCase(trainingCase.id)

        XCTAssertEqual(store.todayDraft.state, .selectLens)
        XCTAssertNotNil(store.trainingPrescription)
        let persistedRepairedSession = try await sessionRepository.session(for: trainingCase.id)
        let repairedSession = try XCTUnwrap(persistedRepairedSession)
        XCTAssertNotNil(repairedSession.trainingPrescription)

        store.acceptTrainingPrescription()
        store.submitTodayStep()

        for _ in 0..<20 where store.todayDraft.state != .answerQuestions {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertFalse(store.questions.isEmpty)
        XCTAssertFalse(String(describing: store.questions).contains("unrelated sibling material"))
    }

    private func makeQuestFixture() async throws -> (entry: DailyEntryDraft, trainingCase: TrainingCase, quest: Quest) {
        let entry = DailyEntryDraft(rawText: "fixture")
        try await SQLiteDailyEntryRepository(database: database).saveDraft(entry)
        let trainingCase = TrainingCase(dailyEntryId: entry.id, title: "Fixture", status: .awaitingVerification)
        try await SQLiteTrainingCaseRepository(database: database).saveCase(trainingCase)
        let quest = makeQuest(caseId: trainingCase.id, title: "Verify fixture")
        try await SQLiteQuestRepository(database: database).saveQuests(
            [quest],
            sourceDailyEntryId: entry.id,
            trainingCaseId: trainingCase.id
        )
        return (entry, trainingCase, quest)
    }

    private func makeQuest(caseId: UUID, title: String) -> Quest {
        Quest(
            trainingCaseId: caseId,
            type: .main,
            title: title,
            whyItMatters: "why",
            completionCriteria: "observable result",
            expectedResistance: "none",
            reflectionQuestion: "what changed?",
            calibrationTarget: "target",
            status: .active,
            verificationDueAt: .now
        )
    }

    private func makeVerification(quest: Quest, entryId: UUID) -> Verification {
        Verification(
            questId: quest.id,
            questTitle: quest.title,
            sourceDailyEntryId: entryId,
            completion: .done,
            valueRating: .high,
            judgmentUpdate: .adjusted,
            evidenceText: "Observed result",
            calibrationNote: "Updated from evidence"
        )
    }

    private func coachAnswerReviewContext(
        caseId: UUID,
        card: ThinkingCard,
        question: ReflectionQuestion
    ) -> CoachAnswerReviewContext {
        CoachAnswerReviewContext(
            caseId: caseId,
            caseTitle: "当前事项",
            mode: .standard,
            cards: [card],
            questions: [question],
            previousTurn: CoachTurnState(
                phase: .fillEvidenceGap,
                readiness: .notReady,
                recommendedMove: .surfaceEvidenceGap,
                reason: "缺事实",
                openEvidenceGaps: [.missingObservation],
                baselineChecks: [],
                decisionSource: .coachRecommended,
                policyVersion: "fixture",
                turnSummary: "fixture"
            )
        )
    }

    private func coachAnswerReviewJSON(refs: [String], userBoundary: String? = nil) -> String {
        let encodedRefs = refs.map { "\"\($0)\"" }.joined(separator: ",")
        let boundaryField = userBoundary.map { ",\"user_boundary\":\"\($0)\"" } ?? ""
        return """
        {"readiness":"not_ready","recommended_move":"surface_evidence_gap","open_evidence_gaps":["missing_observation"],"reason":"回答仍缺少可核对的来源。","turn_summary":"判断更清楚，但证据尚未闭合。","coach_critique":"你给出了方向，还需要一条可核对事实。","repaired_material":"明确了判断。","missing_material":"缺少可回查的观察。","proceed_line":"补充观察，或由你选择带着缺口继续。","ability_gap":"把判断和事实分开。","training_output":"写出可核对的来源。","self_check":"别人能找到你引用的事实。","training_target":"证据纪律。","next_repair_question":"哪条记录能直接核对这个判断？"\(boundaryField),"experience_replay_decision":"比较旧经验条件。","experience_replay_prompt":"旧经验的哪个条件不同？","judgment_sentence_prompt":"基于什么事实，我暂时相信什么。","reference_suggestion":"先写事实，再写判断。","reference_example":"基于「事实」，我暂时判断「……」。","source_refs":[\(encodedRefs)]}
        """
    }

    func testReflectionStateMigrationPreservesExistingSessionWithoutInventingReview() async throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue, upTo: "v70_mentor_benefit_feedback")
        let entryID = UUID(), caseID = UUID(), sessionID = UUID()
        try await queue.write { db in
            try db.execute(sql: "INSERT INTO daily_entries (id, schema_version, date, raw_text, session_mode, state, created_at, updated_at) VALUES (?, 1, ?, ?, ?, ?, ?, ?)",
                arguments: [entryID.uuidString, "2026-10-17T00:00:00Z", "旧记录", SessionMode.standard.rawValue, DailyLoopState.answerQuestions.rawValue, "2026-10-17T00:00:00Z", "2026-10-17T00:00:00Z"])
            try db.execute(sql: "INSERT INTO training_cases (id, daily_entry_id, title, status, sort_order, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?, ?)",
                arguments: [caseID.uuidString, entryID.uuidString, "旧事项", TrainingCaseStatus.inProgress.rawValue, TrainingCaseCreatedBy.user.rawValue, "2026-10-17T00:00:00Z", "2026-10-17T00:00:00Z"])
            try db.execute(sql: "INSERT INTO training_case_sessions (id, case_id, loop_state, session_mode, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                arguments: [sessionID.uuidString, caseID.uuidString, DailyLoopState.answerQuestions.rawValue, SessionMode.standard.rawValue, "2026-10-17T00:00:00Z", "2026-10-17T00:00:00Z"])
        }
        try AppDatabase.makeMigrator().migrate(queue)
        let migratedDB = try AppDatabase(dbQueue: queue)
        let migrated = try await SQLiteTrainingCaseSessionRepository(database: migratedDB).session(for: caseID)
        XCTAssertEqual(migrated?.id, sessionID)
        XCTAssertEqual(migrated?.loopState, .answerQuestions)
        XCTAssertNil(migrated?.reflectionState)
    }

    @MainActor
    func testReturnToTodayOverviewPreservesLensFreeAnswersAndStoppedReview() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        store.todayDraft.state = .answerQuestions
        store.todayDraft.selectedLens = nil
        let question = ReflectionQuestion(question: "看到什么？", whyItMatters: "区分原因。", answer: "只有一次，没有其他记录，今天先不继续。")
        store.questions = [question]
        await store.returnToTodayOverview()
        let loadedSession = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        let saved = try XCTUnwrap(loadedSession)
        XCTAssertEqual(saved.reflectionState?.questions, [question])
        XCTAssertNil(saved.selectedLensId)
        XCTAssertTrue(store.isTodayOverviewPresented)
        XCTAssertNil(store.activeTrainingCase)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.questions, [question])
        XCTAssertNil(store.todayDraft.selectedLens)

        let card = try XCTUnwrap(store.thinkingCards.first)
        let response = try reviewJSONWithEmptyOptionalGuidance(coachAnswerReviewJSON(refs: [question.id.uuidString], userBoundary: "stop"))
        let decision = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(),
            llmClient: GuidanceFixtureLLMClient(response: response)).review(
                context: coachAnswerReviewContext(caseId: fixture.trainingCase.id, card: card, question: question))
        var snapshot = saved
        snapshot.reflectionState = CoachReflectionState(questions: [question], reviewTurn: decision.turn,
            reviewFeedback: decision.feedback, referenceSuggestion: nil, promptRunID: decision.promptRunId)
        await store.returnToTodayOverview()
        try await fixture.sessionRepository.saveSession(snapshot)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertTrue(store.coachAnswerTrainingFeedback?.hasStopped == true)
        XCTAssertTrue(store.coachAnswerTrainingFeedback?.experienceReplayPrompt.isEmpty == true)
        XCTAssertEqual(store.coachAnswerFeedbackPreview, decision.turn)
        XCTAssertEqual(store.questions, [question])
    }

    @MainActor
    private func makeAnswerRetryFixture() async throws -> (store: AppStore, client: AnswerReviewRetryClient, question: ReflectionQuestion, response: Data) {
        let client = AnswerReviewRetryClient()
        let traced = PromptTracingLLMClient(base: client,
            repository: SQLitePromptRunRepository(database: database), modelProvider: "synthetic", modelName: "review-retry")
        let fixture = try await makeCoachFeedbackStore(answerReviewService:
            CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: traced,
                coachPromptTurnRepository: SQLiteCoachPromptTurnRepository(database: database)))
        let store = fixture.store
        let question = ReflectionQuestion(question: "哪些是观察，哪些是推测？", whyItMatters: "区分意图。",
            answer: "晚交是观察，故意是推测，原因还不知道。")
        let card = try XCTUnwrap(store.thinkingCards.first)
        let response = try reviewJSONWithEmptyOptionalGuidance(coachAnswerReviewJSON(refs: [question.id.uuidString]))
        let decision = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(),
            llmClient: GuidanceFixtureLLMClient(response: response)).review(
                context: coachAnswerReviewContext(caseId: fixture.trainingCase.id, card: card, question: question))
        store.todayDraft.state = .answerQuestions
        store.questions = [question]
        await store.returnToTodayOverview()
        let loaded = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        var session = try XCTUnwrap(loaded)
        var previousTurn = decision.turn
        previousTurn.reason = "上轮模型指出尚缺观察，等待用户补充。"
        session.reflectionState = CoachReflectionState(questions: [question], reviewTurn: previousTurn,
            reviewFeedback: decision.feedback, referenceSuggestion: nil, promptRunID: decision.promptRunId)
        try await fixture.sessionRepository.saveSession(session)
        await store.openTrainingCase(fixture.trainingCase.id)
        return (store, client, question, Data(response.utf8))
    }

    @MainActor
    func testAnswerReviewWithoutPriorDiagnosisUsesCurrentAnswersAndHonestMissingContext() async throws {
        let client = AnswerReviewRetryClient()
        let traced = PromptTracingLLMClient(base: client, repository: SQLitePromptRunRepository(database: database),
            modelProvider: "synthetic", modelName: "no-prior-review")
        let fixture = try await makeCoachFeedbackStore(answerReviewService:
            CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: traced,
                coachPromptTurnRepository: SQLiteCoachPromptTurnRepository(database: database)))
        let store = fixture.store
        store.todayDraft.state = .answerQuestions
        let question = ReflectionQuestion(question: "观察和推测分别是什么？", whyItMatters: "区分原因。", answer: "未完成是事实，原因未知。")
        store.questions = [question]
        XCTAssertNil(store.coachTurnState)
        store.submitCoachAnswerReview()
        for _ in 0..<100 where client.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(client.requests.map(\.prompt.id), [.reviewCoachAnswer])
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertTrue(request.contextPayload?.currentInput.rawText?.contains("previous_assessment_available=false") == true)
        XCTAssertTrue(request.contextPayload?.currentInput.rawText?.contains(question.answer) == true)
        client.resolveAll(with: .success(Data(try reviewJSONWithEmptyOptionalGuidance(
            coachAnswerReviewJSON(refs: [question.id.uuidString])).utf8)))
        for _ in 0..<100 where store.isAIRunning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(store.coachAnswerTrainingFeedback)
        XCTAssertEqual(store.questions, [question])
    }

    @MainActor
    func testRestoredReviewCanContinueAfterAnswerEditWithoutLosingPreviousTurn() async throws {
        let fixture = try await makeAnswerRetryFixture()
        let store = fixture.store
        XCTAssertNotNil(store.coachTurnState, "Restore the previous model turn for the next exchange")
        store.updateQuestionAnswer(questionID: fixture.question.id, answer: "我补充了原话，意图仍未知。")
        let caseID = try XCTUnwrap(store.activeTrainingCase?.id)
        await store.saveAnswerReviewAndReturn()
        await store.openTrainingCase(caseID)
        XCTAssertEqual(store.questions.first?.answer, "我补充了原话，意图仍未知。")
        XCTAssertNotNil(store.coachTurnState)
        XCTAssertNil(store.coachAnswerTrainingFeedback, "Old feedback is context, not a review of the changed answer")
        store.submitCoachAnswerReview()
        for _ in 0..<100 where fixture.client.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(fixture.client.requests.map(\.prompt.id), [.reviewCoachAnswer])
        store.cancelCurrentAIRequest()
        fixture.client.resolveAll(with: .success(fixture.response))
    }

    @MainActor
    func testCancelledAnswerReviewRetriesReviewAndIgnoresLateResponseWithoutReplacingAnswers() async throws {
        let fixture = try await makeAnswerRetryFixture()
        let store = fixture.store
        let caseID = store.activeTrainingCase?.id
        store.submitCoachAnswerReview()
        for _ in 0..<100 where fixture.client.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(store.isAIRunning, "Review must expose waiting and cancellation controls")
        store.cancelCurrentAIRequest()
        XCTAssertFalse(store.isAIRunning)
        XCTAssertTrue(store.canRetryCurrentAI)
        store.retryCurrentAIStep()
        store.retryCurrentAIStep() // A double tap must not create another request.
        for _ in 0..<100 where fixture.client.requests.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(fixture.client.requests.map(\.prompt.id), [.reviewCoachAnswer, .reviewCoachAnswer])
        guard fixture.client.requests.count == 2 else {
            store.cancelCurrentAIRequest()
            fixture.client.resolveAll(with: .success(fixture.response))
            return
        }
        fixture.client.resolve(0, with: .success(fixture.response))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(store.coachAnswerTrainingFeedback, "Cancelled response cannot become the current review")
        XCTAssertTrue(store.isAIRunning, "Old request cleanup cannot finish the retry")
        fixture.client.resolve(1, with: .success(fixture.response))
        for _ in 0..<100 where store.isAIRunning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isAIRunning)
        XCTAssertFalse(store.canRetryCurrentAI)
        XCTAssertNotNil(store.coachAnswerTrainingFeedback)
        XCTAssertEqual(store.coachTurnState, store.coachAnswerFeedbackPreview, "The next turn uses the latest model review")
        XCTAssertEqual(store.questions, [fixture.question])
        XCTAssertEqual(store.activeTrainingCase?.id, caseID)
        XCTAssertNil(store.todayDraft.selectedLens)
        XCTAssertTrue(store.quests.isEmpty)
    }

    @MainActor
    func testFailedAnswerReviewKeepsAnswersAndRetriesTheSameOperation() async throws {
        let fixture = try await makeAnswerRetryFixture()
        let store = fixture.store
        store.submitCoachAnswerReview()
        for _ in 0..<100 where fixture.client.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        fixture.client.resolveAll(with: .failure(URLError(.timedOut)))
        for _ in 0..<100 where !store.canRetryCurrentAI { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(store.canRetryCurrentAI)
        XCTAssertNotNil(store.lastAIFailureMessage)
        XCTAssertEqual(store.questions, [fixture.question])
        store.retryCurrentAIStep()
        for _ in 0..<100 where fixture.client.requests.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(fixture.client.requests.map(\.prompt.id), [.reviewCoachAnswer, .reviewCoachAnswer])
        fixture.client.resolveAll(with: .success(fixture.response))
        for _ in 0..<100 where store.isAIRunning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(store.coachAnswerTrainingFeedback)
        XCTAssertNil(store.lastAIFailureMessage)
        XCTAssertEqual(store.questions, [fixture.question])
    }

    @MainActor
    func testReviewedUncertaintyPrimarySavesWithoutActionOrFalseReadinessAndRestores() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        store.todayDraft.state = .answerQuestions
        store.todayDraft.selectedLens = nil
        let question = ReflectionQuestion(question: "哪些是观察，哪些是推测？", whyItMatters: "区分意图。",
            answer: "晚交是观察，故意是推测，原因还不知道。")
        store.questions = [question]
        let card = try XCTUnwrap(store.thinkingCards.first)
        let response = try reviewJSONWithEmptyOptionalGuidance(coachAnswerReviewJSON(refs: [question.id.uuidString], userBoundary: "continue"))
        let client = GuidanceFixtureLLMClient(response: response)
        let decision = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            .review(context: coachAnswerReviewContext(caseId: fixture.trainingCase.id, card: card, question: question))
        await store.returnToTodayOverview()
        let loaded = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        var snapshot = try XCTUnwrap(loaded)
        snapshot.reflectionState = CoachReflectionState(questions: [question], reviewTurn: decision.turn,
            reviewFeedback: decision.feedback, referenceSuggestion: nil, promptRunID: decision.promptRunId)
        try await fixture.sessionRepository.saveSession(snapshot)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertTrue(store.answerReviewPrimaryActionSaves)
        XCTAssertFalse(store.isTodayPrimaryActionDisabled, "Saving uncertainty must not require an action target")
        XCTAssertFalse(store.canChooseAnswerValidation, "There is no validation target in this reflection")
        XCTAssertFalse(store.coachAnswerTrainingFeedback?.hasStopped ?? true)
        let statusBeforeSaving = store.activeTrainingCase?.status
        store.submitTodayStep()
        store.submitTodayStep()
        for _ in 0..<200 where !store.isTodayOverviewPresented { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(store.isTodayOverviewPresented)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.questions, [question])
        XCTAssertNil(store.todayDraft.selectedLens)
        XCTAssertEqual(store.coachAnswerTrainingFeedback?.readiness, .notReady)
        XCTAssertEqual(store.coachAnswerFeedbackPreview?.openEvidenceGaps, [.missingObservation])
        XCTAssertFalse(store.coachAnswerTrainingFeedback?.canProceedToValidation ?? true)
        XCTAssertFalse(store.coachAnswerTrainingFeedback?.hasStopped ?? true)
        XCTAssertTrue(store.quests.isEmpty)
        XCTAssertEqual(client.promptIDs, [.reviewCoachAnswer], "Saving and reopening do not call the model")
        let savedCase = try await SQLiteTrainingCaseRepository(database: database).caseRecord(id: fixture.trainingCase.id)
        XCTAssertEqual(savedCase?.status, statusBeforeSaving, "Saving does not complete the real matter")
        try await database.dbQueue.read { db in
            for table in ["quests", "principle_assets", "metric_contributions"] {
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)"), 0, table)
            }
        }
    }

    @MainActor
    func testUnansweredRepairCanBeSavedWithoutForcingAnAnswer() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        store.todayDraft.state = .answerQuestions
        store.todayDraft.selectedLens = nil
        let questions = [ReflectionQuestion(question: "看到什么？", whyItMatters: "区分原因。", answer: "一次晚交。"),
            ReflectionQuestion(question: "原约定具体是哪天？", isRepairQuestion: true, whyItMatters: "核对约定。")]
        store.questions = questions
        XCTAssertTrue(store.hasUnansweredRepairQuestion)
        XCTAssertFalse(store.answerReviewPrimaryActionSaves)
        XCTAssertTrue(store.canSaveAnswerReview)
        await store.saveAnswerReviewAndReturn()
        XCTAssertTrue(store.isTodayOverviewPresented)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.questions, questions)
        XCTAssertTrue(store.hasUnansweredRepairQuestion)
        XCTAssertTrue(store.quests.isEmpty)
        XCTAssertNil(store.coachAnswerTrainingFeedback, "Saving must not fabricate a review")
    }

    @MainActor
    func testGuidanceCoalescesIdenticalPendingAndCompletedDecisions() async throws {
        let client = GuidanceFixtureLLMClient(response: #"{"decision":"show","hint_id":"judgment.observable_evidence","reason":"测试展示生命周期"}"#)
        client.suspendBeforeResponse = true
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: nil, guidanceClient: client)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(client.responseGate)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(client.requests.count, 1, "Reading unchanged material must reuse the pending decision")
        // Release every fixture request even on the failing pre-fix path.
        gate.resume()
        if client.requests.count > 1, let otherGate = client.responseGate { otherGate.resume() }
        client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        client.suspendBeforeResponse = false
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(client.requests.count, 1, "A validated result should be reused for identical material")
        XCTAssertNotNil(fixture.store.activeGuidance)
    }

    @MainActor
    func testGuidanceLateDecisionCannotReappearAfterOverview() async throws {
        let client = GuidanceFixtureLLMClient(response: #"{"decision":"show","hint_id":"judgment.observable_evidence","reason":"测试过期结果"}"#)
        client.suspendBeforeResponse = true
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: nil, guidanceClient: client)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(client.responseGate)
        await fixture.store.returnToTodayOverview()
        gate.resume(); client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(fixture.store.activeGuidance)
    }

    @MainActor
    func testGuidanceRejectsChangedMaterialWithSameCardID() async throws {
        let client = GuidanceFixtureLLMClient(response: #"{"decision":"show","hint_id":"judgment.observable_evidence","reason":"测试过期材料"}"#)
        client.suspendBeforeResponse = true
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: nil, guidanceClient: client)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(client.responseGate)
        fixture.store.thinkingCards[0].body = "我已经弄清楚区别，现在只想保存结束。"
        gate.resume(); client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(fixture.store.activeGuidance)
    }

    @MainActor
    func testGuidanceHoldIsReusedButChangedAnswerRequestsFreshDecision() async throws {
        let client = GuidanceFixtureLLMClient(response: #"{"decision":"hold","hint_id":null,"reason":"已有说明，不再打断"}"#)
        let question = ReflectionQuestion(question: "哪些代价不会退？", whyItMatters: "区分可逆范围。", answer: "时间。")
        let reflection = CoachReflectionState(questions: [question], reviewTurn: nil, reviewFeedback: nil,
            referenceSuggestion: nil, promptRunID: nil, explanation: CoachExplanation(text: "可退学费，时间不能退。", sourceCardTitles: ["课程退款"]))
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: reflection, guidanceClient: client)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        try await Task.sleep(for: .milliseconds(30))
        await fixture.store.returnToTodayOverview()
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(client.requests.count, 1, "Hold is a validated decision, not an absence to retry")
        XCTAssertNil(fixture.store.activeGuidance)
        let initialRaw = try XCTUnwrap(client.requests.first?.contextPayload?.currentInput.rawText)
        let initialContext = try JSONDecoder().decode(GuidanceDecisionContext.self, from: Data(initialRaw.utf8))
        XCTAssertEqual(initialContext.reflection?.modelExplanation?.text, reflection.explanation?.text)
        fixture.store.updateQuestionAnswer(questionID: question.id, answer: "时间不能退，今天先到这里。")
        await fixture.store.returnToTodayOverview()
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(client.requests.count, 2, "New answers must not use the old hold")
        let raw = try XCTUnwrap(client.requests.last?.contextPayload?.currentInput.rawText)
        let context = try JSONDecoder().decode(GuidanceDecisionContext.self, from: Data(raw.utf8))
        XCTAssertEqual(context.reflection?.userQuestionsAndAnswers.first?.answer, "时间不能退，今天先到这里。")
        XCTAssertNil(context.reflection?.modelExplanation, "Editing the answer invalidates the prior explanation in the existing reflection contract")
    }

    @MainActor
    func testGuidanceFailureRemainsRetryableAndIsNotCached() async throws {
        let client = GuidanceFixtureLLMClient(response: "{}")
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: nil, guidanceClient: client)
        for _ in 0..<2 {
            await fixture.store.openTrainingCase(fixture.trainingCase.id)
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertNil(fixture.store.activeGuidance)
    }

    @MainActor
    func testGuidancePresentationReceiptStartsCooldownAcrossStoreRecreation() async throws {
        let client = GuidanceFixtureLLMClient(response: #"{"decision":"show","hint_id":"judgment.observable_evidence","reason":"测试展示回执"}"#)
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: nil, guidanceClient: client)
        let store = fixture.store
        let repository = SQLiteGuidanceRepository(database: database)
        await store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where store.activeGuidanceOfferID == nil { try await Task.sleep(for: .milliseconds(5)) }
        let offer = try XCTUnwrap(store.activeGuidanceOfferID)
        let before = try await repository.state(for: "judgment.observable_evidence")
        XCTAssertNil(before?.lastShownAt, "Selecting a hint is not presentation")
        await store.recordActiveGuidancePresentation(offerID: offer)
        let shown = try XCTUnwrap(store.guidanceStates.first?.lastShownAt)
        await store.recordActiveGuidancePresentation(offerID: offer)
        let repeated = try await repository.state(for: "judgment.observable_evidence")
        XCTAssertEqual(try XCTUnwrap(repeated?.lastShownAt).timeIntervalSince1970, shown.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertNotNil(store.activeGuidance, "Receipt alone should not make the displayed hint disappear")
        let restarted = AppStore(todayDraft: store.todayDraft,
            dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
            thinkingCardRepository: SQLiteThinkingCardRepository(database: database),
            lensSessionRepository: SQLiteLensSessionRepository(database: database),
            trainingCaseRepository: SQLiteTrainingCaseRepository(database: database),
            trainingCaseSessionRepository: SQLiteTrainingCaseSessionRepository(database: database),
            guidanceRepository: SQLiteGuidanceRepository(database: database), refreshesAIServiceFromKeychain: false,
            guidanceAIService: GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client), trainingCasesVNextEnabled: true)
        await restarted.loadPersistedState()
        await restarted.openTrainingCase(fixture.trainingCase.id)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertNil(restarted.activeGuidance)
    }

    func testDelayedGuidanceReceiptPreservesNewerPreferencesAndEvidence() async throws {
        let repository = SQLiteGuidanceRepository(database: database)
        let item = BuiltinGuidanceCatalog.items[1]
        let newer = Date.now
        let evidence = UUID()
        _ = try await repository.recordEvidence(for: item, verificationId: evidence, isCounterexample: false)
        _ = try await repository.updatePreference(for: item.hintId, snoozedUntil: newer.addingTimeInterval(1000), mastered: true, now: newer)
        let receipt = try await repository.recordPresentation(for: item.hintId, at: newer.addingTimeInterval(-500))
        XCTAssertEqual(receipt.status, .mastered)
        XCTAssertEqual(receipt.evidenceRefs, [evidence.uuidString])
        XCTAssertEqual(try XCTUnwrap(receipt.lastShownAt).timeIntervalSince1970, newer.timeIntervalSince1970, accuracy: 0.001)
    }

    @MainActor
    func testGuidanceCannotReappearAfterNoActionStageOrAnswerEdit() async throws {
        let client = GuidanceFixtureLLMClient(response: #"{"decision":"show","hint_id":"judgment.observable_evidence","reason":"测试停止边界"}"#)
        client.suspendBeforeResponse = true
        let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: nil, guidanceClient: client)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(client.responseGate)
        fixture.store.todayDraft.state = .reviewWithoutAction
        gate.resume(); client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(fixture.store.activeGuidance)
        client.suspendBeforeResponse = false
        fixture.store.todayDraft.state = .answerQuestions
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where fixture.store.activeGuidance == nil { try await Task.sleep(for: .milliseconds(5)) }
        let question = ReflectionQuestion(question: "哪些不能退？", whyItMatters: "区分退出代价。")
        fixture.store.questions = [question]
        fixture.store.updateQuestionAnswer(questionID: question.id, answer: "时间，先停在这里。")
        XCTAssertNil(fixture.store.activeGuidance)
    }

    func testLegacyGuidanceContextDecodesWithoutReflection() throws {
        let legacy = GuidanceDecisionContext(stage: .judgment, triggerKeys: [], candidates: [], states: [],
            currentCaseId: nil, currentCaseTitle: nil, evidenceSummary: "旧材料")
        let oldJSON = try JSONEncoder().encode(legacy)
        XCTAssertNil(try JSONDecoder().decode(GuidanceDecisionContext.self, from: oldJSON).reflection)
    }

    @MainActor
    func testRestoringSavedReflectionNeverRestartsInitialDiagnosis() async throws {
        for hasExplanation in [true, false] {
            let explanation = hasExplanation ? CoachExplanation(text: "退款能撤回金钱承诺，已花时间不能退回。", sourceCardTitles: ["课程退款"]) : nil
            let questions = hasExplanation ? [] : [ReflectionQuestion(question: "退款承诺覆盖哪些成本？", whyItMatters: "区分退出代价。", answer: "只退学费，不退已经投入的时间。")]
            let reflection = CoachReflectionState(questions: questions, reviewTurn: nil, reviewFeedback: nil,
                referenceSuggestion: nil, promptRunID: nil, explanation: explanation)
            let fixture = try await makeInitialDecisionRestoreFixture(state: .answerQuestions, reflection: reflection)
            await fixture.store.openTrainingCase(fixture.trainingCase.id)
            for _ in 0..<10 { await Task.yield() }
            XCTAssertTrue(fixture.client.requests.isEmpty, "Opening saved help is reading, not a new diagnosis")
            XCTAssertEqual(fixture.store.coachExplanation, explanation)
            XCTAssertEqual(fixture.store.questions, questions)
            XCTAssertEqual(fixture.store.todayDraft.state, .answerQuestions)
        }
    }

    @MainActor
    func testInitialDiagnosisCannotReplaceReflectionAfterUserAdvancesWithLens() async throws {
        let fixture = try await makeInitialDecisionRestoreFixture(state: .selectLens, reflection: nil)
        fixture.client.suspendBeforeResponse = true
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where fixture.client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(fixture.client.responseGate)
        fixture.store.todayDraft.selectedLens = .reversibleDecision
        let question = ReflectionQuestion(question: "哪些成本不能退款？", whyItMatters: "认识承诺边界。")
        fixture.store.questions = [question]
        fixture.store.submitTodayStep()
        XCTAssertEqual(fixture.store.todayDraft.state, .answerQuestions)
        gate.resume(); fixture.client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(fixture.store.coachTurnState, "A late initial assessment must not replace the current discussion")
        XCTAssertEqual(fixture.store.questions, [question])
        XCTAssertEqual(fixture.store.todayDraft.selectedLens, .reversibleDecision)
    }

    @MainActor
    func testInitialDiagnosisFailureAfterReturningDoesNotPolluteOverview() async throws {
        let fixture = try await makeInitialDecisionRestoreFixture(state: .selectLens, reflection: nil)
        fixture.client.suspendThenFail = true
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where fixture.client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(fixture.client.responseGate)
        await fixture.store.returnToTodayOverview()
        let message = fixture.store.todayLoopMessage
        gate.resume(); fixture.client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(fixture.store.isTodayOverviewPresented)
        XCTAssertEqual(fixture.store.todayLoopMessage, message, "An abandoned request must not add an error to another surface")
    }

    @MainActor
    func testInitialDiagnosisRejectsChangedCardTextWithSameIdentity() async throws {
        let fixture = try await makeInitialDecisionRestoreFixture(state: .selectLens, reflection: nil)
        fixture.client.suspendBeforeResponse = true
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where fixture.client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(fixture.client.responseGate)
        fixture.store.thinkingCards[0].body = "退款条款已改为不退款，原先的条件作废。"
        gate.resume(); fixture.client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(fixture.store.coachTurnState, "Matching source IDs do not make an old assessment current")
    }

    @MainActor
    func testChoosingLensDuringReassessmentPreservesUserChoice() async throws {
        let fixture = try await makeInitialDecisionRestoreFixture(state: .selectLens, reflection: nil)
        fixture.client.suspendBeforeResponse = true
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where fixture.client.responseGate == nil { try await Task.sleep(for: .milliseconds(5)) }
        let gate = try XCTUnwrap(fixture.client.responseGate)
        fixture.store.selectThinkingLens(.opportunityCost)
        XCTAssertEqual(fixture.store.todayDraft.state, .selectLens)
        gate.resume(); fixture.client.responseGate = nil
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(fixture.store.todayDraft.selectedLens, .opportunityCost)
        XCTAssertEqual(fixture.store.trainingPrescription?.finalLensId, "opportunityCost")
        XCTAssertEqual(fixture.store.trainingPrescription?.source, .userOverride)
        XCTAssertNil(fixture.store.coachTurnState)
    }

    @MainActor
    func testInitialDiagnosisStillRunsForUnfinishedLensSelection() async throws {
        let fixture = try await makeInitialDecisionRestoreFixture(state: .selectLens, reflection: nil)
        await fixture.store.openTrainingCase(fixture.trainingCase.id)
        for _ in 0..<200 where fixture.store.coachTurnState == nil { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(fixture.client.requests.map(\.prompt.id), [.diagnoseTrainingCase])
        XCTAssertNotNil(fixture.store.coachTurnState)
    }

    @MainActor
    private func makeInitialDecisionRestoreFixture(state: DailyLoopState, reflection: CoachReflectionState?, guidanceClient: GuidanceFixtureLLMClient? = nil) async throws ->
        (store: AppStore, trainingCase: TrainingCase, client: GuidanceFixtureLLMClient) {
        let entry = DailyEntryDraft(rawText: "退款条款的承诺边界", state: .capture)
        let trainingCase = TrainingCase(dailyEntryId: entry.id, title: "课程退款")
        let card = ThinkingCard(trainingCaseId: trainingCase.id, type: .decision, title: "课程退款",
            body: "报名一周内全额退款，但已花的时间不能退回。", isConfirmed: true)
        let entries = SQLiteDailyEntryRepository(database: database)
        let cards = SQLiteThinkingCardRepository(database: database)
        let cases = SQLiteTrainingCaseRepository(database: database)
        let sessions = SQLiteTrainingCaseSessionRepository(database: database)
        let prescription = TrainingPrescription(recommendedLensId: "reversibleDecision", recommendedPromptId: "reversible_decision",
            recommendationReason: "区分退出代价。", confidence: 0.7, policyVersion: "coach-decision.llm.v2",
            alternativeLensIds: [], baselineChecks: [], finalLensId: "reversibleDecision", source: .coachRecommended)
        try await entries.saveDraft(entry)
        try await cases.saveCase(trainingCase)
        try await cards.saveCards([card], dailyEntryId: entry.id, trainingCaseId: trainingCase.id)
        try await sessions.saveSession(TrainingCaseSession(caseId: trainingCase.id, loopState: state,
            selectedLensId: "reversibleDecision", trainingPrescription: prescription, reflectionState: reflection))
        let client = GuidanceFixtureLLMClient(response: try coachDecisionJSON(gaps: ["missing_constraint"], refs: [card.id.uuidString]))
        let store = AppStore(todayDraft: entry, dailyEntryRepository: entries, thinkingCardRepository: cards,
            questRepository: SQLiteQuestRepository(database: database), lensSessionRepository: SQLiteLensSessionRepository(database: database),
            trainingCaseRepository: cases, trainingCaseSessionRepository: sessions,
            trainingCaseRelationshipRepository: SQLiteTrainingCaseRelationshipRepository(database: database),
            guidanceRepository: SQLiteGuidanceRepository(database: database),
            refreshesAIServiceFromKeychain: false,
            guidanceAIService: guidanceClient.map { GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: $0) },
            coachDecisionAIService: CoachDecisionAIService(promptProvider: LocalPromptProvider(), llmClient: client),
            trainingCasesVNextEnabled: true)
        await store.loadPersistedState()
        return (store, trainingCase, client)
    }

    @MainActor
    func testDirectExplanationIsPresentedSavedRestoredAndClearedAcrossCases() async throws {
        let json = #"{"questions":[],"explanation":{"text":"晚交是观察，故意是推测；目前不知道原因。","source_card_titles":["报告晚交两天"]}}"#
        let client = GuidanceFixtureLLMClient(response: json)
        let fixture = try await makeCoachFeedbackStore(todayAIService:
            TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client))
        let store = fixture.store
        store.thinkingCards = [ThinkingCard(type: .fact, title: "报告晚交两天", body: "晚交两天，我觉得是故意的，请直接解释，不要追问。", isConfirmed: true)]
        store.todayDraft.state = .selectLens
        store.todayDraft.selectedLens = nil
        store.todayDraft.selectedCustomLensId = nil
        store.submitTodayStep()
        for _ in 0..<300 where store.coachExplanation == nil || store.isAIRunning { try await Task.sleep(for: .milliseconds(10)) }
        let explanation = try XCTUnwrap(store.coachExplanation)
        XCTAssertEqual(explanation.text, "晚交是观察，故意是推测；目前不知道原因。")
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertTrue(store.answerReviewPrimaryActionSaves)
        await store.saveAnswerReviewAndReturn()
        XCTAssertTrue(store.isTodayOverviewPresented)
        XCTAssertNil(store.coachExplanation)
        let saved = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        XCTAssertEqual(saved?.reflectionState?.explanation, explanation)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.coachExplanation, explanation)
        store.todayDraft.state = .selectLens
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertEqual(client.promptIDs, [.generateQuestions], "Returning to an explanation must not regenerate it")
        await store.returnToTodayOverview()
        await store.addManualTrainingCase(title: "另一件事")
        let other = try XCTUnwrap(store.trainingCases.first { $0.id != fixture.trainingCase.id })
        await store.openTrainingCase(other.id)
        XCTAssertNil(store.coachExplanation, "An interpretation belongs to its original matter")
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.coachExplanation, explanation)
        store.questions = []
        XCTAssertNil(store.coachExplanation, "Resetting the current turn invalidates its interpretation")
        XCTAssertTrue(store.quests.isEmpty)
        XCTAssertTrue(store.principles.isEmpty)
    }

    func testExplanationFingerprintIncludesTextAndSourcesAndPreservesLegacyFingerprint() {
        let a = CoachExplanation(text: "一种解释", sourceCardTitles: ["报告"])
        let b = CoachExplanation(text: "另一种解释", sourceCardTitles: ["报告"])
        let c = CoachExplanation(text: a.text, sourceCardTitles: ["排期"])
        XCTAssertEqual(CoachPromptOutputFingerprint.questionTurn([], explanation: nil), CoachPromptOutputFingerprint.questions([]))
        XCTAssertNotEqual(CoachPromptOutputFingerprint.questionTurn([], explanation: a), CoachPromptOutputFingerprint.questionTurn([], explanation: b))
        XCTAssertNotEqual(CoachPromptOutputFingerprint.questionTurn([], explanation: a), CoachPromptOutputFingerprint.questionTurn([], explanation: c))
    }

    @MainActor
    func testNoQuestionsPrimarySavesWithoutGeneratingValidation() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        store.todayDraft.state = .answerQuestions
        store.questions = []
        XCTAssertTrue(store.answerReviewPrimaryActionSaves)
        XCTAssertFalse(store.isTodayPrimaryActionDisabled)
        store.submitTodayStep()
        for _ in 0..<200 where !store.isTodayOverviewPresented { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(store.isTodayOverviewPresented)
        let saved = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        XCTAssertEqual(saved?.loopState, .answerQuestions)
        XCTAssertTrue(saved?.reflectionState?.questions.isEmpty ?? false)
        XCTAssertTrue(store.quests.isEmpty)
    }

    @MainActor
    func testCurrentNoLensChoiceOverridesLegacyLensRowWithoutDeletingAnswers() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        let legacyQuestion = ReflectionQuestion(question: "旧透镜问题", whyItMatters: "旧视角", answer: "旧回答")
        let lenses = SQLiteLensSessionRepository(database: database)
        try await lenses.saveLensSession(.init(dailyEntryId: store.todayDraft.id,
            trainingCaseId: fixture.trainingCase.id, selectedLens: .opposingView, questions: [legacyQuestion]))
        let current = ReflectionQuestion(question: "当前材料的问题", whyItMatters: "保留当前问题", answer: "当前回答，暂时未知。")
        store.todayDraft.state = .answerQuestions
        store.todayDraft.selectedLens = nil
        store.todayDraft.selectedCustomLensId = nil
        store.questions = [current]
        await store.returnToTodayOverview()
        let saved = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        XCTAssertNil(saved?.selectedLensId)
        XCTAssertEqual(saved?.reflectionState?.questions, [current])
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertNil(store.todayDraft.selectedLens, "A stale LensSession must not reinstate a lens explicitly absent from the current reflection")
        XCTAssertNil(store.todayDraft.selectedCustomLensId)
        XCTAssertEqual(store.questions, [current])
        let old = try await lenses.lensSession(forTrainingCaseId: fixture.trainingCase.id)
        XCTAssertEqual(old?.selectedLens, .opposingView, "Keep the old record; precedence is not deletion")
    }

    @MainActor
    func testReturnToTodayOverviewKeepsPageAndAnswersWhenSavingFails() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        store.todayDraft.state = .answerQuestions
        store.questions = [ReflectionQuestion(question: "看到什么？", whyItMatters: "区分原因。", answer: "暂时不记得。")]
        let before = store.questions
        try await database.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_review_exit BEFORE INSERT ON training_case_sessions BEGIN SELECT RAISE(ABORT, 'synthetic disk failure'); END")
        }
        await store.saveAnswerReviewAndReturn()
        XCTAssertEqual(store.activeTrainingCase?.id, fixture.trainingCase.id)
        XCTAssertFalse(store.isTodayOverviewPresented)
        XCTAssertEqual(store.questions, before)
        XCTAssertTrue(store.todayLoopMessage.contains("已保留当前页面"))
        try await database.dbQueue.write { db in try db.execute(sql: "DROP TRIGGER fail_review_exit") }
        await store.saveAnswerReviewAndReturn()
        XCTAssertTrue(store.isTodayOverviewPresented)
        let saved = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        XCTAssertEqual(saved?.reflectionState?.questions, before)
    }

    @MainActor
    func testSaveValidationEndsWithoutRequestingPrincipleAndRestoresSavedAction() async throws {
        let client = GuidanceFixtureLLMClient(response: "{}")
        let fixture = try await makeCoachFeedbackStore(todayAIService:
            TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client))
        let store = fixture.store
        store.todayDraft.state = .reviewQuests
        let quest = completionFixtureQuest()
        store.quests = [quest]
        store.submitTodayStep()
        XCTAssertTrue(store.isSavingTodayCompletion)
        store.submitTodayStep() // A second tap must not reset the completed day.
        await store.returnToTodayOverview() // Navigation must not clear a pending save.
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isSavingTodayCompletion)
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
        XCTAssertTrue(store.isTodayOverviewPresented)
        XCTAssertNil(store.activeTrainingCase)
        XCTAssertTrue(client.promptIDs.isEmpty)
        let savedQuests = try await SQLiteQuestRepository(database: database).quests(forTrainingCaseId: fixture.trainingCase.id)
        XCTAssertEqual(savedQuests.map(\.id), [quest.id])
        XCTAssertEqual(savedQuests.first?.status, .active)
        let session = try await fixture.sessionRepository.session(for: fixture.trainingCase.id)
        XCTAssertEqual(session?.loopState, .sessionComplete)
        let savedCase = try await SQLiteTrainingCaseRepository(database: database).caseRecord(id: fixture.trainingCase.id)
        XCTAssertEqual(savedCase?.status, .awaitingVerification)
    }

    @MainActor
    func testSaveValidationFailureRetainsPageAndDoesNotRequestPrincipleThenRetries() async throws {
        let client = GuidanceFixtureLLMClient(response: "{}")
        let fixture = try await makeCoachFeedbackStore(todayAIService:
            TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client))
        let store = fixture.store
        store.todayDraft.state = .reviewQuests
        let quest = completionFixtureQuest()
        store.quests = [quest]
        try await database.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_validation_save BEFORE INSERT ON quests BEGIN SELECT RAISE(ABORT, 'synthetic disk failure'); END")
        }
        store.submitTodayStep()
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isSavingTodayCompletion)
        XCTAssertEqual(store.todayDraft.state, .reviewQuests)
        XCTAssertEqual(store.activeTrainingCase?.id, fixture.trainingCase.id)
        XCTAssertFalse(store.isTodayOverviewPresented)
        XCTAssertEqual(store.quests, [quest])
        XCTAssertTrue(store.todayLoopMessage.contains("已保留当前页面"))
        XCTAssertTrue(client.promptIDs.isEmpty)
        try await database.dbQueue.write { db in try db.execute(sql: "DROP TRIGGER fail_validation_save") }
        store.submitTodayStep()
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
        let saved = try await SQLiteQuestRepository(database: database).quests(forTrainingCaseId: fixture.trainingCase.id)
        XCTAssertEqual(saved.map(\.id), [quest.id])
    }

    @MainActor
    func testPrincipleExtractionRequiresExplicitSecondaryAction() async throws {
        let client = GuidanceFixtureLLMClient(response: "{\"principle_candidate\":null}")
        let fixture = try await makeCoachFeedbackStore(todayAIService:
            TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client))
        let store = fixture.store
        store.todayDraft.state = .reviewQuests
        store.quests = [completionFixtureQuest()]
        store.saveValidationAndReviewPrinciple()
        for _ in 0..<200 where store.isSavingTodayCompletion || store.todayDraft.state != .extractPrinciple {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(store.todayDraft.state, .extractPrinciple)
        XCTAssertEqual(client.promptIDs, [.extractPrinciple])
        XCTAssertTrue(store.principles.isEmpty)
    }

    @MainActor
    func testUnconfirmedPrincipleEditAndSkipDoNotTouchSavedAssets() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        let repo = SQLitePrincipleRepository(database: database)
        let saved = completionFixturePrinciple(title: "已确认的旧原则")
        try await repo.savePrinciple(saved, sourceDailyEntryId: store.todayDraft.id)
        store.todayDraft.state = .extractPrinciple
        let candidate = completionFixturePrinciple(title: "AI 尚未确认的候选")
        store.principles = [candidate]
        store.updatePrinciple(candidate.id, title: "编辑中的候选", summary: candidate.summary,
            triggerContext: candidate.triggerContext, actionsText: "记录结果",
            successCriteria: candidate.successCriteria, exceptions: candidate.exceptions)
        await store.returnToTodayOverview()
        let beforeSkip = try await repo.activePrinciples()
        XCTAssertEqual(beforeSkip.map(\.id), [saved.id])
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.principles.first?.title, "编辑中的候选")
        store.skipPrinciple()
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        await store.returnToTodayOverview()
        let afterSkip = try await repo.activePrinciples()
        XCTAssertEqual(afterSkip.map(\.id), [saved.id])
    }

    @MainActor
    func testPrincipleAssetSaveFailureRetainsCandidateAndRetriesWithoutDeletingOtherAssets() async throws {
        let fixture = try await makeCoachFeedbackStore()
        let store = fixture.store
        let repo = SQLitePrincipleRepository(database: database)
        let saved = completionFixturePrinciple(title: "已保存原则")
        try await repo.savePrinciple(saved, sourceDailyEntryId: store.todayDraft.id)
        let candidate = completionFixturePrinciple(title: "待保存候选")
        store.todayDraft.state = .extractPrinciple
        store.principles = [candidate]
        try await database.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_principle_save BEFORE INSERT ON principle_assets BEGIN SELECT RAISE(ABORT, 'synthetic principle write failure'); END")
        }
        store.submitTodayStep()
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(store.todayDraft.state, .extractPrinciple)
        XCTAssertEqual(store.principles, [candidate])
        XCTAssertFalse(store.isTodayOverviewPresented)
        await store.returnToTodayOverview()
        try await database.dbQueue.write { db in try db.execute(sql: "DROP TRIGGER fail_principle_save") }
        await store.openTrainingCase(fixture.trainingCase.id)
        store.submitTodayStep()
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        let assets = try await repo.activePrinciples()
        XCTAssertEqual(Set(assets.map(\.id)), Set([saved.id, candidate.id]))
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
    }

    @MainActor
    func testGeneratedPrincipleStaysDraftAcrossCaseSwitchAndFreshStoreRestoration() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"principle_candidate":{"title":"先确认负责人再执行","summary":"执行前先写清负责人和验收标准。",
        "trigger_context":"跨角色交接时","actions":["写下唯一负责人并确认","写下可以检查的验收标准"],
        "success_criteria":"执行前记录里能看到唯一负责人和可检查的验收标准。",
        "exceptions":"低风险同步可简化。","source_card_titles":["交接记录"]}}
        """)
        let fixture = try await makeCoachFeedbackStore(todayAIService:
            TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client))
        let store = fixture.store
        store.todayDraft.state = .reviewQuests
        store.thinkingCards = [ThinkingCard(trainingCaseId: fixture.trainingCase.id,
            type: .problem, title: "交接记录", body: "会后没有明确负责人。", isConfirmed: true)]
        store.quests = [completionFixtureQuest()]
        store.saveValidationAndReviewPrinciple()
        for _ in 0..<200 where store.isSavingTodayCompletion || store.todayDraft.state != .extractPrinciple || store.isAIRunning {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(client.promptIDs, [.extractPrinciple])
        let candidate = try XCTUnwrap(store.principles.first)
        let repo = SQLitePrincipleRepository(database: database)
        let assets = try await repo.activePrinciples()
        XCTAssertTrue(assets.isEmpty)
        XCTAssertTrue(store.activePrinciples.isEmpty)
        await store.returnToTodayOverview()
        await store.addManualTrainingCase(title: "另一个事项")
        let other = try XCTUnwrap(store.trainingCases.first { $0.id != fixture.trainingCase.id })
        await store.openTrainingCase(other.id)
        XCTAssertTrue(store.principles.isEmpty)
        await store.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(store.principles, [candidate])
        await store.returnToTodayOverview()
        let fresh = AppStore(dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
            thinkingCardRepository: SQLiteThinkingCardRepository(database: database),
            questRepository: SQLiteQuestRepository(database: database), principleRepository: repo,
            trainingCaseRepository: SQLiteTrainingCaseRepository(database: database),
            trainingCaseSessionRepository: fixture.sessionRepository,
            refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: true)
        await fresh.loadPersistedState()
        await fresh.openTrainingCase(fixture.trainingCase.id)
        XCTAssertEqual(fresh.principles, [candidate])
        XCTAssertTrue(fresh.activePrinciples.isEmpty)
    }

    @MainActor
    func testOptionalPrincipleCompletionWriteFailuresRetainPageAndCanRetry() async throws {
        for (table, condition) in [
            ("training_case_sessions", "NEW.loop_state = 'sessionComplete'"),
            ("training_cases", "NEW.status = 'awaiting_verification'"),
            ("daily_entries", "NEW.state = 'sessionComplete'")
        ] {
            let fixture = try await makeCoachFeedbackStore()
            let store = fixture.store
            let candidate = completionFixturePrinciple(title: "待保存候选")
            store.todayDraft.state = .extractPrinciple
            store.principles = [candidate]
            try await database.dbQueue.write { db in
                try db.execute(sql: "CREATE TRIGGER fail_optional_finish BEFORE INSERT ON \(table) WHEN \(condition) BEGIN SELECT RAISE(ABORT, 'synthetic completion failure'); END")
            }
            store.submitTodayStep()
            XCTAssertTrue(store.isSavingTodayCompletion)
            store.skipPrinciple()
            store.resetTodayLoop()
            for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(store.todayDraft.state, .extractPrinciple, table)
            XCTAssertEqual(store.principles, [candidate], table)
            XCTAssertFalse(store.isTodayOverviewPresented, table)
            try await database.dbQueue.write { db in try db.execute(sql: "DROP TRIGGER fail_optional_finish") }
            store.submitTodayStep()
            for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(store.todayDraft.state, .sessionComplete, table)
            let saved = try await SQLitePrincipleRepository(database: database).principles(for: store.todayDraft.id)
            XCTAssertEqual(saved.map(\.id), [candidate.id], table)
        }
    }

    @MainActor
    func testLegacyPrincipleCandidateRestoresAsDraftAndEmptyEditCannotBeConfirmed() async throws {
        let entry = DailyEntryDraft(rawText: "今日回顾", state: .extractPrinciple)
        let repo = SQLitePrincipleRepository(database: database)
        let entries = SQLiteDailyEntryRepository(database: database)
        let candidate = completionFixturePrinciple(title: "尚未确认")
        let store = AppStore(todayDraft: entry, principles: [candidate], dailyEntryRepository: entries,
            principleRepository: repo, refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: false)
        store.updatePrinciple(candidate.id, title: "已编辑的草稿", summary: candidate.summary,
            triggerContext: candidate.triggerContext, actionsText: "记录结果",
            successCriteria: candidate.successCriteria, exceptions: candidate.exceptions)
        // Drain the existing persistence chain through a serialized save.
        store.submitTodayStep()
        for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
        let confirmed = try await repo.activePrinciples()
        XCTAssertEqual(confirmed.first?.title, "已编辑的草稿")
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)

        var pending = entry
        pending.principleReviewDrafts = ["daily": [candidate]]
        try await entries.saveDraft(pending)
        let restored = AppStore(dailyEntryRepository: entries, principleRepository: repo,
            refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: false)
        await restored.loadPersistedState()
        XCTAssertEqual(restored.principles, [candidate])
        XCTAssertEqual(restored.activePrinciples.map(\.id), [candidate.id])
        // Keep the saved asset intact while an empty draft edit remains unconfirmed.
        restored.updatePrinciple(candidate.id, title: " ", summary: candidate.summary,
            triggerContext: candidate.triggerContext, actionsText: "",
            successCriteria: candidate.successCriteria, exceptions: candidate.exceptions)
        restored.submitTodayStep()
        XCTAssertFalse(restored.isSavingTodayCompletion)
        XCTAssertEqual(restored.todayDraft.state, .extractPrinciple)
        XCTAssertTrue(restored.todayLoopMessage.contains("至少一个具体动作"))
        let unchanged = try await repo.activePrinciples()
        XCTAssertEqual(unchanged, confirmed)
    }

    @MainActor
    func testLatePrincipleErrorDoesNotChangeAnotherCase() async throws {
        let client = GuidanceFixtureLLMClient(response: "{}")
        client.suspendThenFail = true
        let fixture = try await makeCoachFeedbackStore(todayAIService:
            TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client))
        let store = fixture.store
        store.todayDraft.state = .reviewQuests
        store.quests = [completionFixtureQuest()]
        store.saveValidationAndReviewPrinciple()
        for _ in 0..<200 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(client.responseGate)
        await store.returnToTodayOverview()
        await store.addManualTrainingCase(title: "新事项")
        let other = try XCTUnwrap(store.trainingCases.first { $0.id != fixture.trainingCase.id })
        await store.openTrainingCase(other.id)
        let state = store.todayDraft.state
        let message = store.todayLoopMessage
        client.responseGate?.resume()
        client.responseGate = nil
        for _ in 0..<200 where store.isAIRunning { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(store.activeTrainingCase?.id, other.id)
        XCTAssertEqual(store.todayDraft.state, state)
        XCTAssertEqual(store.todayLoopMessage, message)
        XCTAssertTrue(store.principles.isEmpty)
        XCTAssertFalse(store.canRetryCurrentAI)
    }

    @MainActor
    func testSkipPrincipleCancelsPendingRetryAndDoesNotReopenCompletedFlow() async throws {
        let client = GuidanceFixtureLLMClient(response: "{}")
        client.suspendThenFail = true
        let store = AppStore(todayDraft: DailyEntryDraft(rawText: "今日回顾", state: .extractPrinciple),
            todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client),
            refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: false)
        store.retryCurrentAIStep()
        for _ in 0..<200 where client.responseGate == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(client.responseGate)
        store.skipPrinciple()
        client.responseGate?.resume()
        client.responseGate = nil
        for _ in 0..<200 where store.isAIRunning || store.isSavingTodayCompletion {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
        XCTAssertTrue(store.principles.isEmpty)
        XCTAssertFalse(store.canRetryCurrentAI)
    }

    private func completionFixturePrinciple(title: String) -> PrincipleAsset {
        PrincipleAsset(title: title, summary: "在相同条件下观察实际结果，暂不确定因果。",
            triggerContext: "怀疑入口影响完成时", actions: ["记录一次结果"],
            successCriteria: "留下一次可检查的观察", exceptions: "条件不一致时不外推")
    }

    private func completionFixtureQuest() -> Quest {
        Quest(type: .main, title: "记录一次重试结果", whyItMatters: "区分网络与设计影响。",
            completionCriteria: "网络正常时记录同一任务是否完成及具体卡点。",
            expectedResistance: "对方可能不愿意。", reflectionQuestion: "结果是否改变了对入口设计的怀疑？",
            calibrationTarget: "入口设计导致未完成")
    }

    @MainActor
    func testFinalCompletionWritesMustSucceedBeforeLeavingValidation() async throws {
        for (table, condition) in [
            ("training_case_sessions", "NEW.loop_state = 'sessionComplete'"),
            ("training_cases", "NEW.status = 'awaiting_verification'"),
            ("daily_entries", "NEW.state = 'sessionComplete'")
        ] {
            let fixture = try await makeCoachFeedbackStore()
            let store = fixture.store
            store.todayDraft.state = .reviewQuests
            let quest = completionFixtureQuest()
            store.quests = [quest]
            try await database.dbQueue.write { db in
                try db.execute(sql: "CREATE TRIGGER fail_final_save BEFORE INSERT ON \(table) WHEN \(condition) BEGIN SELECT RAISE(ABORT, 'synthetic final write failure'); END")
            }
            store.submitTodayStep()
            for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(store.todayDraft.state, .reviewQuests, table)
            XCTAssertEqual(store.activeTrainingCase?.id, fixture.trainingCase.id, table)
            XCTAssertFalse(store.isTodayOverviewPresented, table)
            XCTAssertEqual(store.quests, [quest], table)
            XCTAssertTrue(store.todayLoopMessage.contains("已保留当前页面"), table)
            try await database.dbQueue.write { db in try db.execute(sql: "DROP TRIGGER fail_final_save") }
            store.submitTodayStep()
            for _ in 0..<200 where store.isSavingTodayCompletion { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(store.todayDraft.state, .sessionComplete, table)
        }
    }

    @MainActor
    private func makeCoachFeedbackStore(
        todayAIService: TodayAIService? = nil,
        answerReviewService: CoachAnswerReviewAIService? = nil
    ) async throws -> (
        store: AppStore,
        trainingCase: TrainingCase,
        promptRunRepository: SQLitePromptRunRepository,
        sessionRepository: SQLiteTrainingCaseSessionRepository,
        coachPromptTurnRepository: SQLiteCoachPromptTurnRepository
    ) {
        let entry = DailyEntryDraft(rawText: "Coach feedback fixture", state: .reviewCards)
        let entryRepository = SQLiteDailyEntryRepository(database: database)
        let cardRepository = SQLiteThinkingCardRepository(database: database)
        let caseRepository = SQLiteTrainingCaseRepository(database: database)
        let sessionRepository = SQLiteTrainingCaseSessionRepository(database: database)
        let promptRunRepository = SQLitePromptRunRepository(database: database)
        let coachPromptTurnRepository = SQLiteCoachPromptTurnRepository(database: database)
        let questRepository = SQLiteQuestRepository(database: database)
        let lensSessionRepository = SQLiteLensSessionRepository(database: database)
        let relationshipRepository = SQLiteTrainingCaseRelationshipRepository(database: database)
        try await entryRepository.saveDraft(entry)

        let store = AppStore(
            todayDraft: entry,
            dailyEntryRepository: entryRepository,
            thinkingCardRepository: cardRepository,
            questRepository: questRepository,
            principleRepository: SQLitePrincipleRepository(database: database),
            lensSessionRepository: lensSessionRepository,
            promptRunRepository: promptRunRepository,
            trainingCaseRepository: caseRepository,
            trainingCaseSessionRepository: sessionRepository,
            trainingCaseRelationshipRepository: relationshipRepository,
            guidanceRepository: SQLiteGuidanceRepository(database: database),
            coachPromptTurnRepository: coachPromptTurnRepository,
            todayAIService: todayAIService,
            refreshesAIServiceFromKeychain: false,
            coachAnswerReviewAIService: answerReviewService,
            trainingCasesVNextEnabled: true
        )
        await store.addManualTrainingCase(title: "反馈事项")
        let trainingCase = try XCTUnwrap(store.trainingCases.first)
        _ = try await cardRepository.cards(forTrainingCaseId: trainingCase.id)
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM training_case_sessions WHERE case_id = ?",
                arguments: [trainingCase.id.uuidString]
            )
        }
        await store.openTrainingCase(trainingCase.id)
        guard store.activeTrainingCase?.id == trainingCase.id else {
            throw NSError(
                domain: "VNextTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: store.todayLoopMessage]
            )
        }
        return (store, trainingCase, promptRunRepository, sessionRepository, coachPromptTurnRepository)
    }

    private func markCoachTurnPresented(
        _ repository: CoachPromptTurnRepository,
        run: PromptRun,
        session: TrainingCaseSession,
        caseId: UUID,
        promptID: PromptID,
        outputFingerprint: String
    ) async throws {
        try await repository.recordOutcome(
            promptRunId: run.id,
            promptId: promptID,
            outcome: .responseReceived,
            detail: nil
        )
        try await repository.markPresented(
            promptRunId: run.id,
            caseSessionId: session.id,
            caseId: caseId,
            promptId: promptID,
            outputFingerprint: outputFingerprint
        )
    }

    private func makeCoachPromptRun(
        promptID: PromptID,
        caseId: UUID,
        createdAt: Date
    ) -> PromptRun {
        PromptRun(
            promptId: promptID.rawValue,
            promptVersion: "coach-feedback.v1",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [caseId.uuidString],
            requestSummary: "Coach feedback fixture",
            responseJSON: "{\"ok\":true}",
            createdAt: createdAt
        )
    }

    func testCaptureFragmentsDigestMigrationRepositoryAndExport() async throws {
        let repository = SQLiteCaptureFragmentRepository(database: database)
        let day = "2026-08-26"
        let first = try await repository.save(CaptureFragment(rawText: "先确认负责人", dayKey: day, sourceID: "fixture-1"))
        let duplicate = try await repository.save(CaptureFragment(rawText: "不应覆盖", dayKey: day, sourceID: "fixture-1"))
        let second = try await repository.save(CaptureFragment(rawText: "再看验收信号", dayKey: day, sourceID: "fixture-2"))
        XCTAssertEqual(first.id, duplicate.id)

        let digest = try await CaptureDigestService(promptProvider: LocalPromptProvider(), llmClient: MockLLMClient()).generate(for: [first, second], dayKey: day)
        XCTAssertEqual(Set(digest.sourceFragmentIDs), Set([first.id, second.id]))
        try await repository.saveDigest(digest, markingIncluded: digest.sourceFragmentIDs)
        let pending = try await repository.fragments(forDayKey: day, statuses: [.pending])
        let currentDigest = try await repository.currentDigest(forDayKey: day)
        XCTAssertEqual(pending.count, 0)
        XCTAssertEqual(currentDigest?.id, digest.id)

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["capture_fragments"], 2)
        XCTAssertEqual(export.counts["daily_capture_digests"], 1)
    }

    func testSingleNudgeRepositoryRestoresLatestUnfinishedSessionForSameDay() async throws {
        let repository = SQLiteSingleNudgeSessionRepository(database: database)
        let day = "2026-08-29"
        let completed = SingleNudgeSession(
            dayKey: day,
            input: "已完成的点拨",
            lifecycle: .completed,
            result: .completed,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let earlierUnfinished = SingleNudgeSession(
            dayKey: day,
            input: "较早未完成的点拨",
            lifecycle: .questionPresented,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let latestUnfinished = SingleNudgeSession(
            dayKey: day,
            input: "最新未完成的点拨",
            lifecycle: .draft,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        try await repository.save(completed)
        try await repository.save(earlierUnfinished)
        try await repository.save(latestUnfinished)

        let restored = try await repository.session(for: day)

        XCTAssertEqual(restored?.id, latestUnfinished.id)
        XCTAssertEqual(restored?.input, "最新未完成的点拨")
    }

    func testSingleNudgeV52LineagePreservesParentAndExportsLinkedRounds() async throws {
        let repository = SQLiteSingleNudgeSessionRepository(database: database)
        let day = "2026-09-02"
        let parent = SingleNudgeSession(
            dayKey: day,
            input: "学生担心复习安排没有效果。",
            question: "哪一次练习最能说明安排有效？",
            diagnosis: "先把效果标准说清楚。",
            after: "我还没比较错题类型。",
            promptRunID: UUID(),
            reviewPromptRunID: UUID(),
            lifecycle: .receiptPresented,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let child = SingleNudgeSession(
            dayKey: day,
            input: parent.input,
            parentSessionID: parent.id,
            rootSessionID: parent.rootSessionID,
            continuationKind: .alternateAngle,
            lifecycle: .questionPresented,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        try await repository.save(parent)
        try await repository.save(child)

        let persistedParentValue = try await repository.session(id: parent.id)
        let restoredValue = try await repository.session(for: day)
        let persistedParent = try XCTUnwrap(persistedParentValue)
        let restored = try XCTUnwrap(restoredValue)
        XCTAssertEqual(persistedParent.question, parent.question)
        XCTAssertEqual(persistedParent.after, parent.after)
        XCTAssertEqual(persistedParent.promptRunID, parent.promptRunID)
        XCTAssertEqual(persistedParent.reviewPromptRunID, parent.reviewPromptRunID)
        XCTAssertEqual(restored.id, child.id)
        XCTAssertEqual(restored.parentSessionID, parent.id)
        XCTAssertEqual(restored.rootSessionID, parent.id)
        XCTAssertEqual(restored.continuationKind, .alternateAngle)

        let export = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(export.counts["single_nudge_sessions"], 2)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: export.data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let rows = try XCTUnwrap(sections["single_nudge_sessions"] as? [[String: Any]])
        XCTAssertTrue(rows.contains { ($0["parent_session_id"] as? String) == parent.id.uuidString })
        try await database.dbQueue.read { db in
            let columns = try db.columns(in: "single_nudge_sessions").map(\.name)
            XCTAssertTrue(columns.contains("parent_session_id"))
            XCTAssertTrue(columns.contains("root_session_id"))
            XCTAssertTrue(columns.contains("continuation_kind"))
        }
    }

    func testCaptureDigestRequiresTwoPendingFragments() async throws {
        let fragment = CaptureFragment(rawText: "一条素材", dayKey: "2026-08-26")
        do {
            _ = try await CaptureDigestService(promptProvider: LocalPromptProvider(), llmClient: MockLLMClient()).generate(for: [fragment], dayKey: fragment.dayKey)
            XCTFail("Expected insufficient fragments")
        } catch let error as CaptureDigestError {
            XCTAssertEqual(error, .insufficientFragments)
        }
    }

    func testCaptureDigestRejectsInvalidInputsBeforeCallingLLM() async throws {
        let day = "2026-08-26"
        let first = CaptureFragment(rawText: "第一条", dayKey: day)
        let invalidFragmentSets = [
            [first, CaptureFragment(rawText: "跨日素材", dayKey: "2026-08-25")],
            [first, CaptureFragment(rawText: "已整理素材", status: .included, dayKey: day)],
            [first, CaptureFragment(id: first.id, rawText: "重复 ID 素材", dayKey: day)],
            [first, CaptureFragment(rawText: "  ", dayKey: day)]
        ]

        for fragments in invalidFragmentSets {
            let client = GuidanceFixtureLLMClient(response: "{}")
            let service = CaptureDigestService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            )

            do {
                _ = try await service.generate(for: fragments, dayKey: day)
                XCTFail("Expected invalid capture fragments to be rejected")
            } catch let error as CaptureDigestError {
                XCTAssertEqual(error, .invalidResponse)
            }
            XCTAssertTrue(client.promptIDs.isEmpty)
        }
    }

    func testCaptureDigestTransactionRejectsMixedDaySourcesWithoutReplacingCurrentDigest() async throws {
        let repository = SQLiteCaptureFragmentRepository(database: database)
        let day = "2026-08-26"
        let first = try await repository.save(CaptureFragment(rawText: "第一条", dayKey: day))
        let second = try await repository.save(CaptureFragment(rawText: "第二条", dayKey: day))
        let current = DailyCaptureDigest(
            dayKey: day,
            summary: "原有整理",
            themes: ["原有主题"],
            sourceFragmentIDs: [first.id, second.id]
        )
        try await repository.saveDigest(current, markingIncluded: current.sourceFragmentIDs)

        let sameDay = try await repository.save(CaptureFragment(rawText: "同日待整理", dayKey: day))
        let otherDay = try await repository.save(CaptureFragment(rawText: "跨日素材", dayKey: "2026-08-25"))
        let invalid = DailyCaptureDigest(
            dayKey: day,
            summary: "不应保存",
            themes: ["错误来源"],
            sourceFragmentIDs: [sameDay.id, otherDay.id]
        )

        do {
            try await repository.saveDigest(invalid, markingIncluded: invalid.sourceFragmentIDs)
            XCTFail("Expected mixed-day digest sources to be rejected")
        } catch MingSi.PersistenceError.validationFailed {
            // Expected: all sources must be pending fragments for the requested day.
        } catch {
            XCTFail("Expected validation failure, got \(error)")
        }

        let currentDigestID = try await repository.currentDigest(forDayKey: day)?.id
        XCTAssertEqual(currentDigestID, current.id)
        let sameDayPendingIDs = try await repository.fragments(forDayKey: day, statuses: [.pending]).map(\.id)
        XCTAssertEqual(
            sameDayPendingIDs,
            [sameDay.id]
        )
        let otherDayPendingIDs = try await repository.fragments(forDayKey: "2026-08-25", statuses: [.pending]).map(\.id)
        XCTAssertEqual(
            otherDayPendingIDs,
            [otherDay.id]
        )
    }

    func testCaptureDigestRejectsIncompleteReferencesAndBlankThemes() async throws {
        let fragments = [
            CaptureFragment(rawText: "第一条", dayKey: "2026-08-26"),
            CaptureFragment(rawText: "第二条", dayKey: "2026-08-26")
        ]
        let responses = [
            """
            {"summary":"摘要","themes":["主题"],"recommended_question":null,"source_refs":["\(fragments[0].id.uuidString)"]}
            """,
            """
            {"summary":"摘要","themes":["  "],"recommended_question":null,"source_refs":["\(fragments[0].id.uuidString)","\(fragments[1].id.uuidString)"]}
            """
        ]

        for response in responses {
            let service = CaptureDigestService(
                promptProvider: LocalPromptProvider(),
                llmClient: GuidanceFixtureLLMClient(response: response)
            )
            do {
                _ = try await service.generate(for: fragments, dayKey: "2026-08-26")
                XCTFail("Expected invalid response")
            } catch let error as CaptureDigestError {
                XCTAssertEqual(error, .invalidResponse)
            }
        }
    }

    func testCaptureIntentSaverPersistsNonEmptyText() async throws {
        let repository = SQLiteCaptureFragmentRepository(database: database)
        let saver = CaptureIntentSaver(repository: repository)
        try await saver.saveIntentCapture("Siri 保存的闪念")
        let saved = try await repository.fragments(forDayKey: CaptureDayKey.value(for: .now), statuses: nil)
        XCTAssertEqual(saved.first?.source, .appIntent)
        XCTAssertEqual(saved.first?.rawText, "Siri 保存的闪念")
    }

    private func createV1FixtureSchema(in queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('v1_core_records')")
            try db.execute(sql: "CREATE TABLE daily_entries (id TEXT PRIMARY KEY, schema_version INTEGER NOT NULL, date TEXT NOT NULL, raw_text TEXT NOT NULL, session_mode TEXT NOT NULL, state TEXT NOT NULL, privacy_flags_json TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)")
            try db.execute(sql: "CREATE TABLE thinking_cards (id TEXT PRIMARY KEY, daily_entry_id TEXT NOT NULL, schema_version INTEGER NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, importance TEXT NOT NULL, sensitivity TEXT NOT NULL, confidence REAL NOT NULL, is_confirmed INTEGER NOT NULL, is_excluded_from_model INTEGER NOT NULL, source_refs_json TEXT, raw_payload_json TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)")
            try db.execute(sql: "CREATE TABLE quests (id TEXT PRIMARY KEY, source_daily_entry_id TEXT NOT NULL, schema_version INTEGER NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL, why_it_matters TEXT NOT NULL, completion_criteria TEXT NOT NULL, expected_resistance TEXT, reflection_question TEXT, status TEXT NOT NULL, due_date TEXT, reminder_id TEXT, linked_card_ids_json TEXT, raw_payload_json TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)")
            try db.execute(sql: "CREATE TABLE principle_assets (id TEXT PRIMARY KEY, schema_version INTEGER NOT NULL, title TEXT NOT NULL, summary TEXT NOT NULL, trigger_context TEXT NOT NULL, actions_json TEXT NOT NULL, success_criteria TEXT NOT NULL, exceptions TEXT, source_daily_entry_ids_json TEXT, source_card_ids_json TEXT, validation_count INTEGER NOT NULL, last_validated_at TEXT, status TEXT NOT NULL, raw_payload_json TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)")
            try db.execute(sql: "CREATE TABLE prompt_runs (id TEXT PRIMARY KEY, schema_version INTEGER NOT NULL, prompt_id TEXT NOT NULL, prompt_version TEXT NOT NULL, input_schema_version INTEGER NOT NULL, output_schema_version INTEGER NOT NULL, model_provider TEXT NOT NULL, model_name TEXT NOT NULL, session_mode TEXT NOT NULL, source_record_ids_json TEXT, request_summary TEXT, response_json TEXT, error TEXT, created_at TEXT NOT NULL)")
        }
    }

    private static let fixtureTimestamp = "2026-07-15T12:00:00.000Z"
}

private final class RecordingReminderService: ReminderService {
    var permissionRequestCount = 0
    var scheduled: [ReminderRequest] = []
    var cancelled: [String] = []

    func requestPermission() async throws -> ReminderPermissionStatus {
        permissionRequestCount += 1
        return .authorized
    }

    func schedule(_ request: ReminderRequest) async throws {
        scheduled.append(request)
    }

    func cancel(id: String) async {
        cancelled.append(id)
    }
}

private final class GuidanceFixtureLLMClient: LLMClient {
    var suspendThenFail = false
    var suspendBeforeResponse = false
    private(set) var requests: [LLMRequest] = []
    var responseGate: CheckedContinuation<Void, Never>?
    let response: Data
    private(set) var promptIDs: [PromptID] = []

    init(response: String) {
        self.response = Data(response.utf8)
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        promptIDs.append(request.prompt.id)
        requests.append(request)
        if suspendBeforeResponse { await withCheckedContinuation { responseGate = $0 } }
        if suspendThenFail {
            await withCheckedContinuation { responseGate = $0 }
            throw NSError(domain: "SyntheticLatePrincipleError", code: 1)
        }
        return response
    }
}

private final class SideQuestRecordingLLMClient: LLMClient {
    let response: Data
    private(set) var lastRequest: LLMRequest?
    private(set) var requestCount = 0

    init(response: String) {
        self.response = Data(response.utf8)
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        requestCount += 1
        lastRequest = request
        return response
    }
}

private final class VNextResponseClient: LLMClient {
    let response: Data
    init(response: Data) { self.response = response }
    func complete(_ request: LLMRequest) async throws -> Data { response }
}

// Fixtures test orchestration/provenance, not semantic classification quality.
private final class GuidanceEvidenceEchoTestClient: LLMClient {
    private(set) var requests: [LLMRequest] = []
    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        let raw = try XCTUnwrap(request.contextPayload?.currentInput.rawText)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        return try JSONSerialization.data(withJSONObject: ["result": "supports", "hint_id": object["hintId"]!,
            "reason": "只测试保存流程，不代表真实语义判断。", "evidence_quotes": ["动手前写了标准"]])
    }
}

private final class AnswerReviewRetryClient: LLMClient {
    private(set) var requests: [LLMRequest] = []
    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]

    func complete(_ request: LLMRequest) async throws -> Data {
        let index = requests.count
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuations[index] = $0 }
    }

    func resolve(_ index: Int, with result: Result<Data, Error>) {
        continuations.removeValue(forKey: index)?.resume(with: result)
    }

    func resolveAll(with result: Result<Data, Error>) {
        let pending = continuations.values
        continuations.removeAll()
        for continuation in pending { continuation.resume(with: result) }
    }
}

extension VNextTests {
    func testCaptureInputDraftSurvivesDatabaseReopenAndDoesNotBecomeAFragment() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("draft.sqlite")
        let expected = CaptureInputDraft(text: "手写正文\n🧭", speechPreview: "尚未确认的识别")
        do {
            let repository = SQLiteCaptureFragmentRepository(database: try AppDatabase(url: url))
            try repository.saveInputDraft(expected)
        }
        let database = try AppDatabase(url: url)
        let repository = SQLiteCaptureFragmentRepository(database: database)
        XCTAssertEqual(try repository.inputDraft(), expected)
        let fragments = try await repository.fragments(forDayKey: CaptureDayKey.value(for: .now), statuses: nil)
        XCTAssertTrue(fragments.isEmpty)
        let exported = try await SQLiteDataExportRepository(database: database).exportPackage()
        XCTAssertEqual(exported.counts["capture_input_draft"], 1)
        try repository.commitInputDraft(expected)
        XCTAssertEqual(try repository.inputDraft(), CaptureInputDraft(speechPreview: expected.speechPreview))
        let saved = try await repository.fragments(forDayKey: CaptureDayKey.value(for: .now), statuses: nil)
        XCTAssertEqual(saved.map(\.rawText), [expected.text])
        XCTAssertThrowsError(try repository.commitInputDraft(expected), "Stale save must not duplicate a fragment")
        try repository.saveInputDraft(CaptureInputDraft())
        XCTAssertTrue(try repository.inputDraft().isEmpty)
        let cleared = SQLiteCaptureFragmentRepository(database: try AppDatabase(url: url))
        XCTAssertTrue(try cleared.inputDraft().isEmpty)
    }

    func testCaptureDraftCommitRollsBackBothFragmentAndDraftWhenClearFails() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let repository = SQLiteCaptureFragmentRepository(database: database)
        let expected = CaptureInputDraft(text: "事务失败也不能丢失")
        try repository.saveInputDraft(expected)
        try await database.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_draft_clear BEFORE DELETE ON capture_input_draft BEGIN SELECT RAISE(ABORT, 'test'); END")
        }
        XCTAssertThrowsError(try repository.commitInputDraft(expected))
        XCTAssertEqual(try repository.inputDraft(), expected)
        let fragments = try await repository.fragments(forDayKey: CaptureDayKey.value(for: .now), statuses: nil)
        XCTAssertTrue(fragments.isEmpty)
        XCTAssertThrowsError(try repository.saveInputDraft(CaptureInputDraft()))
        XCTAssertEqual(try repository.inputDraft(), expected)
    }
}

extension VNextTests {
    func testCaptureDraftMigrationAppendsAfterExistingSchemaWithoutChangingFragments() async throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue)
        try await queue.write { db in
            // Reconstruct the previous shipped schema, retaining all later
            // principle migrations. The new migration must be additive there.
            try db.execute(sql: "DROP TABLE capture_input_draft")
            try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = 'v72_capture_input_draft'")
            try db.execute(sql: "INSERT INTO capture_fragments (id, raw_text, source, status, day_key, created_at, updated_at) VALUES (?, ?, 'app', 'pending', '2026-10-23', '2026-10-23T00:00:00Z', '2026-10-23T00:00:00Z')",
                           arguments: [UUID().uuidString, "升级前的闪念"])
        }
        let upgraded = try AppDatabase(dbQueue: queue)
        let repository = SQLiteCaptureFragmentRepository(database: upgraded)
        XCTAssertTrue(try repository.inputDraft().isEmpty)
        let saved = try await repository.fragments(forDayKey: "2026-10-23", statuses: nil)
        XCTAssertEqual(saved.map(\.rawText), ["升级前的闪念"])
        try repository.saveInputDraft(CaptureInputDraft(text: "升级后的草稿"))
        XCTAssertEqual(try repository.inputDraft().text, "升级后的草稿")
    }
}
