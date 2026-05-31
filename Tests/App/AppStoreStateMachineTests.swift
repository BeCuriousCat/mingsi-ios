import XCTest
@testable import MingSi

@MainActor
final class AppStoreStateMachineTests: XCTestCase {

    private var store: AppStore!

    override func setUp() {
        super.setUp()
        store = AppStore()
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

    // MARK: - VerifyYesterday -> Capture (synchronous)

    func testVerifyYesterday_requiresCompletionSelection() {
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
        XCTAssertFalse(store.todayLoopMessage.isEmpty)
    }

    func testVerifyYesterday_requiresValueRating() {
        store.selectYesterdayCompletion(.done)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .verifyYesterday)
    }

    func testVerifyYesterday_withBothSelections_advancesToCapture() {
        store.selectYesterdayCompletion(.partial)
        store.selectYesterdayValueRating(.medium)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .capture)
    }

    // MARK: - Capture -> Organizing (async card generation, stays at .organizing)

    func testCapture_emptyInput_blocksProgression() async throws {
        try await advanceTo(.capture)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .capture)
        XCTAssertFalse(store.todayLoopMessage.isEmpty)
    }

    func testCapture_withInput_movesToOrganizing() async throws {
        try await advanceTo(.capture)
        store.updateTodayCapture("Today I had a meeting about project priorities.")
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .organizing)
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

    // MARK: - ReviewCards -> SelectMode

    func testReviewCards_noConfirmedCards_blocksProgression() async throws {
        try await advanceTo(.reviewCards)
        store.thinkingCards = [
            ThinkingCard(type: .fact, title: "Unconfirmed", body: "Body")
        ]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .reviewCards)
    }

    func testReviewCards_withConfirmedCards_advancesToSelectMode() async throws {
        try await advanceTo(.reviewCards)
        var card = ThinkingCard(type: .fact, title: "Test", body: "Body")
        card.isConfirmed = true
        store.thinkingCards = [card]
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectMode)
    }

    // MARK: - SelectMode -> SelectLens

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
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(store.todayDraft.state, .reviewQuests)
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

    // MARK: - ExtractPrinciple -> SessionComplete

    func testExtractPrinciple_savePrinciple_advancesToSessionComplete() async throws {
        try await advanceTo(.extractPrinciple)
        store.principles = [
            PrincipleAsset(title: "Test principle", summary: "Summary",
                          triggerContext: "Context", actions: ["Act"],
                          successCriteria: "Criteria", exceptions: "None")
        ]
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
        store.updateTodayCapture("Had a productive meeting about the project roadmap.")
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .organizing)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(store.thinkingCards.isEmpty)

        // organizing -> reviewCards
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .reviewCards)

        // reviewCards -> selectMode
        store.thinkingCards = store.thinkingCards.map { card in
            var c = card; c.isConfirmed = true; return c
        }
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectMode)

        // selectMode -> selectLens
        store.selectTodayMode(.standard)
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .selectLens)

        // selectLens -> answerQuestions (async question generation)
        store.selectThinkingLens(.leverageAnalysis)
        store.submitTodayStep()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(store.todayDraft.state, .answerQuestions)
        XCTAssertFalse(store.questions.isEmpty)

        // answerQuestions -> reviewQuests (async quest generation)
        store.questions = store.questions.map { q in
            var question = q; question.answer = "Focus on the main blocker."; return question
        }
        store.submitTodayStep()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(store.todayDraft.state, .reviewQuests)

        // reviewQuests -> extractPrinciple (async principle generation)
        var quest = Quest(type: .main, title: "Confirm ownership",
                          whyItMatters: "Reduces rework", completionCriteria: "Owner confirmed",
                          expectedResistance: "Cross-role discussion", reflectionQuestion: "What changed?")
        quest.status = .active
        store.quests = [quest]
        store.submitTodayStep()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(store.todayDraft.state, .extractPrinciple)

        // extractPrinciple -> sessionComplete
        store.submitTodayStep()
        XCTAssertEqual(store.todayDraft.state, .sessionComplete)
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

        case .organizing:
            try await advanceTo(.capture)
            store.updateTodayCapture("Today I discussed project priorities with the team.")
            store.submitTodayStep()
            // Async card generation fires but state stays at .organizing
            try await Task.sleep(for: .milliseconds(300))

        case .reviewCards:
            try await advanceTo(.organizing)
            // After async card generation, cards exist but state is still .organizing
            // Submit again to advance organizing -> reviewCards
            store.submitTodayStep()

        case .selectMode:
            try await advanceTo(.reviewCards)
            var card = ThinkingCard(type: .problem, title: "Confirmed", body: "Body")
            card.isConfirmed = true
            store.thinkingCards = [card]
            store.submitTodayStep()

        case .selectLens:
            try await advanceTo(.selectMode)
            store.selectTodayMode(.standard)
            store.submitTodayStep()

        case .answerQuestions:
            try await advanceTo(.selectLens)
            store.selectThinkingLens(.leverageAnalysis)
            store.questions = [
                ReflectionQuestion(question: "What is the highest-value action?", whyItMatters: "Forces prioritization")
            ]
            store.submitTodayStep()
            try await Task.sleep(for: .milliseconds(300))

        case .reviewQuests:
            try await advanceTo(.answerQuestions)
            store.questions = [
                ReflectionQuestion(question: "Q?", whyItMatters: "M", answer: "Focus on the main blocker.")
            ]
            store.submitTodayStep()
            try await Task.sleep(for: .milliseconds(300))

        case .extractPrinciple:
            try await advanceTo(.reviewQuests)
            var quest = Quest(type: .main, title: "Valid quest", whyItMatters: "W",
                              completionCriteria: "Criteria met", expectedResistance: "E",
                              reflectionQuestion: "R")
            quest.status = .active
            store.quests = [quest]
            store.submitTodayStep()
            try await Task.sleep(for: .milliseconds(300))

        case .sessionComplete:
            try await advanceTo(.extractPrinciple)
            store.principles = [
                PrincipleAsset(title: "P", summary: "S", triggerContext: "T",
                              actions: ["A"], successCriteria: "SC", exceptions: "E")
            ]
            store.submitTodayStep()
        }
    }
}
