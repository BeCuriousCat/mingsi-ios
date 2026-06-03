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

    func testHistoryFilterChipMetrics_keepAdvancedFilterWidthStable() {
        XCTAssertEqual(HistoryFilterChipMetrics.minWidth(for: .project), 86)
        XCTAssertEqual(HistoryFilterChipMetrics.minWidth(for: .lens), 82)
        XCTAssertEqual(HistoryFilterChipMetrics.minWidth(for: .cardType), 96)
        XCTAssertEqual(HistoryFilterChipMetrics.minWidth(for: .questStatus), 96)
        XCTAssertGreaterThanOrEqual(HistoryFilterChipMetrics.maxWidth(for: .project), HistoryFilterChipMetrics.minWidth(for: .project))
        XCTAssertGreaterThanOrEqual(HistoryFilterChipMetrics.maxWidth(for: .cardType), HistoryFilterChipMetrics.minWidth(for: .cardType))
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

    func testHistoryRecordCardSummary_countsConfirmedPendingAndExcludedSeparately() {
        let draft = DailyEntryDraft(rawText: "Fallback generated three cards", state: .reviewCards)
        let record = HistoryRecord(
            draft: draft,
            cards: [
                ThinkingCard(type: .fact, title: "Confirmed", body: "Visible evidence", isConfirmed: true),
                ThinkingCard(type: .problem, title: "Pending", body: "Needs review"),
                ThinkingCard(type: .task, title: "Excluded", body: "Removed", isExcludedFromModel: true)
            ]
        )

        XCTAssertEqual(record.confirmedCards.count, 1)
        XCTAssertEqual(record.pendingCards.count, 1)
        XCTAssertEqual(record.excludedCards.count, 1)
        XCTAssertEqual(record.cardCountSummary, "1 已确认 / 1 待确认")
        XCTAssertTrue(record.hasCardEvidence)
    }

    func testHistoryRecordCardSummary_doesNotTreatOnlyPendingCardsAsEvidence() {
        let draft = DailyEntryDraft(rawText: "Only pending", state: .reviewCards)
        let record = HistoryRecord(
            draft: draft,
            cards: [
                ThinkingCard(type: .fact, title: "Pending", body: "Not confirmed")
            ]
        )

        XCTAssertEqual(record.cardCountSummary, "1 待确认卡")
        XCTAssertFalse(record.hasCardEvidence)
    }

    // MARK: - History search and filtering

    func testHistorySearchQuery_matchesCardBodyText() {
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议复盘", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .problem, title: "会议失焦", body: "会前没有列出确认事项。", isConfirmed: true)
            ]
        )
        let other = HistoryRecord(
            draft: DailyEntryDraft(rawText: "日常杂项", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .idea, title: "散步", body: "晚上整理思路。", isConfirmed: true)
            ]
        )

        let results = HistorySearchQuery(text: "确认事项").apply(to: [matching, other])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_matchesQuestCompletionCriteria() {
        let matchingQuest = Quest(
            type: .main,
            title: "发会议纪要",
            whyItMatters: "减少遗漏",
            completionCriteria: "群内发出 Action 并 @ 到负责人",
            expectedResistance: "会后疲劳",
            reflectionQuestion: "是否减少追问"
        )
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "任务复盘", state: .sessionComplete),
            quests: [matchingQuest]
        )
        let other = HistoryRecord(draft: DailyEntryDraft(rawText: "没有任务", state: .sessionComplete))

        let results = HistorySearchQuery(text: "负责人").apply(to: [matching, other])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_filtersProjectEvidence() {
        let projectId = UUID()
        let linked = HistoryRecord(
            draft: DailyEntryDraft(rawText: "长期议题", state: .sessionComplete),
            projectLinks: [
                ProjectLink(projectId: projectId, sourceType: .dailyEntry, sourceId: UUID().uuidString, linkType: .evidence, isUserConfirmed: true)
            ]
        )
        let plain = HistoryRecord(draft: DailyEntryDraft(rawText: "普通记录", state: .sessionComplete))

        let results = HistorySearchQuery(filter: .project).apply(to: [linked, plain])

        XCTAssertEqual(results.map(\.id), [linked.id])
    }

    func testHistorySearchQuery_filtersGrowthEvidence() {
        let snapshotId = UUID()
        let contribution = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "任务定义更具体",
            reason: "任务定义更具体",
            sourceType: .dailyEntry,
            sourceId: UUID().uuidString,
            sourceDailyEntryId: UUID()
        )
        let linked = HistoryRecord(
            draft: DailyEntryDraft(rawText: "成长证据", state: .sessionComplete),
            growthContributions: [contribution]
        )
        let plain = HistoryRecord(draft: DailyEntryDraft(rawText: "普通记录", state: .sessionComplete))

        let results = HistorySearchQuery(filter: .growth).apply(to: [linked, plain])

        XCTAssertEqual(results.map(\.id), [linked.id])
    }

    func testHistorySearchQuery_combinesKeywordAndFilterAsIntersection() {
        let projectId = UUID()
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议机制", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .decision, title: "会议机制", body: "每次会前列出确认事项。", isConfirmed: true)
            ],
            projectLinks: [
                ProjectLink(projectId: projectId, sourceType: .dailyEntry, sourceId: UUID().uuidString, linkType: .evidence, isUserConfirmed: true)
            ]
        )
        let keywordOnly = HistoryRecord(
            draft: DailyEntryDraft(rawText: "确认事项", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .fact, title: "确认事项", body: "只有关键词。", isConfirmed: true)
            ]
        )

        let results = HistorySearchQuery(text: "确认事项", filter: .project).apply(to: [matching, keywordOnly])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_filtersSpecificProjectId() {
        let selectedProjectId = UUID()
        let otherProjectId = UUID()
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议机制", state: .sessionComplete),
            projectLinks: [
                ProjectLink(projectId: selectedProjectId, sourceType: .dailyEntry, sourceId: UUID().uuidString, linkType: .evidence, isUserConfirmed: true)
            ]
        )
        let other = HistoryRecord(
            draft: DailyEntryDraft(rawText: "另一个长期议题", state: .sessionComplete),
            projectLinks: [
                ProjectLink(projectId: otherProjectId, sourceType: .dailyEntry, sourceId: UUID().uuidString, linkType: .evidence, isUserConfirmed: true)
            ]
        )

        let results = HistorySearchQuery(projectId: selectedProjectId).apply(to: [matching, other])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_filtersSelectedLens() {
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "证据校验复盘", state: .sessionComplete),
            lensSession: LensSession(dailyEntryId: UUID(), selectedLens: .evidenceCheck)
        )
        let other = HistoryRecord(
            draft: DailyEntryDraft(rawText: "杠杆分析复盘", state: .sessionComplete),
            lensSession: LensSession(dailyEntryId: UUID(), selectedLens: .leverageAnalysis)
        )

        let results = HistorySearchQuery(lens: .evidenceCheck).apply(to: [matching, other])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_filtersCardType() {
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "决策复盘", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .decision, title: "会前先列目的", body: "把会议目标写清楚。", isConfirmed: true)
            ]
        )
        let other = HistoryRecord(
            draft: DailyEntryDraft(rawText: "风险复盘", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .risk, title: "缺少负责人", body: "Action 可能落空。", isConfirmed: true)
            ]
        )

        let results = HistorySearchQuery(cardType: .decision).apply(to: [matching, other])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_filtersQuestStatus() {
        let completed = Quest(
            type: .main,
            title: "发会议纪要",
            whyItMatters: "减少遗漏",
            completionCriteria: "群内发出 Action",
            expectedResistance: "会后疲劳",
            reflectionQuestion: "是否减少追问",
            status: .completed
        )
        let failed = Quest(
            type: .main,
            title: "补齐资料",
            whyItMatters: "减少阻塞",
            completionCriteria: "补齐缺口",
            expectedResistance: "时间不足",
            reflectionQuestion: "是否解除阻塞",
            status: .failed
        )
        let matching = HistoryRecord(draft: DailyEntryDraft(rawText: "完成任务", state: .sessionComplete), quests: [completed])
        let other = HistoryRecord(draft: DailyEntryDraft(rawText: "失败任务", state: .sessionComplete), quests: [failed])

        let results = HistorySearchQuery(questStatus: .completed).apply(to: [matching, other])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testHistorySearchQuery_advancedFiltersComposeWithKeywordAndEvidenceType() {
        let selectedProjectId = UUID()
        let matching = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议机制", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .decision, title: "确认事项", body: "会前列出目标和负责人。", isConfirmed: true)
            ],
            quests: [
                Quest(
                    type: .main,
                    title: "发送纪要",
                    whyItMatters: "减少追问",
                    completionCriteria: "群内发出 Action",
                    expectedResistance: "疲劳",
                    reflectionQuestion: "是否减少追问",
                    status: .completed
                )
            ],
            lensSession: LensSession(dailyEntryId: UUID(), selectedLens: .leverageAnalysis),
            projectLinks: [
                ProjectLink(projectId: selectedProjectId, sourceType: .thinkingCard, sourceId: UUID().uuidString, linkType: .decision, isUserConfirmed: true)
            ]
        )
        let wrongLens = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议机制", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .decision, title: "确认事项", body: "会前列出目标。", isConfirmed: true)
            ],
            lensSession: LensSession(dailyEntryId: UUID(), selectedLens: .evidenceCheck),
            projectLinks: [
                ProjectLink(projectId: selectedProjectId, sourceType: .thinkingCard, sourceId: UUID().uuidString, linkType: .decision, isUserConfirmed: true)
            ]
        )
        let wrongType = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议机制", state: .sessionComplete),
            cards: [
                ThinkingCard(type: .risk, title: "确认事项", body: "没有负责人。", isConfirmed: true)
            ],
            lensSession: LensSession(dailyEntryId: UUID(), selectedLens: .leverageAnalysis),
            projectLinks: [
                ProjectLink(projectId: selectedProjectId, sourceType: .thinkingCard, sourceId: UUID().uuidString, linkType: .risk, isUserConfirmed: true)
            ]
        )

        let results = HistorySearchQuery(
            text: "负责人",
            filter: .project,
            projectId: selectedProjectId,
            lens: .leverageAnalysis,
            cardType: .decision,
            questStatus: .completed
        ).apply(to: [matching, wrongLens, wrongType])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    // MARK: - Project evidence digest

    func testProjectEvidenceDigest_mapsTaskEvidenceToDoneSignal() {
        let projectId = UUID()
        let quest = Quest(
            type: .main,
            title: "会前写清确认事项",
            whyItMatters: "减少会议漂移",
            completionCriteria: "会议前列出目标和负责人",
            expectedResistance: "时间紧",
            reflectionQuestion: "是否让会议更短"
        )
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议准备复盘", state: .sessionComplete),
            quests: [quest]
        )
        let link = ProjectLink(
            projectId: projectId,
            sourceType: .quest,
            sourceId: quest.id.uuidString,
            linkType: .task,
            isUserConfirmed: true
        )

        let digest = ProjectEvidenceDigest(projectId: projectId, evidence: [(link, record)])

        XCTAssertEqual(digest.progressSignals.count, 1)
        XCTAssertEqual(digest.progressSignals[0].kind, .done)
        XCTAssertTrue(digest.progressSignals[0].title.contains("会前写清确认事项"))
        XCTAssertEqual(digest.latestSignal?.sourceId, quest.id.uuidString)
    }

    func testProjectEvidenceDigest_mapsBlockerAndRiskEvidenceToSignalKinds() {
        let projectId = UUID()
        let blockerCard = ThinkingCard(type: .problem, title: "接口负责人不明确", body: "推进时反复找人确认。", isConfirmed: true)
        let riskCard = ThinkingCard(type: .risk, title: "没有验收标准", body: "后续容易返工。", isConfirmed: true)
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "项目推进复盘", state: .sessionComplete),
            cards: [blockerCard, riskCard]
        )
        let blockerLink = ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: blockerCard.id.uuidString,
            linkType: .blocker,
            isUserConfirmed: true
        )
        let riskLink = ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: riskCard.id.uuidString,
            linkType: .risk,
            isUserConfirmed: true
        )

        let digest = ProjectEvidenceDigest(projectId: projectId, evidence: [(blockerLink, record), (riskLink, record)])

        XCTAssertEqual(Set(digest.progressSignals.map(\.kind)), Set([.newlyBlocked, .newRisk]))
        XCTAssertTrue(digest.evidenceGapMessage.contains("任务"))
    }

    func testProjectEvidenceDigest_mixedEvidenceProducesNextBet() {
        let projectId = UUID()
        let decision = ThinkingCard(type: .decision, title: "先定义会议产出", body: "每次会前列出要确认的事项。", isConfirmed: true)
        let quest = Quest(
            type: .main,
            title: "发出会议纪要模板",
            whyItMatters: "让 Action 有 owner",
            completionCriteria: "群内发出纪要并标注负责人",
            expectedResistance: "会后疲劳",
            reflectionQuestion: "是否减少追问"
        )
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "会议机制复盘", state: .sessionComplete),
            cards: [decision],
            quests: [quest]
        )
        let links = [
            ProjectLink(projectId: projectId, sourceType: .thinkingCard, sourceId: decision.id.uuidString, linkType: .decision, isUserConfirmed: true),
            ProjectLink(projectId: projectId, sourceType: .quest, sourceId: quest.id.uuidString, linkType: .task, isUserConfirmed: true)
        ]

        let digest = ProjectEvidenceDigest(projectId: projectId, evidence: links.map { ($0, record) })

        XCTAssertNotNil(digest.nextBet)
        XCTAssertTrue(digest.nextBet!.contains("发出会议纪要模板"))
        XCTAssertTrue(digest.hasBeforeAfterEvidence)
    }

    func testProjectEvidenceDigest_beforeAfterRequiresTwoEvidenceEntries() {
        let projectId = UUID()
        let card = ThinkingCard(type: .fact, title: "第一次记录", body: "只有一条证据。", isConfirmed: true)
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "单条证据", state: .sessionComplete),
            cards: [card]
        )
        let link = ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: card.id.uuidString,
            linkType: .evidence,
            isUserConfirmed: true
        )

        let digest = ProjectEvidenceDigest(projectId: projectId, evidence: [(link, record)])

        XCTAssertFalse(digest.hasBeforeAfterEvidence)
        XCTAssertTrue(digest.evidenceGapMessage.contains("before / after"))
    }
}
