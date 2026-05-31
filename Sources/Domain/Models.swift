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

enum ThinkingLens: String, CaseIterable, Identifiable {
    case evidenceCheck
    case opposingView
    case leverageAnalysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .evidenceCheck: return "Evidence Check"
        case .opposingView: return "Opposing View"
        case .leverageAnalysis: return "Leverage Analysis"
        }
    }

    var subtitle: String {
        switch self {
        case .evidenceCheck: return "把事实、判断和假设区分开。"
        case .opposingView: return "主动寻找支持相反结论的证据。"
        case .leverageAnalysis: return "找出最能改变结果的一步。"
        }
    }
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

struct ReflectionQuestion: Identifiable, Hashable {
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

enum PrincipleStatus: String, CaseIterable, Identifiable {
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

struct MetricSnapshot: Identifiable, Hashable {
    let id: UUID
    var period: String
    var clarity: Double
    var valueJudgment: Double
    var executionReliability: Double
    var calibration: Double
    var reflectionDepth: Double
    var summary: String

    init(
        id: UUID = UUID(),
        period: String,
        clarity: Double,
        valueJudgment: Double,
        executionReliability: Double,
        calibration: Double,
        reflectionDepth: Double,
        summary: String
    ) {
        self.id = id
        self.period = period
        self.clarity = clarity
        self.valueJudgment = valueJudgment
        self.executionReliability = executionReliability
        self.calibration = calibration
        self.reflectionDepth = reflectionDepth
        self.summary = summary
    }
}
