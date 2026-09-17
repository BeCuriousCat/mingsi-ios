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

    init(sentSources: Set<MentorSourceReference>, userExpressionSources: Set<MentorSourceReference>,
         supersededSources: Set<MentorSourceReference> = [], eligibleLessons: Set<MentorLessonReference> = [],
         materialQuestionCount: Int, intent: Intent = .discuss,
         availableActions: Set<MentorSuggestedAction> = Set(MentorSuggestedAction.allCases)) throws {
        guard (0...2).contains(materialQuestionCount), userExpressionSources.isSubset(of: sentSources),
              supersededSources.isSubset(of: sentSources), !userExpressionSources.contains(where: \.isLesson),
              userExpressionSources.isDisjoint(with: supersededSources) else { throw MentorResponseError.invalidContext }
        self.sentSources = sentSources
        self.userExpressionSources = userExpressionSources
        self.supersededSources = supersededSources
        self.eligibleLessons = eligibleLessons
        self.materialQuestionCount = materialQuestionCount
        self.intent = intent
        self.availableActions = availableActions
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
    case intentMismatch
    case noUserExpression
    case nonUserDraftSource(String)
}

struct MentorResponseParser {
    func parseTurn(_ data: Data, context: MentorResponseValidationContext) throws -> MentorValidatedTurn {
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
        guard (response.question == nil) == (response.questionPurpose == nil),
              response.action != .clarify || response.question != nil,
              response.materialStatus != .missing || response.question == nil || response.questionPurpose == .material else {
            throw MentorResponseError.invalidField("question_purpose")
        }
        try Self.sources(response.sourceRefs, context: context)
        guard response.suggestedActions.count <= 5, Set(response.suggestedActions).count == response.suggestedActions.count else {
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
            guard response.action == .explain, !response.requiresMaterial else { throw MentorResponseError.intentMismatch }
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
