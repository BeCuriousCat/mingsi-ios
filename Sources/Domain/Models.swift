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

enum YesterdayJudgmentUpdate: String, CaseIterable, Identifiable {
    case confirmed
    case adjusted
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confirmed: return "确认判断"
        case .adjusted: return "调整判断"
        case .rejected: return "推翻判断"
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
        case .verifyYesterday: return "结果校准"
        case .capture: return "今天内容"
        case .organizing: return "整理中"
        case .reviewCards: return "思考卡片"
        case .selectMode: return "选择模式"
        case .selectLens: return "选择透镜"
        case .answerQuestions: return "今日复盘"
        case .reviewQuests: return "明日验证"
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
        let combinedText = consideredCards
            .map { "\($0.title) \($0.body)" }
            .joined(separator: " ")
            .lowercased()
        let systemThinkingSignals = [
            "反馈", "回路", "延迟", "滞后", "二阶", "后果", "返工", "放大", "连锁",
            "feedback", "loop", "delay", "delayed", "second-order", "downstream"
        ]
        let systemThinkingSignalCount = systemThinkingSignals.filter { combinedText.contains($0) }.count
        let judgmentCalibrationSignals = [
            "预测", "预期", "把握", "信心", "置信", "实际", "结果", "相反", "校准", "更新判断",
            "prediction", "expected", "confidence", "actual", "outcome", "calibration", "calibrate"
        ]
        let judgmentCalibrationSignalCount = judgmentCalibrationSignals.filter { combinedText.contains($0) }.count

        if validationCount >= 2 && !highPriorityTypes.isDisjoint(with: [.fact, .risk, .problem]) {
            return item(for: .evidenceCheck)
        }

        if judgmentCalibrationSignalCount >= 2 {
            return item(for: .judgmentCalibration)
        }

        if systemThinkingSignalCount >= 2 {
            return item(for: .systemThinking)
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
            taskSelectionRule: "优先设计能补齐关键证据、确认验收口径或降低事实不确定性的明日验证行动。",
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
            taskSelectionRule: "优先设计能验证关键反方假设、暴露盲点或让不同角色参与校准的明日验证行动。",
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
            taskSelectionRule: "优先设计能改变关键结果、解除瓶颈或让后续动作变简单的明日验证行动。",
            applicability: "适用于任务、决策或行动卡片较多，且用户需要从多个动作中选择下一步的场景。",
            disableConditions: [
                "不要在事实和验收口径明显不清时跳过证据校验。",
                "不要把轻松完成当作高杠杆。",
                "不要生成多个并列验证行动。"
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
            taskSelectionRule: "优先设计能验证核心前提、澄清必要条件或重建行动路径的明日验证行动。",
            applicability: "适用于卡片类型没有明显主导、前提混杂、或用户需要重新定义问题的场景。",
            disableConditions: [
                "不要用抽象原则替代当天具体证据。",
                "不要把复杂问题简化成口号。",
                "不要在用户只需要快速执行时过度拆解。"
            ]
        ),
        LensCatalogItem(
            lensId: "systemThinking",
            promptId: "system_thinking",
            version: "builtin.v1",
            title: "系统思维",
            subtitle: "看见反馈回路、延迟影响和二阶后果。",
            shortLabel: "系统",
            methodLine: "先问：这个结果是由什么回路持续制造的？",
            promptGuidance: "Map feedback loops, delayed effects, constraints, second-order consequences, and observable calibration signals before choosing the next action.",
            symbolName: "point.3.connected.trianglepath.dotted",
            recommendedReason: "当前材料出现返工、延迟影响或连锁后果，适合先看系统结构。",
            questionSeeds: [
                "这个结果是由什么回路持续制造的？",
                "哪个短期动作会在之后放大成本？",
                "明天能观察到什么信号，证明这个系统判断对或错？"
            ],
            accentRole: .accent,
            methodIndex: 5,
            purpose: "识别事件背后的反馈回路、延迟影响、约束瓶颈和二阶后果，避免只修表面症状。",
            questionStrategy: "先画出反馈回路和延迟影响，再追问二阶后果、关键约束和下一次可观察的校准信号。",
            taskSelectionRule: "优先设计能打断负反馈、验证关键约束或采集校准信号的明日验证行动。",
            applicability: "适用于同类问题反复出现、短期动作带来长期代价、返工增加、依赖传导或结果延迟显现的场景。",
            disableConditions: [
                "不要把系统思维变成宏大叙事，必须落到当天证据和下一步观察。",
                "不要在用户只需要事实校验时跳过证据缺口。",
                "不要输出无法在明天或近期观察的抽象判断。"
            ]
        ),
        LensCatalogItem(
            lensId: "judgmentCalibration",
            promptId: "judgment_calibration",
            version: "builtin.v1",
            title: "判断校准",
            subtitle: "用实际证据更新预测、信心和下一步判断。",
            shortLabel: "校准",
            methodLine: "先问：原判断是什么，实际证据让它怎么更新？",
            promptGuidance: "Compare the user's original prediction, confidence, actual evidence, evidence gained, and judgment update before choosing the next calibration signal.",
            symbolName: "scope",
            recommendedReason: "当前材料出现预测、信心或实际结果偏差，适合校准判断。",
            questionSeeds: [
                "原判断是什么，实际证据让它怎么更新？",
                "你当时有多大把握？现在证据支持几分？",
                "下一次要观察哪个信号，避免重复误判？"
            ],
            accentRole: .principle,
            methodIndex: 6,
            purpose: "把原判断、置信度、实际证据和判断更新放在同一张桌面上，训练可校准的判断能力。",
            questionStrategy: "先还原原判断和信心，再对照实际证据，最后要求用户说清判断如何更新和下一次校准信号。",
            taskSelectionRule: "优先设计能验证一个预测、采集一个校准信号或降低下一次误判概率的明日验证行动。",
            applicability: "适用于用户提到预测、预期、把握、信心、实际结果、判断反转、复盘偏差或需要更新判断的场景。",
            disableConditions: [
                "不要把校准变成事后诸葛，必须先明确原判断或可观察预测。",
                "不要在缺少实际证据时强行评价判断质量。",
                "不要用分数羞辱用户，重点是下一次如何更可校准。"
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
    case systemThinking
    case judgmentCalibration

    var id: String { rawValue }

    var catalogItem: LensCatalogItem {
        BuiltinLensCatalog.item(for: self)
    }

    var title: String { catalogItem.title }

    var subtitle: String { catalogItem.subtitle }

    var primaryTrainingDimension: ThinkingTrainingDimension {
        switch self {
        case .evidenceCheck:
            return .evidenceDiscipline
        case .opposingView:
            return .counterexampleSeeking
        case .leverageAnalysis:
            return .testableActionDesign
        case .firstPrinciples:
            return .assumptionTesting
        case .systemThinking:
            return .systemFeedbackAwareness
        case .judgmentCalibration:
            return .judgmentCalibration
        }
    }
}

enum TrainingPrescriptionSource: String, Codable, Hashable {
    case coachRecommended = "coach_recommended"
    case userOverride = "user_override"
    case skipped
}

enum ThinkingTrainingDimension: String, Codable, CaseIterable, Identifiable, Hashable {
    case factInterpretationSeparation = "fact_interpretation_separation"
    case evidenceDiscipline = "evidence_discipline"
    case counterexampleSeeking = "counterexample_seeking"
    case assumptionTesting = "assumption_testing"
    case systemFeedbackAwareness = "system_feedback_awareness"
    case judgmentCalibration = "judgment_calibration"
    case testableActionDesign = "testable_action_design"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .factInterpretationSeparation:
            return "事实/解释分离"
        case .evidenceDiscipline:
            return "证据意识"
        case .counterexampleSeeking:
            return "反例意识"
        case .assumptionTesting:
            return "假设检验"
        case .systemFeedbackAwareness:
            return "系统反馈"
        case .judgmentCalibration:
            return "判断校准"
        case .testableActionDesign:
            return "可验证行动"
        }
    }

    var foundationalCapabilityTitle: String {
        switch self {
        case .testableActionDesign:
            return "执行力"
        case .factInterpretationSeparation, .evidenceDiscipline, .counterexampleSeeking,
             .assumptionTesting, .systemFeedbackAwareness, .judgmentCalibration:
            return "思考力"
        }
    }

    var trainingTitle: String {
        "\(foundationalCapabilityTitle)中的\(displayTitle)"
    }

    static func primary(forLensId lensId: String) -> ThinkingTrainingDimension? {
        ThinkingLens(rawValue: lensId)?.primaryTrainingDimension
    }
}

enum BaselineThinkingCheck: String, Codable, CaseIterable, Hashable {
    case factInterpretationSplit = "fact_interpretation_split"
    case evidenceGap = "evidence_gap"
    case counterexample
    case assumptionTest = "assumption_test"
    case testableAction = "testable_action"
    case feedbackSignal = "feedback_signal"
    case judgmentUpdate = "judgment_update"

    var trainingDimension: ThinkingTrainingDimension {
        switch self {
        case .factInterpretationSplit:
            return .factInterpretationSeparation
        case .evidenceGap:
            return .evidenceDiscipline
        case .counterexample:
            return .counterexampleSeeking
        case .assumptionTest:
            return .assumptionTesting
        case .testableAction:
            return .testableActionDesign
        case .feedbackSignal:
            return .systemFeedbackAwareness
        case .judgmentUpdate:
            return .judgmentCalibration
        }
    }
}

struct TrainingPrescription: Codable, Hashable {
    var recommendedLensId: String
    var recommendedPromptId: String
    var recommendationReason: String
    var confidence: Double
    var policyVersion: String
    var alternativeLensIds: [String]
    var baselineChecks: [BaselineThinkingCheck]
    var primaryTrainingDimension: ThinkingTrainingDimension
    var secondaryTrainingDimensions: [ThinkingTrainingDimension]
    var baselineTrainingDimensions: [ThinkingTrainingDimension]
    var userSelectedLensId: String?
    var finalLensId: String
    var source: TrainingPrescriptionSource
    var overrideBoundary: String

    init(
        recommendedLensId: String,
        recommendedPromptId: String,
        recommendationReason: String,
        confidence: Double,
        policyVersion: String,
        alternativeLensIds: [String],
        baselineChecks: [BaselineThinkingCheck],
        primaryTrainingDimension: ThinkingTrainingDimension? = nil,
        secondaryTrainingDimensions: [ThinkingTrainingDimension]? = nil,
        baselineTrainingDimensions: [ThinkingTrainingDimension]? = nil,
        userSelectedLensId: String? = nil,
        finalLensId: String,
        source: TrainingPrescriptionSource,
        overrideBoundary: String = ""
    ) {
        self.recommendedLensId = recommendedLensId
        self.recommendedPromptId = recommendedPromptId
        self.recommendationReason = recommendationReason
        self.confidence = confidence
        self.policyVersion = policyVersion
        self.alternativeLensIds = alternativeLensIds
        self.baselineChecks = baselineChecks
        let resolvedPrimary = primaryTrainingDimension ??
            ThinkingTrainingDimension.primary(forLensId: recommendedLensId) ??
            .assumptionTesting
        let resolvedBaseline = baselineTrainingDimensions ??
            Self.defaultBaselineTrainingDimensions(for: baselineChecks)
        self.primaryTrainingDimension = resolvedPrimary
        self.secondaryTrainingDimensions = secondaryTrainingDimensions ??
            Self.defaultSecondaryTrainingDimensions(
                baselineTrainingDimensions: resolvedBaseline,
                primaryTrainingDimension: resolvedPrimary
            )
        self.baselineTrainingDimensions = resolvedBaseline
        self.userSelectedLensId = userSelectedLensId
        self.finalLensId = finalLensId
        self.source = source
        self.overrideBoundary = overrideBoundary
    }

    private enum CodingKeys: String, CodingKey {
        case recommendedLensId
        case recommendedPromptId
        case recommendationReason
        case confidence
        case policyVersion
        case alternativeLensIds
        case baselineChecks
        case primaryTrainingDimension
        case secondaryTrainingDimensions
        case baselineTrainingDimensions
        case userSelectedLensId
        case finalLensId
        case source
        case overrideBoundary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let recommendedLensId = try container.decode(String.self, forKey: .recommendedLensId)
        let recommendedPromptId = try container.decode(String.self, forKey: .recommendedPromptId)
        let recommendationReason = try container.decode(String.self, forKey: .recommendationReason)
        let confidence = try container.decode(Double.self, forKey: .confidence)
        let policyVersion = try container.decode(String.self, forKey: .policyVersion)
        let alternativeLensIds = try container.decode([String].self, forKey: .alternativeLensIds)
        let baselineChecks = try container.decode([BaselineThinkingCheck].self, forKey: .baselineChecks)
        let primaryTrainingDimension = try container.decodeIfPresent(
            ThinkingTrainingDimension.self,
            forKey: .primaryTrainingDimension
        )
        let baselineTrainingDimensions = try container.decodeIfPresent(
            [ThinkingTrainingDimension].self,
            forKey: .baselineTrainingDimensions
        )
        let secondaryTrainingDimensions = try container.decodeIfPresent(
            [ThinkingTrainingDimension].self,
            forKey: .secondaryTrainingDimensions
        )
        let userSelectedLensId = try container.decodeIfPresent(String.self, forKey: .userSelectedLensId)
        let finalLensId = try container.decode(String.self, forKey: .finalLensId)
        let source = try container.decode(TrainingPrescriptionSource.self, forKey: .source)
        let overrideBoundary = try container.decodeIfPresent(String.self, forKey: .overrideBoundary) ?? ""

        self.init(
            recommendedLensId: recommendedLensId,
            recommendedPromptId: recommendedPromptId,
            recommendationReason: recommendationReason,
            confidence: confidence,
            policyVersion: policyVersion,
            alternativeLensIds: alternativeLensIds,
            baselineChecks: baselineChecks,
            primaryTrainingDimension: primaryTrainingDimension,
            secondaryTrainingDimensions: secondaryTrainingDimensions,
            baselineTrainingDimensions: baselineTrainingDimensions,
            userSelectedLensId: userSelectedLensId,
            finalLensId: finalLensId,
            source: source,
            overrideBoundary: overrideBoundary
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recommendedLensId, forKey: .recommendedLensId)
        try container.encode(recommendedPromptId, forKey: .recommendedPromptId)
        try container.encode(recommendationReason, forKey: .recommendationReason)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(policyVersion, forKey: .policyVersion)
        try container.encode(alternativeLensIds, forKey: .alternativeLensIds)
        try container.encode(baselineChecks, forKey: .baselineChecks)
        try container.encode(primaryTrainingDimension, forKey: .primaryTrainingDimension)
        try container.encode(secondaryTrainingDimensions, forKey: .secondaryTrainingDimensions)
        try container.encode(baselineTrainingDimensions, forKey: .baselineTrainingDimensions)
        try container.encodeIfPresent(userSelectedLensId, forKey: .userSelectedLensId)
        try container.encode(finalLensId, forKey: .finalLensId)
        try container.encode(source, forKey: .source)
        try container.encode(overrideBoundary, forKey: .overrideBoundary)
    }

    private static func defaultBaselineTrainingDimensions(
        for checks: [BaselineThinkingCheck]
    ) -> [ThinkingTrainingDimension] {
        uniqueTrainingDimensions(checks.map(\.trainingDimension))
    }

    private static func defaultSecondaryTrainingDimensions(
        baselineTrainingDimensions: [ThinkingTrainingDimension],
        primaryTrainingDimension: ThinkingTrainingDimension
    ) -> [ThinkingTrainingDimension] {
        baselineTrainingDimensions
            .filter { $0 != primaryTrainingDimension }
            .prefix(3)
            .map { $0 }
    }

    private static func uniqueTrainingDimensions(
        _ dimensions: [ThinkingTrainingDimension]
    ) -> [ThinkingTrainingDimension] {
        var seen: Set<ThinkingTrainingDimension> = []
        return dimensions.filter { seen.insert($0).inserted }
    }
}

struct LocalTrainingPrescriptionPolicy {
    static let policyVersion = "training-prescription.local-lens-v1"

    private let library: LensCatalogProviding

    init(library: LensCatalogProviding = BuiltinLensCatalog.library) {
        self.library = library
    }

    func prescribe(
        cards: [ThinkingCard],
        mode: SessionMode,
        userSelectedLens: ThinkingLens?
    ) -> TrainingPrescription {
        let recommended = library.recommendedItem(for: cards, mode: mode)
            ?? BuiltinLensCatalog.item(for: .firstPrinciples)
        let userSelectedLensId = userSelectedLens?.rawValue
        let finalLensId = userSelectedLensId ?? recommended.lensId
        let source: TrainingPrescriptionSource = userSelectedLensId == nil ? .coachRecommended : .userOverride

        return TrainingPrescription(
            recommendedLensId: recommended.lensId,
            recommendedPromptId: recommended.promptId,
            recommendationReason: recommended.recommendedReason,
            confidence: confidence(for: recommended, cards: cards),
            policyVersion: Self.policyVersion,
            alternativeLensIds: alternativeLensIds(excluding: recommended.lensId),
            baselineChecks: Self.defaultBaselineChecks,
            userSelectedLensId: userSelectedLensId,
            finalLensId: finalLensId,
            source: source,
            overrideBoundary: overrideBoundary(
                userSelectedLensId: userSelectedLensId,
                recommendedLensId: recommended.lensId
            )
        )
    }

    private static let defaultBaselineChecks: [BaselineThinkingCheck] = [
        .factInterpretationSplit,
        .evidenceGap,
        .counterexample,
        .assumptionTest,
        .testableAction,
        .feedbackSignal,
        .judgmentUpdate
    ]

    private func confidence(for item: LensCatalogItem, cards: [ThinkingCard]) -> Double {
        let consideredCards = cards.filter { !$0.isExcludedFromModel }
        guard !consideredCards.isEmpty else { return 0.60 }
        let highPriorityCount = consideredCards.filter { $0.priority == .high }.count
        if highPriorityCount >= 2 { return 0.78 }
        if highPriorityCount == 1 { return 0.70 }
        return item.lensId == ThinkingLens.firstPrinciples.rawValue ? 0.62 : 0.66
    }

    private func alternativeLensIds(excluding recommendedLensId: String) -> [String] {
        library.items
            .filter { $0.lensId != recommendedLensId }
            .sorted { $0.methodIndex < $1.methodIndex }
            .prefix(3)
            .map(\.lensId)
    }

    private func overrideBoundary(userSelectedLensId: String?, recommendedLensId: String) -> String {
        guard let userSelectedLensId, userSelectedLensId != recommendedLensId else { return "" }
        return "用户改选为 \(userSelectedLensId)，保留教练推荐 \(recommendedLensId) 作为审计；后续问题和任务以最终选择为主，同时保留基础思维检查。"
    }
}

enum ThinkingPhase: String, Codable, CaseIterable, Identifiable, Hashable {
    case exploreProblem = "explore_problem"
    case clarifyJudgment = "clarify_judgment"
    case fillEvidenceGap = "fill_evidence_gap"
    case formAction = "form_action"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .exploreProblem:
            return "探索问题"
        case .clarifyJudgment:
            return "澄清判断"
        case .fillEvidenceGap:
            return "补证据"
        case .formAction:
            return "形成行动"
        }
    }
}

enum ConvergenceReadiness: String, Codable, Hashable {
    case notReady = "not_ready"
    case partiallyReady = "partially_ready"
    case ready
}

enum NextCoachMove: String, Codable, Hashable {
    case askClarifyingQuestion = "ask_clarifying_question"
    case surfaceEvidenceGap = "surface_evidence_gap"
    case slowDownConvergence = "slow_down_convergence"
    case recommendTrainingLens = "recommend_training_lens"
    case generateQuest = "generate_quest"

    var displayRecommendation: String {
        switch self {
        case .askClarifyingQuestion:
            return "先追问问题定义，别急着收敛。"
        case .surfaceEvidenceGap:
            return "先标出判断依据和证据缺口。"
        case .slowDownConvergence:
            return "先减缓收敛，补齐关键证据。"
        case .recommendTrainingLens:
            return "进入训练透镜，围绕主焦点练习。"
        case .generateQuest:
            return "可以继续设计明日验证。"
        }
    }
}

enum CoachDiagnosisSource: String, Codable, Hashable {
    case coachRecommended = "coach_recommended"
    case coachAccepted = "coach_accepted"
    case userSlowDown = "user_slow_down"
    case userOverrideProgress = "user_override_progress"
}

struct CoachDiagnosis: Codable, Hashable {
    var phase: ThinkingPhase
    var readiness: ConvergenceReadiness
    var recommendedMove: NextCoachMove
    var reason: String
    var source: CoachDiagnosisSource
    var policyVersion: String
}

struct CoachTurnState: Codable, Hashable {
    var phase: ThinkingPhase
    var readiness: ConvergenceReadiness
    var recommendedMove: NextCoachMove
    var reason: String
    var openEvidenceGaps: [EvidenceGapType]
    var baselineChecks: [BaselineThinkingCheck]
    var decisionSource: CoachDiagnosisSource
    var policyVersion: String
    var turnSummary: String
}

struct CoachAnswerTrainingFeedback: Codable, Hashable {
    var readiness: ConvergenceReadiness
    var canProceedToValidation: Bool
    var coachCritiqueLine: String
    var repairedLine: String
    var missingLine: String
    var proceedLine: String
    var abilityGapLine: String
    var trainingOutputLine: String
    var selfCheckLine: String
    var trainingTargetLine: String
    var nextRepairQuestion: String
    var experienceReplayDecisionLine: String
    var experienceReplayPrompt: String
    var judgmentSentencePrompt: String
    var teachingPlan: CoachTeachingPlan
}

struct CoachTurnPolicy {
    static let policyVersion = "coach-turn.local-v1"

    func makeInitialTurn(
        cards: [ThinkingCard],
        diagnosis: CoachDiagnosis? = nil
    ) -> CoachTurnState {
        let resolvedDiagnosis = diagnosis ?? CoachEngine().diagnose(cards: cards)
        return CoachTurnState(
            phase: resolvedDiagnosis.phase,
            readiness: resolvedDiagnosis.readiness,
            recommendedMove: resolvedDiagnosis.recommendedMove,
            reason: resolvedDiagnosis.reason,
            openEvidenceGaps: openEvidenceGaps(for: resolvedDiagnosis),
            baselineChecks: defaultBaselineChecks,
            decisionSource: resolvedDiagnosis.source,
            policyVersion: Self.policyVersion,
            turnSummary: initialSummary(for: resolvedDiagnosis)
        )
    }

    func updateAfterAnswers(
        cards: [ThinkingCard],
        questions: [ReflectionQuestion],
        previous: CoachTurnState?
    ) -> CoachTurnState {
        let answeredQuestions = questions.filter {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !answeredQuestions.isEmpty else {
            return previous ?? makeInitialTurn(cards: cards)
        }

        let base = previous ?? makeInitialTurn(cards: cards)
        if base.decisionSource == .userOverrideProgress {
            var overrideTurn = base
            overrideTurn.phase = .formAction
            overrideTurn.readiness = .ready
            overrideTurn.recommendedMove = .generateQuest
            overrideTurn.reason = "用户选择 override 推进；回答会进入行动生成，但未关闭缺口继续作为审计边界。"
            overrideTurn.turnSummary = "用户 override 后继续推进；未关闭缺口仍保留，明天用行动证据校准。"
            overrideTurn.policyVersion = Self.policyVersion
            return overrideTurn
        }

        let unresolvedGaps = unresolvedEvidenceGaps(
            from: base.openEvidenceGaps,
            questions: answeredQuestions
        )

        if unresolvedGaps.isEmpty {
            return CoachTurnState(
                phase: .formAction,
                readiness: .ready,
                recommendedMove: .generateQuest,
                reason: "用户回答已经补足本轮缺口，可以把下一步设计成可验证行动。",
                openEvidenceGaps: [],
                baselineChecks: base.baselineChecks,
                decisionSource: base.decisionSource,
                policyVersion: Self.policyVersion,
                turnSummary: "回答补足了本轮训练缺口，教练轮次从追问推进到形成可验证行动。"
            )
        }

        var unresolved = base
        unresolved.readiness = .notReady
        unresolved.openEvidenceGaps = unresolvedGaps
        unresolved.recommendedMove = unresolvedGaps.isEmpty ? .askClarifyingQuestion : .surfaceEvidenceGap
        unresolved.reason = unresolvedReason(for: unresolvedGaps)
        unresolved.turnSummary = "回答仍未关闭\(unresolvedGaps.map(\.displayTitle).joined(separator: "、"))，继续追问而不是直接收敛。"
        unresolved.policyVersion = Self.policyVersion
        return unresolved
    }

    func applyingUserDecision(
        _ decisionSource: CoachDiagnosisSource,
        to state: CoachTurnState
    ) -> CoachTurnState {
        var updated = state
        updated.decisionSource = decisionSource
        updated.policyVersion = Self.policyVersion
        switch decisionSource {
        case .coachRecommended, .coachAccepted:
            updated.turnSummary = "用户接受或沿用教练轮次：\(state.turnSummary)"
        case .userSlowDown:
            updated.readiness = .notReady
            updated.recommendedMove = .slowDownConvergence
            updated.turnSummary = "用户选择减缓收敛，继续补证据和澄清判断。"
        case .userOverrideProgress:
            updated.phase = .formAction
            updated.readiness = .ready
            updated.recommendedMove = .generateQuest
            updated.turnSummary = "用户主动推进到行动生成；这不是证据缺口已消失的证明，后续仍保留审计边界。"
        }
        return updated
    }

    private var defaultBaselineChecks: [BaselineThinkingCheck] {
        [
            .factInterpretationSplit,
            .evidenceGap,
            .counterexample,
            .assumptionTest,
            .testableAction,
            .feedbackSignal,
            .judgmentUpdate
        ]
    }

    private func openEvidenceGaps(for diagnosis: CoachDiagnosis) -> [EvidenceGapType] {
        switch diagnosis.phase {
        case .exploreProblem:
            return [.missingObservation]
        case .clarifyJudgment:
            return [.missingObservation, .missingCausalLink]
        case .fillEvidenceGap:
            return [.missingObservation, .missingBaseline]
        case .formAction:
            return []
        }
    }

    private func initialSummary(for diagnosis: CoachDiagnosis) -> String {
        "教练初始轮次：\(diagnosis.reason)"
    }

    private func unresolvedEvidenceGaps(
        from gaps: [EvidenceGapType],
        questions: [ReflectionQuestion]
    ) -> [EvidenceGapType] {
        let activeGaps = gaps.filter { $0 != .none }
        guard !activeGaps.isEmpty else { return [] }
        return activeGaps.filter { !answersClose($0, questions: questions) }
    }

    private func answersClose(
        _ gap: EvidenceGapType,
        questions: [ReflectionQuestion]
    ) -> Bool {
        let answerText = questions
            .map(\.answer)
            .joined(separator: " ")
            .lowercased()

        switch gap {
        case .missingObservation:
            return containsAny(answerText, [
                "事实", "证据", "观察", "看到", "记录", "确认", "客户", "数据", "可观察",
                "fact", "evidence", "observed", "observable", "documented", "confirmed"
            ])
        case .missingBaseline:
            return containsAny(answerText, [
                "验收", "标准", "基线", "完成标准", "可检查", "文档",
                "criteria", "baseline", "acceptance", "checkable"
            ])
        case .missingCausalLink:
            return containsAny(answerText, [
                "因为", "导致", "因果", "反馈", "回路", "延迟", "下游", "二阶", "影响",
                "cause", "because", "feedback", "loop", "delay", "downstream", "second-order"
            ])
        case .missingCounterexample:
            return containsAny(answerText, [
                "反例", "相反", "不同解释", "替代解释", "否则", "不成立",
                "counterexample", "opposite", "alternative", "disconfirm"
            ])
        case .missingConstraint:
            return containsAny(answerText, [
                "约束", "限制", "边界", "成本", "资源", "时间窗口",
                "constraint", "limit", "boundary", "cost", "resource"
            ])
        case .missingCalibrationSignal:
            let hasOutcomeSignal = containsAny(answerText, [
                "实际", "结果", "信号", "观察", "返工", "次数", "下降", "上升", "完成后",
                "actual", "outcome", "result", "signal", "observe", "metric"
            ])
            let hasJudgmentUpdate = containsAny(answerText, [
                "更新", "改变判断", "判断", "预测", "预期", "信心", "校准",
                "update", "judgment", "prediction", "confidence", "calibrate"
            ])
            return hasOutcomeSignal && hasJudgmentUpdate
        case .none:
            return true
        }
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private func unresolvedReason(for gaps: [EvidenceGapType]) -> String {
        if gaps.contains(.missingCalibrationSignal) {
            return "用户已有回答，但还没有说明实际结果信号这个校准信号会如何改变判断。"
        }
        if gaps.contains(.missingCausalLink) {
            return "用户已有回答，但还没有说清因果链、反馈或延迟影响。"
        }
        if gaps.contains(.missingObservation) || gaps.contains(.missingBaseline) {
            return "用户已有回答，但还没有补足可观察事实、基线或验收标准。"
        }
        if gaps.contains(.missingCounterexample) {
            return "用户已有回答，但还没有给出能挑战当前解释的反例。"
        }
        if gaps.contains(.missingConstraint) {
            return "用户已有回答，但还没有说清关键约束或边界。"
        }
        return "用户已有回答，但本轮训练缺口还没有关闭。"
    }
}

struct CoachAnswerFeedbackPolicy {
    static let judgmentSentencePrompt = "把下一句写成：我现在相信 X；明天用 Y 观察它是否成立；如果出现 Z，我就更新判断。"

    func makeFeedback(
        turn: CoachTurnState,
        previous: CoachTurnState?,
        questions: [ReflectionQuestion],
        prescription: TrainingPrescription?,
        observation: CoachObservation? = nil
    ) -> CoachAnswerTrainingFeedback {
        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: prescription)
        let remainingGaps = activeGaps(from: turn.openEvidenceGaps)
        let previousGaps = activeGaps(from: previous?.openEvidenceGaps ?? [])
        let repairedGaps = previousGaps.filter { !remainingGaps.contains($0) }
        let canProceed = turn.readiness == .ready && remainingGaps.isEmpty

        return CoachAnswerTrainingFeedback(
            readiness: turn.readiness,
            canProceedToValidation: canProceed,
            coachCritiqueLine: coachCritiqueLine(
                canProceed: canProceed,
                repairedGaps: repairedGaps,
                remainingGaps: remainingGaps,
                plan: plan,
                questions: questions,
                observation: observation
            ),
            repairedLine: repairedLine(repairedGaps: repairedGaps, questions: questions),
            missingLine: missingLine(remainingGaps: remainingGaps),
            proceedLine: proceedLine(canProceed: canProceed, plan: plan),
            abilityGapLine: abilityGapLine(plan: plan, observation: observation),
            trainingOutputLine: trainingOutputLine(plan: plan, observation: observation),
            selfCheckLine: selfCheckLine(plan: plan, observation: observation),
            trainingTargetLine: trainingTargetLine(plan: plan, observation: observation),
            nextRepairQuestion: nextRepairQuestion(plan: plan, observation: observation),
            experienceReplayDecisionLine: ExperienceReplayTraining.line,
            experienceReplayPrompt: plan.experienceReplayPrompt,
            judgmentSentencePrompt: Self.judgmentSentencePrompt,
            teachingPlan: plan
        )
    }

    private func coachCritiqueLine(
        canProceed: Bool,
        repairedGaps: [EvidenceGapType],
        remainingGaps: [EvidenceGapType],
        plan: CoachTeachingPlan,
        questions: [ReflectionQuestion],
        observation: CoachObservation?
    ) -> String {
        let answeredCount = questions.filter {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let repairedPart: String
        if repairedGaps.isEmpty {
            repairedPart = answeredCount > 0 ? "这不是合格复盘，只是回答了问题，还没有补上训练材料" : "还没有可批改的新回答"
        } else if canProceed {
            repairedPart = "已补训练材料：\(gapLine(for: repairedGaps))"
        } else {
            repairedPart = "刚补上：\(gapLine(for: repairedGaps))"
        }
        let nextPart = canProceed
            ? "可以进入明日验证：\(plan.proceedStandard)"
            : critiqueTrainingFocus(
                plan: plan,
                remainingGaps: remainingGaps,
                observation: observation
            )
        let critiqueParts = canProceed || repairedGaps.isEmpty
            ? [repairedPart, nextPart]
            : ["这不是合格复盘", repairedPart, nextPart]
        let suffix = canProceed
            ? "这不是普通待办，下一步要用明日结果校准判断。"
            : "这不是普通待办，要先把思考训练缺口补齐。"
        return "教练批改：\(critiqueParts.joined(separator: "；"))。\(suffix)"
    }

    private func critiqueTrainingFocus(
        plan: CoachTeachingPlan,
        remainingGaps: [EvidenceGapType],
        observation: CoachObservation?
    ) -> String {
        guard let observation else {
            return "还要训练：\(remainingGaps.isEmpty ? plan.missingMoveTitle : gapLine(for: remainingGaps))"
        }
        if observation.primaryGap == .goal {
            return "还要训练：把行动当成答案，先补服务对象、成功标准和可观察信号"
        }
        if observation.primaryGap == .narrative {
            return "还要训练：讲清楚一件事，先补背景、对象、触发、行动和结果"
        }
        return "还要训练：\(observation.trainingAbility.trainingTitle)，\(observation.feedback.diagnosis)"
    }

    private func activeGaps(from gaps: [EvidenceGapType]) -> [EvidenceGapType] {
        gaps.filter { $0 != .none }
    }

    private func repairedLine(
        repairedGaps: [EvidenceGapType],
        questions: [ReflectionQuestion]
    ) -> String {
        let answeredCount = questions.filter {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        guard !repairedGaps.isEmpty else {
            return answeredCount > 0
                ? "你已经回答，但还没有形成可复盘的训练材料。"
                : "还没有新的回答材料。"
        }
        return "已补训练材料：\(gapLine(for: repairedGaps))。"
    }

    private func missingLine(remainingGaps: [EvidenceGapType]) -> String {
        remainingGaps.isEmpty
            ? "关键缺口已关闭。"
            : "还没练到位：\(gapLine(for: remainingGaps))。"
    }

    private func proceedLine(
        canProceed: Bool,
        plan: CoachTeachingPlan
    ) -> String {
        canProceed
            ? "可以进入明日验证：\(plan.proceedStandard)"
            : "现在不能进入明日验证：先修补训练缺口，\(plan.proceedStandard)"
    }

    private func abilityGapLine(
        plan: CoachTeachingPlan,
        observation: CoachObservation?
    ) -> String {
        guard let observation else {
            return "能力缺口：\(plan.trainingTargetLine)还没有补成可复盘材料。"
        }
        if observation.primaryGap == .goal {
            return "能力缺口：把行动当成答案，少了服务对象、成功标准和可观察信号。"
        }
        return "能力缺口：\(observation.trainingAbility.trainingTitle)还没练到位，\(observation.feedback.diagnosis)"
    }

    private func trainingOutputLine(
        plan: CoachTeachingPlan,
        observation: CoachObservation?
    ) -> String {
        guard let observation else {
            return "训练产物：补出一段可复盘材料，能支撑\(plan.proceedStandard)"
        }
        if observation.primaryGap == .goal {
            return "训练产物：一句包含服务对象、成功标准、可观察信号的判断，再决定行动。"
        }
        if observation.primaryGap == .narrative {
            return "训练产物：一段包含背景、对象、触发、行动、结果的完整讲述。"
        }
        return "训练产物：补出\(CoachObservationMaterial.trainingLine(for: observation.missingMaterials))，让下一步可判断、可执行、可复盘。"
    }

    private func selfCheckLine(
        plan: CoachTeachingPlan,
        observation: CoachObservation?
    ) -> String {
        guard let observation else {
            return "自检标准：别人能根据你的材料判断\(plan.proceedStandard)"
        }
        if observation.primaryGap == .goal {
            return "自检标准：这句话要能回答谁的什么问题会变少、成功标准是什么、明天看哪个可观察信号。"
        }
        if observation.primaryGap == .narrative {
            return "自检标准：别人不追问你，也能复述背景、对象、触发、行动和结果。"
        }
        return "自检标准：补完后别人能指出已补\(CoachObservationMaterial.trainingLine(for: observation.missingMaterials))，并知道下一步怎么判断。"
    }

    private func trainingTargetLine(
        plan: CoachTeachingPlan,
        observation: CoachObservation?
    ) -> String {
        guard let observation else {
            return "本轮正在练\(plan.trainingTargetLine)。"
        }
        if observation.primaryGap == .goal {
            return "本轮正在练\(observation.trainingAbility.trainingTitle)：先说清服务对象、成功标准和可观察信号，再安排行动。不是让 AI 替你给答案。"
        }
        return "本轮正在练\(observation.trainingAbility.trainingTitle)：\(observation.trainingAbility.coachingMeaning) 不是让 AI 替你给答案。"
    }

    private func nextRepairQuestion(
        plan: CoachTeachingPlan,
        observation: CoachObservation?
    ) -> String {
        guard let observation else { return plan.repairQuestion }
        if observation.primaryGap == .goal {
            return "下一句请写成：如果这件事做对了，谁的什么问题会变少；成功标准是什么；明天能看到哪个可观察信号？"
        }
        if observation.primaryGap == .narrative {
            return "下一句请按讲清楚一件事来写：什么背景下，谁或哪个对象遇到什么触发；你做了什么；后来发生了什么结果？"
        }
        return plan.repairQuestion
    }

    private func gapLine(for gaps: [EvidenceGapType]) -> String {
        gaps.map(\.displayTitle).joined(separator: "、")
    }
}

enum CoachObservationMaterial: String, Codable, CaseIterable, Hashable {
    case background
    case object
    case trigger
    case action
    case result
    case feeling
    case fact
    case interpretation
    case judgment
    case assumption
    case constraint
    case goal
    case standard
    case openQuestion = "open_question"
    case experience
    case calibrationSignal = "calibration_signal"
}

enum CoachObservationGap: String, Codable, CaseIterable, Hashable {
    case narrative
    case observation
    case object
    case goal
    case constraint
    case causal
    case counterexample
    case judgment
    case execution
    case calibration
    case experience

    var displayTitle: String {
        switch self {
        case .narrative:
            return "讲述缺口"
        case .observation:
            return "观察事实"
        case .object:
            return "对象缺口"
        case .goal:
            return "目标缺口"
        case .constraint:
            return "约束缺口"
        case .causal:
            return "因果链"
        case .counterexample:
            return "反例缺口"
        case .judgment:
            return "判断标准"
        case .execution:
            return "执行安排"
        case .calibration:
            return "校准信号"
        case .experience:
            return "经验复现"
        }
    }
}

enum CoreTrainingAbility: String, Codable, CaseIterable, Hashable {
    case description
    case observation
    case analysis
    case judgment
    case execution
    case calibration

    var displayTitle: String {
        switch self {
        case .description:
            return "描述力"
        case .observation:
            return "观察力"
        case .analysis:
            return "分析力"
        case .judgment:
            return "判断力"
        case .execution:
            return "执行力"
        case .calibration:
            return "校准力"
        }
    }

    var foundationalCapabilityTitle: String {
        switch self {
        case .description:
            return "沟通力"
        case .observation, .analysis, .judgment, .calibration:
            return "思考力"
        case .execution:
            return "执行力"
        }
    }

    var trainingTitle: String {
        "\(foundationalCapabilityTitle)中的\(displayTitle)"
    }

    var coachingMeaning: String {
        switch self {
        case .description:
            return "把事情讲到别人能复盘，而不是只留下感受或结论。"
        case .observation:
            return "分清事实、解释和证据，先看见材料再下判断。"
        case .analysis:
            return "拆出因果、约束和反例，避免只沿着一个解释走。"
        case .judgment:
            return "说清服务对象、重要性和成功标准，让取舍有依据。"
        case .execution:
            return "把想清楚的事安排成可完成、可检查的下一步。"
        case .calibration:
            return "用未来结果修正今天判断，避免经验被机械套用。"
        }
    }
}

struct CoachObservationFeedback: Codable, Hashable {
    var observed: String
    var diagnosis: String
    var training: String
    var ask: String
    var proceedWhen: String
}

struct CoachObservation: Codable, Hashable {
    var policyVersion: String
    var providedMaterials: [CoachObservationMaterial]
    var missingMaterials: [CoachObservationMaterial]
    var thinkingProcessObservation: String
    var primaryGap: CoachObservationGap
    var secondaryGaps: [CoachObservationGap]
    var trainingAbility: CoreTrainingAbility
    var feedback: CoachObservationFeedback
    var experienceReplayPrompt: String

    var narrativeTrainingLine: String {
        "讲清楚一件事：已说清：\(CoachObservationMaterial.trainingLine(for: providedMaterials))；先补：\(CoachObservationMaterial.trainingLine(for: missingMaterials))。"
    }

    var experienceReplayTrainingLine: String {
        ExperienceReplayTraining.line
    }
}

extension CoachObservationMaterial {
    var trainingCue: String {
        switch self {
        case .background:
            return "交代背景"
        case .object:
            return "说明对象"
        case .trigger:
            return "说清触发"
        case .action:
            return "写出做法"
        case .result:
            return "补上结果"
        case .feeling:
            return "感受"
        case .fact:
            return "可观察事实"
        case .interpretation:
            return "解释"
        case .judgment:
            return "判断"
        case .assumption:
            return "假设"
        case .constraint:
            return "限制条件"
        case .goal:
            return "目标"
        case .standard:
            return "成功标准"
        case .openQuestion:
            return "开放问题"
        case .experience:
            return "过往经验"
        case .calibrationSignal:
            return "校准信号"
        }
    }

    static func trainingLine(for materials: [CoachObservationMaterial]) -> String {
        let cues = materials.map(\.trainingCue).filter { !$0.isEmpty }
        return cues.isEmpty ? "暂无" : cues.joined(separator: "、")
    }
}

struct CoachObservationPolicy {
    static let policyVersion = "coach-observation.local-v7"

    func observe(text: String) -> CoachObservation {
        observe(cards: [
            ThinkingCard(type: .idea, title: "", body: text)
        ])
    }

    func observe(cards: [ThinkingCard]) -> CoachObservation {
        let consideredCards = consideredCards(from: cards)
        let text = consideredCards
            .map { "\($0.title) \($0.body)" }
            .joined(separator: " ")
        let normalizedText = text.lowercased()
        let providedMaterials = providedMaterials(from: consideredCards, text: normalizedText)
        let missingMaterials = missingMaterials(from: providedMaterials, text: normalizedText)
        let primaryGap = primaryGap(
            providedMaterials: providedMaterials,
            missingMaterials: missingMaterials,
            text: normalizedText
        )
        let secondaryGaps = secondaryGaps(
            primaryGap: primaryGap,
            providedMaterials: providedMaterials,
            missingMaterials: missingMaterials,
            text: normalizedText
        )
        let ability = trainingAbility(for: primaryGap)

        return CoachObservation(
            policyVersion: Self.policyVersion,
            providedMaterials: providedMaterials,
            missingMaterials: missingMaterials,
            thinkingProcessObservation: thinkingProcessObservation(for: primaryGap),
            primaryGap: primaryGap,
            secondaryGaps: secondaryGaps,
            trainingAbility: ability,
            feedback: feedback(for: primaryGap, ability: ability, providedMaterials: providedMaterials),
            experienceReplayPrompt: experienceReplayPrompt(for: primaryGap)
        )
    }

    private func consideredCards(from cards: [ThinkingCard]) -> [ThinkingCard] {
        let confirmedCards = cards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
        return confirmedCards.isEmpty
            ? cards.filter { !$0.isExcludedFromModel }
            : confirmedCards
    }

    private func providedMaterials(
        from cards: [ThinkingCard],
        text: String
    ) -> [CoachObservationMaterial] {
        var materials: [CoachObservationMaterial] = []

        if hasProvidedBackground(text) {
            materials.append(.background)
        }

        if hasProvidedActorOrObject(text) {
            materials.append(.object)
        }

        if hasProvidedTrigger(text) {
            materials.append(.trigger)
        }

        if cards.contains(where: { $0.type == .task }) ||
            containsAny(text, ["打算", "计划", "明天", "先拉会", "先让", "写清", "行动", "推进", "调整", "暂停", "action", "tomorrow"]) {
            materials.append(.action)
        }

        if hasProvidedResult(text) {
            materials.append(.result)
        }

        if cards.contains(where: { $0.type == .decision }) ||
            containsAny(text, ["我觉得", "大概率", "应该", "不可行", "有效", "倾向", "判断", "结论", "认为"]) {
            materials.append(.judgment)
        }

        if hasProvidedInterpretation(text) {
            materials.append(.interpretation)
        }

        if hasProvidedAssumption(text) {
            materials.append(.assumption)
        }

        if hasProvidedFact(cards: cards, text: text) {
            materials.append(.fact)
        }

        if hasProvidedGoal(text: text) {
            materials.append(.goal)
        }

        if hasProvidedStandard(text) {
            materials.append(.standard)
        }

        if hasProvidedCalibrationSignal(text) {
            materials.append(.calibrationSignal)
        }

        if containsAny(text, ["以前", "之前", "过往", "经验", "复用", "沿用", "照着做", "上次", "previous", "experience"]) {
            materials.append(.experience)
        }

        if containsAny(text, ["感受", "压力", "焦虑", "担心", "兴奋", "难受", "feeling"]) {
            materials.append(.feeling)
        }

        if containsAny(text, ["约束", "限制", "边界", "成本", "资源", "constraint", "limit"]) {
            materials.append(.constraint)
        }

        return unique(materials)
    }

    private func missingMaterials(
        from providedMaterials: [CoachObservationMaterial],
        text: String
    ) -> [CoachObservationMaterial] {
        var missing: [CoachObservationMaterial] = []

        let narrativeCore: [CoachObservationMaterial] = [.background, .object, .trigger, .action, .result]
        let providedNarrativeCore = narrativeCore.filter { providedMaterials.contains($0) }
        if !providedMaterials.isEmpty, providedNarrativeCore.count < 2 {
            missing.append(contentsOf: narrativeCore.filter { !providedMaterials.contains($0) })
        }

        if !providedMaterials.contains(.object),
           providedNarrativeCore.count >= 2 {
            missing.append(.object)
        }

        if providedMaterials.contains(.action),
           !providedMaterials.contains(.goal) {
            missing.append(.goal)
        }

        if providedMaterials.contains(.judgment),
           !providedMaterials.contains(.fact) {
            missing.append(.fact)
        }

        if providedMaterials.contains(.judgment),
           providedMaterials.contains(.fact),
           !providedMaterials.contains(.standard) {
            missing.append(.standard)
        }

        if providedMaterials.contains(.judgment),
           providedMaterials.contains(.fact),
           providedMaterials.contains(.standard),
           !providedMaterials.contains(.calibrationSignal) {
            missing.append(.calibrationSignal)
        }

        if providedMaterials.contains(.experience),
           lacksExperienceFitCheck(text) {
            missing.append(.calibrationSignal)
        }

        if suggestsBlockedProgress(text),
           !providedMaterials.contains(.constraint) {
            missing.append(.constraint)
        }

        return unique(missing)
    }

    private func primaryGap(
        providedMaterials: [CoachObservationMaterial],
        missingMaterials: [CoachObservationMaterial],
        text: String
    ) -> CoachObservationGap {
        if providedMaterials.contains(.experience),
           lacksExperienceFitCheck(text) {
            return .experience
        }

        if providedMaterials.contains(.judgment),
           missingMaterials.contains(.fact) {
            return .observation
        }

        if shouldTrainNarrativeBeforeGoal(
            providedMaterials: providedMaterials,
            missingMaterials: missingMaterials,
            text: text
        ) {
            return .narrative
        }

        if shouldTrainObjectBeforeGoal(
            providedMaterials: providedMaterials,
            missingMaterials: missingMaterials,
            text: text
        ) {
            return .object
        }

        if shouldTrainConstraintBeforeGoal(
            providedMaterials: providedMaterials,
            missingMaterials: missingMaterials,
            text: text
        ) {
            return .constraint
        }

        if shouldTrainCausalAnalysis(providedMaterials: providedMaterials, text: text) {
            return .causal
        }

        if shouldTrainCounterexampleAnalysis(providedMaterials: providedMaterials, text: text) {
            return .counterexample
        }

        if providedMaterials.contains(.action),
           missingMaterials.contains(.goal) {
            return .goal
        }

        if providedMaterials.contains(.judgment),
           missingMaterials.contains(.standard) {
            return .judgment
        }

        if missingMaterials.contains(.calibrationSignal) {
            return .calibration
        }

        if providedMaterials.contains(.action) {
            return .execution
        }

        return .narrative
    }

    private func secondaryGaps(
        primaryGap: CoachObservationGap,
        providedMaterials: [CoachObservationMaterial],
        missingMaterials: [CoachObservationMaterial],
        text: String
    ) -> [CoachObservationGap] {
        var gaps: [CoachObservationGap] = []

        if isThinNarrative(providedMaterials: providedMaterials, missingMaterials: missingMaterials) {
            gaps.append(.narrative)
        }

        if providedMaterials.contains(.experience),
           lacksExperienceFitCheck(text) {
            gaps.append(.counterexample)
        }

        if providedMaterials.contains(.judgment),
           missingMaterials.contains(.fact) {
            gaps.append(.observation)
        }

        if providedMaterials.contains(.action),
           missingMaterials.contains(.goal) {
            gaps.append(.goal)
        }

        if providedMaterials.contains(.judgment),
           missingMaterials.contains(.standard) {
            gaps.append(.judgment)
        }

        if missingMaterials.contains(.constraint) {
            gaps.append(.constraint)
        }

        if missingMaterials.contains(.calibrationSignal) {
            gaps.append(.calibration)
        }

        if shouldTrainCausalAnalysis(providedMaterials: providedMaterials, text: text) {
            gaps.append(.causal)
        }

        if shouldTrainCounterexampleAnalysis(providedMaterials: providedMaterials, text: text) {
            gaps.append(.counterexample)
        }

        return unique(gaps.filter { $0 != primaryGap })
    }

    private func trainingAbility(for gap: CoachObservationGap) -> CoreTrainingAbility {
        switch gap {
        case .narrative, .object:
            return .description
        case .observation:
            return .observation
        case .constraint, .causal, .counterexample:
            return .analysis
        case .goal, .judgment:
            return .judgment
        case .execution:
            return .execution
        case .calibration, .experience:
            return .calibration
        }
    }

    private func thinkingProcessObservation(for gap: CoachObservationGap) -> String {
        switch gap {
        case .experience:
            return "用户正在调用过往经验，但还没有检查这次条件是否相同。"
        case .observation:
            return "用户先给出结论或判断，但还没有补出能支撑判断的可观察事实。"
        case .goal:
            return "用户已经进入动作推进，但还没有把服务对象、目标和成功标准说清楚。"
        case .execution:
            return "用户已经有行动倾向，下一步需要把行动变成可检查结果。"
        case .calibration:
            return "用户需要定义未来用什么信号校准今天的判断。"
        case .constraint:
            return "用户描述了限制，但还没有把边界条件转成判断依据。"
        case .causal:
            return "用户描述了现象，但还没有追踪因果链或反馈结构。"
        case .counterexample:
            return "用户当前解释还没有被反例或替代解释挑战。"
        case .judgment:
            return "用户需要把当前取舍的标准说清楚。"
        case .object:
            return "用户讲了背景、动作或结果，但还没有说清谁受影响、服务对象是谁。"
        case .narrative:
            return "用户还没有把事件讲到别人可以复盘的程度。"
        }
    }

    private func feedback(
        for gap: CoachObservationGap,
        ability: CoreTrainingAbility,
        providedMaterials: [CoachObservationMaterial]
    ) -> CoachObservationFeedback {
        let needsMaterialSeparation = containsMixedThinkingMaterials(providedMaterials)
        switch gap {
        case .experience:
            return CoachObservationFeedback(
                observed: "你提到了过往做法或经验，但还没有判断这次条件是否一样。",
                diagnosis: "当前主要缺口是经验复现判断：旧经验不能直接当成答案。",
                training: "本轮先练\(ability.trainingTitle)，判断经验该复现、调整还是否定。",
                ask: "这条经验在本次是复现、调整，还是否定？请用一句话说明条件差异。",
                proceedWhen: "当你能说清条件差异和复用边界时，再进入行动。"
            )
        case .observation:
            return CoachObservationFeedback(
                observed: "你已经说出了判断或结论，但还没有写出一个可观察事实。",
                diagnosis: "当前主要缺口是观察 gap：事实和解释还没有分开。",
                training: "本轮先练\(ability.trainingTitle)，不急着让 AI 给结论。",
                ask: needsMaterialSeparation
                    ? "请先把事实、感受、解释、判断分开写：哪一句是看到的事实，哪一句只是解释或判断？"
                    : "请补充一个你亲眼看到、直接听到或能被记录验证的事实。",
                proceedWhen: "当答案能分开事实和解释时，可以进入下一步判断。"
            )
        case .goal:
            return CoachObservationFeedback(
                observed: "你已经有动作或推进方式，但还没有说清这个动作服务于谁。",
                diagnosis: "当前主要缺口是目标 gap：行动对象、重要性和达成标准还不清楚。",
                training: "本轮先练\(ability.trainingTitle)，把重要性和成功标准说清。",
                ask: needsMaterialSeparation
                    ? "请先把事实、感受、解释、判断分开，再补一句：如果这件事做对了，谁的什么问题会变少？"
                    : "如果这件事做对了，谁的什么问题会变少？",
                proceedWhen: "当你能说清服务对象、问题和成功标准时，再安排下一步行动。"
            )
        case .execution:
            return CoachObservationFeedback(
                observed: "你已经有行动倾向，但还没有把行动写成可检查结果。",
                diagnosis: "当前主要缺口是执行 gap：下一步、负责人或验收标准还不够清楚。",
                training: "本轮先练\(ability.trainingTitle)，把思考落成可执行安排。",
                ask: "明天最小的一步是什么，完成后留下什么证据？",
                proceedWhen: "当行动能被明天验证时，可以设计明日验证。"
            )
        case .calibration:
            return CoachObservationFeedback(
                observed: "你已经有判断，但还没有定义未来用什么信号校准。",
                diagnosis: "当前主要缺口是校准 gap：结果出现后还不知道如何更新判断。",
                training: "本轮先练\(ability.trainingTitle)，让判断能被未来结果修正。",
                ask: "明天或近期哪个信号会证明你今天的判断需要更新？",
                proceedWhen: "当你能说清校准信号时，再进入行动。"
            )
        case .object:
            return CoachObservationFeedback(
                observed: "你已经说出背景、动作或结果，但还没有说明谁受影响。",
                diagnosis: "当前主要缺口是对象 gap：别人还不知道这件事服务于谁、影响谁。",
                training: "本轮先练\(ability.trainingTitle)，把事情中的人、对象和受影响问题讲清楚。",
                ask: "请补一句：这件事影响谁，或你要服务谁的什么问题？",
                proceedWhen: "当你能说清对象、对象的问题和影响时，再进入目标或行动判断。"
            )
        case .constraint:
            return CoachObservationFeedback(
                observed: "你已经描述了事情推进受阻，但还没有说清具体限制。",
                diagnosis: "当前主要缺口是约束 gap：还不知道卡住来自时间、资源、权限、信息、关系还是系统边界。",
                training: "本轮先练\(ability.trainingTitle)，把限制条件拆出来，再决定怎么推进。",
                ask: "请补一句：现在最大的限制是什么，来自时间、资源、权限、信息、关系还是系统边界？",
                proceedWhen: "当你能说清关键边界和它如何限制行动时，再进入目标或行动判断。"
            )
        case .causal:
            return CoachObservationFeedback(
                observed: "你已经给出一个因果解释，但还没有说明 A 到 B 中间发生了什么。",
                diagnosis: "当前主要缺口是因果 gap：解释链条还没有被拆开，容易把相关性当成原因。",
                training: "本轮先练\(ability.trainingTitle)，把因果链条拆到别人可以检查。",
                ask: needsMaterialSeparation
                    ? "请先把事实、感受、解释、判断分开，再补一句：A 到 B 中间发生了什么？"
                    : "请补一句：A 到 B 中间发生了什么，哪个环节最关键？",
                proceedWhen: "当你能说清中间链条和关键环节时，再进入目标或行动判断。"
            )
        case .counterexample:
            return CoachObservationFeedback(
                observed: "你已经形成一个解释，但还没有说什么证据会挑战它。",
                diagnosis: "当前主要缺口是反例 gap：如果没有推翻条件，解释容易只沿着自己相信的方向变强。",
                training: "本轮先练\(ability.trainingTitle)，主动找能推翻或削弱当前解释的信号。",
                ask: "请补一句：什么事实出现时，会推翻或削弱你现在的解释？",
                proceedWhen: "当你能说清推翻信号或替代解释时，再进入目标或行动判断。"
            )
        case .judgment:
            return CoachObservationFeedback(
                observed: "你已经有事实和判断，但还没有说清用什么标准做取舍。",
                diagnosis: "当前主要缺口是判断标准 gap：事实已经出现，但重要性、优先级或成功标准还不清楚。",
                training: "本轮先练\(ability.trainingTitle)，让判断从感觉变成可解释的取舍。",
                ask: "请补一句：你的判断标准是什么，为什么这件事比其他问题更重要？",
                proceedWhen: "当你能说清判断标准、重要性和取舍依据时，再进入行动。"
            )
        case .narrative:
            return CoachObservationFeedback(
                observed: "你已经写出感受或判断，但事情的前因后果还没有展开。",
                diagnosis: "当前主要缺口是讲述 gap：别人还不能复盘发生了什么。",
                training: "本轮先练\(ability.trainingTitle)，把一件事讲清楚，再进入分析或行动。",
                ask: "请补充前因后果：什么背景下，谁做了什么，触发点是什么，后来发生了什么？",
                proceedWhen: "当你能说清背景、触发点、行动和结果时，再进入下一步。"
            )
        }
    }

    private func containsMixedThinkingMaterials(_ materials: [CoachObservationMaterial]) -> Bool {
        let materialSet = Set(materials)
        let reasoningMaterials: Set<CoachObservationMaterial> = [.fact, .interpretation, .judgment]
        return materialSet.contains(.feeling)
            && !materialSet.intersection(reasoningMaterials).isEmpty
    }

    private func experienceReplayPrompt(for gap: CoachObservationGap) -> String {
        switch gap {
        case .experience:
            return "请检查过往经验和本次条件：哪些条件相同可以复现，哪些不同需要调整，哪些会让旧经验失效？"
        case .narrative:
            return "回想过往一次因为讲述不清导致别人无法复盘的经验：这次要复现哪条讲述顺序？"
        case .observation:
            return "回想过往一次因为事实和解释混在一起而误判的经验：这次要复现哪条事实检查？"
        case .object:
            return "回想过往一次因为没有说清服务对象或受影响的人而判断跑偏的经验：这次要复现哪条对象检查？"
        case .goal:
            return "回想过往一次因为没有先定义服务对象或成功标准而返工的经验：这次要复现哪条目标检查？"
        case .constraint:
            return "回想过往一次忽略限制条件而推进受阻的经验：这次要复现哪条边界检查？"
        case .causal:
            return "回想过往一次误把相关当原因而判断跑偏的经验：这次要复现哪条因果检查？"
        case .counterexample:
            return "回想过往一次忽略反例而判断过早收敛的经验：这次要复现哪条反证检查？"
        case .judgment:
            return "回想过往一次判断标准不清而取舍摇摆的经验：这次要复现哪条取舍检查？"
        case .execution:
            return "回想过往一次行动不可检查而无法复盘结果的经验：这次要复现哪条执行检查？"
        case .calibration:
            return "回想过往一次没有预设校准信号而事后无法更新判断的经验：这次要复现哪条结果检查？"
        }
    }

    private func isThinNarrative(
        providedMaterials: [CoachObservationMaterial],
        missingMaterials: [CoachObservationMaterial]
    ) -> Bool {
        let narrativeCore: [CoachObservationMaterial] = [.background, .object, .trigger, .action, .result]
        let providedNarrativeCoreCount = narrativeCore.filter { providedMaterials.contains($0) }.count
        let missingNarrativeCoreCount = narrativeCore.filter { missingMaterials.contains($0) }.count
        return providedNarrativeCoreCount < 2 && missingNarrativeCoreCount >= 3
    }

    private func shouldTrainNarrativeBeforeGoal(
        providedMaterials: [CoachObservationMaterial],
        missingMaterials: [CoachObservationMaterial],
        text: String
    ) -> Bool {
        guard providedMaterials.contains(.action),
              missingMaterials.contains(.goal),
              !hasExplicitGoalGapSignal(text)
        else { return false }

        let narrativeCore: [CoachObservationMaterial] = [.background, .object, .trigger, .action, .result]
        let providedNarrativeCoreCount = narrativeCore.filter { providedMaterials.contains($0) }.count
        let missingNarrativeCoreCount = narrativeCore.filter { missingMaterials.contains($0) }.count
        return providedNarrativeCoreCount <= 1 && missingNarrativeCoreCount >= 3
    }

    private func shouldTrainObjectBeforeGoal(
        providedMaterials: [CoachObservationMaterial],
        missingMaterials: [CoachObservationMaterial],
        text: String
    ) -> Bool {
        guard missingMaterials.contains(.object),
              !hasExplicitGoalGapSignal(text)
        else { return false }

        let narrativeCore: [CoachObservationMaterial] = [.background, .object, .trigger, .action, .result]
        let providedNarrativeCoreCount = narrativeCore.filter { providedMaterials.contains($0) }.count
        return providedNarrativeCoreCount >= 2
    }

    private func shouldTrainConstraintBeforeGoal(
        providedMaterials: [CoachObservationMaterial],
        missingMaterials: [CoachObservationMaterial],
        text: String
    ) -> Bool {
        guard missingMaterials.contains(.constraint),
              suggestsBlockedProgress(text),
              !hasExplicitGoalGapSignal(text)
        else { return false }

        let narrativeCore: [CoachObservationMaterial] = [.background, .object, .trigger, .action, .result]
        let providedNarrativeCoreCount = narrativeCore.filter { providedMaterials.contains($0) }.count
        return providedNarrativeCoreCount >= 3
    }

    private func shouldTrainCausalAnalysis(
        providedMaterials: [CoachObservationMaterial],
        text: String
    ) -> Bool {
        guard providedMaterials.contains(.fact),
              providedMaterials.contains(.interpretation),
              suggestsCausalShortcut(text),
              !hasCausalMechanism(text)
        else { return false }

        return providedMaterials.contains(.result) || providedMaterials.contains(.judgment)
    }

    private func shouldTrainCounterexampleAnalysis(
        providedMaterials: [CoachObservationMaterial],
        text: String
    ) -> Bool {
        guard providedMaterials.contains(.fact),
              providedMaterials.contains(.interpretation),
              providedMaterials.contains(.judgment),
              !containsMixedThinkingMaterials(providedMaterials),
              !shouldTrainCausalAnalysis(providedMaterials: providedMaterials, text: text),
              !hasCounterexampleSignal(text)
        else { return false }

        return suggestsCausalShortcut(text) || providedMaterials.contains(.assumption)
    }

    private func hasProvidedBackground(_ text: String) -> Bool {
        containsAny(text, [
            "背景", "当时", "会议", "评审", "沟通中", "讨论中", "项目里", "需求评审",
            "context", "meeting", "project context"
        ])
    }

    private func hasProvidedActorOrObject(_ text: String) -> Bool {
        containsAny(text, [
            "用户", "客户", "同事", "团队", "负责人", "alex", "产品", "研发", "设计",
            "使用者", "服务对象", "actor", "customer", "team", "owner"
        ])
    }

    private func hasProvidedTrigger(_ text: String) -> Bool {
        containsAny(text, [
            "因为", "由于", "触发", "开始", "收到", "发现", "被提醒", "提出", "导致",
            "trigger", "because", "started"
        ])
    }

    private func hasProvidedResult(_ text: String) -> Bool {
        containsAny(text, [
            "结果", "最后", "后来", "导致", "变成", "完成", "失败", "返工",
            "outcome", "result", "ended"
        ])
    }

    private func hasProvidedInterpretation(_ text: String) -> Bool {
        containsAny(text, [
            "猜测", "可能是", "可能都", "我理解", "我以为", "意味着", "说明",
            "所以", "因为", "看起来", "似乎", "interpret", "means", "seems"
        ])
    }

    private func hasProvidedAssumption(_ text: String) -> Bool {
        containsAny(text, [
            "假设", "前提", "如果", "估计", "默认", "assume", "assumption", "if "
        ])
    }

    private func hasProvidedFact(cards: [ThinkingCard], text: String) -> Bool {
        if cards.contains(where: { $0.type == .fact }) {
            return true
        }
        if containsAny(text, ["没有事实", "没有看到明确事实", "缺少事实", "缺事实", "只是感觉"]) {
            return false
        }
        return containsAny(text, [
            "事实：", "看到", "听到", "记录", "数据", "实际", "确认", "可观察",
            "fact:", "observed", "documented", "confirmed"
        ])
    }

    private func hasProvidedGoal(text: String) -> Bool {
        if hasExplicitGoalGapSignal(text) {
            return false
        }
        return containsAny(text, [
            "目标是", "为了", "成功标准是", "解决", "服务于", "达成", "验收标准是",
            "goal is", "success criteria"
        ])
    }

    private func hasProvidedStandard(_ text: String) -> Bool {
        containsAny(text, [
            "判断标准", "标准是", "成功标准是", "验收标准是", "取舍标准", "依据是",
            "验收标准", "优先级依据", "衡量", "判定标准", "重要性在于", "criteria", "criterion"
        ])
    }

    private func hasProvidedCalibrationSignal(_ text: String) -> Bool {
        containsAny(text, [
            "校准信号", "未来信号", "明天看", "明天观察", "结果校准", "回来检查",
            "用结果", "如果出现", "证明我错", "证明判断", "指标变化", "实际结果",
            "calibration signal", "future signal", "outcome signal"
        ])
    }

    private func hasExplicitGoalGapSignal(_ text: String) -> Bool {
        containsAny(text, ["不知道到底服务于谁", "没说清目标", "目标不清", "不知道目标", "没有目标"])
    }

    private func suggestsBlockedProgress(_ text: String) -> Bool {
        containsAny(text, [
            "卡住", "推进不下去", "推不动", "受阻", "阻塞", "暂停", "停滞",
            "没有进展", "难推进", "blocked", "stalled", "stuck"
        ])
    }

    private func suggestsCausalShortcut(_ text: String) -> Bool {
        containsAny(text, [
            "因为", "由于", "所以", "导致", "造成", "归因", "是因为",
            "therefore", "because", "caused", "led to"
        ])
    }

    private func hasCausalMechanism(_ text: String) -> Bool {
        containsAny(text, [
            "中间", "链条", "机制", "路径", "环节", "反馈", "回路", "延迟",
            "先", "再", "进而", "影响路径", "mechanism", "chain", "path"
        ])
    }

    private func hasCounterexampleSignal(_ text: String) -> Bool {
        containsAny(text, [
            "反例", "推翻", "削弱", "相反证据", "替代解释", "不成立", "证伪",
            "如果不是", "还有可能", "counterexample", "disconfirm", "falsify"
        ])
    }

    private func lacksExperienceFitCheck(_ text: String) -> Bool {
        if containsAny(text, ["还没判断", "没有判断", "没判断", "未判断", "不确定这次条件"]) {
            return true
        }
        let hasExperienceFitSignal = containsAny(text, [
            "条件相同", "条件一样", "条件不同", "需要调整", "不能复用", "可以复现",
            "复现、调整", "复现还是调整", "否定这条经验"
        ])
        return !hasExperienceFitSignal
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }
}

enum CoachConvergenceRisk: String, Codable, Hashable {
    case low
    case medium
    case high
}

struct CoachDecisionScores: Codable, Hashable {
    var evidenceReadiness: Int
    var convergenceRisk: Int
    var calibrationOpportunity: Int
    var systemFeedback: Int
    var actionTestability: Int
    var historicalLearning: Int
}

struct CoachLensLearningSignal: Codable, Hashable {
    var signal: String
    var lensMove: QuestionLensMove?
    var calibrationTarget: String?
    var reason: String
}

struct CoachLensLearningPolicy {
    static let reinforceSignal = "reinforce"
    static let adjustSignal = "adjust"
    static let avoidSignal = "avoid"
    static let overrideAuditSignalName = "override_audit"

    func signals(from session: LensSession, verification: Verification) -> [CoachLensLearningSignal] {
        session.questions.compactMap { question in
            let answer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !answer.isEmpty else { return nil }
            guard let lensMove = question.lensMove else { return nil }

            let calibrationTarget = question.calibrationTarget?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let signal = Self.signal(
                completion: verification.completion,
                valueRating: verification.valueRating
            )

            return CoachLensLearningSignal(
                signal: signal,
                lensMove: lensMove,
                calibrationTarget: calibrationTarget?.isEmpty == true ? nil : calibrationTarget,
                reason: Self.reason(
                    signal: signal,
                    completion: verification.completion,
                    valueRating: verification.valueRating
                )
            )
        }
    }

    func overrideAuditSignal(
        recommendedLens: ThinkingLens,
        finalLens: ThinkingLens,
        primaryTrainingDimension: ThinkingTrainingDimension,
        recentOverrideCount: Int
    ) -> CoachLensLearningSignal? {
        guard recommendedLens != finalLens else { return nil }
        let isFrequent = recentOverrideCount >= 2
        let prefix = isFrequent ? "frequent user override" : "user override"
        return CoachLensLearningSignal(
            signal: Self.overrideAuditSignalName,
            lensMove: nil,
            calibrationTarget: "\(recommendedLens.rawValue)->\(finalLens.rawValue)",
            reason: "\(prefix) from \(recommendedLens.rawValue) to \(finalLens.rawValue) while primary dimension is \(primaryTrainingDimension.rawValue); audit the pattern without treating the coach diagnosis as wrong."
        )
    }

    static func signal(
        completion: YesterdayCompletion,
        valueRating: YesterdayValueRating
    ) -> String {
        if completion == .done, valueRating == .high {
            return reinforceSignal
        }
        if completion == .missed || valueRating == .low {
            return avoidSignal
        }
        return adjustSignal
    }

    private static func reason(
        signal: String,
        completion: YesterdayCompletion,
        valueRating: YesterdayValueRating
    ) -> String {
        switch signal {
        case reinforceSignal:
            return "done/high verification produced useful evidence; reinforce this lens move when current cards fit."
        case avoidSignal:
            return "\(completion.rawValue)/\(valueRating.rawValue) verification did not produce usable evidence; avoid repeating this lens move and target pattern."
        default:
            return "\(completion.rawValue)/\(valueRating.rawValue) verification was partially useful; make this lens move smaller and more observable next time."
        }
    }
}

struct CoachDecisionAssessment: Codable, Hashable {
    var policyVersion: String
    var phase: ThinkingPhase
    var readiness: ConvergenceReadiness
    var recommendedMove: NextCoachMove
    var primaryTrainingDimension: ThinkingTrainingDimension
    var openEvidenceGaps: [EvidenceGapType]
    var convergenceRisk: CoachConvergenceRisk
    var scores: CoachDecisionScores
    var reason: String
    var whyNow: String
    var expectedUpdate: String
    var proceedWhen: String
    var learningSignals: [CoachLensLearningSignal]
}

struct CoachTeachingPlan: Codable, Hashable {
    var policyVersion: String
    var missingMoveTitle: String
    var trainingTargetTitle: String
    var whyNotAnswer: String
    var proceedStandard: String
    var repairQuestion: String
    var experienceReplayPrompt: String
    var routeSteps: [String]
    var auditNote: String?

    var experienceReplayTrainingLine: String {
        ExperienceReplayTraining.line
    }

    var trainingTargetLine: String {
        if trainingTargetTitle == ThinkingTrainingDimension.testableActionDesign.displayTitle {
            return ThinkingTrainingDimension.testableActionDesign.trainingTitle
        }
        for dimension in ThinkingTrainingDimension.allCases where dimension.displayTitle == trainingTargetTitle {
            return dimension.trainingTitle
        }
        return trainingTargetTitle
    }
}

enum ExperienceReplayTraining {
    static let reproduceLine = "复现：条件相同，可以照用哪条做法"
    static let adaptLine = "调整：条件不同，哪部分要改"
    static let rejectLine = "否定：这条经验为什么不适用"
    static let decisionLines = [reproduceLine, adaptLine, rejectLine]
    static let line = "经验判断：\(reproduceLine)；\(adaptLine)；\(rejectLine)。"
}

struct CoachTeachingPolicy {
    static let policyVersion = "coach-teaching.local-v1"

    func makePlan(
        turn: CoachTurnState,
        prescription: TrainingPrescription?
    ) -> CoachTeachingPlan {
        if turn.decisionSource == .userOverrideProgress {
            return CoachTeachingPlan(
                policyVersion: Self.policyVersion,
                missingMoveTitle: "证据缺口仍然存在，但你选择先推进。",
                trainingTargetTitle: "带着审计边界行动",
                whyNotAnswer: "override 是推进许可，不是缺口已经消失；后续任务仍要留下校准证据。",
                proceedStandard: "任务必须留下可回看证据，方便明天校准。",
                repairQuestion: "如果明天结果和当前判断相反，你要回看哪条证据来校准这次 override？",
                experienceReplayPrompt: "回想过往一次先推进后校准的经验：这次应该复现、调整，还是避免那个做法？",
                routeSteps: ["记录用户主动推进", "保留未关闭缺口", "明天重点验证这个缺口是否造成偏差"],
                auditNote: "用户 override 不是缺口已经消失的证明。"
            )
        }

        if turn.readiness == .ready || turn.openEvidenceGaps.isEmpty {
            return CoachTeachingPlan(
                policyVersion: Self.policyVersion,
                missingMoveTitle: "现在不是继续分析，而是把判断转成明天能留下证据的行动。",
                trainingTargetTitle: (prescription?.primaryTrainingDimension ?? .testableActionDesign).displayTitle,
                whyNotAnswer: "当前证据已经足够形成验证行动，继续追问的收益低于行动校准。",
                proceedStandard: "明日行动能留下负责人、验收标准和可观察结果。",
                repairQuestion: "明天这个行动会留下什么结果证据，让你回看今天的判断是否成立？",
                experienceReplayPrompt: "回想过往一次验证行动有效的经验：这次应该复现哪条做法，哪些条件不同？",
                routeSteps: ["固定当前判断", "设计一个明日验证行动", "明天用结果校准判断"],
                auditNote: nil
            )
        }

        let primaryDimension = prescription?.primaryTrainingDimension ?? dimension(for: turn)
        return CoachTeachingPlan(
            policyVersion: Self.policyVersion,
            missingMoveTitle: missingMoveTitle(for: turn),
            trainingTargetTitle: primaryDimension.displayTitle,
            whyNotAnswer: whyNotAnswer(for: turn),
            proceedStandard: proceedStandard(for: turn),
            repairQuestion: repairQuestion(for: turn),
            experienceReplayPrompt: experienceReplayPrompt(for: turn),
            routeSteps: routeSteps(for: turn),
            auditNote: nil
        )
    }

    private func dimension(for turn: CoachTurnState) -> ThinkingTrainingDimension {
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return .judgmentCalibration
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return .systemFeedbackAwareness
        }
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return .evidenceDiscipline
        }
        return .assumptionTesting
    }

    private func missingMoveTitle(for turn: CoachTurnState) -> String {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return "你已经有行动倾向，但还没有说明可观察证据。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "你已经有判断，但还没有说明明天用什么信号校准。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "你描述了现象，但还没有看清因果链或反馈回路。"
        }
        return "当前真正要解决的问题还没有被定义清楚。"
    }

    private func whyNotAnswer(for turn: CoachTurnState) -> String {
        if turn.recommendedMove == .slowDownConvergence ||
            turn.openEvidenceGaps.contains(.missingObservation) ||
            turn.openEvidenceGaps.contains(.missingBaseline) {
            return "现在直接行动会把未经验证的解释当成事实。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "没有校准信号时，任务完成也不一定能更新判断。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "如果不先看清反馈结构，行动可能只修表面问题。"
        }
        return "问题边界不清时，答案容易变成泛泛建议。"
    }

    private func proceedStandard(for turn: CoachTurnState) -> String {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return "先说清一个可观察事实和一个验收基线。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "先说清一个实际结果信号，以及它会如何改变判断。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "先说清一个反馈信号，以及它的延迟或下游影响。"
        }
        return "先说清要解决的问题和一个关键前提。"
    }

    private func repairQuestion(for turn: CoachTurnState) -> String {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return "刚才的回答里，哪一句是可观察事实？如果没有，请补一句事实和一句验收基线。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "刚才的回答里，哪个实际结果信号会改变你的判断？如果没有，请补一个明天能观察到的信号。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "刚才的回答里，哪条因果链或反馈回路解释了这个结果？如果没有，请补一条因果链。"
        }
        if turn.openEvidenceGaps.contains(.missingCounterexample) {
            return "刚才的回答里，什么证据会推翻你现在的解释？如果没有，请补一个反例或替代解释。"
        }
        if turn.openEvidenceGaps.contains(.missingConstraint) {
            return "刚才的回答里，哪个约束决定了行动边界？如果没有，请补一个关键约束。"
        }
        return "刚才的回答里，哪句话能让你安全推进？如果没有，请补一个可验证判断。"
    }

    private func experienceReplayPrompt(for turn: CoachTurnState) -> String {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return "回想过往一次因为缺少事实或验收标准导致返工的经验：这次要复现哪条防错做法？"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "回想过往一次任务完成但判断没有更新的经验：这次要复现哪条校准做法？"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "回想过往一次只处理表面问题、没有看反馈回路的经验：这次要复现哪条结构化检查？"
        }
        if turn.openEvidenceGaps.contains(.missingCounterexample) {
            return "回想过往一次忽略反例而判断过早收敛的经验：这次要复现哪条反证检查？"
        }
        if turn.openEvidenceGaps.contains(.missingConstraint) {
            return "回想过往一次忽略约束导致行动失效的经验：这次要复现哪条边界检查？"
        }
        return "回想过往一次判断推进有效的经验：这次应该复现、调整，还是拒绝那条经验？"
    }

    private func routeSteps(for turn: CoachTurnState) -> [String] {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return ["补上一个可观察事实", "回答校准问题", "再形成明日验证行动"]
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return ["说清原判断", "定义校准信号", "把信号转成明日观察"]
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return ["画出因果链", "找到反馈或延迟", "选择能测试结构的行动"]
        }
        return ["定义问题边界", "暴露关键前提", "再选择行动"]
    }
}

struct CoachDecisionPolicyV2 {
    static let policyVersion = "coach-decision.local-v2"

    func decide(
        cards: [ThinkingCard],
        questions: [ReflectionQuestion] = [],
        learningSignals: [CoachLensLearningSignal] = []
    ) -> CoachDecisionAssessment {
        let confirmedCards = cards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
        let consideredCards = confirmedCards.isEmpty
            ? cards.filter { !$0.isExcludedFromModel }
            : confirmedCards
        let text = consideredCards
            .map { "\($0.title) \($0.body)" }
            .joined(separator: " ")
            .lowercased()
        let counts = Dictionary(grouping: consideredCards, by: \.type).mapValues(\.count)
        let hasFact = (counts[.fact] ?? 0) > 0
        let hasDecision = (counts[.decision] ?? 0) > 0
        let hasTask = (counts[.task] ?? 0) > 0
        let hasHighRiskOrProblem = consideredCards.contains { card in
            (card.type == .risk || card.type == .problem) && card.priority == .high
        }
        let evidenceSignalCount = countMatches(
            in: text,
            keywords: [
                "事实", "证据", "确认", "文档", "客户", "数据", "可观察",
                "fact", "evidence", "confirmed", "observable", "documented"
            ]
        )
        let gapSignalCount = countMatches(
            in: text,
            keywords: [
                "缺", "不足", "不清", "未确认", "推测", "依据不足", "没有验收",
                "missing", "unclear", "lack", "insufficient", "unconfirmed", "without criteria"
            ]
        )
        let actionSignalCount = countMatches(
            in: text,
            keywords: [
                "负责人", "owner", "alex", "验收", "标准", "criteria", "明天",
                "tomorrow", "小范围", "文档", "observable", "可观察"
            ]
        )
        let calibrationSignalCount = countMatches(
            in: text,
            keywords: [
                "预测", "预期", "把握", "信心", "置信", "实际", "结果", "相反",
                "校准", "更新判断", "prediction", "expected", "confidence",
                "actual", "outcome", "calibration"
            ]
        )
        let systemSignalCount = countMatches(
            in: text,
            keywords: [
                "反馈", "回路", "延迟", "滞后", "二阶", "后果", "返工", "放大", "连锁", "下游",
                "feedback", "loop", "delay", "delayed", "second-order", "downstream"
            ]
        )

        let evidenceReadiness = clampScore(
            (hasFact ? 35 : 0) +
                min(evidenceSignalCount * 12, 30) +
                min(actionSignalCount * 8, 25) +
                (hasTask ? 10 : 0) -
                min(gapSignalCount * 12, 35)
        )
        let calibrationOpportunity = clampScore(min(calibrationSignalCount * 25, 100))
        let systemFeedback = clampScore(min(systemSignalCount * 24, 100))
        let actionTestability = clampScore(
            (hasTask ? 30 : 0) +
                (hasDecision ? 15 : 0) +
                (hasFact ? 20 : 0) +
                min(actionSignalCount * 12, 35)
        )
        let convergenceRiskScore = clampScore(
            (hasHighRiskOrProblem ? 35 : 0) +
                (hasDecision ? 20 : 0) +
                min(gapSignalCount * 16, 35) +
                (evidenceReadiness < 50 ? 15 : 0) -
                (actionTestability >= 75 ? 25 : 0)
        )
        let risk = convergenceRisk(from: convergenceRiskScore)
        let historicalLearning = clampScore(learningSignals.isEmpty ? 0 : min(learningSignals.count * 25, 100))
        let scores = CoachDecisionScores(
            evidenceReadiness: evidenceReadiness,
            convergenceRisk: convergenceRiskScore,
            calibrationOpportunity: calibrationOpportunity,
            systemFeedback: systemFeedback,
            actionTestability: actionTestability,
            historicalLearning: historicalLearning
        )

        if actionTestability >= 75, evidenceReadiness >= 55, risk != .high {
            return CoachDecisionAssessment(
                policyVersion: Self.policyVersion,
                phase: .formAction,
                readiness: .ready,
                recommendedMove: .generateQuest,
                primaryTrainingDimension: .testableActionDesign,
                openEvidenceGaps: [],
                convergenceRisk: .low,
                scores: scores,
                reason: "已有任务、事实或判断，并出现负责人、验收标准或可观察结果，可以把下一步设计成验证行动。",
                whyNow: "当前材料已经足够形成明日可验证行动。",
                expectedUpdate: "把当前判断转成一个明日能产生证据的行动。",
                proceedWhen: "明日行动能留下负责人、验收标准和可观察结果。".trimmingCharacters(in: .whitespacesAndNewlines),
                learningSignals: learningSignals
            )
        }

        if risk == .high, evidenceReadiness < 60 {
            return CoachDecisionAssessment(
                policyVersion: Self.policyVersion,
                phase: .fillEvidenceGap,
                readiness: .notReady,
                recommendedMove: .slowDownConvergence,
                primaryTrainingDimension: .evidenceDiscipline,
                openEvidenceGaps: [.missingObservation, .missingBaseline],
                convergenceRisk: risk,
                scores: scores,
                reason: "当前存在高风险、问题或明确证据缺口，直接行动会过早收敛。",
                whyNow: "现在的主要风险是过早收敛，先补证据比设计明日验证更重要。",
                expectedUpdate: "回答应补足可观察事实、基线或验收口径。",
                proceedWhen: "能说清至少一个可观察事实和一个验收基线后再推进。",
                learningSignals: learningSignals
            )
        }

        if calibrationOpportunity >= 70 {
            return CoachDecisionAssessment(
                policyVersion: Self.policyVersion,
                phase: .clarifyJudgment,
                readiness: .notReady,
                recommendedMove: .surfaceEvidenceGap,
                primaryTrainingDimension: .judgmentCalibration,
                openEvidenceGaps: [.missingCalibrationSignal],
                convergenceRisk: risk,
                scores: scores,
                reason: "材料里同时出现预测、信心、实际结果或相反证据，适合校准原判断。",
                whyNow: "现在最有价值的是比较原预测和实际证据。",
                expectedUpdate: "回答应更新预测、信心或下一次判断依据。",
                proceedWhen: "能指出一个实际结果信号和它如何改变预测后再推进。",
                learningSignals: learningSignals
            )
        }

        if systemFeedback >= 70 {
            return CoachDecisionAssessment(
                policyVersion: Self.policyVersion,
                phase: .clarifyJudgment,
                readiness: .notReady,
                recommendedMove: .surfaceEvidenceGap,
                primaryTrainingDimension: .systemFeedbackAwareness,
                openEvidenceGaps: [.missingCausalLink, .missingCalibrationSignal],
                convergenceRisk: risk,
                scores: scores,
                reason: "材料里出现反馈回路、延迟影响或二阶后果，应该先理解系统结构。",
                whyNow: "现在需要看清反馈回路，而不是只修当前表面问题。",
                expectedUpdate: "回答应说明反馈、延迟或二阶后果如何改变行动选择。",
                proceedWhen: "能说清一个反馈信号及其延迟影响后再推进。",
                learningSignals: learningSignals
            )
        }

        if hasDecision {
            return CoachDecisionAssessment(
                policyVersion: Self.policyVersion,
                phase: .clarifyJudgment,
                readiness: .notReady,
                recommendedMove: .surfaceEvidenceGap,
                primaryTrainingDimension: .factInterpretationSeparation,
                openEvidenceGaps: [.missingObservation, .missingCausalLink],
                convergenceRisk: risk,
                scores: scores,
                reason: "用户已经有判断倾向，但事实、解释和依据还需要拆开。",
                whyNow: "当前先澄清判断依据，避免把解释当成事实。",
                expectedUpdate: "回答应区分事实、解释和待验证假设。",
                proceedWhen: "能列出事实依据和一个待验证假设后再推进。",
                learningSignals: learningSignals
            )
        }

        return CoachDecisionAssessment(
            policyVersion: Self.policyVersion,
            phase: .exploreProblem,
            readiness: .notReady,
            recommendedMove: .askClarifyingQuestion,
            primaryTrainingDimension: .assumptionTesting,
            openEvidenceGaps: [.missingObservation],
            convergenceRisk: risk,
            scores: scores,
            reason: "当前更像想法或沟通片段，真正要解决的问题还没有定义清楚。",
            whyNow: "现在需要先定义问题，而不是选择行动。",
            expectedUpdate: "回答应明确问题边界和需要验证的前提。",
            proceedWhen: "能说清要解决的问题和一个关键前提后再推进。",
            learningSignals: learningSignals
        )
    }

    private func convergenceRisk(from score: Int) -> CoachConvergenceRisk {
        if score >= 70 { return .high }
        if score >= 40 { return .medium }
        return .low
    }

    private func countMatches(in text: String, keywords: [String]) -> Int {
        keywords.filter { text.contains($0.lowercased()) }.count
    }

    private func clampScore(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }
}

struct CoachEngine {
    static let policyVersion = "coach-engine.local-v1"

    func diagnose(cards: [ThinkingCard]) -> CoachDiagnosis {
        let observation = CoachObservationPolicy().observe(cards: cards)
        if let diagnosis = diagnosis(from: observation) {
            return diagnosis
        }

        let confirmedCards = cards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
        let consideredCards = confirmedCards.isEmpty
            ? cards.filter { !$0.isExcludedFromModel }
            : confirmedCards

        let hasTask = consideredCards.contains { $0.type == .task }
        let hasDecision = consideredCards.contains { $0.type == .decision }
        let hasFact = consideredCards.contains { $0.type == .fact }
        let hasBlockingEvidenceGap = consideredCards.contains { card in
            guard card.type == .risk || card.type == .problem else { return false }
            return card.priority == .high || containsEvidenceGapSignal(card)
        }

        if hasTask && (hasDecision || hasFact) && !hasBlockingEvidenceGap {
            return CoachDiagnosis(
                phase: .formAction,
                readiness: .ready,
                recommendedMove: .recommendTrainingLens,
                reason: "已经出现任务、判断或事实，可以进入训练透镜，把行动设计成可验证的下一步。",
                source: .coachRecommended,
                policyVersion: Self.policyVersion
            )
        }

        if hasBlockingEvidenceGap {
            return CoachDiagnosis(
                phase: .fillEvidenceGap,
                readiness: .notReady,
                recommendedMove: .slowDownConvergence,
                reason: "当前材料暴露出风险或问题，但关键证据不足，先补证据再收敛。",
                source: .coachRecommended,
                policyVersion: Self.policyVersion
            )
        }

        if hasDecision {
            return CoachDiagnosis(
                phase: .clarifyJudgment,
                readiness: .notReady,
                recommendedMove: .surfaceEvidenceGap,
                reason: "已经有判断倾向，但事实、解释和依据还需要拆开。",
                source: .coachRecommended,
                policyVersion: Self.policyVersion
            )
        }

        return CoachDiagnosis(
            phase: .exploreProblem,
            readiness: .notReady,
            recommendedMove: .askClarifyingQuestion,
            reason: "当前更像想法或沟通片段，真正要解决的问题还没有被定义清楚。",
            source: .coachRecommended,
            policyVersion: Self.policyVersion
        )
    }

    private func diagnosis(from observation: CoachObservation) -> CoachDiagnosis? {
        switch observation.primaryGap {
        case .narrative, .object:
            return CoachDiagnosis(
                phase: .exploreProblem,
                readiness: .notReady,
                recommendedMove: .askClarifyingQuestion,
                reason: "本轮先练\(observation.trainingAbility.trainingTitle)：先把事情讲清楚一件事，让别人能复盘并看见真正问题。\(observation.feedback.ask)",
                source: .coachRecommended,
                policyVersion: Self.policyVersion
            )
        case .observation, .constraint, .causal, .counterexample, .goal, .judgment, .calibration, .experience, .execution:
            return nil
        }
    }

    private func containsEvidenceGapSignal(_ card: ThinkingCard) -> Bool {
        let text = "\(card.title) \(card.body)".lowercased()
        let keywords = [
            "缺", "不足", "不清", "没有", "未确认", "推测", "依据", "证据", "事实",
            "missing", "unclear", "without", "no ", "lack", "insufficient", "disputed", "criteria"
        ]
        return keywords.contains { text.contains($0) }
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

enum EvidenceGapType: String, Codable, CaseIterable {
    case missingObservation = "missing_observation"
    case missingBaseline = "missing_baseline"
    case missingCausalLink = "missing_causal_link"
    case missingCounterexample = "missing_counterexample"
    case missingConstraint = "missing_constraint"
    case missingCalibrationSignal = "missing_calibration_signal"
    case none

    init?(aiRawValue: String) {
        let normalized = aiRawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }
        self.init(rawValue: normalized)
    }

    var displayTitle: String {
        switch self {
        case .missingObservation:
            return "缺观察事实"
        case .missingBaseline:
            return "缺基线"
        case .missingCausalLink:
            return "缺因果链"
        case .missingCounterexample:
            return "缺反例"
        case .missingConstraint:
            return "缺约束"
        case .missingCalibrationSignal:
            return "缺校准信号"
        case .none:
            return "非证据缺口"
        }
    }
}

enum QuestionAnswerUse: String, Codable, CaseIterable {
    case updateJudgment = "update_judgment"
    case chooseAction = "choose_action"
    case testAssumption = "test_assumption"
    case collectEvidence = "collect_evidence"
    case watchCalibrationSignal = "watch_calibration_signal"

    init?(aiRawValue: String) {
        let normalized = aiRawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }
        self.init(rawValue: normalized)
    }

    var displayTitle: String {
        switch self {
        case .updateJudgment:
            return "更新判断"
        case .chooseAction:
            return "选择行动"
        case .testAssumption:
            return "测试假设"
        case .collectEvidence:
            return "收集证据"
        case .watchCalibrationSignal:
            return "观察校准信号"
        }
    }
}

enum QuestionLensMove: String, Codable, CaseIterable {
    case factInterpretationSplit = "fact_interpretation_split"
    case alternativeExplanation = "alternative_explanation"
    case leverageTradeoff = "leverage_tradeoff"
    case constraintDecomposition = "constraint_decomposition"
    case feedbackLoop = "feedback_loop"
    case delayedEffect = "delayed_effect"
    case secondOrderConsequence = "second_order_consequence"
    case predictionCalibration = "prediction_calibration"

    init?(aiRawValue: String) {
        let normalized = aiRawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }
        self.init(rawValue: normalized)
    }

    var displayTitle: String {
        switch self {
        case .factInterpretationSplit:
            return "分离事实解释"
        case .alternativeExplanation:
            return "替代解释"
        case .leverageTradeoff:
            return "杠杆取舍"
        case .constraintDecomposition:
            return "约束拆解"
        case .feedbackLoop:
            return "反馈回路"
        case .delayedEffect:
            return "延迟影响"
        case .secondOrderConsequence:
            return "二阶后果"
        case .predictionCalibration:
            return "预测校准"
        }
    }
}

struct ReflectionQuestion: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var whyItMatters: String
    var whyNow: String?
    var expectedUpdate: String?
    var proceedWhen: String?
    var evidenceGapType: EvidenceGapType?
    var answerUse: QuestionAnswerUse?
    var lensMove: QuestionLensMove?
    var sourceCardTitles: [String]
    var calibrationTarget: String?
    var answer: String

    init(
        id: UUID = UUID(),
        question: String,
        whyItMatters: String,
        whyNow: String? = nil,
        expectedUpdate: String? = nil,
        proceedWhen: String? = nil,
        evidenceGapType: EvidenceGapType? = nil,
        answerUse: QuestionAnswerUse? = nil,
        lensMove: QuestionLensMove? = nil,
        sourceCardTitles: [String] = [],
        calibrationTarget: String? = nil,
        answer: String = ""
    ) {
        self.id = id
        self.question = question
        self.whyItMatters = whyItMatters
        self.whyNow = whyNow
        self.expectedUpdate = expectedUpdate
        self.proceedWhen = proceedWhen
        self.evidenceGapType = evidenceGapType
        self.answerUse = answerUse
        self.lensMove = lensMove
        self.sourceCardTitles = sourceCardTitles
        self.calibrationTarget = calibrationTarget
        self.answer = answer
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case question
        case whyItMatters
        case whyNow
        case expectedUpdate
        case proceedWhen
        case evidenceGapType
        case answerUse
        case lensMove
        case sourceCardTitles
        case calibrationTarget
        case answer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        question = try container.decode(String.self, forKey: .question)
        whyItMatters = try container.decode(String.self, forKey: .whyItMatters)
        whyNow = try container.decodeIfPresent(String.self, forKey: .whyNow)
        expectedUpdate = try container.decodeIfPresent(String.self, forKey: .expectedUpdate)
        proceedWhen = try container.decodeIfPresent(String.self, forKey: .proceedWhen)
        evidenceGapType = try container.decodeIfPresent(EvidenceGapType.self, forKey: .evidenceGapType)
        answerUse = try container.decodeIfPresent(QuestionAnswerUse.self, forKey: .answerUse)
        lensMove = try container.decodeIfPresent(QuestionLensMove.self, forKey: .lensMove)
        sourceCardTitles = try container.decodeIfPresent([String].self, forKey: .sourceCardTitles) ?? []
        calibrationTarget = try container.decodeIfPresent(String.self, forKey: .calibrationTarget)
        answer = try container.decodeIfPresent(String.self, forKey: .answer) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(question, forKey: .question)
        try container.encode(whyItMatters, forKey: .whyItMatters)
        try container.encodeIfPresent(whyNow, forKey: .whyNow)
        try container.encodeIfPresent(expectedUpdate, forKey: .expectedUpdate)
        try container.encodeIfPresent(proceedWhen, forKey: .proceedWhen)
        try container.encodeIfPresent(evidenceGapType, forKey: .evidenceGapType)
        try container.encodeIfPresent(answerUse, forKey: .answerUse)
        try container.encodeIfPresent(lensMove, forKey: .lensMove)
        try container.encode(sourceCardTitles, forKey: .sourceCardTitles)
        try container.encodeIfPresent(calibrationTarget, forKey: .calibrationTarget)
        try container.encode(answer, forKey: .answer)
    }

    var answerTrainingPrompt: String {
        if let answerUse {
            return answerUse.answerTrainingPrompt
        }

        switch evidenceGapType {
        case .some(.missingObservation), .some(.missingBaseline):
            return QuestionAnswerUse.collectEvidence.answerTrainingPrompt
        case .some(.missingCausalLink), .some(.missingCounterexample), .some(.missingConstraint):
            return QuestionAnswerUse.testAssumption.answerTrainingPrompt
        case .some(.missingCalibrationSignal):
            return QuestionAnswerUse.watchCalibrationSignal.answerTrainingPrompt
        case .some(.none), nil:
            return QuestionAnswerUse.updateJudgment.answerTrainingPrompt
        }
    }
}

extension QuestionAnswerUse {
    var answerTrainingPrompt: String {
        switch self {
        case .collectEvidence:
            return "先写事实，再写解释：补一个可观察事实，不需要完整结论。"
        case .testAssumption:
            return "写支持或推翻：写出能验证或推翻假设的材料。"
        case .chooseAction:
            return "写选择、取舍依据、完成标准：写出一个可执行选择。"
        case .watchCalibrationSignal:
            return "写观察信号和更新条件：写出明天要观察的结果信号。"
        case .updateJudgment:
            return "写原判断、依据、更新后判断：写下判断如何更新。"
        }
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
    var calibrationTarget: String?
    var lensMove: QuestionLensMove?
    var sourceCardTitles: [String]
    var trainingPrincipleId: UUID?
    var status: QuestStatus

    init(
        id: UUID = UUID(),
        type: QuestType,
        title: String,
        whyItMatters: String,
        completionCriteria: String,
        expectedResistance: String,
        reflectionQuestion: String,
        calibrationTarget: String? = nil,
        lensMove: QuestionLensMove? = nil,
        sourceCardTitles: [String] = [],
        trainingPrincipleId: UUID? = nil,
        status: QuestStatus = .draft
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.whyItMatters = whyItMatters
        self.completionCriteria = completionCriteria
        self.expectedResistance = expectedResistance
        self.reflectionQuestion = reflectionQuestion
        self.calibrationTarget = calibrationTarget
        self.lensMove = lensMove
        self.sourceCardTitles = Self.normalizedSourceCardTitles(sourceCardTitles)
        self.trainingPrincipleId = trainingPrincipleId
        self.status = status
    }

    private static func normalizedSourceCardTitles(_ titles: [String]) -> [String] {
        titles.reduce(into: [String]()) { result, title in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
            result.append(trimmed)
        }
    }
}

struct QuestExecutionTrainingFeedback: Hashable {
    var trainingDimension: ThinkingTrainingDimension
    var judgmentLine: String
    var evidenceLine: String
    var resistanceLine: String
    var calibrationLine: String
    var trainingLine: String
}

struct QuestExecutionTrainingPolicy {
    func makeFeedback(for quest: Quest) -> QuestExecutionTrainingFeedback {
        let targetJudgment = trimmed(quest.calibrationTarget)
            ?? "这条验证行动必须回到今天的一个明确判断。"
        let completionEvidence = trimmed(quest.completionCriteria)
            ?? "明天需要留下一个可检查结果。"
        let expectedResistance = trimmed(quest.expectedResistance)
            ?? "先写出最可能阻断执行的一件事。"
        let calibrationPrompt = trimmed(quest.reflectionQuestion)
            ?? "明天用结果校准这个判断是否成立。"

        return QuestExecutionTrainingFeedback(
            trainingDimension: .testableActionDesign,
            judgmentLine: targetJudgment,
            evidenceLine: completionEvidence,
            resistanceLine: expectedResistance,
            calibrationLine: "结果校准时回答：\(calibrationPrompt)",
            trainingLine: trainingLine(for: quest)
        )
    }

    private func trainingLine(for quest: Quest) -> String {
        let move = quest.lensMove?.displayTitle ?? ThinkingTrainingDimension.testableActionDesign.displayTitle
        return "执行力训练：把今天的判断转成一个可验证行动，并用\(move)检查它是否真的改变结果。"
    }

    private func trimmed(_ text: String?) -> String? {
        guard let text else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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
    var sourceCardTitles: [String]
    var status: PrincipleStatus

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        triggerContext: String,
        actions: [String],
        successCriteria: String,
        exceptions: String,
        sourceCardTitles: [String] = [],
        status: PrincipleStatus = .active
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.triggerContext = triggerContext
        self.actions = actions
        self.successCriteria = successCriteria
        self.exceptions = exceptions
        self.sourceCardTitles = Self.normalizedSourceCardTitles(sourceCardTitles)
        self.status = status
    }

    private static func normalizedSourceCardTitles(_ titles: [String]) -> [String] {
        titles.reduce(into: [String]()) { result, title in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
            result.append(trimmed)
        }
    }
}

struct QuestTrainingTarget: Identifiable, Hashable {
    var id: UUID { principleId }
    let principleId: UUID
    var principleTitle: String
    var matchSignal: String
}

enum PrincipleRecallFeedbackValue: String, CaseIterable, Identifiable, Codable {
    case helpful
    case notApplicable = "not_applicable"
    case misrecalled

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .helpful:
            return "有帮助"
        case .notApplicable:
            return "不适用"
        case .misrecalled:
            return "误召回"
        }
    }
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
    var retrievalSignal: String
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
        retrievalSignal: String = "",
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
        self.retrievalSignal = retrievalSignal
        self.feedback = feedback
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum PrincipleRetrievalSignalDisplay {
    static func displayText(for signal: String) -> String? {
        let normalized = signal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        switch normalized.lowercased() {
        case "meeting ownership":
            return "命中会议负责人"
        case "acceptance contract", "write acceptance contract":
            return "命中验收约定"
        default:
            return "命中 \(normalized)"
        }
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
    var matchSignal: String
    var attributionPolicyVersion: String
    var practiceRole: MetricContributionPracticeRole
    var isDisputed: Bool
    var disputeNote: String
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
        matchSignal: String = "",
        attributionPolicyVersion: String = "",
        practiceRole: MetricContributionPracticeRole = .possibleSignal,
        isDisputed: Bool = false,
        disputeNote: String = "",
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
        self.matchSignal = matchSignal
        self.attributionPolicyVersion = attributionPolicyVersion
        self.practiceRole = practiceRole
        self.isDisputed = isDisputed
        self.disputeNote = disputeNote
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
    var latestPracticeEvidenceId: UUID?
    var latestPracticeEvidenceAt: Date?
    var latestPracticeEvidenceSummary: String?
    var latestPracticeEvidenceRole: MetricContributionPracticeRole?
    var latestDisputedPracticeEvidenceId: UUID?
    var latestDisputedPracticeEvidenceAt: Date?
    var latestDisputedPracticeEvidenceSummary: String?
    var latestDisputedPracticeEvidenceNote: String?
    var latestNegativeRecallFeedbackId: UUID?
    var latestNegativeRecallFeedbackAt: Date?
    var latestNegativeRecallFeedbackValue: PrincipleRecallFeedbackValue?
    var latestNegativeRecallFeedbackReason: String?
    var latestNegativeRecallFeedbackSignal: String?
    var latestNegativeRecallFeedbackNote: String?

    static func summaries(
        for principles: [PrincipleAsset],
        practiceEvidence: [PrinciplePracticeEvidence],
        recallFeedback: [PrincipleRecallFeedback],
        disputedPracticeEvidence: [PrinciplePracticeEvidence] = []
    ) -> [PrincipleTrainingSummary] {
        principles.map { principle in
            summary(
                for: principle,
                practiceEvidence: practiceEvidence.filter { $0.principleId == principle.id },
                recallFeedback: recallFeedback.filter { $0.principleId == principle.id },
                disputedPracticeEvidence: disputedPracticeEvidence.filter { $0.principleId == principle.id }
            )
        }
    }

    static func summary(
        for principle: PrincipleAsset,
        practiceEvidence: [PrinciplePracticeEvidence],
        recallFeedback: [PrincipleRecallFeedback],
        disputedPracticeEvidence: [PrinciplePracticeEvidence] = []
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
        let latestPracticeEvidence = practiceEvidence.max { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
        let latestDisputedPracticeEvidence = disputedPracticeEvidence.max { lhs, rhs in
            lhs.updatedAt < rhs.updatedAt
        }
        let latestNegativeRecallFeedback = recallFeedback
            .filter { $0.feedback == .notApplicable || $0.feedback == .misrecalled }
            .max { lhs, rhs in
                lhs.createdAt < rhs.createdAt
            }
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
            latestPracticeEvidenceId: latestPracticeEvidence?.id,
            latestPracticeEvidenceAt: latestPracticeEvidence?.createdAt,
            latestPracticeEvidenceSummary: latestPracticeEvidence?.evidenceSummary,
            latestPracticeEvidenceRole: latestPracticeEvidence?.practiceRole,
            latestDisputedPracticeEvidenceId: latestDisputedPracticeEvidence?.id,
            latestDisputedPracticeEvidenceAt: latestDisputedPracticeEvidence?.updatedAt,
            latestDisputedPracticeEvidenceSummary: latestDisputedPracticeEvidence?.evidenceSummary,
            latestDisputedPracticeEvidenceNote: latestDisputedPracticeEvidence?.disputeNote,
            latestNegativeRecallFeedbackId: latestNegativeRecallFeedback?.id,
            latestNegativeRecallFeedbackAt: latestNegativeRecallFeedback?.createdAt,
            latestNegativeRecallFeedbackValue: latestNegativeRecallFeedback?.feedback,
            latestNegativeRecallFeedbackReason: latestNegativeRecallFeedback?.retrievalReason,
            latestNegativeRecallFeedbackSignal: latestNegativeRecallFeedback?.retrievalSignal,
            latestNegativeRecallFeedbackNote: latestNegativeRecallFeedback?.note
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
    var trainingPrescription: TrainingPrescription?
    var customLensItems: [LensCatalogItem]
    var customLensQuestions: [ReflectionQuestion]
    var yesterdayCompletion: YesterdayCompletion?
    var yesterdayValueRating: YesterdayValueRating?
    var yesterdayJudgmentUpdate: YesterdayJudgmentUpdate?
    var state: DailyLoopState

    init(
        id: UUID = UUID(),
        date: Date = .now,
        rawText: String = "",
        sessionMode: SessionMode = .standard,
        hasSelectedSessionMode: Bool = false,
        selectedLens: ThinkingLens? = nil,
        selectedCustomLensId: String? = nil,
        trainingPrescription: TrainingPrescription? = nil,
        customLensItems: [LensCatalogItem] = [],
        customLensQuestions: [ReflectionQuestion] = [],
        yesterdayCompletion: YesterdayCompletion? = nil,
        yesterdayValueRating: YesterdayValueRating? = nil,
        yesterdayJudgmentUpdate: YesterdayJudgmentUpdate? = nil,
        state: DailyLoopState = .verifyYesterday
    ) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.sessionMode = sessionMode
        self.hasSelectedSessionMode = hasSelectedSessionMode
        self.selectedLens = selectedLens
        self.selectedCustomLensId = selectedCustomLensId
        self.trainingPrescription = trainingPrescription
        self.customLensItems = customLensItems
        self.customLensQuestions = customLensQuestions
        self.yesterdayCompletion = yesterdayCompletion
        self.yesterdayValueRating = yesterdayValueRating
        self.yesterdayJudgmentUpdate = yesterdayJudgmentUpdate
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

enum PromptAssetQualityGateStatus: String, CaseIterable, Identifiable {
    case passed
    case needsReview

    var id: String { rawValue }
}

enum PromptAssetQualityGateIssueReason: String, CaseIterable, Identifiable {
    case highFailureRate
    case highEmptyResultRate
    case highUserDenialRate

    var id: String { rawValue }
}

struct PromptAssetQualityGatePolicy: Hashable {
    var minimumSampleCount: Int
    var failureRateThreshold: Double
    var emptyResultRateThreshold: Double
    var userDenialRateThreshold: Double

    init(
        minimumSampleCount: Int = 4,
        failureRateThreshold: Double = 0.5,
        emptyResultRateThreshold: Double = 0.25,
        userDenialRateThreshold: Double = 0.25
    ) {
        self.minimumSampleCount = minimumSampleCount
        self.failureRateThreshold = failureRateThreshold
        self.emptyResultRateThreshold = emptyResultRateThreshold
        self.userDenialRateThreshold = userDenialRateThreshold
    }
}

struct PromptAssetQualityGateIssue: Hashable, Identifiable {
    var promptId: String
    var promptVersion: String
    var promptPackId: String
    var promptPackVersion: String
    var reason: PromptAssetQualityGateIssueReason
    var rate: Double
    var threshold: Double
    var sampleCount: Int
    var message: String
    var rollbackCandidate: PromptAssetQualityGateRollbackCandidate?

    var id: String {
        [
            promptPackId,
            promptPackVersion,
            promptId,
            promptVersion,
            reason.rawValue
        ].joined(separator: "|")
    }
}

struct PromptAssetQualityGateRollbackCandidate: Hashable, Identifiable {
    var promptId: String
    var currentVersion: String
    var rollbackTargetVersion: String
    var promptPackId: String
    var currentPromptPackVersion: String
    var rollbackPromptPackVersion: String
    var lastPassingRunId: UUID
    var lastPassingRunCreatedAt: Date
    var reason: PromptAssetQualityGateIssueReason

    var id: String {
        [
            promptPackId,
            currentPromptPackVersion,
            promptId,
            currentVersion,
            rollbackTargetVersion,
            reason.rawValue,
            lastPassingRunId.uuidString
        ].joined(separator: "|")
    }
}

struct PromptAssetQualityGate: Hashable {
    var status: PromptAssetQualityGateStatus
    var evaluatedSummaryCount: Int
    var needsReviewAssetCount: Int
    var rollbackReadyAssetCount: Int
    var manualReviewAssetCount: Int
    var issueCount: Int
    var issues: [PromptAssetQualityGateIssue]
    var rollbackCandidates: [PromptAssetQualityGateRollbackCandidate]
    var evaluatedAt: Date

    static func evaluate(
        summaries: [PromptAssetRunQualitySummary],
        policy: PromptAssetQualityGatePolicy = PromptAssetQualityGatePolicy(),
        evalRuns: [PromptEvalRun] = [],
        promptProvider: PromptProvider? = nil,
        mode: SessionMode = .standard,
        runnerVersion: String = PromptEvalRunner.currentRunnerVersion,
        evaluatedAt: Date = .now
    ) -> PromptAssetQualityGate {
        let collectedIssues = summaries.flatMap { summary in
            let candidate = rollbackCandidate(
                for: summary,
                evalRuns: evalRuns,
                promptProvider: promptProvider,
                mode: mode,
                runnerVersion: runnerVersion
            )
            return issues(for: summary, policy: policy, rollbackCandidate: candidate)
        }
        let reviewAssetIDs = Set(collectedIssues.map {
            "\($0.promptPackId)|\($0.promptPackVersion)|\($0.promptId)|\($0.promptVersion)"
        })
        let rollbackCandidates = uniqueRollbackCandidates(collectedIssues.compactMap(\.rollbackCandidate))
        let rollbackReadyAssetIDs = Set(rollbackCandidates.map {
            "\($0.promptPackId)|\($0.currentPromptPackVersion)|\($0.promptId)|\($0.currentVersion)"
        })
        return PromptAssetQualityGate(
            status: collectedIssues.isEmpty ? .passed : .needsReview,
            evaluatedSummaryCount: summaries.count,
            needsReviewAssetCount: reviewAssetIDs.count,
            rollbackReadyAssetCount: rollbackReadyAssetIDs.count,
            manualReviewAssetCount: reviewAssetIDs.subtracting(rollbackReadyAssetIDs).count,
            issueCount: collectedIssues.count,
            issues: collectedIssues,
            rollbackCandidates: rollbackCandidates,
            evaluatedAt: evaluatedAt
        )
    }

    private static func issues(
        for summary: PromptAssetRunQualitySummary,
        policy: PromptAssetQualityGatePolicy,
        rollbackCandidate: PromptAssetQualityGateRollbackCandidate?
    ) -> [PromptAssetQualityGateIssue] {
        guard summary.totalCount >= policy.minimumSampleCount else {
            return []
        }

        var issues: [PromptAssetQualityGateIssue] = []
        appendIssue(
            to: &issues,
            summary: summary,
            reason: .highFailureRate,
            rate: summary.failureRate,
            threshold: policy.failureRateThreshold,
            rollbackCandidate: rollbackCandidate
        )
        appendIssue(
            to: &issues,
            summary: summary,
            reason: .highEmptyResultRate,
            rate: summary.emptyResultRate,
            threshold: policy.emptyResultRateThreshold,
            rollbackCandidate: rollbackCandidate
        )
        appendIssue(
            to: &issues,
            summary: summary,
            reason: .highUserDenialRate,
            rate: summary.userDenialRate,
            threshold: policy.userDenialRateThreshold,
            rollbackCandidate: rollbackCandidate
        )
        return issues
    }

    private static func appendIssue(
        to issues: inout [PromptAssetQualityGateIssue],
        summary: PromptAssetRunQualitySummary,
        reason: PromptAssetQualityGateIssueReason,
        rate: Double,
        threshold: Double,
        rollbackCandidate: PromptAssetQualityGateRollbackCandidate?
    ) {
        guard rate >= threshold else { return }
        var candidate = rollbackCandidate
        candidate?.reason = reason
        issues.append(
            PromptAssetQualityGateIssue(
                promptId: summary.promptId,
                promptVersion: summary.promptVersion,
                promptPackId: summary.promptPackId,
                promptPackVersion: summary.promptPackVersion,
                reason: reason,
                rate: rate,
                threshold: threshold,
                sampleCount: summary.totalCount,
                message: message(summary: summary, reason: reason, rate: rate, threshold: threshold),
                rollbackCandidate: candidate
            )
        )
    }

    private static func rollbackCandidate(
        for summary: PromptAssetRunQualitySummary,
        evalRuns: [PromptEvalRun],
        promptProvider: PromptProvider?,
        mode: SessionMode,
        runnerVersion: String
    ) -> PromptAssetQualityGateRollbackCandidate? {
        guard let promptProvider,
              let promptID = PromptID(rawValue: summary.promptId)
        else {
            return nil
        }

        let currentTemplate = promptProvider.template(for: promptID, mode: mode)
        guard currentTemplate.version == summary.promptVersion,
              currentTemplate.sourceKind == summary.promptSourceKind,
              currentTemplate.packId == summary.promptPackId,
              currentTemplate.packVersion == summary.promptPackVersion,
              currentTemplate.systemPolicyVersion == summary.systemPolicyVersion,
              currentTemplate.contextPolicyVersion == summary.contextPolicyVersion,
              currentTemplate.outputSchemaVersion == summary.outputSchemaVersion,
              currentTemplate.evalSuiteVersion == summary.evalSuiteVersion,
              let rollbackTargetVersion = currentTemplate.rollbackTargetVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rollbackTargetVersion.isEmpty,
              let rollbackTemplate = promptProvider.template(for: promptID, mode: mode, version: rollbackTargetVersion)
        else {
            return nil
        }

        guard let passingRun = evalRuns
            .filter({
                $0.promptId == summary.promptId &&
                    $0.promptVersion == rollbackTemplate.version &&
                    $0.promptSourceKind == rollbackTemplate.sourceKind &&
                    $0.promptPackId == rollbackTemplate.packId &&
                    $0.promptPackVersion == rollbackTemplate.packVersion &&
                    $0.systemPolicyVersion == rollbackTemplate.systemPolicyVersion &&
                    $0.contextPolicyVersion == rollbackTemplate.contextPolicyVersion &&
                    $0.inputSchemaVersion == summary.inputSchemaVersion &&
                    $0.outputSchemaVersion == rollbackTemplate.outputSchemaVersion &&
                    $0.evalSuiteVersion == rollbackTemplate.evalSuiteVersion &&
                    $0.runnerVersion == runnerVersion &&
                    $0.status == .passed
            })
            .max(by: { $0.createdAt < $1.createdAt })
        else {
            return nil
        }

        return PromptAssetQualityGateRollbackCandidate(
            promptId: summary.promptId,
            currentVersion: summary.promptVersion,
            rollbackTargetVersion: rollbackTargetVersion,
            promptPackId: summary.promptPackId,
            currentPromptPackVersion: summary.promptPackVersion,
            rollbackPromptPackVersion: passingRun.promptPackVersion,
            lastPassingRunId: passingRun.id,
            lastPassingRunCreatedAt: passingRun.createdAt,
            reason: .highFailureRate
        )
    }

    private static func uniqueRollbackCandidates(
        _ candidates: [PromptAssetQualityGateRollbackCandidate]
    ) -> [PromptAssetQualityGateRollbackCandidate] {
        var seen = Set<String>()
        var uniqueCandidates: [PromptAssetQualityGateRollbackCandidate] = []
        for candidate in candidates {
            let key = [
                candidate.promptPackId,
                candidate.currentPromptPackVersion,
                candidate.promptId,
                candidate.currentVersion,
                candidate.rollbackTargetVersion
            ].joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            uniqueCandidates.append(candidate)
        }
        return uniqueCandidates
    }

    private static func message(
        summary: PromptAssetRunQualitySummary,
        reason: PromptAssetQualityGateIssueReason,
        rate: Double,
        threshold: Double
    ) -> String {
        let name = PromptID(rawValue: summary.promptId)?.displayName ?? summary.promptId
        let rateText = percent(rate)
        let thresholdText = percent(threshold)
        switch reason {
        case .highFailureRate:
            return "\(name) 运行失败率 \(rateText)，达到复查阈值 \(thresholdText)。"
        case .highEmptyResultRate:
            return "\(name) 空结果率 \(rateText)，达到复查阈值 \(thresholdText)。"
        case .highUserDenialRate:
            return "\(name) 用户否认率 \(rateText)，达到复查阈值 \(thresholdText)。"
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
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
                    promptID: promptID,
                    template: template,
                    runs: runs,
                    reason: .staleVersion,
                    promptProvider: promptProvider,
                    mode: mode,
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
                    promptID: promptID,
                    template: template,
                    runs: runs,
                    reason: .failedCases,
                    promptProvider: promptProvider,
                    mode: mode,
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
        promptID: PromptID,
        template: PromptTemplate,
        runs: [PromptEvalRun],
        reason: PromptEvalReleaseGateIssueReason,
        promptProvider: PromptProvider,
        mode: SessionMode,
        runnerVersion: String
    ) -> PromptEvalRollbackCandidate? {
        guard let rollbackTargetVersion = template.rollbackTargetVersion,
              !rollbackTargetVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        guard let rollbackTemplate = promptProvider.template(for: promptID, mode: mode, version: rollbackTargetVersion) else {
            return nil
        }

        let promptId = promptID.rawValue
        guard let passingRun = runs
            .filter({
                $0.promptId == promptId &&
                    $0.promptVersion == rollbackTemplate.version &&
                    $0.systemPolicyVersion == rollbackTemplate.systemPolicyVersion &&
                    $0.contextPolicyVersion == rollbackTemplate.contextPolicyVersion &&
                    $0.inputSchemaVersion == 1 &&
                    $0.outputSchemaVersion == rollbackTemplate.outputSchemaVersion &&
                    $0.evalSuiteVersion == rollbackTemplate.evalSuiteVersion &&
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

enum MetricContributionPracticeRole: String, CaseIterable, Identifiable, Codable {
    case targetedPractice
    case secondaryPractice
    case possibleSignal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .targetedPractice: return "主练"
        case .secondaryPractice: return "次练"
        case .possibleSignal: return "可能信号"
        }
    }
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
    var practiceRole: MetricContributionPracticeRole
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
        practiceRole: MetricContributionPracticeRole = .possibleSignal,
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
        self.practiceRole = practiceRole
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
            return record.quests.first { $0.id.uuidString == link.sourceId }?.title ?? "明日验证"
        case .verification:
            return record.verification?.calibrationNote ?? "结果校准"
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
