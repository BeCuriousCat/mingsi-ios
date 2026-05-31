import XCTest
import GRDB
@testable import MingSi

final class HistoryFeatureTests: XCTestCase {

    private var database: AppDatabase!
    private var dbQueue: DatabaseQueue!
    private var entryRepo: SQLiteDailyEntryRepository!
    private var cardRepo: SQLiteThinkingCardRepository!
    private var questRepo: SQLiteQuestRepository!
    private var principleRepo: SQLitePrincipleRepository!

    override func setUp() {
        super.setUp()
        dbQueue = try! DatabaseQueue()
        let migrator = AppDatabase.makeMigrator()
        try! migrator.migrate(dbQueue)
        database = try! AppDatabase(dbQueue: dbQueue)
        entryRepo = SQLiteDailyEntryRepository(database: database)
        cardRepo = SQLiteThinkingCardRepository(database: database)
        questRepo = SQLiteQuestRepository(database: database)
        principleRepo = SQLitePrincipleRepository(database: database)
    }

    override func tearDown() {
        principleRepo = nil
        questRepo = nil
        cardRepo = nil
        entryRepo = nil
        database = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - History list: list recent entries

    func testListEntries_noEntries_returnsEmpty() async throws {
        let entries = try await entryRepo.recentEntries(limit: 10)
        XCTAssertTrue(entries.isEmpty)
    }

    func testListEntries_returnsNewestFirst() async throws {
        let older = DailyEntryDraft(rawText: "Older", state: .sessionComplete)
        try await entryRepo.saveDraft(older)

        try await Task.sleep(for: .milliseconds(50))

        let newer = DailyEntryDraft(rawText: "Newer", state: .sessionComplete)
        try await entryRepo.saveDraft(newer)

        let entries = try await entryRepo.recentEntries(limit: 10)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].rawText, "Newer")
        XCTAssertEqual(entries[1].rawText, "Older")
    }

    func testListEntries_respectsLimit() async throws {
        for i in 0..<5 {
            let draft = DailyEntryDraft(rawText: "Entry \(i)", state: .sessionComplete)
            try await entryRepo.saveDraft(draft)
        }

        let entries = try await entryRepo.recentEntries(limit: 3)
        XCTAssertEqual(entries.count, 3)
    }

    // MARK: - History detail: entry with full evidence chain

    func testEntryDetail_withCardsAndQuests() async throws {
        let draft = DailyEntryDraft(rawText: "Full detail test", sessionMode: .standard,
                                     hasSelectedSessionMode: true, selectedLens: .leverageAnalysis,
                                     state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let cards = [
            ThinkingCard(type: .problem, title: "Unclear goal", body: "Meeting lacked focus.",
                         priority: .high, isConfirmed: true),
            ThinkingCard(type: .task, title: "Send summary", body: "Share conclusions.",
                         priority: .medium, isConfirmed: true)
        ]
        try await cardRepo.saveCards(cards, dailyEntryId: draft.id)

        let quests = [
            Quest(type: .main, title: "Confirm ownership", whyItMatters: "Reduces rework",
                  completionCriteria: "Owner confirmed", expectedResistance: "Cross-role",
                  reflectionQuestion: "What changed?", status: .active)
        ]
        try await questRepo.saveQuests(quests, sourceDailyEntryId: draft.id)

        // Load entry
        let loaded = try await entryRepo.latestDraft()
        XCTAssertEqual(loaded?.rawText, "Full detail test")

        // Load evidence chain
        let loadedCards = try await cardRepo.cards(for: draft.id)
        XCTAssertEqual(loadedCards.count, 2)

        let loadedQuests = try await questRepo.quests(for: draft.id)
        XCTAssertEqual(loadedQuests.count, 1)
        XCTAssertEqual(loadedQuests[0].title, "Confirm ownership")
    }

    func testEntryDetail_withPrinciple() async throws {
        let draft = DailyEntryDraft(rawText: "Principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let principles = [
            PrincipleAsset(title: "Clarify before execution", summary: "Make ownership explicit.",
                          triggerContext: "Cross-functional work.", actions: ["Write criteria."],
                          successCriteria: "Owner known.", exceptions: "Low-stakes.")
        ]
        try await principleRepo.savePrinciples(principles, sourceDailyEntryId: draft.id)

        let loadedPrinciples = try await principleRepo.principles(for: draft.id)
        XCTAssertEqual(loadedPrinciples.count, 1)
        XCTAssertEqual(loadedPrinciples[0].title, "Clarify before execution")
    }

    // MARK: - History list entry summary

    func testHistoryEntrySummary_containsLoopState() async throws {
        let draft = DailyEntryDraft(rawText: "Summary test", state: .reviewCards)
        try await entryRepo.saveDraft(draft)

        let entries = try await entryRepo.recentEntries(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].state, DailyLoopState.reviewCards)
    }

    func testHistoryEntrySummary_containsRawTextPreview() async throws {
        let longText = String(repeating: "This is a longer text. ", count: 20)
        let draft = DailyEntryDraft(rawText: longText, state: .capture)
        try await entryRepo.saveDraft(draft)

        let entries = try await entryRepo.recentEntries(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertFalse(entries[0].rawText.isEmpty)
    }
}
