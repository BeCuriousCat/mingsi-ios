import GRDB
import XCTest
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

    func testGuidanceEvidenceClassificationIsModelBacked() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"result":"counterexample","hint_id":"verification.result_not_completion","reason":"只记录了完成，没有实际结果。"}
        """)
        let item = try XCTUnwrap(BuiltinGuidanceCatalog.items.first { $0.hintId == "verification.result_not_completion" })
        let quest = makeQuest(caseId: UUID(), title: "验证结果")
        let verification = makeVerification(quest: quest, entryId: UUID())
        let decision = try await GuidanceAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ).evaluateEvidence(item: item, quest: quest, verification: verification)

        XCTAssertEqual(decision.result, .counterexample)
        XCTAssertEqual(decision.hintId, item.hintId)
        XCTAssertEqual(client.promptIDs, [.evaluateGuidanceEvidence])
    }

    func testCoachTrainingDecisionUsesCentralModelForLensAndDiagnosis() async throws {
        let client = GuidanceFixtureLLMClient(response: """
        {"phase":"fill_evidence_gap","readiness":"not_ready","recommended_move":"surface_evidence_gap","training_dimension":"evidence_discipline","recommended_lens_id":"evidenceCheck","reason":"当前判断缺少可观察证据，需要先补齐支持或推翻它的信号。","confidence":0.84}
        """)
        let card = ThinkingCard(type: .decision, title: "判断", body: "应该直接推进", isConfirmed: true)
        let result = try await CoachDecisionAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ).decide(
            context: CoachDecisionContext(
                caseId: UUID(),
                caseTitle: "验证事项",
                mode: .standard,
                cards: [card]
            )
        )

        XCTAssertEqual(result.diagnosis.phase, .fillEvidenceGap)
        XCTAssertEqual(result.diagnosis.recommendedMove, .surfaceEvidenceGap)
        XCTAssertEqual(result.prescription.recommendedLensId, "evidenceCheck")
        XCTAssertEqual(result.prescription.primaryTrainingDimension, .evidenceDiscipline)
        XCTAssertEqual(client.promptIDs, [.diagnoseTrainingCase])
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
        provider.requestCalendarAuthorization()
        provider.requestHealthAuthorization()
        XCTAssertEqual(provider.locationRequestCount, 1)
        XCTAssertEqual(provider.calendarRequestCount, 1)
        XCTAssertEqual(provider.healthRequestCount, 1)
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
    func testLocalGrowthIncludesEveryCaseVerificationWithCaseAttribution() async throws {
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

        XCTAssertTrue(store.growthSnapshot.canDisplayScores)
        let contributions = try await contributionRepository.contributions(for: store.growthSnapshot.id)
        XCTAssertTrue(contributions.allSatisfy { $0.sourceCaseId != nil })
        for caseID in caseIDs {
            XCTAssertTrue(
                contributions.contains { contribution in
                    contribution.sourceCaseId == caseID && contribution.sourceType == .verification
                },
                "Every case verification must remain attributable to its own case."
            )
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

        let contributions = try await contributionRepository.contributions(for: store.growthSnapshot.id)
        XCTAssertFalse(contributions.isEmpty)
        XCTAssertTrue(contributions.allSatisfy { $0.sourceCaseId != nil })
        let firstLensContributions = contributions.filter { contribution in
            contribution.sourceType == .dailyEntry &&
                contribution.sourceDailyEntryId == entries[0].id &&
                contribution.title == "完成透镜追问"
        }
        XCTAssertEqual(firstLensContributions.count, 1)
        XCTAssertEqual(firstLensContributions.first?.sourceCaseId, cases[0].id)
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

    private func coachAnswerReviewJSON(refs: [String]) -> String {
        let encodedRefs = refs.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"readiness":"not_ready","recommended_move":"surface_evidence_gap","open_evidence_gaps":["missing_observation"],"reason":"回答仍缺少可核对的来源。","turn_summary":"判断更清楚，但证据尚未闭合。","coach_critique":"你给出了方向，还需要一条可核对事实。","repaired_material":"明确了判断。","missing_material":"缺少可回查的观察。","proceed_line":"补充观察，或由你选择带着缺口继续。","ability_gap":"把判断和事实分开。","training_output":"写出可核对的来源。","self_check":"别人能找到你引用的事实。","training_target":"证据纪律。","next_repair_question":"哪条记录能直接核对这个判断？","experience_replay_decision":"比较旧经验条件。","experience_replay_prompt":"旧经验的哪个条件不同？","judgment_sentence_prompt":"基于什么事实，我暂时相信什么。","reference_suggestion":"先写事实，再写判断。","reference_example":"基于「事实」，我暂时判断「……」。","source_refs":[\(encodedRefs)]}
        """
    }

    @MainActor
    private func makeCoachFeedbackStore() async throws -> (
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
            lensSessionRepository: lensSessionRepository,
            promptRunRepository: promptRunRepository,
            trainingCaseRepository: caseRepository,
            trainingCaseSessionRepository: sessionRepository,
            trainingCaseRelationshipRepository: relationshipRepository,
            guidanceRepository: SQLiteGuidanceRepository(database: database),
            coachPromptTurnRepository: coachPromptTurnRepository,
            refreshesAIServiceFromKeychain: false,
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
    let response: Data
    private(set) var promptIDs: [PromptID] = []

    init(response: String) {
        self.response = Data(response.utf8)
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        promptIDs.append(request.prompt.id)
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
