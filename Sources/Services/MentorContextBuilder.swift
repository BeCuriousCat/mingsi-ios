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

struct MentorContextPayload: Codable, Equatable {
    let schemaVersion: String
    let sessionID: UUID
    let semanticRevision: Int
    let requestEpoch: Int
    let initialEntry: String
    let intent: String
    let materialQuestionCount: Int
    let allowsMaterialQuestion: Bool
    let sources: [MentorContextSource]
    let recentExchanges: [[MentorSourceReference]]
    let lessonCandidates: [MentorLessonCandidateSummary]
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", sessionID = "session_id", semanticRevision = "semantic_revision"
        case requestEpoch = "request_epoch", initialEntry = "initial_entry", intent
        case materialQuestionCount = "material_question_count", allowsMaterialQuestion = "allows_material_question"
        case sources, recentExchanges = "recent_exchanges", lessonCandidates = "lesson_candidates"
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
    case requiresMaterialSelection(characterCount: Int, limit: Int)
}

/// Pure preparation of one session's data. Repository ownership and the request epoch
/// must be checked again when submitting; this object never fetches unrelated history.
struct MentorContextBuilder {
    func build(session: MentorSession, items: [MentorTimelineItem], intent: String,
               responseIntent: MentorResponseValidationContext.Intent = .discuss,
               currentLesson: MentorSavedLesson? = nil, selectedUnderstanding: MentorUnderstanding? = nil,
               eligibleLessons: [MentorLesson] = [], characterLimit: Int = 24_000) throws -> MentorBuiltContext {
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
        var userSources: [MentorContextSource] = []
        for item in ordered where item.kind == .user {
            guard let value = try? JSONSerialization.jsonObject(with: Data(item.payloadJSON.utf8)) as? [String: String],
                  Set(value.keys) == ["text"], let text = value["text"], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MentorContextError.invalidUserPayload(item.id)
            }
            userSources.append(MentorContextSource(ref: try ref(item.id), role: .user, content: text,
                supersedes: try item.supersedesItemID.map(ref), isCurrent: successors[item.id] == nil))
        }
        // Preserve every subsequent user expression, including natural-language corrections
        // with no explicit supersedes link. Never pin the first claim and discard its correction.
        var exchanges: [[MentorTimelineItem]] = []
        for item in ordered where item.kind != .lesson {
            if item.kind == .user || exchanges.isEmpty { exchanges.append([item]) }
            else { exchanges[exchanges.count - 1].append(item) }
        }
        exchanges = Array(exchanges.suffix(6))
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
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        while true {
            let assistantItems = exchanges.flatMap { $0 }.filter { $0.kind == .assistant }
            let assistantSources = try assistantItems.map {
                MentorContextSource(ref: try ref($0.id), role: .assistant, content: $0.payloadJSON, supersedes: nil, isCurrent: true)
            }
            let sources = userSources + assistantSources + attachments
            let payload = MentorContextPayload(schemaVersion: "1.0.0", sessionID: session.id,
                semanticRevision: session.semanticRevision, requestEpoch: session.requestEpoch,
                initialEntry: session.initialEntry, intent: intent, materialQuestionCount: session.recallCount,
                allowsMaterialQuestion: session.recallCount < 2 && responseIntent != .directTeaching && responseIntent != .finish,
                sources: sources, recentExchanges: try exchanges.map { try $0.map { try ref($0.id) } }, lessonCandidates: candidates)
            let json = String(decoding: try encoder.encode(payload), as: UTF8.self)
            let length = json.unicodeScalars.count
            if length <= characterLimit {
                let candidateRefs = try candidates.map { try MentorSourceReference("lesson:\($0.id)@\($0.version)") }
                let sent = Set(sources.map(\.ref) + candidateRefs)
                let userExpressions = Set(sources.filter { ($0.role == .user || $0.role == .understanding) && $0.isCurrent }.map(\.ref))
                let validation = try MentorResponseValidationContext(sentSources: sent, userExpressionSources: userExpressions,
                    supersededSources: Set(sources.filter { !$0.isCurrent }.map(\.ref)),
                    eligibleLessons: Set(candidates.map { MentorLessonReference(id: $0.id, version: $0.version) }),
                    materialQuestionCount: session.recallCount, intent: responseIntent)
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
            if exchanges.count > 1 { exchanges.removeFirst(); continue }
            throw MentorContextError.requiresMaterialSelection(characterCount: length, limit: characterLimit)
        }
    }
}
