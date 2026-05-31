import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var todayDraft: DailyEntryDraft
    @Published var thinkingCards: [ThinkingCard]
    @Published var questions: [ReflectionQuestion]
    @Published var quests: [Quest]
    @Published var principles: [PrincipleAsset]
    @Published var growthSnapshot: MetricSnapshot
    @Published var hasResumeableLoop: Bool = true
    @Published var apiKeyConfigured: Bool = false
    @Published var settingsMessage: String = ""
    @Published var todayLoopMessage: String = ""
    @Published private(set) var reminderStatusMessage: String = "明日 09:00 本地提醒将在保存主线任务后请求授权。"

    private let apiKeyStore: KeychainAPIKeyStore
    private let dailyEntryRepository: DailyEntryRepository?
    private let thinkingCardRepository: ThinkingCardRepository?
    private let questRepository: QuestRepository?
    private let principleRepository: PrincipleRepository?
    private let reminderService: ReminderService?
    private let persistenceUnavailableMessage: String?
    private var todayAIService: TodayAIService?
    private var apiKeyStatusMessage: String = ""
    private var scheduledReminderIDs: Set<String> = []

    init(
        todayDraft: DailyEntryDraft? = nil,
        thinkingCards: [ThinkingCard]? = nil,
        questions: [ReflectionQuestion]? = nil,
        quests: [Quest]? = nil,
        principles: [PrincipleAsset]? = nil,
        growthSnapshot: MetricSnapshot? = nil,
        apiKeyStore: KeychainAPIKeyStore = KeychainAPIKeyStore(),
        dailyEntryRepository: DailyEntryRepository? = nil,
        thinkingCardRepository: ThinkingCardRepository? = nil,
        questRepository: QuestRepository? = nil,
        principleRepository: PrincipleRepository? = nil,
        reminderService: ReminderService? = nil,
        todayAIService: TodayAIService? = nil,
        persistenceUnavailableMessage: String? = nil
    ) {
        self.apiKeyStore = apiKeyStore
        self.dailyEntryRepository = dailyEntryRepository
        self.thinkingCardRepository = thinkingCardRepository
        self.questRepository = questRepository
        self.principleRepository = principleRepository
        self.reminderService = reminderService
        self.todayAIService = todayAIService
        self.persistenceUnavailableMessage = persistenceUnavailableMessage
        self.todayDraft = todayDraft ?? DailyEntryDraft()
        self.thinkingCards = thinkingCards ?? []
        self.questions = questions ?? []
        self.quests = quests ?? Self.makePreviewQuests()
        self.principles = principles ?? []
        self.growthSnapshot = growthSnapshot ?? Self.makePreviewGrowth()
        refreshAPIKeyStatus()
    }

    static func live() -> AppStore {
        let apiKeyStore = KeychainAPIKeyStore()
        let todayAIService = makeTodayAIService(apiKeyStore: apiKeyStore)

        do {
            let database = try AppDatabase(url: AppDatabase.defaultURL())
            return AppStore(
                apiKeyStore: apiKeyStore,
                dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
                thinkingCardRepository: SQLiteThinkingCardRepository(database: database),
                questRepository: SQLiteQuestRepository(database: database),
                principleRepository: SQLitePrincipleRepository(database: database),
                reminderService: LocalNotificationReminder(),
                todayAIService: todayAIService
            )
        } catch {
            return AppStore(
                apiKeyStore: apiKeyStore,
                reminderService: LocalNotificationReminder(),
                todayAIService: todayAIService,
                persistenceUnavailableMessage: "本地数据库初始化失败，当前使用临时内存数据。"
            )
        }
    }

    static var preview: AppStore {
        AppStore(
            todayDraft: makePreviewDraft(),
            thinkingCards: makePreviewCards(),
            questions: makePreviewQuestions(),
            quests: makePreviewQuests(),
            principles: makePreviewPrinciples(),
            growthSnapshot: makePreviewGrowth()
        )
    }

    nonisolated static func makePreviewDraft() -> DailyEntryDraft {
        DailyEntryDraft(
            rawText: "今天开了一个会议，但还没把明天最重要的动作想清楚。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .leverageAnalysis,
            yesterdayCompletion: .partial,
            yesterdayValueRating: .medium,
            state: .verifyYesterday
        )
    }

    nonisolated static func makePreviewCards() -> [ThinkingCard] {
        [
            ThinkingCard(
            type: .problem,
            title: "会议目标不够清楚",
            body: "今天的会议讨论了很多内容，但没有先明确本次必须确认的事项。",
            priority: .high,
            sensitivity: .normal,
            confidence: 0.88,
            isConfirmed: true
            ),
            ThinkingCard(
            type: .risk,
            title: "技术债继续累积",
            body: "如果接口归属不清晰，后续还会继续发生返工。",
            priority: .high,
            sensitivity: .normal,
            confidence: 0.82,
            isConfirmed: true
            ),
            ThinkingCard(
            type: .task,
            title: "明天确认接口归属",
            body: "把当前接口的责任人、输入输出和验收方式确认清楚。",
            priority: .high,
            sensitivity: .normal,
            confidence: 0.91,
            isConfirmed: true
            )
        ]
    }

    nonisolated static func makePreviewQuestions() -> [ReflectionQuestion] {
        [
            ReflectionQuestion(
            question: "如果明天只能推进一件最有价值的事，应该是哪一件？",
            whyItMatters: "帮助用户聚焦真正值得做的动作。",
            answer: "先确认接口归属，再发会后总结。"
            ),
            ReflectionQuestion(
            question: "这次会议最可能被忽略的风险是什么？",
            whyItMatters: "帮助用户提前发现重复返工的来源。",
            answer: "如果没有明确负责人，后续会继续扯皮。"
            )
        ]
    }

    nonisolated static func makePreviewQuests() -> [Quest] {
        [
            Quest(
            type: .main,
            title: "明天确认接口归属",
            whyItMatters: "避免接口定义继续模糊。",
            completionCriteria: "确认责任人、输入输出和验收方式。",
            expectedResistance: "会涉及跨角色沟通，需要提前准备。",
            reflectionQuestion: "这次确认后，哪些返工风险被降低了？",
            status: .active
            ),
            Quest(
            type: .side,
            title: "整理会议摘要",
            whyItMatters: "让群里知道结论和行动项。",
            completionCriteria: "发出简洁摘要并 @ 到相关人。",
            expectedResistance: "容易被临时事务打断。",
            reflectionQuestion: "摘要是否足够简洁且可执行？",
            status: .draft
            )
        ]
    }

    nonisolated static func makePreviewPrinciples() -> [PrincipleAsset] {
        [
            PrincipleAsset(
            title: "会议前先定义必须确认的问题",
            summary: "开会前先列 1-3 个必须解决的问题，再进入讨论。",
            triggerContext: "项目会议、跨团队对齐、需要结论的讨论。",
            actions: [
                "会前写出确认事项。",
                "会后写出结论、Action 和负责人。",
                "把会后摘要发到群里。"
            ],
            successCriteria: "会议结束后所有人知道谁做什么、什么时候交付。",
            exceptions: "仅用于需要明确结论的会议；例行同步可简化。"
            )
        ]
    }

    nonisolated static func makePreviewGrowth() -> MetricSnapshot {
        MetricSnapshot(
            period: "weekly",
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            summary: "本周对会议类问题的定义更清楚，但会后验证仍然偏少。"
        )
    }

    var currentStateTitle: String {
        todayDraft.state.title
    }

    var loopResumeText: String {
        todayDraft.state == .sessionComplete ? "今日闭环已完成" : "今日复盘未完成"
    }

    var hasAnsweredReflectionQuestion: Bool {
        questions.contains { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var mainQuest: Quest? {
        quests.first { $0.type == .main }
    }

    func loadPersistedState() async {
        guard let dailyEntryRepository else {
            updateSettingsMessage()
            return
        }

        do {
            guard let draft = try await dailyEntryRepository.latestDraft() else {
                persistDraft()
                return
            }
            todayDraft = draft
            hasResumeableLoop = draft.state != .sessionComplete

            if let cards = try await thinkingCardRepository?.cards(for: draft.id) {
                thinkingCards = cards
            }
            if let storedQuests = try await questRepository?.quests(for: draft.id), !storedQuests.isEmpty {
                quests = storedQuests
            }
            if let storedPrinciples = try await principleRepository?.principles(for: draft.id) {
                principles = storedPrinciples
            }
        } catch {
            todayLoopMessage = "读取本地复盘记录失败，已继续使用当前内存数据。"
        }

        updateSettingsMessage()
    }

    func submitTodayStep() {
        switch todayDraft.state {
        case .verifyYesterday:
            saveYesterdayVerification()
        case .capture:
            organizeCapture()
        case .organizing:
            showReviewedCards()
        case .reviewCards:
            confirmReviewedCards()
        case .selectMode:
            confirmSelectedMode()
        case .selectLens:
            confirmSelectedLens()
        case .answerQuestions:
            generateQuestsFromAnswers()
        case .reviewQuests:
            saveReviewedQuests()
        case .extractPrinciple:
            savePrinciple()
        case .sessionComplete:
            resetTodayLoop()
        }
    }

    func selectYesterdayCompletion(_ completion: YesterdayCompletion) {
        todayDraft.yesterdayCompletion = completion
        clearTodayLoopMessage()
        persistDraft()
    }

    func selectYesterdayValueRating(_ rating: YesterdayValueRating) {
        todayDraft.yesterdayValueRating = rating
        clearTodayLoopMessage()
        persistDraft()
    }

    func updateTodayCapture(_ text: String) {
        todayDraft.rawText = text
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clearTodayLoopMessage()
        }
        persistDraft()
    }

    func confirmCard(_ cardID: ThinkingCard.ID) {
        updateCard(cardID) { card in
            card.isConfirmed = true
            card.isExcludedFromModel = false
        }
    }

    func excludeCard(_ cardID: ThinkingCard.ID) {
        updateCard(cardID) { card in
            card.isConfirmed = false
            card.isExcludedFromModel = true
        }
    }

    func deleteCard(_ cardID: ThinkingCard.ID) {
        thinkingCards.removeAll { $0.id == cardID }
        clearTodayLoopMessage()
        persistCards()
    }

    func selectTodayMode(_ mode: SessionMode) {
        todayDraft.sessionMode = mode
        todayDraft.hasSelectedSessionMode = true
        clearTodayLoopMessage()
        persistDraft()
    }

    func selectThinkingLens(_ lens: ThinkingLens) {
        todayDraft.selectedLens = lens
        clearTodayLoopMessage()
        persistDraft()
    }

    func updateQuestionAnswer(questionID: ReflectionQuestion.ID, answer: String) {
        guard let index = questions.firstIndex(where: { $0.id == questionID }) else { return }
        questions[index].answer = answer
        if !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clearTodayLoopMessage()
        }
    }

    func skipPrinciple() {
        principles = []
        persistPrinciples()
        completeTodayLoop(message: "已跳过原则沉淀，今日闭环完成。")
    }

    func resetTodayLoop() {
        todayDraft = DailyEntryDraft()
        thinkingCards = []
        questions = []
        quests = Self.makePreviewQuests()
        principles = []
        hasResumeableLoop = true
        todayLoopMessage = ""
        reminderStatusMessage = "明日 09:00 本地提醒将在保存主线任务后请求授权。"
        persistDraft()
    }

    private func saveYesterdayVerification() {
        guard todayDraft.yesterdayCompletion != nil else {
            todayLoopMessage = "请选择昨天主线任务的完成情况。"
            return
        }
        guard todayDraft.yesterdayValueRating != nil else {
            todayLoopMessage = "请选择昨天任务的价值判断。"
            return
        }
        moveTodayLoop(to: .capture)
    }

    private func organizeCapture() {
        let trimmedInput = todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            todayLoopMessage = "请输入至少一条今天的事实、困惑或行动，再整理成卡片。"
            return
        }

        let draftID = todayDraft.id
        moveTodayLoop(to: .organizing, message: "正在生成结构化卡片。")
        Task {
            await generateCardsWithAIOrFallback(from: trimmedInput, draftID: draftID)
        }
    }

    private func showReviewedCards() {
        guard !thinkingCards.isEmpty else {
            todayLoopMessage = "没有可 review 的卡片，请回到输入补充内容。"
            return
        }
        moveTodayLoop(to: .reviewCards)
    }

    private func confirmReviewedCards() {
        guard thinkingCards.contains(where: { $0.isConfirmed }) else {
            todayLoopMessage = "至少确认一张卡片，才能进入训练模式选择。"
            return
        }
        moveTodayLoop(to: .selectMode)
    }

    private func confirmSelectedMode() {
        guard todayDraft.hasSelectedSessionMode else {
            todayLoopMessage = "请选择 Quick、Standard 或 Deep。"
            return
        }
        moveTodayLoop(to: .selectLens)
    }

    private func confirmSelectedLens() {
        guard todayDraft.selectedLens != nil else {
            todayLoopMessage = "请选择一个思考透镜。"
            return
        }
        if questions.isEmpty {
            let draftID = todayDraft.id
            todayLoopMessage = "正在生成追问。"
            Task {
                await generateQuestionsWithAIOrFallback(draftID: draftID)
            }
            return
        }
        moveTodayLoop(to: .answerQuestions)
    }

    private func generateQuestsFromAnswers() {
        guard hasAnsweredReflectionQuestion else {
            todayLoopMessage = "至少回答一个问题，才能生成明日任务。"
            return
        }
        let draftID = todayDraft.id
        todayLoopMessage = "正在生成明日任务。"
        Task {
            await generateQuestsWithAIOrFallback(draftID: draftID)
        }
    }

    private func saveReviewedQuests() {
        guard let mainQuest, !mainQuest.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            todayLoopMessage = "请保留一个带完成标准的主线任务。"
            return
        }
        quests = quests.map { quest in
            var updated = quest
            updated.status = quest.type == .main ? .active : quest.status
            return updated
        }
        persistQuests()
        scheduleTomorrowMainQuestReminderIfNeeded(for: mainQuest)
        let draftID = todayDraft.id
        todayLoopMessage = "正在沉淀原则候选。"
        Task {
            await generatePrincipleWithAIOrFallback(draftID: draftID)
        }
    }

    private func savePrinciple() {
        persistPrinciples()
        if principles.isEmpty {
            completeTodayLoop(message: "没有保存原则候选，今日闭环完成。")
        } else {
            completeTodayLoop(message: "原则已保存，今日闭环完成。")
        }
    }

    private func moveTodayLoop(to state: DailyLoopState, message: String = "") {
        todayDraft.state = state
        hasResumeableLoop = state != .sessionComplete
        todayLoopMessage = message
        persistDraft()
    }

    private func completeTodayLoop(message: String) {
        moveTodayLoop(to: .sessionComplete, message: message)
    }

    private func scheduleTomorrowMainQuestReminderIfNeeded(for quest: Quest) {
        guard let reminderService else {
            reminderStatusMessage = "本地提醒暂不可用。"
            updateSettingsMessage()
            return
        }

        let reminderID = reminderID(for: quest)
        guard !scheduledReminderIDs.contains(reminderID) else {
            reminderStatusMessage = "明日 09:00 提醒已安排。"
            updateSettingsMessage()
            return
        }

        scheduledReminderIDs.insert(reminderID)
        let request = ReminderRequest(
            id: reminderID,
            title: "明日主线任务",
            body: quest.title,
            fireDate: tomorrowReminderDate()
        )

        Task {
            do {
                let permission = try await reminderService.requestPermission()
                guard permission.allowsScheduling else {
                    throw ReminderError.permissionDenied
                }

                try await reminderService.schedule(request)
                reminderStatusMessage = "明日 09:00 提醒已安排。"
                todayLoopMessage = "明日 09:00 提醒已安排，正在沉淀原则候选。"
            } catch ReminderError.permissionDenied {
                scheduledReminderIDs.remove(reminderID)
                reminderStatusMessage = "通知权限未开启，明日任务已保存但不会提醒。"
                todayLoopMessage = "任务已保存。通知权限未开启，明日不会提醒。"
            } catch {
                scheduledReminderIDs.remove(reminderID)
                reminderStatusMessage = "本地提醒安排失败，明日任务已保存。"
                todayLoopMessage = "任务已保存，但本地提醒安排失败。"
            }

            updateSettingsMessage()
        }
    }

    private func reminderID(for quest: Quest) -> String {
        "tomorrow-main-quest-\(todayDraft.id.uuidString)-\(quest.id.uuidString)"
    }

    private func tomorrowReminderDate(calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: tomorrow
        ) ?? tomorrow
    }

    private func clearTodayLoopMessage() {
        if !todayLoopMessage.isEmpty {
            todayLoopMessage = ""
        }
    }

    private func updateCard(_ cardID: ThinkingCard.ID, mutate: (inout ThinkingCard) -> Void) {
        guard let index = thinkingCards.firstIndex(where: { $0.id == cardID }) else { return }
        mutate(&thinkingCards[index])
        clearTodayLoopMessage()
        persistCards()
    }

    private func generateCardsWithAIOrFallback(from input: String, draftID: DailyEntryDraft.ID) async {
        guard todayDraft.id == draftID else { return }

        if let todayAIService {
            do {
                thinkingCards = try await todayAIService.organizeCards(for: TodayAIContext(draft: todayDraft))
                todayLoopMessage = apiKeyConfigured ? "已生成结构化卡片，请查看并确认。" : "未配置 GLM，已使用本地模拟 AI 数据。"
                persistCards()
                return
            } catch {
                generateLocalCards(from: input)
                todayLoopMessage = fallbackMessage
                persistCards()
                return
            }
        }

        generateLocalCards(from: input)
        todayLoopMessage = fallbackMessage
        persistCards()
    }

    private func generateQuestionsWithAIOrFallback(draftID: DailyEntryDraft.ID) async {
        guard todayDraft.id == draftID else { return }
        let input = todayDraft.rawText

        if let todayAIService {
            do {
                questions = try await todayAIService.generateQuestions(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions
                    )
                )
                moveTodayLoop(to: .answerQuestions, message: apiKeyConfigured ? "" : "未配置 GLM，已使用本地模拟 AI 问题。")
                return
            } catch {
                generateLocalQuestions(from: input)
                moveTodayLoop(to: .answerQuestions, message: fallbackMessage)
                return
            }
        }

        generateLocalQuestions(from: input)
        moveTodayLoop(to: .answerQuestions, message: fallbackMessage)
    }

    private func generateQuestsWithAIOrFallback(draftID: DailyEntryDraft.ID) async {
        guard todayDraft.id == draftID else { return }

        if let todayAIService {
            do {
                quests = try await todayAIService.generateQuests(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions
                    )
                )
                persistQuests()
                moveTodayLoop(to: .reviewQuests, message: apiKeyConfigured ? "" : "未配置 GLM，已使用本地模拟 AI 任务。")
                return
            } catch {
                generateLocalQuests()
                moveTodayLoop(to: .reviewQuests, message: fallbackMessage)
                return
            }
        }

        generateLocalQuests()
        moveTodayLoop(to: .reviewQuests, message: fallbackMessage)
    }

    private func generatePrincipleWithAIOrFallback(draftID: DailyEntryDraft.ID) async {
        guard todayDraft.id == draftID else { return }

        if let todayAIService {
            do {
                principles = try await todayAIService.extractPrinciple(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions,
                        quests: quests
                    )
                )
                persistPrinciples()
                let message = principles.isEmpty ? "没有足够稳定的原则候选，可以直接跳过。" : ""
                moveTodayLoop(to: .extractPrinciple, message: apiKeyConfigured ? message : "未配置 GLM，已使用本地模拟 AI 原则。")
                return
            } catch {
                generateLocalPrinciple()
                moveTodayLoop(to: .extractPrinciple, message: fallbackMessage)
                return
            }
        }

        generateLocalPrinciple()
        moveTodayLoop(to: .extractPrinciple, message: fallbackMessage)
    }

    private func generateLocalCards(from input: String) {
        let summary = inputSummary(from: input)
        thinkingCards = [
            ThinkingCard(
                type: .fact,
                title: "今天的关键事实",
                body: summary,
                priority: .medium,
                sensitivity: .normal,
                confidence: 0.72,
                isConfirmed: true
            ),
            ThinkingCard(
                type: .problem,
                title: "需要澄清的判断",
                body: "这段输入里最需要想清楚的是：什么事情真正影响明天的结果。",
                priority: .high,
                sensitivity: .normal,
                confidence: 0.68
            ),
            ThinkingCard(
                type: .task,
                title: "明天先完成一个可验证动作",
                body: "把最不清楚的一点变成一个可以在 30 分钟内验证的行动。",
                priority: .high,
                sensitivity: .normal,
                confidence: 0.76
            )
        ]
    }

    private func generateLocalQuestions(from input: String) {
        let focus = inputSummary(from: input)
        let modeQuestion: String
        switch todayDraft.sessionMode {
        case .quick:
            modeQuestion = "如果只能推进一个动作，哪个动作最能减少不确定性？"
        case .standard:
            modeQuestion = "明天最应该先验证的关键判断是什么？"
        case .deep:
            modeQuestion = "这件事背后反复出现的思维模式是什么？"
        }

        questions = [
            ReflectionQuestion(
                question: modeQuestion,
                whyItMatters: "让任务从泛泛而谈变成可验证行动。"
            ),
            ReflectionQuestion(
                question: "\(todayDraft.selectedLens?.title ?? "当前透镜") 会如何改写你对这件事的判断？",
                whyItMatters: focus
            )
        ]
    }

    private func generateLocalQuests() {
        let firstAnswer = questions
            .map { $0.answer.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "先澄清明天最关键的判断"

        quests = [
            Quest(
                type: .main,
                title: questTitle(from: firstAnswer),
                whyItMatters: "这是从今天复盘中提取出的最高杠杆行动。",
                completionCriteria: "在明天结束前产出一个可检查结果：结论、负责人、下一步或验证记录。",
                expectedResistance: "容易被临时消息和低价值事务打断。",
                reflectionQuestion: "完成后，哪个不确定性被实际降低了？",
                status: .draft
            ),
            Quest(
                type: .side,
                title: "记录一个被验证或推翻的判断",
                whyItMatters: "持续训练校准能力。",
                completionCriteria: "写下一条原判断、实际结果和下一次调整。",
                expectedResistance: "容易只做事不回看。",
                reflectionQuestion: "这条判断下次可以怎样更早验证？",
                status: .draft
            )
        ]
        persistQuests()
    }

    private func generateLocalPrinciple() {
        guard let mainQuest else {
            principles = []
            return
        }

        principles = [
            PrincipleAsset(
                title: "先把不确定性变成可验证动作",
                summary: "当事情不清楚时，不继续扩大讨论，先定义一个明天能验证的最小行动。",
                triggerContext: mainQuest.whyItMatters,
                actions: [
                    "写下当前最关键的不确定性。",
                    "把它改写成一个可在明天完成的动作。",
                    "提前定义完成标准。"
                ],
                successCriteria: mainQuest.completionCriteria,
                exceptions: "如果问题已经有明确负责人和标准，可以直接执行而不必再拆解。"
            )
        ]
        persistPrinciples()
    }

    private func persistDraft() {
        guard let dailyEntryRepository else { return }
        let draft = todayDraft
        Task {
            do {
                try await dailyEntryRepository.saveDraft(draft)
            } catch {
                await MainActor.run {
                    todayLoopMessage = "保存本地复盘草稿失败。"
                }
            }
        }
    }

    private func persistCards() {
        guard let thinkingCardRepository else { return }
        let cards = thinkingCards
        let draftID = todayDraft.id
        Task {
            do {
                try await thinkingCardRepository.saveCards(cards, dailyEntryId: draftID)
            } catch {
                await MainActor.run {
                    todayLoopMessage = "保存思考卡片失败。"
                }
            }
        }
    }

    private func persistQuests() {
        guard let questRepository else { return }
        let quests = quests
        let draftID = todayDraft.id
        Task {
            do {
                try await questRepository.saveQuests(quests, sourceDailyEntryId: draftID)
            } catch {
                await MainActor.run {
                    todayLoopMessage = "保存明日任务失败。"
                }
            }
        }
    }

    private func persistPrinciples() {
        guard let principleRepository else { return }
        let principles = principles
        let draftID = todayDraft.id
        Task {
            do {
                try await principleRepository.savePrinciples(principles, sourceDailyEntryId: draftID)
            } catch {
                await MainActor.run {
                    todayLoopMessage = "保存原则资产失败。"
                }
            }
        }
    }

    private func inputSummary(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 90 else { return trimmed }
        return "\(trimmed.prefix(90))..."
    }

    private func questTitle(from answer: String) -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "明天验证一个关键判断" }
        if trimmed.count <= 24 {
            return trimmed
        }
        return "\(trimmed.prefix(24))..."
    }

    private var confirmedCardsForAI: [ThinkingCard] {
        thinkingCards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
    }

    private var fallbackMessage: String {
        "AI 生成失败，已使用本地 fallback 数据。"
    }

    private static func makeTodayAIService(apiKeyStore: KeychainAPIKeyStore) -> TodayAIService {
        let key = (try? apiKeyStore.loadAPIKey())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let client: LLMClient = key.isEmpty ? MockLLMClient() : DirectGLMClient(apiKey: key)
        return TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
    }

    func refreshAPIKeyStatus() {
        do {
            let key = try apiKeyStore.loadAPIKey()
            apiKeyConfigured = key?.isEmpty == false
            todayAIService = Self.makeTodayAIService(apiKeyStore: apiKeyStore)
            apiKeyStatusMessage = apiKeyConfigured ? "GLM API Key 已配置。" : "尚未配置 GLM API Key。"
        } catch {
            apiKeyConfigured = false
            apiKeyStatusMessage = "读取 Keychain 失败。"
        }
        updateSettingsMessage()
    }

    func saveGLMAPIKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            settingsMessage = "API Key 不能为空。"
            return
        }

        do {
            try apiKeyStore.saveAPIKey(trimmed)
            apiKeyConfigured = true
            todayAIService = Self.makeTodayAIService(apiKeyStore: apiKeyStore)
            apiKeyStatusMessage = "GLM API Key 已保存到 Keychain。"
        } catch {
            apiKeyConfigured = false
            apiKeyStatusMessage = "保存 Keychain 失败。"
        }
        updateSettingsMessage()
    }

    func clearGLMAPIKey() {
        do {
            try apiKeyStore.deleteAPIKey()
            apiKeyConfigured = false
            todayAIService = Self.makeTodayAIService(apiKeyStore: apiKeyStore)
            apiKeyStatusMessage = "GLM API Key 已清除。"
        } catch {
            apiKeyStatusMessage = "清除 Keychain 失败。"
        }
        updateSettingsMessage()
    }

    private func updateSettingsMessage() {
        let baseMessage: String
        if let persistenceUnavailableMessage {
            baseMessage = "\(apiKeyStatusMessage)\n\(persistenceUnavailableMessage)"
        } else {
            baseMessage = apiKeyStatusMessage
        }
        settingsMessage = "\(baseMessage)\n\(reminderStatusMessage)"
    }
}
