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
        XCTAssertFalse(store.todayLoopMessage.isEmpty)
    }

    func testVerifyYesterday_withQuest_requiresValueRating() {
        store.quests = [activeMainQuest()]
        store.selectYesterdayCompletion(.done)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
    }

    func testVerifyYesterday_withQuestAndBothSelections_advancesToCapture() async throws {
        store.quests = [activeMainQuest()]
        store.selectYesterdayCompletion(.partial)
        store.selectYesterdayValueRating(.medium)
        store.submitTodayStep()
        try await waitForState(.capture)
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
        XCTAssertEqual(request.jsonPayload["sessionMode"], SessionMode.deep.rawValue)
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

    // MARK: - SelectLens -> AnswerQuestions

    func testSelectLens_noLensSelected_blocksProgression() async throws {
        try await advanceTo(.selectLens)
        store.todayDraft.selectedLens = nil
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectLens)
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
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(request.contextRecordIDs.contains(historicalPrinciple.id.uuidString))
        XCTAssertEqual(store.referencedPrinciples.map(\.id), [historicalPrinciple.id])

        store.navigateTodayLoop(to: .reviewCards)
        XCTAssertTrue(store.referencedPrinciples.isEmpty)
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

    func testAnswerQuestions_withAnsweredQuestion_generatesQuests() async throws {
        try await advanceTo(.answerQuestions)
        store.questions = [
            ReflectionQuestion(question: "Q?", whyItMatters: "Matters", answer: "My answer")
        ]
        store.submitTodayStep()
        try await waitForState(.reviewQuests)
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
        XCTAssertEqual(request.title, "明日主线任务")
        XCTAssertEqual(request.body, "Confirm meeting owner")
        XCTAssertTrue(store.reminderStatusMessage.contains("提醒已安排"))
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
            var question = q; question.answer = "Focus on the main blocker."; return question
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
        XCTAssertTrue(store.todayLoopMessage.contains("AI 整理卡片失败"))
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
            store.todayLoopMessage.contains("重试失败"),
            timeout: 2,
            file: #filePath,
            line: #line,
            failureMessage: "Expected retry failure message"
        ) {
            store.todayLoopMessage.contains("重试失败")
        }
        XCTAssertEqual(store.pendingAIRepairCount, 1)
        XCTAssertEqual(store.thinkingCards.first?.title, fallbackTitle)
        XCTAssertTrue(store.canRetryCurrentAI)
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
        XCTAssertTrue(store.todayLoopMessage.contains("AI 正在运行"))

        llmClient.release()
        try await waitForGeneratedCards()
        XCTAssertFalse(store.isAIRunning)
        XCTAssertEqual(store.thinkingCards.first?.title, "Slow AI card")
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
        XCTAssertTrue(auditStore.promptRunAuditMessage.isEmpty)
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

    func testLoadLatestGrowthSnapshot_loadsAcceptedReportReviewContributions() async throws {
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
        let acceptedPositive = MetricContribution(
            snapshotId: snapshot.id,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Clearer task",
            reason: "The quest had visible completion evidence.",
            sourceType: .quest,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID(),
            candidateStatus: .accepted
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
        try await contributionRepo.saveContribution(acceptedPositive)
        try await contributionRepo.saveContribution(acceptedNegative)
        try await contributionRepo.saveContribution(rejected)

        let growthStore = AppStore(
            metricSnapshotRepository: snapshotRepo,
            metricContributionRepository: contributionRepo,
            refreshesAIServiceFromKeychain: false
        )

        await growthStore.loadLatestGrowthSnapshot()

        XCTAssertEqual(growthStore.growthReportReviewContributions.map(\.id), [acceptedPositive.id, acceptedNegative.id])
        XCTAssertEqual(growthStore.acceptedReportReviewContributions(for: .clarity).map(\.id), [acceptedPositive.id])
        XCTAssertEqual(growthStore.acceptedReportReviewContributions(for: .valueJudgment).map(\.id), [acceptedNegative.id])
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
            candidateStatus: .accepted
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

    func testGenerateWeeklyGrowthReport_withEnoughEvidencePersistsAISnapshotAndContributions() async throws {
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
        XCTAssertEqual(savedContributions[0].candidateStatus, .accepted)
        XCTAssertEqual(growthStore.growthReportReviewContributions.map(\.id), savedContributions.map(\.id))
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
                ReflectionQuestion(question: "Q?", whyItMatters: "M", answer: "Focus on the main blocker.")
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

    func testVisualQATodayStageSeed_answerQuestionsSeedsLensQuestions() {
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

    init(results: [Result]) {
        self.results = results
    }

    func complete(_ request: LLMRequest) async throws -> Data {
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

    func activePrinciples() async throws -> [PrincipleAsset] {
        principlesById.values.filter { $0.status == .active }
    }

    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset] {
        (entryPrincipleIds[dailyEntryId] ?? []).compactMap { principlesById[$0] }
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

    // MARK: - ThinkingLens Catalog

    func testThinkingLens_allCases_containsFirstPrinciples() {
        XCTAssertTrue(ThinkingLens.allCases.contains(.firstPrinciples),
                       "firstPrinciples should appear in allCases")
    }

    func testThinkingLens_existingRawValues_stable() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.rawValue, "evidenceCheck")
        XCTAssertEqual(ThinkingLens.opposingView.rawValue, "opposingView")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.rawValue, "leverageAnalysis")
        XCTAssertEqual(ThinkingLens.firstPrinciples.rawValue, "firstPrinciples")
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
    }

    func testFirstPrinciples_metadata() {
        let item = ThinkingLens.firstPrinciples.catalogItem
        XCTAssertEqual(item.title, "第一性原理")
        XCTAssertEqual(item.promptId, "first_principles")
        XCTAssertEqual(item.version, "builtin.v1")
        XCTAssertTrue(item.promptGuidance.contains("non-negotiable facts"))
        XCTAssertFalse(item.symbolName.isEmpty, "symbolName should not be empty")
    }

    func testFirstPrinciples_rawValue() {
        XCTAssertEqual(ThinkingLens.firstPrinciples.rawValue, "firstPrinciples")
    }

    func testExistingLensTitles_unchanged() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.title, "证据校验")
        XCTAssertEqual(ThinkingLens.opposingView.title, "反方视角")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.title, "杠杆分析")
    }

    func testExistingLensSubtitles_unchanged() {
        XCTAssertEqual(ThinkingLens.evidenceCheck.subtitle, "把事实、判断和假设分开，先清理地基。")
        XCTAssertEqual(ThinkingLens.opposingView.subtitle, "主动寻找相反证据，避免只证明自己是对的。")
        XCTAssertEqual(ThinkingLens.leverageAnalysis.subtitle, "找出最能改变结果的一步，把精力放在关键处。")
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
