import CryptoKit
import XCTest
import GRDB
import UIKit
@testable import MingSi

@MainActor
final class AppStoreStateMachineTests: XCTestCase {

    private var store: AppStore!

    override func setUp() {
        super.setUp()
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_isVerifyYesterday() {
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
    }

    func testInitialState_defaultModeIsStandard() {
        XCTAssertEqual(store.todayDraft.sessionMode, .standard)
    }

    func testInitialState_hasNotSelectedMode() {
        XCTAssertFalse(store.todayDraft.hasSelectedSessionMode)
    }

    func testInitialState_noLensSelected() {
        XCTAssertNil(store.todayDraft.selectedLens)
    }

    func testInitialState_emptyRawText() {
        XCTAssertTrue(store.todayDraft.rawText.isEmpty)
    }

    func testPendingAIRepairBannerText_usesTrainingLanguage() {
        let pendingText = pendingTrainingRepairBannerText(isRunning: false, pendingCount: 2)
        let runningText = pendingTrainingRepairBannerText(isRunning: true, pendingCount: 2)

        XCTAssertEqual(pendingText, "有 2 个训练结果待补齐")
        XCTAssertEqual(runningText, "明思正在补齐训练结果，请等待")
        XCTAssertFalse(pendingText.contains("AI"))
        XCTAssertFalse(runningText.contains("AI"))
    }

    func testOrganizingProgressCopy_usesTrainingLanguageInsteadOfPipelineTerms() {
        let onlineTitle = organizingProgressTitle(isUsingOnlineModel: true)
        let localTitle = organizingProgressTitle(isUsingOnlineModel: false)
        let onlineStatus = organizingProgressFallbackStatusText(isUsingOnlineModel: true)
        let localStatus = organizingProgressFallbackStatusText(isUsingOnlineModel: false)
        let onlineSource = organizingProgressSourceStepCopy(isUsingOnlineModel: true)
        let localSource = organizingProgressSourceStepCopy(isUsingOnlineModel: false)
        let failureLabel = organizingProgressLocalDraftLabel
        let connectingStatus = organizingStreamingConnectingStatusText
        let localFailureStatus = organizingStreamingLocalDraftStatusText
        let interruptedStatus = organizingStreamingInterruptedStatusText(closedCount: 2)

        XCTAssertEqual(onlineTitle, "明思正在整理训练材料")
        XCTAssertEqual(localTitle, "明思正在准备本地训练草稿")
        XCTAssertEqual(onlineStatus, "等待第一张候选卡片。")
        XCTAssertEqual(localStatus, "暂时使用本地训练草稿，你可以先继续确认材料。")
        XCTAssertEqual(onlineSource.title, "整理输入材料")
        XCTAssertEqual(onlineSource.subtitle, "明思把原始输入拆成可确认的训练卡片。")
        XCTAssertEqual(localSource.title, "整理输入材料")
        XCTAssertEqual(localSource.subtitle, "暂时使用本地规则，先保留可编辑的训练卡片。")
        XCTAssertEqual(failureLabel, "本次使用本地训练草稿")
        XCTAssertEqual(connectingStatus, "明思正在整理训练材料。")
        XCTAssertEqual(localFailureStatus, "整理未完成，已使用本地训练草稿。")
        XCTAssertEqual(interruptedStatus, "整理中断，已保留 2 张闭合卡片。")

        let combined = [
            onlineTitle,
            localTitle,
            onlineStatus,
            localStatus,
            onlineSource.title,
            onlineSource.subtitle,
            localSource.title,
            localSource.subtitle,
            failureLabel,
            connectingStatus,
            localFailureStatus,
            interruptedStatus
        ].joined(separator: "\n")
        XCTAssertFalse(combined.contains("AI"))
        XCTAssertFalse(combined.contains("API"))
        XCTAssertFalse(combined.contains("fallback"))
        XCTAssertFalse(combined.contains("模型流"))
    }

    func testLoadPersistedState_restoresUnfinishedPriorDayDraftWithoutChangingDate() async throws {
        let dailyRepo = InMemoryDailyEntryRepository()
        let priorDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let unfinished = DailyEntryDraft(
            date: priorDate,
            rawText: "昨天晚上写了一半，还没有完成闭环。",
            sessionMode: .deep,
            hasSelectedSessionMode: true,
            state: .answerQuestions
        )
        try await dailyRepo.saveDraft(unfinished)

        let restoringStore = AppStore(
            dailyEntryRepository: dailyRepo,
            refreshesAIServiceFromKeychain: false
        )

        await restoringStore.loadPersistedState()

        XCTAssertEqual(restoringStore.todayDraft.id, unfinished.id)
        XCTAssertEqual(restoringStore.todayDraft.rawText, unfinished.rawText)
        XCTAssertEqual(restoringStore.todayDraft.state, .answerQuestions)
        XCTAssertTrue(Calendar.current.isDate(restoringStore.todayDraft.date, inSameDayAs: priorDate))
        XCTAssertFalse(Calendar.current.isDateInToday(restoringStore.todayDraft.date))
    }

    func testLoadPersistedState_restoresUnfinishedPriorDayDraftWhenBlankTodayDraftExists() async throws {
        let dailyRepo = InMemoryDailyEntryRepository()
        let priorDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let unfinished = DailyEntryDraft(
            date: priorDate,
            rawText: "昨天整理到问题阶段，还没有完成追问。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .reviewCards
        )
        let blankToday = DailyEntryDraft(date: Date(), state: .verifyYesterday)
        try await dailyRepo.saveDraft(unfinished)
        try await dailyRepo.saveDraft(blankToday)

        let restoringStore = AppStore(
            dailyEntryRepository: dailyRepo,
            refreshesAIServiceFromKeychain: false
        )

        await restoringStore.loadPersistedState()

        XCTAssertEqual(restoringStore.todayDraft.id, unfinished.id)
        XCTAssertEqual(restoringStore.todayDraft.rawText, unfinished.rawText)
        XCTAssertEqual(restoringStore.todayDraft.state, .reviewCards)
        XCTAssertTrue(Calendar.current.isDate(restoringStore.todayDraft.date, inSameDayAs: priorDate))
    }

    func testLocalFallbackCards_preservesMultipleFactLinesAsSeparateCards() async throws {
        let failingClient = SequencedLLMClient(results: [
            .failure(LLMClientError.httpStatus(500, Data("server down".utf8)))
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: failingClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("""
        事实：客户没有回复验收邮件。
        事实：会议没有指定负责人。
        想法：明天先补一份验收清单。
        """)

        store.submitTodayStep()
        try await waitForGeneratedCards()

        let factCards = store.thinkingCards.filter { $0.type == .fact }
        XCTAssertGreaterThanOrEqual(factCards.count, 2)
        XCTAssertTrue(factCards.contains { $0.body.contains("客户没有回复验收邮件") })
        XCTAssertTrue(factCards.contains { $0.body.contains("会议没有指定负责人") })
    }

    func testInitialState_growthSnapshotUsesEvidenceCollectionState() {
        XCTAssertTrue(store.growthSnapshot.hasInsufficientEvidence)
        XCTAssertFalse(store.growthSnapshot.canDisplayScores)
        XCTAssertEqual(store.growthSnapshot.completeLoopCount, 0)
        XCTAssertTrue(store.growthSnapshot.summary.contains("证据正在积累"))
        XCTAssertFalse(store.growthSnapshot.summary.contains("本周对会议类问题"))
    }

    func testDesignTokens_resolveToReadableDarkModeContrast() {
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)
        let background = UIColor(DS.background).resolvedColor(with: darkTrait)
        let ink = UIColor(DS.ink).resolvedColor(with: darkTrait)
        let mutedInk = UIColor(DS.mutedInk).resolvedColor(with: darkTrait)

        XCTAssertLessThan(Self.relativeLuminance(background), 0.20)
        XCTAssertGreaterThan(Self.relativeLuminance(ink), 0.60)
        XCTAssertGreaterThan(Self.relativeLuminance(mutedInk), 0.35)
    }

    // MARK: - VerifyYesterday -> Capture (synchronous)

    func testVerifyYesterday_withoutQuest_advancesToCapture() async throws {
        store.submitTodayStep()
        try await waitForState(.capture)
    }

    func testVerifyYesterday_withQuest_requiresCompletionSelection() {
        store.quests = [activeMainQuest()]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertEqual(
            store.todayLoopMessage,
            "进入条件：先选择昨天验证行动的完成情况。 训练理由：校准力训练要先看行动有没有真实发生。"
        )
    }

    func testVerifyYesterday_withQuest_requiresValueRating() {
        store.quests = [activeMainQuest()]
        store.selectYesterdayCompletion(.done)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertEqual(
            store.todayLoopMessage,
            "进入条件：先选择昨天验证行动的实际价值。 训练理由：校准不是完成打卡，而是判断行动是否产生价值。"
        )
    }

    func testVerifyYesterday_withQuestAndBothSelections_advancesToCapture() async throws {
        store.quests = [activeMainQuest()]
        store.selectYesterdayCompletion(.partial)
        store.selectYesterdayValueRating(.medium)
        store.selectYesterdayJudgmentUpdate(.adjusted)
        store.submitTodayStep()
        try await waitForState(.capture)
    }

    func testVerifyYesterday_withQuestRequiresJudgmentUpdate() {
        store.quests = [activeMainQuest()]
        store.selectYesterdayCompletion(.done)
        store.selectYesterdayValueRating(.high)

        store.submitTodayStep()

        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertEqual(
            store.todayLoopMessage,
            "进入条件：请选择昨天判断要确认、调整还是推翻。 训练理由：结果校准要用真实结果更新判断，不是继续写今天复盘。"
        )
    }

    func testVerifyYesterday_sendsQuestTrainingTargetToVerificationPrompt() async throws {
        let client = RecordingLLMClient(response: Self.verificationResponse)
        let selected = PrincipleAsset(
            title: "先写验收标准",
            summary: "先把验收标准写成可检查证据。",
            triggerContext: "acceptance contract",
            actions: ["写出验收标准"],
            successCriteria: "完成时能直接检查。",
            exceptions: "",
            status: .active
        )
        let automatic = PrincipleAsset(
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
            title: "会前写出负责人",
            whyItMatters: "避免会议后没有责任人。",
            completionCriteria: "负责人已经写在会议记录。",
            expectedResistance: "临时讨论太快。",
            reflectionQuestion: "是否真的减少了职责空白？",
            trainingPrincipleId: selected.id,
            status: .active
        )
        store = AppStore(
            quests: [quest],
            principles: [selected, automatic],
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        store.selectYesterdayCompletion(.done)
        store.selectYesterdayValueRating(.high)
        store.selectYesterdayJudgmentUpdate(.confirmed)

        store.submitTodayStep()
        try await waitForState(.capture)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == PromptID.verifyQuest })
        let trainingPrinciple = try XCTUnwrap(request.contextPayload?.verification?.trainingPrinciple)
        XCTAssertEqual(trainingPrinciple.principleId, selected.id.uuidString)
        XCTAssertEqual(trainingPrinciple.principleTitle, "先写验收标准")
        XCTAssertEqual(trainingPrinciple.matchSignal, "用户选择")
        XCTAssertEqual(request.contextPayload?.verification?.judgmentUpdate, YesterdayJudgmentUpdate.confirmed.rawValue)
    }

    func testVerifyYesterday_persistsVerificationOnOriginalQuestDayForHistory() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)

        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            rawText: "Yesterday review",
            state: .sessionComplete
        )
        try await dailyRepo.saveDraft(yesterday)

        let today = DailyEntryDraft(rawText: "Today verification", state: .verifyYesterday)
        try await dailyRepo.saveDraft(today)

        let quest = activeMainQuest(title: "Confirm meeting owner")
        try await questRepo.saveQuest(quest, sourceDailyEntryId: yesterday.id)

        let verifyingStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            verificationRepository: verificationRepo,
            refreshesAIServiceFromKeychain: false
        )
        await verifyingStore.loadPersistedState()
        XCTAssertEqual(verifyingStore.todayDraft.id, today.id)
        XCTAssertEqual(verifyingStore.todayDraft.state, .verifyYesterday)
        XCTAssertEqual(verifyingStore.quests.first?.id, quest.id)

        verifyingStore.selectYesterdayCompletion(.done)
        verifyingStore.selectYesterdayValueRating(.high)
        verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
        verifyingStore.submitTodayStep()
        try await waitUntil(
            verifyingStore.todayDraft.state == .capture,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected verification flow to advance to capture"
        ) {
            verifyingStore.todayDraft.state == .capture
        }

        let verificationForYesterday = try await verificationRepo.verification(for: yesterday.id)
        XCTAssertEqual(verificationForYesterday?.questId, quest.id)
        XCTAssertEqual(verificationForYesterday?.sourceDailyEntryId, yesterday.id)
        let verificationForToday = try await verificationRepo.verification(for: today.id)
        XCTAssertNil(verificationForToday)

        await verifyingStore.loadHistoryRecords()
        let yesterdayRecord = verifyingStore.historyRecords.first { $0.draft.id == yesterday.id }
        XCTAssertEqual(yesterdayRecord?.verification?.questId, quest.id)
        XCTAssertTrue(yesterdayRecord?.sourceIds.contains(verificationForYesterday?.id.uuidString ?? "") == true)
    }

    func testVerifyYesterday_recordsPrinciplePracticeEvidenceWhenQuestMatchesActivePrinciple() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let practiceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)

        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            rawText: "昨天围绕会议负责人机制做了行动。",
            state: .sessionComplete
        )
        try await dailyRepo.saveDraft(yesterday)

        let today = DailyEntryDraft(rawText: "今天确认会前负责人已经写清。", state: .verifyYesterday)
        try await dailyRepo.saveDraft(today)

        let quest = Quest(
            type: .main,
            title: "会前明确负责人并写出验收标准",
            whyItMatters: "避免会议后没有责任人。",
            completionCriteria: "负责人和验收标准已经写在会议记录。",
            expectedResistance: "临时讨论太快。",
            reflectionQuestion: "是否真的减少了职责空白？",
            status: .active
        )
        try await questRepo.saveQuest(quest, sourceDailyEntryId: yesterday.id)

        let principle = PrincipleAsset(
            title: "会前明确负责人",
            summary: "推进前先确认唯一负责人。",
            triggerContext: "跨团队会议",
            actions: ["写出负责人", "写出验收标准"],
            successCriteria: "会后没有职责空白。",
            exceptions: "低风险同步可简化。",
            status: .active
        )
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: yesterday.id)

        let verifyingStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )
        await verifyingStore.loadPersistedState()

        verifyingStore.selectYesterdayCompletion(.done)
        verifyingStore.selectYesterdayValueRating(.high)
        verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
        verifyingStore.submitTodayStep()
        try await waitUntil(
            verifyingStore.todayDraft.state == .capture,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected verification flow to advance to capture"
        ) {
            verifyingStore.todayDraft.state == .capture
        }

        let storedVerification = try await verificationRepo.verification(for: yesterday.id)
        let verification = try XCTUnwrap(storedVerification)
        let evidence = try await practiceRepo.evidence(for: principle.id, limit: 10)

        XCTAssertEqual(evidence.count, 1)
        XCTAssertEqual(evidence.first?.sourceDailyEntryId, yesterday.id)
        XCTAssertEqual(evidence.first?.questId, quest.id)
        XCTAssertEqual(evidence.first?.verificationId, verification.id)
        XCTAssertEqual(evidence.first?.evidenceSource, .verification)
        XCTAssertEqual(evidence.first?.strength, .intentionalPractice)
        XCTAssertTrue(evidence.first?.evidenceSummary.contains("会前明确负责人") == true)
        XCTAssertTrue(evidence.first?.evidenceSummary.contains("匹配信号：写出负责人") == true)
        XCTAssertEqual(evidence.first?.matchSignal, "写出负责人")
        XCTAssertEqual(evidence.first?.attributionPolicyVersion, AppStore.principlePracticeAttributionPolicyVersion)
        XCTAssertEqual(evidence.first?.practiceRole, .secondaryPractice)
    }

    func testVerifyYesterday_skipsPracticeEvidenceWhenSameSignalWasDisputed() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let practiceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)

        let priorEntryId = UUID()
        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            rawText: "昨天围绕会议负责人机制做了行动。",
            state: .sessionComplete
        )
        try await dailyRepo.saveDraft(yesterday)
        let today = DailyEntryDraft(rawText: "今天确认会前负责人已经写清。", state: .verifyYesterday)
        try await dailyRepo.saveDraft(today)

        let quest = Quest(
            type: .main,
            title: "会前明确负责人并写出验收标准",
            whyItMatters: "避免会议后没有责任人。",
            completionCriteria: "负责人和验收标准已经写在会议记录。",
            expectedResistance: "临时讨论太快。",
            reflectionQuestion: "是否真的减少了职责空白？",
            status: .active
        )
        try await questRepo.saveQuest(quest, sourceDailyEntryId: yesterday.id)

        let principle = PrincipleAsset(
            title: "会前明确负责人",
            summary: "推进前先确认唯一负责人。",
            triggerContext: "跨团队会议",
            actions: ["写出负责人", "写出验收标准"],
            successCriteria: "会后没有职责空白。",
            exceptions: "低风险同步可简化。",
            status: .active
        )
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: priorEntryId)

        let disputedEvidence = PrinciplePracticeEvidence(
            principleId: principle.id,
            sourceDailyEntryId: priorEntryId,
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "验证任务显示原则「会前明确负责人」被实际练习：历史任务。",
            matchSignal: "写出负责人",
            attributionPolicyVersion: AppStore.principlePracticeAttributionPolicyVersion
        )
        try await practiceRepo.saveEvidence(disputedEvidence)
        try await practiceRepo.disputeEvidence(
            disputedEvidence.id,
            note: "只是记录了负责人，不应算作主动练习原则。"
        )

        let verifyingStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )
        await verifyingStore.loadPersistedState()

        verifyingStore.selectYesterdayCompletion(.done)
        verifyingStore.selectYesterdayValueRating(.high)
        verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
        verifyingStore.submitTodayStep()
        try await waitUntil(
            verifyingStore.todayDraft.state == .capture,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected verification flow to advance to capture"
        ) {
            verifyingStore.todayDraft.state == .capture
        }

        let activeEvidence = try await practiceRepo.evidence(for: principle.id, limit: 10)
        let disputed = try await practiceRepo.disputedEvidence(for: principle.id, limit: 10)

        XCTAssertTrue(activeEvidence.isEmpty)
        XCTAssertEqual(disputed.map(\.id), [disputedEvidence.id])
    }

    func testVerifyYesterday_recordsPrinciplePracticeEvidenceOnlyOnceForSameVerification() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let practiceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)

        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            rawText: "昨天练习了会前明确负责人。",
            state: .sessionComplete
        )
        try await dailyRepo.saveDraft(yesterday)
        let today = DailyEntryDraft(rawText: "今天再次进入验证。", state: .verifyYesterday)
        try await dailyRepo.saveDraft(today)

        let quest = Quest(
            type: .main,
            title: "会前明确负责人",
            whyItMatters: "减少职责空白。",
            completionCriteria: "会议记录有负责人。",
            expectedResistance: "节奏太快。",
            reflectionQuestion: "是否减少返工？",
            status: .active
        )
        try await questRepo.saveQuest(quest, sourceDailyEntryId: yesterday.id)
        let principle = PrincipleAsset(
            title: "会前明确负责人",
            summary: "推进前先确认唯一负责人。",
            triggerContext: "跨团队会议",
            actions: ["写出负责人"],
            successCriteria: "会后没有职责空白。",
            exceptions: "低风险同步可简化。",
            status: .active
        )
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: yesterday.id)

        let verifyingStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )
        await verifyingStore.loadPersistedState()

        verifyingStore.selectYesterdayCompletion(.done)
        verifyingStore.selectYesterdayValueRating(.high)
        verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
        verifyingStore.submitTodayStep()
        try await waitUntil(
            verifyingStore.todayDraft.state == .capture,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected first verification to advance"
        ) {
            verifyingStore.todayDraft.state == .capture
        }

        verifyingStore.todayDraft.state = .verifyYesterday
        verifyingStore.quests = [quest]
        verifyingStore.selectYesterdayCompletion(.done)
        verifyingStore.selectYesterdayValueRating(.high)
        verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
        verifyingStore.submitTodayStep()
        try await waitUntil(
            verifyingStore.todayDraft.state == .capture,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected second verification to advance"
        ) {
            verifyingStore.todayDraft.state == .capture
        }

        let evidence = try await practiceRepo.evidence(for: principle.id, limit: 10)
        XCTAssertEqual(evidence.count, 1)
    }

    // MARK: - Capture -> Organizing (async card generation, stays at .organizing)

    func testCapture_emptyInput_blocksProgression() async throws {
        try await advanceTo(.capture)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertFalse(store.todayLoopMessage.isEmpty)
    }

    func testCapture_requiresModeBeforeOrganizingCards() async throws {
        try await advanceTo(.capture)
        store.updateTodayCapture("Today I had a meeting about project priorities.")
        store.todayDraft.hasSelectedSessionMode = false
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertTrue(store.todayLoopMessage.contains("请选择"))
    }

    func testCapture_withInput_movesToOrganizing() async throws {
        try await advanceTo(.capture)
        store.selectTodayMode(.deep)
        store.updateTodayCapture("Today I had a meeting about project priorities.")
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .organizing)
    }

    func testCapture_selectedModeIsUsedByOrganizeCardsPrompt() async throws {
        let client = RecordingLLMClient(response: Self.cardsResponse(title: "Deep card"))
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.deep)
        store.updateTodayCapture("Today I had a difficult planning discussion.")
        store.submitTodayStep()
        try await waitForGeneratedCards()

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .organizeCards)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["sessionMode"], SessionMode.deep.rawValue)
        XCTAssertTrue(request.prompt.systemText.contains("Session mode: deep"))
    }

    func testCapture_streamingCardsPopulateBeforeDomainCardsPersist() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let cardRepo = SQLiteThinkingCardRepository(database: database)
        let client = StreamingRecordingLLMClient(tokens: [
            "<MINGSI_STREAM version=\"1\"><CARD><TYPE>task</TYPE><TITLE>准备会议目标</TITLE>",
            "<BODY>会前列出必须确认的问题。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>可验证行动</REASON></CARD></MINGSI_STREAM>"
        ])
        store = AppStore(
            thinkingCardRepository: cardRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("明天会议前要准备目标。")
        store.submitTodayStep()

        try await waitForGeneratedCards()
        XCTAssertEqual(store.todayDraft.state, .organizing)
        XCTAssertEqual(store.streamingCards.count, 1)
        XCTAssertEqual(store.streamingCards[0].status, .closed)
        XCTAssertEqual(store.thinkingCards.first?.title, "准备会议目标")
        XCTAssertTrue(store.streamingStatusText.contains("已生成"))

        try await Task.sleep(for: .milliseconds(150))
        var persistedCards = try await cardRepo.cards(for: store.todayDraft.id)
        XCTAssertTrue(persistedCards.isEmpty, "AI candidates must stay in memory until the user confirms or excludes them.")

        let cardID = try XCTUnwrap(store.thinkingCards.first?.id)
        store.confirmCard(cardID)
        try await Task.sleep(for: .milliseconds(150))
        persistedCards = try await cardRepo.cards(for: store.todayDraft.id)
        XCTAssertEqual(persistedCards.count, 1)
        XCTAssertTrue(persistedCards[0].isConfirmed)
    }

    func testCapture_streamingCardsAreVisibleBeforeStreamCompletes() async throws {
        let client = SuspendedStreamingLLMClient(
            firstToken: "<MINGSI_STREAM version=\"1\"><CARD><TYPE>task</TYPE><TITLE>准备会议目标</TITLE>",
            remainingTokens: [
                "<BODY>会前列出必须确认的问题。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>可验证行动</REASON></CARD></MINGSI_STREAM>"
            ]
        )
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("明天会议前要准备目标。")
        store.submitTodayStep()

        try await waitUntil(
            !store.streamingCards.isEmpty,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected a receiving streaming draft before stream completion"
        ) {
            !store.streamingCards.isEmpty
        }
        XCTAssertEqual(store.thinkingCards.count, 0)
        XCTAssertEqual(store.streamingCards.first?.title, "准备会议目标")
        XCTAssertEqual(store.streamingCards.first?.status, .receiving)

        await client.releaseRemaining()

        try await waitForGeneratedCards()
        XCTAssertEqual(store.thinkingCards.first?.title, "准备会议目标")
        XCTAssertEqual(store.streamingCards.first?.status, .closed)
    }

    func testCapture_burstStreamPresentsCardsOneAtATimeBeforeStreamCompletes() async throws {
        let client = SuspendedStreamingLLMClient(
            firstToken: """
            <MINGSI_STREAM version="1"><CARD><TYPE>task</TYPE><TITLE>准备会议目标</TITLE><BODY>会前列出必须确认的问题。</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>可验证行动</REASON></CARD><CARD><TYPE>risk</TYPE><TITLE>会议结论漂移</TITLE><BODY>如果目标不清楚，结论会被后续重写。</BODY><IMPORTANCE>medium</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>medium</CONFIDENCE><REASON>影响判断校准</REASON></CARD></MINGSI_STREAM>
            """,
            remainingTokens: []
        )
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("明天会议前要准备目标，也担心会议结论漂移。")
        store.submitTodayStep()

        try await waitUntil(
            store.streamingCards.count == 1,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected burst stream to expose the first card before showing every card"
        ) {
            store.streamingCards.count == 1
        }
        XCTAssertEqual(store.thinkingCards.count, 0)

        await client.releaseRemaining()

        try await waitForGeneratedCards()
        XCTAssertEqual(store.thinkingCards.map(\.title), ["准备会议目标", "会议结论漂移"])
        XCTAssertEqual(store.streamingCards.count, 2)
    }

    func testRetryPendingAIRepairs_doesNotRerunOrganizeCardsAfterConfirmedCardsOrDownstreamState() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let client = CountingStreamingLLMClient(tokens: [
            "<CARD><TYPE>task</TYPE><TITLE>后台覆盖</TITLE><BODY>不应该生成</BODY></CARD>"
        ])
        let draft = DailyEntryDraft(
            rawText: "Today already has confirmed card-derived context.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .evidenceCheck,
            state: .answerQuestions
        )
        try await dailyRepo.saveDraft(draft)
        try await promptRunRepo.savePromptRun(
            PromptRun(
                promptId: PromptID.organizeCards.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: [draft.id.uuidString],
                requestSummary: "organize failure",
                error: "HTTP 500"
            )
        )

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            promptRunRepository: promptRunRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPersistedState()
        var confirmedCard = ThinkingCard(type: .fact, title: "已确认事实", body: "已经进入后续追问。")
        confirmedCard.isConfirmed = true
        store.thinkingCards = [confirmedCard]
        store.questions = [
            ReflectionQuestion(question: "已经基于旧卡片生成的问题", whyItMatters: "保护下游一致性。")
        ]

        XCTAssertEqual(store.pendingAIRepairCount, 1)
        store.retryPendingAIRepairs()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(client.streamCallCount, 0)
        XCTAssertEqual(store.thinkingCards.map(\.title), ["已确认事实"])
        XCTAssertEqual(store.pendingAIRepairCount, 0)
    }

    // MARK: - Organizing -> ReviewCards

    func testOrganizing_emptyCards_blocksProgression() async throws {
        try await advanceTo(.organizing)
        store.thinkingCards = []
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .organizing)
    }

    func testOrganizing_withCards_advancesToReviewCards() async throws {
        try await advanceTo(.organizing)
        store.thinkingCards = [
            ThinkingCard(type: .problem, title: "Test", body: "Body")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .reviewCards)
    }

    func testEditCard_updatesCardAndClearsDownstreamArtifacts() async throws {
        try await advanceTo(.reviewCards)
        var card = ThinkingCard(type: .fact, title: "Original", body: "Body")
        card.isConfirmed = true
        store.thinkingCards = [card]
        store.questions = [ReflectionQuestion(question: "Q?", whyItMatters: "M")]
        store.quests = [Quest(type: .main, title: "Quest", whyItMatters: "W",
                              completionCriteria: "C", expectedResistance: "E",
                              reflectionQuestion: "R")]
        store.principles = [PrincipleAsset(title: "P", summary: "S", triggerContext: "T",
                                            actions: ["A"], successCriteria: "SC",
                                            exceptions: "E")]

        store.updateCard(
            card.id,
            type: .risk,
            title: "Edited risk",
            body: "Edited body",
            priority: .high,
            sensitivity: .possiblySensitive
        )

        XCTAssertEqual(store.thinkingCards.first?.type, .risk)
        XCTAssertEqual(store.thinkingCards.first?.title, "Edited risk")
        XCTAssertEqual(store.thinkingCards.first?.priority, .high)
        XCTAssertEqual(store.thinkingCards.first?.sensitivity, .possiblySensitive)
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertTrue(store.quests.isEmpty)
        XCTAssertTrue(store.principles.isEmpty)
    }

    // MARK: - ReviewCards -> SelectLens

    func testReviewCards_noConfirmedCards_blocksProgression() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = [
            ThinkingCard(type: .fact, title: "Unconfirmed", body: "Body")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .reviewCards)
    }

    func testReviewCards_withConfirmedCards_advancesToSelectLens() async throws {
        try await advanceTo(.reviewCards)
        var card = ThinkingCard(type: .fact, title: "Test", body: "Body")
        card.isConfirmed = true
        store.thinkingCards = [card]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectLens)
    }

    func testCoachEngine_diagnosesFourThinkingPhasesFromConfirmedCards() {
        let engine = CoachEngine()

        let exploration = engine.diagnose(cards: confirmedCards([
            ThinkingCard(type: .idea, title: "也许要重排优先级", body: "目前只是感觉。"),
            ThinkingCard(type: .communication, title: "同步会没有结论", body: "没人确认前提。")
        ]))
        XCTAssertEqual(exploration.phase, .exploreProblem)
        XCTAssertEqual(exploration.readiness, .notReady)
        XCTAssertEqual(exploration.recommendedMove, .askClarifyingQuestion)

        let judgment = engine.diagnose(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "先保留旧逻辑", body: "这是当前倾向。"),
            ThinkingCard(type: .idea, title: "可能要重排路线", body: "还没有拆开事实和判断。")
        ]))
        XCTAssertEqual(judgment.phase, .clarifyJudgment)
        XCTAssertEqual(judgment.recommendedMove, .surfaceEvidenceGap)

        let evidenceGap = engine.diagnose(cards: confirmedCards([
            ThinkingCard(type: .risk, title: "验收口径不清", body: "缺少事实支撑。", priority: .high),
            ThinkingCard(type: .problem, title: "判断依据不足", body: "目前只有推测。", priority: .medium)
        ]))
        XCTAssertEqual(evidenceGap.phase, .fillEvidenceGap)
        XCTAssertEqual(evidenceGap.readiness, .notReady)
        XCTAssertEqual(evidenceGap.recommendedMove, .slowDownConvergence)

        let action = engine.diagnose(cards: confirmedCards([
            ThinkingCard(type: .task, title: "确认接口负责人", body: "明天先定边界。", priority: .high),
            ThinkingCard(type: .decision, title: "短期兼容旧逻辑", body: "先保证交付。", priority: .medium),
            ThinkingCard(type: .fact, title: "客户承诺未落文档", body: "需要先确认是否真实存在。", priority: .medium)
        ]))
        XCTAssertEqual(action.phase, .formAction)
        XCTAssertEqual(action.readiness, .ready)
        XCTAssertEqual(action.recommendedMove, .recommendTrainingLens)
    }

    func testCoachTurnPolicy_recordsOpenEvidenceGapsFromInsufficientCards() {
        let turn = CoachTurnPolicy().makeInitialTurn(cards: confirmedCards([
            ThinkingCard(type: .risk, title: "验收口径不清", body: "缺少事实支撑。", priority: .high),
            ThinkingCard(type: .problem, title: "判断依据不足", body: "目前只有推测。", priority: .medium)
        ]))

        XCTAssertEqual(turn.phase, .fillEvidenceGap)
        XCTAssertEqual(turn.readiness, .notReady)
        XCTAssertEqual(turn.recommendedMove, .slowDownConvergence)
        XCTAssertEqual(turn.openEvidenceGaps, [.missingObservation, .missingBaseline])
        XCTAssertTrue(turn.baselineChecks.contains(.evidenceGap))
        XCTAssertEqual(turn.decisionSource, .coachRecommended)
        XCTAssertEqual(turn.policyVersion, CoachTurnPolicy.policyVersion)
        XCTAssertTrue(turn.turnSummary.contains("证据"))
    }

    func testCoachDecisionPolicyV2_diagnosesInsufficientEvidenceBeforeConvergence() {
        let decision = CoachDecisionPolicyV2().decide(cards: confirmedCards([
            ThinkingCard(type: .risk, title: "验收口径不清", body: "缺少事实支撑。", priority: .high),
            ThinkingCard(type: .problem, title: "判断依据不足", body: "目前只有推测。", priority: .medium)
        ]))

        XCTAssertEqual(decision.policyVersion, CoachDecisionPolicyV2.policyVersion)
        XCTAssertEqual(decision.phase, .fillEvidenceGap)
        XCTAssertEqual(decision.readiness, .notReady)
        XCTAssertEqual(decision.recommendedMove, .slowDownConvergence)
        XCTAssertEqual(decision.primaryTrainingDimension, .evidenceDiscipline)
        XCTAssertEqual(decision.convergenceRisk, .high)
        XCTAssertTrue(decision.openEvidenceGaps.contains(.missingObservation))
        XCTAssertTrue(decision.openEvidenceGaps.contains(.missingBaseline))
        XCTAssertLessThan(decision.scores.evidenceReadiness, 50)
        XCTAssertTrue(decision.proceedWhen.contains("可观察"))
    }

    func testCoachDecisionPolicyV2_detectsPrematureConvergence() {
        let decision = CoachDecisionPolicyV2().decide(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "今天直接上线", body: "我倾向于继续推进，但没有验收标准。", priority: .high),
            ThinkingCard(type: .risk, title: "失败影响客户", body: "风险较高，依据不足。", priority: .high)
        ]))

        XCTAssertEqual(decision.readiness, .notReady)
        XCTAssertEqual(decision.recommendedMove, .slowDownConvergence)
        XCTAssertEqual(decision.convergenceRisk, .high)
        XCTAssertGreaterThanOrEqual(decision.scores.convergenceRisk, 75)
        XCTAssertTrue(decision.whyNow.contains("过早收敛"))
    }

    func testCoachDecisionPolicyV2_selectsJudgmentCalibrationWhenPredictionMeetsOutcomeEvidence() {
        let decision = CoachDecisionPolicyV2().decide(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "原本预测返工会下降", body: "昨天有 70% 把握认为小验收能减少返工。"),
            ThinkingCard(type: .fact, title: "实际结果相反", body: "今天实际返工没有下降，结果和预期相反。")
        ]))

        XCTAssertEqual(decision.primaryTrainingDimension, .judgmentCalibration)
        XCTAssertGreaterThanOrEqual(decision.scores.calibrationOpportunity, 70)
        XCTAssertTrue(decision.openEvidenceGaps.contains(.missingCalibrationSignal))
        XCTAssertTrue(decision.expectedUpdate.contains("预测"))
    }

    func testCoachDecisionPolicyV2_selectsSystemFeedbackForLoopsDelaysAndDownstreamEffects() {
        let decision = CoachDecisionPolicyV2().decide(cards: confirmedCards([
            ThinkingCard(type: .problem, title: "修复越多返工越多", body: "临时修复形成反馈回路，延迟两周后放大。"),
            ThinkingCard(type: .risk, title: "下游团队被连锁影响", body: "二阶后果是验收和沟通成本继续增加。")
        ]))

        XCTAssertEqual(decision.primaryTrainingDimension, .systemFeedbackAwareness)
        XCTAssertGreaterThanOrEqual(decision.scores.systemFeedback, 70)
        XCTAssertTrue(decision.expectedUpdate.contains("反馈"))
        XCTAssertTrue(decision.proceedWhen.contains("信号"))
    }

    func testCoachDecisionPolicyV2_recognizesActionableStateWhenEvidenceAndCriteriaExist() {
        let decision = CoachDecisionPolicyV2().decide(cards: confirmedCards([
            ThinkingCard(type: .task, title: "明天找 Alex 确认验收标准", body: "负责人是 Alex，明天产出一页验收文档。", priority: .high),
            ThinkingCard(type: .decision, title: "先做小范围验证", body: "不直接全量上线。"),
            ThinkingCard(type: .fact, title: "当前接口只影响一个客户", body: "影响范围可控，有可观察结果。")
        ]))

        XCTAssertEqual(decision.phase, .formAction)
        XCTAssertEqual(decision.readiness, .ready)
        XCTAssertEqual(decision.recommendedMove, .generateQuest)
        XCTAssertEqual(decision.convergenceRisk, .low)
        XCTAssertEqual(decision.openEvidenceGaps, [])
        XCTAssertGreaterThanOrEqual(decision.scores.actionTestability, 75)
        XCTAssertTrue(decision.proceedWhen.contains("明日"))
    }

    func testCoachObservationPolicy_identifiesActionWithoutGoalAsGoalGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .task, title: "明天先拉会推进", body: "我打算先找几个人开会，把事情往前推。"),
            ThinkingCard(type: .communication, title: "讨论有点混乱", body: "大家说了很多，但不知道到底服务于谁。")
        ]))

        XCTAssertEqual(observation.policyVersion, CoachObservationPolicy.policyVersion)
        XCTAssertEqual(observation.primaryGap, .goal)
        XCTAssertEqual(observation.trainingAbility, .judgment)
        XCTAssertTrue(observation.providedMaterials.contains(.action))
        XCTAssertTrue(observation.missingMaterials.contains(.goal))
        XCTAssertTrue(observation.feedback.observed.contains("动作"))
        XCTAssertTrue(observation.feedback.ask.contains("谁"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("成功标准"))
    }

    func testCoachObservationPolicy_identifiesJudgmentWithoutFactAsObservationGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "我觉得方案不可行", body: "这件事大概率会失败。"),
            ThinkingCard(type: .idea, title: "可能是沟通问题", body: "只是感觉，没有看到明确事实。")
        ]))

        XCTAssertEqual(observation.primaryGap, .observation)
        XCTAssertEqual(observation.trainingAbility, .observation)
        XCTAssertTrue(observation.providedMaterials.contains(.judgment))
        XCTAssertTrue(observation.missingMaterials.contains(.fact))
        XCTAssertTrue(observation.thinkingProcessObservation.contains("结论"))
        XCTAssertTrue(observation.feedback.training.contains("观察力"))
        XCTAssertTrue(observation.feedback.ask.contains("事实"))
    }

    func testCoachObservationPolicy_identifiesJudgmentWithoutStandardAsJudgmentGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .fact,
                title: "注册反馈",
                body: "事实是上线后客服收到 12 条用户反馈，3 个用户卡在注册步骤。"
            ),
            ThinkingCard(
                type: .decision,
                title: "优先改注册流程",
                body: "我判断注册流程需要优先改。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .judgment)
        XCTAssertEqual(observation.trainingAbility, .judgment)
        XCTAssertTrue(observation.providedMaterials.contains(.fact))
        XCTAssertTrue(observation.providedMaterials.contains(.judgment))
        XCTAssertTrue(observation.missingMaterials.contains(.standard))
        XCTAssertTrue(observation.thinkingProcessObservation.contains("标准"))
        XCTAssertTrue(observation.feedback.ask.contains("判断标准"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("标准"))
    }

    func testCoachObservationPolicy_identifiesJudgmentWithoutCalibrationSignalAsCalibrationGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .fact,
                title: "注册反馈",
                body: "事实是客服记录了 12 条用户反馈，3 个用户卡在注册步骤。"
            ),
            ThinkingCard(
                type: .decision,
                title: "优先改注册流程",
                body: "我判断应该优先改注册流程，判断标准是影响新用户完成首次使用。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .calibration)
        XCTAssertEqual(observation.trainingAbility, .calibration)
        XCTAssertTrue(observation.providedMaterials.contains(.fact))
        XCTAssertTrue(observation.providedMaterials.contains(.judgment))
        XCTAssertTrue(observation.providedMaterials.contains(.standard))
        XCTAssertTrue(observation.missingMaterials.contains(.calibrationSignal))
        XCTAssertTrue(observation.thinkingProcessObservation.contains("未来"))
        XCTAssertTrue(observation.feedback.ask.contains("信号"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("校准信号"))
    }

    func testCoachObservationPolicy_identifiesExperienceMentionWithoutFitCheck() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "沿用以前的推进方式", body: "之前这样做有效，所以这次也想照着做。"),
            ThinkingCard(type: .idea, title: "可能要复用经验", body: "还没判断这次条件是不是一样。")
        ]))

        XCTAssertEqual(observation.primaryGap, .experience)
        XCTAssertEqual(observation.trainingAbility, .calibration)
        XCTAssertTrue(observation.secondaryGaps.contains(.counterexample))
        XCTAssertTrue(observation.feedback.ask.contains("复现、调整，还是否定"))
        XCTAssertTrue(observation.experienceReplayPrompt.contains("条件"))
    }

    func testCoachObservationPolicy_identifiesThinStoryAsNarrativeGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .idea, title: "今天很乱", body: "感觉方案推进不下去，我有点焦虑。")
        ]))

        XCTAssertEqual(observation.primaryGap, .narrative)
        XCTAssertEqual(observation.trainingAbility, .description)
        XCTAssertTrue(observation.missingMaterials.contains(.background))
        XCTAssertTrue(observation.missingMaterials.contains(.trigger))
        XCTAssertTrue(observation.missingMaterials.contains(.result))
        XCTAssertTrue(observation.thinkingProcessObservation.contains("别人可以复盘"))
        XCTAssertTrue(observation.feedback.observed.contains("感受"))
        XCTAssertTrue(observation.feedback.diagnosis.contains("讲述 gap"))
        XCTAssertTrue(observation.feedback.ask.contains("前因后果"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("背景、触发点、行动和结果"))
    }

    func testCoachObservation_translatesMaterialInventoryIntoNarrativeTraining() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .idea, title: "今天很乱", body: "我只有一种很乱和焦虑的感受。")
        ]))

        XCTAssertTrue(observation.narrativeTrainingLine.contains("讲清楚一件事"))
        XCTAssertTrue(observation.narrativeTrainingLine.contains("已说清：感受"))
        XCTAssertTrue(observation.narrativeTrainingLine.contains("先补：交代背景、说明对象、说清触发、写出做法、补上结果"))
    }

    func testCoachObservationFeedback_namesFoundationalCapabilityLane() {
        let narrativeObservation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .idea, title: "今天很乱", body: "我只有很乱和焦虑的感受。")
        ]))

        XCTAssertTrue(narrativeObservation.feedback.training.contains("沟通力"))
        XCTAssertTrue(narrativeObservation.feedback.training.contains("描述力"))

        let thinkingObservation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "判断方案要重写", body: "我觉得方案应该重写。")
        ]))

        XCTAssertTrue(thinkingObservation.feedback.training.contains("思考力"))
        XCTAssertTrue(thinkingObservation.feedback.training.contains("观察力"))
    }

    func testCoachObservation_experienceReplayTrainingLineUsesReproduceAdaptReject() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .decision, title: "沿用以前的推进方式", body: "之前这样做有效，所以这次也想照着做。"),
            ThinkingCard(type: .idea, title: "可能要复用经验", body: "还没判断这次条件是不是一样。")
        ]))

        XCTAssertTrue(observation.experienceReplayTrainingLine.contains("复现：条件相同，可以照用哪条做法"))
        XCTAssertTrue(observation.experienceReplayTrainingLine.contains("调整：条件不同，哪部分要改"))
        XCTAssertTrue(observation.experienceReplayTrainingLine.contains("否定：这条经验为什么不适用"))
    }

    func testCoachObservationPolicy_identifiesMissingAffectedObjectAsDescriptionGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .task,
                title: "方案推进卡住",
                body: "今天需求评审后，我打算先重写方案。因为会上大家提出很多意见，后来方案没有通过。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .object)
        XCTAssertEqual(observation.trainingAbility, .description)
        XCTAssertTrue(observation.providedMaterials.contains(.background))
        XCTAssertTrue(observation.providedMaterials.contains(.trigger))
        XCTAssertTrue(observation.providedMaterials.contains(.action))
        XCTAssertTrue(observation.providedMaterials.contains(.result))
        XCTAssertTrue(observation.missingMaterials.contains(.object))
        XCTAssertTrue(observation.feedback.diagnosis.contains("对象"))
        XCTAssertTrue(observation.feedback.ask.contains("谁"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("对象"))
    }

    func testCoachObservationPolicy_identifiesBlockedProgressWithoutConstraintAsAnalysisGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .problem,
                title: "跨团队推进卡住",
                body: "今天在项目沟通中，我和产品团队讨论接口方案，但推进不下去，后来决定先暂停方案调整。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .constraint)
        XCTAssertEqual(observation.trainingAbility, .analysis)
        XCTAssertTrue(observation.providedMaterials.contains(.background))
        XCTAssertTrue(observation.providedMaterials.contains(.object))
        XCTAssertTrue(observation.providedMaterials.contains(.action))
        XCTAssertTrue(observation.missingMaterials.contains(.constraint))
        XCTAssertTrue(observation.feedback.diagnosis.contains("约束"))
        XCTAssertTrue(observation.feedback.ask.contains("限制"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("边界"))
    }

    func testCoachObservationPolicy_identifiesUntracedCausalExplanationAsAnalysisGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .fact,
                title: "会议结果",
                body: "事实是会议结束后没有明确负责人，后来接口方案返工。"
            ),
            ThinkingCard(
                type: .idea,
                title: "我的解释",
                body: "我认为返工是因为大家都不想负责，所以方案没有通过。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .causal)
        XCTAssertEqual(observation.trainingAbility, .analysis)
        XCTAssertTrue(observation.providedMaterials.contains(.fact))
        XCTAssertTrue(observation.providedMaterials.contains(.interpretation))
        XCTAssertTrue(observation.providedMaterials.contains(.judgment))
        XCTAssertTrue(observation.thinkingProcessObservation.contains("因果链"))
        XCTAssertTrue(observation.feedback.diagnosis.contains("因果"))
        XCTAssertTrue(observation.feedback.ask.contains("中间"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("链条"))
    }

    func testCoachObservationPolicy_identifiesUnchallengedExplanationAsCounterexampleGap() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .fact,
                title: "方案反馈",
                body: "事实是用户代表在评审里提出三处流程问题，后来方案延期。"
            ),
            ThinkingCard(
                type: .idea,
                title: "我的解释",
                body: "我认为延期是因为流程问题影响了验收判断，中间链条是评审问题先让验收标准变模糊，再导致方案延期。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .counterexample)
        XCTAssertEqual(observation.trainingAbility, .analysis)
        XCTAssertTrue(observation.providedMaterials.contains(.fact))
        XCTAssertTrue(observation.providedMaterials.contains(.interpretation))
        XCTAssertTrue(observation.providedMaterials.contains(.judgment))
        XCTAssertTrue(observation.thinkingProcessObservation.contains("反例"))
        XCTAssertTrue(observation.feedback.diagnosis.contains("反例"))
        XCTAssertTrue(observation.feedback.ask.contains("推翻"))
        XCTAssertTrue(observation.feedback.proceedWhen.contains("替代解释"))
    }

    func testCoachObservationPolicy_counterexampleGapReplaysPastPrematureClosureExperience() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .fact,
                title: "方案反馈",
                body: "事实是用户代表在评审里提出三处流程问题，后来方案延期。"
            ),
            ThinkingCard(
                type: .idea,
                title: "我的解释",
                body: "我认为延期是因为流程问题影响了验收判断，中间链条是评审问题先让验收标准变模糊，再导致方案延期。"
            )
        ]))

        XCTAssertEqual(observation.primaryGap, .counterexample)
        XCTAssertTrue(observation.experienceReplayPrompt.contains("忽略反例"))
        XCTAssertTrue(observation.experienceReplayPrompt.contains("过早收敛"))
        XCTAssertTrue(observation.experienceReplayPrompt.contains("复现哪条反证检查"))
    }

    func testCoachObservationPolicy_experienceReplayPromptMatchesEachTrainingGap() {
        let cases: [(gap: CoachObservationGap, requiredFragments: [String])] = [
            (.narrative, ["讲述不清", "复现哪条讲述顺序"]),
            (.object, ["没有说清服务对象", "复现哪条对象检查"]),
            (.constraint, ["忽略限制条件", "复现哪条边界检查"]),
            (.causal, ["误把相关当原因", "复现哪条因果检查"]),
            (.judgment, ["判断标准不清", "复现哪条取舍检查"]),
            (.execution, ["行动不可检查", "复现哪条执行检查"]),
            (.calibration, ["没有预设校准信号", "复现哪条结果检查"])
        ]

        for testCase in cases {
            let prompt = observationPrompt(for: testCase.gap)
            XCTAssertFalse(
                prompt.contains("回想一次相似经验"),
                "\(testCase.gap) should not fall back to a generic replay prompt."
            )
            for fragment in testCase.requiredFragments {
                XCTAssertTrue(
                    prompt.contains(fragment),
                    "\(testCase.gap) replay prompt should contain \(fragment), got: \(prompt)"
                )
            }
        }
    }

    func testCoachObservationPolicy_trainsDescriptionBeforeGoalWhenActionCannotBeReplayed() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .task, title: "我今天推进了方案", body: "我今天推进了一下方案，感觉还是卡住了。")
        ]))

        XCTAssertEqual(observation.primaryGap, .narrative)
        XCTAssertEqual(observation.trainingAbility, .description)
        XCTAssertTrue(observation.providedMaterials.contains(.action))
        XCTAssertTrue(observation.missingMaterials.contains(.background))
        XCTAssertTrue(observation.missingMaterials.contains(.object))
        XCTAssertTrue(observation.missingMaterials.contains(.trigger))
        XCTAssertTrue(observation.missingMaterials.contains(.result))
        XCTAssertTrue(observation.feedback.training.contains("描述力"))
        XCTAssertTrue(observation.feedback.ask.contains("什么背景下"))
    }

    func testCoachObservationPolicy_separatesFactFeelingInterpretationJudgmentAndAction() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(
                type: .fact,
                title: "会议记录",
                body: "事实是会议结束后没有明确负责人。"
            ),
            ThinkingCard(
                type: .idea,
                title: "我的反应",
                body: "我感到焦虑，猜测大家可能都不想负责，所以判断这个方案会返工。"
            ),
            ThinkingCard(
                type: .task,
                title: "明天动作",
                body: "我打算明天先让 Alex 写清负责人和验收标准。"
            )
        ]))

        XCTAssertTrue(observation.providedMaterials.contains(.fact))
        XCTAssertTrue(observation.providedMaterials.contains(.feeling))
        XCTAssertTrue(observation.providedMaterials.contains(.interpretation))
        XCTAssertTrue(observation.providedMaterials.contains(.judgment))
        XCTAssertTrue(observation.providedMaterials.contains(.action))
        XCTAssertTrue(observation.feedback.ask.contains("事实、感受、解释、判断"))
    }

    func testCoachObservationPolicy_keepsOnePrimaryGapPerTurn() {
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .task, title: "先照以前方式推进", body: "我打算先拉会处理，沿用以前有效的做法。"),
            ThinkingCard(type: .decision, title: "这次应该也有效", body: "我觉得可以先推进，但还没说清目标，也没判断这次条件是否一样。")
        ]))

        XCTAssertEqual(observation.primaryGap, .experience)
        XCTAssertFalse(observation.secondaryGaps.contains(observation.primaryGap))
        XCTAssertEqual(observation.feedback.ask.filter { $0 == "？" }.count, 1)
    }

    func testCoachObservationPolicyObservesAnswerTextAsTrainingMaterials() {
        let observation = CoachObservationPolicy().observe(text: "先让 Alex 写清验收标准。")

        XCTAssertTrue(observation.providedMaterials.contains(.object))
        XCTAssertTrue(observation.providedMaterials.contains(.action))
        XCTAssertTrue(observation.providedMaterials.contains(.standard))
        XCTAssertTrue(observation.missingMaterials.contains(.goal))
        XCTAssertTrue(observation.narrativeTrainingLine.contains("已说清：说明对象、写出做法、成功标准"))
        XCTAssertTrue(observation.narrativeTrainingLine.contains("先补：目标"))
    }

    func testCaptureMaterialObservationCoachesWhileUserWrites() {
        store.todayDraft.state = .capture
        store.updateTodayCapture("先让 Alex 写清验收标准。")

        XCTAssertEqual(
            store.coachCaptureMaterialObservation,
            "思考力中的判断力：行动不能先替代目标。请补：如果这件事做对了，谁的什么问题会变少，成功标准是什么？"
        )
    }

    func testCaptureMaterialObservationChallengesVagueStoryAsDescriptionTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("今天有点乱，感觉推进不下去。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("沟通力"))
        XCTAssertTrue(line.contains("描述力"))
        XCTAssertTrue(line.contains("还不是可复述事件"))
        XCTAssertTrue(line.contains("下一句先补"))
        XCTAssertTrue(line.contains("什么背景下，谁做了什么，触发点是什么，后来发生了什么"))
    }

    func testCaptureMaterialObservationChallengesExperienceReplayWithoutFitCheck() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("之前这样做有效，所以这次我也打算照着做。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("过往经验复现训练"))
        XCTAssertTrue(line.contains("旧经验不能直接当成答案"))
        XCTAssertTrue(line.contains("复现、调整，还是否定"))
        XCTAssertTrue(line.contains("条件差异"))
    }

    func testCaptureMaterialObservationChallengesBlockedProgressAsConstraintTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("今天在项目沟通中，我和产品团队讨论接口方案，但推进不下去，后来决定先暂停方案调整。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("思考力中的分析力"))
        XCTAssertTrue(line.contains("还没说清具体限制"))
        XCTAssertTrue(line.contains("时间、资源、权限、信息、关系还是系统边界"))
    }

    func testCaptureMaterialObservationChallengesCausalShortcutAsAnalysisTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("我看到会议结束后没有明确负责人，后来接口方案实际返工。因为大家都不想负责，所以方案没有通过。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("思考力中的分析力"))
        XCTAssertTrue(line.contains("因果解释"))
        XCTAssertTrue(line.contains("A 到 B 中间发生了什么"))
        XCTAssertTrue(line.contains("哪个环节最关键"))
    }

    func testCaptureMaterialObservationChallengesUnchallengedExplanationAsCounterexampleTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("我看到用户代表在评审里提出三处流程问题，后来方案实际延期。我认为延期是因为流程问题影响了验收判断，中间链条是评审问题先让验收标准变模糊，再导致方案延期。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("思考力中的分析力"))
        XCTAssertTrue(line.contains("反例"))
        XCTAssertTrue(line.contains("替代解释"))
        XCTAssertTrue(line.contains("削弱当前解释"))
    }

    func testCaptureMaterialObservationChallengesActionWithoutGoalAsJudgmentTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("先让 Alex 写清验收标准。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("思考力中的判断力"))
        XCTAssertTrue(line.contains("行动不能先替代目标"))
        XCTAssertTrue(line.contains("谁的什么问题会变少"))
        XCTAssertTrue(line.contains("成功标准"))
    }

    func testCaptureMaterialObservationChallengesVagueActionAsExecutionTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("为了让 Alex 减少返工，明天推进方案处理一下。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("执行力"))
        XCTAssertTrue(line.contains("还不是可检查结果"))
        XCTAssertTrue(line.contains("明天最小的一步"))
        XCTAssertTrue(line.contains("完成后留下什么证据"))
    }

    func testCaptureMaterialObservationChallengesJudgmentWithoutEvidenceAsObservationTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("我觉得这个方案大概率会返工。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("观察力"))
        XCTAssertTrue(line.contains("判断不能先当结论"))
        XCTAssertTrue(line.contains("可观察事实"))
        XCTAssertTrue(line.contains("事实和解释分开"))
    }

    func testCaptureMaterialObservationChallengesJudgmentWithoutStandardAsJudgmentTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("我看到客服记录了 12 条用户反馈，3 个用户卡在注册步骤。我判断注册流程需要优先改。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("思考力中的判断力"))
        XCTAssertTrue(line.contains("判断不能只停在结论"))
        XCTAssertTrue(line.contains("判断标准"))
        XCTAssertTrue(line.contains("取舍依据"))
    }

    func testCaptureMaterialObservationChallengesJudgmentWithoutCalibrationSignalAsCalibrationTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("我看到客服记录了 12 条用户反馈，3 个用户卡在注册步骤。我判断注册流程需要优先改，判断标准是影响新用户完成首次使用。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("思考力中的校准力"))
        XCTAssertTrue(line.contains("判断需要未来信号"))
        XCTAssertTrue(line.contains("明天或近期哪个信号"))
        XCTAssertTrue(line.contains("更新判断"))
    }

    func testCaptureMaterialObservationChallengesMissingObjectAsDescriptionTraining() throws {
        store.todayDraft.state = .capture
        store.updateTodayCapture("今天需求评审后，我打算先重写方案，后来方案没有通过。")

        let line = try XCTUnwrap(store.coachCaptureMaterialObservation)
        XCTAssertTrue(line.contains("沟通力中的描述力"))
        XCTAssertTrue(line.contains("还没说清服务对象"))
        XCTAssertTrue(line.contains("影响谁"))
        XCTAssertTrue(line.contains("谁的什么问题"))
    }

    func testCoachTeachingPolicy_notReadyEvidenceRouteStartsWithEvidenceCollection() {
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .slowDownConvergence,
            reason: "当前存在高风险、问题或明确证据缺口，直接行动会过早收敛。",
            openEvidenceGaps: [.missingObservation, .missingBaseline],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .testableAction],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "回答仍未关闭主要证据缺口，继续追问而不是直接收敛。"
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
            recommendationReason: "当前最需要先补证据。",
            confidence: 0.82,
            policyVersion: "test",
            alternativeLensIds: [],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .testableAction],
            primaryTrainingDimension: .evidenceDiscipline,
            secondaryTrainingDimensions: [],
            baselineTrainingDimensions: [.factInterpretationSeparation, .testableActionDesign],
            userSelectedLensId: nil,
            finalLensId: ThinkingLens.evidenceCheck.rawValue,
            source: .coachRecommended,
            overrideBoundary: ""
        )

        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: prescription)

        XCTAssertEqual(plan.policyVersion, CoachTeachingPolicy.policyVersion)
        XCTAssertTrue(plan.missingMoveTitle.contains("可观察证据"))
        XCTAssertEqual(plan.trainingTargetTitle, ThinkingTrainingDimension.evidenceDiscipline.displayTitle)
        XCTAssertEqual(plan.trainingTargetLine, "思考力中的证据意识")
        XCTAssertTrue(plan.whyNotAnswer.contains("未经验证"))
        XCTAssertTrue(plan.proceedStandard.contains("可观察事实"))
        XCTAssertEqual(plan.routeSteps.first, "补上一个可观察事实")
        XCTAssertTrue(plan.repairQuestion.contains("刚才的回答"))
        XCTAssertTrue(plan.repairQuestion.contains("事实"))
        XCTAssertTrue(plan.experienceReplayPrompt.contains("过往"))
        XCTAssertTrue(plan.experienceReplayPrompt.contains("复现"))
    }

    func testCoachTeachingPolicy_readyRouteFormsTomorrowValidation() {
        let turn = CoachTurnState(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "已有任务、事实或判断，可以把下一步设计成验证行动。",
            openEvidenceGaps: [],
            baselineChecks: [.testableAction, .judgmentUpdate],
            decisionSource: .coachAccepted,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "回答补足了关键证据，教练轮次从追问推进到形成可验证行动。"
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.judgmentCalibration.rawValue,
            recommendedPromptId: ThinkingLens.judgmentCalibration.catalogItem.promptId,
            recommendationReason: "当前可以把判断转成验证行动。",
            confidence: 0.76,
            policyVersion: "test",
            alternativeLensIds: [],
            baselineChecks: [.testableAction, .judgmentUpdate],
            primaryTrainingDimension: .testableActionDesign,
            secondaryTrainingDimensions: [],
            baselineTrainingDimensions: [.judgmentCalibration],
            userSelectedLensId: nil,
            finalLensId: ThinkingLens.judgmentCalibration.rawValue,
            source: .coachRecommended,
            overrideBoundary: ""
        )

        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: prescription)

        XCTAssertTrue(plan.missingMoveTitle.contains("明天能留下证据"))
        XCTAssertEqual(plan.trainingTargetTitle, ThinkingTrainingDimension.testableActionDesign.displayTitle)
        XCTAssertEqual(plan.trainingTargetLine, "执行力中的可验证行动")
        XCTAssertTrue(plan.whyNotAnswer.contains("足够形成验证行动"))
        XCTAssertTrue(plan.proceedStandard.contains("明日行动"))
        XCTAssertEqual(plan.routeSteps, ["固定当前判断", "设计一个明日验证行动", "明天用结果校准判断"])
    }

    func testCoachAnswerFeedbackPolicySeparatesRepairedAndMissingTrainingMaterials() {
        let previous = CoachTurnState(
            phase: .clarifyJudgment,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "用户已经有判断倾向，但事实、解释和依据还需要拆开。",
            openEvidenceGaps: [.missingObservation, .missingCausalLink],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先拆事实和解释。"
        )
        let question = ReflectionQuestion(
            question: "哪一句是可观察事实，哪一句是解释？",
            whyItMatters: "它防止把解释当事实。",
            evidenceGapType: .missingObservation,
            answerUse: .collectEvidence,
            lensMove: .factInterpretationSplit,
            answer: "事实是客户代表在评审里提出三处流程问题；我的解释是这些问题让验收标准变模糊。"
        )
        let updated = CoachTurnPolicy().updateAfterAnswers(
            cards: confirmedCards([
                ThinkingCard(type: .decision, title: "延期原因", body: "我认为延期是流程问题影响验收。")
            ]),
            questions: [question],
            previous: previous
        )

        let feedback = CoachAnswerFeedbackPolicy().makeFeedback(
            turn: updated,
            previous: previous,
            questions: [question],
            prescription: nil
        )

        XCTAssertEqual(feedback.readiness, .notReady)
        XCTAssertFalse(feedback.canProceedToValidation)
        XCTAssertTrue(feedback.coachCritiqueLine.contains("教练批改"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("这不是合格复盘"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("刚补上：缺观察事实"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("还要训练：缺因果链"))
        XCTAssertTrue(feedback.repairedLine.contains("缺观察事实"))
        XCTAssertTrue(feedback.repairedLine.contains("已补训练材料"))
        XCTAssertTrue(feedback.missingLine.contains("缺因果链"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("因果链"))
        XCTAssertTrue(feedback.experienceReplayPrompt.contains("过往"))
        XCTAssertEqual(feedback.experienceReplayDecisionLine, ExperienceReplayTraining.line)
        XCTAssertTrue(feedback.experienceReplayDecisionLine.contains(ExperienceReplayTraining.reproduceLine))
        XCTAssertTrue(feedback.experienceReplayDecisionLine.contains(ExperienceReplayTraining.adaptLine))
        XCTAssertTrue(feedback.experienceReplayDecisionLine.contains(ExperienceReplayTraining.rejectLine))
        XCTAssertTrue(feedback.proceedLine.contains("不能进入明日验证"))
        XCTAssertTrue(feedback.judgmentSentencePrompt.contains("我现在相信 X"))
    }

    func testCoachAnswerFeedbackPolicyFramesUnresolvedAnswerAsTrainingCorrection() {
        let previous = CoachTurnState(
            phase: .clarifyJudgment,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "先补观察事实和因果链。",
            openEvidenceGaps: [.missingObservation, .missingCausalLink],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先把判断拆开。"
        )
        let question = ReflectionQuestion(
            question: "哪一句是可观察事实，哪一句是解释？",
            whyItMatters: "它防止把解释当事实。",
            evidenceGapType: .missingObservation,
            answerUse: .collectEvidence,
            lensMove: .factInterpretationSplit,
            answer: "事实是客户代表在评审里提出三处流程问题；我的解释是这些问题让验收标准变模糊。"
        )
        let updated = CoachTurnPolicy().updateAfterAnswers(
            cards: [],
            questions: [question],
            previous: previous
        )

        let feedback = CoachAnswerFeedbackPolicy().makeFeedback(
            turn: updated,
            previous: previous,
            questions: [question],
            prescription: nil
        )

        XCTAssertTrue(feedback.coachCritiqueLine.contains("这不是合格复盘"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("不是普通待办"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("刚补上：缺观察事实"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("还要训练：缺因果链"))
        XCTAssertTrue(feedback.repairedLine.contains("已补训练材料：缺观察事实"))
        XCTAssertTrue(feedback.missingLine.contains("还没练到位：缺因果链"))
        XCTAssertTrue(feedback.proceedLine.contains("先修补训练缺口"))
    }

    func testCoachAnswerFeedbackPolicyCarriesObservedFoundationalAbilityTraining() {
        let turn = CoachTurnState(
            phase: .exploreProblem,
            readiness: .notReady,
            recommendedMove: .askClarifyingQuestion,
            reason: "当前材料还不能让别人复盘发生了什么。",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先把事件讲清楚。"
        )
        let observation = CoachObservationPolicy().observe(cards: confirmedCards([
            ThinkingCard(type: .idea, title: "今天很乱", body: "我只有很乱和焦虑的感受。")
        ]))

        let feedback = CoachAnswerFeedbackPolicy().makeFeedback(
            turn: turn,
            previous: nil,
            questions: [],
            prescription: nil,
            observation: observation
        )

        XCTAssertTrue(feedback.trainingTargetLine.contains("沟通力中的描述力"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("把事情讲到别人能复盘"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("不是让 AI 替你给答案"))
    }

    func testCoachAnswerFeedbackPolicyTurnsThinStoryIntoNarrativeSequencePractice() {
        let turn = CoachTurnState(
            phase: .exploreProblem,
            readiness: .notReady,
            recommendedMove: .askClarifyingQuestion,
            reason: "当前材料还不能让别人复盘发生了什么。",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先把事件讲清楚。"
        )
        let question = ReflectionQuestion(
            question: "今天发生了什么？",
            whyItMatters: "讲清楚事件是后续分析的材料。",
            evidenceGapType: .missingObservation,
            answerUse: .collectEvidence,
            lensMove: .factInterpretationSplit,
            answer: "今天太乱了，我很焦虑，感觉这事推进不下去。"
        )
        let observation = CoachObservationPolicy().observe(text: question.answer)

        let feedback = CoachAnswerFeedbackPolicy().makeFeedback(
            turn: turn,
            previous: nil,
            questions: [question],
            prescription: nil,
            observation: observation
        )

        XCTAssertEqual(observation.primaryGap, .narrative)
        XCTAssertTrue(feedback.trainingTargetLine.contains("沟通力中的描述力"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("不是让 AI 替你给答案"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("讲清楚一件事"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("背景"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("谁"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("触发"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("做了什么"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("后来"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("结果"))
    }

    func testCoachAnswerFeedbackPolicyTurnsActionOnlyAnswerIntoJudgmentSentencePractice() {
        let turn = CoachTurnState(
            phase: .clarifyJudgment,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "行动已经出现，但目标和判断标准还没有说清楚。",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先把行动背后的服务对象和成功标准说清楚。"
        )
        let question = ReflectionQuestion(
            question: "你准备怎么推进？",
            whyItMatters: "行动前要先校准目标。",
            evidenceGapType: .missingObservation,
            answerUse: .collectEvidence,
            lensMove: .factInterpretationSplit,
            answer: "先让 Alex 写清验收标准。"
        )
        let observation = CoachObservationPolicy().observe(text: question.answer)

        let feedback = CoachAnswerFeedbackPolicy().makeFeedback(
            turn: turn,
            previous: nil,
            questions: [question],
            prescription: nil,
            observation: observation
        )

        XCTAssertTrue(feedback.trainingTargetLine.contains("思考力中的判断力"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("服务对象"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("成功标准"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("可观察信号"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("行动当成答案"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("服务对象"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("成功标准"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("可观察信号"))
        XCTAssertFalse(feedback.coachCritiqueLine.contains("还要训练：观察事实"))
        XCTAssertTrue(feedback.abilityGapLine.contains("行动当成答案"))
        XCTAssertTrue(feedback.abilityGapLine.contains("服务对象"))
        XCTAssertTrue(feedback.abilityGapLine.contains("成功标准"))
        XCTAssertTrue(feedback.abilityGapLine.contains("可观察信号"))
        XCTAssertTrue(feedback.trainingOutputLine.contains("训练产物"))
        XCTAssertTrue(feedback.trainingOutputLine.contains("服务对象"))
        XCTAssertTrue(feedback.trainingOutputLine.contains("成功标准"))
        XCTAssertTrue(feedback.trainingOutputLine.contains("可观察信号"))
        XCTAssertTrue(feedback.selfCheckLine.contains("自检标准"))
        XCTAssertTrue(feedback.selfCheckLine.contains("谁的什么问题"))
        XCTAssertTrue(feedback.selfCheckLine.contains("成功标准"))
        XCTAssertTrue(feedback.selfCheckLine.contains("可观察信号"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("下一句"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("谁"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("成功标准"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("可观察信号"))
        XCTAssertTrue(feedback.experienceReplayPrompt.contains("没有先定义服务对象或成功标准"))
        XCTAssertTrue(feedback.experienceReplayPrompt.contains("复现哪条目标检查"))
        XCTAssertFalse(feedback.experienceReplayPrompt.contains("缺少事实或验收标准"))
    }

    func testCoachAnswerFeedbackPolicyAllowsValidationWhenAnswerClosesGaps() {
        let previous = CoachTurnState(
            phase: .clarifyJudgment,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "材料里同时出现预测和实际结果，适合校准原判断。",
            openEvidenceGaps: [.missingCalibrationSignal],
            baselineChecks: [.judgmentUpdate],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先定义校准信号。"
        )
        let question = ReflectionQuestion(
            question: "明天用什么信号校准这个判断？",
            whyItMatters: "它防止任务完成但判断没有更新。",
            evidenceGapType: .missingCalibrationSignal,
            answerUse: .watchCalibrationSignal,
            lensMove: .predictionCalibration,
            answer: "明天观察返工次数是否下降；如果没有下降，就更新原来认为验收能减少返工的判断。"
        )
        let updated = CoachTurnPolicy().updateAfterAnswers(
            cards: [],
            questions: [question],
            previous: previous
        )

        let feedback = CoachAnswerFeedbackPolicy().makeFeedback(
            turn: updated,
            previous: previous,
            questions: [question],
            prescription: nil
        )

        XCTAssertEqual(feedback.readiness, .ready)
        XCTAssertTrue(feedback.canProceedToValidation)
        XCTAssertTrue(feedback.coachCritiqueLine.contains("教练批改"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("已补训练材料"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("缺校准信号"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("可以进入明日验证"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("用明日结果校准判断"))
        XCTAssertTrue(feedback.repairedLine.contains("缺校准信号"))
        XCTAssertTrue(feedback.missingLine.contains("关键缺口已关闭"))
        XCTAssertTrue(feedback.proceedLine.contains("可以进入明日验证"))
        XCTAssertTrue(feedback.nextRepairQuestion.contains("明天"))
    }

    func testQuestExecutionTrainingPolicyFramesValidationActionAsExecutionPractice() {
        let quest = Quest(
            type: .main,
            title: "明天让负责人书面确认验收标准",
            whyItMatters: "验证书面验收能否减少接口返工。",
            completionCriteria: "明天下午前在会议记录中留下负责人、验收标准和一次返工次数记录。",
            expectedResistance: "可能想直接开会推进，忽略书面确认。",
            reflectionQuestion: "结果是否支持书面验收减少返工？",
            calibrationTarget: "书面验收能减少接口返工",
            lensMove: .predictionCalibration,
            sourceCardTitles: ["接口返工"]
        )

        let feedback = QuestExecutionTrainingPolicy().makeFeedback(for: quest)

        XCTAssertEqual(feedback.trainingDimension, .testableActionDesign)
        XCTAssertTrue(feedback.judgmentLine.contains("书面验收能减少接口返工"))
        XCTAssertTrue(feedback.evidenceLine.contains("会议记录"))
        XCTAssertTrue(feedback.resistanceLine.contains("直接开会"))
        XCTAssertTrue(feedback.calibrationLine.contains("结果校准"))
        XCTAssertTrue(feedback.trainingLine.contains("执行力"))
        XCTAssertTrue(feedback.trainingLine.contains("可验证行动"))
    }

    func testCoachTeachingPolicy_overrideRouteKeepsAuditBoundary() {
        let turn = CoachTurnState(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "用户主动推进到行动生成。",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.evidenceGap, .testableAction],
            decisionSource: .userOverrideProgress,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "用户主动推进到行动生成；这不是证据缺口已消失的证明，后续仍保留审计边界。"
        )

        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: nil)

        XCTAssertTrue(plan.missingMoveTitle.contains("证据缺口仍然存在"))
        XCTAssertTrue(plan.trainingTargetTitle.contains("审计边界"))
        XCTAssertTrue(plan.whyNotAnswer.contains("override 是推进许可"))
        XCTAssertTrue(plan.proceedStandard.contains("可回看证据"))
        XCTAssertEqual(plan.routeSteps.first, "记录用户主动推进")
        XCTAssertTrue(plan.auditNote?.contains("不是缺口已经消失") ?? false)
    }

    func testCoachTurnPolicy_keepsCalibrationGapOpenUntilAnswerNamesOutcomeSignal() {
        let previous = CoachTurnState(
            phase: .clarifyJudgment,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "材料里同时出现预测和实际结果，适合校准原判断。",
            openEvidenceGaps: [.missingCalibrationSignal],
            baselineChecks: [.judgmentUpdate],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "先定义校准信号。"
        )
        let weakAnswer = ReflectionQuestion(
            question: "明天用什么信号校准这个判断？",
            whyItMatters: "它防止任务完成但判断没有更新。",
            evidenceGapType: .missingCalibrationSignal,
            answerUse: .watchCalibrationSignal,
            lensMove: .predictionCalibration,
            answer: "让负责人写清验收标准。"
        )

        let unresolved = CoachTurnPolicy().updateAfterAnswers(
            cards: [],
            questions: [weakAnswer],
            previous: previous
        )

        XCTAssertEqual(unresolved.readiness, .notReady)
        XCTAssertEqual(unresolved.recommendedMove, .surfaceEvidenceGap)
        XCTAssertEqual(unresolved.openEvidenceGaps, [.missingCalibrationSignal])
        XCTAssertTrue(unresolved.reason.contains("校准信号"))

        var calibratedAnswer = weakAnswer
        calibratedAnswer.answer = "明天观察实际返工次数是否下降；如果没有下降，就更新原来认为验收能减少返工的判断。"

        let resolved = CoachTurnPolicy().updateAfterAnswers(
            cards: [],
            questions: [calibratedAnswer],
            previous: previous
        )

        XCTAssertEqual(resolved.readiness, .ready)
        XCTAssertEqual(resolved.recommendedMove, .generateQuest)
        XCTAssertTrue(resolved.openEvidenceGaps.isEmpty)
    }

    func testCoachLensLearningPolicy_reinforcesHighValueCompletedLensMove() {
        let question = ReflectionQuestion(
            question: "明天能观察到什么信号，证明书面验收减少返工？",
            whyItMatters: "它把判断变成可校准信号。",
            evidenceGapType: .missingCalibrationSignal,
            answerUse: .watchCalibrationSignal,
            lensMove: .predictionCalibration,
            sourceCardTitles: ["接口验收不清"],
            calibrationTarget: "书面验收减少接口返工",
            answer: "让负责人书面确认验收标准。"
        )
        let session = LensSession(dailyEntryId: UUID(), selectedLens: .judgmentCalibration, questions: [question])
        let verification = Verification(
            questId: UUID(),
            questTitle: "确认验收标准",
            sourceDailyEntryId: session.dailyEntryId,
            completion: .done,
            valueRating: .high,
            calibrationNote: "实际证据显示返工减少。",
            recommendation: "继续使用预测校准。"
        )

        let signals = CoachLensLearningPolicy().signals(from: session, verification: verification)

        XCTAssertEqual(signals.first?.signal, "reinforce")
        XCTAssertEqual(signals.first?.lensMove, .predictionCalibration)
        XCTAssertEqual(signals.first?.calibrationTarget, "书面验收减少接口返工")
        XCTAssertTrue(signals.first?.reason.contains("high") ?? false)
    }

    func testCoachLensLearningPolicy_avoidsLowValueOrMissedLensMove() {
        let question = ReflectionQuestion(
            question: "明天能观察到什么信号？",
            whyItMatters: "它尝试校准判断。",
            evidenceGapType: .missingCalibrationSignal,
            answerUse: .watchCalibrationSignal,
            lensMove: .predictionCalibration,
            sourceCardTitles: ["接口验收不清"],
            calibrationTarget: "书面验收减少接口返工",
            answer: "观察返工次数。"
        )
        let session = LensSession(dailyEntryId: UUID(), selectedLens: .judgmentCalibration, questions: [question])
        let verification = Verification(
            questId: UUID(),
            questTitle: "观察返工次数",
            sourceDailyEntryId: session.dailyEntryId,
            completion: .missed,
            valueRating: .high,
            calibrationNote: "没有执行，所以没有产生证据。"
        )

        let signals = CoachLensLearningPolicy().signals(from: session, verification: verification)

        XCTAssertEqual(signals.first?.signal, "avoid")
        XCTAssertEqual(signals.first?.lensMove, .predictionCalibration)
        XCTAssertTrue(signals.first?.reason.contains("missed") ?? false)
    }

    func testCoachLensLearningPolicy_adjustsPartialOrMediumLensMove() {
        let question = ReflectionQuestion(
            question: "明天能观察到什么信号？",
            whyItMatters: "它尝试校准判断。",
            evidenceGapType: .missingCalibrationSignal,
            answerUse: .watchCalibrationSignal,
            lensMove: .predictionCalibration,
            sourceCardTitles: ["接口验收不清"],
            calibrationTarget: "书面验收减少接口返工",
            answer: "观察返工次数。"
        )
        let session = LensSession(dailyEntryId: UUID(), selectedLens: .judgmentCalibration, questions: [question])
        let verification = Verification(
            questId: UUID(),
            questTitle: "观察返工次数",
            sourceDailyEntryId: session.dailyEntryId,
            completion: .partial,
            valueRating: .medium,
            calibrationNote: "方向有用，但信号太粗。"
        )

        let signals = CoachLensLearningPolicy().signals(from: session, verification: verification)

        XCTAssertEqual(signals.first?.signal, "adjust")
        XCTAssertEqual(signals.first?.lensMove, .predictionCalibration)
        XCTAssertTrue(signals.first?.reason.contains("smaller") ?? false)
    }

    func testCoachLensLearningPolicy_recordsFrequentUserOverrideAudit() {
        let signal = CoachLensLearningPolicy().overrideAuditSignal(
            recommendedLens: .evidenceCheck,
            finalLens: .opposingView,
            primaryTrainingDimension: .evidenceDiscipline,
            recentOverrideCount: 3
        )

        XCTAssertEqual(signal?.signal, "override_audit")
        XCTAssertNil(signal?.lensMove)
        XCTAssertEqual(signal?.calibrationTarget, "evidenceCheck->opposingView")
        XCTAssertTrue(signal?.reason.contains("frequent") ?? false)
        XCTAssertTrue(signal?.reason.contains("evidence_discipline") ?? false)
    }

    func testReviewCards_withInsufficientEvidenceCreatesCoachDiagnosisThatDefaultsToClarification() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = confirmedCards([
            ThinkingCard(type: .idea, title: "也许要做一个新 App", body: "还没说明为什么做。"),
            ThinkingCard(type: .communication, title: "讨论很多但没有问题定义", body: "暂时只有想法。")
        ])

        store.submitTodayStep()
        try await waitForState(.selectLens)

        let diagnosis = try XCTUnwrap(store.coachDiagnosis)
        XCTAssertEqual(diagnosis.phase, .exploreProblem)
        XCTAssertEqual(diagnosis.readiness, .notReady)
        XCTAssertEqual(diagnosis.recommendedMove, .askClarifyingQuestion)
        XCTAssertTrue(diagnosis.reason.contains("问题"))
    }

    func testReviewCards_thinNarrativeCreatesDescriptionTrainingDiagnosis() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = confirmedCards([
            ThinkingCard(type: .task, title: "我今天推进了方案", body: "我今天推进了一下方案，感觉还是卡住了。")
        ])

        store.submitTodayStep()
        try await waitForState(.selectLens)

        let diagnosis = try XCTUnwrap(store.coachDiagnosis)
        XCTAssertEqual(diagnosis.phase, .exploreProblem)
        XCTAssertEqual(diagnosis.readiness, .notReady)
        XCTAssertEqual(diagnosis.recommendedMove, .askClarifyingQuestion)
        XCTAssertTrue(diagnosis.reason.contains("沟通力"))
        XCTAssertTrue(diagnosis.reason.contains("描述力"))
        XCTAssertTrue(diagnosis.reason.contains("讲清楚一件事"))
        XCTAssertTrue(store.coachTurnState?.turnSummary.contains("讲清楚一件事") == true)
    }

    func testCoachDiagnosis_canAcceptSlowDownOrOverrideProgression() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.acceptCoachDiagnosis()
        XCTAssertEqual(store.coachDiagnosis?.source, .coachAccepted)

        store.slowDownCoachDiagnosis()
        XCTAssertEqual(store.coachDiagnosis?.source, .userSlowDown)
        XCTAssertEqual(store.coachDiagnosis?.recommendedMove, .slowDownConvergence)
        XCTAssertEqual(store.coachDiagnosis?.readiness, .notReady)

        store.overrideCoachDiagnosisToProgress()
        XCTAssertEqual(store.coachDiagnosis?.source, .userOverrideProgress)
        XCTAssertEqual(store.coachDiagnosis?.recommendedMove, .generateQuest)
        XCTAssertEqual(store.coachDiagnosis?.readiness, .ready)
    }

    // MARK: - Legacy SelectMode -> SelectLens

    func testSelectMode_noModeSelected_blocksProgression() async throws {
        try await advanceTo(.selectMode)
        store.todayDraft.hasSelectedSessionMode = false
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectMode)
    }

    func testSelectMode_withMode_advancesToSelectLens() async throws {
        try await advanceTo(.selectMode)
        store.selectTodayMode(.quick)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectLens)
    }

    func testAnswerQuestionsGuard_withoutAnswerExplainsTrainingEntryCondition() {
        store.todayDraft.state = .answerQuestions
        store.questions = [
            ReflectionQuestion(
                question: "今天的判断依据是什么？",
                whyItMatters: "先补上证据缺口。",
                answer: "   "
            )
        ]

        store.submitTodayStep()

        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertEqual(
            store.todayLoopMessage,
            "进入条件：先回答一个教练问题。 训练理由：明日验证必须来自你补过的思考材料，不是 AI 直接生成任务。"
        )
    }

    func testAnswerQuestionsGuard_withoutCalibrationTargetExplainsTrainingEntryCondition() {
        store.todayDraft.state = .answerQuestions
        store.questions = [
            ReflectionQuestion(
                question: "今天的判断依据是什么？",
                whyItMatters: "先补上证据缺口。",
                answer: "这次会议没有明确负责人。"
            )
        ]

        store.submitTodayStep()

        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertEqual(
            store.todayLoopMessage,
            "进入条件：先在今日复盘中形成一个待验证判断。 训练理由：验证行动要验证今天的判断，不是普通待办。"
        )
    }

    // MARK: - SelectLens -> AnswerQuestions

    func testSelectLens_noLensSelected_blocksProgression() async throws {
        try await advanceTo(.selectLens)
        store.todayDraft.selectedLens = nil
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectLens)
    }

    func testSelectLens_createsCoachTrainingPrescriptionForConfirmedCards() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()

        store.submitTodayStep()
        try await waitForState(.selectLens)

        let prescription = try XCTUnwrap(store.trainingPrescription)
        XCTAssertEqual(prescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.finalLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.source, .coachRecommended)
        XCTAssertNil(prescription.userSelectedLensId)
        XCTAssertEqual(prescription.policyVersion, LocalTrainingPrescriptionPolicy.policyVersion)
        XCTAssertTrue(prescription.baselineChecks.contains(.evidenceGap))
    }

    func testSelectLens_acceptsCoachTrainingPrescriptionAndPassesFinalChoiceToQuestionsContext() async throws {
        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        store.todayDraft = DailyEntryDraft(
            rawText: "Today the meeting ended without a written owner.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .reviewCards
        )
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)
        store.acceptTrainingPrescription()

        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuestions })
        let prescription = try XCTUnwrap(request.contextPayload?.trainingPrescription)
        XCTAssertEqual(prescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.finalLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.source, .coachRecommended)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachRecommendedLens"], ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["finalTrainingLens"], ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["trainingPrescriptionSource"], TrainingPrescriptionSource.coachRecommended.rawValue)
    }

    func testSelectLens_withoutConfiguredAPIKeyUsesLocalQuestionsWithoutRetryableFailure() async throws {
        let isolatedKeychain = KeychainAPIKeyStore(service: "com.codex.mingsi.tests.\(UUID().uuidString)")
        store = AppStore(
            apiKeyStore: isolatedKeychain,
            refreshesAIServiceFromKeychain: true
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        XCTAssertFalse(store.questions.isEmpty)
        XCTAssertFalse(store.canRetryCurrentAI)
        XCTAssertEqual(store.pendingAIRepairCount, 0)
        XCTAssertNil(store.lastAIFailureMessage)
        XCTAssertFalse(store.todayLoopMessage.contains("未完成"))
        XCTAssertFalse(store.todayLoopMessage.contains("请求超时"))
        XCTAssertFalse(store.todayLoopMessage.contains("网络请求失败"))
    }

    func testSelectLens_streamingQuestionFailureFallsBackWithDiagnosticRetry() async throws {
        let client = QuestionFailingStreamingLLMClient()
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        XCTAssertFalse(store.questions.isEmpty)
        XCTAssertEqual(store.pendingAIRepairCount, 1)
        XCTAssertTrue(store.canRetryCurrentAI)
        XCTAssertTrue(store.todayLoopMessage.contains("教练追问训练未完成"))
        XCTAssertTrue(store.todayLoopMessage.contains("网络请求失败"))
        XCTAssertFalse(store.isAIRunning)
    }

    func testSelectLens_slowDownCoachDiagnosisPassesToQuestionsContext() async throws {
        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.slowDownCoachDiagnosis()
        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuestions })
        let diagnosis = try XCTUnwrap(request.contextPayload?.coachDiagnosis)
        XCTAssertEqual(diagnosis.source, .userSlowDown)
        XCTAssertEqual(diagnosis.readiness, .notReady)
        XCTAssertEqual(diagnosis.recommendedMove, .slowDownConvergence)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachDiagnosisSource"], CoachDiagnosisSource.userSlowDown.rawValue)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachRecommendedMove"], NextCoachMove.slowDownConvergence.rawValue)
    }

    func testAnswerQuestions_overrideCoachDiagnosisPassesToQuestContext() async throws {
        let client = SequencedLLMClient(results: [
            .success(Self.questionsResponse),
            .success(Self.questsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.overrideCoachDiagnosisToProgress()
        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let question = try XCTUnwrap(store.questions.first)
        store.updateQuestionAnswer(questionID: question.id, answer: "先写清 owner 和验收标准。")
        store.submitTodayStep()
        try await waitForState(.reviewQuests)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuests })
        let diagnosis = try XCTUnwrap(request.contextPayload?.coachDiagnosis)
        XCTAssertEqual(diagnosis.source, .userOverrideProgress)
        XCTAssertEqual(diagnosis.readiness, .ready)
        XCTAssertEqual(diagnosis.recommendedMove, .generateQuest)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachDiagnosisSource"], CoachDiagnosisSource.userOverrideProgress.rawValue)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachRecommendedMove"], NextCoachMove.generateQuest.rawValue)
        let turn = try XCTUnwrap(request.contextPayload?.coachTurnState)
        XCTAssertEqual(turn.decisionSource, .userOverrideProgress)
        XCTAssertEqual(turn.readiness, .ready)
        XCTAssertEqual(turn.recommendedMove, .generateQuest)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachTurnDecisionSource"], CoachDiagnosisSource.userOverrideProgress.rawValue)
    }

    func testAnswerQuestions_updatesCoachTurnStateBeforeQuestContext() async throws {
        let client = SequencedLLMClient(results: [
            .success(Self.questionsResponse),
            .success(Self.questsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = confirmedCards([
            ThinkingCard(type: .risk, title: "验收口径不清", body: "缺少事实支撑。", priority: .high),
            ThinkingCard(type: .problem, title: "判断依据不足", body: "目前只有推测。", priority: .medium)
        ])

        store.submitTodayStep()
        try await waitForState(.selectLens)
        XCTAssertEqual(store.coachTurnState?.readiness, .notReady)
        XCTAssertEqual(store.coachTurnState?.recommendedMove, .slowDownConvergence)

        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let question = try XCTUnwrap(store.questions.first)
        store.updateQuestionAnswer(
            questionID: question.id,
            answer: "事实是负责人是 Alex，验收标准是明天下午前写入文档，并用客户确认作为证据。"
        )
        store.submitTodayStep()
        try await waitForState(.reviewQuests)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuests })
        let turn = try XCTUnwrap(request.contextPayload?.coachTurnState)
        XCTAssertEqual(turn.readiness, .ready)
        XCTAssertEqual(turn.recommendedMove, .generateQuest)
        XCTAssertEqual(turn.decisionSource, .coachRecommended)
        XCTAssertTrue(turn.openEvidenceGaps.isEmpty)
        XCTAssertTrue(turn.turnSummary.contains("回答"))
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachTurnReadiness"], ConvergenceReadiness.ready.rawValue)
        XCTAssertEqual(request.contextPayload?.legacyKeyValues["coachTurnRecommendedMove"], NextCoachMove.generateQuest.rawValue)
    }

    func testAnswerQuestions_unresolvedCoachGapStaysInQuestionStageWithTrainingFeedback() async throws {
        let client = SequencedLLMClient(results: [
            .success(Self.questionsResponse),
            .success(Self.questsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()

        store.submitTodayStep()
        try await waitForState(.selectLens)
        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let question = try XCTUnwrap(store.questions.first)
        store.updateQuestionAnswer(
            questionID: question.id,
            answer: "先让 Alex 写清验收标准。"
        )
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        XCTAssertEqual(store.coachTurnState?.readiness, .notReady)
        XCTAssertEqual(store.coachTurnState?.openEvidenceGaps, [.missingObservation])
        XCTAssertTrue(store.todayLoopMessage.contains("还没练到位"))
        XCTAssertTrue(store.todayLoopMessage.contains("观察事实"))
        XCTAssertTrue(store.todayLoopMessage.contains("现在不能进入明日验证"))
        XCTAssertTrue(store.todayLoopMessage.contains("能力训练"))
        XCTAssertTrue(store.todayLoopMessage.contains("不是让 AI 替你给答案"))
        XCTAssertTrue(store.todayLoopMessage.contains("行动当成答案"))
        XCTAssertTrue(store.todayLoopMessage.contains("服务对象"))
        XCTAssertTrue(store.todayLoopMessage.contains("成功标准"))
        XCTAssertTrue(store.todayLoopMessage.contains("教练追问"))
        XCTAssertTrue(store.todayLoopMessage.contains("过往经验"))
        XCTAssertTrue(store.todayLoopMessage.contains("没有先定义服务对象或成功标准"))
        XCTAssertFalse(client.requests.contains { $0.prompt.id == .generateQuests })
    }

    func testAnswerQuestions_previewCoachGapFeedbackWhileTyping() async throws {
        let client = SequencedLLMClient(results: [
            .success(Self.questionsResponse),
            .success(Self.questsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()

        store.submitTodayStep()
        try await waitForState(.selectLens)
        store.acceptTrainingPrescription()
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let question = try XCTUnwrap(store.questions.first)
        store.updateQuestionAnswer(
            questionID: question.id,
            answer: "先让 Alex 写清验收标准。"
        )

        XCTAssertEqual(store.coachAnswerFeedbackPreview?.readiness, .notReady)
        XCTAssertEqual(store.coachAnswerFeedbackPreview?.openEvidenceGaps, [.missingObservation])
        XCTAssertTrue(store.coachAnswerFeedbackPreview?.reason.contains("观察事实") ?? false)
        let feedback = try XCTUnwrap(store.coachAnswerTrainingFeedback)
        XCTAssertTrue(feedback.trainingTargetLine.contains("思考力中的判断力"))
        XCTAssertTrue(feedback.trainingTargetLine.contains("不是让 AI 替你给答案"))
        XCTAssertTrue(feedback.coachCritiqueLine.contains("行动当成答案"))
        XCTAssertTrue(feedback.abilityGapLine.contains("服务对象"))
        XCTAssertTrue(feedback.abilityGapLine.contains("成功标准"))
        XCTAssertTrue(feedback.abilityGapLine.contains("可观察信号"))
        XCTAssertTrue(feedback.experienceReplayPrompt.contains("没有先定义服务对象或成功标准"))
        XCTAssertTrue(try XCTUnwrap(store.coachAnswerMaterialObservation).contains("行动不能先替代目标"))
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("训练理由") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("先补齐训练缺口") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("缺观察事实") == true)
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertFalse(client.requests.contains { $0.prompt.id == .generateQuests })
    }

    func testSelectLens_recordsUserOverrideSeparatelyFromCoachRecommendation() async throws {
        let client = RecordingLLMClient(response: Self.opposingViewQuestionsResponse)
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.overrideTrainingPrescription(with: .opposingView)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let storePrescription = try XCTUnwrap(store.trainingPrescription)
        XCTAssertEqual(storePrescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(storePrescription.userSelectedLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(storePrescription.finalLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(storePrescription.source, .userOverride)
        XCTAssertTrue(storePrescription.overrideBoundary.contains(ThinkingLens.evidenceCheck.rawValue))
        XCTAssertTrue(storePrescription.overrideBoundary.contains(ThinkingLens.opposingView.rawValue))

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuestions })
        let contextPrescription = try XCTUnwrap(request.contextPayload?.trainingPrescription)
        XCTAssertEqual(contextPrescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(contextPrescription.userSelectedLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(contextPrescription.finalLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(contextPrescription.source, .userOverride)
    }

    func testSelectLens_selectThinkingLensRecordsUserOverrideForAlternativeBuiltinLens() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.selectThinkingLens(.opposingView)

        let prescription = try XCTUnwrap(store.trainingPrescription)
        XCTAssertEqual(prescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.userSelectedLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(prescription.finalLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(prescription.source, .userOverride)
        XCTAssertTrue(prescription.overrideBoundary.contains(ThinkingLens.evidenceCheck.rawValue))
        XCTAssertTrue(prescription.overrideBoundary.contains(ThinkingLens.opposingView.rawValue))
    }

    func testSelectLens_skipTrainingPrescriptionKeepsCoachFocusAndRecordsSkip() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.skipTrainingPrescription()

        let prescription = try XCTUnwrap(store.trainingPrescription)
        XCTAssertEqual(prescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.finalLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.source, .skipped)
        XCTAssertNil(prescription.userSelectedLensId)
        XCTAssertTrue(prescription.overrideBoundary.contains("跳过"))
        XCTAssertTrue(prescription.baselineChecks.contains(.evidenceGap))
    }

    func testSelectLens_withExistingQuestions_advancesDirectly() async throws {
        try await advanceTo(.selectLens)
        store.selectThinkingLens(.evidenceCheck)
        store.questions = [
            ReflectionQuestion(question: "Test question", whyItMatters: "Test")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
    }

    func testGenerateCustomLensFromConfirmedCards_canBeSelectedAndUsedForLocalQuestions() async throws {
        try await advanceTo(.selectLens)
        var card = ThinkingCard(
            type: .problem,
            title: "会议归属不清",
            body: "接口讨论结束后没有唯一负责人。"
        )
        card.isConfirmed = true
        store.thinkingCards = [card]

        let generatedLens = store.generateCustomLensFromConfirmedCards()
        store.selectCustomLens(generatedLens.id)
        store.submitTodayStep()

        XCTAssertEqual(store.availableLensChoices.map(\.id), [generatedLens.id] + ThinkingLens.allCases.map(\.rawValue))
        XCTAssertEqual(store.todayDraft.selectedCustomLensId, generatedLens.id)
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertTrue(store.questions.contains { $0.question == generatedLens.questionSeeds.first })
        XCTAssertTrue(store.questions.contains { $0.question.contains(generatedLens.title) })
    }

    func testCustomLensDefinitionRestoresWithPersistedDraft() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let originalStore = AppStore(
            dailyEntryRepository: dailyRepo,
            refreshesAIServiceFromKeychain: false
        )
        originalStore.todayDraft = DailyEntryDraft(
            rawText: "接口会议后责任边界还不清楚。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .selectLens
        )

        let customLens = originalStore.upsertCustomLens(
            title: "责任边界透镜",
            subtitle: "为当前会议复盘创建。",
            shortLabel: "边界",
            methodLine: "先问：这件事到底归谁拥有？",
            promptGuidance: "Ask ownership and evidence questions.",
            firstQuestion: "这件事到底归谁拥有？",
            idSuffix: "ownership"
        )
        originalStore.selectCustomLens(customLens.id)
        try await waitUntilAsync(
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected custom lens selection to persist"
        ) {
            try await dailyRepo.latestDraft()?.selectedCustomLensId == customLens.id
        }

        let restoredStore = AppStore(
            dailyEntryRepository: dailyRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.todayDraft.selectedCustomLensId, customLens.id)
        XCTAssertEqual(restoredStore.customLensItems.first?.id, customLens.id)
        XCTAssertEqual(restoredStore.selectedLensItem?.title, "责任边界透镜")
        XCTAssertTrue(restoredStore.availableLensChoices.contains { $0.id == customLens.id })
    }

    func testCustomLensQuestionsRestoreWithPersistedDraft() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let originalStore = AppStore(
            dailyEntryRepository: dailyRepo,
            refreshesAIServiceFromKeychain: false
        )
        originalStore.todayDraft = DailyEntryDraft(
            rawText: "接口归属仍然不清，明天需要明确负责人。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .selectLens
        )
        let customLens = originalStore.upsertCustomLens(
            title: "责任边界透镜",
            subtitle: "为当前会议复盘创建。",
            shortLabel: "边界",
            methodLine: "先问：这件事到底归谁拥有？",
            promptGuidance: "Ask ownership and evidence questions.",
            firstQuestion: "这件事到底归谁拥有？",
            idSuffix: "ownership"
        )

        originalStore.selectCustomLens(customLens.id)
        originalStore.submitTodayStep()
        XCTAssertEqual(originalStore.todayDraft.state, .answerQuestions)
        let firstQuestion = try XCTUnwrap(originalStore.questions.first)
        originalStore.updateQuestionAnswer(questionID: firstQuestion.id, answer: "需要产品负责人确认。")

        try await waitUntilAsync(
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected custom lens questions to persist"
        ) {
            try await dailyRepo.latestDraft()?.customLensQuestions.first?.answer == "需要产品负责人确认。"
        }

        let restoredStore = AppStore(
            dailyEntryRepository: dailyRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.todayDraft.selectedCustomLensId, customLens.id)
        XCTAssertEqual(restoredStore.questions.first?.question, "这件事到底归谁拥有？")
        XCTAssertEqual(restoredStore.questions.first?.answer, "需要产品负责人确认。")
    }

    func testCustomLensQuestionsRestoreWinsOverStaleBuiltinLensSession() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let lensRepo = SQLiteLensSessionRepository(database: database)
        let originalStore = AppStore(
            dailyEntryRepository: dailyRepo,
            lensSessionRepository: lensRepo,
            refreshesAIServiceFromKeychain: false
        )
        originalStore.todayDraft = DailyEntryDraft(
            rawText: "同一个议题先做过内置透镜，后来改成责任边界透镜。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .selectLens
        )
        try await lensRepo.saveLensSession(
            LensSession(
                dailyEntryId: originalStore.todayDraft.id,
                selectedLens: .evidenceCheck,
                questions: [
                    ReflectionQuestion(
                        question: "旧内置追问不应覆盖自定义透镜。",
                        whyItMatters: "这是同一天早先留下的 lens session。"
                    )
                ]
            )
        )
        let customLens = originalStore.upsertCustomLens(
            title: "责任边界透镜",
            subtitle: "为当前会议复盘创建。",
            shortLabel: "边界",
            methodLine: "先问：这件事到底归谁拥有？",
            promptGuidance: "Ask ownership and evidence questions.",
            firstQuestion: "这件事到底归谁拥有？",
            idSuffix: "ownership"
        )

        originalStore.selectCustomLens(customLens.id)
        originalStore.submitTodayStep()
        let firstQuestion = try XCTUnwrap(originalStore.questions.first)
        originalStore.updateQuestionAnswer(questionID: firstQuestion.id, answer: "需要产品负责人确认。")
        try await waitUntilAsync(
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected custom lens questions to persist"
        ) {
            try await dailyRepo.latestDraft()?.customLensQuestions.first?.answer == "需要产品负责人确认。"
        }

        let restoredStore = AppStore(
            dailyEntryRepository: dailyRepo,
            lensSessionRepository: lensRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.todayDraft.selectedCustomLensId, customLens.id)
        XCTAssertNil(restoredStore.todayDraft.selectedLens)
        XCTAssertEqual(restoredStore.questions.first?.question, "这件事到底归谁拥有？")
        XCTAssertEqual(restoredStore.questions.first?.answer, "需要产品负责人确认。")
    }

    func testLoadPersistedState_loadsEnabledLensAssetPacksIntoRuntimeChoices() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        let enabledLens = Self.makeRuntimeLensPackItem(
            lensId: "marketplace-role-coach",
            promptId: "role_coach"
        )
        let disabledLens = Self.makeRuntimeLensPackItem(
            lensId: "marketplace-role-off",
            promptId: "role_off"
        )

        try await dailyRepo.saveDraft(
            DailyEntryDraft(
                rawText: "今天要从教练视角复盘沟通方式。",
                sessionMode: .standard,
                hasSelectedSessionMode: true,
                state: .selectLens
            )
        )
        try await packRepo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "marketplace.roles.coach",
                version: "2026.06",
                displayName: "Coach Role Cards",
                sourceKind: .marketplace,
                isEnabled: true,
                items: [enabledLens]
                )
            )
        )
        try await packRepo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "marketplace.roles.disabled",
                version: "2026.06",
                displayName: "Disabled Role Cards",
                sourceKind: .marketplace,
                isEnabled: false,
                items: [disabledLens]
                )
            )
        )

        let restoredStore = AppStore(
            dailyEntryRepository: dailyRepo,
            lensAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertTrue(restoredStore.availableLensChoices.contains { $0.id == "marketplace-role-coach" })
        XCTAssertFalse(restoredStore.availableLensChoices.contains { $0.id == "marketplace-role-off" })
        XCTAssertEqual(restoredStore.runtimeLensItems.first?.packId, "marketplace.roles.coach")
        XCTAssertEqual(restoredStore.runtimeLensItems.first?.sourceKind, .marketplace)
    }

    func testLoadPersistedState_loadsEnabledPromptAssetPacksIntoEffectiveProvider() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                id: "imported.prompt.coach",
                version: "2026.06",
                displayName: "Coach Prompt Pack",
                sourceKind: .imported,
                isEnabled: true,
                templates: [
                    Self.makePromptPackTemplate(
                        promptId: .generateQuestions,
                        version: "pack.questions.v2",
                        userText: "Pack version asks one sharper ownership question."
                    )
                ]
                )
            )
        )

        let restoredStore = AppStore(
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        let template = restoredStore.promptTemplate(for: .generateQuestions, mode: .standard)
        XCTAssertEqual(template.version, "pack.questions.v2")
        XCTAssertEqual(template.userText, "Pack version asks one sharper ownership question.")
    }

    func testLoadPersistedState_ignoresDisabledPromptAssetPacksForEffectiveProvider() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                id: "imported.prompt.disabled",
                version: "2026.06",
                displayName: "Disabled Prompt Pack",
                sourceKind: .imported,
                isEnabled: false,
                templates: [
                    Self.makePromptPackTemplate(
                        promptId: .generateQuestions,
                        version: "disabled.questions.v2",
                        userText: "Disabled pack must not drive runtime prompts."
                    )
                ]
                )
            )
        )

        let restoredStore = AppStore(
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        let template = restoredStore.promptTemplate(for: .generateQuestions, mode: .standard)
        XCTAssertNotEqual(template.version, "disabled.questions.v2")
        XCTAssertNotEqual(template.userText, "Disabled pack must not drive runtime prompts.")
    }

    func testLoadPersistedState_promptRollbackSelectionOverridesEnabledPromptPack() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        let selectionRepo = SQLitePromptAssetSelectionRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                id: "imported.prompt.current",
                version: "2026.06",
                displayName: "Current Prompt Pack",
                sourceKind: .imported,
                isEnabled: true,
                templates: [
                    Self.makePromptPackTemplate(
                        promptId: .generateQuestions,
                        version: "pack.questions.v2",
                        userText: "Current pack prompt."
                    ),
                    Self.makePromptPackTemplate(
                        promptId: .generateQuestions,
                        version: "pack.questions.v1",
                        userText: "Rollback pack prompt."
                    )
                ]
                )
            )
        )
        try await selectionRepo.saveSelection(
            PromptAssetSelection(
                promptId: .generateQuestions,
                selectedVersion: "pack.questions.v1",
                baseVersion: "pack.questions.v2",
                reason: .rollback
            )
        )

        let restoredStore = AppStore(
            promptAssetSelectionRepository: selectionRepo,
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        let template = restoredStore.promptTemplate(for: .generateQuestions, mode: .standard)
        XCTAssertEqual(template.version, "pack.questions.v1")
        XCTAssertEqual(template.userText, "Rollback pack prompt.")
    }

    func testLoadPersistedState_scheduledPromptEvalUsesEnabledPromptPackVersions() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                id: "imported.prompt.eval",
                version: "2026.06",
                displayName: "Eval Prompt Pack",
                sourceKind: .imported,
                isEnabled: true,
                templates: [
                    Self.makePromptPackTemplate(
                        promptId: .generateQuestions,
                        version: "pack.questions.eval.v2",
                        userText: "Eval should record this pack version."
                    )
                ]
                )
            )
        )
        let store = AppStore(
            promptEvalRunRepository: evalRepo,
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        let persisted = try await evalRepo.recentEvalRuns(limit: 100)
        let questionsRun = try XCTUnwrap(persisted.first { $0.promptId == PromptID.generateQuestions.rawValue })
        XCTAssertEqual(questionsRun.promptVersion, "pack.questions.eval.v2")
        XCTAssertEqual(questionsRun.promptSourceKind, .imported)
        XCTAssertEqual(questionsRun.promptPackId, "imported.prompt.eval")
        XCTAssertEqual(questionsRun.promptPackVersion, "2026.06")
        XCTAssertEqual(questionsRun.promptPackDisplayName, "Eval Prompt Pack")
        XCTAssertEqual(store.promptEvalReleaseGate.status, .passed)
    }

    func testRuntimeLensAssetSelectionUsesCustomLensStateWithoutChangingBuiltinLens() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        let lens = Self.makeRuntimeLensPackItem(
            lensId: "marketplace-framework-review",
            promptId: "framework_review"
        )
        try await packRepo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "imported.frameworks.review",
                version: "1.2.0",
                displayName: "Review Frameworks",
                sourceKind: .imported,
                isEnabled: true,
                items: [lens]
                )
            )
        )

        let restoredStore = AppStore(
            lensAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()
        restoredStore.selectCustomLens("marketplace-framework-review")

        XCTAssertEqual(restoredStore.todayDraft.selectedCustomLensId, "marketplace-framework-review")
        XCTAssertNil(restoredStore.todayDraft.selectedLens)
        XCTAssertEqual(restoredStore.selectedLensItem?.packId, "imported.frameworks.review")
        XCTAssertEqual(restoredStore.selectedLensItem?.packVersion, "1.2.0")
    }

    func testLoadLensAssetPacks_listsAllPacksWithEnabledRuntimeCount() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "imported.roles.coach",
                version: "1.0.0",
                displayName: "Coach Roles",
                sourceKind: .imported,
                isEnabled: true,
                items: [Self.makeRuntimeLensPackItem(lensId: "role-coach", promptId: "role_coach")]
                )
            )
        )
        try await packRepo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "imported.frameworks.off",
                version: "1.0.0",
                displayName: "Disabled Frameworks",
                sourceKind: .imported,
                isEnabled: false,
                items: [Self.makeRuntimeLensPackItem(lensId: "framework-off", promptId: "framework_off")]
                )
            )
        )

        let store = AppStore(
            lensAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadLensAssetPacks()

        XCTAssertEqual(store.lensAssetPacks.map(\.id), ["imported.roles.coach", "imported.frameworks.off"])
        XCTAssertEqual(store.runtimeLensItems.map(\.lensId), ["role-coach"])
        XCTAssertEqual(store.lensAssetPackMessage, "已加载 2 个透镜包，启用 1 个。")
    }

    func testLoadLensAssetPacks_keepsMismatchedExternalPackOutOfRuntimeChoices() async throws {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(dbQueue: queue)
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        let lens = Self.makeRuntimeLensPackItem(
            lensId: "stale-role",
            promptId: "stale_role"
        )
        let now = Self.storageString(Date(timeIntervalSince1970: 100))
        let itemsJSON = try Self.encodedJSONString([lens])
        let trustMetadataJSON = try Self.encodedJSONString(
            Self.makeTrustMetadata(contentHash: Self.mismatchedContentHash)
        )

        try await queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO lens_asset_packs
                (id, schema_version, version, display_name, source_kind, is_enabled, items_json, trust_metadata_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "marketplace.roles.stale-hash",
                    1,
                    "2026.05",
                    "Stale Hash Role Cards",
                    LensAssetSourceKind.marketplace.rawValue,
                    1,
                    itemsJSON,
                    trustMetadataJSON,
                    now,
                    now
                ]
            )
        }

        let store = AppStore(
            lensAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadLensAssetPacks()

        XCTAssertEqual(store.lensAssetPacks.map(\.id), ["marketplace.roles.stale-hash"])
        XCTAssertTrue(store.runtimeLensItems.isEmpty)
        XCTAssertFalse(store.availableLensChoices.contains { $0.id == "stale-role" })
    }

    func testSetLensAssetPackEnabled_updatesRuntimeChoicesAndClearsDisabledSelection() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "imported.roles.coach",
                version: "1.0.0",
                displayName: "Coach Roles",
                sourceKind: .imported,
                isEnabled: true,
                items: [Self.makeRuntimeLensPackItem(lensId: "role-coach", promptId: "role_coach")]
                )
            )
        )

        let store = AppStore(
            lensAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadLensAssetPacks()
        store.selectCustomLens("role-coach")

        await store.setLensAssetPack("imported.roles.coach", isEnabled: false)

        XCTAssertFalse(store.availableLensChoices.contains { $0.id == "role-coach" })
        XCTAssertNil(store.todayDraft.selectedCustomLensId)
        XCTAssertNil(store.selectedLensItem)
        let persistedPacks = try await packRepo.allPacks()
        let persisted = try XCTUnwrap(persistedPacks.first)
        XCTAssertFalse(persisted.isEnabled)
        XCTAssertEqual(persisted.trustMetadata?.contentHash, try AssetPackIntegrity.expectedContentHash(for: persisted))
        XCTAssertEqual(store.lensAssetPackMessage, "已停用 Coach Roles。")
    }

    func testImportLensAssetPackFromJSON_persistsAndEnablesPack() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        let pack = try Self.trusted(
            LensAssetPack(
            id: "imported.frameworks.review",
            version: "1.2.0",
            displayName: "Review Frameworks",
            sourceKind: .imported,
            isEnabled: true,
            items: [Self.makeRuntimeLensPackItem(lensId: "framework-review", promptId: "framework_review")]
            )
        )
        let payload = try JSONEncoder().encode(pack)
        let store = AppStore(
            lensAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )

        let imported = try await store.importLensAssetPack(from: payload)

        XCTAssertEqual(imported.id, "imported.frameworks.review")
        XCTAssertEqual(store.lensAssetPacks.map(\.id), ["imported.frameworks.review"])
        XCTAssertTrue(store.availableLensChoices.contains { $0.id == "framework-review" })
        let enabledPacks = try await packRepo.enabledPacks()
        XCTAssertEqual(enabledPacks.first?.id, "imported.frameworks.review")
        XCTAssertEqual(store.lensAssetPackMessage, "已导入 Review Frameworks，包含 1 个透镜。")
    }

    func testLoadPromptAssetPacks_listsAllPacksWithEnabledRuntimeCount() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                    id: "imported.prompts.coach",
                    version: "1.0.0",
                    displayName: "Coach Prompts",
                    sourceKind: .imported,
                    isEnabled: true,
                    templates: [
                        Self.makePromptPackTemplate(
                            promptId: .generateQuestions,
                            version: "coach.questions.v1",
                            userText: "Coach prompt should be active."
                        )
                    ]
                )
            )
        )
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                    id: "imported.prompts.off",
                    version: "1.0.0",
                    displayName: "Disabled Prompts",
                    sourceKind: .imported,
                    isEnabled: false,
                    templates: [
                        Self.makePromptPackTemplate(
                            promptId: .generateQuestions,
                            version: "off.questions.v1",
                            userText: "Disabled prompt should not be active."
                        )
                    ]
                )
            )
        )
        let store = AppStore(
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPromptAssetPacks()

        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["imported.prompts.coach", "imported.prompts.off"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "coach.questions.v1")
        XCTAssertEqual(store.promptAssetPackMessage, "已加载 2 个 Prompt 包，启用 1 个。")
    }

    func testSetPromptAssetPackEnabled_updatesRuntimePromptProvider() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        try await packRepo.savePack(
            try Self.trusted(
                PromptAssetPack(
                    id: "imported.prompts.coach",
                    version: "1.0.0",
                    displayName: "Coach Prompts",
                    sourceKind: .imported,
                    isEnabled: true,
                    templates: [
                        Self.makePromptPackTemplate(
                            promptId: .generateQuestions,
                            version: "coach.questions.v1",
                            userText: "Coach prompt should be active."
                        )
                    ]
                )
            )
        )
        let store = AppStore(
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPromptAssetPacks()

        await store.setPromptAssetPack("imported.prompts.coach", isEnabled: false)

        XCTAssertNotEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "coach.questions.v1")
        let persistedPacks = try await packRepo.allPacks()
        let persisted = try XCTUnwrap(persistedPacks.first)
        XCTAssertFalse(persisted.isEnabled)
        XCTAssertEqual(persisted.trustMetadata?.contentHash, try AssetPackIntegrity.expectedContentHash(for: persisted))
        XCTAssertEqual(store.promptAssetPackMessage, "已停用 Coach Prompts。")
    }

    func testImportPromptAssetPackFromJSON_persistsAndEnablesPack() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        let pack = try Self.trusted(
            PromptAssetPack(
                id: "imported.prompts.review",
                version: "1.2.0",
                displayName: "Review Prompts",
                sourceKind: .imported,
                isEnabled: true,
                templates: [
                    Self.makePromptPackTemplate(
                        promptId: .generateQuestions,
                        version: "review.questions.v1",
                        userText: "Review prompt should be active."
                    )
                ]
            )
        )
        let payload = try JSONEncoder().encode(pack)
        let store = AppStore(
            promptAssetPackRepository: packRepo,
            refreshesAIServiceFromKeychain: false
        )

        let imported = try await store.importPromptAssetPack(from: payload)

        XCTAssertEqual(imported.id, "imported.prompts.review")
        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["imported.prompts.review"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "review.questions.v1")
        let enabledPacks = try await packRepo.enabledPacks()
        XCTAssertEqual(enabledPacks.first?.id, "imported.prompts.review")
        XCTAssertEqual(store.promptAssetPackMessage, "已导入 Review Prompts，包含 1 个 Prompt 模板。")
    }

    func testImportAssetPackInstallManifestFromJSON_savesValidatedPacksAndRefreshesRuntimeAssets() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let installablePrompt = PromptAssetPack(
            id: "marketplace.prompts.installable-settings",
            version: "2026.06",
            displayName: "Installable Settings Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "settings.questions.v1",
                    userText: "Settings manifest prompt should be active."
                )
            ]
        )
        let rejectedPrompt = PromptAssetPack(
            id: "marketplace.prompts.rejected-settings",
            version: "2026.06",
            displayName: "Rejected Settings Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: installablePrompt.templates
        )
        let installableLens = LensAssetPack(
            id: "marketplace.roles.installable-settings",
            version: "2026.06",
            displayName: "Installable Settings Roles",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [
                Self.makeRuntimeLensPackItem(
                    lensId: "settings-role-installable",
                    promptId: "settings_role_installable"
                )
            ]
        )
        let rejectedLens = LensAssetPack(
            id: "marketplace.roles.rejected-settings",
            version: "2026.06",
            displayName: "Rejected Settings Roles",
            sourceKind: .marketplace,
            isEnabled: true,
            items: installableLens.items
        )
        let manifest = AssetPackInstallManifest(
            promptPacks: [
                try Self.trusted(installablePrompt),
                rejectedPrompt
            ],
            lensPacks: [
                try Self.trusted(installableLens),
                rejectedLens
            ]
        )
        let payload = try JSONEncoder().encode(manifest)
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.importAssetPackInstallManifest(from: payload)

        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.installable-settings"])
        XCTAssertEqual(report.rejectedPromptPacks.map(\.packId), ["marketplace.prompts.rejected-settings"])
        XCTAssertEqual(report.installableLensPacks.map(\.id), ["marketplace.roles.installable-settings"])
        XCTAssertEqual(report.rejectedLensPacks.map(\.packId), ["marketplace.roles.rejected-settings"])
        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["marketplace.prompts.installable-settings"])
        XCTAssertEqual(store.lensAssetPacks.map(\.id), ["marketplace.roles.installable-settings"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "settings.questions.v1")
        XCTAssertTrue(store.availableLensChoices.contains { $0.id == "settings-role-installable" })
        let savedPromptPackIds = try await promptRepo.allPacks().map(\.id)
        let savedLensPackIds = try await lensRepo.allPacks().map(\.id)
        XCTAssertEqual(savedPromptPackIds, ["marketplace.prompts.installable-settings"])
        XCTAssertEqual(savedLensPackIds, ["marketplace.roles.installable-settings"])
        XCTAssertEqual(store.assetPackInstallMessage, "已安装 1 个 Prompt 包、1 个透镜包；拒绝 1 个 Prompt 包、1 个透镜包。拒绝原因：Prompt 包缺少信任元数据 1 个、透镜包缺少信任元数据 1 个。")
    }

    func testFetchAndInstallAssetPackInstallManifest_reusesTrustedInstallGateAndRefreshesRuntimeAssets() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let installablePrompt = PromptAssetPack(
            id: "marketplace.prompts.remote-installable",
            version: "2026.06",
            displayName: "Remote Installable Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "remote.questions.v1",
                    userText: "Remote manifest prompt should be active."
                )
            ]
        )
        let rejectedPrompt = PromptAssetPack(
            id: "marketplace.prompts.remote-rejected",
            version: "2026.06",
            displayName: "Remote Rejected Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: installablePrompt.templates
        )
        let installableLens = LensAssetPack(
            id: "marketplace.roles.remote-installable",
            version: "2026.06",
            displayName: "Remote Installable Roles",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [
                Self.makeRuntimeLensPackItem(
                    lensId: "remote-role-installable",
                    promptId: "remote_role_installable"
                )
            ]
        )
        let manifest = AssetPackInstallManifest(
            promptPacks: [
                try Self.trusted(installablePrompt),
                rejectedPrompt
            ],
            lensPacks: [
                try Self.trusted(installableLens)
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [remoteURL: try JSONEncoder().encode(manifest)]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        XCTAssertEqual(fetcher.requestedURLs, [remoteURL])
        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.remote-installable"])
        XCTAssertEqual(report.rejectedPromptPacks.map(\.packId), ["marketplace.prompts.remote-rejected"])
        XCTAssertEqual(report.rejectedPromptPacks.map(\.reason), [.missingTrustMetadata])
        XCTAssertEqual(report.installableLensPacks.map(\.id), ["marketplace.roles.remote-installable"])
        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["marketplace.prompts.remote-installable"])
        XCTAssertEqual(store.lensAssetPacks.map(\.id), ["marketplace.roles.remote-installable"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "remote.questions.v1")
        XCTAssertTrue(store.availableLensChoices.contains { $0.id == "remote-role-installable" })
        XCTAssertEqual(store.assetPackInstallMessage, "已从远程清单安装：已安装 1 个 Prompt 包、1 个透镜包；拒绝 1 个 Prompt 包、0 个透镜包。拒绝原因：Prompt 包缺少信任元数据 1 个。")
    }

    func testFetchAndInstallAssetPackInstallManifest_usesRemoteTrustPolicyBeforeInstalling() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let remotePolicyVersion = "asset-trust.remote.rotated.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.remote-policy",
            version: "2026.06",
            displayName: "Remote Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "remote.policy.questions.v1",
                    userText: "Remote policy prompt should be active."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let manifest = AssetPackInstallManifest(
            trustPolicyURL: policyURL,
            promptPacks: [trustedPrompt]
        )
        let policy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    )
                ]
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                remoteURL: try JSONEncoder().encode(manifest),
                policyURL: try JSONEncoder().encode(policy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        XCTAssertEqual(fetcher.requestedURLs, [remoteURL, policyURL])
        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.remote-policy"])
        XCTAssertTrue(report.rejectedPromptPacks.isEmpty)
        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["marketplace.prompts.remote-policy"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "remote.policy.questions.v1")
    }

    func testFetchAndInstallAssetPackInstallManifest_surfacesRemotePublisherProfiles() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let remotePolicyVersion = "asset-trust.remote.profiled.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.profiled-policy",
            version: "2026.06",
            displayName: "Profiled Publisher Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "profiled.policy.questions.v1",
                    userText: "Profiled publisher prompt should be active."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let manifest = AssetPackInstallManifest(
            trustPolicyURL: policyURL,
            promptPacks: [trustedPrompt]
        )
        let policy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        publisherProfiles: [
                            AssetPackPublisherProfile(
                                id: "mingsi.test.publisher",
                                displayName: "MingSi Test Publisher",
                                websiteURL: URL(string: "https://publisher.mingsi.test")!,
                                trustSummary: "Publishes signed Prompt and Lens packs."
                            )
                        ]
                    )
                ]
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                remoteURL: try JSONEncoder().encode(manifest),
                policyURL: try JSONEncoder().encode(policy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.profiled-policy"])
        XCTAssertTrue(store.assetPackInstallMessage.contains("信任发布者：MingSi Test Publisher。"))
    }

    func testFetchAndInstallAssetPackInstallManifest_surfacesOnlyInstalledPublisherProfiles() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let remotePolicyVersion = "asset-trust.remote.profiled.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.profiled-policy",
            version: "2026.06",
            displayName: "Profiled Publisher Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "profiled.policy.questions.v1",
                    userText: "Profiled publisher prompt should be active."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let manifest = AssetPackInstallManifest(
            trustPolicyURL: policyURL,
            promptPacks: [trustedPrompt]
        )
        let policy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64],
                            "mingsi.other.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        publisherProfiles: [
                            AssetPackPublisherProfile(
                                id: "mingsi.test.publisher",
                                displayName: "MingSi Test Publisher",
                                websiteURL: URL(string: "https://publisher.mingsi.test")!,
                                trustSummary: "Publishes signed Prompt and Lens packs."
                            ),
                            AssetPackPublisherProfile(
                                id: "mingsi.other.publisher",
                                displayName: "Other Publisher",
                                websiteURL: URL(string: "https://other.publisher.mingsi.test")!,
                                trustSummary: "Included in the trust policy but not installed here."
                            )
                        ]
                    )
                ]
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                remoteURL: try JSONEncoder().encode(manifest),
                policyURL: try JSONEncoder().encode(policy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.profiled-policy"])
        XCTAssertTrue(store.assetPackInstallMessage.contains("信任发布者：MingSi Test Publisher。"))
        XCTAssertFalse(store.assetPackInstallMessage.contains("Other Publisher"))
    }

    func testFetchAndInstallAssetPackInstallManifest_rejectsUnsignedRemoteTrustPolicy() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let remotePolicyVersion = "asset-trust.remote.unsigned.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.unsigned-policy",
            version: "2026.06",
            displayName: "Unsigned Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "unsigned.policy.questions.v1",
                    userText: "Unsigned policy prompt should not install."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let manifest = AssetPackInstallManifest(
            trustPolicyURL: policyURL,
            promptPacks: [trustedPrompt]
        )
        let unsignedPolicy = AssetPackTrustPolicyDocument(
            policies: [
                AssetPackTrustPolicy(
                    version: remotePolicyVersion,
                    trustedPublisherPublicKeys: [
                        "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                    ]
                )
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                remoteURL: try Self.assetPackJSONEncoder.encode(manifest),
                policyURL: try Self.assetPackJSONEncoder.encode(unsignedPolicy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        XCTAssertEqual(report.installablePromptPacks.map(\.id), [String]())
        XCTAssertEqual(report.rejectedPromptPacks.map(\.reason), [AssetPackInstallRejectionReason.invalidTrustProof])
        XCTAssertEqual(store.promptAssetPacks.map(\.id), [])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "1.11.0")
    }

    func testFetchAndInstallAssetPackInstallManifest_rejectsExpiredRemoteTrustPolicy() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let remotePolicyVersion = "asset-trust.remote.expired.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.expired-policy",
            version: "2026.06",
            displayName: "Expired Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "expired.policy.questions.v1",
                    userText: "Expired policy prompt should not install."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let manifest = AssetPackInstallManifest(
            trustPolicyURL: policyURL,
            promptPacks: [trustedPrompt]
        )
        let expiredPolicy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    )
                ],
                expiresAt: Date(timeIntervalSince1970: 1)
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                remoteURL: try Self.assetPackJSONEncoder.encode(manifest),
                policyURL: try Self.assetPackJSONEncoder.encode(expiredPolicy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )

        let report = try await store.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        XCTAssertEqual(report.installablePromptPacks.map(\.id), [String]())
        XCTAssertEqual(report.rejectedPromptPacks.map(\.reason), [AssetPackInstallRejectionReason.invalidTrustProof])
        XCTAssertEqual(store.promptAssetPacks.map(\.id), [])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "1.11.0")
    }

    func testLoadPersistedState_usesPersistedRemoteTrustPolicyForPromptAssetPacks() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let remotePolicyVersion = "asset-trust.remote.persisted.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.persisted-policy",
            version: "2026.06",
            displayName: "Persisted Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "persisted.policy.questions.v1",
                    userText: "Persisted policy prompt should survive restart."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let manifest = AssetPackInstallManifest(
            trustPolicyURL: policyURL,
            promptPacks: [trustedPrompt]
        )
        let policy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    )
                ]
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                remoteURL: try JSONEncoder().encode(manifest),
                policyURL: try JSONEncoder().encode(policy)
            ]
        )
        let installingStore = AppStore(
            lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )
        _ = try await installingStore.fetchAndInstallAssetPackInstallManifest(
            from: remoteURL,
            fetcher: fetcher
        )

        let restoredStore = AppStore(
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.promptTemplate(for: .generateQuestions, mode: .standard).version, "persisted.policy.questions.v1")
        XCTAssertEqual(restoredStore.promptAssetPacks.map(\.id), ["marketplace.prompts.persisted-policy"])
    }

    func testLoadPersistedState_excludesPacksAuthorizedOnlyByExpiredRemoteTrustPolicy() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remotePolicyVersion = "asset-trust.remote.expired-persisted.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.expired-persisted-policy",
            version: "2026.06",
            displayName: "Expired Persisted Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "expired.persisted.policy.questions.v1",
                    userText: "Expired persisted policy prompt should not survive restart."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let activePolicy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    )
                ],
                expiresAt: Date(timeIntervalSinceNow: 60)
            )
        )
        let expiredPolicy = try Self.signedTrustPolicyDocument(AssetPackTrustPolicyDocument(
            policies: activePolicy.policies,
            expiresAt: Date(timeIntervalSince1970: 1)
        ))
        try await SQLitePromptAssetPackRepository(
            database: database,
            signatureVerifier: activePolicy.signatureVerifier
        ).savePack(trustedPrompt)
        try await SQLiteAssetPackTrustPolicyRepository(database: database).saveDocument(
            expiredPolicy,
            sourceURL: URL(string: "https://registry.mingsi.test/assets/expired-trust-policy.json")!
        )

        let restoredStore = AppStore(
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.promptAssetPacks.map(\.id), ["marketplace.prompts.expired-persisted-policy"])
        XCTAssertEqual(restoredStore.promptTemplate(for: .generateQuestions, mode: .standard).version, "1.11.0")
    }

    func testLoadPersistedState_excludesPacksAuthorizedOnlyByUnsignedRemoteTrustPolicy() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remotePolicyVersion = "asset-trust.remote.unsigned-persisted.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.unsigned-persisted-policy",
            version: "2026.06",
            displayName: "Unsigned Persisted Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "unsigned.persisted.policy.questions.v1",
                    userText: "Unsigned persisted policy prompt should not survive restart."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let signedPolicy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ]
                    )
                ]
            )
        )
        let unsignedPolicy = AssetPackTrustPolicyDocument(policies: signedPolicy.policies)
        try await SQLitePromptAssetPackRepository(
            database: database,
            signatureVerifier: signedPolicy.signatureVerifier
        ).savePack(trustedPrompt)
        try await SQLiteAssetPackTrustPolicyRepository(database: database).saveDocument(
            unsignedPolicy,
            sourceURL: URL(string: "https://registry.mingsi.test/assets/unsigned-trust-policy.json")!
        )

        let restoredStore = AppStore(
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.promptAssetPacks.map(\.id), ["marketplace.prompts.unsigned-persisted-policy"])
        XCTAssertEqual(restoredStore.promptTemplate(for: .generateQuestions, mode: .standard).version, "1.11.0")
    }

    func testFetchAndInstallAssetPackInstallManifest_reportsRemoteTrustPolicyFetchFailure() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/install-manifest.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/assets/trust-policy.json")!
        let manifest = AssetPackInstallManifest(trustPolicyURL: policyURL)
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [remoteURL: try JSONEncoder().encode(manifest)],
            errorByURL: [policyURL: URLError(.notConnectedToInternet)]
        )
        let store = AppStore(
            lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )

        do {
            _ = try await store.fetchAndInstallAssetPackInstallManifest(
                from: remoteURL,
                fetcher: fetcher
            )
            XCTFail("Expected remote trust policy fetch to fail.")
        } catch {
            XCTAssertEqual(fetcher.requestedURLs, [remoteURL, policyURL])
            XCTAssertTrue(store.assetPackInstallMessage.contains("获取远程资产包信任策略失败"))
            XCTAssertFalse(store.assetPackInstallMessage.contains("获取远程资产包清单失败"))
            XCTAssertFalse(store.assetPackInstallMessage.hasPrefix("已从远程清单安装"))
        }
    }

    func testFetchAndInstallAssetPackInstallManifest_reportsFetchFailure() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/missing.json")!
        let fetcher = FakeAssetPackInstallManifestFetcher(error: URLError(.fileDoesNotExist))
        let store = AppStore(
            lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )

        do {
            _ = try await store.fetchAndInstallAssetPackInstallManifest(
                from: remoteURL,
                fetcher: fetcher
            )
            XCTFail("Expected remote manifest fetch to fail.")
        } catch {
            XCTAssertEqual(fetcher.requestedURLs, [remoteURL])
            XCTAssertTrue(store.assetPackInstallMessage.contains("获取远程资产包清单失败"))
        }
    }

    func testFetchAndInstallAssetPackInstallManifest_keepsInstallFailureDistinctFromFetchFailure() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let remoteURL = URL(string: "https://registry.mingsi.test/assets/invalid.json")!
        let fetcher = FakeAssetPackInstallManifestFetcher(dataByURL: [remoteURL: Data("{".utf8)])
        let store = AppStore(
            lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
            promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )

        do {
            _ = try await store.fetchAndInstallAssetPackInstallManifest(
                from: remoteURL,
                fetcher: fetcher
            )
            XCTFail("Expected remote manifest install to fail.")
        } catch {
            XCTAssertEqual(fetcher.requestedURLs, [remoteURL])
            XCTAssertTrue(store.assetPackInstallMessage.contains("安装资产包清单失败"))
            XCTAssertFalse(store.assetPackInstallMessage.contains("获取远程资产包清单失败"))
        }
    }

    func testFetchAssetPackRegistryCatalog_loadsRemoteEntriesForSettingsSelection() async throws {
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog.json")!
        let manifestURL = URL(string: "https://registry.mingsi.test/manifests/coach.json")!
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.coach",
                    displayName: "Coach Starter Pack",
                    summary: "Prompt and lens starter pack.",
                    manifestURL: manifestURL,
                    updatedAt: Date(timeIntervalSince1970: 1_804_032_000)
                )
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [catalogURL: try Self.assetPackJSONEncoder.encode(catalog)]
        )
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        let loadedCatalog = try await store.fetchAssetPackRegistryCatalog(from: catalogURL, fetcher: fetcher)

        XCTAssertEqual(fetcher.requestedURLs, [catalogURL])
        XCTAssertEqual(loadedCatalog, catalog)
        XCTAssertEqual(store.assetPackRegistryCatalogEntries.map(\.id), ["marketplace.coach"])
        XCTAssertEqual(store.assetPackInstallMessage, "已获取 1 个远程资产包条目。")
    }

    func testSyncAssetPackRegistrySubscriptions_fetchesEnabledCatalogsAndRecordsStatus() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog.json")!
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "mingsi.registry.default",
            displayName: "MingSi Registry",
            catalogURL: catalogURL,
            isEnabled: true
        ))
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "mingsi.registry.disabled",
            displayName: "Disabled Registry",
            catalogURL: URL(string: "https://registry.mingsi.test/disabled.json")!,
            isEnabled: false
        ))

        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.coach",
                    displayName: "Coach Starter Pack",
                    summary: "Prompt and lens starter pack.",
                    manifestURL: URL(string: "manifests/coach.json")!
                )
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [catalogURL: try Self.assetPackJSONEncoder.encode(catalog)]
        )
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            refreshesAIServiceFromKeychain: false
        )

        let syncedEntries = try await store.syncAssetPackRegistrySubscriptions(fetcher: fetcher)

        XCTAssertEqual(fetcher.requestedURLs, [catalogURL])
        XCTAssertEqual(syncedEntries.map(\.id), ["marketplace.coach"])
        XCTAssertEqual(store.assetPackRegistryCatalogEntries.map(\.id), ["marketplace.coach"])
        XCTAssertTrue(store.assetPackInstallMessage.contains("已同步 1 个资产包目录订阅，获取 1 个条目"))

        let subscriptions = try await subscriptionRepo.allSubscriptions()
        let enabled = try XCTUnwrap(subscriptions.first { $0.id == "mingsi.registry.default" })
        let disabled = try XCTUnwrap(subscriptions.first { $0.id == "mingsi.registry.disabled" })
        XCTAssertEqual(enabled.lastSyncStatus, .succeeded)
        XCTAssertEqual(enabled.lastSyncMessage, "Fetched 1 entries.")
        XCTAssertNotNil(enabled.lastSyncedAt)
        XCTAssertEqual(disabled.lastSyncStatus, .neverSynced)
        XCTAssertNil(disabled.lastSyncedAt)
    }

    func testSaveAssetPackRegistrySubscription_persistsAndLoadsForSettingsManagement() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog.json")!
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            refreshesAIServiceFromKeychain: false
        )

        let saved = try await store.saveAssetPackRegistrySubscription(
            displayName: "MingSi Registry",
            catalogURL: catalogURL
        )

        XCTAssertEqual(saved.displayName, "MingSi Registry")
        XCTAssertEqual(saved.catalogURL, catalogURL)
        XCTAssertEqual(saved.lastSyncStatus, .neverSynced)
        XCTAssertEqual(store.assetPackRegistrySubscriptions.map(\.id), [saved.id])
        XCTAssertTrue(store.assetPackInstallMessage.contains("已保存资产包目录订阅"))

        let reloadedStore = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            refreshesAIServiceFromKeychain: false
        )
        await reloadedStore.loadAssetPackRegistrySubscriptions()

        XCTAssertEqual(reloadedStore.assetPackRegistrySubscriptions.map(\.id), [saved.id])
        XCTAssertEqual(reloadedStore.assetPackRegistrySubscriptions.first?.displayName, "MingSi Registry")
        XCTAssertTrue(reloadedStore.assetPackInstallMessage.contains("已加载 1 个资产包目录订阅，启用 1 个"))
    }

    func testSetAssetPackRegistrySubscriptionEnabled_updatesInventoryAndSyncScope() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog.json")!
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            refreshesAIServiceFromKeychain: false
        )
        let saved = try await store.saveAssetPackRegistrySubscription(
            displayName: "MingSi Registry",
            catalogURL: catalogURL
        )

        await store.setAssetPackRegistrySubscription(saved.id, isEnabled: false)
        let fetcher = FakeAssetPackInstallManifestFetcher(dataByURL: [catalogURL: Data()])
        let syncedEntries = try await store.syncAssetPackRegistrySubscriptions(fetcher: fetcher)

        XCTAssertEqual(store.assetPackRegistrySubscriptions.first?.isEnabled, false)
        XCTAssertEqual(fetcher.requestedURLs, [])
        XCTAssertEqual(syncedEntries, [])
        XCTAssertEqual(store.assetPackInstallMessage, "没有已启用的资产包目录订阅。")
    }

    func testSyncDueAssetPackRegistrySubscriptions_fetchesOnlyDueSubscriptions() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let now = Date(timeIntervalSince1970: 1_000)
        let staleURL = URL(string: "https://registry.mingsi.test/stale.json")!
        let neverURL = URL(string: "https://registry.mingsi.test/never.json")!
        let freshURL = URL(string: "https://registry.mingsi.test/fresh.json")!
        let disabledURL = URL(string: "https://registry.mingsi.test/disabled.json")!

        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.stale",
            displayName: "Stale Registry",
            catalogURL: staleURL,
            isEnabled: true,
            lastSyncedAt: now.addingTimeInterval(-61),
            lastSyncStatus: .succeeded,
            lastSyncMessage: "Previous success."
        ))
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.never",
            displayName: "Never Registry",
            catalogURL: neverURL,
            isEnabled: true,
            lastSyncedAt: nil,
            lastSyncStatus: .neverSynced
        ))
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.fresh",
            displayName: "Fresh Registry",
            catalogURL: freshURL,
            isEnabled: true,
            lastSyncedAt: now.addingTimeInterval(-30),
            lastSyncStatus: .succeeded,
            lastSyncMessage: "Still fresh."
        ))
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.disabled",
            displayName: "Disabled Registry",
            catalogURL: disabledURL,
            isEnabled: false,
            lastSyncedAt: nil,
            lastSyncStatus: .neverSynced
        ))

        let staleCatalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.stale",
                    displayName: "Stale Due Pack",
                    summary: "Fetched from a stale subscription.",
                    manifestURL: URL(string: "manifests/stale.json")!
                )
            ]
        )
        let neverCatalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.never",
                    displayName: "Never Due Pack",
                    summary: "Fetched from a never-synced subscription.",
                    manifestURL: URL(string: "manifests/never.json")!
                )
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(dataByURL: [
            staleURL: try Self.assetPackJSONEncoder.encode(staleCatalog),
            neverURL: try Self.assetPackJSONEncoder.encode(neverCatalog),
            freshURL: Data(),
            disabledURL: Data()
        ])
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            refreshesAIServiceFromKeychain: false
        )

        let syncedEntries = try await store.syncDueAssetPackRegistrySubscriptions(
            now: now,
            schedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy(minimumSyncInterval: 60),
            fetcher: fetcher
        )

        XCTAssertEqual(Set(fetcher.requestedURLs), Set([staleURL, neverURL]))
        XCTAssertEqual(fetcher.requestedURLs.count, 2)
        XCTAssertEqual(Set(syncedEntries.map(\.id)), Set(["marketplace.stale", "marketplace.never"]))
        XCTAssertEqual(Set(store.assetPackRegistryCatalogEntries.map(\.id)), Set(["marketplace.stale", "marketplace.never"]))
        XCTAssertTrue(store.assetPackInstallMessage.contains("自动同步 2 个资产包目录订阅"))

        let subscriptions = try await subscriptionRepo.allSubscriptions()
        let stale = try XCTUnwrap(subscriptions.first { $0.id == "registry.stale" })
        let never = try XCTUnwrap(subscriptions.first { $0.id == "registry.never" })
        let fresh = try XCTUnwrap(subscriptions.first { $0.id == "registry.fresh" })
        let disabled = try XCTUnwrap(subscriptions.first { $0.id == "registry.disabled" })
        XCTAssertEqual(stale.lastSyncStatus, .succeeded)
        XCTAssertEqual(never.lastSyncStatus, .succeeded)
        XCTAssertEqual(fresh.lastSyncStatus, .succeeded)
        XCTAssertEqual(fresh.lastSyncMessage, "Still fresh.")
        XCTAssertEqual(disabled.lastSyncStatus, .neverSynced)
    }

    func testSyncDueAssetPackRegistrySubscriptions_skipsNetworkWhenNothingIsDue() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let now = Date(timeIntervalSince1970: 1_000)
        let catalogURL = URL(string: "https://registry.mingsi.test/fresh.json")!
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.fresh",
            displayName: "Fresh Registry",
            catalogURL: catalogURL,
            isEnabled: true,
            lastSyncedAt: now.addingTimeInterval(-30),
            lastSyncStatus: .succeeded,
            lastSyncMessage: "Still fresh."
        ))
        let fetcher = FakeAssetPackInstallManifestFetcher(dataByURL: [catalogURL: Data()])
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            refreshesAIServiceFromKeychain: false
        )

        let syncedEntries = try await store.syncDueAssetPackRegistrySubscriptions(
            now: now,
            schedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy(minimumSyncInterval: 60),
            fetcher: fetcher
        )

        XCTAssertEqual(fetcher.requestedURLs, [])
        XCTAssertEqual(syncedEntries, [])
        XCTAssertEqual(store.assetPackRegistryCatalogEntries, [])
        XCTAssertEqual(store.assetPackInstallMessage, "资产包目录订阅未到自动同步时间。")
    }

    func testLoadPersistedState_doesNotSyncAssetPackRegistrySubscriptionsByDefault() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let now = Date(timeIntervalSince1970: 1_000)
        let catalogURL = URL(string: "https://registry.mingsi.test/due.json")!
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.due",
            displayName: "Due Registry",
            catalogURL: catalogURL,
            isEnabled: true,
            lastSyncedAt: now.addingTimeInterval(-61),
            lastSyncStatus: .succeeded,
            lastSyncMessage: "Previous success."
        ))
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.due",
                    displayName: "Due Pack",
                    summary: "Should not be fetched during default persisted-state load.",
                    manifestURL: URL(string: "manifests/due.json")!
                )
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [catalogURL: try Self.assetPackJSONEncoder.encode(catalog)]
        )
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            assetPackRegistrySyncSchedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy(minimumSyncInterval: 60),
            assetPackRegistrySyncFetcher: fetcher,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        XCTAssertEqual(fetcher.requestedURLs, [])
        XCTAssertEqual(store.assetPackRegistryCatalogEntries, [])
        let subscriptions = try await subscriptionRepo.allSubscriptions()
        let due = try XCTUnwrap(subscriptions.first { $0.id == "registry.due" })
        XCTAssertEqual(due.lastSyncStatus, .succeeded)
        XCTAssertEqual(due.lastSyncMessage, "Previous success.")
        XCTAssertEqual(due.lastSyncedAt, now.addingTimeInterval(-61))
    }

    func testLoadPersistedState_runsDueAssetPackRegistrySubscriptionSyncWhenExplicitlyEnabled() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let subscriptionRepo = SQLiteAssetPackRegistrySubscriptionRepository(database: database)
        let now = Date(timeIntervalSince1970: 1_000)
        let catalogURL = URL(string: "https://registry.mingsi.test/due.json")!
        try await subscriptionRepo.saveSubscription(AssetPackRegistrySubscription(
            id: "registry.due",
            displayName: "Due Registry",
            catalogURL: catalogURL,
            isEnabled: true,
            lastSyncedAt: now.addingTimeInterval(-61),
            lastSyncStatus: .succeeded,
            lastSyncMessage: "Previous success."
        ))
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.due",
                    displayName: "Due Pack",
                    summary: "Fetched during persisted-state load.",
                    manifestURL: URL(string: "manifests/due.json")!
                )
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [catalogURL: try Self.assetPackJSONEncoder.encode(catalog)]
        )
        let store = AppStore(
            assetPackRegistrySubscriptionRepository: subscriptionRepo,
            assetPackRegistrySyncSchedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy(minimumSyncInterval: 60),
            assetPackRegistrySyncFetcher: fetcher,
            syncsAssetPackRegistryOnLoad: true,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        XCTAssertEqual(fetcher.requestedURLs, [catalogURL])
        XCTAssertEqual(store.assetPackRegistryCatalogEntries.map(\.id), ["marketplace.due"])
        XCTAssertTrue(store.assetPackInstallMessage.contains("自动同步 1 个资产包目录订阅"))
    }

    func testInstallAssetPackRegistryCatalogEntry_fetchesEntryManifestAndInstallsThroughTrustGate() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog.json")!
        let manifestURL = URL(string: "https://registry.mingsi.test/manifests/coach.json")!
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.catalog-installable",
            version: "2026.06",
            displayName: "Catalog Installable Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "catalog.questions.v1",
                    userText: "Catalog manifest prompt should be active."
                )
            ]
        )
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.coach",
                    displayName: "Coach Starter Pack",
                    summary: "Prompt and lens starter pack.",
                    manifestURL: manifestURL,
                    updatedAt: nil
                )
            ]
        )
        let manifest = AssetPackInstallManifest(
            promptPacks: [
                try Self.trusted(prompt)
            ]
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                catalogURL: try Self.assetPackJSONEncoder.encode(catalog),
                manifestURL: try Self.assetPackJSONEncoder.encode(manifest)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        _ = try await store.fetchAssetPackRegistryCatalog(from: catalogURL, fetcher: fetcher)
        let report = try await store.installAssetPackRegistryCatalogEntry(
            entryId: "marketplace.coach",
            fetcher: fetcher
        )

        XCTAssertEqual(fetcher.requestedURLs, [catalogURL, manifestURL])
        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.catalog-installable"])
        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["marketplace.prompts.catalog-installable"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "catalog.questions.v1")
        XCTAssertEqual(store.assetPackInstallMessage, "已从 Coach Starter Pack 安装：已安装 1 个 Prompt 包、0 个透镜包；拒绝 0 个 Prompt 包、0 个透镜包。")
    }

    func testInstallAssetPackRegistryCatalogEntry_usesCatalogTrustPolicyWhenManifestOmitsPolicy() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog/index.json")!
        let manifestURL = URL(string: "https://registry.mingsi.test/catalog/manifests/coach.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/catalog/trust/policies/coach.json")!
        let remotePolicyVersion = "asset-trust.remote.catalog-entry.v1"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.catalog-policy",
            version: "2026.06",
            displayName: "Catalog Policy Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "catalog.policy.questions.v1",
                    userText: "Catalog trust policy prompt should be active."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: remotePolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.catalog-policy",
                    displayName: "Catalog Policy Pack",
                    summary: "Catalog entry supplies trust policy metadata.",
                    manifestURL: URL(string: "manifests/coach.json")!,
                    updatedAt: nil,
                    publisherId: "mingsi.test.publisher",
                    publisherDisplayName: "MingSi Test Publisher",
                    trustPolicyURL: URL(string: "trust/policies/coach.json")!,
                    requiredVerificationPolicyVersion: remotePolicyVersion
                )
            ]
        )
        let manifest = AssetPackInstallManifest(promptPacks: [trustedPrompt])
        let policy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: remotePolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    )
                ]
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                catalogURL: try Self.assetPackJSONEncoder.encode(catalog),
                manifestURL: try Self.assetPackJSONEncoder.encode(manifest),
                policyURL: try Self.assetPackJSONEncoder.encode(policy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        _ = try await store.fetchAssetPackRegistryCatalog(from: catalogURL, fetcher: fetcher)
        let report = try await store.installAssetPackRegistryCatalogEntry(
            entryId: "marketplace.catalog-policy",
            fetcher: fetcher
        )

        XCTAssertEqual(fetcher.requestedURLs, [catalogURL, manifestURL, policyURL])
        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.catalog-policy"])
        XCTAssertTrue(report.rejectedPromptPacks.isEmpty)
        XCTAssertEqual(store.promptAssetPacks.map(\.id), ["marketplace.prompts.catalog-policy"])
        XCTAssertEqual(store.promptTemplate(for: .generateQuestions, mode: .standard).version, "catalog.policy.questions.v1")
        XCTAssertEqual(store.assetPackInstallMessage, "已从 Catalog Policy Pack 安装：已安装 1 个 Prompt 包、0 个透镜包；拒绝 0 个 Prompt 包、0 个透镜包。")
    }

    func testInstallAssetPackRegistryCatalogEntry_rejectsPackWhenRequiredPolicyVersionDiffers() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog/index.json")!
        let manifestURL = URL(string: "https://registry.mingsi.test/catalog/manifests/coach.json")!
        let policyURL = URL(string: "https://registry.mingsi.test/catalog/trust/policies/coach.json")!
        let signedPolicyVersion = "asset-trust.remote.catalog-entry.v1"
        let requiredPolicyVersion = "asset-trust.remote.catalog-entry.v2"
        let prompt = PromptAssetPack(
            id: "marketplace.prompts.catalog-policy-mismatch",
            version: "2026.06",
            displayName: "Catalog Policy Mismatch Prompts",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                Self.makePromptPackTemplate(
                    promptId: .generateQuestions,
                    version: "catalog.policy.mismatch.questions.v1",
                    userText: "This prompt should be rejected because the catalog requires v2."
                )
            ]
        )
        let trustedPrompt = try Self.trusted(
            prompt,
            verificationPolicyVersion: signedPolicyVersion,
            privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
        )
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.catalog-policy-mismatch",
                    displayName: "Catalog Policy Mismatch Pack",
                    summary: "Catalog entry requires a newer policy version.",
                    manifestURL: URL(string: "manifests/coach.json")!,
                    updatedAt: nil,
                    publisherId: "mingsi.test.publisher",
                    publisherDisplayName: "MingSi Test Publisher",
                    trustPolicyURL: URL(string: "trust/policies/coach.json")!,
                    requiredVerificationPolicyVersion: requiredPolicyVersion
                )
            ]
        )
        let manifest = AssetPackInstallManifest(promptPacks: [trustedPrompt])
        let policy = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: signedPolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    ),
                    AssetPackTrustPolicy(
                        version: requiredPolicyVersion,
                        trustedPublisherPublicKeys: [
                            "mingsi.test.publisher": [Self.rotatedPublisherPublicKeyBase64]
                        ],
                        revokedPublisherIds: []
                    )
                ]
            )
        )
        let fetcher = FakeAssetPackInstallManifestFetcher(
            dataByURL: [
                catalogURL: try Self.assetPackJSONEncoder.encode(catalog),
                manifestURL: try Self.assetPackJSONEncoder.encode(manifest),
                policyURL: try Self.assetPackJSONEncoder.encode(policy)
            ]
        )
        let store = AppStore(
            lensAssetPackRepository: lensRepo,
            promptAssetPackRepository: promptRepo,
            refreshesAIServiceFromKeychain: false
        )

        _ = try await store.fetchAssetPackRegistryCatalog(from: catalogURL, fetcher: fetcher)
        let report = try await store.installAssetPackRegistryCatalogEntry(
            entryId: "marketplace.catalog-policy-mismatch",
            fetcher: fetcher
        )

        XCTAssertEqual(fetcher.requestedURLs, [catalogURL, manifestURL, policyURL])
        XCTAssertTrue(report.installablePromptPacks.isEmpty)
        XCTAssertEqual(report.rejectedPromptPacks.map(\.packId), ["marketplace.prompts.catalog-policy-mismatch"])
        XCTAssertEqual(report.rejectedPromptPacks.map(\.reason), [.unexpectedVerificationPolicyVersion])
        XCTAssertTrue(store.promptAssetPacks.isEmpty)
        XCTAssertTrue(store.assetPackInstallMessage.contains("拒绝 1 个 Prompt 包"))
        XCTAssertTrue(store.assetPackInstallMessage.contains("Prompt 包策略版本不匹配 1 个"))
    }

    func testSelectLens_generateQuestionsUsesHistoricalActivePrinciplesAndShowsReferences() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let principleRepo = SQLitePrincipleRepository(database: database)
        let historicalPrinciple = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await principleRepo.savePrinciple(historicalPrinciple, sourceDailyEntryId: UUID())

        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            principleRepository: principleRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.selectLens)
        var card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without a clear owner or acceptance criteria."
        )
        card.isConfirmed = true
        store.thinkingCards = [card]

        store.selectThinkingLens(.evidenceCheck)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuestions })
        XCTAssertEqual(request.prompt.id, .generateQuestions)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertTrue(try XCTUnwrap(legacy["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(request.contextRecordIDs.contains(historicalPrinciple.id.uuidString))
        XCTAssertEqual(store.referencedPrinciples.map(\.id), [historicalPrinciple.id])

        store.navigateTodayLoop(to: .reviewCards)
        XCTAssertTrue(store.referencedPrinciples.isEmpty)
    }

    func testSelectLens_generateQuestionsUsesVerifiedLensFeedbackFromHistory() async throws {
        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        let yesterday = DailyEntryDraft(
            rawText: "昨天用判断校准确认接口验收方式。",
            selectedLens: .judgmentCalibration,
            state: .sessionComplete
        )
        let question = ReflectionQuestion(
            question: "书面验收是否比口头确认更能减少返工？",
            whyItMatters: "这是可验证的判断。",
            evidenceGapType: .missingCalibrationSignal,
            answerUse: .watchCalibrationSignal,
            lensMove: .predictionCalibration,
            sourceCardTitles: ["接口验收不清"],
            calibrationTarget: "书面验收减少接口返工",
            answer: "明天先让负责人书面确认验收标准。"
        )
        let verification = Verification(
            questId: UUID(),
            questTitle: "让负责人书面确认验收标准",
            sourceDailyEntryId: yesterday.id,
            completion: .done,
            valueRating: .high,
            calibrationNote: "原判断是书面验收会减少返工；实际证据显示负责人确认后返工减少。",
            likelyIssue: nil,
            recommendation: "继续要求任务先声明可观察校准信号。"
        )
        store.historyRecords = [
            HistoryRecord(
                draft: yesterday,
                verification: verification,
                lensSession: LensSession(
                    dailyEntryId: yesterday.id,
                    selectedLens: .judgmentCalibration,
                    questions: [question]
                )
            )
        ]

        try await advanceTo(.selectLens)
        var card = ThinkingCard(
            type: .problem,
            title: "接口归属仍然容易反复",
            body: "今天又出现负责人和验收标准没有提前写清。"
        )
        card.isConfirmed = true
        store.thinkingCards = [card]

        store.selectThinkingLens(.judgmentCalibration)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuestions })
        let feedback = try XCTUnwrap(request.contextPayload?.lensFeedback.first)
        XCTAssertEqual(feedback.lensId, ThinkingLens.judgmentCalibration.rawValue)
        XCTAssertEqual(feedback.signal, "reinforce")
        XCTAssertEqual(feedback.completion, YesterdayCompletion.done.rawValue)
        XCTAssertEqual(feedback.valueRating, YesterdayValueRating.high.rawValue)
        XCTAssertEqual(feedback.questionTargets, ["书面验收减少接口返工"])
        XCTAssertEqual(feedback.evidenceGapTypes, [EvidenceGapType.missingCalibrationSignal.rawValue])
        XCTAssertEqual(feedback.lensMoves, [QuestionLensMove.predictionCalibration.rawValue])
    }

    func testSelectLens_generateQuestionsUsesSingleRecallFeedbackToDemoteReferencesBeforeReviewThreshold() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let principleRepo = SQLitePrincipleRepository(database: database)
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let penalizedPrinciple = PrincipleAsset(
            title: "Meeting ownership escalation",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        let unchallengedPrinciple = PrincipleAsset(
            title: "Meeting ownership alignment",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await principleRepo.savePrinciple(penalizedPrinciple, sourceDailyEntryId: UUID())
        try await principleRepo.savePrinciple(unchallengedPrinciple, sourceDailyEntryId: UUID())
        try await feedbackRepo.saveFeedback(
            PrincipleRecallFeedback(
                principleId: penalizedPrinciple.id,
                promptId: .generateQuestions,
                retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                retrievalReason: "Earlier recall was too broad.",
                feedback: .misrecalled,
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            principleRepository: principleRepo,
            principleRecallFeedbackRepository: feedbackRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.selectLens)
        var card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "No owner was named."
        )
        card.isConfirmed = true
        store.thinkingCards = [card]

        store.selectThinkingLens(.evidenceCheck)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let request = try XCTUnwrap(client.requests.first { $0.prompt.id == .generateQuestions })
        XCTAssertEqual(
            request.contextPayload?.principles.map(\.id),
            [unchallengedPrinciple.id.uuidString, penalizedPrinciple.id.uuidString]
        )
        XCTAssertEqual(store.referencedPrinciples.map(\.id), [unchallengedPrinciple.id, penalizedPrinciple.id])
        let storedPrinciples = try await principleRepo.activePrinciples()
        XCTAssertTrue(storedPrinciples.contains(where: { $0.id == penalizedPrinciple.id }))
    }

    func testReferencedPrincipleFeedback_persistsRecallMetadataAndRemovesRejectedReference() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let principleRepo = SQLitePrincipleRepository(database: database)
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let recalledPrinciple = PrincipleAsset(
            title: "Meeting ownership alignment",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await principleRepo.savePrinciple(recalledPrinciple, sourceDailyEntryId: UUID())

        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            principleRepository: principleRepo,
            principleRecallFeedbackRepository: feedbackRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.selectLens)
        var card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "No owner was named."
        )
        card.isConfirmed = true
        store.thinkingCards = [card]

        store.selectThinkingLens(.evidenceCheck)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        XCTAssertEqual(store.referencedPrinciples.map(\.id), [recalledPrinciple.id])

        await store.recordReferencedPrincipleFeedback(
            for: recalledPrinciple.id,
            feedback: .notApplicable,
            note: "这个场景不是会议"
        )

        let savedFeedback = try await feedbackRepo.feedback(for: recalledPrinciple.id, limit: 5)
        XCTAssertEqual(savedFeedback.map(\.feedback), [.notApplicable])
        XCTAssertEqual(savedFeedback.first?.sourceDailyEntryId, store.todayDraft.id)
        XCTAssertEqual(savedFeedback.first?.promptId, .generateQuestions)
        XCTAssertEqual(savedFeedback.first?.retrievalPolicyVersion, LocalPrincipleRetriever.policyVersion)
        XCTAssertTrue(savedFeedback.first?.retrievalReason.contains("Meeting ownership alignment") == true)
        XCTAssertEqual(savedFeedback.first?.retrievalSignal, "meeting ownership")
        XCTAssertEqual(savedFeedback.first?.note, "这个场景不是会议")
        XCTAssertTrue(store.referencedPrinciples.isEmpty)
    }

    func testReferencedPrincipleFeedback_marksLinkedPromptRunDeniedForRejectedRecall() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let principleRepo = SQLitePrincipleRepository(database: database)
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let recalledPrinciple = PrincipleAsset(
            title: "Meeting ownership alignment",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await principleRepo.savePrinciple(recalledPrinciple, sourceDailyEntryId: UUID())

        let client = RecordingLLMClient(response: Self.questionsResponse)
        store = AppStore(
            principleRepository: principleRepo,
            promptRunRepository: promptRunRepo,
            principleRecallFeedbackRepository: feedbackRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.selectLens)
        var card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "No owner was named."
        )
        card.isConfirmed = true
        store.thinkingCards = [card]

        store.selectThinkingLens(.evidenceCheck)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)

        let promptRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [store.todayDraft.id.uuidString],
            requestSummary: "question generation with recalled principle",
            responseJSON: #"{"questions":[{"question":"What owner evidence is missing?"}]}"#,
            createdAt: Date(timeIntervalSince1970: 300)
        )
        try await promptRunRepo.savePromptRun(promptRun)

        await store.recordReferencedPrincipleFeedback(
            for: recalledPrinciple.id,
            feedback: .misrecalled
        )

        let savedFeedback = try await feedbackRepo.feedback(for: recalledPrinciple.id, limit: 5)
        XCTAssertEqual(savedFeedback.first?.promptRunId, promptRun.id)

        await store.loadRecentPromptRuns(limit: 5)

        XCTAssertEqual(store.promptRunStats?.userDeniedCount, 1)
        let quality = try XCTUnwrap(store.promptAssetRunQualitySummaries.first {
            $0.promptId == PromptID.generateQuestions.rawValue
        })
        XCTAssertEqual(quality.userDeniedCount, 1)
        XCTAssertEqual(quality.userDenialRate, 1, accuracy: 0.001)
    }

    func testLoadPersistedState_marksRepeatedNegativeRecallFeedbackNeedsReview() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let draft = DailyEntryDraft(rawText: "Review stale recall policy", state: .capture)
        let principle = PrincipleAsset(
            title: "Meeting owner rule",
            summary: "Clarify ownership before execution.",
            triggerContext: "Meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await dailyRepo.saveDraft(draft)
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: draft.id)
        try await feedbackRepo.saveFeedback(
            PrincipleRecallFeedback(
                principleId: principle.id,
                promptId: .generateQuestions,
                retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                retrievalReason: "Owner keyword matched but did not apply.",
                feedback: .notApplicable,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await feedbackRepo.saveFeedback(
            PrincipleRecallFeedback(
                principleId: principle.id,
                promptId: .generateQuests,
                retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                retrievalReason: "Owner keyword was a false positive.",
                feedback: .misrecalled,
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            principleRecallFeedbackRepository: feedbackRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPersistedState()

        let activePrinciples = try await principleRepo.activePrinciples()
        let storedPrinciples = try await principleRepo.principles(for: draft.id)
        XCTAssertTrue(activePrinciples.isEmpty)
        XCTAssertTrue(store.activePrinciples.isEmpty)
        XCTAssertEqual(storedPrinciples.first?.status, .needsReview)
    }

    func testLoadPersistedState_surfacesLatestNegativeRecallFeedbackInTrainingSummary() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let draft = DailyEntryDraft(rawText: "Review stale recall audit", state: .capture)
        let principle = PrincipleAsset(
            title: "Meeting owner rule",
            summary: "Clarify ownership before execution.",
            triggerContext: "Meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        let latest = PrincipleRecallFeedback(
            principleId: principle.id,
            promptId: .generateQuests,
            retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
            retrievalReason: "Owner keyword was a false positive.",
            feedback: .misrecalled,
            note: "This meeting had no action owner.",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        try await dailyRepo.saveDraft(draft)
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: draft.id)
        try await feedbackRepo.saveFeedback(
            PrincipleRecallFeedback(
                principleId: principle.id,
                promptId: .generateQuestions,
                retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                retrievalReason: "Owner keyword matched but did not apply.",
                feedback: .notApplicable,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await feedbackRepo.saveFeedback(latest)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            principleRecallFeedbackRepository: feedbackRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPersistedState()

        let summary = try XCTUnwrap(store.principleTrainingSummaries.first)
        XCTAssertEqual(summary.principle.id, principle.id)
        XCTAssertEqual(summary.state, .needsReview)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackId, latest.id)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackValue, .misrecalled)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackReason, "Owner keyword was a false positive.")
        XCTAssertEqual(summary.latestNegativeRecallFeedbackNote, "This meeting had no action owner.")
    }

    // MARK: - AnswerQuestions -> ReviewQuests (async)

    func testAnswerQuestions_noAnsweredQuestions_blocksProgression() async throws {
        try await advanceTo(.answerQuestions)
        store.questions = [
            ReflectionQuestion(question: "Q?", whyItMatters: "Matters")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
    }

    func testAnswerQuestions_withGapClosingAnswer_generatesQuests() async throws {
        try await advanceTo(.answerQuestions)
        store.questions = [
            ReflectionQuestion(
                question: "Q?",
                whyItMatters: "Matters",
                calibrationTarget: "验收标准明确会减少返工",
                answer: "事实是今天已经确认关键证据。"
            )
        ]
        store.submitTodayStep()
        try await waitForState(.reviewQuests)
    }

    func testAnswerQuestions_answerWithoutCalibrationTargetBlocksQuestGeneration() async throws {
        let client = SequencedLLMClient(results: [
            .success(Self.questsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.answerQuestions)
        store.questions = [
            ReflectionQuestion(
                question: "Q?",
                whyItMatters: "Matters",
                answer: "事实是今天已经确认关键证据。"
            )
        ]

        store.submitTodayStep()

        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertTrue(store.todayLoopMessage.contains("待验证判断"))
        XCTAssertFalse(client.requests.contains { $0.prompt.id == .generateQuests })
    }

    // MARK: - ReviewQuests -> ExtractPrinciple (async)

    func testReviewQuests_noMainQuest_blocksProgression() async throws {
        try await advanceTo(.reviewQuests)
        store.quests = [
            Quest(type: .side, title: "Side only", whyItMatters: "Matters",
                  completionCriteria: "Done", expectedResistance: "None",
                  reflectionQuestion: "What?")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .reviewQuests)
    }

    func testReviewQuests_mainQuestWithoutCriteria_blocksProgression() async throws {
        try await advanceTo(.reviewQuests)
        store.quests = [
            Quest(type: .main, title: "Main", whyItMatters: "Matters",
                  completionCriteria: "   ", expectedResistance: "None",
                  reflectionQuestion: "What?")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .reviewQuests)
    }

    func testEditQuest_updatesQuestAndClearsPrincipleCandidate() async throws {
        try await advanceTo(.reviewQuests)
        let quest = Quest(type: .main, title: "Original quest", whyItMatters: "Old why",
                          completionCriteria: "Old criteria", expectedResistance: "Old resistance",
                          reflectionQuestion: "Old question")
        store.quests = [quest]
        store.principles = [PrincipleAsset(title: "P", summary: "S", triggerContext: "T",
                                            actions: ["A"], successCriteria: "SC",
                                            exceptions: "E")]

        store.updateQuest(
            quest.id,
            title: "Edited quest",
            whyItMatters: "New why",
            completionCriteria: "New criteria",
            expectedResistance: "New resistance",
            reflectionQuestion: "New question"
        )

        XCTAssertEqual(store.quests.first?.title, "Edited quest")
        XCTAssertEqual(store.quests.first?.completionCriteria, "New criteria")
        XCTAssertTrue(store.principles.isEmpty)
    }

    func testReviewQuests_validMainQuest_generatesPrinciple() async throws {
        try await advanceTo(.reviewQuests)
        store.quests = [
            Quest(type: .main, title: "Valid quest", whyItMatters: "Matters",
                  completionCriteria: "Done when verified", expectedResistance: "None",
                  reflectionQuestion: "What changed?")
        ]
        store.submitTodayStep()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(store.todayDraft.state, .extractPrinciple)
    }

    func testReviewQuests_validMainQuestSchedulesTomorrowReminder() async throws {
        let reminder = RecordingReminderService(permission: .authorized)
        store = AppStore(
            reminderService: reminder,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewQuests)
        store.quests = [
            Quest(type: .main, title: "Confirm meeting owner", whyItMatters: "Matters",
                  completionCriteria: "Owner confirmed in writing", expectedResistance: "None",
                  reflectionQuestion: "What changed?")
        ]

        store.submitTodayStep()

        try await waitUntil(
            reminder.scheduledRequests.count == 1,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected one scheduled reminder"
        ) {
            reminder.scheduledRequests.count == 1
        }
        let request = try XCTUnwrap(reminder.scheduledRequests.first)
        XCTAssertEqual(reminder.permissionRequestCount, 1)
        XCTAssertEqual(request.title, "明日验证行动")
        XCTAssertEqual(request.body, "Confirm meeting owner")
        XCTAssertTrue(store.reminderStatusMessage.contains("提醒已安排"))
    }

    func testQuestTrainingTarget_matchesActivePrincipleActionSignal() throws {
        let principle = PrincipleAsset(
            title: "会前确认负责人",
            summary: "协作任务开始前先确认唯一负责人和验收标准。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人", "写出验收标准"],
            successCriteria: "相关人知道下一步由谁推进。",
            exceptions: "",
            status: .active
        )
        let quest = Quest(
            type: .main,
            title: "明天写出负责人并确认验收标准",
            whyItMatters: "减少会议后返工。",
            completionCriteria: "负责人和验收标准都被写入记录。",
            expectedResistance: "可能只口头同步。",
            reflectionQuestion: "负责人确认后，返工是否减少？"
        )
        let trainingStore = AppStore(
            quests: [quest],
            principles: [principle],
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )

        let target = try XCTUnwrap(trainingStore.questTrainingTarget(for: quest.id))
        XCTAssertEqual(target.principleId, principle.id)
        XCTAssertEqual(target.principleTitle, "会前确认负责人")
        XCTAssertEqual(target.matchSignal, "写出负责人")
    }

    func testQuestTrainingTarget_ignoresNeedsReviewPrinciple() {
        let principle = PrincipleAsset(
            title: "会前确认负责人",
            summary: "协作任务开始前先确认唯一负责人和验收标准。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人"],
            successCriteria: "相关人知道下一步由谁推进。",
            exceptions: "",
            status: .needsReview
        )
        let quest = Quest(
            type: .main,
            title: "明天写出负责人",
            whyItMatters: "减少会议后返工。",
            completionCriteria: "负责人被写入记录。",
            expectedResistance: "可能只口头同步。",
            reflectionQuestion: "负责人确认后，返工是否减少？"
        )
        let trainingStore = AppStore(
            quests: [quest],
            principles: [principle],
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )

        XCTAssertNil(trainingStore.questTrainingTarget(for: quest.id))
    }

    func testQuestTrainingTarget_usesSelectedTrainingPrincipleBeforeAutomaticMatch() throws {
        let selected = PrincipleAsset(
            title: "先写验收标准",
            summary: "先把验收标准写成可检查证据。",
            triggerContext: "acceptance contract",
            actions: ["写出验收标准"],
            successCriteria: "完成时能直接检查。",
            exceptions: "",
            status: .active
        )
        let automatic = PrincipleAsset(
            title: "会前确认负责人",
            summary: "协作任务开始前先确认唯一负责人。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人"],
            successCriteria: "相关人知道下一步由谁推进。",
            exceptions: "",
            status: .active
        )
        let quest = Quest(
            type: .main,
            title: "明天写出负责人",
            whyItMatters: "减少会议后返工。",
            completionCriteria: "负责人被写入记录。",
            expectedResistance: "可能只口头同步。",
            reflectionQuestion: "负责人确认后，返工是否减少？",
            trainingPrincipleId: selected.id
        )
        let trainingStore = AppStore(
            quests: [quest],
            principles: [selected, automatic],
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )

        let target = try XCTUnwrap(trainingStore.questTrainingTarget(for: quest.id))
        XCTAssertEqual(target.principleId, selected.id)
        XCTAssertEqual(target.principleTitle, "先写验收标准")
        XCTAssertEqual(target.matchSignal, "用户选择")
    }

    func testUpdateQuestTrainingPrinciple_onlyAcceptsActivePrincipleAndCanClearSelection() throws {
        let active = PrincipleAsset(
            title: "先写验收标准",
            summary: "先把验收标准写成可检查证据。",
            triggerContext: "acceptance contract",
            actions: ["写出验收标准"],
            successCriteria: "完成时能直接检查。",
            exceptions: "",
            status: .active
        )
        let needsReview = PrincipleAsset(
            title: "旧的会议习惯",
            summary: "这条原则需要复核后才能训练。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人"],
            successCriteria: "相关人知道下一步由谁推进。",
            exceptions: "",
            status: .needsReview
        )
        let quest = Quest(
            type: .main,
            title: "明天写出验收标准",
            whyItMatters: "减少返工。",
            completionCriteria: "验收标准被写入记录。",
            expectedResistance: "可能只写行动。",
            reflectionQuestion: "标准是否让完成更清楚？"
        )
        let trainingStore = AppStore(
            quests: [quest],
            principles: [active, needsReview],
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )

        XCTAssertFalse(trainingStore.updateQuestTrainingPrinciple(needsReview.id, for: quest.id))
        XCTAssertNil(trainingStore.quests.first?.trainingPrincipleId)

        XCTAssertTrue(trainingStore.updateQuestTrainingPrinciple(active.id, for: quest.id))
        XCTAssertEqual(trainingStore.quests.first?.trainingPrincipleId, active.id)

        XCTAssertTrue(trainingStore.updateQuestTrainingPrinciple(nil, for: quest.id))
        XCTAssertNil(trainingStore.quests.first?.trainingPrincipleId)
    }

    func testVerifyYesterday_recordsPracticeEvidenceForSelectedTrainingPrincipleBeforeAutomaticMatch() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let practiceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)

        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            rawText: "昨天做了会议任务，但我希望训练的是验收标准。",
            state: .sessionComplete
        )
        try await dailyRepo.saveDraft(yesterday)
        let today = DailyEntryDraft(rawText: "今天确认任务已经完成。", state: .verifyYesterday)
        try await dailyRepo.saveDraft(today)

        let selected = PrincipleAsset(
            title: "先写验收标准",
            summary: "先把验收标准写成可检查证据。",
            triggerContext: "acceptance contract",
            actions: ["写出验收标准"],
            successCriteria: "完成时能直接检查。",
            exceptions: "",
            status: .active
        )
        let automatic = PrincipleAsset(
            title: "会前确认负责人",
            summary: "推进前先确认唯一负责人。",
            triggerContext: "跨团队会议",
            actions: ["写出负责人"],
            successCriteria: "会后没有职责空白。",
            exceptions: "低风险同步可简化。",
            status: .active
        )
        try await principleRepo.savePrinciple(selected, sourceDailyEntryId: yesterday.id)
        try await principleRepo.savePrinciple(automatic, sourceDailyEntryId: yesterday.id)

        let quest = Quest(
            type: .main,
            title: "会前写出负责人",
            whyItMatters: "避免会议后没有责任人。",
            completionCriteria: "负责人已经写在会议记录。",
            expectedResistance: "临时讨论太快。",
            reflectionQuestion: "是否真的减少了职责空白？",
            trainingPrincipleId: selected.id,
            status: .active
        )
        try await questRepo.saveQuest(quest, sourceDailyEntryId: yesterday.id)

        let verifyingStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )
        await verifyingStore.loadPersistedState()

        verifyingStore.selectYesterdayCompletion(.done)
        verifyingStore.selectYesterdayValueRating(.high)
        verifyingStore.selectYesterdayJudgmentUpdate(.confirmed)
        verifyingStore.submitTodayStep()
        try await waitUntil(
            verifyingStore.todayDraft.state == .capture,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected verification flow to advance to capture"
        ) {
            verifyingStore.todayDraft.state == .capture
        }

        let selectedEvidence = try await practiceRepo.evidence(for: selected.id, limit: 10)
        let automaticEvidence = try await practiceRepo.evidence(for: automatic.id, limit: 10)

        XCTAssertEqual(selectedEvidence.count, 1)
        XCTAssertEqual(selectedEvidence.first?.matchSignal, "用户选择")
        XCTAssertEqual(selectedEvidence.first?.practiceRole, .targetedPractice)
        XCTAssertTrue(selectedEvidence.first?.evidenceSummary.contains("用户选择") == true)
        XCTAssertTrue(automaticEvidence.isEmpty)
    }

    func testReviewQuests_duplicateSaveDoesNotScheduleDuplicateReminder() async throws {
        let reminder = RecordingReminderService(permission: .authorized)
        store = AppStore(
            reminderService: reminder,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewQuests)
        let quest = Quest(type: .main, title: "Confirm owner", whyItMatters: "Matters",
                          completionCriteria: "Owner confirmed", expectedResistance: "None",
                          reflectionQuestion: "What changed?")
        store.quests = [quest]

        store.submitTodayStep()
        try await waitUntil(
            reminder.scheduledRequests.count == 1,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected first reminder"
        ) {
            reminder.scheduledRequests.count == 1
        }

        store.todayDraft.state = .reviewQuests
        store.quests = [quest]
        store.submitTodayStep()
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(reminder.permissionRequestCount, 1)
        XCTAssertEqual(reminder.scheduledRequests.count, 1)
    }

    func testReviewQuests_permissionDeniedDoesNotBlockLoop() async throws {
        let reminder = RecordingReminderService(permission: .denied)
        store = AppStore(
            reminderService: reminder,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: MockLLMClient()
            ),
            refreshesAIServiceFromKeychain: false
        )
        try await advanceTo(.reviewQuests)
        store.quests = [
            Quest(type: .main, title: "Confirm owner", whyItMatters: "Matters",
                  completionCriteria: "Owner confirmed", expectedResistance: "None",
                  reflectionQuestion: "What changed?")
        ]

        store.submitTodayStep()

        try await waitUntil(
            store.reminderStatusMessage.contains("通知权限未开启"),
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected denied permission status"
        ) {
            store.reminderStatusMessage.contains("通知权限未开启")
        }
        XCTAssertEqual(reminder.permissionRequestCount, 1)
        XCTAssertTrue(reminder.scheduledRequests.isEmpty)
        XCTAssertNotEqual(store.todayDraft.state, .reviewQuests)
    }

    // MARK: - ExtractPrinciple -> SessionComplete

    func testExtractPrinciple_savePrinciple_advancesToSessionComplete() async throws {
        try await advanceTo(.extractPrinciple)
        store.principles = [
            PrincipleAsset(title: "Test principle", summary: "Summary",
                          triggerContext: "Context", actions: ["Act"],
                          successCriteria: "Criteria", exceptions: "None")
        ]
        store.submitTodayStep()
        try await waitForState(.sessionComplete)
    }

    func testEditPrinciple_updatesCandidateBeforeSave() async throws {
        try await advanceTo(.extractPrinciple)
        let principle = PrincipleAsset(title: "Original", summary: "Summary",
                                       triggerContext: "Context", actions: ["A"],
                                       successCriteria: "Criteria", exceptions: "Exceptions")
        store.principles = [principle]

        store.updatePrinciple(
            principle.id,
            title: "Edited principle",
            summary: "Edited summary",
            triggerContext: "Edited context",
            actionsText: "First action\nSecond action",
            successCriteria: "Edited criteria",
            exceptions: "Edited exceptions"
        )

        XCTAssertEqual(store.principles.first?.title, "Edited principle")
        XCTAssertEqual(store.principles.first?.actions, ["First action", "Second action"])
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
    }

    func testExtractPrinciple_skipPrinciple_advancesToSessionComplete() async throws {
        try await advanceTo(.extractPrinciple)
        store.principles = [
            PrincipleAsset(title: "Test", summary: "S", triggerContext: "C",
                          actions: ["A"], successCriteria: "SC", exceptions: "E")
        ]
        store.skipPrinciple()
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
        XCTAssertTrue(store.principles.isEmpty)
    }

    // MARK: - SessionComplete -> Reset

    func testSessionComplete_submit_resetsToInitialState() async throws {
        try await advanceTo(.sessionComplete)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertTrue(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertTrue(store.principles.isEmpty)
    }

    // MARK: - Reset

    func testResetTodayLoop_resetsAllState() {
        store.selectYesterdayCompletion(.partial)
        store.selectYesterdayValueRating(.medium)
        store.todayDraft.rawText = "Some text"
        store.selectTodayMode(.deep)
        store.selectThinkingLens(.opposingView)
        store.thinkingCards = [ThinkingCard(type: .fact, title: "Test", body: "Body")]
        store.questions = [ReflectionQuestion(question: "Q?", whyItMatters: "M")]
        store.quests = [Quest(type: .main, title: "Quest", whyItMatters: "W",
                              completionCriteria: "C", expectedResistance: "E",
                              reflectionQuestion: "R")]
        store.principles = [PrincipleAsset(title: "P", summary: "S", triggerContext: "T",
                                            actions: ["A"], successCriteria: "SC",
                                            exceptions: "E")]

        store.resetTodayLoop()

        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertTrue(store.todayDraft.rawText.isEmpty)
        XCTAssertTrue(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertTrue(store.principles.isEmpty)
    }

    // MARK: - Properties

    func testMainQuest_returnsFirstMainQuest() {
        store.quests = [
            Quest(type: .side, title: "Side", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R"),
            Quest(type: .main, title: "Main", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R")
        ]
        XCTAssertEqual(store.mainQuest?.title, "Main")
    }

    func testMainQuest_nilWhenNoMainQuest() {
        store.quests = [
            Quest(type: .side, title: "Side", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R")
        ]
        XCTAssertNil(store.mainQuest)
    }

    func testHasAnsweredReflectionQuestion_trueWhenAnswered() {
        store.questions = [
            ReflectionQuestion(question: "Q?", whyItMatters: "M", answer: "A")
        ]
        XCTAssertTrue(store.hasAnsweredReflectionQuestion)
    }

    func testHasAnsweredReflectionQuestion_falseWhenEmpty() {
        store.questions = [
            ReflectionQuestion(question: "Q?", whyItMatters: "M", answer: "")
        ]
        XCTAssertFalse(store.hasAnsweredReflectionQuestion)
    }

    func testHasAnsweredReflectionQuestion_falseWhenWhitespace() {
        store.questions = [
            ReflectionQuestion(question: "Q?", whyItMatters: "M", answer: "   ")
        ]
        XCTAssertFalse(store.hasAnsweredReflectionQuestion)
    }

    // MARK: - Full Loop Integration

    func testFullLoop_canCompleteWithLocalFallback() async throws {
        // verifyYesterday -> capture
        store.selectYesterdayCompletion(.done)
        store.selectYesterdayValueRating(.high)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .capture)

        // capture -> organizing (async card generation)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("Had a productive meeting about the project roadmap.")
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .organizing)
        try await waitForGeneratedCards()

        // organizing -> reviewCards
        store.submitTodayStep()
        try await waitForState(.reviewCards)

        // reviewCards -> selectLens
        store.thinkingCards = store.thinkingCards.map { card in
            var c = card; c.isConfirmed = true; return c
        }
        store.submitTodayStep()
        try await waitForState(.selectLens)

        // selectLens -> answerQuestions (async question generation)
        store.selectThinkingLens(.leverageAnalysis)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)
        try await waitForGeneratedQuestions()

        // answerQuestions -> reviewQuests (async quest generation)
        store.questions = store.questions.map { q in
            var question = q; question.answer = "事实是今天已经确认关键证据，验收标准是负责人和下一步在文档中写清。"; return question
        }
        store.submitTodayStep()
        try await waitForState(.reviewQuests)

        // reviewQuests -> extractPrinciple (async principle generation)
        var quest = Quest(type: .main, title: "Confirm ownership",
                          whyItMatters: "Reduces rework", completionCriteria: "Owner confirmed",
                          expectedResistance: "Cross-role discussion", reflectionQuestion: "What changed?")
        quest.status = .active
        store.quests = [quest]
        store.submitTodayStep()
        try await waitForState(.extractPrinciple)

        // extractPrinciple -> sessionComplete
        store.submitTodayStep()
        try await waitForState(.sessionComplete)
    }

    func testProductionTodayCompletion_persistsHistoryEvidenceThroughSQLiteReload() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let lensRepo = SQLiteLensSessionRepository(database: database)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            thinkingCardRepository: cardRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            lensSessionRepository: lensRepo,
            refreshesAIServiceFromKeychain: false
        )

        let rawInput = "今天要把生产完成路径归档到历史证据里，确认明天可以复盘。"

        store.selectYesterdayCompletion(.done)
        store.selectYesterdayValueRating(.high)
        store.submitTodayStep()
        try await waitForState(.capture)

        store.selectTodayMode(.standard)
        store.updateTodayCapture(rawInput)
        store.submitTodayStep()
        try await waitForGeneratedCards()

        store.submitTodayStep()
        try await waitForState(.reviewCards)

        for card in store.thinkingCards {
            store.confirmCard(card.id)
        }
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.selectThinkingLens(.firstPrinciples)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)
        try await waitForGeneratedQuestions()

        let questionID = try XCTUnwrap(store.questions.first?.id)
        store.updateQuestionAnswer(
            questionID: questionID,
            answer: "事实是今天要验证最小闭环是否写进历史证据，验收标准是历史记录能看到主任务和原则。"
        )
        store.submitTodayStep()
        try await waitForState(.reviewQuests)

        store.submitTodayStep()
        try await waitForState(.extractPrinciple)

        store.submitTodayStep()
        try await waitForState(.sessionComplete)

        let completedEntryID = store.todayDraft.id
        let reloadedStore = AppStore(
            dailyEntryRepository: dailyRepo,
            thinkingCardRepository: cardRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            lensSessionRepository: lensRepo,
            refreshesAIServiceFromKeychain: false
        )

        try await waitUntilAsync(
            timeout: 5,
            file: #filePath,
            line: #line,
            failureMessage: "Expected completed Today evidence to reload from SQLite into History"
        ) {
            await reloadedStore.loadHistoryRecords()
            guard let record = reloadedStore.historyRecords.first(where: { $0.draft.id == completedEntryID }) else {
                return false
            }

            return record.draft.rawText == rawInput &&
                record.draft.state == .sessionComplete &&
                record.confirmedCards.count == 3 &&
                record.confirmedCards.allSatisfy(\.isConfirmed) &&
                record.lensSession?.selectedLens == .firstPrinciples &&
                record.lensSession?.questions.contains {
                    !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                } == true &&
                record.mainQuest != nil &&
                !record.principles.isEmpty &&
                record.sourceIds.contains(completedEntryID.uuidString)
        }

        let record = try XCTUnwrap(reloadedStore.historyRecords.first { $0.draft.id == completedEntryID })
        XCTAssertEqual(record.draft.rawText, rawInput)
        XCTAssertEqual(record.draft.state, .sessionComplete)
        XCTAssertEqual(record.confirmedCards.count, 3)
        XCTAssertTrue(record.confirmedCards.allSatisfy(\.isConfirmed))
        XCTAssertEqual(record.lensSession?.selectedLens, .firstPrinciples)
        XCTAssertTrue(record.lensSession?.questions.contains { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } == true)
        XCTAssertNotNil(record.mainQuest)
        XCTAssertFalse(record.principles.isEmpty)
        XCTAssertTrue(record.sourceIds.contains(completedEntryID.uuidString))
    }

    func testCompletingRestoredPriorDayDraft_keepsHistoryDateOnOriginalDraftDate() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let lensRepo = SQLiteLensSessionRepository(database: database)
        let priorDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let unfinished = DailyEntryDraft(
            date: priorDate,
            rawText: "昨晚已经写到追问阶段，今天只是在补完整个闭环。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .evidenceCheck,
            state: .answerQuestions
        )
        let confirmedCard = ThinkingCard(
            type: .fact,
            title: "昨晚已经开始",
            body: "草稿创建于昨天，今天只是继续完成。",
            priority: .medium,
            isConfirmed: true
        )
        let question = ReflectionQuestion(
            question: "这个闭环应该归属哪一天？",
            whyItMatters: "补完不能改写原始记录日期。",
            calibrationTarget: "补完历史草稿不会改写原始记录日期",
            answer: "事实是草稿创建于昨天，验收标准是历史记录日期仍归属创建草稿的那一天。"
        )
        try await dailyRepo.saveDraft(unfinished)
        try await cardRepo.saveCards([confirmedCard], dailyEntryId: unfinished.id)
        try await lensRepo.saveLensSession(
            LensSession(
                dailyEntryId: unfinished.id,
                selectedLens: .evidenceCheck,
                questions: [question]
            )
        )

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            thinkingCardRepository: cardRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            lensSessionRepository: lensRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPersistedState()
        XCTAssertEqual(store.todayDraft.id, unfinished.id)
        XCTAssertTrue(Calendar.current.isDate(store.todayDraft.date, inSameDayAs: priorDate))

        store.submitTodayStep()
        try await waitForState(.reviewQuests)
        store.submitTodayStep()
        try await waitForState(.extractPrinciple)
        store.submitTodayStep()
        try await waitForState(.sessionComplete)
        try await waitUntilAsync(
            timeout: 5,
            file: #filePath,
            line: #line,
            failureMessage: "Expected restored prior-day draft completion to persist on original date"
        ) {
            await store.loadHistoryRecords()
            guard let record = store.historyRecords.first(where: { $0.draft.id == unfinished.id }) else {
                return false
            }

            return record.draft.state == .sessionComplete &&
                Calendar.current.isDate(record.draft.date, inSameDayAs: priorDate) &&
                !Calendar.current.isDateInToday(record.draft.date)
        }

        let record = try XCTUnwrap(store.historyRecords.first { $0.draft.id == unfinished.id })
        XCTAssertEqual(record.draft.state, .sessionComplete)
        XCTAssertTrue(Calendar.current.isDate(record.draft.date, inSameDayAs: priorDate))
        XCTAssertFalse(Calendar.current.isDateInToday(record.draft.date))
    }

    func testProductionTodayEvidence_canBackProjectLinkAndGrowthContributionsThroughHistoryReload() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let lensRepo = SQLiteLensSessionRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        func seedVerifiedLoop(daysAgo: Int, title: String, completion: YesterdayCompletion, value: YesterdayValueRating) async throws {
            let entry = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
                rawText: "Historical verified loop \(daysAgo)",
                sessionMode: .standard,
                hasSelectedSessionMode: true,
                selectedLens: .evidenceCheck,
                state: .sessionComplete
            )
            try await dailyRepo.saveDraft(entry)

            let quest = Quest(
                type: .main,
                title: title,
                whyItMatters: "Historical evidence matters.",
                completionCriteria: "A visible result exists.",
                expectedResistance: "Interruptions",
                reflectionQuestion: "What changed?",
                status: completion == .done ? .completed : .failed
            )
            try await questRepo.saveQuest(quest, sourceDailyEntryId: entry.id)
            try await verificationRepo.saveVerification(
                Verification(
                    questId: quest.id,
                    questTitle: quest.title,
                    sourceDailyEntryId: entry.id,
                    completion: completion,
                    valueRating: value,
                    calibrationNote: "Historical calibration \(daysAgo)"
                )
            )
            try await lensRepo.saveLensSession(
                LensSession(
                    dailyEntryId: entry.id,
                    selectedLens: .evidenceCheck,
                    questions: [
                        ReflectionQuestion(
                            question: "What evidence supports this?",
                            whyItMatters: "It keeps Growth attribution evidence-backed.",
                            answer: "A concrete result was checked."
                        )
                    ]
                )
            )
        }

        try await seedVerifiedLoop(daysAgo: 2, title: "Verify historical quality gate", completion: .done, value: .high)
        try await seedVerifiedLoop(daysAgo: 1, title: "Reduce historical ambiguity", completion: .missed, value: .low)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            thinkingCardRepository: cardRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            lensSessionRepository: lensRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        let rawInput = "今天要把生产历史证据继续回链到长期议题和成长归因，而不是只停在历史列表里。"

        store.selectYesterdayCompletion(.done)
        store.selectYesterdayValueRating(.high)
        store.submitTodayStep()
        try await waitForState(.capture)

        store.selectTodayMode(.standard)
        store.updateTodayCapture(rawInput)
        store.submitTodayStep()
        try await waitForGeneratedCards()

        store.submitTodayStep()
        try await waitForState(.reviewCards)

        for card in store.thinkingCards {
            store.confirmCard(card.id)
        }
        store.submitTodayStep()
        try await waitForState(.selectLens)

        store.selectThinkingLens(.firstPrinciples)
        store.submitTodayStep()
        try await waitForState(.answerQuestions)
        try await waitForGeneratedQuestions()

        let questionID = try XCTUnwrap(store.questions.first?.id)
        store.updateQuestionAnswer(
            questionID: questionID,
            answer: "事实是证据链要指向真实任务、透镜和历史日期，验收标准是长期议题和成长归因能回链到这条历史记录。"
        )
        store.submitTodayStep()
        try await waitForState(.reviewQuests)

        store.submitTodayStep()
        try await waitForState(.extractPrinciple)

        store.submitTodayStep()
        try await waitForState(.sessionComplete)

        let completedEntryID = store.todayDraft.id

        try await waitUntilAsync(
            timeout: 5,
            file: #filePath,
            line: #line,
            failureMessage: "Expected local Growth attribution to include completed Today evidence"
        ) {
            guard let snapshot = try await snapshotRepo.latestSnapshot(),
                  snapshot.canDisplayScores,
                  snapshot.completeLoopCount >= 3
            else {
                return false
            }
            return try await contributionRepo.contributions(for: snapshot.id).contains { contribution in
                contribution.sourceDailyEntryId == completedEntryID &&
                    !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }

        let archiveStore = AppStore(
            dailyEntryRepository: dailyRepo,
            thinkingCardRepository: cardRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            lensSessionRepository: lensRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        await archiveStore.loadHistoryRecords()

        let completedRecord = try XCTUnwrap(archiveStore.historyRecords.first { $0.draft.id == completedEntryID })
        let quest = try XCTUnwrap(completedRecord.mainQuest)
        XCTAssertEqual(completedRecord.draft.rawText, rawInput)
        XCTAssertEqual(completedRecord.lensSession?.selectedLens, .firstPrinciples)
        XCTAssertFalse(completedRecord.growthContributions.isEmpty)
        XCTAssertTrue(completedRecord.growthContributions.allSatisfy { contribution in
            contribution.sourceDailyEntryId == completedEntryID &&
                !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })

        await archiveStore.createProjectFromQuest(quest, dailyEntryId: completedEntryID)

        let projects = try await projectRepo.activeProjects()
        let project = try XCTUnwrap(projects.first)
        let projectLinks = try await projectLinkRepo.links(for: project.id)
        XCTAssertEqual(projectLinks.map(\.sourceId), [quest.id.uuidString])
        XCTAssertEqual(projectLinks.first?.sourceType, .quest)
        XCTAssertEqual(projectLinks.first?.linkType, .task)
        XCTAssertTrue(projectLinks.first?.isUserConfirmed == true)

        let finalStore = AppStore(
            dailyEntryRepository: dailyRepo,
            thinkingCardRepository: cardRepo,
            questRepository: questRepo,
            principleRepository: principleRepo,
            verificationRepository: verificationRepo,
            lensSessionRepository: lensRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        await finalStore.loadHistoryRecords()

        let finalRecord = try XCTUnwrap(finalStore.historyRecords.first { $0.draft.id == completedEntryID })
        XCTAssertEqual(finalRecord.projectLinks.map(\.sourceId), [quest.id.uuidString])
        XCTAssertEqual(finalStore.projectNames[project.id], project.name)
        XCTAssertTrue(finalRecord.sourceIds.contains(quest.id.uuidString))
        XCTAssertTrue(finalRecord.growthContributions.contains { contribution in
            contribution.sourceDailyEntryId == completedEntryID &&
                finalRecord.sourceIds.contains(contribution.sourceId)
        })
    }

    // MARK: - AI failure repair

    func testAIFailure_usesVisibleFallbackAndCanRetrySameStep() async throws {
        let llmClient = SequencedLLMClient(results: [
            .failure(LLMClientError.httpStatus(500, Data("server down".utf8))),
            .success(Self.cardsResponse(title: "AI repaired card"))
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("Today I need to clarify one meeting decision.")
        store.submitTodayStep()

        try await waitForGeneratedCards()
        XCTAssertEqual(store.todayDraft.state, .organizing)
        XCTAssertEqual(store.pendingAIRepairCount, 1)
        XCTAssertTrue(store.canRetryCurrentAI)
        XCTAssertTrue(store.todayLoopMessage.contains("整理卡片训练未完成"))
        XCTAssertFalse(store.todayLoopMessage.contains("AI 整理卡片失败"))
        XCTAssertTrue(store.todayLoopMessage.contains("HTTP 500"))

        store.retryCurrentAIStep()

        try await waitUntil(
            store.pendingAIRepairCount == 0,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected retry to clear pending AI repair"
        ) {
            store.pendingAIRepairCount == 0
        }
        XCTAssertEqual(store.thinkingCards.first?.title, "AI repaired card")
        XCTAssertFalse(store.canRetryCurrentAI)
    }

    func testAIRetryFailure_keepsExistingFallbackWithoutIncreasingRepairCount() async throws {
        let llmClient = SequencedLLMClient(results: [
            .failure(LLMClientError.httpStatus(500, Data("first failure".utf8))),
            .failure(LLMClientError.httpStatus(502, Data("second failure".utf8)))
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("Today I need a fallback and retry path.")
        store.submitTodayStep()

        try await waitForGeneratedCards()
        let fallbackTitle = store.thinkingCards.first?.title
        XCTAssertEqual(store.pendingAIRepairCount, 1)

        store.retryCurrentAIStep()

        try await waitUntil(
            store.todayLoopMessage.contains("重试未完成"),
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected retry training failure message"
        ) {
            store.todayLoopMessage.contains("重试未完成")
        }
        XCTAssertEqual(store.pendingAIRepairCount, 1)
        XCTAssertEqual(store.thinkingCards.first?.title, fallbackTitle)
        XCTAssertTrue(store.canRetryCurrentAI)
    }

    func testAIRetryInProgressMessage_usesTrainingLanguage() async throws {
        let llmClient = SuspendingLLMClient(response: Self.cardsResponse(title: "Repaired card"))
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )
        store.todayDraft.state = .organizing
        store.todayDraft.rawText = "Today I need to retry card organization."
        store.canRetryCurrentAI = true

        store.retryCurrentAIStep()

        try await waitUntil(
            llmClient.completeCallCount == 1,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected retry to start one model request"
        ) {
            llmClient.completeCallCount == 1
        }
        XCTAssertTrue(store.todayLoopMessage.contains("正在重试整理卡片训练"))
        XCTAssertFalse(store.todayLoopMessage.contains("正在重试 AI"))

        llmClient.release()
    }

    func testPendingAIRepairInProgressMessage_usesTrainingLanguage() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let client = SuspendingLLMClient(response: Self.cardsResponse(title: "Background repaired card"))
        let draft = DailyEntryDraft(
            rawText: "Today I need background repair.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .organizing
        )
        try await dailyRepo.saveDraft(draft)
        try await promptRunRepo.savePromptRun(
            PromptRun(
                promptId: PromptID.organizeCards.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: [draft.id.uuidString],
                requestSummary: "organize failure",
                error: "HTTP 500"
            )
        )

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            promptRunRepository: promptRunRepo,
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: client
            ),
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPersistedState()

        XCTAssertEqual(store.pendingAIRepairCount, 1)
        store.retryPendingAIRepairs()

        try await waitUntil(
            client.completeCallCount == 1,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected background repair to start one model request"
        ) {
            client.completeCallCount == 1
        }
        XCTAssertTrue(store.todayLoopMessage.contains("正在后台补齐未完成训练"))
        XCTAssertFalse(store.todayLoopMessage.contains("正在后台重试 AI"))

        client.release()
    }

    func testQuestionQualityGateFailure_usesStructuredFallbackAndRetryMessage() async throws {
        let llmClient = SequencedLLMClient(results: [
            .success(Self.cardsResponse(title: "Meeting ownership unclear")),
            .success(Self.lowQualityQuestionsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("Today the meeting owner was still unclear after the discussion.")
        store.submitTodayStep()
        try await waitForGeneratedCards()
        store.submitTodayStep()
        try await waitForState(.reviewCards)
        for card in store.thinkingCards {
            store.confirmCard(card.id)
        }
        store.submitTodayStep()
        try await waitForState(.selectLens)
        store.selectThinkingLens(.judgmentCalibration)
        store.submitTodayStep()

        try await waitForState(.answerQuestions)
        XCTAssertEqual(store.pendingAIRepairCount, 1)
        XCTAssertTrue(store.canRetryCurrentAI)
        XCTAssertTrue(store.todayLoopMessage.contains("训练输出质量未达标"))
        XCTAssertFalse(store.todayLoopMessage.contains("AI 输出质量未达标"))
        XCTAssertTrue(store.todayLoopMessage.contains(PromptCoachingQualityIssueReason.genericQuestion.rawValue))

        let fallbackQuestion = try XCTUnwrap(store.questions.first)
        XCTAssertNotNil(fallbackQuestion.evidenceGapType)
        XCTAssertNotNil(fallbackQuestion.answerUse)
        XCTAssertNotNil(fallbackQuestion.lensMove)
        XCTAssertFalse(fallbackQuestion.sourceCardTitles.isEmpty)
        XCTAssertFalse((fallbackQuestion.calibrationTarget ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testQuestionQualityGateFailure_fallbackStartsFromCoachTeachingPlan() async throws {
        let llmClient = SequencedLLMClient(results: [
            .success(Self.cardsResponse(title: "Meeting ownership unclear")),
            .success(Self.lowQualityQuestionsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("Today the meeting owner was still unclear after the discussion.")
        store.submitTodayStep()
        try await waitForGeneratedCards()
        store.submitTodayStep()
        try await waitForState(.reviewCards)
        store.thinkingCards = coachPrescriptionEvidenceCards()
        store.submitTodayStep()
        try await waitForState(.selectLens)
        store.acceptTrainingPrescription()
        store.submitTodayStep()

        try await waitForState(.answerQuestions)

        let fallbackQuestion = try XCTUnwrap(store.questions.first)
        XCTAssertEqual(fallbackQuestion.evidenceGapType, .missingObservation)
        XCTAssertEqual(fallbackQuestion.answerUse, .collectEvidence)
        XCTAssertEqual(fallbackQuestion.lensMove, .factInterpretationSplit)
        XCTAssertTrue(fallbackQuestion.question.contains("可观察事实"))
        XCTAssertTrue(try XCTUnwrap(fallbackQuestion.whyNow).contains("本轮漏想点"))
        XCTAssertTrue(try XCTUnwrap(fallbackQuestion.expectedUpdate).contains("补上"))
        XCTAssertTrue(try XCTUnwrap(fallbackQuestion.proceedWhen).contains("可观察事实"))
        XCTAssertTrue(try XCTUnwrap(fallbackQuestion.calibrationTarget).contains("可观察事实"))
    }

    func testQuestQualityGateFailure_usesFallbackAndRetryMessage() async throws {
        let llmClient = SequencedLLMClient(results: [
            .success(Self.cardsResponse(title: "Meeting ownership unclear")),
            .success(Self.lowQualityQuestsResponse)
        ])
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.answerQuestions)
        store.questions = [
            ReflectionQuestion(
                question: "Which observable signal would prove ownership ambiguity is falling?",
                whyItMatters: "It turns a vague concern into a calibration check.",
                evidenceGapType: .missingCalibrationSignal,
                answerUse: .watchCalibrationSignal,
                lensMove: .predictionCalibration,
                sourceCardTitles: ["Confirmed"],
                calibrationTarget: "Written owner acknowledgement reduces meeting rework",
                answer: "实际结果信号是 owner 确认后追问次数是否下降；如果结果没有下降，就更新判断。"
            )
        ]
        store.submitTodayStep()

        try await waitForState(.reviewQuests)
        XCTAssertEqual(store.pendingAIRepairCount, 1)
        XCTAssertTrue(store.canRetryCurrentAI)
        XCTAssertTrue(store.todayLoopMessage.contains("训练输出质量未达标"))
        XCTAssertFalse(store.todayLoopMessage.contains("AI 输出质量未达标"))
        XCTAssertTrue(store.todayLoopMessage.contains(PromptCoachingQualityIssueReason.busyworkQuest.rawValue))

        let fallbackQuest = try XCTUnwrap(store.quests.first(where: { $0.type == .main }))
        XCTAssertEqual(fallbackQuest.calibrationTarget, "Written owner acknowledgement reduces meeting rework")
        XCTAssertTrue(fallbackQuest.completionCriteria.contains("可检查结果"))
    }

    func testAIGenerationBusyStateBlocksDuplicateRetryRequests() async throws {
        let llmClient = SuspendingLLMClient(response: Self.cardsResponse(title: "Slow AI card"))
        store = AppStore(
            todayAIService: TodayAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: llmClient
            ),
            refreshesAIServiceFromKeychain: false
        )

        try await advanceTo(.capture)
        store.selectTodayMode(.standard)
        store.updateTodayCapture("Today I need to avoid duplicate model calls.")
        store.submitTodayStep()

        try await waitUntil(
            store.isAIRunning,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected AI busy state while request is in flight"
        ) {
            store.isAIRunning
        }
        XCTAssertEqual(llmClient.completeCallCount, 1)

        store.retryCurrentAIStep()

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(llmClient.completeCallCount, 1)
        XCTAssertTrue(store.todayLoopMessage.contains("明思正在训练处理中"))
        XCTAssertFalse(store.todayLoopMessage.contains("AI 正在运行"))

        llmClient.release()
        try await waitForGeneratedCards()
        XCTAssertFalse(store.isAIRunning)
        XCTAssertEqual(store.thinkingCards.first?.title, "Slow AI card")
    }

    func testTodayPrimaryActionBlockerExplainsMissingPrerequisites() {
        store.todayDraft.state = .capture
        store.todayDraft.rawText = "   "
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("先写下") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("讲清楚一件事") == true)

        store.todayDraft.rawText = "今天想复盘会议里的卡点。"
        store.todayDraft.hasSelectedSessionMode = false
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("训练深度") == true)

        store.todayDraft.state = .reviewCards
        store.todayDraft.hasSelectedSessionMode = true
        store.thinkingCards = [ThinkingCard(type: .fact, title: "事实", body: "还没确认。")]
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("确认至少一张材料卡片") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("确认过的材料") == true)

        var confirmedCard = ThinkingCard(type: .fact, title: "事实", body: "已确认。")
        confirmedCard.isConfirmed = true
        store.thinkingCards = [confirmedCard]
        store.todayDraft.state = .selectLens
        store.todayDraft.selectedLens = nil
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("训练处方") == true)

        store.todayDraft.state = .answerQuestions
        store.todayDraft.selectedLens = .firstPrinciples
        store.questions = [
            ReflectionQuestion(
                question: "真正的问题是什么？",
                whyItMatters: "避免只处理表层症状。",
                answer: "   "
            )
        ]
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("回答一个教练问题") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("不是 AI 直接生成任务") == true)

        store.todayDraft.state = .reviewQuests
        store.questions[0].answer = "会议目标没有对齐。"
        store.quests = [
            Quest(
                type: .main,
                title: "明确会议目标",
                whyItMatters: "减少会后返工。",
                completionCriteria: "   ",
                expectedResistance: "大家默认直接开会。",
                reflectionQuestion: "目标是否被写下来？"
            )
        ]
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("完成标准") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("可检查") == true)

        store.quests = [
            Quest(
                type: .main,
                title: "明确会议目标",
                whyItMatters: "减少会后返工。",
                completionCriteria: "会前写出目标。",
                expectedResistance: "大家默认直接开会。",
                reflectionQuestion: "目标是否被写下来？"
            )
        ]
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("进入条件") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("待验证判断") == true)
        XCTAssertTrue(store.todayPrimaryActionBlocker?.contains("不是普通待办") == true)

        store.quests = [
            Quest(
                type: .main,
                title: "明确会议目标",
                whyItMatters: "减少会后返工。",
                completionCriteria: "会前写出目标。",
                expectedResistance: "大家默认直接开会。",
                reflectionQuestion: "目标是否被写下来？",
                calibrationTarget: "会前写出目标能减少会后返工"
            )
        ]
        XCTAssertNil(store.todayPrimaryActionBlocker)
    }

    func testNavigateBackToEarlierCompletedStep_trimsDownstreamGeneratedState() async throws {
        try await advanceTo(.reviewQuests)
        store.principles = [
            PrincipleAsset(title: "P", summary: "S", triggerContext: "T",
                          actions: ["A"], successCriteria: "SC", exceptions: "E")
        ]
        XCTAssertFalse(store.thinkingCards.isEmpty)
        XCTAssertFalse(store.questions.isEmpty)
        XCTAssertFalse(store.quests.isEmpty)
        XCTAssertNotNil(store.todayDraft.selectedLens)

        store.navigateTodayLoop(to: .reviewCards)

        XCTAssertEqual(store.todayDraft.state, .reviewCards)
        XCTAssertFalse(store.thinkingCards.isEmpty)
        XCTAssertFalse(store.todayDraft.hasSelectedSessionMode)
        XCTAssertNil(store.todayDraft.selectedLens)
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertTrue(store.quests.isEmpty)
        XCTAssertTrue(store.principles.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("后续内容会在确认后重新生成"))
    }

    func testPreviousFromReviewCardsReturnsToCaptureWithoutClearingCards() async throws {
        try await advanceTo(.reviewCards)
        let generatedCards = store.thinkingCards
        XCTAssertFalse(generatedCards.isEmpty)

        store.navigateTodayLoopToPreviousUserStep()

        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertEqual(store.thinkingCards, generatedCards)
        XCTAssertTrue(store.todayLoopMessage.contains("已回到今天内容"))
    }

    func testSupplementCaptureAfterGeneratedCards_appendsTextAndReturnsToCaptureForRegeneration() async throws {
        try await advanceTo(.reviewCards)
        XCTAssertFalse(store.thinkingCards.isEmpty)
        let originalText = store.todayDraft.rawText

        store.supplementTodayCapture("补充：会议前需要先列出要确认的事项。")

        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertTrue(store.todayDraft.rawText.contains(originalText))
        XCTAssertTrue(store.todayDraft.rawText.contains("会议前需要先列出"))
        XCTAssertTrue(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("补充材料"))
    }

    func testLoadPersistedState_restoresPendingAIRepairFromPromptRun() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let draft = DailyEntryDraft(
            rawText: "Today I need a repairable AI question failure.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .evidenceCheck,
            state: .answerQuestions
        )
        try await dailyRepo.saveDraft(draft)
        try await promptRunRepo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: [draft.id.uuidString],
                requestSummary: "question failure",
                error: "HTTP 500"
            )
        )

        let restoredStore = AppStore(
            dailyEntryRepository: dailyRepo,
            promptRunRepository: promptRunRepo,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.todayDraft.id, draft.id)
        XCTAssertEqual(restoredStore.pendingAIRepairCount, 1)
    }

    func testLoadRecentPromptRuns_loadsNewestFirstAuditRunsWithRefsAndErrors() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let sourceID = UUID().uuidString
        let contextID = UUID().uuidString
        let oldRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [UUID().uuidString],
            contextRecordIds: [],
            requestSummary: "old run",
            responseJSON: "{\"cards\":[]}",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let failedRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.deep.rawValue,
            sourceRecordIds: [sourceID],
            contextRecordIds: [contextID],
            requestSummary: "question generation failure",
            error: "HTTP 500: upstream unavailable",
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let newestRun = PromptRun(
            promptId: PromptID.extractPrinciple.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.quick.rawValue,
            sourceRecordIds: [sourceID, "principle-source"],
            contextRecordIds: [contextID],
            requestSummary: "principle extraction success",
            responseJSON: "{\"principles\":[]}",
            createdAt: Date(timeIntervalSince1970: 300)
        )
        try await promptRunRepo.savePromptRun(oldRun)
        try await promptRunRepo.savePromptRun(failedRun)
        try await promptRunRepo.savePromptRun(newestRun)
        try await promptRunRepo.updatePromptRunFeedback(.denied, runId: newestRun.id)

        let auditStore = AppStore(
            promptRunRepository: promptRunRepo,
            refreshesAIServiceFromKeychain: false
        )

        await auditStore.loadRecentPromptRuns(limit: 2)

        XCTAssertEqual(auditStore.recentPromptRuns.map(\.id), [newestRun.id, failedRun.id])
        XCTAssertEqual(auditStore.recentPromptRuns[0].sourceRecordIds, [sourceID, "principle-source"])
        XCTAssertEqual(auditStore.recentPromptRuns[0].contextRecordIds, [contextID])
        XCTAssertEqual(auditStore.recentPromptRuns[1].sourceRecordIds, [sourceID])
        XCTAssertEqual(auditStore.recentPromptRuns[1].contextRecordIds, [contextID])
        XCTAssertEqual(auditStore.recentPromptRuns[1].error, "HTTP 500: upstream unavailable")
        XCTAssertEqual(auditStore.promptRunStats?.totalCount, 2)
        XCTAssertEqual(auditStore.promptRunStats?.successCount, 1)
        XCTAssertEqual(auditStore.promptRunStats?.failureCount, 1)
        XCTAssertEqual(auditStore.promptRunStats?.userDeniedCount, 1)
        XCTAssertEqual(auditStore.promptAssetRunQualitySummaries.count, 2)
        let principleQuality = try XCTUnwrap(auditStore.promptAssetRunQualitySummaries.first {
            $0.promptId == PromptID.extractPrinciple.rawValue
        })
        XCTAssertEqual(principleQuality.totalCount, 1)
        XCTAssertEqual(principleQuality.successCount, 1)
        XCTAssertEqual(principleQuality.userDeniedCount, 1)
        let questionQuality = try XCTUnwrap(auditStore.promptAssetRunQualitySummaries.first {
            $0.promptId == PromptID.generateQuestions.rawValue
        })
        XCTAssertEqual(questionQuality.failureCount, 1)
        XCTAssertEqual(questionQuality.failureRate, 1, accuracy: 0.001)
        XCTAssertTrue(auditStore.promptRunAuditMessage.isEmpty)
    }

    func testLoadRecentPromptRuns_updatesPromptAssetQualityGate() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let runs = [
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 100)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "upstream failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 101)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "empty result",
                error: "TodayAIParsingError.emptyResult",
                createdAt: Date(timeIntervalSince1970: 102)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "denied result",
                responseJSON: "{}",
                userFeedback: .denied,
                createdAt: Date(timeIntervalSince1970: 103)
            )
        ]
        for run in runs {
            try await promptRunRepo.savePromptRun(run)
        }

        let auditStore = AppStore(
            promptRunRepository: promptRunRepo,
            refreshesAIServiceFromKeychain: false
        )

        await auditStore.loadRecentPromptRuns(limit: 10)

        XCTAssertEqual(auditStore.promptAssetQualityGate.status, .needsReview)
        XCTAssertEqual(auditStore.promptAssetQualityGate.needsReviewAssetCount, 1)
        XCTAssertTrue(auditStore.promptAssetQualityGate.issues.contains {
            $0.promptId == PromptID.generateQuestions.rawValue &&
                $0.reason == .highFailureRate
        })
    }

    func testLoadRecentPromptRuns_marksPromptAssetQualityRollbackReadinessFromEvalHistory() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let provider = AppStoreImportedPromptPackRollbackFixtureProvider()
        let currentTemplate = provider.template(for: .generateQuestions, mode: .standard)
        let runs = [
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 100)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "second success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 101)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "upstream failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 102)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "second upstream failure",
                error: "HTTP 502",
                createdAt: Date(timeIntervalSince1970: 103)
            )
        ]
        for run in runs {
            try await promptRunRepo.savePromptRun(run)
        }

        let rollbackTemplate = try XCTUnwrap(provider.template(for: .generateQuestions, mode: .standard, version: "1.0.0"))
        let passingRollbackRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: rollbackTemplate.version,
            promptSourceKind: rollbackTemplate.sourceKind,
            promptPackId: rollbackTemplate.packId,
            promptPackVersion: rollbackTemplate.packVersion,
            promptPackDisplayName: rollbackTemplate.packDisplayName,
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "imported.questions.pass", name: "Imported previous prompt passed", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 90)
        )
        try await evalRepo.saveEvalRun(passingRollbackRun)

        let auditStore = AppStore(
            promptRunRepository: promptRunRepo,
            promptEvalRunRepository: evalRepo,
            promptProvider: provider,
            refreshesAIServiceFromKeychain: false
        )

        await auditStore.loadRecentPromptEvalRuns(limit: 10)
        await auditStore.loadRecentPromptRuns(limit: 10)

        XCTAssertEqual(auditStore.promptAssetQualityGate.status, .needsReview)
        XCTAssertEqual(auditStore.promptAssetQualityGate.rollbackReadyAssetCount, 1)
        XCTAssertEqual(auditStore.promptAssetQualityGate.manualReviewAssetCount, 0)
        let issue = try XCTUnwrap(auditStore.promptAssetQualityGate.issues.first)
        XCTAssertEqual(issue.rollbackCandidate?.rollbackTargetVersion, "1.0.0")
        XCTAssertEqual(issue.rollbackCandidate?.lastPassingRunId, passingRollbackRun.id)
    }

    func testPromptRunAuditSummary_groupsFailedAndSuccessfulRunsWithDefaultExpansion() {
        let failedRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            requestSummary: "failed",
            error: "HTTP 500",
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let successfulRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            requestSummary: "success",
            responseJSON: "{}",
            createdAt: Date(timeIntervalSince1970: 300)
        )

        let summary = PromptRunAuditSummary(runs: [successfulRun, failedRun])

        XCTAssertEqual(summary.totalCount, 2)
        XCTAssertEqual(summary.failed.count, 1)
        XCTAssertEqual(summary.successful.count, 1)
        XCTAssertEqual(summary.defaultExpandedGroups, [.failed])
        XCTAssertEqual(summary.group(for: .failed).title, "失败")
        XCTAssertEqual(summary.group(for: .successful).title, "成功")
    }

    func testLoadRecentPromptRuns_withoutRepositoryLeavesRunsEmptyAndShowsUnavailableMessage() async throws {
        let auditStore = AppStore(refreshesAIServiceFromKeychain: false)

        await auditStore.loadRecentPromptRuns()

        XCTAssertTrue(auditStore.recentPromptRuns.isEmpty)
        XCTAssertFalse(auditStore.promptRunAuditMessage.isEmpty)
        XCTAssertTrue(
            auditStore.promptRunAuditMessage.contains("不可用") ||
            auditStore.promptRunAuditMessage.localizedCaseInsensitiveContains("unavailable")
        )
    }

    func testPrepareDataExport_waitsForPendingDraftPersistenceAndReturnsFile() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let exportStore = AppStore(
            dailyEntryRepository: dailyRepo,
            dataExportRepository: exportRepo,
            refreshesAIServiceFromKeychain: false
        )

        exportStore.updateDraftText("Export this draft after queued persistence.")
        let export = try await exportStore.prepareDataExport()
        let exportedText = try String(contentsOf: export.fileURL, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: export.fileURL.path))
        XCTAssertTrue(exportedText.contains("Export this draft after queued persistence."))
        XCTAssertTrue(export.summary.contains("daily_entries: 1"))
        XCTAssertEqual(exportStore.dataExportMessage, "已准备数据导出文件。")
    }

    func testGLMConnectionRefreshesPromptRunAuditAfterCompletion() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let isolatedKeychain = KeychainAPIKeyStore(service: "com.codex.mingsi.tests.\(UUID().uuidString)")
        let auditStore = AppStore(
            apiKeyStore: isolatedKeychain,
            promptRunRepository: promptRunRepo,
            refreshesAIServiceFromKeychain: true
        )
        auditStore.apiKeyConfigured = true

        auditStore.testGLMConnection()

        try await waitUntil(
            !auditStore.isTestingGLMConnection && !auditStore.recentPromptRuns.isEmpty,
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected completed connection test to refresh PromptRun audit rows"
        ) {
            !auditStore.isTestingGLMConnection && !auditStore.recentPromptRuns.isEmpty
        }
        let run = try XCTUnwrap(auditStore.recentPromptRuns.first)
        XCTAssertEqual(run.promptId, PromptID.organizeCards.rawValue)
        XCTAssertEqual(run.promptVersion, "connection-test")
        XCTAssertEqual(run.modelProvider, "GLM")
        XCTAssertEqual(run.modelName, "missing-api-key")
        XCTAssertEqual(run.sessionMode, SessionMode.standard.rawValue)
        XCTAssertTrue(run.error?.contains("API Key") == true)
    }

    func testKeychainRefreshRoutesGrowthReportsThroughAuditedMissingKeyClient() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)
        let isolatedKeychain = KeychainAPIKeyStore(service: "com.codex.mingsi.tests.\(UUID().uuidString)")
        let historyRecords = (0..<3).map { index in
            HistoryRecord(
                draft: DailyEntryDraft(
                    date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                    rawText: "Completed Settings refresh loop \(index)",
                    state: .sessionComplete
                )
            )
        }
        let store = AppStore(
            historyRecords: historyRecords,
            apiKeyStore: isolatedKeychain,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            promptRunRepository: promptRunRepo,
            refreshesAIServiceFromKeychain: true,
            growthAIService: nil
        )

        await store.generateWeeklyGrowthReport()

        XCTAssertFalse(store.growthReportMessage.contains("服务暂不可用"))
        XCTAssertTrue(store.growthReportMessage.contains("AI 成长报告生成失败"))
        let recentRuns = try await promptRunRepo.recentPromptRuns(limit: 1)
        let run = try XCTUnwrap(recentRuns.first)
        XCTAssertEqual(run.promptId, PromptID.weeklyCalibration.rawValue)
        XCTAssertEqual(run.modelProvider, "GLM")
        XCTAssertEqual(run.modelName, "missing-api-key")
        XCTAssertTrue(run.error?.contains("API Key") == true)
    }

    func testRepairablePromptRunsForHistoryRecordReturnsUnresolvedFailuresForThatEntry() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let historicalEntryID = UUID()
        let otherEntryID = UUID()
        let failedRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [historicalEntryID.uuidString],
            requestSummary: "history card failure",
            error: "HTTP 504: timeout",
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let unrelatedRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [otherEntryID.uuidString],
            requestSummary: "other failure",
            error: "HTTP 500",
            createdAt: Date(timeIntervalSince1970: 300)
        )
        try await promptRunRepo.savePromptRun(failedRun)
        try await promptRunRepo.savePromptRun(unrelatedRun)

        let auditStore = AppStore(
            promptRunRepository: promptRunRepo,
            refreshesAIServiceFromKeychain: false
        )

        let repairable = await auditStore.repairablePromptRuns(for: historicalEntryID)

        XCTAssertEqual(repairable.map(\.id), [failedRun.id])
        XCTAssertEqual(repairable.first?.error, "HTTP 504: timeout")
    }

    func testStartHistoricalOrganizeCardsRetry_createsCandidateWithoutChangingCurrentCards() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let candidateRepo = InMemoryHistoricalRetryCandidateRepository()
        let entry = DailyEntryDraft(
            rawText: "Historical raw input that failed card organization.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .capture
        )
        let failedRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [entry.id.uuidString],
            requestSummary: "history card failure",
            error: "HTTP 504: timeout"
        )
        let client = StreamingRecordingLLMClient(tokens: [
            "<CARD><TYPE>fact</TYPE><TITLE>Historical repair</TITLE><BODY>Recovered from retry.</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE></CARD>"
        ])
        try await dailyRepo.saveDraft(entry)
        try await promptRunRepo.savePromptRun(failedRun)

        let auditStore = AppStore(
            dailyEntryRepository: dailyRepo,
            promptRunRepository: promptRunRepo,
            historicalRetryCandidateRepository: candidateRepo,
            todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client),
            refreshesAIServiceFromKeychain: false
        )
        auditStore.thinkingCards = [
            ThinkingCard(type: .fact, title: "Current day card", body: "Should remain untouched.")
        ]

        await auditStore.startHistoricalOrganizeCardsRetry(failedPromptRunId: failedRun.id)

        let candidates = try await candidateRepo.candidates(for: entry.id)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.status, .candidateReady)
        XCTAssertEqual(candidates.first?.failedPromptRunId, failedRun.id)
        XCTAssertTrue(candidates.first?.candidatePayloadJSON?.contains("Historical repair") == true)
        XCTAssertEqual(auditStore.thinkingCards.map { $0.title }, ["Current day card"])
    }

    func testStartHistoricalOrganizeCardsRetry_rejectsUnsupportedPrompt() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let promptRunRepo = SQLitePromptRunRepository(database: database)
        let candidateRepo = InMemoryHistoricalRetryCandidateRepository()
        let entry = DailyEntryDraft(rawText: "Historical input.", state: .capture)
        let failedRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [entry.id.uuidString],
            requestSummary: "unsupported historical failure",
            error: "HTTP 500"
        )
        try await dailyRepo.saveDraft(entry)
        try await promptRunRepo.savePromptRun(failedRun)

        let auditStore = AppStore(
            dailyEntryRepository: dailyRepo,
            promptRunRepository: promptRunRepo,
            historicalRetryCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )

        await auditStore.startHistoricalOrganizeCardsRetry(failedPromptRunId: failedRun.id)

        let candidates = try await candidateRepo.candidates(for: entry.id)
        XCTAssertTrue(candidates.isEmpty)
        XCTAssertTrue(auditStore.todayLoopMessage.contains("暂只支持历史卡片整理"))
    }

    func testAcceptHistoricalRetryCandidate_blocksWhenConfirmedCardsExist() async throws {
        let candidateRepo = InMemoryHistoricalRetryCandidateRepository()
        let entryId = UUID()
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: UUID(),
            repairPromptRunId: UUID(),
            promptId: .organizeCards,
            sourceDailyEntryId: entryId,
            status: .candidateReady,
            reconstructedInputSummary: "Historical input",
            candidatePayloadJSON: #"{"cards":[]}"#
        )
        try await candidateRepo.saveCandidate(candidate)
        let auditStore = AppStore(
            historicalRetryCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )
        var confirmedCard = ThinkingCard(type: .fact, title: "Confirmed", body: "Existing evidence.")
        confirmedCard.isConfirmed = true
        auditStore.thinkingCards = [confirmedCard]

        await auditStore.acceptHistoricalRetryCandidate(candidate.id)

        let loaded = try await candidateRepo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.status, .blocked)
        XCTAssertTrue(loaded?.blockedReason?.contains("confirmed cards") == true)
    }

    func testLoadPersistedState_generatesLocalGrowthSnapshotFromCompletedVerifiedLoops() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let lensRepo = SQLiteLensSessionRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)
        var targetedPracticeEntryID: UUID?
        var possibleSignalEntryID: UUID?

        for index in stride(from: 2, through: 0, by: -1) {
            let prescription = index == 0 ? TrainingPrescription(
                recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
                recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
                recommendationReason: "先校验证据。",
                confidence: 0.78,
                policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
                alternativeLensIds: [ThinkingLens.opposingView.rawValue],
                baselineChecks: [.factInterpretationSplit, .evidenceGap, .counterexample],
                finalLensId: ThinkingLens.evidenceCheck.rawValue,
                source: .coachRecommended
            ) : nil
            let draft = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                rawText: "Completed loop \(index)",
                sessionMode: .standard,
                hasSelectedSessionMode: true,
                selectedLens: .evidenceCheck,
                trainingPrescription: prescription,
                state: .sessionComplete
            )
            if index == 0 {
                targetedPracticeEntryID = draft.id
            }
            if index == 1 {
                possibleSignalEntryID = draft.id
            }
            try await dailyRepo.saveDraft(draft)

            let quest = Quest(
                type: .main,
                title: "Quest \(index)",
                whyItMatters: "It matters",
                completionCriteria: "A visible result exists",
                expectedResistance: "Interruptions",
                reflectionQuestion: "What changed?",
                status: index == 2 ? .failed : .completed
            )
            try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)

            let verification = Verification(
                questId: quest.id,
                questTitle: quest.title,
                sourceDailyEntryId: draft.id,
                completion: index == 2 ? .missed : .done,
                valueRating: index == 1 ? .medium : .high,
                calibrationNote: "Verification \(index)"
            )
            try await verificationRepo.saveVerification(verification)

            let question = ReflectionQuestion(
                question: "What evidence supports this?",
                whyItMatters: "It trains reflection.",
                answer: "Concrete evidence."
            )
            try await lensRepo.saveLensSession(
                LensSession(
                    dailyEntryId: draft.id,
                    selectedLens: .evidenceCheck,
                    questions: [question]
                )
            )
        }

        let restoredStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            verificationRepository: verificationRepo,
            lensSessionRepository: lensRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.growthSnapshot.completeLoopCount, 3)
        XCTAssertTrue(restoredStore.growthSnapshot.canDisplayScores)
        XCTAssertTrue(restoredStore.growthSnapshot.summary.contains("3 次完整复盘"))
        let contributions = try await contributionRepo.contributions(for: restoredStore.growthSnapshot.id)
        XCTAssertFalse(contributions.isEmpty)
        XCTAssertTrue(contributions.allSatisfy { !$0.sourceId.isEmpty })
        XCTAssertTrue(contributions.contains { $0.metric == .executionReliability && $0.direction == .negative })
        let targetedLensContribution = contributions.first { contribution in
            contribution.title == "完成透镜追问" &&
                contribution.sourceDailyEntryId == targetedPracticeEntryID
        }
        XCTAssertEqual(targetedLensContribution?.practiceRole, .targetedPractice)
        XCTAssertTrue(
            targetedLensContribution.map { restoredStore.growthSnapshot.positiveContributionRefs.contains($0.id.uuidString) } ?? false
        )

        let secondaryVerificationContribution = contributions.first { contribution in
            contribution.metric == .executionReliability &&
                contribution.sourceDailyEntryId == targetedPracticeEntryID
        }
        XCTAssertEqual(secondaryVerificationContribution?.practiceRole, .secondaryPractice)

        let possibleLensContributions = contributions.filter { contribution in
            contribution.title == "完成透镜追问" &&
                contribution.practiceRole == .possibleSignal
        }
        XCTAssertTrue(possibleLensContributions.contains { $0.sourceDailyEntryId == possibleSignalEntryID })
        XCTAssertTrue(possibleLensContributions.allSatisfy { contribution in
            !restoredStore.growthSnapshot.positiveContributionRefs.contains(contribution.id.uuidString)
        })
        XCTAssertEqual(restoredStore.growthSnapshot.reflectionDepth, 3.07, accuracy: 0.001)
    }

    func testUpdateContributionFeedback_refreshesMetricContributions() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.4,
            valueJudgment: 3.0,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            summary: "Snapshot",
            positiveContributionRefs: ["pending"],
            status: .confirmedTrend,
            completeLoopCount: 3
        )
        try await snapshotRepo.saveSnapshot(snapshot)
        let contribution = MetricContribution(
            snapshotId: snapshot.id,
            metric: .clarity,
            direction: .positive,
            delta: 0.1,
            title: "Clearer task",
            reason: "The quest had a visible completion standard.",
            sourceType: .quest,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID(),
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(contribution)

        let growthStore = AppStore(
            growthSnapshot: snapshot,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await growthStore.loadMetricContributions(for: .clarity)
        XCTAssertEqual(growthStore.acceptedContributions(for: .clarity).map(\.id), [contribution.id])

        await growthStore.updateContributionFeedback(.inaccurate, for: contribution)

        XCTAssertTrue(growthStore.metricContributions.contains { item in
            item.id == contribution.id && item.userFeedback == .inaccurate
        })
        XCTAssertTrue(growthStore.acceptedContributions(for: .clarity).isEmpty)

        guard let inaccurateContribution = growthStore.metricContributions.first(where: { $0.id == contribution.id }) else {
            XCTFail("Expected inaccurate contribution to remain visible in metric detail cache")
            return
        }

        await growthStore.updateContributionFeedback(.accepted, for: inaccurateContribution)

        XCTAssertEqual(growthStore.acceptedContributions(for: .clarity).map(\.id), [contribution.id])
    }

    func testLoadLatestGrowthSnapshot_loadsReviewableReportReviewContributions() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.4,
            valueJudgment: 2.8,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            summary: "Snapshot",
            positiveContributionRefs: ["accepted"],
            negativeContributionRefs: ["negative"],
            status: .confirmedTrend,
            completeLoopCount: 4,
            nextTrainingFocus: "Train sharper prioritization."
        )
        try await snapshotRepo.saveSnapshot(snapshot)
        let reviewCandidate = MetricContribution(
            snapshotId: snapshot.id,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Clearer task",
            reason: "The quest had visible completion evidence.",
            sourceType: .quest,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID(),
            candidateStatus: .candidate
        )
        let acceptedNegative = MetricContribution(
            snapshotId: snapshot.id,
            metric: .valueJudgment,
            direction: .negative,
            delta: -0.1,
            title: "Low leverage task",
            reason: "The action did not connect to the stated goal.",
            sourceType: .verification,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID(),
            candidateStatus: .accepted
        )
        let rejected = MetricContribution(
            snapshotId: snapshot.id,
            metric: .calibration,
            direction: .positive,
            delta: 0.1,
            title: "Rejected contribution",
            reason: "Should not appear in report review.",
            sourceType: .quest,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID(),
            candidateStatus: .rejected
        )
        try await contributionRepo.saveContribution(reviewCandidate)
        try await contributionRepo.saveContribution(acceptedNegative)
        try await contributionRepo.saveContribution(rejected)

        let growthStore = AppStore(
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await growthStore.loadLatestGrowthSnapshot()

        XCTAssertEqual(growthStore.growthReportReviewContributions.map(\.id), [reviewCandidate.id, acceptedNegative.id])
        XCTAssertTrue(growthStore.acceptedReportReviewContributions(for: .clarity).isEmpty)
        XCTAssertEqual(growthStore.acceptedReportReviewContributions(for: .valueJudgment).map(\.id), [acceptedNegative.id])
    }

    func testLoadLatestGrowthSnapshot_degradesDisplayWhenContributionRefsDoNotResolve() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 4.1,
            valueJudgment: 3.8,
            executionReliability: 3.5,
            calibration: 3.2,
            reflectionDepth: 3.9,
            summary: "Snapshot claims growth without real contributions.",
            positiveContributionRefs: ["missing-positive"],
            negativeContributionRefs: ["missing-negative"],
            status: .confirmedTrend,
            completeLoopCount: 4,
            nextTrainingFocus: "Keep improving."
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let growthStore = AppStore(
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await growthStore.loadLatestGrowthSnapshot()

        XCTAssertFalse(growthStore.growthSnapshot.canDisplayScores)
        XCTAssertEqual(growthStore.growthSnapshot.status, .insufficientEvidence)
        XCTAssertTrue(growthStore.growthSnapshot.summary.contains("缺少可追溯的成长贡献"))
        XCTAssertTrue(growthStore.growthReportReviewContributions.isEmpty)
    }

    func testUpdateContributionFeedback_refreshesReportReviewContributions() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.4,
            valueJudgment: 3.0,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            summary: "Snapshot",
            positiveContributionRefs: ["accepted"],
            status: .confirmedTrend,
            completeLoopCount: 4
        )
        try await snapshotRepo.saveSnapshot(snapshot)
        let contribution = MetricContribution(
            snapshotId: snapshot.id,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Clearer task",
            reason: "The quest had visible completion evidence.",
            sourceType: .quest,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID(),
            candidateStatus: .candidate
        )
        try await contributionRepo.saveContribution(contribution)

        let growthStore = AppStore(
            growthSnapshot: snapshot,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await growthStore.loadLatestGrowthSnapshot()
        XCTAssertEqual(growthStore.growthReportReviewContributions.map(\.id), [contribution.id])

        await growthStore.updateContributionFeedback(.inaccurate, for: contribution)

        XCTAssertTrue(growthStore.growthReportReviewContributions.isEmpty)
        XCTAssertTrue(growthStore.acceptedReportReviewContributions(for: .clarity).isEmpty)
    }

    func testGenerateWeeklyGrowthReport_withEnoughEvidencePersistsAIContributionsAsReviewCandidates() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        var firstEntryId: UUID?
        var firstQuestId: UUID?
        for index in stride(from: 2, through: 0, by: -1) {
            let draft = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                rawText: "Completed report loop \(index)",
                state: .sessionComplete
            )
            try await dailyRepo.saveDraft(draft)
            let quest = Quest(
                type: .main,
                title: "Report Quest \(index)",
                whyItMatters: "It matters",
                completionCriteria: "Visible result",
                expectedResistance: "Interruptions",
                reflectionQuestion: "What changed?",
                status: .completed
            )
            try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)
            try await verificationRepo.saveVerification(
                Verification(
                    questId: quest.id,
                    questTitle: quest.title,
                    sourceDailyEntryId: draft.id,
                    completion: .done,
                    valueRating: .high,
                    calibrationNote: "Report verification \(index)"
                )
            )

            if firstEntryId == nil {
                firstEntryId = draft.id
                firstQuestId = quest.id
            }
        }

        let entryId = try XCTUnwrap(firstEntryId)
        let questId = try XCTUnwrap(firstQuestId)
        let response = Self.growthReportResponse(entryID: entryId, sourceID: questId.uuidString)
        let growthService = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: RecordingLLMClient(response: response)
        )
        let growthStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            verificationRepository: verificationRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false,
            growthAIService: growthService
        )

        await growthStore.loadHistoryRecords()
        await growthStore.generateWeeklyGrowthReport()

        let savedSnapshotCandidate = try await snapshotRepo.latestSnapshot()
        let savedSnapshot = try XCTUnwrap(savedSnapshotCandidate)
        XCTAssertEqual(savedSnapshot.period, "weekly")
        XCTAssertTrue(savedSnapshot.canDisplayScores)
        XCTAssertEqual(savedSnapshot.summary, "AI weekly growth summary")
        XCTAssertEqual(savedSnapshot.completeLoopCount, 3)
        XCTAssertFalse(growthStore.isGeneratingGrowthReport)
        XCTAssertTrue(growthStore.growthReportMessage.contains("周度"))

        let savedContributions = try await contributionRepo.contributions(for: savedSnapshot.id)
        XCTAssertEqual(savedContributions.count, 1)
        XCTAssertEqual(savedContributions[0].sourceId, questId.uuidString)
        XCTAssertEqual(savedContributions[0].sourceDailyEntryId, entryId)
        XCTAssertEqual(savedContributions[0].candidateStatus, .candidate)
        XCTAssertEqual(savedContributions[0].practiceRole, .possibleSignal)
        XCTAssertEqual(growthStore.growthReportReviewContributions.map(\.id), savedContributions.map(\.id))
    }

    func testGenerateMonthlyGrowthReport_withEnoughEvidencePersistsAIContributionsAsReviewCandidates() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        var firstEntryId: UUID?
        var firstQuestId: UUID?
        for index in stride(from: 2, through: 0, by: -1) {
            let draft = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                rawText: "Completed monthly report loop \(index)",
                state: .sessionComplete
            )
            try await dailyRepo.saveDraft(draft)
            let quest = Quest(
                type: .main,
                title: "Monthly Report Quest \(index)",
                whyItMatters: "It matters",
                completionCriteria: "Visible result",
                expectedResistance: "Interruptions",
                reflectionQuestion: "What changed?",
                status: .completed
            )
            try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)
            try await verificationRepo.saveVerification(
                Verification(
                    questId: quest.id,
                    questTitle: quest.title,
                    sourceDailyEntryId: draft.id,
                    completion: .done,
                    valueRating: .high,
                    calibrationNote: "Monthly report verification \(index)"
                )
            )

            if firstEntryId == nil {
                firstEntryId = draft.id
                firstQuestId = quest.id
            }
        }

        let entryId = try XCTUnwrap(firstEntryId)
        let questId = try XCTUnwrap(firstQuestId)
        let growthService = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: RecordingLLMClient(response: Self.growthReportResponse(entryID: entryId, sourceID: questId.uuidString))
        )
        let growthStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            verificationRepository: verificationRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false,
            growthAIService: growthService
        )

        await growthStore.loadHistoryRecords()
        await growthStore.generateMonthlyGrowthReport()

        let savedSnapshotCandidate = try await snapshotRepo.latestSnapshot()
        let savedSnapshot = try XCTUnwrap(savedSnapshotCandidate)
        XCTAssertEqual(savedSnapshot.period, "monthly")
        XCTAssertTrue(savedSnapshot.canDisplayScores)

        let savedContributions = try await contributionRepo.contributions(for: savedSnapshot.id)
        XCTAssertEqual(savedContributions.count, 1)
        XCTAssertEqual(savedContributions[0].sourceId, questId.uuidString)
        XCTAssertEqual(savedContributions[0].sourceDailyEntryId, entryId)
        XCTAssertEqual(savedContributions[0].candidateStatus, .candidate)
        XCTAssertEqual(savedContributions[0].practiceRole, .possibleSignal)
        XCTAssertEqual(growthStore.growthReportReviewContributions.map(\.id), savedContributions.map(\.id))
    }

    func testGenerateWeeklyGrowthReport_includesDismissedContributionFeedbackFromLatestSnapshot() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        var firstEntryId: UUID?
        var firstQuestId: UUID?
        for index in stride(from: 2, through: 0, by: -1) {
            let draft = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                rawText: "Completed feedback loop \(index)",
                state: .sessionComplete
            )
            try await dailyRepo.saveDraft(draft)
            let quest = Quest(
                type: .main,
                title: "Feedback Quest \(index)",
                whyItMatters: "It matters",
                completionCriteria: "Visible result",
                expectedResistance: "Interruptions",
                reflectionQuestion: "What changed?",
                status: .completed
            )
            try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)
            try await verificationRepo.saveVerification(
                Verification(
                    questId: quest.id,
                    questTitle: quest.title,
                    sourceDailyEntryId: draft.id,
                    completion: .done,
                    valueRating: .high,
                    calibrationNote: "Feedback verification \(index)"
                )
            )

            if firstEntryId == nil {
                firstEntryId = draft.id
                firstQuestId = quest.id
            }
        }

        let entryId = try XCTUnwrap(firstEntryId)
        let questId = try XCTUnwrap(firstQuestId)
        let previousSnapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.6,
            valueJudgment: 3.1,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            summary: "Previous weekly report",
            positiveContributionRefs: ["dismissed"],
            status: .confirmedTrend,
            completeLoopCount: 3
        )
        try await snapshotRepo.saveSnapshot(previousSnapshot)
        let dismissedContribution = MetricContribution(
            snapshotId: previousSnapshot.id,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Overstated clarity gain",
            reason: "This inference was too broad.",
            sourceType: .quest,
            sourceId: questId.uuidString,
            sourceDailyEntryId: entryId,
            userFeedback: .inaccurate,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(dismissedContribution)

        let client = RecordingLLMClient(response: Self.growthReportResponse(entryID: entryId, sourceID: questId.uuidString))
        let growthService = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let growthStore = AppStore(
            growthSnapshot: previousSnapshot,
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            verificationRepository: verificationRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false,
            growthAIService: growthService
        )

        await growthStore.loadHistoryRecords()
        await growthStore.generateWeeklyGrowthReport()

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.legacyKeyValues["dismissed_contributions"], "Overstated clarity gain")
        XCTAssertEqual(payload.growth?.dismissedContributionTitles, ["Overstated clarity gain"])
    }

    func testGenerateMonthlyGrowthReport_withInsufficientEvidenceSavesNoContributions() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Only one completed loop", state: .sessionComplete)
        try await dailyRepo.saveDraft(draft)

        let growthStore = AppStore(
            dailyEntryRepository: dailyRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false,
            growthAIService: GrowthAIService(promptProvider: LocalPromptProvider(), llmClient: MockLLMClient())
        )

        await growthStore.loadHistoryRecords()
        await growthStore.generateMonthlyGrowthReport()

        let savedSnapshotCandidate = try await snapshotRepo.latestSnapshot()
        let savedSnapshot = try XCTUnwrap(savedSnapshotCandidate)
        XCTAssertEqual(savedSnapshot.period, "monthly")
        XCTAssertFalse(savedSnapshot.canDisplayScores)
        XCTAssertEqual(savedSnapshot.status, .insufficientEvidence)
        XCTAssertEqual(savedSnapshot.completeLoopCount, 1)
        let savedContributions = try await contributionRepo.contributions(for: savedSnapshot.id)
        XCTAssertTrue(savedContributions.isEmpty)
        XCTAssertFalse(growthStore.isGeneratingGrowthReport)
        XCTAssertTrue(growthStore.growthReportMessage.contains("证据"))
    }

    func testPersistVerification_refreshesGrowthEvidenceWithoutRestart() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let verificationRepo = SQLiteVerificationRepository(database: database)
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        var activeQuest: Quest?
        for index in stride(from: 2, through: 0, by: -1) {
            let draft = DailyEntryDraft(
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                rawText: "Completed loop \(index)",
                sessionMode: .standard,
                hasSelectedSessionMode: true,
                selectedLens: .evidenceCheck,
                state: .sessionComplete
            )
            try await dailyRepo.saveDraft(draft)

            let quest = Quest(
                type: .main,
                title: "Quest \(index)",
                whyItMatters: "It matters",
                completionCriteria: "A visible result exists",
                expectedResistance: "Interruptions",
                reflectionQuestion: "What changed?",
                status: index == 0 ? .active : .completed
            )
            try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)

            if index == 0 {
                activeQuest = quest
            } else {
                try await verificationRepo.saveVerification(
                    Verification(
                        questId: quest.id,
                        questTitle: quest.title,
                        sourceDailyEntryId: draft.id,
                        completion: .done,
                        valueRating: .high,
                        calibrationNote: "Verification \(index)"
                    )
                )
            }
        }

        let today = DailyEntryDraft(rawText: "Today verification", state: .verifyYesterday)
        try await dailyRepo.saveDraft(today)
        let growthStore = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            verificationRepository: verificationRepo,
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await growthStore.loadPersistedState()
        XCTAssertEqual(growthStore.growthSnapshot.completeLoopCount, 3)
        let initialEvidenceRefs = growthStore.growthSnapshot.evidenceRefs
        XCTAssertFalse(initialEvidenceRefs.contains { ref in
            ref == activeQuest?.id.uuidString
        })
        let verifiedQuest = try XCTUnwrap(activeQuest)
        let loadedActiveQuestSourceDay = try await questRepo.sourceDailyEntryId(forQuestId: verifiedQuest.id)
        let activeQuestSourceDay = try XCTUnwrap(loadedActiveQuestSourceDay)

        growthStore.selectYesterdayCompletion(.missed)
        growthStore.selectYesterdayValueRating(.low)
        growthStore.submitTodayStep()
        try await waitUntilAsync(
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected growth evidence refs to refresh after saving verification"
        ) {
            (try await contributionRepo.contributions(for: growthStore.growthSnapshot.id)
                .contains { contribution in
                    contribution.sourceDailyEntryId == activeQuestSourceDay
                })
        }

        let refreshedContributions = try await contributionRepo.contributions(for: growthStore.growthSnapshot.id)
        XCTAssertTrue(refreshedContributions.contains { contribution in
            contribution.sourceDailyEntryId == activeQuestSourceDay
        })
        XCTAssertEqual(growthStore.growthSnapshot.completeLoopCount, 3)
    }

    // MARK: - Project evidence creation

    func testCreateProjectFromCurrentFocus_persistsProjectAndConfirmedQuestLink() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)
        let quest = Quest(
            type: .main,
            title: "Prepare meeting outcomes",
            whyItMatters: "Reduce follow-up ambiguity.",
            completionCriteria: "Owner, action, and acceptance criteria are written.",
            expectedResistance: "Discussion may drift.",
            reflectionQuestion: "Which decision must be explicit?",
            status: .active
        )
        store = AppStore(
            quests: [quest],
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )

        XCTAssertTrue(store.canCreateProjectFromCurrentFocus)

        await store.createProjectFromCurrentFocus()

        let projects = try await projectRepo.activeProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].name, "Prepare meeting ou...")
        XCTAssertEqual(projects[0].goal, "Reduce follow-up ambiguity.")
        XCTAssertEqual(projects[0].successCriteria, "Owner, action, and acceptance criteria are written.")
        XCTAssertEqual(projects[0].currentBottleneck, "Discussion may drift.")
        XCTAssertEqual(projects[0].openQuestions, ["Which decision must be explicit?"])

        let links = try await projectLinkRepo.links(for: projects[0].id)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].sourceType, .quest)
        XCTAssertEqual(links[0].sourceId, quest.id.uuidString)
        XCTAssertEqual(links[0].linkType, .task)
        XCTAssertTrue(links[0].isUserConfirmed)
        XCTAssertEqual(store.projectNames[projects[0].id], "Prepare meeting ou...")
        XCTAssertTrue(store.historyRecords.contains { record in
            record.projectLinks.contains { $0.sourceId == quest.id.uuidString }
        })
        XCTAssertFalse(store.canCreateProjectFromCurrentFocus)
    }

    func testCreateProjectFromCurrentFocus_doesNotDuplicateExistingQuestLink() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)
        let quest = activeMainQuest()
        store = AppStore(
            quests: [quest],
            historyRecords: [
                HistoryRecord(
                    draft: DailyEntryDraft(),
                    quests: [quest],
                    projectLinks: [
                        ProjectLink(
                            projectId: UUID(),
                            sourceType: .quest,
                            sourceId: quest.id.uuidString,
                            linkType: .task,
                            isUserConfirmed: true
                        )
                    ]
                )
            ],
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )

        XCTAssertFalse(store.canCreateProjectFromCurrentFocus)

        await store.createProjectFromCurrentFocus()

        let projects = try await projectRepo.activeProjects()
        XCTAssertTrue(projects.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("已经关联"))
    }

    func testCreateProjectFromHistoricalQuest_persistsProjectAndConfirmedProjectLink() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)

        let historicalEntry = DailyEntryDraft(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            rawText: "Historical quest evidence",
            state: .sessionComplete
        )
        let quest = Quest(
            type: .main,
            title: "Stabilize launch readiness",
            whyItMatters: "Launch needs a repeatable quality gate.",
            completionCriteria: "Quality gate is written and used before release.",
            expectedResistance: "Last-minute scope changes.",
            reflectionQuestion: "Which risk keeps recurring?",
            status: .active
        )
        try await dailyRepo.saveDraft(historicalEntry)
        try await questRepo.saveQuest(quest, sourceDailyEntryId: historicalEntry.id)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadHistoryRecords()

        await store.createProjectFromQuest(quest, dailyEntryId: historicalEntry.id)

        let projects = try await projectRepo.activeProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].name, "Stabilize launch r...")
        XCTAssertEqual(projects[0].goal, "Launch needs a repeatable quality gate.")
        XCTAssertEqual(projects[0].successCriteria, "Quality gate is written and used before release.")
        XCTAssertEqual(projects[0].currentBottleneck, "Last-minute scope changes.")
        XCTAssertEqual(projects[0].openQuestions, ["Which risk keeps recurring?"])

        let links = try await projectLinkRepo.links(for: projects[0].id)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].sourceType, .quest)
        XCTAssertEqual(links[0].sourceId, quest.id.uuidString)
        XCTAssertEqual(links[0].linkType, .task)
        XCTAssertTrue(links[0].isUserConfirmed)
    }

    func testCreateProjectFromHistoricalPrinciple_persistsProjectAndConfirmedProjectLink() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)

        let historicalEntry = DailyEntryDraft(
            date: Date(timeIntervalSince1970: 1_700_086_400),
            rawText: "Historical principle evidence",
            state: .sessionComplete
        )
        let principle = PrincipleAsset(
            title: "Write the decision boundary first",
            summary: "State what would change the decision before debating options.",
            triggerContext: "Ambiguous product or engineering tradeoffs.",
            actions: ["Name the reversible and irreversible parts.", "Write the evidence threshold."],
            successCriteria: "The team can tell why a choice is accepted or rejected.",
            exceptions: "Tiny reversible choices."
        )
        try await dailyRepo.saveDraft(historicalEntry)
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: historicalEntry.id)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadHistoryRecords()

        await store.createProjectFromPrinciple(principle, dailyEntryId: historicalEntry.id)

        let projects = try await projectRepo.activeProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].name, "Write the decision...")
        XCTAssertEqual(projects[0].goal, "State what would change the decision before debating options.")
        XCTAssertEqual(projects[0].successCriteria, "The team can tell why a choice is accepted or rejected.")
        XCTAssertEqual(projects[0].currentBottleneck, "Ambiguous product or engineering tradeoffs.")
        XCTAssertEqual(projects[0].openQuestions, ["Name the reversible and irreversible parts.", "Write the evidence threshold."])

        let links = try await projectLinkRepo.links(for: projects[0].id)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].sourceType, .principle)
        XCTAssertEqual(links[0].sourceId, principle.id.uuidString)
        XCTAssertEqual(links[0].linkType, .principle)
        XCTAssertTrue(links[0].isUserConfirmed)
    }

    func testCreateProjectFromHistoricalQuest_duplicateSourceIdDoesNotCreateDuplicateProjectOrLink() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)

        let historicalEntry = DailyEntryDraft(
            date: Date(timeIntervalSince1970: 1_700_172_800),
            rawText: "Duplicate source evidence",
            state: .sessionComplete
        )
        let quest = activeMainQuest(title: "Prevent duplicated project evidence")
        try await dailyRepo.saveDraft(historicalEntry)
        try await questRepo.saveQuest(quest, sourceDailyEntryId: historicalEntry.id)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadHistoryRecords()

        await store.createProjectFromQuest(quest, dailyEntryId: historicalEntry.id)
        await store.loadHistoryRecords()
        await store.createProjectFromQuest(quest, dailyEntryId: historicalEntry.id)

        let projects = try await projectRepo.activeProjects()
        XCTAssertEqual(projects.count, 1)
        let links = try await projectLinkRepo.links(for: projects[0].id)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].sourceId, quest.id.uuidString)
        XCTAssertEqual(
            store.historyRecords.flatMap(\.projectLinks).filter { $0.sourceId == quest.id.uuidString }.count,
            1
        )
    }

    func testProjectEvidenceTimelineDeepLinkDataLocatesHistoryRecord() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let projectLinkRepo = SQLiteProjectLinkRepository(database: database)

        let historicalEntry = DailyEntryDraft(
            date: Date(timeIntervalSince1970: 1_700_259_200),
            rawText: "Timeline evidence source",
            state: .sessionComplete
        )
        let quest = activeMainQuest(title: "Make timeline links resolvable")
        try await dailyRepo.saveDraft(historicalEntry)
        try await questRepo.saveQuest(quest, sourceDailyEntryId: historicalEntry.id)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            questRepository: questRepo,
            projectLinkRepository: projectLinkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadHistoryRecords()
        await store.createProjectFromQuest(quest, dailyEntryId: historicalEntry.id)
        await store.loadHistoryRecords()

        let timelineRecord = try XCTUnwrap(store.historyRecords.first { record in
            record.projectLinks.contains { $0.sourceId == quest.id.uuidString }
        })
        let timelineLink = try XCTUnwrap(timelineRecord.projectLinks.first { $0.sourceId == quest.id.uuidString })
        let deepLink = HistoryDeepLink(
            dailyEntryId: timelineRecord.draft.id,
            sourceId: timelineLink.sourceId,
            sourceType: .quest
        )

        XCTAssertEqual(deepLink.dailyEntryId, historicalEntry.id)
        XCTAssertEqual(deepLink.sourceId, quest.id.uuidString)
        XCTAssertTrue(timelineRecord.sourceIds.contains(timelineLink.sourceId))
        XCTAssertNotNil(store.historyRecords.first { record in
            record.id == deepLink.dailyEntryId &&
            record.sourceIds.contains(deepLink.sourceId ?? "")
        })

        store.navigateToHistoryDeepLink(deepLink)
        XCTAssertEqual(store.selectedTab, .history)
        XCTAssertEqual(store.historyDeepLink, deepLink)
    }

    // MARK: - Project editing governance

    func testUpdateProjectDetails_persistsEditableFieldsAndRefreshesDictionaries() async throws {
        let projectRepo = InMemoryProjectRepository()
        let project = Project(
            name: "会议机制",
            goal: "减少会后返工",
            successCriteria: "Action 有 owner",
            currentBottleneck: "会前目标不清",
            openQuestions: ["谁负责跟进？"],
            status: .active
        )
        try await projectRepo.saveProject(project)
        store = AppStore(
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project

        await store.updateProjectDetails(
            projectId: project.id,
            name: "会议决策机制",
            goal: "减少会议后的决策返工",
            successCriteria: "每次会议都有 owner、action 和验收标准",
            currentBottleneck: "会前没有写出确认事项",
            openQuestions: ["哪些决策必须会前确认？", "谁在会后发纪要？"]
        )

        let loadedProject = try await projectRepo.project(id: project.id)
        let saved = try XCTUnwrap(loadedProject)
        XCTAssertEqual(saved.name, "会议决策机制")
        XCTAssertEqual(saved.goal, "减少会议后的决策返工")
        XCTAssertEqual(saved.successCriteria, "每次会议都有 owner、action 和验收标准")
        XCTAssertEqual(saved.currentBottleneck, "会前没有写出确认事项")
        XCTAssertEqual(saved.openQuestions, ["哪些决策必须会前确认？", "谁在会后发纪要？"])
        XCTAssertEqual(saved.status, .active)
        XCTAssertTrue(saved.fieldRevisions.keys.contains("name"))
        XCTAssertTrue(saved.fieldRevisions.keys.contains("goal"))
        XCTAssertEqual(store.projectNames[project.id], "会议决策机制")
        XCTAssertEqual(store.projectsById[project.id]?.goal, "减少会议后的决策返工")
    }

    func testUpdateProjectDetails_rejectsEmptyNameAndPreservesExistingProject() async throws {
        let projectRepo = InMemoryProjectRepository()
        let project = Project(
            name: "判断质量",
            goal: "提升决策前的证据意识",
            successCriteria: "每次决策写出反证",
            status: .active
        )
        try await projectRepo.saveProject(project)
        store = AppStore(
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project

        await store.updateProjectDetails(
            projectId: project.id,
            name: "   ",
            goal: "被拒绝的目标",
            successCriteria: "被拒绝的标准",
            currentBottleneck: nil as String?,
            openQuestions: []
        )

        let loadedProject = try await projectRepo.project(id: project.id)
        let saved = try XCTUnwrap(loadedProject)
        XCTAssertEqual(saved.name, "判断质量")
        XCTAssertEqual(saved.goal, "提升决策前的证据意识")
        XCTAssertEqual(store.projectNames[project.id], "判断质量")
        XCTAssertTrue(store.projectSuggestionMessage.contains("项目名称不能为空"))
    }

    func testArchiveProject_preservesProjectAndEvidenceLinks() async throws {
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()
        let project = Project(
            name: "会议机制",
            goal: "减少会后返工",
            successCriteria: "Action 有 owner",
            status: .active
        )
        let link = ProjectLink(
            projectId: project.id,
            sourceType: .quest,
            sourceId: UUID().uuidString,
            linkType: .task,
            isUserConfirmed: true
        )
        try await projectRepo.saveProject(project)
        try await linkRepo.saveLink(link)
        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project

        await store.archiveProject(project.id)

        let loadedProject = try await projectRepo.project(id: project.id)
        let saved = try XCTUnwrap(loadedProject)
        XCTAssertEqual(saved.status, .archived)
        XCTAssertEqual(store.projectsById[project.id]?.status, .archived)
        let links = try await linkRepo.links(for: project.id)
        XCTAssertEqual(links.map(\.id), [link.id])
    }

    func testRestoreProject_setsArchivedProjectBackToActive() async throws {
        let projectRepo = InMemoryProjectRepository()
        let project = Project(
            name: "会议机制",
            goal: "减少会后返工",
            successCriteria: "Action 有 owner",
            status: .archived
        )
        try await projectRepo.saveProject(project)
        store = AppStore(
            projectRepository: projectRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project

        await store.restoreProject(project.id)

        let loadedProject = try await projectRepo.project(id: project.id)
        let saved = try XCTUnwrap(loadedProject)
        XCTAssertEqual(saved.status, .active)
        XCTAssertEqual(store.projectsById[project.id]?.status, .active)
    }

    // MARK: - Project Merge Candidates

    func testSuggestProjectMerges_generatesCandidatesAndUpdatesState() async throws {
        let mergeRepo = InMemoryProjectMergeCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let project1 = Project(
            name: "接口归属确认",
            goal: "明确各接口的负责人",
            successCriteria: "所有接口都有明确负责人",
            status: .active
        )
        let project2 = Project(
            name: "接口负责人问题",
            goal: "确定每个接口的负责人",
            successCriteria: "所有接口都有指定负责人",
            status: .active
        )
        try await projectRepo.saveProject(project1)
        try await projectRepo.saveProject(project2)

        let cardID = UUID()
        let link = ProjectLink(
            projectId: project1.id,
            sourceType: .thinkingCard,
            sourceId: cardID.uuidString,
            linkType: .evidence
        )
        try await linkRepo.saveLink(link)
        let links = try await linkRepo.links(for: project1.id)
        var updatedLink = try XCTUnwrap(links.first)
        updatedLink = ProjectLink(
            id: updatedLink.id,
            projectId: updatedLink.projectId,
            sourceType: updatedLink.sourceType,
            sourceId: updatedLink.sourceId,
            linkType: updatedLink.linkType,
            confidence: updatedLink.confidence,
            isUserConfirmed: true,
            createdAt: updatedLink.createdAt,
            updatedAt: updatedLink.updatedAt
        )
        try await linkRepo.saveLink(updatedLink)

        let response = Data(
            """
            {
              "merge_candidates": [
                {
                  "source_project_id": "\(project2.id.uuidString)",
                  "target_project_id": "\(project1.id.uuidString)",
                  "reason": "两个项目的目标都围绕接口负责人问题",
                  "overlapping_evidence_refs": ["\(cardID.uuidString)"]
                }
              ]
            }
            """.utf8
        )
        let client = RecordingLLMClient(response: response)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectMergeCandidateRepository: mergeRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.suggestProjectMerges(ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ))

        XCTAssertEqual(store.pendingProjectMergeCandidates.count, 1)
        XCTAssertEqual(store.pendingProjectMergeCandidates[0].sourceProjectId, project2.id)
        XCTAssertEqual(store.pendingProjectMergeCandidates[0].targetProjectId, project1.id)
        XCTAssertEqual(store.pendingProjectMergeCandidates[0].status, .pending)
    }

    func testSuggestProjectMerges_dropsInvalidCandidatesWithUnknownProjectIds() async throws {
        let mergeRepo = InMemoryProjectMergeCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let project1 = Project(
            name: "接口归属确认",
            goal: "明确各接口的负责人",
            successCriteria: "所有接口都有明确负责人",
            status: .active
        )
        try await projectRepo.saveProject(project1)

        let response = Data(
            """
            {
              "merge_candidates": [
                {
                  "source_project_id": "\(UUID().uuidString)",
                  "target_project_id": "\(project1.id.uuidString)",
                  "reason": "目标不存在",
                  "overlapping_evidence_refs": []
                }
              ]
            }
            """.utf8
        )
        let client = RecordingLLMClient(response: response)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectMergeCandidateRepository: mergeRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.suggestProjectMerges(ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ))

        XCTAssertTrue(store.pendingProjectMergeCandidates.isEmpty)
    }

    func testSuggestProjectMerges_dropsInvalidCandidatesWithUnresolvedEvidenceRefs() async throws {
        let mergeRepo = InMemoryProjectMergeCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let project1 = Project(
            name: "接口归属确认",
            goal: "明确各接口的负责人",
            successCriteria: "所有接口都有明确负责人",
            status: .active
        )
        let project2 = Project(
            name: "接口负责人问题",
            goal: "确定每个接口的负责人",
            successCriteria: "所有接口都有指定负责人",
            status: .active
        )
        try await projectRepo.saveProject(project1)
        try await projectRepo.saveProject(project2)

        let fakeEvidenceID = UUID()

        let response = Data(
            """
            {
              "merge_candidates": [
                {
                  "source_project_id": "\(project2.id.uuidString)",
                  "target_project_id": "\(project1.id.uuidString)",
                  "reason": "两个项目的目标都围绕接口负责人问题",
                  "overlapping_evidence_refs": ["\(fakeEvidenceID.uuidString)"]
                }
              ]
            }
            """.utf8
        )
        let client = RecordingLLMClient(response: response)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectMergeCandidateRepository: mergeRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.suggestProjectMerges(ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        ))

        XCTAssertTrue(store.pendingProjectMergeCandidates.isEmpty)
    }

    func testAcceptProjectMergeCandidate_archivesSourceAndUpdatesTargetMergeHistory() async throws {
        let mergeRepo = InMemoryProjectMergeCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let project1 = Project(
            name: "接口归属确认",
            goal: "明确各接口的负责人",
            successCriteria: "所有接口都有明确负责人",
            status: .active
        )
        let project2 = Project(
            name: "接口负责人问题",
            goal: "确定每个接口的负责人",
            successCriteria: "所有接口都有指定负责人",
            status: .active
        )
        try await projectRepo.saveProject(project1)
        try await projectRepo.saveProject(project2)

        let candidate = ProjectMergeCandidate(
            sourceProjectId: project2.id,
            targetProjectId: project1.id,
            reason: "两个项目的目标都围绕接口负责人问题",
            overlappingEvidenceRefs: []
        )
        try await mergeRepo.saveMergeCandidate(candidate)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectMergeCandidateRepository: mergeRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPendingProjectMergeCandidates()

        await store.acceptProjectMergeCandidate(candidate.id)

        let sourceProject = try await projectRepo.project(id: project2.id)
        XCTAssertEqual(sourceProject?.status, .archived)
        XCTAssertEqual(store.projectsById[project2.id]?.status, .archived)

        let targetProject = try await projectRepo.project(id: project1.id)
        XCTAssertTrue(targetProject?.mergeHistory.contains { $0.contains("合并了: 接口负责人问题") } == true)
        XCTAssertTrue(store.projectsById[project1.id]?.mergeHistory.contains { $0.contains("合并了: 接口负责人问题") } == true)

        let acceptedCandidate = try await mergeRepo.mergeCandidate(id: candidate.id)
        XCTAssertEqual(acceptedCandidate?.status, .accepted)
    }

    func testRejectProjectMergeCandidate_doesNotAlterProjects() async throws {
        let mergeRepo = InMemoryProjectMergeCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let project1 = Project(
            name: "接口归属确认",
            goal: "明确各接口的负责人",
            successCriteria: "所有接口都有明确负责人",
            status: .active
        )
        let project2 = Project(
            name: "接口负责人问题",
            goal: "确定每个接口的负责人",
            successCriteria: "所有接口都有指定负责人",
            status: .active
        )
        try await projectRepo.saveProject(project1)
        try await projectRepo.saveProject(project2)

        let candidate = ProjectMergeCandidate(
            sourceProjectId: project2.id,
            targetProjectId: project1.id,
            reason: "两个项目的目标都围绕接口负责人问题",
            overlappingEvidenceRefs: []
        )
        try await mergeRepo.saveMergeCandidate(candidate)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectMergeCandidateRepository: mergeRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPendingProjectMergeCandidates()

        await store.rejectProjectMergeCandidate(candidate.id)

        let sourceProject = try await projectRepo.project(id: project2.id)
        XCTAssertEqual(sourceProject?.status, .active)

        let targetProject = try await projectRepo.project(id: project1.id)
        XCTAssertTrue(targetProject?.mergeHistory.isEmpty == true)

        let rejectedCandidate = try await mergeRepo.mergeCandidate(id: candidate.id)
        XCTAssertEqual(rejectedCandidate?.status, .rejected)
    }

    func testDismissProjectMergeCandidate_doesNotAlterProjects() async throws {
        let mergeRepo = InMemoryProjectMergeCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let project1 = Project(
            name: "接口归属确认",
            goal: "明确各接口的负责人",
            successCriteria: "所有接口都有明确负责人",
            status: .active
        )
        let project2 = Project(
            name: "接口负责人问题",
            goal: "确定每个接口的负责人",
            successCriteria: "所有接口都有指定负责人",
            status: .active
        )
        try await projectRepo.saveProject(project1)
        try await projectRepo.saveProject(project2)

        let candidate = ProjectMergeCandidate(
            sourceProjectId: project2.id,
            targetProjectId: project1.id,
            reason: "两个项目的目标都围绕接口负责人问题",
            overlappingEvidenceRefs: []
        )
        try await mergeRepo.saveMergeCandidate(candidate)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectMergeCandidateRepository: mergeRepo,
            refreshesAIServiceFromKeychain: false
        )
        await store.loadPendingProjectMergeCandidates()

        await store.dismissProjectMergeCandidate(candidate.id)

        let sourceProject = try await projectRepo.project(id: project2.id)
        XCTAssertEqual(sourceProject?.status, .active)

        let targetProject = try await projectRepo.project(id: project1.id)
        XCTAssertTrue(targetProject?.mergeHistory.isEmpty == true)

        let dismissedCandidate = try await mergeRepo.mergeCandidate(id: candidate.id)
        XCTAssertEqual(dismissedCandidate?.status, .dismissed)
    }

    // MARK: - State advancement helpers

    /// Advances the store to the given state using the normal user flow.
    /// Each step follows the same path a user would take through the Today loop.
    private func advanceTo(_ target: DailyLoopState) async throws {
        switch target {
        case .verifyYesterday:
            return

        case .capture:
            store.selectYesterdayCompletion(.done)
            store.selectYesterdayValueRating(.high)
            store.submitTodayStep()
            try await waitForState(.capture)

        case .organizing:
            try await advanceTo(.capture)
            store.selectTodayMode(.standard)
            store.updateTodayCapture("Today I discussed project priorities with the team.")
            store.submitTodayStep()
            // Async card generation fires but state stays at .organizing
            try await waitForGeneratedCards()

        case .reviewCards:
            try await advanceTo(.organizing)
            // After async card generation, cards exist but state is still .organizing
            // Submit again to advance organizing -> reviewCards
            store.submitTodayStep()
            try await waitForState(.reviewCards)

        case .selectMode:
            try await advanceTo(.reviewCards)
            store.todayDraft.state = .selectMode
            store.todayDraft.hasSelectedSessionMode = false

        case .selectLens:
            try await advanceTo(.reviewCards)
            var card = ThinkingCard(type: .problem, title: "Confirmed", body: "Body")
            card.isConfirmed = true
            store.thinkingCards = [card]
            store.submitTodayStep()
            try await waitForState(.selectLens)

        case .answerQuestions:
            try await advanceTo(.selectLens)
            store.selectThinkingLens(.leverageAnalysis)
            store.questions = [
                ReflectionQuestion(question: "What is the highest-value action?", whyItMatters: "Forces prioritization")
            ]
            store.submitTodayStep()
            try await waitForState(.answerQuestions)

        case .reviewQuests:
            try await advanceTo(.answerQuestions)
            store.questions = [
                ReflectionQuestion(
                    question: "Q?",
                    whyItMatters: "M",
                    calibrationTarget: "验收标准明确会减少返工",
                    answer: "事实是今天已经确认关键证据。"
                )
            ]
            store.submitTodayStep()
            try await waitForState(.reviewQuests)

        case .extractPrinciple:
            try await advanceTo(.reviewQuests)
            var quest = Quest(type: .main, title: "Valid quest", whyItMatters: "W",
                              completionCriteria: "Criteria met", expectedResistance: "E",
                              reflectionQuestion: "R")
            quest.status = .active
            store.quests = [quest]
            store.submitTodayStep()
            try await waitForState(.extractPrinciple)

        case .sessionComplete:
            try await advanceTo(.extractPrinciple)
            store.principles = [
                PrincipleAsset(title: "P", summary: "S", triggerContext: "T",
                              actions: ["A"], successCriteria: "SC", exceptions: "E")
            ]
            store.submitTodayStep()
            try await waitForState(.sessionComplete)
        }
    }

    private func coachPrescriptionEvidenceCards() -> [ThinkingCard] {
        [
            ThinkingCard(
                type: .fact,
                title: "Meeting ownership unclear",
                body: "The meeting ended without a written owner.",
                priority: .high,
                isConfirmed: true
            ),
            ThinkingCard(
                type: .risk,
                title: "Acceptance criteria missing",
                body: "The next step can be disputed because no checkable criteria were written.",
                priority: .high,
                isConfirmed: true
            )
        ]
    }

    private func confirmedCards(_ cards: [ThinkingCard]) -> [ThinkingCard] {
        cards.map { card in
            var confirmed = card
            confirmed.isConfirmed = true
            return confirmed
        }
    }

    private func observationPrompt(for gap: CoachObservationGap) -> String {
        let cards: [ThinkingCard]
        switch gap {
        case .narrative:
            cards = [
                ThinkingCard(type: .idea, title: "今天很乱", body: "我只有很乱和焦虑的感受。")
            ]
        case .object:
            cards = [
                ThinkingCard(
                    type: .task,
                    title: "方案推进卡住",
                    body: "今天需求评审后，我打算先重写方案。因为会上大家提出很多意见，后来方案没有通过。"
                )
            ]
        case .constraint:
            cards = [
                ThinkingCard(
                    type: .problem,
                    title: "跨团队推进卡住",
                    body: "今天在项目沟通中，我和产品团队讨论接口方案，但推进不下去，后来决定先暂停方案调整。"
                )
            ]
        case .causal:
            cards = [
                ThinkingCard(
                    type: .fact,
                    title: "会议结果",
                    body: "事实是会议结束后没有明确负责人，后来接口方案返工。"
                ),
                ThinkingCard(
                    type: .idea,
                    title: "我的解释",
                    body: "我认为返工是因为大家都不想负责，所以方案没有通过。"
                )
            ]
        case .judgment:
            cards = [
                ThinkingCard(
                    type: .fact,
                    title: "注册反馈",
                    body: "事实是上线后客服收到 12 条用户反馈，3 个用户卡在注册步骤。"
                ),
                ThinkingCard(
                    type: .decision,
                    title: "优先改注册流程",
                    body: "我判断注册流程需要优先改。"
                )
            ]
        case .execution:
            cards = [
                ThinkingCard(
                    type: .task,
                    title: "明天推进方案",
                    body: "为了让 Alex 减少返工，明天推进方案处理一下。"
                )
            ]
        case .calibration:
            cards = [
                ThinkingCard(
                    type: .fact,
                    title: "注册反馈",
                    body: "事实是客服记录了 12 条用户反馈，3 个用户卡在注册步骤。"
                ),
                ThinkingCard(
                    type: .decision,
                    title: "优先改注册流程",
                    body: "我判断应该优先改注册流程，判断标准是影响新用户完成首次使用。"
                )
            ]
        case .observation, .goal, .counterexample, .experience:
            cards = []
        }

        let observation = CoachObservationPolicy().observe(cards: confirmedCards(cards))
        XCTAssertEqual(observation.primaryGap, gap)
        return observation.experienceReplayPrompt
    }

    private func waitForState(
        _ expectedState: DailyLoopState,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await waitUntil(
            store.todayDraft.state == expectedState,
            timeout: timeout,
            file: file,
            line: line,
            failureMessage: "Expected state \(expectedState), got \(store.todayDraft.state)"
        ) {
            store.todayDraft.state == expectedState
        }
    }

    private func waitForGeneratedCards(
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await waitUntil(
            !store.thinkingCards.isEmpty,
            timeout: timeout,
            file: file,
            line: line,
            failureMessage: "Expected generated thinking cards"
        ) {
            !store.thinkingCards.isEmpty
        }
    }

    private func waitForGeneratedQuestions(
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await waitUntil(
            !store.questions.isEmpty,
            timeout: timeout,
            file: file,
            line: line,
            failureMessage: "Expected generated questions"
        ) {
            !store.questions.isEmpty
        }
    }

    private func waitUntil(
        _ initialCondition: Bool,
        timeout: TimeInterval,
        file: StaticString,
        line: UInt,
        failureMessage: @autoclosure () -> String,
        condition: () -> Bool
    ) async throws {
        if initialCondition { return }

        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        guard condition() else {
            XCTFail(failureMessage(), file: file, line: line)
            throw StateMachineWaitError.timeout
        }
    }

    private func waitUntilAsync(
        timeout: TimeInterval,
        file: StaticString,
        line: UInt,
        failureMessage: @autoclosure () -> String,
        condition: () async throws -> Bool
    ) async throws {
        if try await condition() { return }

        let deadline = Date().addingTimeInterval(timeout)
        while try await !condition() && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        guard try await condition() else {
            XCTFail(failureMessage(), file: file, line: line)
            throw StateMachineWaitError.timeout
        }
    }

    private func activeMainQuest(title: String = "Verify real quest") -> Quest {
        Quest(
            type: .main,
            title: title,
            whyItMatters: "It calibrates yesterday.",
            completionCriteria: "A concrete result exists.",
            expectedResistance: "Interruptions.",
            reflectionQuestion: "What changed?",
            status: .active
        )
    }

    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    private static func makeRuntimeLensPackItem(lensId: String, promptId: String) -> LensCatalogItem {
        LensCatalogItem(
            lensId: lensId,
            promptId: promptId,
            version: "asset.v1",
            title: "Runtime Lens",
            subtitle: "Loaded from a persisted lens asset pack.",
            shortLabel: "Run",
            methodLine: "What would this external lens ask first?",
            promptGuidance: "Ask questions from the external lens asset pack.",
            symbolName: "sparkles",
            recommendedReason: "Persisted runtime lens pack.",
            questionSeeds: ["What would this external lens ask first?"],
            accentRole: .accent,
            methodIndex: 20
        )
    }

    private static func makePromptPackTemplate(
        promptId: PromptID,
        version: String,
        userText: String
    ) -> PromptTemplate {
        PromptTemplate(
            id: promptId,
            version: version,
            systemPolicyVersion: "system.pack.v1",
            contextPolicyVersion: "context.\(promptId.rawValue).pack.v1",
            evalSuiteVersion: "\(promptId.rawValue).eval.pack.v1",
            rollbackTargetVersion: nil,
            systemText: "Pack system policy for \(promptId.rawValue).",
            userText: userText,
            outputSchemaVersion: 1
        )
    }

    private static func trusted(
        _ pack: PromptAssetPack,
        verificationPolicyVersion: String = "asset-trust.test.v1",
        privateKeyBase64: String = testPublisherPrivateKeyBase64
    ) throws -> PromptAssetPack {
        let contentHash = try AssetPackIntegrity.expectedContentHash(for: pack)
        return PromptAssetPack(
            id: pack.id,
            version: pack.version,
            displayName: pack.displayName,
            sourceKind: pack.sourceKind,
            isEnabled: pack.isEnabled,
            templates: pack.templates,
            trustMetadata: try signedTrustMetadata(
                contentHash: contentHash,
                signedPayload: AssetPackIntegrity.signaturePayload(for: pack),
                verificationPolicyVersion: verificationPolicyVersion,
                privateKeyBase64: privateKeyBase64
            )
        )
    }

    private static func trusted(_ pack: LensAssetPack) throws -> LensAssetPack {
        let contentHash = try AssetPackIntegrity.expectedContentHash(for: pack)
        return LensAssetPack(
            id: pack.id,
            version: pack.version,
            displayName: pack.displayName,
            sourceKind: pack.sourceKind,
            isEnabled: pack.isEnabled,
            items: pack.items,
            trustMetadata: try signedTrustMetadata(
                contentHash: contentHash,
                signedPayload: AssetPackIntegrity.signaturePayload(for: pack)
            )
        )
    }

    private static func makeTrustMetadata(contentHash: String) -> AssetTrustMetadata {
        AssetTrustMetadata(
            publisherId: "mingsi.test.publisher",
            contentHash: contentHash,
            signature: "p256-sha256:invalid-test-signature",
            trustedAt: "2026-06-10T00:00:00Z",
            verificationPolicyVersion: "asset-trust.test.v1"
        )
    }

    private static func signedTrustMetadata(
        publisherId: String = "mingsi.test.publisher",
        contentHash: String,
        signedPayload: Data,
        verificationPolicyVersion: String = "asset-trust.test.v1",
        privateKeyBase64: String = testPublisherPrivateKeyBase64
    ) throws -> AssetTrustMetadata {
        let keyData = try XCTUnwrap(Data(base64Encoded: privateKeyBase64))
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
        let signature = try privateKey.signature(for: signedPayload)
        return AssetTrustMetadata(
            publisherId: publisherId,
            contentHash: contentHash,
            signature: "p256-sha256:" + signature.derRepresentation.base64EncodedString(),
            trustedAt: "2026-06-10T00:00:00Z",
            verificationPolicyVersion: verificationPolicyVersion
        )
    }

    private static func signedTrustPolicyDocument(
        _ document: AssetPackTrustPolicyDocument,
        privateKeyBase64: String = testRegistryRootPrivateKeyBase64
    ) throws -> AssetPackTrustPolicyDocument {
        AssetPackTrustPolicyDocument(
            policies: document.policies,
            expiresAt: document.expiresAt,
            trustMetadata: try signedTrustMetadata(
                publisherId: "mingsi.test.registry",
                contentHash: try AssetPackIntegrity.expectedContentHash(for: document),
                signedPayload: AssetPackIntegrity.signaturePayload(for: document),
                verificationPolicyVersion: "asset-trust-policy-root.test.v1",
                privateKeyBase64: privateKeyBase64
            )
        )
    }

    nonisolated private static let testPublisherPrivateKeyBase64 = "Zcl0fRH+ywPs2LCNnRt4Jgkkg2IQWBwb0X42sTsVrKc="
    nonisolated private static let rotatedPublisherPrivateKeyBase64 = "XevPucFuvG6Qc3pJsFZIrGxO/SyZ0h7joKaZCTq4F84="
    nonisolated private static let rotatedPublisherPublicKeyBase64 = "oWMff09DdO3X4j8sTNyVyvkyBPwE1u92V6uWUXwja11I+NWsO9JcXodn+3AKjS5V79HtI/FVX3fObaehVz7zKw=="
    nonisolated private static let testRegistryRootPrivateKeyBase64 = "khu517UBQX2f62ROBcl1XuforsMkVw7gbkhzHpGPug4="

    private static let mismatchedContentHash = "sha256:" + String(repeating: "0", count: 64)

    private static let assetPackJSONEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static func storageString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func encodedJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private enum StateMachineWaitError: Error {
        case timeout
    }

    private static func cardsResponse(title: String) -> Data {
        Data(
            """
            {
              "cards": [
                {
                  "type": "fact",
                  "title": "\(title)",
                  "body": "Generated by AI after retry.",
                  "importance": "high",
                  "sensitivity": "normal",
                  "confidence": "high",
                  "reason": "Test response."
                }
              ],
              "sensitivity_notes": [],
              "transcript_quality": "medium",
              "recommended_next_step": "Review the card."
            }
            """.utf8
        )
    }

    private static let questionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "What evidence shows ownership was unclear?",
              "why_this_matters": "It separates fact from interpretation.",
              "expected_answer_type": "fact"
            }
          ]
        }
        """.utf8
    )

    private static let questsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Confirm meeting owner",
            "why_it_matters": "It reduces ambiguity.",
            "completion_criteria": "Owner and acceptance criteria are written and acknowledged before implementation starts.",
            "expected_resistance": "People may assume it is obvious.",
            "reflection_question": "Did written ownership reduce ambiguity?",
            "calibration_target": "Written ownership acknowledgement reduces meeting ambiguity",
            "lens_move": "evidence_threshold",
            "linked_cards": ["Meeting ownership unclear"]
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let opposingViewQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "If missing ownership is not the main risk, what alternative explanation fits the evidence?",
              "why_this_matters": "It asks for a counterexample before locking onto the default interpretation.",
              "evidence_gap_type": "missing_counterexample",
              "answer_use": "test_assumption",
              "lens_move": "alternative_explanation",
              "source_card_titles": ["Meeting ownership unclear"],
              "calibration_target": "Missing ownership is the main risk behind the current rework.",
              "expected_answer_type": "counterexample"
            }
          ]
        }
        """.utf8
    )

    private static let verificationResponse = Data(
        """
        {
          "calibration_note": "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
          "likely_issue": "none",
          "recommendation": "Next calibration: test whether adding acceptance criteria further reduces rework."
        }
        """.utf8
    )

    private static let lowQualityQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "What do you think about the situation?",
              "why_this_matters": "It helps you reflect.",
              "evidence_gap_type": "",
              "answer_use": "",
              "lens_move": "prediction_calibration",
              "source_card_titles": [],
              "calibration_target": "the situation",
              "expected_answer_type": "judgment"
            }
          ]
        }
        """.utf8
    )

    private static let lowQualityQuestsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Polish the meeting notes",
            "why_it_matters": "It looks more complete.",
            "completion_criteria": "Polish the notes.",
            "expected_resistance": "There may be many details.",
            "reflection_question": "How do you feel?",
            "calibration_target": "the situation"
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    // MARK: - Visual QA Launch Fixture

    func testVisualQAProjectDetailFixture_startsOnProjectsTab() {
        let fixtureStore = AppStore.visualQAProjectDetail()
        XCTAssertEqual(fixtureStore.selectedTab, .projects)
    }

    func testVisualQAProjectDetailFixture_hasAtLeastOneEvidenceBackedProject() {
        let fixtureStore = AppStore.visualQAProjectDetail()
        XCTAssertFalse(fixtureStore.projectsById.isEmpty, "Fixture must include at least one project in projectsById")
        XCTAssertFalse(fixtureStore.projectNames.isEmpty, "Fixture must include project names")

        let project = fixtureStore.projectsById.values.first!
        let projectId = project.id
        XCTAssertEqual(fixtureStore.projectNames[projectId], project.name)

        let hasConfirmedLink = fixtureStore.historyRecords.contains { record in
            record.projectLinks.contains { link in
                link.projectId == projectId && link.isUserConfirmed
            }
        }
        XCTAssertTrue(hasConfirmedLink, "Fixture must have at least one history record with a confirmed ProjectLink for the project")
    }

    func testVisualQAProjectDetailFixture_hasProjectInsights() {
        let fixtureStore = AppStore.visualQAProjectDetail()
        let allInsights = fixtureStore.acceptedProjectInsights + fixtureStore.pendingProjectInsights
        XCTAssertFalse(allInsights.isEmpty, "Fixture must have accepted or pending project insights")

        let projectIds = Set(fixtureStore.projectsById.keys)
        XCTAssertTrue(
            allInsights.allSatisfy { projectIds.contains($0.projectId) },
            "All fixture insights must reference a project in projectsById"
        )
    }

    func testVisualQAProjectDetailLaunch_withoutArgument_returnsFalse() {
        let cleanDefaults = UserDefaults(suiteName: "test-visual-qa-no-argument")!
        cleanDefaults.removeObject(forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")
        XCTAssertFalse(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: [:],
                defaults: cleanDefaults,
                markerFileExists: { false }
            ),
            "Without MINGSI_VISUAL_QA_PROJECT_DETAIL, fixture mode should not activate"
        )
        cleanDefaults.removeSuite(named: "test-visual-qa-no-argument")
    }

    func testVisualQAProjectDetailLaunch_withArgument_returnsTrue() {
        XCTAssertTrue(
            AppStore.isVisualQAProjectDetailLaunch(arguments: ["MINGSI_VISUAL_QA_PROJECT_DETAIL"]),
            "With MINGSI_VISUAL_QA_PROJECT_DETAIL, fixture mode should activate"
        )
    }

    func testVisualQAProjectDetailLaunch_withEnvironmentVariable_returnsTrue() {
        XCTAssertTrue(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: ["MINGSI_VISUAL_QA_PROJECT_DETAIL": "1"]
            ),
            "With MINGSI_VISUAL_QA_PROJECT_DETAIL env var, fixture mode should activate"
        )
    }

    func testVisualQAProjectDetailLaunch_withSimctlChildEnvironmentVariable_returnsTrue() {
        XCTAssertTrue(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: ["SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL": "1"]
            ),
            "With SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL env var, fixture mode should activate"
        )
    }

    func testVisualQAFixtureStore_optsOutOfLoadPersistedState() {
        let fixtureStore = AppStore.visualQAProjectDetail()
        XCTAssertFalse(
            fixtureStore.loadsPersistedStateOnLaunch,
            "Visual QA fixture store must not load persisted state on launch"
        )
    }

    func testApplyVisualQAProjectDetailFixture_populatesStoreAndOptsOutOfLoadPersistedState() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)
        XCTAssertTrue(store.historyRecords.flatMap(\.projectLinks).isEmpty)
        XCTAssertTrue(store.loadsPersistedStateOnLaunch)

        store.applyVisualQAProjectDetailFixture()

        XCTAssertEqual(store.selectedTab, .projects)
        XCTAssertFalse(store.historyRecords.flatMap(\.projectLinks).isEmpty)
        XCTAssertFalse(store.projectNames.isEmpty)
        XCTAssertFalse(store.projectsById.isEmpty)
        XCTAssertFalse(store.acceptedProjectInsights.isEmpty)
        XCTAssertFalse(store.pendingProjectInsights.isEmpty)
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQAFixture_loadHistoryRecordsKeepsFixtureProjectEvidence() async {
        let store = AppStore.visualQAProjectDetail()
        XCTAssertFalse(store.historyRecords.flatMap(\.projectLinks).isEmpty)

        await store.loadHistoryRecords()

        XCTAssertFalse(
            store.historyRecords.flatMap(\.projectLinks).isEmpty,
            "Project screen reload tasks must not replace the visual QA fixture with live empty history"
        )
        XCTAssertEqual(store.projectNames.values.first, "Visual QA - 会议机制优化")
    }

    func testNormalStore_loadsPersistedStateOnLaunch() {
        let normalStore = AppStore(
            refreshesAIServiceFromKeychain: false
        )
        XCTAssertTrue(
            normalStore.loadsPersistedStateOnLaunch,
            "Normal store must load persisted state on launch"
        )
    }

    func testLiveStore_loadsPersistedStateOnLaunch() {
        let liveStore = AppStore.live()
        XCTAssertTrue(
            liveStore.loadsPersistedStateOnLaunch,
            "Live store must load persisted state on launch"
        )
    }

    func testVisualQAProjectDetailLaunch_withUserDefaultsSet_returnsTrue() {
        let testDefaults = UserDefaults(suiteName: "test-visual-qa-userdefaults")!
        testDefaults.set(true, forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")
        XCTAssertTrue(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: [:],
                defaults: testDefaults
            ),
            "With MINGSI_VISUAL_QA_PROJECT_DETAIL in UserDefaults, fixture mode should activate"
        )
        testDefaults.removeSuite(named: "test-visual-qa-userdefaults")
    }

    func testVisualQAProjectDetailLaunch_withoutUserDefaults_returnsFalse() {
        let testDefaults = UserDefaults(suiteName: "test-visual-qa-userdefaults-clean")!
        testDefaults.removeObject(forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")
        XCTAssertFalse(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: [:],
                defaults: testDefaults,
                markerFileExists: { false }
            ),
            "Without any flag, fixture mode should not activate"
        )
        testDefaults.removeSuite(named: "test-visual-qa-userdefaults-clean")
    }

    // MARK: - Visual QA Marker File Activation

    func testVisualQAProjectDetailLaunch_withMarkerFile_returnsTrue() {
        XCTAssertTrue(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: [:],
                defaults: UserDefaults(suiteName: "test-marker-clean")!,
                markerFileExists: { true }
            ),
            "With marker file present, fixture mode should activate"
        )
    }

    func testVisualQAProjectDetailLaunch_withoutMarkerFile_returnsFalse() {
        let cleanDefaults = UserDefaults(suiteName: "test-marker-absent")!
        cleanDefaults.removeObject(forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")
        XCTAssertFalse(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: [],
                environment: [:],
                defaults: cleanDefaults,
                markerFileExists: { false }
            ),
            "Without marker file and no other flags, fixture mode should not activate"
        )
        cleanDefaults.removeSuite(named: "test-marker-absent")
    }

    func testVisualQAProjectDetailLaunch_markerFile_doesNotOverrideOtherActivation() {
        XCTAssertTrue(
            AppStore.isVisualQAProjectDetailLaunch(
                arguments: ["MINGSI_VISUAL_QA_PROJECT_DETAIL"],
                environment: [:],
                markerFileExists: { false }
            ),
            "Argument activation should work even when marker file is absent"
        )
    }

    func testVisualQAProjectDetailLaunch_markerFileName_isDocumented() {
        XCTAssertEqual(
            AppStore.visualQAMarkerFileName,
            ".visual_qa_project_detail",
            "Marker filename must be documented and stable for Codex to create"
        )
    }

    func testVisualQATabResolve_environmentVariable() {
        XCTAssertEqual(
            AppStore.resolveVisualQATab(environment: ["MINGSI_VISUAL_QA_TAB": "history"]),
            .history
        )
        XCTAssertEqual(
            AppStore.resolveVisualQATab(environment: ["MINGSI_VISUAL_QA_TAB": "projects"]),
            .projects
        )
        XCTAssertEqual(
            AppStore.resolveVisualQATab(environment: ["MINGSI_VISUAL_QA_TAB": "growth"]),
            .growth
        )
        XCTAssertEqual(
            AppStore.resolveVisualQATab(environment: ["MINGSI_VISUAL_QA_TAB": "settings"]),
            .settings
        )
    }

    func testVisualQATabResolve_simctlChildEnvironmentVariable() {
        XCTAssertEqual(
            AppStore.resolveVisualQATab(environment: ["SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB": "today"]),
            .today
        )
    }

    func testVisualQATabResolve_unknownReturnsNil() {
        XCTAssertNil(
            AppStore.resolveVisualQATab(environment: ["MINGSI_VISUAL_QA_TAB": "timeline"]),
            "Unknown visual QA tabs must not change launch state"
        )
    }

    func testApplyVisualQATabOverride_winsAfterProjectDetailFixture() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQAProjectDetailFixture()
        store.applyVisualQATabOverride(environment: ["MINGSI_VISUAL_QA_TAB": "history"])

        XCTAssertEqual(
            store.selectedTab,
            .history,
            "Visual QA tab override must win after fixture apply so screenshot automation can target any root tab"
        )
    }

    func testVisualQARootTabLaunch_doesNotUseProjectDetailFixtureMarker() {
        let cleanDefaults = UserDefaults(suiteName: "test-visual-qa-root-tab-priority")!
        cleanDefaults.removeObject(forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")

        XCTAssertFalse(
            AppStore.shouldUseVisualQAProjectDetailFixture(
                arguments: [],
                environment: ["MINGSI_VISUAL_QA_TAB": "history"],
                defaults: cleanDefaults,
                markerFileExists: { true }
            ),
            "Root-tab screenshot automation must ignore stale Project Detail marker files"
        )

        cleanDefaults.removeSuite(named: "test-visual-qa-root-tab-priority")
    }

    func testVisualQASettingsAuditProof_appliesSettingsFailureAuditState() throws {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQASettingsAuditProof(
            environment: ["MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF": "1"]
        )

        XCTAssertEqual(store.selectedTab, .settings)
        XCTAssertTrue(store.apiKeyConfigured)
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)
        XCTAssertTrue(store.settingsMessage.contains("GLM 连接测试失败"))
        XCTAssertTrue(store.promptRunAuditMessage.isEmpty)

        let run = try XCTUnwrap(store.recentPromptRuns.first)
        XCTAssertEqual(run.promptId, PromptID.organizeCards.rawValue)
        XCTAssertEqual(run.modelProvider, "GLM")
        XCTAssertEqual(run.modelName, "debug-settings-audit-proof")
        XCTAssertTrue(run.error?.contains("Debug 视觉验证") == true)
    }

    func testVisualQASettingsAuditProof_withoutFlagDoesNothing() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQASettingsAuditProof(environment: [:])

        XCTAssertEqual(store.selectedTab, .today)
        XCTAssertFalse(store.apiKeyConfigured)
        XCTAssertTrue(store.recentPromptRuns.isEmpty)
        XCTAssertTrue(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQASettingsAuditProof_readsSimctlChildFlag() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQASettingsAuditProof(
            environment: ["SIMCTL_CHILD_MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF": "1"]
        )

        XCTAssertEqual(store.selectedTab, .settings)
        XCTAssertFalse(store.recentPromptRuns.isEmpty)
    }

    func testVisualQASettingsAssetPackManifestFixture_readsDirectAndSimctlChildFlags() {
        XCTAssertTrue(AppStore.shouldUseVisualQASettingsAssetPackManifestFixture(
            environment: ["MINGSI_VISUAL_QA_SETTINGS_ASSET_PACK_MANIFEST": "1"]
        ))
        XCTAssertTrue(AppStore.shouldUseVisualQASettingsAssetPackManifestFixture(
            environment: ["SIMCTL_CHILD_MINGSI_VISUAL_QA_SETTINGS_ASSET_PACK_MANIFEST": "1"]
        ))
        XCTAssertFalse(AppStore.shouldUseVisualQASettingsAssetPackManifestFixture(environment: [:]))
    }

    func testVisualQASettingsAuditProof_preventsProjectDetailFixtureMarker() {
        XCTAssertFalse(
            AppStore.shouldUseVisualQAProjectDetailFixture(
                environment: ["MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF": "1"],
                markerFileExists: { true }
            ),
            "Settings audit proof launches must not be hijacked by stale Project Detail visual QA marker files"
        )
    }

    func testVisualQASettingsAuditProof_loadRecentPromptRunsKeepsFixtureRows() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let store = AppStore(
            promptRunRepository: SQLitePromptRunRepository(database: database),
            refreshesAIServiceFromKeychain: false
        )

        store.applyVisualQASettingsAuditProof(
            environment: ["MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF": "1"]
        )
        await store.loadRecentPromptRuns()

        let run = try XCTUnwrap(store.recentPromptRuns.first)
        XCTAssertEqual(run.modelName, "debug-settings-audit-proof")
        XCTAssertTrue(store.promptRunAuditMessage.isEmpty)
    }

    func testVisualQATodaySeedInput_appliesCaptureTextModeAndSkipsPersistedLoad() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天需要先明确会议目标。",
                "MINGSI_VISUAL_QA_TODAY_MODE": "deep"
            ]
        )

        XCTAssertEqual(store.selectedTab, .today)
        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertEqual(store.todayDraft.rawText, "今天需要先明确会议目标。")
        XCTAssertEqual(store.todayDraft.sessionMode, .deep)
        XCTAssertTrue(store.todayDraft.hasSelectedSessionMode)
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQATodaySeedInput_withoutInputDoesNotChangeNormalLaunchState() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(environment: ["MINGSI_VISUAL_QA_TODAY_MODE": "quick"])

        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertTrue(store.todayDraft.rawText.isEmpty)
        XCTAssertFalse(store.todayDraft.hasSelectedSessionMode)
        XCTAssertTrue(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQATodaySeedInput_readsSimctlChildEnvironmentAndDefaultsUnknownMode() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT": "  今天先把输入自动化打通。  ",
                "SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE": "slow"
            ]
        )

        XCTAssertEqual(store.selectedTab, .today)
        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertEqual(store.todayDraft.rawText, "今天先把输入自动化打通。")
        XCTAssertEqual(store.todayDraft.sessionMode, .standard)
        XCTAssertTrue(store.todayDraft.hasSelectedSessionMode)
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQATodaySeedInput_preventsProjectDetailFixtureMarker() {
        XCTAssertFalse(
            AppStore.shouldUseVisualQAProjectDetailFixture(
                environment: ["MINGSI_VISUAL_QA_TODAY_INPUT": "今天先验证输入种子。"],
                markerFileExists: { true }
            ),
            "Today seed launches must not be hijacked by stale Project Detail visual QA marker files"
        )
    }

    func testVisualQATodayStageSeed_withoutInputDoesNothing() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(environment: ["MINGSI_VISUAL_QA_TODAY_STAGE": "select_lens"])

        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertTrue(store.todayDraft.rawText.isEmpty)
        XCTAssertTrue(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQATodayStageSeed_verifyYesterdayKeepsResultCalibrationState() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天先保持验证昨日入口。",
                "MINGSI_VISUAL_QA_TODAY_STAGE": "verify_yesterday"
            ]
        )

        XCTAssertEqual(store.selectedTab, .today)
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertEqual(store.todayDraft.rawText, "今天先保持验证昨日入口。")
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQATodayStageSeed_selectLensSeedsConfirmedFallbackCards() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天需要先明确会议目标。",
                "MINGSI_VISUAL_QA_TODAY_STAGE": "select_lens"
            ]
        )

        XCTAssertEqual(store.selectedTab, .today)
        XCTAssertEqual(store.todayDraft.state, .selectLens)
        XCTAssertEqual(store.todayDraft.rawText, "今天需要先明确会议目标。")
        XCTAssertFalse(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.thinkingCards.contains(where: \.isConfirmed))
        XCTAssertNil(store.todayDraft.selectedLens)
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("本地 fallback"))
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)
    }

    func testVisualQACustomLensSheetFlag_resolvesFromEnvironment() {
        XCTAssertFalse(AppStore.shouldPresentVisualQACustomLensSheet(environment: [:]))
        XCTAssertTrue(
            AppStore.shouldPresentVisualQACustomLensSheet(
                environment: ["MINGSI_VISUAL_QA_TODAY_CUSTOM_LENS_SHEET": "1"]
            )
        )
        XCTAssertTrue(
            AppStore.shouldPresentVisualQACustomLensSheet(
                environment: ["SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_CUSTOM_LENS_SHEET": "1"]
            )
        )
    }

    func testVisualQATodayStageSeed_readsSimctlChildStage() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT": "今天继续截图验证透镜流程。",
                "SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE": "review_cards_confirmed"
            ]
        )

        XCTAssertEqual(store.todayDraft.state, .reviewCards)
        XCTAssertFalse(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.thinkingCards.allSatisfy(\.isConfirmed))
    }

    func testVisualQATodayStageSeed_answerQuestionsSeedsLensQuestions() throws {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天需要用第一性原理拆一下会议目标。",
                "MINGSI_VISUAL_QA_TODAY_STAGE": "answer_questions"
            ]
        )

        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertEqual(store.todayDraft.selectedLens, .firstPrinciples)
        XCTAssertFalse(store.thinkingCards.isEmpty)
        XCTAssertTrue(store.thinkingCards.allSatisfy(\.isConfirmed))
        XCTAssertFalse(store.questions.isEmpty)
        XCTAssertFalse(store.hasAnsweredReflectionQuestion)
        XCTAssertNotNil(store.coachTurnState)
        XCTAssertNotNil(store.trainingPrescription)
        let turn = try XCTUnwrap(store.coachTurnState)
        let teachingPlan = CoachTeachingPolicy().makePlan(
            turn: turn,
            prescription: store.trainingPrescription
        )
        XCTAssertTrue(teachingPlan.repairQuestion.contains("刚才的回答"))
    }

    func testVisualQATodayStageSeed_reviewQuestsSeedsAnsweredQuestionsAndQuests() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天要把明天的最高杠杆行动说清楚。",
                "MINGSI_VISUAL_QA_TODAY_STAGE": "review_quests"
            ]
        )

        XCTAssertEqual(store.todayDraft.state, .reviewQuests)
        XCTAssertEqual(store.todayDraft.selectedLens, .firstPrinciples)
        XCTAssertTrue(store.hasAnsweredReflectionQuestion)
        XCTAssertNotNil(store.mainQuest)
        XCTAssertFalse(store.quests.isEmpty)
    }

    func testVisualQATodayStageSeed_extractPrincipleSeedsQuestsAndPrinciple() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天要把可复用原则从任务里沉淀出来。",
                "MINGSI_VISUAL_QA_TODAY_STAGE": "extract_principle"
            ]
        )

        XCTAssertEqual(store.todayDraft.state, .extractPrinciple)
        XCTAssertNotNil(store.mainQuest)
        XCTAssertFalse(store.principles.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("本地 fallback"))
    }

    func testVisualQATodayStageSeed_sessionCompleteSeedsHistoryArchiveAndHonorsHistoryTab() throws {
        let store = AppStore(refreshesAIServiceFromKeychain: false)

        store.applyVisualQATodaySeed(
            environment: [
                "MINGSI_VISUAL_QA_TODAY_INPUT": "今天要把闭环结果归档到历史证据里。",
                "MINGSI_VISUAL_QA_TODAY_STAGE": "session_complete",
                "MINGSI_VISUAL_QA_TAB": "history"
            ]
        )

        XCTAssertEqual(store.selectedTab, .history)
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
        XCTAssertEqual(store.todayDraft.rawText, "今天要把闭环结果归档到历史证据里。")
        XCTAssertFalse(store.loadsPersistedStateOnLaunch)

        let record = try XCTUnwrap(store.historyRecords.first)
        XCTAssertEqual(record.draft.id, store.todayDraft.id)
        XCTAssertEqual(record.draft.state, .sessionComplete)
        XCTAssertEqual(record.draft.rawText, store.todayDraft.rawText)
        XCTAssertTrue(record.hasCardEvidence)
        XCTAssertTrue(record.confirmedCards.allSatisfy(\.isConfirmed))
        XCTAssertNotNil(record.lensSession)
        XCTAssertTrue(record.lensSession?.questions.contains { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } == true)
        XCTAssertNotNil(record.mainQuest)
        XCTAssertFalse(record.principles.isEmpty)
        XCTAssertTrue(store.todayLoopMessage.contains("本地 fallback"))
    }

    func testTodayAutomationIdentifiers_areStableForRenderedWalkthroughControls() {
        XCTAssertEqual(TodayAutomationID.primaryAction, "today.primary-action")
        XCTAssertEqual(TodayAutomationID.primaryActionHint, "today.primary-action-hint")
        XCTAssertEqual(TodayAutomationID.previousAction, "today.previous-action")
        XCTAssertEqual(TodayAutomationID.supplementCaptureAction, "today.supplement-capture-action")
        XCTAssertEqual(TodayAutomationID.returnToReviewForJudgmentAction, "today.return-to-review-for-judgment-action")
        XCTAssertEqual(TodayAutomationID.retryCurrentStepAction, "today.retry-current-step-action")
        XCTAssertEqual(TodayAutomationID.skipPrincipleAction, "today.skip-principle-action")
        XCTAssertEqual(TodayAutomationID.resetAction, "today.reset-action")
        XCTAssertEqual(TodayAutomationID.cardConfirmAction, "today.card.confirm-action")
        XCTAssertEqual(TodayAutomationID.cardExcludeAction, "today.card.exclude-action")
        XCTAssertEqual(TodayAutomationID.trainingPrescriptionAcceptAction, "today.training-prescription.accept-action")
        XCTAssertEqual(TodayAutomationID.trainingPrescriptionSkipAction, "today.training-prescription.skip-action")
        XCTAssertEqual(TodayAutomationID.trainingPrescriptionOverrideAudit, "today.training-prescription.override-audit")
        XCTAssertEqual(TodayAutomationID.trainingPrescriptionDecisionOverrideAudit, "today.training-prescription.decision-override-audit")
        XCTAssertEqual(TodayAutomationID.answerDiagnosisToggle, "today.answer.diagnosis-toggle")
        XCTAssertEqual(TodayAutomationID.answerTrainingToolsToggle, "today.answer.training-tools-toggle")
        XCTAssertEqual(TodayAutomationID.questionCoachBasisToggle, "today.question.coach-basis-toggle")
        XCTAssertEqual(TodayAutomationID.questionAnswerField, "today.question.answer-field")
        XCTAssertEqual(TodayAutomationID.loopBoundaryToggle, "today.loop-boundary-toggle")
        XCTAssertEqual(TodayAutomationID.questEditAction, "today.quest.edit-action")
        XCTAssertEqual(TodayAutomationID.questTrainingPrinciplePicker, "today.quest.training-principle-picker")
        XCTAssertEqual(TodayAutomationID.lensGenerateAction, "today.lens.generate-action")
        XCTAssertEqual(TodayAutomationID.lensCustomAction, "today.lens.custom-action")
        XCTAssertEqual(TodayAutomationID.principleFeedbackNoteField, "today.principle.feedback.note-field")
        XCTAssertEqual(TodayAutomationID.principleFeedbackHelpfulAction, "today.principle.feedback.helpful-action")
        XCTAssertEqual(TodayAutomationID.principleFeedbackNotApplicableAction, "today.principle.feedback.not-applicable-action")
        XCTAssertEqual(TodayAutomationID.principleFeedbackMisrecalledAction, "today.principle.feedback.misrecalled-action")
        XCTAssertEqual(TodayAutomationID.customLensSheet, "today.custom-lens.sheet")
        XCTAssertEqual(TodayAutomationID.customLensTitleField, "today.custom-lens.title-field")
        XCTAssertEqual(TodayAutomationID.customLensMethodField, "today.custom-lens.method-field")
        XCTAssertEqual(TodayAutomationID.customLensQuestionField, "today.custom-lens.question-field")
        XCTAssertEqual(TodayAutomationID.customLensSaveAction, "today.custom-lens.save-action")
        XCTAssertEqual(TodayAutomationID.state(.verifyYesterday), "today.state.verify_yesterday")
        XCTAssertEqual(TodayAutomationID.state(.capture), "today.state.capture")
        XCTAssertEqual(TodayAutomationID.state(.organizing), "today.state.organizing")
        XCTAssertEqual(TodayAutomationID.state(.reviewCards), "today.state.review_cards")
        XCTAssertEqual(TodayAutomationID.state(.selectMode), "today.state.select_mode")
        XCTAssertEqual(TodayAutomationID.state(.selectLens), "today.state.select_lens")
        XCTAssertEqual(TodayAutomationID.state(.answerQuestions), "today.state.answer_questions")
        XCTAssertEqual(TodayAutomationID.state(.reviewQuests), "today.state.review_quests")
        XCTAssertEqual(TodayAutomationID.state(.extractPrinciple), "today.state.extract_principle")
        XCTAssertEqual(TodayAutomationID.state(.sessionComplete), "today.state.session_complete")
        XCTAssertEqual(TodayAutomationID.lensAction(ThinkingLens.firstPrinciples.catalogItem), "today.lens.firstPrinciples-action")
        XCTAssertEqual(TodayAutomationID.lensAction(ThinkingLens.systemThinking.catalogItem), "today.lens.systemThinking-action")
        XCTAssertEqual(TodayAutomationID.lensAction(ThinkingLens.judgmentCalibration.catalogItem), "today.lens.judgmentCalibration-action")
    }

    func testSettingsAutomationIdentifiers_areStableForLensPackManager() {
        XCTAssertEqual(SettingsAutomationID.lensPackCard, "settings.lens-pack.card")
        XCTAssertEqual(SettingsAutomationID.lensPackRefreshAction, "settings.lens-pack.refresh-action")
        XCTAssertEqual(SettingsAutomationID.lensPackImportField, "settings.lens-pack.import-field")
        XCTAssertEqual(SettingsAutomationID.lensPackPasteAction, "settings.lens-pack.paste-action")
        XCTAssertEqual(SettingsAutomationID.lensPackImportAction, "settings.lens-pack.import-action")
        XCTAssertEqual(SettingsAutomationID.lensPackToggleAction(packId: "imported.roles.coach"), "settings.lens-pack.imported_roles_coach.toggle-action")
    }

    func testSettingsAutomationIdentifiers_areStableForPromptPackManager() {
        XCTAssertEqual(SettingsAutomationID.promptPackCard, "settings.prompt-pack.card")
        XCTAssertEqual(SettingsAutomationID.promptPackRefreshAction, "settings.prompt-pack.refresh-action")
        XCTAssertEqual(SettingsAutomationID.promptPackImportField, "settings.prompt-pack.import-field")
        XCTAssertEqual(SettingsAutomationID.promptPackPasteAction, "settings.prompt-pack.paste-action")
        XCTAssertEqual(SettingsAutomationID.promptPackImportAction, "settings.prompt-pack.import-action")
        XCTAssertEqual(SettingsAutomationID.promptPackToggleAction(packId: "imported.prompts.coach"), "settings.prompt-pack.imported_prompts_coach.toggle-action")
    }

    func testSettingsAutomationIdentifiers_areStableForAssetPackInstallManifest() {
        XCTAssertEqual(SettingsAutomationID.assetPackManifestCard, "settings.asset-pack-manifest.card")
        XCTAssertEqual(SettingsAutomationID.assetPackManifestImportField, "settings.asset-pack-manifest.import-field")
        XCTAssertEqual(SettingsAutomationID.assetPackManifestPasteAction, "settings.asset-pack-manifest.paste-action")
        XCTAssertEqual(SettingsAutomationID.assetPackManifestInstallAction, "settings.asset-pack-manifest.install-action")
        XCTAssertEqual(SettingsAutomationID.assetPackManifestRemoteURLField, "settings.asset-pack-manifest.remote-url-field")
        XCTAssertEqual(SettingsAutomationID.assetPackManifestRemoteInstallAction, "settings.asset-pack-manifest.remote-install-action")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistryCatalogURLField, "settings.asset-pack-registry.catalog-url-field")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistryCatalogFetchAction, "settings.asset-pack-registry.catalog-fetch-action")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistryCatalogEntryInstallAction(entryId: "marketplace.coach"), "settings.asset-pack-registry.marketplace_coach.install-action")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistrySubscriptionNameField, "settings.asset-pack-registry.subscription-name-field")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistrySubscriptionURLField, "settings.asset-pack-registry.subscription-url-field")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistrySubscriptionSaveAction, "settings.asset-pack-registry.subscription-save-action")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistrySubscriptionSyncAction, "settings.asset-pack-registry.subscription-sync-action")
        XCTAssertEqual(SettingsAutomationID.assetPackRegistrySubscriptionToggleAction(subscriptionId: "mingsi.registry.default"), "settings.asset-pack-registry.mingsi_registry_default.subscription-toggle-action")
        XCTAssertEqual(SettingsAutomationID.assetPackManifestMessage, "settings.asset-pack-manifest.message")
    }

    func testGrowthAutomationIdentifiers_areStableForPrinciplePracticeCorrection() {
        XCTAssertEqual(
            GrowthAutomationID.disputeLatestPracticeEvidenceAction(evidenceId: "practice.evidence/1"),
            "growth.principle-practice.practice_evidence_1.dispute-action"
        )
        XCTAssertEqual(
            GrowthAutomationID.disputedPracticeEvidenceAudit(evidenceId: "practice.evidence/1"),
            "growth.principle-practice.practice_evidence_1.disputed-audit"
        )
        XCTAssertEqual(
            GrowthAutomationID.negativeRecallFeedbackAudit(feedbackId: "recall.feedback/1"),
            "growth.principle-recall.recall_feedback_1.negative-audit"
        )
    }

    func testRunPromptEvalSuite_persistsRunsAndUpdatesReleaseGate() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let evalStore = AppStore(
            promptEvalRunRepository: evalRepo,
            refreshesAIServiceFromKeychain: false
        )

        await evalStore.loadRecentPromptEvalRuns()
        XCTAssertEqual(evalStore.promptEvalReleaseGate.status, .blocked)
        XCTAssertEqual(evalStore.promptEvalReleaseGate.missingPromptCount, PromptID.allCases.count)

        await evalStore.runPromptEvalSuite()

        XCTAssertEqual(evalStore.promptEvalReleaseGate.status, .passed)
        XCTAssertTrue(evalStore.promptEvalReleaseGate.canShipPromptAssets)
        XCTAssertEqual(evalStore.promptEvalReleaseGate.passedPromptCount, PromptID.allCases.count)
        XCTAssertEqual(evalStore.recentPromptEvalRuns.count, PromptID.allCases.count)
        XCTAssertTrue(evalStore.promptEvalMessage.contains("通过"))

        let persisted = try await evalRepo.recentEvalRuns(limit: 100)
        XCTAssertEqual(persisted.count, PromptID.allCases.count)
        XCTAssertTrue(persisted.allSatisfy { $0.status == .passed })
    }

    func testLoadPersistedState_runsScheduledPromptEvalWhenHistoryIsMissing() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let store = AppStore(
            promptEvalRunRepository: evalRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        XCTAssertEqual(store.recentPromptEvalRuns.count, PromptID.allCases.count)
        XCTAssertEqual(store.promptEvalReleaseGate.status, .passed)
        XCTAssertTrue(store.promptEvalMessage.contains("自动固定评测"))

        let persisted = try await evalRepo.recentEvalRuns(limit: 100)
        XCTAssertEqual(persisted.count, PromptID.allCases.count)
        XCTAssertTrue(persisted.allSatisfy { $0.status == .passed })
    }

    func testLoadPersistedState_skipsScheduledPromptEvalWhenHistoryIsFresh() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let existingRuns = PromptEvalRunner(promptProvider: LocalPromptProvider())
            .runFixedSuite(createdAt: .now)
        for run in existingRuns {
            try await evalRepo.saveEvalRun(run)
        }
        let store = AppStore(
            promptEvalRunRepository: evalRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        let persisted = try await evalRepo.recentEvalRuns(limit: 100)
        XCTAssertEqual(persisted.count, PromptID.allCases.count)
        XCTAssertEqual(Set(persisted.map(\.id)), Set(existingRuns.map(\.id)))
        XCTAssertEqual(store.promptEvalReleaseGate.status, .passed)
        XCTAssertFalse(store.promptEvalMessage.contains("自动固定评测"))
    }

    func testPromptEvalReleaseGateMessage_includesRollbackReadinessCounts() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let provider = AppStoreRollbackFixturePromptProvider()
        let template = provider.template(for: .generateQuestions, mode: .standard)
        try await evalRepo.saveEvalRun(PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: template.version,
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.current_failure", name: "Current failure", status: .failed)
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        ))
        let rollbackTemplate = try XCTUnwrap(
            provider.template(
                for: .generateQuestions,
                mode: .standard,
                version: template.rollbackTargetVersion ?? ""
            )
        )
        try await evalRepo.saveEvalRun(PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: rollbackTemplate.version,
            systemPolicyVersion: rollbackTemplate.systemPolicyVersion,
            contextPolicyVersion: rollbackTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: rollbackTemplate.outputSchemaVersion,
            evalSuiteVersion: rollbackTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.previous_pass", name: "Previous pass", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        ))
        let evalStore = AppStore(
            promptEvalRunRepository: evalRepo,
            promptProvider: provider,
            refreshesAIServiceFromKeychain: false
        )

        await evalStore.loadRecentPromptEvalRuns()

        XCTAssertEqual(evalStore.promptEvalReleaseGate.rollbackReadyCount, 1)
        XCTAssertTrue(evalStore.promptEvalMessage.contains("可回滚 1"))
        XCTAssertTrue(evalStore.promptEvalMessage.contains("需人工处理 \(PromptID.allCases.count - 1)"))
    }

    func testApplyPromptRollback_usesTargetTemplateAndRefreshesReleaseGate() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let provider = AppStoreExecutableRollbackFixturePromptProvider()
        let currentTemplate = provider.template(for: .generateQuestions, mode: .standard)
        try await evalRepo.saveEvalRun(PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: currentTemplate.version,
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.current_failure", name: "Current failure", status: .failed)
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        ))
        try await evalRepo.saveEvalRun(PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "0.9.0",
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.previous_pass", name: "Previous pass", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        ))
        for promptID in PromptID.allCases where promptID != .generateQuestions {
            let template = provider.template(for: promptID, mode: .standard)
            try await evalRepo.saveEvalRun(PromptEvalRun(
                promptId: promptID.rawValue,
                promptVersion: template.version,
                systemPolicyVersion: template.systemPolicyVersion,
                contextPolicyVersion: template.contextPolicyVersion,
                inputSchemaVersion: 1,
                outputSchemaVersion: template.outputSchemaVersion,
                evalSuiteVersion: template.evalSuiteVersion,
                runnerVersion: PromptEvalRunner.currentRunnerVersion,
                caseResults: [
                    PromptEvalCaseResult(caseId: "\(promptID.rawValue).pass", name: "\(promptID.displayName) pass", status: .passed)
                ],
                createdAt: Date(timeIntervalSince1970: 250)
            ))
        }
        let evalStore = AppStore(
            promptEvalRunRepository: evalRepo,
            promptProvider: provider,
            refreshesAIServiceFromKeychain: false
        )
        await evalStore.loadRecentPromptEvalRuns()
        let candidate = try XCTUnwrap(evalStore.promptEvalReleaseGate.rollbackCandidates.first)

        let didRollback = await evalStore.applyPromptRollback(candidate)

        XCTAssertTrue(didRollback)
        XCTAssertEqual(evalStore.promptTemplate(for: .generateQuestions, mode: .standard).version, "0.9.0")
        XCTAssertEqual(evalStore.promptEvalReleaseGate.status, .passed)
        XCTAssertTrue(evalStore.promptEvalMessage.contains("已回滚"))
    }

    func testApplyPromptRollback_persistsSelectedVersionAcrossStoreReload() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let selectionRepo = SQLitePromptAssetSelectionRepository(database: database)
        let provider = AppStoreExecutableRollbackFixturePromptProvider()
        let currentTemplate = provider.template(for: .generateQuestions, mode: .standard)
        try await evalRepo.saveEvalRun(PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: currentTemplate.version,
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.current_failure", name: "Current failure", status: .failed)
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        ))
        try await evalRepo.saveEvalRun(PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "0.9.0",
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.previous_pass", name: "Previous pass", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        ))
        for promptID in PromptID.allCases where promptID != .generateQuestions {
            let template = provider.template(for: promptID, mode: .standard)
            try await evalRepo.saveEvalRun(PromptEvalRun(
                promptId: promptID.rawValue,
                promptVersion: template.version,
                systemPolicyVersion: template.systemPolicyVersion,
                contextPolicyVersion: template.contextPolicyVersion,
                inputSchemaVersion: 1,
                outputSchemaVersion: template.outputSchemaVersion,
                evalSuiteVersion: template.evalSuiteVersion,
                runnerVersion: PromptEvalRunner.currentRunnerVersion,
                caseResults: [
                    PromptEvalCaseResult(caseId: "\(promptID.rawValue).pass", name: "\(promptID.displayName) pass", status: .passed)
                ],
                createdAt: Date(timeIntervalSince1970: 250)
            ))
        }
        let initialStore = AppStore(
            promptEvalRunRepository: evalRepo,
            promptAssetSelectionRepository: selectionRepo,
            promptProvider: provider,
            refreshesAIServiceFromKeychain: false
        )
        await initialStore.loadRecentPromptEvalRuns()
        let candidate = try XCTUnwrap(initialStore.promptEvalReleaseGate.rollbackCandidates.first)

        let didRollback = await initialStore.applyPromptRollback(candidate)
        XCTAssertTrue(didRollback)

        let restoredStore = AppStore(
            promptEvalRunRepository: evalRepo,
            promptAssetSelectionRepository: selectionRepo,
            promptProvider: provider,
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()
        await restoredStore.loadRecentPromptEvalRuns()

        XCTAssertEqual(restoredStore.promptTemplate(for: .generateQuestions, mode: .standard).version, "0.9.0")
        XCTAssertEqual(restoredStore.promptEvalReleaseGate.status, .passed)
    }

    func testLoadPersistedState_restoresHistoricalPromptAssetSelectionWithLocalProvider() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let selectionRepo = SQLitePromptAssetSelectionRepository(database: database)
        try await selectionRepo.saveSelection(PromptAssetSelection(
            promptId: .generateQuestions,
            selectedVersion: "0.9.0",
            baseVersion: "1.0.0",
            reason: .rollback
        ))

        let restoredStore = AppStore(
            promptAssetSelectionRepository: selectionRepo,
            promptProvider: LocalPromptProvider(),
            refreshesAIServiceFromKeychain: false
        )
        await restoredStore.loadPersistedState()

        XCTAssertEqual(restoredStore.promptTemplate(for: .generateQuestions, mode: .standard).version, "0.9.0")

        await restoredStore.runPromptEvalSuite()

        let restoredRun = try XCTUnwrap(restoredStore.recentPromptEvalRuns.first {
            $0.promptId == PromptID.generateQuestions.rawValue
        })
        XCTAssertEqual(restoredRun.promptVersion, "0.9.0")
        XCTAssertEqual(restoredRun.status, .passed)
    }

    // MARK: - Visual QA Direct Entry

    func testVisualQAProjectDetailFixture_hasDirectEntryProjectID() {
        let fixtureStore = AppStore.visualQAProjectDetail()
        let directEntryID = fixtureStore.visualQAProjectDetailDirectEntryProjectID
        XCTAssertNotNil(directEntryID, "Fixture store must expose a non-nil direct-entry project id")
    }

    func testVisualQAProjectDetailFixture_directEntryID_existsInProjectsById() {
        let fixtureStore = AppStore.visualQAProjectDetail()
        let directEntryID = fixtureStore.visualQAProjectDetailDirectEntryProjectID!
        XCTAssertNotNil(
            fixtureStore.projectsById[directEntryID],
            "Direct-entry project id must exist in projectsById"
        )
    }

    func testNormalStore_hasNoDirectEntryProjectID() {
        let normalStore = AppStore(refreshesAIServiceFromKeychain: false)
        XCTAssertNil(
            normalStore.visualQAProjectDetailDirectEntryProjectID,
            "Normal store must not have a direct-entry project id"
        )
    }

    func testApplyVisualQAProjectDetailFixture_preservesDirectEntryProjectID() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)
        XCTAssertNil(store.visualQAProjectDetailDirectEntryProjectID)

        store.applyVisualQAProjectDetailFixture()

        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID
        XCTAssertNotNil(directEntryID, "applyVisualQAProjectDetailFixture must preserve direct-entry id")
        XCTAssertNotNil(
            store.projectsById[directEntryID!],
            "Direct-entry project id must exist in projectsById after apply"
        )
    }

    // MARK: - Project Candidate Flows

    func testSuggestProjects_persistsPendingCandidatesWithSourceRefs() async throws {
        let candidateRepo = InMemoryProjectCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()
        let entryID = store.todayDraft.id
        let cardID = UUID()
        store.thinkingCards = [
            ThinkingCard(id: cardID, type: .problem, title: "接口归属不清", body: "负责人未明确", isConfirmed: true)
        ]

        let client = RecordingLLMClient(response: Self.projectSuggestionsResponse(
            entryID: entryID,
            cardID: cardID
        ))
        let projectAIService = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.thinkingCards = [
            ThinkingCard(id: cardID, type: .problem, title: "接口归属不清", body: "负责人未明确", isConfirmed: true)
        ]

        await store.suggestProjectsForToday(projectAIService: projectAIService)

        let pending = try await candidateRepo.pendingCandidates()
        XCTAssertTrue(store.isGeneratingProjectSuggestions == false)
        XCTAssertGreaterThanOrEqual(pending.count, 1)
        if let candidate = pending.first {
            XCTAssertFalse(candidate.sourceRefs.isEmpty)
            XCTAssertEqual(candidate.status, .pending)
        }
    }

    func testAcceptProjectCandidate_createsProjectAndConfirmedLink() async throws {
        let candidateRepo = InMemoryProjectCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()
        let sourceRef = UUID()

        let candidate = ProjectCandidate(
            suggestedName: "接口归属确认",
            reason: "反复出现接口归属不清的讨论",
            sourceRefs: [sourceRef.uuidString],
            confidence: 0.85
        )
        try await candidateRepo.saveCandidate(candidate)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.thinkingCards = [
            ThinkingCard(id: sourceRef, type: .problem, title: "接口归属不清", body: "负责人未明确", isConfirmed: true)
        ]

        await store.acceptProjectCandidate(candidate)

        let updatedCandidate = try await candidateRepo.candidate(id: candidate.id)
        XCTAssertEqual(updatedCandidate?.status, .accepted)
        XCTAssertNotNil(updatedCandidate?.acceptedProjectId)

        let savedProject = try await projectRepo.project(id: updatedCandidate!.acceptedProjectId!)
        XCTAssertNotNil(savedProject)
        XCTAssertEqual(savedProject?.name, "接口归属确认")
        XCTAssertEqual(savedProject?.createdBy, .aiSuggested)

        let links = try await linkRepo.links(for: updatedCandidate!.acceptedProjectId!)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].sourceType, .thinkingCard)
        XCTAssertEqual(links[0].sourceId, sourceRef.uuidString)
        XCTAssertTrue(links[0].isUserConfirmed)
    }

    func testDismissCandidate_updatesStatusAndDoesNotCreateProject() async throws {
        let candidateRepo = InMemoryProjectCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let candidate = ProjectCandidate(
            suggestedName: "接口归属确认",
            reason: "反复出现接口归属不清的讨论",
            sourceRefs: [UUID().uuidString],
            confidence: 0.85
        )
        try await candidateRepo.saveCandidate(candidate)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.dismissProjectCandidate(candidate)

        let updated = try await candidateRepo.candidate(id: candidate.id)
        XCTAssertEqual(updated?.status, .dismissed)

        let allProjects = await projectRepo.allProjects()
        XCTAssertTrue(allProjects.isEmpty)
    }

    func testLoadPersistedState_restoresOnlyPendingProjectCandidates() async throws {
        let dailyRepo = InMemoryDailyEntryRepository()
        let candidateRepo = InMemoryProjectCandidateRepository()
        let draft = DailyEntryDraft(rawText: "今天确认了接口归属问题。", state: .sessionComplete)
        try await dailyRepo.saveDraft(draft)

        let pending = ProjectCandidate(
            suggestedName: "接口归属确认",
            reason: "反复出现接口归属不清的讨论",
            sourceRefs: [UUID().uuidString],
            status: .pending
        )
        let dismissed = ProjectCandidate(
            suggestedName: "已忽略候选",
            reason: "用户已经忽略",
            sourceRefs: [UUID().uuidString],
            status: .dismissed
        )
        try await candidateRepo.saveCandidate(pending)
        try await candidateRepo.saveCandidate(dismissed)

        store = AppStore(
            dailyEntryRepository: dailyRepo,
            projectCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        XCTAssertEqual(store.projectCandidates.map(\.id), [pending.id])
        XCTAssertEqual(store.pendingProjectCandidateCount, 1)
    }

    func testAcceptProjectLinkCandidate_createsConfirmedLinkToExistingProject() async throws {
        let candidateRepo = InMemoryProjectCandidateRepository()
        let projectRepo = InMemoryProjectRepository()
        let linkRepo = InMemoryProjectLinkRepository()

        let existingProject = Project(name: "接口归属确认", goal: "确认接口归属", successCriteria: "写出负责人和验收方式")
        try await projectRepo.saveProject(existingProject)

        let sourceID = UUID().uuidString
        let linkCandidate = ProjectLinkCandidate(
            projectId: existingProject.id,
            sourceType: .thinkingCard,
            sourceId: sourceID,
            linkType: .evidence,
            reason: "接口归属不清与项目目标相关",
            confidence: 0.82,
            requiresUserConfirmation: true
        )

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: candidateRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.acceptProjectLinkCandidate(linkCandidate)

        let links = try await linkRepo.links(for: existingProject.id)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].projectId, existingProject.id)
        XCTAssertEqual(links[0].sourceId, sourceID)
        XCTAssertTrue(links[0].isUserConfirmed)
    }

    // MARK: - Project Insight Generation

    func testGenerateProjectInsights_withSufficientEvidence_savesCandidatesAndPublishesState() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let insightRepo = SQLiteProjectInsightRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let linkRepo = SQLiteProjectLinkRepository(database: database)

        let projectID = UUID()
        let cardID = UUID()
        let questID = UUID()

        let project = Project(id: projectID, name: "接口归属确认", goal: "确认接口归属", successCriteria: "写出负责人和验收方式")
        try await projectRepo.saveProject(project)

        let cardLink = ProjectLink(projectId: projectID, sourceType: .thinkingCard, sourceId: cardID.uuidString, linkType: .evidence, isUserConfirmed: true)
        let questLink = ProjectLink(projectId: projectID, sourceType: .quest, sourceId: questID.uuidString, linkType: .evidence, isUserConfirmed: true)
        try await linkRepo.saveLink(cardLink)
        try await linkRepo.saveLink(questLink)

        let client = RecordingLLMClient(response: Self.projectInsightsResponse(projectID: projectID, cardID: cardID, questID: questID))
        let projectAIService = ProjectAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: nil,
            projectInsightRepository: insightRepo,
            refreshesAIServiceFromKeychain: false
        )
        let draft = DailyEntryDraft(rawText: "接口归属仍然不清，明天需要明确负责人和验收方式。", state: .sessionComplete)
        let card = ThinkingCard(id: cardID, type: .problem, title: "接口归属不清", body: "会议后仍无明确负责人。", isConfirmed: true)
        let quest = Quest(
            id: questID,
            type: .main,
            title: "确认接口归属",
            whyItMatters: "减少后续返工。",
            completionCriteria: "写出负责人和验收方式",
            expectedResistance: "信息不完整。",
            reflectionQuestion: "哪些归属仍然没有被确认？",
            status: .active
        )
        store.historyRecords = [
            HistoryRecord(
                draft: draft,
                cards: [card],
                quests: [quest],
                principles: [],
                verification: nil,
                lensSession: nil,
                projectLinks: [cardLink, questLink],
                growthContributions: []
            )
        ]

        await store.generateProjectInsights(for: projectID, projectAIService: projectAIService)

        try await Task.sleep(for: .milliseconds(300))

        let insights = try await insightRepo.insights(for: projectID)
        XCTAssertEqual(insights.count, 2)
        XCTAssertEqual(insights[0].userFeedback, .none)
        XCTAssertEqual(insights[0].sourceRefs, [cardID.uuidString])
        XCTAssertEqual(insights[1].sourceRefs, [questID.uuidString])

        XCTAssertEqual(store.pendingProjectInsights.count, 2)
        XCTAssertEqual(store.acceptedProjectInsights.count, 0)
    }

    func testGenerateProjectInsights_dropsWrongProjectAndUnresolvedSourceRefs() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let insightRepo = SQLiteProjectInsightRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let linkRepo = SQLiteProjectLinkRepository(database: database)

        let projectID = UUID()
        let cardID = UUID()
        let unconfirmedCardID = UUID()

        let project = Project(id: projectID, name: "接口归属确认", goal: "确认接口归属", successCriteria: "写出负责人和验收方式")
        try await projectRepo.saveProject(project)

        let confirmedLink = ProjectLink(projectId: projectID, sourceType: .thinkingCard, sourceId: cardID.uuidString, linkType: .evidence, isUserConfirmed: true)
        let unconfirmedLink = ProjectLink(projectId: projectID, sourceType: .thinkingCard, sourceId: unconfirmedCardID.uuidString, linkType: .evidence, isUserConfirmed: false)
        try await linkRepo.saveLink(confirmedLink)
        try await linkRepo.saveLink(unconfirmedLink)

        let client = RecordingLLMClient(response: Self.projectInsightsWithInvalidCandidatesResponse(
            projectID: projectID,
            validCardID: cardID,
            unconfirmedCardID: unconfirmedCardID
        ))
        let projectAIService = ProjectAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: nil,
            projectInsightRepository: insightRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.historyRecords = [
            HistoryRecord(
                draft: DailyEntryDraft(rawText: "接口归属仍然不清。", state: .sessionComplete),
                cards: [
                    ThinkingCard(id: cardID, type: .problem, title: "接口归属不清", body: "会议后仍无明确负责人。", isConfirmed: true),
                    ThinkingCard(id: unconfirmedCardID, type: .problem, title: "未确认证据", body: "不应作为洞察来源。", isConfirmed: true)
                ],
                quests: [],
                principles: [],
                verification: nil,
                lensSession: nil,
                projectLinks: [confirmedLink, unconfirmedLink],
                growthContributions: []
            )
        ]

        await store.generateProjectInsights(for: projectID, projectAIService: projectAIService)

        try await Task.sleep(for: .milliseconds(300))

        let insights = try await insightRepo.insights(for: projectID)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.title, "合法洞察")
        XCTAssertEqual(insights.first?.sourceRefs, [cardID.uuidString])
        XCTAssertEqual(store.pendingProjectInsights.map(\.title), ["合法洞察"])
    }

    func testGenerateProjectInsights_withInsufficientEvidence_savesNoneAndShowsMessage() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let insightRepo = SQLiteProjectInsightRepository(database: database)
        let projectRepo = SQLiteProjectRepository(database: database)
        let linkRepo = SQLiteProjectLinkRepository(database: database)

        let projectID = UUID()
        let cardID = UUID()
        let project = Project(id: projectID, name: "新项目", goal: "测试目标", successCriteria: "完成")
        try await projectRepo.saveProject(project)
        let link = ProjectLink(projectId: projectID, sourceType: .thinkingCard, sourceId: cardID.uuidString, linkType: .evidence, isUserConfirmed: true)
        try await linkRepo.saveLink(link)

        let client = RecordingLLMClient(response: Self.insufficientEvidenceResponse())
        let projectAIService = ProjectAIService(promptProvider: LocalPromptProvider(), llmClient: client)

        store = AppStore(
            projectLinkRepository: linkRepo,
            projectRepository: projectRepo,
            projectCandidateRepository: nil,
            projectInsightRepository: insightRepo,
            refreshesAIServiceFromKeychain: false
        )
        store.historyRecords = [
            HistoryRecord(
                draft: DailyEntryDraft(rawText: "只有一条新项目证据。", state: .sessionComplete),
                cards: [
                    ThinkingCard(id: cardID, type: .problem, title: "新项目证据不足", body: "目前只有单次记录。", isConfirmed: true)
                ],
                quests: [],
                principles: [],
                verification: nil,
                lensSession: nil,
                projectLinks: [link],
                growthContributions: []
            )
        ]

        await store.generateProjectInsights(for: projectID, projectAIService: projectAIService)

        try await Task.sleep(for: .milliseconds(300))

        let insights = try await insightRepo.insights(for: projectID)
        XCTAssertTrue(insights.isEmpty)

        XCTAssertEqual(store.pendingProjectInsights.count, 0)
        XCTAssertTrue(store.projectInsightGenerationMessage.contains("证据不足"))
    }

    func testAcceptProjectInsight_updatesFeedbackToAcceptedAndKeepsVisible() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let insightRepo = SQLiteProjectInsightRepository(database: database)

        let insightID = UUID()
        let projectID = UUID()
        let insight = ProjectInsight(
            id: insightID,
            projectId: projectID,
            insightType: .progress,
            title: "进展良好",
            summary: "进展良好",
            sourceRefs: ["card-123"],
            userFeedback: .none
        )
        try await insightRepo.saveInsight(insight)

        store = AppStore(
            projectInsightRepository: insightRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadProjectInsights(for: projectID)
        XCTAssertEqual(store.pendingProjectInsights.count, 1)

        await store.submitProjectInsightFeedback(.accepted, for: insightID)

        try await Task.sleep(for: .milliseconds(150))

        let allInsights = try await insightRepo.insights(for: projectID)
        let updated = allInsights.first(where: { $0.id == insightID })
        XCTAssertEqual(updated?.userFeedback, .accepted)

        XCTAssertEqual(store.pendingProjectInsights.count, 0)
        XCTAssertEqual(store.acceptedProjectInsights.count, 1)
    }

    func testMarkInaccurateProjectInsight_removesFromAcceptedNarrative() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let insightRepo = SQLiteProjectInsightRepository(database: database)

        let insightID = UUID()
        let projectID = UUID()
        let insight = ProjectInsight(
            id: insightID,
            projectId: projectID,
            insightType: .blockerChange,
            title: "阻塞已解决",
            summary: "阻塞已解决",
            beforeText: "接口归属不清导致推进卡住。",
            afterText: "负责人已明确，阻塞转为验收文档补齐。",
            sourceRefs: ["card-456"],
            userFeedback: .accepted
        )
        try await insightRepo.saveInsight(insight)

        store = AppStore(
            projectInsightRepository: insightRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadProjectInsights(for: projectID)
        XCTAssertEqual(store.acceptedProjectInsights.count, 1)

        await store.submitProjectInsightFeedback(.inaccurate, for: insightID)

        try await Task.sleep(for: .milliseconds(150))

        let allInsights = try await insightRepo.insights(for: projectID)
        let updated = allInsights.first(where: { $0.id == insightID })
        XCTAssertEqual(updated?.userFeedback, .inaccurate)

        XCTAssertEqual(store.acceptedProjectInsights.count, 0)
    }

    func testDismissProjectInsight_removesFromBothPendingAndAccepted() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let insightRepo = SQLiteProjectInsightRepository(database: database)

        let insightID = UUID()
        let projectID = UUID()
        let insight = ProjectInsight(
            id: insightID,
            projectId: projectID,
            insightType: .openQuestionClosed,
            title: "问题已关闭",
            summary: "问题已关闭",
            sourceRefs: ["quest-789"],
            userFeedback: .none
        )
        try await insightRepo.saveInsight(insight)

        store = AppStore(
            projectInsightRepository: insightRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadProjectInsights(for: projectID)
        XCTAssertEqual(store.pendingProjectInsights.count, 1)

        await store.submitProjectInsightFeedback(.dismissed, for: insightID)

        try await Task.sleep(for: .milliseconds(150))

        let allInsights = try await insightRepo.insights(for: projectID)
        let updated = allInsights.first(where: { $0.id == insightID })
        XCTAssertEqual(updated?.userFeedback, .dismissed)

        XCTAssertEqual(store.pendingProjectInsights.count, 0)
        XCTAssertEqual(store.acceptedProjectInsights.count, 0)
    }

    private static func projectInsightsResponse(projectID: UUID, cardID: UUID, questID: UUID) -> Data {
        Data(
            """
            {
              "insights": [
                {
                  "project_id": "\(projectID.uuidString)",
                  "insight_type": "progress",
                  "title": "进展顺利",
                  "summary": "接口归属逐步明确，从模糊到具体",
                  "source_refs": ["\(cardID.uuidString)"],
                  "confidence": "0.8"
                },
                {
                  "project_id": "\(projectID.uuidString)",
                  "insight_type": "thinking_change",
                  "title": "思考方式转变",
                  "summary": "从被动等待会议到主动会前准备",
                  "before": {
                    "text": "之前依赖会议讨论决定归属",
                    "source_type": "quest",
                    "source_id": "\(questID.uuidString)"
                  },
                  "after": {
                    "text": "现在会前列出必须确认的问题",
                    "source_type": "quest",
                    "source_id": "\(questID.uuidString)"
                  },
                  "source_refs": ["\(questID.uuidString)"],
                  "confidence": "0.85"
                }
              ],
              "insufficient_evidence_reason": null
            }
            """.utf8
        )
    }

    private static func projectInsightsWithInvalidCandidatesResponse(projectID: UUID, validCardID: UUID, unconfirmedCardID: UUID) -> Data {
        Data(
            """
            {
              "insights": [
                {
                  "project_id": "\(UUID().uuidString)",
                  "insight_type": "progress",
                  "title": "错误项目",
                  "summary": "不应保存到当前项目。",
                  "source_refs": ["\(validCardID.uuidString)"],
                  "confidence": "0.8"
                },
                {
                  "project_id": "\(projectID.uuidString)",
                  "insight_type": "progress",
                  "title": "未确认来源",
                  "summary": "不应保存未确认项目链接的来源。",
                  "source_refs": ["\(unconfirmedCardID.uuidString)"],
                  "confidence": "0.8"
                },
                {
                  "project_id": "\(projectID.uuidString)",
                  "insight_type": "progress",
                  "title": "合法洞察",
                  "summary": "来源属于当前项目且已确认。",
                  "source_refs": ["\(validCardID.uuidString)"],
                  "confidence": "0.8"
                }
              ],
              "insufficient_evidence_reason": null
            }
            """.utf8
        )
    }

    private static func insufficientEvidenceResponse() -> Data {
        Data(
            """
            {
              "insights": [],
              "insufficient_evidence_reason": "该项目确认的证据不足3条，无法生成可靠的洞察。"
            }
            """.utf8
        )
    }

    private static func projectSuggestionsResponse(entryID: UUID, cardID: UUID) -> Data {
        Data(
            """
            {
              "project_link_candidates": [],
              "new_project_candidates": [
                {
                  "name": "接口归属确认",
                  "goal": "确认每个接口的负责人和验收标准",
                  "success_criteria": "所有争议接口有明确归属",
                  "current_bottleneck": "会前没有确认接口归属",
                  "why_this_is_long_running": "接口归属不清反复出现在多次复盘中",
                  "reason": "多次复盘涉及接口归属不清的问题",
                  "source_ids": ["\(cardID.uuidString)"],
                  "source_refs": [],
                  "privacy_safe_name_required": false,
                  "confidence": "high"
                }
              ]
            }
            """.utf8
        )
    }

    private static func growthReportResponse(entryID: UUID, sourceID: String) -> Data {
        Data(
            """
            {
              "insufficient_evidence": false,
              "summary": "AI weekly growth summary",
              "metrics": {
                "clarity": {
                  "value": 3.7,
                  "delta": 0.2,
                  "reason": "The user made the main task more explicit."
                }
              },
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.2,
                  "title": "Clear completion criteria",
                  "reason": "The quest had visible completion evidence.",
                  "source_type": "quest",
                  "source_id": "\(sourceID)",
                  "source_daily_entry_id": "\(entryID.uuidString)"
                }
              ],
              "next_training_focus": "Keep making the completion evidence explicit."
            }
            """.utf8
        )
    }
}

private final class SequencedLLMClient: LLMClient {
    enum Result {
        case success(Data)
        case failure(Error)
    }

    private var results: [Result]
    private(set) var requests: [LLMRequest] = []

    init(results: [Result]) {
        self.results = results
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        guard !results.isEmpty else {
            throw LLMClientError.invalidResponse
        }

        switch results.removeFirst() {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}

private final class SuspendingLLMClient: LLMClient {
    private let response: Data
    private var continuations: [CheckedContinuation<Data, Error>] = []
    private(set) var completeCallCount = 0

    init(response: Data) {
        self.response = response
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        completeCallCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func release() {
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume(returning: response)
        }
    }
}

private final class RecordingLLMClient: LLMClient {
    private let response: Data
    private(set) var requests: [LLMRequest] = []

    init(response: Data) {
        self.response = response
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        return response
    }
}

private final class FakeAssetPackInstallManifestFetcher: AssetPackInstallManifestFetching {
    private let dataByURL: [URL: Data]
    private let errorByURL: [URL: Error]
    private let error: Error?
    private(set) var requestedURLs: [URL] = []

    init(
        dataByURL: [URL: Data] = [:],
        errorByURL: [URL: Error] = [:],
        error: Error? = nil
    ) {
        self.dataByURL = dataByURL
        self.errorByURL = errorByURL
        self.error = error
    }

    func fetchInstallManifestData(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        if let error = errorByURL[url] {
            throw error
        }
        if let error {
            throw error
        }
        guard let data = dataByURL[url] else {
            throw URLError(.resourceUnavailable)
        }
        return data
    }

    func fetchTrustPolicyData(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        if let error = errorByURL[url] {
            throw error
        }
        if let error {
            throw error
        }
        guard let data = dataByURL[url] else {
            throw URLError(.resourceUnavailable)
        }
        return data
    }

    func fetchRegistryCatalogData(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        if let error = errorByURL[url] {
            throw error
        }
        if let error {
            throw error
        }
        guard let data = dataByURL[url] else {
            throw URLError(.resourceUnavailable)
        }
        return data
    }
}

private final class InMemoryDailyEntryRepository: DailyEntryRepository {
    private var drafts: [UUID: DailyEntryDraft] = [:]

    func saveDraft(_ draft: DailyEntryDraft) async throws {
        drafts[draft.id] = draft
    }

    func latestDraft() async throws -> DailyEntryDraft? {
        sortedDrafts().first
    }

    func recentEntries(limit: Int) async throws -> [DailyEntryDraft] {
        sortedDrafts().prefix(limit).reduce(into: [DailyEntryDraft]()) { result, draft in
            result.append(draft)
        }
    }

    private func sortedDrafts() -> [DailyEntryDraft] {
        var values = drafts.reduce(into: [DailyEntryDraft]()) { result, pair in
            result.append(pair.value)
        }
        values.sort(by: { (lhs: DailyEntryDraft, rhs: DailyEntryDraft) -> Bool in
            lhs.date > rhs.date
        })
        return values
    }
}

private final class StreamingRecordingLLMClient: LLMClient, StreamingLLMClient {
    private let tokens: [String]

    init(tokens: [String]) {
        self.tokens = tokens
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(.token(token))
            }
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}

private final class QuestionFailingStreamingLLMClient: LLMClient, StreamingLLMClient {
    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            switch request.prompt.id {
            case .organizeCards:
                continuation.yield(
                    .token(
                        "<MINGSI_STREAM version=\"1\"><CARD><TYPE>fact</TYPE><TITLE>Meeting ownership unclear</TITLE><BODY>The meeting ended without a written owner.</BODY><IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>Confirmed source material</REASON></CARD></MINGSI_STREAM>"
                    )
                )
                continuation.yield(.completed)
                continuation.finish()
            case .generateQuestions:
                continuation.yield(.token(#"{"questions":[{"question":"先补上一个可观察事实"}]}"#))
                continuation.finish(throwing: LLMClientError.transport(URLError(.networkConnectionLost)))
            default:
                continuation.finish(throwing: LLMClientError.invalidResponse)
            }
        }
    }
}

private final class SuspendedStreamingLLMClient: LLMClient, StreamingLLMClient {
    private let firstToken: String
    private let remainingTokens: [String]
    private let streamState = SuspendedStreamingState()

    init(firstToken: String, remainingTokens: [String]) {
        self.firstToken = firstToken
        self.remainingTokens = remainingTokens
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await streamState.store(continuation)
                continuation.yield(.token(firstToken))
            }
        }
    }

    func releaseRemaining() async {
        guard let continuation = await streamState.take() else { return }
        for token in remainingTokens {
            continuation.yield(.token(token))
        }
        continuation.yield(.completed)
        continuation.finish()
    }
}

private actor SuspendedStreamingState {
    private var continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation?

    func store(_ continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation) {
        self.continuation = continuation
    }

    func take() -> AsyncThrowingStream<LLMStreamEvent, Error>.Continuation? {
        let value = continuation
        continuation = nil
        return value
    }
}

private final class CountingStreamingLLMClient: LLMClient, StreamingLLMClient {
    private let tokens: [String]
    private(set) var streamCallCount = 0

    init(tokens: [String]) {
        self.tokens = tokens
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        streamCallCount += 1
        return AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(.token(token))
            }
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}

private final class RecordingReminderService: ReminderService {
    private let permission: ReminderPermissionStatus
    private(set) var permissionRequestCount = 0
    private(set) var scheduledRequests: [ReminderRequest] = []
    private(set) var cancelledIDs: [String] = []

    init(permission: ReminderPermissionStatus) {
        self.permission = permission
    }

    func requestPermission() async throws -> ReminderPermissionStatus {
        permissionRequestCount += 1
        return permission
    }

    func schedule(_ request: ReminderRequest) async throws {
        scheduledRequests.append(request)
    }

    func cancel(id: String) async {
        cancelledIDs.append(id)
    }
}

private final class InMemoryProjectCandidateRepository: ProjectCandidateRepository {
    private var candidates: [UUID: ProjectCandidate] = [:]

    func saveCandidate(_ candidate: ProjectCandidate) async throws {
        candidates[candidate.id] = candidate
    }

    func candidate(id: UUID) async throws -> ProjectCandidate? {
        candidates[id]
    }

    func pendingCandidates() async throws -> [ProjectCandidate] {
        candidates.values.filter { $0.status == .pending }
    }

    func updateCandidateStatus(_ status: ProjectCandidateStatus, candidateId: UUID) async throws {
        candidates[candidateId]?.status = status
    }
}

private final class InMemoryHistoricalRetryCandidateRepository: HistoricalRetryCandidateRepository {
    private var candidates: [UUID: HistoricalRetryCandidate] = [:]

    func saveCandidate(_ candidate: HistoricalRetryCandidate) async throws {
        candidates[candidate.id] = candidate
    }

    func candidate(id: UUID) async throws -> HistoricalRetryCandidate? {
        candidates[id]
    }

    func candidates(for sourceDailyEntryId: UUID) async throws -> [HistoricalRetryCandidate] {
        candidates.values
            .filter { $0.sourceDailyEntryId == sourceDailyEntryId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func attachRepairRun(_ repairPromptRunId: UUID, candidatePayloadJSON: String, to candidateId: UUID) async throws {
        guard var candidate = candidates[candidateId] else { return }
        candidate.repairPromptRunId = repairPromptRunId
        candidate.candidatePayloadJSON = candidatePayloadJSON
        candidate.status = .candidateReady
        candidate.error = nil
        candidate.blockedReason = nil
        candidate.updatedAt = .now
        candidates[candidateId] = candidate
    }

    func updateStatus(
        _ status: HistoricalRetryCandidateStatus,
        candidateId: UUID,
        error: String?,
        blockedReason: String?
    ) async throws {
        guard var candidate = candidates[candidateId] else { return }
        candidate.status = status
        candidate.error = error
        candidate.blockedReason = blockedReason
        candidate.updatedAt = .now
        candidates[candidateId] = candidate
    }

    func softDelete(candidateId: UUID) async throws {
        candidates.removeValue(forKey: candidateId)
    }
}

private final class InMemoryProjectRepository: ProjectRepository {
    private var projects: [UUID: Project] = [:]

    func saveProject(_ project: Project) async throws {
        projects[project.id] = project
    }

    func project(id: UUID) async throws -> Project? {
        projects[id]
    }

    func activeProjects() async throws -> [Project] {
        projects.values.filter { $0.status == .active }
    }

    func allProjects() async -> [Project] {
        Array(projects.values)
    }
}

private final class InMemoryProjectLinkRepository: ProjectLinkRepository {
    private var links: [ProjectLink] = []

    func saveLink(_ link: ProjectLink) async throws {
        links.append(link)
    }

    func links(for projectId: UUID) async throws -> [ProjectLink] {
        links.filter { $0.projectId == projectId }
    }

    func links(forSourceIds sourceIds: [String]) async throws -> [ProjectLink] {
        links.filter { sourceIds.contains($0.sourceId) }
    }

    func updateLinkConfirmation(_ isConfirmed: Bool, linkId: UUID) async throws {
        for i in links.indices where links[i].id == linkId {
            links[i] = ProjectLink(
                id: links[i].id,
                projectId: links[i].projectId,
                sourceType: links[i].sourceType,
                sourceId: links[i].sourceId,
                linkType: links[i].linkType,
                confidence: links[i].confidence,
                isUserConfirmed: isConfirmed,
                createdAt: links[i].createdAt,
                updatedAt: links[i].updatedAt
            )
        }
    }
}

// MARK: - InMemoryProjectMergeCandidateRepository

private final class InMemoryProjectMergeCandidateRepository: ProjectMergeCandidateRepository {
    private var candidates: [UUID: ProjectMergeCandidate] = [:]

    func saveMergeCandidate(_ candidate: ProjectMergeCandidate) async throws {
        candidates[candidate.id] = candidate
    }

    func mergeCandidate(id: UUID) async throws -> ProjectMergeCandidate? {
        candidates[id]
    }

    func pendingMergeCandidates() async throws -> [ProjectMergeCandidate] {
        candidates.values.filter { $0.status == .pending }
    }

    func updateMergeCandidateStatus(_ status: ProjectMergeStatus, candidateId: UUID) async throws {
        candidates[candidateId]?.status = status
    }
}

private final class InMemoryPrincipleRepository: PrincipleRepository {
    private var principlesById: [UUID: PrincipleAsset] = [:]
    private var entryPrincipleIds: [UUID: [UUID]] = [:]

    func savePrinciple(_ principle: PrincipleAsset, sourceDailyEntryId: UUID) async throws {
        principlesById[principle.id] = principle
        var ids = entryPrincipleIds[sourceDailyEntryId] ?? []
        if !ids.contains(principle.id) {
            ids.append(principle.id)
        }
        entryPrincipleIds[sourceDailyEntryId] = ids
    }

    func savePrinciples(_ principles: [PrincipleAsset], sourceDailyEntryId: UUID) async throws {
        entryPrincipleIds[sourceDailyEntryId] = []
        for principle in principles {
            try await savePrinciple(principle, sourceDailyEntryId: sourceDailyEntryId)
        }
    }

    func allPrinciples() async throws -> [PrincipleAsset] {
        principlesById.values.filter { $0.status != .archived }
    }

    func activePrinciples() async throws -> [PrincipleAsset] {
        principlesById.values.filter { $0.status == .active }
    }

    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset] {
        (entryPrincipleIds[dailyEntryId] ?? [])
            .compactMap { principlesById[$0] }
            .filter { $0.status != .archived }
    }

    func updatePrinciple(_ principle: PrincipleAsset) async throws {
        principlesById[principle.id] = principle
    }

    func updatePrincipleStatus(_ status: PrincipleStatus, principleId: UUID) async throws {
        principlesById[principleId]?.status = status
    }

    func deletePrinciple(_ principleId: UUID) async throws {
        principlesById.removeValue(forKey: principleId)
        for entryId in entryPrincipleIds.keys {
            entryPrincipleIds[entryId]?.removeAll { $0 == principleId }
        }
    }
}

private final class InMemoryPrinciplePracticeEvidenceRepository: PrinciplePracticeEvidenceRepository {
    private var evidenceById: [UUID: PrinciplePracticeEvidence] = [:]

    func saveEvidence(_ evidence: PrinciplePracticeEvidence) async throws {
        evidenceById[evidence.id] = evidence
    }

    func disputeEvidence(_ evidenceId: UUID, note: String) async throws {
        guard var evidence = evidenceById[evidenceId] else { return }
        evidence.isDisputed = true
        evidence.disputeNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        evidence.updatedAt = .now
        evidenceById[evidenceId] = evidence
    }

    func evidence(for principleId: UUID, limit: Int) async throws -> [PrinciplePracticeEvidence] {
        Array(evidenceById.values)
            .filter { $0.principleId == principleId && !$0.isDisputed }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func disputedEvidence(for principleId: UUID, limit: Int) async throws -> [PrinciplePracticeEvidence] {
        Array(evidenceById.values)
            .filter { $0.principleId == principleId && $0.isDisputed }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    func evidence(
        for principleId: UUID,
        sourceDailyEntryId: UUID,
        questId: UUID,
        evidenceSource: PrinciplePracticeEvidenceSource
    ) async throws -> PrinciplePracticeEvidence? {
        evidenceById.values.first {
            $0.principleId == principleId &&
            $0.sourceDailyEntryId == sourceDailyEntryId &&
            $0.questId == questId &&
            $0.evidenceSource == evidenceSource &&
            !$0.isDisputed
        }
    }
}

// MARK: - Manual Principle Creation

extension AppStoreStateMachineTests {

    func testAddManualPrinciple_persistsActivePrincipleAndLinksToToday() async throws {
        let dailyRepo = InMemoryDailyEntryRepository()
        let principleRepo = InMemoryPrincipleRepository()
        let draft = DailyEntryDraft(rawText: "Manual principle source", state: .capture)
        let store = AppStore(
            todayDraft: draft,
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            refreshesAIServiceFromKeychain: false
        )

        let result = await store.addManualPrinciple(
            title: "  会前确认负责人  ",
            summary: "行动前先确认唯一负责人。",
            triggerContext: "跨团队会议",
            actions: ["  说清负责人  ", "", "确认验收标准"],
            successCriteria: "会后没有职责空白",
            exceptions: "低风险同步可简化"
        )

        XCTAssertTrue(result)
        XCTAssertEqual(store.principles.count, 1)
        XCTAssertEqual(store.activePrinciples.count, 1)
        XCTAssertEqual(store.activePrinciples.first?.title, "会前确认负责人")
        XCTAssertEqual(store.activePrinciples.first?.actions, ["说清负责人", "确认验收标准"])
        let persistedTitles = try await principleRepo.principles(for: draft.id).map(\.title)
        let activeTitles = try await principleRepo.activePrinciples().map(\.title)
        let latestDraft = try await dailyRepo.latestDraft()
        XCTAssertEqual(persistedTitles, ["会前确认负责人"])
        XCTAssertEqual(activeTitles, ["会前确认负责人"])
        XCTAssertEqual(latestDraft?.id, draft.id)
    }

    func testAddManualPrinciple_rejectsMissingRequiredText() async throws {
        let principleRepo = InMemoryPrincipleRepository()
        let store = AppStore(
            principleRepository: principleRepo,
            refreshesAIServiceFromKeychain: false
        )

        let result = await store.addManualPrinciple(
            title: " ",
            summary: "Summary",
            triggerContext: "Context",
            actions: ["Act"],
            successCriteria: "Criteria",
            exceptions: "None"
        )

        XCTAssertFalse(result)
        XCTAssertTrue(store.principles.isEmpty)
        XCTAssertTrue(store.activePrinciples.isEmpty)
        let activePrinciples = try await principleRepo.activePrinciples()
        XCTAssertTrue(activePrinciples.isEmpty)
    }

    func testResetTodayLoop_keepsActiveManualPrinciplesVisibleInGrowthState() async throws {
        let principle = PrincipleAsset(
            title: "先确认负责人",
            summary: "行动前先确认唯一负责人。",
            triggerContext: "协作任务",
            actions: ["说清负责人"],
            successCriteria: "没有职责空白",
            exceptions: ""
        )
        let store = AppStore(
            principles: [principle],
            refreshesAIServiceFromKeychain: false
        )

        store.resetTodayLoop()

        XCTAssertTrue(store.principles.isEmpty)
        XCTAssertEqual(store.activePrinciples.map(\.title), ["先确认负责人"])
    }

    func testPrincipleTrainingSummary_classifiesKnownPracticedInternalizedAndNeedsReview() {
        let known = PrincipleAsset(
            id: UUID(),
            title: "先确认负责人",
            summary: "行动前先确认唯一负责人。",
            triggerContext: "协作任务",
            actions: ["说清负责人"],
            successCriteria: "没有职责空白",
            exceptions: ""
        )
        let practiced = PrincipleAsset(
            id: UUID(),
            title: "先写验收标准",
            summary: "开始前先写清完成证据。",
            triggerContext: "任务启动",
            actions: ["写验收标准"],
            successCriteria: "完成时能直接验证",
            exceptions: ""
        )
        let internalized = PrincipleAsset(
            id: UUID(),
            title: "会后同步结论",
            summary: "会议结束后发出负责人和行动项。",
            triggerContext: "会议结束",
            actions: ["发出结论"],
            successCriteria: "相关人知道下一步",
            exceptions: ""
        )
        let needsReview = PrincipleAsset(
            id: UUID(),
            title: "所有会议都要拉齐",
            summary: "看似有用但经常不适用。",
            triggerContext: "会议",
            actions: ["拉齐所有人"],
            successCriteria: "没有遗漏",
            exceptions: "",
            status: .needsReview
        )
        let earlierPracticeDate = Date(timeIntervalSince1970: 1_700_000_000)
        let latestPracticeDate = Date(timeIntervalSince1970: 1_700_200_000)

        let practicedEvidence = PrinciplePracticeEvidence(
            principleId: practiced.id,
            sourceDailyEntryId: UUID(),
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "验证中实践了验收标准。匹配信号：写验收标准",
            practiceRole: .targetedPractice,
            createdAt: latestPracticeDate,
            updatedAt: latestPracticeDate
        )

        let summaries = PrincipleTrainingSummary.summaries(
            for: [known, practiced, internalized, needsReview],
            practiceEvidence: [
                practicedEvidence,
                PrinciplePracticeEvidence(
                    principleId: internalized.id,
                    sourceDailyEntryId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    evidenceSource: .verification,
                    strength: .intentionalPractice,
                    evidenceSummary: "第一次会后同步。",
                    createdAt: earlierPracticeDate,
                    updatedAt: earlierPracticeDate
                ),
                PrinciplePracticeEvidence(
                    principleId: internalized.id,
                    sourceDailyEntryId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    evidenceSource: .verification,
                    strength: .intentionalPractice,
                    evidenceSummary: "第二次会后同步。",
                    createdAt: earlierPracticeDate.addingTimeInterval(60),
                    updatedAt: earlierPracticeDate.addingTimeInterval(60)
                ),
                PrinciplePracticeEvidence(
                    principleId: internalized.id,
                    sourceDailyEntryId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    evidenceSource: .manual,
                    strength: .internalized,
                    evidenceSummary: "用户明确表示已经自然执行。",
                    createdAt: latestPracticeDate,
                    updatedAt: latestPracticeDate
                )
            ],
            recallFeedback: [
                PrincipleRecallFeedback(
                    principleId: needsReview.id,
                    promptId: .generateQuestions,
                    retrievalPolicyVersion: "principle-retrieval.local-keyword-feedback.v2",
                    retrievalReason: "Matched meeting.",
                    feedback: .misrecalled
                )
            ]
        )

        XCTAssertEqual(summaries.map(\.state), [
            .knownButUnused,
            .consciouslyPracticed,
            .stablyInternalized,
            .needsReview
        ])
        XCTAssertEqual(summaries[1].practiceEvidenceCount, 1)
        XCTAssertEqual(summaries[1].latestPracticeEvidenceId, practicedEvidence.id)
        XCTAssertEqual(summaries[1].latestPracticeEvidenceSummary, "验证中实践了验收标准。匹配信号：写验收标准")
        XCTAssertEqual(summaries[1].latestPracticeEvidenceRole, .targetedPractice)
        XCTAssertEqual(summaries[2].practiceEvidenceCount, 3)
        XCTAssertEqual(summaries[2].latestPracticeEvidenceSummary, "用户明确表示已经自然执行。")
        XCTAssertEqual(summaries[2].latestPracticeEvidenceRole, .possibleSignal)
        XCTAssertEqual(summaries[3].negativeRecallFeedbackCount, 1)
    }

    func testRefreshPrincipleTrainingSummaries_loadsPracticeEvidenceForActivePrinciples() async throws {
        let practiced = PrincipleAsset(
            title: "先写验收标准",
            summary: "开始前先写清完成证据。",
            triggerContext: "任务启动",
            actions: ["写验收标准"],
            successCriteria: "完成时能直接验证",
            exceptions: ""
        )
        let principleRepo = InMemoryPrincipleRepository()
        let practiceRepo = InMemoryPrinciplePracticeEvidenceRepository()
        try await principleRepo.savePrinciple(practiced, sourceDailyEntryId: UUID())
        let evidenceDate = Date(timeIntervalSince1970: 1_700_300_000)
        let evidence = PrinciplePracticeEvidence(
            principleId: practiced.id,
            sourceDailyEntryId: UUID(),
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "验证中实践了验收标准。匹配信号：写验收标准",
            practiceRole: .secondaryPractice,
            createdAt: evidenceDate,
            updatedAt: evidenceDate
        )
        try await practiceRepo.saveEvidence(evidence)
        let dailyRepo = InMemoryDailyEntryRepository()
        let store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()
        await store.refreshPrincipleTrainingSummaries()

        XCTAssertEqual(store.principleTrainingSummaries.map(\.principle.id), [practiced.id])
        XCTAssertEqual(store.principleTrainingSummaries.first?.state, .consciouslyPracticed)
        XCTAssertEqual(store.principleTrainingSummaries.first?.practiceEvidenceCount, 1)
        XCTAssertEqual(store.principleTrainingSummaries.first?.latestPracticeEvidenceId, evidence.id)
        XCTAssertEqual(store.principleTrainingSummaries.first?.latestPracticeEvidenceSummary, "验证中实践了验收标准。匹配信号：写验收标准")
        XCTAssertEqual(store.principleTrainingSummaries.first?.latestPracticeEvidenceRole, .secondaryPractice)
    }

    func testDisputePrinciplePracticeEvidence_removesAttributionFromTrainingSummary() async throws {
        let practiced = PrincipleAsset(
            title: "先写验收标准",
            summary: "开始前先写清完成证据。",
            triggerContext: "任务启动",
            actions: ["写验收标准"],
            successCriteria: "完成时能直接验证",
            exceptions: ""
        )
        let principleRepo = InMemoryPrincipleRepository()
        let practiceRepo = InMemoryPrinciplePracticeEvidenceRepository()
        try await principleRepo.savePrinciple(practiced, sourceDailyEntryId: UUID())
        let evidence = PrinciplePracticeEvidence(
            principleId: practiced.id,
            sourceDailyEntryId: UUID(),
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "验证中实践了验收标准。匹配信号：写验收标准",
            createdAt: Date(timeIntervalSince1970: 1_700_300_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_300_000)
        )
        try await practiceRepo.saveEvidence(evidence)
        let store = AppStore(
            dailyEntryRepository: InMemoryDailyEntryRepository(),
            principleRepository: principleRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()
        await store.refreshPrincipleTrainingSummaries()
        XCTAssertEqual(store.principleTrainingSummaries.first?.state, .consciouslyPracticed)

        let didDispute = await store.disputePrinciplePracticeEvidence(
            evidence.id,
            note: "这次只是完成任务，不应算作原则练习。"
        )

        XCTAssertTrue(didDispute)
        XCTAssertEqual(store.principleTrainingSummaries.first?.state, .knownButUnused)
        XCTAssertEqual(store.principleTrainingSummaries.first?.practiceEvidenceCount, 0)
        XCTAssertNil(store.principleTrainingSummaries.first?.latestPracticeEvidenceId)
        XCTAssertNil(store.principleTrainingSummaries.first?.latestPracticeEvidenceSummary)
    }

    func testDisputedPrinciplePracticeEvidence_remainsVisibleAsAuditInTrainingSummary() async throws {
        let practiced = PrincipleAsset(
            title: "先写验收标准",
            summary: "开始前先写清完成证据。",
            triggerContext: "任务启动",
            actions: ["写验收标准"],
            successCriteria: "完成时能直接验证",
            exceptions: ""
        )
        let principleRepo = InMemoryPrincipleRepository()
        let practiceRepo = InMemoryPrinciplePracticeEvidenceRepository()
        try await principleRepo.savePrinciple(practiced, sourceDailyEntryId: UUID())
        let evidence = PrinciplePracticeEvidence(
            principleId: practiced.id,
            sourceDailyEntryId: UUID(),
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "验证中实践了验收标准。匹配信号：写验收标准",
            createdAt: Date(timeIntervalSince1970: 1_700_300_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_300_000)
        )
        try await practiceRepo.saveEvidence(evidence)
        let store = AppStore(
            dailyEntryRepository: InMemoryDailyEntryRepository(),
            principleRepository: principleRepo,
            principlePracticeEvidenceRepository: practiceRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()
        let didDispute = await store.disputePrinciplePracticeEvidence(
            evidence.id,
            note: "这次只是完成任务，不应算作原则练习。"
        )

        XCTAssertTrue(didDispute)
        let summary = try XCTUnwrap(store.principleTrainingSummaries.first)
        XCTAssertEqual(summary.practiceEvidenceCount, 0)
        XCTAssertNil(summary.latestPracticeEvidenceId)
        XCTAssertEqual(summary.latestDisputedPracticeEvidenceId, evidence.id)
        XCTAssertEqual(summary.latestDisputedPracticeEvidenceSummary, "验证中实践了验收标准。匹配信号：写验收标准")
        XCTAssertEqual(summary.latestDisputedPracticeEvidenceNote, "这次只是完成任务，不应算作原则练习。")
    }

    func testPrincipleTrainingSummary_surfacesLatestNegativeRecallFeedbackForReviewAudit() {
        let needsReview = PrincipleAsset(
            id: UUID(),
            title: "所有会议都要拉齐",
            summary: "看似有用但经常不适用。",
            triggerContext: "会议",
            actions: ["拉齐所有人"],
            successCriteria: "没有遗漏",
            exceptions: "",
            status: .needsReview
        )
        let earlier = PrincipleRecallFeedback(
            principleId: needsReview.id,
            promptId: .generateQuestions,
            retrievalPolicyVersion: "principle-retrieval.local-keyword-feedback.v2",
            retrievalReason: "Matched meeting keyword.",
            feedback: .notApplicable,
            note: "这次只是信息同步。",
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000)
        )
        let latest = PrincipleRecallFeedback(
            principleId: needsReview.id,
            promptId: .generateQuests,
            retrievalPolicyVersion: "principle-retrieval.local-keyword-feedback.v2",
            retrievalReason: "Matched cross-team meeting and owner.",
            retrievalSignal: "meeting ownership",
            feedback: .misrecalled,
            note: "模型把例外场景当成规则。",
            createdAt: Date(timeIntervalSince1970: 1_700_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_200_000)
        )

        let summary = PrincipleTrainingSummary.summary(
            for: needsReview,
            practiceEvidence: [],
            recallFeedback: [earlier, latest]
        )

        XCTAssertEqual(summary.state, .needsReview)
        XCTAssertEqual(summary.negativeRecallFeedbackCount, 2)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackId, latest.id)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackAt, latest.createdAt)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackValue, .misrecalled)
        XCTAssertEqual(summary.latestNegativeRecallFeedbackReason, "Matched cross-team meeting and owner.")
        XCTAssertEqual(summary.latestNegativeRecallFeedbackSignal, "meeting ownership")
        XCTAssertEqual(summary.latestNegativeRecallFeedbackNote, "模型把例外场景当成规则。")
    }

    func testLoadPersistedState_keepsNeedsReviewPrinciplesVisibleInTrainingSummaries() async throws {
        let needsReview = PrincipleAsset(
            title: "所有会议都要拉齐",
            summary: "看似有用但经常不适用。",
            triggerContext: "会议",
            actions: ["拉齐所有人"],
            successCriteria: "没有遗漏",
            exceptions: "",
            status: .needsReview
        )
        let principleRepo = InMemoryPrincipleRepository()
        try await principleRepo.savePrinciple(needsReview, sourceDailyEntryId: UUID())
        let dailyRepo = InMemoryDailyEntryRepository()
        let store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()

        XCTAssertTrue(store.activePrinciples.isEmpty)
        XCTAssertEqual(store.principleTrainingSummaries.map(\.principle.id), [needsReview.id])
        XCTAssertEqual(store.principleTrainingSummaries.first?.state, .needsReview)
    }

    func testRepairPrinciple_reactivatesNeedsReviewPrincipleAndRefreshesTrainingSummary() async throws {
        let needsReview = PrincipleAsset(
            title: "所有会议都要拉齐",
            summary: "看似有用但经常不适用。",
            triggerContext: "会议",
            actions: ["拉齐所有人"],
            successCriteria: "没有遗漏",
            exceptions: "",
            status: .needsReview
        )
        let principleRepo = InMemoryPrincipleRepository()
        try await principleRepo.savePrinciple(needsReview, sourceDailyEntryId: UUID())
        let dailyRepo = InMemoryDailyEntryRepository()
        let store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()
        let didRepair = await store.repairPrinciple(
            needsReview.id,
            title: "只拉齐有决策权的人",
            summary: "协作前确认真正参与决策和执行的人。",
            triggerContext: "跨团队会议",
            actions: ["列出决策人", "列出执行人"],
            successCriteria: "会后每个行动项都有唯一负责人。",
            exceptions: "纯信息同步可以只发纪要。"
        )

        XCTAssertTrue(didRepair)
        XCTAssertEqual(store.activePrinciples.map(\.id), [needsReview.id])
        XCTAssertEqual(store.activePrinciples.first?.title, "只拉齐有决策权的人")
        XCTAssertTrue(store.principles.isEmpty)
        XCTAssertEqual(store.principleTrainingSummaries.map(\.principle.id), [needsReview.id])
        XCTAssertEqual(store.principleTrainingSummaries.first?.state, .knownButUnused)
        let stored = try await principleRepo.activePrinciples()
        XCTAssertEqual(stored.map(\.id), [needsReview.id])
        XCTAssertEqual(stored.first?.summary, "协作前确认真正参与决策和执行的人。")
    }

    func testArchivePrinciple_removesNeedsReviewPrincipleFromVisibleTrainingAssets() async throws {
        let needsReview = PrincipleAsset(
            title: "Visual QA - 会前确认负责人",
            summary: "协作任务开始前先确认唯一负责人和验收标准。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人", "写出验收标准"],
            successCriteria: "相关人知道下一步由谁推进。",
            exceptions: "低风险同步可简化",
            status: .needsReview
        )
        let principleRepo = InMemoryPrincipleRepository()
        try await principleRepo.savePrinciple(needsReview, sourceDailyEntryId: UUID())
        let dailyRepo = InMemoryDailyEntryRepository()
        let store = AppStore(
            dailyEntryRepository: dailyRepo,
            principleRepository: principleRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()
        let didArchive = await store.archivePrinciple(needsReview.id)

        XCTAssertTrue(didArchive)
        XCTAssertTrue(store.activePrinciples.isEmpty)
        XCTAssertTrue(store.principleTrainingSummaries.isEmpty)
        XCTAssertEqual(store.todayLoopMessage, "原则已归档。")
        let active = try await principleRepo.activePrinciples()
        let all = try await principleRepo.allPrinciples()
        XCTAssertTrue(active.isEmpty)
        XCTAssertTrue(all.isEmpty)
    }

    func testDeletePrinciple_removesNeedsReviewPrincipleFromRepositoryAndVisibleTrainingAssets() async throws {
        let needsReview = PrincipleAsset(
            title: "Visual QA - 待清理测试原则",
            summary: "这是手工测试留下的原则资产。",
            triggerContext: "manual testing",
            actions: ["清理测试数据"],
            successCriteria: "原则资产列表不再显示它。",
            exceptions: "",
            status: .needsReview
        )
        let principleRepo = InMemoryPrincipleRepository()
        try await principleRepo.savePrinciple(needsReview, sourceDailyEntryId: UUID())
        let store = AppStore(
            principleRepository: principleRepo,
            refreshesAIServiceFromKeychain: false
        )

        await store.loadPersistedState()
        let didDelete = await store.deletePrinciple(needsReview.id)

        XCTAssertTrue(didDelete)
        XCTAssertTrue(store.activePrinciples.isEmpty)
        XCTAssertTrue(store.principleTrainingSummaries.isEmpty)
        XCTAssertEqual(store.todayLoopMessage, "原则已删除。")
        let active = try await principleRepo.activePrinciples()
        let all = try await principleRepo.allPrinciples()
        XCTAssertTrue(active.isEmpty)
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - ThinkingLens Catalog

    func testThinkingLens_allCases_containsFirstPrinciples() {
        XCTAssertTrue(ThinkingLens.allCases.contains(.firstPrinciples),
                       "firstPrinciples should appear in allCases")
    }

    func testThinkingLens_allCases_containsSystemThinking() {
        XCTAssertTrue(ThinkingLens.allCases.contains(.systemThinking),
                       "systemThinking should appear in allCases")
    }

    func testThinkingLens_allCases_containsJudgmentCalibration() {
        XCTAssertTrue(ThinkingLens.allCases.contains(.judgmentCalibration),
                       "judgmentCalibration should appear in allCases")
    }

    func testThinkingLens_existingRawValues_stable() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.rawValue, "evidenceCheck")
        XCTAssertEqual(ThinkingLens.opposingView.rawValue, "opposingView")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.rawValue, "leverageAnalysis")
        XCTAssertEqual(ThinkingLens.firstPrinciples.rawValue, "firstPrinciples")
        XCTAssertEqual(ThinkingLens.systemThinking.rawValue, "systemThinking")
        XCTAssertEqual(ThinkingLens.judgmentCalibration.rawValue, "judgmentCalibration")
    }

    func testBuiltinCatalog_containsOneItem_perLensCase() {
        let catalogCount = BuiltinLensCatalog.items.count
        let lensCount = ThinkingLens.allCases.count
        XCTAssertEqual(catalogCount, lensCount,
                       "Built-in catalog should have one item per ThinkingLens case")
    }

    func testBuiltinLensLibrary_listsOneItem_perLensCase() {
        let library = BuiltinLensCatalog.library

        XCTAssertEqual(library.items.count, ThinkingLens.allCases.count)
    }

    func testBuiltinLensLibrary_lookupByLocalId_returnsFirstPrinciples() {
        let item = BuiltinLensCatalog.library.item(localId: "firstPrinciples")

        XCTAssertEqual(item?.title, "第一性原理")
        XCTAssertEqual(item?.lensId, ThinkingLens.firstPrinciples.rawValue)
    }

    func testBuiltinLensLibrary_lookupByPromptId_returnsFirstPrinciples() {
        let item = BuiltinLensCatalog.library.item(promptId: "first_principles")

        XCTAssertEqual(item?.lensId, ThinkingLens.firstPrinciples.rawValue)
        XCTAssertEqual(item?.promptId, "first_principles")
    }

    func testBuiltinLensLibrary_lookupByThinkingLens_matchesCatalogItem() {
        let libraryItem = BuiltinLensCatalog.library.item(for: .firstPrinciples)

        XCTAssertEqual(libraryItem, ThinkingLens.firstPrinciples.catalogItem)
    }

    func testThinkingLens_promptIds_stable() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.catalogItem.promptId, "evidence_check")
        XCTAssertEqual(ThinkingLens.opposingView.catalogItem.promptId, "opposing_view")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.catalogItem.promptId, "leverage_analysis")
        XCTAssertEqual(ThinkingLens.firstPrinciples.catalogItem.promptId, "first_principles")
        XCTAssertEqual(ThinkingLens.systemThinking.catalogItem.promptId, "system_thinking")
        XCTAssertEqual(ThinkingLens.judgmentCalibration.catalogItem.promptId, "judgment_calibration")
    }

    func testFirstPrinciples_metadata() {
        let item = ThinkingLens.firstPrinciples.catalogItem
        XCTAssertEqual(item.title, "第一性原理")
        XCTAssertEqual(item.promptId, "first_principles")
        XCTAssertEqual(item.version, "builtin.v1")
        XCTAssertTrue(item.promptGuidance.contains("non-negotiable facts"))
        XCTAssertFalse(item.symbolName.isEmpty, "symbolName should not be empty")
    }

    func testSystemThinking_metadata() {
        let item = ThinkingLens.systemThinking.catalogItem

        XCTAssertEqual(item.title, "系统思维")
        XCTAssertEqual(item.promptId, "system_thinking")
        XCTAssertEqual(item.version, "builtin.v1")
        XCTAssertTrue(item.promptGuidance.contains("feedback loops"))
        XCTAssertTrue(item.promptGuidance.contains("delayed effects"))
        XCTAssertTrue(item.questionStrategy.contains("反馈回路"))
        XCTAssertTrue(item.questionStrategy.contains("二阶后果"))
        XCTAssertTrue(item.taskSelectionRule.contains("校准信号"))
        XCTAssertTrue(item.disableConditions.contains("不要把系统思维变成宏大叙事，必须落到当天证据和下一步观察。"))
        XCTAssertFalse(item.symbolName.isEmpty, "symbolName should not be empty")
    }

    func testJudgmentCalibration_metadata() {
        let item = ThinkingLens.judgmentCalibration.catalogItem

        XCTAssertEqual(item.title, "判断校准")
        XCTAssertEqual(item.promptId, "judgment_calibration")
        XCTAssertEqual(item.version, "builtin.v1")
        XCTAssertTrue(item.promptGuidance.contains("prediction"))
        XCTAssertTrue(item.promptGuidance.contains("actual evidence"))
        XCTAssertTrue(item.questionStrategy.contains("原判断"))
        XCTAssertTrue(item.taskSelectionRule.contains("校准信号"))
        XCTAssertTrue(item.disableConditions.contains("不要把校准变成事后诸葛，必须先明确原判断或可观察预测。"))
        XCTAssertFalse(item.symbolName.isEmpty, "symbolName should not be empty")
    }

    func testBuiltinLensCatalog_methodAssetMetadataIsComplete() {
        let methodIndexes = BuiltinLensCatalog.items.map(\.methodIndex)

        XCTAssertEqual(Set(methodIndexes).count, ThinkingLens.allCases.count)
        XCTAssertEqual(methodIndexes.sorted(), [1, 2, 3, 4, 5, 6])

        for item in BuiltinLensCatalog.items {
            XCTAssertFalse(item.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.questionStrategy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.taskSelectionRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.applicability.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.disableConditions.isEmpty)
            XCTAssertTrue(item.disableConditions.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
            XCTAssertEqual(item.uiMetadata.symbolName, item.symbolName)
            XCTAssertEqual(item.uiMetadata.accentRole, item.accentRole)
            XCTAssertEqual(item.uiMetadata.methodIndex, item.methodIndex)
            XCTAssertFalse(item.recommendedReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.questionSeeds.isEmpty)
            XCTAssertTrue(item.questionSeeds.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
            XCTAssertFalse(item.accentRole.rawValue.isEmpty)
            XCTAssertGreaterThan(item.methodIndex, 0)
        }
    }

    func testBuiltinLensCatalog_packMetadataIsFirstPartyAndVersioned() {
        for item in BuiltinLensCatalog.items {
            XCTAssertEqual(item.sourceKind, .builtin)
            XCTAssertEqual(item.packId, "mingsi.builtin.lenses")
            XCTAssertEqual(item.packVersion, "builtin.v1")
            XCTAssertEqual(item.packDisplayName, "MingSi Built-in Lens Pack")
            XCTAssertTrue(item.isBuiltIn)
        }
    }

    func testLensLibrary_combinesEnabledMarketplaceLensPackAndIgnoresDisabledPacks() {
        let roleLens = LensCatalogItem(
            lensId: "role-coach",
            promptId: "role_coach",
            version: "role.v1",
            title: "Coach Role",
            subtitle: "Use a coaching voice.",
            shortLabel: "Coach",
            methodLine: "What would a coach ask first?",
            promptGuidance: "Ask coaching-style reflection questions.",
            symbolName: "person.wave.2",
            recommendedReason: "Imported role card pack.",
            questionSeeds: ["What would a coach ask first?"],
            accentRole: .accent,
            methodIndex: 10
        )
        let disabledLens = LensCatalogItem(
            lensId: "disabled-role",
            promptId: "disabled_role",
            version: "role.v1",
            title: "Disabled Role",
            subtitle: "Should not appear.",
            shortLabel: "Off",
            methodLine: "Should not appear.",
            promptGuidance: "Should not appear.",
            symbolName: "nosign",
            recommendedReason: "Disabled pack.",
            questionSeeds: ["Should not appear."],
            accentRole: .brick,
            methodIndex: 11
        )
        let library = LensLibrary(packs: [
            LensAssetPack(
                id: "marketplace.roles.coach",
                version: "2026.06",
                displayName: "Coach Role Cards",
                sourceKind: .marketplace,
                isEnabled: true,
                items: [roleLens]
            ),
            LensAssetPack(
                id: "marketplace.roles.disabled",
                version: "2026.06",
                displayName: "Disabled Role Cards",
                sourceKind: .marketplace,
                isEnabled: false,
                items: [disabledLens]
            )
        ])

        let imported = library.item(localId: "role-coach")

        XCTAssertEqual(imported?.promptId, "role_coach")
        XCTAssertEqual(imported?.sourceKind, .marketplace)
        XCTAssertEqual(imported?.packId, "marketplace.roles.coach")
        XCTAssertEqual(imported?.packVersion, "2026.06")
        XCTAssertEqual(imported?.packDisplayName, "Coach Role Cards")
        XCTAssertFalse(imported?.isBuiltIn ?? true)
        XCTAssertNil(library.item(localId: "disabled-role"))
    }

    func testLensCatalogItem_decodesLegacyCustomLensJSONWithDefaultAssetFields() throws {
        let legacyJSON = """
        {
          "lensId": "custom-owner",
          "promptId": "custom_owner",
          "version": "custom.v1",
          "title": "Owner Lens",
          "subtitle": "Clarify ownership.",
          "shortLabel": "Owner",
          "methodLine": "Who owns the next decision?",
          "promptGuidance": "Ask ownership and evidence questions.",
          "symbolName": "person.crop.circle.badge.checkmark",
          "recommendedReason": "Created from confirmed cards.",
          "questionSeeds": ["Who owns the next decision?"],
          "accentRole": "brick",
          "methodIndex": 0
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(LensCatalogItem.self, from: legacyJSON)

        XCTAssertEqual(item.lensId, "custom-owner")
        XCTAssertEqual(item.purpose, "Clarify ownership.")
        XCTAssertEqual(item.questionStrategy, "Ask ownership and evidence questions.")
        XCTAssertEqual(item.taskSelectionRule, "Use this lens to choose a next action grounded in the user's confirmed cards.")
        XCTAssertEqual(item.applicability, "Created from confirmed cards.")
        XCTAssertEqual(item.disableConditions, ["Do not use when the user has not selected this custom lens."])
        XCTAssertEqual(item.uiMetadata.symbolName, "person.crop.circle.badge.checkmark")
        XCTAssertEqual(item.uiMetadata.accentRole, .brick)
        XCTAssertEqual(item.uiMetadata.methodIndex, 0)
        XCTAssertEqual(item.sourceKind, .localCustom)
        XCTAssertEqual(item.packId, "local.custom-lenses")
        XCTAssertEqual(item.packVersion, "session.v1")
        XCTAssertEqual(item.packDisplayName, "Local Custom Lenses")
        XCTAssertFalse(item.isBuiltIn)
    }

    func testBuiltinLensLibrary_recommendsEvidenceCheckForValidationHeavyCards() {
        let cards = [
            ThinkingCard(type: .fact, title: "客户预期变更", body: "需要确认客户是否真的接受延期。", priority: .high),
            ThinkingCard(type: .risk, title: "验收口径不清", body: "缺少事实支撑。", priority: .high),
            ThinkingCard(type: .problem, title: "判断依据不足", body: "目前只有推测。", priority: .medium)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.evidenceCheck.rawValue)
    }

    func testBuiltinLensLibrary_prioritizesEvidenceCheckForDeepValidationRisk() {
        let cards = [
            ThinkingCard(type: .risk, title: "关键依赖未确认", body: "上线窗口可能只是估计。", priority: .high),
            ThinkingCard(type: .problem, title: "验收边界模糊", body: "需要补充事实依据。", priority: .medium),
            ThinkingCard(type: .fact, title: "客户还没回复", body: "这是当前唯一确定事实。", priority: .high)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .deep)

        XCTAssertEqual(item?.lensId, ThinkingLens.evidenceCheck.rawValue)
    }

    func testBuiltinLensLibrary_prioritizesEvidenceCheckOverLeverageForHighPriorityValidation() {
        let cards = [
            ThinkingCard(type: .task, title: "同步接口 owner", body: "今天先约齐负责人。", priority: .high),
            ThinkingCard(type: .decision, title: "保留旧逻辑", body: "先用兼容方案交付。", priority: .medium),
            ThinkingCard(type: .risk, title: "验收口径不清", body: "上线前必须确认依据。", priority: .high),
            ThinkingCard(type: .fact, title: "客户承诺未落文档", body: "需要先确认是否真实存在。", priority: .high)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.evidenceCheck.rawValue)
    }

    func testBuiltinLensLibrary_recommendsLeverageAnalysisForActionHeavyCards() {
        let cards = [
            ThinkingCard(type: .task, title: "确认接口负责人", body: "明天先定边界。", priority: .high),
            ThinkingCard(type: .decision, title: "短期兼容旧逻辑", body: "先保证交付。", priority: .medium),
            ThinkingCard(type: .task, title: "补完成标准", body: "写清验收条件。", priority: .medium)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.leverageAnalysis.rawValue)
    }

    func testBuiltinLensLibrary_recommendsOpposingViewForDeepRiskHeavyCards() {
        let cards = [
            ThinkingCard(type: .risk, title: "第三方接口延期", body: "计划可能被拖住。", priority: .medium),
            ThinkingCard(type: .problem, title: "只看到自己视角", body: "缺少反证。", priority: .medium),
            ThinkingCard(type: .risk, title: "技术债继续累积", body: "短期方案可能扩大成本。", priority: .low)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .deep)

        XCTAssertEqual(item?.lensId, ThinkingLens.opposingView.rawValue)
    }

    func testBuiltinLensLibrary_recommendsFirstPrinciplesWhenNoTypeDominates() {
        let cards = [
            ThinkingCard(type: .idea, title: "也许要重排优先级", body: "目前只是感觉。", priority: .medium),
            ThinkingCard(type: .communication, title: "同步会没有结论", body: "没人确认前提。", priority: .medium),
            ThinkingCard(type: .fact, title: "会议没有 owner", body: "这是唯一确定事实。", priority: .low)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .quick)

        XCTAssertEqual(item?.lensId, ThinkingLens.firstPrinciples.rawValue)
    }

    func testBuiltinLensLibrary_recommendsSystemThinkingForFeedbackLoopAndDelayCards() {
        let cards = [
            ThinkingCard(type: .problem, title: "修复越多返工越多", body: "每次临时修复都会制造下一轮返工，像反馈回路。", priority: .medium),
            ThinkingCard(type: .risk, title: "短期压进度会延迟爆发", body: "现在省掉验收，可能两周后在集成阶段放大成本。", priority: .medium),
            ThinkingCard(type: .decision, title: "继续走临时方案", body: "需要理解二阶后果。", priority: .medium)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.systemThinking.rawValue)
    }

    func testBuiltinLensLibrary_recommendsJudgmentCalibrationForPredictionAndOutcomeCards() {
        let cards = [
            ThinkingCard(type: .decision, title: "我原本预测返工会减少", body: "昨天我有 70% 把握认为小范围验收能减少一轮返工。", priority: .medium),
            ThinkingCard(type: .fact, title: "实际结果相反", body: "实际证据显示返工没有减少，问题来自负责人未确认。", priority: .medium),
            ThinkingCard(type: .problem, title: "需要更新判断", body: "下次要校准信心和预测依据。", priority: .medium)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.judgmentCalibration.rawValue)
    }

    func testFirstPrinciples_rawValue() {
        XCTAssertEqual(ThinkingLens.firstPrinciples.rawValue, "firstPrinciples")
    }

    func testSystemThinking_rawValue() {
        XCTAssertEqual(ThinkingLens.systemThinking.rawValue, "systemThinking")
    }

    func testJudgmentCalibration_rawValue() {
        XCTAssertEqual(ThinkingLens.judgmentCalibration.rawValue, "judgmentCalibration")
    }

    func testEvidenceGapType_displayTitles_areStable() {
        XCTAssertEqual(EvidenceGapType.missingObservation.displayTitle, "缺观察事实")
        XCTAssertEqual(EvidenceGapType.missingBaseline.displayTitle, "缺基线")
        XCTAssertEqual(EvidenceGapType.missingCausalLink.displayTitle, "缺因果链")
        XCTAssertEqual(EvidenceGapType.missingCounterexample.displayTitle, "缺反例")
        XCTAssertEqual(EvidenceGapType.missingConstraint.displayTitle, "缺约束")
        XCTAssertEqual(EvidenceGapType.missingCalibrationSignal.displayTitle, "缺校准信号")
        XCTAssertEqual(EvidenceGapType.none.displayTitle, "非证据缺口")
    }

    func testReflectionQuestion_answerPromptGuidesMissingThinkingMaterial() {
        XCTAssertEqual(
            ReflectionQuestion(
                question: "还缺哪个可观察事实？",
                whyItMatters: "补证据",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence
            ).answerTrainingPrompt,
            "先写事实，再写解释：补一个可观察事实，不需要完整结论。"
        )
        XCTAssertEqual(
            ReflectionQuestion(
                question: "怎么验证这个解释？",
                whyItMatters: "测假设",
                evidenceGapType: .missingCounterexample,
                answerUse: .testAssumption
            ).answerTrainingPrompt,
            "写支持或推翻：写出能验证或推翻假设的材料。"
        )
        XCTAssertEqual(
            ReflectionQuestion(
                question: "下一步选什么？",
                whyItMatters: "做取舍",
                evidenceGapType: EvidenceGapType.none,
                answerUse: .chooseAction
            ).answerTrainingPrompt,
            "写选择、取舍依据、完成标准：写出一个可执行选择。"
        )
        XCTAssertEqual(
            ReflectionQuestion(
                question: "明天观察什么结果？",
                whyItMatters: "留信号",
                evidenceGapType: .missingCalibrationSignal,
                answerUse: .watchCalibrationSignal
            ).answerTrainingPrompt,
            "写观察信号和更新条件：写出明天要观察的结果信号。"
        )
        XCTAssertEqual(
            ReflectionQuestion(
                question: "判断怎么变？",
                whyItMatters: "校准判断",
                evidenceGapType: EvidenceGapType.none,
                answerUse: .updateJudgment
            ).answerTrainingPrompt,
            "写原判断、依据、更新后判断：写下判断如何更新。"
        )
    }

    func testPrincipleRetrievalSignalDisplayText_mapsKnownSignalsAndFallsBackDeterministically() {
        XCTAssertEqual(
            PrincipleRetrievalSignalDisplay.displayText(for: " meeting ownership "),
            "命中会议负责人"
        )
        XCTAssertEqual(
            PrincipleRetrievalSignalDisplay.displayText(for: "acceptance contract"),
            "命中验收约定"
        )
        XCTAssertEqual(
            PrincipleRetrievalSignalDisplay.displayText(for: "custom local signal"),
            "命中 custom local signal"
        )
        XCTAssertNil(PrincipleRetrievalSignalDisplay.displayText(for: " "))
    }

    func testExistingLensTitles_unchanged() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.title, "证据校验")
        XCTAssertEqual(ThinkingLens.opposingView.title, "反方视角")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.title, "杠杆分析")
        XCTAssertEqual(ThinkingLens.systemThinking.title, "系统思维")
        XCTAssertEqual(ThinkingLens.judgmentCalibration.title, "判断校准")
    }

    func testExistingLensSubtitles_unchanged() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.subtitle, "把事实、判断和假设分开，先清理地基。")
        XCTAssertEqual(ThinkingLens.opposingView.subtitle, "主动寻找相反证据，避免只证明自己是对的。")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.subtitle, "找出最能改变结果的一步，把精力放在关键处。")
        XCTAssertEqual(ThinkingLens.systemThinking.subtitle, "看见反馈回路、延迟影响和二阶后果。")
        XCTAssertEqual(ThinkingLens.judgmentCalibration.subtitle, "用实际证据更新预测、信心和下一步判断。")
    }

    // MARK: - Visual QA Variant Selector

    func testVariantResolve_knownIds_allExist() {
        let knownIds: [String] = [
            "nil_project", "minimal", "normal", "accepted_insight",
            "pending_insight", "merge_history", "long_timeline",
            "long_name", "sparse_next_bet", "generating_insight"
        ]
        for id in knownIds {
            let variant = AppStore.resolveVisualQAProjectDetailVariant(
                environment: ["MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT": id]
            )
            XCTAssertEqual(variant.rawValue, id, "Variant id '\(id)' should resolve")
        }
    }

    func testVariantResolve_unknownFallsBackToNormal() {
        let variant = AppStore.resolveVisualQAProjectDetailVariant(
            environment: ["MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT": "nonexistent_variant"]
        )
        XCTAssertEqual(variant, .normal, "Unknown variant should fall back to normal")
    }

    func testVariantResolve_absentFallsBackToNormal() {
        let variant = AppStore.resolveVisualQAProjectDetailVariant(
            environment: [:]
        )
        XCTAssertEqual(variant, .normal, "Absent variant should fall back to normal")
    }

    func testVariantResolve_simctlChildPrefix() {
        let variant = AppStore.resolveVisualQAProjectDetailVariant(
            environment: ["SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT": "minimal"]
        )
        XCTAssertEqual(variant, .minimal, "SIMCTL_CHILD_ prefix should resolve")
    }

    // MARK: - All Variants Common Invariants

    func testAllVariants_startOnProjectsTab() {
        for variant in AppStore.VisualQAProjectDetailVariant.allCases {
            let store = AppStore.visualQAProjectDetail(variant: variant)
            XCTAssertEqual(store.selectedTab, .projects, "Variant \(variant.rawValue) must start on projects tab")
        }
    }

    func testAllVariants_haveDirectEntryProjectID() {
        for variant in AppStore.VisualQAProjectDetailVariant.allCases {
            let store = AppStore.visualQAProjectDetail(variant: variant)
            XCTAssertNotNil(
                store.visualQAProjectDetailDirectEntryProjectID,
                "Variant \(variant.rawValue) must expose direct-entry project id"
            )
        }
    }

    func testAllVariants_directEntryID_hasBoardItem() {
        for variant in AppStore.VisualQAProjectDetailVariant.allCases {
            let store = AppStore.visualQAProjectDetail(variant: variant)
            let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
            let hasLink = store.historyRecords.contains { record in
                record.projectLinks.contains { $0.projectId == directEntryID }
            }
            XCTAssertTrue(
                hasLink,
                "Variant \(variant.rawValue) must have a board item (ProjectLink) for the direct-entry id"
            )
        }
    }

    func testAllVariants_projectLinksResolveToFixtureSources() {
        for variant in AppStore.VisualQAProjectDetailVariant.allCases {
            let store = AppStore.visualQAProjectDetail(variant: variant)
            let unresolvedLinks = store.historyRecords.flatMap { record in
                record.projectLinks.filter { link in
                    switch link.sourceType {
                    case .dailyEntry:
                        return link.sourceId != record.draft.id.uuidString
                    case .thinkingCard:
                        return !record.cards.contains { $0.id.uuidString == link.sourceId }
                    case .quest:
                        return !record.quests.contains { $0.id.uuidString == link.sourceId }
                    case .verification:
                        return record.verification == nil
                    case .principle:
                        return !record.principles.contains { $0.id.uuidString == link.sourceId }
                    }
                }
            }
            XCTAssertTrue(
                unresolvedLinks.isEmpty,
                "Variant \(variant.rawValue) must keep ProjectLink source ids resolvable in History evidence"
            )
        }
    }

    func testAllVariants_optOutOfLoadPersistedState() {
        for variant in AppStore.VisualQAProjectDetailVariant.allCases {
            let store = AppStore.visualQAProjectDetail(variant: variant)
            XCTAssertFalse(
                store.loadsPersistedStateOnLaunch,
                "Variant \(variant.rawValue) must opt out of loading persisted state"
            )
        }
    }

    // MARK: - Project Detail Display Helpers

    func testProjectDetailStatusChipText_usesChineseStatusAndFallback() {
        XCTAssertEqual(projectDetailStatusChipText(for: .active), "活跃")
        XCTAssertEqual(projectDetailStatusChipText(for: .watching), "关注中")
        XCTAssertEqual(projectDetailStatusChipText(for: .paused), "暂停")
        XCTAssertEqual(projectDetailStatusChipText(for: .archived), "已归档")
        XCTAssertEqual(projectDetailStatusChipText(for: nil), "活跃")
    }

    func testProjectDetailThinkingChangeVisibility_requiresAcceptedInsightOrBeforeAfterEvidence() {
        XCTAssertFalse(
            shouldShowProjectDetailThinkingChange(
                hasBeforeAfterEvidence: false,
                acceptedInsightCount: 0
            )
        )
        XCTAssertTrue(
            shouldShowProjectDetailThinkingChange(
                hasBeforeAfterEvidence: true,
                acceptedInsightCount: 0
            )
        )
        XCTAssertTrue(
            shouldShowProjectDetailThinkingChange(
                hasBeforeAfterEvidence: false,
                acceptedInsightCount: 1
            )
        )
    }

    func testProjectDetailTimelineDisplay_boundsLongTimelineUntilExpanded() {
        XCTAssertEqual(projectDetailTimelineVisibleCount(totalCount: 10, isExpanded: false), 5)
        XCTAssertEqual(projectDetailTimelineVisibleCount(totalCount: 10, isExpanded: true), 10)
        XCTAssertEqual(projectDetailTimelineVisibleCount(totalCount: 3, isExpanded: false), 3)
        XCTAssertEqual(projectDetailTimelineToggleTitle(totalCount: 10, isExpanded: false), "查看全部 10 条证据")
        XCTAssertEqual(projectDetailTimelineToggleTitle(totalCount: 10, isExpanded: true), "收起证据")
        XCTAssertNil(projectDetailTimelineToggleTitle(totalCount: 5, isExpanded: false))
    }

    func testProjectDetailProgressSignalDisplay_boundsLongSignalsUntilExpanded() {
        XCTAssertEqual(projectDetailTimelineVisibleCount(totalCount: 10, isExpanded: false, collapsedLimit: 2), 2)
        XCTAssertEqual(projectDetailTimelineVisibleCount(totalCount: 10, isExpanded: true, collapsedLimit: 2), 10)
        XCTAssertEqual(projectDetailProgressSignalsToggleTitle(totalCount: 10, isExpanded: false), "查看全部 10 条进展")
        XCTAssertEqual(projectDetailProgressSignalsToggleTitle(totalCount: 10, isExpanded: true), "收起进展")
        XCTAssertNil(projectDetailProgressSignalsToggleTitle(totalCount: 2, isExpanded: false))
    }

    // MARK: - Variant-Specific Shape Tests

    func testVariant_nilProject_hasNoPersistedProject() {
        let store = AppStore.visualQAProjectDetail(variant: .nil_project)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        XCTAssertNil(
            store.projectsById[directEntryID],
            "nil_project must have no persisted Project for the direct-entry id"
        )
        XCTAssertNil(
            store.projectNames[directEntryID],
            "nil_project must have no project name for the direct-entry id"
        )
    }

    func testVariant_minimal_hasAtMostOneConfirmedLink() {
        let store = AppStore.visualQAProjectDetail(variant: .minimal)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let confirmedLinks = store.historyRecords.flatMap(\.projectLinks).filter {
            $0.projectId == directEntryID && $0.isUserConfirmed
        }
        XCTAssertLessThanOrEqual(
            confirmedLinks.count, 1,
            "minimal variant must have 0 or 1 confirmed evidence links"
        )
    }

    func testVariant_normal_preservesExistingFixtureBehavior() {
        let store = AppStore.visualQAProjectDetail(variant: .normal)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        XCTAssertNotNil(store.projectsById[directEntryID])
        XCTAssertEqual(store.projectNames[directEntryID], "Visual QA - 会议机制优化")
        XCTAssertFalse(store.acceptedProjectInsights.isEmpty)
        XCTAssertFalse(store.pendingProjectInsights.isEmpty)
    }

    func testVariant_acceptedInsight_hasAcceptedInsightRecords() {
        let store = AppStore.visualQAProjectDetail(variant: .accepted_insight)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let hasAccepted = store.acceptedProjectInsights.contains { $0.projectId == directEntryID }
        XCTAssertTrue(hasAccepted, "accepted_insight must have accepted ProjectInsight for direct-entry project")
    }

    func testVariant_pendingInsight_hasPendingInsightRecords() {
        let store = AppStore.visualQAProjectDetail(variant: .pending_insight)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let hasPending = store.pendingProjectInsights.contains { $0.projectId == directEntryID }
        XCTAssertTrue(hasPending, "pending_insight must have pending ProjectInsight for direct-entry project")
    }

    func testVariant_mergeHistory_hasNonEmptyMergeHistory() {
        let store = AppStore.visualQAProjectDetail(variant: .merge_history)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let project = store.projectsById[directEntryID]
        XCTAssertNotNil(project)
        XCTAssertFalse(project!.mergeHistory.isEmpty, "merge_history must have non-empty mergeHistory")
    }

    func testVariant_longTimeline_hasAtLeast10ConfirmedLinks() {
        let store = AppStore.visualQAProjectDetail(variant: .long_timeline)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let confirmedLinks = store.historyRecords.flatMap(\.projectLinks).filter {
            $0.projectId == directEntryID && $0.isUserConfirmed
        }
        XCTAssertGreaterThanOrEqual(
            confirmedLinks.count, 10,
            "long_timeline must have at least 10 confirmed project links"
        )
    }

    func testVariant_longName_hasLongName() {
        let store = AppStore.visualQAProjectDetail(variant: .long_name)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let name = store.projectNames[directEntryID]
        XCTAssertNotNil(name)
        XCTAssertTrue(name!.count > 30, "long_name must use a long project name (got: \(name!.count) chars)")
    }

    func testVariant_sparseNextBet_hasSparseOverviewAndDerivedNextBet() {
        let store = AppStore.visualQAProjectDetail(variant: .sparse_next_bet)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID!
        let project = store.projectsById[directEntryID]
        XCTAssertNotNil(project)
        XCTAssertTrue(project!.goal.isEmpty)
        XCTAssertTrue(project!.successCriteria.isEmpty)
        XCTAssertNil(project!.currentBottleneck)
        XCTAssertTrue(project!.openQuestions.isEmpty)

        let evidence = store.historyRecords.flatMap { record in
            record.projectLinks
                .filter { $0.projectId == directEntryID }
                .map { (link: $0, record: record) }
        }
        let digest = ProjectEvidenceDigest(projectId: directEntryID, evidence: evidence)
        XCTAssertNotNil(digest.nextBet, "sparse_next_bet must derive nextBet from fixture evidence")
    }

    func testVariant_generatingInsight_setsFlag() {
        let store = AppStore.visualQAProjectDetail(variant: .generating_insight)
        XCTAssertTrue(
            store.isGeneratingProjectInsights,
            "generating_insight must set isGeneratingProjectInsights"
        )
    }

    // MARK: - Apply Fixture with Variant

    func testApplyVisualQAProjectDetailFixture_withVariant_preservesDirectEntryID() {
        let store = AppStore(refreshesAIServiceFromKeychain: false)
        store.applyVisualQAProjectDetailFixture(variant: .long_name)
        let directEntryID = store.visualQAProjectDetailDirectEntryProjectID
        XCTAssertNotNil(directEntryID, "applyFixture with variant must preserve direct-entry id")
        let name = store.projectNames[directEntryID!]
        XCTAssertTrue(name!.count > 30, "applied variant should match long_name shape")
    }

    func testNormalStore_unaffectedByVariantSelector() {
        let normalStore = AppStore(refreshesAIServiceFromKeychain: false)
        XCTAssertNil(normalStore.visualQAProjectDetailDirectEntryProjectID)
        XCTAssertTrue(normalStore.loadsPersistedStateOnLaunch)
    }
}

private struct AppStoreRollbackFixturePromptProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        var template = base.template(for: id, mode: mode)
        if id == .generateQuestions {
            template.rollbackTargetVersion = "0.9.0"
        }
        return template
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        base.template(for: id, mode: mode, version: version)
    }
}

private struct AppStoreExecutableRollbackFixturePromptProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        var template = base.template(for: id, mode: mode)
        if id == .generateQuestions {
            template.rollbackTargetVersion = "0.9.0"
        }
        return template
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let template = base.template(for: id, mode: mode)
        guard id == .generateQuestions, version == "0.9.0" else {
            return template.version == version ? template : nil
        }
        return PromptTemplate(
            id: template.id,
            version: "0.9.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            rollbackTargetVersion: nil,
            systemText: template.systemText,
            userText: template.userText,
            outputSchemaVersion: template.outputSchemaVersion
        )
    }
}

private struct AppStoreImportedPromptPackRollbackFixtureProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        if id == .generateQuestions {
            return importedTemplate(version: "1.1.0", packVersion: "2026.06", rollbackTargetVersion: "1.0.0")
        }
        return base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        guard id == .generateQuestions else {
            let template = base.template(for: id, mode: mode)
            return template.version == version ? template : nil
        }
        switch version {
        case "1.1.0":
            return importedTemplate(version: "1.1.0", packVersion: "2026.06", rollbackTargetVersion: "1.0.0")
        case "1.0.0":
            return importedTemplate(version: "1.0.0", packVersion: "2026.05", rollbackTargetVersion: nil)
        default:
            return nil
        }
    }

    private func importedTemplate(
        version: String,
        packVersion: String,
        rollbackTargetVersion: String?
    ) -> PromptTemplate {
        let baseTemplate = base.template(for: .generateQuestions, mode: .standard)
        return PromptTemplate(
            id: .generateQuestions,
            version: version,
            systemPolicyVersion: baseTemplate.systemPolicyVersion,
            contextPolicyVersion: baseTemplate.contextPolicyVersion,
            evalSuiteVersion: baseTemplate.evalSuiteVersion,
            rollbackTargetVersion: rollbackTargetVersion,
            sourceKind: .marketplace,
            packId: "marketplace.prompts.coach",
            packVersion: packVersion,
            packDisplayName: "Coach Prompt Pack",
            systemText: baseTemplate.systemText,
            userText: "Imported questions prompt \(version).",
            outputSchemaVersion: baseTemplate.outputSchemaVersion
        )
    }
}
