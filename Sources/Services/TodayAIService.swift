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
            payload: [
                "privacyRules": "Avoid repeating unnecessary confidential specifics. Mark sensitive content defensively.",
                "sessionMode": context.draft.sessionMode.rawValue
            ]
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
            payload: [
                "privacyRules": "Avoid repeating unnecessary confidential specifics. Mark sensitive content defensively.",
                "sessionMode": context.draft.sessionMode.rawValue,
                "streamProtocol": "MINGSI_STREAM_V1"
            ]
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
            context: context,
            payload: [
                "selectedLens": context.draft.selectedLens?.rawValue ?? "",
                "sessionMode": context.draft.sessionMode.rawValue
            ]
        )
        let data = try await llmClient.complete(request)
        return try parser.parseQuestions(from: data)
    }

    func generateQuests(for context: TodayAIContext) async throws -> [Quest] {
        let request = request(
            promptID: .generateQuests,
            context: context,
            payload: [
                "selectedLens": context.draft.selectedLens?.rawValue ?? "",
                "sessionMode": context.draft.sessionMode.rawValue
            ]
        )
        let data = try await llmClient.complete(request)
        return try parser.parseQuests(from: data)
    }

    func extractPrinciple(for context: TodayAIContext) async throws -> [PrincipleAsset] {
        let request = request(
            promptID: .extractPrinciple,
            context: context,
            payload: [
                "sessionMode": context.draft.sessionMode.rawValue
            ]
        )
        let data = try await llmClient.complete(request)
        return try parser.parsePrinciples(from: data)
    }

    func verifyQuest(input: VerifyQuestInput, sessionMode: SessionMode) async throws -> VerifyQuestResult {
        let template = promptProvider.template(for: .verifyQuest, mode: sessionMode)
        let request = LLMRequest(
            prompt: template,
            inputSummary: "quest=\(input.questTitle); completion=\(input.completion); rating=\(input.valueRating)",
            jsonPayload: [
                "questTitle": input.questTitle,
                "completionCriteria": input.completionCriteria,
                "completion": input.completion,
                "valueRating": input.valueRating,
                "rawText": input.rawText
            ],
            contextPayload: PromptContextPayload(
                currentInput: .init(rawText: input.rawText),
                userChoice: .init(sessionMode: sessionMode.rawValue),
                extra: [
                    "questTitle": input.questTitle,
                    "completionCriteria": input.completionCriteria,
                    "completion": input.completion,
                    "valueRating": input.valueRating
                ]
            ),
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
        payload: [String: String]
    ) -> LLMRequest {
        let promptContext = contextAssembler.assemble(promptID: promptID, context: context)
        let contextPayload = promptContext.contextPayload.mergingExtra(payload)
        let mergedPayload = contextPayload.legacyKeyValues
        return LLMRequest(
            prompt: promptProvider.template(for: promptID, mode: context.draft.sessionMode),
            inputSummary: promptContext.inputSummary,
            jsonPayload: mergedPayload,
            contextPayload: contextPayload,
            sourceRecordIDs: promptContext.sourceRecordIDs,
            contextVersion: promptContext.version,
            contextRecordIDs: promptContext.contextRecordIDs
        )
    }
}

struct PromptContext: Hashable {
    var version: Int = 1
    var inputSummary: String
    var payload: [String: String]
    var contextPayload: PromptContextPayload
    var sourceRecordIDs: [String]
    var contextRecordIDs: [String]
}

protocol ContextAssembler {
    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext
}

protocol PrincipleRetriever {
    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [PrincipleAsset]
}

struct LocalPrincipleRetriever: PrincipleRetriever {
    private let minimumScore = 2
    private let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "before", "by", "did", "do", "does", "for", "from",
        "has", "have", "if", "in", "is", "it", "its", "not", "of", "on", "one", "or", "our", "the",
        "their", "then", "this", "to", "was", "were", "what", "when", "where", "which", "who", "why",
        "will", "with", "write", "action", "actions", "criteria", "discussion", "ended", "next",
        "明日", "任务", "今天", "昨天", "问题", "行动", "标准", "完成", "需要", "进行", "一个", "这个"
    ]

    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int = 3) -> [PrincipleAsset] {
        guard promptID != .organizeCards else { return [] }

        let terms = searchTerms(from: context)
        let scored = context.principles
            .filter { $0.status == .active }
            .map { principle in
                (principle, score(principle: principle, terms: terms))
            }
            .filter { $0.1 >= minimumScore }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.1 > rhs.1
            }
            .prefix(limit)
            .map { $0.0 }

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
}

struct DefaultContextAssembler: ContextAssembler {
    private let principleRetriever: PrincipleRetriever

    init(principleRetriever: PrincipleRetriever = LocalPrincipleRetriever()) {
        self.principleRetriever = principleRetriever
    }

    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext {
        let relevantPrinciples = principleRetriever.relevantPrinciples(for: context, promptID: promptID, limit: 3)
        let existingPrinciples = promptID == .extractPrinciple ? context.principles : []
        var payload = basePayload(for: promptID, context: context)
        if !relevantPrinciples.isEmpty {
            payload["relevantPrinciples"] = principlesPayload(relevantPrinciples)
            payload["principleUsageRule"] = "Use accepted principles only as comparison lenses. Do not force today's situation to fit them."
        }
        let contextPayload = structuredPayload(
            for: context,
            relevantPrinciples: relevantPrinciples,
            existingPrinciples: existingPrinciples,
            extra: !relevantPrinciples.isEmpty ? [
                "principleUsageRule": "Use accepted principles only as comparison lenses. Do not force today's situation to fit them."
            ] : [:]
        )

        return PromptContext(
            version: 1,
            inputSummary: inputSummary(for: context, relevantPrinciples: relevantPrinciples),
            payload: payload,
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
        relevantPrinciples: [PrincipleAsset],
        existingPrinciples: [PrincipleAsset],
        extra: [String: String]
    ) -> PromptContextPayload {
        PromptContextPayload(
            currentInput: .init(
                dailyEntryId: context.draft.id.uuidString,
                rawText: context.draft.rawText
            ),
            userChoice: .init(
                sessionMode: context.draft.sessionMode.rawValue,
                selectedLens: context.draft.selectedLens?.rawValue
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
            principles: relevantPrinciples.map { principle in
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
            extra: extra
        )
    }

    private func basePayload(for promptID: PromptID, context: TodayAIContext) -> [String: String] {
        switch promptID {
        case .organizeCards:
            return [
                "rawText": context.draft.rawText
            ]
        case .generateQuestions:
            return [
                "confirmedCards": cardsPayload(context.confirmedCards),
                "priorAnswers": questionsPayload(context.questions)
            ]
        case .generateQuests:
            return [
                "confirmedCards": cardsPayload(context.confirmedCards),
                "reflectionAnswers": questionsPayload(context.questions)
            ]
        case .extractPrinciple:
            return [
                "confirmedCards": cardsPayload(context.confirmedCards),
                "reflectionAnswers": questionsPayload(context.questions),
                "selectedQuest": questsPayload(context.quests),
                "existingPrinciples": principlesPayload(context.principles)
            ]
        case .recommendLenses, .verifyQuest, .weeklyCalibration, .monthlyGrowth, .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges:
            return [:]
        }
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
        let lens = context.draft.selectedLens?.rawValue ?? "none"
        let cardTitles = context.confirmedCards.map(\.title).joined(separator: ", ")
        let principleTitles = relevantPrinciples.map(\.title).joined(separator: ", ")
        return "mode=\(context.draft.sessionMode.rawValue); lens=\(lens); rawText=\(rawText); cards=\(cardTitles); principles=\(principleTitles)"
    }

    private func cardsPayload(_ cards: [ThinkingCard]) -> String {
        cards.map { card in
            [
                "type": card.type.rawValue,
                "title": card.title,
                "body": card.body,
                "priority": card.priority.rawValue,
                "sensitivity": card.sensitivity.rawValue
            ]
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: ", ")
        }
        .joined(separator: "\n")
    }

    private func questionsPayload(_ questions: [ReflectionQuestion]) -> String {
        questions.map { question in
            "question: \(question.question), answer: \(question.answer)"
        }
        .joined(separator: "\n")
    }

    private func questsPayload(_ quests: [Quest]) -> String {
        quests.map { quest in
            "type: \(quest.type.rawValue), title: \(quest.title), completionCriteria: \(quest.completionCriteria)"
        }
        .joined(separator: "\n")
    }

    private func principlesPayload(_ principles: [PrincipleAsset]) -> String {
        principles.map { principle in
            [
                "id": principle.id.uuidString,
                "title": principle.title,
                "summary": principle.summary,
                "triggerContext": principle.triggerContext,
                "successCriteria": principle.successCriteria,
                "exceptions": principle.exceptions
            ]
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: ", ")
        }
        .joined(separator: "\n")
    }
}
