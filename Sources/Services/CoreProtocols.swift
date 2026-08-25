import Foundation
import UserNotifications

enum PromptID: String, Codable, CaseIterable, Identifiable {
    case organizeCards
    case recommendLenses
    case generateQuestions
    case generateQuests
    case verifyQuest
    case extractPrinciple
    case suggestProjectLinks
    case generateProjectInsights
    case suggestProjectMerges
    case generateSideQuest
    case weeklyCalibration
    case monthlyGrowth
    case recommendGuidance
    case evaluateGuidanceEvidence
    case diagnoseTrainingCase
    case reviewCoachAnswer

    var id: String { rawValue }

    /// Stable product-level routing for the global decision center. It is
    /// derived from the PromptID so existing PromptRun rows need no migration.
    var decisionRoute: LLMDecisionRoute {
        switch self {
        case .organizeCards:
            return .capture
        case .recommendLenses, .generateQuestions, .generateQuests, .diagnoseTrainingCase, .reviewCoachAnswer:
            return .coaching
        case .verifyQuest, .extractPrinciple, .weeklyCalibration, .monthlyGrowth,
             .recommendGuidance, .evaluateGuidanceEvidence:
            return .calibration
        case .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges:
            return .projects
        case .generateSideQuest:
            return .life
        }
    }

    var displayName: String {
        switch self {
        case .organizeCards: return "整理卡片"
        case .recommendLenses: return "推荐透镜"
        case .generateQuestions: return "生成追问"
        case .generateQuests: return "设计明日验证"
        case .verifyQuest: return "结果校准"
        case .extractPrinciple: return "沉淀原则"
        case .suggestProjectLinks: return "建议长期议题"
        case .generateProjectInsights: return "生成项目洞察"
        case .suggestProjectMerges: return "建议合并议题"
        case .generateSideQuest: return "生成生活奇遇"
        case .weeklyCalibration: return "周校准"
        case .monthlyGrowth: return "月度成长"
        case .recommendGuidance: return "选择当前提示"
        case .evaluateGuidanceEvidence: return "判断提示证据"
        case .diagnoseTrainingCase: return "诊断事项训练重点"
        case .reviewCoachAnswer: return "复盘教练回答"
        }
    }
}

enum LLMDecisionRoute: String, Codable, CaseIterable, Hashable, Identifiable {
    case capture
    case coaching
    case calibration
    case projects
    case life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capture: return "整理中心"
        case .coaching: return "教练中心"
        case .calibration: return "校准成长中心"
        case .projects: return "项目中心"
        case .life: return "生活奇遇中心"
        }
    }
}

struct PromptTemplate: Codable, Hashable {
    let id: PromptID
    let version: String
    var systemPolicyVersion: String = "system.v1"
    var contextPolicyVersion: String = "context.v1"
    var evalSuiteVersion: String = "eval.v1"
    var rollbackTargetVersion: String?
    var sourceKind: PromptAssetSourceKind = .builtin
    var packId: String = "mingsi.builtin.prompts"
    var packVersion: String = "builtin.v1"
    var packDisplayName: String = "MingSi Built-in Prompt Pack"
    let systemText: String
    let userText: String
    let outputSchemaVersion: Int

    func applyingPackMetadata(_ pack: PromptAssetPack) -> PromptTemplate {
        var copy = self
        copy.sourceKind = pack.sourceKind
        copy.packId = pack.id
        copy.packVersion = pack.version
        copy.packDisplayName = pack.displayName
        return copy
    }
}

struct LLMRequest: Hashable {
    /// Correlates transport auditing with the output that reaches a coach surface.
    let traceID: UUID
    let prompt: PromptTemplate
    let inputSummary: String
    var contextPayload: PromptContextPayload?
    var sourceRecordIDs: [String] = []
    var contextVersion: Int = 1
    var contextRecordIDs: [String] = []

    var decisionRoute: LLMDecisionRoute {
        prompt.id.decisionRoute
    }

    init(
        traceID: UUID = UUID(),
        prompt: PromptTemplate,
        inputSummary: String,
        contextPayload: PromptContextPayload? = nil,
        sourceRecordIDs: [String] = [],
        contextVersion: Int = 1,
        contextRecordIDs: [String] = []
    ) {
        self.traceID = traceID
        self.prompt = prompt
        self.inputSummary = inputSummary
        self.contextPayload = contextPayload
        self.sourceRecordIDs = sourceRecordIDs
        self.contextVersion = contextVersion
        self.contextRecordIDs = contextRecordIDs
    }
}

struct PromptContextPayload: Codable, Hashable {
    struct LensCatalogContext: Codable, Hashable {
        struct UIMetadata: Codable, Hashable {
            var symbolName: String
            var accentRole: LensAccentRole
            var methodIndex: Int
        }

        var localId: String
        var promptId: String
        var version: String
        var title: String
        var methodLine: String
        var promptGuidance: String
        var purpose: String
        var questionStrategy: String
        var taskSelectionRule: String
        var applicability: String
        var disableConditions: [String]
        var uiMetadata: UIMetadata
        var sourceKind: LensAssetSourceKind
        var packId: String
        var packVersion: String
        var packDisplayName: String

        init(
            localId: String,
            promptId: String,
            version: String,
            title: String,
            methodLine: String,
            promptGuidance: String,
            purpose: String,
            questionStrategy: String,
            taskSelectionRule: String,
            applicability: String,
            disableConditions: [String],
            uiMetadata: UIMetadata,
            sourceKind: LensAssetSourceKind = .localCustom,
            packId: String = "local.custom-lenses",
            packVersion: String? = nil,
            packDisplayName: String = "Local Custom Lenses"
        ) {
            self.localId = localId
            self.promptId = promptId
            self.version = version
            self.title = title
            self.methodLine = methodLine
            self.promptGuidance = promptGuidance
            self.purpose = purpose
            self.questionStrategy = questionStrategy
            self.taskSelectionRule = taskSelectionRule
            self.applicability = applicability
            self.disableConditions = disableConditions
            self.uiMetadata = uiMetadata
            self.sourceKind = sourceKind
            self.packId = packId
            self.packVersion = packVersion ?? version
            self.packDisplayName = packDisplayName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let localId = try container.decode(String.self, forKey: .localId)
            let promptId = try container.decode(String.self, forKey: .promptId)
            let version = try container.decode(String.self, forKey: .version)
            let sourceKind = try container.decodeIfPresent(LensAssetSourceKind.self, forKey: .sourceKind)
                ?? Self.defaultSourceKind(localId: localId, promptId: promptId)
            self.init(
                localId: localId,
                promptId: promptId,
                version: version,
                title: try container.decode(String.self, forKey: .title),
                methodLine: try container.decode(String.self, forKey: .methodLine),
                promptGuidance: try container.decode(String.self, forKey: .promptGuidance),
                purpose: try container.decode(String.self, forKey: .purpose),
                questionStrategy: try container.decode(String.self, forKey: .questionStrategy),
                taskSelectionRule: try container.decode(String.self, forKey: .taskSelectionRule),
                applicability: try container.decode(String.self, forKey: .applicability),
                disableConditions: try container.decode([String].self, forKey: .disableConditions),
                uiMetadata: try container.decode(UIMetadata.self, forKey: .uiMetadata),
                sourceKind: sourceKind,
                packId: try container.decodeIfPresent(String.self, forKey: .packId)
                    ?? Self.defaultPackId(sourceKind: sourceKind, localId: localId, promptId: promptId),
                packVersion: try container.decodeIfPresent(String.self, forKey: .packVersion)
                    ?? Self.defaultPackVersion(sourceKind: sourceKind, localId: localId, promptId: promptId),
                packDisplayName: try container.decodeIfPresent(String.self, forKey: .packDisplayName)
                    ?? Self.defaultPackDisplayName(sourceKind: sourceKind, localId: localId, promptId: promptId)
            )
        }

        private static func defaultSourceKind(localId: String, promptId: String) -> LensAssetSourceKind {
            builtinItem(localId: localId, promptId: promptId)?.sourceKind ?? .localCustom
        }

        private static func defaultPackId(sourceKind: LensAssetSourceKind, localId: String, promptId: String) -> String {
            if sourceKind == .builtin,
               let item = builtinItem(localId: localId, promptId: promptId) {
                return item.packId
            }
            return "local.custom-lenses"
        }

        private static func defaultPackVersion(sourceKind: LensAssetSourceKind, localId: String, promptId: String) -> String {
            if sourceKind == .builtin,
               let item = builtinItem(localId: localId, promptId: promptId) {
                return item.packVersion
            }
            return "session.v1"
        }

        private static func defaultPackDisplayName(sourceKind: LensAssetSourceKind, localId: String, promptId: String) -> String {
            if sourceKind == .builtin,
               let item = builtinItem(localId: localId, promptId: promptId) {
                return item.packDisplayName
            }
            return "Local Custom Lenses"
        }

        private static func builtinItem(localId: String, promptId: String) -> LensCatalogItem? {
            BuiltinLensCatalog.item(localId: localId) ?? BuiltinLensCatalog.item(promptId: promptId)
        }
    }

    struct CurrentInput: Codable, Hashable {
        var dailyEntryId: String?
        var rawText: String?
    }

    struct CurrentCaseContext: Codable, Hashable {
        var id: String
        var title: String
        var status: String
        var evidenceRefs: [String]
    }

    struct UserChoice: Codable, Hashable {
        var sessionMode: String
        var selectedLens: String?
        var lensCatalog: LensCatalogContext?
    }

    struct TrainingPrescriptionContext: Codable, Hashable {
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
            primaryTrainingDimension: ThinkingTrainingDimension,
            secondaryTrainingDimensions: [ThinkingTrainingDimension],
            baselineTrainingDimensions: [ThinkingTrainingDimension],
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
            self.primaryTrainingDimension = primaryTrainingDimension
            self.secondaryTrainingDimensions = secondaryTrainingDimensions
            self.baselineTrainingDimensions = baselineTrainingDimensions
            self.userSelectedLensId = userSelectedLensId
            self.finalLensId = finalLensId
            self.source = source
            self.overrideBoundary = overrideBoundary
        }

        init(_ prescription: TrainingPrescription) {
            self.init(
                recommendedLensId: prescription.recommendedLensId,
                recommendedPromptId: prescription.recommendedPromptId,
                recommendationReason: prescription.recommendationReason,
                confidence: prescription.confidence,
                policyVersion: prescription.policyVersion,
                alternativeLensIds: prescription.alternativeLensIds,
                baselineChecks: prescription.baselineChecks,
                primaryTrainingDimension: prescription.primaryTrainingDimension,
                secondaryTrainingDimensions: prescription.secondaryTrainingDimensions,
                baselineTrainingDimensions: prescription.baselineTrainingDimensions,
                userSelectedLensId: prescription.userSelectedLensId,
                finalLensId: prescription.finalLensId,
                source: prescription.source,
                overrideBoundary: prescription.overrideBoundary
            )
        }
    }

    struct CoachDiagnosisContext: Codable, Hashable {
        var phase: ThinkingPhase
        var readiness: ConvergenceReadiness
        var recommendedMove: NextCoachMove
        var reason: String
        var source: CoachDiagnosisSource
        var policyVersion: String

        init(
            phase: ThinkingPhase,
            readiness: ConvergenceReadiness,
            recommendedMove: NextCoachMove,
            reason: String,
            source: CoachDiagnosisSource,
            policyVersion: String
        ) {
            self.phase = phase
            self.readiness = readiness
            self.recommendedMove = recommendedMove
            self.reason = reason
            self.source = source
            self.policyVersion = policyVersion
        }

        init(_ diagnosis: CoachDiagnosis) {
            self.init(
                phase: diagnosis.phase,
                readiness: diagnosis.readiness,
                recommendedMove: diagnosis.recommendedMove,
                reason: diagnosis.reason,
                source: diagnosis.source,
                policyVersion: diagnosis.policyVersion
            )
        }
    }

    struct CoachTurnStateContext: Codable, Hashable {
        var phase: ThinkingPhase
        var readiness: ConvergenceReadiness
        var recommendedMove: NextCoachMove
        var reason: String
        var openEvidenceGaps: [EvidenceGapType]
        var baselineChecks: [BaselineThinkingCheck]
        var decisionSource: CoachDiagnosisSource
        var policyVersion: String
        var turnSummary: String

        init(
            phase: ThinkingPhase,
            readiness: ConvergenceReadiness,
            recommendedMove: NextCoachMove,
            reason: String,
            openEvidenceGaps: [EvidenceGapType],
            baselineChecks: [BaselineThinkingCheck],
            decisionSource: CoachDiagnosisSource,
            policyVersion: String,
            turnSummary: String
        ) {
            self.phase = phase
            self.readiness = readiness
            self.recommendedMove = recommendedMove
            self.reason = reason
            self.openEvidenceGaps = openEvidenceGaps
            self.baselineChecks = baselineChecks
            self.decisionSource = decisionSource
            self.policyVersion = policyVersion
            self.turnSummary = turnSummary
        }

        init(_ state: CoachTurnState) {
            self.init(
                phase: state.phase,
                readiness: state.readiness,
                recommendedMove: state.recommendedMove,
                reason: state.reason,
                openEvidenceGaps: state.openEvidenceGaps,
                baselineChecks: state.baselineChecks,
                decisionSource: state.decisionSource,
                policyVersion: state.policyVersion,
                turnSummary: state.turnSummary
            )
        }
    }

    struct CoachTeachingPlanContext: Codable, Hashable {
        var policyVersion: String
        var missingMoveTitle: String
        var trainingTargetTitle: String
        var whyNotAnswer: String
        var proceedStandard: String
        var repairQuestion: String
        var experienceReplayPrompt: String
        var routeSteps: [String]
        var auditNote: String?

        init(
            policyVersion: String,
            missingMoveTitle: String,
            trainingTargetTitle: String,
            whyNotAnswer: String,
            proceedStandard: String,
            repairQuestion: String,
            experienceReplayPrompt: String,
            routeSteps: [String],
            auditNote: String? = nil
        ) {
            self.policyVersion = policyVersion
            self.missingMoveTitle = missingMoveTitle
            self.trainingTargetTitle = trainingTargetTitle
            self.whyNotAnswer = whyNotAnswer
            self.proceedStandard = proceedStandard
            self.repairQuestion = repairQuestion
            self.experienceReplayPrompt = experienceReplayPrompt
            self.routeSteps = routeSteps
            self.auditNote = auditNote
        }

        init(_ plan: CoachTeachingPlan) {
            self.init(
                policyVersion: plan.policyVersion,
                missingMoveTitle: plan.missingMoveTitle,
                trainingTargetTitle: plan.trainingTargetTitle,
                whyNotAnswer: plan.whyNotAnswer,
                proceedStandard: plan.proceedStandard,
                repairQuestion: plan.repairQuestion,
                experienceReplayPrompt: plan.experienceReplayPrompt,
                routeSteps: plan.routeSteps,
                auditNote: plan.auditNote
            )
        }

        enum CodingKeys: String, CodingKey {
            case policyVersion
            case missingMoveTitle
            case trainingTargetTitle
            case whyNotAnswer
            case proceedStandard
            case repairQuestion
            case experienceReplayPrompt
            case routeSteps
            case auditNote
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                policyVersion: container.decode(String.self, forKey: .policyVersion),
                missingMoveTitle: container.decode(String.self, forKey: .missingMoveTitle),
                trainingTargetTitle: container.decode(String.self, forKey: .trainingTargetTitle),
                whyNotAnswer: container.decode(String.self, forKey: .whyNotAnswer),
                proceedStandard: container.decode(String.self, forKey: .proceedStandard),
                repairQuestion: container.decodeIfPresent(String.self, forKey: .repairQuestion) ?? "",
                experienceReplayPrompt: container.decodeIfPresent(String.self, forKey: .experienceReplayPrompt) ?? "",
                routeSteps: container.decode([String].self, forKey: .routeSteps),
                auditNote: container.decodeIfPresent(String.self, forKey: .auditNote)
            )
        }
    }

    struct CoachObservationContext: Codable, Hashable {
        struct FeedbackContext: Codable, Hashable {
            var observed: String
            var diagnosis: String
            var training: String
            var ask: String
            var proceedWhen: String

            init(_ feedback: CoachObservationFeedback) {
                self.observed = feedback.observed
                self.diagnosis = feedback.diagnosis
                self.training = feedback.training
                self.ask = feedback.ask
                self.proceedWhen = feedback.proceedWhen
            }
        }

        var policyVersion: String
        var providedMaterials: [CoachObservationMaterial]
        var missingMaterials: [CoachObservationMaterial]
        var thinkingProcessObservation: String
        var primaryGap: CoachObservationGap
        var secondaryGaps: [CoachObservationGap]
        var trainingAbility: CoreTrainingAbility
        var feedback: FeedbackContext
        var experienceReplayPrompt: String

        init(_ observation: CoachObservation) {
            self.policyVersion = observation.policyVersion
            self.providedMaterials = observation.providedMaterials
            self.missingMaterials = observation.missingMaterials
            self.thinkingProcessObservation = observation.thinkingProcessObservation
            self.primaryGap = observation.primaryGap
            self.secondaryGaps = observation.secondaryGaps
            self.trainingAbility = observation.trainingAbility
            self.feedback = FeedbackContext(observation.feedback)
            self.experienceReplayPrompt = observation.experienceReplayPrompt
        }
    }

    struct CoachPatternSummaryContext: Codable, Hashable {
        struct PatternContext: Codable, Hashable {
            var primaryGap: CoachQualityGap
            var foundationalAbility: CoachFoundationalAbility
            var count: Int
            var minimalTrainingAction: String

            init(_ signal: CoachPatternSignal) {
                self.primaryGap = signal.primaryGap
                self.foundationalAbility = signal.foundationalAbility
                self.count = signal.count
                self.minimalTrainingAction = signal.minimalTrainingAction
            }
        }

        var policyVersion: String
        var analyzedRecordCount: Int
        var totalSignalCount: Int
        var sourceDailyEntryIds: [String]
        var topPatterns: [PatternContext]
        var guidanceLine: String

        init(_ summary: CoachPatternSummary) {
            self.policyVersion = summary.policyVersion
            self.analyzedRecordCount = summary.analyzedRecordCount
            self.totalSignalCount = summary.totalSignalCount
            self.sourceDailyEntryIds = summary.sourceDailyEntryIds
            self.topPatterns = summary.topPatterns.map(PatternContext.init)
            self.guidanceLine = summary.guidanceLine
        }
    }

    struct Card: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var body: String
        var priority: String
        var sensitivity: String
        var isExcludedFromModel: Bool
    }

    struct Answer: Codable, Hashable {
        var id: String
        var question: String
        var answer: String
        var calibrationTarget: String? = nil
    }

    struct QuestContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var completionCriteria: String
        var calibrationTarget: String? = nil
    }

    struct PrincipleContext: Codable, Hashable {
        var id: String
        var title: String
        var summary: String
        var triggerContext: String
        var successCriteria: String
        var exceptions: String
        var status: PrincipleStatus
        var retrievalReason: String
        var retrievalPolicyVersion: String
        var retrievalSignal: String

        init(
            id: String,
            title: String,
            summary: String,
            triggerContext: String,
            successCriteria: String,
            exceptions: String,
            status: PrincipleStatus,
            retrievalReason: String = "",
            retrievalPolicyVersion: String = "",
            retrievalSignal: String = ""
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.triggerContext = triggerContext
            self.successCriteria = successCriteria
            self.exceptions = exceptions
            self.status = status
            self.retrievalReason = retrievalReason
            self.retrievalPolicyVersion = retrievalPolicyVersion
            self.retrievalSignal = retrievalSignal
        }
    }

    struct Privacy: Codable, Hashable {
        var rules: String?
    }

    struct PromptDirectives: Codable, Hashable {
        var privacyRules: String?
        var streamProtocol: String?
        var principleUsageRule: String?
        var principleSelectionRule: String?
        var coachDiagnosisRule: String?
        var coachTurnRule: String?
        var coachTeachingRule: String?
        var coachObservationRule: String?
        var coachPatternSummaryRule: String?
    }

    struct VerificationContext: Codable, Hashable {
        var questTitle: String
        var completionCriteria: String
        var targetJudgment: String? = nil
        var trainingPrinciple: VerificationTrainingPrincipleContext? = nil
        var completion: String
        var valueRating: String
        var judgmentUpdate: String
    }

    struct VerificationTrainingPrincipleContext: Codable, Hashable {
        var principleId: String
        var principleTitle: String
        var matchSignal: String

        init(principleId: UUID, principleTitle: String, matchSignal: String) {
            self.principleId = principleId.uuidString
            self.principleTitle = principleTitle
            self.matchSignal = matchSignal
        }

        init(principleId: String, principleTitle: String, matchSignal: String) {
            self.principleId = principleId
            self.principleTitle = principleTitle
            self.matchSignal = matchSignal
        }
    }

    struct LensFeedbackContext: Codable, Hashable {
        var lensId: String
        var lensTitle: String
        var signal: String
        var completion: String
        var valueRating: String
        var calibrationNote: String
        var recommendation: String?
        var questionTargets: [String]
        var evidenceGapTypes: [String]
        var lensMoves: [String]
    }

    struct GrowthRecordContext: Codable, Hashable {
        var dailyEntryId: String
        var date: Date
        var confirmedCardCount: Int
        var hasMainQuest: Bool
        var mainQuestTitle: String?
        var mainQuestCompletionCriteria: String?
        var verificationCompletion: String?
        var verificationValueRating: String?
        var calibrationNote: String?
        var hasLensSessionAnswers: Bool
        var principleTitles: [String]
    }

    struct GrowthSnapshotContext: Codable, Hashable {
        var clarity: Double
        var valueJudgment: Double
        var executionReliability: Double
        var calibration: Double
        var reflectionDepth: Double
    }

    struct GrowthContext: Codable, Hashable {
        var period: String
        var startDate: Date?
        var endDate: Date?
        var completeLoopCount: Int
        var records: [GrowthRecordContext]
        var previousSnapshot: GrowthSnapshotContext?
        var dismissedContributionTitles: [String]
    }

    struct ProjectCardContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var body: String
    }

    struct ProjectQuestContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var completionCriteria: String
    }

    struct ActiveProjectContext: Codable, Hashable {
        var id: String
        var name: String
        var goal: String?
        var successCriteria: String?
        var status: String?
    }

    struct ProjectEvidenceContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var body: String
    }

    struct ProjectLinkContext: Codable, Hashable {
        var projectId: String
        var sourceId: String
        var sourceType: String
        var linkType: String
    }

    struct ProjectContext: Codable, Hashable {
        var dailyEntryId: String
        var confirmedCards: [ProjectCardContext]
        var quests: [ProjectQuestContext]
        var activeProjects: [ActiveProjectContext]
        var existingLinkSourceIds: [String]
        var projectId: String?
        var projectName: String?
        var projectGoal: String?
        var projectSuccessCriteria: String?
        var confirmedEvidence: [ProjectEvidenceContext] = []
        var acceptedInsightCount: Int?
        var confirmedProjectLinks: [ProjectLinkContext] = []
    }

    var currentInput: CurrentInput
    var currentCase: CurrentCaseContext?
    var userChoice: UserChoice
    var trainingPrescription: TrainingPrescriptionContext?
    var coachDiagnosis: CoachDiagnosisContext?
    var coachTurnState: CoachTurnStateContext?
    var coachTeachingPlan: CoachTeachingPlanContext?
    var coachObservation: CoachObservationContext?
    var coachPatternSummary: CoachPatternSummaryContext?
    var cards: [Card]
    var answers: [Answer]
    var quests: [QuestContext]
    var principles: [PrincipleContext]
    var existingPrinciples: [PrincipleContext]
    var privacy: Privacy
    var directives: PromptDirectives
    var verification: VerificationContext?
    var lensFeedback: [LensFeedbackContext]
    var growth: GrowthContext?
    var project: ProjectContext?

    var rawText: String {
        currentInput.rawText ?? ""
    }

    var sessionMode: SessionMode? {
        SessionMode(rawValue: userChoice.sessionMode)
    }

    var selectedLens: ThinkingLens? {
        userChoice.selectedLens.flatMap(ThinkingLens.init(rawValue:))
    }

    var privacyRules: String {
        privacy.rules ?? ""
    }

    var confirmedCards: [Card] {
        cards
    }

    var relevantPrinciples: [PrincipleContext] {
        principles
    }

    init(
        currentInput: CurrentInput = CurrentInput(),
        currentCase: CurrentCaseContext? = nil,
        userChoice: UserChoice,
        cards: [Card] = [],
        answers: [Answer] = [],
        quests: [QuestContext] = [],
        principles: [PrincipleContext] = [],
        existingPrinciples: [PrincipleContext] = [],
        privacy: Privacy = Privacy(),
        directives: PromptDirectives = PromptDirectives(),
        verification: VerificationContext? = nil,
        lensFeedback: [LensFeedbackContext] = [],
        growth: GrowthContext? = nil,
        project: ProjectContext? = nil,
        trainingPrescription: TrainingPrescriptionContext? = nil,
        coachDiagnosis: CoachDiagnosisContext? = nil,
        coachTurnState: CoachTurnStateContext? = nil,
        coachTeachingPlan: CoachTeachingPlanContext? = nil,
        coachObservation: CoachObservationContext? = nil,
        coachPatternSummary: CoachPatternSummaryContext? = nil
    ) {
        self.currentInput = currentInput
        self.currentCase = currentCase
        self.userChoice = userChoice
        self.trainingPrescription = trainingPrescription
        self.coachDiagnosis = coachDiagnosis
        self.coachTurnState = coachTurnState
        self.coachTeachingPlan = coachTeachingPlan
        self.coachObservation = coachObservation
        self.coachPatternSummary = coachPatternSummary
        self.cards = cards
        self.answers = answers
        self.quests = quests
        self.principles = principles
        self.existingPrinciples = existingPrinciples
        self.privacy = privacy
        self.directives = directives
        self.verification = verification
        self.lensFeedback = lensFeedback
        self.growth = growth
        self.project = project
    }

    func applyingDirectives(_ directives: PromptDirectives) -> PromptContextPayload {
        var copy = self
        if let privacyRules = directives.privacyRules {
            copy.privacy.rules = privacyRules
            copy.directives.privacyRules = privacyRules
        }
        if let streamProtocol = directives.streamProtocol {
            copy.directives.streamProtocol = streamProtocol
        }
        if let principleUsageRule = directives.principleUsageRule {
            copy.directives.principleUsageRule = principleUsageRule
        }
        if let principleSelectionRule = directives.principleSelectionRule {
            copy.directives.principleSelectionRule = principleSelectionRule
        }
        if let coachDiagnosisRule = directives.coachDiagnosisRule {
            copy.directives.coachDiagnosisRule = coachDiagnosisRule
        }
        if let coachTurnRule = directives.coachTurnRule {
            copy.directives.coachTurnRule = coachTurnRule
        }
        if let coachTeachingRule = directives.coachTeachingRule {
            copy.directives.coachTeachingRule = coachTeachingRule
        }
        if let coachObservationRule = directives.coachObservationRule {
            copy.directives.coachObservationRule = coachObservationRule
        }
        if let coachPatternSummaryRule = directives.coachPatternSummaryRule {
            copy.directives.coachPatternSummaryRule = coachPatternSummaryRule
        }
        return copy
    }

    var legacyKeyValues: [String: String] {
        var values: [String: String] = [:]
        values["sessionMode"] = userChoice.sessionMode

        if let promptId = userChoice.lensCatalog?.promptId {
            values["selectedLens"] = promptId
        } else if let selectedLens = userChoice.selectedLens {
            values["selectedLens"] = selectedLens
        }
        if let lensCatalog = userChoice.lensCatalog {
            values["lensTitle"] = lensCatalog.title
            values["lensMethodLine"] = lensCatalog.methodLine
            values["lensPromptGuidance"] = lensCatalog.promptGuidance
            values["lensPurpose"] = lensCatalog.purpose
            values["lensQuestionStrategy"] = lensCatalog.questionStrategy
            values["lensTaskSelectionRule"] = lensCatalog.taskSelectionRule
            values["lensApplicability"] = lensCatalog.applicability
            values["lensDisableConditions"] = lensCatalog.disableConditions.joined(separator: "\n")
            values["lensSourceKind"] = lensCatalog.sourceKind.rawValue
            values["lensPackId"] = lensCatalog.packId
            values["lensPackVersion"] = lensCatalog.packVersion
            values["lensPackDisplayName"] = lensCatalog.packDisplayName
        }
        if let trainingPrescription {
            values["coachRecommendedLens"] = trainingPrescription.recommendedLensId
            values["coachRecommendedPrompt"] = trainingPrescription.recommendedPromptId
            values["coachRecommendationReason"] = trainingPrescription.recommendationReason
            values["coachRecommendationConfidence"] = String(format: "%.2f", trainingPrescription.confidence)
            values["coachRecommendationPolicyVersion"] = trainingPrescription.policyVersion
            values["coachAlternativeLenses"] = trainingPrescription.alternativeLensIds.joined(separator: ",")
            values["baselineThinkingChecks"] = trainingPrescription.baselineChecks.map(\.rawValue).joined(separator: ",")
            values["primaryTrainingDimension"] = trainingPrescription.primaryTrainingDimension.rawValue
            values["secondaryTrainingDimensions"] = trainingPrescription.secondaryTrainingDimensions.map(\.rawValue).joined(separator: ",")
            values["baselineTrainingDimensions"] = trainingPrescription.baselineTrainingDimensions.map(\.rawValue).joined(separator: ",")
            if let userSelectedLensId = trainingPrescription.userSelectedLensId {
                values["userSelectedTrainingLens"] = userSelectedLensId
            }
            values["finalTrainingLens"] = trainingPrescription.finalLensId
            values["trainingPrescriptionSource"] = trainingPrescription.source.rawValue
            if !trainingPrescription.overrideBoundary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                values["trainingOverrideBoundary"] = trainingPrescription.overrideBoundary
            }
        }
        if let coachDiagnosis {
            values["coachThinkingPhase"] = coachDiagnosis.phase.rawValue
            values["coachReadiness"] = coachDiagnosis.readiness.rawValue
            values["coachRecommendedMove"] = coachDiagnosis.recommendedMove.rawValue
            values["coachDiagnosisReason"] = coachDiagnosis.reason
            values["coachDiagnosisSource"] = coachDiagnosis.source.rawValue
            values["coachDiagnosisPolicyVersion"] = coachDiagnosis.policyVersion
        }
        if let coachTurnState {
            values["coachTurnPhase"] = coachTurnState.phase.rawValue
            values["coachTurnReadiness"] = coachTurnState.readiness.rawValue
            values["coachTurnRecommendedMove"] = coachTurnState.recommendedMove.rawValue
            values["coachTurnReason"] = coachTurnState.reason
            values["coachTurnOpenEvidenceGaps"] = coachTurnState.openEvidenceGaps.map(\.rawValue).joined(separator: ",")
            values["coachTurnBaselineChecks"] = coachTurnState.baselineChecks.map(\.rawValue).joined(separator: ",")
            values["coachTurnDecisionSource"] = coachTurnState.decisionSource.rawValue
            values["coachTurnPolicyVersion"] = coachTurnState.policyVersion
            values["coachTurnSummary"] = coachTurnState.turnSummary
        }
        if let coachTeachingPlan {
            values["coachTeachingPolicyVersion"] = coachTeachingPlan.policyVersion
            values["coachTeachingMissingMove"] = coachTeachingPlan.missingMoveTitle
            values["coachTeachingTrainingTarget"] = coachTeachingPlan.trainingTargetTitle
            values["coachTeachingWhyNotAnswer"] = coachTeachingPlan.whyNotAnswer
            values["coachTeachingProceedStandard"] = coachTeachingPlan.proceedStandard
            values["coachTeachingRepairQuestion"] = coachTeachingPlan.repairQuestion
            values["coachTeachingExperienceReplayPrompt"] = coachTeachingPlan.experienceReplayPrompt
            values["coachTeachingRouteSteps"] = coachTeachingPlan.routeSteps.joined(separator: " -> ")
            if let auditNote = coachTeachingPlan.auditNote,
               !auditNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                values["coachTeachingAuditNote"] = auditNote
            }
        }
        if let coachObservation {
            values["coachObservationPolicyVersion"] = coachObservation.policyVersion
            values["coachObservationProvidedMaterials"] = coachObservation.providedMaterials.map(\.rawValue).joined(separator: ",")
            values["coachObservationMissingMaterials"] = coachObservation.missingMaterials.map(\.rawValue).joined(separator: ",")
            values["coachObservationThinkingProcess"] = coachObservation.thinkingProcessObservation
            values["coachObservationPrimaryGap"] = coachObservation.primaryGap.rawValue
            values["coachObservationSecondaryGaps"] = coachObservation.secondaryGaps.map(\.rawValue).joined(separator: ",")
            values["coachObservationTrainingAbility"] = coachObservation.trainingAbility.displayTitle
            values["coachObservationTrainingAbilityRaw"] = coachObservation.trainingAbility.rawValue
            values["coachObservationObserved"] = coachObservation.feedback.observed
            values["coachObservationDiagnosis"] = coachObservation.feedback.diagnosis
            values["coachObservationTraining"] = coachObservation.feedback.training
            values["coachObservationAsk"] = coachObservation.feedback.ask
            values["coachObservationProceedWhen"] = coachObservation.feedback.proceedWhen
            values["coachObservationExperienceReplayPrompt"] = coachObservation.experienceReplayPrompt
        }
        if let rawText = currentInput.rawText {
            values["rawText"] = rawText
        }
        if !cards.isEmpty {
            values["confirmedCards"] = cards.map { card in
                [
                    "type": card.type,
                    "title": card.title,
                    "body": card.body,
                    "priority": card.priority,
                    "sensitivity": card.sensitivity
                ]
                .map { "\($0.key): \($0.value)" }
                .sorted()
                .joined(separator: ", ")
            }.joined(separator: "\n")
        }
        if !answers.isEmpty {
            let renderedAnswers = answers.map { answer in
                var parts = ["question: \(answer.question)", "answer: \(answer.answer)"]
                if let calibrationTarget = answer.calibrationTarget,
                   !calibrationTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parts.append("calibrationTarget: \(calibrationTarget)")
                }
                return parts.joined(separator: ", ")
            }.joined(separator: "\n")
            values["priorAnswers"] = renderedAnswers
            values["reflectionAnswers"] = renderedAnswers
        }
        if !quests.isEmpty {
            values["selectedQuest"] = quests.map { quest in
                var parts = ["type: \(quest.type)", "title: \(quest.title)", "completionCriteria: \(quest.completionCriteria)"]
                if let calibrationTarget = quest.calibrationTarget,
                   !calibrationTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parts.append("calibrationTarget: \(calibrationTarget)")
                }
                return parts.joined(separator: ", ")
            }.joined(separator: "\n")
        }
        if !principles.isEmpty {
            values["relevantPrinciples"] = legacyPrinciples(principles)
        }
        if !existingPrinciples.isEmpty {
            values["existingPrinciples"] = legacyPrinciples(existingPrinciples)
        }
        if let principleUsageRule = directives.principleUsageRule {
            values["principleUsageRule"] = principleUsageRule
        }
        if let principleSelectionRule = directives.principleSelectionRule {
            values["principleSelectionRule"] = principleSelectionRule
        }
        if let coachDiagnosisRule = directives.coachDiagnosisRule {
            values["coachDiagnosisRule"] = coachDiagnosisRule
        }
        if let coachTurnRule = directives.coachTurnRule {
            values["coachTurnRule"] = coachTurnRule
        }
        if let coachTeachingRule = directives.coachTeachingRule {
            values["coachTeachingRule"] = coachTeachingRule
        }
        if let coachObservationRule = directives.coachObservationRule {
            values["coachObservationRule"] = coachObservationRule
        }
        if let coachPatternSummary {
            values["coachPatternSummaryPolicyVersion"] = coachPatternSummary.policyVersion
            values["coachPatternSummaryAnalyzedRecordCount"] = "\(coachPatternSummary.analyzedRecordCount)"
            values["coachPatternSummaryTopGaps"] = coachPatternSummary.topPatterns.map { pattern in
                "\(pattern.primaryGap.rawValue):\(pattern.foundationalAbility.rawValue):\(pattern.count)"
            }.joined(separator: ",")
            values["coachPatternSummaryGuidance"] = coachPatternSummary.guidanceLine
        }
        if let coachPatternSummaryRule = directives.coachPatternSummaryRule {
            values["coachPatternSummaryRule"] = coachPatternSummaryRule
        }
        if let streamProtocol = directives.streamProtocol {
            values["streamProtocol"] = streamProtocol
        }
        if let privacyRules = directives.privacyRules {
            values["privacyRules"] = privacyRules
        }
        if let privacyRules = privacy.rules {
            values["privacyRules"] = privacyRules
        }
        if let verification {
            values["questTitle"] = verification.questTitle
            values["completionCriteria"] = verification.completionCriteria
            if let targetJudgment = verification.targetJudgment,
               !targetJudgment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                values["targetJudgment"] = targetJudgment
            }
            if let trainingPrinciple = verification.trainingPrinciple {
                values["trainingPrinciple"] = [
                    "id: \(trainingPrinciple.principleId)",
                    "title: \(trainingPrinciple.principleTitle)",
                    "matchSignal: \(trainingPrinciple.matchSignal)"
                ].joined(separator: ", ")
            }
            values["completion"] = verification.completion
            values["valueRating"] = verification.valueRating
            values["judgmentUpdate"] = verification.judgmentUpdate
        }
        if !lensFeedback.isEmpty {
            values["lensFeedback"] = lensFeedback.map { feedback in
                var parts = [
                    "lens=\(feedback.lensTitle)",
                    "lensId=\(feedback.lensId)",
                    "signal=\(feedback.signal)",
                    "completion=\(feedback.completion)",
                    "value=\(feedback.valueRating)",
                    "calibrationNote=\(feedback.calibrationNote)"
                ]
                if let recommendation = feedback.recommendation?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !recommendation.isEmpty {
                    parts.append("recommendation=\(recommendation)")
                }
                if !feedback.questionTargets.isEmpty {
                    parts.append("targets=\(feedback.questionTargets.joined(separator: " | "))")
                }
                if !feedback.evidenceGapTypes.isEmpty {
                    parts.append("evidenceGaps=\(feedback.evidenceGapTypes.joined(separator: ","))")
                }
                if !feedback.lensMoves.isEmpty {
                    parts.append("lensMoves=\(feedback.lensMoves.joined(separator: ","))")
                }
                return parts.joined(separator: "; ")
            }
            .joined(separator: "\n")
        }
        if let growth {
            mergeGrowthLegacyValues(growth, into: &values)
        }
        if let project {
            mergeProjectLegacyValues(project, into: &values)
        }
        return values
    }

    private func mergeGrowthLegacyValues(_ growth: GrowthContext, into values: inout [String: String]) {
        values["period"] = growth.period
        values["complete_loop_count"] = String(growth.completeLoopCount)
        values["record_count"] = String(growth.records.count)
        values["evidence_summaries"] = growth.records.map { record in
            var parts = ["entry=\(record.dailyEntryId)"]
            parts.append("cards=\(record.confirmedCardCount)")
            if let title = record.mainQuestTitle {
                parts.append("quest=\(title)")
            }
            if let completion = record.verificationCompletion {
                parts.append("completion=\(completion)")
            }
            if let rating = record.verificationValueRating {
                parts.append("value=\(rating)")
            }
            return parts.joined(separator: "; ")
        }
        .joined(separator: "\n")

        if let previous = growth.previousSnapshot {
            values["previous_clarity"] = String(format: "%.1f", previous.clarity)
            values["previous_value_judgment"] = String(format: "%.1f", previous.valueJudgment)
            values["previous_execution_reliability"] = String(format: "%.1f", previous.executionReliability)
            values["previous_calibration"] = String(format: "%.1f", previous.calibration)
            values["previous_reflection_depth"] = String(format: "%.1f", previous.reflectionDepth)
        }

        if !growth.dismissedContributionTitles.isEmpty {
            values["dismissed_contributions"] = growth.dismissedContributionTitles.joined(separator: "; ")
        }
    }

    private func mergeProjectLegacyValues(_ project: ProjectContext, into values: inout [String: String]) {
        if !project.dailyEntryId.isEmpty {
            values["daily_entry_id"] = project.dailyEntryId
            values["confirmed_cards_count"] = String(project.confirmedCards.count)
        }
        if let projectId = project.projectId {
            values["project_id"] = projectId
        }
        if let projectName = project.projectName {
            values["project_name"] = projectName
        }
        if let projectGoal = project.projectGoal {
            values["project_goal"] = projectGoal
        }
        if let projectSuccessCriteria = project.projectSuccessCriteria {
            values["project_success_criteria"] = projectSuccessCriteria
        }
        if let acceptedInsightCount = project.acceptedInsightCount {
            values["accepted_insight_count"] = String(acceptedInsightCount)
        }

        if !project.confirmedCards.isEmpty {
            values["confirmed_cards"] = project.confirmedCards.map { card in
                "id: \(card.id), type: \(card.type), title: \(card.title), body: \(card.body)"
            }.joined(separator: "\n")
        }
        if !project.quests.isEmpty {
            values["quests"] = project.quests.map { quest in
                "id: \(quest.id), type: \(quest.type), title: \(quest.title), completionCriteria: \(quest.completionCriteria)"
            }.joined(separator: "\n")
        }
        if !project.activeProjects.isEmpty {
            values["active_projects_count"] = String(project.activeProjects.count)
            values["active_projects"] = project.activeProjects.map { activeProject in
                var parts = ["id: \(activeProject.id)", "name: \(activeProject.name)"]
                if let goal = activeProject.goal {
                    parts.append("goal: \(goal)")
                }
                if let successCriteria = activeProject.successCriteria {
                    parts.append("success_criteria: \(successCriteria)")
                }
                if let status = activeProject.status {
                    parts.append("status: \(status)")
                }
                return parts.joined(separator: ", ")
            }.joined(separator: "\n")
        }
        if !project.existingLinkSourceIds.isEmpty {
            values["existing_link_source_ids"] = project.existingLinkSourceIds.joined(separator: ", ")
        }
        if !project.confirmedEvidence.isEmpty {
            values["confirmed_evidence"] = project.confirmedEvidence.map { evidence in
                "id: \(evidence.id), type: \(evidence.type), title: \(evidence.title), body: \(evidence.body)"
            }.joined(separator: "\n")
        }
        if !project.confirmedProjectLinks.isEmpty {
            values["confirmed_project_links"] = project.confirmedProjectLinks.map { link in
                "project_id: \(link.projectId), source_id: \(link.sourceId), source_type: \(link.sourceType), link_type: \(link.linkType)"
            }.joined(separator: "\n")
        }
    }

    private func legacyPrinciples(_ principles: [PrincipleContext]) -> String {
        principles.map { principle in
            [
                "id": principle.id,
                "title": principle.title,
                "summary": principle.summary,
                "triggerContext": principle.triggerContext,
                "successCriteria": principle.successCriteria,
                "exceptions": principle.exceptions,
                "status": principle.status.rawValue,
                "retrievalReason": principle.retrievalReason,
                "retrievalPolicyVersion": principle.retrievalPolicyVersion,
                "retrievalSignal": principle.retrievalSignal
            ]
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: ", ")
        }.joined(separator: "\n")
    }

    func renderedJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum LLMClientError: Error {
    case missingAPIKey
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int, Data)
    case encodingFailed(Error)
    case transport(Error)
}

protocol PromptProvider {
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate
    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate?
}

extension PromptProvider {
    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let template = template(for: id, mode: mode)
        return template.version == version ? template : nil
    }
}

protocol LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data
}

/// The single model gateway used by product decision services. Feature services
/// still own their schemas and evidence boundaries, but all model traffic passes
/// through this shared object so transport, cancellation, and PromptRun tracing
/// have one authority instead of per-feature clients.
final class CentralLLMDecisionCenter: LLMClient {
    static let policyVersion = "llm-decision-center.v1"

    private let base: LLMClient

    init(base: LLMClient) {
        self.base = base
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        try await base.complete(request)
    }
}

extension CentralLLMDecisionCenter: StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        guard let streamingBase = base as? StreamingLLMClient else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMClientError.invalidResponse)
            }
        }
        return streamingBase.stream(request)
    }
}

enum LLMStreamEvent: Hashable {
    /// The request task started. It does not mean the remote endpoint has accepted it yet.
    case requestStarted
    /// HTTP headers arrived from a successful streaming response.
    case connected
    /// A non-terminal SSE data packet arrived, even when it has no displayable content.
    case receivedEvent
    case token(String)
    case completed
}

protocol StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}

struct MissingAPIKeyLLMClient: LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.missingAPIKey
    }
}

extension MissingAPIKeyLLMClient: StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMClientError.missingAPIKey)
        }
    }
}

final class PromptTracingLLMClient: LLMClient {
    private let base: LLMClient
    private let repository: PromptRunRepository
    private let modelProvider: String
    private let modelName: String

    init(
        base: LLMClient,
        repository: PromptRunRepository,
        modelProvider: String,
        modelName: String
    ) {
        self.base = base
        self.repository = repository
        self.modelProvider = modelProvider
        self.modelName = modelName
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        do {
            let data = try await base.complete(request)
            await saveRun(for: request, responseData: data, error: nil)
            return data
        } catch {
            await saveRun(for: request, responseData: nil, error: error)
            throw error
        }
    }

    private func saveRun(for request: LLMRequest, responseData: Data?, error: Error?) async {
        let errorMessage: String?
        if let llmError = error as? LLMClientError {
            errorMessage = llmError.userFacingMessage
        } else {
            errorMessage = error?.localizedDescription
        }

        let run = PromptRun(
            id: request.traceID,
            promptId: request.prompt.id.rawValue,
            promptVersion: request.prompt.version,
            promptSourceKind: request.prompt.sourceKind,
            promptPackId: request.prompt.packId,
            promptPackVersion: request.prompt.packVersion,
            promptPackDisplayName: request.prompt.packDisplayName,
            systemPolicyVersion: request.prompt.systemPolicyVersion,
            contextPolicyVersion: request.prompt.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: request.prompt.outputSchemaVersion,
            evalSuiteVersion: request.prompt.evalSuiteVersion,
            rollbackTargetVersion: request.prompt.rollbackTargetVersion,
            modelProvider: modelProvider,
            modelName: modelName,
            sessionMode: sessionMode(from: request),
            sourceRecordIds: Array(Set(request.sourceRecordIDs)).sorted(),
            contextRecordIds: Array(Set(request.contextRecordIDs)).sorted(),
            requestSummary: request.inputSummary,
            responseJSON: responseData.flatMap { String(data: $0, encoding: .utf8) },
            error: errorMessage
        )

        try? await repository.savePromptRun(run)
    }

    private func sessionMode(from request: LLMRequest) -> String {
        request.contextPayload?.userChoice.sessionMode
            ?? "unknown"
    }
}

extension PromptTracingLLMClient: StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        guard let streamingBase = base as? StreamingLLMClient else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMClientError.invalidResponse)
            }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                var rawStream = ""
                do {
                    for try await event in streamingBase.stream(request) {
                        if case .token(let text) = event {
                            rawStream += text
                        }
                        continuation.yield(event)
                    }
                    await saveRun(
                        for: request,
                        responseData: Data(rawStream.utf8),
                        error: nil
                    )
                    continuation.finish()
                } catch {
                    await saveRun(
                        for: request,
                        responseData: rawStream.isEmpty ? nil : Data(rawStream.utf8),
                        error: error
                    )
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct PromptEvalRunner {
    static let currentRunnerVersion = "prompt-eval-runner.v1"

    private let promptProvider: PromptProvider
    private let parser: TodayAIResponseParser

    init(promptProvider: PromptProvider, parser: TodayAIResponseParser = TodayAIResponseParser()) {
        self.promptProvider = promptProvider
        self.parser = parser
    }

    func runFixedSuite(mode: SessionMode = .standard, createdAt: Date = .now) -> [PromptEvalRun] {
        PromptEvalCase.fixedSuite
            .groupedByPromptId()
            .map { promptId, cases in
                let template = promptProvider.template(for: promptId, mode: mode)
                let results = cases.map(runCase)
                return PromptEvalRun(
                    promptId: promptId.rawValue,
                    promptVersion: template.version,
                    promptSourceKind: template.sourceKind,
                    promptPackId: template.packId,
                    promptPackVersion: template.packVersion,
                    promptPackDisplayName: template.packDisplayName,
                    systemPolicyVersion: template.systemPolicyVersion,
                    contextPolicyVersion: template.contextPolicyVersion,
                    inputSchemaVersion: 1,
                    outputSchemaVersion: template.outputSchemaVersion,
                    evalSuiteVersion: template.evalSuiteVersion,
                    runnerVersion: Self.currentRunnerVersion,
                    caseResults: results,
                    createdAt: createdAt
                )
            }
            .sorted { $0.promptId < $1.promptId }
    }

    private func runCase(_ evalCase: PromptEvalCase) -> PromptEvalCaseResult {
        do {
            try evalCase.assertion(parser)
            return PromptEvalCaseResult(
                caseId: evalCase.caseId,
                name: evalCase.name,
                status: .passed,
                inputSummary: evalCase.inputSummary,
                expectedBehavior: evalCase.expectedBehavior,
                actualObservation: "passed: fixed-suite assertions satisfied.",
                diagnosticReason: "fixed-suite pass: \(evalCase.caseId)"
            )
        } catch {
            let reason = String(describing: error)
            return PromptEvalCaseResult(
                caseId: evalCase.caseId,
                name: evalCase.name,
                status: .failed,
                failureReason: reason,
                inputSummary: evalCase.inputSummary,
                expectedBehavior: evalCase.expectedBehavior,
                actualObservation: "failed: \(reason)",
                diagnosticReason: "fixed-suite failure: \(reason)"
            )
        }
    }
}

enum PromptCoachingQualityIssueReason: String, Codable, CaseIterable, Identifiable {
    case genericQuestion
    case missingEvidenceGapType
    case missingAnswerUse
    case missingLensMove
    case missingSourceGrounding
    case vagueCalibrationTarget
    case missingSelectedLensMove
    case missingTrainingDimensionAlignment
    case missingPrimaryTrainingDimensionFocus
    case missingCoachTurnAlignment
    case missingFunctionalCoachField
    case missingThinkingMaterialTarget
    case missingPrincipleReplay
    case missingNarrativeRepair
    case appeasingWithoutCorrection
    case repeatedAvoidedLensMove
    case unadjustedLensMove
    case missingReinforcedLensMove
    case missingSystemThinkingLensMove
    case weakVerificationCalibrationNote
    case weakVerificationRecommendation
    case missingExpectedPrinciplePracticeAssessment
    case missingPrincipleSourceGrounding
    case weakPrincipleActionability
    case busyworkQuest
    case weakCompletionCriteria

    var id: String { rawValue }
}

struct PromptCoachingQualityIssue: Hashable, Identifiable {
    var id: String { "\(reason.rawValue):\(subject)" }
    var reason: PromptCoachingQualityIssueReason
    var subject: String
}

enum PromptCoachingQualityPolicy {
    static func evaluateQuestions(
        _ questions: [ReflectionQuestion],
        selectedLens: ThinkingLens? = nil,
        lensFeedback: [PromptContextPayload.LensFeedbackContext] = [],
        primaryTrainingDimension: ThinkingTrainingDimension? = nil,
        baselineTrainingDimensions: [ThinkingTrainingDimension] = [],
        coachTurnState: CoachTurnState? = nil,
        relevantPrinciples: [PromptContextPayload.PrincipleContext] = [],
        coachObservation: PromptContextPayload.CoachObservationContext? = nil
    ) -> [PromptCoachingQualityIssue] {
        let trainingDimensions = normalizedTrainingDimensions(
            primaryTrainingDimension: primaryTrainingDimension,
            baselineTrainingDimensions: baselineTrainingDimensions
        )
        let avoidedMoves = Set(
            lensFeedback
                .filter { $0.signal == "avoid" }
                .flatMap(\.lensMoves)
        )
        let reinforcedMoves = Set(
            lensFeedback
                .filter { $0.signal == "reinforce" }
                .flatMap(\.lensMoves)
        )
        let adjustedTargetsByMove = lensFeedback
            .filter { $0.signal == "adjust" }
            .flatMap { feedback in
                feedback.lensMoves.flatMap { move in
                    feedback.questionTargets.map { target in (move, target) }
                }
            }
            .reduce(into: [String: Set<String>]()) { result, pair in
                result[pair.0, default: []].insert(pair.1)
            }

        var allIssues = questions.flatMap { question in
            var issues: [PromptCoachingQualityIssue] = []
            let subject = question.question

            if containsGenericQuestionPattern(question.question) {
                issues.append(issue(.genericQuestion, subject: subject))
            }
            if !hasFunctionalCoachFields(question) {
                issues.append(issue(.missingFunctionalCoachField, subject: subject))
            }
            if !targetsMissingThinkingMaterial(question) {
                issues.append(issue(.missingThinkingMaterialTarget, subject: subject))
            }
            if isAppeasingWithoutCorrection(question) {
                issues.append(issue(.appeasingWithoutCorrection, subject: subject))
            }
            if question.evidenceGapType == nil {
                issues.append(issue(.missingEvidenceGapType, subject: subject))
            }
            if question.answerUse == nil {
                issues.append(issue(.missingAnswerUse, subject: subject))
            }
            if question.lensMove == nil {
                issues.append(issue(.missingLensMove, subject: subject))
            }
            if question.sourceCardTitles.isEmpty {
                issues.append(issue(.missingSourceGrounding, subject: subject))
            }
            if isVagueCalibrationTarget(question.calibrationTarget) {
                issues.append(issue(.vagueCalibrationTarget, subject: subject))
            }
            if !trainingDimensions.isEmpty,
               !isAlignedWithAnyTrainingDimension(question, dimensions: trainingDimensions) {
                issues.append(issue(.missingTrainingDimensionAlignment, subject: subject))
            }
            if let coachTurnState,
               !isAligned(question, with: coachTurnState) {
                issues.append(issue(.missingCoachTurnAlignment, subject: subject))
            }
            if let lensMove = question.lensMove,
               avoidedMoves.contains(lensMove.rawValue) {
                issues.append(issue(.repeatedAvoidedLensMove, subject: subject))
            }
            if let lensMove = question.lensMove,
               repeatsAdjustedTarget(
                   question.calibrationTarget,
                   previousTargets: adjustedTargetsByMove[lensMove.rawValue]
               ) {
                issues.append(issue(.unadjustedLensMove, subject: subject))
            }

            return issues
        }
        if let primaryTrainingDimension,
           let firstQuestion = questions.first,
           isAlignedWithAnyTrainingDimension(firstQuestion, dimensions: trainingDimensions),
           !isAligned(firstQuestion, with: primaryTrainingDimension) {
            allIssues.append(issue(.missingPrimaryTrainingDimensionFocus, subject: firstQuestion.question))
        }
        if !reinforcedMoves.isEmpty {
            let outputMoves = Set(questions.compactMap { $0.lensMove?.rawValue })
            if reinforcedMoves.isDisjoint(with: outputMoves) {
                allIssues.append(issue(.missingReinforcedLensMove, subject: reinforcedMoves.sorted().joined(separator: ",")))
            }
        }
        if let selectedLens,
           let requiredMoves = requiredLensMoves(for: selectedLens) {
            let outputMoves = Set(questions.compactMap(\.lensMove))
            if requiredMoves.isDisjoint(with: outputMoves) {
                if selectedLens == .systemThinking {
                    allIssues.append(issue(.missingSystemThinkingLensMove, subject: ThinkingLens.systemThinking.rawValue))
                } else {
                    allIssues.append(issue(.missingSelectedLensMove, subject: selectedLens.rawValue))
                }
            }
        }
        if !relevantPrinciples.isEmpty,
           !questions.contains(where: { targetsPrincipleReplay($0, relevantPrinciples: relevantPrinciples) }) {
            allIssues.append(
                issue(
                    .missingPrincipleReplay,
                    subject: relevantPrinciples.map(\.title).joined(separator: ",")
                )
            )
        }
        if let coachObservation,
           coachObservation.trainingAbility == .description,
           !questions.contains(where: { repairsNarrativeGap($0, observation: coachObservation) }) {
            allIssues.append(issue(.missingNarrativeRepair, subject: coachObservation.primaryGap.rawValue))
        }
        return allIssues
    }

    static func evaluateQuests(
        _ quests: [Quest],
        selectedLens: ThinkingLens? = nil,
        coachTurnState: CoachTurnState? = nil
    ) -> [PromptCoachingQualityIssue] {
        var allIssues = quests.flatMap { quest in
            var issues: [PromptCoachingQualityIssue] = []
            let subject = quest.title

            if isAppeasingWithoutCorrection(quest) {
                issues.append(issue(.appeasingWithoutCorrection, subject: subject))
            }
            if isBusyworkQuest(quest) {
                issues.append(issue(.busyworkQuest, subject: subject))
            }
            if hasWeakCompletionCriteria(quest.completionCriteria) {
                issues.append(issue(.weakCompletionCriteria, subject: subject))
            }
            if isVagueCalibrationTarget(quest.calibrationTarget) {
                issues.append(issue(.vagueCalibrationTarget, subject: subject))
            }
            if quest.sourceCardTitles.isEmpty {
                issues.append(issue(.missingSourceGrounding, subject: subject))
            }

            return issues
        }

        if let coachTurnState,
           coachTurnState.readiness != .ready,
           coachTurnState.decisionSource != .userOverrideProgress {
            allIssues.append(
                issue(.missingCoachTurnAlignment, subject: coachTurnState.recommendedMove.rawValue)
            )
        }

        if let selectedLens,
           let requiredMoves = requiredLensMoves(for: selectedLens) {
            let questMoves = Set(quests.compactMap(\.lensMove))
            if requiredMoves.isDisjoint(with: questMoves) {
                if selectedLens == .systemThinking {
                    allIssues.append(issue(.missingSystemThinkingLensMove, subject: ThinkingLens.systemThinking.rawValue))
                } else {
                    allIssues.append(issue(.missingSelectedLensMove, subject: selectedLens.rawValue))
                }
            }
        }

        return allIssues
    }

    static func evaluateVerification(
        _ result: VerifyQuestResult,
        targetJudgment: String?,
        hasTrainingPrinciple: Bool = false
    ) -> [PromptCoachingQualityIssue] {
        let target = targetJudgment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = target.isEmpty ? "trainingPrinciple" : target

        var issues: [PromptCoachingQualityIssue] = []
        if !target.isEmpty {
            if hasWeakVerificationCalibrationNote(result.calibrationNote) {
                issues.append(issue(.weakVerificationCalibrationNote, subject: target))
            }
            if hasWeakVerificationRecommendation(result.recommendation) {
                issues.append(issue(.weakVerificationRecommendation, subject: target))
            }
        }
        if hasTrainingPrinciple,
           (result.expectedPrinciplePracticeAssessment ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.missingExpectedPrinciplePracticeAssessment, subject: subject))
        }
        return issues
    }

    static func evaluatePrinciples(_ principles: [PrincipleAsset]) -> [PromptCoachingQualityIssue] {
        principles.flatMap { principle in
            var issues: [PromptCoachingQualityIssue] = []
            if isAppeasingWithoutCorrection(principle) {
                issues.append(issue(.appeasingWithoutCorrection, subject: principle.title))
            }
            if principle.sourceCardTitles.isEmpty {
                issues.append(issue(.missingPrincipleSourceGrounding, subject: principle.title))
            }
            if hasWeakPrincipleActionability(principle) {
                issues.append(issue(.weakPrincipleActionability, subject: principle.title))
            }
            return issues
        }
    }

    private static func issue(
        _ reason: PromptCoachingQualityIssueReason,
        subject: String
    ) -> PromptCoachingQualityIssue {
        PromptCoachingQualityIssue(reason: reason, subject: subject)
    }

    private static func hasFunctionalCoachFields(_ question: ReflectionQuestion) -> Bool {
        [
            question.whyNow,
            question.expectedUpdate,
            question.proceedWhen
        ].allSatisfy { field in
            !(field?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    private static func targetsMissingThinkingMaterial(_ question: ReflectionQuestion) -> Bool {
        if question.evidenceGapType == EvidenceGapType.none,
           question.answerUse == .chooseAction,
           question.lensMove == .leverageTradeoff {
            return true
        }

        let combined = [
            question.question,
            question.whyItMatters,
            question.whyNow ?? "",
            question.expectedUpdate ?? "",
            question.proceedWhen ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        let missingMaterialSignals = [
            "缺",
            "补",
            "没有",
            "未明确",
            "不清",
            "不足",
            "证据",
            "基线",
            "因果",
            "反例",
            "约束",
            "假设",
            "解释",
            "信号",
            "校准",
            "missing",
            "gap",
            "evidence",
            "baseline",
            "causal",
            "counterexample",
            "constraint",
            "assumption",
            "signal",
            "calibration"
        ]
        return missingMaterialSignals.contains { combined.contains($0) }
    }

    private static func targetsPrincipleReplay(
        _ question: ReflectionQuestion,
        relevantPrinciples: [PromptContextPayload.PrincipleContext]
    ) -> Bool {
        let combined = [
            question.question,
            question.whyItMatters,
            question.whyNow ?? "",
            question.expectedUpdate ?? "",
            question.proceedWhen ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        let replayContextSignals = [
            "原则",
            "经验",
            "过往",
            "过去",
            "之前",
            "上次",
            "prior",
            "previous",
            "principle",
            "experience",
            "replay"
        ]
        let replayDecisionSignals = [
            "复用",
            "沿用",
            "借鉴",
            "迁移",
            "调整",
            "改写",
            "拒绝",
            "不适用",
            "reproduce",
            "reuse",
            "apply",
            "adapt",
            "reject"
        ]

        let mentionsReplayContext = replayContextSignals.contains { combined.contains($0) }
            || mentionsAnyPrinciple(relevantPrinciples, in: combined)
        let mentionsReplayDecision = replayDecisionSignals.contains { combined.contains($0) }
        return mentionsReplayContext && mentionsReplayDecision
    }

    private static func mentionsAnyPrinciple(
        _ principles: [PromptContextPayload.PrincipleContext],
        in text: String
    ) -> Bool {
        principles.contains { principle in
            let fields = [
                principle.title,
                principle.summary,
                principle.triggerContext,
                principle.successCriteria
            ]
            return fields.contains { field in
                let normalized = field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalized.count >= 4 && text.contains(normalized)
            }
        }
    }

    private static func repairsNarrativeGap(
        _ question: ReflectionQuestion,
        observation: PromptContextPayload.CoachObservationContext
    ) -> Bool {
        let combined = [
            question.question,
            question.whyItMatters,
            question.whyNow ?? "",
            question.expectedUpdate ?? "",
            question.proceedWhen ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        let missingNarrativeMaterials = Set(observation.missingMaterials).intersection(Self.narrativeMaterials)
        guard !missingNarrativeMaterials.isEmpty else {
            return containsAnyNarrativeCue(in: combined)
        }
        return missingNarrativeMaterials.contains { material in
            narrativeSignals(for: material).contains { combined.contains($0) }
        }
    }

    private static let narrativeMaterials: Set<CoachObservationMaterial> = [
        .background,
        .object,
        .trigger,
        .action,
        .result
    ]

    private static func containsAnyNarrativeCue(in text: String) -> Bool {
        narrativeMaterials.contains { material in
            narrativeSignals(for: material).contains { text.contains($0) }
        }
    }

    private static func narrativeSignals(for material: CoachObservationMaterial) -> [String] {
        switch material {
        case .background:
            return ["背景", "前因", "场景", "context", "background"]
        case .object:
            return ["对象", "谁", "服务于谁", "影响谁", "stakeholder", "user", "object"]
        case .trigger:
            return ["触发", "起因", "因为什么", "trigger"]
        case .action:
            return ["做法", "动作", "你怎么做", "采取了什么", "action"]
        case .result:
            return ["结果", "后来", "造成什么", "影响", "result", "outcome"]
        case .feeling, .fact, .interpretation, .judgment, .assumption, .constraint,
             .goal, .standard, .openQuestion, .experience, .calibrationSignal:
            return []
        }
    }

    private static func containsGenericQuestionPattern(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let genericPatterns = [
            "你怎么看",
            "这说明了什么",
            "感觉如何",
            "有什么感受",
            "有什么启发",
            "如何更好",
            "what do you think",
            "how do you feel"
        ]
        return genericPatterns.contains { normalized.contains($0) }
    }

    private static func isAppeasingWithoutCorrection(_ question: ReflectionQuestion) -> Bool {
        let combined = [
            question.question,
            question.whyItMatters,
            question.whyNow ?? "",
            question.expectedUpdate ?? "",
            question.proceedWhen ?? "",
            question.calibrationTarget ?? ""
        ]
        .joined(separator: " ")
        return isAppeasingWithoutCorrectionText(combined)
    }

    private static func isAppeasingWithoutCorrection(_ quest: Quest) -> Bool {
        let combined = [
            quest.title,
            quest.whyItMatters,
            quest.completionCriteria,
            quest.expectedResistance,
            quest.reflectionQuestion,
            quest.calibrationTarget ?? ""
        ]
        .joined(separator: " ")
        return isAppeasingWithoutCorrectionText(combined)
    }

    private static func isAppeasingWithoutCorrection(_ principle: PrincipleAsset) -> Bool {
        let combined = [
            principle.title,
            principle.summary,
            principle.triggerContext,
            principle.actions.joined(separator: " "),
            principle.successCriteria,
            principle.exceptions
        ]
        .joined(separator: " ")
        return isAppeasingWithoutCorrectionText(combined)
    }

    private static func isAppeasingWithoutCorrectionText(_ text: String) -> Bool {
        let combined = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !combined.isEmpty else { return false }

        let appeasingPatterns = [
            "你已经想得很充分",
            "你已经做得很好",
            "你的想法很有价值",
            "认可你",
            "更有信心",
            "觉得有信心",
            "继续按这个方向",
            "继续按当前判断",
            "认可自己的判断",
            "当前判断已经够好",
            "我理解你",
            "理解你的",
            "压力很大",
            "处境确实不容易",
            "承认这个情况很困难",
            "现在这样也合理",
            "被理解",
            "validate your thinking",
            "you are already right",
            "feel more confident",
            "keep going",
            "i understand",
            "your pressure",
            "this is understandable"
        ]
        let correctionPatterns = [
            "缺",
            "不足",
            "不清",
            "风险",
            "事实",
            "证据",
            "反例",
            "相反",
            "校准",
            "观察",
            "假设",
            "解释",
            "过早",
            "不要急",
            "先补",
            "missing",
            "gap",
            "risk",
            "fact",
            "evidence",
            "counterexample",
            "calibration",
            "assumption",
            "premature",
            "observable"
        ]

        let hasAppeasingPattern = appeasingPatterns.contains { combined.contains($0) }
        guard hasAppeasingPattern else { return false }
        if containsProceedDespiteGapPattern(combined) {
            return true
        }
        return !correctionPatterns.contains { combined.contains($0) }
    }

    private static func containsProceedDespiteGapPattern(_ text: String) -> Bool {
        let proceedPatterns = [
            "先继续推进",
            "继续推进当前",
            "继续按原计划",
            "继续按当前方案",
            "先按原方案",
            "先推进",
            "进入行动",
            "go ahead",
            "keep moving",
            "continue with the current"
        ]
        let unresolvedGapPatterns = [
            "证据不足",
            "证据缺口",
            "缺口",
            "还没补",
            "后面再补",
            "之后再补",
            "以后再补",
            "later",
            "evidence is insufficient",
            "unresolved gap",
            "missing evidence"
        ]
        return proceedPatterns.contains { text.contains($0) } &&
            unresolvedGapPatterns.contains { text.contains($0) }
    }

    private static func isVagueCalibrationTarget(_ target: String?) -> Bool {
        let normalized = target?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard normalized.count >= 8 else { return true }
        let vagueTargets = [
            "用户的思考",
            "这个情况",
            "明天最值得验证的关键判断",
            "当前透镜是否能改变下一步判断",
            "improve thinking",
            "understand the situation",
            "the user's thinking",
            "the situation"
        ]
        return vagueTargets.contains { normalized.localizedCaseInsensitiveContains($0) }
    }

    private static func repeatsAdjustedTarget(
        _ target: String?,
        previousTargets: Set<String>?
    ) -> Bool {
        let current = normalizedComparableText(target)
        guard current.count >= 6, let previousTargets, !previousTargets.isEmpty else {
            return false
        }

        return previousTargets.contains { previous in
            let normalizedPrevious = normalizedComparableText(previous)
            guard normalizedPrevious.count >= 6 else { return false }
            return current == normalizedPrevious ||
                current.contains(normalizedPrevious) ||
                normalizedPrevious.contains(current)
        }
    }

    private static func requiredLensMoves(for lens: ThinkingLens) -> Set<QuestionLensMove>? {
        switch lens {
        case .evidenceCheck:
            return [.factInterpretationSplit]
        case .opposingView:
            return [.alternativeExplanation]
        case .leverageAnalysis:
            return [.leverageTradeoff]
        case .firstPrinciples:
            return [.constraintDecomposition]
        case .systemThinking:
            return [.feedbackLoop, .delayedEffect, .secondOrderConsequence]
        case .judgmentCalibration:
            return [.predictionCalibration]
        }
    }

    private static func normalizedTrainingDimensions(
        primaryTrainingDimension: ThinkingTrainingDimension?,
        baselineTrainingDimensions: [ThinkingTrainingDimension]
    ) -> [ThinkingTrainingDimension] {
        var seen: Set<ThinkingTrainingDimension> = []
        return ([primaryTrainingDimension].compactMap { $0 } + baselineTrainingDimensions).filter { dimension in
            seen.insert(dimension).inserted
        }
    }

    private static func isAlignedWithAnyTrainingDimension(
        _ question: ReflectionQuestion,
        dimensions: [ThinkingTrainingDimension]
    ) -> Bool {
        dimensions.contains { isAligned(question, with: $0) }
    }

    private static func isAligned(
        _ question: ReflectionQuestion,
        with coachTurnState: CoachTurnState
    ) -> Bool {
        guard coachTurnState.readiness != .ready else { return true }
        guard coachTurnState.decisionSource != .userOverrideProgress else { return true }

        switch coachTurnState.recommendedMove {
        case .surfaceEvidenceGap, .slowDownConvergence:
            return question.evidenceGapType.map { $0 != .none } ?? false ||
                question.answerUse == .collectEvidence ||
                question.answerUse == .testAssumption ||
                question.answerUse == .watchCalibrationSignal
        case .askClarifyingQuestion:
            return question.answerUse != .chooseAction
        case .recommendTrainingLens, .generateQuest:
            return true
        }
    }

    private static func isAligned(
        _ question: ReflectionQuestion,
        with dimension: ThinkingTrainingDimension
    ) -> Bool {
        switch dimension {
        case .factInterpretationSeparation:
            return question.lensMove == .factInterpretationSplit
        case .evidenceDiscipline:
            return question.evidenceGapType.map { $0 != .none } ?? false ||
                question.answerUse == .collectEvidence ||
                question.answerUse == .watchCalibrationSignal ||
                question.answerUse == .updateJudgment ||
                question.lensMove == .factInterpretationSplit
        case .counterexampleSeeking:
            return question.evidenceGapType == .missingCounterexample ||
                question.lensMove == .alternativeExplanation
        case .assumptionTesting:
            return question.answerUse == .testAssumption ||
                question.lensMove == .constraintDecomposition
        case .systemFeedbackAwareness:
            return question.lensMove == .feedbackLoop ||
                question.lensMove == .delayedEffect ||
                question.lensMove == .secondOrderConsequence
        case .judgmentCalibration:
            return question.evidenceGapType == .missingCalibrationSignal ||
                question.answerUse == .watchCalibrationSignal ||
                question.lensMove == .predictionCalibration
        case .testableActionDesign:
            return question.answerUse == .chooseAction ||
                question.answerUse == .testAssumption ||
                question.lensMove == .leverageTradeoff
        }
    }

    private static func normalizedComparableText(_ text: String?) -> String {
        (text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    private static func isBusyworkQuest(_ quest: Quest) -> Bool {
        let combined = [
            quest.title,
            quest.whyItMatters,
            quest.completionCriteria,
            quest.reflectionQuestion
        ].joined(separator: " ")
        let busyworkSignals = ["排版", "整理会议纪要", "补更多说明", "看起来更完整", "format", "polish"]
        let calibrationSignals = ["证据", "校准", "验证", "观察", "预测", "判断", "反例", "信号"]
        return busyworkSignals.contains { combined.localizedCaseInsensitiveContains($0) } &&
            !calibrationSignals.contains { combined.localizedCaseInsensitiveContains($0) }
    }

    private static func hasWeakCompletionCriteria(_ criteria: String) -> Bool {
        let trimmed = criteria.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 16 else { return true }
        let observableSignals = ["记录", "完成", "包含", "发送", "确认", "验收", "校准信号", "可观察", "before", "record"]
        return !observableSignals.contains { trimmed.localizedCaseInsensitiveContains($0) }
    }

    private static func hasWeakPrincipleActionability(_ principle: PrincipleAsset) -> Bool {
        let concreteActions = principle.actions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { action in
                action.count >= 6 && !containsVaguePrincipleLanguage(action)
            }
        guard concreteActions.count >= 2 else { return true }

        let successCriteria = principle.successCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        guard successCriteria.count >= 16 else { return true }

        let observableSignals = [
            "记录", "写", "列出", "确认", "复述", "发送", "验收", "标准", "负责人", "完成", "可观察",
            "record", "write", "confirm", "send", "owner", "acceptance", "criteria", "observable", "before"
        ]
        guard observableSignals.contains(where: { successCriteria.localizedCaseInsensitiveContains($0) }) else {
            return true
        }

        let combined = [
            principle.title,
            principle.summary,
            principle.triggerContext,
            principle.successCriteria
        ].joined(separator: " ")
        return containsVaguePrincipleLanguage(combined)
    }

    private static func containsVaguePrincipleLanguage(_ text: String) -> Bool {
        let vagueSignals = [
            "做得更好",
            "保持清晰",
            "清晰沟通很重要",
            "事情更顺利",
            "持续改进",
            "提高效率",
            "be better",
            "keep clear",
            "improve efficiency",
            "things go smoother"
        ]
        return vagueSignals.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func hasWeakVerificationCalibrationNote(_ note: String) -> Bool {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40 else { return true }

        let originalPredictionSignals = [
            "原判断",
            "原预测",
            "原先判断",
            "original prediction",
            "original judgment",
            "target judgment"
        ]
        let actualEvidenceSignals = [
            "实际证据",
            "实际情况",
            "实际结果",
            "actual evidence",
            "evidence showed",
            "evidence shows",
            "actual result",
            "actual outcome"
        ]
        let evidenceGainedSignals = [
            "证据收获",
            "获得的证据",
            "证据显示",
            "evidence gained",
            "gained evidence",
            "what we learned",
            "learned that"
        ]
        let judgmentUpdateSignals = [
            "判断更新",
            "更新判断",
            "下一步判断",
            "judgment update",
            "updated judgment",
            "update the judgment",
            "next judgment"
        ]
        let observableEvidenceSignals = [
            "可观察证据",
            "可观察信号",
            "观察到",
            "observable evidence",
            "observable signal",
            "observed signal",
            "observed evidence"
        ]
        let completionCriteriaSignals = [
            "完成标准",
            "验收标准",
            "验收口径",
            "完成口径",
            "completion criteria",
            "acceptance criteria",
            "criteria matched",
            "criteria met"
        ]

        return !containsAnySignal(trimmed, originalPredictionSignals) ||
            !containsAnySignal(trimmed, actualEvidenceSignals) ||
            !containsAnySignal(trimmed, evidenceGainedSignals) ||
            !containsAnySignal(trimmed, judgmentUpdateSignals) ||
            !containsAnySignal(trimmed, observableEvidenceSignals) ||
            !containsAnySignal(trimmed, completionCriteriaSignals)
    }

    private static func hasWeakVerificationRecommendation(_ recommendation: String?) -> Bool {
        let trimmed = recommendation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.count >= 16 else { return true }

        let nextStepSignals = [
            "下一次",
            "下一步",
            "明天",
            "校准",
            "验证",
            "测试",
            "观察",
            "信号",
            "行动",
            "next calibration",
            "next action",
            "next step",
            "observable signal",
            "signal to observe",
            "test whether",
            "observe whether"
        ]
        return !containsAnySignal(trimmed, nextStepSignals)
    }

    private static func containsAnySignal(_ text: String, _ signals: [String]) -> Bool {
        signals.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

private struct PromptEvalFailure: Error, CustomStringConvertible {
    var description: String
}

private struct PromptEvalCase {
    var promptId: PromptID
    var caseId: String
    var name: String
    var inputSummary: String
    var expectedBehavior: String
    var assertion: (TodayAIResponseParser) throws -> Void

    static let fixedSuite: [PromptEvalCase] = [
        PromptEvalCase(
            promptId: .organizeCards,
            caseId: "cards.messy_daily_input",
            name: "Messy daily input produces typed sensitive cards",
            inputSummary: "Messy meeting coordination input with one sensitive internal-project card.",
            expectedBehavior: "Produce communication, risk, and task cards while preserving sensitivity classification."
        ) { _ in
            let assembler = XMLStreamingCardAssembler()
            _ = assembler.append(
                """
                <MINGSI_STREAM version="1">
                <CARD>
                <TYPE>communication</TYPE>
                <TITLE>会前没有明确要确认的决策</TITLE>
                <BODY>会议推进时先讨论细节，最后才发现负责人和验收标准没有写清。</BODY>
                <IMPORTANCE>high</IMPORTANCE>
                <SENSITIVITY>normal</SENSITIVITY>
                <CONFIDENCE>high</CONFIDENCE>
                <REASON>这是可复用的沟通流程问题。</REASON>
                </CARD>
                <CARD>
                <TYPE>risk</TYPE>
                <TITLE>内部项目名需要抽象化</TITLE>
                <BODY>用户提到具体内部项目和客户语境，后续模型调用应避免重复细节。</BODY>
                <IMPORTANCE>medium</IMPORTANCE>
                <SENSITIVITY>possibly_sensitive</SENSITIVITY>
                <CONFIDENCE>medium</CONFIDENCE>
                <REASON>符合隐私边界要求。</REASON>
                </CARD>
                <CARD>
                <TYPE>task</TYPE>
                <TITLE>下次会议前写出决策清单</TITLE>
                <BODY>列出本次会议要确认的事项、负责人和完成标准。</BODY>
                <IMPORTANCE>high</IMPORTANCE>
                <SENSITIVITY>normal</SENSITIVITY>
                <CONFIDENCE>high</CONFIDENCE>
                <REASON>可转化为明日验证。</REASON>
                </CARD>
                </MINGSI_STREAM>
                """
            )
            _ = assembler.finish()
            let cards = assembler.currentCards.compactMap(\.domainCard)
            try expect(cards.count == 3, "Expected three cards.")
            try expect(cards.map(\.type) == [.communication, .risk, .task], "Expected communication/risk/task cards.")
            try expect(cards.contains { $0.sensitivity == .possiblySensitive }, "Expected a possibly sensitive card.")
        },
        PromptEvalCase(
            promptId: .recommendLenses,
            caseId: "lenses.recommends_supported_default",
            name: "Lens recommendations include supported default",
            inputSummary: "Meeting reflection where facts and interpretation are mixed.",
            expectedBehavior: "Recommend at most two supported lens ids and choose a supported default lens."
        ) { _ in
            let object = try jsonObject(Self.recommendLensesFixture)
            guard let recommendations = object["recommended_lenses"] as? [[String: Any]],
                  let first = recommendations.first,
                  let defaultLens = object["default_lens"] as? String,
                  let id = first["id"] as? String else {
                throw PromptEvalFailure(description: "Expected recommended_lenses and default_lens.")
            }
            let supported = Set(BuiltinLensCatalog.library.items.map(\.promptId))
            try expect(supported.contains(id), "Expected supported lens id.")
            try expect(supported.contains(defaultLens), "Expected supported default lens.")
            try expect(recommendations.count <= 2, "Expected at most two recommendations.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.concrete_lens_specific",
            name: "Questions are concrete and lens-specific",
            inputSummary: "First-principles and evidence-check meeting cards requiring lens-specific follow-up questions.",
            expectedBehavior: "Generate concrete, lens-specific questions including fact-vs-judgment and disconfirmation checks."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.questionsFixture.utf8))
            try expect(questions.count == 3, "Expected three questions.")
            try expect(questions.contains { $0.question.contains("事实") && $0.question.contains("判断") }, "Expected fact-vs-judgment question.")
            try expect(questions.contains { $0.question.contains("最可能") && $0.question.contains("推翻") }, "Expected disconfirming evidence question.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.evidence_gap_taxonomy",
            name: "Questions classify evidence gaps",
            inputSummary: "Evidence-check and judgment-calibration cards with missing observations, counterexamples, and calibration signals.",
            expectedBehavior: "Classify question evidence gaps without forcing every question into a missing evidence category."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.evidenceGapTaxonomyQuestionsFixture.utf8))
            try expect(questions.count == 4, "Expected four taxonomy questions.")
            let gapTypes = Set(questions.compactMap(\.evidenceGapType))
            try expect(gapTypes.contains(.missingObservation), "Expected missing observation type.")
            try expect(gapTypes.contains(.missingCounterexample), "Expected missing counterexample type.")
            try expect(gapTypes.contains(.missingCalibrationSignal), "Expected missing calibration signal type.")
            try expect(gapTypes.contains(.none), "Expected non-gap tradeoff question to use none.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.answer_use_not_pseudo_depth",
            name: "Questions declare how answers will be used",
            inputSummary: "Real reflection cards where broad introspection would feel smart but would not update judgment or action.",
            expectedBehavior: "Every question should declare whether the answer updates judgment, chooses action, tests an assumption, collects evidence, or watches a calibration signal."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.answerUseQuestionsFixture.utf8))
            try expect(questions.count == 4, "Expected four answer-use questions.")
            let uses = Set(questions.compactMap(\.answerUse))
            try expect(uses.contains(.updateJudgment), "Expected update judgment question.")
            try expect(uses.contains(.chooseAction), "Expected choose action question.")
            try expect(uses.contains(.testAssumption), "Expected test assumption question.")
            try expect(uses.contains(.watchCalibrationSignal), "Expected calibration signal question.")
            try expect(
                questions.allSatisfy { !$0.question.contains("你怎么看") && !$0.question.contains("这说明了什么") },
                "Expected no pseudo-depth questions."
            )
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.lens_move_taxonomy",
            name: "Questions declare lens-specific reasoning moves",
            inputSummary: "System-thinking and judgment-calibration cards requiring feedback-loop, delayed-effect, second-order, and prediction-calibration moves.",
            expectedBehavior: "Every question should declare the concrete reasoning move trained by the selected lens."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.lensMoveQuestionsFixture.utf8))
            try expect(questions.count == 4, "Expected four lens-move questions.")
            let moves = Set(questions.compactMap(\.lensMove))
            try expect(moves.contains(.feedbackLoop), "Expected feedback loop move.")
            try expect(moves.contains(.delayedEffect), "Expected delayed effect move.")
            try expect(moves.contains(.secondOrderConsequence), "Expected second-order consequence move.")
            try expect(moves.contains(.predictionCalibration), "Expected prediction calibration move.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.source_card_grounding",
            name: "Questions cite confirmed source cards",
            inputSummary: "Confirmed meeting and ownership cards where useful follow-up questions must stay tied to card evidence.",
            expectedBehavior: "Every question should cite at least one confirmed card title instead of floating above the user's records."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.sourceGroundedQuestionsFixture.utf8))
            try expect(questions.count == 3, "Expected three grounded questions.")
            try expect(questions.allSatisfy { !$0.sourceCardTitles.isEmpty }, "Expected every question to cite source cards.")
            try expect(
                questions.flatMap(\.sourceCardTitles).contains("会议目标不清"),
                "Expected questions to cite the meeting-goal card."
            )
            try expect(
                questions.flatMap(\.sourceCardTitles).contains("接口归属未确认"),
                "Expected questions to cite the ownership card."
            )
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.calibration_target_declared",
            name: "Questions name the judgment they calibrate",
            inputSummary: "Judgment-calibration and opposing-view cards where useful questions must make the target judgment explicit.",
            expectedBehavior: "Every question should declare a concrete judgment, assumption, prediction, causal explanation, or tradeoff that the answer will calibrate."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.calibrationTargetQuestionsFixture.utf8))
            try expect(questions.count == 3, "Expected three calibration-target questions.")
            let targets = questions.compactMap(\.calibrationTarget)
            try expect(targets.count == questions.count, "Expected every question to include calibration_target.")
            try expect(
                targets.allSatisfy { target in
                    let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.count >= 8 && !trimmed.contains("用户的思考") && !trimmed.contains("这个情况")
                },
                "Expected concrete calibration targets instead of vague labels."
            )
            try expect(
                targets.contains { $0.contains("接口归属未确认") },
                "Expected ownership assumption calibration target."
            )
            try expect(
                targets.contains { $0.contains("小范围验收") },
                "Expected small-acceptance prediction calibration target."
            )
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.lens_feedback_tunes_moves",
            name: "Verified lens feedback tunes future questions",
            inputSummary: "Prior verified lens outcomes where one move should be reinforced and low-value moves should be avoided.",
            expectedBehavior: "Use lensFeedback verified outcomes to reinforce effective lens moves and avoid low-value or uncalibratable moves."
        ) { _ in
            let text = LocalPromptProvider().template(for: .generateQuestions, mode: .standard).userText
            try expect(text.contains("lensFeedback"), "Expected prompt to mention lensFeedback.")
            try expect(text.contains("verified outcomes"), "Expected prompt to use verified outcomes.")
            try expect(text.contains("lensMoves"), "Expected prompt to use specific lens moves from feedback.")
            try expect(text.contains("reinforce"), "Expected reinforce instruction.")
            try expect(text.contains("avoid"), "Expected avoid instruction.")
            try expect(
                text.contains("low-value or uncalibratable"),
                "Expected low-value or uncalibratable move guardrail."
            )
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.prompt_declares_non_appeasing_coach_stance",
            name: "Questions prompt declares non-appeasing coach stance",
            inputSummary: "A user wants to proceed while skipping facts, goals, or counterexamples.",
            expectedBehavior: "The prompt should tell the LLM to respect the user without flattering, reassuring, or agreeing around weak thinking moves."
        ) { _ in
            let text = LocalPromptProvider().template(for: .generateQuestions, mode: .standard).userText
            try expect(text.contains("not a satisfaction-maximizing assistant"), "Expected non-satisfaction stance.")
            try expect(text.contains("Do not flatter, reassure, or agree"), "Expected anti-flattery rule.")
            try expect(text.contains("Empathy is not agreement"), "Expected empathy-is-not-agreement rule.")
            try expect(text.contains("Critique the thinking move, not the person"), "Expected person-safe critique rule.")
            try expect(text.contains("weak claim, missing evidence, premature conclusion"), "Expected weak-thinking taxonomy.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_functional_coach_fields",
            name: "Question quality gate requires functional coach fields",
            inputSummary: "A grounded question that lacks why-now, expected-update, and proceed-when coach fields.",
            expectedBehavior: "Flag questions whose answer cannot be used to decide why this question now, what changes, and when to proceed."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "这次会议返工里，哪条是可观察事实？",
                    whyItMatters: "它把事实和解释拆开。",
                    evidenceGapType: .missingObservation,
                    answerUse: .collectEvidence,
                    lensMove: .factInterpretationSplit,
                    sourceCardTitles: ["会议返工来自验收口径不清"],
                    calibrationTarget: "验收口径不清是本次会议返工的主要原因"
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuestions(questions).map(\.reason))
            try expect(reasons.contains(.missingFunctionalCoachField), "Expected missing functional coach field issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_blocks_appeasing_output",
            name: "Question quality gate blocks appeasing output",
            inputSummary: "A structurally complete question praises and validates the user's existing judgment without naming any missing thinking move.",
            expectedBehavior: "Flag outputs that only reassure or increase confidence instead of correcting a weak thinking move."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "你已经想得很充分了，可以继续按这个方向推进吗？",
                    whyItMatters: "你的想法很有价值，这个问题帮助你更有信心地行动。",
                    whyNow: "当前最重要的是认可你已经做出的判断。",
                    expectedUpdate: "答案会让你更确定自己原来的方向。",
                    proceedWhen: "当你觉得有信心时就可以推进。",
                    evidenceGapType: EvidenceGapType.none,
                    answerUse: .chooseAction,
                    lensMove: .leverageTradeoff,
                    sourceCardTitles: ["会议返工来自验收口径不清"],
                    calibrationTarget: "继续按当前判断推进"
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuestions(questions).map(\.reason))
            try expect(reasons.contains(.appeasingWithoutCorrection), "Expected appeasing output issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_blocks_generic_uncalibratable_output",
            name: "Question quality gate blocks generic uncalibratable output",
            inputSummary: "A generated question that sounds reflective but lacks evidence gap, answer use, grounding, and a concrete calibration target.",
            expectedBehavior: "Flag generic or uncalibratable questions before they can count as passing prompt output."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "你怎么看这个情况？",
                    whyItMatters: "帮助你思考。",
                    evidenceGapType: nil,
                    answerUse: nil,
                    lensMove: nil,
                    sourceCardTitles: [],
                    calibrationTarget: "用户的思考"
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuestions(questions).map(\.reason))
            try expect(reasons.contains(.genericQuestion), "Expected generic question issue.")
            try expect(reasons.contains(.missingEvidenceGapType), "Expected missing evidence gap issue.")
            try expect(reasons.contains(.missingAnswerUse), "Expected missing answer use issue.")
            try expect(reasons.contains(.missingLensMove), "Expected missing lens move issue.")
            try expect(reasons.contains(.missingSourceGrounding), "Expected missing source grounding issue.")
            try expect(reasons.contains(.vagueCalibrationTarget), "Expected vague calibration target issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_honors_avoid_lens_moves",
            name: "Question quality gate honors avoided lens moves",
            inputSummary: "Verified lens feedback marks a prior prediction-calibration move as low-value and uncalibratable.",
            expectedBehavior: "Flag repeated avoided lens moves so the next prompt must choose a smaller, more observable move."
        ) { _ in
            let feedback = [
                PromptContextPayload.LensFeedbackContext(
                    lensId: ThinkingLens.judgmentCalibration.rawValue,
                    lensTitle: ThinkingLens.judgmentCalibration.title,
                    signal: "avoid",
                    completion: YesterdayCompletion.missed.rawValue,
                    valueRating: YesterdayValueRating.low.rawValue,
                    calibrationNote: "上一次预测校准问题太抽象，未产生可观察信号。",
                    recommendation: "下一次先明确证据缺口。",
                    questionTargets: ["小范围验收减少返工"],
                    evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                    lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
                )
            ]
            let questions = [
                ReflectionQuestion(
                    question: "明天能观察到哪个信号，证明小范围验收确实减少返工？",
                    whyItMatters: "校准信号让判断可以被事实更新。",
                    whyNow: "当前教练轮次需要避免重复低价值校准方式。",
                    expectedUpdate: "答案会更新下一次校准信号的选择。",
                    proceedWhen: "当答案给出一个更清晰的可观察信号时推进。",
                    evidenceGapType: .missingCalibrationSignal,
                    answerUse: .watchCalibrationSignal,
                    lensMove: .predictionCalibration,
                    sourceCardTitles: ["返工来自验收口径"],
                    calibrationTarget: "小范围验收能显著减少返工"
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuestions(questions, lensFeedback: feedback).map(\.reason))
            try expect(reasons == [.repeatedAvoidedLensMove], "Expected only repeated avoided lens move issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_adjusted_lens_move",
            name: "Question quality gate requires adjusted lens moves",
            inputSummary: "Verified lens feedback marks a prior prediction-calibration move as useful but too broad.",
            expectedBehavior: "Flag reuse of the same lens move and same calibration target when adjust feedback asked for a smaller observable signal."
        ) { _ in
            let feedback = [
                PromptContextPayload.LensFeedbackContext(
                    lensId: ThinkingLens.judgmentCalibration.rawValue,
                    lensTitle: ThinkingLens.judgmentCalibration.title,
                    signal: "adjust",
                    completion: YesterdayCompletion.partial.rawValue,
                    valueRating: YesterdayValueRating.medium.rawValue,
                    calibrationNote: "预测校准方向有用，但目标太大，完成后仍不知道验收机制是否真的减少返工。",
                    recommendation: "下一次把 prediction_calibration 缩小到一个可观察信号。",
                    questionTargets: ["验收机制减少返工"],
                    evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                    lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
                )
            ]
            let questions = [
                ReflectionQuestion(
                    question: "明天能观察到哪个信号，证明验收机制减少返工？",
                    whyItMatters: "它继续校准同一个判断。",
                    whyNow: "当前教练轮次需要把上次过大的校准目标缩小。",
                    expectedUpdate: "答案会更新校准目标的观察粒度。",
                    proceedWhen: "当答案把目标缩小到一个可观察信号时推进。",
                    evidenceGapType: .missingCalibrationSignal,
                    answerUse: .watchCalibrationSignal,
                    lensMove: .predictionCalibration,
                    sourceCardTitles: ["验收机制不清"],
                    calibrationTarget: "验收机制减少返工"
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuestions(questions, lensFeedback: feedback).map(\.reason))
            try expect(reasons == [.unadjustedLensMove], "Expected only unadjusted lens move issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_reinforced_lens_move",
            name: "Question quality gate requires reinforced lens moves",
            inputSummary: "Verified lens feedback marks a prior prediction-calibration move as high-value and worth reusing on current evidence.",
            expectedBehavior: "Flag question batches that ignore a reinforced lens move instead of carrying the useful reasoning move into current grounding and targets."
        ) { _ in
            let feedback = [
                PromptContextPayload.LensFeedbackContext(
                    lensId: ThinkingLens.judgmentCalibration.rawValue,
                    lensTitle: ThinkingLens.judgmentCalibration.title,
                    signal: "reinforce",
                    completion: YesterdayCompletion.done.rawValue,
                    valueRating: YesterdayValueRating.high.rawValue,
                    calibrationNote: "prediction_calibration produced a clear calibration signal.",
                    recommendation: "Keep prediction_calibration, but ground it in today's cards.",
                    questionTargets: ["书面验收减少返工"],
                    evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                    lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
                )
            ]
            let questions = [
                ReflectionQuestion(
                    question: "还有什么替代解释能说明今天的返工？",
                    whyItMatters: "它检查解释是否过早收敛。",
                    whyNow: "当前教练轮次需要检查是否忽略了已验证的有效 lens move。",
                    expectedUpdate: "答案会更新本轮是否沿用 prediction_calibration。",
                    proceedWhen: "当答案说明是否有必要改用替代解释时推进。",
                    evidenceGapType: .missingCounterexample,
                    answerUse: .testAssumption,
                    lensMove: .alternativeExplanation,
                    sourceCardTitles: ["今天返工来自验收口径"],
                    calibrationTarget: "今天返工主要来自验收口径不清"
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuestions(questions, lensFeedback: feedback).map(\.reason))
            try expect(reasons == [.missingReinforcedLensMove], "Expected only missing reinforced lens move issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_training_dimension_alignment",
            name: "Question quality gate requires training dimension alignment",
            inputSummary: "Coach plan sets evidence discipline as the primary training dimension while the generated question only chooses an action.",
            expectedBehavior: "Flag questions that serve neither the primary training dimension nor any baseline training dimension."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "明天应该优先做哪个动作来减少会议返工？",
                    whyItMatters: "它帮助选择下一步动作。",
                    whyNow: "当前教练轮次需要先判断行动选择是否跳过证据训练重点。",
                    expectedUpdate: "答案会更新下一步行动边界。",
                    proceedWhen: "当答案说明一个可执行动作和取舍理由时推进。",
                    evidenceGapType: EvidenceGapType.none,
                    answerUse: .chooseAction,
                    lensMove: .leverageTradeoff,
                    sourceCardTitles: ["会议返工来自验收口径不清"],
                    calibrationTarget: "优先做高杠杆动作能减少会议返工"
                )
            ]
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateQuestions(
                    questions,
                    primaryTrainingDimension: .evidenceDiscipline,
                    baselineTrainingDimensions: [.counterexampleSeeking]
                ).map(\.reason)
            )
            try expect(reasons == [.missingTrainingDimensionAlignment], "Expected only missing training dimension alignment issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_primary_training_dimension_focus",
            name: "Question quality gate requires first question primary training focus",
            inputSummary: "Coach plan sets judgment calibration as the primary training dimension while the generated first question only performs a baseline counterexample check.",
            expectedBehavior: "Flag question batches whose first question dilutes the coach-led main training focus by serving only a baseline check."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "还有哪个反例会推翻验收口径不清是返工主因？",
                    whyItMatters: "它检查当前解释是否过早收敛。",
                    whyNow: "当前教练轮次需要检查首问是否偏离主训练焦点。",
                    expectedUpdate: "答案会更新是否应该先做判断校准。",
                    proceedWhen: "当答案说明反例是否改变主判断时推进。",
                    evidenceGapType: .missingCounterexample,
                    answerUse: .testAssumption,
                    lensMove: .alternativeExplanation,
                    sourceCardTitles: ["验收口径导致返工"],
                    calibrationTarget: "验收口径不清是返工主要原因"
                )
            ]
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateQuestions(
                    questions,
                    primaryTrainingDimension: .judgmentCalibration,
                    baselineTrainingDimensions: [.counterexampleSeeking]
                ).map(\.reason)
            )
            try expect(reasons == [.missingPrimaryTrainingDimensionFocus], "Expected only missing primary training dimension focus issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_system_thinking_lens_move",
            name: "Question quality gate requires system thinking moves",
            inputSummary: "System-thinking lens selected but generated questions only test an alternative explanation.",
            expectedBehavior: "Flag question batches that ignore feedback-loop, delayed-effect, and second-order consequence moves when system thinking is selected."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "还有什么替代解释能说明今天的返工？",
                    whyItMatters: "它检查解释是否过早收敛。",
                    whyNow: "当前教练轮次需要确认系统思维是否被替代解释稀释。",
                    expectedUpdate: "答案会更新是否需要回到反馈回路或延迟影响。",
                    proceedWhen: "当答案说明替代解释是否足以替代系统信号时推进。",
                    evidenceGapType: .missingCounterexample,
                    answerUse: .testAssumption,
                    lensMove: .alternativeExplanation,
                    sourceCardTitles: ["临时修复带来返工"],
                    calibrationTarget: "返工主要来自解释过早收敛"
                )
            ]
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateQuestions(
                    questions,
                    selectedLens: .systemThinking
                ).map(\.reason)
            )
            try expect(reasons == [.missingSystemThinkingLensMove], "Expected only missing system thinking lens move issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.quality_gate_requires_selected_lens_move",
            name: "Question quality gate requires selected lens moves",
            inputSummary: "Leverage-analysis lens selected but generated questions only test an alternative explanation.",
            expectedBehavior: "Flag question batches that do not include the reasoning move required by the selected built-in lens."
        ) { _ in
            let questions = [
                ReflectionQuestion(
                    question: "还有什么替代解释能说明今天的返工？",
                    whyItMatters: "它检查解释是否过早收敛。",
                    whyNow: "当前教练轮次需要确认杠杆分析透镜是否被替代解释稀释。",
                    expectedUpdate: "答案会更新是否需要回到高杠杆取舍。",
                    proceedWhen: "当答案说明替代解释是否改变最高杠杆动作时推进。",
                    evidenceGapType: .missingCounterexample,
                    answerUse: .testAssumption,
                    lensMove: .alternativeExplanation,
                    sourceCardTitles: ["会议返工来自低价值任务"],
                    calibrationTarget: "明天最能减少返工的是最高杠杆动作"
                )
            ]
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateQuestions(
                    questions,
                    selectedLens: .leverageAnalysis
                ).map(\.reason)
            )
            try expect(reasons == [.missingSelectedLensMove], "Expected only missing selected lens move issue.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.system_thinking_calibration",
            name: "System thinking questions expose loops and calibration signals",
            inputSummary: "Repeated rework and delayed integration cost cards selected with system_thinking lens.",
            expectedBehavior: "Generate system-thinking questions about feedback loops, delayed effects, second-order consequences, and next calibration signals."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.systemThinkingQuestionsFixture.utf8))
            try expect(questions.count == 3, "Expected three system-thinking questions.")
            try expect(
                questions.contains { $0.question.contains("反馈回路") || $0.question.contains("回路") },
                "Expected feedback-loop question."
            )
            try expect(
                questions.contains { $0.question.contains("延迟") || $0.question.contains("两周后") },
                "Expected delayed-effect question."
            )
            try expect(
                questions.contains { $0.question.contains("二阶后果") || $0.question.contains("后果") },
                "Expected second-order consequence question."
            )
            try expect(
                questions.contains { $0.question.contains("校准信号") || $0.question.contains("证明") },
                "Expected calibration signal question."
            )
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.main_quest_verifiable",
            name: "Main quest has verifiable criteria",
            inputSummary: "Meeting preparation card and reflection answers about reducing rework.",
            expectedBehavior: "Generate one main quest with observable completion criteria and an owner signal."
        ) { parser in
            let quests = try parser.parseQuests(from: Data(Self.questsFixture.utf8))
            try expect(quests.count == 1, "Expected exactly one quest.")
            try expect(quests[0].type == .main, "Expected main quest.")
            try expect(quests[0].completionCriteria.contains("负责人"), "Expected owner in completion criteria.")
            try expect(quests[0].completionCriteria.count > quests[0].title.count, "Expected detailed completion criteria.")
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.calibration_signal_task",
            name: "Main quest tests a judgment with a calibration signal",
            inputSummary: "System-thinking cards about repeated rework and delayed integration cost.",
            expectedBehavior: "Generate a main quest that closes an evidence gap and produces an observable calibration signal."
        ) { parser in
            let quests = try parser.parseQuests(from: Data(Self.calibrationQuestFixture.utf8))
            try expect(quests.count == 1, "Expected exactly one calibration quest.")
            let quest = quests[0]
            try expect(quest.type == .main, "Expected main quest.")
            try expect(quest.whyItMatters.contains("证据缺口"), "Expected evidence gap in why_it_matters.")
            try expect(quest.completionCriteria.contains("校准信号"), "Expected calibration signal in completion criteria.")
            try expect(quest.reflectionQuestion.contains("反馈回路"), "Expected feedback loop in reflection question.")
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.quality_gate_blocks_busywork_without_calibration",
            name: "Quest quality gate blocks busywork without calibration",
            inputSummary: "A generated main quest that polishes meeting notes but does not reduce uncertainty or create a calibration signal.",
            expectedBehavior: "Flag busywork, weak completion criteria, and vague calibration targets before accepting quest output."
        ) { _ in
            let quests = [
                Quest(
                    type: .main,
                    title: "整理会议纪要排版",
                    whyItMatters: "看起来更完整。",
                    completionCriteria: "把会议纪要排版好。",
                    expectedResistance: "会觉得还有很多要补。",
                    reflectionQuestion: "今天感觉如何？",
                    calibrationTarget: "这个情况",
                    sourceCardTitles: ["会议返工来自验收口径"]
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuests(quests).map(\.reason))
            try expect(reasons.contains(.busyworkQuest), "Expected busywork quest issue.")
            try expect(reasons.contains(.weakCompletionCriteria), "Expected weak completion criteria issue.")
            try expect(reasons.contains(.vagueCalibrationTarget), "Expected vague calibration target issue.")
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.quality_gate_blocks_appeasing_output",
            name: "Quest quality gate blocks appeasing output",
            inputSummary: "A generated quest validates the user's current judgment and increases confidence without naming a repair move.",
            expectedBehavior: "Flag quests that let the user proceed by reassurance instead of testing a judgment, evidence gap, or skipped tradeoff."
        ) { _ in
            let quests = [
                Quest(
                    type: .main,
                    title: "继续按当前方案推进",
                    whyItMatters: "你已经想得很充分了，这会让你更有信心。",
                    completionCriteria: "明天完成推进并确认自己更有信心。",
                    expectedResistance: "可能担心还没准备好，但你的判断已经够好了。",
                    reflectionQuestion: "你是否更认可自己当前的方向？",
                    calibrationTarget: "继续按当前判断推进",
                    lensMove: .leverageTradeoff,
                    sourceCardTitles: ["会议返工来自验收口径不清"]
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuests(quests).map(\.reason))
            try expect(reasons.contains(.appeasingWithoutCorrection), "Expected appeasing quest issue.")
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.quality_gate_requires_source_grounding",
            name: "Quest quality gate requires source grounding",
            inputSummary: "A generated main quest that has a calibration signal but no linked card titles.",
            expectedBehavior: "Flag ungrounded quests before accepting tomorrow's action."
        ) { _ in
            let quests = [
                Quest(
                    type: .main,
                    title: "用一次小验收测试返工来源",
                    whyItMatters: "它补上返工判断里的证据缺口。",
                    completionCriteria: "明天下午前完成一次小范围验收，记录是否减少一轮返工，并写下一个可观察的校准信号。",
                    expectedResistance: "你会想先继续推进功能，因为短期看起来更快。",
                    reflectionQuestion: "这次验收有没有减少一轮返工？",
                    calibrationTarget: "小验收能比继续补说明更有效地减少返工",
                    sourceCardTitles: []
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluateQuests(quests).map(\.reason))
            try expect(reasons.contains(.missingSourceGrounding), "Expected missing source grounding issue.")
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.quality_gate_requires_selected_lens_move",
            name: "Quest quality gate requires selected lens moves",
            inputSummary: "Leverage-analysis lens selected but generated quest uses an opposing-view action.",
            expectedBehavior: "Flag quest output that does not include the reasoning move required by the selected built-in lens."
        ) { _ in
            let quests = [
                Quest(
                    type: .main,
                    title: "访谈一个反对方来测试解释",
                    whyItMatters: "它可以检查当前解释是否过早收敛。",
                    completionCriteria: "明天完成一次 15 分钟访谈，记录一个反方证据和一个可观察的校准信号。",
                    expectedResistance: "你会想直接推进当前判断，因为找反方反馈比较慢。",
                    reflectionQuestion: "这条反方证据是否推翻了当前解释？",
                    calibrationTarget: "返工主要来自对方没有理解当前解释",
                    lensMove: .alternativeExplanation,
                    sourceCardTitles: ["会议返工来自低价值任务"]
                )
            ]
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateQuests(
                    quests,
                    selectedLens: .leverageAnalysis
                ).map(\.reason)
            )
            try expect(reasons == [.missingSelectedLensMove], "Expected only missing selected lens move issue.")
        },
        PromptEvalCase(
            promptId: .verifyQuest,
            caseId: "verify.calibration_note_required",
            name: "Verification requires a calibration note",
            inputSummary: "Quest verification result where the user completed work but criteria were unclear.",
            expectedBehavior: "Return a calibration note and recommendation tied to the quest's acceptance criteria."
        ) { parser in
            let result = try parser.parseVerification(from: Data(Self.verificationFixture.utf8))
            try expect(result.calibrationNote.contains("验收标准"), "Expected calibration note to reference criteria.")
            try expect(result.recommendation?.isEmpty == false, "Expected recommendation.")
        },
        PromptEvalCase(
            promptId: .verifyQuest,
            caseId: "verify.judgment_update_from_evidence",
            name: "Verification updates judgment from evidence",
            inputSummary: "Quest predicted one small acceptance check would reveal the source of rework.",
            expectedBehavior: "Compare the original prediction with actual evidence, state evidence gained, and recommend the next calibration."
        ) { parser in
            let result = try parser.parseVerification(from: Data(Self.judgmentUpdateVerificationFixture.utf8))
            try expect(result.calibrationNote.contains("原判断"), "Expected original judgment in calibration note.")
            try expect(result.calibrationNote.contains("实际证据"), "Expected actual evidence in calibration note.")
            try expect(result.calibrationNote.contains("证据收获"), "Expected evidence gained in calibration note.")
            try expect(result.calibrationNote.contains("判断更新"), "Expected judgment update in calibration note.")
            try expect(result.calibrationNote.contains("可观察证据"), "Expected observable evidence in calibration note.")
            try expect(result.calibrationNote.contains("完成标准"), "Expected completion criteria evidence in calibration note.")
            let issues = PromptCoachingQualityPolicy.evaluateVerification(result, targetJudgment: "小范围验收可以暴露返工来源")
            try expect(issues.isEmpty, "Expected judgment-update verification to pass quality gate.")
            try expect(result.recommendation?.contains("下一次校准") == true, "Expected next calibration recommendation.")
        },
        PromptEvalCase(
            promptId: .verifyQuest,
            caseId: "verify.quality_gate_blocks_weak_calibration_note",
            name: "Verification quality gate blocks weak calibration notes",
            inputSummary: "Quest verification result with a target judgment but only a generic usefulness note.",
            expectedBehavior: "Flag verification output that does not compare original prediction, actual evidence, evidence gained, and judgment update."
        ) { _ in
            let result = VerifyQuestResult(
                calibrationNote: "The quest was useful.",
                likelyIssue: nil,
                recommendation: "Next calibration: test whether written owner acknowledgement reduces ambiguity."
            )
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateVerification(
                    result,
                    targetJudgment: "Written owner acknowledgement reduces ambiguity"
                ).map(\.reason)
            )
            try expect(reasons == [.weakVerificationCalibrationNote], "Expected weak verification calibration note issue.")
        },
        PromptEvalCase(
            promptId: .verifyQuest,
            caseId: "verify.quality_gate_blocks_weak_recommendation",
            name: "Verification quality gate blocks weak recommendations",
            inputSummary: "Quest verification result with a strong calibration note but generic encouragement.",
            expectedBehavior: "Flag verification recommendation that does not name the next calibration action or observable signal."
        ) { _ in
            let result = VerifyQuestResult(
                calibrationNote: "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
                likelyIssue: "none",
                recommendation: "Keep going."
            )
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateVerification(
                    result,
                    targetJudgment: "Written owner acknowledgement reduces ambiguity"
                ).map(\.reason)
            )
            try expect(reasons == [.weakVerificationRecommendation], "Expected weak verification recommendation issue.")
        },
        PromptEvalCase(
            promptId: .verifyQuest,
            caseId: "verify.training_principle_assessment_required",
            name: "Verification requires expected principle practice assessment when training target exists",
            inputSummary: "Quest verification has an expected training principle but no separate practice assessment.",
            expectedBehavior: "Flag verification output that omits expected_principle_practice_assessment when trainingPrinciple was present."
        ) { _ in
            let result = VerifyQuestResult(
                calibrationNote: "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
                likelyIssue: "none",
                recommendation: "Next calibration: test whether earlier owner confirmation reduces rework."
            )
            let reasons = Set(
                PromptCoachingQualityPolicy.evaluateVerification(
                    result,
                    targetJudgment: "Written owner acknowledgement reduces ambiguity",
                    hasTrainingPrinciple: true
                ).map(\.reason)
            )
            try expect(
                reasons == [.missingExpectedPrinciplePracticeAssessment],
                "Expected missing expected principle practice assessment issue."
            )
        },
        PromptEvalCase(
            promptId: .extractPrinciple,
            caseId: "principle.behavior_rule_not_slogan",
            name: "Principle is a behavior rule rather than a slogan",
            inputSummary: "Repeated meeting ownership pattern suitable for a reusable behavior rule.",
            expectedBehavior: "Extract a principle with concrete actions, success criteria, and source card grounding rather than a vague slogan."
        ) { parser in
            let principles = try parser.parsePrinciples(from: Data(Self.principleFixture.utf8))
            try expect(principles.count == 1, "Expected one principle.")
            try expect(principles[0].actions.count >= 3, "Expected concrete actions.")
            try expect(principles[0].successCriteria.contains("负责人"), "Expected success criteria.")
            try expect(principles[0].sourceCardTitles.contains("会议目标不清"), "Expected principle to cite source cards.")
        },
        PromptEvalCase(
            promptId: .extractPrinciple,
            caseId: "principle.quality_gate_requires_source_grounding",
            name: "Principle quality gate requires source grounding",
            inputSummary: "Reusable-looking principle that names behavior but cites no confirmed source card.",
            expectedBehavior: "Flag principle output that cannot be traced back to confirmed evidence."
        ) { _ in
            let principles = [
                PrincipleAsset(
                    title: "会议前先定义要确认的决策",
                    summary: "重要会议前先写清要确认什么、谁负责、什么算完成。",
                    triggerContext: "跨角色会议或需要推进协作时。",
                    actions: ["写出要确认的决策", "标出负责人", "写出验收标准"],
                    successCriteria: "参会者能复述下一步负责人和完成标准。",
                    exceptions: "低风险同步会可以只写一句目标。",
                    sourceCardTitles: []
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluatePrinciples(principles).map(\.reason))
            try expect(reasons == [.missingPrincipleSourceGrounding], "Expected missing principle source grounding issue.")
        },
        PromptEvalCase(
            promptId: .extractPrinciple,
            caseId: "principle.quality_gate_requires_actionability",
            name: "Principle quality gate requires actionability",
            inputSummary: "Reusable-looking principle that cites evidence but only offers vague advice.",
            expectedBehavior: "Flag principle output that is grounded but not actionable or verifiable."
        ) { _ in
            let principles = [
                PrincipleAsset(
                    title: "保持清晰",
                    summary: "清晰沟通很重要。",
                    triggerContext: "工作中需要沟通时。",
                    actions: ["做得更好"],
                    successCriteria: "事情更顺利。",
                    exceptions: "无。",
                    sourceCardTitles: ["会议目标不清"]
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluatePrinciples(principles).map(\.reason))
            try expect(reasons == [.weakPrincipleActionability], "Expected weak principle actionability issue.")
        },
        PromptEvalCase(
            promptId: .extractPrinciple,
            caseId: "principle.quality_gate_blocks_appeasing_output",
            name: "Principle quality gate blocks appeasing output",
            inputSummary: "A principle candidate turns confidence and reassurance into a reusable rule without evidence or boundary.",
            expectedBehavior: "Flag principles that preserve comfort instead of naming missing evidence, exception, trigger boundary, or action standard."
        ) { _ in
            let principles = [
                PrincipleAsset(
                    title: "相信自己当前判断",
                    summary: "你的想法很有价值，后续可以继续按当前判断推进。",
                    triggerContext: "当你觉得方向已经明确时。",
                    actions: ["认可自己的判断", "继续推进当前方案"],
                    successCriteria: "自己觉得更有信心。",
                    exceptions: "无。",
                    sourceCardTitles: ["会议返工来自验收口径不清"]
                )
            ]
            let reasons = Set(PromptCoachingQualityPolicy.evaluatePrinciples(principles).map(\.reason))
            try expect(reasons.contains(.appeasingWithoutCorrection), "Expected appeasing principle issue.")
        },
        PromptEvalCase(
            promptId: .suggestProjectLinks,
            caseId: "project_links.evidence_backed_candidates",
            name: "Project link suggestions keep evidence refs",
            inputSummary: "Daily project evidence containing one active-project blocker and one new long-running project candidate.",
            expectedBehavior: "Preserve evidence refs on both project link candidates and new project candidates."
        ) { parser in
            let result = try parser.parseProjectSuggestions(from: Data(Self.projectLinksFixture.utf8))
            try expect(result.projectLinks.count == 1, "Expected one link candidate.")
            try expect(result.projectLinks[0].sourceId == "card-123", "Expected source evidence id.")
            try expect(result.projectCandidates.first?.sourceRefs == ["card-456", "quest-789"], "Expected new project source refs.")
        },
        PromptEvalCase(
            promptId: .generateProjectInsights,
            caseId: "project_insights.source_refs_required",
            name: "Project insights preserve source refs",
            inputSummary: "Project insight fixture with a single quest-backed progress signal.",
            expectedBehavior: "Return only insights with valid source refs."
        ) { parser in
            let result = try parser.parseProjectInsights(from: Data(Self.projectInsightsFixture.utf8))
            try expect(result.insights.count == 1, "Expected one project insight.")
            try expect(result.insights[0].sourceRefs == ["quest-123"], "Expected source refs.")
        },
        PromptEvalCase(
            promptId: .suggestProjectMerges,
            caseId: "project_merges.overlap_evidence_required",
            name: "Project merge candidates require overlap evidence",
            inputSummary: "Two project candidates with explicit overlapping evidence links.",
            expectedBehavior: "Return merge candidates only when overlap evidence refs are present."
        ) { parser in
            let candidates = try parser.parseProjectMergeCandidates(from: Data(Self.projectMergesFixture.utf8))
            try expect(candidates.count == 1, "Expected one merge candidate.")
            try expect(candidates[0].overlappingEvidenceRefs == ["link-1", "verification-2"], "Expected overlap refs.")
        },
        PromptEvalCase(
            promptId: .generateSideQuest,
            caseId: "side_quest.llm_decides_offer_or_hold",
            name: "Side quest decisions are model-led and bounded",
            inputSummary: "An opted-in user with a small set of enabled life categories and recent outcomes.",
            expectedBehavior: "Return offer or hold, ground the rationale, and keep the optional encounter non-task-like while retaining safety and notification fields.") { _ in
            let template = LocalPromptProvider().template(for: .generateSideQuest, mode: .standard)
            try expect(template.userText.contains("offer | hold"), "Expected explicit offer-or-hold decision.")
            try expect(template.userText.contains("not being assigned another item to finish"), "Expected the encounter, rather than task, framing.")
            try expect(template.userText.contains("find a counterexample"), "Expected abstract coaching exercises to be excluded.")
            try expect(template.userText.contains("completion_experience"), "Expected explicit positive reward field.")
            try expect(template.userText.contains("prerequisite_ids"), "Expected explicit prerequisite field.")
            try expect(template.userText.contains("notification_title"), "Expected model-generated notification copy.")
            let object = try jsonObject(
                """
                {"decision":"hold","reason":"今天没有足够依据提供新的邀请。","grounding_refs":[],"offer":null}
                """
            )
            try expect(object["decision"] as? String == "hold", "Expected a valid hold decision fixture.")
            try expect(object["offer"] is NSNull, "Expected hold to have no offer.")
        },
        PromptEvalCase(
            promptId: .recommendGuidance,
            caseId: "guidance.model_selects_existing_hint",
            name: "Guidance selection is model-led and catalog-bounded",
            inputSummary: "Two eligible hints are available for a verification stage with one missing result signal.",
            expectedBehavior: "The model may show one supplied hint or hold, but cannot invent copy or IDs.") { _ in
            let template = LocalPromptProvider().template(for: .recommendGuidance, mode: .standard)
            try expect(template.userText.contains("show | hold"), "Expected explicit show-or-hold decision.")
            try expect(template.userText.contains("Never invent hint IDs"), "Expected catalog boundary.")
        },
        PromptEvalCase(
            promptId: .evaluateGuidanceEvidence,
            caseId: "guidance.evidence_classification_is_model_led",
            name: "Guidance evidence classification stays bounded",
            inputSummary: "A verification contains a concrete result and a hint rule about observable evidence.",
            expectedBehavior: "Return supports, counterexample, or insufficient for the supplied hint only.") { _ in
            let template = LocalPromptProvider().template(for: .evaluateGuidanceEvidence, mode: .standard)
            try expect(template.userText.contains("supports | counterexample | insufficient"), "Expected bounded evidence result.")
            try expect(template.userText.contains("Do not create scores"), "Expected no-score boundary.")
        },
        PromptEvalCase(
            promptId: .diagnoseTrainingCase,
            caseId: "coach.central_training_decision",
            name: "Training focus is decided by the central model",
            inputSummary: "Confirmed cards contain a judgment with an unresolved evidence gap.",
            expectedBehavior: "Return one existing lens, training dimension, phase, readiness, and repair-oriented reason.") { _ in
            let template = LocalPromptProvider().template(for: .diagnoseTrainingCase, mode: .standard)
            try expect(template.userText.contains("central coach decision layer"), "Expected central coach instruction.")
            try expect(template.userText.contains("recommended_lens_id"), "Expected structured lens decision.")
        },
        PromptEvalCase(
            promptId: .reviewCoachAnswer,
            caseId: "coach.answer_review_is_current_matter_bounded",
            name: "Answer review remains model-led and evidence-bounded",
            inputSummary: "One answered question cites a current matter card and needs a readiness review.",
            expectedBehavior: "Return readiness, an allowed move, and source references from the current matter only.") { _ in
            let template = LocalPromptProvider().template(for: .reviewCoachAnswer, mode: .standard)
            try expect(template.userText.contains("central coach review layer"), "Expected central answer-review instruction.")
            try expect(template.userText.contains("source_refs"), "Expected evidence references.")
            try expect(template.userText.contains("another matter's material"), "Expected current-matter isolation.")
        },
        PromptEvalCase(
            promptId: .weeklyCalibration,
            caseId: "growth.weekly_contributions_have_evidence",
            name: "Weekly growth contributions have evidence refs",
            inputSummary: "Weekly growth fixture with evidence-backed positive and negative metric contributions.",
            expectedBehavior: "Produce a draft-review weekly snapshot and metric contributions with source ids."
        ) { parser in
            let result = try parser.parseGrowthReport(from: Data(Self.growthFixture.utf8), period: "weekly", completeLoopCount: 5)
            try expect(result.snapshot.status == .draftReview, "Expected draft review growth snapshot.")
            try expect(result.contributions.count == 2, "Expected two metric contributions.")
            try expect(result.contributions.allSatisfy { !$0.sourceId.isEmpty }, "Expected contribution source ids.")
        },
        PromptEvalCase(
            promptId: .monthlyGrowth,
            caseId: "growth.monthly_contributions_have_evidence",
            name: "Monthly growth contributions have evidence refs",
            inputSummary: "Monthly growth fixture reusing evidence-backed metric contributions.",
            expectedBehavior: "Produce a monthly snapshot and contributions linked to source daily entries."
        ) { parser in
            let result = try parser.parseGrowthReport(from: Data(Self.growthFixture.utf8), period: "monthly", completeLoopCount: 6)
            try expect(result.snapshot.period == "monthly", "Expected monthly period.")
            try expect(result.contributions.allSatisfy { !$0.sourceDailyEntryId.uuidString.isEmpty }, "Expected source daily entry ids.")
        }
    ]

    private static let recommendLensesFixture = """
    {
      "recommended_lenses": [
        {
          "id": "evidence_check",
          "name": "证据校验",
          "why_recommended": "今天的会议判断混合了事实和解释。"
        }
      ],
      "default_lens": "evidence_check"
    }
    """

    private static let questionsFixture = """
    {
      "questions": [
        {
          "question": "这次会议中，哪些内容是事实，哪些只是你对对方意图的判断？",
          "why_this_matters": "证据校验透镜要求先分开事实和解释，避免把感觉当结论。",
          "evidence_gap_type": "missing_observation",
          "answer_use": "collect_evidence",
          "expected_answer_type": "fact"
        },
        {
          "question": "如果你对会议低效的判断是错的，最可能被哪条证据推翻？",
          "why_this_matters": "反方问题可以阻止只证明自己原本的看法。",
          "evidence_gap_type": "missing_counterexample",
          "answer_use": "test_assumption",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天只做一件事时，哪一个动作最能减少后续返工？",
          "why_this_matters": "杠杆分析必须把思考落到可执行取舍。",
          "evidence_gap_type": "none",
          "answer_use": "choose_action",
          "expected_answer_type": "tradeoff"
        }
      ]
    }
    """

    private static let evidenceGapTaxonomyQuestionsFixture = """
    {
      "questions": [
        {
          "question": "现在缺少哪条可观察事实，才能判断返工是不是由验收口径造成？",
          "why_this_matters": "先补观察事实，避免把感觉当成原因。",
          "evidence_gap_type": "missing_observation",
          "answer_use": "collect_evidence",
          "expected_answer_type": "fact"
        },
        {
          "question": "如果负责人确认不是返工来源，哪个反例会最先推翻你的解释？",
          "why_this_matters": "反例能防止只收集支持原判断的证据。",
          "evidence_gap_type": "missing_counterexample",
          "answer_use": "test_assumption",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天能观察到哪个校准信号，证明小范围验收确实减少返工？",
          "why_this_matters": "校准信号让判断可以被后续行动更新。",
          "evidence_gap_type": "missing_calibration_signal",
          "answer_use": "watch_calibration_signal",
          "expected_answer_type": "validation"
        },
        {
          "question": "如果只能做一个动作，你会先确认负责人还是先补实现，取舍标准是什么？",
          "why_this_matters": "这是行动取舍问题，不应该被伪装成证据缺口。",
          "evidence_gap_type": "none",
          "answer_use": "choose_action",
          "expected_answer_type": "tradeoff"
        }
      ]
    }
    """

    private static let answerUseQuestionsFixture = """
    {
      "questions": [
        {
          "question": "如果明天的小范围验收没有减少返工，你会更新哪个关于返工来源的判断？",
          "why_this_matters": "答案必须直接改变你对返工来源的判断，而不是停留在感受描述。",
          "evidence_gap_type": "missing_calibration_signal",
          "answer_use": "update_judgment",
          "expected_answer_type": "judgment"
        },
        {
          "question": "明天先确认负责人还是先补实现，哪一个更可能改变后续结果，取舍标准是什么？",
          "why_this_matters": "答案会直接决定下一步行动，而不是生成更多泛泛反思。",
          "evidence_gap_type": "none",
          "answer_use": "choose_action",
          "expected_answer_type": "tradeoff"
        },
        {
          "question": "如果负责人不清不是主要原因，哪个最小反证会推翻这个假设？",
          "why_this_matters": "答案会把假设变成可测试对象，避免只证明原解释正确。",
          "evidence_gap_type": "missing_counterexample",
          "answer_use": "test_assumption",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天结束时看哪个信号，能校准小验收是否真的降低了返工？",
          "why_this_matters": "答案会定义后续观察点，让判断可以被事实更新。",
          "evidence_gap_type": "missing_calibration_signal",
          "answer_use": "watch_calibration_signal",
          "expected_answer_type": "validation"
        }
      ]
    }
    """

    private static let lensMoveQuestionsFixture = """
    {
      "questions": [
        {
          "question": "这个临时修复不断制造返工的反馈回路是什么：哪个动作让下一轮问题更容易发生？",
          "why_this_matters": "答案要暴露系统如何持续制造同一类结果。",
          "evidence_gap_type": "missing_causal_link",
          "answer_use": "test_assumption",
          "lens_move": "feedback_loop",
          "expected_answer_type": "judgment"
        },
        {
          "question": "今天省掉验收会在两周后的集成阶段产生什么延迟影响？",
          "why_this_matters": "延迟影响能校准短期效率和长期返工之间的关系。",
          "evidence_gap_type": "missing_baseline",
          "answer_use": "update_judgment",
          "lens_move": "delayed_effect",
          "expected_answer_type": "validation"
        },
        {
          "question": "如果继续用临时修复推进，除了返工之外还会产生哪个二阶后果？",
          "why_this_matters": "二阶后果能避免只优化眼前动作。",
          "evidence_gap_type": "missing_constraint",
          "answer_use": "test_assumption",
          "lens_move": "second_order_consequence",
          "expected_answer_type": "judgment"
        },
        {
          "question": "原先认为小验收能减少返工的预测，被明天的实际证据怎样校准？",
          "why_this_matters": "判断校准要求把原预测和实际证据放在一起更新。",
          "evidence_gap_type": "missing_calibration_signal",
          "answer_use": "update_judgment",
          "lens_move": "prediction_calibration",
          "expected_answer_type": "validation"
        }
      ]
    }
    """

    private static let sourceGroundedQuestionsFixture = """
    {
      "questions": [
        {
          "question": "会议目标不清这张卡里，哪些内容是事实，哪些只是你对会议低效的解释？",
          "why_this_matters": "答案必须回到已确认卡片，才能关闭真实证据缺口。",
          "evidence_gap_type": "missing_observation",
          "answer_use": "collect_evidence",
          "lens_move": "fact_interpretation_split",
          "source_card_titles": ["会议目标不清"],
          "calibration_target": "会议低效主要来自目标不清",
          "expected_answer_type": "fact"
        },
        {
          "question": "接口归属未确认如果不是返工主因，哪条反例会最先推翻这个判断？",
          "why_this_matters": "反例问题必须绑定具体卡片，避免变成空泛反思。",
          "evidence_gap_type": "missing_counterexample",
          "answer_use": "test_assumption",
          "lens_move": "alternative_explanation",
          "source_card_titles": ["接口归属未确认"],
          "calibration_target": "接口归属未确认是返工主因",
          "expected_answer_type": "validation"
        },
        {
          "question": "会议目标不清和接口归属未确认之间，哪个反馈回路最可能持续制造返工？",
          "why_this_matters": "系统思维需要从来源卡片中寻找结构，而不是凭空讲道理。",
          "evidence_gap_type": "missing_causal_link",
          "answer_use": "test_assumption",
          "lens_move": "feedback_loop",
          "source_card_titles": ["会议目标不清", "接口归属未确认"],
          "calibration_target": "会议目标不清和接口归属未确认会形成持续返工回路",
          "expected_answer_type": "judgment"
        }
      ]
    }
    """

    private static let calibrationTargetQuestionsFixture = """
    {
      "questions": [
        {
          "question": "如果接口归属未确认不是返工主因，哪个反例会先出现？",
          "why_this_matters": "反例能把根因解释变成可校准判断。",
          "evidence_gap_type": "missing_counterexample",
          "answer_use": "test_assumption",
          "lens_move": "alternative_explanation",
          "source_card_titles": ["接口归属未确认"],
          "calibration_target": "接口归属未确认是返工主因",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天的小范围验收能观察到哪个信号，证明返工确实下降？",
          "why_this_matters": "预测必须绑定后续可观察信号。",
          "evidence_gap_type": "missing_calibration_signal",
          "answer_use": "watch_calibration_signal",
          "lens_move": "prediction_calibration",
          "source_card_titles": ["返工来自验收口径"],
          "calibration_target": "小范围验收能显著减少返工",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天先确认负责人还是先补实现，哪个选择更能降低后续返工？",
          "why_this_matters": "行动取舍需要说明被校准的权衡标准。",
          "evidence_gap_type": "none",
          "answer_use": "choose_action",
          "lens_move": "leverage_tradeoff",
          "source_card_titles": ["接口归属未确认", "会议目标不清"],
          "calibration_target": "先确认负责人比先补实现更能降低返工",
          "expected_answer_type": "tradeoff"
        }
      ]
    }
    """

    private static let systemThinkingQuestionsFixture = """
    {
      "questions": [
        {
          "question": "这个临时修复不断制造返工的反馈回路是什么：哪个动作让下一轮问题更容易发生？",
          "why_this_matters": "系统思维先看问题如何被结构持续制造，而不是只修一次症状。",
          "evidence_gap_type": "missing_causal_link",
          "answer_use": "test_assumption",
          "expected_answer_type": "judgment"
        },
        {
          "question": "今天省掉验收会在两周后的集成阶段产生什么延迟影响和二阶后果？",
          "why_this_matters": "延迟影响会让短期看似高效的选择在后面放大成本。",
          "evidence_gap_type": "missing_baseline",
          "answer_use": "update_judgment",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天能观察到哪个校准信号，证明你对返工来源的系统判断是对还是错？",
          "why_this_matters": "没有可观察信号，系统解释就会变成宏大叙事而不是可校准判断。",
          "evidence_gap_type": "missing_calibration_signal",
          "answer_use": "watch_calibration_signal",
          "expected_answer_type": "validation"
        }
      ]
    }
    """

    private static let questsFixture = """
    {
      "main_quest": {
        "type": "main",
        "title": "会前写出决策清单并确认负责人",
        "why_it_matters": "这是减少会议返工的最高杠杆动作。",
        "completion_criteria": "会议开始前完成一页清单，包含要确认的决策、负责人、验收标准，并在会后发出确认摘要。",
        "expected_resistance": "临时事项会诱导你直接开会而不先写清楚目标。",
        "reflection_question": "这次准备是否让会议少绕了一轮？",
        "lens_move": "leverage_tradeoff",
        "linked_cards": ["会前没有明确要确认的决策"]
      },
      "side_quests": [],
      "observation_quest": null,
      "rejected_low_value_tasks": ["先把会议纪要排版得更完整"]
    }
    """

    private static let calibrationQuestFixture = """
    {
      "main_quest": {
        "type": "main",
        "title": "用一次小验收测试返工来源",
        "why_it_matters": "这不是普通待办，而是用明天的行动补上返工判断里的证据缺口。",
        "completion_criteria": "明天下午前完成一次小范围验收，记录是否减少一轮返工，并写下一个可观察的校准信号。",
        "expected_resistance": "你会想先继续推进功能，因为短期看起来更快。",
        "reflection_question": "这次验收有没有打断临时修复继续制造返工的反馈回路？",
        "lens_move": "feedback_loop",
        "linked_cards": ["临时修复反复制造返工", "集成问题延迟两周才暴露"]
      },
      "side_quests": [],
      "observation_quest": null,
      "rejected_low_value_tasks": ["继续补更多临时说明但不验证返工来源"]
    }
    """

    private static let verificationFixture = """
    {
      "calibration_note": "任务完成，但验收标准一开始还不够可观察。",
      "likely_issue": "unclear_criteria",
      "recommendation": "明天的主任务先写出可验收的完成标准。"
    }
    """

    private static let judgmentUpdateVerificationFixture = """
    {
      "calibration_note": "原判断是小范围验收可以暴露返工来源；实际证据显示返工主要来自负责人未确认，而不是实现细节。可观察证据是负责人没有在验收标准里确认完成口径。证据收获是下一次要先验证负责人和验收口径。判断更新是先确认负责人和完成标准，再继续投入实现。",
      "likely_issue": "unclear_criteria",
      "recommendation": "下一次校准先把负责人确认作为可观察信号，再决定是否继续投入实现。",
      "expected_principle_practice_assessment": "预期原则被部分实践：用户用小验收发现负责人确认缺口，但还没有在开始前完成负责人确认。"
    }
    """

    private static let principleFixture = """
    {
      "principle_candidate": {
        "title": "会议前先定义要确认的决策",
        "summary": "重要会议前先写清要确认什么、谁负责、什么算完成。",
        "trigger_context": "跨角色会议或需要推进协作时。",
        "actions": ["写出要确认的决策", "标出负责人", "写出验收标准", "会后发送确认摘要"],
        "success_criteria": "参会者能复述下一步负责人和完成标准。",
        "exceptions": "低风险同步会可以只写一句目标。",
        "source_card_titles": ["会议目标不清", "接口归属未确认"]
      }
    }
    """

    private static let projectLinksFixture = """
    {
      "project_link_candidates": [
        {
          "project_id": "11111111-1111-1111-1111-111111111111",
          "candidate_project_name": null,
          "link_type": "blocker",
          "source_type": "thinking_card",
          "source_id": "card-123",
          "reason": "The blocker matches an active project.",
          "confidence": "high",
          "requires_user_confirmation": true
        }
      ],
      "new_project_candidates": [
        {
          "candidate_project_name": "Cross-team ownership clarity",
          "goal": "Make ownership explicit before implementation work starts.",
          "current_bottleneck": "Responsibility boundaries keep surfacing after meetings.",
          "success_criteria": "Every cross-team decision has one owner and visible acceptance criteria.",
          "why_this_is_long_running": "The same ownership ambiguity appears across multiple planning loops.",
          "source_refs": [
            {
              "source_type": "thinking_card",
              "source_id": "card-456"
            },
            {
              "source_type": "quest",
              "source_id": "quest-789"
            }
          ],
          "privacy_safe_name_required": true,
          "confidence": "medium"
        }
      ]
    }
    """

    private static let projectInsightsFixture = """
    {
      "project_insights": [
        {
          "project_id": "22222222-2222-2222-2222-222222222222",
          "insight_type": "progress",
          "title": "Decision owner is now explicit",
          "summary": "The latest quest names the owner before implementation starts.",
          "before": null,
          "after": null,
          "source_refs": ["quest-123"],
          "confidence": "high"
        }
      ],
      "insufficient_evidence_reason": null
    }
    """

    private static let projectMergesFixture = """
    {
      "merge_candidates": [
        {
          "source_project_id": "33333333-3333-3333-3333-333333333333",
          "target_project_id": "44444444-4444-4444-4444-444444444444",
          "reason": "Both projects track the same repeated ownership ambiguity.",
          "overlapping_evidence_refs": ["link-1", "verification-2"],
          "risks_if_merged": ["One narrow context may get hidden."],
          "risks_if_kept_separate": ["Evidence remains split across duplicate projects."],
          "confidence": "high"
        }
      ]
    }
    """

    private static let growthFixture = """
    {
      "insufficient_evidence": false,
      "summary": "会议目标和验收标准比上周更清晰。",
      "metrics": {
        "clarity": {"value": 3.8, "delta": 0.2, "reason": "多次任务先定义负责人和验收标准。"},
        "value_judgment": {"value": 3.4, "delta": 0.1, "reason": "开始拒绝低价值排版任务。"},
        "execution_reliability": {"value": 3.2, "delta": 0.1, "reason": "主任务完成率稳定。"},
        "calibration": {"value": 3.1, "delta": 0.1, "reason": "复盘能识别标准不清。"},
        "reflection_depth": {"value": 3.6, "delta": 0.2, "reason": "能区分事实和判断。"}
      },
      "metric_contributions": [
        {
          "metric": "clarity",
          "direction": "positive",
          "delta": 0.20,
          "title": "会议目标更清晰",
          "reason": "用户在任务中明确要求会前写出决策、负责人和验收标准。",
          "source_type": "quest",
          "source_id": "quest-001",
          "source_daily_entry_id": "55555555-5555-5555-5555-555555555555"
        },
        {
          "metric": "reflection_depth",
          "direction": "positive",
          "delta": 0.10,
          "title": "能拆分事实和判断",
          "reason": "复盘记录了哪些是事实、哪些是对方意图的解释。",
          "source_type": "thinking_card",
          "source_id": "card-002",
          "source_daily_entry_id": "55555555-5555-5555-5555-555555555555"
        }
      ],
      "next_training_focus": "继续把会议任务写成可验收标准。"
    }
    """

    private static func jsonObject(_ json: String) throws -> [String: Any] {
        guard
            let data = json.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw PromptEvalFailure(description: "Invalid JSON object fixture.")
        }
        return object
    }
}

private extension Array where Element == PromptEvalCase {
    func groupedByPromptId() -> [(PromptID, [PromptEvalCase])] {
        var grouped: [PromptID: [PromptEvalCase]] = [:]
        for evalCase in self {
            grouped[evalCase.promptId, default: []].append(evalCase)
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.caseId < $1.caseId }) }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }
}

private func expect(_ condition: Bool, _ message: String) throws {
    guard condition else {
        throw PromptEvalFailure(description: message)
    }
}

protocol ReminderService {
    func requestPermission() async throws -> ReminderPermissionStatus
    func schedule(_ request: ReminderRequest) async throws
    func cancel(id: String) async
}

enum ReminderPermissionStatus: Hashable {
    case notDetermined
    case authorized
    case denied

    var allowsScheduling: Bool {
        self == .authorized
    }
}

enum ReminderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied."
        }
    }
}

struct ReminderRequest: Hashable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

final class LocalPromptProvider: PromptProvider {
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        let asset = Self.assetMetadata(for: id)
        return PromptTemplate(
            id: id,
            version: asset.promptVersion,
            systemPolicyVersion: asset.systemPolicyVersion,
            contextPolicyVersion: asset.contextPolicyVersion,
            evalSuiteVersion: asset.evalSuiteVersion,
            rollbackTargetVersion: asset.rollbackTargetVersion,
            systemText: id == .organizeCards ? Self.streamingCardsSystemText(for: mode) : Self.systemText(for: mode),
            userText: Self.userText(for: id, mode: mode),
            outputSchemaVersion: asset.outputSchemaVersion
        )
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let current = template(for: id, mode: mode)
        if current.version == version {
            return current
        }
        return Self.historicalTemplate(for: id, mode: mode, version: version, current: current)
    }

    private struct PromptAssetMetadata {
        var promptVersion: String
        var systemPolicyVersion: String
        var contextPolicyVersion: String
        var outputSchemaVersion: Int
        var evalSuiteVersion: String
        var rollbackTargetVersion: String?
    }

    private static func assetMetadata(for id: PromptID) -> PromptAssetMetadata {
        let promptVersion: String
        let rollbackTargetVersion: String?
        let outputSchemaVersion: Int
        switch id {
        case .generateQuestions:
            promptVersion = "1.13.0"
            rollbackTargetVersion = "1.12.0"
            outputSchemaVersion = 6
        case .generateQuests:
            promptVersion = "1.8.0"
            rollbackTargetVersion = "1.7.0"
            outputSchemaVersion = 3
        case .verifyQuest:
            promptVersion = "1.8.0"
            rollbackTargetVersion = "1.7.0"
            outputSchemaVersion = 3
        case .extractPrinciple:
            promptVersion = "1.5.0"
            rollbackTargetVersion = "1.4.0"
            outputSchemaVersion = 1
        default:
            promptVersion = "1.0.0"
            rollbackTargetVersion = nil
            outputSchemaVersion = 1
        }

        return PromptAssetMetadata(
            promptVersion: promptVersion,
            systemPolicyVersion: "system.v1",
            contextPolicyVersion: "context.\(id.rawValue).v1",
            outputSchemaVersion: outputSchemaVersion,
            evalSuiteVersion: "\(id.rawValue).eval.v1",
            rollbackTargetVersion: rollbackTargetVersion
        )
    }

    private static func historicalTemplate(
        for id: PromptID,
        mode: SessionMode,
        version: String,
        current: PromptTemplate
    ) -> PromptTemplate? {
        switch (id, version) {
        case (.generateQuestions, "1.12.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.11.0",
                systemText: current.systemText,
                userText: Self.userTextV1120(for: id, mode: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.11.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.10.0",
                systemText: current.systemText,
                userText: Self.userTextV1110(for: id, mode: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.10.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.9.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV1100UserText(for: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.9.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.8.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV190UserText(for: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.8.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.7.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV180UserText(for: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.7.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.6.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV170UserText(for: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.6.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.5.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV160UserText(for: mode),
                outputSchemaVersion: 6
            )
        case (.generateQuestions, "1.5.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.4.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV150UserText(for: mode),
                outputSchemaVersion: 5
            )
        case (.generateQuestions, "1.4.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.3.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV140UserText(for: mode),
                outputSchemaVersion: 4
            )
        case (.generateQuestions, "1.3.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.2.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV130UserText(for: mode),
                outputSchemaVersion: 3
            )
        case (.generateQuestions, "1.2.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.1.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV120UserText(for: mode),
                outputSchemaVersion: 2
            )
        case (.generateQuestions, "1.1.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.0.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV110UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.generateQuestions, "1.0.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "0.9.0",
                systemText: current.systemText,
                userText: Self.generateQuestionsV100UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.generateQuestions, "0.9.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: nil,
                systemText: current.systemText,
                userText: Self.generateQuestionsV090UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.generateQuests, "1.7.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.6.0",
                systemText: current.systemText,
                userText: Self.userTextV1120(for: id, mode: mode),
                outputSchemaVersion: 3
            )
        case (.generateQuests, "1.6.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.5.0",
                systemText: current.systemText,
                userText: Self.userTextV1110(for: id, mode: mode),
                outputSchemaVersion: 3
            )
        case (.generateQuests, "1.5.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.4.0",
                systemText: current.systemText,
                userText: Self.generateQuestsV150UserText(for: mode),
                outputSchemaVersion: 3
            )
        case (.generateQuests, "1.4.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.3.0",
                systemText: current.systemText,
                userText: Self.generateQuestsV140UserText(for: mode),
                outputSchemaVersion: 3
            )
        case (.generateQuests, "1.3.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.2.0",
                systemText: current.systemText,
                userText: Self.generateQuestsV130UserText(for: mode),
                outputSchemaVersion: 3
            )
        case (.generateQuests, "1.2.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.1.0",
                systemText: current.systemText,
                userText: Self.generateQuestsV120UserText(for: mode),
                outputSchemaVersion: 2
            )
        case (.generateQuests, "1.1.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.0.0",
                systemText: current.systemText,
                userText: Self.generateQuestsV110UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.generateQuests, "1.0.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: nil,
                systemText: current.systemText,
                userText: Self.generateQuestsV100UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.verifyQuest, "1.6.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.5.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV160UserText(for: mode),
                outputSchemaVersion: 2
            )
        case (.verifyQuest, "1.7.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.6.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV170UserText(for: mode),
                outputSchemaVersion: 2
            )
        case (.verifyQuest, "1.5.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.4.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV150UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.verifyQuest, "1.4.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.3.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV140UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.verifyQuest, "1.3.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.2.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV130UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.verifyQuest, "1.2.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.1.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV120UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.verifyQuest, "1.1.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.0.0",
                systemText: current.systemText,
                userText: Self.verifyQuestV110UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.verifyQuest, "1.0.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: nil,
                systemText: current.systemText,
                userText: Self.verifyQuestV100UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.extractPrinciple, "1.4.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.3.0",
                systemText: current.systemText,
                userText: Self.userTextV1110(for: id, mode: mode),
                outputSchemaVersion: 1
            )
        case (.extractPrinciple, "1.3.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.2.0",
                systemText: current.systemText,
                userText: Self.extractPrincipleV130UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.extractPrinciple, "1.2.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.1.0",
                systemText: current.systemText,
                userText: Self.extractPrincipleV120UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.extractPrinciple, "1.1.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: "1.0.0",
                systemText: current.systemText,
                userText: Self.extractPrincipleV110UserText(for: mode),
                outputSchemaVersion: 1
            )
        case (.extractPrinciple, "1.0.0"):
            return PromptTemplate(
                id: id,
                version: version,
                systemPolicyVersion: current.systemPolicyVersion,
                contextPolicyVersion: current.contextPolicyVersion,
                evalSuiteVersion: current.evalSuiteVersion,
                rollbackTargetVersion: nil,
                systemText: current.systemText,
                userText: Self.extractPrincipleV100UserText(for: mode),
                outputSchemaVersion: 1
            )
        default:
            return nil
        }
    }

    private static func generateQuestionsV110UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV120UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV130UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV140UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - Each question must declare the lens-specific reasoning move it trains with lens_move.
        - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
        - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV150UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - Each question must declare the lens-specific reasoning move it trains with lens_move.
        - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
        - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
        - Every question must cite at least one confirmed card title in source_card_titles.
        - Do not invent source_card_titles; use exact titles from confirmedCards.
        - If a question cannot be tied to a confirmed card, replace it with a grounded question.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
              "source_card_titles": ["exact confirmed card title"],
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV160UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - Each question must declare the lens-specific reasoning move it trains with lens_move.
        - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
        - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
        - Every question must cite at least one confirmed card title in source_card_titles.
        - Do not invent source_card_titles; use exact titles from confirmedCards.
        - If a question cannot be tied to a confirmed card, replace it with a grounded question.
        - Every question must name the judgment or assumption it will calibrate in calibration_target.
        - Do not use vague calibration targets like "the user's thinking" or "the situation"; name a concrete belief, prediction, causal explanation, or tradeoff.
        - If the target cannot be stated, replace the question with one whose calibration target is explicit.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        - When lensFeedback is present, use verified outcomes and lensMoves to tune the next questions: reinforce lensMoves marked reinforce, make lensMoves marked adjust more concrete, and avoid lensMoves marked avoid.
        - Do not repeat a lens move that produced low-value or uncalibratable work; replace it with a question that names a clearer evidence gap and calibration target.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, lensFeedback, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
              "source_card_titles": ["exact confirmed card title"],
              "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV170UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

        Coach-led training plan:
        - Use trainingPrescription as the coach plan, not a lens picker.
        - Read primaryTrainingDimension, secondaryTrainingDimensions, and baselineTrainingDimensions before writing questions.
        - The first question must train primaryTrainingDimension unless the confirmed cards make that unsafe or impossible.
        - Every question must serve either primaryTrainingDimension or one baselineTrainingDimension; use secondaryTrainingDimensions as optional follow-up, not as a second main focus.
        - Use selectedLens/finalTrainingLens to choose lens_move, but use training dimensions to decide what skill the question trains.
        - Do not treat a user override as proof that the coach diagnosis was wrong; keep override boundaries explicit in why_this_matters.

        Teaching frame:
        - Use coachTeachingPlan before wording questions.
        - Start from missingMoveTitle as the missing thinking move.
        - Use trainingTargetTitle to keep this as training, not an AI answer.
        - Keep whyNotAnswer visible in why_this_matters or why_now.
        - Use proceedStandard to define proceed_when.
        - Use repairQuestion when the user's prior answer still does not close the gap; ask the user to repair their own answer instead of giving an answer.
        - Use experienceReplayPrompt to ask whether prior experience should be reproduced, adapted, or rejected in this case.
        - routeSteps are teaching route cues, not permission to add extra workflow steps.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - Every question must include why_now: why this question is the right next move in the current coach turn.
        - Every question must include expected_update: what judgment, action, evidence plan, or calibration signal the answer is expected to change.
        - Every question must include proceed_when: what kind of answer is sufficient to move toward action.
        - Each question must declare the lens-specific reasoning move it trains with lens_move.
        - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
        - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
        - Every question must cite at least one confirmed card title in source_card_titles.
        - Do not invent source_card_titles; use exact titles from confirmedCards.
        - If a question cannot be tied to a confirmed card, replace it with a grounded question.
        - Every question must name the judgment or assumption it will calibrate in calibration_target.
        - Do not use vague calibration targets like "the user's thinking" or "the situation"; name a concrete belief, prediction, causal explanation, or tradeoff.
        - If the target cannot be stated, replace the question with one whose calibration target is explicit.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        - When lensFeedback is present, use verified outcomes and lensMoves to tune the next questions: reinforce lensMoves marked reinforce, make lensMoves marked adjust more concrete, and avoid lensMoves marked avoid.
        - Do not repeat a lens move that produced low-value or uncalibratable work; replace it with a question that names a clearer evidence gap and calibration target.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, finalTrainingLens, trainingPrescription, coachTeachingPlan, priorAnswers, lensFeedback, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "why_now": "why this question is the right next move in the current coach turn",
              "expected_update": "what judgment, action, evidence plan, or calibration signal the answer is expected to change",
              "proceed_when": "what kind of answer is sufficient to move toward action",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
              "source_card_titles": ["exact confirmed card title"],
              "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV180UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.
        You are not a satisfaction-maximizing assistant.
        Do not flatter, reassure, or agree just to make the user feel validated.
        If the user's input contains a weak claim, missing evidence, premature conclusion, vague goal, avoided responsibility, or harmful pattern, name it clearly.
        Critique the thinking move, not the person.
        Do not diagnose personality, intelligence, motivation, or hidden intent.
        Every correction must say what was observed, why it is weak or risky, what ability it trains, and what to repair next.

        Coach-led training plan:
        - Use trainingPrescription as the coach plan, not a lens picker.
        - Read primaryTrainingDimension, secondaryTrainingDimensions, and baselineTrainingDimensions before writing questions.
        - The first question must train primaryTrainingDimension unless the confirmed cards make that unsafe or impossible.
        - Every question must serve either primaryTrainingDimension or one baselineTrainingDimension; use secondaryTrainingDimensions as optional follow-up, not as a second main focus.
        - Use selectedLens/finalTrainingLens to choose lens_move, but use training dimensions to decide what skill the question trains.
        - Do not treat a user override as proof that the coach diagnosis was wrong; keep override boundaries explicit in why_this_matters.

        Teaching frame:
        - Use coachTeachingPlan before wording questions.
        - Start from missingMoveTitle as the missing thinking move.
        - Use trainingTargetTitle to keep this as training, not an AI answer.
        - Keep whyNotAnswer visible in why_this_matters or why_now.
        - Use proceedStandard to define proceed_when.
        - Use repairQuestion when the user's prior answer still does not close the gap; ask the user to repair their own answer instead of giving an answer.
        - Use experienceReplayPrompt to ask whether prior experience should be reproduced, adapted, or rejected in this case.
        - routeSteps are teaching route cues, not permission to add extra workflow steps.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - Every question must include why_now: why this question is the right next move in the current coach turn.
        - Every question must include expected_update: what judgment, action, evidence plan, or calibration signal the answer is expected to change.
        - Every question must include proceed_when: what kind of answer is sufficient to move toward action.
        - Each question must declare the lens-specific reasoning move it trains with lens_move.
        - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
        - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
        - Every question must cite at least one confirmed card title in source_card_titles.
        - Do not invent source_card_titles; use exact titles from confirmedCards.
        - If a question cannot be tied to a confirmed card, replace it with a grounded question.
        - Every question must name the judgment or assumption it will calibrate in calibration_target.
        - Do not use vague calibration targets like "the user's thinking" or "the situation"; name a concrete belief, prediction, causal explanation, or tradeoff.
        - If the target cannot be stated, replace the question with one whose calibration target is explicit.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        - When lensFeedback is present, use verified outcomes and lensMoves to tune the next questions: reinforce lensMoves marked reinforce, make lensMoves marked adjust more concrete, and avoid lensMoves marked avoid.
        - Do not repeat a lens move that produced low-value or uncalibratable work; replace it with a question that names a clearer evidence gap and calibration target.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, finalTrainingLens, trainingPrescription, coachTeachingPlan, priorAnswers, lensFeedback, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "why_now": "why this question is the right next move in the current coach turn",
              "expected_update": "what judgment, action, evidence plan, or calibration signal the answer is expected to change",
              "proceed_when": "what kind of answer is sufficient to move toward action",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
              "source_card_titles": ["exact confirmed card title"],
              "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV190UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        Do not ask questions that only invite opinions, venting, or vague self-description.
        Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.
        You are not a satisfaction-maximizing assistant.
        Do not flatter, reassure, or agree just to make the user feel validated.
        Empathy is not agreement.
        Acknowledge pressure or context only when it helps the user face the real thinking gap.
        If the user's input contains a weak claim, missing evidence, premature conclusion, vague goal, avoided responsibility, or harmful pattern, name it clearly.
        Critique the thinking move, not the person.
        Do not diagnose personality, intelligence, motivation, or hidden intent.
        Every correction must say what was observed, why it is weak or risky, what ability it trains, and what to repair next.

        Coach-led training plan:
        - Use trainingPrescription as the coach plan, not a lens picker.
        - Read primaryTrainingDimension, secondaryTrainingDimensions, and baselineTrainingDimensions before writing questions.
        - The first question must train primaryTrainingDimension unless the confirmed cards make that unsafe or impossible.
        - Every question must serve either primaryTrainingDimension or one baselineTrainingDimension; use secondaryTrainingDimensions as optional follow-up, not as a second main focus.
        - Use selectedLens/finalTrainingLens to choose lens_move, but use training dimensions to decide what skill the question trains.
        - Do not treat a user override as proof that the coach diagnosis was wrong; keep override boundaries explicit in why_this_matters.

        Teaching frame:
        - Use coachTeachingPlan before wording questions.
        - Start from missingMoveTitle as the missing thinking move.
        - Use trainingTargetTitle to keep this as training, not an AI answer.
        - Keep whyNotAnswer visible in why_this_matters or why_now.
        - Use proceedStandard to define proceed_when.
        - Use repairQuestion when the user's prior answer still does not close the gap; ask the user to repair their own answer instead of giving an answer.
        - Use experienceReplayPrompt to ask whether prior experience should be reproduced, adapted, or rejected in this case.
        - routeSteps are teaching route cues, not permission to add extra workflow steps.

        Loop boundary:
        - This prompt runs inside 今日复盘, not 明日实验.
        - Train the user to clarify today's content and today's review: what happened, how they acted, what they believed, what evidence is missing, and what judgment is now testable.
        - Do not design tomorrow's quest here. You may prepare the judgment and calibration signal that tomorrow's quest will use.

        Judgment sentence training:
        - Help the user repair answers toward this judgment sentence: 我现在相信 X；明天用 Y 观察它是否成立；如果出现 Z，我就更新判断。
        - Ask questions that make X, Y, or Z more concrete instead of giving the answer for the user.
        - calibration_target must be X: the belief, prediction, causal explanation, or tradeoff being tested.
        - expected_update should say how the answer changes X, Y, or Z.
        - proceed_when should say what is enough to move from 今日复盘 into 明日实验.

        Required coaching coverage:
        - At least one question must name an evidence gap or missing observation.
        - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
        - At least one question must connect to tomorrow's action or next calibration signal.
        - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
        - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
        - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
        - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
        - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
        - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
        - Every question must include why_now: why this question is the right next move in the current coach turn.
        - Every question must include expected_update: what judgment, action, evidence plan, or calibration signal the answer is expected to change.
        - Every question must include proceed_when: what kind of answer is sufficient to move toward action.
        - Each question must declare the lens-specific reasoning move it trains with lens_move.
        - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
        - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
        - Every question must cite at least one confirmed card title in source_card_titles.
        - Do not invent source_card_titles; use exact titles from confirmedCards.
        - If a question cannot be tied to a confirmed card, replace it with a grounded question.
        - Every question must name the judgment or assumption it will calibrate in calibration_target.
        - Do not use vague calibration targets like "the user's thinking" or "the situation"; name a concrete belief, prediction, causal explanation, or tradeoff.
        - If the target cannot be stated, replace the question with one whose calibration target is explicit.
        - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
        - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
        - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
        - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
        - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
        - When lensFeedback is present, use verified outcomes and lensMoves to tune the next questions: reinforce lensMoves marked reinforce, make lensMoves marked adjust more concrete, and avoid lensMoves marked avoid.
        - Do not repeat a lens move that produced low-value or uncalibratable work; replace it with a question that names a clearer evidence gap and calibration target.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, finalTrainingLens, trainingPrescription, coachTeachingPlan, priorAnswers, lensFeedback, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "why_now": "why this question is the right next move in the current coach turn",
              "expected_update": "what judgment, action, evidence plan, or calibration signal the answer is expected to change",
              "proceed_when": "what kind of answer is sufficient to move toward action",
              "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
              "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
              "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
              "source_card_titles": ["exact confirmed card title"],
              "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestionsV1100UserText(for mode: SessionMode) -> String {
        let teachingNeedle = """
        Teaching frame:
        - Use coachTeachingPlan before wording questions.
        - Start from missingMoveTitle as the missing thinking move.
        - Use trainingTargetTitle to keep this as training, not an AI answer.
        - Keep whyNotAnswer visible in why_this_matters or why_now.
        - Use proceedStandard to define proceed_when.
        - Use repairQuestion when the user's prior answer still does not close the gap; ask the user to repair their own answer instead of giving an answer.
        - Use experienceReplayPrompt to ask whether prior experience should be reproduced, adapted, or rejected in this case.
        - routeSteps are teaching route cues, not permission to add extra workflow steps.
        """
        let observationFrame = """
        Teaching frame:
        - Use coachTeachingPlan before wording questions.
        - Start from missingMoveTitle as the missing thinking move.
        - Use trainingTargetTitle to keep this as training, not an AI answer.
        - Keep whyNotAnswer visible in why_this_matters or why_now.
        - Use proceedStandard to define proceed_when.
        - Use repairQuestion when the user's prior answer still does not close the gap; ask the user to repair their own answer instead of giving an answer.
        - Use experienceReplayPrompt to ask whether prior experience should be reproduced, adapted, or rejected in this case.
        - routeSteps are teaching route cues, not permission to add extra workflow steps.

        Observation frame:
        - Use coachObservation before wording questions.
        - Treat coachObservation as the coach's interpretation of confirmed material, not source evidence.
        - Start from primaryGap and trainingAbility when deciding the first question.
        - Use feedback.observed to show what MingSi saw, feedback.diagnosis to name the gap, and feedback.ask as the repair question shape.
        - Use experienceReplayPrompt when the user's prior experience should be reproduced, adapted, or rejected.

        Question training contract:
        - Each batch must have one primary training contract derived from coachObservation.trainingAbility, coachObservation.primaryGap, and coachObservation.feedback.ask.
        - The first question must ask the user to produce missing material for that contract; it must not provide the missing material or solve the case for the user.
        - why_now must name the observed gap, not just say the topic is important.
        - expected_update must name the user-owned training output the answer should create.
        - proceed_when must name a self-checkable standard the user can inspect in their own answer.
        - If experienceReplayPrompt is relevant, ask the user to decide whether prior experience should reproduce, adapt, or reject today's move before applying it.
        """
        return generateQuestionsV190UserText(for: mode)
            .replacingOccurrences(of: teachingNeedle, with: observationFrame)
            .replacingOccurrences(
                of: "Input will include confirmedCards, selectedLens, finalTrainingLens, trainingPrescription, coachTeachingPlan, priorAnswers, lensFeedback, and sessionMode.",
                with: "Input will include confirmedCards, selectedLens, finalTrainingLens, trainingPrescription, coachObservation, coachTeachingPlan, priorAnswers, lensFeedback, and sessionMode."
            )
    }

    private static func generateQuestionsV100UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate lens-specific reflection questions from the confirmed cards.
        Questions must be specific to the user's content.
        Do not ask generic self-help questions.
        At least one question should challenge a hidden assumption.
        At least one question should connect to tomorrow's action.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func systemText(for mode: SessionMode) -> String {
        """
        You are 明思, a thinking coach for a busy knowledge worker.
        Help the user clarify problems, challenge assumptions, choose high-value actions, and calibrate judgment.
        Do not decide for the user.
        Do not replace the user's thinking.
        Separate facts, interpretations, assumptions, risks, and validation needs.
        Treat user statements as reported material, not independently verified facts. Do not present an inferred cause, motive, outcome, or growth claim as established evidence. When evidence is missing or conflicting, preserve the uncertainty and state what would make the claim checkable.
        Do not encourage the user to share confidential company information, code, customer data, or internal documents.
        Be concise, concrete, and non-performative.
        Language: 默认使用简体中文回答；if the user clearly writes in another language, follow the user's input language.
        Session mode: \(mode.rawValue). Quick is shortest path, standard is the default full loop, and deep uses more scrutiny.
        Return valid JSON only, matching the requested schema.
        """
    }

    private static func streamingCardsSystemText(for mode: SessionMode) -> String {
        """
        You are 明思, a thinking coach for a busy knowledge worker.
        Convert raw daily input into editable thinking cards.
        Do not decide for the user.
        Do not replace the user's thinking.
        Treat user statements as reported material, not independently verified facts. Preserve uncertainty instead of converting an interpretation, motive, or causal explanation into a fact.
        Do not encourage the user to share confidential company information, code, customer data, or internal documents.
        Language: 默认使用简体中文回答；if the user clearly writes in another language, follow the user's input language.
        Session mode: \(mode.rawValue). Quick is shortest path, standard is the default full loop, and deep uses more scrutiny.
        Return only MINGSI_STREAM_V2 XML-like tags. V2 may include CASE_KEY and CASE_TITLE inside each CARD. Do not return JSON, Markdown, comments, or explanations outside the allowed tags.
        """
    }

    private static func generateQuestionsV090UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate concrete reflection questions from the confirmed cards.
        Questions must be specific to the user's actual situation.
        Do not ask generic self-help questions.
        Include at least one question that tests an assumption or missing fact.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func generateQuestsV100UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate tomorrow's quests from confirmed cards and user answers.
        Create exactly one main quest unless information is insufficient.
        Create at most two side quests and at most one observation quest.
        The main quest should target the highest-value action, not the easiest task.
        Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
        If information is insufficient, ask for clarification rather than inventing a task.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedLens, and sessionMode.
        Return JSON:
        {
          "main_quest": {
            "type": "main",
            "title": "string",
            "why_it_matters": "string",
            "completion_criteria": "string",
            "expected_resistance": "string",
            "reflection_question": "string",
            "linked_cards": ["string"]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": ["string"]
        }
        """
    }

    private static func verifyQuestV100UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Review yesterday's quest, completion status, and actual value.
        Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
        Do not blame the user.
        Return a concise calibration note and one recommendation for today's quest design.
        \(modeGuidance)

        Input will include yesterdayQuest, userVerification, completionEvidence, and actualValue.
        Return JSON:
        {
          "calibration_note": "string",
          "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
          "recommendation": "string"
        }
        """
    }

    private static func generateQuestsV110UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate tomorrow's quests from confirmed cards and user answers.
        Create exactly one main quest unless information is insufficient.
        Create at most two side quests and at most one observation quest.
        The main quest should target the highest-value action, not the easiest task.
        Treat the main quest as a calibration instrument, not a generic todo.
        Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
        Each quest must include lens_move matching the selected lens's required reasoning move.
        The main quest must test one important judgment, close one evidence gap, or produce one observable calibration signal.
        Reject low-value tasks that feel productive but do not reduce uncertainty or improve tomorrow's judgment.
        If information is insufficient, ask for clarification rather than inventing a task.

        Lens-specific quest rules:
        - When selectedLens is system_thinking, choose an action that can interrupt a feedback loop, test a constraint, or observe a delayed effect.
        - When selectedLens is evidence_check, choose an action that gathers missing evidence or separates fact from interpretation.
        - When selectedLens is opposing_view, choose an action that can test the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, choose the smallest action likely to change the result, not the easiest visible work.
        - When selectedLens is first_principles, choose an action that validates a hard constraint or strips away an inherited assumption.
        - When selectedLens is judgment_calibration, choose an action that tests one prediction or produces a clear calibration signal.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedLens, and sessionMode.
        Return JSON:
        {
          "main_quest": {
            "type": "main",
            "title": "string",
            "why_it_matters": "string",
            "completion_criteria": "string",
            "expected_resistance": "string",
            "reflection_question": "string",
            "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
            "linked_cards": ["string"]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": ["string"]
        }
        """
    }

    private static func generateQuestsV120UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate tomorrow's quests from confirmed cards and user answers.
        Create exactly one main quest unless information is insufficient.
        Create at most two side quests and at most one observation quest.
        The main quest should target the highest-value action, not the easiest task.
        Treat the main quest as a calibration instrument, not a generic todo.
        Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
        The main quest must test one important judgment, close one evidence gap, or produce one observable calibration signal.
        Every quest must name the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate in calibration_target.
        Use reflectionAnswers calibrationTarget when it exists; otherwise derive a concrete target from confirmedCards and the user's answer.
        Do not invent vague calibration targets like "improve thinking" or "understand the situation".
        Reject low-value tasks that feel productive but do not reduce uncertainty or improve tomorrow's judgment.
        If information is insufficient, ask for clarification rather than inventing a task.
        Use lensFeedback as verified lens outcomes from previous days.
        Reinforce lensMoves that produced high-value calibration evidence.
        When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
        When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.

        Lens-specific quest rules:
        - When selectedLens is system_thinking, choose an action that can interrupt a feedback loop, test a constraint, or observe a delayed effect.
        - When selectedLens is evidence_check, choose an action that gathers missing evidence or separates fact from interpretation.
        - When selectedLens is opposing_view, choose an action that can test the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, choose the smallest action likely to change the result, not the easiest visible work.
        - When selectedLens is first_principles, choose an action that validates a hard constraint or strips away an inherited assumption.
        - When selectedLens is judgment_calibration, choose an action that tests one prediction or produces a clear calibration signal.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedLens, lensFeedback, and sessionMode.
        Return JSON:
        {
          "main_quest": {
            "type": "main",
            "title": "string",
            "why_it_matters": "string",
            "completion_criteria": "string",
            "expected_resistance": "string",
            "reflection_question": "string",
            "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
            "linked_cards": ["string"]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": ["string"]
        }
        """
    }

    private static func generateQuestsV130UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate tomorrow's quests from confirmed cards and user answers.
        Create exactly one main quest unless information is insufficient.
        Create at most two side quests and at most one observation quest.
        The main quest should target the highest-value action, not the easiest task.
        Treat the main quest as a calibration instrument, not a generic todo.
        Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
        The main quest must test one important judgment, close one evidence gap, or produce one observable calibration signal.
        Every quest must name the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate in calibration_target.
        Every quest must name the selected lens reasoning move it trains in lens_move.
        Use reflectionAnswers calibrationTarget when it exists; otherwise derive a concrete target from confirmedCards and the user's answer.
        Do not invent vague calibration targets like "improve thinking" or "understand the situation".
        Reject low-value tasks that feel productive but do not reduce uncertainty or improve tomorrow's judgment.
        If information is insufficient, ask for clarification rather than inventing a task.
        Use lensFeedback as verified lens outcomes from previous days.
        Reinforce lensMoves that produced high-value calibration evidence.
        When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
        When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.
        Use coachTeachingPlan.proceedStandard to preserve the evidence or answer standard that made action safe.
        Use coachTeachingPlan.experienceReplayPrompt when a quest should reuse, adapt, or reject past experience.
        If coachTeachingPlan.auditNote exists, keep it visible in why_it_matters or expected_resistance.
        Do not erase unresolved teaching gaps just because a quest can be generated.

        Lens-specific quest rules:
        - When selectedLens is system_thinking, choose an action that can interrupt a feedback loop, test a constraint, or observe a delayed effect.
        - When selectedLens is evidence_check, choose an action that gathers missing evidence or separates fact from interpretation.
        - When selectedLens is opposing_view, choose an action that can test the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, choose the smallest action likely to change the result, not the easiest visible work.
        - When selectedLens is first_principles, choose an action that validates a hard constraint or strips away an inherited assumption.
        - When selectedLens is judgment_calibration, choose an action that tests one prediction or produces a clear calibration signal.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedLens, lensFeedback, coachTeachingPlan, and sessionMode.
        Return JSON:
        {
          "main_quest": {
            "type": "main",
            "title": "string",
            "why_it_matters": "string",
            "completion_criteria": "string",
            "expected_resistance": "string",
            "reflection_question": "string",
            "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
            "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
            "linked_cards": ["string"]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": ["string"]
        }
        """
    }

    private static func generateQuestsV140UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate tomorrow's quests from confirmed cards and user answers.
        Create exactly one main quest unless information is insufficient.
        Create at most two side quests and at most one observation quest.
        The main quest should target the highest-value action, not the easiest task.
        Treat the main quest as a calibration instrument, not a generic todo.
        You are not a satisfaction-maximizing assistant.
        Do not turn a weak judgment into a quest just to let the user proceed.
        If the user's answers still contain weak evidence, skipped tradeoffs, premature conclusions, vague goals, avoided responsibility, or harmful patterns, name the unresolved evidence gap, skipped tradeoff, premature conclusion, or avoided responsibility before designing the quest.
        Critique the action design or thinking move, not the person.
        Do not diagnose personality, intelligence, motivation, or hidden intent.
        Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
        The main quest must test one important judgment, close one evidence gap, or produce one observable calibration signal.
        Every quest must name the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate in calibration_target.
        Every quest must name the selected lens reasoning move it trains in lens_move.
        Use reflectionAnswers calibrationTarget when it exists; otherwise derive a concrete target from confirmedCards and the user's answer.
        Do not invent vague calibration targets like "improve thinking" or "understand the situation".
        Reject low-value tasks that feel productive but do not reduce uncertainty or improve tomorrow's judgment.
        If information is insufficient, ask for clarification rather than inventing a task.
        Use lensFeedback as verified lens outcomes from previous days.
        Reinforce lensMoves that produced high-value calibration evidence.
        When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
        When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.
        Use coachTeachingPlan.proceedStandard to preserve the evidence or answer standard that made action safe.
        Use coachTeachingPlan.experienceReplayPrompt when a quest should reuse, adapt, or reject past experience.
        If coachTeachingPlan.auditNote exists, keep it visible in why_it_matters or expected_resistance.
        Do not erase unresolved teaching gaps just because a quest can be generated.

        Lens-specific quest rules:
        - When selectedLens is system_thinking, choose an action that can interrupt a feedback loop, test a constraint, or observe a delayed effect.
        - When selectedLens is evidence_check, choose an action that gathers missing evidence or separates fact from interpretation.
        - When selectedLens is opposing_view, choose an action that can test the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, choose the smallest action likely to change the result, not the easiest visible work.
        - When selectedLens is first_principles, choose an action that validates a hard constraint or strips away an inherited assumption.
        - When selectedLens is judgment_calibration, choose an action that tests one prediction or produces a clear calibration signal.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedLens, lensFeedback, coachTeachingPlan, and sessionMode.
        Return JSON:
        {
          "main_quest": {
            "type": "main",
            "title": "string",
            "why_it_matters": "string",
            "completion_criteria": "string",
            "expected_resistance": "string",
            "reflection_question": "string",
            "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
            "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
            "linked_cards": ["string"]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": ["string"]
        }
        """
    }

    private static func generateQuestsV150UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate tomorrow's quests from confirmed cards and user answers.
        Create exactly one main quest unless information is insufficient.
        Create at most two side quests and at most one observation quest.
        The main quest should target the highest-value action, not the easiest task.
        Treat the main quest as a calibration instrument, not a generic todo.
        You are not a satisfaction-maximizing assistant.
        Empathy is not agreement.
        Acknowledge pressure or context only when it helps the user face the real action-design gap.
        Do not turn a weak judgment into a quest just to let the user proceed.
        If the user's answers still contain weak evidence, skipped tradeoffs, premature conclusions, vague goals, avoided responsibility, or harmful patterns, name the unresolved evidence gap, skipped tradeoff, premature conclusion, or avoided responsibility before designing the quest.
        Critique the action design or thinking move, not the person.
        Do not diagnose personality, intelligence, motivation, or hidden intent.
        Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
        The main quest must test one important judgment, close one evidence gap, or produce one observable calibration signal.
        Every quest must name the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate in calibration_target.
        Every quest must name the selected lens reasoning move it trains in lens_move.
        Use reflectionAnswers calibrationTarget when it exists; otherwise derive a concrete target from confirmedCards and the user's answer.
        Do not invent vague calibration targets like "improve thinking" or "understand the situation".
        Reject low-value tasks that feel productive but do not reduce uncertainty or improve tomorrow's judgment.
        If information is insufficient, ask for clarification rather than inventing a task.
        Use lensFeedback as verified lens outcomes from previous days.
        Reinforce lensMoves that produced high-value calibration evidence.
        When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
        When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.
        Use coachTeachingPlan.proceedStandard to preserve the evidence or answer standard that made action safe.
        Use coachTeachingPlan.experienceReplayPrompt when a quest should reuse, adapt, or reject past experience.
        If coachTeachingPlan.auditNote exists, keep it visible in why_it_matters or expected_resistance.
        Do not erase unresolved teaching gaps just because a quest can be generated.

        Loop boundary:
        - This prompt runs inside 明日实验, after 今日复盘 has produced at least one testable judgment.
        - Do not continue today's review, add new reflection questions, or rewrite the user's whole story.
        - Convert one reviewed judgment into tomorrow's action; tomorrow's result calibration will later ask whether the action was done, whether it created value, and how the judgment changed.

        Judgment sentence training:
        - Reuse the reviewed judgment sentence shape: 我现在相信 X；明天用 Y 观察它是否成立；如果出现 Z，我就更新判断。
        - Use reflectionAnswers calibrationTarget as X when present.
        - main_quest.calibration_target must be X.
        - completion_criteria should preserve Y as an observable signal or artifact.
        - reflection_question or expected_resistance should preserve Z as the condition that would update the judgment.

        Lens-specific quest rules:
        - When selectedLens is system_thinking, choose an action that can interrupt a feedback loop, test a constraint, or observe a delayed effect.
        - When selectedLens is evidence_check, choose an action that gathers missing evidence or separates fact from interpretation.
        - When selectedLens is opposing_view, choose an action that can test the strongest alternative explanation or stakeholder objection.
        - When selectedLens is leverage_analysis, choose the smallest action likely to change the result, not the easiest visible work.
        - When selectedLens is first_principles, choose an action that validates a hard constraint or strips away an inherited assumption.
        - When selectedLens is judgment_calibration, choose an action that tests one prediction or produces a clear calibration signal.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedLens, lensFeedback, coachTeachingPlan, and sessionMode.
        Return JSON:
        {
          "main_quest": {
            "type": "main",
            "title": "string",
            "why_it_matters": "string",
            "completion_criteria": "string",
            "expected_resistance": "string",
            "reflection_question": "string",
            "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
            "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
            "linked_cards": ["string"]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": ["string"]
        }
        """
    }

    private static func verifyQuestV110UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Review yesterday's quest, completion status, and actual value.
        Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
        Do not blame the user.
        Compare the original prediction or intended judgment with the actual evidence.
        Name what evidence gained changes, confirms, or weakens the user's judgment.
        Return a concise calibration note and one recommendation for today's quest design.
        The calibration_note must include the original prediction, actual evidence, evidence gained, and judgment update.
        The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.
        \(modeGuidance)

        Input will include yesterdayQuest, userVerification, completionEvidence, and actualValue.
        Return JSON:
        {
          "calibration_note": "string",
          "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
          "recommendation": "string"
        }
        """
    }

    private static func verifyQuestV120UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Review yesterday's quest, completion status, and actual value.
        Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
        Do not blame the user.
        Compare the original prediction or intended judgment with the actual evidence.
        Compare targetJudgment with actual evidence when targetJudgment is present.
        Name what evidence gained changes, confirms, or weakens the user's judgment.
        Return a concise calibration note and one recommendation for today's quest design.
        The calibration_note must include the original prediction, actual evidence, evidence gained, and judgment update.
        The recommendation must name the next calibration action or signal to observe.
        \(modeGuidance)

        Input will include targetJudgment, yesterdayQuest, userVerification, completionEvidence, and actualValue.
        Return JSON:
        {
          "calibration_note": "string",
          "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
          "recommendation": "string"
        }
        """
    }

    private static func verifyQuestV130UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Review yesterday's quest, completion status, and actual value.
        Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
        Do not blame the user.
        Compare the original prediction or intended judgment with the actual evidence.
        Compare targetJudgment with actual evidence when targetJudgment is present.
        Name what evidence gained changes, confirms, or weakens the user's judgment.
        Name the observable evidence or signal that proves what actually happened.
        Compare completion criteria or acceptance criteria with the evidence before judging completion quality.
        Return a concise calibration note and one recommendation for today's quest design.
        The calibration_note must include the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
        The recommendation must name the next calibration action or signal to observe.
        \(modeGuidance)

        Input will include targetJudgment, yesterdayQuest, userVerification, completionEvidence, and actualValue.
        Return JSON:
        {
          "calibration_note": "string",
          "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
          "recommendation": "string"
        }
        """
    }

    private static func verifyQuestV140UserText(for mode: SessionMode) -> String {
        verifyQuestV130UserText(for: mode)
    }

    private static func verifyQuestV150UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Review yesterday's quest, completion status, and actual value.
        Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
        Do not blame the user.
        Compare the original prediction or intended judgment with the actual evidence.
        Compare targetJudgment with actual evidence when targetJudgment is present.
        If trainingPrinciple is present, assess whether the expected principle was actually practiced, using the provided matchSignal as the user's or local system's intended training signal.
        Do not create or confirm principle practice evidence yourself; only explain whether the verification evidence supports the expected principle practice.
        Name what evidence gained changes, confirms, or weakens the user's judgment.
        Name the observable evidence or signal that proves what actually happened.
        Compare completion criteria or acceptance criteria with the evidence before judging completion quality.
        Return a concise calibration note and one recommendation for today's quest design.
        The calibration_note must include the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
        When trainingPrinciple is present, the calibration_note must also mention whether the expected principle was actually practiced.
        The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.
        \(modeGuidance)

        Input will include targetJudgment, trainingPrinciple, yesterdayQuest, userVerification, completionEvidence, and actualValue.
        Return JSON:
        {
          "calibration_note": "string",
          "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
          "recommendation": "string"
        }
        """
    }

    private static func verifyQuestV160UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Review yesterday's quest, completion status, and actual value.
        Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
        Do not blame the user.
        Compare the original prediction or intended judgment with the actual evidence.
        Compare targetJudgment with actual evidence when targetJudgment is present.
        If trainingPrinciple is present, assess whether the expected principle was actually practiced, using the provided matchSignal as the user's or local system's intended training signal.
        Do not create or confirm principle practice evidence yourself; only explain whether the verification evidence supports the expected principle practice.
        Do not use expected_principle_practice_assessment as practice evidence; it is audit feedback only.
        Name what evidence gained changes, confirms, or weakens the user's judgment.
        Name the observable evidence or signal that proves what actually happened.
        Compare completion criteria or acceptance criteria with the evidence before judging completion quality.
        Return a concise calibration note, one recommendation for today's quest design, and a separate expected principle practice assessment.
        The calibration_note must include the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
        When trainingPrinciple is present, expected_principle_practice_assessment must state whether the expected principle was practiced, partially practiced, not practiced, or not assessable from the evidence, and name the evidence signal behind that judgment.
        The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.
        \(modeGuidance)

        Input will include targetJudgment, trainingPrinciple, yesterdayQuest, userVerification, completionEvidence, and actualValue.
        Return JSON:
        {
          "calibration_note": "string",
          "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
          "recommendation": "string",
          "expected_principle_practice_assessment": "string; required when trainingPrinciple is present, otherwise empty string"
        }
        """
    }

    private static func verifyQuestV170UserText(for mode: SessionMode) -> String {
        verifyQuestV160UserText(for: mode).replacingOccurrences(
            of: "Do not use expected_principle_practice_assessment as practice evidence; it is audit feedback only.",
            with: """
            Do not use expected_principle_practice_assessment as practice evidence; it is audit feedback only.

            Evidence ownership:
            - Treat completion, userVerification, completionEvidence, actualValue, and the user's judgmentUpdate as separate claims. They do not prove one another.
            - Completing an action proves only that the action was attempted; it does not prove value or confirm targetJudgment.
            - Only a concrete observed result, response, artifact, metric, or failed acceptance criterion may support, weaken, or confirm targetJudgment.
            - If the provided evidence is missing, indirect, conflicting, or only reports completion, explicitly say the evidence is insufficient and keep the judgment open. Do not invent an outcome, causal explanation, or principle practice.
            - In calibration_note, label the boundary between observed facts, the judgment update, and the next test so the user can tell what is known versus inferred.
            """
        )
        .replacingOccurrences(
            of: "Input will include targetJudgment, trainingPrinciple, yesterdayQuest, userVerification, completionEvidence, and actualValue.",
            with: "Input will include targetJudgment, trainingPrinciple, yesterdayQuest, completion, valueRating, judgmentUpdate, and currentInput.rawText as the user's recorded observable evidence."
        )
    }

    private static func verifyQuestV180UserText(for mode: SessionMode) -> String {
        verifyQuestV170UserText(for: mode).replacingOccurrences(
            of: "The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.",
            with: """
            The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.

            Growth settlement evidence:
            - Return zero to three growth_evidence_items only when the supplied evidence supports a specific newly demonstrated behavior.
            - This is a one-time evidence receipt, not a score, rating, personality conclusion, or ability change.
            - Each item must use exactly one category: clarify, judgment, or action; and one existing metric: clarity, value_judgment, execution_reliability, calibration, or reflection_depth.
            - Each title must describe the observed behavior in under 80 characters. Do not use generic praise.
            - source_refs may contain only the supplied quest ID and verification ID. The verification ID is preallocated for this request. If no item is evidence-backed, return an empty array.
            """
        )
        .replacingOccurrences(
            of: "\"expected_principle_practice_assessment\": \"string; required when trainingPrinciple is present, otherwise empty string\"",
            with: """
            \"expected_principle_practice_assessment\": \"string; required when trainingPrinciple is present, otherwise empty string\",
            \"growth_evidence_items\": [
              {
                \"category\": \"clarify | judgment | action\",
                \"metric\": \"clarity | value_judgment | execution_reliability | calibration | reflection_depth\",
                \"title\": \"brief observed behavior\",
                \"source_refs\": [\"quest UUID or verification UUID\"]
              }
            ]
            """
        )
    }

    private static func extractPrincipleV100UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
        Do not create a principle if the lesson is too situational.
        The principle must be concrete enough to apply later.
        Frame it as a behavior rule, not a slogan.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
        Return JSON:
        {
          "principle_candidate": {
            "title": "string",
            "summary": "string",
            "trigger_context": "string",
            "actions": ["string"],
            "success_criteria": "string",
            "exceptions": "string",
            "source_card_titles": ["string"]
          }
        }
        If no reusable rule is justified, return:
        {
          "principle_candidate": null
        }
        """
    }

    private static func extractPrincipleV110UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
        Do not create a principle if the lesson is too situational.
        The principle must be concrete enough to apply later.
        Frame it as a behavior rule, not a slogan.
        The principle must cite source_card_titles using exact titles from confirmedCards.
        Do not invent source_card_titles. If no confirmed card supports the rule, return principle_candidate: null.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
        Return JSON:
        {
          "principle_candidate": {
            "title": "string",
            "summary": "string",
            "trigger_context": "string",
            "actions": ["string"],
            "success_criteria": "string",
            "exceptions": "string",
            "source_card_titles": ["string"]
          }
        }
        If no reusable rule is justified, return:
        {
          "principle_candidate": null
        }
        """
    }

    private static func extractPrincipleV120UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
        Do not create a principle if the lesson is too situational.
        The principle must be concrete enough to apply later.
        Frame it as a behavior rule, not a slogan.
        The principle must include at least two concrete actions the user can do next time.
        The success_criteria must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
        Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
        The principle must cite source_card_titles using exact titles from confirmedCards.
        Do not invent source_card_titles. If no confirmed card supports the rule, return principle_candidate: null.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
        Return JSON:
        {
          "principle_candidate": {
            "title": "string",
            "summary": "string",
            "trigger_context": "string",
            "actions": ["string"],
            "success_criteria": "string",
            "exceptions": "string",
            "source_card_titles": ["string"]
          }
        }
        If no reusable rule is justified, return:
        {
          "principle_candidate": null
        }
        """
    }

    private static func extractPrincipleV130UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
        Do not create a principle if the lesson is too situational.
        The principle must be concrete enough to apply later.
        Frame it as a behavior rule, not a slogan.
        The principle must include at least two concrete actions the user can do next time.
        The success_criteria must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
        Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
        You are not a satisfaction-maximizing assistant.
        Do not turn an unverified story or comforting lesson into a principle.
        If the lesson lacks evidence, exceptions, trigger boundaries, or a concrete action standard, name the missing evidence, exception, trigger boundary, or action standard by returning principle_candidate: null instead of inventing a rule.
        Critique the reusable rule, not the person.
        Do not diagnose personality, intelligence, motivation, or hidden intent.
        The principle must cite source_card_titles using exact titles from confirmedCards.
        Do not invent source_card_titles. If no confirmed card supports the rule, return principle_candidate: null.
        \(modeGuidance)

        Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
        Return JSON:
        {
          "principle_candidate": {
            "title": "string",
            "summary": "string",
            "trigger_context": "string",
            "actions": ["string"],
            "success_criteria": "string",
            "exceptions": "string",
            "source_card_titles": ["string"]
          }
        }
        If no reusable rule is justified, return:
        {
          "principle_candidate": null
        }
        """
    }

    private static func userText(for id: PromptID, mode: SessionMode) -> String {
        let prior = userTextV1120(for: id, mode: mode)

        switch id {
        case .generateQuestions:
            return """
            \(prior)

            True-need grounding:
            - Treat a requested task, feature, solution, or plan as a proposed means, not proof of the underlying outcome that matters.
            - When the confirmed material names an action but not the affected person, object, consequence, or success condition, use the first useful question to uncover exactly one missing link: who or what is affected, what cost remains if nothing changes, or what observable change would count as success.
            - Do not add a separate needs-analysis ritual. If the cards already name a concrete affected object and an observable consequence or success condition, continue with the current evidence and judgment work.
            - Ask in the user's situation and vocabulary. Do not use business jargon such as “true need” as a label for the user.
            - A stated preference or a completed deliverable is not enough. The question must connect the proposed action to a condition in reality that the user can later observe.
            """
        case .generateQuests:
            return """
            \(prior)

            True-need validation:
            - A validation action must test whether the proposed work changes the concrete condition that matters, not merely whether the work was delivered.
            - Preserve the affected person or object, the observable condition that should change, and the feedback that would show no meaningful change in calibration_target, completion_criteria, or reflection_question.
            - When the real condition is still unknown, generate the smallest respectful discovery action instead of a delivery task. When it is already clear, do not add discovery work for its own sake.
            - Do not describe this as a “true need” exercise to the user. Keep the task grounded in their actual situation and the signal that would update their judgment.
            """
        default:
            return prior
        }
    }

    private static func userTextV1120(for id: PromptID, mode: SessionMode) -> String {
        let legacy = userTextV1110(for: id, mode: mode)

        switch id {
        case .generateQuestions:
            return legacy.replacingOccurrences(
                of: "Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.",
                with: """
                Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.

                Evidence ownership:
                - Confirmed cards are reported material. coachObservation, trainingPrescription, and coachTeachingPlan are coaching interpretations, not new source evidence.
                - Do not phrase an interpretation, causal explanation, or inferred motive as an established fact.
                - When a card contains only an interpretation, the first useful question must ask for the observable event, baseline, or counterexample that could support or weaken it.
                - A complete-sounding answer is not sufficient by itself: proceed_when must require material that can distinguish observation from interpretation or make the judgment testable.
                """
            )
        case .generateQuests:
            return legacy.replacingOccurrences(
                of: "Treat the main validation action as a calibration instrument, not a generic todo.",
                with: """
                Treat the main validation action as a calibration instrument, not a generic todo.

                Evidence ownership:
                - Completing the action is not evidence that the target judgment is correct or that the action created value.
                - completion_criteria must name the observable result, response, artifact, metric, or failed acceptance criterion to collect, not merely that the action was done.
                - reflection_question must ask what observed signal would support, weaken, or leave calibration_target unresolved; do not ask only whether the user completed the task.
                - If no discriminating signal can be observed tomorrow, turn the action into the smallest evidence-collection step or ask for clarification instead of producing a normal task.
                """
            )
        case .extractPrinciple:
            return legacy.replacingOccurrences(
                of: "Do not create a principle if the lesson is too situational.",
                with: """
                Do not create a principle if the lesson is too situational.

                Evidence ownership:
                - A completed action, a positive feeling, or one favorable outcome is not enough to establish a reusable rule.
                - Create a principle only when the supplied material shows either a repeated pattern or a stated invariant with an explicit boundary and a checkable next-use test.
                - Separate the observed pattern from the proposed rule. Do not invent repetition, causal certainty, or exceptions that are not supported by the input.
                - If the evidence only supports a one-time lesson, return principle_candidate: null and preserve it for later verification rather than promoting it into memory.
                """
            )
        case .verifyQuest:
            return verifyQuestV180UserText(for: mode)
        default:
            return legacy
        }
    }

    private static func userTextV1110(for id: PromptID, mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        switch id {
        case .organizeCards:
            return """
            Organize the user's raw daily input into editable thinking cards.
            Do not summarize into one article.
            Extract concrete facts, problems, decisions, risks, ideas, communications, and tasks.
            Preserve uncertainty. If boundaries are unclear, infer likely cards and mark lower confidence.
            If content may contain confidential company details, mark it possibly_sensitive or sensitive and avoid repeating unnecessary specifics.
            \(modeGuidance)

            Input will include rawText, optional projectContext, privacyRules, and sessionMode.
            Return only this controlled XML-like streaming format:
            <MINGSI_STREAM version="2">
            <CARD>
            <CASE_KEY>stable short key shared by cards from the same matter</CASE_KEY>
            <CASE_TITLE>short natural-language matter title</CASE_TITLE>
            <TYPE>fact | problem | decision | risk | idea | communication | task</TYPE>
            <TITLE>string</TITLE>
            <BODY>string</BODY>
            <IMPORTANCE>low | medium | high</IMPORTANCE>
            <SENSITIVITY>normal | possibly_sensitive | sensitive</SENSITIVITY>
            <CONFIDENCE>low | medium | high</CONFIDENCE>
            <REASON>string</REASON>
            </CARD>
            </MINGSI_STREAM>

            Rules:
            - Output no Markdown and no text outside the tags.
            - Start a CARD as soon as a candidate is clear enough; do not wait to plan every card first.
            - Every CARD must close with </CARD>.
            - Cards about the same matter must use the same CASE_KEY and CASE_TITLE. Distinct matters must use distinct keys.
            - BODY must not contain XML control tags. Rewrite angle brackets as plain words.
            - Prefer quick 1-3 cards, standard 2-6 cards, deep 3-8 cards.

            Example:
            <MINGSI_STREAM version="2">
            <CARD>
            <CASE_KEY>meeting-ownership</CASE_KEY>
            <CASE_TITLE>明确会议中的接口归属</CASE_TITLE>
            <TYPE>problem</TYPE>
            <TITLE>会议前没有定义确认事项</TITLE>
            <BODY>今天的会议讨论了接口归属，但会前没有先列出必须确认的问题。</BODY>
            <IMPORTANCE>high</IMPORTANCE>
            <SENSITIVITY>normal</SENSITIVITY>
            <CONFIDENCE>high</CONFIDENCE>
            <REASON>这是影响会议效率和结论质量的流程问题。</REASON>
            </CARD>
            </MINGSI_STREAM>
            """

        case .recommendLenses:
            return """
            Review the confirmed cards and recommend up to two thinking lenses.
            Choose lenses that improve the user's thinking quality today.
            Prefer lenses that expose unclear goals, weak evidence, opportunity cost, hidden assumptions, low-leverage execution, feedback loops, delayed effects, second-order consequences, prediction error, or judgment calibration needs.
            Explain briefly why each lens is useful.
            \(modeGuidance)

            Input will include confirmedCards, excludedCardTitles, and sessionMode.
            Return JSON:
            {
              "recommended_lenses": [
                {
                  "id": "first_principles | opposing_view | leverage_analysis | evidence_check | system_thinking | judgment_calibration",
                  "name": "string",
                  "why_recommended": "string"
                }
              ],
              "default_lens": "string"
            }
            """

        case .generateQuestions:
            return """
            Generate lens-specific reflection questions from the confirmed cards.
            Questions must be specific to the user's content.
            Do not ask generic self-help questions.
            Do not ask questions that only invite opinions, venting, or vague self-description.
            Ask as a thinking coach: expose the judgment being made, the evidence gap behind it, and the next calibration signal.
            You are not a satisfaction-maximizing assistant.
            Do not flatter, reassure, or agree just to make the user feel validated.
            Empathy is not agreement.
            Acknowledge pressure or context only when it helps the user face the real thinking gap.
            If the user's input contains a weak claim, missing evidence, premature conclusion, vague goal, avoided responsibility, or harmful pattern, name it clearly.
            Critique the thinking move, not the person.
            Do not diagnose personality, intelligence, motivation, or hidden intent.
            Every correction must say what was observed, why it is weak or risky, what ability it trains, and what to repair next.

            Coach-led training plan:
            - Use trainingPrescription as the coach plan, not a lens picker.
            - Read primaryTrainingDimension, secondaryTrainingDimensions, and baselineTrainingDimensions before writing questions.
            - The first question must train primaryTrainingDimension unless the confirmed cards make that unsafe or impossible.
            - Every question must serve either primaryTrainingDimension or one baselineTrainingDimension; use secondaryTrainingDimensions as optional follow-up, not as a second main focus.
            - Use selectedLens/finalTrainingLens to choose lens_move, but use training dimensions to decide what skill the question trains.
            - Do not treat a user override as proof that the coach diagnosis was wrong; keep override boundaries explicit in why_this_matters.

            Teaching frame:
            - Use coachTeachingPlan before wording questions.
            - Start from missingMoveTitle as the missing thinking move.
            - Use trainingTargetTitle to keep this as training, not an AI answer.
            - Keep whyNotAnswer visible in why_this_matters or why_now.
            - Use proceedStandard to define proceed_when.
            - Use repairQuestion when the user's prior answer still does not close the gap; ask the user to repair their own answer instead of giving an answer.
            - Use experienceReplayPrompt to ask whether prior experience should be reproduced, adapted, or rejected in this case.
            - routeSteps are teaching route cues, not permission to add extra workflow steps.

            Observation frame:
            - Use coachObservation before wording questions.
            - Treat coachObservation as the coach's interpretation of confirmed material, not source evidence.
            - Start from primaryGap and trainingAbility when deciding the first question.
            - Use feedback.observed to show what MingSi saw, feedback.diagnosis to name the gap, and feedback.ask as the repair question shape.
            - Use experienceReplayPrompt when the user's prior experience should be reproduced, adapted, or rejected.

            Question training contract:
            - Each batch must have one primary training contract derived from coachObservation.trainingAbility, coachObservation.primaryGap, and coachObservation.feedback.ask.
            - The first question must ask the user to produce missing material for that contract; it must not provide the missing material or solve the case for the user.
            - why_now must name the observed gap, not just say the topic is important.
            - expected_update must name the user-owned training output the answer should create.
            - proceed_when must name a self-checkable standard the user can inspect in their own answer.
            - If experienceReplayPrompt is relevant, ask the user to decide whether prior experience should reproduce, adapt, or reject today's move before applying it.

            Loop boundary:
            - This prompt runs inside 今日复盘, not 明日验证.
            - Train the user to clarify today's content and today's review: what happened, how they acted, what they believed, what evidence is missing, and what judgment is now testable.
            - Do not design tomorrow's validation action (验证行动) here. You may prepare the judgment and calibration signal that tomorrow's action will use.

            Judgment sentence training:
            - Help the user repair answers toward this judgment sentence: 我现在相信 X；明天用 Y 观察它是否成立；如果出现 Z，我就更新判断。
            - Ask questions that make X, Y, or Z more concrete instead of giving the answer for the user.
            - calibration_target must be X: the belief, prediction, causal explanation, or tradeoff being tested.
            - expected_update should say how the answer changes X, Y, or Z.
            - proceed_when should say what is enough to move from 今日复盘 into 明日验证.

            Required coaching coverage:
            - At least one question must name an evidence gap or missing observation.
            - At least one question must ask for a disconfirming signal: what would prove the current interpretation wrong?
            - At least one question must connect to tomorrow's action or next calibration signal.
            - Classify each question's evidence gap with evidence_gap_type. Use none when the question is primarily a tradeoff, framing, or prioritization question.
            - Evidence gap taxonomy: missing_observation, missing_baseline, missing_causal_link, missing_counterexample, missing_constraint, missing_calibration_signal, none.
            - Do not label every question as an evidence gap; only choose a missing_* type when the answer would close that specific gap.
            - Declare answer_use for every question: update_judgment, choose_action, test_assumption, collect_evidence, or watch_calibration_signal.
            - Do not ask aesthetically smart questions whose answer would not change a judgment or action.
            - If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question.
            - Every question must include why_now: why this question is the right next move in the current coach turn.
            - Every question must include expected_update: what judgment, action, evidence plan, or calibration signal the answer is expected to change.
            - Every question must include proceed_when: what kind of answer is sufficient to move toward action.
            - Each question must declare the lens-specific reasoning move it trains with lens_move.
            - Lens move taxonomy: fact_interpretation_split, alternative_explanation, leverage_tradeoff, constraint_decomposition, feedback_loop, delayed_effect, second_order_consequence, prediction_calibration.
            - Match lens_move to selectedLens: evidence_check uses fact_interpretation_split; opposing_view uses alternative_explanation; leverage_analysis uses leverage_tradeoff; first_principles uses constraint_decomposition; system_thinking uses feedback_loop, delayed_effect, or second_order_consequence; judgment_calibration uses prediction_calibration.
            - Every question must cite at least one confirmed card title in source_card_titles.
            - Do not invent source_card_titles; use exact titles from confirmedCards.
            - If a question cannot be tied to a confirmed card, replace it with a grounded question.
            - Every question must name the judgment or assumption it will calibrate in calibration_target.
            - Do not use vague calibration targets like "the user's thinking" or "the situation"; name a concrete belief, prediction, causal explanation, or tradeoff.
            - If the target cannot be stated, replace the question with one whose calibration target is explicit.
            - When selectedLens is system_thinking, include feedback loop, delayed effects, constraint, or second-order consequence language.
            - When selectedLens is evidence_check, separate facts, interpretations, assumptions, and validation needs.
            - When selectedLens is opposing_view, ask for the strongest alternative explanation or stakeholder objection.
            - When selectedLens is leverage_analysis, force a tradeoff between high-leverage action and low-value busyness.
            - When selectedLens is first_principles, separate hard constraints from inherited assumptions.
            - When selectedLens is judgment_calibration, compare original prediction, confidence, actual evidence, and judgment update.
            - When lensFeedback is present, use verified outcomes and lensMoves to tune the next questions: reinforce lensMoves marked reinforce, make lensMoves marked adjust more concrete, and avoid lensMoves marked avoid.
            - Do not repeat a lens move that produced low-value or uncalibratable work; replace it with a question that names a clearer evidence gap and calibration target.
            \(modeGuidance)

            Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
            Input will include confirmedCards, selectedLens, finalTrainingLens, trainingPrescription, coachObservation, coachTeachingPlan, priorAnswers, lensFeedback, and sessionMode.
            Return JSON:
            {
              "questions": [
                {
                  "question": "string",
                  "why_this_matters": "string",
                  "why_now": "why this question is the right next move in the current coach turn",
                  "expected_update": "what judgment, action, evidence plan, or calibration signal the answer is expected to change",
                  "proceed_when": "what kind of answer is sufficient to move toward action",
                  "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
                  "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
                  "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
                  "source_card_titles": ["exact confirmed card title"],
                  "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
                  "expected_answer_type": "fact | judgment | tradeoff | validation"
                }
              ]
            }
            """

        case .generateQuests:
            return """
            Generate tomorrow's validation actions from confirmed cards and user answers.
            Create exactly one main validation action unless information is insufficient.
            Create at most two side validation actions and at most one observation action.
            The main validation action should target the highest-value action, not the easiest task.
            Treat the main validation action as a calibration instrument, not a generic todo.
            You are not a satisfaction-maximizing assistant.
            Empathy is not agreement.
            Acknowledge pressure or context only when it helps the user face the real action-design gap.
            Do not turn a weak judgment into a validation action just to let the user proceed.
            If the user's answers still contain weak evidence, skipped tradeoffs, premature conclusions, vague goals, avoided responsibility, or harmful patterns, name the unresolved evidence gap, skipped tradeoff, premature conclusion, or avoided responsibility before designing the action.
            Critique the action design or thinking move, not the person.
            Do not diagnose personality, intelligence, motivation, or hidden intent.
            Each validation action must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
            The main validation action must test one important judgment, close one evidence gap, or produce one observable calibration signal.
            Every validation action must name the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate in calibration_target.
            Every validation action must name the selected lens reasoning move it trains in lens_move.
            Use reflectionAnswers calibrationTarget when it exists; otherwise derive a concrete target from confirmedCards and the user's answer.
            Do not invent vague calibration targets like "improve thinking" or "understand the situation".
            Reject low-value tasks that feel productive but do not reduce uncertainty or improve tomorrow's judgment.
            If information is insufficient, ask for clarification rather than inventing a task.
            Use lensFeedback as verified lens outcomes from previous days.
            Reinforce lensMoves that produced high-value calibration evidence.
            When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
            When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.
            Use coachTeachingPlan.proceedStandard to preserve the evidence or answer standard that made action safe.
            Use coachTeachingPlan.experienceReplayPrompt when a validation action should reuse, adapt, or reject past experience.
            If coachTeachingPlan.auditNote exists, keep it visible in why_it_matters or expected_resistance.
            Do not erase unresolved teaching gaps just because a validation action can be generated.

            Loop boundary:
            - This prompt runs inside 明日验证, after 今日复盘 has produced at least one testable judgment.
            - Do not continue today's review, add new reflection questions, or rewrite the user's whole story.
            - Convert one reviewed judgment into tomorrow's 验证行动; tomorrow's result calibration will later ask whether the action was done, whether it created value, and how the judgment changed.

            Judgment sentence training:
            - Reuse the reviewed judgment sentence shape: 我现在相信 X；明天用 Y 观察它是否成立；如果出现 Z，我就更新判断。
            - Use reflectionAnswers calibrationTarget as X when present.
            - main_quest.calibration_target must be X.
            - completion_criteria should preserve Y as an observable signal or artifact.
            - reflection_question or expected_resistance should preserve Z as the condition that would update the judgment.

            Lens-specific quest rules:
            - When selectedLens is system_thinking, choose an action that can interrupt a feedback loop, test a constraint, or observe a delayed effect.
            - When selectedLens is evidence_check, choose an action that gathers missing evidence or separates fact from interpretation.
            - When selectedLens is opposing_view, choose an action that can test the strongest alternative explanation or stakeholder objection.
            - When selectedLens is leverage_analysis, choose the smallest action likely to change the result, not the easiest visible work.
            - When selectedLens is first_principles, choose an action that validates a hard constraint or strips away an inherited assumption.
            - When selectedLens is judgment_calibration, choose an action that tests one prediction or produces a clear calibration signal.
            \(modeGuidance)

            Input will include confirmedCards, reflectionAnswers, selectedLens, lensFeedback, coachTeachingPlan, and sessionMode.
            Return JSON:
            {
              "main_quest": {
                "type": "main",
                "title": "string",
                "why_it_matters": "string",
                "completion_criteria": "string",
                "expected_resistance": "string",
                "reflection_question": "string",
                "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
                "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
                "linked_cards": ["string"]
              },
              "side_quests": [],
              "observation_quest": null,
              "rejected_low_value_tasks": ["string"]
            }
            """

        case .verifyQuest:
            return verifyQuestV160UserText(for: mode)

        case .extractPrinciple:
            return """
            From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
            Do not create a principle if the lesson is too situational.
            The principle must be concrete enough to apply later.
            Frame it as a behavior rule, not a slogan.
            The principle must include at least two concrete actions the user can do next time.
            The success_criteria must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
            Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
            You are not a satisfaction-maximizing assistant.
            Empathy is not agreement.
            Acknowledge pressure or context only when it helps the user face the real reusable-rule gap.
            Do not turn an unverified story or comforting lesson into a principle.
            If the lesson lacks evidence, exceptions, trigger boundaries, or a concrete action standard, name the missing evidence, exception, trigger boundary, or action standard by returning principle_candidate: null instead of inventing a rule.
            Critique the reusable rule, not the person.
            Do not diagnose personality, intelligence, motivation, or hidden intent.
            The principle must cite source_card_titles using exact titles from confirmedCards.
            Do not invent source_card_titles. If no confirmed card supports the rule, return principle_candidate: null.
            \(modeGuidance)

            Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
            Return JSON:
            {
              "principle_candidate": {
                "title": "string",
                "summary": "string",
                "trigger_context": "string",
                "actions": ["string"],
                "success_criteria": "string",
                "exceptions": "string",
                "source_card_titles": ["string"]
              }
            }
            If no reusable rule is justified, return:
            {
              "principle_candidate": null
            }
            """

        case .generateSideQuest:
            return """
            You are MingSi's life-encounter curator. Decide whether a small, optional encounter could feel naturally welcome today. This is not a productivity task generator, a self-improvement exercise, or a daily obligation.

            Use only the supplied context: current day, explicitly enabled categories, recent side-quest outcomes, current confirmed matters, the user-provided life context, and a reduced current situation snapshot. Make one of two decisions: `hold` when no encounter would feel natural today, or `offer` when a small, voluntary moment can bring curiosity, a pleasant surprise, or a sense of discovery beyond the active work loop.

            Encounter quality:
            - An encounter should feel like noticing a small unexpected detail on the way to an ordinary plan, not being assigned another item to finish.
            - Favor a concrete, low-pressure invitation: a different familiar turn, a sound or detail worth noticing, an unplanned browse, a small cultural detour, a remembered connection, or a private moment of attention.
            - It may be missed, ignored, or naturally pass. Never imply that accepting, doing, or writing about it is an achievement.
            - Never turn abstract thinking into an encounter. Do not ask the person to find a counterexample, analyze a belief, optimize themselves, make a plan, prove a result, or complete a deliberate training exercise.
            - The title must be evocative but plain. The invitation must be one light suggestion, not a checklist, instruction sequence, or measurable challenge. The optional observation question should invite a feeling or a noticed detail, never evidence or evaluation.
            - Prefer `hold` to a generic, task-like, repetitive, overly earnest, or weakly grounded offer.

            Safety and dignity rules:
            - Never infer personality, diagnose mental or physical health, judge appearance, prescribe diet/exercise, require spending, use contacts/location/calendar data, or encourage risky travel, strangers, alcohol, gambling, or illegal activity.
            - A connection invitation must make contact entirely voluntary. A movement invitation must be gentle and body-appropriate. A self-care invitation must not imply cleanliness, body shape, or productivity is moral worth.
            - Do not repeat a recent task or restate a declined task. Do not turn a user's unfinished main work into a side quest.
            - Treat recent_side_quest_corrections as explicit preference signals. Avoid repeating a corrected pattern, but never expose or infer the user's private note; only use the reason code and has_note flag.
            - When `exploration_season` is present, let its title and optional intent guide an offer without turning the season into a daily requirement. Prefer a category that extends the theme and avoid repeating categories already frequent in `category_history`. If no safe, practical invitation can genuinely continue that theme in the supplied situation, return `hold`.
            - Keep it concrete, naturally possible within 5-45 minutes, and safe to decline without explanation. Do not use a command tone or a productivity tone.
            - Never assume a facility, route, home/work identity, free time, physical capacity, or local resource that is not represented in the supplied context. In particular, do not suggest swimming, travel, or a venue without explicit evidence that it is available. Return `hold` whenever the situation is too uncertain for a practical invitation.
            - For an `offer`, `grounding_refs` must contain one or more exact tokens from `available_grounding_refs`. They are the only allowed reasons for claiming the invitation fits this moment. Do not invent tokens.
            - Choose only from enabled categories. Use only prerequisite IDs supplied by the schema.
            - Experience rewards are a quiet acknowledgement recorded by the app, not proof of intelligence, worth, productivity, or one of the five coaching metrics. Completion experience must be 10-30 and reflection bonus 0-5.

            Return JSON only:
            {
              "decision": "offer | hold",
              "reason": "brief explanation grounded in supplied context",
              "grounding_refs": ["exact token from available_grounding_refs"],
              "offer": {
                "category": "connection | curiosity | making | exploration | interest | vitality | self_care",
                "title": "short, evocative natural-language title",
                "invitation": "one voluntary, concrete, non-task-like suggestion",
                "evidence_prompt": "one optional prompt about a noticed detail or feeling",
                "minimum_minutes": 5,
                "maximum_minutes": 45,
                "prerequisite_ids": ["freelyChosenContact | daylightAndFamiliarRoute | availableMaterials | uninterruptedTenMinutes | bodyAppropriate | noRequiredSpending"],
                "completion_experience": 10,
                "reflection_bonus_experience": 0,
                "notification_title": "short optional notification title",
                "notification_body": "short optional notification body"
              }
            }
            When holding, set "offer" to null and explain why no invitation is useful now.
            """

        case .recommendGuidance:
            return """
            You are MingSi's central decision layer for selecting a single, useful in-app coaching hint.
            Review only the supplied current matter, stage, trigger signals, candidate hint definitions, and user hint state.
            Decide whether one candidate materially improves the user's next thinking move now.
            Return `hold` when the evidence is weak, the hint would be repetitive, or showing it would distract from the current action.
            Return `show` only when the selected hint directly addresses the current evidence gap.
            Never invent hint IDs or hint copy. Do not diagnose personality, motivation, intelligence, health, or intent.
            The local app will enforce cooldown, mastery, consent, and safety before presenting your decision.

            Return JSON only:
            {
              "decision": "show | hold",
              "hint_id": "one supplied candidate hint ID, or null when holding",
              "reason": "brief evidence-grounded explanation"
            }
            """

        case .evaluateGuidanceEvidence:
            return """
            You are MingSi's central decision layer for evaluating whether a confirmed verification provides evidence for one coaching hint.
            Compare the supplied hint rule, the original action and the user's actual verification evidence.
            Return `supports` only when the evidence demonstrates the hint's behavior was practiced.
            Return `counterexample` when the evidence shows the hinted behavior was missing or contradicted.
            Return `insufficient` when the evidence is too vague, indirect, or unrelated.
            Do not infer personality, motivation, health, or intent. Do not create scores or new hint IDs.

            Return JSON only:
            {
              "result": "supports | counterexample | insufficient",
              "hint_id": "the supplied hint ID",
              "reason": "brief explanation grounded in the supplied evidence"
            }
            """

        case .diagnoseTrainingCase:
            return """
            You are MingSi's central coach decision layer. Diagnose the current confirmed matter and choose one training focus before the user answers questions.
            Separate reported cards from your interpretation. Base every decision on the supplied cards only.
            Choose one phase, readiness, next move, training dimension, and existing thinking lens. Do not invent a new lens or diagnose personality, motivation, intelligence, health, or intent.
            `not_ready` means the next questions must close an evidence gap before action. `ready` means an observable action can be designed now.
            Be specific about what was observed, why it matters, what ability is being trained, and what the user must repair next.

            Allowed phase values: explore_problem, clarify_judgment, fill_evidence_gap, form_action.
            Allowed readiness values: ready, not_ready.
            Allowed next_move values: ask_clarifying_question, surface_evidence_gap, slow_down_convergence, recommend_training_lens, generate_quest.
            Allowed training dimensions: fact_interpretation_separation, evidence_discipline, counterexample_seeking, assumption_testing, system_feedback_awareness, judgment_calibration, testable_action_design.
            Allowed lens IDs: firstPrinciples, evidenceCheck, opposingView, leverageAnalysis, systemThinking, judgmentCalibration.

            Return JSON only:
            {
              "phase": "explore_problem | clarify_judgment | fill_evidence_gap | form_action",
              "readiness": "ready | not_ready",
              "recommended_move": "ask_clarifying_question | surface_evidence_gap | slow_down_convergence | recommend_training_lens | generate_quest",
              "training_dimension": "one allowed training dimension",
              "recommended_lens_id": "one allowed lens ID",
              "reason": "what was observed, why it matters, and what to repair next",
              "confidence": 0.0
            }
            """

        case .reviewCoachAnswer:
            return """
            You are MingSi's central coach review layer. Review only the supplied current matter cards, the coach's prior evidence gaps, and the user's answered questions.
            Decide whether the answer has actually closed the prior gap. Do not mistake fluency, optimism, task completion, or a stated intention for evidence.
            Return `ready` only when the current material supports moving to one observable validation action. Otherwise return `not_ready` or `partially_ready` and name the remaining evidence gap.
            Never diagnose personality, motivation, intelligence, health, or intent. Do not create scores, capability ratings, or facts that were not supplied. Do not use another matter's material.
            `source_refs` must cite one or more supplied card or answer IDs only. A reference suggestion is optional; it must be a structure, not an answer for the user to copy as fact.

            Return JSON only:
            {
              "readiness": "not_ready | partially_ready | ready",
              "recommended_move": "ask_clarifying_question | surface_evidence_gap | slow_down_convergence | generate_quest",
              "open_evidence_gaps": ["missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal"],
              "reason": "brief evidence-grounded explanation",
              "turn_summary": "brief summary of what changed after this answer",
              "coach_critique": "direct but nonjudgmental feedback grounded in the answer",
              "repaired_material": "what the answer made more concrete, or empty string",
              "missing_material": "the one most important remaining material, or a clear ready statement",
              "proceed_line": "what the user can do next, preserving their option to continue with a gap",
              "ability_gap": "brief current training gap",
              "training_output": "what a good next expression or action must make observable",
              "self_check": "one check the user can apply",
              "training_target": "what is being practiced in this current matter",
              "next_repair_question": "one concrete next question",
              "experience_replay_decision": "brief prompt to compare old experience with current conditions",
              "experience_replay_prompt": "one safe replay question",
              "judgment_sentence_prompt": "a sentence frame, not an asserted answer",
              "reference_suggestion": "optional brief structural guidance or empty string",
              "reference_example": "optional neutral sentence structure or empty string",
              "source_refs": ["supplied card ID or answer ID"]
            }
            """

        case .weeklyCalibration:
            return """
            Analyze confirmed daily records and quest verifications for the week.
            Produce a strict Growth attribution report.

            Rules:
            - Growth is an attribution ledger, not a personality test.
            - Fewer than 3 complete loops: return insufficient_evidence=true.
            - Every score delta must be explained by positive or negative metric_contributions.
            - Every contribution MUST include source_type, source_id, and source_daily_entry_id (UUID of the daily entry).
            - A contribution without source evidence must be omitted.
            - Delta per contribution must be between 0.01 and 0.30.
            - Avoid vague praise. Use evidence snippets.
            - Include dismissed contributions from prior rounds as context only.
            \(modeGuidance)

            Input includes: period, complete_loop_count, evidence_summaries (one per daily entry with id, card count, quest, verification), optional previous scores, optional dismissed_contributions.

            Return JSON:
            {
              "insufficient_evidence": false,
              "summary": "string: one-sentence attribution summary",
              "metrics": {
                "clarity": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "value_judgment": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "execution_reliability": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "calibration": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "reflection_depth": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"}
              },
              "metric_contributions": [
                {
                  "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
                  "direction": "positive | negative",
                  "delta": 0.01-0.30,
                  "title": "string",
                  "reason": "string",
                  "source_type": "daily_entry | thinking_card | quest | verification | principle",
                  "source_id": "UUID or string id of the source record",
                  "source_daily_entry_id": "UUID of the daily entry"
                }
              ],
              "next_training_focus": "string"
            }

            If insufficient evidence:
            {
              "insufficient_evidence": true,
              "summary": "string: explain what is missing",
              "metrics": {},
              "metric_contributions": [],
              "next_training_focus": "string"
            }
            """

        case .monthlyGrowth:
            return """
            Compare this month's records against baseline and early-month examples.
            Produce a strict Growth attribution report.

            Rules:
            - Growth is an attribution ledger, not a personality test.
            - Fewer than 3 complete loops: return insufficient_evidence=true.
            - Every score delta must be explained by positive or negative metric_contributions.
            - Every contribution MUST include source_type, source_id, and source_daily_entry_id (UUID of the daily entry).
            - A contribution without source evidence must be omitted.
            - Delta per contribution must be between 0.01 and 0.30.
            - Do not present scores as objective intelligence measures; present them as personal trend indicators.
            - Use before/after evidence.
            \(modeGuidance)

            Input includes: period, complete_loop_count, evidence_summaries, optional previous scores, optional dismissed_contributions.

            Return JSON:
            {
              "insufficient_evidence": false,
              "summary": "string",
              "metrics": {
                "clarity": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "value_judgment": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "execution_reliability": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "calibration": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "reflection_depth": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"}
              },
              "metric_contributions": [
                {
                  "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
                  "direction": "positive | negative",
                  "delta": 0.01-0.30,
                  "title": "string",
                  "reason": "string",
                  "source_type": "daily_entry | thinking_card | quest | verification | principle",
                  "source_id": "UUID or string id of the source record",
                  "source_daily_entry_id": "UUID of the daily entry"
                }
              ],
              "next_training_focus": "string"
            }

            If insufficient evidence:
            {
              "insufficient_evidence": true,
              "summary": "string",
              "metrics": {},
              "metric_contributions": [],
              "next_training_focus": "string"
            }
            """

        case .suggestProjectLinks:
            return """
            Review confirmed cards, quests, verifications, principles, and existing active projects.
            Suggest at most two project link candidates to existing projects.
            If no existing project fits and the evidence suggests a recurring long-running topic, propose at most one new project candidate.
            Do not use company-sensitive names.
            Only link confirmed evidence.
            Do not create or merge projects automatically.
            Return candidates that require user confirmation.
            Do not treat repeated keywords as a project unless there is a recurring goal, blocker, decision pattern, or action standard.

            Rules:
            - Every candidate must include source_ids referencing real evidence IDs.
            - A candidate without source evidence must be omitted.
            - A link candidate must reference an existing project_id or a candidate_project_name.
            - Limit: at most 2 link candidates and 1 new project candidate per request.
            - Do not suggest a link if the source_id already has a confirmed project link.

            Input includes: confirmed_cards, quests, active_projects, existing_link_source_ids.
            Return JSON:
            {
              "project_link_candidates": [
                {
                  "project_id": "UUID of existing project (optional if candidate_project_name is set)",
                  "candidate_project_name": "string (optional, used when matching by name)",
                  "source_type": "thinking_card | quest | verification | principle",
                  "source_id": "UUID of the source record",
                  "link_type": "evidence | blocker | decision | task | principle | risk",
                  "reason": "string: why this evidence belongs to this project",
                  "confidence": "high | medium | low",
                  "requires_user_confirmation": true
                }
              ],
              "new_project_candidates": [
                {
                  "name": "string: abstract, non-sensitive project name",
                  "goal": "string",
                  "success_criteria": "string",
                  "current_bottleneck": "string",
                  "why_this_is_long_running": "string: must explain recurring goal, blocker, decision pattern, or action standard",
                  "reason": "string: why this topic deserves a dedicated long-running project",
                  "source_ids": ["UUID of source evidence"],
                  "source_refs": [],
                  "privacy_safe_name_required": false,
                  "confidence": "high | medium | low"
                }
              ]
            }
            """

        case .generateProjectInsights:
            return """
            Review a project's confirmed evidence and generate evidence-backed insights.
            Identify progress, blocker changes, thinking changes, open questions closed, principles practiced, and next bets.
            Every insight must be grounded in specific evidence with source references.
            Do not invent insights without evidence.
            If fewer than 3 confirmed evidence items exist, return insufficient_evidence_reason with a clear explanation.

            Rules:
            - Every insight must include source_refs referencing real evidence IDs (cards, quests, verifications, principles).
            - A thinking_change insight must include before_text and after_text.
            - A blocker_change insight must include before_text and after_text.
            - Limit: at most 5 insights per request.
            - Do not repeat insights already accepted by the user.
            - Focus on patterns and changes visible across multiple evidence items.

            Input includes: project_id, project_name, project_goal, project_success_criteria, confirmed_evidence (array with id, type, title, body), accepted_insight_count.
            Return JSON:
            {
              "project_insights": [
                {
                  "project_id": "UUID of the project",
                  "insight_type": "progress | blocker_change | thinking_change | open_question_closed | principle_practiced | next_bet",
                  "title": "string: concise user-facing title",
                  "summary": "string: concise insight",
                  "before": {
                    "text": "string (required for thinking_change and blocker_change)",
                    "source_type": "thinking_card | quest | verification | principle | daily_entry",
                    "source_id": "source evidence id"
                  },
                  "after": {
                    "text": "string (required for thinking_change and blocker_change)",
                    "source_type": "thinking_card | quest | verification | principle | daily_entry",
                    "source_id": "source evidence id"
                  },
                  "source_refs": ["UUID or string id of the source evidence"]
                }
              ],
              "insufficient_evidence_reason": "string (null if evidence is sufficient)"
            }

            If insufficient evidence:
            {
              "insights": [],
              "insufficient_evidence_reason": "string: explain what evidence is missing and why it's insufficient"
            }
            """

        case .suggestProjectMerges:
            return """
            Review active projects and their confirmed evidence links to identify potential merge candidates.
            Two active projects should be merged only if they share confirmed evidence and have overlapping goals, blockers, or success criteria.
            Do not suggest merges based solely on name similarity.
            Every overlapping evidence reference must correspond to a confirmed project link for either project.

            Rules:
            - A merge candidate must have both source_project_id and target_project_id referencing existing active projects.
            - overlapping_evidence_refs must be a subset of confirmed project link source IDs for both projects.
            - Source project and target project must be different projects.
            - Limit: at most 3 merge candidates per request.
            - Require user confirmation for all merge candidates.
            - Do not automatically merge projects.

            Input includes: active_projects (array with id, name, goal, success_criteria, status), confirmed_project_links (array with project_id, source_id, source_type, link_type).
            Return JSON:
            {
              "merge_candidates": [
                {
                  "source_project_id": "UUID of the project to merge from",
                  "target_project_id": "UUID of the project to merge into",
                  "reason": "string: explain why these projects should merge (overlapping goals, blockers, success criteria, or evidence patterns)",
                  "overlapping_evidence_refs": ["UUID or string id of overlapping evidence from confirmed links"]
                }
              ]
            }
            """
        }
    }

    private static func modeGuidance(for mode: SessionMode) -> String {
        switch mode {
        case .quick:
            return "Use the shortest useful path. Prefer fewer cards, fewer questions, and one main quest."
        case .standard:
            return "Use the default full loop: clear cards, one recommended lens, three questions, quests, and a principle candidate when justified."
        case .deep:
            return "Use higher scrutiny. Include stronger opposing views, more explicit assumptions, and deeper validation needs."
        }
    }
}

final class LocalNotificationReminder: ReminderService {
    func requestPermission() async throws -> ReminderPermissionStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        @unknown default:
            return .denied
        }
    }

    func schedule(_ request: ReminderRequest) async throws {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notification = UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        try await center.add(notification)
    }

    func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
