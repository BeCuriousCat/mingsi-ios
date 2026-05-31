import Foundation
import GRDB

enum PersistenceError: Error {
    case unimplemented
    case invalidStoredValue(String)
}

protocol DailyEntryRepository {
    func saveDraft(_ draft: DailyEntryDraft) async throws
    func latestDraft() async throws -> DailyEntryDraft?
}

protocol ThinkingCardRepository {
    func saveCards(_ cards: [ThinkingCard], dailyEntryId: UUID) async throws
    func cards(for dailyEntryId: UUID) async throws -> [ThinkingCard]
}

protocol QuestRepository {
    func saveQuest(_ quest: Quest, sourceDailyEntryId: UUID) async throws
    func saveQuests(_ quests: [Quest], sourceDailyEntryId: UUID) async throws
    func activeMainQuest() async throws -> Quest?
    func quests(for dailyEntryId: UUID) async throws -> [Quest]
}

protocol PrincipleRepository {
    func savePrinciple(_ principle: PrincipleAsset, sourceDailyEntryId: UUID) async throws
    func savePrinciples(_ principles: [PrincipleAsset], sourceDailyEntryId: UUID) async throws
    func activePrinciples() async throws -> [PrincipleAsset]
    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset]
}

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        dbQueue = try DatabaseQueue(path: url.path)
        let migrator = Self.makeMigrator()
        try migrator.migrate(dbQueue)
    }

    static func defaultURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("mingsi.sqlite")
    }

    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_core_records") { db in
            try db.create(table: "daily_entries", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("date", .text).notNull()
                table.column("raw_text", .text).notNull()
                table.column("session_mode", .text).notNull()
                table.column("state", .text).notNull()
                table.column("privacy_flags_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "thinking_cards", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("daily_entry_id", .text).notNull()
                table.column("schema_version", .integer).notNull()
                table.column("type", .text).notNull()
                table.column("title", .text).notNull()
                table.column("body", .text).notNull()
                table.column("importance", .text).notNull()
                table.column("sensitivity", .text).notNull()
                table.column("confidence", .double).notNull()
                table.column("is_confirmed", .integer).notNull()
                table.column("is_excluded_from_model", .integer).notNull()
                table.column("source_refs_json", .text)
                table.column("raw_payload_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "quests", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("source_daily_entry_id", .text).notNull()
                table.column("schema_version", .integer).notNull()
                table.column("type", .text).notNull()
                table.column("title", .text).notNull()
                table.column("why_it_matters", .text).notNull()
                table.column("completion_criteria", .text).notNull()
                table.column("expected_resistance", .text)
                table.column("reflection_question", .text)
                table.column("status", .text).notNull()
                table.column("due_date", .text)
                table.column("reminder_id", .text)
                table.column("linked_card_ids_json", .text)
                table.column("raw_payload_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "principle_assets", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("title", .text).notNull()
                table.column("summary", .text).notNull()
                table.column("trigger_context", .text).notNull()
                table.column("actions_json", .text).notNull()
                table.column("success_criteria", .text).notNull()
                table.column("exceptions", .text)
                table.column("source_daily_entry_ids_json", .text)
                table.column("source_card_ids_json", .text)
                table.column("validation_count", .integer).notNull()
                table.column("last_validated_at", .text)
                table.column("status", .text).notNull()
                table.column("raw_payload_json", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
                table.column("deleted_at", .text)
            }

            try db.create(table: "prompt_runs", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("schema_version", .integer).notNull()
                table.column("prompt_id", .text).notNull()
                table.column("prompt_version", .text).notNull()
                table.column("input_schema_version", .integer).notNull()
                table.column("output_schema_version", .integer).notNull()
                table.column("model_provider", .text).notNull()
                table.column("model_name", .text).notNull()
                table.column("session_mode", .text).notNull()
                table.column("source_record_ids_json", .text)
                table.column("request_summary", .text)
                table.column("response_json", .text)
                table.column("error", .text)
                table.column("created_at", .text).notNull()
            }
        }

        migrator.registerMigration("v2_daily_loop_fields") { db in
            try db.alter(table: "daily_entries") { table in
                table.add(column: "has_selected_session_mode", .boolean).notNull().defaults(to: false)
                table.add(column: "selected_lens", .text)
                table.add(column: "yesterday_completion", .text)
                table.add(column: "yesterday_value_rating", .text)
            }
        }

        return migrator
    }
}

final class SQLiteDailyEntryRepository: DailyEntryRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveDraft(_ draft: DailyEntryDraft) async throws {
        try await database.dbQueue.write { db in
            var row = DailyEntryRow(draft: draft)
            if let existing = try DailyEntryRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func latestDraft() async throws -> DailyEntryDraft? {
        try await database.dbQueue.read { db in
            try DailyEntryRow
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }
}

final class SQLiteThinkingCardRepository: ThinkingCardRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveCards(_ cards: [ThinkingCard], dailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            let now = Date().mingsiStorageString
            let savedIDs = cards.map { $0.id.uuidString }
            let existingRows = try ThinkingCardRow
                .filter(Column("daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)

            for var row in existingRows where !savedIDs.contains(row.id) {
                row.deletedAt = now
                row.updatedAt = now
                try row.upsert(db)
            }

            for card in cards {
                var row = ThinkingCardRow(card: card, dailyEntryId: dailyEntryId)
                if let existing = try ThinkingCardRow.fetchOne(db, key: row.id) {
                    row.createdAt = existing.createdAt
                }
                try row.upsert(db)
            }
        }
    }

    func cards(for dailyEntryId: UUID) async throws -> [ThinkingCard] {
        try await database.dbQueue.read { db in
            try ThinkingCardRow
                .filter(Column("daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLiteQuestRepository: QuestRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func saveQuest(_ quest: Quest, sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            var row = QuestRow(quest: quest, sourceDailyEntryId: sourceDailyEntryId)
            if let existing = try QuestRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func saveQuests(_ quests: [Quest], sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            let now = Date().mingsiStorageString
            let savedIDs = quests.map { $0.id.uuidString }
            let existingRows = try QuestRow
                .filter(Column("source_daily_entry_id") == sourceDailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)

            for var row in existingRows where !savedIDs.contains(row.id) {
                row.deletedAt = now
                row.updatedAt = now
                try row.upsert(db)
            }

            for quest in quests {
                var row = QuestRow(quest: quest, sourceDailyEntryId: sourceDailyEntryId)
                if let existing = try QuestRow.fetchOne(db, key: row.id) {
                    row.createdAt = existing.createdAt
                }
                try row.upsert(db)
            }
        }
    }

    func activeMainQuest() async throws -> Quest? {
        try await database.dbQueue.read { db in
            try QuestRow
                .filter(Column("type") == QuestType.main.rawValue)
                .filter(Column("status") == QuestStatus.active.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchOne(db)?
                .domainModel()
        }
    }

    func quests(for dailyEntryId: UUID) async throws -> [Quest] {
        try await database.dbQueue.read { db in
            try QuestRow
                .filter(Column("source_daily_entry_id") == dailyEntryId.uuidString)
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

final class SQLitePrincipleRepository: PrincipleRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func savePrinciple(_ principle: PrincipleAsset, sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            var row = PrincipleAssetRow(principle: principle, sourceDailyEntryId: sourceDailyEntryId)
            if let existing = try PrincipleAssetRow.fetchOne(db, key: row.id) {
                row.createdAt = existing.createdAt
            }
            try row.upsert(db)
        }
    }

    func savePrinciples(_ principles: [PrincipleAsset], sourceDailyEntryId: UUID) async throws {
        try await database.dbQueue.write { db in
            let now = Date().mingsiStorageString
            let savedIDs = principles.map { $0.id.uuidString }
            let existingRows = try PrincipleAssetRow
                .filter(Column("source_daily_entry_ids_json").like("%\(sourceDailyEntryId.uuidString)%"))
                .filter(Column("deleted_at") == nil)
                .fetchAll(db)

            for var row in existingRows where !savedIDs.contains(row.id) {
                row.deletedAt = now
                row.updatedAt = now
                try row.upsert(db)
            }

            for principle in principles {
                var row = PrincipleAssetRow(principle: principle, sourceDailyEntryId: sourceDailyEntryId)
                if let existing = try PrincipleAssetRow.fetchOne(db, key: row.id) {
                    row.createdAt = existing.createdAt
                }
                try row.upsert(db)
            }
        }
    }

    func activePrinciples() async throws -> [PrincipleAsset] {
        try await database.dbQueue.read { db in
            try PrincipleAssetRow
                .filter(Column("status") == PrincipleStatus.active.rawValue)
                .filter(Column("deleted_at") == nil)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }

    func principles(for dailyEntryId: UUID) async throws -> [PrincipleAsset] {
        try await database.dbQueue.read { db in
            try PrincipleAssetRow
                .filter(Column("source_daily_entry_ids_json").like("%\(dailyEntryId.uuidString)%"))
                .filter(Column("deleted_at") == nil)
                .order(Column("created_at").asc)
                .fetchAll(db)
                .map { try $0.domainModel() }
        }
    }
}

private struct DailyEntryRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_entries"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var date: String
    var rawText: String
    var sessionMode: String
    var hasSelectedSessionMode: Bool
    var selectedLens: String?
    var yesterdayCompletion: String?
    var yesterdayValueRating: String?
    var state: String
    var privacyFlagsJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    enum Columns {
        static let id = Column(CodingKeys.id)
    }

    init(draft: DailyEntryDraft) {
        let now = Date().mingsiStorageString
        id = draft.id.uuidString
        schemaVersion = 1
        date = draft.date.mingsiStorageString
        rawText = draft.rawText
        sessionMode = draft.sessionMode.rawValue
        hasSelectedSessionMode = draft.hasSelectedSessionMode
        selectedLens = draft.selectedLens?.rawValue
        yesterdayCompletion = draft.yesterdayCompletion?.rawValue
        yesterdayValueRating = draft.yesterdayValueRating?.rawValue
        state = draft.state.rawValue
        privacyFlagsJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> DailyEntryDraft {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("daily_entries.id")
        }
        guard let mode = SessionMode(rawValue: sessionMode) else {
            throw PersistenceError.invalidStoredValue("daily_entries.session_mode")
        }
        guard let state = DailyLoopState(rawValue: state) else {
            throw PersistenceError.invalidStoredValue("daily_entries.state")
        }
        let lens: ThinkingLens?
        if let selectedLens {
            guard let parsedLens = ThinkingLens(rawValue: selectedLens) else {
                throw PersistenceError.invalidStoredValue("daily_entries.selected_lens")
            }
            lens = parsedLens
        } else {
            lens = nil
        }
        let completion: YesterdayCompletion?
        if let yesterdayCompletion {
            guard let parsedCompletion = YesterdayCompletion(rawValue: yesterdayCompletion) else {
                throw PersistenceError.invalidStoredValue("daily_entries.yesterday_completion")
            }
            completion = parsedCompletion
        } else {
            completion = nil
        }
        let valueRating: YesterdayValueRating?
        if let yesterdayValueRating {
            guard let parsedValueRating = YesterdayValueRating(rawValue: yesterdayValueRating) else {
                throw PersistenceError.invalidStoredValue("daily_entries.yesterday_value_rating")
            }
            valueRating = parsedValueRating
        } else {
            valueRating = nil
        }
        return DailyEntryDraft(
            id: uuid,
            date: Date(mingsiStorageString: date) ?? .now,
            rawText: rawText,
            sessionMode: mode,
            hasSelectedSessionMode: hasSelectedSessionMode,
            selectedLens: lens,
            yesterdayCompletion: completion,
            yesterdayValueRating: valueRating,
            state: state
        )
    }
}

private struct ThinkingCardRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "thinking_cards"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var dailyEntryId: String
    var schemaVersion: Int
    var type: String
    var title: String
    var body: String
    var importance: String
    var sensitivity: String
    var confidence: Double
    var isConfirmed: Bool
    var isExcludedFromModel: Bool
    var sourceRefsJson: String?
    var rawPayloadJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(card: ThinkingCard, dailyEntryId: UUID) {
        let now = Date().mingsiStorageString
        id = card.id.uuidString
        self.dailyEntryId = dailyEntryId.uuidString
        schemaVersion = 1
        type = card.type.rawValue
        title = card.title
        body = card.body
        importance = card.priority.rawValue
        sensitivity = card.sensitivity.storageValue
        confidence = card.confidence
        isConfirmed = card.isConfirmed
        isExcludedFromModel = card.isExcludedFromModel
        sourceRefsJson = try? PersistenceJSON.encode(card.sourceRefs)
        rawPayloadJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> ThinkingCard {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("thinking_cards.id")
        }
        guard let type = ThinkingCardType(rawValue: type) else {
            throw PersistenceError.invalidStoredValue("thinking_cards.type")
        }
        guard let priority = PriorityLevel(rawValue: importance) else {
            throw PersistenceError.invalidStoredValue("thinking_cards.importance")
        }
        let sensitivity = SensitivityLevel(storageValue: sensitivity)
        let refs: [String] = try PersistenceJSON.decode(sourceRefsJson) ?? []
        return ThinkingCard(
            id: uuid,
            type: type,
            title: title,
            body: body,
            priority: priority,
            sensitivity: sensitivity,
            confidence: confidence,
            isConfirmed: isConfirmed,
            isExcludedFromModel: isExcludedFromModel,
            sourceRefs: refs
        )
    }
}

private struct QuestRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "quests"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var sourceDailyEntryId: String
    var schemaVersion: Int
    var type: String
    var title: String
    var whyItMatters: String
    var completionCriteria: String
    var expectedResistance: String?
    var reflectionQuestion: String?
    var status: String
    var dueDate: String?
    var reminderId: String?
    var linkedCardIdsJson: String?
    var rawPayloadJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(quest: Quest, sourceDailyEntryId: UUID) {
        let now = Date().mingsiStorageString
        id = quest.id.uuidString
        self.sourceDailyEntryId = sourceDailyEntryId.uuidString
        schemaVersion = 1
        type = quest.type.rawValue
        title = quest.title
        whyItMatters = quest.whyItMatters
        completionCriteria = quest.completionCriteria
        expectedResistance = quest.expectedResistance
        reflectionQuestion = quest.reflectionQuestion
        status = quest.status.rawValue
        dueDate = nil
        reminderId = nil
        linkedCardIdsJson = nil
        rawPayloadJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> Quest {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("quests.id")
        }
        guard let type = QuestType(rawValue: type) else {
            throw PersistenceError.invalidStoredValue("quests.type")
        }
        guard let status = QuestStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("quests.status")
        }
        return Quest(
            id: uuid,
            type: type,
            title: title,
            whyItMatters: whyItMatters,
            completionCriteria: completionCriteria,
            expectedResistance: expectedResistance ?? "",
            reflectionQuestion: reflectionQuestion ?? "",
            status: status
        )
    }
}

private struct PrincipleAssetRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "principle_assets"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var id: String
    var schemaVersion: Int
    var title: String
    var summary: String
    var triggerContext: String
    var actionsJson: String
    var successCriteria: String
    var exceptions: String?
    var sourceDailyEntryIdsJson: String?
    var sourceCardIdsJson: String?
    var validationCount: Int
    var lastValidatedAt: String?
    var status: String
    var rawPayloadJson: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    init(principle: PrincipleAsset, sourceDailyEntryId: UUID) {
        let now = Date().mingsiStorageString
        id = principle.id.uuidString
        schemaVersion = 1
        title = principle.title
        summary = principle.summary
        triggerContext = principle.triggerContext
        actionsJson = (try? PersistenceJSON.encode(principle.actions)) ?? "[]"
        successCriteria = principle.successCriteria
        exceptions = principle.exceptions
        sourceDailyEntryIdsJson = try? PersistenceJSON.encode([sourceDailyEntryId.uuidString])
        sourceCardIdsJson = nil
        validationCount = 0
        lastValidatedAt = nil
        status = principle.status.rawValue
        rawPayloadJson = nil
        createdAt = now
        updatedAt = now
        deletedAt = nil
    }

    func domainModel() throws -> PrincipleAsset {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidStoredValue("principle_assets.id")
        }
        guard let status = PrincipleStatus(rawValue: status) else {
            throw PersistenceError.invalidStoredValue("principle_assets.status")
        }
        let actions: [String] = try PersistenceJSON.decode(actionsJson) ?? []
        return PrincipleAsset(
            id: uuid,
            title: title,
            summary: summary,
            triggerContext: triggerContext,
            actions: actions,
            successCriteria: successCriteria,
            exceptions: exceptions ?? "",
            status: status
        )
    }
}

private enum PersistenceJSON {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.invalidStoredValue("json_encoding")
        }
        return string
    }

    static func decode<T: Decodable>(_ json: String?) throws -> T? {
        guard let json, !json.isEmpty else { return nil }
        guard let data = json.data(using: .utf8) else {
            throw PersistenceError.invalidStoredValue("json_decoding")
        }
        return try decoder.decode(T.self, from: data)
    }

    static func decode<T: Decodable>(_ json: String) throws -> T? {
        try decode(Optional(json))
    }
}

private extension Date {
    static let mingsiStorageFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var mingsiStorageString: String {
        Self.mingsiStorageFormatter.string(from: self)
    }

    init?(mingsiStorageString: String) {
        guard let date = Self.mingsiStorageFormatter.date(from: mingsiStorageString) else {
            return nil
        }
        self = date
    }
}

private extension SensitivityLevel {
    var storageValue: String {
        switch self {
        case .normal: return "normal"
        case .possiblySensitive: return "possibly_sensitive"
        case .sensitive: return "sensitive"
        }
    }

    init(storageValue: String) {
        switch storageValue {
        case "possibly_sensitive":
            self = .possiblySensitive
        case "sensitive":
            self = .sensitive
        default:
            self = .normal
        }
    }
}
