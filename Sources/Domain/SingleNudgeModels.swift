import Foundation

enum SingleNudgeLifecycle: String, Codable, Hashable, CaseIterable {
    case draft
    case generatingQuestion
    case questionPresented
    case beforeRecorded
    case afterRecorded
    case generatingReview
    case receiptPresented
    case feedbackRecorded
    case completed
}

enum SingleNudgeFeedback: String, Codable, Hashable, CaseIterable {
    case helpful
    case neutral
    case notHelpful
}

enum SingleNudgeResult: String, Codable, Hashable, CaseIterable {
    case pending
    case completed
    case skipped
}

/// Describes why this round exists without exposing the storage graph to the
/// person using the product.
enum SingleNudgeContinuationKind: String, Codable, Hashable, CaseIterable {
    case initial
    case alternateAngle
    case deeper
}

struct SingleNudgeReview: Codable, Hashable {
    var diagnosis: String
    var cognitiveShift: String?
    var thinkingAction: String?
    var unresolvedUncertainty: String?
    var transitionToVerification: Bool
}

typealias SingleNudgeLifecycleState = SingleNudgeLifecycle
typealias SingleNudgeFeedbackRating = SingleNudgeFeedback

struct SingleNudgeSession: Codable, Hashable, Identifiable {
    var id: UUID
    var dayKey: String
    var input: String
    var question: String?
    var diagnosis: String?
    var before: String?
    var after: String?
    var cognitiveShift: String?
    var thinkingAction: String?
    var unresolvedUncertainty: String?
    var transitionToVerification: Bool?
    var promptRunID: UUID?
    var reviewPromptRunID: UUID?
    /// A nudge round is append-only once a child is created. These links retain
    /// the exact conversation material used by follow-up model calls.
    var parentSessionID: UUID?
    var rootSessionID: UUID
    var continuationKind: SingleNudgeContinuationKind
    var sourceRefs: [String]
    var reviewSourceRefs: [String]
    var lifecycle: SingleNudgeLifecycle
    var result: SingleNudgeResult
    var feedback: SingleNudgeFeedback?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(), dayKey: String, input: String = "", question: String? = nil, diagnosis: String? = nil,
        before: String? = nil, after: String? = nil,
        cognitiveShift: String? = nil, thinkingAction: String? = nil, unresolvedUncertainty: String? = nil,
        transitionToVerification: Bool? = nil, promptRunID: UUID? = nil, reviewPromptRunID: UUID? = nil,
        parentSessionID: UUID? = nil, rootSessionID: UUID? = nil,
        continuationKind: SingleNudgeContinuationKind = .initial,
        sourceRefs: [String] = [], reviewSourceRefs: [String] = [],
        lifecycle: SingleNudgeLifecycle = .draft, result: SingleNudgeResult = .pending,
        feedback: SingleNudgeFeedback? = nil, createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id; self.dayKey = dayKey; self.input = input; self.question = question; self.diagnosis = diagnosis
        self.before = before; self.after = after; self.lifecycle = lifecycle; self.result = result
        self.cognitiveShift = cognitiveShift; self.thinkingAction = thinkingAction; self.unresolvedUncertainty = unresolvedUncertainty
        self.transitionToVerification = transitionToVerification; self.promptRunID = promptRunID; self.reviewPromptRunID = reviewPromptRunID
        self.parentSessionID = parentSessionID; self.rootSessionID = rootSessionID ?? id; self.continuationKind = continuationKind
        self.sourceRefs = sourceRefs; self.reviewSourceRefs = reviewSourceRefs
        self.feedback = feedback; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
