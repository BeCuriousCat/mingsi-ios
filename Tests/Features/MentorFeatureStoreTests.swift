import XCTest
import GRDB
@testable import MingSi

@MainActor
final class MentorFeatureStoreTests: XCTestCase {
    func testDeleteViewedSessionClearsOwnedContentAndRefreshesHome() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "需要删除的交流")
        try await waitUntil { store.state.phase == .editing }
        let id = try XCTUnwrap(store.state.session?.id)
        store.beginUnderstanding()
        store.saveUnderstanding(text: "所属理解")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        store.submit(text: "提交的原话")
        try await waitUntil { store.state.phase == .showingResponse }
        let rejected = await store.deleteViewedSession()
        XCTAssertFalse(rejected, "Live editing cannot bypass the history confirmation route")
        store.viewSession(id: id)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        let deleted = await store.deleteViewedSession()
        XCTAssertTrue(deleted)
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertNil(store.state.session)
        XCTAssertNil(store.state.response)
        XCTAssertTrue(store.state.understandings.isEmpty)
        XCTAssertTrue(store.state.recentSessions.isEmpty)
        XCTAssertNil(store.state.latestUnfinishedSession)
        let remainingSession = try await repo.session(id: id)
        let remainingItems = try await repo.items(sessionID: id)
        let remainingNotes = try await repo.understandings(sessionID: id)
        XCTAssertNil(remainingSession)
        XCTAssertTrue(remainingItems.isEmpty)
        XCTAssertTrue(remainingNotes.isEmpty)
        let requestCount = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(transport.calls, 1)
    }

    func testFailedDeletionPreservesHistoryAndCanBeRetried() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "不能静默丢失")
        try await waitUntil { store.state.phase == .editing }
        let id = try XCTUnwrap(store.state.session?.id)
        store.viewSession(id: id)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_history_delete BEFORE DELETE ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let deleted = await store.deleteViewedSession()
        XCTAssertFalse(deleted)
        XCTAssertEqual(store.state.session?.id, id)
        XCTAssertEqual(store.state.inputText, "不能静默丢失")
        XCTAssertTrue(store.state.isViewingHistory)
        XCTAssertNotNil(store.state.deletionError)
        XCTAssertFalse(store.state.isTransitioningSession)
        let retained = try await repo.session(id: id)
        XCTAssertNotNil(retained)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_history_delete") }
        let retried = await store.deleteViewedSession()
        XCTAssertTrue(retried)
        XCTAssertNil(store.state.session)
    }

    func testViewingHistoryPreservesLifecycleDraftAndVersionsUntilExplicitContinuation() async throws {
        for lifecycle in [MentorSessionLifecycle.active, .paused, .ended] {
            let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
            let id = UUID()
            try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: lifecycle,
                draftText: "历史草稿", draftRevision: 1, activityAt: .now))
            let note = try await repo.beginUserUnderstanding(sessionID: id, draftID: UUID(), previousRevisionID: nil)
            _ = try await repo.saveUnderstandingDraft(sessionID: id, draftID: note.id, editRevision: 1, text: "历史理解")
            let before = try await repo.session(id: id)
            let notes = try await repo.understandings(sessionID: id)
            let transport = MentorStoreFixtureTransport()
            let store = MentorFeatureStore(repository: repo, transport: transport)
            store.viewSession(id: id)
            try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
            XCTAssertEqual(store.state.inputText, "历史草稿")
            store.updateInputText("不能修改")
            store.submit(text: "不能发送")
            store.beginUnderstanding()
            store.saveUnderstanding(text: "不能覆盖理解")
            store.confirmUnderstanding()
            store.pause()
            store.finish()
            let after = try await repo.session(id: id)
            let unchangedNotes = try await repo.understandings(sessionID: id)
            XCTAssertEqual(before, after)
            XCTAssertEqual(notes, unchangedNotes)
            XCTAssertEqual(transport.calls, 0)
            store.continueSession(id: id)
            try await waitUntil { !store.state.isViewingHistory && store.state.phase == .editing }
            let continued = try await repo.session(id: id)
            XCTAssertEqual(continued?.lifecycle, .active)
            XCTAssertEqual(continued?.draftText, "历史草稿")
        }
    }

    func testStartingAfterViewingHistoryDoesNotPauseTheViewedRecord() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "保留历史状态", draftRevision: 1, activityAt: .now))
        let before = try await repo.session(id: id)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.viewSession(id: id)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        store.start(entry: "discuss")
        try await waitUntil { store.state.session?.id != id }
        XCTAssertFalse(store.state.isViewingHistory)
        let after = try await repo.session(id: id)
        XCTAssertEqual(after, before)
    }

    func testHomeResumptionIsIndependentOfRecentHistoryPage() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let unfinishedID = UUID()
        try await repo.createSession(MentorSession(id: unfinishedID, initialEntry: "discuss", lifecycle: .paused,
            draftText: "还没说完的一件事", draftRevision: 1, activityAt: date))
        for index in 1...25 {
            try await repo.createSession(MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .ended,
                draftText: "较新的已结束交流", draftRevision: 1, activityAt: date.addingTimeInterval(Double(index))))
        }
        // An empty abandoned entry is not resumable material.
        try await repo.createSession(MentorSession(id: UUID(), initialEntry: "listen", lifecycle: .draft,
            draftText: "", draftRevision: 0, activityAt: date.addingTimeInterval(30)))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.loadRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertEqual(store.state.recentSessions.count, 3)
        XCTAssertTrue(store.state.recentSessions.allSatisfy { $0.lifecycle == .ended })
        XCTAssertEqual(store.state.latestUnfinishedSession?.id, unfinishedID)
        store.loadMoreRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertEqual(store.state.latestUnfinishedSession?.id, unfinishedID)
        try await repo.suspendSession(id: unfinishedID, ending: true, draftRevision: 1, draftText: "还没说完的一件事")
        store.loadRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertNil(store.state.latestUnfinishedSession)
    }

    func testUnsupportedIntentDoesNotSubmitOrChangeDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "保留原文")
        try await waitUntil { store.state.phase == .editing }
        let original = store.state.session
        for intent in ["draft_understanding", "unknown", ""] {
            store.submit(intent: intent, text: "不能被当作普通交流")
            XCTAssertEqual(store.state.phase, .editing)
            XCTAssertEqual(store.state.session, original)
            XCTAssertEqual(store.state.inputText, "保留原文")
            XCTAssertNotNil(store.state.actionError)
        }
        XCTAssertEqual(transport.calls, 0)
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(count, 0)
    }

    func testNewResponseHidesUnavailableAIDraftButKeepsAuditableOutput() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        transport.suggestedActions = ["draft_understanding", "reply", "finish"]
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "今天意识到交付不等于效果")
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(store.state.response?.availableSuggestedActions, [.reply, .finish])
        XCTAssertEqual(store.state.response?.response.suggestedActions, [.draftUnderstanding, .reply, .finish])
    }

    func testUnsupportedHistoricalIntentCannotRetryThroughConversationPrompt() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
            text: "原话", intent: "draft_understanding", contextSnapshotJSON: "{}"))
        try await repo.finishRequest(sessionID: id, requestID: requestID, reason: .failed)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.continueSession(id: id)
        try await waitUntil { store.state.phase == .editing }
        store.retryLastRequest()
        try await waitUntil { store.state.phase != .submitting }
        XCTAssertNotNil(store.state.retryError)
        XCTAssertEqual(transport.calls, 0)
        let candidate = try await repo.retryableRequest(sessionID: id)
        XCTAssertEqual(candidate?.id, requestID)
    }

    func testRestoredSuggestionsReflectCurrentCapabilitiesWithoutRewritingHistory() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
            text: "用户原话", intent: "reply", contextSnapshotJSON: "{}"))
        let payload = """
        {"schema_version":"1.0.0","action":"explain","material_status":"usable","body":"一个新视角","question":null,"question_purpose":null,"source_refs":[],"lesson_ref":null,"suggested_actions":["draft_understanding","another_lesson","reply","finish"]}
        """
        let item = try await repo.commitResponse(sessionID: id, requestID: requestID, payloadJSON: payload)
        for hasCatalog in [false, true] {
            let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(),
                catalog: hasCatalog ? try catalog() : nil)
            store.continueSession(id: id)
            try await waitUntil { store.state.phase == .showingResponse }
            XCTAssertEqual(store.state.response?.availableSuggestedActions,
                hasCatalog ? [.anotherLesson, .reply, .finish] : [.reply, .finish])
            XCTAssertEqual(store.state.response?.response.suggestedActions,
                [.draftUnderstanding, .anotherLesson, .reply, .finish])
        }
        let stored = try await repo.items(sessionID: id)
        XCTAssertEqual(stored.first { $0.id == item.id }?.payloadJSON, payload)
    }

    func testDiscardUnderstandingCancelsDebounceAndKeepsPersistedContent() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "交流草稿也要保留")
        try await waitUntil { store.state.phase == .editing }
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.beginUnderstanding()
        store.saveUnderstanding(text: "已经保存的理解")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let original = store.state.understanding
        store.updateUnderstandingText("放弃尚在防抖窗口的文字")
        let discarded = await store.discardUnderstandingEdits()
        XCTAssertTrue(discarded)
        XCTAssertEqual(store.state.understanding, original)
        XCTAssertEqual(store.state.understandingInputText, "已经保存的理解")
        XCTAssertEqual(store.state.inputText, "交流草稿也要保留")
        XCTAssertFalse(store.state.hasUnsavedUnderstanding)
        try await Task.sleep(for: .milliseconds(600))
        let saved = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(saved, [try XCTUnwrap(original)])
        XCTAssertEqual(transport.calls, 0)
    }

    func testDiscardFailedRevisionPreservesConfirmedOriginalAndSavedDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "已确认的原版本")
        store.confirmUnderstanding()
        try await waitUntil { !store.state.isConfirmingUnderstanding }
        let confirmed = try XCTUnwrap(store.state.understanding)
        store.beginUnderstanding(previousRevisionID: confirmed.id)
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER fail_discard_note BEFORE UPDATE OF text ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.saveUnderstanding(text: "无法保存的新版本")
        try await waitUntil { store.state.understandingError != nil }
        let discarded = await store.discardUnderstandingEdits()
        XCTAssertTrue(discarded)
        XCTAssertNil(store.state.understandingError)
        XCTAssertEqual(store.state.understandingInputText, confirmed.text)
        XCTAssertEqual(store.state.understanding?.state, .draft)
        let notes = try await repo.understandings(sessionID: confirmed.sessionID)
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes.first { $0.id == confirmed.id }, confirmed)
    }

    func testDiscardWaitsForQueuedSaveAndRestoresItsCommittedSnapshot() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "已排队的保存")
        store.updateUnderstandingText("还没入队的输入")
        let discarded = await store.discardUnderstandingEdits()
        XCTAssertTrue(discarded)
        XCTAssertEqual(store.state.understandingInputText, "已排队的保存")
        XCTAssertEqual(store.state.pendingUnderstandingOperations, 0)
        XCTAssertFalse(store.state.hasUnsavedUnderstanding)
    }

    func testDiscardReadFailureKeepsBufferAndCanRetryAfterDatabaseRecovery() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "已保存")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        store.updateUnderstandingText("仍须保留的输入")
        try await db.dbQueue.write { try $0.execute(sql: "ALTER TABLE mentor_understandings RENAME TO temporarily_unavailable_understandings") }
        let failed = await store.discardUnderstandingEdits()
        XCTAssertFalse(failed)
        XCTAssertEqual(store.state.understandingInputText, "仍须保留的输入")
        XCTAssertTrue(store.state.hasUnsavedUnderstanding)
        XCTAssertNotNil(store.state.understandingError)
        XCTAssertFalse(store.state.isTransitioningSession)
        try await db.dbQueue.write { try $0.execute(sql: "ALTER TABLE temporarily_unavailable_understandings RENAME TO mentor_understandings") }
        let recovered = await store.discardUnderstandingEdits()
        XCTAssertTrue(recovered)
        XCTAssertEqual(store.state.understandingInputText, "已保存")
    }

    func testDiscardFailedCreationDoesNotDeleteOtherUnderstandingGroups() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "另一组草稿")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let original = try XCTUnwrap(store.state.understanding)
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER fail_discard_creation BEFORE INSERT ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.beginUnderstanding()
        store.updateUnderstandingText("未创建成功的草稿")
        try await waitUntil { store.state.understandingError != nil }
        let discarded = await store.discardUnderstandingEdits()
        XCTAssertTrue(discarded)
        XCTAssertNil(store.state.understanding)
        XCTAssertEqual(store.state.understandingInputText, "")
        XCTAssertEqual(store.state.understandings, [original])
        let saved = try await repo.understandings(sessionID: original.sessionID)
        XCTAssertEqual(saved, [original])
    }

    func testUnderstandingTypingDebouncesAndDoesNotReplaceNewerInput() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let original = try XCTUnwrap(store.state.understanding)
        store.updateUnderstandingText("第一句")
        try await Task.sleep(for: .milliseconds(150))
        store.updateUnderstandingText("最后一句")
        XCTAssertTrue(store.state.hasUnsavedUnderstanding)
        store.beginUnderstanding()
        XCTAssertEqual(store.state.understanding?.id, original.id)
        try await Task.sleep(for: .milliseconds(200))
        let before = try await repo.understandings(sessionID: original.sessionID)
        XCTAssertEqual(before.first?.text, original.text)
        XCTAssertEqual(store.state.understandingInputText, "最后一句")
        try await waitUntil { !store.state.hasUnsavedUnderstanding }
        let after = try await repo.understandings(sessionID: original.sessionID)
        XCTAssertEqual(after.first?.text, "最后一句")
        XCTAssertEqual(after.first?.editRevision, original.editRevision + 1)
        XCTAssertEqual(transport.calls, 0)
    }

    func testEarlierUnderstandingSaveDoesNotUnlockEditorWithDebouncePending() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let id = store.state.understanding?.id
        store.saveUnderstanding(text: "原句")
        store.updateUnderstandingText("临时修改")
        store.updateUnderstandingText("原句")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertTrue(store.state.hasUnsavedUnderstanding)
        store.beginUnderstanding()
        XCTAssertEqual(store.state.understanding?.id, id)
        let flushed = await store.flushPendingEdits()
        XCTAssertTrue(flushed)
        XCTAssertFalse(store.state.hasUnsavedUnderstanding)
        XCTAssertEqual(store.state.understanding?.text, "原句")
    }

    func testUnderstandingDebounceFlushesOnConfirmationAndSessionExit() async throws {
        for confirm in [false, true] {
            let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
            let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing }
            let id = try XCTUnwrap(store.state.session?.id)
            store.beginUnderstanding()
            store.updateUnderstandingText("创建期间输入并立即离开")
            if confirm { store.confirmUnderstanding() }
            else { store.start(entry: "discuss") }
            try await waitUntil { !store.state.isTransitioningSession && !store.state.isConfirmingUnderstanding }
            let saved = try await repo.understandings(sessionID: id)
            XCTAssertEqual(saved.first?.text, "创建期间输入并立即离开")
            XCTAssertEqual(saved.first?.state, confirm ? .confirmed : .draft)
            XCTAssertFalse(store.state.hasUnsavedUnderstanding)
        }
    }

    func testUnderstandingDebouncedSaveFailurePreservesTextUntilExplicitRetry() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let id = try XCTUnwrap(store.state.session?.id)
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER fail_debounced_note BEFORE UPDATE OF text ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.updateUnderstandingText("尚未落盘的理解")
        let flushed = await store.flushPendingEdits()
        XCTAssertFalse(flushed)
        XCTAssertTrue(store.state.hasUnsavedUnderstanding)
        store.start(entry: "discuss")
        try await waitUntil { !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.session?.id, id)
        XCTAssertEqual(store.state.understandingInputText, "尚未落盘的理解")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_debounced_note") }
        store.retryUnderstandingSave()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertFalse(store.state.hasUnsavedUnderstanding)
        XCTAssertNil(store.state.understandingError)
        let saved = try await repo.understandings(sessionID: id)
        XCTAssertEqual(saved.first?.text, "尚未落盘的理解")
    }

    func testSwitchInvalidatesHeldRequestForNewAndExistingDestinations() async throws {
        for existing in [false, true] {
            let db = try AppDatabase(dbQueue: DatabaseQueue())
            let repo = SQLiteMentorRepository(database: db)
            let held = HeldMentorTransport()
            let store = MentorFeatureStore(repository: repo, transport: held)
            let destination = UUID()
            if existing {
                try await repo.createSession(MentorSession(id: destination, initialEntry: "discuss", lifecycle: .draft, draftText: "", draftRevision: 0, activityAt: .now))
            }
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing }
            let oldID = try XCTUnwrap(store.state.session?.id)
            store.submit(text: "旧会话原话")
            try await waitUntil { held.pending != nil }
            let before = try await repo.session(id: oldID)
            if existing { store.continueSession(id: destination) }
            else { store.start(entry: "discuss") }
            try await waitUntil { store.state.session?.id != oldID && !store.state.isTransitioningSession }
            let after = try await repo.session(id: oldID)
            XCTAssertEqual(after?.lifecycle, .paused)
            XCTAssertEqual(after?.requestEpoch, (before?.requestEpoch ?? 0) + 1)
            let retry = try await repo.retryableRequest(sessionID: oldID)
            XCTAssertNotNil(retry)
            let activeID = store.state.session?.id
            let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(held.request))
            held.pending?.resume(returning: payload)
            held.pending = nil
            try await waitUntil { held.didReturn }
            for _ in 0..<10 { await Task.yield() }
            XCTAssertEqual(store.state.session?.id, activeID)
            let items = try await repo.items(sessionID: oldID)
            XCTAssertFalse(items.contains { $0.kind == .assistant })
        }
    }

    func testSwitchSuspensionFailureKeepsOriginalDraftAndCanRetry() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "必须保留")
        try await waitUntil { store.state.phase == .editing }
        let original = try XCTUnwrap(store.state.session)
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER fail_switch BEFORE UPDATE OF lifecycle ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.start(entry: "discuss")
        try await waitUntil { !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.session?.id, original.id)
        XCTAssertEqual(store.state.inputText, "必须保留")
        let unchanged = try await repo.session(id: original.id)
        XCTAssertEqual(unchanged?.requestEpoch, original.requestEpoch)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_switch") }
        store.start(entry: "discuss")
        try await waitUntil { store.state.session?.id != original.id }
        let saved = try await repo.session(id: original.id)
        XCTAssertEqual(saved?.lifecycle, .paused)
        XCTAssertEqual(saved?.draftText, "必须保留")
    }

    func testDirectDiscussionPersistsInputAndValidatedResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(store.state.phase, .editing)
        guard let sessionID = store.state.session?.id else { return XCTFail("session missing") }
        let beforeSubmit = ContinuousClock().now
        store.submit(text: "今天完成了一个改动")
        let afterSubmit = ContinuousClock().now
        try await Task.sleep(for: .milliseconds(150))
        guard case .showingResponse = store.state.phase else { return XCTFail("response was not shown: \(store.state.phase)") }
        let startedAt = try XCTUnwrap(transport.lastRequest?.mentorStartedAt)
        XCTAssertGreaterThanOrEqual(startedAt, beforeSubmit)
        XCTAssertLessThanOrEqual(startedAt, afterSubmit)
        XCTAssertEqual(store.state.response?.response.action, .explain)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .user }.count, 1)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .assistant }.count, 1)
        let activeSession = try await repo.session(id: sessionID)
        XCTAssertEqual(activeSession?.lifecycle, .active)
        store.finish()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.state.phase, .ended)
        let endedSession = try await repo.session(id: sessionID)
        XCTAssertEqual(endedSession?.lifecycle, .ended)
    }

    func testListenEntryWorksWithoutNetworkAndFinishCancelsForegroundTask() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(store.state.phase, .reading)
        XCTAssertNotNil(store.state.lesson)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .lesson }.count, 1)
        store.acknowledgeLesson()
        try await Task.sleep(for: .milliseconds(80))
        store.finish()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.phase, .ended)
    }

    func testUnderstandingDraftAndConfirmationStayLocal() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await Task.sleep(for: .milliseconds(50))
        store.beginUnderstanding()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.understanding?.state, .draft)
        store.saveUnderstanding(text: "我会先区分动作和效果")
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.understanding?.text, "我会先区分动作和效果")
        store.confirmUnderstanding()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.understanding?.state, .confirmed)
        XCTAssertEqual(store.state.understanding?.confirmedAt != nil, true)
        let sessionID = try XCTUnwrap(store.state.session?.id)
        let understandings = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(understandings.count, 1)
    }

    func testRecentSessionsLoadAndContinueExistingDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "保留这件事")
        try await Task.sleep(for: .milliseconds(60))
        let id = try XCTUnwrap(store.state.session?.id)
        store.pause()
        try await Task.sleep(for: .milliseconds(80))
        store.loadRecentSessions()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.recentSessions.first?.id, id)
        store.continueSession(id: id)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.state.session?.id, id)
        XCTAssertEqual(store.state.inputText, "保留这件事")
        XCTAssertEqual(store.state.phase, .editing)
    }

    func testHistoryReadDoesNotCancelTransportAndFinishRejectsLateSuccess() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let id = try XCTUnwrap(store.state.session?.id)
        store.submit(text: "保留原话")
        try await waitUntil { transport.pending != nil }
        store.loadRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertEqual(store.state.phase, .submitting)
        XCTAssertFalse(transport.wasCancelled)
        store.finish()
        try await waitUntil { store.state.phase == .ended }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { transport.didReturn }
        // Drain the transport continuation and the Store's following actor work.
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(store.state.phase, .ended)
        let items = try await repo.items(sessionID: id)
        XCTAssertFalse(items.contains { $0.kind == .assistant })
    }

    func testHistoryReadAllowsCurrentResponseToComplete() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "这次不结束会话")
        try await waitUntil { transport.pending != nil }
        store.loadRecentSessions()
        try await waitUntil { !store.state.isLoadingHistory }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertFalse(transport.wasCancelled)
        XCTAssertNotNil(store.state.response)
    }

    func testNewStoreEntryDoesNotRecoverAnotherLiveRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
            text: "另一个页面的请求", intent: "reply", contextSnapshotJSON: "{}"))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let requestState = try await db.dbQueue.read {
            try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [requestID.uuidString])
        }
        XCTAssertEqual(requestState, "prepared")
        let original = try await repo.session(id: id)
        XCTAssertEqual(original?.lifecycle, .active)
    }

    func testHistoryFailureDoesNotReplaceConversationPhase() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.loadRecentSessions(limit: 0)
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertNotNil(store.state.historyError)
        XCTAssertEqual(store.state.phase, .editing)
    }

    func testResponseReceiptUnlocksNextTurnWithoutAcknowledgingNewResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "第一轮")
        try await waitUntil { store.state.phase == .showingResponse }
        let first = try XCTUnwrap(store.state.responseItemID)
        store.submit(text: "尚未呈现时不应提交")
        XCTAssertEqual(store.state.phase, .showingResponse)
        XCTAssertEqual(store.state.inputText, "第一轮")
        store.acknowledgeResponse(itemID: first)
        try await waitUntil { store.state.acknowledgedResponseItemID == first }
        store.submit(text: "第二轮")
        try await waitUntil { store.state.phase == .showingResponse && store.state.responseItemID != first }
        let second = try XCTUnwrap(store.state.responseItemID)
        store.acknowledgeResponse(itemID: first)
        XCTAssertNil(store.state.acknowledgedResponseItemID)
        let presented = try await db.dbQueue.read {
            try String.fetchOne($0, sql: "SELECT presented_at FROM mentor_items WHERE id = ?", arguments: [second.uuidString])
        }
        XCTAssertNil(presented)
        store.acknowledgeResponse(itemID: second)
        try await waitUntil { store.state.acknowledgedResponseItemID == second }
        let id = try XCTUnwrap(store.state.session?.id)
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.filter { $0.kind == .user }.count, 2)
        XCTAssertEqual(items.filter { $0.kind == .assistant }.count, 2)
    }

    func testReceiptFailurePreservesResponseAndCanRetryLocally() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "需要保留的回应")
        try await waitUntil { store.state.phase == .showingResponse }
        let item = try XCTUnwrap(store.state.responseItemID)
        let response = store.state.response
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER reject_receipt BEFORE UPDATE OF presented_at ON mentor_items BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.acknowledgeResponse(itemID: item)
        try await waitUntil { store.state.presentationError != nil }
        XCTAssertEqual(store.state.response, response)
        XCTAssertEqual(store.state.phase, .showingResponse)
        XCTAssertNil(store.state.acknowledgedResponseItemID)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_receipt") }
        store.acknowledgeResponse(itemID: item)
        try await waitUntil { store.state.acknowledgedResponseItemID == item }
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(count, 1)
        XCTAssertNil(store.state.presentationError)
    }

    func testResponseSaveRetryDoesNotRepeatModelOrUserInput() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER reject_response BEFORE INSERT ON mentor_items WHEN NEW.kind = 'assistant' BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.submit(text: "只提交一次")
        try await waitUntil { store.state.canRetryResponseSave }
        XCTAssertEqual(transport.calls, 1)
        store.retryLastRequest()
        XCTAssertTrue(store.state.canRetryResponseSave)
        XCTAssertEqual(transport.calls, 1)
        let retainedID = store.state.session?.id
        store.start(entry: "discuss")
        store.continueSession(id: UUID())
        XCTAssertFalse(store.state.isTransitioningSession)
        XCTAssertEqual(store.state.session?.id, retainedID)
        XCTAssertTrue(store.state.canRetryResponseSave)
        store.updateInputText("回应保存失败后继续编辑的草稿")
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_exit_draft BEFORE UPDATE OF draft_text ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.finish()
        try await waitUntil { !store.state.isTransitioningSession }
        XCTAssertNotNil(store.state.draftSaveError)
        XCTAssertTrue(store.state.canRetryResponseSave)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_exit_draft") }
        let flushed = await store.flushDraft()
        XCTAssertTrue(flushed)
        store.retryResponseSave()
        try await waitUntil { store.state.canRetryResponseSave }
        XCTAssertEqual(transport.calls, 1)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_response") }
        store.retryResponseSave()
        store.retryResponseSave()
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertFalse(store.state.canRetryResponseSave)
        XCTAssertEqual(transport.calls, 1)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .user }.count, 1)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .assistant }.count, 1)
    }

    func testTransportAndProtocolFailuresPersistTerminalRequests() async throws {
        let cases: [(Result<Data, Error>, String)] = [
            (.failure(URLError(.notConnectedToInternet)), "failed"),
            (.success(Data("invalid JSON".utf8)), "failed"),
            (.failure(MentorRequestExecutionError.timedOut), "timed_out"),
            (.failure(CancellationError()), "cancelled")
        ]
        for (result, expected) in cases {
            let db = try AppDatabase(dbQueue: DatabaseQueue())
            let transport = FailingMentorTransport(result: result)
            let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport)
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing }
            store.submit(text: "失败也保留原话")
            try await waitUntil { if case .failed = store.state.phase { return true }; return false }
            let status = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests") }
            XCTAssertEqual(status, expected)
            XCTAssertEqual(transport.calls, 1)
            XCTAssertFalse(store.state.canRetryResponseSave)
            XCTAssertFalse(store.state.canRetryRequestFinalization)
        }
    }

    func testRequestFinalizationFailureRetriesOnlyDatabaseWrite() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = FailingMentorTransport(result: .failure(URLError(.notConnectedToInternet)))
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_request_end BEFORE UPDATE OF state ON mentor_requests WHEN NEW.state IN ('failed', 'timed_out', 'cancelled') BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.submit(text: "请求失败的原话")
        try await waitUntil { store.state.canRetryRequestFinalization }
        XCTAssertNotNil(store.state.requestFinalizationError)
        let failedPhase = store.state.phase
        store.retryRequestFinalization()
        try await waitUntil { store.state.canRetryRequestFinalization }
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_request_end") }
        store.retryRequestFinalization()
        try await waitUntil { store.state.requestFinalizationError == nil }
        XCTAssertEqual(store.state.phase, failedPhase)
        XCTAssertEqual(transport.calls, 1)
        let statuses = try await db.dbQueue.read { try String.fetchAll($0, sql: "SELECT state FROM mentor_requests") }
        XCTAssertEqual(statuses, ["failed"])
    }

    func testExplainButtonDoesNotResubmitDraftAndRejectsMaterialQuestion() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = TeachingIntentTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "还没有提交的原话")
        try await waitUntil { store.state.phase == .editing }
        store.submit(intent: "explain")
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }
        XCTAssertEqual(store.state.inputText, "还没有提交的原话")
        let request = try XCTUnwrap(transport.request)
        let payload = try JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
        XCTAssertFalse(payload.allowsMaterialQuestion)
        XCTAssertEqual(payload.intent, "explain")
        XCTAssertFalse(payload.sources.contains { $0.role == .user })
        let sessionID = try XCTUnwrap(store.state.session?.id)
        let items = try await repo.items(sessionID: sessionID)
        XCTAssertTrue(items.isEmpty, "Intent is not user expression; rejected response must not persist")
        XCTAssertNil(store.state.response)
    }

    func testFinishIntentEndsLocallyWithoutTransport() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "下次再说")
        try await waitUntil { store.state.phase == .editing }
        store.submit(intent: "finish")
        try await waitUntil { store.state.phase == .ended }
        XCTAssertEqual(transport.calls, 0)
        let saved = try await repo.session(id: try XCTUnwrap(store.state.session?.id))
        XCTAssertEqual(saved?.draftText, "下次再说")
        XCTAssertEqual(saved?.lifecycle, .ended)
    }

    func testLocalLessonSwitchPreservesDraftAndExhaustsWithoutRequests() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport, catalog: try catalog())
        store.start(entry: "discuss", initialText: "还想继续说的事")
        try await waitUntil { store.state.phase == .editing }
        var seen = Set<String>()
        for _ in 0..<24 {
            store.submit(intent: "another_lesson")
            store.submit(intent: "another_lesson") // ignored while selecting
            try await waitUntil { store.state.phase == .reading }
            let lesson = try XCTUnwrap(store.state.lesson)
            XCTAssertTrue(seen.insert(lesson.lesson.id).inserted)
            XCTAssertEqual(store.state.inputText, "还想继续说的事")
            store.acknowledgeLesson()
        }
        store.submit(intent: "another_lesson")
        try await waitUntil { store.state.phase == .lessonExhausted }
        XCTAssertNil(store.state.lesson)
        XCTAssertEqual(seen.count, 24)
        XCTAssertEqual(store.state.timeline.count, 24)
        XCTAssertEqual(transport.calls, 0)
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(count, 0)
        store.finish()
        try await waitUntil { store.state.phase == .ended }
    }

    func testLessonSwitchFailurePreservesCurrentReading() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport, catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let first = store.state.lesson
        // Without an actual presentation receipt the next selection must fail.
        store.selectAnotherLesson()
        try await waitUntil { store.state.lessonError != nil }
        XCTAssertEqual(store.state.phase, .reading)
        XCTAssertEqual(store.state.lesson, first)
        XCTAssertEqual(transport.calls, 0)
    }

    func testSameDayListeningRestoresEndedSnapshotWithoutCatalogOrNetwork() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let time = Date(timeIntervalSince1970: 1_789_430_400)
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .draft,
            draftText: "保存的草稿", draftRevision: 1, activityAt: time))
        let selected = try await repo.selectNextLesson(sessionID: id, itemID: UUID(), expectedEpoch: 0,
            catalog: try catalog(), at: time, timeZone: zone)
        let lesson = try XCTUnwrap(selected)
        try await repo.acknowledgePresentation(sessionID: id, itemID: lesson.id, at: time, timeZone: zone)
        try await repo.saveReadingPosition(sessionID: id, itemID: lesson.id, revision: 1, section: .boundary)
        try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "保存的草稿")
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport, timeZone: zone, now: { time })
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .ended }
        XCTAssertEqual(store.state.session?.id, id)
        let persisted = try await repo.savedLesson(sessionID: id, itemID: lesson.id)
        XCTAssertEqual(store.state.lesson, persisted)
        XCTAssertEqual(store.state.lesson?.readingSection, .boundary)
        XCTAssertEqual(store.state.inputText, "保存的草稿")
        XCTAssertEqual(transport.calls, 0)
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_sessions") }
        XCTAssertEqual(count, 1)
        let stored = try await repo.session(id: id)
        XCTAssertEqual(stored?.lifecycle, .ended)
    }

    func testRapidUnderstandingEditsConfirmLatestVersion() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "第一句话")
        store.saveUnderstanding(text: "修正后的体会")
        store.confirmUnderstanding()
        try await waitUntil { store.state.understanding?.state == .confirmed }
        XCTAssertEqual(store.state.understanding?.text, "修正后的体会")
        XCTAssertEqual(store.state.understanding?.editRevision, 2)
        XCTAssertEqual(transport.calls, 0)
    }

    func testFailedUnderstandingEditCannotConfirmOldText() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "旧文本")
        try await waitUntil { store.state.understanding?.text == "旧文本" }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_note_edit BEFORE UPDATE OF text ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.saveUnderstanding(text: "未保存的新文本")
        store.confirmUnderstanding()
        try await waitUntil { store.state.understandingError != nil }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(store.state.understanding?.state, .draft)
        XCTAssertEqual(store.state.understandingInputText, "未保存的新文本")
        XCTAssertEqual(store.state.phase, .editing)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_note_edit") }
        store.saveUnderstanding(text: store.state.understandingInputText)
        store.confirmUnderstanding()
        try await waitUntil { store.state.understanding?.state == .confirmed }
        XCTAssertEqual(store.state.understanding?.text, "未保存的新文本")
    }

    func testNotRelevantFeedbackPrecedesImmediateLessonSelection() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport, catalog: try catalog())
        store.start(entry: "listen", initialText: "保留草稿")
        try await waitUntil { store.state.phase == .reading }
        let first = try XCTUnwrap(store.state.lesson)
        store.acknowledgeLesson()
        store.recordLessonFeedback(.notRelevant)
        store.recordLessonFeedback(.notRelevant)
        store.selectAnotherLesson()
        try await waitUntil { store.state.phase == .reading && store.state.lesson?.id != first.id }
        XCTAssertNotEqual(store.state.lesson?.lesson.theme, first.lesson.theme)
        XCTAssertEqual(store.state.inputText, "保留草稿")
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback") }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(transport.calls, 0)
        let previousSession = store.state.session?.id
        store.start(entry: "listen", initialText: "另一个会话")
        try await waitUntil { store.state.phase == .reading && store.state.session?.id != previousSession }
        XCTAssertEqual(store.state.lesson?.lesson.theme, first.lesson.theme)
    }

    func testKnownFeedbackWinsOverImmediateSameDayResume() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db),
            transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let first = try XCTUnwrap(store.state.lesson)
        store.acknowledgeLesson()
        store.recordLessonFeedback(.alreadyKnown)
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading && store.state.lesson?.id != first.id }
        XCTAssertNotEqual(store.state.lesson?.lesson.id, first.lesson.id)
        let known = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback WHERE kind = 'already_known' AND revoked_at IS NULL") }
        XCTAssertEqual(known, 1)
    }

    func testResetKnownFeedbackPreservesRecentPresentationExclusion() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let time = Date(timeIntervalSince1970: 1_789_430_400)
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(),
            catalog: try catalog(), timeZone: zone, now: { time })
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let first = try XCTUnwrap(store.state.lesson)
        store.acknowledgeLesson()
        store.recordLessonFeedback(.alreadyKnown)
        try await waitUntil { !store.state.isSavingLessonFeedback }
        XCTAssertNil(store.state.lessonFeedbackError)
        store.resetKnownLessonFeedback()
        try await waitUntil { !store.state.isSavingLessonFeedback }
        XCTAssertNil(store.state.lessonFeedbackError)
        let active = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback WHERE revoked_at IS NULL") }
        XCTAssertEqual(active, 0)
        // A new session must still exclude the recently presented logical lesson.
        store.start(entry: "listen", initialText: "新交流")
        try await waitUntil { store.state.phase == .reading && store.state.lesson?.id != first.id }
        XCTAssertNotEqual(store.state.lesson?.lesson.id, first.lesson.id)
        let original = try await repo.savedLesson(sessionID: first.sessionID, itemID: first.id)
        XCTAssertNotNil(original)
    }

    func testFeedbackWriteFailureKeepsLessonAndCanRetryLocally() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport, catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let first = store.state.lesson
        store.acknowledgeLesson()
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_feedback BEFORE INSERT ON mentor_feedback BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.recordLessonFeedback(.alreadyKnown)
        store.selectAnotherLesson()
        try await waitUntil { !store.state.isSavingLessonFeedback && store.state.phase == .reading }
        XCTAssertNotNil(store.state.lessonFeedbackError)
        XCTAssertEqual(store.state.lesson, first)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_feedback") }
        store.recordLessonFeedback(.alreadyKnown)
        store.selectAnotherLesson()
        try await waitUntil { store.state.phase == .reading && store.state.lesson?.id != first?.id }
        XCTAssertNil(store.state.lessonFeedbackError)
        XCTAssertEqual(transport.calls, 0)
    }

    func testContinueRestoresSavedLessonAndUnderstandingVersionsWithoutCatalog() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID()
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "listen", lifecycle: .draft,
            draftText: "原交流草稿", draftRevision: 1, activityAt: .now))
        let selected = try await repo.selectNextLesson(sessionID: sessionID, itemID: UUID(), expectedEpoch: 0,
            catalog: try catalog(), at: .now, timeZone: .current)
        let lesson = try XCTUnwrap(selected)
        try await repo.acknowledgePresentation(sessionID: sessionID, itemID: lesson.id, at: .now, timeZone: .current)
        try await repo.saveReadingPosition(sessionID: sessionID, itemID: lesson.id, revision: 1, section: .example)
        let original = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: UUID(), previousRevisionID: nil)
        _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: original.id, editRevision: 1, text: "原确认理解")
        let confirmed = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: original.id, expectedEditRevision: 1)
        let revision = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: UUID(), previousRevisionID: confirmed.id)
        _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: revision.id, editRevision: 1, text: "尚未确认的修订")
        try await repo.suspendSession(id: sessionID, ending: true, draftRevision: 1, draftText: "原交流草稿")
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.continueSession(id: sessionID)
        try await waitUntil { store.state.phase == .editing }
        XCTAssertEqual(store.state.session?.lifecycle, .active)
        XCTAssertEqual(store.state.inputText, "原交流草稿")
        XCTAssertEqual(store.state.lesson?.readingSection, .example)
        let persistedLesson = try await repo.savedLesson(sessionID: sessionID, itemID: lesson.id)
        XCTAssertEqual(store.state.lesson, persistedLesson)
        let versions = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(store.state.understandings, versions)
        XCTAssertEqual(store.state.understanding?.id, revision.id)
        XCTAssertEqual(store.state.understandingInputText, "尚未确认的修订")
        store.saveUnderstanding(text: "恢复后继续修订")
        store.confirmUnderstanding()
        try await waitUntil { store.state.understanding?.state == .confirmed }
        XCTAssertEqual(store.state.understandings.first(where: { $0.id == confirmed.id }), confirmed)
        XCTAssertEqual(store.state.understandings.first(where: { $0.id == revision.id })?.text, "恢复后继续修订")
        XCTAssertEqual(transport.calls, 0)
    }

    func testSameDayRestorePreservesMultipleDraftsWithoutArbitrarySelection() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .draft,
            draftText: "", draftRevision: 0, activityAt: .now))
        let selected = try await repo.selectNextLesson(sessionID: id, itemID: UUID(), expectedEpoch: 0,
            catalog: try catalog(), at: .now, timeZone: .current)
        let lesson = try XCTUnwrap(selected)
        try await repo.acknowledgePresentation(sessionID: id, itemID: lesson.id, at: .now, timeZone: .current)
        for text in ["第一个独立想法", "第二个独立想法"] {
            let draft = try await repo.beginUserUnderstanding(sessionID: id, draftID: UUID(), previousRevisionID: nil)
            _ = try await repo.saveUnderstandingDraft(sessionID: id, draftID: draft.id, editRevision: 1, text: text)
        }
        try await repo.suspendSession(id: id, ending: true, draftRevision: 0, draftText: "")
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .ended }
        XCTAssertEqual(Set(store.state.understandings.map(\.text)), ["第一个独立想法", "第二个独立想法"])
        XCTAssertNil(store.state.understanding)
        XCTAssertEqual(store.state.understandingInputText, "")
        XCTAssertEqual(store.state.session?.lifecycle, .ended)
    }

    func testContinueReplaysSavedResponseAndRequiresActualPresentationBeforeNextTurn() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let original = MentorFeatureStore(repository: repo, transport: transport)
        original.start(entry: "discuss")
        try await waitUntil { original.state.phase == .editing }
        original.submit(text: "今天完成了改动")
        try await waitUntil { original.state.phase == .showingResponse }
        let id = try XCTUnwrap(original.state.session?.id)
        let responseID = try XCTUnwrap(original.state.responseItemID)
        original.finish()
        try await waitUntil { original.state.phase == .ended }
        let restored = MentorFeatureStore(repository: repo, transport: transport)
        restored.continueSession(id: id)
        try await waitUntil { restored.state.phase == .showingResponse }
        XCTAssertEqual(restored.state.response, original.state.response)
        XCTAssertEqual(restored.state.responseItemID, responseID)
        XCTAssertNil(restored.state.acknowledgedResponseItemID)
        restored.submit(text: "未呈现时不应提交")
        XCTAssertEqual(transport.calls, 1)
        restored.acknowledgeResponse(itemID: responseID)
        try await waitUntil { restored.state.acknowledgedResponseItemID == responseID }
        restored.submit(text: "继续这个问题")
        try await waitUntil { restored.state.phase == .showingResponse && restored.state.responseItemID != responseID }
        XCTAssertEqual(transport.calls, 2)
        XCTAssertEqual(restored.state.timeline.filter { $0.kind == .assistant }.count, 2)
    }

    func testActiveListeningResumeKeepsResponsePresentationGate() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let original = MentorFeatureStore(repository: repo, transport: transport, catalog: try catalog())
        original.start(entry: "listen")
        try await waitUntil { original.state.phase == .reading }
        original.acknowledgeLesson()
        // Wait on persisted receipt before beginning this test's model turn.
        for _ in 0..<200 {
            if try await repo.listeningResume(at: .now, timeZone: .current) != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        original.submit(text: "这个角度让我想到今天的工作")
        try await waitUntil { original.state.phase == .showingResponse }
        let restored = MentorFeatureStore(repository: repo, transport: transport)
        restored.start(entry: "listen")
        try await waitUntil { restored.state.phase == .showingResponse }
        XCTAssertEqual(restored.state.responseItemID, original.state.responseItemID)
        restored.submit(text: "不能绕过呈现确认")
        XCTAssertEqual(transport.calls, 1)
        XCTAssertNil(restored.state.acknowledgedResponseItemID)
    }

    func testConfirmedUnderstandingRevisionStartsWithOriginalTextAndResumesExistingDraft() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "原本认可的理解")
        store.confirmUnderstanding()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let confirmed = try XCTUnwrap(store.state.understanding)
        XCTAssertEqual(confirmed.state, .confirmed)
        store.saveUnderstanding(text: "不能直接改写确认版本")
        XCTAssertEqual(store.state.understandingInputText, "原本认可的理解")
        store.beginUnderstanding(previousRevisionID: confirmed.id)
        XCTAssertEqual(store.state.understandingInputText, "原本认可的理解")
        store.saveUnderstanding(text: "创建完成前输入的修订")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let revision = try XCTUnwrap(store.state.understanding)
        XCTAssertEqual(revision.text, "创建完成前输入的修订")
        XCTAssertEqual(store.state.understandingInputText, revision.text)
        store.beginUnderstanding(previousRevisionID: confirmed.id)
        XCTAssertEqual(store.state.understanding?.id, revision.id)
        XCTAssertEqual(store.state.understandingInputText, revision.text)
        let versions = try await repo.understandings(sessionID: confirmed.sessionID)
        XCTAssertEqual(versions.count, 2)
        XCTAssertEqual(versions.first(where: { $0.id == confirmed.id }), confirmed)
        store.confirmUnderstanding()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        store.beginUnderstanding(previousRevisionID: confirmed.id)
        XCTAssertEqual(store.state.understanding?.id, revision.id)
        XCTAssertNil(store.state.understandingError)
    }

    func testDraftSelectionWaitsForWritesAndPreservesFailedInput() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "第一份草稿")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let first = try XCTUnwrap(store.state.understanding)
        store.beginUnderstanding()
        store.saveUnderstanding(text: "第二份草稿")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let second = try XCTUnwrap(store.state.understanding)
        store.selectUnderstandingDraft(id: first.id)
        XCTAssertEqual(store.state.understandingInputText, first.text)
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_selected_edit BEFORE UPDATE OF text ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.saveUnderstanding(text: "不能丢失的输入")
        store.selectUnderstandingDraft(id: second.id)
        XCTAssertEqual(store.state.understanding?.id, first.id)
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertNotNil(store.state.understandingError)
        store.selectUnderstandingDraft(id: second.id)
        XCTAssertEqual(store.state.understandingInputText, "不能丢失的输入")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_selected_edit") }
        store.retryUnderstandingSave()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertNil(store.state.understandingError)
        store.selectUnderstandingDraft(id: second.id)
        XCTAssertEqual(store.state.understandingInputText, second.text)
        store.selectUnderstandingDraft(id: first.id)
        XCTAssertEqual(store.state.understandingInputText, "不能丢失的输入")
        store.selectUnderstandingDraft(id: UUID())
        XCTAssertEqual(store.state.understanding?.id, first.id)
    }

    func testUnderstandingCreationFailureRetriesWithTypedTextAndNoDuplicateDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_note_creation BEFORE INSERT ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "创建失败时已经输入的想法")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertNotNil(store.state.understandingError)
        XCTAssertNil(store.state.understanding)
        store.saveUnderstanding(text: "失败后继续修正的想法")
        XCTAssertEqual(store.state.understandingInputText, "失败后继续修正的想法")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_note_creation") }
        store.retryUnderstandingSave()
        store.retryUnderstandingSave()
        store.confirmUnderstanding()
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertEqual(store.state.understanding?.state, .confirmed)
        XCTAssertEqual(store.state.understanding?.text, "失败后继续修正的想法")
        let notes = try await repo.understandings(sessionID: XCTUnwrap(store.state.session?.id))
        XCTAssertEqual(notes.count, 1)
    }

    func testRapidReadingPositionsPersistLatestSectionBeforeContinuation() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport, catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let lesson = try XCTUnwrap(store.state.lesson)
        try await repo.acknowledgePresentation(sessionID: lesson.sessionID, itemID: lesson.id, at: .now, timeZone: .current)
        let before = try await repo.session(id: lesson.sessionID)
        store.saveReadingPosition(itemID: lesson.id, section: .claim)
        store.saveReadingPosition(itemID: lesson.id, section: .example)
        store.saveReadingPosition(itemID: lesson.id, section: .boundary)
        store.saveReadingPosition(itemID: lesson.id, section: .boundary)
        XCTAssertEqual(store.state.lesson?.readingSection, .boundary)
        store.continueSession(id: lesson.sessionID)
        try await waitUntil { store.state.phase == .editing }
        XCTAssertEqual(store.state.pendingReadingPositionSaves, 0)
        let saved = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertEqual(saved?.readingSection, .boundary)
        XCTAssertEqual(saved?.readingRevision, 3)
        XCTAssertEqual(store.state.lesson?.readingSection, .boundary)
        let after = try await repo.session(id: lesson.sessionID)
        XCTAssertEqual(after?.semanticRevision, before?.semanticRevision)
        XCTAssertEqual(after?.requestEpoch, before?.requestEpoch)
        XCTAssertEqual(transport.calls, 0)
    }

    func testOldLessonScrollCannotMoveReplacementAndDoesNotConfirmPresentation() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let old = try XCTUnwrap(store.state.lesson)
        store.saveReadingPosition(itemID: old.id, section: .example)
        try await waitUntil { store.state.pendingReadingPositionSaves == 0 }
        let unpresented = try await repo.listeningResume(at: .now, timeZone: .current)
        XCTAssertNil(unpresented)
        store.acknowledgeLesson()
        store.saveReadingPosition(itemID: old.id, section: .boundary)
        store.selectAnotherLesson()
        try await waitUntil { store.state.phase == .reading && store.state.lesson?.id != old.id }
        let replacement = try XCTUnwrap(store.state.lesson)
        store.saveReadingPosition(itemID: old.id, section: .claim)
        store.saveReadingPosition(itemID: replacement.id, section: .observation)
        XCTAssertEqual(store.state.lesson, replacement)
        let savedOld = try await repo.savedLesson(sessionID: old.sessionID, itemID: old.id)
        XCTAssertEqual(savedOld?.readingSection, .boundary)
        XCTAssertEqual(store.state.pendingReadingPositionSaves, 0)
    }

    func testReadingPositionFailureKeepsVisibleSectionAndRetriesLocally() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport, catalog: try catalog())
        store.start(entry: "listen", initialText: "保留交流草稿")
        try await waitUntil { store.state.phase == .reading }
        let lesson = try XCTUnwrap(store.state.lesson)
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_position BEFORE UPDATE OF reading_section ON mentor_lesson_snapshots BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.saveReadingPosition(itemID: lesson.id, section: .boundary)
        try await waitUntil { store.state.pendingReadingPositionSaves == 0 }
        XCTAssertNotNil(store.state.readingPositionError)
        XCTAssertEqual(store.state.lesson?.readingSection, .boundary)
        XCTAssertEqual(store.state.inputText, "保留交流草稿")
        XCTAssertEqual(store.state.phase, .reading)
        let failed = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertEqual(failed?.readingSection, .title)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_position") }
        store.retryReadingPositionSave()
        store.retryReadingPositionSave()
        try await waitUntil { store.state.pendingReadingPositionSaves == 0 }
        let saved = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertEqual(saved?.readingSection, .boundary)
        XCTAssertEqual(saved?.readingRevision, 1)
        XCTAssertNil(store.state.readingPositionError)
        XCTAssertEqual(transport.calls, 0)
    }

    func testMentorRequestUsesVersionedPromptAndFreezesExactSentContext() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "今天的具体片段")
        try await waitUntil { store.state.phase == .showingResponse }
        let sent = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(sent.prompt.id, .mentorRespond)
        XCTAssertEqual(sent.prompt.version, "1.0.0")
        XCTAssertEqual(sent.decisionRoute, .coaching)
        XCTAssertNotEqual(sent.prompt.userText, sent.inputSummary)
        let token = try XCTUnwrap(sent.mentorAuditToken)
        let snapshot = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT context_snapshot_json FROM mentor_requests WHERE id = ?", arguments: [token.requestID.uuidString]) }
        XCTAssertEqual(snapshot, sent.inputSummary)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8))
        XCTAssertEqual(context.sources.first(where: { $0.role == .user })?.content, "今天的具体片段")
        XCTAssertEqual(context.sessionID, token.sessionID)
    }

    func testContextSnapshotWriteFailurePreventsModelCall() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_context BEFORE UPDATE OF context_snapshot_json ON mentor_requests BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.submit(text: "不能漏存的原话")
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }
        XCTAssertEqual(transport.calls, 0)
        let terminal = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests") }
        XCTAssertEqual(terminal, "failed")
        XCTAssertEqual(store.state.inputText, "不能漏存的原话")
    }

    func testSharedGatewayUsesInjectedPromptAndPersistsOwnedAuditBeforeResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let runs = SQLitePromptRunRepository(database: db)
        let base = MentorStoreFixtureTransport()
        let center = CentralLLMDecisionCenter(base: PromptTracingLLMClient(base: base, repository: runs,
            modelProvider: "fixture", modelName: "shared-model", mentorAudit: repo))
        let store = MentorFeatureStore(repository: repo, transport: center, promptProvider: MentorTestPromptProvider())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "经过共享模型入口的原话")
        try await waitUntil { store.state.phase == .showingResponse }
        let request = try XCTUnwrap(base.lastRequest)
        XCTAssertEqual(request.prompt.version, "test-injected.2")
        let savedRuns = try await runs.recentPromptRuns(limit: 10)
        let run = try XCTUnwrap(savedRuns.first)
        XCTAssertEqual(savedRuns.count, 1)
        XCTAssertEqual(run.id, request.traceID)
        XCTAssertEqual(run.promptVersion, "test-injected.2")
        XCTAssertEqual(run.requestSummary, request.inputSummary)
        XCTAssertEqual(run.modelName, "shared-model")
        let owner = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT mentor_request_id FROM prompt_runs WHERE id = ?", arguments: [run.id.uuidString]) }
        XCTAssertEqual(owner, request.mentorAuditToken?.requestID.uuidString)
        // The request is now terminal. Replaying it must fail before a second model call.
        do { _ = try await center.complete(request); XCTFail("Terminal request reached the model") } catch {}
        XCTAssertEqual(base.calls, 1)
    }

    func testSharedGatewayMissingAuditRejectsBeforeNetwork() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let runs = SQLitePromptRunRepository(database: db)
        let base = MentorStoreFixtureTransport()
        let center = CentralLLMDecisionCenter(base: PromptTracingLLMClient(base: base, repository: runs,
            modelProvider: "fixture", modelName: "missing-audit"))
        let store = MentorFeatureStore(repository: repo, transport: center)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "审计缺失时不能发出")
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }
        XCTAssertEqual(base.calls, 0)
        XCTAssertNil(store.state.response)
        let saved = try await runs.recentPromptRuns(limit: 10)
        XCTAssertTrue(saved.isEmpty)
    }

    func testSharedGatewayAuditWriteFailureDoesNotPublishUnauditedResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let runs = SQLitePromptRunRepository(database: db)
        let base = MentorStoreFixtureTransport()
        let center = CentralLLMDecisionCenter(base: PromptTracingLLMClient(base: base, repository: runs,
            modelProvider: "fixture", modelName: "audit-failure", mentorAudit: repo))
        let store = MentorFeatureStore(repository: repo, transport: center)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_mentor_trace BEFORE INSERT ON prompt_runs BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.submit(text: "原话仍需保留")
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }
        XCTAssertEqual(base.calls, 1)
        XCTAssertNil(store.state.response)
        let items = try await repo.items(sessionID: XCTUnwrap(store.state.session?.id))
        XCTAssertEqual(items.filter { $0.kind == .user }.count, 1)
        XCTAssertEqual(items.filter { $0.kind == .assistant }.count, 0)
    }

    func testAppAssemblySharesDatabaseAndRetainsMentorAcrossConfigurationRefresh() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let app = AppStore.persistentStore(database: db,
            apiKeyStore: KeychainAPIKeyStore(service: "mingsi.mentor.tests.\(UUID().uuidString)"), trainingCasesVNextEnabled: false)
        let prepared = await app.prepareMentorFeature(catalog: try catalog())
        let feature = try XCTUnwrap(prepared)
        let repeated = await app.prepareMentorFeature()
        XCTAssertTrue(repeated === feature)
        feature.start(entry: "listen")
        try await waitUntil { feature.state.phase == .reading }
        let lesson = try XCTUnwrap(feature.state.lesson)
        let repo = SQLiteMentorRepository(database: db)
        let stored = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertEqual(stored, lesson)
        feature.acknowledgeLesson()
        feature.selectAnotherLesson()
        try await waitUntil { feature.state.phase == .reading && feature.state.lesson?.id != lesson.id }
        feature.acknowledgeLesson()
        // Presentation is setup for a new discussion; use the repository receipt to await its completion.
        let current = try XCTUnwrap(feature.state.lesson)
        try await repo.acknowledgePresentation(sessionID: current.sessionID, itemID: current.id, at: .now, timeZone: .current)
        feature.submit(text: "未配置模型也要保存原话")
        try await waitUntil { if case .failed = feature.state.phase { return true }; return false }
        let runs = try await SQLitePromptRunRepository(database: db).recentPromptRuns(limit: 5)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.modelName, "missing-api-key")
        XCTAssertNotNil(runs.first?.error)
        app.refreshAPIKeyStatus()
        XCTAssertTrue(app.mentorFeatureStore === feature)
        XCTAssertEqual(feature.state.inputText, "未配置模型也要保存原话")
        XCTAssertEqual(feature.state.session?.id, lesson.sessionID)
    }

    func testAppAssemblyDisablesMentorOnLegacyDatabaseAndUnconfiguredPreview() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue(), includesVNextMigrations: false)
        let app = AppStore.persistentStore(database: db,
            apiKeyStore: KeychainAPIKeyStore(service: "mingsi.mentor.legacy.\(UUID().uuidString)"), trainingCasesVNextEnabled: false)
        let legacy = await app.prepareMentorFeature()
        let preview = await AppStore(refreshesAIServiceFromKeychain: false).prepareMentorFeature()
        XCTAssertNil(legacy)
        XCTAssertNil(preview)
    }

    func testDependencyRefreshOnlyChangesFutureTurns() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let old = HeldMentorTransport()
        let new = MentorStoreFixtureTransport()
        let oldProvider = MentorTestPromptProvider()
        oldProvider.version = "1.0.0"
        let store = MentorFeatureStore(repository: repo, transport: old, promptProvider: oldProvider)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "提交时捕获配置")
        oldProvider.version = "changed-after-submit"
        store.updateDependencies(transport: new, promptProvider: MentorTestPromptProvider())
        try await waitUntil { old.pending != nil }
        XCTAssertEqual(new.calls, 0)
        let originalRequest = try XCTUnwrap(old.request)
        XCTAssertEqual(originalRequest.prompt.version, "1.0.0")
        old.pending?.resume(returning: try await MentorStoreFixtureTransport().complete(originalRequest))
        old.pending = nil
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertFalse(old.wasCancelled)
        let itemID = try XCTUnwrap(store.state.responseItemID)
        store.acknowledgeResponse(itemID: itemID)
        try await waitUntil { store.state.acknowledgedResponseItemID == itemID }
        store.submit(text: "下一轮使用新配置")
        try await waitUntil { store.state.phase == .showingResponse && store.state.responseItemID != itemID }
        XCTAssertEqual(new.calls, 1)
        XCTAssertEqual(new.lastRequest?.prompt.version, "test-injected.2")
    }

    func testAppStartupRecoveryPreservesOriginalInputAndDoesNotRepeatForLiveWork() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let originalID = UUID()
        try await repo.createSession(MentorSession(id: originalID, initialEntry: "discuss", lifecycle: .active,
            draftText: "未提交的草稿", draftRevision: 1, activityAt: .now))
        let abandonedID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: originalID,
            text: "上次已经提交的原话", intent: "reply", contextSnapshotJSON: "{}"))
        let app = AppStore.persistentStore(database: db,
            apiKeyStore: KeychainAPIKeyStore(service: "mingsi.recovery.\(UUID().uuidString)"), trainingCasesVNextEnabled: false)
        async let first = app.prepareMentorFeature()
        async let second = app.prepareMentorFeature()
        let results = await (first, second)
        let feature = try XCTUnwrap(results.0)
        XCTAssertTrue(feature === results.1)
        XCTAssertFalse(app.isPreparingMentorFeature)
        XCTAssertNil(app.mentorPreparationError)
        let recovered = try await repo.session(id: originalID)
        XCTAssertEqual(recovered?.lifecycle, .paused)
        XCTAssertEqual(recovered?.requestEpoch, 1)
        XCTAssertEqual(recovered?.draftText, "未提交的草稿")
        let state = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [abandonedID.uuidString]) }
        XCTAssertEqual(state, "interrupted")
        let items = try await repo.items(sessionID: originalID)
        XCTAssertEqual(items.filter { $0.kind == .user }.count, 1)
        let runs = try await SQLitePromptRunRepository(database: db).recentPromptRuns(limit: 10)
        XCTAssertTrue(runs.isEmpty)
        let held = HeldMentorTransport()
        feature.updateDependencies(transport: held, promptProvider: LocalPromptProvider())
        feature.start(entry: "discuss")
        try await waitUntil { feature.state.phase == .editing }
        feature.submit(text: "当前进程的新请求")
        try await waitUntil { held.pending != nil }
        let again = await app.prepareMentorFeature()
        XCTAssertTrue(again === feature)
        let request = try XCTUnwrap(held.request)
        let currentID = try XCTUnwrap(request.mentorAuditToken?.requestID)
        let active = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [currentID.uuidString]) }
        XCTAssertEqual(active, "in_flight")
        XCTAssertFalse(held.wasCancelled)
        held.pending?.resume(returning: try await MentorStoreFixtureTransport().complete(request))
        held.pending = nil
        try await waitUntil { feature.state.phase == .showingResponse }
    }

    func testAppStartupRecoveryFailureKeepsFeatureUnavailableUntilRetrySucceeds() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "保留草稿", draftRevision: 1, activityAt: .now))
        _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
            text: "保留原话", intent: "reply", contextSnapshotJSON: "{}"))
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_recovery BEFORE UPDATE OF state ON mentor_requests WHEN NEW.state = 'interrupted' BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let app = AppStore.persistentStore(database: db,
            apiKeyStore: KeychainAPIKeyStore(service: "mingsi.recovery.failure.\(UUID().uuidString)"), trainingCasesVNextEnabled: false)
        let failed = await app.prepareMentorFeature()
        XCTAssertNil(failed)
        XCTAssertNil(app.mentorFeatureStore)
        XCTAssertNotNil(app.mentorPreparationError)
        XCTAssertFalse(app.isPreparingMentorFeature)
        let unchanged = try await repo.session(id: id)
        XCTAssertEqual(unchanged?.requestEpoch, 0)
        XCTAssertEqual(unchanged?.lifecycle, .active)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_recovery") }
        let retried = await app.prepareMentorFeature()
        XCTAssertNotNil(retried)
        XCTAssertNil(app.mentorPreparationError)
        let recovered = try await repo.session(id: id)
        XCTAssertEqual(recovered?.requestEpoch, 1)
        XCTAssertEqual(recovered?.draftText, "保留草稿")
    }

    func testExplicitNetworkRetryReusesOriginalItemAndKeepsNewDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let failed = FailingMentorTransport(result: .failure(URLError(.notConnectedToInternet)))
        let store = MentorFeatureStore(repository: repo, transport: failed)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "原来那轮的原话")
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }
        let first = try XCTUnwrap(failed.request)
        let original = try XCTUnwrap(store.state.retryableRequest)
        let id = try XCTUnwrap(store.state.session?.id)
        try await repo.saveDraft(sessionID: id, revision: 2, text: "还没提交的新草稿")
        store.continueSession(id: id)
        try await waitUntil { store.state.phase == .editing }
        let success = MentorStoreFixtureTransport()
        store.updateDependencies(transport: success, promptProvider: LocalPromptProvider())
        store.retryLastRequest()
        store.retryLastRequest()
        try await waitUntil { store.state.phase == .showingResponse }
        let second = try XCTUnwrap(success.lastRequest)
        XCTAssertNotEqual(first.traceID, second.traceID)
        XCTAssertEqual(success.calls, 1)
        XCTAssertEqual(store.state.inputText, "还没提交的新草稿")
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .user }.count, 1)
        let oldContext = try JSONDecoder().decode(MentorContextPayload.self, from: Data(first.inputSummary.utf8))
        let newContext = try JSONDecoder().decode(MentorContextPayload.self, from: Data(second.inputSummary.utf8))
        XCTAssertEqual(oldContext, newContext)
        let relation = try await db.dbQueue.read { try Row.fetchOne($0,
            sql: "SELECT retry_of, user_item_id FROM mentor_requests WHERE id = ?", arguments: [second.mentorAuditToken!.requestID.uuidString]) }
        XCTAssertEqual(relation?["retry_of"] as String?, original.id.uuidString)
        let users = try await db.dbQueue.read { try String.fetchAll($0, sql: "SELECT user_item_id FROM mentor_requests") }
        XCTAssertEqual(Set(users).count, 1)
        XCTAssertNil(store.state.retryableRequest)
    }

    func testInterruptedFrozenRequestRetriesWithNewEpochAndSameEvidence() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id,
            text: "崩溃前的原话", intent: "reply", contextSnapshotJSON: "{}"))
        let loaded = try await repo.session(id: id)
        let before = try XCTUnwrap(loaded)
        let items = try await repo.items(sessionID: id)
        let built = try MentorContextBuilder().build(session: before, items: items, intent: "reply")
        try await repo.prepareRequestContext(token: .init(sessionID: id, requestID: requestID,
            requestEpoch: 0, semanticRevision: 0), json: built.json)
        _ = try await repo.recoverInterruptedRequests()
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.continueSession(id: id)
        try await waitUntil { store.state.phase == .editing }
        XCTAssertEqual(store.state.retryableRequest?.id, requestID)
        store.retryLastRequest()
        try await waitUntil { store.state.phase == .showingResponse }
        let sent = try XCTUnwrap(transport.lastRequest)
        var expected = built.payload
        expected.requestEpoch = 1
        XCTAssertEqual(try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8)), expected)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .user }.count, 1)
        XCTAssertEqual(transport.calls, 1)
    }

    func testTypingDebouncesDraftWithoutSubmittingUserItems() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let id = try XCTUnwrap(store.state.session?.id)
        store.updateInputText("第一段")
        store.updateInputText("最后的输入")
        let before = try await repo.session(id: id)
        XCTAssertEqual(before?.draftText, "")
        XCTAssertTrue(store.state.hasUnsavedDraft)
        try await waitUntil { !store.state.hasUnsavedDraft }
        let saved = try await repo.session(id: id)
        XCTAssertEqual(saved?.draftText, "最后的输入")
        XCTAssertEqual(saved?.draftRevision, 2)
        XCTAssertFalse(store.state.isSavingDraft)
        XCTAssertEqual(transport.calls, 0)
        let items = try await repo.items(sessionID: id)
        XCTAssertTrue(items.isEmpty)
    }

    func testSubmitFlushPreservesNewTypingWhileModelUsesSubmittedText() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.updateInputText("本轮提交的原话")
        store.submit()
        store.updateInputText("等待期间的新草稿")
        try await waitUntil { transport.pending != nil }
        let request = try XCTUnwrap(transport.request)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
        XCTAssertEqual(context.sources.filter { $0.role == .user }.map(\.content), ["本轮提交的原话"])
        let saved = try await repo.session(id: XCTUnwrap(store.state.session?.id))
        XCTAssertEqual(saved?.draftText, "等待期间的新草稿")
        transport.pending?.resume(returning: try await MentorStoreFixtureTransport().complete(request))
        transport.pending = nil
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(store.state.inputText, "等待期间的新草稿")
    }

    func testDraftFailureBlocksSwitchAndRetrySavesBeforeLeaving() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let old = try XCTUnwrap(store.state.session?.id)
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_draft BEFORE UPDATE OF draft_text ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.updateInputText("不能丢失的草稿")
        store.start(entry: "discuss", initialText: "下一件事")
        try await waitUntil { !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.session?.id, old)
        XCTAssertEqual(store.state.inputText, "不能丢失的草稿")
        XCTAssertTrue(store.state.hasUnsavedDraft)
        XCTAssertNotNil(store.state.draftSaveError)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_draft") }
        store.start(entry: "discuss", initialText: "下一件事")
        try await waitUntil { store.state.session?.id != old && !store.state.isTransitioningSession }
        let saved = try await repo.session(id: old)
        XCTAssertEqual(saved?.draftText, "不能丢失的草稿")
        XCTAssertEqual(store.state.inputText, "下一件事")
    }

    func testPauseAndFinishFlushDraftBeforeLifecycleChange() async throws {
        for ending in [false, true] {
            let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
            let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing }
            let id = try XCTUnwrap(store.state.session?.id)
            store.updateInputText("离开前最后一句")
            if ending { store.finish() } else { store.pause() }
            store.updateInputText("离开过程不能接受的编辑事件")
            try await waitUntil { store.state.phase == (ending ? .ended : .paused) }
            let saved = try await repo.session(id: id)
            XCTAssertEqual(saved?.draftText, "离开前最后一句")
            XCTAssertEqual(saved?.lifecycle, ending ? .ended : .paused)
            XCTAssertFalse(store.state.hasUnsavedDraft)
            XCTAssertFalse(store.state.isTransitioningSession)
        }
    }

    func testAppBackgroundFlushesMentorDraftWithoutModelRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let app = AppStore.persistentStore(database: db,
            apiKeyStore: KeychainAPIKeyStore(service: "mingsi.draft.background.\(UUID().uuidString)"), trainingCasesVNextEnabled: false)
        let prepared = await app.prepareMentorFeature()
        let feature = try XCTUnwrap(prepared)
        feature.start(entry: "discuss")
        try await waitUntil { feature.state.phase == .editing }
        feature.updateInputText("进入后台之前的文字")
        app.handleScenePhase(.inactive)
        app.handleScenePhase(.background)
        try await waitUntil { !feature.state.hasUnsavedDraft }
        let saved = try await SQLiteMentorRepository(database: db).session(id: XCTUnwrap(feature.state.session?.id))
        XCTAssertEqual(saved?.draftText, "进入后台之前的文字")
        let runs = try await SQLitePromptRunRepository(database: db).recentPromptRuns(limit: 10)
        XCTAssertTrue(runs.isEmpty)
    }

    func testSwitchWaitsForQueuedUnderstandingCreationAndLatestEdit() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        let originalID = try XCTUnwrap(store.state.session?.id)
        store.beginUnderstanding()
        store.saveUnderstanding(text: "第一版")
        store.saveUnderstanding(text: "切换前的最新理解")
        store.start(entry: "discuss", initialText: "下一件事")
        store.saveUnderstanding(text: "旧编辑器迟到的事件")
        try await waitUntil { store.state.session?.id != originalID && !store.state.isTransitioningSession }
        let saved = try await repo.understandings(sessionID: originalID)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.text, "切换前的最新理解")
        XCTAssertEqual(saved.first?.state, .draft)
        XCTAssertEqual(store.state.inputText, "下一件事")
    }

    func testUnderstandingWriteFailureBlocksAllSessionTransitionsUntilSaved() async throws {
        for action in ["start", "continue", "pause", "finish"] {
            let db = try AppDatabase(dbQueue: DatabaseQueue())
            let repo = SQLiteMentorRepository(database: db)
            let transport = MentorStoreFixtureTransport()
            let store = MentorFeatureStore(repository: repo, transport: transport)
            let targetID = UUID()
            try await repo.createSession(MentorSession(id: targetID, initialEntry: "discuss", lifecycle: .paused,
                draftText: "历史草稿", draftRevision: 1, activityAt: .now))
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing }
            let oldID = try XCTUnwrap(store.state.session?.id)
            store.beginUnderstanding()
            store.saveUnderstanding(text: "已保存的理解")
            try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
            try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_exit_note BEFORE UPDATE OF text ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END") }
            store.saveUnderstanding(text: "离开前未保存的理解")
            func leave() {
                switch action {
                case "start": store.start(entry: "discuss")
                case "continue": store.continueSession(id: targetID)
                case "pause": store.pause()
                default: store.finish()
                }
            }
            leave()
            try await waitUntil { !store.state.isTransitioningSession && store.state.pendingUnderstandingOperations == 0 }
            XCTAssertEqual(store.state.session?.id, oldID, action)
            XCTAssertEqual(store.state.understandingInputText, "离开前未保存的理解", action)
            XCTAssertNotNil(store.state.understandingError, action)
            let old = try await repo.understandings(sessionID: oldID)
            XCTAssertEqual(old.first?.text, "已保存的理解", action)
            try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_exit_note") }
            store.retryUnderstandingSave()
            try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
            XCTAssertNil(store.state.understandingError)
            leave()
            try await waitUntil { !store.state.isTransitioningSession }
            switch action {
            case "start": XCTAssertNotEqual(store.state.session?.id, oldID)
            case "continue": XCTAssertEqual(store.state.session?.id, targetID)
            case "pause": XCTAssertEqual(store.state.phase, .paused)
            default: XCTAssertEqual(store.state.phase, .ended)
            }
            let saved = try await repo.understandings(sessionID: oldID)
            XCTAssertEqual(saved.first?.text, "离开前未保存的理解")
            XCTAssertEqual(saved.first?.state, .draft)
            XCTAssertEqual(transport.calls, 0)
        }
    }

    func testConfirmationFreezesInputUntilItsResultIsKnown() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "我明确认可的这一版")
        store.confirmUnderstanding()
        XCTAssertTrue(store.state.isConfirmingUnderstanding)
        store.saveUnderstanding(text: "确认过程中迟到的编辑")
        store.confirmUnderstanding()
        let flushed = await store.flushPendingEdits()
        XCTAssertTrue(flushed)
        XCTAssertFalse(store.state.isConfirmingUnderstanding)
        XCTAssertEqual(store.state.understanding?.state, .confirmed)
        XCTAssertEqual(store.state.understanding?.text, "我明确认可的这一版")
        XCTAssertEqual(store.state.understandingInputText, "我明确认可的这一版")
        XCTAssertNil(store.state.understandingError)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected state was not reached")
    }

    private func catalog() throws -> MentorLessonCatalog {
        let lessons = (1...24).map { index in
            let base = MentorLesson(id: String(format: "L%02d", index), version: "1.0", editorialOrder: index,
                title: "Fixture lesson \(index)", theme: MentorLesson.Theme.allCases[(index - 1) / 4],
                applicableContexts: ["fixture context"], claim: "Fixture claim", example: "Fixture example", boundary: "Fixture boundary", observation: nil,
                sourceType: .teachingExample, citations: [], contentHash: "", review: .init(status: .approved, reviewedBy: "fixture", reviewedAt: .now, note: nil))
            return MentorLesson(id: base.id, version: base.version, editorialOrder: base.editorialOrder, title: base.title, theme: base.theme,
                applicableContexts: base.applicableContexts, claim: base.claim, example: base.example, boundary: base.boundary, observation: base.observation,
                sourceType: base.sourceType, citations: base.citations, contentHash: MentorLessonCatalog.contentHash(for: base), review: base.review)
        }
        return try MentorLessonCatalog(pack: MentorLessonPack(schemaVersion: "1.0.0", packID: "fixture", version: "1.0", lessons: lessons))
    }
}

private final class MentorStoreFixtureTransport: MentorTransport, LLMClient, @unchecked Sendable {
    var suggestedActions = ["finish"]
    private(set) var calls = 0
    private(set) var lastRequest: LLMRequest?
    func complete(_ request: LLMRequest) async throws -> Data {
        calls += 1
        lastRequest = request
        let source = request.sourceRecordIDs.first ?? "item:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        return try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "explain", "material_status": "usable",
            "body": "把完成动作和实际效果分开看。", "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": [source], "lesson_ref": NSNull(), "suggested_actions": suggestedActions
        ])
    }
}

@MainActor
private final class HeldMentorTransport: MentorTransport {
    var pending: CheckedContinuation<Data, Error>?
    var request: LLMRequest?
    var wasCancelled = false
    var didReturn = false
    func complete(_ request: LLMRequest) async throws -> Data {
        self.request = request
        let data: Data = try await withCheckedThrowingContinuation { pending = $0 }
        wasCancelled = Task.isCancelled
        didReturn = true
        return data
    }
}

private final class FailingMentorTransport: MentorTransport {
    let result: Result<Data, Error>
    private(set) var calls = 0
    private(set) var request: LLMRequest?
    init(result: Result<Data, Error>) { self.result = result }
    func complete(_ request: LLMRequest) async throws -> Data {
        calls += 1
        self.request = request
        return try result.get()
    }
}

private final class TeachingIntentTransport: MentorTransport {
    private(set) var request: LLMRequest?
    func complete(_ request: LLMRequest) async throws -> Data {
        self.request = request
        return try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "clarify", "material_status": "missing",
            "body": "先补充一个片段", "question": "当时发生了什么？", "question_purpose": "material",
            "source_refs": [], "lesson_ref": NSNull(), "suggested_actions": ["finish"]
        ])
    }
}

private final class MentorTestPromptProvider: PromptProvider {
    var version = "test-injected.2"
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        let base = LocalPromptProvider().template(for: id, mode: mode)
        return PromptTemplate(id: id, version: version, systemText: base.systemText,
            userText: base.userText, outputSchemaVersion: base.outputSchemaVersion)
    }
}
