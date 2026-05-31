import Foundation

enum TodayAIParsingError: Error {
    case missingResponseContent
    case invalidJSON
    case emptyResult
}

struct TodayAIResponseParser {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func parseCards(from data: Data) throws -> [ThinkingCard] {
        let response = try decoder.decode(OrganizeCardsResponseDTO.self, from: normalizedPayloadData(from: data))
        let cards = response.cards.compactMap { dto -> ThinkingCard? in
            let title = dto.title.trimmed
            let body = dto.body.trimmed
            guard !title.isEmpty || !body.isEmpty else { return nil }

            return ThinkingCard(
                type: ThinkingCardType(aiRawValue: dto.type.value),
                title: title.isEmpty ? "未命名卡片" : title,
                body: body.isEmpty ? dto.reason.trimmed : body,
                priority: PriorityLevel(aiRawValue: dto.importance.value),
                sensitivity: SensitivityLevel(aiRawValue: dto.sensitivity.value),
                confidence: ConfidenceMapper.score(from: dto.confidence.value),
                isConfirmed: false
            )
        }

        guard !cards.isEmpty else { throw TodayAIParsingError.emptyResult }
        return cards
    }

    func parseQuestions(from data: Data) throws -> [ReflectionQuestion] {
        let response = try decoder.decode(QuestionsResponseDTO.self, from: normalizedPayloadData(from: data))
        let questions = response.questions.compactMap { dto -> ReflectionQuestion? in
            let question = dto.question.trimmed
            guard !question.isEmpty else { return nil }

            return ReflectionQuestion(
                question: question,
                whyItMatters: dto.whyThisMatters.trimmed.ifEmpty("帮助把今天的判断转成可验证行动。")
            )
        }

        guard !questions.isEmpty else { throw TodayAIParsingError.emptyResult }
        return questions
    }

    func parseQuests(from data: Data) throws -> [Quest] {
        let response = try decoder.decode(QuestsResponseDTO.self, from: normalizedPayloadData(from: data))
        guard let mainQuest = response.mainQuest?.domainQuest(defaultType: .main) else {
            throw TodayAIParsingError.emptyResult
        }

        var quests = [mainQuest]
        quests.append(contentsOf: response.sideQuests.compactMap { $0.domainQuest(defaultType: .side) })
        if let observationQuest = response.observationQuest?.domainQuest(defaultType: .observation) {
            quests.append(observationQuest)
        }

        return quests
    }

    func parsePrinciples(from data: Data) throws -> [PrincipleAsset] {
        let response = try decoder.decode(PrincipleResponseDTO.self, from: normalizedPayloadData(from: data))
        guard let candidate = response.principleCandidate else { return [] }
        guard let principle = candidate.domainPrinciple else { return [] }
        return [principle]
    }

    private func normalizedPayloadData(from data: Data) throws -> Data {
        if let envelope = try? decoder.decode(LLMChatEnvelopeDTO.self, from: data),
           let content = envelope.choices.compactMap(\.message?.content).first?.trimmed,
           !content.isEmpty {
            return try jsonObjectData(from: content)
        }

        return try jsonObjectData(from: String(decoding: data, as: UTF8.self))
    }

    private func jsonObjectData(from text: String) throws -> Data {
        let stripped = text
            .trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmed

        guard
            let start = stripped.firstIndex(of: "{"),
            let end = stripped.lastIndex(of: "}"),
            start <= end
        else {
            throw TodayAIParsingError.invalidJSON
        }

        let jsonText = String(stripped[start...end])
        guard let data = jsonText.data(using: .utf8) else {
            throw TodayAIParsingError.invalidJSON
        }
        return data
    }
}

private struct LLMChatEnvelopeDTO: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message?
    }

    struct Message: Decodable {
        let content: String?
    }
}

private struct OrganizeCardsResponseDTO: Decodable {
    let cards: [CardDTO]
}

private struct CardDTO: Decodable {
    let type: FlexibleString
    let title: String
    let body: String
    let importance: FlexibleString
    let sensitivity: FlexibleString
    let confidence: FlexibleString
    let reason: String

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case body
        case importance
        case sensitivity
        case confidence
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(FlexibleString.self, forKey: .type) ?? FlexibleString("")
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        importance = try container.decodeIfPresent(FlexibleString.self, forKey: .importance) ?? FlexibleString("")
        sensitivity = try container.decodeIfPresent(FlexibleString.self, forKey: .sensitivity) ?? FlexibleString("")
        confidence = try container.decodeIfPresent(FlexibleString.self, forKey: .confidence) ?? FlexibleString("")
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }
}

private struct QuestionsResponseDTO: Decodable {
    let questions: [QuestionDTO]
}

private struct QuestionDTO: Decodable {
    let question: String
    let whyThisMatters: String

    private enum CodingKeys: String, CodingKey {
        case question
        case whyThisMatters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        whyThisMatters = try container.decodeIfPresent(String.self, forKey: .whyThisMatters) ?? ""
    }
}

private struct QuestsResponseDTO: Decodable {
    let mainQuest: QuestDTO?
    let sideQuests: [QuestDTO]
    let observationQuest: QuestDTO?

    private enum CodingKeys: String, CodingKey {
        case mainQuest
        case sideQuests
        case observationQuest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainQuest = try container.decodeIfPresent(QuestDTO.self, forKey: .mainQuest)
        sideQuests = try container.decodeIfPresent([QuestDTO].self, forKey: .sideQuests) ?? []
        observationQuest = try container.decodeIfPresent(QuestDTO.self, forKey: .observationQuest)
    }
}

private struct QuestDTO: Decodable {
    let type: FlexibleString
    let title: String
    let whyItMatters: String
    let completionCriteria: String
    let expectedResistance: String
    let reflectionQuestion: String

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case whyItMatters
        case completionCriteria
        case expectedResistance
        case reflectionQuestion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(FlexibleString.self, forKey: .type) ?? FlexibleString("")
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        whyItMatters = try container.decodeIfPresent(String.self, forKey: .whyItMatters) ?? ""
        completionCriteria = try container.decodeIfPresent(String.self, forKey: .completionCriteria) ?? ""
        expectedResistance = try container.decodeIfPresent(String.self, forKey: .expectedResistance) ?? ""
        reflectionQuestion = try container.decodeIfPresent(String.self, forKey: .reflectionQuestion) ?? ""
    }

    func domainQuest(defaultType: QuestType) -> Quest? {
        let title = title.trimmed
        let completionCriteria = completionCriteria.trimmed
        guard !title.isEmpty, !completionCriteria.isEmpty else { return nil }

        return Quest(
            type: QuestType(aiRawValue: type.value) ?? defaultType,
            title: title,
            whyItMatters: whyItMatters.trimmed.ifEmpty("来自今日复盘的高价值行动。"),
            completionCriteria: completionCriteria,
            expectedResistance: expectedResistance.trimmed.ifEmpty("容易被临时事务打断。"),
            reflectionQuestion: reflectionQuestion.trimmed.ifEmpty("完成后，哪个关键判断被验证了？"),
            status: .draft
        )
    }
}

private struct PrincipleResponseDTO: Decodable {
    let principleCandidate: PrincipleDTO?
}

private struct PrincipleDTO: Decodable {
    let title: String
    let summary: String
    let triggerContext: String
    let actions: [String]
    let successCriteria: String
    let exceptions: String

    private enum CodingKeys: String, CodingKey {
        case title
        case summary
        case triggerContext
        case actions
        case successCriteria
        case exceptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        triggerContext = try container.decodeIfPresent(String.self, forKey: .triggerContext) ?? ""
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        successCriteria = try container.decodeIfPresent(String.self, forKey: .successCriteria) ?? ""
        exceptions = try container.decodeIfPresent(String.self, forKey: .exceptions) ?? ""
    }

    var domainPrinciple: PrincipleAsset? {
        let cleanActions = actions.map(\.trimmed).filter { !$0.isEmpty }
        guard !title.trimmed.isEmpty, !summary.trimmed.isEmpty, !cleanActions.isEmpty else { return nil }

        return PrincipleAsset(
            title: title.trimmed,
            summary: summary.trimmed,
            triggerContext: triggerContext.trimmed.ifEmpty("适用于类似的复盘场景。"),
            actions: cleanActions,
            successCriteria: successCriteria.trimmed.ifEmpty("行动结果可被检查。"),
            exceptions: exceptions.trimmed.ifEmpty("低风险场景可简化。")
        )
    }
}

private struct FlexibleString: Decodable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            value = ""
        }
    }
}

private enum ConfidenceMapper {
    static func score(from rawValue: String) -> Double {
        switch rawValue.lowercased().trimmed {
        case "high":
            return 0.86
        case "medium":
            return 0.72
        case "low":
            return 0.48
        default:
            if let number = Double(rawValue) {
                if number > 1 {
                    return min(max(number / 100, 0), 1)
                }
                return min(max(number, 0), 1)
            }
            return 0.64
        }
    }
}

private extension ThinkingCardType {
    init(aiRawValue: String) {
        self = ThinkingCardType(rawValue: aiRawValue.normalizedAIRawValue) ?? .idea
    }
}

private extension PriorityLevel {
    init(aiRawValue: String) {
        self = PriorityLevel(rawValue: aiRawValue.normalizedAIRawValue) ?? .medium
    }
}

private extension SensitivityLevel {
    init(aiRawValue: String) {
        switch aiRawValue.normalizedAIRawValue {
        case "sensitive":
            self = .sensitive
        case "possibly_sensitive", "possiblysensitive":
            self = .possiblySensitive
        default:
            self = .normal
        }
    }
}

private extension QuestType {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedAIRawValue: String {
        trimmed
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
