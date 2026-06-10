import CryptoKit
import XCTest
import GRDB
@testable import MingSi

final class PersistenceCoreTests: XCTestCase {

    private var database: AppDatabase!
    private var dbQueue: DatabaseQueue!

    override func setUp() {
        super.setUp()
        dbQueue = try! DatabaseQueue()
        let migrator = AppDatabase.makeMigrator()
        try! migrator.migrate(dbQueue)
        database = try! AppDatabase(dbQueue: dbQueue)
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

    func testLatestDraft_prefersNewestEntryDateOverLaterUpdateTimestamp() async throws {
        let repo = SQLiteDailyEntryRepository(database: database)
        let today = DailyEntryDraft(rawText: "Today entry", state: .verifyYesterday)
        let yesterday = DailyEntryDraft(
            date: Calendar.current.date(byAdding: .day, value: -1, to: today.date) ?? today.date,
            rawText: "Yesterday entry",
            state: .sessionComplete
        )

        try await repo.saveDraft(today)
        try await Task.sleep(for: .milliseconds(50))
        try await repo.saveDraft(yesterday)

        let latest = try await repo.latestDraft()
        XCTAssertEqual(latest?.id, today.id)
        XCTAssertEqual(latest?.rawText, "Today entry")
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
        let loaded = try await repo.latestDraft()
        let unwrapped = try XCTUnwrap(loaded)

        XCTAssertEqual(unwrapped.sessionMode, .deep)
        XCTAssertTrue(unwrapped.hasSelectedSessionMode)
        XCTAssertEqual(unwrapped.selectedLens, .opposingView)
        XCTAssertEqual(unwrapped.yesterdayCompletion, .partial)
        XCTAssertEqual(unwrapped.yesterdayValueRating, .medium)
        XCTAssertEqual(unwrapped.state, .answerQuestions)
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

    func testUpdateQuestStatus_marksActiveQuestResolved() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let questRepo = SQLiteQuestRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Quest status test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let quest = Quest(type: .main, title: "Active main", whyItMatters: "W",
                          completionCriteria: "C", expectedResistance: "E",
                          reflectionQuestion: "R", status: .active)
        try await questRepo.saveQuest(quest, sourceDailyEntryId: draft.id)

        try await questRepo.updateQuestStatus(.completed, questId: quest.id)

        let active = try await questRepo.activeMainQuest()
        XCTAssertNil(active)

        let loaded = try await questRepo.quests(for: draft.id)
        XCTAssertEqual(loaded.first?.status, .completed)
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

    func testUpdatePrincipleStatus_archivedPrincipleIsHiddenFromVisibleReads() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Archive principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let principle = PrincipleAsset(
            title: "Visual QA - Meeting owner",
            summary: "Clarify ownership before execution.",
            triggerContext: "Meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: draft.id)

        try await principleRepo.updatePrincipleStatus(.archived, principleId: principle.id)

        let activePrinciples = try await principleRepo.activePrinciples()
        let allPrinciples = try await principleRepo.allPrinciples()
        let storedPrinciples = try await principleRepo.principles(for: draft.id)
        XCTAssertTrue(activePrinciples.isEmpty)
        XCTAssertTrue(allPrinciples.isEmpty)
        XCTAssertTrue(storedPrinciples.isEmpty)
    }

    func testDeletePrinciple_removesPrincipleFromVisibleReadsAndExport() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let evidenceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Delete principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let principle = PrincipleAsset(
            title: "Visual QA - stale test rule",
            summary: "This seed should be removable from the local principle library.",
            triggerContext: "Manual test data cleanup",
            actions: ["Delete stale seed"],
            successCriteria: "The rule no longer appears in principle assets.",
            exceptions: "None",
            status: .needsReview
        )
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: draft.id)
        try await feedbackRepo.saveFeedback(
            PrincipleRecallFeedback(
                principleId: principle.id,
                sourceDailyEntryId: draft.id,
                promptId: .generateQuestions,
                retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                retrievalReason: "manual cleanup regression",
                feedback: .misrecalled
            )
        )
        try await evidenceRepo.saveEvidence(
            PrinciplePracticeEvidence(
                principleId: principle.id,
                sourceDailyEntryId: draft.id,
                evidenceSource: .manual,
                strength: .attempted,
                evidenceSummary: "manual cleanup regression"
            )
        )

        try await principleRepo.deletePrinciple(principle.id)

        let activePrinciples = try await principleRepo.activePrinciples()
        let allPrinciples = try await principleRepo.allPrinciples()
        let storedPrinciples = try await principleRepo.principles(for: draft.id)
        let feedback = try await feedbackRepo.feedback(for: principle.id, limit: 10)
        let evidence = try await evidenceRepo.evidence(for: principle.id, limit: 10)
        XCTAssertTrue(activePrinciples.isEmpty)
        XCTAssertTrue(allPrinciples.isEmpty)
        XCTAssertTrue(storedPrinciples.isEmpty)
        XCTAssertTrue(feedback.isEmpty)
        XCTAssertTrue(evidence.isEmpty)

        let data = try await exportRepo.exportJSON()
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(payload["sections"] as? [String: Any])
        let principleRows = try XCTUnwrap(sections["principle_assets"] as? [[String: Any]])
        XCTAssertTrue(principleRows.isEmpty)
    }

    func testUpdatePrincipleStatus_movesActivePrincipleToNeedsReview() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Needs review principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let principle = PrincipleAsset(
            title: "Meeting owner rule",
            summary: "Clarify ownership before execution.",
            triggerContext: "Meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .active
        )
        try await principleRepo.savePrinciple(principle, sourceDailyEntryId: draft.id)

        try await principleRepo.updatePrincipleStatus(.needsReview, principleId: principle.id)

        let activePrinciples = try await principleRepo.activePrinciples()
        let storedPrinciples = try await principleRepo.principles(for: draft.id)
        XCTAssertTrue(activePrinciples.isEmpty)
        XCTAssertEqual(storedPrinciples.first?.status, .needsReview)
    }

    func testUpdatePrinciple_reactivatesNeedsReviewPrincipleAndPreservesSourceLink() async throws {
        let entryRepo = SQLiteDailyEntryRepository(database: database)
        let principleRepo = SQLitePrincipleRepository(database: database)

        let draft = DailyEntryDraft(rawText: "Repair principle test", state: .sessionComplete)
        try await entryRepo.saveDraft(draft)

        let needsReview = PrincipleAsset(
            title: "Meeting owner rule",
            summary: "Too broad.",
            triggerContext: "Every meeting",
            actions: ["Invite everyone"],
            successCriteria: "Everyone aligned.",
            exceptions: "",
            status: .needsReview
        )
        try await principleRepo.savePrinciple(needsReview, sourceDailyEntryId: draft.id)

        let repaired = PrincipleAsset(
            id: needsReview.id,
            title: "Clarify accountable owner",
            summary: "Before a cross-functional meeting ends, name one accountable owner.",
            triggerContext: "Cross-functional meeting",
            actions: ["Name owner", "Name acceptance evidence"],
            successCriteria: "Every action item has one owner and one evidence criterion.",
            exceptions: "Pure FYI syncs can stay async.",
            status: .active
        )
        try await principleRepo.updatePrinciple(repaired)

        let activePrinciples = try await principleRepo.activePrinciples()
        let allPrinciples = try await principleRepo.allPrinciples()
        let storedForEntry = try await principleRepo.principles(for: draft.id)
        XCTAssertEqual(activePrinciples.map(\.id), [needsReview.id])
        XCTAssertEqual(allPrinciples.map(\.id), [needsReview.id])
        XCTAssertEqual(storedForEntry.map(\.id), [needsReview.id])
        XCTAssertEqual(storedForEntry.first?.title, "Clarify accountable owner")
        XCTAssertEqual(storedForEntry.first?.actions, ["Name owner", "Name acceptance evidence"])
        XCTAssertEqual(storedForEntry.first?.status, .active)
    }

    func testPrincipleRecallFeedback_persistsNotApplicableAndMisrecalledEvents() async throws {
        let repo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let principleID = UUID()
        let promptRunID = UUID()
        let entryID = UUID()

        let notApplicable = PrincipleRecallFeedback(
            principleId: principleID,
            promptRunId: promptRunID,
            sourceDailyEntryId: entryID,
            promptId: .generateQuestions,
            retrievalPolicyVersion: "principle-retrieval.local-keyword.v1",
            retrievalReason: "Matched meeting ownership with 会前明确负责人 using local keyword policy; score=4.",
            feedback: .notApplicable,
            note: "这次是临时同步，不需要负责人机制。",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let misrecalled = PrincipleRecallFeedback(
            principleId: principleID,
            promptRunId: promptRunID,
            sourceDailyEntryId: entryID,
            promptId: .generateQuests,
            retrievalPolicyVersion: "principle-retrieval.local-keyword.v1",
            retrievalReason: "Matched keyword overlap with 会前明确负责人 using local keyword policy; score=2.",
            feedback: .misrecalled,
            note: "关键词撞上了，但场景不是会议。",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        try await repo.saveFeedback(notApplicable)
        try await repo.saveFeedback(misrecalled)

        let loaded = try await repo.feedback(for: principleID, limit: 10)
        XCTAssertEqual(loaded.map(\.feedback), [.misrecalled, .notApplicable])
        XCTAssertEqual(loaded.first?.promptId, .generateQuests)
        XCTAssertEqual(loaded.first?.retrievalPolicyVersion, "principle-retrieval.local-keyword.v1")
        XCTAssertEqual(loaded.first?.note, "关键词撞上了，但场景不是会议。")
    }

    func testPrinciplePracticeEvidence_persistsPracticeEvidenceForPrinciple() async throws {
        let repo = SQLitePrinciplePracticeEvidenceRepository(database: database)
        let principleID = UUID()
        let entryID = UUID()
        let questID = UUID()
        let verificationID = UUID()
        let earlier = PrinciplePracticeEvidence(
            principleId: principleID,
            sourceDailyEntryId: entryID,
            questId: questID,
            verificationId: verificationID,
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "用户在复盘中说明先写负责人再推进会议。",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let later = PrinciplePracticeEvidence(
            principleId: principleID,
            sourceDailyEntryId: entryID,
            questId: questID,
            verificationId: nil,
            evidenceSource: .quest,
            strength: .attempted,
            evidenceSummary: "明日任务明确要求先确认负责人。",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        try await repo.saveEvidence(earlier)
        try await repo.saveEvidence(later)

        let loaded = try await repo.evidence(for: principleID, limit: 10)
        XCTAssertEqual(loaded.map(\.strength), [.attempted, .intentionalPractice])
        XCTAssertEqual(loaded.first?.evidenceSource, .quest)
        XCTAssertEqual(loaded.first?.sourceDailyEntryId, entryID)
        XCTAssertEqual(loaded.last?.verificationId, verificationID)
        XCTAssertEqual(loaded.last?.evidenceSummary, "用户在复盘中说明先写负责人再推进会议。")
    }

    func testPrinciplePracticeEvidence_loadsVerificationEvidenceByBusinessKey() async throws {
        let repo = SQLitePrinciplePracticeEvidenceRepository(database: database)
        let principleID = UUID()
        let entryID = UUID()
        let questID = UUID()
        let verificationID = UUID()
        let matching = PrinciplePracticeEvidence(
            principleId: principleID,
            sourceDailyEntryId: entryID,
            questId: questID,
            verificationId: verificationID,
            evidenceSource: .verification,
            strength: .intentionalPractice,
            evidenceSummary: "验证显示会前明确负责人被练习。"
        )
        let differentSource = PrinciplePracticeEvidence(
            principleId: principleID,
            sourceDailyEntryId: entryID,
            questId: questID,
            verificationId: nil,
            evidenceSource: .quest,
            strength: .attempted,
            evidenceSummary: "任务要求会前明确负责人。"
        )

        try await repo.saveEvidence(matching)
        try await repo.saveEvidence(differentSource)

        let loaded = try await repo.evidence(
            for: principleID,
            sourceDailyEntryId: entryID,
            questId: questID,
            evidenceSource: .verification
        )

        XCTAssertEqual(loaded?.id, matching.id)
        XCTAssertEqual(loaded?.verificationId, verificationID)
        XCTAssertEqual(loaded?.evidenceSource, .verification)
    }

    // MARK: - VerificationRepository

    func testSaveVerification_andLoadByEntryAndQuest() async throws {
        let repo = SQLiteVerificationRepository(database: database)
        let entryId = UUID()
        let questId = UUID()

        let verification = Verification(
            questId: questId,
            questTitle: "Verify ownership",
            sourceDailyEntryId: entryId,
            completion: .partial,
            valueRating: .medium,
            calibrationNote: "Criteria were partly met.",
            likelyIssue: "unclear_criteria",
            recommendation: "Make completion evidence visible."
        )

        try await repo.saveVerification(verification)

        let byEntry = try await repo.verification(for: entryId)
        XCTAssertEqual(byEntry?.questTitle, "Verify ownership")
        XCTAssertEqual(byEntry?.completion, .partial)
        XCTAssertEqual(byEntry?.likelyIssue, "unclear_criteria")

        let byQuest = try await repo.verification(forQuestId: questId)
        XCTAssertEqual(byQuest?.id, verification.id)
    }

    // MARK: - LensSessionRepository

    func testSaveLensSession_persistsQuestionsAndAnswers() async throws {
        let repo = SQLiteLensSessionRepository(database: database)
        let entryId = UUID()
        let questions = [
            ReflectionQuestion(
                question: "What evidence changed?",
                whyItMatters: "It calibrates judgment.",
                answer: "The owner acknowledged the criteria."
            )
        ]

        let session = LensSession(
            dailyEntryId: entryId,
            selectedLens: .evidenceCheck,
            questions: questions
        )

        try await repo.saveLensSession(session)

        let loaded = try await repo.lensSession(for: entryId)
        XCTAssertEqual(loaded?.selectedLens, .evidenceCheck)
        XCTAssertEqual(loaded?.questions.count, 1)
        XCTAssertEqual(loaded?.questions.first?.answer, "The owner acknowledged the criteria.")
    }

    func testSaveLensSession_updatesExistingDailySession() async throws {
        let repo = SQLiteLensSessionRepository(database: database)
        let entryId = UUID()

        try await repo.saveLensSession(
            LensSession(
                dailyEntryId: entryId,
                selectedLens: .evidenceCheck,
                questions: [ReflectionQuestion(question: "Q1", whyItMatters: "M1")]
            )
        )
        try await repo.saveLensSession(
            LensSession(
                dailyEntryId: entryId,
                selectedLens: .opposingView,
                questions: [ReflectionQuestion(question: "Q2", whyItMatters: "M2", answer: "A2")]
            )
        )

        let loaded = try await repo.lensSession(for: entryId)
        XCTAssertEqual(loaded?.selectedLens, .opposingView)
        XCTAssertEqual(loaded?.questions.first?.question, "Q2")

        try await dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM lens_sessions WHERE daily_entry_id = ?", arguments: [entryId.uuidString])
            XCTAssertEqual(count, 1)
        }
    }

    // MARK: - Project Evidence Repositories

    func testSaveProject_andLoadPreservesEvidenceFields() async throws {
        let repo = SQLiteProjectRepository(database: database)
        let project = Project(
            name: "会议效率",
            goal: "减少会议后的执行歧义",
            successCriteria: "每次关键会议都有结论、Action 和负责人",
            currentBottleneck: "会前确认事项不够明确",
            openQuestions: ["哪些会议需要完整模板？"],
            status: .watching,
            createdBy: .user,
            confidence: 0.93,
            mergeHistory: ["merged-old-project"],
            fieldRevisions: ["goal": "从泛泛推进改成降低执行歧义"]
        )

        try await repo.saveProject(project)

        let loaded = try await repo.project(id: project.id)
        XCTAssertEqual(loaded?.name, "会议效率")
        XCTAssertEqual(loaded?.goal, project.goal)
        XCTAssertEqual(loaded?.successCriteria, project.successCriteria)
        XCTAssertEqual(loaded?.currentBottleneck, project.currentBottleneck)
        XCTAssertEqual(loaded?.openQuestions, project.openQuestions)
        XCTAssertEqual(loaded?.status, .watching)
        XCTAssertEqual(loaded?.createdBy, .user)
        XCTAssertEqual(loaded?.confidence, 0.93)
        XCTAssertEqual(loaded?.mergeHistory, ["merged-old-project"])
        XCTAssertEqual(loaded?.fieldRevisions["goal"], "从泛泛推进改成降低执行歧义")
    }

    func testSaveProjectCandidate_preservesSourceRefsAndStatus() async throws {
        let repo = SQLiteProjectCandidateRepository(database: database)
        let acceptedProjectId = UUID()
        let candidate = ProjectCandidate(
            suggestedName: "跨团队协作边界",
            suggestedGoal: "明确协作边界",
            suggestedBottleneck: "责任边界经常在会议后才暴露",
            suggestedSuccessCriteria: "关键交付前确认责任人和验收方式",
            reason: "14 天内多次出现会议后责任不清。",
            sourceRefs: ["card-1", "quest-2"],
            privacyReviewNote: "名称已抽象化",
            status: .renamedAndAccepted,
            acceptedProjectId: acceptedProjectId,
            createdBy: .aiSuggested,
            confidence: 0.82
        )

        try await repo.saveCandidate(candidate)

        let loaded = try await repo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.suggestedName, "跨团队协作边界")
        XCTAssertEqual(loaded?.suggestedBottleneck, "责任边界经常在会议后才暴露")
        XCTAssertEqual(loaded?.reason, "14 天内多次出现会议后责任不清。")
        XCTAssertEqual(loaded?.sourceRefs, ["card-1", "quest-2"])
        XCTAssertEqual(loaded?.privacyReviewNote, "名称已抽象化")
        XCTAssertEqual(loaded?.status, .renamedAndAccepted)
        XCTAssertEqual(loaded?.acceptedProjectId, acceptedProjectId)
        XCTAssertEqual(loaded?.confidence, 0.82)
    }

    func testSaveProjectCandidate_emptySourceRefsThrowsValidation() async throws {
        let repo = SQLiteProjectCandidateRepository(database: database)
        let candidate = ProjectCandidate(
            suggestedName: "无证据候选",
            reason: "Should fail",
            sourceRefs: []
        )

        try await assertValidationFailure {
            try await repo.saveCandidate(candidate)
        }
    }

    func testUpdateProjectCandidateStatus_preservesAuditRecord() async throws {
        let repo = SQLiteProjectCandidateRepository(database: database)
        let candidate = ProjectCandidate(
            suggestedName: "会议效率",
            reason: "Repeated evidence.",
            sourceRefs: ["entry-1"]
        )
        try await repo.saveCandidate(candidate)

        try await repo.updateCandidateStatus(.rejected, candidateId: candidate.id)

        let loaded = try await repo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.status, .rejected)
        XCTAssertEqual(loaded?.sourceRefs, ["entry-1"])
    }

    func testSaveProjectLink_preservesSourceAndConfirmation() async throws {
        let repo = SQLiteProjectLinkRepository(database: database)
        let projectId = UUID()
        let link = ProjectLink(
            projectId: projectId,
            sourceType: .thinkingCard,
            sourceId: "card-123",
            linkType: .blocker,
            confidence: 0.67,
            isUserConfirmed: true
        )

        try await repo.saveLink(link)

        let links = try await repo.links(for: projectId)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.sourceType, .thinkingCard)
        XCTAssertEqual(links.first?.sourceId, "card-123")
        XCTAssertEqual(links.first?.linkType, .blocker)
        XCTAssertEqual(links.first?.confidence, 0.67)
        XCTAssertEqual(links.first?.isUserConfirmed, true)
    }

    func testSaveProjectLink_emptySourceIdThrowsValidation() async throws {
        let repo = SQLiteProjectLinkRepository(database: database)
        let link = ProjectLink(
            projectId: UUID(),
            sourceType: .quest,
            sourceId: "   ",
            linkType: .task
        )

        try await assertValidationFailure {
            try await repo.saveLink(link)
        }
    }

    func testSaveProjectMergeCandidate_preservesEvidenceRefsAndStatusUpdate() async throws {
        let repo = SQLiteProjectMergeCandidateRepository(database: database)
        let candidate = ProjectMergeCandidate(
            sourceProjectId: UUID(),
            targetProjectId: UUID(),
            reason: "目标和阻塞高度重叠。",
            overlappingEvidenceRefs: ["link-1", "verification-2"]
        )

        try await repo.saveMergeCandidate(candidate)
        try await repo.updateMergeCandidateStatus(.dismissed, candidateId: candidate.id)

        let loaded = try await repo.mergeCandidate(id: candidate.id)
        XCTAssertEqual(loaded?.reason, "目标和阻塞高度重叠。")
        XCTAssertEqual(loaded?.overlappingEvidenceRefs, ["link-1", "verification-2"])
        XCTAssertEqual(loaded?.status, .dismissed)
    }

    func testSaveProjectInsight_preservesBeforeAfterAndFeedback() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let projectId = UUID()
        let insight = ProjectInsight(
            projectId: projectId,
            insightType: .thinkingChange,
            title: "问题定义更具体",
            summary: "从推进项目转向验证责任边界。",
            beforeText: "推进项目",
            afterText: "确认当前阻塞是边界问题还是设计问题",
            sourceRefs: ["card-old", "card-new"],
            confidence: 0.8
        )

        try await repo.saveInsight(insight)
        try await repo.updateInsightFeedback(.inaccurate, insightId: insight.id)

        let loaded = try await repo.insights(for: projectId)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.insightType, .thinkingChange)
        XCTAssertEqual(loaded.first?.title, "问题定义更具体")
        XCTAssertEqual(loaded.first?.beforeText, "推进项目")
        XCTAssertEqual(loaded.first?.afterText, "确认当前阻塞是边界问题还是设计问题")
        XCTAssertEqual(loaded.first?.sourceRefs, ["card-old", "card-new"])
        XCTAssertEqual(loaded.first?.userFeedback, .inaccurate)
    }

    func testSaveProjectInsight_thinkingChangeWithoutBeforeAfterThrowsValidation() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let insight = ProjectInsight(
            projectId: UUID(),
            insightType: .thinkingChange,
            title: "证据不足的变化",
            summary: "Should fail",
            sourceRefs: ["card-1"]
        )

        try await assertValidationFailure {
            try await repo.saveInsight(insight)
        }
    }

    func testSaveProjectInsight_blockerChangeWithoutBeforeAfterThrowsValidation() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let insight = ProjectInsight(
            projectId: UUID(),
            insightType: .blockerChange,
            title: "证据不足的阻塞变化",
            summary: "Should fail",
            sourceRefs: ["card-1"]
        )

        try await assertValidationFailure {
            try await repo.saveInsight(insight)
        }
    }

    func testSaveProjectInsight_emptySourceRefsThrowsValidation() async throws {
        let repo = SQLiteProjectInsightRepository(database: database)
        let insight = ProjectInsight(
            projectId: UUID(),
            insightType: .progress,
            title: "无来源进展",
            summary: "Should fail",
            sourceRefs: []
        )

        try await assertValidationFailure {
            try await repo.saveInsight(insight)
        }
    }

    // MARK: - PromptRunRepository

    func testSavePromptRun_andLoadRecent() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let run = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            promptSourceKind: .imported,
            promptPackId: "imported.prompt.audit",
            promptPackVersion: "2026.06",
            promptPackDisplayName: "Imported Prompt Audit",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1", "card-1"],
            contextRecordIds: ["entry-1", "card-1", "principle-1"],
            requestSummary: "mode=standard; rawText=demo",
            responseJSON: #"{"cards":[]}"#
        )

        try await repo.savePromptRun(run)

        let recent = try await repo.recentPromptRuns(limit: 5)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.promptId, PromptID.organizeCards.rawValue)
        XCTAssertEqual(recent.first?.promptSourceKind, .imported)
        XCTAssertEqual(recent.first?.promptPackId, "imported.prompt.audit")
        XCTAssertEqual(recent.first?.promptPackVersion, "2026.06")
        XCTAssertEqual(recent.first?.promptPackDisplayName, "Imported Prompt Audit")
        XCTAssertEqual(recent.first?.modelProvider, "GLM")
        XCTAssertEqual(recent.first?.modelName, "glm-test")
        XCTAssertEqual(recent.first?.sourceRecordIds, ["entry-1", "card-1"])
        XCTAssertEqual(recent.first?.contextRecordIds, ["entry-1", "card-1", "principle-1"])
        XCTAssertEqual(recent.first?.responseJSON, #"{"cards":[]}"#)
        XCTAssertNil(recent.first?.error)
    }

    func testPromptRun_legacyRowsWithoutContextRefsFallbackToSourceRefs() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO prompt_runs (
                        id, schema_version, prompt_id, prompt_version, input_schema_version,
                        output_schema_version, model_provider, model_name, session_mode,
                        source_record_ids_json, context_record_ids_json, request_summary,
                        response_json, error, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    UUID().uuidString,
                    1,
                    PromptID.generateQuestions.rawValue,
                    "1.0.0",
                    1,
                    1,
                    "GLM",
                    "glm-test",
                    SessionMode.standard.rawValue,
                    #"["entry-1","card-1"]"#,
                    nil,
                    "legacy row",
                    #"{"questions":[]}"#,
                    nil,
                    Self.storageString(Date(timeIntervalSince1970: 10))
                ]
            )
        }

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.sourceRecordIds, ["entry-1", "card-1"])
        XCTAssertEqual(recent.first?.contextRecordIds, ["entry-1", "card-1"])
    }

    func testPromptRun_unresolvedFailuresReturnsOnlyFailedRuns() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: ["entry-1"],
                requestSummary: "success",
                responseJSON: #"{"questions":[]}"#,
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: ["entry-1"],
                requestSummary: "failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )

        let failures = try await repo.unresolvedFailures(limit: 10)
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.requestSummary, "failure")
        XCTAssertEqual(failures.first?.error, "HTTP 500")
    }

    func testPromptRun_unresolvedFailuresIgnoresFailureResolvedByLaterSuccess() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let sourceIds = ["entry-1", "card-1"]
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuests.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: sourceIds,
                requestSummary: "older failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.generateQuests.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: sourceIds,
                requestSummary: "later success",
                responseJSON: #"{"main_quest":null}"#,
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )

        let failures = try await repo.unresolvedFailures(limit: 10)
        XCTAssertTrue(failures.isEmpty)
    }

    func testPromptRun_updateFeedbackPersistsUserDenial() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let run = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1"],
            requestSummary: "question generation",
            responseJSON: #"{"questions":[{"question":"What evidence matters?"}]}"#,
            createdAt: Date(timeIntervalSince1970: 1)
        )

        try await repo.savePromptRun(run)
        try await repo.updatePromptRunFeedback(.denied, runId: run.id)

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.userFeedback, .denied)
    }

    func testPromptRun_statsCalculatesFailureEmptyResultAndDenialRates() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.organizeCards.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: ["entry-1"],
                requestSummary: "success",
                responseJSON: #"{"cards":[{"title":"A"}]}"#,
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        try await repo.savePromptRun(
            PromptRun(
                promptId: PromptID.organizeCards.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: ["entry-2"],
                requestSummary: "http failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )
        let emptyResultRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-3"],
            requestSummary: "empty model output",
            error: "TodayAIParsingError.emptyResult",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let deniedRun = PromptRun(
            promptId: PromptID.generateQuests.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-4"],
            requestSummary: "user rejected quest",
            responseJSON: #"{"main_quest":{"title":"Low value busywork"}}"#,
            createdAt: Date(timeIntervalSince1970: 4)
        )
        try await repo.savePromptRun(emptyResultRun)
        try await repo.savePromptRun(deniedRun)
        try await repo.updatePromptRunFeedback(.denied, runId: deniedRun.id)

        let stats = try await repo.promptRunStats(limit: 10)

        XCTAssertEqual(stats.totalCount, 4)
        XCTAssertEqual(stats.successCount, 2)
        XCTAssertEqual(stats.failureCount, 2)
        XCTAssertEqual(stats.emptyResultCount, 1)
        XCTAssertEqual(stats.userDeniedCount, 1)
        XCTAssertEqual(stats.failureRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(stats.emptyResultRate, 0.25, accuracy: 0.001)
        XCTAssertEqual(stats.userDenialRate, 0.25, accuracy: 0.001)
    }

    // MARK: - PromptEvalRunRepository

    func testSavePromptEvalRun_andLoadRecent() async throws {
        let repo = SQLitePromptEvalRunRepository(database: database)
        let run = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "questions.1.0.0",
            systemPolicyVersion: "system.v1",
            contextPolicyVersion: "context.generateQuestions.v1",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            evalSuiteVersion: "generateQuestions.eval.v1",
            runnerVersion: "prompt-eval-runner.test",
            caseResults: [
                PromptEvalCaseResult(
                    caseId: "questions.concrete_lens_specific",
                    name: "Concrete lens-specific questions",
                    status: .passed,
                    inputSummary: "Lens-specific question fixture from meeting evidence.",
                    expectedBehavior: "Ask concrete questions tied to the selected lens.",
                    actualObservation: "Parser returned concrete evidence and disconfirmation questions.",
                    diagnosticReason: "fixed-suite pass: all assertions satisfied."
                ),
                PromptEvalCaseResult(
                    caseId: "questions.rejects_generic",
                    name: "Rejects generic questions",
                    status: .failed,
                    failureReason: "Expected at least one evidence-specific question.",
                    inputSummary: "Generic question regression fixture.",
                    expectedBehavior: "Reject generic prompts that ignore evidence.",
                    actualObservation: "No evidence-specific question was found.",
                    diagnosticReason: "fixed-suite failure: Expected at least one evidence-specific question."
                )
            ],
            createdAt: Date(timeIntervalSince1970: 20)
        )

        try await repo.saveEvalRun(run)

        let recent = try await repo.recentEvalRuns(limit: 5)
        let loaded = try XCTUnwrap(recent.first)
        XCTAssertEqual(loaded.id, run.id)
        XCTAssertEqual(loaded.promptId, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(loaded.promptVersion, "questions.1.0.0")
        XCTAssertEqual(loaded.contextPolicyVersion, "context.generateQuestions.v1")
        XCTAssertEqual(loaded.evalSuiteVersion, "generateQuestions.eval.v1")
        XCTAssertEqual(loaded.runnerVersion, "prompt-eval-runner.test")
        XCTAssertEqual(loaded.totalCaseCount, 2)
        XCTAssertEqual(loaded.passedCaseCount, 1)
        XCTAssertEqual(loaded.failedCaseCount, 1)
        XCTAssertEqual(loaded.passRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(loaded.status, .failed)
        XCTAssertEqual(loaded.caseResults.last?.failureReason, "Expected at least one evidence-specific question.")
        XCTAssertEqual(loaded.caseResults.first?.inputSummary, "Lens-specific question fixture from meeting evidence.")
        XCTAssertEqual(loaded.caseResults.first?.expectedBehavior, "Ask concrete questions tied to the selected lens.")
        XCTAssertEqual(loaded.caseResults.first?.actualObservation, "Parser returned concrete evidence and disconfirmation questions.")
        XCTAssertEqual(loaded.caseResults.first?.diagnosticReason, "fixed-suite pass: all assertions satisfied.")
    }

    // MARK: - PromptAssetSelectionRepository

    func testPromptAssetSelection_saveAndLoadSelectedVersions() async throws {
        let repo = SQLitePromptAssetSelectionRepository(database: database)

        try await repo.saveSelection(
            PromptAssetSelection(
                promptId: .generateQuestions,
                selectedVersion: "0.9.0",
                baseVersion: "1.0.0",
                reason: .rollback
            )
        )

        let selections = try await repo.allSelections()

        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.promptId, .generateQuestions)
        XCTAssertEqual(selections.first?.selectedVersion, "0.9.0")
        XCTAssertEqual(selections.first?.baseVersion, "1.0.0")
        XCTAssertEqual(selections.first?.reason, .rollback)
    }

    // MARK: - PromptAssetPackRepository

    func testPromptAssetPack_saveAndLoadEnabledPacks() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.1.1.0",
            systemPolicyVersion: "system.v1",
            contextPolicyVersion: "context.generateQuestions.v1",
            evalSuiteVersion: "generateQuestions.eval.v1",
            rollbackTargetVersion: "1.0.0",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let pack = try Self.trusted(
            PromptAssetPack(
            id: "marketplace.prompts.questions",
            version: "2026.06",
            displayName: "Question Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
            )
        )

        try await repo.savePack(pack)

        let packs = try await repo.enabledPacks()
        let loaded = try XCTUnwrap(packs.first)
        XCTAssertEqual(loaded.id, "marketplace.prompts.questions")
        XCTAssertEqual(loaded.version, "2026.06")
        XCTAssertEqual(loaded.displayName, "Question Prompt Pack")
        XCTAssertEqual(loaded.sourceKind, .marketplace)
        XCTAssertTrue(loaded.isEnabled)
        XCTAssertEqual(loaded.templates.map(\.id), [.generateQuestions])
        XCTAssertEqual(loaded.templates.first?.version, "questions.registry.1.1.0")
        XCTAssertEqual(loaded.templates.first?.rollbackTargetVersion, "1.0.0")
        XCTAssertEqual(loaded.trustMetadata?.contentHash, try AssetPackIntegrity.expectedContentHash(for: loaded))
    }

    func testPromptAssetPack_disabledPacksPersistButDoNotLoadAsEnabled() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuests,
            version: "quests.registry.1.1.0",
            systemText: "System guardrails",
            userText: "Generate one verifiable quest.",
            outputSchemaVersion: 1
        )

        try await repo.savePack(
            try Self.trusted(
                PromptAssetPack(
                id: "imported.prompts.disabled",
                version: "2026.06",
                displayName: "Disabled Prompt Pack",
                sourceKind: .imported,
                isEnabled: false,
                templates: [template]
                )
            )
        )

        let enabledPacks = try await repo.enabledPacks()
        let allPackIds = try await repo.allPacks().map(\.id)

        XCTAssertTrue(enabledPacks.isEmpty)
        XCTAssertEqual(allPackIds, ["imported.prompts.disabled"])
    }

    func testPromptAssetPack_externalPackRequiresTrustMetadata() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.1.1.0",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let pack = PromptAssetPack(
            id: "marketplace.prompts.untrusted",
            version: "2026.06",
            displayName: "Untrusted Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testPromptAssetPack_externalPackRejectsMismatchedContentHash() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.1.1.0",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let pack = PromptAssetPack(
            id: "marketplace.prompts.tampered",
            version: "2026.06",
            displayName: "Tampered Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template],
            trustMetadata: Self.makeTrustMetadata(contentHash: Self.mismatchedContentHash)
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testPromptAssetPack_externalPackRejectsInvalidSignature() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.1.1.0",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let unsigned = PromptAssetPack(
            id: "marketplace.prompts.invalid-signature",
            version: "2026.06",
            displayName: "Invalid Signature Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
        )
        let pack = PromptAssetPack(
            id: unsigned.id,
            version: unsigned.version,
            displayName: unsigned.displayName,
            sourceKind: unsigned.sourceKind,
            isEnabled: unsigned.isEnabled,
            templates: unsigned.templates,
            trustMetadata: Self.makeTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: unsigned),
                signature: "p256-sha256:invalid-signature"
            )
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testPromptAssetPack_externalPackRejectsUnknownVerificationPolicyVersion() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.1.1.0",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let unsigned = PromptAssetPack(
            id: "marketplace.prompts.unknown-policy",
            version: "2026.06",
            displayName: "Unknown Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
        )
        let pack = PromptAssetPack(
            id: unsigned.id,
            version: unsigned.version,
            displayName: unsigned.displayName,
            sourceKind: unsigned.sourceKind,
            isEnabled: unsigned.isEnabled,
            templates: unsigned.templates,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: unsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: unsigned),
                verificationPolicyVersion: "asset-trust.unknown.v9"
            )
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testPromptAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.1.1.0",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let unsigned = PromptAssetPack(
            id: "marketplace.prompts.revoked-publisher",
            version: "2026.06",
            displayName: "Revoked Publisher Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
        )
        let pack = PromptAssetPack(
            id: unsigned.id,
            version: unsigned.version,
            displayName: unsigned.displayName,
            sourceKind: unsigned.sourceKind,
            isEnabled: unsigned.isEnabled,
            templates: unsigned.templates,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: unsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: unsigned),
                verificationPolicyVersion: "asset-trust.test.revoked.v1"
            )
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testPromptAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.rotated",
            systemText: "System guardrails",
            userText: "Generate concrete reflection questions.",
            outputSchemaVersion: 1
        )
        let oldKeyUnsigned = PromptAssetPack(
            id: "marketplace.prompts.rotated-old",
            version: "2026.06",
            displayName: "Rotated Old Key Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
        )
        let newKeyUnsigned = PromptAssetPack(
            id: "marketplace.prompts.rotated-new",
            version: "2026.06",
            displayName: "Rotated New Key Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [template]
        )
        let oldKeyPack = PromptAssetPack(
            id: oldKeyUnsigned.id,
            version: oldKeyUnsigned.version,
            displayName: oldKeyUnsigned.displayName,
            sourceKind: oldKeyUnsigned.sourceKind,
            isEnabled: oldKeyUnsigned.isEnabled,
            templates: oldKeyUnsigned.templates,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: oldKeyUnsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: oldKeyUnsigned),
                verificationPolicyVersion: "asset-trust.test.rotated.v1"
            )
        )
        let newKeyPack = PromptAssetPack(
            id: newKeyUnsigned.id,
            version: newKeyUnsigned.version,
            displayName: newKeyUnsigned.displayName,
            sourceKind: newKeyUnsigned.sourceKind,
            isEnabled: newKeyUnsigned.isEnabled,
            templates: newKeyUnsigned.templates,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: newKeyUnsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: newKeyUnsigned),
                verificationPolicyVersion: "asset-trust.test.rotated.v1",
                privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
            )
        )

        try await repo.savePack(oldKeyPack)
        try await repo.savePack(newKeyPack)

        let enabledPackIds = try await repo.enabledPacks().map(\.id)
        XCTAssertEqual(Set(enabledPackIds), ["marketplace.prompts.rotated-old", "marketplace.prompts.rotated-new"])
    }

    func testAssetPackTrustPolicyDocumentSignatureVerifier_allowsSignedDocuments() throws {
        let document = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: "asset-trust.remote.rotated.v1",
                        trustedPublisherPublicKeys: [
                            "mingsi.remote.publisher": ["remote-public-key"]
                        ],
                        revokedPublisherIds: ["mingsi.remote.revoked"]
                    )
                ]
            )
        )

        XCTAssertEqual(
            document.signatureVerifier.publicKeyStrings(
                for: "mingsi.remote.publisher",
                verificationPolicyVersion: "asset-trust.remote.rotated.v1"
            ),
            ["remote-public-key"]
        )
        XCTAssertTrue(
            document.signatureVerifier.publicKeyStrings(
                for: "mingsi.remote.revoked",
                verificationPolicyVersion: "asset-trust.remote.rotated.v1"
            ).isEmpty
        )
    }

    func testAssetPackTrustPolicyDocumentSignatureVerifier_rejectsUnsignedAndTamperedDocuments() throws {
        let unsigned = AssetPackTrustPolicyDocument(
            policies: [
                AssetPackTrustPolicy(
                    version: "asset-trust.remote.unsigned.v1",
                    trustedPublisherPublicKeys: [
                        "mingsi.remote.publisher": ["remote-public-key"]
                    ]
                )
            ]
        )
        var tampered = try Self.signedTrustPolicyDocument(unsigned)
        tampered.policies = [
            AssetPackTrustPolicy(
                version: "asset-trust.remote.unsigned.v1",
                trustedPublisherPublicKeys: [
                    "mingsi.remote.publisher": ["tampered-public-key"]
                ]
            )
        ]

        XCTAssertTrue(
            unsigned.signatureVerifier.publicKeyStrings(
                for: "mingsi.remote.publisher",
                verificationPolicyVersion: "asset-trust.remote.unsigned.v1"
            ).isEmpty
        )
        XCTAssertTrue(
            tampered.signatureVerifier.publicKeyStrings(
                for: "mingsi.remote.publisher",
                verificationPolicyVersion: "asset-trust.remote.unsigned.v1"
            ).isEmpty
        )
    }

    func testAssetPackTrustPolicyRepository_saveAndLoadDocuments() async throws {
        let repo = SQLiteAssetPackTrustPolicyRepository(database: database)
        let document = try Self.signedTrustPolicyDocument(
            AssetPackTrustPolicyDocument(
                policies: [
                    AssetPackTrustPolicy(
                        version: "asset-trust.remote.rotated.v1",
                        trustedPublisherPublicKeys: [
                            "mingsi.remote.publisher": ["remote-public-key"]
                        ],
                        revokedPublisherIds: ["mingsi.remote.revoked"]
                    )
                ]
            )
        )

        try await repo.saveDocument(
            document,
            sourceURL: URL(string: "https://registry.mingsi.test/trust-policy.json")!
        )

        let documents = try await repo.allDocuments()
        XCTAssertEqual(documents.map(\.sourceURL?.absoluteString), ["https://registry.mingsi.test/trust-policy.json"])
        XCTAssertEqual(documents.first?.document, document)
        XCTAssertEqual(
            documents.first?.document.signatureVerifier.publicKeyStrings(
                for: "mingsi.remote.publisher",
                verificationPolicyVersion: "asset-trust.remote.rotated.v1"
            ),
            ["remote-public-key"]
        )
        XCTAssertTrue(
            documents.first?.document.signatureVerifier.publicKeyStrings(
                for: "mingsi.remote.revoked",
                verificationPolicyVersion: "asset-trust.remote.rotated.v1"
            ).isEmpty ?? false
        )
    }

    func testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.legacy",
            systemText: "System guardrails",
            userText: "Legacy external pack without trust proof.",
            outputSchemaVersion: 1
        )
        let now = Self.storageString(Date(timeIntervalSince1970: 100))

        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO prompt_asset_packs
                (id, schema_version, version, display_name, source_kind, is_enabled, templates_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "marketplace.prompts.legacy",
                    1,
                    "2026.05",
                    "Legacy Prompt Pack",
                    PromptAssetSourceKind.marketplace.rawValue,
                    1,
                    try Self.encodedJSONString([template]),
                    now,
                    now
                ]
            )
        }

        let enabledPacks = try await repo.enabledPacks()
        let allPacks = try await repo.allPacks()

        XCTAssertTrue(enabledPacks.isEmpty)
        XCTAssertEqual(allPacks.map(\.id), ["marketplace.prompts.legacy"])
        XCTAssertNil(allPacks.first?.trustMetadata)
    }

    func testPromptAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash() async throws {
        let repo = SQLitePromptAssetPackRepository(database: database)
        let template = PromptTemplate(
            id: .generateQuestions,
            version: "questions.registry.legacy",
            systemText: "System guardrails",
            userText: "Legacy external pack with stale trust proof.",
            outputSchemaVersion: 1
        )
        let now = Self.storageString(Date(timeIntervalSince1970: 100))

        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO prompt_asset_packs
                (id, schema_version, version, display_name, source_kind, is_enabled, templates_json, trust_metadata_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "marketplace.prompts.stale-hash",
                    1,
                    "2026.05",
                    "Stale Hash Prompt Pack",
                    PromptAssetSourceKind.marketplace.rawValue,
                    1,
                    try Self.encodedJSONString([template]),
                    try Self.encodedJSONString(Self.makeTrustMetadata(contentHash: Self.mismatchedContentHash)),
                    now,
                    now
                ]
            )
        }

        let enabledPacks = try await repo.enabledPacks()
        let allPacks = try await repo.allPacks()

        XCTAssertTrue(enabledPacks.isEmpty)
        XCTAssertEqual(allPacks.map(\.id), ["marketplace.prompts.stale-hash"])
        XCTAssertEqual(allPacks.first?.trustMetadata?.contentHash, Self.mismatchedContentHash)
    }

    // MARK: - LensAssetPackRepository

    func testLensAssetPack_saveAndLoadEnabledPacks() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "role-coach",
            promptId: "role_coach",
            version: "role.v1",
            title: "Coach Role",
            subtitle: "Use a coaching voice.",
            shortLabel: "Coach",
            methodLine: "What would a coach ask first?",
            promptGuidance: "Ask coaching-style reflection questions.",
            symbolName: "person.wave.2",
            recommendedReason: "Imported role card pack.",
            questionSeeds: ["What would a coach ask first?"],
            accentRole: .accent,
            methodIndex: 10
        )
        let pack = try Self.trusted(
            LensAssetPack(
            id: "marketplace.roles.coach",
            version: "2026.06",
            displayName: "Coach Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
            )
        )

        try await repo.savePack(pack)

        let packs = try await repo.enabledPacks()
        let loaded = try XCTUnwrap(packs.first)
        XCTAssertEqual(loaded.id, "marketplace.roles.coach")
        XCTAssertEqual(loaded.version, "2026.06")
        XCTAssertEqual(loaded.displayName, "Coach Role Cards")
        XCTAssertEqual(loaded.sourceKind, .marketplace)
        XCTAssertTrue(loaded.isEnabled)
        XCTAssertEqual(loaded.items.map(\.lensId), ["role-coach"])
        XCTAssertEqual(loaded.stampedItems.first?.packId, "marketplace.roles.coach")
        XCTAssertEqual(loaded.trustMetadata?.contentHash, try AssetPackIntegrity.expectedContentHash(for: loaded))
    }

    func testLensAssetPack_disabledPacksPersistButDoNotLoadAsEnabled() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "disabled-role",
            promptId: "disabled_role",
            version: "role.v1",
            title: "Disabled Role",
            subtitle: "Should not appear.",
            shortLabel: "Off",
            methodLine: "Should not appear.",
            promptGuidance: "Should not appear.",
            symbolName: "nosign",
            recommendedReason: "Disabled pack.",
            questionSeeds: ["Should not appear."],
            accentRole: .brick,
            methodIndex: 11
        )

        try await repo.savePack(
            try Self.trusted(
                LensAssetPack(
                id: "marketplace.roles.disabled",
                version: "2026.06",
                displayName: "Disabled Role Cards",
                sourceKind: .marketplace,
                isEnabled: false,
                items: [lens]
                )
            )
        )

        let enabledPacks = try await repo.enabledPacks()
        let allPackIds = try await repo.allPacks().map(\.id)

        XCTAssertTrue(enabledPacks.isEmpty)
        XCTAssertEqual(allPackIds, ["marketplace.roles.disabled"])
    }

    func testLensAssetPack_externalPackRequiresTrustMetadata() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "untrusted-role",
            promptId: "untrusted_role",
            version: "role.v1",
            title: "Untrusted Role",
            subtitle: "Should not be saved.",
            shortLabel: "NoTrust",
            methodLine: "Should not be saved.",
            promptGuidance: "Should not be saved.",
            symbolName: "nosign",
            recommendedReason: "Marketplace pack without trust proof.",
            questionSeeds: ["Should not be saved."],
            accentRole: .brick,
            methodIndex: 11
        )
        let pack = LensAssetPack(
            id: "marketplace.roles.untrusted",
            version: "2026.06",
            displayName: "Untrusted Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testLensAssetPack_externalPackRejectsMismatchedContentHash() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "tampered-role",
            promptId: "tampered_role",
            version: "role.v1",
            title: "Tampered Role",
            subtitle: "Should not be saved.",
            shortLabel: "NoHash",
            methodLine: "Should not be saved.",
            promptGuidance: "Should not be saved.",
            symbolName: "nosign",
            recommendedReason: "Marketplace pack with a stale content hash.",
            questionSeeds: ["Should not be saved."],
            accentRole: .brick,
            methodIndex: 11
        )
        let pack = LensAssetPack(
            id: "marketplace.roles.tampered",
            version: "2026.06",
            displayName: "Tampered Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens],
            trustMetadata: Self.makeTrustMetadata(contentHash: Self.mismatchedContentHash)
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testLensAssetPack_externalPackRejectsInvalidSignature() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "invalid-signature-role",
            promptId: "invalid_signature_role",
            version: "role.v1",
            title: "Invalid Signature Role",
            subtitle: "Should not be saved.",
            shortLabel: "NoSig",
            methodLine: "Should not be saved.",
            promptGuidance: "Should not be saved.",
            symbolName: "nosign",
            recommendedReason: "Marketplace pack with an invalid signature.",
            questionSeeds: ["Should not be saved."],
            accentRole: .brick,
            methodIndex: 11
        )
        let unsigned = LensAssetPack(
            id: "marketplace.roles.invalid-signature",
            version: "2026.06",
            displayName: "Invalid Signature Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
        )
        let pack = LensAssetPack(
            id: unsigned.id,
            version: unsigned.version,
            displayName: unsigned.displayName,
            sourceKind: unsigned.sourceKind,
            isEnabled: unsigned.isEnabled,
            items: unsigned.items,
            trustMetadata: Self.makeTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: unsigned),
                signature: "p256-sha256:invalid-signature"
            )
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testLensAssetPack_externalPackRejectsUnknownVerificationPolicyVersion() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "unknown-policy-role",
            promptId: "unknown_policy_role",
            version: "role.v1",
            title: "Unknown Policy Role",
            subtitle: "Should not be saved.",
            shortLabel: "NoPolicy",
            methodLine: "Should not be saved.",
            promptGuidance: "Should not be saved.",
            symbolName: "nosign",
            recommendedReason: "Marketplace pack with an unknown trust policy.",
            questionSeeds: ["Should not be saved."],
            accentRole: .brick,
            methodIndex: 11
        )
        let unsigned = LensAssetPack(
            id: "marketplace.roles.unknown-policy",
            version: "2026.06",
            displayName: "Unknown Policy Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
        )
        let pack = LensAssetPack(
            id: unsigned.id,
            version: unsigned.version,
            displayName: unsigned.displayName,
            sourceKind: unsigned.sourceKind,
            isEnabled: unsigned.isEnabled,
            items: unsigned.items,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: unsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: unsigned),
                verificationPolicyVersion: "asset-trust.unknown.v9"
            )
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testLensAssetPack_externalPackRejectsRevokedPublisherForPolicyVersion() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "revoked-publisher-role",
            promptId: "revoked_publisher_role",
            version: "role.v1",
            title: "Revoked Publisher Role",
            subtitle: "Should not be saved.",
            shortLabel: "Revoked",
            methodLine: "Should not be saved.",
            promptGuidance: "Should not be saved.",
            symbolName: "nosign",
            recommendedReason: "Marketplace pack from a revoked publisher.",
            questionSeeds: ["Should not be saved."],
            accentRole: .brick,
            methodIndex: 11
        )
        let unsigned = LensAssetPack(
            id: "marketplace.roles.revoked-publisher",
            version: "2026.06",
            displayName: "Revoked Publisher Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
        )
        let pack = LensAssetPack(
            id: unsigned.id,
            version: unsigned.version,
            displayName: unsigned.displayName,
            sourceKind: unsigned.sourceKind,
            isEnabled: unsigned.isEnabled,
            items: unsigned.items,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: unsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: unsigned),
                verificationPolicyVersion: "asset-trust.test.revoked.v1"
            )
        )

        try await assertValidationFailure {
            try await repo.savePack(pack)
        }

        let packs = try await repo.allPacks()
        XCTAssertTrue(packs.isEmpty)
    }

    func testLensAssetPack_verificationPolicyAllowsPublisherKeyRotationGracePeriod() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "rotated-role",
            promptId: "rotated_role",
            version: "role.v1",
            title: "Rotated Role",
            subtitle: "Should support key rotation grace.",
            shortLabel: "Rotate",
            methodLine: "Use a rotated publisher key.",
            promptGuidance: "Use a rotated publisher key.",
            symbolName: "key",
            recommendedReason: "Marketplace pack signed during key rotation.",
            questionSeeds: ["Which publisher key signed this pack?"],
            accentRole: .brick,
            methodIndex: 12
        )
        let oldKeyUnsigned = LensAssetPack(
            id: "marketplace.roles.rotated-old",
            version: "2026.06",
            displayName: "Rotated Old Key Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
        )
        let newKeyUnsigned = LensAssetPack(
            id: "marketplace.roles.rotated-new",
            version: "2026.06",
            displayName: "Rotated New Key Role Cards",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [lens]
        )
        let oldKeyPack = LensAssetPack(
            id: oldKeyUnsigned.id,
            version: oldKeyUnsigned.version,
            displayName: oldKeyUnsigned.displayName,
            sourceKind: oldKeyUnsigned.sourceKind,
            isEnabled: oldKeyUnsigned.isEnabled,
            items: oldKeyUnsigned.items,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: oldKeyUnsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: oldKeyUnsigned),
                verificationPolicyVersion: "asset-trust.test.rotated.v1"
            )
        )
        let newKeyPack = LensAssetPack(
            id: newKeyUnsigned.id,
            version: newKeyUnsigned.version,
            displayName: newKeyUnsigned.displayName,
            sourceKind: newKeyUnsigned.sourceKind,
            isEnabled: newKeyUnsigned.isEnabled,
            items: newKeyUnsigned.items,
            trustMetadata: try Self.signedTrustMetadata(
                contentHash: try AssetPackIntegrity.expectedContentHash(for: newKeyUnsigned),
                signedPayload: AssetPackIntegrity.signaturePayload(for: newKeyUnsigned),
                verificationPolicyVersion: "asset-trust.test.rotated.v1",
                privateKeyBase64: Self.rotatedPublisherPrivateKeyBase64
            )
        )

        try await repo.savePack(oldKeyPack)
        try await repo.savePack(newKeyPack)

        let enabledPackIds = try await repo.enabledPacks().map(\.id)
        XCTAssertEqual(Set(enabledPackIds), ["marketplace.roles.rotated-old", "marketplace.roles.rotated-new"])
    }

    func testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithoutTrustMetadata() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "legacy-role",
            promptId: "legacy_role",
            version: "role.v1",
            title: "Legacy Role",
            subtitle: "Legacy external pack without trust proof.",
            shortLabel: "Legacy",
            methodLine: "Should not enter runtime.",
            promptGuidance: "Should not enter runtime.",
            symbolName: "nosign",
            recommendedReason: "Legacy pack.",
            questionSeeds: ["Should not enter runtime."],
            accentRole: .brick,
            methodIndex: 11
        )
        let now = Self.storageString(Date(timeIntervalSince1970: 100))

        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO lens_asset_packs
                (id, schema_version, version, display_name, source_kind, is_enabled, items_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "marketplace.roles.legacy",
                    1,
                    "2026.05",
                    "Legacy Role Cards",
                    LensAssetSourceKind.marketplace.rawValue,
                    1,
                    try Self.encodedJSONString([lens]),
                    now,
                    now
                ]
            )
        }

        let enabledPacks = try await repo.enabledPacks()
        let allPacks = try await repo.allPacks()

        XCTAssertTrue(enabledPacks.isEmpty)
        XCTAssertEqual(allPacks.map(\.id), ["marketplace.roles.legacy"])
        XCTAssertNil(allPacks.first?.trustMetadata)
    }

    func testLensAssetPack_enabledPacksExcludeLegacyExternalPacksWithMismatchedContentHash() async throws {
        let repo = SQLiteLensAssetPackRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "stale-role",
            promptId: "stale_role",
            version: "role.v1",
            title: "Stale Role",
            subtitle: "Legacy external pack with stale trust proof.",
            shortLabel: "Stale",
            methodLine: "Should not enter runtime.",
            promptGuidance: "Should not enter runtime.",
            symbolName: "nosign",
            recommendedReason: "Legacy pack.",
            questionSeeds: ["Should not enter runtime."],
            accentRole: .brick,
            methodIndex: 11
        )
        let now = Self.storageString(Date(timeIntervalSince1970: 100))

        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO lens_asset_packs
                (id, schema_version, version, display_name, source_kind, is_enabled, items_json, trust_metadata_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "marketplace.roles.stale-hash",
                    1,
                    "2026.05",
                    "Stale Hash Role Cards",
                    LensAssetSourceKind.marketplace.rawValue,
                    1,
                    try Self.encodedJSONString([lens]),
                    try Self.encodedJSONString(Self.makeTrustMetadata(contentHash: Self.mismatchedContentHash)),
                    now,
                    now
                ]
            )
        }

        let enabledPacks = try await repo.enabledPacks()
        let allPacks = try await repo.allPacks()

        XCTAssertTrue(enabledPacks.isEmpty)
        XCTAssertEqual(allPacks.map(\.id), ["marketplace.roles.stale-hash"])
        XCTAssertEqual(allPacks.first?.trustMetadata?.contentHash, Self.mismatchedContentHash)
    }

    // MARK: - AssetPackInstallManifest

    func testAssetPackRegistryCatalog_decodesManifestEntries() throws {
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog.json")!
        let manifestURL = URL(string: "https://registry.mingsi.test/manifests/coach.json")!
        let catalog = AssetPackRegistryCatalog(
            version: "2026.06",
            entries: [
                AssetPackRegistryCatalogEntry(
                    id: "marketplace.coach",
                    displayName: "Coach Starter Pack",
                    summary: "Prompt and lens starter pack.",
                    manifestURL: manifestURL,
                    updatedAt: Date(timeIntervalSince1970: 1_804_032_000)
                )
            ]
        )

        let data = try Self.assetPackJSONEncoder.encode(catalog)
        let decoded = try Self.assetPackJSONDecoder.decode(AssetPackRegistryCatalog.self, from: data)

        XCTAssertEqual(decoded.version, "2026.06")
        XCTAssertEqual(decoded.entries.map(\.id), ["marketplace.coach"])
        XCTAssertEqual(decoded.entries.first?.displayName, "Coach Starter Pack")
        XCTAssertEqual(decoded.entries.first?.manifestURL, manifestURL)
        XCTAssertEqual(decoded.entries.first?.sourceURL(baseURL: catalogURL), manifestURL)
    }

    func testAssetPackRegistryCatalog_resolvesRelativeManifestURLsAgainstCatalogURL() throws {
        let catalogURL = URL(string: "https://registry.mingsi.test/catalog/index.json")!
        let entry = AssetPackRegistryCatalogEntry(
            id: "marketplace.relative",
            displayName: "Relative Manifest",
            summary: "Uses a relative URL.",
            manifestURL: URL(string: "manifests/relative.json")!,
            updatedAt: nil
        )

        XCTAssertEqual(
            entry.sourceURL(baseURL: catalogURL),
            URL(string: "https://registry.mingsi.test/catalog/manifests/relative.json")!
        )
    }

    func testAssetPackInstallManifest_filtersInstallablePromptAndLensPacksThroughTrustGate() throws {
        let trustedPromptUnsigned = PromptAssetPack(
            id: "marketplace.prompts.installable",
            version: "2026.06",
            displayName: "Installable Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                PromptTemplate(
                    id: .generateQuestions,
                    version: "questions.installable.v1",
                    systemText: "System guardrails",
                    userText: "Generate concrete reflection questions.",
                    outputSchemaVersion: 1
                )
            ]
        )
        let unknownPolicyPromptUnsigned = PromptAssetPack(
            id: "marketplace.prompts.unknown-policy",
            version: "2026.06",
            displayName: "Unknown Policy Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: trustedPromptUnsigned.templates
        )
        let revokedLensUnsigned = LensAssetPack(
            id: "marketplace.roles.revoked",
            version: "2026.06",
            displayName: "Revoked Lens Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [
                LensCatalogItem(
                    lensId: "manifest-revoked-role",
                    promptId: "manifest_revoked_role",
                    version: "role.v1",
                    title: "Revoked Role",
                    subtitle: "Should not be installable.",
                    shortLabel: "Reject",
                    methodLine: "Should not be installable.",
                    promptGuidance: "Should not be installable.",
                    symbolName: "nosign",
                    recommendedReason: "Revoked publisher.",
                    questionSeeds: ["Should not be installable."],
                    accentRole: .brick,
                    methodIndex: 13
                )
            ]
        )
        let trustedLensUnsigned = LensAssetPack(
            id: "marketplace.roles.installable",
            version: "2026.06",
            displayName: "Installable Lens Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [
                LensCatalogItem(
                    lensId: "manifest-role",
                    promptId: "manifest_role",
                    version: "role.v1",
                    title: "Manifest Role",
                    subtitle: "Should be installable.",
                    shortLabel: "Install",
                    methodLine: "Should be installable.",
                    promptGuidance: "Should be installable.",
                    symbolName: "checkmark.seal",
                    recommendedReason: "Trusted publisher.",
                    questionSeeds: ["Should be installable."],
                    accentRole: .accent,
                    methodIndex: 14
                )
            ]
        )

        let manifest = AssetPackInstallManifest(
            promptPacks: [
                PromptAssetPack(
                    id: trustedPromptUnsigned.id,
                    version: trustedPromptUnsigned.version,
                    displayName: trustedPromptUnsigned.displayName,
                    sourceKind: trustedPromptUnsigned.sourceKind,
                    isEnabled: trustedPromptUnsigned.isEnabled,
                    templates: trustedPromptUnsigned.templates,
                    trustMetadata: try Self.signedTrustMetadata(
                        contentHash: try AssetPackIntegrity.expectedContentHash(for: trustedPromptUnsigned),
                        signedPayload: AssetPackIntegrity.signaturePayload(for: trustedPromptUnsigned)
                    )
                ),
                PromptAssetPack(
                    id: unknownPolicyPromptUnsigned.id,
                    version: unknownPolicyPromptUnsigned.version,
                    displayName: unknownPolicyPromptUnsigned.displayName,
                    sourceKind: unknownPolicyPromptUnsigned.sourceKind,
                    isEnabled: unknownPolicyPromptUnsigned.isEnabled,
                    templates: unknownPolicyPromptUnsigned.templates,
                    trustMetadata: try Self.signedTrustMetadata(
                        contentHash: try AssetPackIntegrity.expectedContentHash(for: unknownPolicyPromptUnsigned),
                        signedPayload: AssetPackIntegrity.signaturePayload(for: unknownPolicyPromptUnsigned),
                        verificationPolicyVersion: "asset-trust.unknown.v9"
                    )
                )
            ],
            lensPacks: [
                LensAssetPack(
                    id: revokedLensUnsigned.id,
                    version: revokedLensUnsigned.version,
                    displayName: revokedLensUnsigned.displayName,
                    sourceKind: revokedLensUnsigned.sourceKind,
                    isEnabled: revokedLensUnsigned.isEnabled,
                    items: revokedLensUnsigned.items,
                    trustMetadata: try Self.signedTrustMetadata(
                        contentHash: try AssetPackIntegrity.expectedContentHash(for: revokedLensUnsigned),
                        signedPayload: AssetPackIntegrity.signaturePayload(for: revokedLensUnsigned),
                        verificationPolicyVersion: "asset-trust.test.revoked.v1"
                    )
                ),
                LensAssetPack(
                    id: trustedLensUnsigned.id,
                    version: trustedLensUnsigned.version,
                    displayName: trustedLensUnsigned.displayName,
                    sourceKind: trustedLensUnsigned.sourceKind,
                    isEnabled: trustedLensUnsigned.isEnabled,
                    items: trustedLensUnsigned.items,
                    trustMetadata: try Self.signedTrustMetadata(
                        contentHash: try AssetPackIntegrity.expectedContentHash(for: trustedLensUnsigned),
                        signedPayload: AssetPackIntegrity.signaturePayload(for: trustedLensUnsigned)
                    )
                )
            ]
        )

        let report = AssetPackInstallManifestValidator().validate(manifest)

        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.installable"])
        XCTAssertEqual(report.installableLensPacks.map(\.id), ["marketplace.roles.installable"])
        XCTAssertEqual(report.rejectedPromptPacks.first?.packId, "marketplace.prompts.unknown-policy")
        XCTAssertEqual(report.rejectedPromptPacks.first?.reason, .invalidTrustProof)
        XCTAssertEqual(report.rejectedLensPacks.first?.packId, "marketplace.roles.revoked")
        XCTAssertEqual(report.rejectedLensPacks.first?.reason, .invalidTrustProof)
    }

    func testAssetPackInstallManifestInstaller_savesOnlyValidatedPromptAndLensPacks() async throws {
        let promptRepo = SQLitePromptAssetPackRepository(database: database)
        let lensRepo = SQLiteLensAssetPackRepository(database: database)
        let installablePromptUnsigned = PromptAssetPack(
            id: "marketplace.prompts.installable-install",
            version: "2026.06",
            displayName: "Installable Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: [
                PromptTemplate(
                    id: .generateQuestions,
                    version: "questions.installable-install.v1",
                    systemText: "System guardrails",
                    userText: "Generate concrete reflection questions.",
                    outputSchemaVersion: 1
                )
            ]
        )
        let rejectedPrompt = PromptAssetPack(
            id: "marketplace.prompts.rejected-install",
            version: "2026.06",
            displayName: "Rejected Prompt Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            templates: installablePromptUnsigned.templates
        )
        let installableLensUnsigned = LensAssetPack(
            id: "marketplace.roles.installable-install",
            version: "2026.06",
            displayName: "Installable Lens Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            items: [
                LensCatalogItem(
                    lensId: "installable-install-role",
                    promptId: "installable_install_role",
                    version: "role.v1",
                    title: "Installable Role",
                    subtitle: "Should be installed.",
                    shortLabel: "Install",
                    methodLine: "Should be installed.",
                    promptGuidance: "Should be installed.",
                    symbolName: "checkmark.seal",
                    recommendedReason: "Trusted publisher.",
                    questionSeeds: ["Should be installed."],
                    accentRole: .accent,
                    methodIndex: 15
                )
            ]
        )
        let rejectedLens = LensAssetPack(
            id: "marketplace.roles.rejected-install",
            version: "2026.06",
            displayName: "Rejected Lens Pack",
            sourceKind: .marketplace,
            isEnabled: true,
            items: installableLensUnsigned.items
        )
        let manifest = AssetPackInstallManifest(
            promptPacks: [
                try Self.trusted(installablePromptUnsigned),
                rejectedPrompt
            ],
            lensPacks: [
                try Self.trusted(installableLensUnsigned),
                rejectedLens
            ]
        )

        let report = try await AssetPackInstallManifestInstaller(
            promptAssetPackRepository: promptRepo,
            lensAssetPackRepository: lensRepo
        ).install(manifest)

        XCTAssertEqual(report.installablePromptPacks.map(\.id), ["marketplace.prompts.installable-install"])
        XCTAssertEqual(report.rejectedPromptPacks.map(\.packId), ["marketplace.prompts.rejected-install"])
        XCTAssertEqual(report.rejectedPromptPacks.map(\.reason), [.missingTrustMetadata])
        XCTAssertEqual(report.installableLensPacks.map(\.id), ["marketplace.roles.installable-install"])
        XCTAssertEqual(report.rejectedLensPacks.map(\.packId), ["marketplace.roles.rejected-install"])
        XCTAssertEqual(report.rejectedLensPacks.map(\.reason), [.missingTrustMetadata])

        let savedPromptPackIds = try await promptRepo.allPacks().map(\.id)
        let enabledPromptPackIds = try await promptRepo.enabledPacks().map(\.id)
        let savedLensPackIds = try await lensRepo.allPacks().map(\.id)
        let enabledLensPackIds = try await lensRepo.enabledPacks().map(\.id)
        XCTAssertEqual(savedPromptPackIds, ["marketplace.prompts.installable-install"])
        XCTAssertEqual(enabledPromptPackIds, ["marketplace.prompts.installable-install"])
        XCTAssertEqual(savedLensPackIds, ["marketplace.roles.installable-install"])
        XCTAssertEqual(enabledLensPackIds, ["marketplace.roles.installable-install"])
    }

    // MARK: - DataExportRepository

    func testDataExport_includesSavedDraftAndPromptRun() async throws {
        let dailyRepo = SQLiteDailyEntryRepository(database: database)
        let promptRepo = SQLitePromptRunRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let draft = DailyEntryDraft(
            rawText: "Export should contain this local reflection.",
            sessionMode: .standard,
            hasSelectedSessionMode: true,
            selectedLens: .evidenceCheck,
            state: .answerQuestions
        )
        let promptRun = PromptRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            promptSourceKind: .marketplace,
            promptPackId: "marketplace.prompts.export",
            promptPackVersion: "2026.06",
            promptPackDisplayName: "Marketplace Prompt Export",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: [draft.id.uuidString],
            requestSummary: "question generation",
            responseJSON: #"{"questions":[]}"#,
            createdAt: Date(timeIntervalSince1970: 10)
        )

        try await dailyRepo.saveDraft(draft)
        try await promptRepo.savePromptRun(promptRun)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let dailyEntries = try XCTUnwrap(sections["daily_entries"] as? [[String: Any]])
        let promptRuns = try XCTUnwrap(sections["prompt_runs"] as? [[String: Any]])
        let counts = try XCTUnwrap(object["counts"] as? [String: Int])

        XCTAssertEqual(object["schema_version"] as? Int, 1)
        XCTAssertEqual(dailyEntries.count, 1)
        let exportedEntry = try XCTUnwrap(dailyEntries.first)
        let exportedRawText = exportedEntry["raw_text"] as? String
        let exportedLens = exportedEntry["selected_lens"] as? String
        XCTAssertEqual(exportedRawText, "Export should contain this local reflection.")
        XCTAssertEqual(exportedLens, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(promptRuns.count, 1)
        let exportedPromptRun = try XCTUnwrap(promptRuns.first)
        let exportedPromptId = exportedPromptRun["prompt_id"] as? String
        let exportedResponse = exportedPromptRun["response_json"] as? String
        XCTAssertEqual(exportedPromptId, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(exportedPromptRun["prompt_source_kind"] as? String, PromptAssetSourceKind.marketplace.rawValue)
        XCTAssertEqual(exportedPromptRun["prompt_pack_id"] as? String, "marketplace.prompts.export")
        XCTAssertEqual(exportedPromptRun["prompt_pack_version"] as? String, "2026.06")
        XCTAssertEqual(exportedPromptRun["prompt_pack_display_name"] as? String, "Marketplace Prompt Export")
        XCTAssertEqual(exportedResponse, #"{"questions":[]}"#)
        XCTAssertEqual(exportedPromptRun["system_policy_version"] as? String, "system.v1")
        XCTAssertEqual(exportedPromptRun["context_policy_version"] as? String, "context.v1")
        XCTAssertEqual(exportedPromptRun["eval_suite_version"] as? String, "eval.v1")
        XCTAssertEqual(exportedPromptRun["user_feedback"] as? String, PromptRunFeedback.none.rawValue)
        XCTAssertEqual(counts["daily_entries"], 1)
        XCTAssertEqual(counts["prompt_runs"], 1)
    }

    func testDataExport_includesPromptEvalRuns() async throws {
        let evalRepo = SQLitePromptEvalRunRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let run = PromptEvalRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "cards.1.0.0",
            systemPolicyVersion: "system.v1",
            contextPolicyVersion: "context.organizeCards.v1",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            evalSuiteVersion: "organizeCards.eval.v1",
            runnerVersion: "prompt-eval-runner.test",
            caseResults: [
                PromptEvalCaseResult(
                    caseId: "cards.messy_daily_input",
                    name: "Messy daily input produces typed cards",
                    status: .passed,
                    inputSummary: "Messy daily input fixture with meeting coordination evidence.",
                    expectedBehavior: "Produce typed cards with sensitivity classification.",
                    actualObservation: "Parser returned communication, risk, and task cards.",
                    diagnosticReason: "fixed-suite pass: all assertions satisfied."
                )
            ],
            createdAt: Date(timeIntervalSince1970: 30)
        )

        try await evalRepo.saveEvalRun(run)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let evalRuns = try XCTUnwrap(sections["prompt_eval_runs"] as? [[String: Any]])
        let counts = try XCTUnwrap(object["counts"] as? [String: Int])

        XCTAssertEqual(evalRuns.count, 1)
        let exportedRun = try XCTUnwrap(evalRuns.first)
        XCTAssertEqual(exportedRun["prompt_id"] as? String, PromptID.organizeCards.rawValue)
        XCTAssertEqual(exportedRun["eval_suite_version"] as? String, "organizeCards.eval.v1")
        let exportedCases = try XCTUnwrap(exportedRun["case_results"] as? [[String: Any]])
        let exportedCase = try XCTUnwrap(exportedCases.first)
        XCTAssertEqual(exportedCase["inputSummary"] as? String, "Messy daily input fixture with meeting coordination evidence.")
        XCTAssertEqual(exportedCase["expectedBehavior"] as? String, "Produce typed cards with sensitivity classification.")
        XCTAssertEqual(exportedCase["actualObservation"] as? String, "Parser returned communication, risk, and task cards.")
        XCTAssertEqual(exportedCase["diagnosticReason"] as? String, "fixed-suite pass: all assertions satisfied.")
        XCTAssertEqual(exportedRun["runner_version"] as? String, "prompt-eval-runner.test")
        XCTAssertEqual(exportedRun["total_case_count"] as? Int, 1)
        XCTAssertEqual(exportedRun["passed_case_count"] as? Int, 1)
        XCTAssertEqual(exportedRun["failed_case_count"] as? Int, 0)
        XCTAssertEqual(counts["prompt_eval_runs"], 1)
    }

    func testDataExport_includesPromptAssetSelections() async throws {
        let selectionRepo = SQLitePromptAssetSelectionRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)

        try await selectionRepo.saveSelection(
            PromptAssetSelection(
                promptId: .generateQuestions,
                selectedVersion: "0.9.0",
                baseVersion: "1.0.0",
                reason: .rollback
            )
        )

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let selections = try XCTUnwrap(sections["prompt_asset_selections"] as? [[String: Any]])
        let counts = try XCTUnwrap(object["counts"] as? [String: Int])

        XCTAssertEqual(selections.count, 1)
        let exportedSelection = try XCTUnwrap(selections.first)
        XCTAssertEqual(exportedSelection["prompt_id"] as? String, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(exportedSelection["selected_version"] as? String, "0.9.0")
        XCTAssertEqual(exportedSelection["base_version"] as? String, "1.0.0")
        XCTAssertEqual(exportedSelection["reason"] as? String, PromptAssetSelectionReason.rollback.rawValue)
        XCTAssertEqual(counts["prompt_asset_selections"], 1)
    }

    func testDataExport_includesPromptAssetPacks() async throws {
        let packRepo = SQLitePromptAssetPackRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let template = PromptTemplate(
            id: .extractPrinciple,
            version: "principle.registry.1.1.0",
            systemPolicyVersion: "system.v1",
            contextPolicyVersion: "context.extractPrinciple.v1",
            evalSuiteVersion: "extractPrinciple.eval.v1",
            systemText: "System guardrails",
            userText: "Extract one reusable principle.",
            outputSchemaVersion: 1
        )
        let pack = try Self.trusted(
            PromptAssetPack(
            id: "imported.prompts.principles",
            version: "1.2.0",
            displayName: "Principle Prompt Pack",
            sourceKind: .imported,
            isEnabled: true,
            templates: [template]
            )
        )

        try await packRepo.savePack(pack)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let packs = try XCTUnwrap(sections["prompt_asset_packs"] as? [[String: Any]])
        let counts = try XCTUnwrap(object["counts"] as? [String: Int])
        let exportedPack = try XCTUnwrap(packs.first)

        XCTAssertEqual(packs.count, 1)
        XCTAssertEqual(exportedPack["id"] as? String, "imported.prompts.principles")
        XCTAssertEqual(exportedPack["version"] as? String, "1.2.0")
        XCTAssertEqual(exportedPack["display_name"] as? String, "Principle Prompt Pack")
        XCTAssertEqual(exportedPack["source_kind"] as? String, PromptAssetSourceKind.imported.rawValue)
        XCTAssertEqual(exportedPack["is_enabled"] as? Int, 1)
        let exportedTrustMetadataJSON = try XCTUnwrap(exportedPack["trust_metadata_json"] as? String)
        XCTAssertTrue(exportedTrustMetadataJSON.contains("sha256:"))
        XCTAssertTrue(try XCTUnwrap(exportedPack["templates_json"] as? String).contains("principle.registry.1.1.0"))
        let exportedTemplates = try XCTUnwrap(exportedPack["templates"] as? [[String: Any]])
        XCTAssertEqual(exportedTemplates.first?["id"] as? String, PromptID.extractPrinciple.rawValue)
        XCTAssertEqual(exportedTemplates.first?["contextPolicyVersion"] as? String, "context.extractPrinciple.v1")
        XCTAssertEqual(counts["prompt_asset_packs"], 1)
    }

    func testDataExport_includesLensAssetPacks() async throws {
        let packRepo = SQLiteLensAssetPackRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let lens = LensCatalogItem(
            lensId: "framework-review",
            promptId: "framework_review",
            version: "framework.v1",
            title: "Framework Review",
            subtitle: "Review decisions through a framework.",
            shortLabel: "Frame",
            methodLine: "Which frame changes this decision?",
            promptGuidance: "Ask framework-oriented reflection questions.",
            symbolName: "rectangle.3.group",
            recommendedReason: "Imported framework pack.",
            questionSeeds: ["Which frame changes this decision?"],
            accentRole: .graphite,
            methodIndex: 12
        )
        let pack = try Self.trusted(
            LensAssetPack(
            id: "imported.frameworks.review",
            version: "1.2.0",
            displayName: "Review Frameworks",
            sourceKind: .imported,
            isEnabled: true,
            items: [lens]
            )
        )

        try await packRepo.savePack(pack)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let packs = try XCTUnwrap(sections["lens_asset_packs"] as? [[String: Any]])
        let counts = try XCTUnwrap(object["counts"] as? [String: Int])
        let exportedPack = try XCTUnwrap(packs.first)

        XCTAssertEqual(packs.count, 1)
        XCTAssertEqual(exportedPack["id"] as? String, "imported.frameworks.review")
        XCTAssertEqual(exportedPack["version"] as? String, "1.2.0")
        XCTAssertEqual(exportedPack["display_name"] as? String, "Review Frameworks")
        XCTAssertEqual(exportedPack["source_kind"] as? String, LensAssetSourceKind.imported.rawValue)
        XCTAssertEqual(exportedPack["is_enabled"] as? Int, 1)
        let exportedTrustMetadataJSON = try XCTUnwrap(exportedPack["trust_metadata_json"] as? String)
        XCTAssertTrue(exportedTrustMetadataJSON.contains("sha256:"))
        XCTAssertTrue(try XCTUnwrap(exportedPack["items_json"] as? String).contains("framework-review"))
        XCTAssertEqual(counts["lens_asset_packs"], 1)
    }

    func testDataExport_emptyDatabaseStillReturnsStructuredSections() async throws {
        let exportRepo = SQLiteDataExportRepository(database: database)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let counts = try XCTUnwrap(object["counts"] as? [String: Int])

        XCTAssertEqual(object["schema_version"] as? Int, 1)
        XCTAssertTrue((sections["daily_entries"] as? [[String: Any]])?.isEmpty == true)
        XCTAssertTrue((sections["prompt_runs"] as? [[String: Any]])?.isEmpty == true)
        XCTAssertEqual(counts["daily_entries"], 0)
        XCTAssertEqual(counts["prompt_runs"], 0)
        XCTAssertGreaterThan(data.count, 200)
    }

    func testDataExport_includesPrincipleRecallFeedback() async throws {
        let feedbackRepo = SQLitePrincipleRecallFeedbackRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let principleID = UUID()
        let promptRunID = UUID()
        let feedback = PrincipleRecallFeedback(
            principleId: principleID,
            promptRunId: promptRunID,
            promptId: .generateQuestions,
            retrievalPolicyVersion: "principle-retrieval.local-keyword.v1",
            retrievalReason: "Matched meeting ownership.",
            feedback: .notApplicable,
            note: "当前场景不适用。"
        )

        try await feedbackRepo.saveFeedback(feedback)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let feedbackRows = try XCTUnwrap(sections["principle_recall_feedback"] as? [[String: Any]])
        let exported = try XCTUnwrap(feedbackRows.first)

        XCTAssertEqual(feedbackRows.count, 1)
        XCTAssertEqual(exported["principle_id"] as? String, principleID.uuidString)
        XCTAssertEqual(exported["prompt_run_id"] as? String, promptRunID.uuidString)
        XCTAssertEqual(exported["feedback"] as? String, PrincipleRecallFeedbackValue.notApplicable.rawValue)
        XCTAssertEqual(exported["retrieval_policy_version"] as? String, "principle-retrieval.local-keyword.v1")
    }

    func testDataExport_includesPrinciplePracticeEvidence() async throws {
        let practiceRepo = SQLitePrinciplePracticeEvidenceRepository(database: database)
        let exportRepo = SQLiteDataExportRepository(database: database)
        let principleID = UUID()
        let entryID = UUID()
        let questID = UUID()
        let evidence = PrinciplePracticeEvidence(
            principleId: principleID,
            sourceDailyEntryId: entryID,
            questId: questID,
            evidenceSource: .quest,
            strength: .intentionalPractice,
            evidenceSummary: "任务证据显示用户主动练习了该原则。"
        )

        try await practiceRepo.saveEvidence(evidence)

        let data = try await exportRepo.exportJSON()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try XCTUnwrap(object["sections"] as? [String: Any])
        let evidenceRows = try XCTUnwrap(sections["principle_practice_evidence"] as? [[String: Any]])
        let exported = try XCTUnwrap(evidenceRows.first)

        XCTAssertEqual(evidenceRows.count, 1)
        XCTAssertEqual(exported["principle_id"] as? String, principleID.uuidString)
        XCTAssertEqual(exported["source_daily_entry_id"] as? String, entryID.uuidString)
        XCTAssertEqual(exported["quest_id"] as? String, questID.uuidString)
        XCTAssertEqual(exported["evidence_source"] as? String, PrinciplePracticeEvidenceSource.quest.rawValue)
        XCTAssertEqual(exported["strength"] as? String, PrinciplePracticeEvidenceStrength.intentionalPractice.rawValue)
    }

    func testPromptTracingLLMClient_recordsSuccessAndFailure() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "1.0.0",
                systemText: "Return JSON only.",
                userText: "Return cards.",
                outputSchemaVersion: 1
            ),
            inputSummary: "mode=standard; rawText=demo",
            contextPayload: PromptContextPayload(
                userChoice: .init(sessionMode: SessionMode.standard.rawValue)
            ),
            sourceRecordIDs: ["entry-1"],
            contextRecordIDs: ["entry-1", "principle-1"]
        )

        let successClient = PromptTracingLLMClient(
            base: MockLLMClient(),
            repository: repo,
            modelProvider: "mock",
            modelName: "local-mock"
        )
        _ = try await successClient.complete(request)

        let failureClient = PromptTracingLLMClient(
            base: AlwaysFailingLLMClient(),
            repository: repo,
            modelProvider: "GLM",
            modelName: "glm-test"
        )
        do {
            _ = try await failureClient.complete(request)
            XCTFail("Expected failing LLM client to throw")
        } catch {
            // Expected.
        }

        let recent = try await repo.recentPromptRuns(limit: 10)
        XCTAssertEqual(recent.count, 2)
        XCTAssertTrue(recent.contains { $0.modelProvider == "mock" && $0.responseJSON != nil && $0.error == nil })
        XCTAssertTrue(recent.contains { $0.modelProvider == "GLM" && $0.responseJSON == nil && $0.error?.contains("HTTP 503") == true })
        XCTAssertTrue(recent.allSatisfy { $0.sourceRecordIds == ["entry-1"] })
        XCTAssertTrue(recent.allSatisfy { $0.contextRecordIds == ["entry-1", "principle-1"] })
    }

    func testPromptTracingLLMClient_recordsPromptAssetVersions() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.2.1.0",
                systemPolicyVersion: "system.2026-06",
                contextPolicyVersion: "context.today.v2",
                evalSuiteVersion: "questions.eval.v3",
                rollbackTargetVersion: "questions.2.0.0",
                systemText: "Return JSON only.",
                userText: "Return questions.",
                outputSchemaVersion: 3
            ),
            inputSummary: "mode=deep; prompt asset audit",
            contextPayload: PromptContextPayload(
                userChoice: .init(sessionMode: SessionMode.deep.rawValue)
            ),
            sourceRecordIDs: ["entry-asset"],
            contextRecordIDs: ["principle-asset"]
        )
        let client = PromptTracingLLMClient(
            base: MockLLMClient(),
            repository: repo,
            modelProvider: "mock",
            modelName: "asset-audit"
        )

        _ = try await client.complete(request)

        let recent = try await repo.recentPromptRuns(limit: 1)
        let run = try XCTUnwrap(recent.first)
        XCTAssertEqual(run.promptVersion, "questions.2.1.0")
        XCTAssertEqual(run.promptSourceKind, .builtin)
        XCTAssertEqual(run.promptPackId, "mingsi.builtin.prompts")
        XCTAssertEqual(run.promptPackVersion, "builtin.v1")
        XCTAssertEqual(run.promptPackDisplayName, "MingSi Built-in Prompt Pack")
        XCTAssertEqual(run.systemPolicyVersion, "system.2026-06")
        XCTAssertEqual(run.contextPolicyVersion, "context.today.v2")
        XCTAssertEqual(run.evalSuiteVersion, "questions.eval.v3")
        XCTAssertEqual(run.rollbackTargetVersion, "questions.2.0.0")
        XCTAssertEqual(run.outputSchemaVersion, 3)
    }

    func testPromptTracingLLMClient_prefersStructuredContextSessionModeOverLegacyPayload() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.structured-context",
                systemText: "Return JSON only.",
                userText: "Return questions.",
                outputSchemaVersion: 1
            ),
            inputSummary: "mode=deep; structured context should drive prompt run audit",
            contextPayload: PromptContextPayload(
                userChoice: .init(sessionMode: SessionMode.deep.rawValue)
            ),
            sourceRecordIDs: ["entry-context-session"],
            contextRecordIDs: ["entry-context-session"]
        )
        let client = PromptTracingLLMClient(
            base: MockLLMClient(),
            repository: repo,
            modelProvider: "mock",
            modelName: "structured-context-audit"
        )

        _ = try await client.complete(request)

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.sessionMode, SessionMode.deep.rawValue)
    }

    func testPromptTracingLLMClient_withoutStructuredContextDoesNotAuditLegacySessionMode() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.no-legacy-session-mode",
                systemText: "Return JSON only.",
                userText: "Return questions.",
                outputSchemaVersion: 1
            ),
            inputSummary: "legacy session mode should not drive prompt run audit",
            sourceRecordIDs: ["entry-no-structured-context"],
            contextRecordIDs: ["entry-no-structured-context"]
        )
        let client = PromptTracingLLMClient(
            base: MockLLMClient(),
            repository: repo,
            modelProvider: "mock",
            modelName: "structured-context-audit"
        )

        _ = try await client.complete(request)

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.sessionMode, "unknown")
    }

    func testLLMRequest_hasNoStoredLegacyPayloadField() {
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.no-stored-legacy",
                systemText: "Return JSON only.",
                userText: "Return questions.",
                outputSchemaVersion: 1
            ),
            inputSummary: "request should only store structured context"
        )

        let legacyFieldName = ["json", "Payload"].joined()
        XCTAssertFalse(Mirror(reflecting: request).children.contains { $0.label == legacyFieldName })
    }

    func testLLMRequest_exposesStructuredContextForLegacyCompatibilityExport() throws {
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.derived-legacy",
                systemText: "Return JSON only.",
                userText: "Return questions.",
                outputSchemaVersion: 1
            ),
            inputSummary: "structured context derives legacy compatibility",
            contextPayload: PromptContextPayload(
                currentInput: .init(rawText: "current structured input"),
                userChoice: .init(sessionMode: SessionMode.deep.rawValue)
            )
        )
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)

        XCTAssertEqual(legacy["sessionMode"], SessionMode.deep.rawValue)
        XCTAssertEqual(legacy["rawText"], "current structured input")
        XCTAssertNil(legacy["purpose"])
    }

    func testLLMRequest_allowsStructuredContextWithoutCallerLegacyPayload() {
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.no-caller-legacy",
                systemText: "Return JSON only.",
                userText: "Return questions.",
                outputSchemaVersion: 1
            ),
            inputSummary: "structured context omits caller legacy dictionary",
            contextPayload: PromptContextPayload(
                currentInput: .init(rawText: "typed source of truth"),
                userChoice: .init(sessionMode: SessionMode.deep.rawValue)
            )
        )
        let legacy = request.contextPayload?.legacyKeyValues

        XCTAssertEqual(legacy?["sessionMode"], SessionMode.deep.rawValue)
        XCTAssertEqual(legacy?["rawText"], "typed source of truth")
    }

    func testPromptContextPayloadLegacyExportUsesOnlyStructuredFields() {
        let payload = PromptContextPayload(
            currentInput: .init(rawText: "typed source of truth"),
            userChoice: .init(sessionMode: SessionMode.deep.rawValue),
            privacy: .init(rules: "typed privacy rules"),
            directives: .init(streamProtocol: "MINGSI_STREAM_V1")
        )

        let legacy = payload.legacyKeyValues

        XCTAssertEqual(legacy["rawText"], "typed source of truth")
        XCTAssertEqual(legacy["sessionMode"], SessionMode.deep.rawValue)
        XCTAssertEqual(legacy["streamProtocol"], "MINGSI_STREAM_V1")
        XCTAssertNil(legacy["purpose"])
    }

    func testPromptTracingLLMClient_recordsMissingAPIKeyAsFailure() async throws {
        let repo = SQLitePromptRunRepository(database: database)
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "1.0.0",
                systemText: "Return JSON only.",
                userText: "Return cards.",
                outputSchemaVersion: 1
            ),
            inputSummary: "connection requires BYOK",
            contextPayload: PromptContextPayload(
                userChoice: .init(sessionMode: SessionMode.standard.rawValue)
            ),
            sourceRecordIDs: ["entry-missing-key"],
            contextRecordIDs: ["entry-missing-key"]
        )
        let client = PromptTracingLLMClient(
            base: MissingAPIKeyLLMClient(),
            repository: repo,
            modelProvider: "GLM",
            modelName: "missing-api-key"
        )

        do {
            _ = try await client.complete(request)
            XCTFail("Expected missing API key to throw")
        } catch LLMClientError.missingAPIKey {
            // Expected.
        } catch {
            XCTFail("Expected missing API key, got \(error)")
        }

        let recent = try await repo.recentPromptRuns(limit: 1)
        XCTAssertEqual(recent.first?.modelProvider, "GLM")
        XCTAssertEqual(recent.first?.modelName, "missing-api-key")
        XCTAssertNil(recent.first?.responseJSON)
        XCTAssertTrue(recent.first?.error?.contains("API Key") == true)
    }

    // MARK: - HistoricalRetryCandidateRepository

    func testHistoricalRetryCandidate_createAttachAndQueryByEntry() async throws {
        let repo = SQLiteHistoricalRetryCandidateRepository(database: database)
        let entryId = UUID()
        let failedRunId = UUID()
        let repairRunId = UUID()
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: failedRunId,
            promptId: .organizeCards,
            sourceDailyEntryId: entryId,
            reconstructedInputSummary: "rawText=142 chars"
        )

        try await repo.saveCandidate(candidate)
        try await repo.attachRepairRun(
            repairRunId,
            candidatePayloadJSON: #"{"cards":[{"title":"A"}]}"#,
            to: candidate.id
        )

        let candidates = try await repo.candidates(for: entryId)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.id, candidate.id)
        XCTAssertEqual(candidates.first?.failedPromptRunId, failedRunId)
        XCTAssertEqual(candidates.first?.repairPromptRunId, repairRunId)
        XCTAssertEqual(candidates.first?.promptId, .organizeCards)
        XCTAssertEqual(candidates.first?.sourceDailyEntryId, entryId)
        XCTAssertEqual(candidates.first?.status, .candidateReady)
        XCTAssertEqual(candidates.first?.candidatePayloadJSON, #"{"cards":[{"title":"A"}]}"#)
    }

    func testHistoricalRetryCandidate_statusUpdatesPreserveAuditPayload() async throws {
        let repo = SQLiteHistoricalRetryCandidateRepository(database: database)
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: UUID(),
            promptId: .organizeCards,
            sourceDailyEntryId: UUID(),
            status: .candidateReady,
            reconstructedInputSummary: "rawText=42 chars",
            candidatePayloadJSON: #"{"cards":[]}"#
        )

        try await repo.saveCandidate(candidate)
        try await repo.updateStatus(.blocked, candidateId: candidate.id, blockedReason: "confirmed cards exist")

        let loaded = try await repo.candidate(id: candidate.id)
        XCTAssertEqual(loaded?.status, .blocked)
        XCTAssertEqual(loaded?.blockedReason, "confirmed cards exist")
        XCTAssertEqual(loaded?.candidatePayloadJSON, #"{"cards":[]}"#)
    }

    func testHistoricalRetryCandidate_softDeleteDoesNotDeletePromptRuns() async throws {
        let promptRepo = SQLitePromptRunRepository(database: database)
        let candidateRepo = SQLiteHistoricalRetryCandidateRepository(database: database)
        let failedRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1"],
            requestSummary: "failed card organization",
            error: "HTTP 500"
        )
        let repairRun = PromptRun(
            promptId: PromptID.organizeCards.rawValue,
            promptVersion: "1.0.0",
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            modelProvider: "GLM",
            modelName: "glm-test",
            sessionMode: SessionMode.standard.rawValue,
            sourceRecordIds: ["entry-1"],
            requestSummary: "repair success",
            responseJSON: #"{"cards":[]}"#
        )
        let candidate = HistoricalRetryCandidate(
            failedPromptRunId: failedRun.id,
            repairPromptRunId: repairRun.id,
            promptId: .organizeCards,
            sourceDailyEntryId: UUID(),
            status: .candidateReady,
            reconstructedInputSummary: "rawText=42 chars",
            candidatePayloadJSON: #"{"cards":[]}"#
        )

        try await promptRepo.savePromptRun(failedRun)
        try await promptRepo.savePromptRun(repairRun)
        try await candidateRepo.saveCandidate(candidate)
        try await candidateRepo.softDelete(candidateId: candidate.id)

        let deletedCandidate = try await candidateRepo.candidate(id: candidate.id)
        XCTAssertNil(deletedCandidate)
        let promptRuns = try await promptRepo.recentPromptRuns(limit: 10)
        XCTAssertTrue(promptRuns.contains { $0.id == failedRun.id })
        XCTAssertTrue(promptRuns.contains { $0.id == repairRun.id })
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
            XCTAssertTrue(try db.tableExists("verifications"))
            XCTAssertTrue(try db.tableExists("lens_sessions"))
            XCTAssertTrue(try db.tableExists("projects"))
            XCTAssertTrue(try db.tableExists("project_candidates"))
            XCTAssertTrue(try db.tableExists("project_links"))
            XCTAssertTrue(try db.tableExists("project_merge_candidates"))
            XCTAssertTrue(try db.tableExists("project_insights"))
        }
    }

    func testMigration_v7_addsPromptRunContextRefs() throws {
        try dbQueue.read { db in
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
            XCTAssertTrue(promptRunColumns.contains("source_record_ids_json"))
            XCTAssertTrue(promptRunColumns.contains("context_record_ids_json"))
        }
    }

    func testMigration_v13_addsPromptRunFeedback() throws {
        try dbQueue.read { db in
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
            XCTAssertTrue(promptRunColumns.contains("user_feedback"))
        }
    }

    func testMigration_v14_addsPrincipleRecallFeedbackTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("principle_recall_feedback"))

            let columns = Set(try db.columns(in: "principle_recall_feedback").map(\.name))
            XCTAssertTrue(columns.contains("principle_id"))
            XCTAssertTrue(columns.contains("prompt_run_id"))
            XCTAssertTrue(columns.contains("source_daily_entry_id"))
            XCTAssertTrue(columns.contains("prompt_id"))
            XCTAssertTrue(columns.contains("retrieval_policy_version"))
            XCTAssertTrue(columns.contains("retrieval_reason"))
            XCTAssertTrue(columns.contains("feedback"))
            XCTAssertTrue(columns.contains("note"))

            let indexes = try db.indexes(on: "principle_recall_feedback").map(\.name)
            XCTAssertTrue(indexes.contains("idx_principle_recall_feedback_principle_id"))
            XCTAssertTrue(indexes.contains("idx_principle_recall_feedback_prompt_run_id"))
            XCTAssertTrue(indexes.contains("idx_principle_recall_feedback_feedback"))
        }
    }

    func testMigration_v16_addsPromptEvalRunsTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("prompt_eval_runs"))

            let columns = Set(try db.columns(in: "prompt_eval_runs").map(\.name))
            XCTAssertTrue(columns.contains("prompt_id"))
            XCTAssertTrue(columns.contains("prompt_version"))
            XCTAssertTrue(columns.contains("system_policy_version"))
            XCTAssertTrue(columns.contains("context_policy_version"))
            XCTAssertTrue(columns.contains("input_schema_version"))
            XCTAssertTrue(columns.contains("output_schema_version"))
            XCTAssertTrue(columns.contains("eval_suite_version"))
            XCTAssertTrue(columns.contains("runner_version"))
            XCTAssertTrue(columns.contains("status"))
            XCTAssertTrue(columns.contains("total_case_count"))
            XCTAssertTrue(columns.contains("passed_case_count"))
            XCTAssertTrue(columns.contains("failed_case_count"))
            XCTAssertTrue(columns.contains("case_results_json"))

            let indexes = try db.indexes(on: "prompt_eval_runs").map(\.name)
            XCTAssertTrue(indexes.contains("idx_prompt_eval_runs_prompt_id"))
            XCTAssertTrue(indexes.contains("idx_prompt_eval_runs_eval_suite_version"))
            XCTAssertTrue(indexes.contains("idx_prompt_eval_runs_created_at"))
        }
    }

    func testMigration_v21_addsPromptAssetPackProvenanceColumns() throws {
        try dbQueue.read { db in
            let promptRunColumns = Set(try db.columns(in: "prompt_runs").map(\.name))
            XCTAssertTrue(promptRunColumns.contains("prompt_source_kind"))
            XCTAssertTrue(promptRunColumns.contains("prompt_pack_id"))
            XCTAssertTrue(promptRunColumns.contains("prompt_pack_version"))
            XCTAssertTrue(promptRunColumns.contains("prompt_pack_display_name"))

            let evalRunColumns = Set(try db.columns(in: "prompt_eval_runs").map(\.name))
            XCTAssertTrue(evalRunColumns.contains("prompt_source_kind"))
            XCTAssertTrue(evalRunColumns.contains("prompt_pack_id"))
            XCTAssertTrue(evalRunColumns.contains("prompt_pack_version"))
            XCTAssertTrue(evalRunColumns.contains("prompt_pack_display_name"))
        }
    }

    func testMigration_v22_addsAssetPackTrustPoliciesTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("asset_pack_trust_policies"))

            let columns = Set(try db.columns(in: "asset_pack_trust_policies").map(\.name))
            XCTAssertTrue(columns.contains("id"))
            XCTAssertTrue(columns.contains("schema_version"))
            XCTAssertTrue(columns.contains("source_url"))
            XCTAssertTrue(columns.contains("document_json"))
            XCTAssertTrue(columns.contains("created_at"))
            XCTAssertTrue(columns.contains("updated_at"))
            XCTAssertTrue(columns.contains("deleted_at"))

            let indexes = try db.indexes(on: "asset_pack_trust_policies").map(\.name)
            XCTAssertTrue(indexes.contains("idx_asset_pack_trust_policies_source_url"))
            XCTAssertTrue(indexes.contains("idx_asset_pack_trust_policies_updated_at"))
        }
    }

    func testMigration_v17_addsPromptAssetSelectionsTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("prompt_asset_selections"))

            let columns = Set(try db.columns(in: "prompt_asset_selections").map(\.name))
            XCTAssertTrue(columns.contains("prompt_id"))
            XCTAssertTrue(columns.contains("schema_version"))
            XCTAssertTrue(columns.contains("selected_version"))
            XCTAssertTrue(columns.contains("base_version"))
            XCTAssertTrue(columns.contains("reason"))
            XCTAssertTrue(columns.contains("created_at"))
            XCTAssertTrue(columns.contains("updated_at"))
            XCTAssertTrue(columns.contains("deleted_at"))

            let indexes = try db.indexes(on: "prompt_asset_selections").map(\.name)
            XCTAssertTrue(indexes.contains("idx_prompt_asset_selections_updated_at"))
        }
    }

    func testMigration_v18_addsLensAssetPacksTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("lens_asset_packs"))

            let columns = Set(try db.columns(in: "lens_asset_packs").map(\.name))
            XCTAssertTrue(columns.contains("id"))
            XCTAssertTrue(columns.contains("schema_version"))
            XCTAssertTrue(columns.contains("version"))
            XCTAssertTrue(columns.contains("display_name"))
            XCTAssertTrue(columns.contains("source_kind"))
            XCTAssertTrue(columns.contains("is_enabled"))
            XCTAssertTrue(columns.contains("items_json"))
            XCTAssertTrue(columns.contains("trust_metadata_json"))
            XCTAssertTrue(columns.contains("created_at"))
            XCTAssertTrue(columns.contains("updated_at"))
            XCTAssertTrue(columns.contains("deleted_at"))

            let indexes = try db.indexes(on: "lens_asset_packs").map(\.name)
            XCTAssertTrue(indexes.contains("idx_lens_asset_packs_source_kind"))
            XCTAssertTrue(indexes.contains("idx_lens_asset_packs_enabled"))
            XCTAssertTrue(indexes.contains("idx_lens_asset_packs_updated_at"))
        }
    }

    func testMigration_v19_addsPromptAssetPacksTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("prompt_asset_packs"))

            let columns = Set(try db.columns(in: "prompt_asset_packs").map(\.name))
            XCTAssertTrue(columns.contains("id"))
            XCTAssertTrue(columns.contains("schema_version"))
            XCTAssertTrue(columns.contains("version"))
            XCTAssertTrue(columns.contains("display_name"))
            XCTAssertTrue(columns.contains("source_kind"))
            XCTAssertTrue(columns.contains("is_enabled"))
            XCTAssertTrue(columns.contains("templates_json"))
            XCTAssertTrue(columns.contains("trust_metadata_json"))
            XCTAssertTrue(columns.contains("created_at"))
            XCTAssertTrue(columns.contains("updated_at"))
            XCTAssertTrue(columns.contains("deleted_at"))

            let indexes = try db.indexes(on: "prompt_asset_packs").map(\.name)
            XCTAssertTrue(indexes.contains("idx_prompt_asset_packs_source_kind"))
            XCTAssertTrue(indexes.contains("idx_prompt_asset_packs_enabled"))
            XCTAssertTrue(indexes.contains("idx_prompt_asset_packs_updated_at"))
        }
    }

    func testMigration_v20_addsAssetPackTrustMetadataColumns() throws {
        try dbQueue.read { db in
            let promptColumns = Set(try db.columns(in: "prompt_asset_packs").map(\.name))
            let lensColumns = Set(try db.columns(in: "lens_asset_packs").map(\.name))

            XCTAssertTrue(promptColumns.contains("trust_metadata_json"))
            XCTAssertTrue(lensColumns.contains("trust_metadata_json"))
        }
    }

    func testMigration_v15_addsPrinciplePracticeEvidenceTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("principle_practice_evidence"))

            let columns = Set(try db.columns(in: "principle_practice_evidence").map(\.name))
            XCTAssertTrue(columns.contains("principle_id"))
            XCTAssertTrue(columns.contains("source_daily_entry_id"))
            XCTAssertTrue(columns.contains("quest_id"))
            XCTAssertTrue(columns.contains("verification_id"))
            XCTAssertTrue(columns.contains("evidence_source"))
            XCTAssertTrue(columns.contains("strength"))
            XCTAssertTrue(columns.contains("evidence_summary"))

            let indexes = try db.indexes(on: "principle_practice_evidence").map(\.name)
            XCTAssertTrue(indexes.contains("idx_principle_practice_evidence_principle_id"))
            XCTAssertTrue(indexes.contains("idx_principle_practice_evidence_source_daily_entry_id"))
            XCTAssertTrue(indexes.contains("idx_principle_practice_evidence_strength"))
        }
    }

    func testMigration_v8_addsHistoricalRetryCandidatesTableAndIndexes() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("historical_retry_candidates"))

            let columns = Set(try db.columns(in: "historical_retry_candidates").map(\.name))
            XCTAssertTrue(columns.contains("failed_prompt_run_id"))
            XCTAssertTrue(columns.contains("repair_prompt_run_id"))
            XCTAssertTrue(columns.contains("prompt_id"))
            XCTAssertTrue(columns.contains("source_daily_entry_id"))
            XCTAssertTrue(columns.contains("candidate_payload_json"))
            XCTAssertTrue(columns.contains("blocked_reason"))

            let indexes = try db.indexes(on: "historical_retry_candidates").map(\.name)
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_source_daily_entry_id"))
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_failed_prompt_run_id"))
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_status"))
            XCTAssertTrue(indexes.contains("idx_historical_retry_candidates_updated_at"))
        }
    }

    func testMigration_v9_addsSelectedCustomLensIdForDatabasesAlreadyPastV2() throws {
        let legacyQueue = try DatabaseQueue()
        try legacyQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE daily_entries (
                    id TEXT PRIMARY KEY,
                    schema_version INTEGER NOT NULL,
                    date TEXT NOT NULL,
                    raw_text TEXT NOT NULL,
                    session_mode TEXT NOT NULL,
                    has_selected_session_mode BOOLEAN NOT NULL DEFAULT 0,
                    selected_lens TEXT,
                    yesterday_completion TEXT,
                    yesterday_value_rating TEXT,
                    state TEXT NOT NULL,
                    privacy_flags_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT
                )
                """
            )
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            for identifier in [
                "v1_core_records",
                "v2_daily_loop_fields",
                "v3_verification_and_lens_sessions",
                "v4_project_evidence_layer",
                "v5_growth_attribution_layer",
                "v6_metric_contribution_source_entry_backfill",
                "v7_prompt_run_context_refs",
                "v8_historical_retry_candidates"
            ] {
                try db.execute(
                    sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                    arguments: [identifier]
                )
            }
        }

        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(legacyQueue)

        try legacyQueue.read { db in
            let dailyEntryColumns = Set(try db.columns(in: "daily_entries").map(\.name))
            XCTAssertTrue(dailyEntryColumns.contains("selected_custom_lens_id"))
        }
    }

    func testMigration_v10_addsCustomLensItemsForDatabasesAlreadyPastV2() throws {
        let legacyQueue = try DatabaseQueue()
        try legacyQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE daily_entries (
                    id TEXT PRIMARY KEY,
                    schema_version INTEGER NOT NULL,
                    date TEXT NOT NULL,
                    raw_text TEXT NOT NULL,
                    session_mode TEXT NOT NULL,
                    has_selected_session_mode BOOLEAN NOT NULL DEFAULT 0,
                    selected_lens TEXT,
                    selected_custom_lens_id TEXT,
                    yesterday_completion TEXT,
                    yesterday_value_rating TEXT,
                    state TEXT NOT NULL,
                    privacy_flags_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT
                )
                """
            )
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            for identifier in [
                "v1_core_records",
                "v2_daily_loop_fields",
                "v3_verification_and_lens_sessions",
                "v4_project_evidence_layer",
                "v5_growth_attribution_layer",
                "v6_metric_contribution_source_entry_backfill",
                "v7_prompt_run_context_refs",
                "v8_historical_retry_candidates",
                "v9_daily_entry_custom_lens_id"
            ] {
                try db.execute(
                    sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                    arguments: [identifier]
                )
            }
        }

        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(legacyQueue)

        try legacyQueue.read { db in
            let dailyEntryColumns = Set(try db.columns(in: "daily_entries").map(\.name))
            XCTAssertTrue(dailyEntryColumns.contains("custom_lens_items_json"))
        }
    }

    func testMigration_v11_addsCustomLensQuestionsForDatabasesAlreadyPastV2() throws {
        let legacyQueue = try DatabaseQueue()
        try legacyQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE daily_entries (
                    id TEXT PRIMARY KEY,
                    schema_version INTEGER NOT NULL,
                    date TEXT NOT NULL,
                    raw_text TEXT NOT NULL,
                    session_mode TEXT NOT NULL,
                    has_selected_session_mode BOOLEAN NOT NULL DEFAULT 0,
                    selected_lens TEXT,
                    selected_custom_lens_id TEXT,
                    custom_lens_items_json TEXT,
                    yesterday_completion TEXT,
                    yesterday_value_rating TEXT,
                    state TEXT NOT NULL,
                    privacy_flags_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT
                )
                """
            )
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            for identifier in [
                "v1_core_records",
                "v2_daily_loop_fields",
                "v3_verification_and_lens_sessions",
                "v4_project_evidence_layer",
                "v5_growth_attribution_layer",
                "v6_metric_contribution_source_entry_backfill",
                "v7_prompt_run_context_refs",
                "v8_historical_retry_candidates",
                "v9_daily_entry_custom_lens_id",
                "v10_daily_entry_custom_lens_items"
            ] {
                try db.execute(
                    sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                    arguments: [identifier]
                )
            }
        }

        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(legacyQueue)

        try legacyQueue.read { db in
            let dailyEntryColumns = Set(try db.columns(in: "daily_entries").map(\.name))
            XCTAssertTrue(dailyEntryColumns.contains("custom_lens_questions_json"))
        }
    }

    func testMigration_v2_addsDailyLoopFields() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "daily_entries")
            let columnNames = Set(columns.map(\.name))
            XCTAssertTrue(columnNames.contains("has_selected_session_mode"))
            XCTAssertTrue(columnNames.contains("selected_lens"))
            XCTAssertTrue(columnNames.contains("selected_custom_lens_id"))
            XCTAssertTrue(columnNames.contains("custom_lens_items_json"))
            XCTAssertTrue(columnNames.contains("custom_lens_questions_json"))
            XCTAssertTrue(columnNames.contains("yesterday_completion"))
            XCTAssertTrue(columnNames.contains("yesterday_value_rating"))
        }
    }

    func testMigration_v3_addsVerificationAndLensSessionFields() throws {
        try dbQueue.read { db in
            let verificationColumns = Set(try db.columns(in: "verifications").map(\.name))
            XCTAssertTrue(verificationColumns.contains("quest_id"))
            XCTAssertTrue(verificationColumns.contains("source_daily_entry_id"))
            XCTAssertTrue(verificationColumns.contains("calibration_note"))

            let lensColumns = Set(try db.columns(in: "lens_sessions").map(\.name))
            XCTAssertTrue(lensColumns.contains("daily_entry_id"))
            XCTAssertTrue(lensColumns.contains("selected_lens"))
            XCTAssertTrue(lensColumns.contains("questions_json"))
        }
    }

    func testMigration_v4_addsProjectEvidenceTables() throws {
        try dbQueue.read { db in
            let projectColumns = Set(try db.columns(in: "projects").map(\.name))
            XCTAssertTrue(projectColumns.contains("name"))
            XCTAssertTrue(projectColumns.contains("success_criteria"))
            XCTAssertTrue(projectColumns.contains("current_bottleneck"))
            XCTAssertTrue(projectColumns.contains("merge_history_json"))
            XCTAssertTrue(projectColumns.contains("field_revisions_json"))

            let candidateColumns = Set(try db.columns(in: "project_candidates").map(\.name))
            XCTAssertTrue(candidateColumns.contains("suggested_name"))
            XCTAssertTrue(candidateColumns.contains("reason"))
            XCTAssertTrue(candidateColumns.contains("source_refs_json"))
            XCTAssertTrue(candidateColumns.contains("accepted_project_id"))

            let linkColumns = Set(try db.columns(in: "project_links").map(\.name))
            XCTAssertTrue(linkColumns.contains("source_type"))
            XCTAssertTrue(linkColumns.contains("source_id"))
            XCTAssertTrue(linkColumns.contains("link_type"))
            XCTAssertTrue(linkColumns.contains("is_user_confirmed"))

            let insightColumns = Set(try db.columns(in: "project_insights").map(\.name))
            XCTAssertTrue(insightColumns.contains("insight_type"))
            XCTAssertTrue(insightColumns.contains("before_text"))
            XCTAssertTrue(insightColumns.contains("after_text"))
            XCTAssertTrue(insightColumns.contains("source_refs_json"))
            XCTAssertTrue(insightColumns.contains("user_feedback"))
        }
    }

    // MARK: - Growth Attribution Repositories

    func testSaveSnapshot_andLoadLatestPreservesAttributionFields() async throws {
        let repo = SQLiteMetricSnapshotRepository(database: database)
        let startDate = Date(timeIntervalSince1970: 1_800_000_000)
        let endDate = Date(timeIntervalSince1970: 1_800_604_800)
        let snapshot = MetricSnapshot(
            period: "weekly",
            startDate: startDate,
            endDate: endDate,
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            previousClarity: 3.4,
            previousValueJudgment: 3.2,
            previousExecutionReliability: 3.0,
            previousCalibration: 2.8,
            previousReflectionDepth: 3.3,
            clarityDelta: 0.4,
            valueJudgmentDelta: 0.3,
            executionReliabilityDelta: 0.2,
            calibrationDelta: 0.2,
            reflectionDepthDelta: 0.3,
            summary: "清晰度提升，因为问题定义更具体。",
            metricReasons: [
                GrowthMetric.clarity.rawValue: "问题定义更具体",
                GrowthMetric.valueJudgment.rawValue: "更常选择高杠杆动作"
            ],
            evidenceRefs: ["entry-1", "entry-2", "entry-3"],
            positiveContributionRefs: ["contribution-1", "contribution-2"],
            negativeContributionRefs: ["contribution-3"],
            status: .confirmedTrend,
            completeLoopCount: 3,
            nextTrainingFocus: "继续练习会前确认目标"
        )

        try await repo.saveSnapshot(snapshot)

        let loaded = try await repo.latestSnapshot()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.period, "weekly")
        XCTAssertEqual(loaded?.clarity, 3.8)
        XCTAssertEqual(loaded?.previousClarity, 3.4)
        XCTAssertEqual(loaded?.clarityDelta, 0.4)
        XCTAssertEqual(loaded?.summary, "清晰度提升，因为问题定义更具体。")
        XCTAssertEqual(loaded?.metricReasons[GrowthMetric.clarity.rawValue], "问题定义更具体")
        XCTAssertEqual(loaded?.evidenceRefs, ["entry-1", "entry-2", "entry-3"])
        XCTAssertEqual(loaded?.positiveContributionRefs, ["contribution-1", "contribution-2"])
        XCTAssertEqual(loaded?.negativeContributionRefs, ["contribution-3"])
        XCTAssertEqual(loaded?.status, .confirmedTrend)
        XCTAssertEqual(loaded?.completeLoopCount, 3)
        XCTAssertEqual(loaded?.nextTrainingFocus, "继续练习会前确认目标")
        XCTAssertFalse(loaded?.hasInsufficientEvidence == true)
        XCTAssertTrue(loaded?.canDisplayScores == true)
    }

    func testSaveSnapshot_insufficientEvidenceRoundTrip() async throws {
        let repo = SQLiteMetricSnapshotRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "weekly",
            clarity: 0,
            valueJudgment: 0,
            executionReliability: 0,
            calibration: 0,
            reflectionDepth: 0,
            summary: "尚未积累证据",
            status: .insufficientEvidence,
            completeLoopCount: 2
        )

        try await repo.saveSnapshot(snapshot)
        let loaded = try await repo.latestSnapshot()
        XCTAssertTrue(loaded?.hasInsufficientEvidence == true)
        XCTAssertFalse(loaded?.canDisplayScores == true)
        XCTAssertEqual(loaded?.metricReasons, [:])
        XCTAssertEqual(loaded?.evidenceRefs, [])
    }

    func testSaveSnapshot_andLoadById() async throws {
        let repo = SQLiteMetricSnapshotRepository(database: database)
        let snapshot = MetricSnapshot(
            period: "monthly",
            clarity: 4.0,
            valueJudgment: 3.8,
            executionReliability: 3.5,
            calibration: 3.2,
            reflectionDepth: 3.9,
            summary: "Monthly snapshot",
            positiveContributionRefs: ["contribution-1"],
            status: .confirmedTrend,
            completeLoopCount: 3
        )

        try await repo.saveSnapshot(snapshot)
        let loaded = try await repo.snapshot(id: snapshot.id)
        XCTAssertEqual(loaded?.id, snapshot.id)
        XCTAssertEqual(loaded?.period, "monthly")
    }

    func testSaveContribution_andLoad() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let sourceDailyEntryId = UUID()
        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            summary: "Test"
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let contribution = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.4,
            title: "问题定义更具体",
            reason: "问题定义更具体",
            sourceType: .thinkingCard,
            sourceId: "card-2",
            sourceDailyEntryId: sourceDailyEntryId,
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(contribution)

        let loaded = try await contributionRepo.contributions(for: snapshotId)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].metric, .clarity)
        XCTAssertEqual(loaded[0].direction, .positive)
        XCTAssertEqual(loaded[0].delta, 0.4)
        XCTAssertEqual(loaded[0].title, "问题定义更具体")
        XCTAssertEqual(loaded[0].reason, "问题定义更具体")
        XCTAssertEqual(loaded[0].sourceType, .thinkingCard)
        XCTAssertEqual(loaded[0].sourceId, "card-2")
        XCTAssertEqual(loaded[0].sourceDailyEntryId, sourceDailyEntryId)
        XCTAssertEqual(loaded[0].userFeedback, .accepted)
        XCTAssertEqual(loaded[0].candidateStatus, .accepted)
    }

    func testSaveContribution_emptySourceIdThrowsValidation() async throws {
        let repo = SQLiteMetricContributionRepository(database: database)
        let contribution = MetricContribution(
            snapshotId: UUID(),
            metric: .clarity,
            direction: .positive,
            delta: 0.1,
            title: "Should fail",
            reason: "Should fail",
            sourceType: .dailyEntry,
            sourceId: "   ",
            sourceDailyEntryId: UUID()
        )

        try await assertValidationFailure {
            try await repo.saveContribution(contribution)
        }
    }

    func testUpdateContributionStatus_retainedAndExcludedFromAccepted() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3.8,
            valueJudgment: 3.5,
            executionReliability: 3.2,
            calibration: 3.0,
            reflectionDepth: 3.6,
            summary: "Test"
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let accepted = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.3,
            title: "Positive contribution",
            reason: "Positive contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        let rejected = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Rejected contribution",
            reason: "Rejected contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-2",
            sourceDailyEntryId: UUID()
        )
        try await contributionRepo.saveContribution(accepted)
        try await contributionRepo.saveContribution(rejected)

        try await contributionRepo.updateContributionStatus(.rejected, contributionId: rejected.id)

        let allContributions = try await contributionRepo.contributions(for: snapshotId)
        XCTAssertEqual(allContributions.count, 2)

        let acceptedOnly = try await contributionRepo.acceptedContributions(for: snapshotId, metric: .clarity)
        XCTAssertEqual(acceptedOnly.count, 1)
        XCTAssertEqual(acceptedOnly[0].delta, 0.3)
    }

    func testReconstructionFromAcceptedDeltas() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let previousValue = 3.0
        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: "weekly",
            clarity: 3.5,
            valueJudgment: 3.0,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            previousClarity: previousValue,
            summary: "Test reconstruction"
        )
        try await snapshotRepo.saveSnapshot(snapshot)

        let c1 = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.3,
            title: "Refined problem statement",
            reason: "Refined problem statement",
            sourceType: .thinkingCard,
            sourceId: "card-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        let c2 = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Completed verification",
            reason: "Completed verification",
            sourceType: .verification,
            sourceId: "verification-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        let c3 = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.5,
            title: "Dismissed outlier",
            reason: "Dismissed outlier",
            sourceType: .dailyEntry,
            sourceId: "entry-3",
            sourceDailyEntryId: UUID(),
            userFeedback: .dismissed,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(c1)
        try await contributionRepo.saveContribution(c2)
        try await contributionRepo.saveContribution(c3)

        let accepted = try await contributionRepo.acceptedContributions(for: snapshotId, metric: .clarity)
        let reconstructedValue = previousValue + accepted.map(\.delta).reduce(0, +)
        XCTAssertEqual(reconstructedValue, 3.5, "Current value must equal previous + sum of accepted deltas")
    }

    // MARK: - History Evidence Repository Helpers

    func testProjectLinks_forSourceIds_returnsMatchingLinks() async throws {
        let repo = SQLiteProjectLinkRepository(database: database)
        let projectA = UUID()
        let projectB = UUID()

        let link1 = ProjectLink(
            projectId: projectA,
            sourceType: .thinkingCard,
            sourceId: "card-1",
            linkType: .evidence,
            confidence: 0.8,
            isUserConfirmed: true
        )
        let link2 = ProjectLink(
            projectId: projectA,
            sourceType: .quest,
            sourceId: "quest-1",
            linkType: .task
        )
        let link3 = ProjectLink(
            projectId: projectB,
            sourceType: .thinkingCard,
            sourceId: "card-2",
            linkType: .blocker
        )

        try await repo.saveLink(link1)
        try await repo.saveLink(link2)
        try await repo.saveLink(link3)

        let matching = try await repo.links(forSourceIds: ["card-1", "quest-1"])
        XCTAssertEqual(matching.count, 2)
        let matchingIds = Set(matching.map(\.id))
        XCTAssertTrue(matchingIds.contains(link1.id))
        XCTAssertTrue(matchingIds.contains(link2.id))

        let noMatch = try await repo.links(forSourceIds: ["nonexistent"])
        XCTAssertEqual(noMatch.count, 0)

        let empty = try await repo.links(forSourceIds: [])
        XCTAssertEqual(empty.count, 0)
    }

    func testMetricContributions_forDailyEntryId_returnsAcceptedOnly() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        let entryA = UUID()
        let entryB = UUID()

        try await snapshotRepo.saveSnapshot(
            MetricSnapshot(id: snapshotId, period: "weekly", clarity: 3.0, valueJudgment: 3.0,
                           executionReliability: 3.0, calibration: 3.0, reflectionDepth: 3.0, summary: "Test")
        )

        let accepted = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.3,
            title: "Accepted contribution",
            reason: "Accepted contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-a",
            sourceDailyEntryId: entryA,
            userFeedback: .none,
            candidateStatus: .accepted
        )
        let rejected = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.2,
            title: "Rejected contribution",
            reason: "Rejected contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-a-2",
            sourceDailyEntryId: entryA,
            userFeedback: .none,
            candidateStatus: .rejected
        )
        let inaccurate = MetricContribution(
            snapshotId: snapshotId,
            metric: .clarity,
            direction: .positive,
            delta: 0.1,
            title: "Inaccurate contribution",
            reason: "Inaccurate contribution",
            sourceType: .dailyEntry,
            sourceId: "entry-b-1",
            sourceDailyEntryId: entryB,
            userFeedback: .inaccurate,
            candidateStatus: .accepted
        )

        try await contributionRepo.saveContribution(accepted)
        try await contributionRepo.saveContribution(rejected)
        try await contributionRepo.saveContribution(inaccurate)

        let entryAResults = try await contributionRepo.contributions(forDailyEntryId: entryA)
        XCTAssertEqual(entryAResults.count, 1)
        XCTAssertEqual(entryAResults[0].title, "Accepted contribution")

        let entryBResults = try await contributionRepo.contributions(forDailyEntryId: entryB)
        XCTAssertEqual(entryBResults.count, 0, "Inaccurate contributions excluded")

        let noResults = try await contributionRepo.contributions(forDailyEntryId: UUID())
        XCTAssertEqual(noResults.count, 0)
    }

    func testUpdateContributionFeedback_toInaccurateExcludesFromAccepted() async throws {
        let snapshotRepo = SQLiteMetricSnapshotRepository(database: database)
        let contributionRepo = SQLiteMetricContributionRepository(database: database)

        let snapshotId = UUID()
        try await snapshotRepo.saveSnapshot(
            MetricSnapshot(id: snapshotId, period: "weekly", clarity: 3.0, valueJudgment: 3.0,
                           executionReliability: 3.0, calibration: 3.0, reflectionDepth: 3.0, summary: "Test")
        )

        let contribution = MetricContribution(
            snapshotId: snapshotId,
            metric: .calibration,
            direction: .negative,
            delta: -0.2,
            title: "Initial assessment",
            reason: "Initial assessment",
            sourceType: .dailyEntry,
            sourceId: "entry-1",
            sourceDailyEntryId: UUID(),
            userFeedback: .accepted,
            candidateStatus: .accepted
        )
        try await contributionRepo.saveContribution(contribution)
        try await contributionRepo.updateContributionFeedback(.inaccurate, contributionId: contribution.id)

        let all = try await contributionRepo.contributions(for: snapshotId)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].userFeedback, .inaccurate)

        let accepted = try await contributionRepo.acceptedContributions(for: snapshotId, metric: .calibration)
        XCTAssertEqual(accepted.count, 0, "Inaccurate contributions excluded from accepted")
    }

    // MARK: - Migration v5

    func testMigration_v5_addsGrowthAttributionTables() throws {
        try dbQueue.read { db in
            let snapshotColumns = Set(try db.columns(in: "metric_snapshots").map(\.name))
            XCTAssertTrue(snapshotColumns.contains("period"))
            XCTAssertTrue(snapshotColumns.contains("start_date"))
            XCTAssertTrue(snapshotColumns.contains("end_date"))
            XCTAssertTrue(snapshotColumns.contains("clarity"))
            XCTAssertTrue(snapshotColumns.contains("previous_scores_json"))
            XCTAssertTrue(snapshotColumns.contains("delta_scores_json"))
            XCTAssertTrue(snapshotColumns.contains("metric_reasons_json"))
            XCTAssertTrue(snapshotColumns.contains("summary"))
            XCTAssertTrue(snapshotColumns.contains("evidence_refs_json"))
            XCTAssertTrue(snapshotColumns.contains("positive_contribution_refs_json"))
            XCTAssertTrue(snapshotColumns.contains("negative_contribution_refs_json"))
            XCTAssertTrue(snapshotColumns.contains("status"))
            XCTAssertTrue(snapshotColumns.contains("complete_loop_count"))
            XCTAssertTrue(snapshotColumns.contains("next_training_focus"))

            let contributionColumns = Set(try db.columns(in: "metric_contributions").map(\.name))
            XCTAssertTrue(contributionColumns.contains("snapshot_id"))
            XCTAssertTrue(contributionColumns.contains("metric"))
            XCTAssertTrue(contributionColumns.contains("direction"))
            XCTAssertTrue(contributionColumns.contains("delta"))
            XCTAssertTrue(contributionColumns.contains("title"))
            XCTAssertTrue(contributionColumns.contains("reason"))
            XCTAssertTrue(contributionColumns.contains("source_type"))
            XCTAssertTrue(contributionColumns.contains("source_id"))
            XCTAssertTrue(contributionColumns.contains("source_daily_entry_id"))
            XCTAssertTrue(contributionColumns.contains("user_feedback"))
            XCTAssertTrue(contributionColumns.contains("candidate_status"))
        }
    }

    func testMigration_v6_backfillsLegacyMetricContributionSourceDailyEntryId() throws {
        let legacyQueue = try DatabaseQueue()
        try legacyQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE metric_contributions (
                    id TEXT PRIMARY KEY,
                    schema_version INTEGER NOT NULL,
                    snapshot_id TEXT NOT NULL,
                    metric TEXT NOT NULL,
                    direction TEXT NOT NULL,
                    delta DOUBLE NOT NULL,
                    title TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_id TEXT NOT NULL,
                    user_feedback TEXT NOT NULL,
                    candidate_status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT
                )
                """
            )
        }

        let migrator = AppDatabase.makeMigrator()
        try migrator.migrate(legacyQueue)

        try legacyQueue.read { db in
            let contributionColumns = Set(try db.columns(in: "metric_contributions").map(\.name))
            XCTAssertTrue(contributionColumns.contains("source_daily_entry_id"))
        }
    }

    // MARK: - Helper

    private func readCreatedAt(for id: UUID) -> String? {
        try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT created_at FROM daily_entries WHERE id = ?", arguments: [id.uuidString])
        }
    }

    private static func storageString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static let mismatchedContentHash = "sha256:" + String(repeating: "0", count: 64)

    private static func trusted(_ pack: PromptAssetPack) throws -> PromptAssetPack {
        let contentHash = try AssetPackIntegrity.expectedContentHash(for: pack)
        return PromptAssetPack(
            id: pack.id,
            version: pack.version,
            displayName: pack.displayName,
            sourceKind: pack.sourceKind,
            isEnabled: pack.isEnabled,
            templates: pack.templates,
            trustMetadata: try signedTrustMetadata(
                contentHash: contentHash,
                signedPayload: AssetPackIntegrity.signaturePayload(for: pack)
            )
        )
    }

    private static func trusted(_ pack: LensAssetPack) throws -> LensAssetPack {
        let contentHash = try AssetPackIntegrity.expectedContentHash(for: pack)
        return LensAssetPack(
            id: pack.id,
            version: pack.version,
            displayName: pack.displayName,
            sourceKind: pack.sourceKind,
            isEnabled: pack.isEnabled,
            items: pack.items,
            trustMetadata: try signedTrustMetadata(
                contentHash: contentHash,
                signedPayload: AssetPackIntegrity.signaturePayload(for: pack)
            )
        )
    }

    private static func makeTrustMetadata(
        publisherId: String = "mingsi.test.publisher",
        contentHash: String,
        signature: String = "p256-sha256:invalid-test-signature",
        verificationPolicyVersion: String = "asset-trust.test.v1"
    ) -> AssetTrustMetadata {
        AssetTrustMetadata(
            publisherId: publisherId,
            contentHash: contentHash,
            signature: signature,
            trustedAt: "2026-06-10T00:00:00Z",
            verificationPolicyVersion: verificationPolicyVersion
        )
    }

    private static func signedTrustMetadata(
        publisherId: String = "mingsi.test.publisher",
        contentHash: String,
        signedPayload: Data,
        verificationPolicyVersion: String = "asset-trust.test.v1",
        privateKeyBase64: String = testPublisherPrivateKeyBase64
    ) throws -> AssetTrustMetadata {
        makeTrustMetadata(
            publisherId: publisherId,
            contentHash: contentHash,
            signature: try signature(for: signedPayload, privateKeyBase64: privateKeyBase64),
            verificationPolicyVersion: verificationPolicyVersion
        )
    }

    private static func signedTrustPolicyDocument(
        _ document: AssetPackTrustPolicyDocument,
        privateKeyBase64: String = testRegistryRootPrivateKeyBase64
    ) throws -> AssetPackTrustPolicyDocument {
        AssetPackTrustPolicyDocument(
            policies: document.policies,
            expiresAt: document.expiresAt,
            trustMetadata: try signedTrustMetadata(
                publisherId: "mingsi.test.registry",
                contentHash: try AssetPackIntegrity.expectedContentHash(for: document),
                signedPayload: AssetPackIntegrity.signaturePayload(for: document),
                verificationPolicyVersion: "asset-trust-policy-root.test.v1",
                privateKeyBase64: privateKeyBase64
            )
        )
    }

    private static func signature(for payload: Data, privateKeyBase64: String = testPublisherPrivateKeyBase64) throws -> String {
        let keyData = try XCTUnwrap(Data(base64Encoded: privateKeyBase64))
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
        let signature = try privateKey.signature(for: payload)
        return "p256-sha256:" + signature.derRepresentation.base64EncodedString()
    }

    private static let testPublisherPrivateKeyBase64 = "Zcl0fRH+ywPs2LCNnRt4Jgkkg2IQWBwb0X42sTsVrKc="
    private static let rotatedPublisherPrivateKeyBase64 = "XevPucFuvG6Qc3pJsFZIrGxO/SyZ0h7joKaZCTq4F84="
    private static let testRegistryRootPrivateKeyBase64 = "khu517UBQX2f62ROBcl1XuforsMkVw7gbkhzHpGPug4="

    private static let assetPackJSONEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let assetPackJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func encodedJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func assertValidationFailure(
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
            XCTFail("Expected validation failure", file: file, line: line)
        } catch let error as MingSi.PersistenceError {
            if case .validationFailed = error {
                return
            }
            XCTFail("Expected validation failure, got \(error)", file: file, line: line)
        } catch {
            XCTFail("Expected validation failure, got \(error)", file: file, line: line)
        }
    }
}

private final class AlwaysFailingLLMClient: LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.httpStatus(503, Data("service unavailable".utf8))
    }
}
