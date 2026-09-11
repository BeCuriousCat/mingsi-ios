import Foundation
import CryptoKit

struct MentorLessonPack: Codable, Equatable {
    let schemaVersion: String
    let packID: String
    let version: String
    let lessons: [MentorLesson]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case packID = "pack_id"
        case version
        case lessons
    }
}

struct MentorLesson: Codable, Equatable, Identifiable {
    let id: String
    let version: String
    let editorialOrder: Int
    let title: String
    let theme: Theme
    let applicableContexts: [String]
    let claim: String
    let example: String
    let boundary: String
    let observation: String?
    let sourceType: SourceType
    let citations: [Citation]
    let contentHash: String
    let review: Review

    enum Theme: String, Codable, CaseIterable {
        case observation, evidence, tradeoff, communication, iteration, attention
    }

    enum SourceType: String, Codable {
        case teachingExample = "teaching_example"
        case externalReference = "external_reference"
    }

    struct Citation: Codable, Equatable {
        let title: String
        let url: String
    }

    struct Review: Codable, Equatable {
        let status: Status
        let reviewedBy: String?
        let reviewedAt: Date?
        let note: String?

        enum Status: String, Codable { case draft, approved, rejected }

        enum CodingKeys: String, CodingKey {
            case status
            case reviewedBy = "reviewed_by"
            case reviewedAt = "reviewed_at"
            case note
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, version
        case editorialOrder = "editorial_order"
        case title, theme
        case applicableContexts = "applicable_contexts"
        case claim, example, boundary, observation
        case sourceType = "source_type"
        case citations
        case contentHash = "content_hash"
        case review
    }
}

enum MentorLessonValidationError: Error, Equatable, LocalizedError {
    case invalidField(String)
    case unapprovedLesson(String)
    case changedVersion(String)
    case missingResource(String)
    case invalidSchemaVersion(String)
    case invalidPackCount(Int)
    case duplicateLessonID(String)
    case duplicateEditorialOrder(Int)
    case invalidEditorialOrder(Int)
    case missingThemeDistribution(MentorLesson.Theme)
    case missingRequiredLesson(String)
    case invalidReview(String)
    case invalidCitations(String)
    case invalidContentHash(String)

    var errorDescription: String {
        switch self {
        case .invalidField(let field): return "Invalid lesson field: \(field)"
        case .unapprovedLesson(let id): return "Lesson is not approved for release: \(id)"
        case .changedVersion(let id): return "Lesson content changed without a new version: \(id)"
        case .missingResource(let name): return "Lesson resource is missing: \(name)"
        case .invalidSchemaVersion(let value): return "Unsupported lesson pack schema version: \(value)"
        case .invalidPackCount(let count): return "Expected exactly 24 lessons, got \(count)"
        case .duplicateLessonID(let id): return "Duplicate lesson ID: \(id)"
        case .duplicateEditorialOrder(let order): return "Duplicate editorial order: \(order)"
        case .invalidEditorialOrder(let order): return "Invalid editorial order: \(order)"
        case .missingThemeDistribution(let theme): return "Theme does not contain four lessons: \(theme.rawValue)"
        case .missingRequiredLesson(let id): return "Required lesson is missing: \(id)"
        case .invalidReview(let id): return "Approved or rejected lesson lacks review metadata: \(id)"
        case .invalidCitations(let id): return "Citation policy failed for lesson: \(id)"
        case .invalidContentHash(let id): return "Invalid content hash for lesson: \(id)"
        }
    }
}

struct MentorLessonCatalog {
    enum ValidationMode { case release, editorialPreview }
    let pack: MentorLessonPack

    init(pack: MentorLessonPack, mode: ValidationMode = .release, previous: MentorLessonCatalog? = nil) throws {
        try Self.validate(pack, mode: mode)
        if let previous {
            for lesson in pack.lessons {
                if let old = previous.lesson(id: lesson.id, version: lesson.version), old.contentHash != lesson.contentHash {
                    throw MentorLessonValidationError.changedVersion(lesson.id)
                }
            }
        }
        self.pack = pack
    }

    init(jsonData: Data, mode: ValidationMode = .release, previous: MentorLessonCatalog? = nil) throws {
        try Self.validateJSONShape(jsonData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
                throw MentorLessonValidationError.invalidField("review.reviewed_at")
            }
            return date
        }
        try self.init(pack: decoder.decode(MentorLessonPack.self, from: jsonData), mode: mode, previous: previous)
    }

    /// Missing or invalid resources are explicit failures; callers can offer history or exit.
    /// Production loading always enforces approval, even if editorial tools accept drafts.
    static func loadBundled(bundle: Bundle = .main, resource: String = "mentor-lessons-m1", previous: MentorLessonCatalog? = nil) throws -> MentorLessonCatalog {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw MentorLessonValidationError.missingResource(resource)
        }
        return try MentorLessonCatalog(jsonData: Data(contentsOf: url), previous: previous)
    }

    var lessonsInEditorialOrder: [MentorLesson] {
        pack.lessons.sorted { $0.editorialOrder < $1.editorialOrder }
    }

    func lesson(id: String, version: String) -> MentorLesson? {
        pack.lessons.first { $0.id == id && $0.version == version }
    }

    static func validate(_ pack: MentorLessonPack, mode: ValidationMode = .release) throws {
        guard pack.schemaVersion == "1.0.0" else { throw MentorLessonValidationError.invalidSchemaVersion(pack.schemaVersion) }
        try pattern(pack.packID, #"^[a-z][a-z0-9._-]{0,79}$"#, field: "pack_id")
        try version(pack.version, field: "version")
        guard pack.lessons.count == 24 else { throw MentorLessonValidationError.invalidPackCount(pack.lessons.count) }
        var ids = Set<String>()
        var orders = Set<Int>()
        for lesson in pack.lessons {
            try pattern(lesson.id, #"^L[0-9]{2}$"#, field: "id")
            try version(lesson.version, field: "\(lesson.id).version")
            guard ids.insert(lesson.id).inserted else { throw MentorLessonValidationError.duplicateLessonID(lesson.id) }
            guard (1...24).contains(lesson.editorialOrder) else { throw MentorLessonValidationError.invalidEditorialOrder(lesson.editorialOrder) }
            guard orders.insert(lesson.editorialOrder).inserted else { throw MentorLessonValidationError.duplicateEditorialOrder(lesson.editorialOrder) }
            try nonblank(lesson.title, max: 200, field: "\(lesson.id).title")
            for (field, text) in [("claim", lesson.claim), ("example", lesson.example), ("boundary", lesson.boundary)] {
                try nonblank(text, max: 4000, field: "\(lesson.id).\(field)")
            }
            if let text = lesson.observation { try nonblank(text, max: 4000, field: "\(lesson.id).observation") }
            guard (1...12).contains(lesson.applicableContexts.count), Set(lesson.applicableContexts).count == lesson.applicableContexts.count else {
                throw MentorLessonValidationError.invalidField("\(lesson.id).applicable_contexts")
            }
            for text in lesson.applicableContexts { try nonblank(text, max: 500, field: "\(lesson.id).applicable_contexts") }
            guard lesson.citations.count <= 20 else { throw MentorLessonValidationError.invalidCitations(lesson.id) }
            if lesson.sourceType == .teachingExample, !lesson.citations.isEmpty { throw MentorLessonValidationError.invalidCitations(lesson.id) }
            if lesson.sourceType == .externalReference && lesson.citations.isEmpty { throw MentorLessonValidationError.invalidCitations(lesson.id) }
            for (index, citation) in lesson.citations.enumerated() {
                try nonblank(citation.title, max: 300, field: "\(lesson.id).citation.title")
                guard citation.url.unicodeScalars.count <= 2048,
                      citation.url.range(of: #"\s"#, options: .regularExpression) == nil,
                      let url = URLComponents(string: citation.url), ["http", "https"].contains(url.scheme),
                      url.host?.isEmpty == false,
                      !lesson.citations.prefix(index).contains(citation) else {
                    throw MentorLessonValidationError.invalidCitations(lesson.id)
                }
            }
            if let reviewer = lesson.review.reviewedBy { try nonblank(reviewer, max: 120, field: "\(lesson.id).reviewed_by") }
            if let note = lesson.review.note, note.unicodeScalars.count > 2000 { throw MentorLessonValidationError.invalidReview(lesson.id) }
            if let date = lesson.review.reviewedAt, !date.timeIntervalSince1970.isFinite { throw MentorLessonValidationError.invalidReview(lesson.id) }
            if lesson.review.status != .draft && (lesson.review.reviewedBy == nil || lesson.review.reviewedAt == nil) { throw MentorLessonValidationError.invalidReview(lesson.id) }
            guard lesson.contentHash == contentHash(for: lesson) else { throw MentorLessonValidationError.invalidContentHash(lesson.id) }
            if mode == .release, lesson.review.status != .approved { throw MentorLessonValidationError.unapprovedLesson(lesson.id) }
        }
        for theme in MentorLesson.Theme.allCases where pack.lessons.filter({ $0.theme == theme }).count != 4 {
            throw MentorLessonValidationError.missingThemeDistribution(theme)
        }
        for id in ["L01", "L02"] where !ids.contains(id) { throw MentorLessonValidationError.missingRequiredLesson(id) }
    }

    /// RFC 8785 for this contract's content object: only strings, arrays and objects.
    /// Editorial order, approval and pack metadata deliberately do not affect content identity.
    static func contentHash(for lesson: MentorLesson) -> String {
        let digest = SHA256.hash(data: canonicalContent(for: lesson))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    static func canonicalContent(for lesson: MentorLesson) -> Data {
        var fields: [String: CanonicalValue] = [
            "id": .string(lesson.id), "version": .string(lesson.version), "title": .string(lesson.title),
            "theme": .string(lesson.theme.rawValue), "applicable_contexts": .array(lesson.applicableContexts.map(CanonicalValue.string)),
            "claim": .string(lesson.claim), "example": .string(lesson.example), "boundary": .string(lesson.boundary),
            "source_type": .string(lesson.sourceType.rawValue),
            "citations": .array(lesson.citations.map { .object(["title": .string($0.title), "url": .string($0.url)]) })
        ]
        if let observation = lesson.observation { fields["observation"] = .string(observation) }
        return Data(CanonicalValue.object(fields).serialized.utf8)
    }

    private static func nonblank(_ value: String, max: Int, field: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.unicodeScalars.count <= max else {
            throw MentorLessonValidationError.invalidField(field)
        }
    }

    private static func pattern(_ value: String, _ regex: String, field: String) throws {
        guard let range = value.range(of: regex, options: .regularExpression), range == value.startIndex..<value.endIndex else {
            throw MentorLessonValidationError.invalidField(field)
        }
    }

    private static func version(_ value: String, field: String) throws {
        guard value.unicodeScalars.count <= 32 else { throw MentorLessonValidationError.invalidField(field) }
        try pattern(value, #"^[0-9]+\.[0-9]+(?:\.[0-9]+)?$"#, field: field)
    }

    /// Codable ignores unknown keys and accepts null optionals; the published schema does neither.
    private static func validateJSONShape(_ data: Data) throws {
        func object(_ value: Any, required: Set<String>, optional: Set<String> = [], field: String) throws -> [String: Any] {
            guard let object = value as? [String: Any], required.isSubset(of: Set(object.keys)),
                  Set(object.keys).isSubset(of: required.union(optional)),
                  !object.values.contains(where: { $0 is NSNull }) else {
                throw MentorLessonValidationError.invalidField(field)
            }
            return object
        }
        let raw = try JSONSerialization.jsonObject(with: data)
        let pack = try object(raw, required: ["schema_version", "pack_id", "version", "lessons"], field: "pack")
        guard let lessons = pack["lessons"] as? [Any] else { throw MentorLessonValidationError.invalidField("lessons") }
        for value in lessons {
            let lesson = try object(value, required: ["id", "version", "editorial_order", "title", "theme", "applicable_contexts", "claim", "example", "boundary", "source_type", "citations", "content_hash", "review"], optional: ["observation"], field: "lesson")
            _ = try object(lesson["review"]!, required: ["status"], optional: ["reviewed_by", "reviewed_at", "note"], field: "review")
            guard let citations = lesson["citations"] as? [Any] else { throw MentorLessonValidationError.invalidField("citations") }
            for value in citations { _ = try object(value, required: ["title", "url"], field: "citation") }
        }
    }
}

private indirect enum CanonicalValue {
    case string(String), array([CanonicalValue]), object([String: CanonicalValue])

    var serialized: String {
        switch self {
        case .string(let value):
            var result = "\""
            for scalar in value.unicodeScalars {
                switch scalar.value {
                case 0x22: result += "\\\""
                case 0x5c: result += "\\\\"
                case 0x08: result += "\\b"
                case 0x09: result += "\\t"
                case 0x0a: result += "\\n"
                case 0x0c: result += "\\f"
                case 0x0d: result += "\\r"
                case 0..<0x20: result += String(format: "\\u%04x", scalar.value)
                default: result.unicodeScalars.append(scalar)
                }
            }
            return result + "\""
        case .array(let values): return "[" + values.map(\.serialized).joined(separator: ",") + "]"
        case .object(let values):
            let keys = values.keys.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
            return "{" + keys.map { CanonicalValue.string($0).serialized + ":" + values[$0]!.serialized }.joined(separator: ",") + "}"
        }
    }
}
