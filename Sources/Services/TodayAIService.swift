import Foundation

struct TodayAIContext: Hashable {
    var draft: DailyEntryDraft
    var confirmedCards: [ThinkingCard] = []
    var questions: [ReflectionQuestion] = []
    var quests: [Quest] = []
}

final class TodayAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient
    private let parser: TodayAIResponseParser

    init(
        promptProvider: PromptProvider,
        llmClient: LLMClient,
        parser: TodayAIResponseParser = TodayAIResponseParser()
    ) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
        self.parser = parser
    }

    func organizeCards(for context: TodayAIContext) async throws -> [ThinkingCard] {
        let request = request(
            promptID: .organizeCards,
            context: context,
            payload: [
                "rawText": context.draft.rawText,
                "privacyRules": "Avoid repeating unnecessary confidential specifics. Mark sensitive content defensively.",
                "sessionMode": context.draft.sessionMode.rawValue
            ]
        )
        let data = try await llmClient.complete(request)
        return try parser.parseCards(from: data)
    }

    func generateQuestions(for context: TodayAIContext) async throws -> [ReflectionQuestion] {
        let request = request(
            promptID: .generateQuestions,
            context: context,
            payload: [
                "confirmedCards": cardsPayload(context.confirmedCards),
                "priorAnswers": questionsPayload(context.questions),
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
                "confirmedCards": cardsPayload(context.confirmedCards),
                "reflectionAnswers": questionsPayload(context.questions),
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
                "confirmedCards": cardsPayload(context.confirmedCards),
                "reflectionAnswers": questionsPayload(context.questions),
                "selectedQuest": questsPayload(context.quests),
                "sessionMode": context.draft.sessionMode.rawValue
            ]
        )
        let data = try await llmClient.complete(request)
        return try parser.parsePrinciples(from: data)
    }

    private func request(
        promptID: PromptID,
        context: TodayAIContext,
        payload: [String: String]
    ) -> LLMRequest {
        LLMRequest(
            prompt: promptProvider.template(for: promptID, mode: context.draft.sessionMode),
            inputSummary: inputSummary(for: context),
            jsonPayload: payload
        )
    }

    private func inputSummary(for context: TodayAIContext) -> String {
        let rawText = context.draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lens = context.draft.selectedLens?.rawValue ?? "none"
        let cardTitles = context.confirmedCards.map(\.title).joined(separator: ", ")
        return "mode=\(context.draft.sessionMode.rawValue); lens=\(lens); rawText=\(rawText); cards=\(cardTitles)"
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
}
