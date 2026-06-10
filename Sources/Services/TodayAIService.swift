import Foundation

struct VerifyQuestInput: Hashable {
    var sourceRecordIDs: [String] = []
    var questTitle: String
    var completionCriteria: String
    var completion: String
    var valueRating: String
    var rawText: String
}

struct VerifyQuestResult: Hashable {
    var calibrationNote: String
    var likelyIssue: String?
    var recommendation: String?
}

struct TodayAIContext: Hashable {
    var draft: DailyEntryDraft
    var confirmedCards: [ThinkingCard] = []
    var questions: [ReflectionQuestion] = []
    var quests: [Quest] = []
    var principles: [PrincipleAsset] = []
    var principleRecallFeedback: [PrincipleRecallFeedback] = []
    var selectedLensItem: LensCatalogItem?
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
        return try parser.parseQuestions(from: data)
    }

    func generateQuests(for context: TodayAIContext) async throws -> [Quest] {
        let request = request(
            promptID: .generateQuests,
            context: context
        )
        let data = try await llmClient.complete(request)
        return try parser.parseQuests(from: data)
    }

    func extractPrinciple(for context: TodayAIContext) async throws -> [PrincipleAsset] {
        let request = request(
            promptID: .extractPrinciple,
            context: context
        )
        let data = try await llmClient.complete(request)
        return try parser.parsePrinciples(from: data)
    }

    func verifyQuest(input: VerifyQuestInput, sessionMode: SessionMode) async throws -> VerifyQuestResult {
        let template = promptProvider.template(for: .verifyQuest, mode: sessionMode)
        let contextPayload = PromptContextPayload(
            currentInput: .init(rawText: input.rawText),
            userChoice: .init(sessionMode: sessionMode.rawValue),
            verification: .init(
                questTitle: input.questTitle,
                completionCriteria: input.completionCriteria,
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
        return try parser.parseVerification(from: data)
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
    var policyVersion: String
}

extension PrincipleRetriever {
    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [PrincipleAsset] {
        retrievePrinciples(for: context, promptID: promptID, limit: limit).map(\.principle)
    }
}

struct LocalPrincipleRetriever: PrincipleRetriever {
    static let policyVersion = "principle-retrieval.local-keyword-feedback.v2"

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
                let penalty = recallFeedbackPenalty(
                    for: principle.id,
                    feedback: context.principleRecallFeedback
                )
                return (principle, baseScore, max(0, baseScore - penalty), penalty)
            }
            .filter { $0.2 >= minimumScore }
            .sorted { lhs, rhs in
                if lhs.2 == rhs.2 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.2 > rhs.2
            }
            .prefix(limit)
            .map { principle, baseScore, adjustedScore, penalty in
                RetrievedPrinciple(
                    principle: principle,
                    score: adjustedScore,
                    retrievalReason: retrievalReason(
                        for: principle,
                        terms: terms,
                        baseScore: baseScore,
                        adjustedScore: adjustedScore,
                        feedbackPenalty: penalty
                    ),
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
        feedback: [PrincipleRecallFeedback]
    ) -> Int {
        feedback
            .filter { $0.principleId == principleId }
            .reduce(0) { partial, event in
                switch event.feedback {
                case .helpful:
                    return partial
                case .notApplicable, .misrecalled:
                    return partial + 1
                }
            }
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
}

struct DefaultContextAssembler: ContextAssembler {
    private let principleRetriever: PrincipleRetriever

    init(principleRetriever: PrincipleRetriever = LocalPrincipleRetriever()) {
        self.principleRetriever = principleRetriever
    }

    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext {
        let retrievedPrinciples = principleRetriever.retrievePrinciples(for: context, promptID: promptID, limit: 3)
        let relevantPrinciples = retrievedPrinciples.map(\.principle)
        let existingPrinciples = promptID == .extractPrinciple ? context.principles : []
        let contextPayload = structuredPayload(
            for: context,
            retrievedPrinciples: retrievedPrinciples,
            existingPrinciples: existingPrinciples,
            directives: .init(
                principleUsageRule: !relevantPrinciples.isEmpty
                    ? "Use accepted principles only as comparison lenses. Do not force today's situation to fit them."
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
                existingPrinciples: existingPrinciples
            )
        )
    }

    private func structuredPayload(
        for context: TodayAIContext,
        retrievedPrinciples: [RetrievedPrinciple],
        existingPrinciples: [PrincipleAsset],
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
                    answer: question.answer
                )
            },
            quests: context.quests.map { quest in
                .init(
                    id: quest.id.uuidString,
                    type: quest.type.rawValue,
                    title: quest.title,
                    completionCriteria: quest.completionCriteria
                )
            },
            principles: retrievedPrinciples.map { retrieved in
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
                    retrievalPolicyVersion: retrieved.policyVersion
                )
            },
            existingPrinciples: existingPrinciples.map { principle in
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
            directives: directives
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
        selectedLensItem(for: context)?.lensId
    }

    private func selectedLensItem(for context: TodayAIContext) -> LensCatalogItem? {
        context.selectedLensItem ?? context.draft.selectedLens?.catalogItem
    }
}
