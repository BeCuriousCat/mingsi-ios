import XCTest
import GRDB
@testable import MingSi

final class PersistenceCoreTests: XCTestCase {

    private var database: AppDatabase!
    private var dbQueue: DatabaseQueue!

    override func setUp() throws {
        try super.setUp()
        dbQueue = try DatabaseQueue()
        // Run migrations manually on the in-memory queue
        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(dbQueue)
        database = AppDatabase(dbQueue: dbQueue)
    }

    override func tearDown() {
        database = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - DailyEntryRepository

    func testSaveDraft_andLoadLatest() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let draft = DailyEntryDraft(
            rawText: "Test raw text for persistence.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .evidenceCheck,
            yesterdayCompletion: .done,
            yesterdayValueRating: .high,
            state: .capture
        )

        try await repo.saveDraft(draft)

        let loaded = try await repo.latestDraft()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.rawText, "Test raw text for persistence.")
        XCTAssertEqual(loaded?.sessionMode, .standard)
        XCTAssertTrue(loaded?.hasSelectedSessionMode == true)
        XCTAssertEqual(loaded?.selectedLens, .evidenceCheck)
        XCTAssertEqual(loaded?.yesterdayCompletion, .done)
        XCTAssertEqual(loaded?.yesterdayValueRating, .high)
        XCTAssertEqual(loaded?.state, .capture)
    }

    func testSaveDraft_upsertPreservesCreatedAt() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let draft = DailyEntryDraft(rawText: "First save", state: .capture)

        try await repo.saveDraft(draft)

        let first = try await repo.latestDraft()
        let firstCreatedAt = first.map { readCreatedAt(for: $0.id) }

        var updatedDraft = draft
        updatedDraft.rawText = "Second save"
        updatedDraft.state = .reviewCards
        try await repo.saveDraft(updatedDraft)

        let second = try await repo.latestDraft()
        XCTAssertEqual(second?.rawText, "Second save")
        XCTAssertEqual(second?.state, .reviewCards)
        XCTAssertEqual(second?.id, draft.id)

        let secondCreatedAt = second.map { readCreatedAt(for: $0.id) }
        XCTAssertEqual(firstCreatedAt, secondCreatedAt)
    }

    func testLatestDraft_returnsMostRecentlyUpdated() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)

        let older = DailyEntryDraft(rawText: "Older entry", state: .capture)
        try await repo.saveDraft(older)

        // Small sleep to ensure different timestamps
        try await Task.sleep(for: .milliseconds(50))

        let newer = DailyEntryDraft(rawText: "Newer entry", state: .reviewCards)
        try await repo.saveDraft(newer)

        let latest = try await repo.latestDraft()
        XCTAssertEqual(latest?.rawText, "Newer entry")
    }

    func testLatestDraft_noDrafts_returnsNil() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let result = try await repo.latestDraft()
        XCTAssertNil(result)
    }

    func testSaveDraft_preservesAllLoopFields() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let draft = DailyEntryDraft(
            rawText: "Full loop test",
            sessionMode: .deep,
            hasSelectedSessionMode: true,
            selectedLens: .opposingView,
            yesterdayCompletion: .partial,
            yesterdayValueRating: .medium,
            state: .answerQuestions
        )

        try await repo.saveDraft(draft)
        let loaded = try XCTUnwrap(try await repo.latestDraft())

        XCTAssertEqual(loaded.sessionMode, .deep)
        XCTAssertTrue(loaded.hasSelectedSessionMode)
        XCTAssertEqual(loaded.selectedLens, .opposingView)
        XCTAssertEqual(loaded.yesterdayCompletion, .partial)
        XCTAssertEqual(loaded.yesterdayValueRating, .medium)
        XCTAssertEqual(loaded.state, .answerQuestions)
    }

    // MARK: - ThinkingCardRepository

    func testSaveCards_andLoad() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Card test", state: .reviewCards)
        try await entryRepo.saveDraft(draft)

        let cards = [
            ThinkingCard(type: .problem, title: "Problem 1", body: "Body 1",
                         priority: .high, sensitivity: .normal, confidence: 0.85, isConfirmed: true),
            ThinkingCard(type: .task, title: "Task 1", body: "Body 2",
                         priority: .medium, sensitivity: .possiblySensitive, confidence: 0.72)
        ]
        try await cardRepo.saveCards(cards, dailyEntryId: draft.id)

        let loaded = try await cardRepo.cards(for: draft.id)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].title, "Problem 1")
        XCTAssertEqual(loaded[0].type, .problem)
        XCTAssertTrue(loaded[0].isConfirmed)
        XCTAssertEqual(loaded[1].sensitivity, .possiblySensitive)
    }

    func testSaveCards_softDeletesRemovedCards() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let cardRepo = SQLiteThinkingCardRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Delete test", state: .reviewCards)
        try await entryRepo.saveDraft(draft)

        let originalCards = [
            ThinkingCard(type: .fact, title: "Keep", body: "Body"),
            ThinkingCard(type: .fact, title: "Delete", body: "Body"),
            ThinkingCard(type: .fact, title: "Also delete", body: "Body")
        ]
        try await cardRepo.saveCards(originalCards, dailyEntryId: draft.id)

        let keptCards = [originalCards[0]]
        try await cardRepo.saveCards(keptCards, dailyEntryId: draft.id)

        let loaded = try await cardRepo.cards(for: draft.id)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Keep")
    }

    // MARK: - QuestRepository

    func testSaveQuests_andLoad() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Quest test", state: .reviewQuests)
        try await entryRepo.saveDraft(draft)

        let quests = [
            Quest(type: .main, title: "Main quest", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R", status: .active),
            Quest(type: .side, title: "Side quest", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R", status: .draft)
        ]
        try await questRepo.saveQuests(quests, sourceDailyEntryId: draft.id)

        let loaded = try await questRepo.quests(for: draft.id)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].type, .main)
        XCTAssertEqual(loaded[0].status, .active)
        XCTAssertEqual(loaded[1].type, .side)
    }

    func testActiveMainQuest_returnsActiveMainQuest() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Active quest test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let quests = [
            Quest(type: .main, title: "Active main", whyItMatters: "W",
                  completionCriteria: "C", expectedResistance: "E",
                  reflectionQuestion: "R", status: .active)
        ]
        try await questRepo.saveQuests(quests, sourceDailyEntryId: draft.id)

        let active = try await questRepo.activeMainQuest()
        XCTAssertEqual(active?.title, "Active main")
        XCTAssertEqual(active?.type, .main)
        XCTAssertEqual(active?.status, .active)
    }

    func testActiveMainQuest_noActiveQuest_returnsNil() async throws {
        let questRepo = SQLiteQuestRepository(database: database)
        let result = try await questRepo.activeMainQuest()
        XCTAssertNil(result)
    }

    // MARK: - PrincipleRepository

    func testSavePrinciples_andLoad() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Principle test", state: .extractPrinciple)
        try await entryRepo.saveDraft(draft)

        let principles = [
            PrincipleAsset(title: "Clarify before execution", summary: "Make ownership explicit.",
                          triggerContext: "Cross-functional work.", actions: ["Write owner.", "Write criteria."],
                          successCriteria: "People know who owns what.", exceptions: "Low-stakes sync.")
        ]
        try await principleRepo.savePrinciples(principles, sourceDailyEntryId: draft.id)

        let loaded = try await principleRepo.principles(for: draft.id)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Clarify before execution")
        XCTAssertEqual(loaded[0].actions.count, 2)
    }

    func testActivePrinciples_returnsOnlyActive() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Active principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let active = PrincipleAsset(title: "Active", summary: "S", triggerContext: "T",
                                     actions: ["A"], successCriteria: "SC", exceptions: "E", status: .active)
        let archived = PrincipleAsset(title: "Archived", summary: "S", triggerContext: "T",
                                       actions: ["A"], successCriteria: "SC", exceptions: "E", status: .archived)
        try await principleRepo.savePrinciples([active, archived], sourceDailyEntryId: draft.id)

        let activePrinciples = try await principleRepo.activePrinciples()
        XCTAssertEqual(activePrinciples.count, 1)
        XCTAssertEqual(activePrinciples[0].title, "Active")
    }

    // MARK: - Migration

    func testMigration_v1_createsAllTables() throws {
        // Tables created in setUp - verify they exist
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("daily_entries"))
            XCTAssertTrue(try db.tableExists("thinking_cards"))
            XCTAssertTrue(try db.tableExists("quests"))
            XCTAssertTrue(try db.tableExists("principle_assets"))
            XCTAssertTrue(try db.tableExists("prompt_runs"))
        }
    }

    func testMigration_v2_addsDailyLoopFields() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "daily_entries")
            let columnNames = Set(columns.map(\.name))
            XCTAssertTrue(columnNames.contains("has_selected_session_mode"))
            XCTAssertTrue(columnNames.contains("selected_lens"))
            XCTAssertTrue(columnNames.contains("yesterday_completion"))
            XCTAssertTrue(columnNames.contains("yesterday_value_rating"))
        }
    }

    // MARK: - Helper

    private func readCreatedAt(for id: UUID) -> String? {
        try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT created_at FROM daily_entries WHERE id = ?", arguments: [id.uuidString])
        }
    }
}
