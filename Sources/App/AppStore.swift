import Foundation
import SwiftUI

private struct HistoricalRetryCandidatePayload: Codable {
    var cards: [HistoricalRetryCardPayload]
}

private struct HistoricalRetryCardPayload: Codable {
    var id: String
    var type: String
    var title: String
    var body: String
    var priority: String
    var sensitivity: String
    var confidence: Double
    var isConfirmed: Bool
    var isExcludedFromModel: Bool
    var sourceRefs: [String]

    init(card: ThinkingCard) {
        id = card.id.uuidString
        type = card.type.rawValue
        title = card.title
        body = card.body
        priority = card.priority.rawValue
        sensitivity = card.sensitivity.rawValue
        confidence = card.confidence
        isConfirmed = card.isConfirmed
        isExcludedFromModel = card.isExcludedFromModel
        sourceRefs = card.sourceRefs
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var todayDraft: DailyEntryDraft
    @Published var thinkingCards: [ThinkingCard]
    @Published var questions: [ReflectionQuestion]
    @Published var quests: [Quest]
    @Published var principles: [PrincipleAsset]
    @Published private(set) var activePrinciples: [PrincipleAsset]
    @Published private(set) var referencedPrinciples: [PrincipleAsset] = []
    @Published var historyRecords: [HistoryRecord] = []
    @Published var projectNames: [UUID: String] = [:]
    @Published var projectsById: [UUID: Project] = [:]
    @Published var growthSnapshot: MetricSnapshot
    @Published var metricContributions: [MetricContribution] = []
    @Published var growthReportReviewContributions: [MetricContribution] = []
    @Published var isResumeBannerDismissed: Bool = false
    @Published var historyDeepLink: HistoryDeepLink?
    @Published var apiKeyConfigured: Bool = false
    @Published var settingsMessage: String = ""
    @Published var isTestingGLMConnection: Bool = false
    @Published var todayLoopMessage: String = ""
    @Published var lastAIFailureMessage: String?
    @Published var canRetryCurrentAI: Bool = false
    @Published private(set) var isAIRunning: Bool = false
    @Published private(set) var aiActivityMessage: String = ""
    @Published var streamingCards: [StreamingCardDraft] = []
    @Published var streamingStatusText: String = ""
    @Published var recentPromptRuns: [PromptRun] = []
    @Published var promptRunAuditMessage: String = ""
    @Published private(set) var pendingAIRepairCount: Int = 0
    @Published private(set) var reminderStatusMessage: String = "明日 09:00 本地提醒将在保存主线任务后请求授权。"
    @Published var projectCandidates: [ProjectCandidate] = []
    @Published var projectLinkCandidates: [ProjectLinkCandidate] = []
    @Published var isGeneratingProjectSuggestions: Bool = false
    @Published var projectSuggestionMessage: String = ""
    @Published var isGeneratingGrowthReport: Bool = false
    @Published var growthReportMessage: String = ""
    @Published var pendingProjectInsights: [ProjectInsight] = []
    @Published var acceptedProjectInsights: [ProjectInsight] = []
    @Published var isGeneratingProjectInsights: Bool = false
    @Published var projectInsightGenerationMessage: String = ""
    @Published var pendingProjectMergeCandidates: [ProjectMergeCandidate] = []
    @Published var isGeneratingProjectMerges: Bool = false
    @Published var projectMergeMessage: String = ""

    private let apiKeyStore: KeychainAPIKeyStore
    private let dailyEntryRepository: DailyEntryRepository?
    private let thinkingCardRepository: ThinkingCardRepository?
    private let questRepository: QuestRepository?
    private let principleRepository: PrincipleRepository?
    private let verificationRepository: VerificationRepository?
    private let lensSessionRepository: LensSessionRepository?
    private let metricSnapshotRepository: MetricSnapshotRepository?
    private let metricContributionRepository: MetricContributionRepository?
    private let projectLinkRepository: ProjectLinkRepository?
    private let projectRepository: ProjectRepository?
    private let projectCandidateRepository: ProjectCandidateRepository?
    private let projectMergeCandidateRepository: ProjectMergeCandidateRepository?
    private let projectInsightRepository: ProjectInsightRepository?
    private let promptRunRepository: PromptRunRepository?
    private let historicalRetryCandidateRepository: HistoricalRetryCandidateRepository?
    private let reminderService: ReminderService?
    private let promptProvider: PromptProvider
    private let persistenceUnavailableMessage: String?
    private let refreshesAIServiceFromKeychain: Bool
    private var todayAIService: TodayAIService?
    private var growthAIService: GrowthAIService?
    private var apiKeyStatusMessage: String = ""
    private var glmConnectionMessage: String = ""
    private var scheduledReminderIDs: Set<String> = []
    private var pendingAIRepairPrompts: Set<PromptID> = [] {
        didSet {
            pendingAIRepairCount = pendingAIRepairPrompts.count
        }
    }
    private var activeAIRequestCount: Int = 0
    #if DEBUG
    private(set) var loadsPersistedStateOnLaunch: Bool = true
    #endif

    init(
        todayDraft: DailyEntryDraft? = nil,
        thinkingCards: [ThinkingCard]? = nil,
        questions: [ReflectionQuestion]? = nil,
        quests: [Quest]? = nil,
        principles: [PrincipleAsset]? = nil,
        historyRecords: [HistoryRecord]? = nil,
        growthSnapshot: MetricSnapshot? = nil,
        apiKeyStore: KeychainAPIKeyStore = KeychainAPIKeyStore(),
        dailyEntryRepository: DailyEntryRepository? = nil,
        thinkingCardRepository: ThinkingCardRepository? = nil,
        questRepository: QuestRepository? = nil,
        principleRepository: PrincipleRepository? = nil,
        verificationRepository: VerificationRepository? = nil,
        lensSessionRepository: LensSessionRepository? = nil,
        metricSnapshotRepository: MetricSnapshotRepository? = nil,
        metricContributionRepository: MetricContributionRepository? = nil,
        projectLinkRepository: ProjectLinkRepository? = nil,
        projectRepository: ProjectRepository? = nil,
        projectCandidateRepository: ProjectCandidateRepository? = nil,
        projectMergeCandidateRepository: ProjectMergeCandidateRepository? = nil,
        projectInsightRepository: ProjectInsightRepository? = nil,
        promptRunRepository: PromptRunRepository? = nil,
        historicalRetryCandidateRepository: HistoricalRetryCandidateRepository? = nil,
        reminderService: ReminderService? = nil,
        promptProvider: PromptProvider = LocalPromptProvider(),
        todayAIService: TodayAIService? = nil,
        persistenceUnavailableMessage: String? = nil,
        refreshesAIServiceFromKeychain: Bool = true,
        growthAIService: GrowthAIService? = nil
    ) {
        self.apiKeyStore = apiKeyStore
        self.dailyEntryRepository = dailyEntryRepository
        self.thinkingCardRepository = thinkingCardRepository
        self.questRepository = questRepository
        self.principleRepository = principleRepository
        self.verificationRepository = verificationRepository
        self.lensSessionRepository = lensSessionRepository
        self.metricSnapshotRepository = metricSnapshotRepository
        self.metricContributionRepository = metricContributionRepository
        self.projectLinkRepository = projectLinkRepository
        self.projectRepository = projectRepository
        self.projectCandidateRepository = projectCandidateRepository
        self.projectMergeCandidateRepository = projectMergeCandidateRepository
        self.projectInsightRepository = projectInsightRepository
        self.promptRunRepository = promptRunRepository
        self.historicalRetryCandidateRepository = historicalRetryCandidateRepository
        self.reminderService = reminderService
        self.promptProvider = promptProvider
        self.todayAIService = todayAIService
        self.persistenceUnavailableMessage = persistenceUnavailableMessage
        self.refreshesAIServiceFromKeychain = refreshesAIServiceFromKeychain
        self.growthAIService = growthAIService
        self.todayDraft = todayDraft ?? DailyEntryDraft()
        self.thinkingCards = thinkingCards ?? []
        self.questions = questions ?? []
        self.quests = quests ?? []
        self.principles = principles ?? []
        self.activePrinciples = principles?.filter { $0.status == .active } ?? []
        self.historyRecords = historyRecords ?? []
        self.growthSnapshot = growthSnapshot ?? Self.makeEmptyGrowth()
        refreshAPIKeyStatus()
    }

    static func live() -> AppStore {
        let apiKeyStore = KeychainAPIKeyStore()

        do {
            let database = try AppDatabase(url: AppDatabase.defaultURL())
            let promptRunRepository = SQLitePromptRunRepository(database: database)
            let todayAIService = makeTodayAIService(
                apiKeyStore: apiKeyStore,
                promptRunRepository: promptRunRepository
            )
            let growthService = GrowthAIService(
                promptProvider: LocalPromptProvider(),
                llmClient: makeLLMClient(apiKeyStore: apiKeyStore, promptRunRepository: promptRunRepository)
            )
            return AppStore(
                apiKeyStore: apiKeyStore,
                dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
                thinkingCardRepository: SQLiteThinkingCardRepository(database: database),
                questRepository: SQLiteQuestRepository(database: database),
                principleRepository: SQLitePrincipleRepository(database: database),
                verificationRepository: SQLiteVerificationRepository(database: database),
                lensSessionRepository: SQLiteLensSessionRepository(database: database),
                metricSnapshotRepository: SQLiteMetricSnapshotRepository(database: database),
                metricContributionRepository: SQLiteMetricContributionRepository(database: database),
                projectLinkRepository: SQLiteProjectLinkRepository(database: database),
                projectRepository: SQLiteProjectRepository(database: database),
                projectCandidateRepository: SQLiteProjectCandidateRepository(database: database),
                projectMergeCandidateRepository: SQLiteProjectMergeCandidateRepository(database: database),
                projectInsightRepository: SQLiteProjectInsightRepository(database: database),
                promptRunRepository: promptRunRepository,
                historicalRetryCandidateRepository: SQLiteHistoricalRetryCandidateRepository(database: database),
                reminderService: LocalNotificationReminder(),
                todayAIService: todayAIService,
                growthAIService: growthService
            )
        } catch {
            let todayAIService = makeTodayAIService(apiKeyStore: apiKeyStore, promptRunRepository: nil)
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

#if DEBUG
    nonisolated static let visualQAMarkerFileName = ".visual_qa_project_detail"

    static func isVisualQAProjectDetailLaunch(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard,
        markerFileExists: () -> Bool = {
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return false
            }
            return FileManager.default.fileExists(atPath: docs.appendingPathComponent(visualQAMarkerFileName).path)
        }
    ) -> Bool {
        arguments.contains("MINGSI_VISUAL_QA_PROJECT_DETAIL")
            || environment["MINGSI_VISUAL_QA_PROJECT_DETAIL"] != nil
            || environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL"] != nil
            || defaults.bool(forKey: "MINGSI_VISUAL_QA_PROJECT_DETAIL")
            || markerFileExists()
    }

    static func visualQAProjectDetail() -> AppStore {
        let project = Project(
            name: "Visual QA - 会议机制优化",
            goal: "减少会议后的返工和模糊结论",
            successCriteria: "每次会议结束时有明确负责人、行动项和验收标准",
            currentBottleneck: "会前没有列出必须确认的问题",
            openQuestions: ["哪些决策必须会前确认？", "谁在会后发纪要？"],
            status: .active,
            mergeHistory: ["合并了: Visual QA - 接口归属确认\n来源项目: fixture\n原因: 视觉验证用例\n证据: fixture-evidence"]
        )

        let cardID = UUID()
        let questID = UUID()
        let draft = DailyEntryDraft(
            rawText: "Visual QA: 会议讨论了接口归属问题，但结束时没有明确负责人。",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .sessionComplete
        )
        let card = ThinkingCard(
            id: cardID,
            type: .problem,
            title: "Visual QA - 会议目标不清",
            body: "会议讨论了多个议题，但没有逐项确认负责人。",
            isConfirmed: true
        )
        let quest = Quest(
            id: questID,
            type: .main,
            title: "Visual QA - 确认会议机制",
            whyItMatters: "减少后续返工",
            completionCriteria: "写出负责人和验收方式",
            expectedResistance: "跨角色沟通",
            reflectionQuestion: "哪些归属确认后减少了返工？",
            status: .completed
        )

        let confirmedLink = ProjectLink(
            projectId: project.id,
            sourceType: .thinkingCard,
            sourceId: cardID.uuidString,
            linkType: .evidence,
            isUserConfirmed: true
        )
        let taskLink = ProjectLink(
            projectId: project.id,
            sourceType: .quest,
            sourceId: questID.uuidString,
            linkType: .task,
            isUserConfirmed: true
        )

        let record = HistoryRecord(
            draft: draft,
            cards: [card],
            quests: [quest],
            principles: [],
            verification: nil,
            lensSession: nil,
            projectLinks: [confirmedLink, taskLink],
            growthContributions: []
        )

        let acceptedInsight = ProjectInsight(
            projectId: project.id,
            insightType: .progress,
            title: "Visual QA - 进展信号",
            summary: "从依赖会议讨论到主动会前准备，接口归属逐步明确。",
            sourceRefs: [cardID.uuidString],
            userFeedback: .accepted
        )
        let pendingInsight = ProjectInsight(
            projectId: project.id,
            insightType: .thinkingChange,
            title: "Visual QA - 思考转变",
            summary: "从被动等待会议结论到会前列出必须确认的问题。",
            beforeText: "之前依赖会议讨论决定归属",
            afterText: "现在会前列出必须确认的问题",
            sourceRefs: [questID.uuidString],
            userFeedback: .none
        )

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.acceptedProjectInsights = [acceptedInsight]
        store.pendingProjectInsights = [pendingInsight]
        store.loadsPersistedStateOnLaunch = false
        return store
    }

    func applyVisualQAProjectDetailFixture() {
        let fixture = AppStore.visualQAProjectDetail()
        selectedTab = fixture.selectedTab
        todayDraft = fixture.todayDraft
        thinkingCards = fixture.thinkingCards
        questions = fixture.questions
        quests = fixture.quests
        principles = fixture.principles
        activePrinciples = fixture.activePrinciples
        referencedPrinciples = fixture.referencedPrinciples
        historyRecords = fixture.historyRecords
        projectNames = fixture.projectNames
        projectsById = fixture.projectsById
        growthSnapshot = fixture.growthSnapshot
        metricContributions = fixture.metricContributions
        growthReportReviewContributions = fixture.growthReportReviewContributions
        pendingProjectInsights = fixture.pendingProjectInsights
        acceptedProjectInsights = fixture.acceptedProjectInsights
        pendingProjectMergeCandidates = fixture.pendingProjectMergeCandidates
        projectCandidates = fixture.projectCandidates
        projectLinkCandidates = fixture.projectLinkCandidates
        isResumeBannerDismissed = fixture.isResumeBannerDismissed
        loadsPersistedStateOnLaunch = false
    }
#endif

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
            summary: "本周对会议类问题的定义更清楚，但会后验证仍然偏少。",
            hasInsufficientEvidence: true
        )
    }

    nonisolated static func makeEmptyGrowth() -> MetricSnapshot {
        MetricSnapshot(
            period: "weekly",
            clarity: 3.0,
            valueJudgment: 3.0,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            summary: "证据正在积累。完成 3 次完整复盘后，再生成可解释的成长趋势。",
            status: .insufficientEvidence,
            completeLoopCount: 0,
            nextTrainingFocus: "先稳定完成输入、卡片确认、明日任务和次日验证。"
        )
    }

    var currentStateTitle: String {
        todayDraft.state.title
    }

    var loopResumeText: String {
        todayDraft.state == .sessionComplete ? "今日闭环已完成" : "今日复盘未完成"
    }

    var hasResumeableLoop: Bool {
        todayDraft.state != .sessionComplete
    }

    var hasAnsweredReflectionQuestion: Bool {
        questions.contains { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var mainQuest: Quest? {
        quests.first { $0.type == .main }
    }

    var canCreateProjectFromCurrentFocus: Bool {
        guard let mainQuest,
              projectRepository != nil,
              projectLinkRepository != nil
        else { return false }
        return !hasProjectLink(forSourceId: mainQuest.id.uuidString)
    }

    func loadPersistedState() async {
        guard let dailyEntryRepository else {
            updateSettingsMessage()
            return
        }

        do {
            guard let draft = try await dailyEntryRepository.latestDraft() else {
                pendingAIRepairPrompts = []
                await initializeFromLastActiveQuest()
                persistDraft()
                await loadActivePrinciples()
                await loadPendingProjectCandidates()
                await loadPendingProjectMergeCandidates()
                await loadLatestGrowthSnapshot()
                return
            }

            if !Calendar.current.isDateInToday(draft.date) {
                todayDraft = DailyEntryDraft()
                thinkingCards = []
                questions = []
                quests = []
                principles = []
                referencedPrinciples = []
                pendingAIRepairPrompts = []
                await initializeFromLastActiveQuest()
                persistDraft()
                await loadHistoryRecords()
                await loadActivePrinciples()
                await loadPendingProjectCandidates()
                await loadPendingProjectMergeCandidates()
                await loadLatestGrowthSnapshot()
                updateSettingsMessage()
                return
            }

            todayDraft = draft
            if let cards = try await thinkingCardRepository?.cards(for: draft.id) {
                thinkingCards = cards
            }
            if let storedQuests = try await questRepository?.quests(for: draft.id), !storedQuests.isEmpty {
                quests = storedQuests
            }
            if let storedPrinciples = try await principleRepository?.principles(for: draft.id) {
                principles = storedPrinciples
            }
            await loadActivePrinciples()
            referencedPrinciples = []
            if let session = try await lensSessionRepository?.lensSession(for: draft.id) {
                questions = session.questions
                if draft.selectedLens == nil {
                    todayDraft.selectedLens = session.selectedLens
                }
            }
            if todayDraft.state == .verifyYesterday {
                await initializeFromLastActiveQuest()
                persistDraft()
            }
            await loadHistoryRecords()
            await loadPendingProjectCandidates()
            await loadPendingProjectMergeCandidates()
            await loadLatestGrowthSnapshot()
            await generateLocalGrowthSnapshotFromHistoryIfNeeded()
            await restorePendingAIRepairsFromPromptRuns()
        } catch {
            todayLoopMessage = "读取本地复盘记录失败，已继续使用当前内存数据。"
        }

        updateSettingsMessage()
    }

    private func restorePendingAIRepairsFromPromptRuns() async {
        guard let promptRunRepository else { return }
        do {
            let failures = try await promptRunRepository.unresolvedFailures(limit: 100)
            let todayEntryID = todayDraft.id.uuidString
            let restoredPrompts = failures.reduce(into: Set<PromptID>()) { result, run in
                guard run.sourceRecordIds.contains(todayEntryID),
                      let prompt = PromptID(rawValue: run.promptId),
                      Self.canRepairPrompt(prompt)
                else { return }
                result.insert(prompt)
            }
            pendingAIRepairPrompts = restoredPrompts
        } catch {
            // Repair recovery should never block the daily loop.
        }
    }

    func loadRecentPromptRuns(limit: Int = 12) async {
        guard let promptRunRepository else {
            recentPromptRuns = []
            promptRunAuditMessage = "AI 调用记录暂不可用。"
            return
        }

        do {
            recentPromptRuns = try await promptRunRepository.recentPromptRuns(limit: limit)
            promptRunAuditMessage = recentPromptRuns.isEmpty ? "还没有 AI 调用记录。" : ""
        } catch {
            recentPromptRuns = []
            promptRunAuditMessage = "读取 AI 调用记录失败。"
        }
    }

    func promptTemplate(for promptID: PromptID, mode: SessionMode) -> PromptTemplate {
        promptProvider.template(for: promptID, mode: mode)
    }

    func repairablePromptRuns(for dailyEntryId: UUID, limit: Int = 100) async -> [PromptRun] {
        guard let promptRunRepository else { return [] }
        do {
            let dailyEntryId = dailyEntryId.uuidString
            return try await promptRunRepository.unresolvedFailures(limit: limit)
                .filter { run in
                    guard let prompt = PromptID(rawValue: run.promptId),
                          Self.canRepairPrompt(prompt)
                    else { return false }
                    return run.sourceRecordIds.contains(dailyEntryId)
                }
        } catch {
            return []
        }
    }

    func historicalRetryCandidates(for dailyEntryId: UUID) async -> [HistoricalRetryCandidate] {
        guard let historicalRetryCandidateRepository else { return [] }
        do {
            return try await historicalRetryCandidateRepository.candidates(for: dailyEntryId)
        } catch {
            return []
        }
    }

    func startHistoricalOrganizeCardsRetry(failedPromptRunId: UUID) async {
        guard let promptRunRepository else {
            todayLoopMessage = "历史 AI 修复暂不可用。"
            return
        }

        do {
            guard let failedRun = try await promptRunRepository
                .unresolvedFailures(limit: 200)
                .first(where: { $0.id == failedPromptRunId })
            else {
                todayLoopMessage = "没有找到可重试的历史 AI 失败记录。"
                return
            }

            guard PromptID(rawValue: failedRun.promptId) == .organizeCards else {
                todayLoopMessage = "暂只支持历史卡片整理失败的重试。"
                return
            }

            guard let dailyEntryRepository,
                  let historicalRetryCandidateRepository,
                  let todayAIService
            else {
                todayLoopMessage = "历史 AI 修复暂不可用。"
                return
            }

            guard let sourceId = failedRun.sourceRecordIds.compactMap(UUID.init(uuidString:)).first,
                  let entry = try await dailyEntryRepository
                    .recentEntries(limit: 240)
                    .first(where: { $0.id == sourceId })
            else {
                todayLoopMessage = "无法从历史记录重建本次 AI 修复输入。"
                return
            }

            let candidate = HistoricalRetryCandidate(
                failedPromptRunId: failedRun.id,
                promptId: .organizeCards,
                sourceDailyEntryId: entry.id,
                status: .retrying,
                reconstructedInputSummary: Self.historicalRetryInputSummary(from: entry.rawText)
            )
            try await historicalRetryCandidateRepository.saveCandidate(candidate)

            let beforeRuns = try await promptRunRepository.recentPromptRuns(limit: 20)
            let cards = try await todayAIService.streamOrganizedCards(
                for: TodayAIContext(draft: entry),
                onUpdate: { _ in }
            )
            let payloadJSON = try Self.historicalRetryCandidatePayloadJSON(from: cards)
            let repairRunId = try await Self.discoverRepairPromptRunId(
                after: beforeRuns,
                failedRun: failedRun,
                promptRunRepository: promptRunRepository
            )

            if let repairRunId {
                try await historicalRetryCandidateRepository.attachRepairRun(
                    repairRunId,
                    candidatePayloadJSON: payloadJSON,
                    to: candidate.id
                )
            } else {
                var readyCandidate = candidate
                readyCandidate.status = .candidateReady
                readyCandidate.candidatePayloadJSON = payloadJSON
                readyCandidate.updatedAt = .now
                try await historicalRetryCandidateRepository.saveCandidate(readyCandidate)
            }

            todayLoopMessage = "历史卡片候选已生成，等待你审阅。"
        } catch {
            await markLatestHistoricalRetryFailed(
                failedPromptRunId: failedPromptRunId,
                reason: aiFailureMessage(for: error)
            )
        }
    }

    func acceptHistoricalRetryCandidate(_ candidateId: UUID) async {
        guard let historicalRetryCandidateRepository else {
            todayLoopMessage = "历史 AI 修复暂不可用。"
            return
        }

        do {
            guard try await historicalRetryCandidateRepository.candidate(id: candidateId) != nil else {
                todayLoopMessage = "没有找到这次历史修复候选。"
                return
            }

            if thinkingCards.contains(where: \.isConfirmed) {
                let reason = "blocked by confirmed cards"
                try await historicalRetryCandidateRepository.updateStatus(
                    .blocked,
                    candidateId: candidateId,
                    blockedReason: reason
                )
                todayLoopMessage = "历史修复已阻断：该记录已有确认卡片。"
                return
            }

            try await historicalRetryCandidateRepository.updateStatus(
                .accepted,
                candidateId: candidateId,
                error: nil,
                blockedReason: nil
            )
            todayLoopMessage = "历史修复候选已接受。"
        } catch {
            todayLoopMessage = "接受历史修复候选失败：\(aiFailureMessage(for: error))"
        }
    }

    func dismissHistoricalRetryCandidate(_ candidateId: UUID) async {
        guard let historicalRetryCandidateRepository else { return }
        do {
            try await historicalRetryCandidateRepository.updateStatus(
                .dismissed,
                candidateId: candidateId,
                error: nil,
                blockedReason: nil
            )
            todayLoopMessage = "已忽略本次历史修复结果。"
        } catch {
            todayLoopMessage = "忽略历史修复结果失败。"
        }
    }

    private static func canRepairPrompt(_ prompt: PromptID) -> Bool {
        switch prompt {
        case .organizeCards, .generateQuestions, .generateQuests, .extractPrinciple:
            return true
        case .recommendLenses, .verifyQuest, .weeklyCalibration, .monthlyGrowth, .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges:
            return false
        }
    }

    private func initializeFromLastActiveQuest() async {
        do {
            if let activeQuest = try await questRepository?.activeMainQuest() {
                let existingVerification: Verification?
                if let verificationRepository {
                    existingVerification = try await verificationRepository.verification(forQuestId: activeQuest.id)
                } else {
                    existingVerification = nil
                }

                if existingVerification != nil {
                    todayDraft.state = .capture
                } else {
                    quests = [activeQuest]
                    todayDraft.state = .verifyYesterday
                }
            } else {
                todayDraft.state = .capture
            }
        } catch {
            todayDraft.state = .capture
        }
    }

    func loadHistoryRecords(limit: Int = 180) async {
        #if DEBUG
        guard loadsPersistedStateOnLaunch else { return }
        #endif
        guard let dailyEntryRepository else {
            historyRecords = [currentHistoryRecord]
            return
        }

        do {
            let entries = try await dailyEntryRepository.recentEntries(limit: limit)
            var records: [HistoryRecord] = []
            for entry in entries {
                let cards = try await thinkingCardRepository?.cards(for: entry.id) ?? []
                let entryQuests = try await questRepository?.quests(for: entry.id) ?? []
                let entryPrinciples = try await principleRepository?.principles(for: entry.id) ?? []
                let verification = try await verificationRepository?.verification(for: entry.id)
                let lensSession = try await lensSessionRepository?.lensSession(for: entry.id)

                var sourceIds: [String] = [entry.id.uuidString]
                sourceIds.append(contentsOf: cards.map { $0.id.uuidString })
                sourceIds.append(contentsOf: entryQuests.map { $0.id.uuidString })
                if let verification { sourceIds.append(verification.id.uuidString) }
                sourceIds.append(contentsOf: entryPrinciples.map { $0.id.uuidString })

                let projectLinks = (try? await projectLinkRepository?.links(forSourceIds: sourceIds)) ?? []
                let growthContributions = (try? await metricContributionRepository?.contributions(forDailyEntryId: entry.id)) ?? []

                records.append(
                    HistoryRecord(
                        draft: entry,
                        cards: cards,
                        quests: entryQuests,
                        principles: entryPrinciples,
                        verification: verification,
                        lensSession: lensSession,
                        projectLinks: projectLinks,
                        growthContributions: growthContributions
                    )
                )
            }
            historyRecords = records.isEmpty ? [currentHistoryRecord] : records

            var names: [UUID: String] = [:]
            var projects: [UUID: Project] = [:]
            let projectIds = Set(records.flatMap { $0.projectLinks.map(\.projectId) })
            for projectId in projectIds {
                if let project = try? await projectRepository?.project(id: projectId) {
                    names[projectId] = project.name
                    projects[projectId] = project
                }
            }
            projectNames = names
            projectsById = projects
        } catch {
            historyRecords = [currentHistoryRecord]
            todayLoopMessage = "读取历史记录失败，已显示当前复盘。"
        }
    }

    private func loadPendingProjectCandidates() async {
        guard let projectCandidateRepository else { return }
        do {
            projectCandidates = try await projectCandidateRepository.pendingCandidates()
        } catch {
            projectSuggestionMessage = "读取项目候选失败。"
        }
    }

    func loadLatestGrowthSnapshot() async {
        guard let metricSnapshotRepository else { return }

        do {
            if let snapshot = try await metricSnapshotRepository.latestSnapshot() {
                growthSnapshot = snapshot
                await loadGrowthReportReviewContributions()
            }
        } catch {
            todayLoopMessage = "读取成长快照失败，已保留当前证据状态。"
        }
    }

    func loadGrowthReportReviewContributions() async {
        guard let metricContributionRepository, growthSnapshot.canDisplayScores else {
            growthReportReviewContributions = []
            return
        }

        do {
            growthReportReviewContributions = try await metricContributionRepository
                .contributions(for: growthSnapshot.id)
                .filter { contribution in
                    contribution.isAcceptedForTrend &&
                    !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
        } catch {
            growthReportReviewContributions = []
        }
    }

    func loadMetricContributions(for metric: GrowthMetric) async {
        guard let metricContributionRepository else {
            metricContributions = []
            return
        }
        do {
            metricContributions = try await metricContributionRepository
                .contributions(for: growthSnapshot.id)
                .filter { contribution in
                    contribution.metric == metric &&
                    contribution.candidateStatus == .accepted &&
                    contribution.userFeedback != .dismissed &&
                    !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
        } catch {
            metricContributions = []
        }
    }

    func updateContributionFeedback(
        _ feedback: MetricContributionFeedback,
        for contribution: MetricContribution
    ) async {
        guard let metricContributionRepository else { return }

        do {
            try await metricContributionRepository.updateContributionFeedback(
                feedback,
                contributionId: contribution.id
            )
            await loadLatestGrowthSnapshot()
            await loadMetricContributions(for: contribution.metric)
            await loadGrowthReportReviewContributions()
        } catch {
            todayLoopMessage = "成长证据反馈保存失败，请稍后重试。"
        }
    }

    private func generateLocalGrowthSnapshotFromHistoryIfNeeded() async {
        guard let metricSnapshotRepository, let metricContributionRepository else { return }

        let completedRecords = historyRecords
            .filter { $0.draft.state == .sessionComplete }
            .sorted { $0.draft.date < $1.draft.date }
        guard completedRecords.count >= 3 else {
            growthSnapshot = Self.makeEmptyGrowth()
            return
        }

        let verifiedRecords = completedRecords.filter { $0.verification != nil }
        guard !verifiedRecords.isEmpty else {
            growthSnapshot = MetricSnapshot(
                period: "weekly",
                clarity: 3.0,
                valueJudgment: 3.0,
                executionReliability: 3.0,
                calibration: 3.0,
                reflectionDepth: 3.0,
                summary: "已有 \(completedRecords.count) 次闭环，但缺少次日验证，暂不生成成长趋势。",
                status: .insufficientEvidence,
                completeLoopCount: completedRecords.count,
                nextTrainingFocus: "优先补齐次日验证，让成长判断有结果证据。"
            )
            return
        }

        let evidenceIds = completedRecords.flatMap { record in
            var ids = [record.draft.id.uuidString]
            if let verificationId = record.verification?.id.uuidString {
                ids.append(verificationId)
            }
            return ids
        }
        if growthSnapshot.canDisplayScores,
           growthSnapshot.completeLoopCount >= completedRecords.count,
           Set(growthSnapshot.evidenceRefs) == Set(evidenceIds) {
            return
        }

        let snapshotID = UUID()
        let contributions = makeLocalGrowthContributions(
            snapshotID: snapshotID,
            records: completedRecords
        )
        guard !contributions.isEmpty else { return }

        let positiveRefs = contributions
            .filter { $0.direction == .positive }
            .map { $0.id.uuidString }
        let negativeRefs = contributions
            .filter { $0.direction == .negative }
            .map { $0.id.uuidString }
        let scores = growthScores(from: contributions)
        let reasons = growthReasons(from: contributions)
        let summary = localGrowthSummary(
            completeLoopCount: completedRecords.count,
            positiveCount: positiveRefs.count,
            negativeCount: negativeRefs.count
        )

        let snapshot = MetricSnapshot(
            id: snapshotID,
            period: "weekly",
            startDate: completedRecords.first?.draft.date,
            endDate: completedRecords.last?.draft.date,
            clarity: scores[.clarity] ?? 3.0,
            valueJudgment: scores[.valueJudgment] ?? 3.0,
            executionReliability: scores[.executionReliability] ?? 3.0,
            calibration: scores[.calibration] ?? 3.0,
            reflectionDepth: scores[.reflectionDepth] ?? 3.0,
            previousClarity: 3.0,
            previousValueJudgment: 3.0,
            previousExecutionReliability: 3.0,
            previousCalibration: 3.0,
            previousReflectionDepth: 3.0,
            clarityDelta: (scores[.clarity] ?? 3.0) - 3.0,
            valueJudgmentDelta: (scores[.valueJudgment] ?? 3.0) - 3.0,
            executionReliabilityDelta: (scores[.executionReliability] ?? 3.0) - 3.0,
            calibrationDelta: (scores[.calibration] ?? 3.0) - 3.0,
            reflectionDepthDelta: (scores[.reflectionDepth] ?? 3.0) - 3.0,
            summary: summary,
            metricReasons: reasons,
            evidenceRefs: evidenceIds,
            positiveContributionRefs: positiveRefs,
            negativeContributionRefs: negativeRefs,
            status: .confirmedTrend,
            completeLoopCount: completedRecords.count,
            nextTrainingFocus: "继续把明日任务写成可验证结果，并在第二天做价值校准。"
        )

        do {
            try await metricSnapshotRepository.saveSnapshot(snapshot)
            for contribution in contributions {
                try await metricContributionRepository.saveContribution(contribution)
            }
            growthSnapshot = snapshot
            await loadGrowthReportReviewContributions()
        } catch {
            todayLoopMessage = "成长快照生成失败，已保留当前证据状态。"
        }
    }

    private func makeLocalGrowthContributions(
        snapshotID: UUID,
        records: [HistoryRecord]
    ) -> [MetricContribution] {
        var contributions: [MetricContribution] = []

        for record in records {
            if let mainQuest = record.mainQuest,
               !mainQuest.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contributions.append(
                    MetricContribution(
                        snapshotId: snapshotID,
                        metric: .clarity,
                        direction: .positive,
                        delta: 0.08,
                        title: "任务完成标准更具体",
                        reason: "主线任务包含可验证的完成标准。",
                        sourceType: .quest,
                        sourceId: mainQuest.id.uuidString,
                        sourceDailyEntryId: record.draft.id,
                        candidateStatus: .accepted
                    )
                )
            }

            if let verification = record.verification {
                switch verification.completion {
                case .done:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .executionReliability,
                            direction: .positive,
                            delta: 0.14,
                            title: "主线任务完成",
                            reason: "次日验证显示主线任务已完成。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                case .partial:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .executionReliability,
                            direction: .positive,
                            delta: 0.05,
                            title: "主线任务部分完成",
                            reason: "次日验证显示任务有推进但未完全闭合。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                case .missed:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .executionReliability,
                            direction: .negative,
                            delta: 0.12,
                            title: "主线任务未完成",
                            reason: "次日验证显示任务没有完成，需要校准任务大小或阻力判断。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                }

                switch verification.valueRating {
                case .high:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .valueJudgment,
                            direction: .positive,
                            delta: 0.14,
                            title: "完成了高价值任务",
                            reason: "次日验证显示任务实际价值高。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                case .medium:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .valueJudgment,
                            direction: .positive,
                            delta: 0.05,
                            title: "任务价值中等",
                            reason: "任务产生了一定价值，但仍有校准空间。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                case .low:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .valueJudgment,
                            direction: .negative,
                            delta: 0.12,
                            title: "任务完成但价值偏低",
                            reason: "次日验证显示任务实际价值低，需要重新判断优先级。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                case .uncertain:
                    contributions.append(
                        MetricContribution(
                            snapshotId: snapshotID,
                            metric: .calibration,
                            direction: .negative,
                            delta: 0.06,
                            title: "任务价值仍不确定",
                            reason: "次日验证无法判断实际价值，需要更清晰的结果证据。",
                            sourceType: .verification,
                            sourceId: verification.id.uuidString,
                            sourceDailyEntryId: record.draft.id,
                            candidateStatus: .accepted
                        )
                    )
                }
            }

            if let lensSession = record.lensSession,
               lensSession.questions.contains(where: { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                contributions.append(
                    MetricContribution(
                        snapshotId: snapshotID,
                        metric: .reflectionDepth,
                        direction: .positive,
                        delta: 0.07,
                        title: "完成透镜追问",
                        reason: "用户回答了透镜问题，形成了可追溯的思考过程。",
                        sourceType: .dailyEntry,
                        sourceId: record.draft.id.uuidString,
                        sourceDailyEntryId: record.draft.id,
                        candidateStatus: .accepted
                    )
                )
            }
        }

        return contributions
    }

    private func growthScores(from contributions: [MetricContribution]) -> [GrowthMetric: Double] {
        var scores = Dictionary(uniqueKeysWithValues: GrowthMetric.allCases.map { ($0, 3.0) })
        for contribution in contributions {
            let signedDelta = contribution.direction == .positive ? contribution.delta : -contribution.delta
            scores[contribution.metric] = min(5.0, max(1.0, (scores[contribution.metric] ?? 3.0) + signedDelta))
        }
        return scores
    }

    private func growthReasons(from contributions: [MetricContribution]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: GrowthMetric.allCases.map { metric in
            let metricContributions = contributions.filter { $0.metric == metric }
            let positive = metricContributions.filter { $0.direction == .positive }.count
            let negative = metricContributions.filter { $0.direction == .negative }.count
            let reason: String
            if metricContributions.isEmpty {
                reason = "本期还没有足够证据解释该指标。"
            } else {
                reason = "来自 \(positive) 条正向证据和 \(negative) 条负向证据。"
            }
            return (metric.rawValue, reason)
        })
    }

    private func localGrowthSummary(
        completeLoopCount: Int,
        positiveCount: Int,
        negativeCount: Int
    ) -> String {
        "已基于 \(completeLoopCount) 次完整复盘生成本地成长快照：\(positiveCount) 条正向证据，\(negativeCount) 条负向证据。"
    }

    private func hasProjectLink(forSourceId sourceId: String) -> Bool {
        historyRecords.contains { record in
            record.projectLinks.contains { $0.sourceId == sourceId }
        }
    }

    private func hasExistingProjectLink(forSourceId sourceId: String) async -> Bool {
        if hasProjectLink(forSourceId: sourceId) { return true }
        guard let links = try? await projectLinkRepository?.links(forSourceIds: [sourceId]) else {
            return false
        }
        return !links.isEmpty
    }

    private func appendVisibleProjectLink(_ link: ProjectLink, dailyEntryId: UUID) {
        guard !hasProjectLink(forSourceId: link.sourceId) else { return }
        if let index = historyRecords.firstIndex(where: { $0.draft.id == dailyEntryId }) {
            historyRecords[index].projectLinks.append(link)
            return
        }
        guard dailyEntryId == todayDraft.id else { return }
        var record = currentHistoryRecord
        record.projectLinks = [link]
        historyRecords = [record] + historyRecords.filter { $0.id != record.id }
    }

    private static func projectName(from quest: Quest) -> String {
        let title = quest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "未命名长期议题" }
        if title.count <= 18 { return title }
        return String(title.prefix(18)) + "..."
    }

    private static func projectGoal(from quest: Quest) -> String {
        nonEmpty(quest.whyItMatters) ?? "持续推进：\(projectName(from: quest))"
    }

    private static func projectSuccessCriteria(from quest: Quest) -> String {
        nonEmpty(quest.completionCriteria) ?? "后续复盘中能看到明确进展证据。"
    }

    private static func projectName(from principle: PrincipleAsset) -> String {
        let title = principle.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "未命名长期议题" }
        if title.count <= 18 { return title }
        return String(title.prefix(18)) + "..."
    }

    private static func projectGoal(from principle: PrincipleAsset) -> String {
        nonEmpty(principle.summary) ?? "持续训练：\(projectName(from: principle))"
    }

    private static func projectSuccessCriteria(from principle: PrincipleAsset) -> String {
        nonEmpty(principle.successCriteria) ?? "后续复盘中能看到这条原则被实际使用。"
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func actions(from text: String) -> [String] {
        let actions = text
            .split(whereSeparator: \.isNewline)
            .map { line in
                line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-*•0123456789.、 "))
            }
            .filter { !$0.isEmpty }
        let fallback = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return actions.isEmpty && !fallback.isEmpty ? [fallback] : actions
    }

    func navigateToHistoryDeepLink(_ link: HistoryDeepLink) {
        historyDeepLink = link
        selectedTab = .history
    }

    func createProjectFromCurrentFocus() async {
        guard let mainQuest else {
            todayLoopMessage = "请先生成一条明日主线任务，再创建长期议题。"
            return
        }
        await createProjectFromQuest(mainQuest, dailyEntryId: todayDraft.id)
    }

    func createProjectFromQuest(_ quest: Quest, dailyEntryId: UUID) async {
        await createProject(
            name: Self.projectName(from: quest),
            goal: Self.projectGoal(from: quest),
            successCriteria: Self.projectSuccessCriteria(from: quest),
            currentBottleneck: Self.nonEmpty(quest.expectedResistance),
            openQuestions: Self.nonEmpty(quest.reflectionQuestion).map { [$0] } ?? [],
            sourceType: .quest,
            sourceId: quest.id.uuidString,
            linkType: .task,
            dailyEntryId: dailyEntryId,
            createdFrom: "quest"
        )
    }

    func createProjectFromPrinciple(_ principle: PrincipleAsset, dailyEntryId: UUID) async {
        await createProject(
            name: Self.projectName(from: principle),
            goal: Self.projectGoal(from: principle),
            successCriteria: Self.projectSuccessCriteria(from: principle),
            currentBottleneck: Self.nonEmpty(principle.triggerContext),
            openQuestions: principle.actions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            sourceType: .principle,
            sourceId: principle.id.uuidString,
            linkType: .principle,
            dailyEntryId: dailyEntryId,
            createdFrom: "principle"
        )
    }

    private func createProject(
        name: String,
        goal: String,
        successCriteria: String,
        currentBottleneck: String?,
        openQuestions: [String],
        sourceType: ProjectSourceType,
        sourceId: String,
        linkType: ProjectLinkType,
        dailyEntryId: UUID,
        createdFrom: String
    ) async {
        guard let projectRepository, let projectLinkRepository else {
            todayLoopMessage = "本地项目存储暂不可用。"
            return
        }

        let trimmedSourceId = sourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSourceId.isEmpty else {
            todayLoopMessage = "这条证据缺少来源，不能保存为长期议题。"
            return
        }
        guard !(await hasExistingProjectLink(forSourceId: trimmedSourceId)) else {
            todayLoopMessage = "这条证据已经关联到长期议题。"
            return
        }

        let project = Project(
            name: name,
            goal: goal,
            successCriteria: successCriteria,
            currentBottleneck: currentBottleneck,
            openQuestions: openQuestions,
            status: .active,
            createdBy: .user,
            confidence: 1,
            fieldRevisions: [
                "created_from": "\(createdFrom):\(trimmedSourceId)"
            ]
        )
        let link = ProjectLink(
            projectId: project.id,
            sourceType: sourceType,
            sourceId: trimmedSourceId,
            linkType: linkType,
            confidence: 1,
            isUserConfirmed: true
        )

        do {
            try await projectRepository.saveProject(project)
            try await projectLinkRepository.saveLink(link)
            projectNames[project.id] = project.name
            projectsById[project.id] = project
            if dailyEntryRepository != nil {
                await loadHistoryRecords()
            }
            appendVisibleProjectLink(link, dailyEntryId: dailyEntryId)
            todayLoopMessage = "已保存为长期议题：\(project.name)。"
        } catch {
            todayLoopMessage = "长期议题保存失败，已保留当前任务。"
        }
    }

    func acceptedContributions(for metric: GrowthMetric) -> [MetricContribution] {
        metricContributions.filter { contribution in
            contribution.metric == metric &&
            contribution.candidateStatus == .accepted &&
            contribution.userFeedback != .inaccurate &&
            contribution.userFeedback != .dismissed &&
            !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func acceptedReportReviewContributions(for metric: GrowthMetric) -> [MetricContribution] {
        growthReportReviewContributions.filter { contribution in
            contribution.metric == metric &&
            contribution.isAcceptedForTrend &&
            !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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

    func retryCurrentAIStep() {
        guard !isAIRunning else {
            todayLoopMessage = "AI 正在运行，请等待当前请求完成。"
            return
        }

        let draftID = todayDraft.id
        switch todayDraft.state {
        case .organizing:
            let trimmedInput = todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedInput.isEmpty else {
                todayLoopMessage = "请输入内容后再重试整理。"
                return
            }
            todayLoopMessage = "正在重试 AI 整理。"
            lastAIFailureMessage = nil
            canRetryCurrentAI = false
            Task {
                await generateCardsWithAIOrFallback(from: trimmedInput, draftID: draftID, allowsFallback: false)
            }
        case .answerQuestions:
            guard todayDraft.selectedLens != nil else {
                todayLoopMessage = "请选择透镜后再重试追问。"
                return
            }
            todayLoopMessage = "正在重试 AI 追问。"
            lastAIFailureMessage = nil
            canRetryCurrentAI = false
            Task {
                await generateQuestionsWithAIOrFallback(draftID: draftID, allowsFallback: false)
            }
        case .reviewQuests:
            guard hasAnsweredReflectionQuestion else {
                todayLoopMessage = "至少回答一个问题后再重试生成任务。"
                return
            }
            todayLoopMessage = "正在重试 AI 任务。"
            lastAIFailureMessage = nil
            canRetryCurrentAI = false
            Task {
                await generateQuestsWithAIOrFallback(draftID: draftID, allowsFallback: false)
            }
        case .extractPrinciple:
            todayLoopMessage = "正在重试 AI 原则沉淀。"
            lastAIFailureMessage = nil
            canRetryCurrentAI = false
            Task {
                await generatePrincipleWithAIOrFallback(draftID: draftID, allowsFallback: false)
            }
        default:
            todayLoopMessage = "当前步骤没有可重试的 AI 调用。"
        }
    }

    func retryPendingAIRepairs() {
        guard pendingAIRepairCount > 0 else { return }
        guard !isAIRunning else {
            todayLoopMessage = "AI 正在运行，请等待当前补跑完成。"
            return
        }
        let draftID = todayDraft.id
        let currentState = todayDraft.state
        let promptsToRepair = pendingAIRepairPrompts
        let canRepairCards = canRunBackgroundCardRepair
        todayLoopMessage = "正在后台重试 AI 补全。"
        Task {
            if promptsToRepair.contains(.organizeCards),
               canRepairCards,
               !todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await generateCardsWithAIOrFallback(from: todayDraft.rawText, draftID: draftID, allowsFallback: false)
            } else if promptsToRepair.contains(.organizeCards) {
                pendingAIRepairPrompts.remove(.organizeCards)
            }

            if promptsToRepair.contains(.generateQuestions),
               todayDraft.selectedLens != nil {
                await generateQuestionsWithAIOrFallback(draftID: draftID, allowsFallback: false)
            }

            if promptsToRepair.contains(.generateQuests),
               hasAnsweredReflectionQuestion {
                await generateQuestsWithAIOrFallback(draftID: draftID, allowsFallback: false)
            }

            if promptsToRepair.contains(.extractPrinciple),
               !quests.isEmpty {
                await generatePrincipleWithAIOrFallback(draftID: draftID, allowsFallback: false)
            }

            if todayDraft.id == draftID {
                todayDraft.state = currentState
                persistDraft()
            }
        }
    }

    func dismissPendingAIRepairs() {
        pendingAIRepairPrompts = []
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        clearTodayLoopMessage()
    }

    func canNavigateTodayLoop(to state: DailyLoopState) -> Bool {
        guard let targetIndex = DailyLoopState.allCases.firstIndex(of: state),
              let currentIndex = DailyLoopState.allCases.firstIndex(of: todayDraft.state)
        else { return false }

        return targetIndex <= currentIndex && state != .organizing && todayDraft.state != .organizing
    }

    func navigateTodayLoop(to state: DailyLoopState) {
        guard canNavigateTodayLoop(to: state), state != todayDraft.state else { return }
        trimDerivedState(after: state)
        moveTodayLoop(to: state, message: "已回到\(state.title)，后续内容会在确认后重新生成。")
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
        if todayDraft.state != .capture {
            trimDerivedState(after: .capture)
        }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clearTodayLoopMessage()
        }
        persistDraft()
    }

    func supplementTodayCapture(_ text: String) {
        let supplement = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !supplement.isEmpty else {
            todayLoopMessage = "请输入补充材料后再重新整理。"
            return
        }

        let existing = todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        todayDraft.rawText = existing.isEmpty ? supplement : "\(todayDraft.rawText)\n\(supplement)"
        trimDerivedState(after: .capture)
        moveTodayLoop(to: .capture, message: "已加入补充材料，请重新整理成卡片。")
        persistDraft()
    }

    func confirmCard(_ cardID: ThinkingCard.ID) {
        trimDerivedState(after: .reviewCards)
        updateCard(cardID) { card in
            card.isConfirmed = true
            card.isExcludedFromModel = false
        }
    }

    func excludeCard(_ cardID: ThinkingCard.ID) {
        trimDerivedState(after: .reviewCards)
        updateCard(cardID) { card in
            card.isConfirmed = false
            card.isExcludedFromModel = true
        }
    }

    func deleteCard(_ cardID: ThinkingCard.ID) {
        trimDerivedState(after: .reviewCards)
        thinkingCards.removeAll { $0.id == cardID }
        clearTodayLoopMessage()
        persistCards()
    }

    func updateCard(
        _ cardID: ThinkingCard.ID,
        type: ThinkingCardType,
        title: String,
        body: String,
        priority: PriorityLevel,
        sensitivity: SensitivityLevel
    ) {
        trimDerivedState(after: .reviewCards)
        updateCard(cardID) { card in
            card.type = type
            card.title = title
            card.body = body
            card.priority = priority
            card.sensitivity = sensitivity
        }
    }

    func selectTodayMode(_ mode: SessionMode) {
        todayDraft.sessionMode = mode
        todayDraft.hasSelectedSessionMode = true
        trimDerivedState(after: todayDraft.state == .capture ? .capture : .selectMode)
        clearTodayLoopMessage()
        persistDraft()
    }

    func selectThinkingLens(_ lens: ThinkingLens) {
        todayDraft.selectedLens = lens
        trimDerivedState(after: .selectLens)
        Task { await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuestions) }
        clearTodayLoopMessage()
        persistDraft()
        persistLensSession()
    }

    func updateQuestionAnswer(questionID: ReflectionQuestion.ID, answer: String) {
        guard let index = questions.firstIndex(where: { $0.id == questionID }) else { return }
        questions[index].answer = answer
        trimDerivedState(after: .answerQuestions)
        if !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clearTodayLoopMessage()
        }
        persistLensSession()
    }

    func updateQuest(
        _ questID: Quest.ID,
        title: String,
        whyItMatters: String,
        completionCriteria: String,
        expectedResistance: String,
        reflectionQuestion: String
    ) {
        guard let index = quests.firstIndex(where: { $0.id == questID }) else { return }
        quests[index].title = title
        quests[index].whyItMatters = whyItMatters
        quests[index].completionCriteria = completionCriteria
        quests[index].expectedResistance = expectedResistance
        quests[index].reflectionQuestion = reflectionQuestion
        trimDerivedState(after: .reviewQuests)
        clearTodayLoopMessage()
        persistQuests()
    }

    func updatePrinciple(
        _ principleID: PrincipleAsset.ID,
        title: String,
        summary: String,
        triggerContext: String,
        actionsText: String,
        successCriteria: String,
        exceptions: String
    ) {
        guard let index = principles.firstIndex(where: { $0.id == principleID }) else { return }
        principles[index].title = title
        principles[index].summary = summary
        principles[index].triggerContext = triggerContext
        principles[index].actions = Self.actions(from: actionsText)
        principles[index].successCriteria = successCriteria
        principles[index].exceptions = exceptions
        clearTodayLoopMessage()
        persistPrinciples()
    }

    @discardableResult
    func addManualPrinciple(
        title: String,
        summary: String,
        triggerContext: String,
        actions: [String],
        successCriteria: String,
        exceptions: String
    ) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedSummary.isEmpty else {
            todayLoopMessage = "原则标题和摘要不能为空。"
            return false
        }

        let principle = PrincipleAsset(
            title: trimmedTitle,
            summary: trimmedSummary,
            triggerContext: triggerContext.trimmingCharacters(in: .whitespacesAndNewlines),
            actions: actions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            successCriteria: successCriteria.trimmingCharacters(in: .whitespacesAndNewlines),
            exceptions: exceptions.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .active
        )

        do {
            if let dailyEntryRepository {
                try await dailyEntryRepository.saveDraft(todayDraft)
            }
            if let principleRepository {
                try await principleRepository.savePrinciple(principle, sourceDailyEntryId: todayDraft.id)
            }
        } catch {
            todayLoopMessage = "保存原则资产失败。"
            return false
        }

        upsertManualPrincipleInMemory(principle)
        todayLoopMessage = principleRepository == nil ? "原则已添加到当前会话（当前未启用持久化）。" : "原则已保存。"
        return true
    }

    func skipPrinciple() {
        principles = []
        persistPrinciples()
        completeTodayLoop(message: "已跳过原则沉淀，今日闭环完成。")
    }

    func resetTodayLoop() {
        todayDraft = DailyEntryDraft()
        thinkingCards = []
        streamingCards = []
        streamingStatusText = ""
        questions = []
        quests = []
        principles = []
        referencedPrinciples = []
        todayLoopMessage = ""
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        pendingAIRepairPrompts = []
        reminderStatusMessage = "明日 09:00 本地提醒将在保存主线任务后请求授权。"

        Task {
            await initializeFromLastActiveQuest()
            persistDraft()
        }
    }

    private func saveYesterdayVerification() {
        guard let quest = mainQuest else {
            moveTodayLoop(to: .capture)
            return
        }
        guard todayDraft.yesterdayCompletion != nil else {
            todayLoopMessage = "请选择昨天主线任务的完成情况。"
            return
        }
        guard todayDraft.yesterdayValueRating != nil else {
            todayLoopMessage = "请选择昨天任务的价值判断。"
            return
        }

        let completion = todayDraft.yesterdayCompletion!
        let rating = todayDraft.yesterdayValueRating!
        let draftID = todayDraft.id

        todayLoopMessage = "正在保存昨日验证。"
        Task {
            await persistVerification(
                quest: quest,
                completion: completion,
                rating: rating,
                draftID: draftID
            )
            moveTodayLoop(to: .capture)
        }
    }

    private func persistVerification(
        quest: Quest,
        completion: YesterdayCompletion,
        rating: YesterdayValueRating,
        draftID: UUID
    ) async {
        var calibrationNote = "本地校准：用户自评完成度 \(completion.title)，价值 \(rating.title)。"
        var likelyIssue: String?
        var recommendation: String?

        if let todayAIService {
            do {
                let result = try await todayAIService.verifyQuest(
                    input: VerifyQuestInput(
                        sourceRecordIDs: [quest.id.uuidString, draftID.uuidString],
                        questTitle: quest.title,
                        completionCriteria: quest.completionCriteria,
                        completion: completion.rawValue,
                        valueRating: rating.rawValue,
                        rawText: todayDraft.rawText
                    ),
                    sessionMode: todayDraft.sessionMode
                )
                calibrationNote = result.calibrationNote
                likelyIssue = result.likelyIssue
                recommendation = result.recommendation
            } catch {
                calibrationNote = "本地校准（AI 校准失败）：用户自评完成度 \(completion.title)，价值 \(rating.title)。"
            }
        }

        let sourceDailyEntryId: UUID
        do {
            sourceDailyEntryId = try await questRepository?.sourceDailyEntryId(forQuestId: quest.id) ?? draftID
        } catch {
            sourceDailyEntryId = draftID
        }

        let verification = Verification(
            questId: quest.id,
            questTitle: quest.title,
            sourceDailyEntryId: sourceDailyEntryId,
            completion: completion,
            valueRating: rating,
            calibrationNote: calibrationNote,
            likelyIssue: likelyIssue,
            recommendation: recommendation
        )

        do {
            try await verificationRepository?.saveVerification(verification)
            let resolvedStatus = questStatus(for: completion)
            quests = quests.map { current in
                guard current.id == quest.id else { return current }
                var updated = current
                updated.status = resolvedStatus
                return updated
            }
            try await questRepository?.updateQuestStatus(resolvedStatus, questId: quest.id)
            await refreshGrowthEvidenceAfterTodayChange()
        } catch {
            todayLoopMessage = "校准记录保存失败，但已继续下一步。"
        }
    }

    private func questStatus(for completion: YesterdayCompletion) -> QuestStatus {
        switch completion {
        case .done:
            return .completed
        case .partial:
            return .partial
        case .missed:
            return .failed
        }
    }

    private func organizeCapture() {
        guard !isAIRunning else {
            todayLoopMessage = "AI 正在运行，请等待当前请求完成。"
            return
        }

        let trimmedInput = todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            todayLoopMessage = "请输入至少一条今天的事实、困惑或行动，再整理成卡片。"
            return
        }
        guard todayDraft.hasSelectedSessionMode else {
            todayLoopMessage = "请选择 Quick、Standard 或 Deep，再整理成卡片。"
            return
        }

        let draftID = todayDraft.id
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        moveTodayLoop(to: .organizing, message: "正在生成结构化卡片。")
        guard todayAIService != nil else {
            generateLocalCards(from: trimmedInput)
            recordAIFallback(prompt: .organizeCards, reason: "未配置 GLM，已使用本地整理。", canRetry: false)
            persistCards()
            return
        }
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
            todayLoopMessage = "至少确认一张卡片，才能进入思考透镜选择。"
            return
        }
        moveTodayLoop(to: .selectLens)
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
            guard todayAIService != nil else {
                generateLocalQuestions(from: todayDraft.rawText)
                Task { await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuestions) }
                persistLensSession()
                moveTodayLoop(to: .answerQuestions)
                recordAIFallback(prompt: .generateQuestions, reason: "未配置 GLM，已使用本地追问。", canRetry: false)
                return
            }
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
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        guard todayAIService != nil else {
            generateLocalQuests()
            Task { await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuests) }
            moveTodayLoop(to: .reviewQuests)
            recordAIFallback(prompt: .generateQuests, reason: "未配置 GLM，已使用本地任务。", canRetry: false)
            return
        }
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
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        guard todayAIService != nil else {
            generateLocalPrinciple()
            moveTodayLoop(to: .extractPrinciple)
            recordAIFallback(prompt: .extractPrinciple, reason: "未配置 GLM，已使用本地原则候选。", canRetry: false)
            return
        }
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
        todayLoopMessage = message
        persistDraft()
    }

    private func completeTodayLoop(message: String) {
        moveTodayLoop(to: .sessionComplete, message: message)
        Task {
            await refreshGrowthEvidenceAfterTodayChange()
        }
    }

    private func refreshGrowthEvidenceAfterTodayChange() async {
        await loadHistoryRecords()
        await loadLatestGrowthSnapshot()
        await generateLocalGrowthSnapshotFromHistoryIfNeeded()
    }

    func generateWeeklyGrowthReport() async {
        guard !isGeneratingGrowthReport else { return }
        guard let metricSnapshotRepository, let metricContributionRepository else {
            growthReportMessage = "本地成长存储暂不可用。"
            return
        }

        isGeneratingGrowthReport = true
        growthReportMessage = "正在生成周度校准报告。"
        defer { isGeneratingGrowthReport = false }

        let completedRecords = historyRecords
            .filter { $0.draft.state == .sessionComplete }
            .sorted { $0.draft.date < $1.draft.date }

        let context = buildGrowthReportContext(
            period: "weekly",
            completedRecords: completedRecords
        )

        guard let growthAIService else {
            growthReportMessage = "AI 成长报告服务暂不可用，已保留当前本地快照。"
            return
        }

        do {
            let result = try await growthAIService.generateWeeklyReport(context: context)
            try await metricSnapshotRepository.saveSnapshot(result.snapshot)
            let acceptedContributions = result.contributions.map { contribution in
                acceptedGrowthContribution(contribution)
            }
            for contribution in acceptedContributions {
                try await metricContributionRepository.saveContribution(contribution)
            }
            growthSnapshot = result.snapshot
            metricContributions = acceptedContributions
            growthReportReviewContributions = result.snapshot.canDisplayScores ? acceptedContributions : []
            growthReportMessage = result.snapshot.canDisplayScores
                ? "周度校准报告已生成。"
                : "证据不足，已记录周度证据积累状态。"
        } catch {
            growthReportMessage = "AI 成长报告生成失败，已保留当前本地快照。"
        }
    }

    func generateMonthlyGrowthReport() async {
        guard !isGeneratingGrowthReport else { return }
        guard let metricSnapshotRepository, let metricContributionRepository else {
            growthReportMessage = "本地成长存储暂不可用。"
            return
        }

        isGeneratingGrowthReport = true
        growthReportMessage = "正在生成月度成长报告。"
        defer { isGeneratingGrowthReport = false }

        let completedRecords = historyRecords
            .filter { $0.draft.state == .sessionComplete }
            .sorted { $0.draft.date < $1.draft.date }

        let context = buildGrowthReportContext(
            period: "monthly",
            completedRecords: completedRecords
        )

        guard let growthAIService else {
            growthReportMessage = "AI 成长报告服务暂不可用，已保留当前本地快照。"
            return
        }

        do {
            let result = try await growthAIService.generateMonthlyReport(context: context)
            try await metricSnapshotRepository.saveSnapshot(result.snapshot)
            let acceptedContributions = result.contributions.map { contribution in
                acceptedGrowthContribution(contribution)
            }
            for contribution in acceptedContributions {
                try await metricContributionRepository.saveContribution(contribution)
            }
            growthSnapshot = result.snapshot
            metricContributions = acceptedContributions
            growthReportReviewContributions = result.snapshot.canDisplayScores ? acceptedContributions : []
            growthReportMessage = result.snapshot.canDisplayScores
                ? "月度成长报告已生成。"
                : "证据不足，已记录月度证据积累状态。"
        } catch {
            growthReportMessage = "AI 成长月报生成失败，已保留当前本地快照。"
        }
    }

    private func buildGrowthReportContext(
        period: String,
        completedRecords: [HistoryRecord]
    ) -> GrowthReportContext {
        let summaries = completedRecords.map { record -> GrowthRecordSummary in
            GrowthRecordSummary(
                dailyEntryId: record.draft.id,
                date: record.draft.date,
                confirmedCardCount: record.confirmedCards.count,
                hasMainQuest: record.mainQuest != nil,
                mainQuestTitle: record.mainQuest?.title,
                mainQuestCompletionCriteria: record.mainQuest?.completionCriteria,
                verificationCompletion: record.verification?.completion.rawValue,
                verificationValueRating: record.verification?.valueRating.rawValue,
                calibrationNote: record.verification?.calibrationNote,
                hasLensSessionAnswers: record.lensSession?.questions.contains(where: { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? false,
                principleTitles: record.principles.map(\.title)
            )
        }

        let dismissed = historyRecords.flatMap { record in
            record.growthContributions.filter { $0.userFeedback == .inaccurate || $0.userFeedback == .dismissed }
        }.map(\.title)

        return GrowthReportContext(
            period: period,
            startDate: completedRecords.first?.draft.date,
            endDate: completedRecords.last?.draft.date,
            completeLoopCount: completedRecords.count,
            historyRecords: summaries,
            previousSnapshot: growthSnapshot.canDisplayScores ? growthSnapshot : nil,
            dismissedContributionTitles: dismissed
        )
    }

    private func acceptedGrowthContribution(_ contribution: MetricContribution) -> MetricContribution {
        var accepted = contribution
        accepted.candidateStatus = .accepted
        accepted.userFeedback = .none
        accepted.updatedAt = .now
        return accepted
    }

    private func trimDerivedState(after state: DailyLoopState) {
        switch state {
        case .verifyYesterday:
            todayDraft.rawText = ""
            thinkingCards = []
            streamingCards = []
            streamingStatusText = ""
            todayDraft.hasSelectedSessionMode = false
            todayDraft.sessionMode = .standard
            todayDraft.selectedLens = nil
            questions = []
            quests = []
            principles = []
            referencedPrinciples = []
        case .capture, .organizing:
            thinkingCards = []
            streamingCards = []
            streamingStatusText = ""
            todayDraft.selectedLens = nil
            questions = []
            quests = []
            principles = []
            referencedPrinciples = []
        case .reviewCards:
            todayDraft.hasSelectedSessionMode = false
            todayDraft.sessionMode = .standard
            todayDraft.selectedLens = nil
            questions = []
            quests = []
            principles = []
            referencedPrinciples = []
        case .selectMode:
            todayDraft.selectedLens = nil
            questions = []
            quests = []
            principles = []
            referencedPrinciples = []
        case .selectLens:
            questions = []
            quests = []
            principles = []
            referencedPrinciples = []
        case .answerQuestions:
            quests = []
            principles = []
        case .reviewQuests:
            principles = []
        case .extractPrinciple, .sessionComplete:
            break
        }
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        persistDraft()
    }

    private func handleAIFailure(
        prompt: PromptID,
        error: Error,
        fallback: () -> Void
    ) {
        fallback()
        recordAIFallback(prompt: prompt, reason: aiFailureMessage(for: error), canRetry: true)
    }

    private func recordAISuccess(prompt: PromptID? = nil, message: String = "") {
        if let prompt {
            pendingAIRepairPrompts.remove(prompt)
        }
        lastAIFailureMessage = nil
        canRetryCurrentAI = false
        todayLoopMessage = message
    }

    private func recordAIFallback(prompt: PromptID, reason: String, canRetry: Bool) {
        let message = "AI \(prompt.displayName)失败：\(reason) 已使用本地结果，可继续流程。"
        lastAIFailureMessage = message
        canRetryCurrentAI = canRetry
        if canRetry {
            pendingAIRepairPrompts.insert(prompt)
        }
        todayLoopMessage = message
    }

    private func recordAIRepairFailure(prompt: PromptID, reason: String) {
        let message = "AI \(prompt.displayName)重试失败：\(reason) 已保留当前内容，可稍后再试。"
        lastAIFailureMessage = message
        canRetryCurrentAI = true
        pendingAIRepairPrompts.insert(prompt)
        todayLoopMessage = message
    }

    private func aiFailureMessage(for error: Error) -> String {
        if let llmError = error as? LLMClientError {
            return llmError.userFacingMessage
        }
        return error.localizedDescription
    }

    private func beginAIActivity(_ message: String) {
        activeAIRequestCount += 1
        isAIRunning = true
        aiActivityMessage = message
    }

    private func endAIActivity() {
        activeAIRequestCount = max(0, activeAIRequestCount - 1)
        isAIRunning = activeAIRequestCount > 0
        if !isAIRunning {
            aiActivityMessage = ""
        }
    }

    private func markLatestHistoricalRetryFailed(failedPromptRunId: UUID, reason: String) async {
        guard let historicalRetryCandidateRepository,
              let promptRunRepository
        else {
            todayLoopMessage = "历史 AI 重试失败：\(reason)"
            return
        }

        do {
            let failedRun = try await promptRunRepository
                .unresolvedFailures(limit: 200)
                .first { $0.id == failedPromptRunId }
            guard let sourceId = failedRun?.sourceRecordIds.compactMap(UUID.init(uuidString:)).first else {
                todayLoopMessage = "历史 AI 重试失败：\(reason)"
                return
            }
            let candidates = try await historicalRetryCandidateRepository.candidates(for: sourceId)
            if let candidate = candidates.first(where: { $0.failedPromptRunId == failedPromptRunId }) {
                try await historicalRetryCandidateRepository.updateStatus(
                    .failed,
                    candidateId: candidate.id,
                    error: reason
                )
            }
            todayLoopMessage = "历史 AI 重试失败：\(reason)"
        } catch {
            todayLoopMessage = "历史 AI 重试失败：\(reason)"
        }
    }

    private static func historicalRetryInputSummary(from rawText: String) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 120 else { return trimmed }
        return String(trimmed.prefix(120)) + "..."
    }

    private static func historicalRetryCandidatePayloadJSON(from cards: [ThinkingCard]) throws -> String {
        let payload = HistoricalRetryCandidatePayload(cards: cards.map(HistoricalRetryCardPayload.init(card:)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? #"{"cards":[]}"#
    }

    private static func discoverRepairPromptRunId(
        after beforeRuns: [PromptRun],
        failedRun: PromptRun,
        promptRunRepository: PromptRunRepository
    ) async throws -> UUID? {
        let beforeIds = Set(beforeRuns.map(\.id))
        return try await promptRunRepository
            .recentPromptRuns(limit: 20)
            .first { run in
                !beforeIds.contains(run.id) &&
                run.promptId == PromptID.organizeCards.rawValue &&
                run.error == nil &&
                run.responseJSON != nil &&
                Set(run.sourceRecordIds) == Set(failedRun.sourceRecordIds)
            }?
            .id
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

    private func generateCardsWithAIOrFallback(
        from input: String,
        draftID: DailyEntryDraft.ID,
        allowsFallback: Bool = true
    ) async {
        guard todayDraft.id == draftID else { return }
        beginAIActivity("正在整理思考卡片。")
        defer { endAIActivity() }

        if let todayAIService {
            do {
                streamingCards = []
                streamingStatusText = "正在连接 GLM 流式整理。"
                thinkingCards = try await todayAIService.streamOrganizedCards(
                    for: TodayAIContext(draft: todayDraft),
                    onUpdate: { [weak self] drafts in
                        await MainActor.run {
                            guard let self, self.todayDraft.id == draftID else { return }
                            self.streamingCards = drafts
                            let closedCount = drafts.compactMap(\.domainCard).count
                            if closedCount > 0 {
                                self.streamingStatusText = "已闭合 \(closedCount) 张候选卡片，继续接收中。"
                            } else if drafts.isEmpty {
                                self.streamingStatusText = "等待第一张候选卡片。"
                            } else {
                                self.streamingStatusText = "正在生成第 \(drafts.count) 张候选卡片。"
                            }
                        }
                    }
                )
                streamingStatusText = "已生成 \(thinkingCards.count) 张候选卡片，请查看并确认。"
                recordAISuccess(prompt: .organizeCards, message: "已生成结构化卡片，请查看并确认。")
                persistCards()
                return
            } catch {
                if allowsFallback {
                    handleAIFailure(prompt: .organizeCards, error: error) {
                        let streamedCards = streamingCards.compactMap(\.domainCard)
                        if streamedCards.isEmpty {
                            generateLocalCards(from: input)
                            streamingStatusText = "流式整理失败，已使用本地 fallback。"
                        } else {
                            thinkingCards = streamedCards
                            streamingStatusText = "流式中断，已保留 \(streamedCards.count) 张闭合卡片。"
                        }
                        persistCards()
                    }
                } else {
                    recordAIRepairFailure(prompt: .organizeCards, reason: aiFailureMessage(for: error))
                }
                return
            }
        }

        if allowsFallback {
            generateLocalCards(from: input)
            recordAIFallback(prompt: .organizeCards, reason: "未配置 GLM，已使用本地整理。", canRetry: false)
            persistCards()
        }
    }

    private func generateQuestionsWithAIOrFallback(
        draftID: DailyEntryDraft.ID,
        allowsFallback: Bool = true
    ) async {
        guard todayDraft.id == draftID else { return }
        beginAIActivity("正在生成追问。")
        defer { endAIActivity() }
        let input = todayDraft.rawText

        if let todayAIService {
            do {
                let contextPrinciples = await contextPrinciplesForAI()
                questions = try await todayAIService.generateQuestions(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions,
                        principles: contextPrinciples
                    )
                )
                refreshReferencedPrinciples(promptID: .generateQuestions, from: contextPrinciples)
                persistLensSession()
                moveTodayLoop(to: .answerQuestions)
                recordAISuccess(prompt: .generateQuestions)
                return
            } catch {
                if allowsFallback {
                    handleAIFailure(prompt: .generateQuestions, error: error) {
                        generateLocalQuestions(from: input)
                        Task { await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuestions) }
                        persistLensSession()
                        moveTodayLoop(to: .answerQuestions)
                    }
                } else {
                    recordAIRepairFailure(prompt: .generateQuestions, reason: aiFailureMessage(for: error))
                }
                return
            }
        }

        if allowsFallback {
            generateLocalQuestions(from: input)
            await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuestions)
            persistLensSession()
            moveTodayLoop(to: .answerQuestions)
            recordAIFallback(prompt: .generateQuestions, reason: "未配置 GLM，已使用本地追问。", canRetry: false)
        }
    }

    private func generateQuestsWithAIOrFallback(
        draftID: DailyEntryDraft.ID,
        allowsFallback: Bool = true
    ) async {
        guard todayDraft.id == draftID else { return }
        beginAIActivity("正在生成明日任务。")
        defer { endAIActivity() }

        if let todayAIService {
            do {
                let contextPrinciples = await contextPrinciplesForAI()
                quests = try await todayAIService.generateQuests(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions,
                        principles: contextPrinciples
                    )
                )
                refreshReferencedPrinciples(promptID: .generateQuests, from: contextPrinciples)
                persistQuests()
                moveTodayLoop(to: .reviewQuests)
                recordAISuccess(prompt: .generateQuests)
                return
            } catch {
                if allowsFallback {
                    handleAIFailure(prompt: .generateQuests, error: error) {
                        generateLocalQuests()
                        Task { await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuests) }
                        moveTodayLoop(to: .reviewQuests)
                    }
                } else {
                    recordAIRepairFailure(prompt: .generateQuests, reason: aiFailureMessage(for: error))
                }
                return
            }
        }

        if allowsFallback {
            generateLocalQuests()
            await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuests)
            moveTodayLoop(to: .reviewQuests)
            recordAIFallback(prompt: .generateQuests, reason: "未配置 GLM，已使用本地任务。", canRetry: false)
        }
    }

    private func generatePrincipleWithAIOrFallback(
        draftID: DailyEntryDraft.ID,
        allowsFallback: Bool = true
    ) async {
        guard todayDraft.id == draftID else { return }
        beginAIActivity("正在沉淀行动准则。")
        defer { endAIActivity() }

        if let todayAIService {
            do {
                principles = try await todayAIService.extractPrinciple(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions,
                        quests: quests,
                        principles: await existingPrinciplesForDedupe()
                    )
                )
                persistPrinciples()
                let message = principles.isEmpty ? "没有足够稳定的原则候选，可以直接跳过。" : ""
                moveTodayLoop(to: .extractPrinciple, message: message)
                recordAISuccess(prompt: .extractPrinciple, message: message)
                return
            } catch {
                if allowsFallback {
                    handleAIFailure(prompt: .extractPrinciple, error: error) {
                        generateLocalPrinciple()
                        moveTodayLoop(to: .extractPrinciple)
                    }
                } else {
                    recordAIRepairFailure(prompt: .extractPrinciple, reason: aiFailureMessage(for: error))
                }
                return
            }
        }

        if allowsFallback {
            generateLocalPrinciple()
            moveTodayLoop(to: .extractPrinciple)
            recordAIFallback(prompt: .extractPrinciple, reason: "未配置 GLM，已使用本地原则候选。", canRetry: false)
        }
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
                confidence: 0.72
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
        let cards = thinkingCards.filter { $0.isConfirmed || $0.isExcludedFromModel }
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

    private var canRunBackgroundCardRepair: Bool {
        thinkingCards.isEmpty &&
        questions.isEmpty &&
        quests.isEmpty &&
        principles.isEmpty
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

    private func persistLensSession() {
        guard let lensSessionRepository, let lens = todayDraft.selectedLens else { return }
        let draftID = todayDraft.id
        let currentQuestions = questions
        Task {
            let session = LensSession(
                dailyEntryId: draftID,
                selectedLens: lens,
                questions: currentQuestions
            )
            do {
                try await lensSessionRepository.saveLensSession(session)
            } catch {
                await MainActor.run {
                    todayLoopMessage = "保存透镜会话失败。"
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

    private func contextPrinciplesForAI() async -> [PrincipleAsset] {
        do {
            if let activePrinciples = try await principleRepository?.activePrinciples() {
                return activePrinciples
            }
        } catch {
            todayLoopMessage = "读取历史原则失败，已继续当前流程。"
        }
        return activePrinciples
    }

    private func loadActivePrinciples() async {
        do {
            if let storedPrinciples = try await principleRepository?.activePrinciples() {
                activePrinciples = storedPrinciples
            } else {
                activePrinciples = principles.filter { $0.status == .active }
            }
        } catch {
            activePrinciples = principles.filter { $0.status == .active }
            todayLoopMessage = "读取历史原则失败，已继续当前流程。"
        }
    }

    private func upsertManualPrincipleInMemory(_ principle: PrincipleAsset) {
        if let todayIndex = principles.firstIndex(where: { $0.id == principle.id }) {
            principles[todayIndex] = principle
        } else {
            principles.append(principle)
        }
        if let activeIndex = activePrinciples.firstIndex(where: { $0.id == principle.id }) {
            activePrinciples[activeIndex] = principle
        } else {
            activePrinciples.insert(principle, at: 0)
        }
    }

    private func existingPrinciplesForDedupe() async -> [PrincipleAsset] {
        var merged: [PrincipleAsset.ID: PrincipleAsset] = Dictionary(uniqueKeysWithValues: principles.map { ($0.id, $0) })
        for principle in await contextPrinciplesForAI() {
            merged[principle.id] = principle
        }
        return Array(merged.values).sorted { $0.title < $1.title }
    }

    private func refreshReferencedPrinciplesForCurrentContext(promptID: PromptID) async {
        let contextPrinciples = await contextPrinciplesForAI()
        refreshReferencedPrinciples(promptID: promptID, from: contextPrinciples)
    }

    private func refreshReferencedPrinciples(promptID: PromptID, from contextPrinciples: [PrincipleAsset]) {
        let context = TodayAIContext(
            draft: todayDraft,
            confirmedCards: confirmedCardsForAI,
            questions: questions,
            quests: quests,
            principles: contextPrinciples
        )
        referencedPrinciples = LocalPrincipleRetriever().relevantPrinciples(
            for: context,
            promptID: promptID,
            limit: 3
        )
    }

    private var currentHistoryRecord: HistoryRecord {
        HistoryRecord(
            draft: todayDraft,
            cards: thinkingCards,
            quests: quests,
            principles: principles,
            verification: nil,
            lensSession: todayDraft.selectedLens.map { lens in
                LensSession(dailyEntryId: todayDraft.id, selectedLens: lens, questions: questions)
            }
        )
    }

    private static func makeTodayAIService(
        apiKeyStore: KeychainAPIKeyStore,
        promptRunRepository: PromptRunRepository?
    ) -> TodayAIService {
        TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: makeLLMClient(apiKeyStore: apiKeyStore, promptRunRepository: promptRunRepository)
        )
    }

    private static func makeLLMClient(
        apiKeyStore: KeychainAPIKeyStore,
        promptRunRepository: PromptRunRepository?
    ) -> LLMClient {
        let key = (try? apiKeyStore.loadAPIKey())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            let missingKeyClient = MissingAPIKeyLLMClient()
            guard let promptRunRepository else { return missingKeyClient }
            return PromptTracingLLMClient(
                base: missingKeyClient,
                repository: promptRunRepository,
                modelProvider: "GLM",
                modelName: "missing-api-key"
            )
        }

        var config = GLMClientConfiguration()
        if let customURL = (try? apiKeyStore.loadBaseURL())?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customURL.isEmpty, let url = URL(string: customURL) {
            config = GLMClientConfiguration(
                baseURL: GLMClientConfiguration.normalizeBaseURL(url),
                model: config.model,
                temperature: config.temperature,
                requestTimeout: config.requestTimeout,
                protocolKind: config.protocolKind,
                usesJSONResponseFormat: config.usesJSONResponseFormat
            )
        }

        if let modelName = (try? apiKeyStore.loadModelName())?.trimmingCharacters(in: .whitespacesAndNewlines),
           !modelName.isEmpty {
            config = GLMClientConfiguration(
                baseURL: config.baseURL,
                model: modelName,
                temperature: config.temperature,
                requestTimeout: config.requestTimeout,
                protocolKind: config.protocolKind,
                usesJSONResponseFormat: config.usesJSONResponseFormat
            )
        }

        let directClient = DirectGLMClient(apiKey: key, configuration: config)
        guard let promptRunRepository else { return directClient }
        return PromptTracingLLMClient(
            base: directClient,
            repository: promptRunRepository,
            modelProvider: "GLM",
            modelName: config.model
        )
    }

    private func refreshAIServiceFromKeychainIfNeeded() {
        guard refreshesAIServiceFromKeychain else { return }
        todayAIService = Self.makeTodayAIService(
            apiKeyStore: apiKeyStore,
            promptRunRepository: promptRunRepository
        )
    }

    func refreshAPIKeyStatus() {
        do {
            let key = try apiKeyStore.loadAPIKey()
            apiKeyConfigured = key?.isEmpty == false
            refreshAIServiceFromKeychainIfNeeded()
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
            refreshAIServiceFromKeychainIfNeeded()
            apiKeyStatusMessage = "GLM API Key 已保存到 Keychain。"
            testGLMConnection()
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
            refreshAIServiceFromKeychainIfNeeded()
            apiKeyStatusMessage = "GLM API Key 已清除。"
            glmConnectionMessage = ""
        } catch {
            apiKeyStatusMessage = "清除 Keychain 失败。"
        }
        updateSettingsMessage()
    }

    var currentBaseURL: String {
        (try? apiKeyStore.loadBaseURL()) ?? ""
    }

    var currentModelName: String {
        (try? apiKeyStore.loadModelName()) ?? ""
    }

    func saveGLMBaseURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try apiKeyStore.deleteBaseURL()
                apiKeyStatusMessage = "已恢复默认 API 地址。"
            } else {
                guard URL(string: trimmed) != nil else {
                    apiKeyStatusMessage = "URL 格式不正确。"
                    updateSettingsMessage()
                    return
                }
                let normalized = GLMClientConfiguration.normalizeBaseURL(URL(string: trimmed)!).absoluteString
                try apiKeyStore.saveBaseURL(normalized)
                apiKeyStatusMessage = "API Base URL 已保存。"
            }
            refreshAIServiceFromKeychainIfNeeded()
            testGLMConnection()
        } catch {
            apiKeyStatusMessage = "保存 Base URL 失败。"
        }
        updateSettingsMessage()
    }

    func clearGLMBaseURL() {
        do {
            try apiKeyStore.deleteBaseURL()
            refreshAIServiceFromKeychainIfNeeded()
            apiKeyStatusMessage = "已恢复默认 API 地址。"
            testGLMConnection()
        } catch {
            apiKeyStatusMessage = "清除 Base URL 失败。"
        }
        updateSettingsMessage()
    }

    func saveGLMModelName(_ modelName: String) {
        let trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try apiKeyStore.deleteModelName()
                apiKeyStatusMessage = "已恢复默认模型。"
            } else {
                try apiKeyStore.saveModelName(trimmed)
                apiKeyStatusMessage = "模型名已保存。"
            }
            refreshAIServiceFromKeychainIfNeeded()
            testGLMConnection()
        } catch {
            apiKeyStatusMessage = "保存模型名失败。"
        }
        updateSettingsMessage()
    }

    func saveGLMEndpointConfiguration(baseURL: String, modelName: String) {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if trimmedURL.isEmpty {
                try apiKeyStore.deleteBaseURL()
            } else {
                guard let url = URL(string: trimmedURL) else {
                    apiKeyStatusMessage = "URL 格式不正确。"
                    updateSettingsMessage()
                    return
                }
                let normalized = GLMClientConfiguration.normalizeBaseURL(url).absoluteString
                try apiKeyStore.saveBaseURL(normalized)
            }

            if trimmedModel.isEmpty {
                try apiKeyStore.deleteModelName()
            } else {
                try apiKeyStore.saveModelName(trimmedModel)
            }

            refreshAIServiceFromKeychainIfNeeded()
            apiKeyStatusMessage = "GLM 地址和模型配置已保存。"
            testGLMConnection()
        } catch {
            apiKeyStatusMessage = "保存 GLM 配置失败。"
            updateSettingsMessage()
        }
    }

    func testGLMConnection() {
        guard apiKeyConfigured else {
            glmConnectionMessage = "未配置 API Key，暂不测试连接。"
            updateSettingsMessage()
            return
        }

        isTestingGLMConnection = true
        glmConnectionMessage = "正在测试 GLM 连接..."
        updateSettingsMessage()

        let client = Self.makeLLMClient(apiKeyStore: apiKeyStore, promptRunRepository: promptRunRepository)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "connection-test",
                systemText: "Return valid JSON only.",
                userText: "Reply with {\"ok\":true}.",
                outputSchemaVersion: 1
            ),
            inputSummary: "connection test",
            jsonPayload: ["purpose": "test"]
        )

        Task {
            do {
                _ = try await client.complete(request)
                glmConnectionMessage = "GLM 连接测试通过。"
            } catch let error as LLMClientError {
                glmConnectionMessage = "GLM 连接测试失败：\(error.userFacingMessage)"
            } catch {
                glmConnectionMessage = "GLM 连接测试失败：\(error.localizedDescription)"
            }
            isTestingGLMConnection = false
            updateSettingsMessage()
        }
    }

    private func updateSettingsMessage() {
        let baseMessage: String
        if let persistenceUnavailableMessage {
            baseMessage = "\(apiKeyStatusMessage)\n\(persistenceUnavailableMessage)"
        } else {
            baseMessage = apiKeyStatusMessage
        }
        let connection = glmConnectionMessage.isEmpty ? "" : "\n\(glmConnectionMessage)"
        settingsMessage = "\(baseMessage)\(connection)\n\(reminderStatusMessage)"
    }

    // MARK: - Project AI Candidate Review

    var pendingProjectCandidateCount: Int {
        projectCandidates.filter { $0.status == .pending }.count
    }

    var hasEnoughEvidenceForProjectSuggestions: Bool {
        let confirmedCards = thinkingCards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
        return confirmedCards.count >= 2
    }

    func suggestProjectsForToday(projectAIService: ProjectAIService? = nil) async {
        guard let projectCandidateRepository else {
            projectSuggestionMessage = "本地候选存储暂不可用。"
            return
        }

        isGeneratingProjectSuggestions = true
        projectSuggestionMessage = "正在生成项目建议。"

        let service = projectAIService ?? self.projectAIService
        guard let service else {
            isGeneratingProjectSuggestions = false
            projectSuggestionMessage = "AI 项目建议服务暂不可用。"
            return
        }

        let context = buildProjectSuggestionContext()
        do {
            let result = try await service.suggestProjectLinks(context: context)

            var savedCandidates: [ProjectCandidate] = []
            for candidate in result.newProjectCandidates {
                guard !candidate.sourceRefs.isEmpty else { continue }
                try await projectCandidateRepository.saveCandidate(candidate)
                savedCandidates.append(candidate)
            }

            projectLinkCandidates = result.linkCandidates
            projectCandidates = savedCandidates
            isGeneratingProjectSuggestions = false
            projectSuggestionMessage = savedCandidates.isEmpty && result.linkCandidates.isEmpty
                ? "暂无足够的项目建议。"
                : ""
        } catch {
            isGeneratingProjectSuggestions = false
            projectSuggestionMessage = "项目建议生成失败：\(error.localizedDescription)"
        }
    }

    func acceptProjectCandidate(_ candidate: ProjectCandidate) async {
        guard let projectRepository, let projectLinkRepository, let projectCandidateRepository else {
            projectSuggestionMessage = "本地存储暂不可用。"
            return
        }

        let project = Project(
            name: candidate.suggestedName,
            goal: candidate.suggestedGoal ?? "持续推进：\(candidate.suggestedName)",
            successCriteria: candidate.suggestedSuccessCriteria ?? "后续复盘中能看到明确进展证据。",
            currentBottleneck: candidate.suggestedBottleneck,
            status: .active,
            createdBy: .aiSuggested,
            confidence: candidate.confidence
        )

        guard let sourceId = candidate.sourceRefs.first else {
            projectSuggestionMessage = "候选缺少来源证据，无法创建项目。"
            return
        }

        let link = ProjectLink(
            projectId: project.id,
            sourceType: projectSourceType(for: sourceId),
            sourceId: sourceId,
            linkType: .evidence,
            confidence: candidate.confidence,
            isUserConfirmed: true
        )

        do {
            try await projectRepository.saveProject(project)
            try await projectLinkRepository.saveLink(link)
            var acceptedCandidate = candidate
            acceptedCandidate.status = .accepted
            acceptedCandidate.acceptedProjectId = project.id
            acceptedCandidate.updatedAt = .now
            try await projectCandidateRepository.saveCandidate(acceptedCandidate)

            projectNames[project.id] = project.name
            projectsById[project.id] = project
            projectCandidates = projectCandidates.map { c in
                guard c.id == candidate.id else { return c }
                return acceptedCandidate
            }

            if dailyEntryRepository != nil {
                await loadHistoryRecords()
            }
            projectSuggestionMessage = "已创建长期议题：\(project.name)。"
        } catch {
            projectSuggestionMessage = "项目创建失败，请稍后重试。"
        }
    }

    func dismissProjectCandidate(_ candidate: ProjectCandidate) async {
        guard let projectCandidateRepository else {
            projectSuggestionMessage = "本地存储暂不可用。"
            return
        }

        do {
            try await projectCandidateRepository.updateCandidateStatus(.dismissed, candidateId: candidate.id)
            projectCandidates = projectCandidates.map { c in
                guard c.id == candidate.id else { return c }
                var updated = c
                updated.status = .dismissed
                return updated
            }
        } catch {
            projectSuggestionMessage = "候选状态更新失败。"
        }
    }

    func acceptProjectLinkCandidate(_ linkCandidate: ProjectLinkCandidate) async {
        guard let projectLinkRepository else {
            projectSuggestionMessage = "本地存储暂不可用。"
            return
        }

        guard let projectId = linkCandidate.projectId else {
            projectSuggestionMessage = "关联候选缺少目标项目。"
            return
        }

        let link = ProjectLink(
            projectId: projectId,
            sourceType: linkCandidate.sourceType,
            sourceId: linkCandidate.sourceId,
            linkType: linkCandidate.linkType,
            confidence: linkCandidate.confidence,
            isUserConfirmed: true
        )

        do {
            try await projectLinkRepository.saveLink(link)
            projectLinkCandidates = projectLinkCandidates.filter { $0.id != linkCandidate.id }

            if dailyEntryRepository != nil {
                await loadHistoryRecords()
            }
            let projectName = projectNames[projectId] ?? "长期议题"
            projectSuggestionMessage = "已关联到：\(projectName)。"
        } catch {
            projectSuggestionMessage = "关联保存失败，请稍后重试。"
        }
    }

    func dismissProjectLinkCandidate(_ linkCandidate: ProjectLinkCandidate) {
        projectLinkCandidates = projectLinkCandidates.filter { $0.id != linkCandidate.id }
    }

    private func buildProjectSuggestionContext() -> ProjectSuggestionContext {
        let confirmedCards = thinkingCards
            .filter { $0.isConfirmed && !$0.isExcludedFromModel }
            .map { card in
                ProjectSuggestionCardContext(
                    id: card.id.uuidString,
                    type: card.type.rawValue,
                    title: card.title,
                    body: card.body
                )
            }

        let questsContext = quests.map { quest in
            ProjectSuggestionQuestContext(
                id: quest.id.uuidString,
                type: quest.type.rawValue,
                title: quest.title,
                completionCriteria: quest.completionCriteria
            )
        }

        let activeProjects = projectsById.values
            .filter { $0.status == .active }
            .map { project in
                ProjectSuggestionProjectContext(
                    id: project.id.uuidString,
                    name: project.name
                )
            }

        let existingLinkSourceIds = historyRecords.flatMap { record in
            record.projectLinks.map(\.sourceId)
        }

        return ProjectSuggestionContext(
            dailyEntryId: todayDraft.id,
            confirmedCards: confirmedCards,
            quests: questsContext,
            activeProjects: activeProjects,
            existingLinkSourceIds: existingLinkSourceIds
        )
    }

    private func projectSourceType(for sourceId: String) -> ProjectSourceType {
        if sourceId == todayDraft.id.uuidString { return .dailyEntry }
        if thinkingCards.contains(where: { $0.id.uuidString == sourceId }) { return .thinkingCard }
        if quests.contains(where: { $0.id.uuidString == sourceId }) { return .quest }
        if principles.contains(where: { $0.id.uuidString == sourceId }) { return .principle }

        for record in historyRecords {
            if record.draft.id.uuidString == sourceId { return .dailyEntry }
            if record.cards.contains(where: { $0.id.uuidString == sourceId }) { return .thinkingCard }
            if record.quests.contains(where: { $0.id.uuidString == sourceId }) { return .quest }
            if record.principles.contains(where: { $0.id.uuidString == sourceId }) { return .principle }
            if record.verification?.id.uuidString == sourceId { return .verification }
        }

        return .dailyEntry
    }

    func generateProjectInsights(for projectId: UUID, projectAIService: ProjectAIService? = nil) async {
        guard let projectInsightRepository else {
            projectInsightGenerationMessage = "本地洞察存储暂不可用。"
            return
        }

        guard let projectRepository, let projectLinkRepository else {
            projectInsightGenerationMessage = "项目数据暂不可用。"
            return
        }

        isGeneratingProjectInsights = true
        projectInsightGenerationMessage = "正在根据历史证据生成洞察。"

        let service = projectAIService ?? self.projectAIService
        guard let service else {
            isGeneratingProjectInsights = false
            projectInsightGenerationMessage = "AI 项目洞察服务暂不可用。"
            return
        }

        do {
            guard let project = try await projectRepository.project(id: projectId) else {
                isGeneratingProjectInsights = false
                projectInsightGenerationMessage = "项目不存在。"
                return
            }

            let links = try await projectLinkRepository.links(for: projectId)
            let confirmedLinks = links.filter { $0.isUserConfirmed }

            guard !confirmedLinks.isEmpty else {
                isGeneratingProjectInsights = false
                projectInsightGenerationMessage = "该项目暂无确认证据，无法生成洞察。"
                return
            }

            var evidence: [ProjectInsightEvidenceContext] = []
            for link in confirmedLinks {
                let evidenceItem = await buildProjectInsightEvidence(from: link.sourceId, sourceType: link.sourceType)
                if let item = evidenceItem {
                    evidence.append(item)
                }
            }

            guard !evidence.isEmpty else {
                isGeneratingProjectInsights = false
                projectInsightGenerationMessage = "项目证据还没有加载到历史中，无法生成洞察。"
                return
            }

            let acceptedInsights = try await projectInsightRepository.insights(for: projectId)
                .filter { $0.userFeedback == .accepted }

            let context = ProjectInsightsContext(
                projectId: projectId,
                projectName: project.name,
                projectGoal: project.goal,
                projectSuccessCriteria: project.successCriteria,
                confirmedEvidence: evidence,
                acceptedInsightCount: acceptedInsights.count
            )

            let result = try await service.generateProjectInsights(context: context)

            if let reason = result.insufficientEvidenceReason {
                isGeneratingProjectInsights = false
                projectInsightGenerationMessage = reason
                return
            }

            for insight in result.insights {
                guard insight.projectId == projectId,
                      !insight.sourceRefs.isEmpty,
                      Set(insight.sourceRefs).isSubset(of: Set(evidence.map(\.id)))
                else { continue }
                try await projectInsightRepository.saveInsight(insight)
            }

            await loadProjectInsights(for: projectId)

            isGeneratingProjectInsights = false
            projectInsightGenerationMessage = ""

        } catch {
            isGeneratingProjectInsights = false
            projectInsightGenerationMessage = "生成洞察失败: \(error.localizedDescription)"
        }
    }

    func loadProjectInsights(for projectId: UUID) async {
        guard let projectInsightRepository else { return }

        do {
            let insights = try await projectInsightRepository.insights(for: projectId)
            pendingProjectInsights = insights.filter { $0.userFeedback == .none }
            acceptedProjectInsights = insights.filter { $0.userFeedback == .accepted }
        } catch {
            pendingProjectInsights = []
            acceptedProjectInsights = []
        }
    }

    func submitProjectInsightFeedback(_ feedback: ProjectFeedback, for insightId: UUID) async {
        guard let projectInsightRepository else { return }

        do {
            let projectId = pendingProjectInsights.first(where: { $0.id == insightId })?.projectId
                ?? acceptedProjectInsights.first(where: { $0.id == insightId })?.projectId

            guard let projectId = projectId else { return }

            let allInsights = try await projectInsightRepository.insights(for: projectId)
            guard let insight = allInsights.first(where: { $0.id == insightId }) else { return }

            var updated = insight
            updated.userFeedback = feedback
            updated.updatedAt = Date.now

            try await projectInsightRepository.saveInsight(updated)

            await loadProjectInsights(for: projectId)

        } catch {
        }
    }

    private func buildProjectInsightEvidence(from sourceId: String, sourceType: ProjectSourceType) async -> ProjectInsightEvidenceContext? {
        switch sourceType {
        case .thinkingCard:
            guard let card = thinkingCards.first(where: { $0.id.uuidString == sourceId }) else {
                for record in historyRecords {
                    if let card = record.cards.first(where: { $0.id.uuidString == sourceId }) {
                        return .init(id: card.id.uuidString, type: "thinking_card", title: card.title, body: card.body)
                    }
                }
                return nil
            }
            return .init(id: card.id.uuidString, type: "thinking_card", title: card.title, body: card.body)

        case .quest:
            guard let quest = quests.first(where: { $0.id.uuidString == sourceId }) else {
                for record in historyRecords {
                    if let quest = record.quests.first(where: { $0.id.uuidString == sourceId }) {
                        return .init(id: quest.id.uuidString, type: "quest", title: quest.title, body: quest.completionCriteria)
                    }
                }
                return nil
            }
            return .init(id: quest.id.uuidString, type: "quest", title: quest.title, body: quest.completionCriteria)

        case .verification:
            for record in historyRecords {
                if let verification = record.verification, verification.id.uuidString == sourceId {
                    return .init(id: verification.id.uuidString, type: "verification", title: "任务验证", body: verification.calibrationNote)
                }
            }
            return nil

        case .principle:
            guard let principle = principles.first(where: { $0.id.uuidString == sourceId }) else {
                for record in historyRecords {
                    if let principle = record.principles.first(where: { $0.id.uuidString == sourceId }) {
                        return .init(id: principle.id.uuidString, type: "principle", title: principle.title, body: principle.summary)
                    }
                }
                return nil
            }
            return .init(id: principle.id.uuidString, type: "principle", title: principle.title, body: principle.summary)

        case .dailyEntry:
            if todayDraft.id.uuidString == sourceId {
                return .init(id: todayDraft.id.uuidString, type: "daily_entry", title: "当日复盘", body: todayDraft.rawText)
            }
            for record in historyRecords where record.draft.id.uuidString == sourceId {
                return .init(id: record.draft.id.uuidString, type: "daily_entry", title: "历史复盘", body: record.draft.rawText)
            }
            return nil
        }
    }

    private var projectAIService: ProjectAIService? {
        guard let apiKey = try? apiKeyStore.loadAPIKey(),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: Self.makeLLMClient(apiKeyStore: apiKeyStore, promptRunRepository: promptRunRepository)
        )
    }

    func loadPendingProjectMergeCandidates() async {
        guard let projectMergeCandidateRepository else { return }

        do {
            let candidates = try await projectMergeCandidateRepository.pendingMergeCandidates()
            pendingProjectMergeCandidates = candidates
        } catch {
            pendingProjectMergeCandidates = []
        }
    }

    func updateProjectDetails(
        projectId: UUID,
        name: String,
        goal: String,
        successCriteria: String,
        currentBottleneck: String?,
        openQuestions: [String]
    ) async {
        guard let projectRepository else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            projectSuggestionMessage = "项目名称不能为空。"
            return
        }

        do {
            guard var project = try await projectRepository.project(id: projectId) ?? projectsById[projectId] else {
                projectSuggestionMessage = "没有找到这个长期议题。"
                return
            }

            let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSuccessCriteria = successCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBottleneck = currentBottleneck?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedBottleneck = trimmedBottleneck?.isEmpty == true ? nil : trimmedBottleneck
            let normalizedQuestions = openQuestions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            recordProjectRevision(&project, field: "name", oldValue: project.name, newValue: trimmedName)
            recordProjectRevision(&project, field: "goal", oldValue: project.goal, newValue: trimmedGoal)
            recordProjectRevision(&project, field: "successCriteria", oldValue: project.successCriteria, newValue: trimmedSuccessCriteria)
            recordProjectRevision(&project, field: "currentBottleneck", oldValue: project.currentBottleneck ?? "", newValue: normalizedBottleneck ?? "")
            recordProjectRevision(&project, field: "openQuestions", oldValue: project.openQuestions.joined(separator: "\n"), newValue: normalizedQuestions.joined(separator: "\n"))

            project.name = trimmedName
            project.goal = trimmedGoal
            project.successCriteria = trimmedSuccessCriteria
            project.currentBottleneck = normalizedBottleneck
            project.openQuestions = normalizedQuestions
            project.updatedAt = .now

            try await projectRepository.saveProject(project)
            projectNames[project.id] = project.name
            projectsById[project.id] = project
            projectSuggestionMessage = "长期议题已更新。"
        } catch {
            projectSuggestionMessage = "更新长期议题失败: \(error.localizedDescription)"
        }
    }

    func archiveProject(_ projectId: UUID) async {
        await updateProjectStatus(projectId, status: .archived, message: "长期议题已归档。")
    }

    func restoreProject(_ projectId: UUID) async {
        await updateProjectStatus(projectId, status: .active, message: "长期议题已恢复为 active。")
    }

    private func updateProjectStatus(_ projectId: UUID, status: ProjectStatus, message: String) async {
        guard let projectRepository else { return }

        do {
            guard var project = try await projectRepository.project(id: projectId) ?? projectsById[projectId] else {
                projectSuggestionMessage = "没有找到这个长期议题。"
                return
            }
            recordProjectRevision(&project, field: "status", oldValue: project.status.rawValue, newValue: status.rawValue)
            project.status = status
            project.updatedAt = .now
            try await projectRepository.saveProject(project)
            projectNames[project.id] = project.name
            projectsById[project.id] = project
            projectSuggestionMessage = message
        } catch {
            projectSuggestionMessage = "更新长期议题失败: \(error.localizedDescription)"
        }
    }

    private func recordProjectRevision(_ project: inout Project, field: String, oldValue: String, newValue: String) {
        guard oldValue != newValue else { return }
        project.fieldRevisions[field] = "\(oldValue) -> \(newValue)"
    }

    func suggestProjectMerges(_ projectAIService: ProjectAIService? = nil) async {
        guard let projectMergeCandidateRepository else {
            projectMergeMessage = "本地合并候选拟暂不可用。"
            return
        }

        guard let projectRepository, let projectLinkRepository else {
            projectMergeMessage = "项目数据暂不可用。"
            return
        }

        let service = projectAIService ?? self.projectAIService
        guard let service else {
            projectMergeMessage = "AI 项目合并服务暂不可用。"
            return
        }

        isGeneratingProjectMerges = true
        projectMergeMessage = "正在检查可合并议题。"

        do {
            let activeProjects = try await projectRepository.activeProjects()
            guard activeProjects.count >= 2 else {
                isGeneratingProjectMerges = false
                projectMergeMessage = "需要至少2个活跃议题才能检查合并。"
                return
            }

            var confirmedLinks: [ProjectLink] = []
            for project in activeProjects {
                let links = try await projectLinkRepository.links(for: project.id)
                confirmedLinks.append(contentsOf: links.filter { $0.isUserConfirmed })
            }

            let context = ProjectMergeSuggestionContext(
                activeProjects: activeProjects.map { project in
                    .init(
                        id: project.id.uuidString,
                        name: project.name,
                        goal: project.goal,
                        successCriteria: project.successCriteria,
                        status: project.status.rawValue
                    )
                },
                confirmedProjectLinks: confirmedLinks.map { link in
                    .init(
                        projectId: link.projectId.uuidString,
                        sourceId: link.sourceId,
                        sourceType: link.sourceType.rawValue,
                        linkType: link.linkType.rawValue
                    )
                }
            )

            let result = try await service.suggestProjectMerges(context: context)

            for candidate in result.candidates {
                let sourceProject = activeProjects.first { $0.id == candidate.sourceProjectId }
                let targetProject = activeProjects.first { $0.id == candidate.targetProjectId }

                guard sourceProject != nil, targetProject != nil,
                      candidate.sourceProjectId != candidate.targetProjectId,
                      Set(candidate.overlappingEvidenceRefs).isSubset(of: Set(confirmedLinks.map(\.sourceId)))
                else { continue }

                try await projectMergeCandidateRepository.saveMergeCandidate(candidate)
            }

            await loadPendingProjectMergeCandidates()

            isGeneratingProjectMerges = false
            projectMergeMessage = pendingProjectMergeCandidates.isEmpty ? "未发现可合并议题。" : ""

        } catch {
            isGeneratingProjectMerges = false
            projectMergeMessage = "检查合并失败: \(error.localizedDescription)"
        }
    }

    func acceptProjectMergeCandidate(_ candidateId: UUID) async {
        guard let projectMergeCandidateRepository, let projectRepository else { return }

        do {
            guard let candidate = try await projectMergeCandidateRepository.mergeCandidate(id: candidateId) else { return }

            let sourceProject = try await projectRepository.project(id: candidate.sourceProjectId)
            let targetProject = try await projectRepository.project(id: candidate.targetProjectId)

            guard var source = sourceProject, var target = targetProject else { return }

            source.status = ProjectStatus.archived
            try await projectRepository.saveProject(source)

            let auditLine = """
            合并了: \(source.name)
            来源项目: \(candidate.sourceProjectId.uuidString)
            原因: \(candidate.reason)
            证据: \(candidate.overlappingEvidenceRefs.joined(separator: ", "))
            """

            target.mergeHistory.append(auditLine)
            try await projectRepository.saveProject(target)

            try await projectMergeCandidateRepository.updateMergeCandidateStatus(.accepted, candidateId: candidateId)

            projectsById[source.id] = source
            projectsById[target.id] = target
            projectNames[source.id] = source.name
            projectNames[target.id] = target.name

            await loadPendingProjectMergeCandidates()

        } catch {
        }
    }

    func rejectProjectMergeCandidate(_ candidateId: UUID) async {
        guard let projectMergeCandidateRepository else { return }

        do {
            try await projectMergeCandidateRepository.updateMergeCandidateStatus(.rejected, candidateId: candidateId)
            await loadPendingProjectMergeCandidates()
        } catch {
        }
    }

    func dismissProjectMergeCandidate(_ candidateId: UUID) async {
        guard let projectMergeCandidateRepository else { return }

        do {
            try await projectMergeCandidateRepository.updateMergeCandidateStatus(.dismissed, candidateId: candidateId)
            await loadPendingProjectMergeCandidates()
        } catch {
        }
    }
}
