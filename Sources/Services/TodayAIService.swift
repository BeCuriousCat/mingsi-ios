import Foundation

struct VerifyQuestInput: Hashable {
    var sourceRecordIDs: [String] = []
    var questTitle: String
    var completionCriteria: String
    var targetJudgment: String? = nil
    var trainingPrinciple: PromptContextPayload.VerificationTrainingPrincipleContext? = nil
    var completion: String
    var valueRating: String
    var rawText: String
}

struct VerifyQuestResult: Hashable {
    var calibrationNote: String
    var likelyIssue: String?
    var recommendation: String?
    var expectedPrinciplePracticeAssessment: String? = nil
}

struct TodayAIContext: Hashable {
    var draft: DailyEntryDraft
    var confirmedCards: [ThinkingCard] = []
    var questions: [ReflectionQuestion] = []
    var quests: [Quest] = []
    var principles: [PrincipleAsset] = []
    var principleRecallFeedback: [PrincipleRecallFeedback] = []
    var selectedLensItem: LensCatalogItem?
    var lensFeedback: [PromptContextPayload.LensFeedbackContext] = []
    var trainingPrescription: TrainingPrescription? = nil
    var coachDiagnosis: CoachDiagnosis? = nil
    var coachTurnState: CoachTurnState? = nil
}

final class TodayAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient
    private let parser: TodayAIResponseParser
    private let contextAssembler: ContextAssembler

    init(
        promptProvider: PromptProvider,
        llmClient: LLMClient,
        parser: TodayAIResponseParser = TodayAIResponseParser(),
        contextAssembler: ContextAssembler = DefaultContextAssembler()
    ) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
        self.parser = parser
        self.contextAssembler = contextAssembler
    }

    func organizeCards(for context: TodayAIContext) async throws -> [ThinkingCard] {
        let request = request(
            promptID: .organizeCards,
            context: context,
            directives: organizeCardsDirectives()
        )
        let data = try await llmClient.complete(request)
        return try parser.parseCards(from: data)
    }

    func streamOrganizedCards(
        for context: TodayAIContext,
        onUpdate: @escaping ([StreamingCardDraft]) async -> Void
    ) async throws -> [ThinkingCard] {
        guard let streamingClient = llmClient as? StreamingLLMClient else {
            return try await organizeCards(for: context)
        }

        let request = request(
            promptID: .organizeCards,
            context: context,
            directives: organizeCardsDirectives(streamProtocol: "MINGSI_STREAM_V1")
        )
        let assembler = XMLStreamingCardAssembler()

        for try await event in streamingClient.stream(request) {
            switch event {
            case .token(let text):
                let events = assembler.append(text)
                for event in events {
                    if case .updated(let cards) = event {
                        await onUpdate(cards)
                    }
                }
            case .completed:
                break
            }
        }

        for event in assembler.finish() {
            if case .updated(let cards) = event {
                await onUpdate(cards)
            }
        }

        let cards = assembler.currentCards.compactMap(\.domainCard)
        guard !cards.isEmpty else { throw TodayAIParsingError.emptyResult }
        return cards
    }

    func generateQuestions(for context: TodayAIContext) async throws -> [ReflectionQuestion] {
        let request = request(
            promptID: .generateQuestions,
            context: context
        )
        let data = try await llmClient.complete(request)
        let questions = try parser.parseQuestions(from: data)
        let visiblePayload = request.contextPayload
        try validateCoachingQuality(
            PromptCoachingQualityPolicy.evaluateQuestions(
                questions,
                selectedLens: effectiveTrainingLens(forPromptPayload: visiblePayload, fallback: context),
                lensFeedback: visiblePayload?.lensFeedback ?? [],
                primaryTrainingDimension: visiblePayload?.trainingPrescription?.primaryTrainingDimension,
                baselineTrainingDimensions: visiblePayload?.trainingPrescription?.baselineTrainingDimensions ?? [],
                coachTurnState: coachTurnState(from: visiblePayload)
            )
        )
        return questions
    }

    func generateQuests(for context: TodayAIContext) async throws -> [Quest] {
        let request = request(
            promptID: .generateQuests,
            context: context
        )
        let data = try await llmClient.complete(request)
        let quests = try parser.parseQuests(from: data)
        let visiblePayload = request.contextPayload
        try validateCoachingQuality(
            PromptCoachingQualityPolicy.evaluateQuests(
                quests,
                selectedLens: effectiveTrainingLens(forPromptPayload: visiblePayload, fallback: context),
                coachTurnState: coachTurnState(from: visiblePayload)
            )
        )
        return quests
    }

    func extractPrinciple(for context: TodayAIContext) async throws -> [PrincipleAsset] {
        let request = request(
            promptID: .extractPrinciple,
            context: context
        )
        let data = try await llmClient.complete(request)
        let principles = try parser.parsePrinciples(from: data)
        try validateCoachingQuality(PromptCoachingQualityPolicy.evaluatePrinciples(principles))
        return principles
    }

    func verifyQuest(input: VerifyQuestInput, sessionMode: SessionMode) async throws -> VerifyQuestResult {
        let template = promptProvider.template(for: .verifyQuest, mode: sessionMode)
        let contextPayload = PromptContextPayload(
            currentInput: .init(rawText: input.rawText),
            userChoice: .init(sessionMode: sessionMode.rawValue),
            verification: .init(
                questTitle: input.questTitle,
                completionCriteria: input.completionCriteria,
                targetJudgment: input.targetJudgment,
                trainingPrinciple: input.trainingPrinciple,
                completion: input.completion,
                valueRating: input.valueRating
            )
        )
        let request = LLMRequest(
            prompt: template,
            inputSummary: "quest=\(input.questTitle); completion=\(input.completion); rating=\(input.valueRating)",
            contextPayload: contextPayload,
            sourceRecordIDs: input.sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: input.sourceRecordIDs
        )
        let data = try await llmClient.complete(request)
        let result = try parser.parseVerification(from: data)
        try validateCoachingQuality(
            PromptCoachingQualityPolicy.evaluateVerification(
                result,
                targetJudgment: input.targetJudgment,
                hasTrainingPrinciple: input.trainingPrinciple != nil
            )
        )
        return result
    }

    private func validateCoachingQuality(_ issues: [PromptCoachingQualityIssue]) throws {
        guard !issues.isEmpty else { return }
        let reasons = Array(Set(issues.map { $0.reason.rawValue })).sorted()
        throw TodayAIParsingError.qualityGateFailed(reasons)
    }

    private func effectiveTrainingLens(for context: TodayAIContext) -> ThinkingLens? {
        if let finalLensId = context.trainingPrescription?.finalLensId,
           let prescribedLens = ThinkingLens(rawValue: finalLensId) {
            return prescribedLens
        }
        return context.draft.selectedLens
    }

    private func effectiveTrainingLens(
        forPromptPayload payload: PromptContextPayload?,
        fallback context: TodayAIContext
    ) -> ThinkingLens? {
        guard let payload else { return effectiveTrainingLens(for: context) }
        if let finalLensId = payload.trainingPrescription?.finalLensId,
           let prescribedLens = ThinkingLens(rawValue: finalLensId) {
            return prescribedLens
        }
        return payload.selectedLens
    }

    private func coachTurnState(from payload: PromptContextPayload?) -> CoachTurnState? {
        guard let turn = payload?.coachTurnState else { return nil }
        return CoachTurnState(
            phase: turn.phase,
            readiness: turn.readiness,
            recommendedMove: turn.recommendedMove,
            reason: turn.reason,
            openEvidenceGaps: turn.openEvidenceGaps,
            baselineChecks: turn.baselineChecks,
            decisionSource: turn.decisionSource,
            policyVersion: turn.policyVersion,
            turnSummary: turn.turnSummary
        )
    }

    private func request(
        promptID: PromptID,
        context: TodayAIContext,
        directives: PromptContextPayload.PromptDirectives = .init()
    ) -> LLMRequest {
        let promptContext = contextAssembler.assemble(promptID: promptID, context: context)
        let contextPayload = promptContext.contextPayload.applyingDirectives(directives)
        return LLMRequest(
            prompt: promptProvider.template(for: promptID, mode: context.draft.sessionMode),
            inputSummary: promptContext.inputSummary,
            contextPayload: contextPayload,
            sourceRecordIDs: promptContext.sourceRecordIDs,
            contextVersion: promptContext.version,
            contextRecordIDs: promptContext.contextRecordIDs
        )
    }

    private func organizeCardsDirectives(streamProtocol: String? = nil) -> PromptContextPayload.PromptDirectives {
        .init(
            privacyRules: "Avoid repeating unnecessary confidential specifics. Mark sensitive content defensively.",
            streamProtocol: streamProtocol
        )
    }
}

struct PromptContext: Hashable {
    var version: Int = 1
    var inputSummary: String
    var contextPayload: PromptContextPayload
    var sourceRecordIDs: [String]
    var contextRecordIDs: [String]
}

protocol ContextAssembler {
    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext
}

protocol PrincipleRetriever {
    func retrievePrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [RetrievedPrinciple]
    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [PrincipleAsset]
}

struct RetrievedPrinciple: Hashable {
    var principle: PrincipleAsset
    var score: Int
    var retrievalReason: String
    var retrievalSignal: String
    var policyVersion: String
}

extension PrincipleRetriever {
    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [PrincipleAsset] {
        retrievePrinciples(for: context, promptID: promptID, limit: limit).map(\.principle)
    }
}

struct LocalPrincipleRetriever: PrincipleRetriever {
    static let policyVersion = "principle-retrieval.local-keyword-feedback.v3"

    private let minimumScore = 2
    private let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "before", "by", "did", "do", "does", "for", "from",
        "has", "have", "if", "in", "is", "it", "its", "not", "of", "on", "one", "or", "our", "the",
        "their", "then", "this", "to", "was", "were", "what", "when", "where", "which", "who", "why",
        "will", "with", "write", "action", "actions", "criteria", "discussion", "ended", "next",
        "明日", "任务", "今天", "昨天", "问题", "行动", "标准", "完成", "需要", "进行", "一个", "这个"
    ]

    func retrievePrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int = 3) -> [RetrievedPrinciple] {
        guard promptID != .organizeCards else { return [] }

        let terms = searchTerms(from: context)
        let scored = context.principles
            .filter { $0.status == .active }
            .map { principle in
                let baseScore = score(principle: principle, terms: terms)
                let retrievalSignal = retrievalSignal(for: principle, terms: terms)
                let penalty = recallFeedbackPenalty(
                    for: principle.id,
                    retrievalSignal: retrievalSignal,
                    feedback: context.principleRecallFeedback
                )
                return (principle, retrievalSignal, baseScore, max(0, baseScore - penalty), penalty)
            }
            .filter { $0.3 >= minimumScore }
            .sorted { lhs, rhs in
                if lhs.3 == rhs.3 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.3 > rhs.3
            }
            .prefix(limit)
            .map { principle, retrievalSignal, baseScore, adjustedScore, penalty in
                return RetrievedPrinciple(
                    principle: principle,
                    score: adjustedScore,
                    retrievalReason: retrievalReason(
                        for: principle,
                        terms: terms,
                        baseScore: baseScore,
                        adjustedScore: adjustedScore,
                        feedbackPenalty: penalty
                    ),
                    retrievalSignal: retrievalSignal,
                    policyVersion: Self.policyVersion
                )
            }

        return Array(scored)
    }

    private func searchTerms(from context: TodayAIContext) -> [String] {
        let text = [
            context.draft.rawText,
            context.draft.selectedLens?.title ?? "",
            context.confirmedCards.map { "\($0.title) \($0.body)" }.joined(separator: " "),
            context.questions.map { "\($0.question) \($0.answer)" }.joined(separator: " "),
            context.quests.map { "\($0.title) \($0.whyItMatters) \($0.completionCriteria)" }.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        return text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { term in
                term.count >= 3 && !stopWords.contains(term)
            }
    }

    private func score(principle: PrincipleAsset, terms: [String]) -> Int {
        guard !terms.isEmpty else { return 0 }
        let uniqueTerms = Set(terms)
        let highSignalText = [
            principle.title,
            principle.triggerContext
        ].joined(separator: " ").lowercased()
        let fullText = [
            highSignalText,
            principle.summary,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ].joined(separator: " ").lowercased()

        return uniqueTerms.reduce(0) { partial, term in
            if highSignalText.contains(term) {
                return partial + 2
            }
            if fullText.contains(term) {
                return partial + 1
            }
            return partial
        }
    }

    private func recallFeedbackPenalty(
        for principleId: UUID,
        retrievalSignal: String,
        feedback: [PrincipleRecallFeedback]
    ) -> Int {
        let normalizedRetrievalSignal = normalizedSignal(retrievalSignal)
        return feedback
            .filter { $0.principleId == principleId }
            .reduce(0) { partial, event in
                switch event.feedback {
                case .helpful:
                    return partial
                case .notApplicable, .misrecalled:
                    let eventSignal = normalizedSignal(event.retrievalSignal)
                    guard eventSignal.isEmpty || eventSignal == normalizedRetrievalSignal else {
                        return partial
                    }
                    return partial + 1
                }
            }
    }

    private func normalizedSignal(_ signal: String) -> String {
        signal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func retrievalReason(
        for principle: PrincipleAsset,
        terms: [String],
        baseScore: Int,
        adjustedScore: Int,
        feedbackPenalty: Int
    ) -> String {
        let principleText = [
            principle.title,
            principle.summary,
            principle.triggerContext,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ].joined(separator: " ").lowercased()
        let matchedTerms = Array(Set(terms))
            .sorted()
            .filter { principleText.contains($0) }
            .prefix(4)
        let matchedText = matchedTerms.isEmpty ? "keyword overlap" : matchedTerms.joined(separator: ", ")
        var reason = "Matched \(matchedText) with \(principle.title) using local keyword policy; score=\(adjustedScore)."
        if feedbackPenalty > 0 {
            reason += " Applied negative recall feedback penalty=\(feedbackPenalty) from base score=\(baseScore)."
        }
        return reason
    }

    private func retrievalSignal(for principle: PrincipleAsset, terms: [String]) -> String {
        let termSet = Set(terms)
        let candidateFields = [
            principle.triggerContext,
            principle.title,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ]

        for field in candidateFields {
            let signal = field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let signalTerms = signal
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
            guard !signal.isEmpty, !signalTerms.isEmpty else { continue }
            if signalTerms.allSatisfy({ termSet.contains($0) }) {
                return signal
            }
        }

        let principleText = [
            principle.title,
            principle.summary,
            principle.triggerContext,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ].joined(separator: " ").lowercased()
        let matchedTerms = Array(Set(terms))
            .sorted()
            .filter { principleText.contains($0) }
            .prefix(4)
        return matchedTerms.isEmpty ? "keyword overlap" : matchedTerms.joined(separator: " ")
    }
}

struct CoachContextMemorySelection: Hashable {
    var retrievedPrinciples: [RetrievedPrinciple] = []
    var existingPrinciples: [PrincipleAsset] = []
    var lensFeedback: [PromptContextPayload.LensFeedbackContext] = []
    var trainingPrescription: TrainingPrescription?
    var coachDiagnosis: CoachDiagnosis?
    var coachTurnState: CoachTurnState?
    var coachTeachingPlan: CoachTeachingPlan?

    var relevantPrinciples: [PrincipleAsset] {
        retrievedPrinciples.map(\.principle)
    }
}

struct CoachContextMemoryPolicy {
    static let policyVersion = "coach-context-memory.local-v1"

    var principleLimit = 3
    var lensFeedbackLimit = 2

    func selectMemory(
        promptID: PromptID,
        context: TodayAIContext,
        principleRetriever: PrincipleRetriever
    ) -> CoachContextMemorySelection {
        guard allowsCoachMemory(promptID) else {
            return CoachContextMemorySelection()
        }

        let retrievedPrinciples = allowsPrincipleReferences(promptID)
            ? principleRetriever.retrievePrinciples(
                for: context,
                promptID: promptID,
                limit: principleLimit
            )
            : []
        let existingPrinciples = promptID == .extractPrinciple ? context.principles : []

        return CoachContextMemorySelection(
            retrievedPrinciples: retrievedPrinciples,
            existingPrinciples: existingPrinciples,
            lensFeedback: lensFeedback(
                for: promptID,
                context: context
            ),
            trainingPrescription: allowsTrainingPrescription(promptID) ? context.trainingPrescription : nil,
            coachDiagnosis: allowsCoachTurn(promptID) ? context.coachDiagnosis : nil,
            coachTurnState: allowsCoachTurn(promptID) ? context.coachTurnState : nil,
            coachTeachingPlan: coachTeachingPlan(
                for: promptID,
                context: context
            )
        )
    }

    private func coachTeachingPlan(
        for promptID: PromptID,
        context: TodayAIContext
    ) -> CoachTeachingPlan? {
        guard allowsCoachTurn(promptID),
              let turn = context.coachTurnState else {
            return nil
        }
        return CoachTeachingPolicy().makePlan(
            turn: turn,
            prescription: context.trainingPrescription
        )
    }

    func lensFeedback(
        for promptID: PromptID,
        context: TodayAIContext
    ) -> [PromptContextPayload.LensFeedbackContext] {
        guard allowsLensFeedback(promptID) else { return [] }
        let finalLensId = context.trainingPrescription?.finalLensId
            ?? context.selectedLensItem?.lensId
            ?? context.draft.selectedLens?.rawValue
        guard let finalLensId else { return [] }

        return Array(
            context.lensFeedback
                .filter { $0.lensId == finalLensId }
                .prefix(lensFeedbackLimit)
        )
    }

    private func allowsCoachMemory(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .generateQuestions, .generateQuests, .extractPrinciple:
            return true
        case .organizeCards, .recommendLenses, .verifyQuest, .suggestProjectLinks,
             .generateProjectInsights, .suggestProjectMerges, .weeklyCalibration, .monthlyGrowth:
            return false
        }
    }

    private func allowsPrincipleReferences(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .generateQuestions, .generateQuests:
            return true
        case .extractPrinciple, .organizeCards, .recommendLenses, .verifyQuest,
             .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges,
             .weeklyCalibration, .monthlyGrowth:
            return false
        }
    }

    private func allowsLensFeedback(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .generateQuestions, .generateQuests:
            return true
        case .organizeCards, .recommendLenses, .verifyQuest, .extractPrinciple,
             .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges,
             .weeklyCalibration, .monthlyGrowth:
            return false
        }
    }

    private func allowsTrainingPrescription(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .generateQuestions, .generateQuests, .extractPrinciple:
            return true
        case .organizeCards, .recommendLenses, .verifyQuest, .suggestProjectLinks,
             .generateProjectInsights, .suggestProjectMerges, .weeklyCalibration, .monthlyGrowth:
            return false
        }
    }

    private func allowsCoachTurn(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .generateQuestions, .generateQuests:
            return true
        case .organizeCards, .recommendLenses, .verifyQuest, .extractPrinciple,
             .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges,
             .weeklyCalibration, .monthlyGrowth:
            return false
        }
    }
}

struct DefaultContextAssembler: ContextAssembler {
    private let principleRetriever: PrincipleRetriever
    private let memoryPolicy: CoachContextMemoryPolicy

    init(
        principleRetriever: PrincipleRetriever = LocalPrincipleRetriever(),
        memoryPolicy: CoachContextMemoryPolicy = CoachContextMemoryPolicy()
    ) {
        self.principleRetriever = principleRetriever
        self.memoryPolicy = memoryPolicy
    }

    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext {
        let memory = memoryPolicy.selectMemory(
            promptID: promptID,
            context: context,
            principleRetriever: principleRetriever
        )
        let relevantPrinciples = memory.relevantPrinciples
        let contextPayload = structuredPayload(
            for: context,
            memory: memory,
            directives: .init(
                principleUsageRule: !relevantPrinciples.isEmpty
                    ? "Use accepted principles as experience replay: ask whether today's case should reproduce, adapt, or reject the prior behavior. Do not force today's situation to fit them."
                    : nil,
                coachDiagnosisRule: memory.coachDiagnosis != nil
                    ? "Use coachDiagnosis as a coach plan, not source evidence. If readiness is not_ready, ask clarification or evidence-gap questions before converging. Treat user override as a user choice to proceed, not proof that the coach diagnosis was wrong."
                    : nil,
                coachTurnRule: memory.coachTurnState != nil
                    ? "Use coachTurnState as the stateful coach turn plan. If readiness is not_ready, ask clarification or evidence-gap questions before converging. If readiness is ready, form a verifiable action. Treat user override as permission to proceed, not proof that the coach was wrong."
                    : nil,
                coachTeachingRule: memory.coachTeachingPlan != nil
                    ? "Use coachTeachingPlan as the teaching frame. Start from the missing thinking move, train the named target, keep why_not_answer visible, use repairQuestion when the user's answer still leaves the gap open, ask whether prior experience should be reproduced/adapted/rejected, and only proceed when the proceed standard is satisfied."
                    : nil
            )
        )

        return PromptContext(
            version: 1,
            inputSummary: inputSummary(for: context, relevantPrinciples: relevantPrinciples),
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs(for: context),
            contextRecordIDs: contextRecordIDs(
                for: context,
                relevantPrinciples: relevantPrinciples,
                existingPrinciples: memory.existingPrinciples
            )
        )
    }

    private func structuredPayload(
        for context: TodayAIContext,
        memory: CoachContextMemorySelection,
        directives: PromptContextPayload.PromptDirectives
    ) -> PromptContextPayload {
        PromptContextPayload(
            currentInput: .init(
                dailyEntryId: context.draft.id.uuidString,
                rawText: context.draft.rawText
            ),
            userChoice: .init(
                sessionMode: context.draft.sessionMode.rawValue,
                selectedLens: selectedLensId(for: context),
                lensCatalog: selectedLensItem(for: context).map { item in
                    return .init(
                        localId: item.lensId,
                        promptId: item.promptId,
                        version: item.version,
                        title: item.title,
                        methodLine: item.methodLine,
                        promptGuidance: item.promptGuidance,
                        purpose: item.purpose,
                        questionStrategy: item.questionStrategy,
                        taskSelectionRule: item.taskSelectionRule,
                        applicability: item.applicability,
                        disableConditions: item.disableConditions,
                        uiMetadata: .init(
                            symbolName: item.uiMetadata.symbolName,
                            accentRole: item.uiMetadata.accentRole,
                            methodIndex: item.uiMetadata.methodIndex
                        ),
                        sourceKind: item.sourceKind,
                        packId: item.packId,
                        packVersion: item.packVersion,
                        packDisplayName: item.packDisplayName
                    )
                }
            ),
            cards: context.confirmedCards.map { card in
                .init(
                    id: card.id.uuidString,
                    type: card.type.rawValue,
                    title: card.title,
                    body: card.body,
                    priority: card.priority.rawValue,
                    sensitivity: card.sensitivity.rawValue,
                    isExcludedFromModel: card.isExcludedFromModel
                )
            },
            answers: context.questions.map { question in
                .init(
                    id: question.id.uuidString,
                    question: question.question,
                    answer: question.answer,
                    calibrationTarget: question.calibrationTarget
                )
            },
            quests: context.quests.map { quest in
                .init(
                    id: quest.id.uuidString,
                    type: quest.type.rawValue,
                    title: quest.title,
                    completionCriteria: quest.completionCriteria,
                    calibrationTarget: quest.calibrationTarget
                )
            },
            principles: memory.retrievedPrinciples.map { retrieved in
                let principle = retrieved.principle
                return PromptContextPayload.PrincipleContext(
                    id: principle.id.uuidString,
                    title: principle.title,
                    summary: principle.summary,
                    triggerContext: principle.triggerContext,
                    successCriteria: principle.successCriteria,
                    exceptions: principle.exceptions,
                    status: principle.status,
                    retrievalReason: retrieved.retrievalReason,
                    retrievalPolicyVersion: retrieved.policyVersion,
                    retrievalSignal: retrieved.retrievalSignal
                )
            },
            existingPrinciples: memory.existingPrinciples.map { principle in
                .init(
                    id: principle.id.uuidString,
                    title: principle.title,
                    summary: principle.summary,
                    triggerContext: principle.triggerContext,
                    successCriteria: principle.successCriteria,
                    exceptions: principle.exceptions,
                    status: principle.status
                )
            },
            directives: directives,
            lensFeedback: memory.lensFeedback,
            trainingPrescription: memory.trainingPrescription.map(PromptContextPayload.TrainingPrescriptionContext.init),
            coachDiagnosis: memory.coachDiagnosis.map(PromptContextPayload.CoachDiagnosisContext.init),
            coachTurnState: memory.coachTurnState.map(PromptContextPayload.CoachTurnStateContext.init),
            coachTeachingPlan: memory.coachTeachingPlan.map(PromptContextPayload.CoachTeachingPlanContext.init)
        )
    }

    private func sourceRecordIDs(for context: TodayAIContext) -> [String] {
        var ids = [context.draft.id.uuidString]
        ids.append(contentsOf: context.confirmedCards.map { $0.id.uuidString })
        ids.append(contentsOf: context.questions.map { $0.id.uuidString })
        ids.append(contentsOf: context.quests.map { $0.id.uuidString })
        return Array(Set(ids)).sorted()
    }

    private func contextRecordIDs(
        for context: TodayAIContext,
        relevantPrinciples: [PrincipleAsset],
        existingPrinciples: [PrincipleAsset]
    ) -> [String] {
        var ids = sourceRecordIDs(for: context)
        ids.append(contentsOf: relevantPrinciples.map { $0.id.uuidString })
        ids.append(contentsOf: existingPrinciples.map { $0.id.uuidString })
        return Array(Set(ids)).sorted()
    }

    private func inputSummary(for context: TodayAIContext, relevantPrinciples: [PrincipleAsset]) -> String {
        let rawText = context.draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lens = selectedLensItem(for: context)?.promptId ?? "none"
        let cardTitles = context.confirmedCards.map(\.title).joined(separator: ", ")
        let principleTitles = relevantPrinciples.map(\.title).joined(separator: ", ")
        return "mode=\(context.draft.sessionMode.rawValue); lens=\(lens); rawText=\(rawText); cards=\(cardTitles); principles=\(principleTitles)"
    }

    private func selectedLensId(for context: TodayAIContext) -> String? {
        if let finalLensId = context.trainingPrescription?.finalLensId {
            return finalLensId
        }
        return selectedLensItem(for: context)?.lensId
    }

    private func selectedLensItem(for context: TodayAIContext) -> LensCatalogItem? {
        if let finalLensId = context.trainingPrescription?.finalLensId {
            if let runtimeItem = context.selectedLensItem, runtimeItem.lensId == finalLensId {
                return runtimeItem
            }
            if let builtinItem = BuiltinLensCatalog.item(localId: finalLensId) {
                return builtinItem
            }
        }
        return context.selectedLensItem ?? context.draft.selectedLens?.catalogItem
    }
}
