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

enum LensAccentRole: String, Codable, CaseIterable {
    case graphite
    case brick
    case accent
    case principle
}

enum LensAssetSourceKind: String, Codable, CaseIterable {
    case builtin
    case localCustom
    case imported
    case marketplace

    var requiresTrustMetadata: Bool {
        switch self {
        case .builtin, .localCustom:
            return false
        case .imported, .marketplace:
            return true
        }
    }
}

enum PromptAssetSourceKind: String, Codable, CaseIterable {
    case builtin
    case localCustom
    case imported
    case marketplace

    var requiresTrustMetadata: Bool {
        switch self {
        case .builtin, .localCustom:
            return false
        case .imported, .marketplace:
            return true
        }
    }
}

struct AssetTrustMetadata: Codable, Hashable {
    let publisherId: String
    let contentHash: String
    let signature: String
    let trustedAt: String
    let verificationPolicyVersion: String

    init(
        publisherId: String,
        contentHash: String,
        signature: String,
        trustedAt: String,
        verificationPolicyVersion: String
    ) {
        self.publisherId = publisherId
        self.contentHash = contentHash
        self.signature = signature
        self.trustedAt = trustedAt
        self.verificationPolicyVersion = verificationPolicyVersion
    }

    var missingRequiredFields: [String] {
        [
            ("publisherId", publisherId),
            ("contentHash", contentHash),
            ("signature", signature),
            ("trustedAt", trustedAt),
            ("verificationPolicyVersion", verificationPolicyVersion)
        ].compactMap { field, value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? field : nil
        }
    }
}

struct PromptAssetPack: Codable, Hashable {
    let id: String
    let version: String
    let displayName: String
    let sourceKind: PromptAssetSourceKind
    let isEnabled: Bool
    let templates: [PromptTemplate]
    let trustMetadata: AssetTrustMetadata?

    init(
        id: String,
        version: String,
        displayName: String,
        sourceKind: PromptAssetSourceKind,
        isEnabled: Bool = true,
        templates: [PromptTemplate],
        trustMetadata: AssetTrustMetadata? = nil
    ) {
        self.id = id
        self.version = version
        self.displayName = displayName
        self.sourceKind = sourceKind
        self.isEnabled = isEnabled
        self.templates = templates
        self.trustMetadata = trustMetadata
    }
}

struct LensCatalogItem: Codable, Hashable {
    struct UIMetadata: Codable, Hashable {
        let symbolName: String
        let accentRole: LensAccentRole
        let methodIndex: Int
    }

    let lensId: String
    let promptId: String
    let version: String
    let title: String
    let subtitle: String
    let shortLabel: String
    let methodLine: String
    let promptGuidance: String
    let symbolName: String
    let recommendedReason: String
    let questionSeeds: [String]
    let accentRole: LensAccentRole
    let methodIndex: Int
    let purpose: String
    let questionStrategy: String
    let taskSelectionRule: String
    let applicability: String
    let disableConditions: [String]
    let uiMetadata: UIMetadata
    let sourceKind: LensAssetSourceKind
    let packId: String
    let packVersion: String
    let packDisplayName: String

    var id: String { lensId }
    var isBuiltIn: Bool { sourceKind == .builtin }

    init(
        lensId: String,
        promptId: String,
        version: String,
        title: String,
        subtitle: String,
        shortLabel: String,
        methodLine: String,
        promptGuidance: String,
        symbolName: String,
        recommendedReason: String,
        questionSeeds: [String],
        accentRole: LensAccentRole,
        methodIndex: Int,
        purpose: String? = nil,
        questionStrategy: String? = nil,
        taskSelectionRule: String? = nil,
        applicability: String? = nil,
        disableConditions: [String]? = nil,
        uiMetadata: UIMetadata? = nil,
        sourceKind: LensAssetSourceKind = .localCustom,
        packId: String = Self.defaultCustomPackId,
        packVersion: String? = nil,
        packDisplayName: String = Self.defaultCustomPackDisplayName
    ) {
        self.lensId = lensId
        self.promptId = promptId
        self.version = version
        self.title = title
        self.subtitle = subtitle
        self.shortLabel = shortLabel
        self.methodLine = methodLine
        self.promptGuidance = promptGuidance
        self.symbolName = symbolName
        self.recommendedReason = recommendedReason
        self.questionSeeds = questionSeeds
        self.accentRole = accentRole
        self.methodIndex = methodIndex
        self.purpose = purpose ?? subtitle
        self.questionStrategy = questionStrategy ?? promptGuidance
        self.taskSelectionRule = taskSelectionRule ?? Self.defaultTaskSelectionRule
        self.applicability = applicability ?? recommendedReason
        self.disableConditions = disableConditions ?? Self.defaultDisableConditions
        self.uiMetadata = uiMetadata ?? UIMetadata(
            symbolName: symbolName,
            accentRole: accentRole,
            methodIndex: methodIndex
        )
        self.sourceKind = sourceKind
        self.packId = packId
        self.packVersion = packVersion ?? Self.defaultPackVersion(for: sourceKind, itemVersion: version)
        self.packDisplayName = packDisplayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lensId = try container.decode(String.self, forKey: .lensId)
        let promptId = try container.decode(String.self, forKey: .promptId)
        let version = try container.decode(String.self, forKey: .version)
        let title = try container.decode(String.self, forKey: .title)
        let subtitle = try container.decode(String.self, forKey: .subtitle)
        let shortLabel = try container.decode(String.self, forKey: .shortLabel)
        let methodLine = try container.decode(String.self, forKey: .methodLine)
        let promptGuidance = try container.decode(String.self, forKey: .promptGuidance)
        let symbolName = try container.decode(String.self, forKey: .symbolName)
        let recommendedReason = try container.decode(String.self, forKey: .recommendedReason)
        let questionSeeds = try container.decode([String].self, forKey: .questionSeeds)
        let accentRole = try container.decode(LensAccentRole.self, forKey: .accentRole)
        let methodIndex = try container.decode(Int.self, forKey: .methodIndex)

        self.init(
            lensId: lensId,
            promptId: promptId,
            version: version,
            title: title,
            subtitle: subtitle,
            shortLabel: shortLabel,
            methodLine: methodLine,
            promptGuidance: promptGuidance,
            symbolName: symbolName,
            recommendedReason: recommendedReason,
            questionSeeds: questionSeeds,
            accentRole: accentRole,
            methodIndex: methodIndex,
            purpose: try container.decodeIfPresent(String.self, forKey: .purpose),
            questionStrategy: try container.decodeIfPresent(String.self, forKey: .questionStrategy),
            taskSelectionRule: try container.decodeIfPresent(String.self, forKey: .taskSelectionRule),
            applicability: try container.decodeIfPresent(String.self, forKey: .applicability),
            disableConditions: try container.decodeIfPresent([String].self, forKey: .disableConditions),
            uiMetadata: try container.decodeIfPresent(UIMetadata.self, forKey: .uiMetadata),
            sourceKind: try container.decodeIfPresent(LensAssetSourceKind.self, forKey: .sourceKind) ?? .localCustom,
            packId: try container.decodeIfPresent(String.self, forKey: .packId) ?? Self.defaultCustomPackId,
            packVersion: try container.decodeIfPresent(String.self, forKey: .packVersion),
            packDisplayName: try container.decodeIfPresent(String.self, forKey: .packDisplayName) ?? Self.defaultCustomPackDisplayName
        )
    }

    private static let defaultTaskSelectionRule = "Use this lens to choose a next action grounded in the user's confirmed cards."
    private static let defaultDisableConditions = ["Do not use when the user has not selected this custom lens."]
    private static let defaultCustomPackId = "local.custom-lenses"
    private static let defaultCustomPackVersion = "session.v1"
    private static let defaultCustomPackDisplayName = "Local Custom Lenses"

    private static func defaultPackVersion(for sourceKind: LensAssetSourceKind, itemVersion: String) -> String {
        sourceKind == .localCustom ? defaultCustomPackVersion : itemVersion
    }

    func applyingPackMetadata(_ pack: LensAssetPack) -> LensCatalogItem {
        LensCatalogItem(
            lensId: lensId,
            promptId: promptId,
            version: version,
            title: title,
            subtitle: subtitle,
            shortLabel: shortLabel,
            methodLine: methodLine,
            promptGuidance: promptGuidance,
            symbolName: symbolName,
            recommendedReason: recommendedReason,
            questionSeeds: questionSeeds,
            accentRole: accentRole,
            methodIndex: methodIndex,
            purpose: purpose,
            questionStrategy: questionStrategy,
            taskSelectionRule: taskSelectionRule,
            applicability: applicability,
            disableConditions: disableConditions,
            uiMetadata: uiMetadata,
            sourceKind: pack.sourceKind,
            packId: pack.id,
            packVersion: pack.version,
            packDisplayName: pack.displayName
        )
    }
}

struct LensAssetPack: Codable, Hashable {
    let id: String
    let version: String
    let displayName: String
    let sourceKind: LensAssetSourceKind
    let isEnabled: Bool
    let items: [LensCatalogItem]
    let trustMetadata: AssetTrustMetadata?

    init(
        id: String,
        version: String,
        displayName: String,
        sourceKind: LensAssetSourceKind,
        isEnabled: Bool = true,
        items: [LensCatalogItem],
        trustMetadata: AssetTrustMetadata? = nil
    ) {
        self.id = id
        self.version = version
        self.displayName = displayName
        self.sourceKind = sourceKind
        self.isEnabled = isEnabled
        self.items = items
        self.trustMetadata = trustMetadata
    }

    var stampedItems: [LensCatalogItem] {
        guard isEnabled else { return [] }
        return items.map { $0.applyingPackMetadata(self) }
    }
}

protocol LensCatalogProviding {
    var items: [LensCatalogItem] { get }
    func item(localId: String) -> LensCatalogItem?
    func item(promptId: String) -> LensCatalogItem?
    func item(for lens: ThinkingLens) -> LensCatalogItem?
    func recommendedItem(for cards: [ThinkingCard], mode: SessionMode) -> LensCatalogItem?
}

struct LensLibrary: LensCatalogProviding {
    let items: [LensCatalogItem]

    init(items: [LensCatalogItem]) {
        self.items = items
    }

    init(packs: [LensAssetPack]) {
        self.items = packs.flatMap(\.stampedItems)
    }

    func item(localId: String) -> LensCatalogItem? {
        items.first { $0.lensId == localId }
    }

    func item(promptId: String) -> LensCatalogItem? {
        items.first { $0.promptId == promptId }
    }

    func item(for lens: ThinkingLens) -> LensCatalogItem? {
        item(localId: lens.rawValue)
    }

    func recommendedItem(for cards: [ThinkingCard], mode: SessionMode) -> LensCatalogItem? {
        let consideredCards = cards.filter { !$0.isExcludedFromModel }
        guard !consideredCards.isEmpty else {
            return items.sorted { $0.methodIndex < $1.methodIndex }.first
        }

        let counts = Dictionary(grouping: consideredCards, by: \.type).mapValues(\.count)
        let highPriorityTypes = Set(consideredCards.filter { $0.priority == .high }.map(\.type))
        let riskProblemCount = (counts[.risk] ?? 0) + (counts[.problem] ?? 0)
        let actionCount = (counts[.task] ?? 0) + (counts[.decision] ?? 0)
        let validationCount = (counts[.fact] ?? 0) + riskProblemCount
        let dominantCount = counts.values.max() ?? 0

        if validationCount >= 2 && !highPriorityTypes.isDisjoint(with: [.fact, .risk, .problem]) {
            return item(for: .evidenceCheck)
        }

        if mode == .deep && riskProblemCount >= 2 {
            return item(for: .opposingView)
        }

        if actionCount >= 2 && actionCount >= riskProblemCount {
            return item(for: .leverageAnalysis)
        }

        if dominantCount <= 1 {
            return item(for: .firstPrinciples)
        }

        return item(for: .firstPrinciples)
    }
}

enum BuiltinLensCatalog {
    private static let pack = LensAssetPack(
        id: "mingsi.builtin.lenses",
        version: "builtin.v1",
        displayName: "MingSi Built-in Lens Pack",
        sourceKind: .builtin,
        items: builtinItems
    )

    static let library = LensLibrary(packs: [pack])

    private static let builtinItems = [
        LensCatalogItem(
            lensId: "evidenceCheck",
            promptId: "evidence_check",
            version: "builtin.v1",
            title: "证据校验",
            subtitle: "把事实、判断和假设分开，先清理地基。",
            shortLabel: "事实",
            methodLine: "先问：我知道什么，还是我以为什么？",
            promptGuidance: "Separate facts, interpretations, assumptions, and validation gaps before asking the user to decide.",
            symbolName: "checklist",
            recommendedReason: "当前材料里有事实、风险或问题需要先验清依据。",
            questionSeeds: [
                "我知道什么，还是我以为什么？",
                "哪条判断现在缺少可验证证据？",
                "如果只保留事实，这件事还剩什么？"
            ],
            accentRole: .graphite,
            methodIndex: 1,
            purpose: "把事实、判断、假设和待验证缺口拆开，避免在证据不足时推进决策。",
            questionStrategy: "先要求用户区分已知事实和解释性判断，再找出最需要补证据的一处。",
            taskSelectionRule: "优先生成能补齐关键证据、确认验收口径或降低事实不确定性的明日任务。",
            applicability: "适用于事实、风险、问题或高优先级卡片较多，且当前判断依赖未验证依据的场景。",
            disableConditions: [
                "不要用于用户已经明确选择其他透镜的请求。",
                "不要把未经确认的推测包装成事实。",
                "不要要求用户暴露公司、客户或个人敏感细节。"
            ]
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
            symbolName: "arrow.left.arrow.right",
            recommendedReason: "当前材料里问题和风险偏多，适合先挑战默认判断。",
            questionSeeds: [
                "如果我错了，证据会长什么样？",
                "谁会不同意这个判断，理由是什么？",
                "有没有一个更便宜的解释？"
            ],
            accentRole: .brick,
            methodIndex: 2,
            purpose: "主动寻找反证、替代解释和被忽略的利益相关方，降低只证明自己正确的风险。",
            questionStrategy: "先让用户描述相反证据会是什么，再追问谁会不同意以及最强反方理由。",
            taskSelectionRule: "优先生成能验证关键反方假设、暴露盲点或让不同角色参与校准的明日任务。",
            applicability: "适用于问题和风险偏多、用户判断较强、或 Deep 模式下需要挑战默认解释的场景。",
            disableConditions: [
                "不要为了反对而反对，必须回到当天确认卡片。",
                "不要把反方视角变成替用户否定自己。",
                "不要在事实明显不足时输出确定性结论。"
            ]
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
            symbolName: "point.topleft.down.curvedto.point.bottomright.up",
            recommendedReason: "当前材料已经出现任务或决策，适合收敛最高杠杆动作。",
            questionSeeds: [
                "哪一步最能改变结果？",
                "如果只做一件事，哪件事会让其他事变简单？",
                "当前真正卡住结果的约束是什么？"
            ],
            accentRole: .accent,
            methodIndex: 3,
            purpose: "识别最小但最能改变结果的动作、约束或决策，避免把容易完成误判为高价值。",
            questionStrategy: "先比较不同动作的结果影响，再排除低杠杆忙碌，最后收敛一个关键约束。",
            taskSelectionRule: "优先生成能改变关键结果、解除瓶颈或让后续动作变简单的明日主线任务。",
            applicability: "适用于任务、决策或行动卡片较多，且用户需要从多个动作中选择下一步的场景。",
            disableConditions: [
                "不要在事实和验收口径明显不清时跳过证据校验。",
                "不要把轻松完成当作高杠杆。",
                "不要生成多个并列主线任务。"
            ]
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
            symbolName: "square.stack.3d.down.right",
            recommendedReason: "当前材料没有单一主导类型，适合先拆前提和硬约束。",
            questionSeeds: [
                "如果从零开始，这件事必须成立的条件是什么？",
                "哪些规则是事实，哪些只是沿用的假设？",
                "去掉默认做法后，最小可行动作是什么？"
            ],
            accentRole: .principle,
            methodIndex: 4,
            purpose: "拆掉默认前提，保留不可再拆的事实、约束和目标，再从这些基本条件重建下一步。",
            questionStrategy: "先识别硬事实和不可变约束，再分离沿用假设，最后从零重建一个最小行动。",
            taskSelectionRule: "优先生成能验证核心前提、澄清必要条件或重建行动路径的明日任务。",
            applicability: "适用于卡片类型没有明显主导、前提混杂、或用户需要重新定义问题的场景。",
            disableConditions: [
                "不要用抽象原则替代当天具体证据。",
                "不要把复杂问题简化成口号。",
                "不要在用户只需要快速执行时过度拆解。"
            ]
        ),
    ]

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

enum PrincipleRecallFeedbackValue: String, CaseIterable, Identifiable, Codable {
    case helpful
    case notApplicable = "not_applicable"
    case misrecalled

    var id: String { rawValue }
}

struct PrincipleRecallFeedback: Identifiable, Hashable {
    let id: UUID
    var schemaVersion: Int
    var principleId: UUID
    var promptRunId: UUID?
    var sourceDailyEntryId: UUID?
    var promptId: PromptID
    var retrievalPolicyVersion: String
    var retrievalReason: String
    var feedback: PrincipleRecallFeedbackValue
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        principleId: UUID,
        promptRunId: UUID? = nil,
        sourceDailyEntryId: UUID? = nil,
        promptId: PromptID,
        retrievalPolicyVersion: String,
        retrievalReason: String,
        feedback: PrincipleRecallFeedbackValue,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.principleId = principleId
        self.promptRunId = promptRunId
        self.sourceDailyEntryId = sourceDailyEntryId
        self.promptId = promptId
        self.retrievalPolicyVersion = retrievalPolicyVersion
        self.retrievalReason = retrievalReason
        self.feedback = feedback
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum PrinciplePracticeEvidenceSource: String, CaseIterable, Identifiable, Codable {
    case quest
    case verification
    case manual

    var id: String { rawValue }
}

enum PrinciplePracticeEvidenceStrength: String, CaseIterable, Identifiable, Codable {
    case attempted
    case intentionalPractice = "intentional_practice"
    case internalized

    var id: String { rawValue }
}

struct PrinciplePracticeEvidence: Identifiable, Hashable {
    let id: UUID
    var schemaVersion: Int
    var principleId: UUID
    var sourceDailyEntryId: UUID
    var questId: UUID?
    var verificationId: UUID?
    var evidenceSource: PrinciplePracticeEvidenceSource
    var strength: PrinciplePracticeEvidenceStrength
    var evidenceSummary: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        principleId: UUID,
        sourceDailyEntryId: UUID,
        questId: UUID? = nil,
        verificationId: UUID? = nil,
        evidenceSource: PrinciplePracticeEvidenceSource,
        strength: PrinciplePracticeEvidenceStrength,
        evidenceSummary: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.principleId = principleId
        self.sourceDailyEntryId = sourceDailyEntryId
        self.questId = questId
        self.verificationId = verificationId
        self.evidenceSource = evidenceSource
        self.strength = strength
        self.evidenceSummary = evidenceSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum PrincipleTrainingState: String, CaseIterable, Identifiable, Codable {
    case knownButUnused = "known_but_unused"
    case consciouslyPracticed = "consciously_practiced"
    case stablyInternalized = "stably_internalized"
    case needsReview = "needs_review"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knownButUnused: return "已知未使用"
        case .consciouslyPracticed: return "有意识练习"
        case .stablyInternalized: return "稳定内化"
        case .needsReview: return "需要复审"
        }
    }
}

struct PrincipleTrainingSummary: Identifiable, Hashable {
    var id: UUID { principle.id }
    var principle: PrincipleAsset
    var state: PrincipleTrainingState
    var practiceEvidenceCount: Int
    var intentionalPracticeCount: Int
    var internalizedEvidenceCount: Int
    var helpfulRecallFeedbackCount: Int
    var negativeRecallFeedbackCount: Int
    var latestPracticeEvidenceAt: Date?

    static func summaries(
        for principles: [PrincipleAsset],
        practiceEvidence: [PrinciplePracticeEvidence],
        recallFeedback: [PrincipleRecallFeedback]
    ) -> [PrincipleTrainingSummary] {
        principles.map { principle in
            summary(
                for: principle,
                practiceEvidence: practiceEvidence.filter { $0.principleId == principle.id },
                recallFeedback: recallFeedback.filter { $0.principleId == principle.id }
            )
        }
    }

    static func summary(
        for principle: PrincipleAsset,
        practiceEvidence: [PrinciplePracticeEvidence],
        recallFeedback: [PrincipleRecallFeedback]
    ) -> PrincipleTrainingSummary {
        let helpfulCount = recallFeedback.filter { $0.feedback == .helpful }.count
        let negativeCount = recallFeedback.filter {
            $0.feedback == .notApplicable || $0.feedback == .misrecalled
        }.count
        let intentionalPracticeCount = practiceEvidence.filter {
            $0.strength == .intentionalPractice || $0.strength == .internalized
        }.count
        let internalizedEvidenceCount = practiceEvidence.filter { $0.strength == .internalized }.count
        let distinctPracticeDays = Set(practiceEvidence.map(\.sourceDailyEntryId)).count
        let latestPracticeAt = practiceEvidence.map(\.createdAt).max()
        let state: PrincipleTrainingState

        if principle.status == .needsReview || negativeCount >= 2 {
            state = .needsReview
        } else if internalizedEvidenceCount > 0 || distinctPracticeDays >= 3 {
            state = .stablyInternalized
        } else if intentionalPracticeCount > 0 || helpfulCount > 0 {
            state = .consciouslyPracticed
        } else {
            state = .knownButUnused
        }

        return PrincipleTrainingSummary(
            principle: principle,
            state: state,
            practiceEvidenceCount: practiceEvidence.count,
            intentionalPracticeCount: intentionalPracticeCount,
            internalizedEvidenceCount: internalizedEvidenceCount,
            helpfulRecallFeedbackCount: helpfulCount,
            negativeRecallFeedbackCount: negativeCount,
            latestPracticeEvidenceAt: latestPracticeAt
        )
    }
}

struct DailyEntryDraft: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var rawText: String
    var sessionMode: SessionMode
    var hasSelectedSessionMode: Bool
    var selectedLens: ThinkingLens?
    var selectedCustomLensId: String?
    var customLensItems: [LensCatalogItem]
    var customLensQuestions: [ReflectionQuestion]
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
        selectedCustomLensId: String? = nil,
        customLensItems: [LensCatalogItem] = [],
        customLensQuestions: [ReflectionQuestion] = [],
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
        self.selectedCustomLensId = selectedCustomLensId
        self.customLensItems = customLensItems
        self.customLensQuestions = customLensQuestions
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
    var promptSourceKind: PromptAssetSourceKind
    var promptPackId: String
    var promptPackVersion: String
    var promptPackDisplayName: String
    var systemPolicyVersion: String
    var contextPolicyVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var evalSuiteVersion: String
    var rollbackTargetVersion: String?
    var modelProvider: String
    var modelName: String
    var sessionMode: String
    var sourceRecordIds: [String]
    var contextRecordIds: [String]
    var requestSummary: String
    var responseJSON: String?
    var error: String?
    var userFeedback: PromptRunFeedback
    var createdAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        promptId: String,
        promptVersion: String,
        promptSourceKind: PromptAssetSourceKind = .builtin,
        promptPackId: String = "mingsi.builtin.prompts",
        promptPackVersion: String = "builtin.v1",
        promptPackDisplayName: String = "MingSi Built-in Prompt Pack",
        systemPolicyVersion: String = "system.v1",
        contextPolicyVersion: String = "context.v1",
        inputSchemaVersion: Int = 1,
        outputSchemaVersion: Int,
        evalSuiteVersion: String = "eval.v1",
        rollbackTargetVersion: String? = nil,
        modelProvider: String,
        modelName: String,
        sessionMode: String,
        sourceRecordIds: [String] = [],
        contextRecordIds: [String] = [],
        requestSummary: String,
        responseJSON: String? = nil,
        error: String? = nil,
        userFeedback: PromptRunFeedback = .none,
        createdAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.promptId = promptId
        self.promptVersion = promptVersion
        self.promptSourceKind = promptSourceKind
        self.promptPackId = promptPackId
        self.promptPackVersion = promptPackVersion
        self.promptPackDisplayName = promptPackDisplayName
        self.systemPolicyVersion = systemPolicyVersion
        self.contextPolicyVersion = contextPolicyVersion
        self.inputSchemaVersion = inputSchemaVersion
        self.outputSchemaVersion = outputSchemaVersion
        self.evalSuiteVersion = evalSuiteVersion
        self.rollbackTargetVersion = rollbackTargetVersion
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.sessionMode = sessionMode
        self.sourceRecordIds = sourceRecordIds
        self.contextRecordIds = contextRecordIds
        self.requestSummary = requestSummary
        self.responseJSON = responseJSON
        self.error = error
        self.userFeedback = userFeedback
        self.createdAt = createdAt
    }
}

enum PromptRunFeedback: String, CaseIterable, Identifiable {
    case none
    case accepted
    case denied

    var id: String { rawValue }
}

struct PromptRunStats: Hashable {
    var totalCount: Int
    var successCount: Int
    var failureCount: Int
    var emptyResultCount: Int
    var userDeniedCount: Int

    var failureRate: Double { rate(failureCount) }
    var emptyResultRate: Double { rate(emptyResultCount) }
    var userDenialRate: Double { rate(userDeniedCount) }

    private func rate(_ count: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return Double(count) / Double(totalCount)
    }
}

struct PromptAssetRunQualitySummary: Identifiable, Hashable {
    var promptId: String
    var promptVersion: String
    var promptSourceKind: PromptAssetSourceKind
    var promptPackId: String
    var promptPackVersion: String
    var promptPackDisplayName: String
    var systemPolicyVersion: String
    var contextPolicyVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var evalSuiteVersion: String
    var totalCount: Int
    var successCount: Int
    var failureCount: Int
    var emptyResultCount: Int
    var userDeniedCount: Int
    var latestRunCreatedAt: Date

    var id: String {
        [
            promptId,
            promptVersion,
            promptSourceKind.rawValue,
            promptPackId,
            promptPackVersion,
            systemPolicyVersion,
            contextPolicyVersion,
            String(inputSchemaVersion),
            String(outputSchemaVersion),
            evalSuiteVersion
        ].joined(separator: "|")
    }

    var failureRate: Double { rate(failureCount) }
    var emptyResultRate: Double { rate(emptyResultCount) }
    var userDenialRate: Double { rate(userDeniedCount) }

    static func summaries(for runs: [PromptRun]) -> [PromptAssetRunQualitySummary] {
        let grouped = Dictionary(grouping: runs, by: PromptAssetRunQualityKey.init(run:))
        return grouped
            .map { key, runs in
                PromptAssetRunQualitySummary(
                    key: key,
                    runs: runs
                )
            }
            .sorted { lhs, rhs in
                if lhs.latestRunCreatedAt == rhs.latestRunCreatedAt {
                    if lhs.promptId == rhs.promptId {
                        return lhs.promptVersion > rhs.promptVersion
                    }
                    return lhs.promptId < rhs.promptId
                }
                return lhs.latestRunCreatedAt > rhs.latestRunCreatedAt
            }
    }

    private init(key: PromptAssetRunQualityKey, runs: [PromptRun]) {
        promptId = key.promptId
        promptVersion = key.promptVersion
        promptSourceKind = key.promptSourceKind
        promptPackId = key.promptPackId
        promptPackVersion = key.promptPackVersion
        promptPackDisplayName = key.promptPackDisplayName
        systemPolicyVersion = key.systemPolicyVersion
        contextPolicyVersion = key.contextPolicyVersion
        inputSchemaVersion = key.inputSchemaVersion
        outputSchemaVersion = key.outputSchemaVersion
        evalSuiteVersion = key.evalSuiteVersion
        totalCount = runs.count
        successCount = runs.filter(Self.isSuccess).count
        failureCount = runs.filter(Self.isFailure).count
        emptyResultCount = runs.filter(Self.isEmptyResultFailure).count
        userDeniedCount = runs.filter { $0.userFeedback == .denied }.count
        latestRunCreatedAt = runs.map(\.createdAt).max() ?? .distantPast
    }

    private func rate(_ count: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return Double(count) / Double(totalCount)
    }

    private static func isSuccess(_ run: PromptRun) -> Bool {
        run.responseJSON != nil && run.error == nil
    }

    private static func isFailure(_ run: PromptRun) -> Bool {
        run.responseJSON == nil && run.error != nil
    }

    private static func isEmptyResultFailure(_ run: PromptRun) -> Bool {
        guard isFailure(run), let error = run.error?.lowercased() else { return false }
        return error.contains("emptyresult") || error.contains("empty result")
    }
}

private struct PromptAssetRunQualityKey: Hashable {
    var promptId: String
    var promptVersion: String
    var promptSourceKind: PromptAssetSourceKind
    var promptPackId: String
    var promptPackVersion: String
    var promptPackDisplayName: String
    var systemPolicyVersion: String
    var contextPolicyVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var evalSuiteVersion: String

    init(run: PromptRun) {
        promptId = run.promptId
        promptVersion = run.promptVersion
        promptSourceKind = run.promptSourceKind
        promptPackId = run.promptPackId
        promptPackVersion = run.promptPackVersion
        promptPackDisplayName = run.promptPackDisplayName
        systemPolicyVersion = run.systemPolicyVersion
        contextPolicyVersion = run.contextPolicyVersion
        inputSchemaVersion = run.inputSchemaVersion
        outputSchemaVersion = run.outputSchemaVersion
        evalSuiteVersion = run.evalSuiteVersion
    }
}

enum PromptEvalStatus: String, Codable, CaseIterable, Identifiable {
    case passed
    case failed

    var id: String { rawValue }
}

struct PromptEvalCaseResult: Codable, Hashable {
    var caseId: String
    var name: String
    var status: PromptEvalStatus
    var failureReason: String?
    var inputSummary: String
    var expectedBehavior: String
    var actualObservation: String
    var diagnosticReason: String

    init(
        caseId: String,
        name: String,
        status: PromptEvalStatus,
        failureReason: String? = nil,
        inputSummary: String = "",
        expectedBehavior: String = "",
        actualObservation: String = "",
        diagnosticReason: String = ""
    ) {
        self.caseId = caseId
        self.name = name
        self.status = status
        self.failureReason = failureReason
        self.inputSummary = inputSummary
        self.expectedBehavior = expectedBehavior
        self.actualObservation = actualObservation
        self.diagnosticReason = diagnosticReason
    }
}

struct PromptEvalRun: Identifiable, Hashable {
    let id: UUID
    var schemaVersion: Int
    var promptId: String
    var promptVersion: String
    var promptSourceKind: PromptAssetSourceKind
    var promptPackId: String
    var promptPackVersion: String
    var promptPackDisplayName: String
    var systemPolicyVersion: String
    var contextPolicyVersion: String
    var inputSchemaVersion: Int
    var outputSchemaVersion: Int
    var evalSuiteVersion: String
    var runnerVersion: String
    var caseResults: [PromptEvalCaseResult]
    var createdAt: Date

    var totalCaseCount: Int { caseResults.count }
    var passedCaseCount: Int { caseResults.filter { $0.status == .passed }.count }
    var failedCaseCount: Int { caseResults.filter { $0.status == .failed }.count }
    var status: PromptEvalStatus { failedCaseCount == 0 ? .passed : .failed }
    var passRate: Double {
        guard totalCaseCount > 0 else { return 0 }
        return Double(passedCaseCount) / Double(totalCaseCount)
    }

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        promptId: String,
        promptVersion: String,
        promptSourceKind: PromptAssetSourceKind = .builtin,
        promptPackId: String = "mingsi.builtin.prompts",
        promptPackVersion: String = "builtin.v1",
        promptPackDisplayName: String = "MingSi Built-in Prompt Pack",
        systemPolicyVersion: String,
        contextPolicyVersion: String,
        inputSchemaVersion: Int,
        outputSchemaVersion: Int,
        evalSuiteVersion: String,
        runnerVersion: String,
        caseResults: [PromptEvalCaseResult],
        createdAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.promptId = promptId
        self.promptVersion = promptVersion
        self.promptSourceKind = promptSourceKind
        self.promptPackId = promptPackId
        self.promptPackVersion = promptPackVersion
        self.promptPackDisplayName = promptPackDisplayName
        self.systemPolicyVersion = systemPolicyVersion
        self.contextPolicyVersion = contextPolicyVersion
        self.inputSchemaVersion = inputSchemaVersion
        self.outputSchemaVersion = outputSchemaVersion
        self.evalSuiteVersion = evalSuiteVersion
        self.runnerVersion = runnerVersion
        self.caseResults = caseResults
        self.createdAt = createdAt
    }
}

enum PromptEvalReleaseGateStatus: String, CaseIterable, Identifiable {
    case passed
    case blocked

    var id: String { rawValue }
}

enum PromptEvalReleaseGateIssueReason: String, CaseIterable, Identifiable {
    case missingRun
    case staleVersion
    case failedCases
    case runnerMismatch

    var id: String { rawValue }
}

struct PromptEvalReleaseGateIssue: Hashable, Identifiable {
    var promptId: String
    var reason: PromptEvalReleaseGateIssueReason
    var message: String
    var rollbackCandidate: PromptEvalRollbackCandidate?

    var id: String { "\(promptId)-\(reason.rawValue)" }
}

struct PromptEvalRollbackCandidate: Hashable, Identifiable {
    var promptId: String
    var currentVersion: String
    var rollbackTargetVersion: String
    var lastPassingRunId: UUID
    var lastPassingRunCreatedAt: Date
    var reason: PromptEvalReleaseGateIssueReason

    var id: String { "\(promptId)-\(rollbackTargetVersion)-\(lastPassingRunId.uuidString)" }
}

struct PromptEvalReleaseGate: Hashable {
    var status: PromptEvalReleaseGateStatus
    var totalPromptCount: Int
    var passedPromptCount: Int
    var failedPromptCount: Int
    var missingPromptCount: Int
    var stalePromptCount: Int
    var runnerMismatchCount: Int
    var rollbackReadyCount: Int
    var manualReviewCount: Int
    var rollbackCandidates: [PromptEvalRollbackCandidate]
    var blockingIssues: [PromptEvalReleaseGateIssue]
    var evaluatedAt: Date

    var canShipPromptAssets: Bool { status == .passed }

    static func blocked(
        promptProvider: PromptProvider,
        mode: SessionMode = .standard,
        runnerVersion: String = PromptEvalRunner.currentRunnerVersion,
        evaluatedAt: Date = .now
    ) -> PromptEvalReleaseGate {
        evaluate(
            runs: [],
            promptProvider: promptProvider,
            mode: mode,
            runnerVersion: runnerVersion,
            evaluatedAt: evaluatedAt
        )
    }

    static func evaluate(
        runs: [PromptEvalRun],
        promptProvider: PromptProvider,
        mode: SessionMode,
        runnerVersion: String,
        evaluatedAt: Date = .now
    ) -> PromptEvalReleaseGate {
        var issues: [PromptEvalReleaseGateIssue] = []
        var passedPromptCount = 0
        var failedPromptIDs = Set<String>()
        var missingPromptIDs = Set<String>()
        var stalePromptIDs = Set<String>()
        var runnerMismatchPromptIDs = Set<String>()
        var rollbackCandidates: [PromptEvalRollbackCandidate] = []

        for promptID in PromptID.allCases {
            let promptId = promptID.rawValue
            let template = promptProvider.template(for: promptID, mode: mode)
            let promptRuns = runs.filter { $0.promptId == promptId }
            let matchingVersionRuns = promptRuns.filter {
                $0.promptId == promptId &&
                    $0.promptVersion == template.version &&
                    $0.systemPolicyVersion == template.systemPolicyVersion &&
                    $0.contextPolicyVersion == template.contextPolicyVersion &&
                    $0.inputSchemaVersion == 1 &&
                    $0.outputSchemaVersion == template.outputSchemaVersion &&
                    $0.evalSuiteVersion == template.evalSuiteVersion
            }
            let run = matchingVersionRuns.max { $0.createdAt < $1.createdAt }
                ?? promptRuns.max { $0.createdAt < $1.createdAt }

            guard let run else {
                missingPromptIDs.insert(promptId)
                issues.append(issue(promptId: promptId, reason: .missingRun, candidate: nil))
                continue
            }

            var isPromptPassed = true

            if isStale(run: run, template: template) {
                stalePromptIDs.insert(promptId)
                let candidate = rollbackCandidate(
                    promptId: promptId,
                    template: template,
                    runs: runs,
                    reason: .staleVersion,
                    runnerVersion: runnerVersion
                )
                if let candidate {
                    rollbackCandidates.append(candidate)
                }
                issues.append(issue(promptId: promptId, reason: .staleVersion, candidate: candidate))
                isPromptPassed = false
            }

            if run.status == .failed {
                failedPromptIDs.insert(promptId)
                let candidate = rollbackCandidate(
                    promptId: promptId,
                    template: template,
                    runs: runs,
                    reason: .failedCases,
                    runnerVersion: runnerVersion
                )
                if let candidate {
                    rollbackCandidates.append(candidate)
                }
                issues.append(issue(promptId: promptId, reason: .failedCases, candidate: candidate))
                isPromptPassed = false
            }

            if run.runnerVersion != runnerVersion {
                runnerMismatchPromptIDs.insert(promptId)
                issues.append(issue(promptId: promptId, reason: .runnerMismatch, candidate: nil))
                isPromptPassed = false
            }

            if isPromptPassed {
                passedPromptCount += 1
            }
        }

        let status: PromptEvalReleaseGateStatus = issues.isEmpty ? .passed : .blocked
        return PromptEvalReleaseGate(
            status: status,
            totalPromptCount: PromptID.allCases.count,
            passedPromptCount: passedPromptCount,
            failedPromptCount: failedPromptIDs.count,
            missingPromptCount: missingPromptIDs.count,
            stalePromptCount: stalePromptIDs.count,
            runnerMismatchCount: runnerMismatchPromptIDs.count,
            rollbackReadyCount: Set(rollbackCandidates.map(\.promptId)).count,
            manualReviewCount: PromptID.allCases.count - passedPromptCount - Set(rollbackCandidates.map(\.promptId)).count,
            rollbackCandidates: rollbackCandidates,
            blockingIssues: issues,
            evaluatedAt: evaluatedAt
        )
    }

    private static func isStale(run: PromptEvalRun, template: PromptTemplate) -> Bool {
        run.promptVersion != template.version ||
            run.systemPolicyVersion != template.systemPolicyVersion ||
            run.contextPolicyVersion != template.contextPolicyVersion ||
            run.inputSchemaVersion != 1 ||
            run.outputSchemaVersion != template.outputSchemaVersion ||
            run.evalSuiteVersion != template.evalSuiteVersion
    }

    private static func issue(
        promptId: String,
        reason: PromptEvalReleaseGateIssueReason,
        candidate: PromptEvalRollbackCandidate?
    ) -> PromptEvalReleaseGateIssue {
        PromptEvalReleaseGateIssue(
            promptId: promptId,
            reason: reason,
            message: message(promptId: promptId, reason: reason, candidate: candidate),
            rollbackCandidate: candidate
        )
    }

    private static func message(
        promptId: String,
        reason: PromptEvalReleaseGateIssueReason,
        candidate: PromptEvalRollbackCandidate?
    ) -> String {
        let name = PromptID(rawValue: promptId)?.displayName ?? promptId
        switch reason {
        case .missingRun:
            return "\(name) 缺少固定评测记录。"
        case .staleVersion:
            if let candidate {
                return "\(name) 版本已过期，可回滚到 \(candidate.rollbackTargetVersion) 的通过记录。"
            }
            return "\(name) 的评测记录已落后于当前 Prompt / Context / Schema / Eval 版本。"
        case .failedCases:
            if let candidate {
                return "\(name) 当前评测失败，可回滚到 \(candidate.rollbackTargetVersion) 的通过记录。"
            }
            return "\(name) 存在失败评测用例。"
        case .runnerMismatch:
            return "\(name) 使用的评测 runner 版本不匹配。"
        }
    }

    private static func rollbackCandidate(
        promptId: String,
        template: PromptTemplate,
        runs: [PromptEvalRun],
        reason: PromptEvalReleaseGateIssueReason,
        runnerVersion: String
    ) -> PromptEvalRollbackCandidate? {
        guard let rollbackTargetVersion = template.rollbackTargetVersion,
              !rollbackTargetVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        guard let passingRun = runs
            .filter({
                $0.promptId == promptId &&
                    $0.promptVersion == rollbackTargetVersion &&
                    $0.systemPolicyVersion == template.systemPolicyVersion &&
                    $0.contextPolicyVersion == template.contextPolicyVersion &&
                    $0.inputSchemaVersion == 1 &&
                    $0.outputSchemaVersion == template.outputSchemaVersion &&
                    $0.evalSuiteVersion == template.evalSuiteVersion &&
                    $0.runnerVersion == runnerVersion &&
                    $0.status == .passed
            })
            .max(by: { $0.createdAt < $1.createdAt })
        else {
            return nil
        }

        return PromptEvalRollbackCandidate(
            promptId: promptId,
            currentVersion: template.version,
            rollbackTargetVersion: rollbackTargetVersion,
            lastPassingRunId: passingRun.id,
            lastPassingRunCreatedAt: passingRun.createdAt,
            reason: reason
        )
    }
}

enum PromptEvalScheduleReason: String, Codable, CaseIterable, Identifiable {
    case missingRequiredRun = "missing_required_run"
    case staleRequiredRun = "stale_required_run"
    case failedRequiredRun = "failed_required_run"
    case runnerMismatch = "runner_mismatch"
    case minimumIntervalElapsed = "minimum_interval_elapsed"

    var id: String { rawValue }
}

struct PromptEvalScheduleDecision: Hashable {
    var reason: PromptEvalScheduleReason?

    var shouldRun: Bool { reason != nil }

    static let skip = PromptEvalScheduleDecision(reason: nil)
}

struct PromptEvalSchedulePolicy: Hashable {
    var minimumRunInterval: TimeInterval

    init(minimumRunInterval: TimeInterval = 24 * 60 * 60) {
        self.minimumRunInterval = minimumRunInterval
    }

    func decision(
        runs: [PromptEvalRun],
        promptProvider: PromptProvider,
        mode: SessionMode,
        runnerVersion: String,
        now: Date = .now
    ) -> PromptEvalScheduleDecision {
        let gate = PromptEvalReleaseGate.evaluate(
            runs: runs,
            promptProvider: promptProvider,
            mode: mode,
            runnerVersion: runnerVersion,
            evaluatedAt: now
        )

        if gate.missingPromptCount > 0 {
            return PromptEvalScheduleDecision(reason: .missingRequiredRun)
        }
        if gate.stalePromptCount > 0 {
            return PromptEvalScheduleDecision(reason: .staleRequiredRun)
        }
        if gate.failedPromptCount > 0 {
            return PromptEvalScheduleDecision(reason: .failedRequiredRun)
        }
        if gate.runnerMismatchCount > 0 {
            return PromptEvalScheduleDecision(reason: .runnerMismatch)
        }

        guard minimumRunInterval > 0,
              let latestRunDate = runs.map(\.createdAt).max()
        else {
            return .skip
        }

        if now.timeIntervalSince(latestRunDate) >= minimumRunInterval {
            return PromptEvalScheduleDecision(reason: .minimumIntervalElapsed)
        }
        return .skip
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

extension MetricSnapshot {
    func degradedForMissingGrowthContributions() -> MetricSnapshot {
        MetricSnapshot(
            id: id,
            period: period,
            startDate: startDate,
            endDate: endDate,
            clarity: clarity,
            valueJudgment: valueJudgment,
            executionReliability: executionReliability,
            calibration: calibration,
            reflectionDepth: reflectionDepth,
            previousClarity: previousClarity,
            previousValueJudgment: previousValueJudgment,
            previousExecutionReliability: previousExecutionReliability,
            previousCalibration: previousCalibration,
            previousReflectionDepth: previousReflectionDepth,
            clarityDelta: clarityDelta,
            valueJudgmentDelta: valueJudgmentDelta,
            executionReliabilityDelta: executionReliabilityDelta,
            calibrationDelta: calibrationDelta,
            reflectionDepthDelta: reflectionDepthDelta,
            summary: "缺少可追溯的成长贡献，暂不展示分数。",
            metricReasons: metricReasons,
            evidenceRefs: evidenceRefs,
            positiveContributionRefs: [],
            negativeContributionRefs: [],
            status: .insufficientEvidence,
            completeLoopCount: completeLoopCount,
            nextTrainingFocus: nextTrainingFocus,
            createdAt: createdAt,
            updatedAt: .now
        )
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
