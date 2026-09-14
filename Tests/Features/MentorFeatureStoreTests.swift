import XCTest
import GRDB
@testable import MingSi

@MainActor
final class MentorFeatureStoreTests: XCTestCase {
    func testDirectDiscussionPersistsInputAndValidatedResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(store.state.phase, .editing)
        guard let sessionID = store.state.session?.id else { return XCTFail("session missing") }
        store.submit(text: "今天完成了一个改动")
        try await Task.sleep(for: .milliseconds(150))
        guard case .showingResponse = store.state.phase else { return XCTFail("response was not shown: \(store.state.phase)") }
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
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_request_end BEFORE UPDATE OF state ON mentor_requests BEGIN SELECT RAISE(ABORT, 'injected'); END") }
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

private final class MentorStoreFixtureTransport: MentorTransport, @unchecked Sendable {
    private(set) var calls = 0
    func complete(_ request: LLMRequest) async throws -> Data {
        calls += 1
        let source = request.sourceRecordIDs.first ?? "item:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        return try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "explain", "material_status": "usable",
            "body": "把完成动作和实际效果分开看。", "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": [source], "lesson_ref": NSNull(), "suggested_actions": ["finish"]
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
    init(result: Result<Data, Error>) { self.result = result }
    func complete(_ request: LLMRequest) async throws -> Data {
        calls += 1
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
