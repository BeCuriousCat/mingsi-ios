import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case history
    case projects
    case growth
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今日"
        case .history: return "历史"
        case .projects: return "项目"
        case .growth: return "成长"
        case .settings: return "设置"
        }
    }
}

enum SessionMode: String, CaseIterable, Identifiable {
    case quick
    case standard
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .deep: return "Deep"
        }
    }
}

enum YesterdayCompletion: String, CaseIterable, Identifiable {
    case done
    case partial
    case missed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .done: return "完成"
        case .partial: return "部分"
        case .missed: return "未完成"
        }
    }
}

enum YesterdayValueRating: String, CaseIterable, Identifiable {
    case high
    case medium
    case low
    case uncertain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return "高价值"
        case .medium: return "中价值"
        case .low: return "低价值"
        case .uncertain: return "不确定"
        }
    }
}

enum DailyLoopState: String, CaseIterable, Identifiable {
    case verifyYesterday
    case capture
    case organizing
    case reviewCards
    case selectMode
    case selectLens
    case answerQuestions
    case reviewQuests
    case extractPrinciple
    case sessionComplete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verifyYesterday: return "验证昨日"
        case .capture: return "今日输入"
        case .organizing: return "整理中"
        case .reviewCards: return "思考卡片"
        case .selectMode: return "选择模式"
        case .selectLens: return "选择透镜"
        case .answerQuestions: return "回答问题"
        case .reviewQuests: return "明日任务"
        case .extractPrinciple: return "原则沉淀"
        case .sessionComplete: return "今日完成"
        }
    }
}

struct LensCatalogItem: Equatable {
    let lensId: String
    let promptId: String
    let version: String
    let title: String
    let subtitle: String
    let shortLabel: String
    let methodLine: String
    let promptGuidance: String
    let symbolName: String
}

protocol LensCatalogProviding {
    var items: [LensCatalogItem] { get }
    func item(localId: String) -> LensCatalogItem?
    func item(promptId: String) -> LensCatalogItem?
    func item(for lens: ThinkingLens) -> LensCatalogItem?
}

struct LensLibrary: LensCatalogProviding {
    let items: [LensCatalogItem]

    func item(localId: String) -> LensCatalogItem? {
        items.first { $0.lensId == localId }
    }

    func item(promptId: String) -> LensCatalogItem? {
        items.first { $0.promptId == promptId }
    }

    func item(for lens: ThinkingLens) -> LensCatalogItem? {
        item(localId: lens.rawValue)
    }
}

enum BuiltinLensCatalog {
    static let library = LensLibrary(items: [
        LensCatalogItem(
            lensId: "evidenceCheck",
            promptId: "evidence_check",
            version: "builtin.v1",
            title: "证据校验",
            subtitle: "把事实、判断和假设分开，先清理地基。",
            shortLabel: "事实",
            methodLine: "先问：我知道什么，还是我以为什么？",
            promptGuidance: "Separate facts, interpretations, assumptions, and validation gaps before asking the user to decide.",
            symbolName: "checklist"
        ),
        LensCatalogItem(
            lensId: "opposingView",
            promptId: "opposing_view",
            version: "builtin.v1",
            title: "反方视角",
            subtitle: "主动寻找相反证据，避免只证明自己是对的。",
            shortLabel: "反证",
            methodLine: "先问：如果我错了，证据会长什么样？",
            promptGuidance: "Challenge the user's current interpretation by looking for contrary evidence, missing stakeholders, and plausible alternative explanations.",
            symbolName: "arrow.left.arrow.right"
        ),
        LensCatalogItem(
            lensId: "leverageAnalysis",
            promptId: "leverage_analysis",
            version: "builtin.v1",
            title: "杠杆分析",
            subtitle: "找出最能改变结果的一步，把精力放在关键处。",
            shortLabel: "杠杆",
            methodLine: "先问：哪一步最能改变结果？",
            promptGuidance: "Focus questions and quests on the smallest action, decision, or constraint that can most change the outcome.",
            symbolName: "point.topleft.down.curvedto.point.bottomright.up"
        ),
        LensCatalogItem(
            lensId: "firstPrinciples",
            promptId: "first_principles",
            version: "builtin.v1",
            title: "第一性原理",
            subtitle: "拆掉默认前提，只保留不可再拆的事实和约束。",
            shortLabel: "本质",
            methodLine: "先问：如果从零开始，这件事必须成立的条件是什么？",
            promptGuidance: "Decompose the situation into non-negotiable facts, hard constraints, assumed rules, and rebuild the next action from those primitives.",
            symbolName: "square.stack.3d.down.right"
        ),
    ])

    static var items: [LensCatalogItem] {
        library.items
    }

    static func item(for lens: ThinkingLens) -> LensCatalogItem {
        library.item(for: lens)!
    }

    static func item(localId: String) -> LensCatalogItem? {
        library.item(localId: localId)
    }

    static func item(promptId: String) -> LensCatalogItem? {
        library.item(promptId: promptId)
    }
}

enum ThinkingLens: String, CaseIterable, Identifiable {
    case evidenceCheck
    case opposingView
    case leverageAnalysis
    case firstPrinciples

    var id: String { rawValue }

    var catalogItem: LensCatalogItem {
        BuiltinLensCatalog.item(for: self)
    }

    var title: String { catalogItem.title }

    var subtitle: String { catalogItem.subtitle }
}

enum ThinkingCardType: String, CaseIterable, Identifiable {
    case fact
    case problem
    case decision
    case risk
    case idea
    case communication
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fact: return "事实"
        case .problem: return "问题"
        case .decision: return "决策"
        case .risk: return "风险"
        case .idea: return "想法"
        case .communication: return "沟通"
        case .task: return "任务"
        }
    }
}

enum PriorityLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
}

enum SensitivityLevel: String, CaseIterable, Identifiable {
    case normal
    case possiblySensitive
    case sensitive

    var id: String { rawValue }
}

struct ThinkingCard: Identifiable, Hashable {
    let id: UUID
    var type: ThinkingCardType
    var title: String
    var body: String
    var priority: PriorityLevel
    var sensitivity: SensitivityLevel
    var confidence: Double
    var isConfirmed: Bool
    var isExcludedFromModel: Bool
    var sourceRefs: [String]

    init(
        id: UUID = UUID(),
        type: ThinkingCardType,
        title: String,
        body: String,
        priority: PriorityLevel = .medium,
        sensitivity: SensitivityLevel = .normal,
        confidence: Double = 0.75,
        isConfirmed: Bool = false,
        isExcludedFromModel: Bool = false,
        sourceRefs: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.priority = priority
        self.sensitivity = sensitivity
        self.confidence = confidence
        self.isConfirmed = isConfirmed
        self.isExcludedFromModel = isExcludedFromModel
        self.sourceRefs = sourceRefs
    }
}

struct ReflectionQuestion: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var whyItMatters: String
    var answer: String

    init(
        id: UUID = UUID(),
        question: String,
        whyItMatters: String,
        answer: String = ""
    ) {
        self.id = id
        self.question = question
        self.whyItMatters = whyItMatters
        self.answer = answer
    }
}

enum QuestType: String, CaseIterable, Identifiable {
    case main
    case side
    case observation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return "主线"
        case .side: return "次要"
        case .observation: return "观察"
        }
    }
}

enum QuestStatus: String, CaseIterable, Identifiable {
    case draft
    case active
    case completed
    case partial
    case failed
    case archived

    var id: String { rawValue }
}

struct Quest: Identifiable, Hashable {
    let id: UUID
    var type: QuestType
    var title: String
    var whyItMatters: String
    var completionCriteria: String
    var expectedResistance: String
    var reflectionQuestion: String
    var status: QuestStatus

    init(
        id: UUID = UUID(),
        type: QuestType,
        title: String,
        whyItMatters: String,
        completionCriteria: String,
        expectedResistance: String,
        reflectionQuestion: String,
        status: QuestStatus = .draft
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.whyItMatters = whyItMatters
        self.completionCriteria = completionCriteria
        self.expectedResistance = expectedResistance
        self.reflectionQuestion = reflectionQuestion
        self.status = status
    }
}

enum PrincipleStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case needsReview
    case archived

    var id: String { rawValue }
}

struct PrincipleAsset: Identifiable, Hashable {
    let id: UUID
    var title: String
    var summary: String
    var triggerContext: String
    var actions: [String]
    var successCriteria: String
    var exceptions: String
    var status: PrincipleStatus

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        triggerContext: String,
        actions: [String],
        successCriteria: String,
        exceptions: String,
        status: PrincipleStatus = .active
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.triggerContext = triggerContext
        self.actions = actions
        self.successCriteria = successCriteria
        self.exceptions = exceptions
        self.status = status
    }
}

struct DailyEntryDraft: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var rawText: String
    var sessionMode: SessionMode
    var hasSelectedSessionMode: Bool
    var selectedLens: ThinkingLens?
    var yesterdayCompletion: YesterdayCompletion?
    var yesterdayValueRating: YesterdayValueRating?
    var state: DailyLoopState

    init(
        id: UUID = UUID(),
        date: Date = .now,
        rawText: String = "",
        sessionMode: SessionMode = .standard,
        hasSelectedSessionMode: Bool = false,
        selectedLens: ThinkingLens? = nil,
        yesterdayCompletion: YesterdayCompletion? = nil,
        yesterdayValueRating: YesterdayValueRating? = nil,
        state: DailyLoopState = .verifyYesterday
    ) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.sessionMode = sessionMode
        self.hasSelectedSessionMode = hasSelectedSessionMode
        self.selectedLens = selectedLens
        self.yesterdayCompletion = yesterdayCompletion
        self.yesterdayValueRating = yesterdayValueRating
        self.state = state
    }
}

struct PromptRun: Identifiable, Hashable {
    let id: UUID
    var schemaVersion: Int
    var promptId: String
    var promptVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var modelProvider: String
    var modelName: String
    var sessionMode: String
    var sourceRecordIds: [String]
    var contextRecordIds: [String]
    var requestSummary: String
    var responseJSON: String?
    var error: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        promptId: String,
        promptVersion: String,
        inputSchemaVersion: Int = 1,
        outputSchemaVersion: Int,
        modelProvider: String,
        modelName: String,
        sessionMode: String,
        sourceRecordIds: [String] = [],
        contextRecordIds: [String] = [],
        requestSummary: String,
        responseJSON: String? = nil,
        error: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.promptId = promptId
        self.promptVersion = promptVersion
        self.inputSchemaVersion = inputSchemaVersion
        self.outputSchemaVersion = outputSchemaVersion
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.sessionMode = sessionMode
        self.sourceRecordIds = sourceRecordIds
        self.contextRecordIds = contextRecordIds
        self.requestSummary = requestSummary
        self.responseJSON = responseJSON
        self.error = error
        self.createdAt = createdAt
    }
}

enum HistoricalRetryCandidateStatus: String, CaseIterable, Identifiable {
    case pending
    case retrying
    case candidateReady = "candidate_ready"
    case accepted
    case dismissed
    case blocked
    case failed

    var id: String { rawValue }
}

struct HistoricalRetryCandidate: Identifiable, Hashable {
    let id: UUID
    var schemaVersion: Int
    var failedPromptRunId: UUID
    var repairPromptRunId: UUID?
    var promptId: PromptID
    var sourceDailyEntryId: UUID
    var status: HistoricalRetryCandidateStatus
    var reconstructedInputSummary: String
    var candidatePayloadJSON: String?
    var error: String?
    var blockedReason: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        failedPromptRunId: UUID,
        repairPromptRunId: UUID? = nil,
        promptId: PromptID,
        sourceDailyEntryId: UUID,
        status: HistoricalRetryCandidateStatus = .pending,
        reconstructedInputSummary: String,
        candidatePayloadJSON: String? = nil,
        error: String? = nil,
        blockedReason: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.failedPromptRunId = failedPromptRunId
        self.repairPromptRunId = repairPromptRunId
        self.promptId = promptId
        self.sourceDailyEntryId = sourceDailyEntryId
        self.status = status
        self.reconstructedInputSummary = reconstructedInputSummary
        self.candidatePayloadJSON = candidatePayloadJSON
        self.error = error
        self.blockedReason = blockedReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct MetricSnapshot: Identifiable, Hashable {
    let id: UUID
    var period: String
    var startDate: Date?
    var endDate: Date?
    var clarity: Double
    var valueJudgment: Double
    var executionReliability: Double
    var calibration: Double
    var reflectionDepth: Double
    var previousClarity: Double?
    var previousValueJudgment: Double?
    var previousExecutionReliability: Double?
    var previousCalibration: Double?
    var previousReflectionDepth: Double?
    var clarityDelta: Double?
    var valueJudgmentDelta: Double?
    var executionReliabilityDelta: Double?
    var calibrationDelta: Double?
    var reflectionDepthDelta: Double?
    var summary: String
    var metricReasons: [String: String]
    var evidenceRefs: [String]
    var positiveContributionRefs: [String]
    var negativeContributionRefs: [String]
    var status: MetricSnapshotStatus
    var completeLoopCount: Int
    var nextTrainingFocus: String?
    var createdAt: Date
    var updatedAt: Date

    var hasInsufficientEvidence: Bool {
        status == .insufficientEvidence ||
            completeLoopCount < 3 ||
            (positiveContributionRefs.isEmpty && negativeContributionRefs.isEmpty)
    }

    var canDisplayScores: Bool {
        !hasInsufficientEvidence
    }

    init(
        id: UUID = UUID(),
        period: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        clarity: Double,
        valueJudgment: Double,
        executionReliability: Double,
        calibration: Double,
        reflectionDepth: Double,
        previousClarity: Double? = nil,
        previousValueJudgment: Double? = nil,
        previousExecutionReliability: Double? = nil,
        previousCalibration: Double? = nil,
        previousReflectionDepth: Double? = nil,
        clarityDelta: Double? = nil,
        valueJudgmentDelta: Double? = nil,
        executionReliabilityDelta: Double? = nil,
        calibrationDelta: Double? = nil,
        reflectionDepthDelta: Double? = nil,
        summary: String,
        reasons: [String] = [],
        metricReasons: [String: String] = [:],
        evidenceRefs: [String] = [],
        positiveContributionRefs: [String] = [],
        negativeContributionRefs: [String] = [],
        status: MetricSnapshotStatus = .draftReview,
        completeLoopCount: Int = 0,
        nextTrainingFocus: String? = nil,
        hasInsufficientEvidence: Bool? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.clarity = clarity
        self.valueJudgment = valueJudgment
        self.executionReliability = executionReliability
        self.calibration = calibration
        self.reflectionDepth = reflectionDepth
        self.previousClarity = previousClarity
        self.previousValueJudgment = previousValueJudgment
        self.previousExecutionReliability = previousExecutionReliability
        self.previousCalibration = previousCalibration
        self.previousReflectionDepth = previousReflectionDepth
        self.clarityDelta = clarityDelta
        self.valueJudgmentDelta = valueJudgmentDelta
        self.executionReliabilityDelta = executionReliabilityDelta
        self.calibrationDelta = calibrationDelta
        self.reflectionDepthDelta = reflectionDepthDelta
        self.summary = summary
        self.metricReasons = metricReasons.isEmpty && !reasons.isEmpty ? ["summary": reasons.joined(separator: "\n")] : metricReasons
        self.evidenceRefs = evidenceRefs
        self.positiveContributionRefs = positiveContributionRefs
        self.negativeContributionRefs = negativeContributionRefs
        self.status = hasInsufficientEvidence == true ? .insufficientEvidence : status
        self.completeLoopCount = completeLoopCount
        self.nextTrainingFocus = nextTrainingFocus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Growth Attribution Layer

enum MetricSnapshotStatus: String, CaseIterable, Identifiable {
    case insufficientEvidence = "insufficient_evidence"
    case draftReview = "draft_review"
    case confirmedTrend = "confirmed_trend"
    case recalibrated

    var id: String { rawValue }
}

enum GrowthMetric: String, CaseIterable, Identifiable {
    case clarity
    case valueJudgment = "value_judgment"
    case executionReliability = "execution_reliability"
    case calibration
    case reflectionDepth = "reflection_depth"

    var id: String { rawValue }
}

enum MetricContributionStatus: String, CaseIterable, Identifiable {
    case candidate
    case accepted
    case rejected

    var id: String { rawValue }
}

enum MetricContributionDirection: String, CaseIterable, Identifiable {
    case positive
    case negative

    var id: String { rawValue }
}

enum MetricContributionSourceType: String, CaseIterable, Identifiable {
    case dailyEntry = "daily_entry"
    case thinkingCard = "thinking_card"
    case quest
    case verification
    case principle
    case project

    var id: String { rawValue }
}

enum MetricContributionFeedback: String, CaseIterable, Identifiable {
    case accepted
    case inaccurate
    case dismissed
    case none

    var id: String { rawValue }
}

struct MetricContribution: Identifiable, Hashable {
    let id: UUID
    var snapshotId: UUID
    var metric: GrowthMetric
    var direction: MetricContributionDirection
    var delta: Double
    var title: String
    var reason: String
    var sourceType: MetricContributionSourceType
    var sourceId: String
    var sourceDailyEntryId: UUID
    var userFeedback: MetricContributionFeedback
    var candidateStatus: MetricContributionStatus
    var createdAt: Date
    var updatedAt: Date

    var isAcceptedForTrend: Bool {
        candidateStatus == .accepted && userFeedback != .inaccurate && userFeedback != .dismissed
    }

    init(
        id: UUID = UUID(),
        snapshotId: UUID,
        metric: GrowthMetric,
        direction: MetricContributionDirection,
        delta: Double,
        title: String,
        reason: String,
        sourceType: MetricContributionSourceType,
        sourceId: String,
        sourceDailyEntryId: UUID,
        userFeedback: MetricContributionFeedback = .none,
        candidateStatus: MetricContributionStatus = .candidate,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.snapshotId = snapshotId
        self.metric = metric
        self.direction = direction
        self.delta = delta
        self.title = title
        self.reason = reason
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.sourceDailyEntryId = sourceDailyEntryId
        self.userFeedback = userFeedback
        self.candidateStatus = candidateStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Verification: Identifiable, Hashable {
    let id: UUID
    var questId: UUID
    var questTitle: String
    var sourceDailyEntryId: UUID
    var completion: YesterdayCompletion
    var valueRating: YesterdayValueRating
    var calibrationNote: String
    var likelyIssue: String?
    var recommendation: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        questId: UUID,
        questTitle: String,
        sourceDailyEntryId: UUID,
        completion: YesterdayCompletion,
        valueRating: YesterdayValueRating,
        calibrationNote: String,
        likelyIssue: String? = nil,
        recommendation: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.questId = questId
        self.questTitle = questTitle
        self.sourceDailyEntryId = sourceDailyEntryId
        self.completion = completion
        self.valueRating = valueRating
        self.calibrationNote = calibrationNote
        self.likelyIssue = likelyIssue
        self.recommendation = recommendation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct LensSession: Identifiable, Hashable {
    let id: UUID
    var dailyEntryId: UUID
    var selectedLens: ThinkingLens
    var questions: [ReflectionQuestion]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dailyEntryId: UUID,
        selectedLens: ThinkingLens,
        questions: [ReflectionQuestion] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.dailyEntryId = dailyEntryId
        self.selectedLens = selectedLens
        self.questions = questions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct HistoryRecord: Identifiable, Hashable {
    var draft: DailyEntryDraft
    var cards: [ThinkingCard]
    var quests: [Quest]
    var principles: [PrincipleAsset]
    var verification: Verification?
    var lensSession: LensSession?
    var projectLinks: [ProjectLink]
    var growthContributions: [MetricContribution]

    var id: DailyEntryDraft.ID { draft.id }

    var mainQuest: Quest? {
        quests.first { $0.type == .main }
    }

    var confirmedCards: [ThinkingCard] {
        cards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
    }

    var pendingCards: [ThinkingCard] {
        cards.filter { !$0.isConfirmed && !$0.isExcludedFromModel }
    }

    var excludedCards: [ThinkingCard] {
        cards.filter(\.isExcludedFromModel)
    }

    var cardCountSummary: String {
        let confirmedCount = confirmedCards.count
        let pendingCount = pendingCards.count
        if confirmedCount > 0, pendingCount > 0 {
            return "\(confirmedCount) 已确认 / \(pendingCount) 待确认"
        }
        if confirmedCount > 0 {
            return "\(confirmedCount) 已确认卡"
        }
        if pendingCount > 0 {
            return "\(pendingCount) 待确认卡"
        }
        if !excludedCards.isEmpty {
            return "\(excludedCards.count) 已排除卡"
        }
        return "无卡片"
    }

    var hasCardEvidence: Bool {
        !confirmedCards.isEmpty
    }

    var hasTaskEvidence: Bool {
        !quests.isEmpty
    }

    var hasVerificationEvidence: Bool {
        verification != nil
    }

    var hasPrincipleEvidence: Bool {
        !principles.isEmpty
    }

    var hasSummaryEvidence: Bool {
        lensSession != nil || !growthContributions.isEmpty || !projectLinks.isEmpty
    }

    var hasHistoricalRepairBlockingEvidence: Bool {
        hasCardEvidence ||
            hasTaskEvidence ||
            hasVerificationEvidence ||
            hasPrincipleEvidence ||
            hasSummaryEvidence
    }

    var sourceIds: [String] {
        var ids: [String] = [draft.id.uuidString]
        ids.append(contentsOf: cards.map { $0.id.uuidString })
        ids.append(contentsOf: quests.map { $0.id.uuidString })
        if let verification { ids.append(verification.id.uuidString) }
        ids.append(contentsOf: principles.map { $0.id.uuidString })
        return ids
    }

    init(
        draft: DailyEntryDraft,
        cards: [ThinkingCard] = [],
        quests: [Quest] = [],
        principles: [PrincipleAsset] = [],
        verification: Verification? = nil,
        lensSession: LensSession? = nil,
        projectLinks: [ProjectLink] = [],
        growthContributions: [MetricContribution] = []
    ) {
        self.draft = draft
        self.cards = cards
        self.quests = quests
        self.principles = principles
        self.verification = verification
        self.lensSession = lensSession
        self.projectLinks = projectLinks
        self.growthContributions = growthContributions
    }
}

enum HistoryEvidenceFilter: String, CaseIterable, Identifiable {
    case all
    case cards
    case tasks
    case verification
    case principles
    case project
    case growth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .cards: return "卡片"
        case .tasks: return "任务"
        case .verification: return "验证"
        case .principles: return "原则"
        case .project: return "项目"
        case .growth: return "成长"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .cards: return "rectangle.stack"
        case .tasks: return "checkmark.circle"
        case .verification: return "scope"
        case .principles: return "bookmark"
        case .project: return "folder"
        case .growth: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct HistorySearchQuery: Hashable {
    var text: String
    var filter: HistoryEvidenceFilter
    var projectId: UUID?
    var lens: ThinkingLens?
    var cardType: ThinkingCardType?
    var questStatus: QuestStatus?

    init(
        text: String = "",
        filter: HistoryEvidenceFilter = .all,
        projectId: UUID? = nil,
        lens: ThinkingLens? = nil,
        cardType: ThinkingCardType? = nil,
        questStatus: QuestStatus? = nil
    ) {
        self.text = text
        self.filter = filter
        self.projectId = projectId
        self.lens = lens
        self.cardType = cardType
        self.questStatus = questStatus
    }

    var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isActive: Bool {
        !normalizedText.isEmpty ||
            filter != .all ||
            projectId != nil ||
            lens != nil ||
            cardType != nil ||
            questStatus != nil
    }

    func apply(to records: [HistoryRecord]) -> [HistoryRecord] {
        records.filter { record in
            matchesFilter(record) &&
                matchesAdvancedFilters(record) &&
                matchesText(record)
        }
    }

    private func matchesFilter(_ record: HistoryRecord) -> Bool {
        switch filter {
        case .all:
            return true
        case .cards:
            return !record.cards.isEmpty
        case .tasks:
            return !record.quests.isEmpty
        case .verification:
            return record.verification != nil
        case .principles:
            return !record.principles.isEmpty
        case .project:
            return !record.projectLinks.isEmpty
        case .growth:
            return !record.growthContributions.isEmpty
        }
    }

    private func matchesAdvancedFilters(_ record: HistoryRecord) -> Bool {
        if let projectId, !record.projectLinks.contains(where: { $0.projectId == projectId }) {
            return false
        }
        if let lens, record.lensSession?.selectedLens != lens {
            return false
        }
        if let cardType, !record.cards.contains(where: { $0.type == cardType }) {
            return false
        }
        if let questStatus, !record.quests.contains(where: { $0.status == questStatus }) {
            return false
        }
        return true
    }

    private func matchesText(_ record: HistoryRecord) -> Bool {
        let query = normalizedText
        guard !query.isEmpty else { return true }
        return searchableText(for: record).contains(query)
    }

    private func searchableText(for record: HistoryRecord) -> String {
        var parts: [String] = [
            record.draft.rawText,
            record.draft.state.title,
            record.draft.sessionMode.title
        ]

        parts.append(contentsOf: record.cards.flatMap { card in
            [card.type.title, card.title, card.body, card.priority.rawValue, card.sensitivity.rawValue]
        })

        parts.append(contentsOf: record.quests.flatMap { quest in
            [
                quest.type.title,
                quest.title,
                quest.whyItMatters,
                quest.completionCriteria,
                quest.expectedResistance,
                quest.reflectionQuestion,
                quest.status.rawValue
            ]
        })

        parts.append(contentsOf: record.principles.flatMap { principle in
            [
                principle.title,
                principle.summary,
                principle.triggerContext,
                principle.successCriteria,
                principle.exceptions
            ] + principle.actions
        })

        if let verification = record.verification {
            parts.append(contentsOf: [
                verification.questTitle,
                verification.completion.title,
                verification.valueRating.title,
                verification.calibrationNote,
                verification.likelyIssue ?? "",
                verification.recommendation ?? ""
            ])
        }

        if let lensSession = record.lensSession {
            parts.append(contentsOf: [
                lensSession.selectedLens.title,
                lensSession.selectedLens.subtitle
            ])
            parts.append(contentsOf: lensSession.questions.flatMap { question in
                [question.question, question.answer, question.whyItMatters]
            })
        }

        parts.append(contentsOf: record.projectLinks.flatMap { link in
            [link.sourceType.rawValue, link.linkType.title]
        })

        parts.append(contentsOf: record.growthContributions.flatMap { contribution in
            [
                contribution.metric.rawValue,
                contribution.direction.rawValue,
                contribution.title,
                contribution.reason,
                contribution.sourceType.rawValue
            ]
        })

        return parts.joined(separator: "\n").lowercased()
    }
}

struct HistoryDeepLink: Identifiable, Equatable {
    let id: UUID
    let dailyEntryId: UUID
    let sourceId: String?
    let sourceType: MetricContributionSourceType?

    init(
        id: UUID = UUID(),
        dailyEntryId: UUID,
        sourceId: String? = nil,
        sourceType: MetricContributionSourceType? = nil
    ) {
        self.id = id
        self.dailyEntryId = dailyEntryId
        self.sourceId = sourceId
        self.sourceType = sourceType
    }
}

// MARK: - Project Evidence Layer

enum ProjectStatus: String, CaseIterable, Identifiable {
    case active
    case watching
    case paused
    case archived

    var id: String { rawValue }
}

enum ProjectCandidateStatus: String, CaseIterable, Identifiable {
    case pending
    case accepted
    case renamedAndAccepted = "renamed_and_accepted"
    case dismissed
    case rejected

    var id: String { rawValue }
}

enum ProjectCreatedBy: String, CaseIterable, Identifiable {
    case user
    case aiSuggested = "ai_suggested"

    var id: String { rawValue }
}

enum ProjectSourceType: String, CaseIterable, Identifiable {
    case dailyEntry = "daily_entry"
    case thinkingCard = "thinking_card"
    case quest
    case verification
    case principle

    var id: String { rawValue }
}

enum ProjectLinkType: String, CaseIterable, Identifiable {
    case evidence
    case blocker
    case decision
    case task
    case principle
    case risk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .evidence: return "证据"
        case .blocker: return "阻塞"
        case .decision: return "决策"
        case .task: return "任务"
        case .principle: return "原则"
        case .risk: return "风险"
        }
    }
}

enum ProjectMergeStatus: String, CaseIterable, Identifiable {
    case pending
    case accepted
    case rejected
    case dismissed

    var id: String { rawValue }
}

enum ProjectInsightType: String, CaseIterable, Identifiable {
    case progress
    case blockerChange = "blocker_change"
    case thinkingChange = "thinking_change"
    case openQuestionClosed = "open_question_closed"
    case principlePracticed = "principle_practiced"
    case nextBet = "next_bet"

    var id: String { rawValue }
}

enum ProjectFeedback: String, CaseIterable, Identifiable {
    case accepted
    case inaccurate
    case dismissed
    case none

    var id: String { rawValue }
}

struct Project: Identifiable, Hashable {
    let id: UUID
    var name: String
    var goal: String
    var successCriteria: String
    var currentBottleneck: String?
    var openQuestions: [String]
    var status: ProjectStatus
    var createdBy: ProjectCreatedBy
    var confidence: Double
    var mergeHistory: [String]
    var fieldRevisions: [String: String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        goal: String,
        successCriteria: String,
        currentBottleneck: String? = nil,
        openQuestions: [String] = [],
        status: ProjectStatus = .active,
        createdBy: ProjectCreatedBy = .user,
        confidence: Double = 1,
        mergeHistory: [String] = [],
        fieldRevisions: [String: String] = [:],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.successCriteria = successCriteria
        self.currentBottleneck = currentBottleneck
        self.openQuestions = openQuestions
        self.status = status
        self.createdBy = createdBy
        self.confidence = confidence
        self.mergeHistory = mergeHistory
        self.fieldRevisions = fieldRevisions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProjectCandidate: Identifiable, Hashable {
    let id: UUID
    var suggestedName: String
    var suggestedGoal: String?
    var suggestedBottleneck: String?
    var suggestedSuccessCriteria: String?
    var reason: String
    var sourceRefs: [String]
    var privacyReviewNote: String?
    var status: ProjectCandidateStatus
    var acceptedProjectId: UUID?
    var createdBy: ProjectCreatedBy
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        suggestedName: String,
        suggestedGoal: String? = nil,
        suggestedBottleneck: String? = nil,
        suggestedSuccessCriteria: String? = nil,
        reason: String,
        sourceRefs: [String],
        privacyReviewNote: String? = nil,
        status: ProjectCandidateStatus = .pending,
        acceptedProjectId: UUID? = nil,
        createdBy: ProjectCreatedBy = .aiSuggested,
        confidence: Double = 0.75,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.suggestedName = suggestedName
        self.suggestedGoal = suggestedGoal
        self.suggestedBottleneck = suggestedBottleneck
        self.suggestedSuccessCriteria = suggestedSuccessCriteria
        self.reason = reason
        self.sourceRefs = sourceRefs
        self.privacyReviewNote = privacyReviewNote
        self.status = status
        self.acceptedProjectId = acceptedProjectId
        self.createdBy = createdBy
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProjectLinkCandidate: Identifiable, Hashable {
    let id: UUID
    var projectId: UUID?
    var candidateProjectName: String?
    var sourceType: ProjectSourceType
    var sourceId: String
    var linkType: ProjectLinkType
    var reason: String
    var confidence: Double
    var requiresUserConfirmation: Bool
    var isUserConfirmed: Bool { false }

    init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        candidateProjectName: String? = nil,
        sourceType: ProjectSourceType,
        sourceId: String,
        linkType: ProjectLinkType,
        reason: String,
        confidence: Double = 0.75,
        requiresUserConfirmation: Bool = true
    ) {
        self.id = id
        self.projectId = projectId
        self.candidateProjectName = candidateProjectName
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.linkType = linkType
        self.reason = reason
        self.confidence = confidence
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

struct ProjectSuggestionResult: Hashable {
    var linkCandidates: [ProjectLinkCandidate]
    var newProjectCandidates: [ProjectCandidate]

    var projectLinks: [ProjectLinkCandidate] { linkCandidates }
    var projectCandidates: [ProjectCandidate] { newProjectCandidates }
}

struct ProjectLink: Identifiable, Hashable {
    let id: UUID
    var projectId: UUID
    var sourceType: ProjectSourceType
    var sourceId: String
    var linkType: ProjectLinkType
    var confidence: Double
    var isUserConfirmed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectId: UUID,
        sourceType: ProjectSourceType,
        sourceId: String,
        linkType: ProjectLinkType,
        confidence: Double = 0.75,
        isUserConfirmed: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.projectId = projectId
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.linkType = linkType
        self.confidence = confidence
        self.isUserConfirmed = isUserConfirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProjectMergeCandidate: Identifiable, Hashable {
    let id: UUID
    var sourceProjectId: UUID
    var targetProjectId: UUID
    var reason: String
    var overlappingEvidenceRefs: [String]
    var status: ProjectMergeStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceProjectId: UUID,
        targetProjectId: UUID,
        reason: String,
        overlappingEvidenceRefs: [String] = [],
        status: ProjectMergeStatus = .pending,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sourceProjectId = sourceProjectId
        self.targetProjectId = targetProjectId
        self.reason = reason
        self.overlappingEvidenceRefs = overlappingEvidenceRefs
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProjectInsightsResult: Hashable {
    var insights: [ProjectInsight]
    var insufficientEvidenceReason: String?
}

struct ProjectInsight: Identifiable, Hashable {
    let id: UUID
    var projectId: UUID
    var insightType: ProjectInsightType
    var title: String
    var summary: String
    var beforeText: String?
    var afterText: String?
    var sourceRefs: [String]
    var periodStart: Date?
    var periodEnd: Date?
    var confidence: Double
    var userFeedback: ProjectFeedback
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectId: UUID,
        insightType: ProjectInsightType,
        title: String,
        summary: String,
        beforeText: String? = nil,
        afterText: String? = nil,
        sourceRefs: [String],
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        confidence: Double = 0.75,
        userFeedback: ProjectFeedback = .none,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.projectId = projectId
        self.insightType = insightType
        self.title = title
        self.summary = summary
        self.beforeText = beforeText
        self.afterText = afterText
        self.sourceRefs = sourceRefs
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.confidence = confidence
        self.userFeedback = userFeedback
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ProjectEvidenceSignalKind: String, CaseIterable, Identifiable {
    case done
    case learned
    case unblocked
    case newlyBlocked
    case newRisk
    case nextBet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .done: return "Done"
        case .learned: return "Learned"
        case .unblocked: return "Unblocked"
        case .newlyBlocked: return "Newly Blocked"
        case .newRisk: return "Risk"
        case .nextBet: return "Next Bet"
        }
    }
}

struct ProjectEvidenceSignal: Identifiable, Hashable {
    let id: UUID
    var kind: ProjectEvidenceSignalKind
    var title: String
    var detail: String
    var sourceId: String
    var sourceType: ProjectSourceType
    var dailyEntryId: UUID
    var date: Date

    init(
        id: UUID = UUID(),
        kind: ProjectEvidenceSignalKind,
        title: String,
        detail: String,
        sourceId: String,
        sourceType: ProjectSourceType,
        dailyEntryId: UUID,
        date: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.sourceId = sourceId
        self.sourceType = sourceType
        self.dailyEntryId = dailyEntryId
        self.date = date
    }
}

struct ProjectEvidenceDigest: Hashable {
    let projectId: UUID
    var progressSignals: [ProjectEvidenceSignal]
    var nextBet: String?
    var evidenceGapMessage: String
    var hasBeforeAfterEvidence: Bool

    init(projectId: UUID, evidence: [(link: ProjectLink, record: HistoryRecord)]) {
        self.projectId = projectId

        let orderedEvidence = evidence
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.record.draft.date == rhs.element.record.draft.date {
                    if lhs.element.link.updatedAt == rhs.element.link.updatedAt {
                        return lhs.offset < rhs.offset
                    }
                    return lhs.element.link.updatedAt > rhs.element.link.updatedAt
                }
                return lhs.element.record.draft.date > rhs.element.record.draft.date
            }
            .map(\.element)

        progressSignals = orderedEvidence.map { entry in
            let sourceTitle = Self.sourceTitle(for: entry.link, in: entry.record)
            return ProjectEvidenceSignal(
                kind: Self.signalKind(for: entry.link),
                title: sourceTitle,
                detail: Self.signalDetail(for: entry.link, title: sourceTitle, record: entry.record),
                sourceId: entry.link.sourceId,
                sourceType: entry.link.sourceType,
                dailyEntryId: entry.record.draft.id,
                date: entry.record.draft.date
            )
        }

        nextBet = Self.deriveNextBet(from: orderedEvidence)
        hasBeforeAfterEvidence = orderedEvidence.count >= 2
        evidenceGapMessage = Self.evidenceGapMessage(
            evidenceCount: orderedEvidence.count,
            hasTaskEvidence: orderedEvidence.contains { $0.link.linkType == .task || $0.link.sourceType == .quest },
            hasBeforeAfterEvidence: hasBeforeAfterEvidence
        )
    }

    var latestSignal: ProjectEvidenceSignal? {
        progressSignals.first
    }

    private static func signalKind(for link: ProjectLink) -> ProjectEvidenceSignalKind {
        switch link.linkType {
        case .task:
            return .done
        case .blocker:
            return .newlyBlocked
        case .risk:
            return .newRisk
        case .principle, .decision, .evidence:
            return .learned
        }
    }

    private static func signalDetail(for link: ProjectLink, title: String, record: HistoryRecord) -> String {
        switch link.linkType {
        case .task:
            if let quest = record.quests.first(where: { $0.id.uuidString == link.sourceId }),
               !quest.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "下一次验证：\(quest.completionCriteria)"
            }
            return "这条任务证据可以作为项目推进的行动记录。"
        case .blocker:
            return "阻塞证据需要后续任务或验证确认是否被移除。"
        case .risk:
            return "风险证据需要后续决策或行动降低不确定性。"
        case .decision:
            return "决策证据记录了当前判断，应在后续验证它是否改变结果。"
        case .principle:
            return "原则证据可以转化为后续稳定行动标准。"
        case .evidence:
            return "证据已记录：\(title)"
        }
    }

    private static func sourceTitle(for link: ProjectLink, in record: HistoryRecord) -> String {
        switch link.sourceType {
        case .dailyEntry:
            let text = record.draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "当日复盘记录" : String(text.prefix(80))
        case .thinkingCard:
            return record.cards.first { $0.id.uuidString == link.sourceId }?.title ?? "思考卡片"
        case .quest:
            return record.quests.first { $0.id.uuidString == link.sourceId }?.title ?? "明日任务"
        case .verification:
            return record.verification?.calibrationNote ?? "次日验证"
        case .principle:
            return record.principles.first { $0.id.uuidString == link.sourceId }?.title ?? "原则资产"
        }
    }

    private static func deriveNextBet(from evidence: [(link: ProjectLink, record: HistoryRecord)]) -> String? {
        for entry in evidence {
            if let quest = entry.record.quests.first(where: { $0.id.uuidString == entry.link.sourceId }) {
                return "验证：\(quest.title)"
            }
        }

        for entry in evidence where entry.link.linkType == .blocker || entry.link.linkType == .risk {
            let title = sourceTitle(for: entry.link, in: entry.record)
            return "降低不确定性：\(title)"
        }

        for entry in evidence where entry.link.linkType == .decision {
            let title = sourceTitle(for: entry.link, in: entry.record)
            return "验证判断：\(title)"
        }

        return nil
    }

    private static func evidenceGapMessage(
        evidenceCount: Int,
        hasTaskEvidence: Bool,
        hasBeforeAfterEvidence: Bool
    ) -> String {
        var gaps: [String] = []
        if !hasTaskEvidence {
            gaps.append("缺少任务或验证证据")
        }
        if !hasBeforeAfterEvidence {
            gaps.append("缺少 before / after 对照证据")
        }
        if evidenceCount == 0 {
            gaps.append("缺少已确认来源")
        }
        return gaps.isEmpty ? "证据链可继续积累。" : gaps.joined(separator: "；")
    }
}
