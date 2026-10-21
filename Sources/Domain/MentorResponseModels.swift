import Foundation

struct MentorSourceReference: Hashable, Codable, Identifiable {
    let value: String
    var id: String { value }
    var isLesson: Bool { value.hasPrefix("lesson:") }

    init(_ raw: String) throws {
        let pattern = #"^(?:(?:item|capture|legacy-nudge|understanding):[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|lesson:L[0-9]{2}@[0-9]+\.[0-9]+(?:\.[0-9]+)?)$"#
        guard raw.unicodeScalars.count <= 100, let range = raw.range(of: pattern, options: .regularExpression),
              range == raw.startIndex..<raw.endIndex else { throw MentorResponseError.invalidField("source_refs") }
        if raw.hasPrefix("lesson:") {
            value = raw
        } else {
            let parts = raw.split(separator: ":", maxSplits: 1)
            guard let id = UUID(uuidString: String(parts[1])) else { throw MentorResponseError.invalidField("source_refs") }
            value = String(parts[0]) + ":" + id.uuidString
        }
    }

    init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct MentorLessonReference: Codable, Hashable {
    let id: String
    let version: String
}

enum MentorAction: String, Codable, CaseIterable { case clarify, explain, compare, advise, close }
enum MentorMaterialStatus: String, Codable { case missing, usable, notNeeded = "not_needed" }
enum MentorQuestionPurpose: String, Codable { case material, reflection }
enum MentorSuggestedAction: String, Codable, CaseIterable {
    case reply, explain, anotherLesson = "another_lesson", draftUnderstanding = "draft_understanding", finish
}

struct MentorTurnResponse: Codable, Equatable {
    let schemaVersion: String
    let action: MentorAction
    let materialStatus: MentorMaterialStatus
    let body: String
    let question: String?
    let questionPurpose: MentorQuestionPurpose?
    let sourceRefs: [MentorSourceReference]
    let lessonRef: MentorLessonReference?
    let suggestedActions: [MentorSuggestedAction]

    var requiresMaterial: Bool {
        question != nil && (questionPurpose == .material || materialStatus == .missing)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", action, materialStatus = "material_status", body, question
        case questionPurpose = "question_purpose", sourceRefs = "source_refs", lessonRef = "lesson_ref", suggestedActions = "suggested_actions"
    }

    // These three nulls are required by the wire contract. Synthesized encodeIfPresent
    // would silently remove them when persisting or replaying a validated response.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(action, forKey: .action)
        try container.encode(materialStatus, forKey: .materialStatus)
        try container.encode(body, forKey: .body)
        try container.encode(question, forKey: .question)
        try container.encode(questionPurpose, forKey: .questionPurpose)
        try container.encode(sourceRefs, forKey: .sourceRefs)
        try container.encode(lessonRef, forKey: .lessonRef)
        try container.encode(suggestedActions, forKey: .suggestedActions)
    }
}

/// A model response is always a draft, with no confirmation or persistence side effects.
struct MentorUnderstandingDraftResponse: Codable, Equatable {
    let schemaVersion: String
    let text: String
    let sourceRefs: [MentorSourceReference]
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", text, sourceRefs = "source_refs" }
}

/// The request builder must derive these facts from the exact payload sent to the model.
/// A syntactically valid reference is never evidence of ownership or user authorship.
struct MentorResponseValidationContext {
    enum Intent { case discuss, directTeaching, finish }
    let sentSources: Set<MentorSourceReference>
    let userExpressionSources: Set<MentorSourceReference>
    let supersededSources: Set<MentorSourceReference>
    let eligibleLessons: Set<MentorLessonReference>
    let materialQuestionCount: Int
    let intent: Intent
    let availableActions: Set<MentorSuggestedAction>
    /// The new user expression that anchors this turn, when one exists.
    /// Explicit UI actions may intentionally omit this anchor.
    let latestUserExpressionSource: MentorSourceReference?
    /// The immediately preceding assistant question, when the request is a
    /// continuation. This is a deterministic guard against asking the same
    /// question again after the user has already seen it.
    let previousAssistantQuestion: String?

    init(sentSources: Set<MentorSourceReference>, userExpressionSources: Set<MentorSourceReference>,
         supersededSources: Set<MentorSourceReference> = [], eligibleLessons: Set<MentorLessonReference> = [],
         materialQuestionCount: Int, intent: Intent = .discuss,
         availableActions: Set<MentorSuggestedAction> = Set(MentorSuggestedAction.allCases),
         previousAssistantQuestion: String? = nil,
         latestUserExpressionSource: MentorSourceReference? = nil) throws {
        guard (0...2).contains(materialQuestionCount), userExpressionSources.isSubset(of: sentSources),
              supersededSources.isSubset(of: sentSources), !userExpressionSources.contains(where: \.isLesson),
              userExpressionSources.isDisjoint(with: supersededSources),
              latestUserExpressionSource.map({ userExpressionSources.contains($0) }) ?? true else {
            throw MentorResponseError.invalidContext
        }
        self.sentSources = sentSources
        self.userExpressionSources = userExpressionSources
        self.supersededSources = supersededSources
        self.eligibleLessons = eligibleLessons
        self.materialQuestionCount = materialQuestionCount
        self.intent = intent
        self.availableActions = availableActions
        self.previousAssistantQuestion = previousAssistantQuestion
        self.latestUserExpressionSource = latestUserExpressionSource
    }
}

struct MentorValidatedTurn: Equatable {
    let response: MentorTurnResponse
    /// Suggestions are intersected with current capabilities; never execute model commands.
    let availableSuggestedActions: [MentorSuggestedAction]
}

enum MentorResponseError: Error, Equatable {
    case invalidField(String)
    case unsupportedSchema
    case invalidContext
    case unsentSource(String)
    case supersededSource(String)
    case ineligibleLesson
    case materialBudgetExhausted
    case repeatedQuestion
    case intentMismatch
    case noUserExpression
    case nonUserDraftSource(String)
    case qualityGateFailed(MentorResponseQualityIssue)
}

/// Cheap local checks for the mentor's core promise. The model still owns the
/// nuanced judgment; this policy rejects visibly ungrounded responses even
/// when they describe a material gap, and protects the zero-material review path.
enum MentorResponseQualityIssue: String, Error, Equatable {
    case missingSourceGrounding = "missing_source_grounding"
    case genericResponse = "generic_response"
    case hiddenQuestionInBody = "hidden_question_in_body"
    case reviewOpeningNeedsQuestion = "review_opening_needs_question"
    case reviewOpeningNeedsSpecificDoorway = "review_opening_needs_specific_doorway"
}

struct MentorResponseQualityPolicy {
    static func validate(_ response: MentorTurnResponse,
                         context: MentorResponseValidationContext,
                         initialEntry: String,
                         intent: String) throws {
        let body = response.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGeneric(body, action: response.action) else {
            throw MentorResponseError.qualityGateFailed(.genericResponse)
        }
        guard !containsQuestionMarkOutsideQuotedText(body) else {
            throw MentorResponseError.qualityGateFailed(.hiddenQuestionInBody)
        }

        let hasUserMaterial = !context.userExpressionSources.isEmpty
        if hasUserMaterial, response.action != .close {
            let requiredSources = context.latestUserExpressionSource.map { [$0] } ?? Array(context.userExpressionSources)
            if response.sourceRefs.allSatisfy({ !requiredSources.contains($0) }) {
                throw MentorResponseError.qualityGateFailed(.missingSourceGrounding)
            }
        }

        // A blank review is a deliberate invitation to remember something.
        // It must leave a reply doorway in the same turn; otherwise a valid
        // JSON response can still strand the user on an empty screen.
        if initialEntry == "review", intent == "review", !hasUserMaterial,
           response.action != .close, response.question == nil {
            throw MentorResponseError.qualityGateFailed(.reviewOpeningNeedsQuestion)
        }
        if initialEntry == "review", intent == "review", !hasUserMaterial,
           let question = response.question, isGenericReviewQuestion(question) {
            throw MentorResponseError.qualityGateFailed(.reviewOpeningNeedsSpecificDoorway)
        }
    }

    private static func isGeneric(_ body: String, action: MentorAction) -> Bool {
        guard action != .close else { return false }
        let normalized = body
            .lowercased()
            .replacingOccurrences(of: "[\\s，。！？、,.!?：:；;“”\"'（）()]+", with: "", options: .regularExpression)
        guard !normalized.isEmpty else { return true }
        let genericOnly = [
            "请说说你的感受",
            "请说说今天发生了什么",
            "你可以继续思考",
            "希望这能帮助你",
            "这是一个值得思考的问题",
            "具体情况需要具体分析"
        ]
        return genericOnly.contains(normalized)
    }

    private static func containsQuestionMarkOutsideQuotedText(_ body: String) -> Bool {
        var quoteDepth = 0
        var insideASCIIQuotes = false
        for character in body {
            switch character {
            case "“", "「", "『": quoteDepth += 1
            case "”", "」", "』": quoteDepth = max(0, quoteDepth - 1)
            case "\"": insideASCIIQuotes.toggle()
            case "?", "？":
                if quoteDepth == 0 && !insideASCIIQuotes { return true }
            default: break
            }
        }
        return false
    }

    private static func isGenericReviewQuestion(_ question: String) -> Bool {
        let normalized = question
            .lowercased()
            .replacingOccurrences(of: "[\\s，。！？、,.!?：:；;“”\"'（）()]+", with: "", options: .regularExpression)
        let genericOpenings = [
            "请说说今天发生了什么",
            "今天发生了什么",
            "你今天想聊什么",
            "你想聊什么",
            "你想聊些什么",
            "你有什么想法",
            "请说说你的感受",
            "你今天感觉怎么样"
        ]
        return genericOpenings.contains(normalized)
    }
}

struct MentorResponseParser {
    func parseTurn(_ data: Data, context: MentorResponseValidationContext) throws -> MentorValidatedTurn {
        let data = try Self.payloadData(data)
        let object = try Self.object(data, keys: ["schema_version", "action", "material_status", "body", "question", "question_purpose", "source_refs", "lesson_ref", "suggested_actions"])
        if let lesson = object["lesson_ref"], !(lesson is NSNull) {
            guard let fields = lesson as? [String: Any], Set(fields.keys) == ["id", "version"] else {
                throw MentorResponseError.invalidField("lesson_ref")
            }
        }
        let response = try JSONDecoder().decode(MentorTurnResponse.self, from: data)
        guard response.schemaVersion == "1.0.0" else { throw MentorResponseError.unsupportedSchema }
        try Self.text(response.body, limit: 12000, field: "body")
        if let question = response.question { try Self.text(question, limit: 1000, field: "question") }
        if let question = response.question,
           let previous = context.previousAssistantQuestion,
           Self.normalizedQuestion(question) == Self.normalizedQuestion(previous) {
            throw MentorResponseError.repeatedQuestion
        }
        guard (response.question == nil) == (response.questionPurpose == nil),
              response.action != .clarify || response.question != nil,
              response.materialStatus != .missing || response.question == nil || response.questionPurpose == .material else {
            throw MentorResponseError.invalidField("question_purpose")
        }
        try Self.sources(response.sourceRefs, context: context)
        // Two is a deliberate interaction budget. More choices turn a short
        // thinking step into another planning menu, even when the model's
        // body is otherwise valid.
        guard response.suggestedActions.count <= 2, Set(response.suggestedActions).count == response.suggestedActions.count else {
            throw MentorResponseError.invalidField("suggested_actions")
        }
        if let lesson = response.lessonRef {
            try Self.lesson(lesson)
            guard context.eligibleLessons.contains(lesson) else { throw MentorResponseError.ineligibleLesson }
        }
        guard !response.requiresMaterial || context.materialQuestionCount < 2 else { throw MentorResponseError.materialBudgetExhausted }
        switch context.intent {
        case .discuss: break
        case .directTeaching:
            guard response.action == .explain, response.question == nil else { throw MentorResponseError.intentMismatch }
        case .finish:
            guard response.action == .close, response.question == nil, response.lessonRef == nil else { throw MentorResponseError.intentMismatch }
        }
        let available = response.suggestedActions.filter {
            context.availableActions.contains($0)
                && ($0 != .draftUnderstanding || !context.userExpressionSources.isEmpty)
                && ($0 != .anotherLesson || !context.eligibleLessons.isEmpty)
                && (context.intent != .finish || $0 == .finish)
        }
        return MentorValidatedTurn(response: response, availableSuggestedActions: available)
    }

    func parseUnderstanding(_ data: Data, context: MentorResponseValidationContext) throws -> MentorUnderstandingDraftResponse {
        let data = try Self.payloadData(data)
        _ = try Self.object(data, keys: ["schema_version", "text", "source_refs"])
        let response = try JSONDecoder().decode(MentorUnderstandingDraftResponse.self, from: data)
        guard response.schemaVersion == "1.0.0" else { throw MentorResponseError.unsupportedSchema }
        try Self.text(response.text, limit: 12000, field: "text")
        guard !context.userExpressionSources.isEmpty else { throw MentorResponseError.noUserExpression }
        guard !response.sourceRefs.isEmpty else { throw MentorResponseError.invalidField("source_refs") }
        try Self.sources(response.sourceRefs, context: context)
        for ref in response.sourceRefs where !context.userExpressionSources.contains(ref) {
            throw MentorResponseError.nonUserDraftSource(ref.value)
        }
        return response
    }

    /// OpenAI-compatible transports return an envelope; injected local clients
    /// may return the protocol JSON directly. Unwrap without repairing content.
    private static func payloadData(_ data: Data) throws -> Data {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MentorResponseError.invalidField("object")
        }
        guard object["choices"] != nil else { return data }
        let envelope = try JSONDecoder().decode(GLMChatCompletionResponse.self, from: data)
        guard envelope.choices.count == 1, let content = envelope.choices.first?.message?.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MentorResponseError.invalidField("response_content")
        }
        return Data(content.utf8)
    }

    private static func object(_ data: Data, keys: Set<String>) throws -> [String: Any] {
        // Do not extract fenced JSON, repair malformed JSON or silently request another response.
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == keys else {
            throw MentorResponseError.invalidField("object")
        }
        return object
    }

    private static func text(_ value: String, limit: Int, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.unicodeScalars.count <= limit else {
            throw MentorResponseError.invalidField(field)
        }
    }

    private static func normalizedQuestion(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "?？。.!！"))
    }

    private static func sources(_ sources: [MentorSourceReference], context: MentorResponseValidationContext) throws {
        guard sources.count <= 128, Set(sources).count == sources.count else { throw MentorResponseError.invalidField("source_refs") }
        for source in sources {
            guard context.sentSources.contains(source) else { throw MentorResponseError.unsentSource(source.value) }
            guard !context.supersededSources.contains(source) else { throw MentorResponseError.supersededSource(source.value) }
        }
    }

    private static func lesson(_ lesson: MentorLessonReference) throws {
        for (value, regex) in [(lesson.id, #"^L[0-9]{2}$"#), (lesson.version, #"^[0-9]+\.[0-9]+(?:\.[0-9]+)?$"#)] {
            guard let range = value.range(of: regex, options: .regularExpression), range == value.startIndex..<value.endIndex else {
                throw MentorResponseError.invalidField("lesson_ref")
            }
        }
        guard lesson.version.unicodeScalars.count <= 32 else { throw MentorResponseError.invalidField("lesson_ref.version") }
    }
}
