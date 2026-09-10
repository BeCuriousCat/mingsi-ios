import Foundation

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
    let pack: MentorLessonPack

    init(pack: MentorLessonPack) throws {
        try Self.validate(pack)
        self.pack = pack
    }

    init(jsonData: Data, decoder: JSONDecoder = .mentorLessonDecoder) throws {
        try self.init(pack: decoder.decode(MentorLessonPack.self, from: jsonData))
    }

    var lessonsInEditorialOrder: [MentorLesson] {
        pack.lessons.sorted { $0.editorialOrder < $1.editorialOrder }
    }

    func lesson(id: String, version: String) -> MentorLesson? {
        pack.lessons.first { $0.id == id && $0.version == version }
    }

    static func validate(_ pack: MentorLessonPack) throws {
        guard pack.schemaVersion == "1.0.0" else { throw MentorLessonValidationError.invalidSchemaVersion(pack.schemaVersion) }
        guard pack.lessons.count == 24 else { throw MentorLessonValidationError.invalidPackCount(pack.lessons.count) }
        var ids = Set<String>()
        var orders = Set<Int>()
        for lesson in pack.lessons {
            guard ids.insert(lesson.id).inserted else { throw MentorLessonValidationError.duplicateLessonID(lesson.id) }
            guard (1...24).contains(lesson.editorialOrder) else { throw MentorLessonValidationError.invalidEditorialOrder(lesson.editorialOrder) }
            guard orders.insert(lesson.editorialOrder).inserted else { throw MentorLessonValidationError.duplicateEditorialOrder(lesson.editorialOrder) }
            guard lesson.contentHash.range(of: #"^sha256:[0-9a-f]{64}$"#, options: .regularExpression) != nil else { throw MentorLessonValidationError.invalidContentHash(lesson.id) }
            if lesson.sourceType == .teachingExample, !lesson.citations.isEmpty { throw MentorLessonValidationError.invalidCitations(lesson.id) }
            if lesson.sourceType == .externalReference && lesson.citations.isEmpty { throw MentorLessonValidationError.invalidCitations(lesson.id) }
            if lesson.review.status != .draft && (lesson.review.reviewedBy?.isEmpty != false || lesson.review.reviewedAt == nil) { throw MentorLessonValidationError.invalidReview(lesson.id) }
        }
        for theme in MentorLesson.Theme.allCases where pack.lessons.filter({ $0.theme == theme }).count != 4 {
            throw MentorLessonValidationError.missingThemeDistribution(theme)
        }
        for id in ["L01", "L02"] where !ids.contains(id) { throw MentorLessonValidationError.missingRequiredLesson(id) }
    }
}

private extension JSONDecoder {
    static let mentorLessonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
