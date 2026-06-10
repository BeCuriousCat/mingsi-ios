import Foundation
import SwiftUI

private struct HistoricalRetryCandidatePayload: Codable {
    var cards: [HistoricalRetryCardPayload]
}

struct PreparedDataExport: Identifiable, Equatable {
    let id = UUID()
    var fileURL: URL
    var summary: String
    var createdAt: Date
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

private struct PromptRollbackOverrideProvider: PromptProvider {
    let base: PromptProvider
    let overrides: [PromptID: PromptTemplate]

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        overrides[id] ?? base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        if let override = overrides[id], override.version == version {
            return override
        }
        return base.template(for: id, mode: mode, version: version)
    }
}

private struct PromptAssetPackProvider: PromptProvider {
    let base: PromptProvider
    private let currentTemplates: [PromptID: PromptTemplate]
    private let versionedTemplates: [PromptID: [String: PromptTemplate]]

    init(base: PromptProvider, packs: [PromptAssetPack]) {
        self.base = base

        var currentTemplates: [PromptID: PromptTemplate] = [:]
        var versionedTemplates: [PromptID: [String: PromptTemplate]] = [:]
        for pack in packs where pack.isEnabled {
            for template in pack.templates {
                let stampedTemplate = template.applyingPackMetadata(pack)
                if currentTemplates[stampedTemplate.id] == nil {
                    currentTemplates[stampedTemplate.id] = stampedTemplate
                }

                var versions = versionedTemplates[stampedTemplate.id] ?? [:]
                if versions[stampedTemplate.version] == nil {
                    versions[stampedTemplate.version] = stampedTemplate
                }
                versionedTemplates[stampedTemplate.id] = versions
            }
        }

        self.currentTemplates = currentTemplates
        self.versionedTemplates = versionedTemplates
    }

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        currentTemplates[id] ?? base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        versionedTemplates[id]?[version] ?? base.template(for: id, mode: mode, version: version)
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var todayDraft: DailyEntryDraft
    @Published var thinkingCards: [ThinkingCard]
    @Published var customLensItems: [LensCatalogItem] = [] {
        didSet {
            todayDraft.customLensItems = customLensItems
        }
    }
    @Published private(set) var runtimeLensItems: [LensCatalogItem] = []
    @Published private(set) var lensAssetPacks: [LensAssetPack] = []
    @Published var lensAssetPackMessage: String = ""
    @Published private(set) var promptAssetPacks: [PromptAssetPack] = []
    @Published var promptAssetPackMessage: String = ""
    @Published private(set) var assetPackRegistryCatalogEntries: [AssetPackRegistryCatalogEntry] = []
    @Published private(set) var assetPackRegistrySubscriptions: [AssetPackRegistrySubscription] = []
    @Published var assetPackInstallMessage: String = ""
    @Published var questions: [ReflectionQuestion]
    @Published var quests: [Quest]
    @Published var principles: [PrincipleAsset]
    @Published private(set) var activePrinciples: [PrincipleAsset]
    @Published private(set) var referencedPrinciples: [PrincipleAsset] = []
    @Published private(set) var principleTrainingSummaries: [PrincipleTrainingSummary] = []
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
    @Published var dataExportMessage: String = ""
    @Published var preparedDataExport: PreparedDataExport?
    @Published var isTestingGLMConnection: Bool = false
    @Published var todayLoopMessage: String = ""
    @Published var lastAIFailureMessage: String?
    @Published var canRetryCurrentAI: Bool = false
    @Published private(set) var isAIRunning: Bool = false
    @Published private(set) var aiActivityMessage: String = ""
    @Published var streamingCards: [StreamingCardDraft] = []
    @Published var streamingStatusText: String = ""
    @Published var recentPromptRuns: [PromptRun] = []
    @Published var promptRunStats: PromptRunStats?
    @Published var promptAssetRunQualitySummaries: [PromptAssetRunQualitySummary] = []
    @Published var promptAssetQualityGate: PromptAssetQualityGate = PromptAssetQualityGate.evaluate(summaries: [])
    @Published var promptRunAuditMessage: String = ""
    @Published var recentPromptEvalRuns: [PromptEvalRun] = []
    @Published private(set) var promptRollbackOverrides: [PromptID: PromptTemplate] = [:]
    @Published var promptEvalReleaseGate: PromptEvalReleaseGate = .blocked(promptProvider: LocalPromptProvider())
    @Published var promptEvalMessage: String = ""
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

    var availableLensChoices: [LensCatalogItem] {
        customLensItems + runtimeLensItems + ThinkingLens.allCases
            .sorted { $0.catalogItem.methodIndex < $1.catalogItem.methodIndex }
            .map(\.catalogItem)
    }

    var selectedLensTitle: String {
        selectedLensItem?.title ?? todayDraft.selectedLens?.title ?? "当前透镜"
    }

    var selectedLensItem: LensCatalogItem? {
        if let customId = todayDraft.selectedCustomLensId,
           let item = (customLensItems + runtimeLensItems).first(where: { $0.lensId == customId }) {
            return item
        }
        return todayDraft.selectedLens?.catalogItem
    }

    private let apiKeyStore: KeychainAPIKeyStore
    private let dailyEntryRepository: DailyEntryRepository?
    private let thinkingCardRepository: ThinkingCardRepository?
    private let questRepository: QuestRepository?
    private let principleRepository: PrincipleRepository?
    private let verificationRepository: VerificationRepository?
    private let lensSessionRepository: LensSessionRepository?
    private let lensAssetPackRepository: LensAssetPackRepository?
    private let metricSnapshotRepository: MetricSnapshotRepository?
    private let metricContributionRepository: MetricContributionRepository?
    private let projectLinkRepository: ProjectLinkRepository?
    private let projectRepository: ProjectRepository?
    private let projectCandidateRepository: ProjectCandidateRepository?
    private let projectMergeCandidateRepository: ProjectMergeCandidateRepository?
    private let projectInsightRepository: ProjectInsightRepository?
    private let promptRunRepository: PromptRunRepository?
    private let promptEvalRunRepository: PromptEvalRunRepository?
    private let promptAssetSelectionRepository: PromptAssetSelectionRepository?
    private let promptAssetPackRepository: PromptAssetPackRepository?
    private let assetPackTrustPolicyRepository: AssetPackTrustPolicyRepository?
    private let assetPackRegistrySubscriptionRepository: AssetPackRegistrySubscriptionRepository?
    private let dataExportRepository: DataExportRepository?
    private let historicalRetryCandidateRepository: HistoricalRetryCandidateRepository?
    private let principleRecallFeedbackRepository: PrincipleRecallFeedbackRepository?
    private let principlePracticeEvidenceRepository: PrinciplePracticeEvidenceRepository?
    private let reminderService: ReminderService?
    private let promptProvider: PromptProvider
    private let promptEvalSchedulePolicy: PromptEvalSchedulePolicy
    private let assetPackRegistrySyncSchedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy
    private let assetPackRegistrySyncFetcher: AssetPackInstallManifestFetching
    private var runtimePromptAssetPacks: [PromptAssetPack] = []
    private var assetPackRegistryCatalogURL: URL?
    private var assetPackRegistryCatalogEntrySourceURLs: [String: URL] = [:]
    private let persistenceUnavailableMessage: String?
    private let refreshesAIServiceFromKeychain: Bool
    private var todayAIService: TodayAIService?
    private var growthAIService: GrowthAIService?
    private var runtimePromptProvider: PromptProvider {
        PromptAssetPackProvider(base: promptProvider, packs: runtimePromptAssetPacks)
    }
    private var effectivePromptProvider: PromptProvider {
        PromptRollbackOverrideProvider(base: runtimePromptProvider, overrides: promptRollbackOverrides)
    }
    private var apiKeyStatusMessage: String = ""
    private var glmConnectionMessage: String = ""
    private let principleNeedsReviewNegativeFeedbackThreshold = 2
    private var referencedPrincipleRetrievals: [UUID: RetrievedPrinciple] = [:]
    private var scheduledReminderIDs: Set<String> = []
    private var persistenceChain: Task<Void, Never>?
    private var persistenceChainGeneration = 0
    private var pendingAIRepairPrompts: Set<PromptID> = [] {
        didSet {
            pendingAIRepairCount = pendingAIRepairPrompts.count
        }
    }
    private var activeAIRequestCount: Int = 0
    private static let exportTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
    private static let assetPackJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    #if DEBUG
    private(set) var loadsPersistedStateOnLaunch: Bool = true
    private(set) var visualQAProjectDetailDirectEntryProjectID: UUID?
    private var visualQASettingsAuditProofActive = false
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
        lensAssetPackRepository: LensAssetPackRepository? = nil,
        metricSnapshotRepository: MetricSnapshotRepository? = nil,
        metricContributionRepository: MetricContributionRepository? = nil,
        projectLinkRepository: ProjectLinkRepository? = nil,
        projectRepository: ProjectRepository? = nil,
        projectCandidateRepository: ProjectCandidateRepository? = nil,
        projectMergeCandidateRepository: ProjectMergeCandidateRepository? = nil,
        projectInsightRepository: ProjectInsightRepository? = nil,
        promptRunRepository: PromptRunRepository? = nil,
        promptEvalRunRepository: PromptEvalRunRepository? = nil,
        promptAssetSelectionRepository: PromptAssetSelectionRepository? = nil,
        promptAssetPackRepository: PromptAssetPackRepository? = nil,
        assetPackTrustPolicyRepository: AssetPackTrustPolicyRepository? = nil,
        assetPackRegistrySubscriptionRepository: AssetPackRegistrySubscriptionRepository? = nil,
        dataExportRepository: DataExportRepository? = nil,
        historicalRetryCandidateRepository: HistoricalRetryCandidateRepository? = nil,
        principleRecallFeedbackRepository: PrincipleRecallFeedbackRepository? = nil,
        principlePracticeEvidenceRepository: PrinciplePracticeEvidenceRepository? = nil,
        reminderService: ReminderService? = nil,
        promptProvider: PromptProvider = LocalPromptProvider(),
        promptEvalSchedulePolicy: PromptEvalSchedulePolicy = PromptEvalSchedulePolicy(),
        assetPackRegistrySyncSchedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy =
            AssetPackRegistrySubscriptionSyncSchedulePolicy(),
        assetPackRegistrySyncFetcher: AssetPackInstallManifestFetching =
            URLSessionAssetPackInstallManifestFetcher(),
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
        self.lensAssetPackRepository = lensAssetPackRepository
        self.metricSnapshotRepository = metricSnapshotRepository
        self.metricContributionRepository = metricContributionRepository
        self.projectLinkRepository = projectLinkRepository
        self.projectRepository = projectRepository
        self.projectCandidateRepository = projectCandidateRepository
        self.projectMergeCandidateRepository = projectMergeCandidateRepository
        self.projectInsightRepository = projectInsightRepository
        self.promptRunRepository = promptRunRepository
        self.promptEvalRunRepository = promptEvalRunRepository
        self.promptAssetSelectionRepository = promptAssetSelectionRepository
        self.promptAssetPackRepository = promptAssetPackRepository
        self.assetPackTrustPolicyRepository = assetPackTrustPolicyRepository
        self.assetPackRegistrySubscriptionRepository = assetPackRegistrySubscriptionRepository
        self.dataExportRepository = dataExportRepository
        self.historicalRetryCandidateRepository = historicalRetryCandidateRepository
        self.principleRecallFeedbackRepository = principleRecallFeedbackRepository
        self.principlePracticeEvidenceRepository = principlePracticeEvidenceRepository
        self.reminderService = reminderService
        self.promptProvider = promptProvider
        self.promptEvalSchedulePolicy = promptEvalSchedulePolicy
        self.assetPackRegistrySyncSchedulePolicy = assetPackRegistrySyncSchedulePolicy
        self.assetPackRegistrySyncFetcher = assetPackRegistrySyncFetcher
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
        self.customLensItems = self.todayDraft.customLensItems
        self.promptEvalReleaseGate = PromptEvalReleaseGate.blocked(promptProvider: effectivePromptProvider)
        refreshAPIKeyStatus()
    }

    static func live() -> AppStore {
        let apiKeyStore = KeychainAPIKeyStore()

        do {
            let database = try AppDatabase(url: AppDatabase.defaultURL())
            let promptRunRepository = SQLitePromptRunRepository(database: database)
            let promptEvalRunRepository = SQLitePromptEvalRunRepository(database: database)
            return AppStore(
                apiKeyStore: apiKeyStore,
                dailyEntryRepository: SQLiteDailyEntryRepository(database: database),
                thinkingCardRepository: SQLiteThinkingCardRepository(database: database),
                questRepository: SQLiteQuestRepository(database: database),
                principleRepository: SQLitePrincipleRepository(database: database),
                verificationRepository: SQLiteVerificationRepository(database: database),
                lensSessionRepository: SQLiteLensSessionRepository(database: database),
                lensAssetPackRepository: SQLiteLensAssetPackRepository(database: database),
                metricSnapshotRepository: SQLiteMetricSnapshotRepository(database: database),
                metricContributionRepository: SQLiteMetricContributionRepository(database: database),
                projectLinkRepository: SQLiteProjectLinkRepository(database: database),
                projectRepository: SQLiteProjectRepository(database: database),
                projectCandidateRepository: SQLiteProjectCandidateRepository(database: database),
                projectMergeCandidateRepository: SQLiteProjectMergeCandidateRepository(database: database),
                projectInsightRepository: SQLiteProjectInsightRepository(database: database),
                promptRunRepository: promptRunRepository,
                promptEvalRunRepository: promptEvalRunRepository,
                promptAssetSelectionRepository: SQLitePromptAssetSelectionRepository(database: database),
                promptAssetPackRepository: SQLitePromptAssetPackRepository(database: database),
                assetPackTrustPolicyRepository: SQLiteAssetPackTrustPolicyRepository(database: database),
                assetPackRegistrySubscriptionRepository: SQLiteAssetPackRegistrySubscriptionRepository(database: database),
                dataExportRepository: SQLiteDataExportRepository(database: database),
                historicalRetryCandidateRepository: SQLiteHistoricalRetryCandidateRepository(database: database),
                principleRecallFeedbackRepository: SQLitePrincipleRecallFeedbackRepository(database: database),
                principlePracticeEvidenceRepository: SQLitePrinciplePracticeEvidenceRepository(database: database),
                reminderService: LocalNotificationReminder()
            )
        } catch {
            return AppStore(
                apiKeyStore: apiKeyStore,
                reminderService: LocalNotificationReminder(),
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

    static func resolveVisualQATab(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppTab? {
        let raw = environment["MINGSI_VISUAL_QA_TAB"]
            ?? environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB"]
        guard let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalized.isEmpty
        else {
            return nil
        }
        return AppTab(rawValue: normalized)
    }

    func applyVisualQATabOverride(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard let visualQATab = Self.resolveVisualQATab(environment: environment) else {
            return
        }
        selectedTab = visualQATab
    }

    static func isVisualQASettingsAuditProof(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF"] != nil ||
            environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF"] != nil
    }

    func applyVisualQASettingsAuditProof(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard Self.isVisualQASettingsAuditProof(environment: environment) else { return }

        selectedTab = .settings
        apiKeyConfigured = true
        apiKeyStatusMessage = "GLM API Key 已配置。"
        glmConnectionMessage = "GLM 连接测试失败：Debug 视觉验证使用本地失败样本。"
        recentPromptRuns = [Self.makeVisualQASettingsAuditProofRun()]
        promptRunAuditMessage = ""
        visualQASettingsAuditProofActive = true
        loadsPersistedStateOnLaunch = false
        updateSettingsMessage()
    }

    private static func makeVisualQASettingsAuditProofRun() -> PromptRun {
        PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "connection-test",
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "debug-settings-audit-proof",
            sessionMode: SessionMode.standard.rawValue,
            requestSummary: "Debug Settings BYOK/PromptRun rendered proof",
            error: "Debug 视觉验证：本地连接失败样本。",
            createdAt: Date(timeIntervalSince1970: 1_804_032_000)
        )
    }

    static func shouldUseVisualQASettingsAssetPackManifestFixture(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["MINGSI_VISUAL_QA_SETTINGS_ASSET_PACK_MANIFEST"] != nil ||
            environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_SETTINGS_ASSET_PACK_MANIFEST"] != nil
    }

    static func resolveVisualQATodayInput(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let raw = environment["MINGSI_VISUAL_QA_TODAY_INPUT"]
            ?? environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT"]
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func resolveVisualQATodayMode(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SessionMode {
        let raw = environment["MINGSI_VISUAL_QA_TODAY_MODE"]
            ?? environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE"]
            ?? ""
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SessionMode(rawValue: normalized) ?? .standard
    }

    enum VisualQATodayStage: String {
        case capture
        case reviewCards = "review_cards"
        case reviewCardsConfirmed = "review_cards_confirmed"
        case selectLens = "select_lens"
        case answerQuestions = "answer_questions"
        case reviewQuests = "review_quests"
        case extractPrinciple = "extract_principle"
        case sessionComplete = "session_complete"

        var label: String {
            switch self {
            case .capture:
                return DailyLoopState.capture.title
            case .reviewCards, .reviewCardsConfirmed:
                return DailyLoopState.reviewCards.title
            case .selectLens:
                return DailyLoopState.selectLens.title
            case .answerQuestions:
                return DailyLoopState.answerQuestions.title
            case .reviewQuests:
                return DailyLoopState.reviewQuests.title
            case .extractPrinciple:
                return DailyLoopState.extractPrinciple.title
            case .sessionComplete:
                return DailyLoopState.sessionComplete.title
            }
        }
    }

    static func resolveVisualQATodayStage(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> VisualQATodayStage {
        let raw = environment["MINGSI_VISUAL_QA_TODAY_STAGE"]
            ?? environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE"]
            ?? ""
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return VisualQATodayStage(rawValue: normalized) ?? .capture
    }

    static func shouldPresentVisualQACustomLensSheet(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["MINGSI_VISUAL_QA_TODAY_CUSTOM_LENS_SHEET"] != nil ||
            environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_CUSTOM_LENS_SHEET"] != nil
    }

    func applyVisualQATodaySeed(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard let seedInput = Self.resolveVisualQATodayInput(environment: environment) else {
            return
        }

        selectedTab = Self.resolveVisualQATab(environment: environment) ?? .today
        todayDraft.rawText = seedInput
        todayDraft.sessionMode = Self.resolveVisualQATodayMode(environment: environment)
        todayDraft.hasSelectedSessionMode = true
        trimDerivedState(after: .capture)
        applyVisualQATodayStageSeed(
            Self.resolveVisualQATodayStage(environment: environment),
            input: seedInput
        )
        loadsPersistedStateOnLaunch = false
    }

    private func applyVisualQATodayStageSeed(_ stage: VisualQATodayStage, input: String) {
        switch stage {
        case .capture:
            todayDraft.state = .capture
            return

        case .reviewCards:
            seedVisualQAFallbackCards(from: input, confirmed: false)
            todayDraft.state = .reviewCards

        case .reviewCardsConfirmed:
            seedVisualQAFallbackCards(from: input, confirmed: true)
            todayDraft.state = .reviewCards

        case .selectLens:
            seedVisualQAFallbackCards(from: input, confirmed: true)
            todayDraft.state = .selectLens

        case .answerQuestions:
            seedVisualQAQuestions(from: input, answered: false)
            seedVisualQAReferencedPrinciple(promptID: .generateQuestions)
            todayDraft.state = .answerQuestions

        case .reviewQuests:
            seedVisualQAQuestions(from: input, answered: true)
            generateLocalQuests()
            seedVisualQAReferencedPrinciple(promptID: .generateQuests)
            todayDraft.state = .reviewQuests

        case .extractPrinciple:
            seedVisualQAQuestions(from: input, answered: true)
            generateLocalQuests()
            activateVisualQAMainQuest()
            generateLocalPrinciple()
            todayDraft.state = .extractPrinciple

        case .sessionComplete:
            seedVisualQAQuestions(from: input, answered: true)
            generateLocalQuests()
            activateVisualQAMainQuest()
            generateLocalPrinciple()
            todayDraft.state = .sessionComplete
            historyRecords = [currentHistoryRecord]
        }

        markVisualQATodayStageFallback(stage)
    }

    private func seedVisualQAFallbackCards(from input: String, confirmed: Bool) {
        generateLocalCards(from: input)
        guard confirmed else { return }
        thinkingCards = thinkingCards.map { card in
            var updated = card
            updated.isConfirmed = true
            updated.isExcludedFromModel = false
            return updated
        }
    }

    private func seedVisualQAQuestions(from input: String, answered: Bool) {
        seedVisualQAFallbackCards(from: input, confirmed: true)
        todayDraft.selectedLens = .firstPrinciples
        generateLocalQuestions(from: input)
        guard answered else { return }
        questions = questions.map { question in
            var updated = question
            updated.answer = "先回到最小事实：明天只验证一个会改变判断的关键假设。"
            return updated
        }
    }

    private func seedVisualQAReferencedPrinciple(promptID: PromptID) {
        let principle = PrincipleAsset(
            title: "Visual QA - 会前确认负责人",
            summary: "协作任务开始前先确认唯一负责人和验收标准。",
            triggerContext: "meeting ownership",
            actions: ["写出负责人", "写出验收标准"],
            successCriteria: "相关人知道下一步由谁推进。",
            exceptions: "低风险同步可简化",
            status: .active
        )
        referencedPrinciples = [principle]
        referencedPrincipleRetrievals = [
            principle.id: RetrievedPrinciple(
                principle: principle,
                score: 4,
                retrievalReason: "Visual QA seed matched meeting ownership with 会前确认负责人 using local keyword policy; score=4.",
                policyVersion: LocalPrincipleRetriever.policyVersion
            )
        ]
        activePrinciples = [principle]
    }

    private func activateVisualQAMainQuest() {
        quests = quests.map { quest in
            var updated = quest
            if quest.type == .main {
                updated.status = .active
            }
            return updated
        }
    }

    private func markVisualQATodayStageFallback(_ stage: VisualQATodayStage) {
        let message = "Debug 视觉验证：已使用本地 fallback 预置到\(stage.label)，不会记录为 AI 成功。"
        lastAIFailureMessage = message
        canRetryCurrentAI = false
        todayLoopMessage = message
    }

    enum VisualQAProjectDetailVariant: String, CaseIterable, Equatable {
        case nil_project
        case minimal
        case normal
        case accepted_insight
        case pending_insight
        case merge_history
        case long_timeline
        case long_name
        case sparse_next_bet
        case generating_insight
    }

    static func resolveVisualQAProjectDetailVariant(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> VisualQAProjectDetailVariant {
        let raw = environment["MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT"]
            ?? environment["SIMCTL_CHILD_MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT"]
            ?? ""
        return VisualQAProjectDetailVariant(rawValue: raw) ?? .normal
    }

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

    static func shouldUseVisualQAProjectDetailFixture(
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
        if resolveVisualQATab(environment: environment) != nil {
            return false
        }
        if resolveVisualQATodayInput(environment: environment) != nil {
            return false
        }
        if isVisualQASettingsAuditProof(environment: environment) {
            return false
        }
        return isVisualQAProjectDetailLaunch(
            arguments: arguments,
            environment: environment,
            defaults: defaults,
            markerFileExists: markerFileExists
        )
    }

    static func visualQAProjectDetail() -> AppStore {
        visualQAProjectDetail(variant: resolveVisualQAProjectDetailVariant())
    }

    static func visualQAProjectDetail(variant: VisualQAProjectDetailVariant) -> AppStore {
        switch variant {
        case .normal:
            return makeNormalVariant()
        case .nil_project:
            return makeNilProjectVariant()
        case .minimal:
            return makeMinimalVariant()
        case .accepted_insight:
            return makeAcceptedInsightVariant()
        case .pending_insight:
            return makePendingInsightVariant()
        case .merge_history:
            return makeMergeHistoryVariant()
        case .long_timeline:
            return makeLongTimelineVariant()
        case .long_name:
            return makeLongNameVariant()
        case .sparse_next_bet:
            return makeSparseNextBetVariant()
        case .generating_insight:
            return makeGeneratingInsightVariant()
        }
    }

    private static func makeBaseProject(name: String = "Visual QA - 会议机制优化") -> Project {
        Project(
            name: name,
            goal: "减少会议后的返工和模糊结论",
            successCriteria: "每次会议结束时有明确负责人、行动项和验收标准",
            currentBottleneck: "会前没有列出必须确认的问题",
            openQuestions: ["哪些决策必须会前确认？", "谁在会后发纪要？"],
            status: .active,
            mergeHistory: ["合并了: Visual QA - 接口归属确认\n来源项目: fixture\n原因: 视觉验证用例\n证据: fixture-evidence"]
        )
    }

    private static func makeConfirmedLink(projectId: UUID, sourceId: UUID) -> ProjectLink {
        ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: sourceId.uuidString,
            linkType: .evidence,
            isUserConfirmed: true
        )
    }

    private static func makeHistoryRecord(projectId: UUID, links: [ProjectLink]) -> HistoryRecord {
        let draft = DailyEntryDraft(
            rawText: "Visual QA: 会议讨论了接口归属问题",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            state: .sessionComplete
        )
        let cards = links.enumerated().compactMap { offset, link -> ThinkingCard? in
            guard link.sourceType == .thinkingCard,
                  let sourceId = UUID(uuidString: link.sourceId) else { return nil }
            return ThinkingCard(
                id: sourceId,
                type: .problem,
                title: "Visual QA - 会议目标不清 \(offset + 1)",
                body: "会议讨论了多个议题，但没有逐项确认负责人。",
                isConfirmed: true
            )
        }
        let quests = links.enumerated().compactMap { offset, link -> Quest? in
            guard link.sourceType == .quest,
                  let sourceId = UUID(uuidString: link.sourceId) else { return nil }
            return Quest(
                id: sourceId,
                type: .main,
                title: "Visual QA - 下一步验证 \(offset + 1)",
                whyItMatters: "验证下一步押注是否降低返工",
                completionCriteria: "完成一次带负责人和验收标准的会议确认",
                expectedResistance: "跨角色沟通",
                reflectionQuestion: "哪一个确认动作减少了返工？",
                status: .active
            )
        }
        return HistoryRecord(
            draft: draft,
            cards: cards,
            quests: quests,
            principles: [],
            verification: nil,
            lensSession: nil,
            projectLinks: links,
            growthContributions: []
        )
    }

    private static func makeAcceptedInsight(projectId: UUID, sourceId: UUID) -> ProjectInsight {
        ProjectInsight(
            projectId: projectId,
            insightType: .progress,
            title: "Visual QA - 进展信号",
            summary: "从依赖会议讨论到主动会前准备，接口归属逐步明确。",
            sourceRefs: [sourceId.uuidString],
            userFeedback: .accepted
        )
    }

    private static func makePendingInsight(projectId: UUID, sourceId: UUID) -> ProjectInsight {
        ProjectInsight(
            projectId: projectId,
            insightType: .thinkingChange,
            title: "Visual QA - 思考转变",
            summary: "从被动等待会议结论到会前列出必须确认的问题。",
            beforeText: "之前依赖会议讨论决定归属",
            afterText: "现在会前列出必须确认的问题",
            sourceRefs: [sourceId.uuidString],
            userFeedback: .none
        )
    }

    private static func makeNormalVariant() -> AppStore {
        let project = makeBaseProject()
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

        let acceptedInsight = makeAcceptedInsight(projectId: project.id, sourceId: cardID)
        let pendingInsight = makePendingInsight(projectId: project.id, sourceId: questID)

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
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeNilProjectVariant() -> AppStore {
        let projectId = UUID()
        let sourceId = UUID()
        let link = makeConfirmedLink(projectId: projectId, sourceId: sourceId)
        let record = makeHistoryRecord(projectId: projectId, links: [link])

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        // No projectsById or projectNames — board item exists via link but no persisted Project
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = projectId
        return store
    }

    private static func makeMinimalVariant() -> AppStore {
        let project = Project(
            name: "Visual QA - 最小项目",
            goal: "验证最小数据",
            successCriteria: "目标可展示"
        )
        let sourceId = UUID()
        let link = makeConfirmedLink(projectId: project.id, sourceId: sourceId)
        let record = makeHistoryRecord(projectId: project.id, links: [link])

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeAcceptedInsightVariant() -> AppStore {
        let project = makeBaseProject()
        let sourceId1 = UUID()
        let sourceId2 = UUID()
        let link1 = makeConfirmedLink(projectId: project.id, sourceId: sourceId1)
        let link2 = makeConfirmedLink(projectId: project.id, sourceId: sourceId2)
        let record = makeHistoryRecord(projectId: project.id, links: [link1, link2])

        let insight1 = makeAcceptedInsight(projectId: project.id, sourceId: sourceId1)
        let insight2 = ProjectInsight(
            projectId: project.id,
            insightType: .progress,
            title: "Visual QA - 流程改善",
            summary: "会议纪要模板落地后，确认项漏掉率明显下降。",
            sourceRefs: [sourceId2.uuidString],
            userFeedback: .accepted
        )

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.acceptedProjectInsights = [insight1, insight2]
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makePendingInsightVariant() -> AppStore {
        let project = makeBaseProject()
        let sourceId1 = UUID()
        let sourceId2 = UUID()
        let link1 = makeConfirmedLink(projectId: project.id, sourceId: sourceId1)
        let link2 = makeConfirmedLink(projectId: project.id, sourceId: sourceId2)
        let record = makeHistoryRecord(projectId: project.id, links: [link1, link2])

        let pending1 = makePendingInsight(projectId: project.id, sourceId: sourceId1)
        let pending2 = ProjectInsight(
            projectId: project.id,
            insightType: .blockerChange,
            title: "Visual QA - 待审瓶颈",
            summary: "跨团队依赖确认仍在等待反馈。",
            sourceRefs: [sourceId2.uuidString],
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
        store.pendingProjectInsights = [pending1, pending2]
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeMergeHistoryVariant() -> AppStore {
        let project = Project(
            name: "Visual QA - 合并历史",
            goal: "验证合并展示",
            successCriteria: "合并历史完整显示",
            mergeHistory: [
                "合并了: Visual QA - 接口归属确认\n来源项目: fixture-a\n原因: 证据重叠\n证据: ev-001",
                "合并了: Visual QA - 会议优化\n来源项目: fixture-b\n原因: 目标对齐\n证据: ev-002",
                "合并了: Visual QA - 返工追踪\n来源项目: fixture-c\n原因: 主题一致\n证据: ev-003"
            ]
        )
        let sourceId = UUID()
        let link = makeConfirmedLink(projectId: project.id, sourceId: sourceId)
        let record = makeHistoryRecord(projectId: project.id, links: [link])

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeLongTimelineVariant() -> AppStore {
        let project = makeBaseProject()
        var records: [HistoryRecord] = []
        for i in 0..<10 {
            let sourceId = UUID()
            let link = makeConfirmedLink(projectId: project.id, sourceId: sourceId)
            let record = HistoryRecord(
                draft: DailyEntryDraft(
                    rawText: "Visual QA timeline entry \(i)",
                    sessionMode: .standard,
                    hasSelectedSessionMode: true,
                    state: .sessionComplete
                ),
                cards: [ThinkingCard(
                    id: sourceId,
                    type: .problem,
                    title: "Timeline entry \(i)",
                    body: "Evidence for timeline entry \(i)",
                    isConfirmed: true
                )],
                quests: [],
                principles: [],
                verification: nil,
                lensSession: nil,
                projectLinks: [link],
                growthContributions: []
            )
            records.append(record)
        }

        let store = AppStore(
            historyRecords: records,
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeLongNameVariant() -> AppStore {
        let longName = "Visual QA - 这是一个非常长的项目名称用于测试文本换行效果和截断展示的视觉验证场景"
        let project = Project(
            name: longName,
            goal: "验证长名称显示",
            successCriteria: "名称完整显示或正确截断"
        )
        let sourceId = UUID()
        let link = makeConfirmedLink(projectId: project.id, sourceId: sourceId)
        let record = makeHistoryRecord(projectId: project.id, links: [link])

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = longName
        store.projectsById[project.id] = project
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeSparseNextBetVariant() -> AppStore {
        let project = Project(
            name: "Visual QA - 稀疏下一步",
            goal: "",
            successCriteria: ""
        )
        let sourceId = UUID()
        let link = ProjectLink(
            projectId: project.id,
            sourceType: .quest,
            sourceId: sourceId.uuidString,
            linkType: .task,
            isUserConfirmed: true
        )
        let record = makeHistoryRecord(projectId: project.id, links: [link])

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    private static func makeGeneratingInsightVariant() -> AppStore {
        let project = makeBaseProject()
        let sourceId = UUID()
        let link = makeConfirmedLink(projectId: project.id, sourceId: sourceId)
        let record = makeHistoryRecord(projectId: project.id, links: [link])

        let store = AppStore(
            historyRecords: [record],
            growthSnapshot: makeEmptyGrowth(),
            refreshesAIServiceFromKeychain: false
        )
        store.selectedTab = .projects
        store.projectNames[project.id] = project.name
        store.projectsById[project.id] = project
        store.isGeneratingProjectInsights = true
        store.loadsPersistedStateOnLaunch = false
        store.visualQAProjectDetailDirectEntryProjectID = project.id
        return store
    }

    func applyVisualQAProjectDetailFixture() {
        applyVisualQAProjectDetailFixture(variant: AppStore.resolveVisualQAProjectDetailVariant())
    }

    func applyVisualQAProjectDetailFixture(variant: VisualQAProjectDetailVariant) {
        let fixture = AppStore.visualQAProjectDetail(variant: variant)
        selectedTab = fixture.selectedTab
        todayDraft = fixture.todayDraft
        thinkingCards = fixture.thinkingCards
        questions = fixture.questions
        quests = fixture.quests
        principles = fixture.principles
        activePrinciples = fixture.activePrinciples
        referencedPrinciples = fixture.referencedPrinciples
        referencedPrincipleRetrievals = [:]
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
        visualQAProjectDetailDirectEntryProjectID = fixture.visualQAProjectDetailDirectEntryProjectID
        isGeneratingProjectInsights = fixture.isGeneratingProjectInsights
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

    var todayPrimaryActionBlocker: String? {
        if isAIRunning {
            return "AI 正在运行，完成后会继续。"
        }

        switch todayDraft.state {
        case .verifyYesterday, .organizing, .selectMode, .extractPrinciple, .sessionComplete:
            return nil
        case .capture:
            let trimmedInput = todayDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedInput.isEmpty {
                return "先写下一段今天的事实、困惑或行动。"
            }
            if !todayDraft.hasSelectedSessionMode {
                return "先选择 Quick、Standard 或 Deep 训练深度。"
            }
            return nil
        case .reviewCards:
            if thinkingCards.contains(where: { $0.isConfirmed }) {
                return nil
            }
            return "确认至少一张卡片后再继续。"
        case .selectLens:
            if todayDraft.selectedLens != nil || todayDraft.selectedCustomLensId != nil {
                return nil
            }
            return "先选择一个思考透镜。"
        case .answerQuestions:
            if hasAnsweredReflectionQuestion {
                return nil
            }
            return "至少回答一个问题后再生成任务。"
        case .reviewQuests:
            guard let mainQuest else {
                return "先保留一个主线任务。"
            }
            if mainQuest.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "给主线任务补上可验证的完成标准。"
            }
            return nil
        }
    }

    var canCreateProjectFromCurrentFocus: Bool {
        guard let mainQuest,
              projectRepository != nil,
              projectLinkRepository != nil
        else { return false }
        return !hasProjectLink(forSourceId: mainQuest.id.uuidString)
    }

    func loadPersistedState() async {
        await loadRuntimePromptAssetPacks()
        await loadPromptAssetSelections()
        await loadRuntimeLensPacks()
        await runScheduledPromptEvalIfNeeded()
        await runScheduledAssetPackRegistrySubscriptionSyncIfNeeded()

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
                clearReferencedPrinciples()
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
            customLensItems = draft.customLensItems
            if draft.selectedCustomLensId != nil, !draft.customLensQuestions.isEmpty {
                questions = draft.customLensQuestions
            }
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
            clearReferencedPrinciples()
            if todayDraft.selectedCustomLensId == nil,
               let session = try await lensSessionRepository?.lensSession(for: draft.id) {
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

    private func runScheduledAssetPackRegistrySubscriptionSyncIfNeeded(now: Date = .now) async {
        guard assetPackRegistrySubscriptionRepository != nil else { return }

        do {
            _ = try await syncDueAssetPackRegistrySubscriptions(
                now: now,
                schedulePolicy: assetPackRegistrySyncSchedulePolicy,
                fetcher: assetPackRegistrySyncFetcher
            )
        } catch {
            assetPackInstallMessage = "自动同步资产包目录订阅失败：\(error.localizedDescription)"
        }
    }

    private func runScheduledPromptEvalIfNeeded(now: Date = .now) async {
        guard let promptEvalRunRepository else { return }

        do {
            recentPromptEvalRuns = try await promptEvalRunRepository.recentEvalRuns(limit: 100)
            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: recentPromptEvalRuns,
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )

            let decision = promptEvalSchedulePolicy.decision(
                runs: recentPromptEvalRuns,
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion,
                now: now
            )
            guard decision.shouldRun else {
                promptEvalMessage = recentPromptEvalRuns.isEmpty ? "还没有固定评测记录。" : promptEvalGateSummaryMessage
                return
            }

            await runPromptEvalSuite()
            promptEvalMessage = "自动固定评测：\(promptEvalMessage)"
        } catch {
            recentPromptEvalRuns = []
            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: [],
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )
            promptEvalMessage = "读取 Prompt 固定评测失败。"
        }
    }

    private func loadPromptAssetSelections() async {
        guard let promptAssetSelectionRepository else { return }

        do {
            let selections = try await promptAssetSelectionRepository.allSelections()
            var restoredOverrides: [PromptID: PromptTemplate] = [:]
            for selection in selections {
                guard let template = runtimePromptProvider.template(
                    for: selection.promptId,
                    mode: .standard,
                    version: selection.selectedVersion
                ) else {
                    continue
                }
                restoredOverrides[selection.promptId] = template
            }
            promptRollbackOverrides = restoredOverrides
            refreshAIServiceFromKeychainIfNeeded()
        } catch {
            promptEvalMessage = "读取 Prompt 资产选择失败，已使用当前本地版本。"
        }
    }

    private func loadRuntimePromptAssetPacks() async {
        guard let promptAssetPackRepository else {
            promptAssetPacks = []
            runtimePromptAssetPacks = []
            return
        }

        do {
            let verifier = await assetPackSignatureVerifierFromPersistedPolicies()
            let packs = try await promptAssetPackRepository.allPacks()
            promptAssetPacks = Self.sortedPromptAssetPacks(packs)
            if let repository = promptAssetPackRepository as? SQLitePromptAssetPackRepository {
                runtimePromptAssetPacks = try await repository.enabledPacks(signatureVerifier: verifier)
            } else {
                runtimePromptAssetPacks = try await promptAssetPackRepository.enabledPacks()
            }
        } catch {
            promptAssetPacks = []
            runtimePromptAssetPacks = []
        }
        refreshAIServiceFromKeychainIfNeeded()
    }

    private func loadRuntimeLensPacks() async {
        guard let lensAssetPackRepository else {
            lensAssetPacks = []
            runtimeLensItems = []
            return
        }

        do {
            let verifier = await assetPackSignatureVerifierFromPersistedPolicies()
            let packs = try await lensAssetPackRepository.allPacks()
            lensAssetPacks = Self.sortedLensAssetPacks(packs)
            let runtimePacks: [LensAssetPack]
            if let repository = lensAssetPackRepository as? SQLiteLensAssetPackRepository {
                runtimePacks = try await repository.enabledPacks(signatureVerifier: verifier)
            } else {
                runtimePacks = try await lensAssetPackRepository.enabledPacks()
            }
            runtimeLensItems = Self.sortedRuntimeLensItems(from: runtimePacks)
        } catch {
            lensAssetPacks = []
            runtimeLensItems = []
        }
    }

    private func assetPackSignatureVerifierFromPersistedPolicies() async -> AssetPackSignatureVerifier {
        guard let assetPackTrustPolicyRepository else { return .default }

        do {
            let records = try await assetPackTrustPolicyRepository.allDocuments()
            return AssetPackSignatureVerifier.combining(
                records
                    .map(\.document)
                    .filter { !$0.isExpired() && $0.hasValidTrustSignature }
                    .map(\.signatureVerifier) + [.default]
            )
        } catch {
            return .default
        }
    }

    func loadLensAssetPacks() async {
        guard let lensAssetPackRepository else {
            lensAssetPacks = []
            runtimeLensItems = []
            lensAssetPackMessage = "透镜包管理不可用：本地数据库未启用。"
            return
        }

        do {
            let packs = try await lensAssetPackRepository.allPacks()
            applyLensAssetPacks(packs)
            lensAssetPackMessage = "已加载 \(lensAssetPacks.count) 个透镜包，启用 \(lensAssetPacks.filter(\.isEnabled).count) 个。"
        } catch {
            lensAssetPacks = []
            runtimeLensItems = []
            lensAssetPackMessage = "读取透镜包失败：\(error.localizedDescription)"
        }
    }

    func loadPromptAssetPacks() async {
        guard let promptAssetPackRepository else {
            promptAssetPacks = []
            runtimePromptAssetPacks = []
            refreshPromptRuntimeState()
            promptAssetPackMessage = "Prompt 包管理不可用：本地数据库未启用。"
            return
        }

        do {
            let packs = try await promptAssetPackRepository.allPacks()
            applyPromptAssetPacks(packs)
            promptAssetPackMessage = "已加载 \(promptAssetPacks.count) 个 Prompt 包，启用 \(promptAssetPacks.filter(\.isEnabled).count) 个。"
        } catch {
            promptAssetPacks = []
            runtimePromptAssetPacks = []
            refreshPromptRuntimeState()
            promptAssetPackMessage = "读取 Prompt 包失败：\(error.localizedDescription)"
        }
    }

    func loadAssetPackRegistrySubscriptions() async {
        guard let assetPackRegistrySubscriptionRepository else {
            assetPackRegistrySubscriptions = []
            assetPackInstallMessage = "资产包目录订阅不可用：本地数据库未启用。"
            return
        }

        do {
            assetPackRegistrySubscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
            let enabledCount = assetPackRegistrySubscriptions.filter(\.isEnabled).count
            assetPackInstallMessage = "已加载 \(assetPackRegistrySubscriptions.count) 个资产包目录订阅，启用 \(enabledCount) 个。"
        } catch {
            assetPackRegistrySubscriptions = []
            assetPackInstallMessage = "读取资产包目录订阅失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveAssetPackRegistrySubscription(
        displayName: String,
        catalogURL: URL
    ) async throws -> AssetPackRegistrySubscription {
        guard let assetPackRegistrySubscriptionRepository else {
            assetPackInstallMessage = "资产包目录订阅不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            assetPackInstallMessage = "保存资产包目录订阅失败：名称不能为空。"
            throw PersistenceError.validationFailed("Asset pack registry subscription name is required")
        }
        guard catalogURL.scheme != nil else {
            assetPackInstallMessage = "保存资产包目录订阅失败：URL 必须是绝对地址。"
            throw PersistenceError.validationFailed("Asset pack registry subscription URL must be absolute")
        }

        let existingSubscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
        let existing = existingSubscriptions.first { $0.catalogURL == catalogURL }
        let now = Date()
        let subscription = AssetPackRegistrySubscription(
            id: existing?.id ?? Self.assetPackRegistrySubscriptionId(for: catalogURL),
            schemaVersion: existing?.schemaVersion ?? 1,
            displayName: trimmedName,
            catalogURL: catalogURL,
            syncPolicyVersion: existing?.syncPolicyVersion ?? AssetPackRegistrySubscription.currentSyncPolicyVersion,
            isEnabled: existing?.isEnabled ?? true,
            lastSyncedAt: existing?.lastSyncedAt,
            lastSyncStatus: existing?.lastSyncStatus ?? .neverSynced,
            lastSyncMessage: existing?.lastSyncMessage ?? "",
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        try await assetPackRegistrySubscriptionRepository.saveSubscription(subscription)
        assetPackRegistrySubscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
        assetPackInstallMessage = "已保存资产包目录订阅：\(trimmedName)。"
        return subscription
    }

    func setAssetPackRegistrySubscription(_ subscriptionId: String, isEnabled: Bool) async {
        guard let assetPackRegistrySubscriptionRepository else {
            assetPackRegistrySubscriptions = []
            assetPackInstallMessage = "资产包目录订阅不可用：本地数据库未启用。"
            return
        }

        do {
            let subscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
            guard var subscription = subscriptions.first(where: { $0.id == subscriptionId }) else {
                assetPackInstallMessage = "未找到资产包目录订阅：\(subscriptionId)。"
                return
            }

            subscription.isEnabled = isEnabled
            subscription.updatedAt = .now
            try await assetPackRegistrySubscriptionRepository.saveSubscription(subscription)
            assetPackRegistrySubscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
            assetPackInstallMessage = "\(isEnabled ? "已启用" : "已停用")资产包目录订阅：\(subscription.displayName)。"
        } catch {
            assetPackInstallMessage = "更新资产包目录订阅失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func importAssetPackInstallManifest(from data: Data) async throws -> AssetPackInstallValidationReport {
        guard promptAssetPackRepository != nil, lensAssetPackRepository != nil else {
            assetPackInstallMessage = "资产包安装不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        do {
            let manifest = try JSONDecoder().decode(AssetPackInstallManifest.self, from: data)
            let report = try await installAssetPackManifest(manifest)
            assetPackInstallMessage = Self.assetPackInstallSummary(report)
            return report
        } catch {
            assetPackInstallMessage = "安装资产包清单失败：\(error.localizedDescription)"
            throw error
        }
    }

    @discardableResult
    func fetchAndInstallAssetPackInstallManifest(
        from url: URL,
        fallbackTrustPolicyURL: URL? = nil,
        requiredVerificationPolicyVersion: String? = nil,
        fetcher: AssetPackInstallManifestFetching = URLSessionAssetPackInstallManifestFetcher()
    ) async throws -> AssetPackInstallValidationReport {
        let data: Data
        do {
            data = try await fetcher.fetchInstallManifestData(from: url)
        } catch {
            assetPackInstallMessage = "获取远程资产包清单失败：\(error.localizedDescription)"
            throw error
        }

        do {
            let manifest = try Self.assetPackJSONDecoder.decode(AssetPackInstallManifest.self, from: data)
            let signatureVerifier: AssetPackSignatureVerifier?
            var publisherProfileSummary: String?
            if let trustPolicyURL = manifest.trustPolicyURL ?? fallbackTrustPolicyURL {
                let trustPolicyData: Data
                do {
                    trustPolicyData = try await fetcher.fetchTrustPolicyData(from: trustPolicyURL)
                } catch {
                    assetPackInstallMessage = "获取远程资产包信任策略失败：\(error.localizedDescription)"
                    throw error
                }
                let trustPolicyDocument = try Self.assetPackJSONDecoder.decode(AssetPackTrustPolicyDocument.self, from: trustPolicyData)
                let persistedVerifier = await assetPackSignatureVerifierFromPersistedPolicies()
                if trustPolicyDocument.hasValidTrustSignature {
                    try await assetPackTrustPolicyRepository?.saveDocument(
                        trustPolicyDocument,
                        sourceURL: trustPolicyURL
                    )
                    publisherProfileSummary = Self.assetPackTrustPolicyPublisherSummary(trustPolicyDocument)
                    signatureVerifier = AssetPackSignatureVerifier.combining([
                        trustPolicyDocument.signatureVerifier,
                        persistedVerifier
                    ])
                } else {
                    signatureVerifier = persistedVerifier
                }
            } else {
                signatureVerifier = nil
            }

            let report = try await installAssetPackManifest(
                manifest,
                signatureVerifier: signatureVerifier,
                requiredVerificationPolicyVersion: requiredVerificationPolicyVersion
            )
            assetPackInstallMessage = "已从远程清单安装：\(Self.assetPackInstallSummary(report))\(publisherProfileSummary ?? "")"
            return report
        } catch {
            if assetPackInstallMessage.isEmpty || assetPackInstallMessage.hasPrefix("已") {
                assetPackInstallMessage = "安装资产包清单失败：\(error.localizedDescription)"
            }
            throw error
        }
    }

    @discardableResult
    func fetchAssetPackRegistryCatalog(
        from url: URL,
        fetcher: AssetPackInstallManifestFetching = URLSessionAssetPackInstallManifestFetcher()
    ) async throws -> AssetPackRegistryCatalog {
        let data: Data
        do {
            data = try await fetcher.fetchRegistryCatalogData(from: url)
        } catch {
            assetPackInstallMessage = "获取远程资产包目录失败：\(error.localizedDescription)"
            throw error
        }

        do {
            let catalog = try Self.assetPackJSONDecoder.decode(AssetPackRegistryCatalog.self, from: data)
            assetPackRegistryCatalogURL = url
            assetPackRegistryCatalogEntries = catalog.entries
            assetPackRegistryCatalogEntrySourceURLs = catalog.entries.reduce(into: [String: URL]()) { result, entry in
                result[entry.id] = url
            }
            assetPackInstallMessage = "已获取 \(catalog.entries.count) 个远程资产包条目。"
            return catalog
        } catch {
            assetPackRegistryCatalogURL = nil
            assetPackRegistryCatalogEntries = []
            assetPackRegistryCatalogEntrySourceURLs = [:]
            assetPackInstallMessage = "解析远程资产包目录失败：\(error.localizedDescription)"
            throw error
        }
    }

    @discardableResult
    func syncAssetPackRegistrySubscriptions(
        fetcher: AssetPackInstallManifestFetching = URLSessionAssetPackInstallManifestFetcher()
    ) async throws -> [AssetPackRegistryCatalogEntry] {
        guard let assetPackRegistrySubscriptionRepository else {
            assetPackInstallMessage = "资产包目录同步不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        let subscriptions = try await assetPackRegistrySubscriptionRepository.enabledSubscriptions()
        assetPackRegistrySubscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
        guard !subscriptions.isEmpty else {
            assetPackRegistryCatalogEntries = []
            assetPackRegistryCatalogEntrySourceURLs = [:]
            assetPackInstallMessage = "没有已启用的资产包目录订阅。"
            return []
        }

        return try await syncAssetPackRegistrySubscriptions(
            subscriptions,
            repository: assetPackRegistrySubscriptionRepository,
            fetcher: fetcher,
            syncedAt: .now,
            messagePrefix: "已同步"
        )
    }

    @discardableResult
    func syncDueAssetPackRegistrySubscriptions(
        now: Date = .now,
        schedulePolicy: AssetPackRegistrySubscriptionSyncSchedulePolicy = AssetPackRegistrySubscriptionSyncSchedulePolicy(),
        fetcher: AssetPackInstallManifestFetching = URLSessionAssetPackInstallManifestFetcher()
    ) async throws -> [AssetPackRegistryCatalogEntry] {
        guard let assetPackRegistrySubscriptionRepository else {
            assetPackInstallMessage = "资产包目录自动同步不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        let subscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
        let dueSubscriptions = schedulePolicy.dueSubscriptions(subscriptions, now: now)
        assetPackRegistrySubscriptions = subscriptions
        guard !dueSubscriptions.isEmpty else {
            assetPackRegistryCatalogEntries = []
            assetPackRegistryCatalogEntrySourceURLs = [:]
            assetPackInstallMessage = "资产包目录订阅未到自动同步时间。"
            return []
        }

        return try await syncAssetPackRegistrySubscriptions(
            dueSubscriptions,
            repository: assetPackRegistrySubscriptionRepository,
            fetcher: fetcher,
            syncedAt: now,
            messagePrefix: "自动同步"
        )
    }

    private func syncAssetPackRegistrySubscriptions(
        _ subscriptions: [AssetPackRegistrySubscription],
        repository assetPackRegistrySubscriptionRepository: AssetPackRegistrySubscriptionRepository,
        fetcher: AssetPackInstallManifestFetching,
        syncedAt: Date,
        messagePrefix: String
    ) async throws -> [AssetPackRegistryCatalogEntry] {
        var entries: [AssetPackRegistryCatalogEntry] = []
        var sourceURLs: [String: URL] = [:]
        var failedCount = 0

        for subscription in subscriptions {
            do {
                let data = try await fetcher.fetchRegistryCatalogData(from: subscription.catalogURL)
                let catalog = try Self.assetPackJSONDecoder.decode(AssetPackRegistryCatalog.self, from: data)
                entries.append(contentsOf: catalog.entries)
                for entry in catalog.entries {
                    sourceURLs[entry.id] = subscription.catalogURL
                }
                try await assetPackRegistrySubscriptionRepository.recordSyncResult(
                    subscriptionId: subscription.id,
                    status: .succeeded,
                    message: "Fetched \(catalog.entries.count) entries.",
                    syncedAt: syncedAt
                )
            } catch {
                failedCount += 1
                try await assetPackRegistrySubscriptionRepository.recordSyncResult(
                    subscriptionId: subscription.id,
                    status: .failed,
                    message: error.localizedDescription,
                    syncedAt: syncedAt
                )
            }
        }

        assetPackRegistryCatalogURL = subscriptions.first?.catalogURL
        assetPackRegistryCatalogEntries = entries
        assetPackRegistryCatalogEntrySourceURLs = sourceURLs
        assetPackRegistrySubscriptions = try await assetPackRegistrySubscriptionRepository.allSubscriptions()
        assetPackInstallMessage = failedCount == 0
            ? "\(messagePrefix) \(subscriptions.count) 个资产包目录订阅，获取 \(entries.count) 个条目。"
            : "\(messagePrefix) \(subscriptions.count) 个资产包目录订阅，获取 \(entries.count) 个条目；\(failedCount) 个失败。"
        return entries
    }

    @discardableResult
    func installAssetPackRegistryCatalogEntry(
        entryId: String,
        fetcher: AssetPackInstallManifestFetching = URLSessionAssetPackInstallManifestFetcher()
    ) async throws -> AssetPackInstallValidationReport {
        guard let entry = assetPackRegistryCatalogEntries.first(where: { $0.id == entryId }) else {
            assetPackInstallMessage = "未找到远程资产包条目：\(entryId)。"
            throw PersistenceError.validationFailed("Asset pack registry entry not found: \(entryId)")
        }

        let sourceURL = assetPackRegistryCatalogEntrySourceURLs[entry.id] ?? assetPackRegistryCatalogURL
        let manifestURL = sourceURL.map { entry.sourceURL(baseURL: $0) } ?? entry.manifestURL
        let fallbackTrustPolicyURL = sourceURL.flatMap { entry.trustPolicySourceURL(baseURL: $0) }
            ?? entry.trustPolicyURL
        let report = try await fetchAndInstallAssetPackInstallManifest(
            from: manifestURL,
            fallbackTrustPolicyURL: fallbackTrustPolicyURL,
            requiredVerificationPolicyVersion: entry.requiredVerificationPolicyVersion,
            fetcher: fetcher
        )
        assetPackInstallMessage = "已从 \(entry.displayName) 安装：\(Self.assetPackInstallSummary(report))"
        return report
    }

    private func installAssetPackManifest(
        _ manifest: AssetPackInstallManifest,
        signatureVerifier: AssetPackSignatureVerifier? = nil,
        requiredVerificationPolicyVersion: String? = nil
    ) async throws -> AssetPackInstallValidationReport {
        guard let promptAssetPackRepository, let lensAssetPackRepository else {
            assetPackInstallMessage = "资产包安装不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        let validator = AssetPackInstallManifestValidator(
            signatureVerifier: signatureVerifier ?? .default,
            requiredVerificationPolicyVersion: requiredVerificationPolicyVersion
        )
        let report = try await AssetPackInstallManifestInstaller(
            promptAssetPackRepository: promptAssetPackRepository,
            lensAssetPackRepository: lensAssetPackRepository,
            validator: validator,
            signatureVerifier: signatureVerifier
        ).install(manifest)

        applyPromptAssetPacks(try await promptAssetPackRepository.allPacks())
        applyLensAssetPacks(try await lensAssetPackRepository.allPacks())
        promptAssetPackMessage = "资产包清单安装后已刷新 Prompt 包。"
        lensAssetPackMessage = "资产包清单安装后已刷新透镜包。"
        return report
    }

    func setPromptAssetPack(_ packId: String, isEnabled: Bool) async {
        guard let promptAssetPackRepository else {
            promptAssetPackMessage = "Prompt 包管理不可用：本地数据库未启用。"
            return
        }

        do {
            let packs = promptAssetPacks.isEmpty ? try await promptAssetPackRepository.allPacks() : promptAssetPacks
            guard let pack = packs.first(where: { $0.id == packId }) else {
                promptAssetPackMessage = "未找到 Prompt 包 \(packId)。"
                return
            }

            let updatedPack = PromptAssetPack(
                id: pack.id,
                version: pack.version,
                displayName: pack.displayName,
                sourceKind: pack.sourceKind,
                isEnabled: isEnabled,
                templates: pack.templates,
                trustMetadata: pack.trustMetadata
            )
            try await promptAssetPackRepository.savePack(updatedPack)

            let reloadedPacks = try await promptAssetPackRepository.allPacks()
            applyPromptAssetPacks(reloadedPacks)
            promptAssetPackMessage = isEnabled ? "已启用 \(pack.displayName)。" : "已停用 \(pack.displayName)。"
        } catch {
            promptAssetPackMessage = "更新 Prompt 包失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func importPromptAssetPack(from data: Data) async throws -> PromptAssetPack {
        guard let promptAssetPackRepository else {
            promptAssetPackMessage = "Prompt 包管理不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        do {
            let decodedPack = try JSONDecoder().decode(PromptAssetPack.self, from: data)
            try validatePromptAssetPackForImport(decodedPack)
            try await promptAssetPackRepository.savePack(decodedPack)
            let packs = try await promptAssetPackRepository.allPacks()
            applyPromptAssetPacks(packs)
            promptAssetPackMessage = "已导入 \(decodedPack.displayName)，包含 \(decodedPack.templates.count) 个 Prompt 模板。"
            return decodedPack
        } catch {
            promptAssetPackMessage = "导入 Prompt 包失败：\(error.localizedDescription)"
            throw error
        }
    }

    func setLensAssetPack(_ packId: String, isEnabled: Bool) async {
        guard let lensAssetPackRepository else {
            lensAssetPackMessage = "透镜包管理不可用：本地数据库未启用。"
            return
        }

        do {
            let packs = lensAssetPacks.isEmpty ? try await lensAssetPackRepository.allPacks() : lensAssetPacks
            guard let pack = packs.first(where: { $0.id == packId }) else {
                lensAssetPackMessage = "未找到透镜包 \(packId)。"
                return
            }

            let updatedPack = LensAssetPack(
                id: pack.id,
                version: pack.version,
                displayName: pack.displayName,
                sourceKind: pack.sourceKind,
                isEnabled: isEnabled,
                items: pack.items,
                trustMetadata: pack.trustMetadata
            )
            try await lensAssetPackRepository.savePack(updatedPack)

            if !isEnabled {
                clearRuntimeLensSelectionIfNeeded(from: pack)
            }

            let reloadedPacks = try await lensAssetPackRepository.allPacks()
            applyLensAssetPacks(reloadedPacks)
            lensAssetPackMessage = isEnabled ? "已启用 \(pack.displayName)。" : "已停用 \(pack.displayName)。"
        } catch {
            lensAssetPackMessage = "更新透镜包失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func importLensAssetPack(from data: Data) async throws -> LensAssetPack {
        guard let lensAssetPackRepository else {
            lensAssetPackMessage = "透镜包管理不可用：本地数据库未启用。"
            throw PersistenceError.unimplemented
        }

        do {
            let decodedPack = try JSONDecoder().decode(LensAssetPack.self, from: data)
            try validateLensAssetPackForImport(decodedPack)
            try await lensAssetPackRepository.savePack(decodedPack)
            let packs = try await lensAssetPackRepository.allPacks()
            applyLensAssetPacks(packs)
            lensAssetPackMessage = "已导入 \(decodedPack.displayName)，包含 \(decodedPack.items.count) 个透镜。"
            return decodedPack
        } catch {
            lensAssetPackMessage = "导入透镜包失败：\(error.localizedDescription)"
            throw error
        }
    }

    private func applyLensAssetPacks(_ packs: [LensAssetPack]) {
        lensAssetPacks = Self.sortedLensAssetPacks(packs)
        runtimeLensItems = Self.sortedRuntimeLensItems(from: lensAssetPacks.filter(Self.canUseAsRuntimeLensPack))
    }

    private func applyPromptAssetPacks(_ packs: [PromptAssetPack]) {
        promptAssetPacks = Self.sortedPromptAssetPacks(packs)
        runtimePromptAssetPacks = promptAssetPacks.filter(Self.canUseAsRuntimePromptPack)
        refreshPromptRuntimeState()
    }

    private func refreshPromptRuntimeState() {
        refreshAIServiceFromKeychainIfNeeded()
        promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
            runs: recentPromptEvalRuns,
            promptProvider: effectivePromptProvider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
    }

    private func clearRuntimeLensSelectionIfNeeded(from pack: LensAssetPack) {
        guard let selectedId = todayDraft.selectedCustomLensId,
              pack.items.contains(where: { $0.lensId == selectedId })
        else { return }

        todayDraft.selectedCustomLensId = nil
        todayDraft.customLensQuestions = []
        questions = []
        persistDraft()
    }

    private func validateLensAssetPackForImport(_ pack: LensAssetPack) throws {
        guard !pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires id")
        }
        guard !pack.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires version")
        }
        guard !pack.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires displayName")
        }
        guard !pack.items.isEmpty else {
            throw PersistenceError.validationFailed("LensAssetPack requires at least one lens")
        }
        guard !pack.sourceKind.requiresTrustMetadata || pack.trustMetadata != nil else {
            throw PersistenceError.validationFailed("LensAssetPack requires trust metadata for external sources")
        }
    }

    private func validatePromptAssetPackForImport(_ pack: PromptAssetPack) throws {
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
        guard !pack.sourceKind.requiresTrustMetadata || pack.trustMetadata != nil else {
            throw PersistenceError.validationFailed("PromptAssetPack requires trust metadata for external sources")
        }
    }

    private static func sortedPromptAssetPacks(_ packs: [PromptAssetPack]) -> [PromptAssetPack] {
        packs.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled {
                return lhs.isEnabled && !rhs.isEnabled
            }
            let lhsName = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if lhsName != .orderedSame {
                return lhsName == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    private static func sortedLensAssetPacks(_ packs: [LensAssetPack]) -> [LensAssetPack] {
        packs.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled {
                return lhs.isEnabled && !rhs.isEnabled
            }
            let lhsName = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if lhsName != .orderedSame {
                return lhsName == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    private static func sortedRuntimeLensItems(from packs: [LensAssetPack]) -> [LensCatalogItem] {
        LensLibrary(packs: packs).items.sorted { lhs, rhs in
            if lhs.methodIndex != rhs.methodIndex {
                return lhs.methodIndex < rhs.methodIndex
            }
            return lhs.lensId < rhs.lensId
        }
    }

    private static func assetPackInstallSummary(_ report: AssetPackInstallValidationReport) -> String {
        let installedPromptCount = report.installablePromptPacks.count
        let installedLensCount = report.installableLensPacks.count
        let rejectedPromptCount = report.rejectedPromptPacks.count
        let rejectedLensCount = report.rejectedLensPacks.count
        let base = "已安装 \(installedPromptCount) 个 Prompt 包、\(installedLensCount) 个透镜包；拒绝 \(rejectedPromptCount) 个 Prompt 包、\(rejectedLensCount) 个透镜包。"
        let rejectionDetails = assetPackInstallRejectionSummary(report)
        guard !rejectionDetails.isEmpty else { return base }
        return "\(base)拒绝原因：\(rejectionDetails)。"
    }

    private static func assetPackTrustPolicyPublisherSummary(_ document: AssetPackTrustPolicyDocument) -> String? {
        var seenPublisherIds: Set<String> = []
        let names = document.policies
            .flatMap(\.publisherProfiles)
            .compactMap { profile -> String? in
                guard seenPublisherIds.insert(profile.id).inserted else { return nil }
                let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackId = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
                if !displayName.isEmpty { return displayName }
                return fallbackId.isEmpty ? nil : fallbackId
            }

        guard !names.isEmpty else { return nil }
        return "信任发布者：\(names.joined(separator: "、"))。"
    }

    private static func assetPackInstallRejectionSummary(_ report: AssetPackInstallValidationReport) -> String {
        let promptDetails = assetPackInstallRejectionSummary(
            title: "Prompt 包",
            rejections: report.rejectedPromptPacks
        )
        let lensDetails = assetPackInstallRejectionSummary(
            title: "透镜包",
            rejections: report.rejectedLensPacks
        )
        return (promptDetails + lensDetails).joined(separator: "、")
    }

    private static func assetPackInstallRejectionSummary(
        title: String,
        rejections: [AssetPackInstallRejection]
    ) -> [String] {
        var reasonOrder: [AssetPackInstallRejectionReason] = []
        var countsByReason: [AssetPackInstallRejectionReason: Int] = [:]
        for rejection in rejections {
            if countsByReason[rejection.reason] == nil {
                reasonOrder.append(rejection.reason)
            }
            countsByReason[rejection.reason, default: 0] += 1
        }
        return reasonOrder.compactMap { reason in
            guard let count = countsByReason[reason] else { return nil }
            return "\(title)\(assetPackInstallRejectionReasonLabel(reason)) \(count) 个"
        }
    }

    private static func assetPackInstallRejectionReasonLabel(_ reason: AssetPackInstallRejectionReason) -> String {
        switch reason {
        case .missingTrustMetadata:
            return "缺少信任元数据"
        case .incompleteTrustMetadata:
            return "信任元数据不完整"
        case .unexpectedVerificationPolicyVersion:
            return "策略版本不匹配"
        case .mismatchedContentHash:
            return "内容哈希不匹配"
        case .invalidTrustProof:
            return "签名或信任策略无效"
        }
    }

    private static func assetPackRegistrySubscriptionId(for catalogURL: URL) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let normalized = catalogURL.absoluteString.lowercased()
        let sanitized = normalized.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "_")
            .joined(separator: "_")
        let suffix = sanitized.isEmpty ? "catalog" : String(sanitized.prefix(64))
        return "registry.\(suffix)"
    }

    private static func canUseAsRuntimeLensPack(_ pack: LensAssetPack) -> Bool {
        guard pack.isEnabled else { return false }
        guard pack.sourceKind.requiresTrustMetadata else { return true }
        guard let metadata = pack.trustMetadata,
              metadata.missingRequiredFields.isEmpty
        else { return false }
        return (try? AssetPackIntegrity.hasValidContentHash(pack)) == true
    }

    private static func canUseAsRuntimePromptPack(_ pack: PromptAssetPack) -> Bool {
        guard pack.isEnabled else { return false }
        guard pack.sourceKind.requiresTrustMetadata else { return true }
        guard let metadata = pack.trustMetadata,
              metadata.missingRequiredFields.isEmpty
        else { return false }
        return (try? AssetPackIntegrity.hasValidContentHash(pack)) == true
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
        #if DEBUG
        if visualQASettingsAuditProofActive {
            recentPromptRuns = [Self.makeVisualQASettingsAuditProofRun()]
            promptRunStats = PromptRunStats(
                totalCount: 1,
                successCount: 0,
                failureCount: 1,
                emptyResultCount: 0,
                userDeniedCount: 0
            )
            promptAssetRunQualitySummaries = PromptAssetRunQualitySummary.summaries(for: recentPromptRuns)
            refreshPromptAssetQualityGate()
            promptRunAuditMessage = ""
            return
        }
        #endif

        guard let promptRunRepository else {
            recentPromptRuns = []
            promptRunStats = nil
            promptAssetRunQualitySummaries = []
            refreshPromptAssetQualityGate()
            promptRunAuditMessage = "AI 调用记录暂不可用。"
            return
        }

        do {
            recentPromptRuns = try await promptRunRepository.recentPromptRuns(limit: limit)
            promptRunStats = try await promptRunRepository.promptRunStats(limit: limit)
            promptAssetRunQualitySummaries = try await promptRunRepository.promptAssetRunQualitySummaries(limit: limit)
            refreshPromptAssetQualityGate()
            promptRunAuditMessage = recentPromptRuns.isEmpty ? "还没有 AI 调用记录。" : ""
        } catch {
            recentPromptRuns = []
            promptRunStats = nil
            promptAssetRunQualitySummaries = []
            refreshPromptAssetQualityGate()
            promptRunAuditMessage = "读取 AI 调用记录失败。"
        }
    }

    private func refreshPromptAssetQualityGate() {
        promptAssetQualityGate = PromptAssetQualityGate.evaluate(
            summaries: promptAssetRunQualitySummaries,
            evalRuns: recentPromptEvalRuns,
            promptProvider: effectivePromptProvider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
    }

    func loadRecentPromptEvalRuns(limit: Int = 100) async {
        guard let promptEvalRunRepository else {
            recentPromptEvalRuns = []
            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: [],
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )
            refreshPromptAssetQualityGate()
            promptEvalMessage = "Prompt 固定评测记录暂不可用。"
            return
        }

        do {
            recentPromptEvalRuns = try await promptEvalRunRepository.recentEvalRuns(limit: limit)
            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: recentPromptEvalRuns,
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )
            refreshPromptAssetQualityGate()
            promptEvalMessage = recentPromptEvalRuns.isEmpty ? "还没有固定评测记录。" : promptEvalGateSummaryMessage
        } catch {
            recentPromptEvalRuns = []
            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: [],
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )
            refreshPromptAssetQualityGate()
            promptEvalMessage = "读取 Prompt 固定评测失败。"
        }
    }

    func runPromptEvalSuite() async {
        let runner = PromptEvalRunner(promptProvider: effectivePromptProvider)
        let runs = runner.runFixedSuite()
        recentPromptEvalRuns = runs

        do {
            if let promptEvalRunRepository {
                for run in runs {
                    try await promptEvalRunRepository.saveEvalRun(run)
                }
                recentPromptEvalRuns = try await promptEvalRunRepository.recentEvalRuns(limit: 100)
            }

            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: recentPromptEvalRuns,
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )

            let persistenceNote = promptEvalRunRepository == nil ? "（未持久化）" : ""
            promptEvalMessage = "\(promptEvalGateSummaryMessage)\(persistenceNote)"
        } catch {
            promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
                runs: runs,
                promptProvider: effectivePromptProvider,
                mode: .standard,
                runnerVersion: PromptEvalRunner.currentRunnerVersion
            )
            promptEvalMessage = "固定评测已运行，但保存记录失败。"
        }
    }

    @discardableResult
    func applyPromptRollback(_ candidate: PromptEvalRollbackCandidate) async -> Bool {
        guard promptEvalReleaseGate.rollbackCandidates.contains(candidate) else {
            promptEvalMessage = "回滚失败：候选记录已过期，请重新加载固定评测。"
            return false
        }
        guard let promptID = PromptID(rawValue: candidate.promptId) else {
            promptEvalMessage = "回滚失败：未知 Prompt。"
            return false
        }
        guard let rollbackTemplate = runtimePromptProvider.template(
            for: promptID,
            mode: .standard,
            version: candidate.rollbackTargetVersion
        ) else {
            promptEvalMessage = "回滚失败：本地没有 \(candidate.rollbackTargetVersion) 版本的 Prompt 资产。"
            return false
        }

        if let promptAssetSelectionRepository {
            do {
                try await promptAssetSelectionRepository.saveSelection(
                    PromptAssetSelection(
                        promptId: promptID,
                        selectedVersion: candidate.rollbackTargetVersion,
                        baseVersion: candidate.currentVersion,
                        reason: .rollback
                    )
                )
            } catch {
                promptEvalMessage = "回滚失败：无法保存 Prompt 资产选择。"
                return false
            }
        }
        promptRollbackOverrides[promptID] = rollbackTemplate
        refreshAIServiceFromKeychainIfNeeded()
        promptEvalReleaseGate = PromptEvalReleaseGate.evaluate(
            runs: recentPromptEvalRuns,
            promptProvider: effectivePromptProvider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        promptEvalMessage = "已回滚 \(promptID.displayName)：\(candidate.currentVersion) → \(candidate.rollbackTargetVersion)。\(promptEvalGateSummaryMessage)"
        return true
    }

    private var promptEvalGateSummaryMessage: String {
        switch promptEvalReleaseGate.status {
        case .passed:
            return "固定评测通过：\(promptEvalReleaseGate.passedPromptCount)/\(promptEvalReleaseGate.totalPromptCount) 个 Prompt 可发布。"
        case .blocked:
            let issueCount = promptEvalReleaseGate.blockingIssues.count
            return "固定评测阻塞：\(issueCount) 项需要处理。可回滚 \(promptEvalReleaseGate.rollbackReadyCount) · 需人工处理 \(promptEvalReleaseGate.manualReviewCount)。"
        }
    }

    @discardableResult
    func prepareDataExport() async throws -> PreparedDataExport {
        guard let dataExportRepository else {
            dataExportMessage = "数据导出不可用：本地数据库未初始化。"
            throw PersistenceError.unimplemented
        }

        await waitForPendingPersistence()
        let package = try await dataExportRepository.exportPackage()
        let fileName = "mingsi-export-\(Self.exportTimestampFormatter.string(from: package.createdAt)).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try package.data.write(to: fileURL, options: .atomic)

        let prepared = PreparedDataExport(
            fileURL: fileURL,
            summary: package.summary,
            createdAt: package.createdAt
        )
        preparedDataExport = prepared
        dataExportMessage = "已准备数据导出文件。"
        return prepared
    }

    func promptTemplate(for promptID: PromptID, mode: SessionMode) -> PromptTemplate {
        effectivePromptProvider.template(for: promptID, mode: mode)
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
                let reviewContributions = try await displayableGrowthContributions(for: snapshot)
                if snapshot.canDisplayScores && reviewContributions.isEmpty {
                    growthSnapshot = snapshot.degradedForMissingGrowthContributions()
                    growthReportReviewContributions = []
                } else {
                    growthSnapshot = snapshot
                    growthReportReviewContributions = reviewContributions
                }
            }
        } catch {
            todayLoopMessage = "读取成长快照失败，已保留当前证据状态。"
        }
    }

    func loadGrowthReportReviewContributions() async {
        do {
            growthReportReviewContributions = try await displayableGrowthContributions(for: growthSnapshot)
        } catch {
            growthReportReviewContributions = []
        }
    }

    private func displayableGrowthContributions(for snapshot: MetricSnapshot) async throws -> [MetricContribution] {
        guard let metricContributionRepository, snapshot.canDisplayScores else { return [] }
        return try await metricContributionRepository
            .contributions(for: snapshot.id)
            .filter { contribution in
                contribution.isAcceptedForTrend &&
                !contribution.sourceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    func navigateTodayLoopToPreviousUserStep() {
        switch todayDraft.state {
        case .reviewCards:
            moveTodayLoop(to: .capture, message: "已回到今日输入，已生成的卡片会保留到你重新整理。")
        case .selectLens:
            navigateTodayLoop(to: .reviewCards)
        case .answerQuestions:
            navigateTodayLoop(to: .selectLens)
        case .reviewQuests:
            navigateTodayLoop(to: .answerQuestions)
        case .extractPrinciple:
            navigateTodayLoop(to: .reviewQuests)
        case .sessionComplete:
            navigateTodayLoop(to: .extractPrinciple)
        case .capture, .verifyYesterday, .organizing, .selectMode:
            if let previousState = previousNavigableTodayLoopState() {
                navigateTodayLoop(to: previousState)
            }
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
        if todayDraft.state != .capture {
            trimDerivedState(after: .capture)
        }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clearTodayLoopMessage()
        }
        persistDraft()
    }

    func updateDraftText(_ text: String) {
        updateTodayCapture(text)
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
        todayDraft.selectedCustomLensId = nil
        trimDerivedState(after: .selectLens)
        Task { await refreshReferencedPrinciplesForCurrentContext(promptID: .generateQuestions) }
        clearTodayLoopMessage()
        persistDraft()
        persistLensSession()
    }

    @discardableResult
    func generateCustomLensFromConfirmedCards() -> LensCatalogItem {
        let confirmedCards = thinkingCards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
        let primaryCard = confirmedCards.first
        let title: String
        let methodLine: String
        let promptGuidance: String
        let firstQuestion: String

        if let primaryCard {
            switch primaryCard.type {
            case .problem, .risk:
                title = "卡点拆解"
                methodLine = "先问：这个卡点背后真正没有被确认的是什么？"
                promptGuidance = "Use the user's confirmed cards to isolate the unresolved blocker and convert it into a testable next question."
                firstQuestion = "这个卡点背后真正没有被确认的是什么？"
            case .task, .decision:
                title = "行动校准"
                methodLine = "先问：这一步完成后，哪个判断会被验证？"
                promptGuidance = "Use the user's confirmed actions and decisions to ask for verifiable outcomes and tradeoffs."
                firstQuestion = "这一步完成后，哪个判断会被验证？"
            case .fact:
                title = "事实延展"
                methodLine = "先问：这条事实还能支持哪两个不同解释？"
                promptGuidance = "Use the confirmed fact to generate multiple plausible interpretations before choosing one."
                firstQuestion = "这条事实还能支持哪两个不同解释？"
            case .idea, .communication:
                title = "意图澄清"
                methodLine = "先问：我真正想改变谁的什么理解？"
                promptGuidance = "Use the user's ideas or communication cards to clarify intent, audience, and desired change."
                firstQuestion = "我真正想改变谁的什么理解？"
            }
        } else {
            title = "自定义透镜"
            methodLine = "先问：这次复盘最需要被重新看见的是什么？"
            promptGuidance = "Ask the user to name the missing angle and turn it into a concrete reflection question."
            firstQuestion = "这次复盘最需要被重新看见的是什么？"
        }

        let safeSuffix = (primaryCard?.id.uuidString.prefix(8)).map(String.init) ?? String(todayDraft.id.uuidString.prefix(8))
        return upsertCustomLens(
            title: title,
            subtitle: primaryCard.map { "由「\($0.title)」生成，服务于本次 Today。" } ?? "为当前 Today 临时生成。",
            shortLabel: "自定",
            methodLine: methodLine,
            promptGuidance: promptGuidance,
            firstQuestion: firstQuestion,
            idSuffix: safeSuffix
        )
    }

    @discardableResult
    func upsertCustomLens(
        title: String,
        subtitle: String,
        shortLabel: String,
        methodLine: String,
        promptGuidance: String,
        firstQuestion: String,
        idSuffix: String? = nil
    ) -> LensCatalogItem {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "自定义透镜" : trimmedTitle
        let trimmedQuestion = firstQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedQuestion = trimmedQuestion.isEmpty ? "这次复盘最需要被重新看见的是什么？" : trimmedQuestion
        let safeId = (idSuffix ?? UUID().uuidString.prefix(8).description)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let item = LensCatalogItem(
            lensId: "custom-\(safeId.isEmpty ? UUID().uuidString.prefix(8) : Substring(safeId))",
            promptId: "custom_lens",
            version: "session.v1",
            title: resolvedTitle,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "本次 Today 的临时方法卡。" : subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            shortLabel: shortLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定" : shortLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            methodLine: methodLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "先问：\(resolvedQuestion)" : methodLine.trimmingCharacters(in: .whitespacesAndNewlines),
            promptGuidance: promptGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Use the user's custom lens to generate concrete reflection questions." : promptGuidance.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: "wand.and.stars",
            recommendedReason: "由当前卡片或手写规则生成。",
            questionSeeds: [resolvedQuestion],
            accentRole: .brick,
            methodIndex: 0
        )
        customLensItems.removeAll { $0.lensId == item.lensId }
        customLensItems.insert(item, at: 0)
        persistDraft()
        return item
    }

    func selectCustomLens(_ lensId: String) {
        guard (customLensItems + runtimeLensItems).contains(where: { $0.lensId == lensId }) else { return }
        todayDraft.selectedCustomLensId = lensId
        todayDraft.selectedLens = nil
        trimDerivedState(after: .selectLens)
        clearTodayLoopMessage()
        persistDraft()
    }

    func updateQuestionAnswer(questionID: ReflectionQuestion.ID, answer: String) {
        guard let index = questions.firstIndex(where: { $0.id == questionID }) else { return }
        questions[index].answer = answer
        trimDerivedState(after: .answerQuestions)
        if todayDraft.selectedCustomLensId != nil {
            todayDraft.customLensQuestions = questions
            persistDraft()
        }
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

    @discardableResult
    func repairPrinciple(
        _ principleID: PrincipleAsset.ID,
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

        guard let existing = principleTrainingSummaries.map(\.principle).first(where: { $0.id == principleID }) ??
            activePrinciples.first(where: { $0.id == principleID }) ??
            principles.first(where: { $0.id == principleID })
        else {
            todayLoopMessage = "没有找到要复审的原则。"
            return false
        }

        let repaired = PrincipleAsset(
            id: existing.id,
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
            if let principleRepository {
                try await principleRepository.updatePrinciple(repaired)
            }
        } catch {
            todayLoopMessage = "保存原则复审失败。"
            return false
        }

        if let todayIndex = principles.firstIndex(where: { $0.id == repaired.id }) {
            principles[todayIndex] = repaired
        }
        if let activeIndex = activePrinciples.firstIndex(where: { $0.id == repaired.id }) {
            activePrinciples[activeIndex] = repaired
        } else {
            activePrinciples.insert(repaired, at: 0)
        }
        await loadActivePrinciples()
        todayLoopMessage = principleRepository == nil ? "原则已复审并重新启用（当前未启用持久化）。" : "原则已复审并重新启用。"
        return true
    }

    @discardableResult
    func archivePrinciple(_ principleID: PrincipleAsset.ID) async -> Bool {
        do {
            if let principleRepository {
                try await principleRepository.updatePrincipleStatus(.archived, principleId: principleID)
            }
        } catch {
            todayLoopMessage = "归档原则失败。"
            return false
        }

        principles.removeAll { $0.id == principleID }
        activePrinciples.removeAll { $0.id == principleID }
        referencedPrinciples.removeAll { $0.id == principleID }
        referencedPrincipleRetrievals[principleID] = nil
        principleTrainingSummaries.removeAll { $0.principle.id == principleID }
        await refreshPrincipleTrainingSummaries()
        todayLoopMessage = principleRepository == nil ? "原则已从当前会话移除（当前未启用持久化）。" : "原则已归档。"
        return true
    }

    @discardableResult
    func deletePrinciple(_ principleID: PrincipleAsset.ID) async -> Bool {
        do {
            if let principleRepository {
                try await principleRepository.deletePrinciple(principleID)
            }
        } catch {
            todayLoopMessage = "删除原则失败。"
            return false
        }

        principles.removeAll { $0.id == principleID }
        activePrinciples.removeAll { $0.id == principleID }
        referencedPrinciples.removeAll { $0.id == principleID }
        referencedPrincipleRetrievals[principleID] = nil
        principleTrainingSummaries.removeAll { $0.principle.id == principleID }
        await refreshPrincipleTrainingSummaries()
        todayLoopMessage = principleRepository == nil ? "原则已从当前会话删除（当前未启用持久化）。" : "原则已删除。"
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
        clearReferencedPrinciples()
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
            await recordPrinciplePracticeEvidenceIfNeeded(
                quest: quest,
                verification: verification,
                sourceDailyEntryId: sourceDailyEntryId
            )
            await refreshGrowthEvidenceAfterTodayChange()
        } catch {
            todayLoopMessage = "校准记录保存失败，但已继续下一步。"
        }
    }

    private func recordPrinciplePracticeEvidenceIfNeeded(
        quest: Quest,
        verification: Verification,
        sourceDailyEntryId: UUID
    ) async {
        guard let principlePracticeEvidenceRepository else { return }

        let candidatePrinciples: [PrincipleAsset]
        do {
            if let storedPrinciples = try await principleRepository?.activePrinciples() {
                candidatePrinciples = storedPrinciples
            } else {
                candidatePrinciples = activePrinciples
            }
        } catch {
            candidatePrinciples = activePrinciples
        }

        let practiceText = [
            quest.title,
            quest.whyItMatters,
            quest.completionCriteria,
            quest.reflectionQuestion,
            verification.calibrationNote,
            verification.likelyIssue,
            verification.recommendation,
            todayDraft.rawText
        ]
            .compactMap { $0 }
            .joined(separator: "\n")

        for principle in candidatePrinciples where Self.practiceText(practiceText, matches: principle) {
            do {
                let existing = try await principlePracticeEvidenceRepository.evidence(
                    for: principle.id,
                    sourceDailyEntryId: sourceDailyEntryId,
                    questId: quest.id,
                    evidenceSource: .verification
                )
                guard existing == nil else { continue }

                let evidence = PrinciplePracticeEvidence(
                    principleId: principle.id,
                    sourceDailyEntryId: sourceDailyEntryId,
                    questId: quest.id,
                    verificationId: verification.id,
                    evidenceSource: .verification,
                    strength: .intentionalPractice,
                    evidenceSummary: "验证任务显示原则「\(principle.title)」被实际练习：\(quest.title)"
                )
                try await principlePracticeEvidenceRepository.saveEvidence(evidence)
            } catch {
                continue
            }
        }
    }

    private static func practiceText(_ text: String, matches principle: PrincipleAsset) -> Bool {
        let normalizedText = normalizePracticeMatchText(text)
        let candidates = ([principle.title, principle.summary, principle.triggerContext, principle.successCriteria] + principle.actions)
            .map(normalizePracticeMatchText)
            .filter { $0.count >= 4 }
        return candidates.contains { normalizedText.contains($0) }
    }

    private static func normalizePracticeMatchText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation }
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
        guard todayDraft.selectedLens != nil || todayDraft.selectedCustomLensId != nil else {
            todayLoopMessage = "请选择一个思考透镜。"
            return
        }
        if questions.isEmpty {
            let draftID = todayDraft.id
            todayLoopMessage = "正在生成追问。"
            if todayDraft.selectedCustomLensId != nil {
                generateLocalQuestions(from: todayDraft.rawText)
                moveTodayLoop(to: .answerQuestions)
                return
            }
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
            await waitForPendingPersistence()
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
        let dismissedContributionTitles = await dismissedGrowthContributionTitles()

        let context = buildGrowthReportContext(
            period: "weekly",
            completedRecords: completedRecords,
            dismissedContributionTitles: dismissedContributionTitles
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
        let dismissedContributionTitles = await dismissedGrowthContributionTitles()

        let context = buildGrowthReportContext(
            period: "monthly",
            completedRecords: completedRecords,
            dismissedContributionTitles: dismissedContributionTitles
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
        completedRecords: [HistoryRecord],
        dismissedContributionTitles: [String]
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

        return GrowthReportContext(
            period: period,
            startDate: completedRecords.first?.draft.date,
            endDate: completedRecords.last?.draft.date,
            completeLoopCount: completedRecords.count,
            historyRecords: summaries,
            previousSnapshot: growthSnapshot.canDisplayScores ? growthSnapshot : nil,
            dismissedContributionTitles: dismissedContributionTitles
        )
    }

    private func dismissedGrowthContributionTitles() async -> [String] {
        var contributions = historyRecords.flatMap { record in
            record.growthContributions
        }

        if let metricContributionRepository {
            var snapshotIds: [UUID] = [growthSnapshot.id]
            if let metricSnapshotRepository,
               let latestSnapshot = try? await metricSnapshotRepository.latestSnapshot(),
               latestSnapshot.id != growthSnapshot.id {
                snapshotIds.append(latestSnapshot.id)
            }

            for snapshotId in snapshotIds {
                if let snapshotContributions = try? await metricContributionRepository.contributions(for: snapshotId) {
                    contributions.append(contentsOf: snapshotContributions)
                }
            }
        }

        var seen: Set<String> = []
        return contributions.compactMap { contribution -> String? in
            guard contribution.userFeedback == .inaccurate || contribution.userFeedback == .dismissed else {
                return nil
            }
            let title = contribution.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !seen.contains(title) else { return nil }
            seen.insert(title)
            return title
        }
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
            customLensItems = []
            streamingCards = []
            streamingStatusText = ""
            todayDraft.hasSelectedSessionMode = false
            todayDraft.sessionMode = .standard
            todayDraft.selectedLens = nil
            todayDraft.selectedCustomLensId = nil
            todayDraft.customLensQuestions = []
            questions = []
            quests = []
            principles = []
            clearReferencedPrinciples()
        case .capture, .organizing:
            thinkingCards = []
            customLensItems = []
            streamingCards = []
            streamingStatusText = ""
            todayDraft.selectedLens = nil
            todayDraft.selectedCustomLensId = nil
            todayDraft.customLensQuestions = []
            questions = []
            quests = []
            principles = []
            clearReferencedPrinciples()
        case .reviewCards:
            todayDraft.hasSelectedSessionMode = false
            todayDraft.sessionMode = .standard
            todayDraft.selectedLens = nil
            todayDraft.selectedCustomLensId = nil
            todayDraft.customLensQuestions = []
            questions = []
            quests = []
            principles = []
            clearReferencedPrinciples()
        case .selectMode:
            todayDraft.selectedLens = nil
            todayDraft.selectedCustomLensId = nil
            todayDraft.customLensQuestions = []
            questions = []
            quests = []
            principles = []
            clearReferencedPrinciples()
        case .selectLens:
            todayDraft.customLensQuestions = []
            questions = []
            quests = []
            principles = []
            clearReferencedPrinciples()
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

    private func previousNavigableTodayLoopState() -> DailyLoopState? {
        guard
            let currentIndex = DailyLoopState.allCases.firstIndex(of: todayDraft.state),
            currentIndex > 0
        else { return nil }

        return DailyLoopState.allCases[..<currentIndex]
            .reversed()
            .first { canNavigateTodayLoop(to: $0) }
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
                let recallFeedback = await principleRecallFeedbackForAI(principles: contextPrinciples)
                questions = try await todayAIService.generateQuestions(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions,
                        principles: contextPrinciples,
                        principleRecallFeedback: recallFeedback,
                        selectedLensItem: selectedLensItem
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
                let recallFeedback = await principleRecallFeedbackForAI(principles: contextPrinciples)
                quests = try await todayAIService.generateQuests(
                    for: TodayAIContext(
                        draft: todayDraft,
                        confirmedCards: confirmedCardsForAI,
                        questions: questions,
                        principles: contextPrinciples,
                        principleRecallFeedback: recallFeedback,
                        selectedLensItem: selectedLensItem
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
                        principles: await existingPrinciplesForDedupe(),
                        selectedLensItem: selectedLensItem
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
        let lensItem = selectedLensItem
        let modeQuestion: String
        switch todayDraft.sessionMode {
        case .quick:
            modeQuestion = "如果只能推进一个动作，哪个动作最能减少不确定性？"
        case .standard:
            modeQuestion = "明天最应该先验证的关键判断是什么？"
        case .deep:
            modeQuestion = "这件事背后反复出现的思维模式是什么？"
        }

        if let customLensId = todayDraft.selectedCustomLensId,
           let customLens = (customLensItems + runtimeLensItems).first(where: { $0.lensId == customLensId }) {
            questions = [
                ReflectionQuestion(
                    question: customLens.questionSeeds.first ?? customLens.methodLine,
                    whyItMatters: customLens.methodLine
                ),
                ReflectionQuestion(
                    question: "\(customLens.title) 会如何改写你对这件事的判断？",
                    whyItMatters: focus
                )
            ]
            todayDraft.customLensQuestions = questions
            persistDraft()
            return
        }

        questions = [
            ReflectionQuestion(
                question: modeQuestion,
                whyItMatters: "让任务从泛泛而谈变成可验证行动。"
            ),
            ReflectionQuestion(
                question: "\(lensItem?.title ?? "当前透镜") 会如何改写你对这件事的判断？",
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
        enqueuePersistence(errorMessage: "保存本地复盘草稿失败。") {
            try await dailyEntryRepository.saveDraft(draft)
        }
    }

    private func persistCards() {
        guard let thinkingCardRepository else { return }
        let cards = thinkingCards.filter { $0.isConfirmed || $0.isExcludedFromModel }
        let draftID = todayDraft.id
        enqueuePersistence(errorMessage: "保存思考卡片失败。") {
            try await thinkingCardRepository.saveCards(cards, dailyEntryId: draftID)
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
        enqueuePersistence(errorMessage: "保存明日任务失败。") {
            try await questRepository.saveQuests(quests, sourceDailyEntryId: draftID)
        }
    }

    private func persistPrinciples() {
        guard let principleRepository else { return }
        let principles = principles
        let draftID = todayDraft.id
        enqueuePersistence(errorMessage: "保存原则资产失败。") {
            try await principleRepository.savePrinciples(principles, sourceDailyEntryId: draftID)
        }
    }

    private func persistLensSession() {
        guard let lensSessionRepository, let lens = todayDraft.selectedLens else { return }
        let draftID = todayDraft.id
        let currentQuestions = questions
        let session = LensSession(
            dailyEntryId: draftID,
            selectedLens: lens,
            questions: currentQuestions
        )
        enqueuePersistence(errorMessage: "保存透镜会话失败。") {
            try await lensSessionRepository.saveLensSession(session)
        }
    }

    private func enqueuePersistence(
        errorMessage: String,
        operation: @escaping () async throws -> Void
    ) {
        let previous = persistenceChain
        persistenceChainGeneration += 1
        let generation = persistenceChainGeneration
        let next = Task { [weak self] in
            if let previous {
                await previous.value
            }

            do {
                try await operation()
            } catch {
                await MainActor.run {
                    self?.todayLoopMessage = errorMessage
                }
            }

            await MainActor.run {
                guard self?.persistenceChainGeneration == generation else { return }
                self?.persistenceChain = nil
            }
        }
        persistenceChain = next
    }

    private func waitForPendingPersistence() async {
        let chain = persistenceChain
        await chain?.value
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
            if let storedPrinciples = try await principleRepository?.activePrinciples() {
                let reviewedPrinciples = await markPrinciplesNeedingReviewIfNeeded(storedPrinciples)
                return reviewedPrinciples.filter { $0.status == .active }
            }
        } catch {
            todayLoopMessage = "读取历史原则失败，已继续当前流程。"
        }
        return activePrinciples
    }

    private func loadActivePrinciples() async {
        do {
            if let principleRepository {
                let storedPrinciples = try await principleRepository.allPrinciples()
                let reviewedPrinciples = await markPrinciplesNeedingReviewIfNeeded(storedPrinciples)
                activePrinciples = reviewedPrinciples.filter { $0.status == .active }
                await refreshPrincipleTrainingSummaries(from: reviewedPrinciples)
                return
            } else {
                activePrinciples = principles.filter { $0.status == .active }
            }
        } catch {
            activePrinciples = principles.filter { $0.status == .active }
            todayLoopMessage = "读取历史原则失败，已继续当前流程。"
        }
        await refreshPrincipleTrainingSummaries()
    }

    func refreshPrincipleTrainingSummaries() async {
        let visiblePrinciples: [PrincipleAsset]
        do {
            visiblePrinciples = try await principleRepository?.allPrinciples() ?? activePrinciples
        } catch {
            visiblePrinciples = activePrinciples
        }
        await refreshPrincipleTrainingSummaries(from: visiblePrinciples)
    }

    private func refreshPrincipleTrainingSummaries(from principles: [PrincipleAsset]) async {
        let visiblePrinciples = principles.filter { $0.status != .archived }
        guard !visiblePrinciples.isEmpty else {
            principleTrainingSummaries = []
            return
        }

        var practiceEvidence: [PrinciplePracticeEvidence] = []
        var recallFeedback: [PrincipleRecallFeedback] = []

        for principle in visiblePrinciples {
            do {
                let evidence = try await principlePracticeEvidenceRepository?.evidence(for: principle.id, limit: 20) ?? []
                practiceEvidence.append(contentsOf: evidence)
            } catch {
                continue
            }
            do {
                let feedback = try await principleRecallFeedbackRepository?.feedback(for: principle.id, limit: 20) ?? []
                recallFeedback.append(contentsOf: feedback)
            } catch {
                continue
            }
        }

        principleTrainingSummaries = PrincipleTrainingSummary.summaries(
            for: visiblePrinciples,
            practiceEvidence: practiceEvidence,
            recallFeedback: recallFeedback
        )
    }

    private func markPrinciplesNeedingReviewIfNeeded(_ principles: [PrincipleAsset]) async -> [PrincipleAsset] {
        guard let principleRepository, let principleRecallFeedbackRepository else { return principles }

        var reviewedPrinciples = principles
        for index in reviewedPrinciples.indices where reviewedPrinciples[index].status == .active {
            let principle = reviewedPrinciples[index]
            do {
                let feedback = try await principleRecallFeedbackRepository.feedback(
                    for: principle.id,
                    limit: principleNeedsReviewNegativeFeedbackThreshold
                )
                let negativeCount = feedback.filter {
                    $0.feedback == .notApplicable || $0.feedback == .misrecalled
                }.count
                guard negativeCount >= principleNeedsReviewNegativeFeedbackThreshold else { continue }

                try await principleRepository.updatePrincipleStatus(.needsReview, principleId: principle.id)
                reviewedPrinciples[index].status = .needsReview
            } catch {
                continue
            }
        }
        return reviewedPrinciples
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

    private func principleRecallFeedbackForAI(principles: [PrincipleAsset]) async -> [PrincipleRecallFeedback] {
        guard let principleRecallFeedbackRepository else { return [] }
        var feedback: [PrincipleRecallFeedback] = []
        for principle in principles {
            do {
                let loaded = try await principleRecallFeedbackRepository.feedback(for: principle.id, limit: 5)
                feedback.append(contentsOf: loaded)
            } catch {
                continue
            }
        }
        return feedback
    }

    private func refreshReferencedPrinciplesForCurrentContext(promptID: PromptID) async {
        let contextPrinciples = await contextPrinciplesForAI()
        let recallFeedback = await principleRecallFeedbackForAI(principles: contextPrinciples)
        refreshReferencedPrinciples(
            promptID: promptID,
            from: contextPrinciples,
            recallFeedback: recallFeedback
        )
    }

    private func refreshReferencedPrinciples(
        promptID: PromptID,
        from contextPrinciples: [PrincipleAsset],
        recallFeedback: [PrincipleRecallFeedback] = []
    ) {
        let context = TodayAIContext(
            draft: todayDraft,
            confirmedCards: confirmedCardsForAI,
            questions: questions,
            quests: quests,
            principles: contextPrinciples,
            principleRecallFeedback: recallFeedback,
            selectedLensItem: selectedLensItem
        )
        let retrieved = LocalPrincipleRetriever().retrievePrinciples(
            for: context,
            promptID: promptID,
            limit: 3
        )
        referencedPrinciples = retrieved.map(\.principle)
        referencedPrincipleRetrievals = Dictionary(
            uniqueKeysWithValues: retrieved.map { ($0.principle.id, $0) }
        )
    }

    private func clearReferencedPrinciples() {
        referencedPrinciples = []
        referencedPrincipleRetrievals = [:]
    }

    func recordReferencedPrincipleFeedback(
        for principleId: UUID,
        feedback: PrincipleRecallFeedbackValue,
        note: String = ""
    ) async {
        guard let retrieved = referencedPrincipleRetrievals[principleId],
              let principleRecallFeedbackRepository
        else {
            return
        }

        let promptId: PromptID = todayDraft.state == .reviewQuests ? .generateQuests : .generateQuestions
        let event = PrincipleRecallFeedback(
            principleId: principleId,
            sourceDailyEntryId: todayDraft.id,
            promptId: promptId,
            retrievalPolicyVersion: retrieved.policyVersion,
            retrievalReason: retrieved.retrievalReason,
            feedback: feedback,
            note: note
        )

        do {
            try await principleRecallFeedbackRepository.saveFeedback(event)
            if feedback == .notApplicable || feedback == .misrecalled {
                referencedPrinciples.removeAll { $0.id == principleId }
                referencedPrincipleRetrievals[principleId] = nil
                await loadActivePrinciples()
            } else {
                await refreshPrincipleTrainingSummaries()
            }
        } catch {
            todayLoopMessage = "保存原则反馈失败，已保留当前流程。"
        }
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
        promptRunRepository: PromptRunRepository?,
        promptProvider: PromptProvider = LocalPromptProvider()
    ) -> TodayAIService {
        TodayAIService(
            promptProvider: promptProvider,
            llmClient: makeLLMClient(apiKeyStore: apiKeyStore, promptRunRepository: promptRunRepository)
        )
    }

    private static func makeGrowthAIService(
        apiKeyStore: KeychainAPIKeyStore,
        promptRunRepository: PromptRunRepository?,
        promptProvider: PromptProvider = LocalPromptProvider()
    ) -> GrowthAIService {
        GrowthAIService(
            promptProvider: promptProvider,
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
            promptRunRepository: promptRunRepository,
            promptProvider: effectivePromptProvider
        )
        growthAIService = Self.makeGrowthAIService(
            apiKeyStore: apiKeyStore,
            promptRunRepository: promptRunRepository,
            promptProvider: effectivePromptProvider
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
        let contextPayload = PromptContextPayload(
            currentInput: .init(rawText: "connection test"),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue)
        )
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "connection-test",
                systemText: "Return valid JSON only.",
                userText: "Reply with {\"ok\":true}.",
                outputSchemaVersion: 1
            ),
            inputSummary: "connection test",
            contextPayload: contextPayload
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
            await loadRecentPromptRuns()
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
            promptProvider: effectivePromptProvider,
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
