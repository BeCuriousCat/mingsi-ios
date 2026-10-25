import Foundation

struct MentorContextSource: Codable, Equatable {
    enum Role: String, Codable { case user, assistant, lesson, understanding }
    let ref: MentorSourceReference
    let role: Role
    let content: String
    let supersedes: MentorSourceReference?
    let isCurrent: Bool
    enum CodingKeys: String, CodingKey {
        case ref, role, content, supersedes, isCurrent = "is_current"
    }
}

struct MentorLessonCandidateSummary: Codable, Equatable {
    let id: String
    let version: String
    let title: String
    let theme: MentorLesson.Theme
    let claim: String
    let applicableContexts: [String]
    enum CodingKeys: String, CodingKey {
        case id, version, title, theme, claim, applicableContexts = "applicable_contexts"
    }
}

/// A temporary, explicit slice of a user or assistant source. The complete source remains
/// in the timeline; this value only describes the material the user chose to
/// send in one request after the context budget was exceeded.
struct MentorMaterialFragment: Equatable, Identifiable {
    enum Field { case userText, assistantBody, assistantQuestion }
    let id: UUID
    let sourceID: UUID
    let label: String
    let text: String
    let field: Field

    init(id: UUID, sourceID: UUID, label: String, text: String, field: Field = .userText) {
        self.id = id
        self.sourceID = sourceID
        self.label = label
        self.text = text
        self.field = field
    }
}

struct MentorMaterialSelectionState: Equatable {
    let characterCount: Int
    let limit: Int
    let candidates: [MentorMaterialFragment]
    var currentUserSourceID: UUID? = nil
    var selectedIDs: Set<UUID> = []
    var error: String?

    var selectedFragments: [MentorMaterialFragment] {
        candidates.filter { selectedIDs.contains($0.id) }
    }
}

/// Small, derived routing metadata for the current conversational turn.
/// It is not user evidence and is intentionally additive to the 1.0.0
/// context payload so frozen requests and older snapshots remain replayable.
struct MentorConversationState: Codable, Equatable {
    let visibleTurnIndex: Int
    let hasNewUserExpression: Bool
    let previousAssistantRef: MentorSourceReference?
    let previousAssistantQuestion: String?
    let previousAssistantQuestionPurpose: MentorQuestionPurpose?
    /// Optional so stored contexts from before excerpt selection still decode.
    var usesSelectedExcerpts: Bool? = nil

    static let empty = MentorConversationState(
        visibleTurnIndex: 0,
        hasNewUserExpression: false,
        previousAssistantRef: nil,
        previousAssistantQuestion: nil,
        previousAssistantQuestionPurpose: nil
    )
}

struct MentorContextPayload: Codable, Equatable {
    let schemaVersion: String
    let sessionID: UUID
    let semanticRevision: Int
    var requestEpoch: Int
    let initialEntry: String
    let intent: String
    let materialQuestionCount: Int
    let allowsMaterialQuestion: Bool
    let sources: [MentorContextSource]
    let recentExchanges: [[MentorSourceReference]]
    let lessonCandidates: [MentorLessonCandidateSummary]
    /// Explicit anchors for the turn being answered. The source list is a
    /// timeline, so asking the model to infer the latest user expression from
    /// ordering is fragile once a session contains corrections or older
    /// assistant responses. These fields are additive and optional on decode
    /// so persisted 1.0.0 contexts remain replayable.
    let latestUserSourceRef: MentorSourceReference?
    let currentExchangeRefs: [MentorSourceReference]
    let conversationState: MentorConversationState
    let selectedMethod: CoachMethodSnapshot?

    init(
        schemaVersion: String,
        sessionID: UUID,
        semanticRevision: Int,
        requestEpoch: Int,
        initialEntry: String,
        intent: String,
        materialQuestionCount: Int,
        allowsMaterialQuestion: Bool,
        sources: [MentorContextSource],
        recentExchanges: [[MentorSourceReference]],
        lessonCandidates: [MentorLessonCandidateSummary],
        latestUserSourceRef: MentorSourceReference? = nil,
        currentExchangeRefs: [MentorSourceReference] = [],
        conversationState: MentorConversationState = .empty,
        selectedMethod: CoachMethodSnapshot? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.semanticRevision = semanticRevision
        self.requestEpoch = requestEpoch
        self.initialEntry = initialEntry
        self.intent = intent
        self.materialQuestionCount = materialQuestionCount
        self.allowsMaterialQuestion = allowsMaterialQuestion
        self.sources = sources
        self.recentExchanges = recentExchanges
        self.lessonCandidates = lessonCandidates
        self.latestUserSourceRef = latestUserSourceRef
        self.currentExchangeRefs = currentExchangeRefs
        self.conversationState = conversationState
        self.selectedMethod = selectedMethod
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        semanticRevision = try container.decode(Int.self, forKey: .semanticRevision)
        requestEpoch = try container.decode(Int.self, forKey: .requestEpoch)
        initialEntry = try container.decode(String.self, forKey: .initialEntry)
        intent = try container.decode(String.self, forKey: .intent)
        materialQuestionCount = try container.decode(Int.self, forKey: .materialQuestionCount)
        allowsMaterialQuestion = try container.decode(Bool.self, forKey: .allowsMaterialQuestion)
        sources = try container.decode([MentorContextSource].self, forKey: .sources)
        recentExchanges = try container.decode([[MentorSourceReference]].self, forKey: .recentExchanges)
        lessonCandidates = try container.decode([MentorLessonCandidateSummary].self, forKey: .lessonCandidates)
        latestUserSourceRef = try container.decodeIfPresent(MentorSourceReference.self, forKey: .latestUserSourceRef)
        currentExchangeRefs = try container.decodeIfPresent([MentorSourceReference].self, forKey: .currentExchangeRefs) ?? []
        conversationState = try container.decodeIfPresent(MentorConversationState.self, forKey: .conversationState) ?? .empty
        selectedMethod = try container.decodeIfPresent(CoachMethodSnapshot.self, forKey: .selectedMethod)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", sessionID = "session_id", semanticRevision = "semantic_revision"
        case requestEpoch = "request_epoch", initialEntry = "initial_entry", intent
        case materialQuestionCount = "material_question_count", allowsMaterialQuestion = "allows_material_question"
        case sources, recentExchanges = "recent_exchanges", lessonCandidates = "lesson_candidates"
        case latestUserSourceRef = "latest_user_source_ref", currentExchangeRefs = "current_exchange_refs"
        case conversationState = "conversation_state", selectedMethod = "selected_method"
    }
}

struct MentorBuiltContext {
    let payload: MentorContextPayload
    let json: String
    let validation: MentorResponseValidationContext
    let omittedItemIDs: [UUID]
}

enum MentorContextError: Error, Equatable {
    case invalidTimeline
    case invalidCorrection
    case invalidUserPayload(UUID)
    case invalidLesson
    case invalidUnderstanding
    case invalidIntent
    case invalidBudget
    case invalidMaterialSelection
    case missingCurrentUserSelection
    case requiresMaterialSelection(characterCount: Int, limit: Int)
}

/// Pure preparation of one session's data. Repository ownership and the request epoch
/// must be checked again when submitting; this object never fetches unrelated history.
struct MentorContextBuilder {
    /// Split only for an explicit user choice. No part of the stored source is
    /// deleted or silently shortened in the normal context path.
    static func materialSelectionCandidates(items: [MentorTimelineItem], maximumCharacters: Int = 900,
                                            currentUserSourceID: UUID? = nil) -> [MentorMaterialFragment] {
        guard maximumCharacters > 0 else { return [] }
        var result: [MentorMaterialFragment] = []
        for item in items.sorted(by: { $0.sequence < $1.sequence }) {
          for (field, text) in selectableParts(item) {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let characters = Array(text)
            let chunks: [[Character]]
            if characters.count <= maximumCharacters {
                chunks = [characters]
            } else {
                chunks = stride(from: 0, to: characters.count, by: maximumCharacters).map { start in
                    Array(characters[start ..< min(start + maximumCharacters, characters.count)])
                }
            }
            for (index, chunk) in chunks.enumerated() where !chunk.isEmpty {
                let sourceLabel: String
                switch field {
                case .userText: sourceLabel = item.id == currentUserSourceID ? "本轮输入" : "原话第 \(item.sequence) 条"
                case .assistantBody: sourceLabel = "老师回应第 \(item.sequence) 条 · 正文"
                case .assistantQuestion: sourceLabel = "老师回应第 \(item.sequence) 条 · 提问"
                }
                result.append(MentorMaterialFragment(id: UUID(), sourceID: item.id,
                    label: "\(sourceLabel) · 片段 \(index + 1)/\(chunks.count)", text: String(chunk), field: field))
            }
          }
        }
        return result
    }

    private static func selectableParts(_ item: MentorTimelineItem) -> [(MentorMaterialFragment.Field, String)] {
        guard let object = try? JSONSerialization.jsonObject(with: Data(item.payloadJSON.utf8)) as? [String: Any] else { return [] }
        switch item.kind {
        case .user:
            return (object["text"] as? String).map { [(.userText, $0)] } ?? []
        case .assistant:
            var parts: [(MentorMaterialFragment.Field, String)] = []
            if let body = object["body"] as? String { parts.append((.assistantBody, body)) }
            if let question = object["question"] as? String { parts.append((.assistantQuestion, question)) }
            return parts
        default: return []
        }
    }

    /// Retry the same frozen evidence, changing only the lifecycle epoch.
    func replay(json: String, session: MentorSession) throws -> MentorBuiltContext {
        var payload = try JSONDecoder().decode(MentorContextPayload.self, from: Data(json.utf8))
        guard payload.schemaVersion == "1.0.0", payload.sessionID == session.id,
              payload.semanticRevision == session.semanticRevision,
              payload.materialQuestionCount == session.recallCount else { throw MentorContextError.invalidTimeline }
        payload.requestEpoch = session.requestEpoch
        let candidateRefs = try payload.lessonCandidates.map { try MentorSourceReference("lesson:\($0.id)@\($0.version)") }
        let context = try MentorResponseValidationContext(
            sentSources: Set(payload.sources.map(\.ref) + candidateRefs),
            userExpressionSources: Set(payload.sources.filter { ($0.role == .user || $0.role == .understanding) && $0.isCurrent }.map(\.ref)),
            supersededSources: Set(payload.sources.filter { !$0.isCurrent }.map(\.ref)),
            eligibleLessons: Set(payload.lessonCandidates.map { MentorLessonReference(id: $0.id, version: $0.version) }),
            materialQuestionCount: session.recallCount, intent: payload.intent == "explain" ? .directTeaching : .discuss,
            previousAssistantQuestion: payload.conversationState.previousAssistantQuestion,
            latestUserExpressionSource: payload.latestUserSourceRef)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return MentorBuiltContext(payload: payload, json: String(decoding: try encoder.encode(payload), as: UTF8.self),
            validation: context, omittedItemIDs: [])
    }

    func build(session: MentorSession, items: [MentorTimelineItem], intent: String,
               responseIntent: MentorResponseValidationContext.Intent = .discuss,
               currentLesson: MentorSavedLesson? = nil, selectedUnderstanding: MentorUnderstanding? = nil,
               eligibleLessons: [MentorLesson] = [], characterLimit: Int = 24_000,
               selectedMaterialFragments: [MentorMaterialFragment] = [],
               suppressCurrentUserAnchor: Bool = false,
               selectedMethod: CoachMethodSnapshot? = nil) throws -> MentorBuiltContext {
        guard characterLimit > 0, characterLimit <= 24_000 else { throw MentorContextError.invalidBudget }
        guard !intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MentorContextError.invalidIntent }
        let ordered = items.sorted { $0.sequence < $1.sequence }
        guard Set(items.map(\.id)).count == items.count, Set(items.map(\.sequence)).count == items.count,
              items.allSatisfy({ $0.sessionID == session.id && $0.sequence > 0 }) else { throw MentorContextError.invalidTimeline }
        let byID = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
        var successors: [UUID: UUID] = [:]
        for item in ordered {
            if let parentID = item.supersedesItemID {
                guard item.kind == .user, let parent = byID[parentID], parent.kind == .user,
                      parent.sequence < item.sequence, successors[parentID] == nil else { throw MentorContextError.invalidCorrection }
                successors[parentID] = item.id
            }
        }
        func ref(_ id: UUID) throws -> MentorSourceReference { try MentorSourceReference("item:" + id.uuidString) }
        let selectedBySource = Dictionary(grouping: selectedMaterialFragments, by: \.sourceID)
        let isExplicitSelection = !selectedMaterialFragments.isEmpty
        if isExplicitSelection {
            for fragment in selectedMaterialFragments {
                guard let item = byID[fragment.sourceID], !fragment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      Self.selectableParts(item).contains(where: { $0.0 == fragment.field && $0.1.contains(fragment.text) }) else {
                    throw MentorContextError.invalidMaterialSelection
                }
            }
            if !suppressCurrentUserAnchor, let latest = ordered.last(where: { $0.kind == .user }),
               selectedBySource[latest.id] == nil {
                throw MentorContextError.missingCurrentUserSelection
            }
        }
        var userSources: [MentorContextSource] = []
        for item in ordered where item.kind == .user {
            guard let value = try? JSONSerialization.jsonObject(with: Data(item.payloadJSON.utf8)) as? [String: String],
                  Set(value.keys) == ["text"], let text = value["text"], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MentorContextError.invalidUserPayload(item.id)
            }
            let sourceText: String
            if isExplicitSelection {
                guard let fragments = selectedBySource[item.id] else { continue }
                sourceText = fragments.map(\.text).joined(separator: "\n")
            } else {
                sourceText = text
            }
            userSources.append(MentorContextSource(ref: try ref(item.id), role: .user, content: sourceText,
                supersedes: try item.supersedesItemID.map(ref), isCurrent: successors[item.id] == nil))
        }
        // Preserve every subsequent user expression, including natural-language corrections
        // with no explicit supersedes link. Never pin the first claim and discard its correction.
        var exchanges: [[MentorTimelineItem]] = []
        for item in ordered where item.kind != .lesson {
            if item.kind == .user || exchanges.isEmpty { exchanges.append([item]) }
            else { exchanges[exchanges.count - 1].append(item) }
        }
        // Keep the logical turn count separate from the request window. The
        // model needs to know how far the conversation has progressed even
        // when older exchanges are omitted for size. A short follow-up also
        // needs the immediately preceding assistant response, so compression
        // may not remove the final two exchange groups in that shape.
        let visibleTurnIndex = max(1, exchanges.count)
        if isExplicitSelection {
            exchanges = exchanges.map { $0.filter { selectedBySource[$0.id] != nil } }.filter { !$0.isEmpty }
        } else {
            exchanges = Array(exchanges.suffix(6))
        }
        var attachments: [MentorContextSource] = []
        if let saved = currentLesson {
            guard saved.sessionID == session.id, let item = byID[saved.id], item.kind == .lesson,
                  saved.lesson.contentHash == MentorLessonCatalog.contentHash(for: saved.lesson) else { throw MentorContextError.invalidLesson }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            guard let stored = try? decoder.decode(MentorLesson.self, from: Data(item.payloadJSON.utf8)), stored == saved.lesson else {
                throw MentorContextError.invalidLesson
            }
            attachments.append(MentorContextSource(ref: try MentorSourceReference("lesson:\(saved.lesson.id)@\(saved.lesson.version)"),
                role: .lesson, content: item.payloadJSON, supersedes: nil, isCurrent: true))
        }
        if let understanding = selectedUnderstanding {
            guard understanding.sessionID == session.id, understanding.state == .confirmed,
                  understanding.confirmedAt != nil, !understanding.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MentorContextError.invalidUnderstanding
            }
            attachments.append(MentorContextSource(ref: try MentorSourceReference("understanding:" + understanding.id.uuidString),
                role: .understanding, content: understanding.text, supersedes: nil, isCurrent: true))
        }
        guard Set(eligibleLessons.map { $0.id }).count == eligibleLessons.count,
              eligibleLessons.allSatisfy({ $0.review.status == .approved && $0.contentHash == MentorLessonCatalog.contentHash(for: $0) }) else {
            throw MentorContextError.invalidLesson
        }
        var candidates = eligibleLessons.sorted { $0.editorialOrder < $1.editorialOrder }.map {
            MentorLessonCandidateSummary(id: $0.id, version: $0.version, title: $0.title, theme: $0.theme,
                claim: $0.claim, applicableContexts: $0.applicableContexts)
        }
        let latestCorrectionSequence = ordered.filter { $0.supersedesItemID != nil }.map(\.sequence).max() ?? 0
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        while true {
            let assistantItems = exchanges.flatMap { $0 }.filter { $0.kind == .assistant }
            let assistantSources = try assistantItems.map { item in
                let content: String
                if isExplicitSelection {
                    let fragments = selectedBySource[item.id] ?? []
                    var selected: [String: String] = [:]
                    let body = fragments.filter { $0.field == .assistantBody }.map(\.text)
                    let question = fragments.filter { $0.field == .assistantQuestion }.map(\.text)
                    if !body.isEmpty { selected["body"] = body.joined(separator: "\n") }
                    if !question.isEmpty { selected["question"] = question.joined(separator: "\n") }
                    content = String(decoding: try encoder.encode(selected), as: UTF8.self)
                } else {
                    content = item.payloadJSON
                }
                return MentorContextSource(ref: try ref(item.id), role: .assistant, content: content,
                    supersedes: nil, isCurrent: item.sequence > latestCorrectionSequence)
            }
            let sources = userSources + assistantSources + attachments
            let currentExchange = exchanges.last ?? []
            let latestUserItem = suppressCurrentUserAnchor ? nil : currentExchange.last(where: { $0.kind == .user })
            let previousAssistant: MentorTimelineItem? = {
                if isExplicitSelection {
                    // Omitted replies must not make an older selected reply
                    // appear immediately adjacent to the current request.
                    let boundary = latestUserItem?.sequence ?? Int.max
                    let actual = ordered.last { $0.kind == .assistant && $0.sequence < boundary }
                    guard let actual, selectedBySource[actual.id] != nil else { return nil }
                    return actual
                }
                if latestUserItem != nil {
                    return exchanges.dropLast().last?.last(where: { $0.kind == .assistant })
                }
                return currentExchange.last(where: { $0.kind == .assistant })
                    ?? exchanges.dropLast().last?.last(where: { $0.kind == .assistant })
            }()
            // A short follow-up such as “这是什么意思？” belongs to the
            // previous assistant response as well as the new user item. Keep
            // that adjacent response explicit so the model can resolve
            // ellipsis without treating an older question as the new ask.
            let adjacentAssistant: MentorTimelineItem? = {
                guard currentExchange.count == 1, currentExchange.first?.kind == .user else { return nil }
                return previousAssistant
            }()
            let currentContextItems = (adjacentAssistant.map { [$0] } ?? []) + currentExchange
            let latestUserSourceRef = try latestUserItem.map { try ref($0.id) }
            let currentExchangeRefs = try currentContextItems.map { try ref($0.id) }
            let previousAssistantQuestion: (String, MentorQuestionPurpose?)? = {
                guard let previousAssistant,
                      let source = assistantSources.first(where: { $0.ref.value == "item:" + previousAssistant.id.uuidString }),
                      let data = source.content.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let raw = object["question"] as? String else { return nil }
                let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !question.isEmpty else { return nil }
                let purpose = (object["question_purpose"] as? String).flatMap(MentorQuestionPurpose.init(rawValue:))
                return (question, purpose)
            }()
            var conversationState = MentorConversationState(
                visibleTurnIndex: visibleTurnIndex,
                hasNewUserExpression: latestUserItem != nil,
                previousAssistantRef: try previousAssistant.map { try ref($0.id) },
                previousAssistantQuestion: previousAssistantQuestion?.0,
                previousAssistantQuestionPurpose: previousAssistantQuestion?.1)
            if isExplicitSelection { conversationState.usesSelectedExcerpts = true }
            let payload = MentorContextPayload(schemaVersion: "1.0.0", sessionID: session.id,
                semanticRevision: session.semanticRevision, requestEpoch: session.requestEpoch,
                initialEntry: session.initialEntry, intent: intent, materialQuestionCount: session.recallCount,
                allowsMaterialQuestion: session.recallCount < 2 && responseIntent != .directTeaching && responseIntent != .finish,
                sources: sources, recentExchanges: try exchanges.map { try $0.map { try ref($0.id) } }, lessonCandidates: candidates,
                latestUserSourceRef: latestUserSourceRef, currentExchangeRefs: currentExchangeRefs,
                conversationState: conversationState, selectedMethod: selectedMethod)
            let json = String(decoding: try encoder.encode(payload), as: UTF8.self)
            let length = json.unicodeScalars.count
            if length <= characterLimit {
                let candidateRefs = try candidates.map { try MentorSourceReference("lesson:\($0.id)@\($0.version)") }
                let sent = Set(sources.map(\.ref) + candidateRefs)
                let userExpressions = Set(sources.filter { ($0.role == .user || $0.role == .understanding) && $0.isCurrent }.map(\.ref))
                let validation = try MentorResponseValidationContext(sentSources: sent, userExpressionSources: userExpressions,
                    supersededSources: Set(sources.filter { !$0.isCurrent }.map(\.ref)),
                    eligibleLessons: Set(candidates.map { MentorLessonReference(id: $0.id, version: $0.version) }),
                    materialQuestionCount: session.recallCount, intent: responseIntent,
                    previousAssistantQuestion: conversationState.previousAssistantQuestion,
                    latestUserExpressionSource: latestUserSourceRef)
                let retained = Set(userSources.map(\.ref) + assistantSources.map(\.ref))
                let omitted = try ordered.filter { item in
                    if item.kind == .lesson { return item.id != currentLesson?.id }
                    return !retained.contains(try ref(item.id))
                }.map(\.id)
                return MentorBuiltContext(payload: payload, json: json, validation: validation, omittedItemIDs: omitted)
            }
            // Remove entire candidate summaries, so the model never receives opaque IDs.
            if !candidates.isEmpty { candidates.removeLast(); continue }
            // Older conversational groups may go; user evidence remains independently intact.
            let minimumExchangesToKeep = latestUserItem != nil && currentExchange.count == 1 ? 2 : 1
            if !isExplicitSelection, exchanges.count > minimumExchangesToKeep { exchanges.removeFirst(); continue }
            throw MentorContextError.requiresMaterialSelection(characterCount: length, limit: characterLimit)
        }
    }
}
