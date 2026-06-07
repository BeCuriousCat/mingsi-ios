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

    func testHistoryRecordRepairBlockingEvidence_includesConfirmedCardsAndDownstreamEvidence() {
        let draft = DailyEntryDraft(rawText: "Repair guard", state: .sessionComplete)

        let withConfirmedCard = HistoryRecord(
            draft: draft,
            cards: [
                ThinkingCard(type: .fact, title: "Confirmed", body: "Durable evidence", isConfirmed: true)
            ]
        )
        let withQuest = HistoryRecord(
            draft: draft,
            quests: [
                Quest(
                    type: .main,
                    title: "Follow up",
                    whyItMatters: "Downstream task",
                    completionCriteria: "A visible result exists",
                    expectedResistance: "Time pressure",
                    reflectionQuestion: "What will prove this worked?"
                )
            ]
        )
        let withVerification = HistoryRecord(
            draft: draft,
            verification: Verification(
                questId: UUID(),
                questTitle: "Follow up",
                sourceDailyEntryId: draft.id,
                completion: .done,
                valueRating: .high,
                calibrationNote: "Evidence exists"
            )
        )
        let withoutBlockingEvidence = HistoryRecord(
            draft: draft,
            cards: [
                ThinkingCard(type: .fact, title: "Pending", body: "Not confirmed")
            ]
        )

        XCTAssertTrue(withConfirmedCard.hasHistoricalRepairBlockingEvidence)
        XCTAssertTrue(withQuest.hasHistoricalRepairBlockingEvidence)
        XCTAssertTrue(withVerification.hasHistoricalRepairBlockingEvidence)
        XCTAssertFalse(withoutBlockingEvidence.hasHistoricalRepairBlockingEvidence)
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

    // MARK: - Historical AI repair

    func testHistoryRepairCardPreview_decodesValidCandidatePayload() {
        let payload = """
        {"cards":[{"id":"card-1","type":"problem","title":"会议目标不清","body":"会前没有列出必须确认的问题。","priority":"high","sensitivity":"normal","confidence":0.86,"isConfirmed":false,"isExcludedFromModel":false,"sourceRefs":[]}]}
        """

        let previews = HistoryRepairCardPreview.decode(from: payload)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews[0].type, "problem")
        XCTAssertEqual(previews[0].title, "会议目标不清")
        XCTAssertEqual(previews[0].body, "会前没有列出必须确认的问题。")
        XCTAssertEqual(previews[0].priority, "high")
        XCTAssertEqual(previews[0].sensitivity, "normal")
    }

    func testHistoryRepairCardPreview_invalidPayloadReturnsEmpty() {
        XCTAssertTrue(HistoryRepairCardPreview.decode(from: "not-json").isEmpty)
        XCTAssertTrue(HistoryRepairCardPreview.decode(from: nil).isEmpty)
    }

    func testHistoricalRetryCandidateStatus_historyRepairTitleCoversReviewStates() {
        XCTAssertEqual(HistoricalRetryCandidateStatus.pending.historyRepairTitle, "待处理")
        XCTAssertEqual(HistoricalRetryCandidateStatus.retrying.historyRepairTitle, "生成中")
        XCTAssertEqual(HistoricalRetryCandidateStatus.candidateReady.historyRepairTitle, "候选已生成")
        XCTAssertEqual(HistoricalRetryCandidateStatus.accepted.historyRepairTitle, "已接受")
        XCTAssertEqual(HistoricalRetryCandidateStatus.dismissed.historyRepairTitle, "已忽略")
        XCTAssertEqual(HistoricalRetryCandidateStatus.blocked.historyRepairTitle, "已阻断")
        XCTAssertEqual(HistoricalRetryCandidateStatus.failed.historyRepairTitle, "重试失败")
    }

    func testHistoryRepairPromptSupport_onlyOrganizeCardsCanStartHistoricalRetry() {
        XCTAssertTrue(HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: PromptID.organizeCards.rawValue))
        XCTAssertFalse(HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: PromptID.generateQuestions.rawValue))
        XCTAssertFalse(HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: PromptID.generateQuests.rawValue))
        XCTAssertFalse(HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: PromptID.extractPrinciple.rawValue))
        XCTAssertFalse(HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: PromptID.weeklyCalibration.rawValue))
        XCTAssertFalse(HistoryRepairPromptSupport.canStartHistoricalRetry(promptId: "unknownPrompt"))
    }

    // MARK: - HistoricalRetryCandidateStatus detail copy

    func testHistoricalRetryCandidateStatus_historyRepairDetailIsNonEmptyForAllStatuses() {
        for status in HistoricalRetryCandidateStatus.allCases {
            XCTAssertFalse(
                status.historyRepairDetail.isEmpty,
                "historyRepairDetail should not be empty for \(status.rawValue)"
            )
        }
    }

    func testHistoricalRetryCandidateStatus_historyRepairDetailDoesNotOverstatePersistence() {
        XCTAssertFalse(HistoricalRetryCandidateStatus.accepted.historyRepairDetail.contains("写入本日记录"))
        XCTAssertTrue(HistoricalRetryCandidateStatus.accepted.historyRepairDetail.contains("审计"))
        XCTAssertFalse(HistoricalRetryCandidateStatus.failed.historyRepairDetail.contains("再次尝试"))
    }

    // MARK: - PromptRun audit outcome

    func testPromptRunAuditOutcome_successfulRun() {
        let run = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1",
            outputSchemaVersion: 1,
            modelProvider: "test",
            modelName: "test",
            sessionMode: "standard",
            sourceRecordIds: ["id-1"],
            contextRecordIds: [],
            requestSummary: "ok",
            responseJSON: "{}",
            error: nil,
            createdAt: Date()
        )
        XCTAssertEqual(
            run.auditOutcome,
            PromptRunAuditOutcome.success
        )
        XCTAssertTrue(run.auditOutcomeLine.contains("成功"))
        XCTAssertTrue(run.auditOutcomeLine.contains("审计"))
    }

    func testPromptRunAuditOutcome_failedOrganizeCardsRepairable() {
        let run = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1",
            outputSchemaVersion: 1,
            modelProvider: "test",
            modelName: "test",
            sessionMode: "standard",
            sourceRecordIds: ["id-1", "id-2"],
            contextRecordIds: [],
            requestSummary: "failed",
            responseJSON: nil,
            error: "timeout",
            createdAt: Date()
        )
        XCTAssertEqual(
            run.auditOutcome,
            PromptRunAuditOutcome.repairableFromHistory
        )
        XCTAssertTrue(run.auditOutcomeLine.contains("修复"))
        XCTAssertTrue(run.auditOutcomeLine.contains("历史"))
    }

    func testPromptRunAuditOutcome_failedUnsupportedPrompt() {
        let run = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1",
            outputSchemaVersion: 1,
            modelProvider: "test",
            modelName: "test",
            sessionMode: "standard",
            sourceRecordIds: ["id-1"],
            contextRecordIds: [],
            requestSummary: "failed",
            responseJSON: nil,
            error: "timeout",
            createdAt: Date()
        )
        XCTAssertEqual(
            run.auditOutcome,
            PromptRunAuditOutcome.auditOnlyFailure
        )
        XCTAssertTrue(run.auditOutcomeLine.contains("仅审计"))
    }

    // MARK: - History repair summary

    func testHistoryRepairSummaryLine_mixedCounts() {
        let summary = HistoryRepairSummary(
            unresolvedCount: 2,
            reviewableCount: 1,
            completedCount: 1,
            problemCount: 1
        )
        let line = summary.summaryLine
        XCTAssertNotNil(line)
        XCTAssertTrue(line!.contains("2"), "should mention unresolved count")
        XCTAssertTrue(line!.contains("1"), "should mention reviewable or completed count")
    }

    func testHistoryRepairSummaryLine_emptyIsNil() {
        let summary = HistoryRepairSummary(
            unresolvedCount: 0,
            reviewableCount: 0,
            completedCount: 0,
            problemCount: 0
        )
        XCTAssertNil(summary.summaryLine)
    }

    // MARK: - Project merge audit display helpers

    func testMergeAuditDisplayLines_emptyHistoryProducesNoLines() {
        let lines = mergeAuditDisplayLines(from: [])
        XCTAssertTrue(lines.isEmpty, "empty merge history should produce no display lines")
    }

    func testMergeAuditDisplayLines_whitespaceOnlyHistoryIsIgnored() {
        let lines = mergeAuditDisplayLines(from: ["  ", "\t", "\n ", ""])
        XCTAssertTrue(lines.isEmpty, "whitespace-only entries should be filtered out")
    }

    func testMergeAuditDisplayLines_nonEmptyHistoryIsTrimmedAndPreserved() {
        let lines = mergeAuditDisplayLines(from: ["  merged from X  ", "archived source Y "])
        XCTAssertEqual(lines, ["merged from X", "archived source Y"])
    }

    func testCandidateEvidenceSummary_includesCountAndCompactRefs() {
        let candidate = ProjectMergeCandidate(
            sourceProjectId: UUID(),
            targetProjectId: UUID(),
            reason: "overlap",
            overlappingEvidenceRefs: ["abc12345-6789", "def67890-1234", "ghi11111-2222"]
        )
        let summary = candidateEvidenceSummary(candidate)
        XCTAssertTrue(summary.contains("3"), "should contain evidence count")
        XCTAssertTrue(summary.contains("abc12345"), "should contain compact ref preview")
    }

    func testCandidateEvidenceSummary_emptyRefsShowsCountOnly() {
        let candidate = ProjectMergeCandidate(
            sourceProjectId: UUID(),
            targetProjectId: UUID(),
            reason: "overlap",
            overlappingEvidenceRefs: []
        )
        let summary = candidateEvidenceSummary(candidate)
        XCTAssertTrue(summary.contains("0"), "should show zero count")
    }

    func testCandidateConsequenceLine_doesNotClaimLinksMovedOrSourceDeleted() {
        let line = candidateConsequenceLine()
        XCTAssertFalse(line.contains("删除"), "must not claim source is deleted")
        XCTAssertFalse(line.contains("移动"), "must not claim links are moved")
        XCTAssertTrue(line.contains("归档"), "should mention source is archived")
        XCTAssertTrue(line.contains("保留"), "should mention evidence links are retained")
    }

    // MARK: - Growth report drilldown helpers

    private func makeGrowthContribution(
        metric: GrowthMetric = .clarity,
        direction: MetricContributionDirection,
        delta: Double,
        title: String = "test",
        reason: String = "reason",
        sourceId: String = "source-id"
    ) -> MetricContribution {
        MetricContribution(
            id: UUID(),
            snapshotId: UUID(),
            metric: metric,
            direction: direction,
            delta: delta,
            title: title,
            reason: reason,
            sourceType: .dailyEntry,
            sourceId: sourceId,
            sourceDailyEntryId: UUID(),
            userFeedback: .none,
            candidateStatus: .accepted,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testGrowthContributionCountSummary_countsPositiveAndNegative() {
        let contributions = [
            makeGrowthContribution(direction: .positive, delta: 0.3),
            makeGrowthContribution(direction: .positive, delta: 0.1),
            makeGrowthContribution(direction: .negative, delta: -0.2)
        ]

        XCTAssertEqual(growthContributionCountSummary(contributions), "+2 / -1")
    }

    func testGrowthContributionCountSummary_emptyContributions() {
        XCTAssertEqual(growthContributionCountSummary([]), "+0 / -0")
    }

    func testGrowthLeadingContribution_choosesLargestAbsoluteDelta() {
        let contributions = [
            makeGrowthContribution(direction: .positive, delta: 0.2, title: "small"),
            makeGrowthContribution(direction: .negative, delta: -0.8, title: "large negative"),
            makeGrowthContribution(direction: .positive, delta: 0.5, title: "medium")
        ]

        XCTAssertEqual(growthLeadingContribution(contributions)?.title, "large negative")
    }

    func testGrowthLeadingContribution_emptyReturnsNil() {
        XCTAssertNil(growthLeadingContribution([]))
    }

    func testGrowthMetricReasonDisplay_trimsWhitespace() {
        XCTAssertEqual(growthMetricReasonDisplay("  实际原因  "), "实际原因")
    }

    func testGrowthMetricReasonDisplay_emptyStringReturnsNil() {
        XCTAssertNil(growthMetricReasonDisplay("  "))
    }

    func testGrowthMetricReasonDisplay_nilInputReturnsNil() {
        XCTAssertNil(growthMetricReasonDisplay(nil))
    }

    func testGrowthFallbackReason_presentWhenReasonMissingAndContributionsExist() {
        let contributions = [
            makeGrowthContribution(direction: .positive, delta: 0.3)
        ]

        let fallback = growthMetricFallbackReason(reason: nil, contributions: contributions)

        XCTAssertEqual(fallback, "根据已接受贡献归因，点击查看来源证据。")
    }

    func testGrowthFallbackReason_absentWhenReasonMissingAndNoContributions() {
        XCTAssertNil(growthMetricFallbackReason(reason: nil, contributions: []))
    }

    func testGrowthFallbackReason_absentWhenReasonPresent() {
        let contributions = [
            makeGrowthContribution(direction: .positive, delta: 0.3)
        ]

        XCTAssertNil(growthMetricFallbackReason(reason: "有原因", contributions: contributions))
    }

    func testGrowthMetricDisplayTitle_returnsCorrectTitle() {
        XCTAssertEqual(growthMetricDisplayTitle(.clarity), "清晰度")
        XCTAssertEqual(growthMetricDisplayTitle(.valueJudgment), "价值判断")
        XCTAssertEqual(growthMetricDisplayTitle(.executionReliability), "执行可靠性")
        XCTAssertEqual(growthMetricDisplayTitle(.calibration), "校准")
        XCTAssertEqual(growthMetricDisplayTitle(.reflectionDepth), "反思深度")
    }

    func testHistoryRecordContainsDeepLinkSource_matchesQuestContributionSource() {
        let quest = Quest(
            type: .main,
            title: "发出会议纪要",
            whyItMatters: "减少遗漏",
            completionCriteria: "群内发出 Action",
            expectedResistance: "会后疲劳",
            reflectionQuestion: "是否减少追问"
        )
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "任务复盘", state: .sessionComplete),
            quests: [quest]
        )
        let deepLink = HistoryDeepLink(
            dailyEntryId: record.draft.id,
            sourceId: quest.id.uuidString,
            sourceType: .quest
        )

        XCTAssertTrue(historyRecordContainsDeepLinkSource(deepLink, in: record))
    }

    func testHistoryRecordContainsDeepLinkSource_matchesProjectContributionSource() {
        let projectId = UUID()
        let quest = Quest(
            type: .main,
            title: "发出会议纪要",
            whyItMatters: "减少遗漏",
            completionCriteria: "群内发出 Action",
            expectedResistance: "会后疲劳",
            reflectionQuestion: "是否减少追问"
        )
        let projectLink = ProjectLink(
            projectId: projectId,
            sourceType: .quest,
            sourceId: quest.id.uuidString,
            linkType: .task,
            isUserConfirmed: true
        )
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "项目复盘", state: .sessionComplete),
            quests: [quest],
            projectLinks: [projectLink]
        )
        let deepLink = HistoryDeepLink(
            dailyEntryId: record.draft.id,
            sourceId: projectId.uuidString,
            sourceType: .project
        )

        XCTAssertTrue(historyRecordContainsDeepLinkSource(deepLink, in: record))
        XCTAssertTrue(isProjectLinkHighlighted(projectLink, highlightedSourceId: projectId.uuidString))
    }

    func testHistoryRecordContainsDeepLinkSource_rejectsUnresolvedProjectContributionSource() {
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "项目复盘", state: .sessionComplete),
            projectLinks: [
                ProjectLink(
                    projectId: UUID(),
                    sourceType: .dailyEntry,
                    sourceId: UUID().uuidString,
                    linkType: .evidence,
                    isUserConfirmed: true
                )
            ]
        )
        let deepLink = HistoryDeepLink(
            dailyEntryId: record.draft.id,
            sourceId: UUID().uuidString,
            sourceType: .project
        )

        XCTAssertFalse(historyRecordContainsDeepLinkSource(deepLink, in: record))
    }

    // MARK: - Project detail display helpers

    func testProjectThinkingChangeHeadline_returnsInsufficientEvidence_whenNoBeforeAfter() {
        XCTAssertEqual(projectThinkingChangeHeadline(hasBeforeAfterEvidence: false), "证据不足")
    }

    func testProjectThinkingChangeHeadline_returnsAwaitingInsight_whenBeforeAfterExists() {
        let headline = projectThinkingChangeHeadline(hasBeforeAfterEvidence: true)
        XCTAssertNotEqual(headline, "证据不足")
        XCTAssertFalse(headline.isEmpty)
    }

    func testProjectThinkingChangeBody_isNonEmptyInBothCases() {
        XCTAssertFalse(projectThinkingChangeBody(hasBeforeAfterEvidence: false).isEmpty)
        XCTAssertFalse(projectThinkingChangeBody(hasBeforeAfterEvidence: true).isEmpty)
    }

    func testProjectOverviewFactLines_includesRealProjectFields() {
        let lines = projectOverviewFactLines(
            goal: "提高会议效率",
            successCriteria: "会议时间缩短30%",
            currentBottleneck: "负责人不明确",
            nextBet: nil,
            openQuestions: nil,
            evidenceGapMessage: ""
        )
        let titles = lines.map(\.title)
        XCTAssertTrue(titles.contains("目标"))
        XCTAssertTrue(titles.contains("成功标准"))
        XCTAssertTrue(titles.contains("当前阻塞"))
    }

    func testProjectOverviewFactLines_omitsMissingOptionalPlaceholders() {
        let lines = projectOverviewFactLines(
            goal: "提高效率",
            successCriteria: "缩短时间",
            currentBottleneck: nil,
            nextBet: nil,
            openQuestions: nil,
            evidenceGapMessage: ""
        )
        let titles = lines.map(\.title)
        XCTAssertFalse(titles.contains("当前阻塞"), "nil bottleneck should not appear")
        XCTAssertFalse(titles.contains("下一步押注"), "nil nextBet should not appear")
        XCTAssertFalse(titles.contains("开放问题"), "nil openQuestions should not appear")
        XCTAssertFalse(titles.contains("证据缺口"), "empty gap message should not appear")
    }

    func testProjectOverviewFactLines_trimsAndOmitsWhitespaceOnlyValues() {
        let lines = projectOverviewFactLines(
            goal: "  提高效率  ",
            successCriteria: "   ",
            currentBottleneck: "\n\t",
            nextBet: "  发出会议纪要模板  ",
            openQuestions: ["  谁负责推进？  ", "   "],
            evidenceGapMessage: "  缺少验证证据  "
        )

        XCTAssertEqual(
            lines,
            [
                ProjectOverviewFactLine(title: "目标", value: "提高效率"),
                ProjectOverviewFactLine(title: "下一步押注", value: "发出会议纪要模板"),
                ProjectOverviewFactLine(title: "开放问题", value: "谁负责推进？"),
                ProjectOverviewFactLine(title: "证据缺口", value: "缺少验证证据"),
            ]
        )
    }

    func testProjectOverviewFactLines_includesDigestDerivedRowsWhenAvailable() {
        let lines = projectOverviewFactLines(
            goal: nil,
            successCriteria: nil,
            currentBottleneck: nil,
            nextBet: "验证：发出会议纪要模板",
            openQuestions: nil,
            evidenceGapMessage: "缺少任务或验证证据"
        )
        let titles = lines.map(\.title)
        XCTAssertTrue(titles.contains("下一步押注"), "should include nextBet when present")
        XCTAssertTrue(titles.contains("证据缺口"), "should include gap message when non-empty")
    }

    func testProjectOverviewFactLines_emptyWhenNoRealData() {
        let lines = projectOverviewFactLines(
            goal: nil,
            successCriteria: nil,
            currentBottleneck: nil,
            nextBet: nil,
            openQuestions: nil,
            evidenceGapMessage: ""
        )
        XCTAssertTrue(lines.isEmpty, "should produce no fact lines when all inputs are nil/empty")
    }

    func testProjectPrincipleEvidenceEntries_returnsOnlyPrincipleSourcesWithHistoryEvidence() {
        let projectId = UUID()
        let principle = PrincipleAsset(
            title: "先定义成功标准",
            summary: "行动前写清可验证结果。",
            triggerContext: "任务反复返工",
            actions: ["写出验收标准"],
            successCriteria: "行动前能说清完成条件",
            exceptions: "紧急止血时先做最小动作"
        )
        let quest = Quest(
            type: .main,
            title: "发出验收模板",
            whyItMatters: "减少返工",
            completionCriteria: "群内发出模板",
            expectedResistance: "时间紧",
            reflectionQuestion: "是否减少追问"
        )
        let card = ThinkingCard(type: .decision, title: "先同步口径", body: "先统一验收标准。", isConfirmed: true)
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "原则和任务复盘", state: .sessionComplete),
            cards: [card],
            quests: [quest],
            principles: [principle]
        )
        let principleLink = ProjectLink(
            projectId: projectId,
            sourceType: .principle,
            sourceId: principle.id.uuidString,
            linkType: .principle,
            isUserConfirmed: true
        )
        let questLink = ProjectLink(
            projectId: projectId,
            sourceType: .quest,
            sourceId: quest.id.uuidString,
            linkType: .task,
            isUserConfirmed: true
        )
        let cardLink = ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: card.id.uuidString,
            linkType: .decision,
            isUserConfirmed: true
        )
        let item = ProjectEvidenceBoardItem(
            id: projectId,
            name: "会议机制",
            entries: [(questLink, record), (principleLink, record), (cardLink, record)]
        )

        let entries = projectPrincipleEvidenceEntries(from: item)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].link.sourceType, .principle)
        XCTAssertEqual(entries[0].link.sourceId, principle.id.uuidString)
        XCTAssertEqual(entries[0].record.draft.id, record.draft.id)
    }

    func testProjectPrincipleEvidenceEntries_emptyWhenProjectHasNoPrincipleSources() {
        let projectId = UUID()
        let quest = Quest(
            type: .main,
            title: "发出验收模板",
            whyItMatters: "减少返工",
            completionCriteria: "群内发出模板",
            expectedResistance: "时间紧",
            reflectionQuestion: "是否减少追问"
        )
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "任务复盘", state: .sessionComplete),
            quests: [quest]
        )
        let item = ProjectEvidenceBoardItem(
            id: projectId,
            name: "会议机制",
            entries: [
                (
                    ProjectLink(
                        projectId: projectId,
                        sourceType: .quest,
                        sourceId: quest.id.uuidString,
                        linkType: .task,
                        isUserConfirmed: true
                    ),
                    record
                )
            ]
        )

        XCTAssertTrue(projectPrincipleEvidenceEntries(from: item).isEmpty)
    }

    func testProjectPrincipleEvidenceEntries_excludesUnresolvedPrincipleSources() {
        let projectId = UUID()
        let missingPrincipleId = UUID()
        let record = HistoryRecord(
            draft: DailyEntryDraft(rawText: "没有原则资产的复盘", state: .sessionComplete),
            principles: []
        )
        let item = ProjectEvidenceBoardItem(
            id: projectId,
            name: "会议机制",
            entries: [
                (
                    ProjectLink(
                        projectId: projectId,
                        sourceType: .principle,
                        sourceId: missingPrincipleId.uuidString,
                        linkType: .principle,
                        isUserConfirmed: true
                    ),
                    record
                )
            ]
        )

        XCTAssertTrue(projectPrincipleEvidenceEntries(from: item).isEmpty)
    }

    // MARK: - Project status filter helpers

    private func makeBoardItem(id: UUID = UUID()) -> ProjectEvidenceBoardItem {
        ProjectEvidenceBoardItem(
            id: id,
            name: "Test Project",
            entries: []
        )
    }

    func testProjectStatusFilteredItems_nilStatusReturnsAllItems() {
        let id1 = UUID()
        let id2 = UUID()
        let items = [makeBoardItem(id: id1), makeBoardItem(id: id2)]
        let projectsById: [UUID: Project] = [
            id1: Project(id: id1, name: "A", goal: "", successCriteria: "", status: .active),
            id2: Project(id: id2, name: "B", goal: "", successCriteria: "", status: .watching),
        ]

        let filtered = projectStatusFilteredItems(items, projectsById: projectsById, status: nil)

        XCTAssertEqual(filtered.count, 2, "nil filter should return all items")
    }

    func testProjectStatusFilteredItems_activeFilterReturnsOnlyActive() {
        let activeId = UUID()
        let watchingId = UUID()
        let items = [makeBoardItem(id: activeId), makeBoardItem(id: watchingId)]
        let projectsById: [UUID: Project] = [
            activeId: Project(id: activeId, name: "Active", goal: "", successCriteria: "", status: .active),
            watchingId: Project(id: watchingId, name: "Watching", goal: "", successCriteria: "", status: .watching),
        ]

        let filtered = projectStatusFilteredItems(items, projectsById: projectsById, status: .active)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].id, activeId)
    }

    func testProjectStatusFilteredItems_missingProjectPreservedForNil_excludedForConcrete() {
        let knownId = UUID()
        let missingId = UUID()
        let items = [makeBoardItem(id: knownId), makeBoardItem(id: missingId)]
        let projectsById: [UUID: Project] = [
            knownId: Project(id: knownId, name: "Known", goal: "", successCriteria: "", status: .active),
        ]

        let nilFiltered = projectStatusFilteredItems(items, projectsById: projectsById, status: nil)
        XCTAssertEqual(nilFiltered.count, 2, "nil filter should preserve items missing from projectsById")

        let activeFiltered = projectStatusFilteredItems(items, projectsById: projectsById, status: .active)
        XCTAssertEqual(activeFiltered.count, 1, "concrete filter should exclude items missing from projectsById")
        XCTAssertEqual(activeFiltered[0].id, knownId)
    }

    func testProjectBoardCountText_concreteFilterDistinguishesFilteredFromTotal() {
        let text = projectBoardCountText(filteredCount: 2, totalCount: 5, filterStatus: .active)

        XCTAssertTrue(text.contains("2"), "should show filtered count")
        XCTAssertTrue(text.contains("5"), "should show total count")
    }
}
