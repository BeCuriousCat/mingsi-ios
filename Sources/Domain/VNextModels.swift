import CryptoKit
import Foundation

enum FeatureFlags {
    static var trainingCasesVNextEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        let raw = environment["MINGSI_VNEXT_CASES_ENABLED"]
            ?? environment["SIMCTL_CHILD_MINGSI_VNEXT_CASES_ENABLED"]
        guard let raw else { return true }
        return !["0", "false", "no"].contains(raw.lowercased())
    }
}

enum TrainingCaseStatus: String, Codable, CaseIterable, Identifiable {
    case pendingConfirmation = "pending_confirmation"
    case ready
    case inProgress = "in_progress"
    case awaitingVerification = "awaiting_verification"
    case completed
    case merged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pendingConfirmation: return "待确认"
        case .ready: return "待推进"
        case .inProgress: return "进行中"
        case .awaitingVerification: return "待验证"
        case .completed: return "已完成"
        case .merged: return "已合并"
        }
    }
}

enum TrainingCaseCreatedBy: String, Codable {
    case user
    case aiSuggested = "ai_suggested"
    case migration
}

struct TrainingCase: Identifiable, Hashable {
    let id: UUID
    var dailyEntryId: UUID
    var title: String
    var status: TrainingCaseStatus
    var sortOrder: Int
    var createdBy: TrainingCaseCreatedBy
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dailyEntryId: UUID,
        title: String,
        status: TrainingCaseStatus = .pendingConfirmation,
        sortOrder: Int = 0,
        createdBy: TrainingCaseCreatedBy = .user,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.dailyEntryId = dailyEntryId
        self.title = title
        self.status = status
        self.sortOrder = sortOrder
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Model interpretation, never a new observation or evidence of improvement.
struct CoachExplanation: Codable, Hashable {
    var text: String
    var sourceCardTitles: [String]
}

struct CoachQuestionTurn: Hashable {
    var questions: [ReflectionQuestion]
    var explanation: CoachExplanation?
}

struct CoachReflectionState: Codable, Hashable {
    var questions: [ReflectionQuestion]
    var reviewTurn: CoachTurnState?
    var reviewFeedback: CoachAnswerTrainingFeedback?
    var referenceSuggestion: CoachReferenceSuggestion?
    var promptRunID: UUID?
    /// Previous model context, even when feedback for an edited answer is invalid.
    var previousTurn: CoachTurnState? = nil
    var explanation: CoachExplanation? = nil
}

struct TrainingCaseSession: Identifiable, Hashable {
    let id: UUID
    var caseId: UUID
    var loopState: DailyLoopState
    var sessionMode: SessionMode
    var selectedLensId: String?
    var trainingPrescription: TrainingPrescription?
    var reflectionState: CoachReflectionState?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        loopState: DailyLoopState = .reviewCards,
        sessionMode: SessionMode = .standard,
        selectedLensId: String? = nil,
        trainingPrescription: TrainingPrescription? = nil,
        reflectionState: CoachReflectionState? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.loopState = loopState
        self.sessionMode = sessionMode
        self.selectedLensId = selectedLensId
        self.trainingPrescription = trainingPrescription
        self.reflectionState = reflectionState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum TrainingCaseRelationshipStatus: String, Codable {
    case active
    case reverted
}

struct TrainingCaseMerge: Identifiable, Hashable {
    let id: UUID
    var sourceCaseId: UUID
    var targetCaseId: UUID
    var status: TrainingCaseRelationshipStatus
    var createdAt: Date
    var revertedAt: Date?

    init(
        id: UUID = UUID(),
        sourceCaseId: UUID,
        targetCaseId: UUID,
        status: TrainingCaseRelationshipStatus = .active,
        createdAt: Date = .now,
        revertedAt: Date? = nil
    ) {
        self.id = id
        self.sourceCaseId = sourceCaseId
        self.targetCaseId = targetCaseId
        self.status = status
        self.createdAt = createdAt
        self.revertedAt = revertedAt
    }
}

enum TrainingCaseLinkKind: String, Codable, CaseIterable {
    case relatedTo = "related_to"
    case followUpOf = "follow_up_of"
}

struct TrainingCaseLink: Identifiable, Hashable {
    let id: UUID
    var sourceCaseId: UUID
    var targetCaseId: UUID
    var kind: TrainingCaseLinkKind
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceCaseId: UUID,
        targetCaseId: UUID,
        kind: TrainingCaseLinkKind,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceCaseId = sourceCaseId
        self.targetCaseId = targetCaseId
        self.kind = kind
        self.createdAt = createdAt
    }
}

struct TrainingCaseSuggestion: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var title: String
    var cardIds: [UUID]
}

struct OrganizedCaptureResult: Hashable {
    var cards: [ThinkingCard]
    var caseSuggestions: [TrainingCaseSuggestion]

    static func singleCase(cards: [ThinkingCard], title: String = "今天要想清楚的事") -> OrganizedCaptureResult {
        OrganizedCaptureResult(
            cards: cards,
            caseSuggestions: [TrainingCaseSuggestion(key: "default", title: title, cardIds: cards.map(\.id))]
        )
    }
}

struct TrainingCaseRecord: Identifiable, Hashable {
    var trainingCase: TrainingCase
    var session: TrainingCaseSession?
    var cards: [ThinkingCard]
    var quests: [Quest]
    var lensSession: LensSession?
    var verifications: [Verification]
    var growthSettlements: [GrowthSettlement] = []

    var id: UUID { trainingCase.id }
}

enum ProjectClosureReason: String, Codable, CaseIterable, Identifiable {
    case achieved
    case stopped
    case replaced
    case merged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .achieved: return "目标达成"
        case .stopped: return "主动停止"
        case .replaced: return "已被替代"
        case .merged: return "合并到其他项目"
        }
    }
}

struct ProjectClosureReview: Identifiable, Hashable {
    let id: UUID
    var projectId: UUID
    var reason: ProjectClosureReason
    var outcome: String
    var evidenceRefs: [String]
    var transferredItems: String?
    var reviewNote: String?
    var aiSummary: String?
    var principleCandidates: [ProjectClosurePrincipleCandidate]
    var previousStatus: ProjectStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectId: UUID,
        reason: ProjectClosureReason,
        outcome: String,
        evidenceRefs: [String] = [],
        transferredItems: String? = nil,
        reviewNote: String? = nil,
        aiSummary: String? = nil,
        principleCandidates: [ProjectClosurePrincipleCandidate] = [],
        previousStatus: ProjectStatus,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.projectId = projectId
        self.reason = reason
        self.outcome = outcome
        self.evidenceRefs = evidenceRefs
        self.transferredItems = transferredItems
        self.reviewNote = reviewNote
        self.aiSummary = aiSummary
        self.principleCandidates = principleCandidates
        self.previousStatus = previousStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProjectClosurePrincipleCandidate: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var summary: String
    var triggerContext: String
    var actions: [String]
    var successCriteria: String
    var exceptions: String
    var evidenceRefs: [String]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        triggerContext: String,
        actions: [String],
        successCriteria: String,
        exceptions: String,
        evidenceRefs: [String]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.triggerContext = triggerContext
        self.actions = actions
        self.successCriteria = successCriteria
        self.exceptions = exceptions
        self.evidenceRefs = evidenceRefs
    }

    func principle() -> PrincipleAsset {
        PrincipleAsset(
            title: title,
            summary: summary,
            triggerContext: triggerContext,
            actions: actions,
            successCriteria: successCriteria,
            exceptions: exceptions,
            sourceCardTitles: []
        )
    }
}

enum GrowthSettlementCategory: String, Codable, CaseIterable {
    case clarify
    case judgment
    case action

    var title: String {
        switch self {
        case .clarify: return "讲清"
        case .judgment: return "判断"
        case .action: return "行动"
        }
    }
}

struct GrowthSettlementEvidenceItem: Identifiable, Hashable, Codable {
    let id: UUID
    var category: GrowthSettlementCategory
    var metric: GrowthMetric
    var title: String
    var sourceRefs: [String]

    init(
        id: UUID = UUID(),
        category: GrowthSettlementCategory,
        metric: GrowthMetric,
        title: String,
        sourceRefs: [String]
    ) {
        self.id = id
        self.category = category
        self.metric = metric
        self.title = title
        self.sourceRefs = sourceRefs
    }
}

struct GrowthSettlement: Identifiable, Hashable {
    let id: UUID
    var verificationId: UUID
    var caseId: UUID?
    var originalJudgment: String
    var actualResult: String
    var judgmentUpdate: YesterdayJudgmentUpdate
    var calibrationAssessment: CalibrationAssessment?
    var calibrationNote: String
    var recommendation: String?
    var evidenceItems: [GrowthSettlementEvidenceItem]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        verificationId: UUID,
        caseId: UUID?,
        originalJudgment: String,
        actualResult: String,
        judgmentUpdate: YesterdayJudgmentUpdate,
        evidenceItems: [GrowthSettlementEvidenceItem],
        calibrationAssessment: CalibrationAssessment? = nil,
        calibrationNote: String = "",
        recommendation: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.verificationId = verificationId
        self.caseId = caseId
        self.originalJudgment = originalJudgment
        self.actualResult = actualResult
        self.judgmentUpdate = judgmentUpdate
        self.calibrationAssessment = calibrationAssessment
        self.calibrationNote = calibrationNote
        self.recommendation = recommendation
        self.evidenceItems = evidenceItems
        self.createdAt = createdAt
    }
}

enum GuidanceStage: String, Codable, CaseIterable {
    case capture
    case clarify
    case judgment
    case action
    case verification
}

enum GuidanceMasteryStatus: String, Codable {
    case practicing
    case mastered
}

struct GuidanceCatalogItem: Identifiable, Hashable, Codable {
    var id: String { hintId }
    var hintId: String
    var version: String
    var copy: String
    var explanation: String
    var stage: GuidanceStage
    var triggerKey: String
    var cooldownDays: Int
    var masteryEvidenceCount: Int
    var regressionTriggerKey: String
}

struct GuidanceCatalogResourcePack: Hashable, Codable {
    var version: String
    var items: [GuidanceCatalogItem]
    var signature: String?
    var signerId: String?
}

protocol GuidanceCatalogPackVerifying {
    func verify(_ pack: GuidanceCatalogResourcePack) -> Bool
}

struct UserGuidanceState: Identifiable, Hashable, Codable {
    var id: String { hintId }
    var hintId: String
    var status: GuidanceMasteryStatus
    var evidenceCount: Int
    var counterexampleCount: Int
    var lastShownAt: Date?
    var snoozedUntil: Date?
    var evidenceRefs: [String]
    var updatedAt: Date

    init(
        hintId: String,
        status: GuidanceMasteryStatus = .practicing,
        evidenceCount: Int = 0,
        counterexampleCount: Int = 0,
        lastShownAt: Date? = nil,
        snoozedUntil: Date? = nil,
        evidenceRefs: [String] = [],
        updatedAt: Date = .now
    ) {
        self.hintId = hintId
        self.status = status
        self.evidenceCount = evidenceCount
        self.counterexampleCount = counterexampleCount
        self.lastShownAt = lastShownAt
        self.snoozedUntil = snoozedUntil
        self.evidenceRefs = evidenceRefs
        self.updatedAt = updatedAt
    }
}

enum CoachTurnFeedbackValue: String, Codable, CaseIterable, Identifiable {
    case useful
    case wrongTarget = "wrong_target"
    case repetitive
    case tooAbstract = "too_abstract"
    case gaveAwayAnswer = "gave_away_answer"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .useful: return "有用"
        case .wrongTarget: return "目标不对"
        case .repetitive: return "重复"
        case .tooAbstract: return "太抽象"
        case .gaveAwayAnswer: return "直接给了答案"
        }
    }
}

/// The terminal lifecycle of an AI-produced coach turn. Only `.presented` is
/// eligible for Prompt quality feedback or version comparison.
enum CoachPromptTurnOutcome: String, Codable, CaseIterable, Identifiable {
    case responseReceived = "response_received"
    case transportFailed = "transport_failed"
    case parseRejected = "parse_rejected"
    case qualityRejected = "quality_rejected"
    case presented
    case cancelled
    case discarded

    var id: String { rawValue }
}

struct CoachPromptTurn: Identifiable, Hashable {
    var id: UUID { promptRunId }
    var promptRunId: UUID
    var caseSessionId: UUID?
    var promptId: PromptID
    var outcome: CoachPromptTurnOutcome
    /// A digest of visible generated fields. It never stores the visible text.
    var outputFingerprint: String?
    var detail: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        promptRunId: UUID,
        caseSessionId: UUID? = nil,
        promptId: PromptID,
        outcome: CoachPromptTurnOutcome,
        outputFingerprint: String? = nil,
        detail: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.promptRunId = promptRunId
        self.caseSessionId = caseSessionId
        self.promptId = promptId
        self.outcome = outcome
        self.outputFingerprint = outputFingerprint
        self.detail = detail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CoachPromptQualityRecord: Hashable {
    var turn: CoachPromptTurn
    var run: PromptRun
    var feedback: [CoachTurnFeedback]
}

struct CoachPromptQualitySummary: Identifiable, Hashable {
    var promptId: String
    var promptVersion: String
    var contextPolicyVersion: String
    var modelProvider: String
    var modelName: String
    var sessionMode: String
    var presentedCount: Int
    var transportFailedCount: Int
    var parseRejectedCount: Int
    var qualityRejectedCount: Int
    var cancelledCount: Int
    var discardedCount: Int
    var usefulCount: Int
    var wrongTargetCount: Int
    var repetitiveCount: Int
    var tooAbstractCount: Int
    var gaveAwayAnswerCount: Int
    var latestUpdatedAt: Date

    var id: String {
        [promptId, promptVersion, contextPolicyVersion, modelProvider, modelName, sessionMode]
            .joined(separator: "|")
    }

    var feedbackCount: Int {
        usefulCount + wrongTargetCount + repetitiveCount + tooAbstractCount + gaveAwayAnswerCount
    }

    /// Share of presented turns that received at least one user rating. A
    /// missing rating is an unknown quality signal, not a positive result.
    var feedbackCoverageRate: Double {
        guard presentedCount > 0 else { return 0 }
        return Double(feedbackCount) / Double(presentedCount)
    }

    var negativeFeedbackCount: Int {
        wrongTargetCount + repetitiveCount + tooAbstractCount + gaveAwayAnswerCount
    }

    var negativeFeedbackRate: Double {
        guard presentedCount > 0 else { return 0 }
        return Double(negativeFeedbackCount) / Double(presentedCount)
    }

    /// Complaint rate among rated turns. Optional keeps an unrated summary
    /// from being presented as a misleading 0% complaint rate.
    var ratedNegativeFeedbackRate: Double? {
        guard feedbackCount > 0 else { return nil }
        return Double(negativeFeedbackCount) / Double(feedbackCount)
    }

    static func summaries(for records: [CoachPromptQualityRecord]) -> [CoachPromptQualitySummary] {
        let grouped = Dictionary(grouping: records) { record in
            CoachPromptQualityKey(run: record.run)
        }
        return grouped.map { key, records in
            CoachPromptQualitySummary(key: key, records: records)
        }
        .sorted { lhs, rhs in
            if lhs.latestUpdatedAt != rhs.latestUpdatedAt {
                return lhs.latestUpdatedAt > rhs.latestUpdatedAt
            }
            return lhs.id < rhs.id
        }
    }

    private init(key: CoachPromptQualityKey, records: [CoachPromptQualityRecord]) {
        promptId = key.promptId
        promptVersion = key.promptVersion
        contextPolicyVersion = key.contextPolicyVersion
        modelProvider = key.modelProvider
        modelName = key.modelName
        sessionMode = key.sessionMode
        presentedCount = records.count(where: { $0.turn.outcome == .presented })
        transportFailedCount = records.count(where: { $0.turn.outcome == .transportFailed })
        parseRejectedCount = records.count(where: { $0.turn.outcome == .parseRejected })
        qualityRejectedCount = records.count(where: { $0.turn.outcome == .qualityRejected })
        cancelledCount = records.count(where: { $0.turn.outcome == .cancelled })
        discardedCount = records.count(where: { $0.turn.outcome == .discarded })

        let feedbackByRun = Dictionary(
            uniqueKeysWithValues: records
                .filter { $0.turn.outcome == .presented }
                .map { record in
                    (record.turn.promptRunId, Set(record.feedback.map(\.value)))
                }
        )
        usefulCount = feedbackByRun.values.count(where: { $0.contains(.useful) })
        wrongTargetCount = feedbackByRun.values.count(where: { $0.contains(.wrongTarget) })
        repetitiveCount = feedbackByRun.values.count(where: { $0.contains(.repetitive) })
        tooAbstractCount = feedbackByRun.values.count(where: { $0.contains(.tooAbstract) })
        gaveAwayAnswerCount = feedbackByRun.values.count(where: { $0.contains(.gaveAwayAnswer) })
        latestUpdatedAt = records.map(\.turn.updatedAt).max() ?? .distantPast
    }
}

private struct CoachPromptQualityKey: Hashable {
    var promptId: String
    var promptVersion: String
    var contextPolicyVersion: String
    var modelProvider: String
    var modelName: String
    var sessionMode: String

    init(run: PromptRun) {
        promptId = run.promptId
        promptVersion = run.promptVersion
        contextPolicyVersion = run.contextPolicyVersion
        modelProvider = run.modelProvider
        modelName = run.modelName
        sessionMode = run.sessionMode
    }
}

enum CoachPromptOutputFingerprint {
    static func questionTurn(_ questions: [ReflectionQuestion], explanation: CoachExplanation?) -> String {
        guard let explanation else { return self.questions(questions) }
        return digest([self.questions(questions), explanation.text,
            explanation.sourceCardTitles.joined(separator: "\u{1F}")].joined(separator: "\u{1E}"))
    }

    static func questions(_ questions: [ReflectionQuestion]) -> String {
        digest(questions.map { question in
            [
                question.question,
                question.whyItMatters,
                question.whyNow ?? "",
                question.expectedUpdate ?? "",
                question.proceedWhen ?? "",
                question.evidenceGapType?.rawValue ?? "",
                question.answerUse?.rawValue ?? "",
                question.lensMove?.rawValue ?? "",
                question.sourceCardTitles.joined(separator: "\u{1F}") ,
                question.calibrationTarget ?? ""
            ].joined(separator: "\u{1E}")
        }.joined(separator: "\u{1D}"))
    }

    static func quests(_ quests: [Quest]) -> String {
        digest(quests.map { quest in
            [
                quest.type.rawValue,
                quest.title,
                quest.whyItMatters,
                quest.completionCriteria,
                quest.expectedResistance,
                quest.reflectionQuestion,
                quest.calibrationTarget ?? "",
                quest.lensMove?.rawValue ?? "",
                quest.sourceCardTitles.joined(separator: "\u{1F}")
            ].joined(separator: "\u{1E}")
        }.joined(separator: "\u{1D}"))
    }

    static func answerReview(
        questions: [ReflectionQuestion],
        turn: CoachTurnState,
        feedback: CoachAnswerTrainingFeedback,
        referenceSuggestion: CoachReferenceSuggestion?
    ) -> String {
        let answers = questions.map { "\($0.id.uuidString):\($0.answer)" }.joined(separator: "\u{1D}")
        return digest([
            answers,
            turn.readiness.rawValue,
            turn.recommendedMove.rawValue,
            turn.reason,
            feedback.coachCritiqueLine,
            feedback.missingLine,
            feedback.nextRepairQuestion,
            feedback.userBoundary?.rawValue ?? "continue",
            feedback.proceedLine,
            feedback.experienceReplayPrompt,
            feedback.judgmentSentencePrompt,
            referenceSuggestion?.guidance ?? ""
        ].joined(separator: "\u{1E}"))
    }

    private static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct CoachTurnFeedback: Identifiable, Hashable {
    let id: UUID
    var caseSessionId: UUID
    var promptRunId: UUID?
    var coachObservationId: String?
    var value: CoachTurnFeedbackValue
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        caseSessionId: UUID,
        promptRunId: UUID? = nil,
        coachObservationId: String? = nil,
        value: CoachTurnFeedbackValue,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.caseSessionId = caseSessionId
        self.promptRunId = promptRunId
        self.coachObservationId = coachObservationId
        self.value = value
        self.note = note
        self.createdAt = createdAt
    }
}

enum BuiltinGuidanceCatalog {
    static let version = "guidance.v1"

    static let items: [GuidanceCatalogItem] = [
        GuidanceCatalogItem(
            hintId: "action.completion_criteria",
            version: version,
            copy: "开始前，先写清怎样算完成。",
            explanation: "完成标准越具体，明天越容易用真实结果校准判断。",
            stage: .action,
            triggerKey: "missing_completion_criteria",
            cooldownDays: 1,
            masteryEvidenceCount: 2,
            regressionTriggerKey: "completion_criteria_regression"
        ),
        GuidanceCatalogItem(
            hintId: "judgment.observable_evidence",
            version: version,
            copy: "先写下支持或推翻判断的可观察事实。",
            explanation: "把事实与解释分开，能减少只凭感受确认原判断。",
            stage: .judgment,
            triggerKey: "missing_observable_evidence",
            cooldownDays: 1,
            masteryEvidenceCount: 2,
            regressionTriggerKey: "observable_evidence_regression"
        ),
        GuidanceCatalogItem(
            hintId: "verification.result_not_completion",
            version: version,
            copy: "完成不等于有效，记录这一步实际改变了什么。",
            explanation: "验证的目标是更新判断，而不只是确认任务做完。",
            stage: .verification,
            triggerKey: "completion_without_result",
            cooldownDays: 2,
            masteryEvidenceCount: 2,
            regressionTriggerKey: "result_evidence_regression"
        )
    ]
}

struct WeeklyGuidanceReviewSelection: Hashable, Codable {
    var trainingFocus: String
    var hintIds: [String]
    var evidenceRefs: [String]
}

struct WeeklyGuidanceReviewRecord: Hashable, Codable {
    var weekKey: String
    var selection: WeeklyGuidanceReviewSelection
    var generatedAt: Date

    init(
        weekKey: String,
        selection: WeeklyGuidanceReviewSelection,
        generatedAt: Date = .now
    ) {
        self.weekKey = weekKey
        self.selection = selection
        self.generatedAt = generatedAt
    }
}

struct WeeklyGuidanceReviewReadiness: Equatable {
    let recentVerificationCount: Int
    let coveredDayCount: Int

    var isEligible: Bool {
        recentVerificationCount >= 3 && coveredDayCount >= 2
    }

    var remainingVerificationCount: Int {
        max(0, 3 - recentVerificationCount)
    }

    var remainingDayCount: Int {
        max(0, 2 - coveredDayCount)
    }
}

struct WeeklyGuidanceReviewPolicy {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func weekKey(for date: Date = .now) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? calendar.component(.year, from: date)
        let week = components.weekOfYear ?? 1
        return String(format: "%04d-W%02d", year, week)
    }

    func readiness(
        verifications: [Verification],
        now: Date = .now
    ) -> WeeklyGuidanceReviewReadiness {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recent = verifications.filter { $0.createdAt >= cutoff && $0.createdAt <= now }
        let days = Set(recent.map { calendar.startOfDay(for: $0.createdAt) })
        return WeeklyGuidanceReviewReadiness(
            recentVerificationCount: recent.count,
            coveredDayCount: days.count
        )
    }

    func isEligible(verifications: [Verification], now: Date = .now) -> Bool {
        readiness(verifications: verifications, now: now).isEligible
    }

    func validate(
        _ selection: WeeklyGuidanceReviewSelection,
        catalog: [GuidanceCatalogItem] = BuiltinGuidanceCatalog.items,
        allowedEvidenceRefs: Set<String>
    ) -> Bool {
        let allowedHintIds = Set(catalog.map(\.hintId))
        return !selection.trainingFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selection.hintIds.isEmpty &&
            Set(selection.hintIds).isSubset(of: allowedHintIds) &&
            !selection.evidenceRefs.isEmpty &&
            Set(selection.evidenceRefs).isSubset(of: allowedEvidenceRefs)
    }
}
