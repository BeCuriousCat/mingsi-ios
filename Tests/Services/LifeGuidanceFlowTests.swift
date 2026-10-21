import XCTest
import GRDB
@testable import MingSi

@MainActor
final class LifeGuidanceFlowTests: XCTestCase {
    private let event = LifeGuidanceEvent(id: "event:1", text: "最近消息通知太多，手机不断打断我的注意力。")
    private func day(_ key: String) -> Date {
        ISO8601DateFormatter().date(from: key + "T12:00:00Z")!
    }

    func testDailySnapshotAndFeedbackSurviveReopenAndContentUpdate() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteLifeGuidanceRepository(database: db)
        let store = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-05") }, chooseIndex: { _ in 0 })
        await store.refresh()
        let original = try XCTUnwrap(store.cards.first?.item)
        let saved = await store.update(original) { $0.isSaved = true; $0.hasTried = true; $0.observation = "这次没有中断，完成了一个小结果。" }
        XCTAssertTrue(saved)

        var changed = original
        changed.version = "new.v2"
        changed.firstStep = "另一个动作"
        let reopened = LifeGuidanceStore(repository: repo, catalog: [changed], now: { self.day("2026-10-05") }, chooseIndex: { _ in 0 })
        await reopened.refresh()
        XCTAssertEqual(reopened.cards.first?.item, original)
        XCTAssertEqual(reopened.savedItems.first?.item.contentHash, original.contentHash)
        XCTAssertEqual(reopened.savedItems.first?.observation, "这次没有中断，完成了一个小结果。")
        XCTAssertTrue(reopened.savedItems.first?.hasTried == true)

        let nextDay = LifeGuidanceStore(repository: repo, catalog: [changed], now: { self.day("2026-10-06") }, chooseIndex: { _ in 0 })
        await nextDay.refresh()
        XCTAssertEqual(nextDay.cards.first?.item.version, changed.version)
        XCTAssertEqual(nextDay.savedItems.first?.item.version, original.version)
    }

    func testReviewIsOncePerReviewPersistsDedupAndMergesWithDaily() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteLifeGuidanceRepository(database: db)
        let first = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-01") }, chooseIndex: { _ in 0 })
        let matcher = GuidanceMatcherStub(itemID: "life.attention.nonessential-notifications")
        await first.recommend(reviewID: "one", events: [event], matcher: matcher)
        await first.recommend(reviewID: "one", events: [event], matcher: matcher)
        XCTAssertEqual(matcher.calls, 1)
        XCTAssertEqual(first.cards.count, 1)
        XCTAssertEqual(first.cards.first?.triggers, [.daily, .dailyReview])
        XCTAssertEqual(first.cards.first?.event, event)

        let day13 = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-14") }, chooseIndex: { _ in 1 })
        await day13.recommend(reviewID: "two", events: [event], matcher: matcher)
        XCTAssertFalse(matcher.lastCandidates.contains("life.attention.nonessential-notifications"))
        XCTAssertTrue(day13.exposures.contains { $0.id == "review:two" && $0.item == nil })
        let day14 = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-15") }, chooseIndex: { _ in 1 })
        await day14.recommend(reviewID: "three", events: [event], matcher: matcher)
        XCTAssertTrue(matcher.lastCandidates.contains("life.attention.nonessential-notifications"))
        XCTAssertNotNil(day14.cards.first { $0.triggers == [.dailyReview] })
    }

    func testNotSuitableOnlyHidesCurrentDayAndSavedRecordCanBeDeleted() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteLifeGuidanceRepository(database: db)
        let store = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-05") }, chooseIndex: { _ in 0 })
        await store.refresh()
        let item = try XCTUnwrap(store.cards.first?.item)
        _ = await store.update(item) { $0.isSaved = true; $0.dismissedDayKeys.insert("2026-10-05") }
        XCTAssertTrue(store.cards.isEmpty)
        let reopened = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-05") }, chooseIndex: { _ in 0 })
        await reopened.refresh()
        XCTAssertTrue(reopened.cards.isEmpty)
        let next = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-06") }, chooseIndex: { _ in 0 })
        await next.refresh()
        XCTAssertEqual(next.cards.first?.item.id, item.id)
        let record = try XCTUnwrap(next.savedItems.first)
        let deleted = await next.deleteRecord(record)
        XCTAssertTrue(deleted)
        let records = try await repo.feedback()
        XCTAssertTrue(records.isEmpty)
    }

    func testWriteFailureDoesNotClaimSavedOrLoseOldFeedback() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteLifeGuidanceRepository(database: db)
        let store = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-05") }, chooseIndex: { _ in 0 })
        await store.refresh()
        let item = try XCTUnwrap(store.cards.first?.item)
        try await db.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER reject_guidance_feedback BEFORE INSERT ON life_guidance_feedback BEGIN SELECT RAISE(ABORT, 'injected failure'); END")
        }
        let saved = await store.update(item) { $0.isSaved = true; $0.observation = "保留这次观察" }
        XCTAssertFalse(saved)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNil(store.state(for: item))
        XCTAssertTrue(store.savedItems.isEmpty)
    }

    func testReviewOwnershipDeletionAndExportAreComplete() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteLifeGuidanceRepository(database: db)
        let mentor = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await mentor.createSession(MentorSession(id: id, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let store = LifeGuidanceStore(repository: repo, now: { self.day("2026-10-05") }, chooseIndex: { _ in 0 })
        await store.recommend(reviewID: "mentor:" + id.uuidString, events: [event], matcher: GuidanceMatcherStub(itemID: "life.attention.nonessential-notifications"))
        let item = try XCTUnwrap(store.cards.first?.item)
        _ = await store.update(item) { $0.isSaved = true }
        let audit = SQLitePromptRunRepository(database: db)
        let shortlistRun = PromptRun(promptId: PromptID.lifeGuidanceShortlist.rawValue, promptVersion: "1", outputSchemaVersion: 1,
            modelProvider: "test", modelName: "test", sessionMode: "standard", sourceRecordIds: ["mentor-session:" + id.uuidString],
            requestSummary: event.text, responseJSON: "{\"itemIDs\":[]}")
        try await audit.savePromptRun(shortlistRun)
        let exported = try await SQLiteDataExportRepository(database: db).exportPackage()
        XCTAssertEqual(exported.counts["life_guidance_exposures"], 2)
        XCTAssertEqual(exported.counts["life_guidance_feedback"], 1)
        try await mentor.deleteSession(id: id)
        let auditRows = try await audit.recentPromptRuns(limit: 20)
        XCTAssertFalse(auditRows.contains { $0.id == shortlistRun.id }, "删除会话也应删除查找资料时的私人材料")
        do {
            try await audit.savePromptRun(shortlistRun)
            XCTFail("迟到的查找审计不能写回已删除会话")
        } catch { }
        await store.refresh()
        XCTAssertEqual(store.exposures.count, 1)
        XCTAssertEqual(store.savedItems.count, 1, "删除私人回顾不应删除用户保存的通用建议")
        await store.recommend(reviewID: "mentor:" + id.uuidString, events: [event], matcher: GuidanceMatcherStub(itemID: "life.attention.nonessential-notifications"))
        let exposures = try await repo.exposures()
        XCTAssertEqual(exposures.count, 1, "已删除会话的延迟结果不能重新写入")
    }

    func testUpgradeAnExistingDatabaseWithoutReplacingUserRecords() async throws {
        let queue = try DatabaseQueue()
        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(queue, upTo: "v70_mentor_benefit_feedback")
        let id = UUID().uuidString
        try await queue.write { db in
            try db.execute(sql: "INSERT INTO mentor_sessions (id, initial_entry, lifecycle, draft_text, draft_revision, activity_at) VALUES (?, 'review', 'draft', '旧用户草稿', 1, '2026-10-04T12:00:00Z')", arguments: [id])
        }
        let upgraded = try AppDatabase(dbQueue: queue)
        let saved = try await queue.read { db in try String.fetchOne(db, sql: "SELECT draft_text FROM mentor_sessions WHERE id = ?", arguments: [id]) }
        XCTAssertEqual(saved, "旧用户草稿")
        let repo = SQLiteLifeGuidanceRepository(database: upgraded)
        let exposures = try await repo.exposures()
        XCTAssertTrue(exposures.isEmpty)
    }

    func testReferenceSnapshotFeedbackSurvivesReopenExportAndSourceReplacement() async throws {
        let suiteName = "life-guidance-reference-bookmarks-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteLifeGuidanceRepository(database: db)
        let book = LifeGuidanceReferenceBook.loadBundled()
        let entry = try XCTUnwrap(book.entries.first)
        let store = LifeGuidanceStore(repository: repo, referenceBook: book, referenceBookmarkDefaults: defaults)
        XCTAssertTrue(store.bookmarkedReferenceEntries.isEmpty)
        let bookmarked = await store.toggleBookmark(entry)
        XCTAssertTrue(bookmarked)
        XCTAssertEqual(store.bookmarkedReferenceEntries.map(\.id), [entry.id])

        let reopened = LifeGuidanceStore(repository: repo, referenceBook: book, referenceBookmarkDefaults: defaults)
        await reopened.refresh()
        XCTAssertEqual(reopened.bookmarkedReferenceEntries.map(\.id), [entry.id])
        let item = try XCTUnwrap(reopened.bookmarkedReferenceRecords.first?.item)
        let tried = await reopened.update(item) { $0.hasTried = true; $0.observation = "我试过了，这次没有变化。" }
        XCTAssertTrue(tried)
        let withoutSource = LifeGuidanceStore(repository: repo, referenceBook: .empty, referenceBookmarkDefaults: defaults)
        await withoutSource.refresh()
        XCTAssertEqual(withoutSource.bookmarkedReferenceEntries.first, entry)
        XCTAssertEqual(withoutSource.savedItems.first?.observation, "我试过了，这次没有变化。")
        XCTAssertTrue(withoutSource.bookmarkedReferenceRecords.first!.item.captureMaterial.contains(entry.rawMarkdown))
        let exported = try await SQLiteDataExportRepository(database: db).exportPackage()
        XCTAssertEqual(exported.counts["life_guidance_feedback"], 1)
        let unsaved = await reopened.toggleBookmark(entry)
        XCTAssertTrue(unsaved)
        XCTAssertTrue(reopened.bookmarkedReferenceEntries.isEmpty)
    }

    func testReferenceDailyAndReviewIncludeTheLastChapter() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let book = LifeGuidanceReferenceBook.loadBundled()
        let store = LifeGuidanceStore(repository: SQLiteLifeGuidanceRepository(database: db), catalog: [], referenceBook: book,
            chooseIndex: { $0 - 1 })
        await store.refresh()
        let last = try XCTUnwrap(book.entries.last)
        XCTAssertEqual(store.cards.first?.item.referenceEntry, last)
        let matcher = GuidanceMatcherStub(itemID: last.id)
        await store.recommend(reviewID: "last-chapter", events: [event], matcher: matcher)
        XCTAssertEqual(matcher.lastCandidates.count, 670)
        XCTAssertEqual(store.cards.first?.triggers, [.daily, .dailyReview])
    }

    func testLegacyBookmarksMigrateOnlyAfterSuccessfulDatabaseSave() async throws {
        let suite = "guidance-migration-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let book = LifeGuidanceReferenceBook.loadBundled()
        let entry = try XCTUnwrap(book.entries.last)
        defaults.set([entry.id], forKey: "mingsi.lifeGuidance.referenceBookmarks")
        try await db.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER reject_reference_feedback BEFORE INSERT ON life_guidance_feedback BEGIN SELECT RAISE(ABORT, 'failure'); END")
        }
        let store = LifeGuidanceStore(repository: SQLiteLifeGuidanceRepository(database: db), referenceBook: book, referenceBookmarkDefaults: defaults)
        await store.refresh()
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(defaults.stringArray(forKey: "mingsi.lifeGuidance.referenceBookmarks"), [entry.id])
        XCTAssertTrue(store.bookmarkedReferenceRecords.isEmpty)
        let failed = await store.toggleBookmark(entry)
        XCTAssertFalse(failed)
        XCTAssertFalse(store.isBookmarked(entry))
        try await db.dbQueue.write { db in try db.execute(sql: "DROP TRIGGER reject_reference_feedback") }
        await store.refresh()
        XCTAssertTrue(store.isBookmarked(entry))
        XCTAssertNil(defaults.object(forKey: "mingsi.lifeGuidance.referenceBookmarks"))
    }
}

@MainActor
private final class GuidanceMatcherStub: LifeGuidanceReviewMatching {
    let itemID: String
    var calls = 0
    var lastCandidates: [String] = []
    init(itemID: String) { self.itemID = itemID }
    @MainActor
    func match(events: [LifeGuidanceEvent], candidates: [LifeGuidanceItem]) async throws -> LifeGuidanceReviewDecision? {
        calls += 1
        lastCandidates = candidates.map(\.id)
        guard let item = candidates.first(where: { $0.id == itemID }), let event = events.first else { return nil }
        return LifeGuidanceReviewDecision(item: item, event: event, explanation: "这段事件明确描述了通知造成的中断。")
    }
}

final class LifeGuidanceReviewServiceTests: XCTestCase {
    private let event = LifeGuidanceEvent(id: "event:1", text: "消息通知不断打断注意力，今天写方案时被手机打断了五次。")
    private func output(item: String? = "life.attention.nonessential-notifications", eventID: String? = "event:1", quote: String? = "消息通知不断打断注意力", confidence: Double = 0.95) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["itemID": item.map { $0 as Any } ?? NSNull(), "eventID": eventID.map { $0 as Any } ?? NSNull(), "quote": quote.map { $0 as Any } ?? NSNull(), "explanation": item == nil ? NSNull() : "通知造成了明确中断。", "confidence": confidence])
    }
    func testRequiresAnApprovedCandidateExactEventQuoteAndHighConfidence() throws {
        let catalog = BuiltinLifeGuidanceCatalog.items
        let matched = try LifeGuidanceReviewService.validate(output(), events: [event], candidates: catalog)
        XCTAssertEqual(matched?.event.text, "消息通知不断打断注意力")
        XCTAssertThrowsError(try LifeGuidanceReviewService.validate(output(item: "invented"), events: [event], candidates: catalog))
        XCTAssertThrowsError(try LifeGuidanceReviewService.validate(output(eventID: "other"), events: [event], candidates: catalog))
        XCTAssertThrowsError(try LifeGuidanceReviewService.validate(output(quote: "模型编造的经历"), events: [event], candidates: catalog))
        XCTAssertNil(try LifeGuidanceReviewService.validate(output(confidence: 0.89), events: [event], candidates: catalog))
        XCTAssertNil(try LifeGuidanceReviewService.validate(output(item: nil, eventID: nil, quote: nil, confidence: 0), events: [event], candidates: catalog))
        let generic = LifeGuidanceEvent(id: event.id, text: "今天工作时间充足，事情顺利完成")
        XCTAssertThrowsError(try LifeGuidanceReviewService.validate(output(), events: [generic], candidates: catalog))
    }

    func testAllReferenceTitlesParticipateBeforeFullNotesAreChecked() async throws {
        let book = LifeGuidanceReferenceBook.loadBundled()
        let item = try XCTUnwrap(book.recommendationItems.last)
        let client = ReferenceMatchingClient(itemID: item.id, event: event)
        let service = LifeGuidanceReviewService(client: client, provider: LocalPromptProvider(), ownerSessionID: UUID())
        let result = try await service.match(events: [event], candidates: book.recommendationItems)
        XCTAssertEqual(result?.item.referenceEntry, item.referenceEntry)
        XCTAssertEqual(client.requests.map { $0.prompt.id }, [.lifeGuidanceShortlist, .lifeGuidanceReview])
        let index = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(client.requests[0].inputSummary.utf8)) as? [String: Any])
        let sections = try XCTUnwrap(index["sections"] as? [[String: Any]])
        let entries = sections.flatMap { $0["entries"] as? [[String: String]] ?? [] }
        XCTAssertEqual(Set(entries.compactMap { $0["id"] }), Set(book.entries.map(\.id)))
        let full = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(client.requests[1].inputSummary.utf8)) as? [String: Any])
        let candidates = try XCTUnwrap(full["candidates"] as? [[String: String]])
        XCTAssertEqual(candidates.first?["boundary"], item.referenceEntry?.note)
        XCTAssertEqual(candidates.first?["kind"], "原指南资料入口")
        XCTAssertTrue(client.requests.allSatisfy { $0.inputSummary.utf8.count <= LifeGuidanceReviewService.maximumRequestBytes })
        XCTAssertTrue(client.requests.allSatisfy { $0.sourceRecordIDs.contains { $0.hasPrefix("mentor-session:") } })
    }

    func testDraftAdaptationsAndInventedShortlistIDsAreRejected() async throws {
        var draft = BuiltinLifeGuidanceCatalog.items[0]
        draft.reviewStatus = .draft
        XCTAssertThrowsError(try LifeGuidanceReviewService.validate(output(), events: [event], candidates: [draft]))
        let client = ReferenceMatchingClient(itemID: "invented", event: event)
        do {
            _ = try await LifeGuidanceReviewService(client: client, provider: LocalPromptProvider()).match(events: [event], candidates: LifeGuidanceReferenceBook.loadBundled().recommendationItems)
            XCTFail("Invented shortlist ID must be rejected")
        } catch { XCTAssertEqual(client.requests.count, 1) }
    }
}

private final class ReferenceMatchingClient: LLMClient {
    let itemID: String
    let event: LifeGuidanceEvent
    var requests: [LLMRequest] = []
    init(itemID: String, event: LifeGuidanceEvent) { self.itemID = itemID; self.event = event }
    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        if request.prompt.id == .lifeGuidanceShortlist {
            return try JSONSerialization.data(withJSONObject: ["itemIDs": [itemID]])
        }
        return try JSONSerialization.data(withJSONObject: ["itemID": itemID, "eventID": event.id, "quote": event.text, "explanation": "事件与资料讨论同一问题。", "confidence": 0.95])
    }
}
