import XCTest
import GRDB
@testable import MingSi

@MainActor
final class MentorFeatureStoreTests: XCTestCase {
    func testStreamingPreviewSurvivesFailureWithoutBecomingSavedAssistant() async throws {
        for failure: LLMClientError in [.incompleteResponse,
            .providerStreamFailure(ProviderStreamFailure(event: .responsesError, reason: .quota))] {
            let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
            let transport = HeldMentorTransport()
            let store = MentorFeatureStore(repository: repo, transport: transport)
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
            store.submit(text: "请解释这次结果，先不安排动作。")
            try await waitUntil { transport.pending != nil }
            let request = try XCTUnwrap(transport.request)
            let progress = try XCTUnwrap(request.mentorStreamProgress)
            try progress.receive(#"{"body":"正在逐步显示的解释"#)
            try await waitUntil { store.state.streamingPreview == "正在逐步显示的解释" }
            XCTAssertEqual(store.state.phase, .submitting)
            let before = try await repo.items(sessionID: XCTUnwrap(store.state.session?.id))
            XCTAssertFalse(before.contains { $0.kind == .assistant })
            transport.pending?.resume(throwing: failure); transport.pending = nil
            try await waitUntil { if case .failed = store.state.phase { return true }; return false }
            XCTAssertEqual(store.state.streamingPreview, "正在逐步显示的解释")
            let saved = try await repo.items(sessionID: XCTUnwrap(store.state.session?.id))
            XCTAssertFalse(saved.contains { $0.kind == .assistant })
            XCTAssertTrue(saved.contains { $0.kind == .user })
            XCTAssertNotNil(store.state.retryableRequest)
            XCTAssertEqual(store.state.requestFailureMessage, failure.userFacingMessage)
        }
    }

    func testCancelledStreamCannotUpdatePreviewOrPersistLateAnswer() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.submit(text: "保留原话")
        try await waitUntil { transport.pending != nil }
        let progress = try XCTUnwrap(transport.request?.mentorStreamProgress)
        try progress.receive(#"{"body":"取消前"#)
        try await waitUntil { store.state.streamingPreview == "取消前" }
        store.configurationDidChange()
        try progress.receive("不应该出现")
        transport.pending?.resume(returning: Data("{}".utf8)); transport.pending = nil
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(store.state.streamingPreview.contains("不应该出现"))
        let saved = try await repo.items(sessionID: XCTUnwrap(store.state.session?.id))
        XCTAssertFalse(saved.contains { $0.kind == .assistant })
    }

    private func exhaustedRecallStore() async throws -> (AppDatabase, SQLiteMentorRepository, MentorStoreFixtureTransport, MentorFeatureStore) {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        transport.materialQuestions = ["今天改动具体影响哪个使用环节？", "这个环节前后有什么变化？"]
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "review", automaticallyOpenReview: false)
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        XCTAssertFalse(store.canContinueRecall)
        for index in 0..<2 {
            store.submit(text: "回看片段 \(index + 1)")
            try await waitUntil { store.state.phase == .showingResponse }
            XCTAssertFalse(store.canContinueRecall, "Unseen content must not unlock a new recall segment")
            store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
            try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
            XCTAssertEqual(store.state.session?.recallCount, index + 1)
        }
        XCTAssertTrue(store.canContinueRecall)
        return (db, repo, transport, store)
    }

    func testUserCriteriaStayInSamePersistedConversationAfterReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mentor-criteria-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("conversation.sqlite")
        let database = try AppDatabase(url: url)
        let repository = SQLiteMentorRepository(database: database)
        let transport = MentorCriteriaFixtureTransport()
        let first = MentorFeatureStore(repository: repository, transport: transport)
        first.start(entry: "discuss")
        try await waitUntil { first.state.phase == .editing && !first.state.isTransitioningSession }
        let original = "周日只有半天，兼职能赚三百元，也想陪父母聚餐，两件事都重要；先比较取舍，不要替我排序。"
        first.submit(text: original)
        try await waitUntil { first.state.phase == .showingResponse }
        let sessionID = try XCTUnwrap(first.state.session?.id)
        let responseID = try XCTUnwrap(first.state.responseItemID)
        let response = try XCTUnwrap(first.state.response)
        first.acknowledgeResponse(itemID: responseID)
        try await waitUntil { first.state.acknowledgedResponseItemID == responseID }

        let reopened = MentorFeatureStore(repository: SQLiteMentorRepository(database: try AppDatabase(url: url)), transport: transport)
        reopened.continueSession(id: sessionID)
        try await waitUntil { reopened.state.phase == .showingResponse && !reopened.state.isTransitioningSession }
        XCTAssertEqual(reopened.state.responseItemID, responseID)
        XCTAssertEqual(reopened.state.response, response)
        XCTAssertEqual(transport.requests.count, 1, "Opening persisted context must not call the model")
        reopened.acknowledgeResponse(itemID: responseID)
        try await waitUntil { reopened.state.acknowledgedResponseItemID == responseID }
        let priority = "本月房租已留够，接下来两周没有其他相聚机会，这次更在意陪父母。请按这个标准直接给建议。"
        reopened.submit(text: priority)
        try await waitUntil { reopened.state.phase == .showingResponse && reopened.state.responseItemID != responseID }
        XCTAssertEqual(reopened.state.session?.id, sessionID)
        XCTAssertEqual(reopened.state.response?.response.action, .advise)
        XCTAssertNil(reopened.state.response?.response.question)
        XCTAssertEqual(transport.requests.count, 2)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(try XCTUnwrap(transport.requests.last).inputSummary.utf8))
        XCTAssertEqual(context.sessionID, sessionID)
        XCTAssertEqual(context.conversationState.visibleTurnIndex, 2)
        XCTAssertEqual(context.sources.first { $0.ref == context.latestUserSourceRef }?.content, priority)
        XCTAssertTrue(context.sources.contains { $0.content == original && $0.role == .user })
        XCTAssertTrue(context.sources.contains { $0.role == .assistant && $0.ref.value == "item:" + responseID.uuidString })
        XCTAssertEqual(reopened.state.response?.response.sourceRefs, [try XCTUnwrap(context.latestUserSourceRef)])
        XCTAssertTrue(transport.requests.allSatisfy { $0.prompt.version == "2.17.0" })
        let items = try await repository.items(sessionID: sessionID)
        XCTAssertEqual(items.filter { $0.kind == .user }.count, 2)
        XCTAssertEqual(items.filter { $0.kind == .assistant }.count, 2)
    }

    func testExplicitRecallContinuationPreservesDraftAndHistoryWithoutCallingModel() async throws {
        let (db, repo, transport, store) = try await exhaustedRecallStore()
        let sessionID = try XCTUnwrap(store.state.session?.id)
        let originalEpoch = try XCTUnwrap(store.state.session?.requestEpoch)
        let originalItems = store.state.timeline
        store.updateInputText("尚未发送的另一个片段")

        let continued = await store.continueRecall()
        XCTAssertTrue(continued)
        XCTAssertFalse(store.canContinueRecall)
        XCTAssertEqual(store.state.session?.recallCount, 0)
        XCTAssertEqual(store.state.session?.requestEpoch, originalEpoch + 1)
        XCTAssertEqual(store.state.inputText, "尚未发送的另一个片段")
        XCTAssertEqual(store.state.timeline, originalItems)
        XCTAssertEqual(transport.calls, 2)
        let duplicate = await store.continueRecall()
        XCTAssertFalse(duplicate)
        let receipts = try await db.dbQueue.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_recall_continuations")
        }
        XCTAssertEqual(receipts, 1)

        let restored = MentorFeatureStore(repository: repo, transport: transport)
        restored.continueSession(id: sessionID)
        try await waitUntil { restored.state.phase == .showingResponse && !restored.state.isTransitioningSession }
        XCTAssertEqual(restored.state.session?.recallCount, 0)
        XCTAssertEqual(restored.state.inputText, "尚未发送的另一个片段")
        restored.acknowledgeResponse(itemID: try XCTUnwrap(restored.state.responseItemID))
        try await waitUntil { restored.state.acknowledgedResponseItemID == restored.state.responseItemID }
        transport.materialQuestions = ["这个新片段里，你具体改变了哪一步？"]
        restored.submit()
        try await waitUntil { restored.state.phase == .showingResponse && restored.state.responseItemID != originalItems.last?.id }
        let context = try JSONDecoder().decode(MentorContextPayload.self,
            from: Data(try XCTUnwrap(transport.lastRequest).inputSummary.utf8))
        XCTAssertEqual(context.materialQuestionCount, 0)
        XCTAssertTrue(context.allowsMaterialQuestion)
        XCTAssertEqual(context.conversationState.visibleTurnIndex, 3)
        XCTAssertEqual(transport.calls, 3)
    }

    func testRecallContinuationWriteFailurePreservesBudgetAndCanRetryLocally() async throws {
        let (db, repo, transport, store) = try await exhaustedRecallStore()
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.updateInputText("失败也要保留的片段")
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER reject_recall_continuation BEFORE UPDATE OF recall_count ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        let failed = await store.continueRecall()
        XCTAssertFalse(failed)
        XCTAssertNotNil(store.state.actionError)
        XCTAssertTrue(store.canContinueRecall)
        XCTAssertEqual(store.state.inputText, "失败也要保留的片段")
        let unchanged = try await repo.session(id: sessionID)
        XCTAssertEqual(unchanged?.recallCount, 2)
        let receipts = try await db.dbQueue.read {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_recall_continuations")
        }
        XCTAssertEqual(receipts, 0)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_recall_continuation") }
        let retried = await store.continueRecall()
        XCTAssertTrue(retried)
        XCTAssertNil(store.state.actionError)
        XCTAssertEqual(store.state.session?.recallCount, 0)
        XCTAssertEqual(transport.calls, 2)
    }

    func testRecallContinuationDoesNotModifyReadOnlyHistoryOrUnsavedDraft() async throws {
        let (db, repo, transport, store) = try await exhaustedRecallStore()
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.updateInputText("必须先保存的片段")
        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER reject_recall_draft BEFORE UPDATE OF draft_text ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        let failed = await store.continueRecall()
        XCTAssertFalse(failed)
        XCTAssertEqual(store.state.session?.recallCount, 2)
        XCTAssertEqual(store.state.inputText, "必须先保存的片段")
        XCTAssertNotNil(store.state.draftSaveError)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_recall_draft") }

        store.viewSession(id: sessionID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertFalse(store.canContinueRecall)
        let historyAttempt = await store.continueRecall()
        XCTAssertFalse(historyAttempt)
        let saved = try await repo.session(id: sessionID)
        XCTAssertEqual(saved?.recallCount, 2)
        XCTAssertEqual(transport.calls, 2)
    }

    func testReviewOpeningKeepsBothMaterialFollowUpsAvailable() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        transport.materialQuestions = ["今天改动具体影响哪个使用环节？", "这个环节前后有什么变化？"]
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "review")
        try await waitUntil { store.state.phase == .showingResponse && !store.state.isTransitioningSession }
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
        let afterOpening = try await repo.session(id: sessionID)
        XCTAssertEqual(afterOpening?.recallCount, 0, "The opening must leave both follow-up questions available")

        for index in 0..<2 {
            store.submit(text: "我补充第 \(index + 1) 个实际片段")
            try await waitUntil { store.state.phase == .showingResponse }
            let sent = try XCTUnwrap(transport.lastRequest)
            let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8))
            XCTAssertEqual(context.materialQuestionCount, index)
            XCTAssertTrue(context.allowsMaterialQuestion)
            XCTAssertTrue(try XCTUnwrap(store.state.response).response.requiresMaterial)
            store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
            try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
            let saved = try await repo.session(id: sessionID)
            XCTAssertEqual(saved?.recallCount, index + 1)
        }
        store.submit(text: "我已经补充了结果，现在请解释")
        try await waitUntil { store.state.phase == .showingResponse }
        let sent = try XCTUnwrap(transport.lastRequest)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8))
        XCTAssertEqual(context.materialQuestionCount, 2)
        XCTAssertFalse(context.allowsMaterialQuestion)
        XCTAssertNil(store.state.response?.response.question)
        XCTAssertEqual(transport.calls, 4)
    }

    func testReviewRecommendationReceivesOnlyCurrentUserEventsAfterSavedResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        var received: [[LifeGuidanceEvent]] = []
        let store = MentorFeatureStore(repository: repo, transport: transport,
            onReviewReady: { _, events in received.append(events) })
        store.start(entry: "review")
        try await waitUntil { store.state.phase == .showingResponse && !store.state.isTransitioningSession }
        XCTAssertEqual(transport.calls, 1, "A zero-material review should receive an opening prompt")
        let openingContext = try JSONDecoder().decode(MentorContextPayload.self,
            from: Data(try XCTUnwrap(transport.lastRequest).inputSummary.utf8))
        XCTAssertEqual(openingContext.initialEntry, "review")
        XCTAssertEqual(openingContext.intent, "review")
        XCTAssertNil(openingContext.latestUserSourceRef)
        XCTAssertTrue(openingContext.sources.filter { $0.role == .user }.isEmpty)
        XCTAssertTrue(received.isEmpty, "An empty review opening must not trigger a guidance recommendation")
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
        store.submit(text: "每个人都在不停打断我")
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(received.count, 1)
        let original = try XCTUnwrap(store.state.timeline.first { $0.kind == .user })
        XCTAssertEqual(received.first?.first?.id, "item:" + original.id.uuidString)
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
        let corrected = await store.correctUserItem(original.id, text: "核对后只有一条非必要通知打断了我")
        XCTAssertTrue(corrected)
        store.submit(text: "我希望下次写方案时能少一些通知中断")
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(received.count, 2)
        let last = try XCTUnwrap(received.last)
        XCTAssertFalse(last.contains { $0.text == "每个人都在不停打断我" })
        XCTAssertTrue(last.contains { $0.text == "核对后只有一条非必要通知打断了我" })
        XCTAssertFalse(last.contains { $0.text == "把完成动作和实际效果分开看。" })
    }

    func testLocalCorrectionPreservesOriginalDraftAndVersionsAndUsesCorrectedContext() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "所有用户都失败了")
        try await waitUntil { store.state.phase == .showingResponse }
        let original = try XCTUnwrap(store.state.timeline.first { $0.kind == .user })
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
        store.updateInputText("保留未发送的新问题")
        let corrected = await store.correctUserItem(original.id, text: "只有一位用户失败了")
        XCTAssertTrue(corrected)
        XCTAssertEqual(transport.calls, 1, "更正只在本地保存")
        XCTAssertEqual(store.state.timeline.first, original)
        XCTAssertEqual(store.state.timeline.last?.supersedesItemID, original.id)
        XCTAssertEqual(store.state.inputText, "保留未发送的新问题")
        XCTAssertNil(store.state.response)
        XCTAssertNil(store.state.retryableRequest)
        XCTAssertFalse(store.canCorrectUserItem(original.id))
        let correction = try XCTUnwrap(store.state.timeline.last)
        XCTAssertTrue(store.canCorrectUserItem(correction.id))
        XCTAssertEqual(store.state.session?.semanticRevision, 1)
        store.submit(text: "我现在应该先验证什么？")
        try await waitUntil { store.state.phase == .showingResponse }
        let payload = try JSONDecoder().decode(MentorContextPayload.self, from: Data(try XCTUnwrap(transport.lastRequest).inputSummary.utf8))
        XCTAssertEqual(payload.sources.first { $0.content == "所有用户都失败了" }?.isCurrent, false)
        XCTAssertEqual(payload.sources.first { $0.content == "只有一位用户失败了" }?.isCurrent, true)
        XCTAssertTrue(payload.sources.filter { $0.role == .assistant }.allSatisfy { !$0.isCurrent })
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
        let second = await store.correctUserItem(correction.id, text: "确认后，这一位只是延迟完成。")
        XCTAssertTrue(second)
        XCTAssertEqual(store.state.session?.semanticRevision, 2)
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.finish()
        try await waitUntil { store.state.phase == .ended && !store.state.isTransitioningSession }
        let restored = MentorFeatureStore(repository: repo, transport: transport)
        restored.viewSession(id: sessionID)
        try await waitUntil { restored.state.isViewingHistory && !restored.state.isTransitioningSession }
        XCTAssertEqual(restored.state.timeline.filter { $0.supersedesItemID != nil }.count, 2)
        XCTAssertNil(restored.state.response)
        XCTAssertFalse(restored.canCorrectUserItem(correction.id), "只读历史不能修改")
    }

    func testOversizedMaterialWaitsForExplicitSelectionBeforeNetworkRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: String(repeating: "事实片段。", count: 8_000))
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.submit()
        try await waitUntil { store.state.phase != .submitting }
        if store.state.materialSelection == nil {
            XCTAssertEqual(transport.calls, 1)
            return
        }
        XCTAssertEqual(transport.calls, 0)
        XCTAssertFalse(store.state.materialSelection?.candidates.isEmpty == true)
        store.submitMaterialSelection()
        XCTAssertEqual(store.state.materialSelection?.error, "至少选择一条片段后再发送。")
        let first = try XCTUnwrap(store.state.materialSelection?.candidates.first)
        store.toggleMaterialFragment(first.id)
        store.submitMaterialSelection()
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(transport.calls, 1)
        XCTAssertEqual(try XCTUnwrap(transport.lastRequest).inputSummary.filter { $0 == "事" }.count,
                       first.text.filter { $0 == "事" }.count)
        let stored = try XCTUnwrap(store.state.timeline.first(where: { $0.kind == .user }))
        let storedText = try XCTUnwrap(JSONDecoder().decode([String: String].self, from: Data(stored.payloadJSON.utf8))["text"])
        XCTAssertEqual(storedText, String(repeating: "事实片段。", count: 8_000))
    }
    func testHistoryOrTeacherSelectionCannotReplacePendingRequestInSQLiteFlow() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: String(repeating: "完整旧原话。", count: 8_000))
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.submit()
        try await waitUntil { store.state.materialSelection != nil }
        let first = try XCTUnwrap(store.state.materialSelection?.candidates.first)
        store.toggleMaterialFragment(first.id)
        store.submitMaterialSelection()
        try await waitUntil { store.state.phase == .showingResponse }
        let responseID = try XCTUnwrap(store.state.responseItemID)
        store.acknowledgeResponse(itemID: responseID)
        try await waitUntil { store.state.acknowledgedResponseItemID == responseID }
        let currentText = "请解释选中的老师原话，以本轮问题为准。"
        store.submit(text: currentText)
        try await waitUntil { store.state.materialSelection != nil }
        let selection = try XCTUnwrap(store.state.materialSelection)
        let old = try XCTUnwrap(selection.candidates.first { $0.field == .userText && $0.sourceID != selection.currentUserSourceID })
        let teacher = try XCTUnwrap(selection.candidates.first { $0.field == .assistantBody })
        let current = try XCTUnwrap(selection.candidates.first { $0.sourceID == selection.currentUserSourceID })
        for fragment in [old, teacher] {
            store.toggleMaterialFragment(fragment.id)
            store.submitMaterialSelection()
            XCTAssertNotNil(store.state.materialSelection?.error)
            XCTAssertEqual(transport.calls, 1)
            store.toggleMaterialFragment(fragment.id)
        }
        store.toggleMaterialFragment(teacher.id)
        store.toggleMaterialFragment(current.id)
        store.submitMaterialSelection()
        try await waitUntil { store.state.phase == .showingResponse && store.state.responseItemID != responseID }
        XCTAssertEqual(transport.calls, 2)
        let sent = try XCTUnwrap(transport.lastRequest)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8))
        XCTAssertEqual(context.sources.first { $0.ref == context.latestUserSourceRef }?.content, currentText)
        XCTAssertFalse(sent.inputSummary.contains("完整旧原话"))
        XCTAssertEqual(context.sources.filter { $0.role == .assistant }.count, 1)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .user }.count, 2)
        XCTAssertTrue(store.state.timeline.contains { $0.payloadJSON.contains(String(repeating: "完整旧原话。", count: 8_000)) })
    }


    func testCorrectionRejectsLateResponseAndCancelsItsOwnedRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let immediate = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: immediate)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "最初的事实")
        try await waitUntil { store.state.phase == .showingResponse }
        let original = try XCTUnwrap(store.state.timeline.first { $0.kind == .user })
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        try await waitUntil { store.state.acknowledgedResponseItemID == store.state.responseItemID }
        let held = HeldMentorTransport()
        store.updateDependencies(transport: held, promptProvider: LocalPromptProvider())
        store.submit(text: "在等待的下一轮")
        try await waitUntil { held.pending != nil }
        let request = try XCTUnwrap(held.request)
        let corrected = await store.correctUserItem(original.id, text: "修正后的事实")
        XCTAssertTrue(corrected)
        let timeline = store.state.timeline
        let outcome = try await repo.requestOutcome(sessionID: try XCTUnwrap(store.state.session?.id),
            requestID: try XCTUnwrap(request.mentorAuditToken?.requestID))
        XCTAssertEqual(outcome, .cancelled)
        held.pending?.resume(returning: try await immediate.complete(request))
        try await waitUntil { held.didReturn }
        await store.flushUsageEvents()
        XCTAssertEqual(store.state.timeline, timeline)
        XCTAssertEqual(store.state.phase, .editing)
        XCTAssertNil(store.state.response)
        XCTAssertTrue(held.wasCancelled)
    }

    func testCorrectionWriteFailureKeepsOriginalAndCanRetryWithoutNetwork() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let capture = try await SQLiteCaptureFragmentRepository(database: db).save(CaptureFragment(rawText: "闪念原文", dayKey: "2026-10-03"))
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        let opened = await store.startCaptureSession(from: capture.id)
        XCTAssertTrue(opened)
        let original = try XCTUnwrap(store.state.timeline.first)
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_correction_ui BEFORE INSERT ON mentor_corrections BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let failed = await store.correctUserItem(original.id, text: "尚未保存的更正")
        XCTAssertFalse(failed)
        XCTAssertNotNil(store.state.correctionError)
        XCTAssertEqual(store.state.timeline, [original])
        XCTAssertTrue(store.canCorrectUserItem(original.id))
        XCTAssertEqual(store.state.session?.semanticRevision, 0)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_correction_ui") }
        let retried = await store.correctUserItem(original.id, text: "保存后的更正")
        XCTAssertTrue(retried)
        XCTAssertNil(store.state.correctionError)
        XCTAssertEqual(transport.calls, 0)
        let fragments = try await SQLiteCaptureFragmentRepository(database: db).fragments(forDayKey: capture.dayKey, statuses: nil)
        XCTAssertEqual(fragments.first?.rawText, "闪念原文", "更正借用的会话材料不能改写闪念来源")
        let empty = await store.correctUserItem(try XCTUnwrap(store.state.timeline.last).id, text: " \n")
        XCTAssertFalse(empty)
        XCTAssertEqual(store.state.timeline.count, 2)
    }

    func testBlankExitRetainsAttemptAndActualExitPhaseWithoutCreatingSession() async throws {
        for ending in [false, true] {
            let db = try AppDatabase(dbQueue: DatabaseQueue())
            let repo = SQLiteMentorRepository(database: db)
            var tick = 100.0
            let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), uptime: { tick })
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
            let sessionID = try XCTUnwrap(store.state.session?.id)
            tick = 101.5
            if ending { store.finish() } else { store.pause() }
            try await waitUntil { store.state.phase == (ending ? .ended : .paused) && !store.state.isTransitioningSession }
            await store.flushUsageEvents()
            let facts = try await usageFacts(db)
            XCTAssertEqual(facts.count, 2)
            let entry = try XCTUnwrap(facts.first { $0.kind == "entry_started" })
            let exit = try XCTUnwrap(facts.first { $0.kind == "session_left" })
            XCTAssertEqual(entry.attributes["has_material"], "false")
            XCTAssertEqual(entry.attributes["schema_version"], "1.0.0")
            XCTAssertEqual(entry.attributes["content_version"], "unavailable")
            XCTAssertEqual(exit.attemptID, entry.attemptID)
            XCTAssertEqual(exit.attributes["exit_phase"], "editing")
            XCTAssertEqual(exit.attributes["exit_action"], ending ? "finish" : "pause")
            XCTAssertEqual(exit.attributes["duration_ms"], "1500")
            XCTAssertTrue(facts.allSatisfy { $0.sessionID == nil })
            let persisted = try await repo.session(id: sessionID)
            XCTAssertNil(persisted)
            store.pause()
            try await waitUntil { !store.state.isTransitioningSession }
            await store.flushUsageEvents()
            let repeated = try await usageFacts(db)
            XCTAssertEqual(repeated.count, 2, "Dismissal after finish must not count another exit")
        }
    }

    func testRapidEntryClicksKeepEveryAttemptIncludingCancelledEntries() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        store.start(entry: "discuss")
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.pause()
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        let entries = facts.filter { $0.kind == "entry_started" }
        let exits = facts.filter { $0.kind == "session_left" }
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(exits.count, 3)
        XCTAssertEqual(Set(entries.map(\.attemptID)), Set(exits.map(\.attemptID)))
        XCTAssertEqual(exits.filter { $0.attributes["reason"] == "entry_cancelled" }.count, 2)
        XCTAssertTrue(facts.allSatisfy { $0.sessionID == nil })
        let sessions = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_sessions") }
        XCTAssertEqual(sessions, 0)
    }

    func testSwitchAndPresentationTimingsStayWithTheirOriginalAttempts() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        var tick = 10.0
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog(), uptime: { tick })
        store.start(entry: "discuss", initialText: "不应进入观测日志的私人原话")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        let oldSessionID = try XCTUnwrap(store.state.session?.id)
        tick = 12
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading && !store.state.isTransitioningSession }
        let firstLesson = try XCTUnwrap(store.state.lesson)
        await store.flushUsageEvents()
        let beforePresentation = try await usageFacts(db)
        XCTAssertFalse(beforePresentation.contains { $0.kind == "content_presented" }, "Saving is not presentation")
        tick = 14
        store.acknowledgeLesson()
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        var facts = try await usageFacts(db)
        let oldEntry = try XCTUnwrap(facts.first { $0.kind == "entry_started" && $0.sessionID == oldSessionID.uuidString })
        let exit = try XCTUnwrap(facts.first { $0.kind == "session_left" })
        XCTAssertEqual(exit.attemptID, oldEntry.attemptID)
        XCTAssertEqual(exit.sessionID, oldSessionID.uuidString)
        XCTAssertEqual(exit.attributes["exit_phase"], "editing")
        XCTAssertEqual(exit.attributes["switched_entry"], "listen")
        XCTAssertEqual(exit.attributes["duration_ms"], "2000")
        let first = try XCTUnwrap(facts.first { $0.kind == "content_presented" })
        XCTAssertNotEqual(first.attemptID, oldEntry.attemptID)
        XCTAssertEqual(first.sessionID, firstLesson.sessionID.uuidString)
        XCTAssertEqual(first.attributes["first_content"], "true")
        XCTAssertEqual(first.attributes["duration_ms"], "2000")
        XCTAssertEqual(first.attributes["timing_scope"], "entry_to_content")
        XCTAssertEqual(first.attributes["content_kind"], "lesson")
        XCTAssertEqual(first.attributes["content_version"], "1.0")
        XCTAssertEqual(first.attributes["presentation"], "new")
        XCTAssertEqual(facts.filter { $0.kind == "content_presented" }.count, 1)
        tick = 15
        store.selectAnotherLesson()
        try await waitUntil { store.state.phase == .reading && store.state.lesson?.id != firstLesson.id }
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        facts = try await usageFacts(db)
        let second = try XCTUnwrap(facts.last { $0.kind == "content_presented" })
        XCTAssertEqual(second.attemptID, first.attemptID)
        XCTAssertEqual(second.attributes["first_content"], "false")
        XCTAssertNil(second.attributes["duration_ms"])
        XCTAssertFalse(facts.contains { $0.attributes.values.contains(where: { $0.contains("私人原话") }) })
        store.pause()
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        tick = 20
        store.continueSession(id: firstLesson.sessionID)
        try await waitUntil { store.state.phase == .reading && !store.state.isTransitioningSession }
        tick = 21
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        let restoredFacts = try await usageFacts(db)
        let restored = try XCTUnwrap(restoredFacts.last { $0.kind == "content_presented" })
        XCTAssertNotEqual(restored.attemptID, first.attemptID)
        XCTAssertEqual(restored.attributes["presentation"], "revisit")
        XCTAssertEqual(restored.attributes["first_content"], "true")
        XCTAssertEqual(restored.attributes["duration_ms"], "1000")
    }

    func testReadOnlyHistoryPresentationAndExitOnlyWriteUsageFacts() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let lesson = try XCTUnwrap(store.state.lesson)
        store.finish()
        try await waitUntil { store.state.phase == .ended && !store.state.isTransitioningSession }
        let before = try await repo.session(id: lesson.sessionID)
        let beforeItems = try await repo.items(sessionID: lesson.sessionID)
        store.viewSession(id: lesson.sessionID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        store.acknowledgeLesson()
        store.acknowledgeLesson()
        store.pause()
        await store.flushUsageEvents()
        let after = try await repo.session(id: lesson.sessionID)
        let afterItems = try await repo.items(sessionID: lesson.sessionID)
        XCTAssertEqual(before, after)
        XCTAssertEqual(beforeItems, afterItems)
        let receipt = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT presented_at FROM mentor_items WHERE id = ?", arguments: [lesson.id.uuidString]) }
        XCTAssertNil(receipt, "Read-only history must not create a domain receipt, even for unseen content")
        let facts = try await usageFacts(db)
        let history = try XCTUnwrap(facts.first { $0.kind == "entry_started" && $0.attributes["entry"] == "history" })
        let presentation = try XCTUnwrap(facts.first { $0.kind == "content_presented" })
        XCTAssertEqual(presentation.attemptID, history.attemptID)
        XCTAssertEqual(presentation.attributes["presentation"], "revisit")
        let exit = try XCTUnwrap(facts.first { $0.kind == "session_left" && $0.attemptID == history.attemptID })
        XCTAssertEqual(exit.attributes["exit_phase"], "history")
        XCTAssertTrue(store.state.isViewingHistory)
        XCTAssertNil(store.state.acknowledgedResponseItemID)
    }

    func testLocalTeachingAndPersonalReplyRecordSwitchesWithoutChangingInitialAttempt() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport, catalog: try catalog())
        store.start(entry: "recall")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.selectAnotherLesson()
        try await waitUntil { store.state.phase == .reading }
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        let before = try await usageFacts(db)
        let entry = try XCTUnwrap(before.first { $0.kind == "entry_started" })
        let teaching = try XCTUnwrap(before.first { $0.kind == "content_presented" })
        XCTAssertEqual(entry.attributes["entry"], "recall")
        XCTAssertEqual(teaching.attemptID, entry.attemptID)
        XCTAssertEqual(teaching.attributes["switched_entry"], "listen")
        XCTAssertEqual(transport.calls, 0)
        store.submit(text: "我想聊一个实际发生的片段")
        try await waitUntil { store.state.phase == .showingResponse }
        await store.flushUsageEvents()
        let after = try await usageFacts(db)
        let discussion = try XCTUnwrap(after.first { $0.kind == "request_finished" })
        XCTAssertEqual(discussion.attributes["switched_entry"], "discuss")
        XCTAssertEqual(discussion.attemptID, entry.attemptID)
        XCTAssertEqual(discussion.sessionID, entry.sessionID)
        XCTAssertEqual(after.filter { $0.kind == "entry_started" }.count, 1)
        XCTAssertEqual(transport.calls, 1)
    }

    func testPresentationReceiptRetryPreservesFirstObservedTime() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        var tick = 10.0
        let epoch = Date(timeIntervalSince1970: 1_700_000_000)
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: MentorStoreFixtureTransport(),
            catalog: try catalog(), now: { epoch.addingTimeInterval(tick) }, uptime: { tick })
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_receipt BEFORE UPDATE OF presented_at ON mentor_items BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        tick = 12
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        XCTAssertNotNil(store.state.presentationError)
        let before = try await usageFacts(db)
        XCTAssertFalse(before.contains { $0.kind == "content_presented" })
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_receipt") }
        tick = 50
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        let after = try await usageFacts(db)
        let event = try XCTUnwrap(after.first { $0.kind == "content_presented" })
        XCTAssertEqual(event.attributes["duration_ms"], "2000")
        let occurred = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT occurred_at FROM mentor_usage_events WHERE event_kind = 'content_presented'") }
        XCTAssertEqual(occurred, ISO8601DateFormatter().string(from: epoch.addingTimeInterval(12)))
        XCTAssertNil(store.state.presentationError)
    }

    func testFailedNewEntryDoesNotCloseOrReattributePreviousAttempt() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "原交流")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.start(entry: "listen")
        try await waitUntil { store.state.actionError != nil && !store.state.isTransitioningSession }
        await store.flushUsageEvents()
        var facts = try await usageFacts(db)
        XCTAssertEqual(store.state.phase, .editing)
        XCTAssertEqual(store.state.session?.id, sessionID)
        let old = try XCTUnwrap(facts.first { $0.kind == "entry_started" && $0.sessionID != nil })
        let failed = try XCTUnwrap(facts.first { $0.kind == "entry_started" && $0.attributes["entry"] == "listen" })
        XCTAssertFalse(facts.contains { $0.kind == "session_left" && $0.attemptID == old.attemptID })
        XCTAssertTrue(facts.contains { $0.kind == "session_left" && $0.attemptID == failed.attemptID && $0.attributes["reason"] == "entry_failed" && $0.sessionID == nil })
        store.pause()
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        await store.flushUsageEvents()
        facts = try await usageFacts(db)
        XCTAssertTrue(facts.contains { $0.kind == "session_left" && $0.attemptID == old.attemptID && $0.sessionID == sessionID.uuidString })
    }

    func testResumingPersonalDiscussionDoesNotCountThePreviousPathSwitchAgain() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading && !store.state.isTransitioningSession }
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.acknowledgeLesson()
        await store.flushUsageEvents()
        store.submit(text: "我想聊实际发生的一件事")
        try await waitUntil { store.state.phase == .showingResponse }
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        await store.flushUsageEvents()
        store.pause()
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        store.continueSession(id: sessionID)
        try await waitUntil { store.state.phase == .showingResponse && !store.state.isTransitioningSession }
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        await store.flushUsageEvents()
        store.submit(text: "这是对同一件事的补充")
        try await waitUntil { store.state.phase == .showingResponse && store.state.inputText.contains("补充") }
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        let requests = facts.filter { $0.kind == "request_finished" }
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.attributes["switched_entry"], "discuss")
        XCTAssertNil(requests.last?.attributes["switched_entry"])
        XCTAssertNotEqual(requests.first?.attemptID, requests.last?.attemptID)
    }

    func testSuccessfulRequestDurationAndFirstResponsePresentationAreSeparate() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = HeldMentorTransport()
        var tick = 10.0
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport, uptime: { tick })
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        tick = 12
        store.submit(text: "私人表达")
        try await waitUntil { transport.pending != nil }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        tick = 14.125
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { store.state.phase == .showingResponse }
        await store.flushUsageEvents()
        var facts = try await usageFacts(db)
        let entry = try XCTUnwrap(facts.first { $0.kind == "entry_started" })
        let completed = try XCTUnwrap(facts.first { $0.kind == "request_finished" })
        XCTAssertEqual(completed.attemptID, entry.attemptID)
        XCTAssertEqual(completed.sessionID, entry.sessionID)
        XCTAssertNotNil(completed.sessionID, "Blank session materialization must attach the attempt")
        XCTAssertEqual(completed.attributes["reason"], "succeeded")
        XCTAssertEqual(completed.attributes["duration_ms"], "2125")
        XCTAssertEqual(completed.attributes["timing_scope"], "request")
        XCTAssertFalse(facts.contains { $0.kind == "content_presented" })
        tick = 15
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        await store.flushUsageEvents()
        facts = try await usageFacts(db)
        let presented = try XCTUnwrap(facts.first { $0.kind == "content_presented" })
        XCTAssertEqual(presented.attributes["duration_ms"], "5000")
        XCTAssertEqual(presented.attributes["content_kind"], "response")
        XCTAssertEqual(presented.attributes["schema_version"], "1.0.0")
    }

    func testCancelledRequestsKeepOriginalAttemptAndRejectLateSuccessAfterSwitch() async throws {
        for action in ["finish", "pause", "switch"] {
            let db = try AppDatabase(dbQueue: DatabaseQueue())
            let transport = HeldMentorTransport()
            var tick = 10.0
            let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport, uptime: { tick })
            store.start(entry: "discuss")
            try await waitUntil { store.state.phase == .editing }
            let originalID = try XCTUnwrap(store.state.session?.id)
            tick = 12
            store.submit(text: "中断前的私人原话")
            try await waitUntil { transport.pending != nil }
            let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
            tick = 13
            if action == "finish" { store.finish() }
            else if action == "pause" { store.pause() }
            else { store.start(entry: "discuss", initialText: "另一个入口") }
            try await waitUntil { !store.state.isTransitioningSession && store.state.phase != .submitting }
            await store.flushUsageEvents()
            var facts = try await usageFacts(db)
            let entry = try XCTUnwrap(facts.first { $0.kind == "entry_started" })
            let request = try XCTUnwrap(facts.first { $0.kind == "request_finished" })
            XCTAssertEqual(request.attemptID, entry.attemptID)
            XCTAssertEqual(request.sessionID, originalID.uuidString)
            XCTAssertEqual(request.attributes["reason"], "cancelled")
            XCTAssertEqual(request.attributes["duration_ms"], "1000")
            let exit = try XCTUnwrap(facts.first { $0.kind == "session_left" && $0.attemptID == entry.attemptID })
            XCTAssertEqual(exit.attributes["exit_phase"], "submitting")
            tick = 20
            transport.pending?.resume(returning: payload)
            transport.pending = nil
            try await waitUntil { transport.didReturn }
            for _ in 0..<10 { await Task.yield() }
            await store.flushUsageEvents()
            facts = try await usageFacts(db)
            XCTAssertEqual(facts.filter { $0.kind == "request_finished" }.count, 1)
            XCTAssertFalse(facts.contains { $0.attributes["reason"] == "succeeded" })
        }
    }

    func testWatchdogTimeoutRecordsOneRequestDurationAndNoLateSuccess() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = HeldMentorTransport()
        var tick = 10.0
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport,
            uptime: { tick }, requestDeadlineAfter: .milliseconds(30))
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "超时的原话")
        try await waitUntil { transport.pending != nil }
        tick = 11
        try await waitUntil { if case .failed = store.state.phase { return store.state.retryableRequest != nil }; return false }
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        let event = try XCTUnwrap(facts.first { $0.kind == "request_finished" })
        XCTAssertEqual(event.attributes["reason"], "timed_out")
        XCTAssertEqual(event.attributes["duration_ms"], "1000")
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { transport.didReturn }
        for _ in 0..<10 { await Task.yield() }
        await store.flushUsageEvents()
        let after = try await usageFacts(db)
        XCTAssertEqual(after.filter { $0.kind == "request_finished" }.count, 1)
        XCTAssertEqual(after.first { $0.kind == "request_finished" }?.attemptID, event.attemptID)
    }

    func testFailedExitMetadataCannotCopyPrivateErrorOrUserText() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let privateText = "私人原文不得进入统计"
        let transport = FailingMentorTransport(result: .failure(NSError(domain: privateText, code: 42)))
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: privateText)
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }
        if case .failed(let error) = store.state.phase { XCTAssertTrue(error.contains(privateText)) }
        store.finish()
        try await waitUntil { store.state.phase == .ended && !store.state.isTransitioningSession }
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        XCTAssertEqual(facts.first { $0.kind == "request_finished" }?.attributes["reason"], "failed")
        XCTAssertEqual(facts.first { $0.kind == "session_left" }?.attributes["exit_phase"], "failed")
        XCTAssertFalse(facts.flatMap { $0.attributes.values }.contains { $0.contains(privateText) })
    }

    func testObservationWriteFailureDoesNotBlockLocalConversation() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_usage BEFORE INSERT ON mentor_usage_events BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "仍应保存的业务草稿")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.finish()
        try await waitUntil { store.state.phase == .ended && !store.state.isTransitioningSession }
        await store.flushUsageEvents()
        let session = try await repo.session(id: try XCTUnwrap(store.state.session?.id))
        XCTAssertEqual(session?.draftText, "仍应保存的业务草稿")
        XCTAssertEqual(session?.lifecycle, .ended)
        XCTAssertEqual(transport.calls, 0)
        let facts = try await usageFacts(db)
        XCTAssertTrue(facts.isEmpty)
    }

    func testResponseSaveRetryDoesNotIncludeUserWaitingTimeInRequestDuration() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = HeldMentorTransport()
        var tick = 10.0
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport, uptime: { tick })
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_response BEFORE INSERT ON mentor_items WHEN NEW.kind = 'assistant' BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        tick = 12
        store.submit(text: "保留这次原话")
        try await waitUntil { transport.pending != nil }
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(transport.request))
        tick = 14
        transport.pending?.resume(returning: payload)
        transport.pending = nil
        try await waitUntil { store.state.canRetryResponseSave }
        await store.flushUsageEvents()
        let before = try await usageFacts(db)
        XCTAssertFalse(before.contains { $0.kind == "request_finished" }, "A rejected commit is not a successful request")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_response") }
        tick = 100
        store.retryResponseSave()
        try await waitUntil { store.state.phase == .showingResponse }
        await store.flushUsageEvents()
        let after = try await usageFacts(db)
        let request = try XCTUnwrap(after.first { $0.kind == "request_finished" })
        XCTAssertEqual(request.attributes["duration_ms"], "2000")
        XCTAssertEqual(request.attributes["reason"], "succeeded")
        XCTAssertEqual(after.filter { $0.kind == "request_finished" }.count, 1)
    }

    func testUnderstandingCancellationRecordsUnderstandingPhaseAndOneRequestEnd() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let initial = MentorStoreFixtureTransport()
        initial.suggestedActions = ["draft_understanding", "finish"]
        var tick = 10.0
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: initial, uptime: { tick })
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "只有我确认的表达才属于我的理解")
        try await waitUntil { store.state.phase == .showingResponse }
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        await store.flushUsageEvents()
        let held = HeldMentorTransport()
        store.updateDependencies(transport: held, promptProvider: LocalPromptProvider())
        tick = 12
        store.generateUnderstanding()
        try await waitUntil { held.pending != nil }
        tick = 13
        store.pause()
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        let cancelled = try XCTUnwrap(facts.first { $0.kind == "request_finished" && $0.attributes["reason"] == "cancelled" })
        XCTAssertEqual(cancelled.attributes["duration_ms"], "1000")
        let exit = try XCTUnwrap(facts.first { $0.kind == "session_left" })
        XCTAssertEqual(exit.attributes["exit_phase"], "understanding")
        XCTAssertEqual(cancelled.attemptID, exit.attemptID)
        let payload = try await MentorStoreFixtureTransport().complete(try XCTUnwrap(held.request))
        held.pending?.resume(returning: payload)
        held.pending = nil
        try await waitUntil { held.didReturn && !store.state.isGeneratingUnderstanding }
        await store.flushUsageEvents()
        let after = try await usageFacts(db)
        XCTAssertEqual(after.filter { $0.kind == "request_finished" }.count, 2, "Initial response plus one cancelled understanding request")
        XCTAssertNil(store.state.generatedUnderstandingID)
    }

    func testUnderstandingTerminalWriteFailureDoesNotInventSuccessfulAuditAndRetriesLocally() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let transport = MentorStoreFixtureTransport()
        transport.suggestedActions = ["draft_understanding", "finish"]
        transport.draftFailure = URLError(.notConnectedToInternet)
        let store = MentorFeatureStore(repository: SQLiteMentorRepository(database: db), transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "正在保留的交流")
        try await waitUntil { store.state.phase == .showingResponse }
        store.acknowledgeResponse(itemID: try XCTUnwrap(store.state.responseItemID))
        await store.flushUsageEvents()
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_understanding_end BEFORE UPDATE OF state ON mentor_requests WHEN NEW.state = 'failed' BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.generateUnderstanding()
        try await waitUntil { store.state.canRetryRequestFinalization && !store.state.isGeneratingUnderstanding }
        await store.flushUsageEvents()
        let before = try await usageFacts(db)
        XCTAssertEqual(before.filter { $0.kind == "request_finished" }.count, 1)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER reject_understanding_end") }
        store.retryRequestFinalization()
        try await waitUntil { !store.state.canRetryRequestFinalization && store.state.requestFinalizationError == nil }
        await store.flushUsageEvents()
        let after = try await usageFacts(db)
        XCTAssertEqual(after.filter { $0.kind == "request_finished" && $0.attributes["reason"] == "failed" }.count, 1)
        XCTAssertEqual(transport.calls, 2, "A terminal-write retry must not invoke the model")
        XCTAssertEqual(store.state.phase, .showingResponse)
    }

    func testBlankDiscussEntryStaysInMemoryUntilItHasMaterial() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())

        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && store.state.session != nil }
        let sessionID = try XCTUnwrap(store.state.session?.id)

        let before = try await repo.session(id: sessionID)
        XCTAssertNil(before)
        let page = try await repo.recentSessions()
        XCTAssertTrue(page.sessions.isEmpty)

        store.updateInputText("第一次真正留下的交流")
        let flushed = await store.flushPendingEdits()
        XCTAssertTrue(flushed)
        let persistedValue = try await repo.session(id: sessionID)
        let persisted = try XCTUnwrap(persistedValue)
        XCTAssertEqual(persisted.draftText, "第一次真正留下的交流")
        XCTAssertEqual(persisted.draftRevision, 1)
    }

    func testBlankDiscussEntryCanExitWithoutCreatingRecentSession() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())

        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && store.state.session != nil }
        let sessionID = try XCTUnwrap(store.state.session?.id)

        store.pause()
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        let savedAfterExit = try await repo.session(id: sessionID)
        XCTAssertNil(savedAfterExit)
        let recentAfterExit = try await repo.recentSessions()
        XCTAssertTrue(recentAfterExit.sessions.isEmpty)

        // The discarded synthetic state must not block a later real entry.
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && store.state.session?.id != sessionID }
        let savedAfterRestart = try await repo.session(id: sessionID)
        XCTAssertNil(savedAfterRestart)
    }

    func testHistorySourceDetailsAreReadOnlyAndUnderstandingUsesExplicitLinks() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID()
        let itemID = UUID()
        let activity = Date(timeIntervalSince1970: 1_700_000_000)
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "discuss", lifecycle: .ended,
            draftText: "保留草稿", draftRevision: 1, activityAt: activity))
        try await repo.appendItem(MentorTimelineItem(id: itemID, sessionID: sessionID, sequence: 1, kind: .user,
            payloadJSON: "{\"text\":\"这是明确保存的用户原话\"}"))
        let draft = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: UUID(), previousRevisionID: nil)
        let saved = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: draft.id, editRevision: 1,
            text: "这是一条理解")
        let note = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: saved.id, expectedEditRevision: 1)
        try await repo.saveSourceLink(MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .understanding,
            ownerID: note.id, sourceKind: "item", sourceID: itemID.uuidString, sourceVersion: nil,
            contentHash: nil, availability: .available))

        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.viewSession(id: sessionID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        let beforeValue = try await repo.session(id: sessionID)
        let before = try XCTUnwrap(beforeValue)
        let reference = try MentorSourceReference("item:\(itemID.uuidString)")
        let details = await store.sourceDetails(for: [reference])
        let references = await store.understandingSourceReferences()
        let afterValue = try await repo.session(id: sessionID)
        let after = try XCTUnwrap(afterValue)

        XCTAssertEqual(details.first?.status, .available)
        XCTAssertEqual(details.first?.content, "这是明确保存的用户原话")
        XCTAssertEqual(references[note.id], [reference])
        XCTAssertEqual(after, before)
        XCTAssertTrue(store.state.isViewingHistory)
        XCTAssertEqual(store.state.phase, .ended)
        XCTAssertNil(store.state.acknowledgedResponseItemID)
    }

    func testLessonPreferencesResetFailureAndRetryPreserveReadingAndOtherFeedback() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let lesson = try XCTUnwrap(store.state.lesson)
        store.acknowledgeLesson()
        store.recordLessonFeedback(.alreadyKnown)
        try await waitUntil { !store.state.isSavingLessonFeedback }
        store.recordLessonFeedback(.notRelevant)
        try await waitUntil { !store.state.isSavingLessonFeedback }
        let preferences = store.makeLessonPreferencesStore()
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_known_reset BEFORE UPDATE OF revoked_at ON mentor_feedback BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        await preferences.resetKnownFeedback()
        XCTAssertNotNil(preferences.error)
        XCTAssertFalse(preferences.didReset)
        XCTAssertFalse(preferences.isResetting)
        let stillKnown = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback WHERE kind = 'already_known' AND revoked_at IS NULL") }
        XCTAssertEqual(stillKnown, 1)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_known_reset") }
        await preferences.resetKnownFeedback()
        XCTAssertNil(preferences.error)
        XCTAssertTrue(preferences.didReset)
        let kinds = try await db.dbQueue.read { try String.fetchAll($0, sql: "SELECT kind FROM mentor_feedback WHERE revoked_at IS NULL") }
        XCTAssertEqual(kinds, ["not_relevant"])
        let saved = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertNotNil(saved)
        let presented = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT presented_at FROM mentor_items WHERE id = ?", arguments: [lesson.id.uuidString]) }
        XCTAssertNotNil(presented)
        store.start(entry: "discuss", initialText: "新的交流")
        try await waitUntil { store.state.phase == .editing && store.state.session?.id != lesson.sessionID }
        XCTAssertTrue(preferences.didReset, "Global settings result survives conversation changes")
    }

    func testBenefitFeedbackPersistsPrivateNoteAndCoarseUsageEvent() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "我想确认明天先验证哪一个事实")
        try await waitUntil { store.state.phase == .showingResponse }
        let sessionID = try XCTUnwrap(store.state.session?.id)
        store.updateBenefitFeedbackNote("我把下一步验证标准写清楚了。")
        store.recordBenefitFeedback(.helped)
        try await waitUntil { !store.state.isSavingBenefitFeedback }

        let saved = try await repo.benefitFeedback(sessionID: sessionID)
        XCTAssertEqual(saved?.kind, .helped)
        XCTAssertEqual(saved?.note, "我把下一步验证标准写清楚了。")
        let usage = try await db.dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT event_kind, attributes_json FROM mentor_usage_events WHERE session_id = ? ORDER BY occurred_at", arguments: [sessionID.uuidString])
        }
        let benefitEvent = try XCTUnwrap(usage.first(where: { ($0["event_kind"] as String) == MentorUsageEventKind.benefitFeedback.rawValue }))
        let attributes = benefitEvent["attributes_json"] as String
        XCTAssertTrue(attributes.contains("benefit_helped"))
        XCTAssertFalse(attributes.contains("下一步验证标准"))

        store.viewSession(id: sessionID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.benefitFeedback?.note, "我把下一步验证标准写清楚了。")
    }

    func testLegacyOnlyHistoryAndHomePaginationCanReadBeyondOneHundredRoots() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: db)
        let repo = SQLiteMentorRepository(database: db)
        var ids: [UUID] = []
        for index in 0..<105 {
            let id = UUID()
            ids.append(id)
            let date = Date(timeIntervalSince1970: Double(10000 - index))
            try await legacy.save(SingleNudgeSession(id: id, dayKey: "2026-10-03", input: "旧记录 \(index)",
                lifecycle: .completed, result: .completed, createdAt: date, updatedAt: date))
        }
        let feature = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(),
            legacyNudgeAdapter: LegacyNudgeAdapter(database: db))
        let history = feature.makeHistoryStore()
        history.refresh()
        try await waitUntil { !history.isLoading }
        XCTAssertEqual(history.sessions.map(\.id), Array(ids.prefix(20)))
        XCTAssertTrue(history.hasMore)
        for _ in 0..<5 {
            history.loadMore()
            try await waitUntil { !history.isLoading }
            XCTAssertNil(history.error)
        }
        XCTAssertEqual(history.sessions.map(\.id), ids)
        XCTAssertFalse(history.hasMore)

        feature.loadRecentSessions()
        try await waitUntil { !feature.state.isLoadingHistory }
        XCTAssertEqual(feature.state.recentSessions.map(\.id), Array(ids.prefix(3)))
        for _ in 0..<6 {
            feature.loadMoreRecentSessions()
            try await waitUntil { !feature.state.isLoadingHistory }
            XCTAssertNil(feature.state.historyError)
        }
        XCTAssertEqual(feature.state.recentSessions.map(\.id), ids)
        XCTAssertFalse(feature.state.hasMoreRecentSessions)
    }

    func testMixedHistoryKeepsEveryRowAcrossPagesAndRefreshAfterWrapperAndDeletion() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: db)
        let repo = SQLiteMentorRepository(database: db)
        let adapter = LegacyNudgeAdapter(database: db)
        var ids: [UUID] = []
        for index in 0..<66 {
            let id = UUID()
            ids.append(id)
            let date = Date(timeIntervalSince1970: Double(10000 - index))
            if index.isMultiple(of: 2) {
                try await legacy.save(SingleNudgeSession(id: id, dayKey: "2026-10-03", input: "旧记录 \(index)",
                    lifecycle: .completed, result: .completed, createdAt: date, updatedAt: date))
            } else {
                try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .ended,
                    draftText: "新记录 \(index)", draftRevision: 1, activityAt: date))
            }
        }
        let history = MentorHistoryStore(repository: repo, legacyNudgeAdapter: adapter)
        history.refresh()
        try await waitUntil { !history.isLoading }
        for page in 1...3 {
            XCTAssertEqual(history.sessions.map(\.id), Array(ids.prefix(page * 20)))
            XCTAssertTrue(history.hasMore)
            history.loadMore()
            try await waitUntil { !history.isLoading }
        }
        XCTAssertEqual(history.sessions.map(\.id), ids)
        XCTAssertFalse(history.hasMore)

        let wrapper = try await adapter.continueChain(rootID: ids[24], at: Date(timeIntervalSince1970: 20000))
        try await repo.deleteSession(id: ids[25])
        history.refresh()
        try await waitUntil { !history.isLoading }
        XCTAssertNil(history.error)
        let expected = [wrapper.id] + ids.filter { $0 != ids[24] && $0 != ids[25] }
        XCTAssertEqual(history.sessions.map(\.id), expected)
        XCTAssertEqual(history.sessions.filter { $0.originLegacyRootID == ids[24] }.count, 1)
        XCTAssertFalse(history.hasMore)
    }

    func testMixedHistoryReadFailureDoesNotConsumeBufferedRowsOrAdvanceEitherCursor() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: db)
        let repo = SQLiteMentorRepository(database: db)
        var ids: [UUID] = []
        for index in 0..<65 {
            let id = UUID()
            ids.append(id)
            let date = Date(timeIntervalSince1970: Double(10000 - index))
            if index.isMultiple(of: 2) {
                try await legacy.save(SingleNudgeSession(id: id, dayKey: "2026-10-03", input: "旧记录 \(index)",
                    lifecycle: .completed, result: .completed, createdAt: date, updatedAt: date))
            } else {
                try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .ended,
                    draftText: "新记录 \(index)", draftRevision: 1, activityAt: date))
            }
        }
        let history = MentorHistoryStore(repository: repo, legacyNudgeAdapter: LegacyNudgeAdapter(database: db))
        history.refresh()
        try await waitUntil { !history.isLoading }
        history.loadMore()
        try await waitUntil { !history.isLoading }
        XCTAssertEqual(history.sessions.map(\.id), Array(ids.prefix(40)))
        try await db.dbQueue.write { try $0.execute(sql: "ALTER TABLE mentor_sessions RENAME TO unavailable_sessions") }
        history.loadMore()
        try await waitUntil { !history.isLoading }
        XCTAssertNotNil(history.error)
        XCTAssertEqual(history.sessions.map(\.id), Array(ids.prefix(40)))
        XCTAssertTrue(history.hasMore)
        try await db.dbQueue.write { try $0.execute(sql: "ALTER TABLE unavailable_sessions RENAME TO mentor_sessions") }
        for _ in 0..<2 {
            history.loadMore()
            try await waitUntil { !history.isLoading }
        }
        XCTAssertNil(history.error)
        XCTAssertEqual(history.sessions.map(\.id), ids)
        XCTAssertFalse(history.hasMore)
    }

    func testMixedHistoryUsesGlobalIDOrderWhenActivityTimestampsAreEqual() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: db)
        let repo = SQLiteMentorRepository(database: db)
        var ids: [UUID] = []
        let date = Date(timeIntervalSince1970: 10000)
        for index in 1...46 {
            let id = try XCTUnwrap(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index)))
            ids.append(id)
            if index.isMultiple(of: 2) {
                try await legacy.save(SingleNudgeSession(id: id, dayKey: "2026-10-03", input: "旧记录 \(index)",
                    lifecycle: .completed, result: .completed, createdAt: date, updatedAt: date))
            } else {
                try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .ended,
                    draftText: "新记录 \(index)", draftRevision: 1, activityAt: date))
            }
        }
        let history = MentorHistoryStore(repository: repo, legacyNudgeAdapter: LegacyNudgeAdapter(database: db))
        history.refresh()
        try await waitUntil { !history.isLoading }
        for _ in 0..<2 {
            history.loadMore()
            try await waitUntil { !history.isLoading }
        }
        XCTAssertNil(history.error)
        XCTAssertEqual(history.sessions.map(\.id), ids.reversed())
        XCTAssertFalse(history.hasMore)
    }

    func testHomeFindsLatestUnfinishedLegacyRootOutsidePreviewAndComparesBothSources() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: db)
        let repo = SQLiteMentorRepository(database: db)
        let legacyID = UUID(), mentorID = UUID()
        try await repo.createSession(MentorSession(id: mentorID, initialEntry: "discuss", lifecycle: .paused,
            draftText: "较早未结束交流", draftRevision: 1, activityAt: Date(timeIntervalSince1970: 500)))
        var unfinished = SingleNudgeSession(id: legacyID, dayKey: "2026-10-03", input: "还没说完的旧点拨",
            createdAt: Date(timeIntervalSince1970: 600), updatedAt: Date(timeIntervalSince1970: 600))
        try await legacy.save(unfinished)
        for index in 0..<25 {
            let date = Date(timeIntervalSince1970: Double(700 + index))
            try await legacy.save(SingleNudgeSession(dayKey: "2026-10-03", input: "较新的已结束旧点拨",
                lifecycle: .completed, result: .completed, createdAt: date, updatedAt: date))
        }
        let feature = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(),
            legacyNudgeAdapter: LegacyNudgeAdapter(database: db))
        feature.loadRecentSessions()
        try await waitUntil { !feature.state.isLoadingHistory }
        XCTAssertEqual(feature.state.recentSessions.count, 3)
        XCTAssertTrue(feature.state.recentSessions.allSatisfy { $0.lifecycle == .ended })
        XCTAssertEqual(feature.state.latestUnfinishedSession?.id, legacyID)
        unfinished.lifecycle = .completed
        unfinished.result = .completed
        try await legacy.save(unfinished)
        feature.loadRecentSessions()
        try await waitUntil { !feature.state.isLoadingHistory }
        XCTAssertEqual(feature.state.latestUnfinishedSession?.id, mentorID)
    }

    func testHistoryReadFailureKeepsLoadedRowsAndCanRetry() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        for index in 0..<21 {
            try await repo.createSession(MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .ended,
                draftText: "历史 \(index)", draftRevision: 1, activityAt: .now))
        }
        let history = MentorHistoryStore(repository: repo)
        history.refresh()
        try await waitUntil { !history.isLoading }
        let original = history.sessions
        try await db.dbQueue.write { try $0.execute(sql: "ALTER TABLE mentor_sessions RENAME TO unavailable_sessions") }
        history.loadMore()
        try await waitUntil { !history.isLoading }
        XCTAssertNotNil(history.error)
        XCTAssertEqual(history.sessions, original)
        XCTAssertTrue(history.hasMore)
        history.refresh()
        try await waitUntil { !history.isLoading }
        XCTAssertNotNil(history.error)
        XCTAssertEqual(history.sessions, original)
        try await db.dbQueue.write { try $0.execute(sql: "ALTER TABLE unavailable_sessions RENAME TO mentor_sessions") }
        history.loadMore()
        try await waitUntil { !history.isLoading }
        XCTAssertNil(history.error)
        XCTAssertEqual(history.sessions.count, 21)
        XCTAssertFalse(history.hasMore)
    }

    func testIndependentHistoryPaginationRefreshesLoadedRangeAfterDeletion() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        var ids: [UUID] = []
        for index in 0..<45 {
            let id = UUID()
            ids.append(id)
            try await repo.createSession(MentorSession(id: id, initialEntry: "discuss", lifecycle: .ended,
                draftText: "历史 \(index)", draftRevision: 1, activityAt: Date(timeIntervalSince1970: Double(1000 - index))))
        }
        let feature = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        let history = feature.makeHistoryStore()
        history.refresh()
        try await waitUntil { !history.isLoading }
        XCTAssertEqual(history.sessions.map(\.id), Array(ids.prefix(20)))
        XCTAssertTrue(history.hasMore)
        history.loadMore()
        try await waitUntil { !history.isLoading }
        XCTAssertEqual(history.sessions.count, 40)
        feature.viewSession(id: ids[25])
        try await waitUntil { feature.state.isViewingHistory && !feature.state.isTransitioningSession }
        let deleted = await feature.deleteViewedSession()
        XCTAssertTrue(deleted)
        history.refresh()
        try await waitUntil { !history.isLoading }
        XCTAssertEqual(history.sessions.map(\.id), Array(ids.filter { $0 != ids[25] }.prefix(40)))
        history.loadMore()
        try await waitUntil { !history.isLoading }
        XCTAssertEqual(history.sessions.count, 44)
        XCTAssertFalse(history.hasMore)
        feature.loadRecentSessions()
        try await waitUntil { !feature.state.isLoadingHistory }
        XCTAssertEqual(feature.state.recentSessions.count, 3)
        XCTAssertEqual(history.sessions.count, 44)
    }

    func testUnderstandingGroupDeletionReloadsHistoryAndPreservesOtherMaterial() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss", initialText: "保留交流草稿")
        try await waitUntil { store.state.phase == .editing }
        let id = try XCTUnwrap(store.state.session?.id)
        store.beginUnderstanding()
        store.saveUnderstanding(text: "整组理解")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let note = try XCTUnwrap(store.state.understanding)
        store.confirmUnderstanding()
        try await waitUntil { !store.state.isConfirmingUnderstanding }
        store.beginUnderstanding(previousRevisionID: note.id)
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let other = try await repo.beginUserUnderstanding(sessionID: id, draftID: UUID(), previousRevisionID: nil)
        _ = try await repo.saveUnderstandingDraft(sessionID: id, draftID: other.id, editRevision: 1, text: "独立理解")
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "保留原话",
            intent: "reply", contextSnapshotJSON: "{\"sources\":[{\"ref\":\"understanding:\(note.id.uuidString)\"}]}"))
        let payload = "{\"schema_version\":\"1.0.0\",\"action\":\"explain\",\"material_status\":\"usable\",\"body\":\"派生回应\",\"question\":null,\"question_purpose\":null,\"source_refs\":[],\"lesson_ref\":null,\"suggested_actions\":[]}"
        _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: payload)
        let rejected = await store.deleteViewedUnderstanding(groupID: note.groupID)
        XCTAssertFalse(rejected)
        store.viewSession(id: id)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertNotNil(store.state.response)
        let deleted = await store.deleteViewedUnderstanding(groupID: note.groupID)
        XCTAssertTrue(deleted)
        XCTAssertNil(store.state.response)
        XCTAssertNil(store.state.responseItemID)
        XCTAssertEqual(store.state.timeline.map(\.kind), [.user])
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertEqual(store.state.understandings.map(\.id), [other.id])
        XCTAssertEqual(store.state.understandingInputText, "独立理解")
        XCTAssertEqual(store.state.inputText, "保留交流草稿")
        XCTAssertEqual(store.state.session?.requestEpoch, 1)
        XCTAssertTrue(store.state.isViewingHistory)
        XCTAssertFalse(store.state.isTransitioningSession)
        XCTAssertFalse(store.state.isDeletingUnderstanding)
        XCTAssertEqual(transport.calls, 0)
        XCTAssertEqual(store.state.latestUnfinishedSession?.id, id)
    }

    func testCommittedUnderstandingDeletionDoesNotRestoreStaleDetailWhenReloadFails() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "原文")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "要删除")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let note = try XCTUnwrap(store.state.understanding)
        store.submit(text: "用户原话")
        try await waitUntil { store.state.phase == .showingResponse }
        store.viewSession(id: note.sessionID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertNotNil(store.state.response)
        try await db.dbQueue.write { db in
            try db.execute(sql: "UPDATE mentor_items SET payload_json = '{}' WHERE kind = 'assistant'")
        }
        let deleted = await store.deleteViewedUnderstanding(groupID: note.groupID)
        XCTAssertTrue(deleted, "A failed detail read must not report a committed deletion as failed")
        let notes = try await repo.understandings(sessionID: note.sessionID)
        XCTAssertTrue(notes.isEmpty)
        XCTAssertTrue(store.state.understandings.isEmpty)
        XCTAssertNil(store.state.response)
        XCTAssertTrue(store.state.timeline.isEmpty)
        XCTAssertEqual(store.state.understandingDeletionError, "理解已删除，但详情暂时无法刷新。请返回后重新打开这次交流。")
        XCTAssertFalse(store.state.isTransitioningSession)
        XCTAssertFalse(store.state.isDeletingUnderstanding)
        XCTAssertTrue(store.state.isViewingHistory)
    }

    func testUnderstandingDeletionFailurePreservesDetailAndRetrySucceeds() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "原文")
        try await waitUntil { store.state.phase == .editing }
        store.beginUnderstanding()
        store.saveUnderstanding(text: "仍需保留")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        let note = try XCTUnwrap(store.state.understanding)
        store.viewSession(id: note.sessionID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_note_delete BEFORE DELETE ON mentor_understandings BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let deleted = await store.deleteViewedUnderstanding(groupID: note.groupID)
        XCTAssertFalse(deleted)
        XCTAssertEqual(store.state.understandings, [note])
        XCTAssertEqual(store.state.understandingInputText, "仍需保留")
        XCTAssertNotNil(store.state.understandingDeletionError)
        XCTAssertFalse(store.state.isTransitioningSession)
        XCTAssertFalse(store.state.isDeletingUnderstanding)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_note_delete") }
        let retried = await store.deleteViewedUnderstanding(groupID: note.groupID)
        XCTAssertTrue(retried)
        XCTAssertTrue(store.state.understandings.isEmpty)
        XCTAssertNil(store.state.understanding)
        XCTAssertNil(store.state.understandingDeletionError)
    }

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

    func testListenWithoutApprovedCatalogFailsBeforeCreatingSession() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport)

        store.start(entry: "listen")
        try await waitUntil { !store.state.isTransitioningSession }

        XCTAssertNil(store.state.session)
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertTrue(store.state.actionError?.contains("没有可用的已审核教材") == true)
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_sessions") }
        XCTAssertEqual(count, 0)
        XCTAssertEqual(transport.calls, 0)
    }

    func testNewResponseExposesAIDraftActionAndKeepsAuditableOutput() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = MentorStoreFixtureTransport()
        transport.suggestedActions = ["draft_understanding", "reply"]
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "今天意识到交付不等于效果")
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(store.state.response?.availableSuggestedActions, [.draftUnderstanding, .reply])
        XCTAssertEqual(store.state.response?.response.suggestedActions, [.draftUnderstanding, .reply])
    }

    func testGenerateUnderstandingCreatesUnconfirmedDraftAfterResponseAcknowledgement() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        transport.suggestedActions = ["draft_understanding", "finish"]
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "我会先确认实际效果")
        try await waitUntil { store.state.phase == .showingResponse }
        let responseID = try XCTUnwrap(store.state.responseItemID)
        store.acknowledgeResponse(itemID: responseID)
        try await waitUntil { store.state.acknowledgedResponseItemID == responseID }

        store.generateUnderstanding()
        try await waitUntil { !store.state.isGeneratingUnderstanding && store.state.generatedUnderstandingID != nil }
        let draft = try XCTUnwrap(store.state.understanding)
        XCTAssertTrue(draft.isAIDraft)
        XCTAssertEqual(draft.state, .draft)
        XCTAssertEqual(draft.text, "我会先确认实际效果")
        XCTAssertEqual(transport.calls, 2)
        let requests = try await repo.items(sessionID: draft.sessionID)
        XCTAssertEqual(requests.filter { $0.kind == .assistant }.count, 1,
            "Understanding generation must not add a second assistant timeline item")
        await store.flushUsageEvents()
        let beforeConfirmation = try await usageFacts(db)
        XCTAssertEqual(beforeConfirmation.filter { $0.kind == "request_finished" && $0.attributes["reason"] == "succeeded" }.count, 2)
        XCTAssertFalse(beforeConfirmation.contains { $0.kind == "understanding_confirmed" })
        store.confirmUnderstanding()
        let flushed = await store.flushPendingEdits()
        XCTAssertTrue(flushed)
        await store.flushUsageEvents()
        let afterConfirmation = try await usageFacts(db)
        XCTAssertEqual(afterConfirmation.filter { $0.kind == "understanding_confirmed" }.count, 1)
        XCTAssertEqual(transport.calls, 2)
    }

    func testUnderstandingGenerationFailureKeepsResponseAndCanRetry() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let transport = MentorStoreFixtureTransport()
        transport.suggestedActions = ["draft_understanding", "finish"]
        transport.draftFailure = URLError(.cannotLoadFromNetwork)
        let store = MentorFeatureStore(repository: repo, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "原交流仍然保留")
        try await waitUntil { store.state.phase == .showingResponse }
        let responseID = try XCTUnwrap(store.state.responseItemID)
        store.acknowledgeResponse(itemID: responseID)
        try await waitUntil { store.state.acknowledgedResponseItemID == responseID }

        store.generateUnderstanding()
        try await waitUntil { store.state.understandingGenerationError != nil && !store.state.isGeneratingUnderstanding }
        XCTAssertEqual(store.state.phase, .showingResponse)
        XCTAssertNil(store.state.generatedUnderstandingID)
        XCTAssertEqual(store.state.responseItemID, responseID)

        transport.draftFailure = nil
        store.generateUnderstanding()
        try await waitUntil { !store.state.isGeneratingUnderstanding && store.state.generatedUnderstandingID != nil }
        XCTAssertEqual(transport.calls, 3)
        XCTAssertTrue(try XCTUnwrap(store.state.understanding).isAIDraft)
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        XCTAssertEqual(facts.filter { $0.kind == "request_finished" && $0.attributes["reason"] == "failed" }.count, 1)
        XCTAssertEqual(facts.filter { $0.kind == "request_finished" && $0.attributes["reason"] == "succeeded" }.count, 2)
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
                hasCatalog ? [.draftUnderstanding, .anotherLesson] : [.draftUnderstanding, .reply])
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
        XCTAssertNil(store.state.understanding, "An empty editor does not create a persisted draft")
        store.saveUnderstanding(text: "已保存的原句")
        try await waitUntil { store.state.understanding?.text == "已保存的原句" && store.state.pendingUnderstandingOperations == 0 }
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
        XCTAssertNil(store.state.understanding)
        store.saveUnderstanding(text: "原句")
        store.updateUnderstandingText("临时修改")
        store.updateUnderstandingText("原句")
        try await waitUntil { store.state.pendingUnderstandingOperations == 0 }
        XCTAssertTrue(store.state.hasUnsavedUnderstanding)
        let materializedID = try XCTUnwrap(store.state.understanding?.id)
        store.beginUnderstanding()
        XCTAssertEqual(store.state.understanding?.id, materializedID)
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

    func testMentorQualityGateRejectsUngroundedModelResponseBeforePresentation() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: UngroundedMentorTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }

        store.submit(text: "我完成了改动，但还不知道效果")
        try await waitUntil {
            if case .failed = store.state.phase { return true }
            return false
        }
        XCTAssertTrue(store.state.timeline.contains { $0.kind == .user })
        XCTAssertFalse(store.state.timeline.contains { $0.kind == .assistant },
            "a quality-gated response must not reach the conversation timeline")
        XCTAssertNotNil(store.state.retryableRequest)
    }

    func testProductionCatalogReadsSwitchesFeedbackAndRestoresWithoutNetwork() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repository = SQLiteMentorRepository(database: db)
        let transport = FailingMentorTransport(result: .failure(LLMClientError.missingAPIKey))
        let store = MentorFeatureStore(repository: repository, transport: transport, catalog: try MentorLessonCatalog.loadBundled())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading && !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.lesson?.lesson.id, "L01")
        store.acknowledgeLesson()
        store.recordLessonFeedback(.alreadyKnown)
        store.selectAnotherLesson()
        try await waitUntil { store.state.lesson?.lesson.id == "L02" && !store.state.isTransitioningSession }
        store.acknowledgeLesson()
        await store.flushPendingEdits()
        let id = try XCTUnwrap(store.state.session?.id)
        let restored = MentorFeatureStore(repository: repository, transport: transport, catalog: try MentorLessonCatalog.loadBundled())
        restored.continueSession(id: id)
        try await waitUntil { restored.state.session?.id == id && !restored.state.isTransitioningSession }
        XCTAssertEqual(restored.state.lesson?.lesson.id, "L02")
        restored.finish()
        try await waitUntil { restored.state.phase == .ended && !restored.state.isTransitioningSession }
        XCTAssertEqual(transport.calls, 0)
    }

    func testTransportEnvelopePersistsProtocolContentAndReplaysAfterRestart() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repository = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repository, transport: EnvelopeMentorTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.submit(text: "真实接口会返回响应包")
        try await waitUntil { store.state.phase == .showingResponse }
        let id = try XCTUnwrap(store.state.session?.id)
        let response = try XCTUnwrap(store.state.timeline.last { $0.kind == .assistant })
        XCTAssertNoThrow(try JSONDecoder().decode(MentorTurnResponse.self, from: Data(response.payloadJSON.utf8)))
        let restored = MentorFeatureStore(repository: repository, transport: EnvelopeMentorTransport())
        restored.continueSession(id: id)
        try await waitUntil { restored.state.session?.id == id && !restored.state.isTransitioningSession }
        XCTAssertEqual(restored.state.response?.response.body, store.state.response?.response.body)
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
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        store.beginUnderstanding()
        XCTAssertNil(store.state.understanding, "An empty editor stays in memory until the first real text")
        store.saveUnderstanding(text: "我会先区分动作和效果")
        try await waitUntil { store.state.understanding?.text == "我会先区分动作和效果" && store.state.pendingUnderstandingOperations == 0 }
        XCTAssertEqual(store.state.understanding?.state, .draft)
        XCTAssertEqual(store.state.understanding?.text, "我会先区分动作和效果")
        store.confirmUnderstanding()
        try await waitUntil { store.state.understanding?.state == .confirmed && store.state.pendingUnderstandingOperations == 0 }
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

    func testLongRunningRequestShowsWaitingNoticeAndPauseClearsIt() async throws {
        let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
        let transport = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: transport,
            requestWaitingNoticeAfter: .milliseconds(5))
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }

        store.submit(text: "保留当前输入")
        try await waitUntil { transport.pending != nil }
        try await waitUntil { store.state.requestWaitingNotice }
        XCTAssertEqual(store.state.phase, .submitting)

        store.pause()
        try await waitUntil { store.state.phase == .paused }
        XCTAssertFalse(store.state.requestWaitingNotice)

        // Held transports do not observe cancellation themselves; release the
        // continuation so the cancelled request can finish without leaking.
        transport.pending?.resume(throwing: CancellationError())
        transport.pending = nil
        for _ in 0..<5 { await Task.yield() }
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

    func testModelBalanceFailureShowsActionableMessageAndPreservesTheSubmittedTurn() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repository = SQLiteMentorRepository(database: db)
        let transport = FailingMentorTransport(result: .failure(LLMClientError.httpStatus(429,
            Data(#"{"error":{"code":"1113","message":"provider diagnostic"}}"#.utf8))))
        let store = MentorFeatureStore(repository: repository, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "这段原话应当保留")
        try await waitUntil { if case .failed = store.state.phase { return true }; return false }

        XCTAssertTrue(store.state.requestFailureMessage?.contains("余额不足") == true)
        XCTAssertFalse(store.state.requestFailureMessage?.contains("provider diagnostic") == true)
        XCTAssertEqual(transport.calls, 1, "A quota failure must not trigger automatic retries")
        let sessionID = try XCTUnwrap(store.state.session?.id)
        let items = try await repository.items(sessionID: sessionID)
        XCTAssertEqual(items.filter { $0.kind == .user }.count, 1)
        XCTAssertTrue(items.first { $0.kind == .user }?.payloadJSON.contains("这段原话应当保留") == true)
        XCTAssertNotNil(store.state.retryableRequest)

        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && store.state.session?.id != sessionID }
        XCTAssertNil(store.state.requestFailureMessage)
        XCTAssertEqual(transport.calls, 1)
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
        XCTAssertNil(payload.latestUserSourceRef)
        XCTAssertTrue(payload.currentExchangeRefs.isEmpty)
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
        XCTAssertTrue(store.state.isViewingHistory)
        store.recordLessonFeedback(.alreadyKnown)
        store.saveReadingPosition(itemID: lesson.id, section: .title)
        let feedbackCount = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback") }
        XCTAssertEqual(feedbackCount, 0)
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
        XCTAssertTrue(store.state.lessonFeedbackNotice?.contains("以后不再自动推荐") == true)
        store.resetKnownLessonFeedback()
        try await waitUntil { !store.state.isSavingLessonFeedback }
        XCTAssertNil(store.state.lessonFeedbackError)
        XCTAssertTrue(store.state.lessonFeedbackNotice?.contains("已重置") == true)
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
        XCTAssertNil(store.state.lessonFeedbackNotice)
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
        try await waitUntil { store.state.phase == .reading }
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
        // Both items can become visible in one geometry callback after resume.
        // The lesson receipt must not swallow the response receipt behind it.
        let responseID = try XCTUnwrap(restored.state.responseItemID)
        restored.acknowledgeLesson()
        restored.acknowledgeResponse(itemID: responseID)
        restored.acknowledgeLesson()
        restored.acknowledgeResponse(itemID: responseID)
        try await waitUntil { restored.state.acknowledgedResponseItemID == responseID }
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

    func testLateReadingEventsCannotOverwritePositionDuringNavigationOrAfterExit() async throws {
        for ending in [false, true] {
            let repo = SQLiteMentorRepository(database: try AppDatabase(dbQueue: DatabaseQueue()))
            let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
            store.start(entry: "listen")
            try await waitUntil { store.state.phase == .reading }
            let lesson = try XCTUnwrap(store.state.lesson)
            store.saveReadingPosition(itemID: lesson.id, section: .example)
            if ending { store.finish() } else { store.pause() }
            XCTAssertTrue(store.state.isTransitioningSession)
            store.saveReadingPosition(itemID: lesson.id, section: .boundary)
            try await waitUntil { !store.state.isTransitioningSession }
            XCTAssertEqual(store.state.phase, ending ? .ended : .paused)
            store.saveReadingPosition(itemID: lesson.id, section: .claim)
            let saved = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
            XCTAssertEqual(saved?.readingSection, .example)
            XCTAssertEqual(saved?.readingRevision, 1)
            XCTAssertEqual(store.state.lesson?.readingSection, .example)
            store.continueSession(id: lesson.sessionID)
            store.saveReadingPosition(itemID: lesson.id, section: .title)
            try await waitUntil { !store.state.isTransitioningSession }
            XCTAssertEqual(store.state.lesson?.readingSection, .example)
            store.saveReadingPosition(itemID: lesson.id, section: .boundary)
            try await waitUntil { store.state.pendingReadingPositionSaves == 0 }
            let resumed = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
            XCTAssertEqual(resumed?.readingSection, .boundary)
        }
    }

    func testReadingOffsetSurvivesPauseContinueAndFailureRetry() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport(), catalog: try catalog())
        store.start(entry: "listen")
        try await waitUntil { store.state.phase == .reading }
        let lesson = try XCTUnwrap(store.state.lesson)
        store.saveReadingPosition(itemID: lesson.id, section: .example, offset: 120, layoutKey: "402/large")
        store.pause()
        try await waitUntil { !store.state.isTransitioningSession }
        store.continueSession(id: lesson.sessionID)
        try await waitUntil { !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.phase, .reading, "Continuing a lesson must enable feedback and local next-lesson actions")
        XCTAssertEqual(store.state.lesson?.readingOffset, 120)
        XCTAssertEqual(store.state.lesson?.readingLayoutKey, "402/large")
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_offset BEFORE UPDATE OF reading_offset ON mentor_lesson_snapshots BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        store.saveReadingPosition(itemID: lesson.id, section: .example, offset: 240, layoutKey: "402/large")
        try await waitUntil { store.state.pendingReadingPositionSaves == 0 }
        XCTAssertNotNil(store.state.readingPositionError)
        XCTAssertEqual(store.state.lesson?.readingOffset, 240)
        let beforeRetry = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertEqual(beforeRetry?.readingOffset, 120)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_offset") }
        store.retryReadingPositionSave()
        try await waitUntil { store.state.pendingReadingPositionSaves == 0 }
        XCTAssertNil(store.state.readingPositionError)
        let afterRetry = try await repo.savedLesson(sessionID: lesson.sessionID, itemID: lesson.id)
        XCTAssertEqual(afterRetry?.readingOffset, 240)
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
        try await waitUntil { !store.state.isTransitioningSession && store.state.phase == .reading }
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
        XCTAssertEqual(sent.prompt.version, "2.17.0")
        XCTAssertEqual(sent.decisionRoute, .coaching)
        XCTAssertNotEqual(sent.prompt.userText, sent.inputSummary)
        let token = try XCTUnwrap(sent.mentorAuditToken)
        let snapshot = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT context_snapshot_json FROM mentor_requests WHERE id = ?", arguments: [token.requestID.uuidString]) }
        XCTAssertEqual(snapshot, sent.inputSummary)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8))
        XCTAssertNotNil(context.latestUserSourceRef)
        XCTAssertEqual(context.currentExchangeRefs.count, 1)
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
        let store = MentorFeatureStore(repository: repo, transport: old, promptProvider: oldProvider, requestPolicy: .responses)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "提交时捕获配置")
        oldProvider.version = "changed-after-submit"
        store.updateDependencies(transport: new, promptProvider: MentorTestPromptProvider(), requestPolicy: .m1)
        try await waitUntil { old.pending != nil }
        XCTAssertEqual(new.calls, 0)
        let originalRequest = try XCTUnwrap(old.request)
        XCTAssertEqual(originalRequest.prompt.version, "1.0.0")
        XCTAssertEqual(originalRequest.mentorExecutionPolicy, .responses)
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
        XCTAssertEqual(new.lastRequest?.mentorExecutionPolicy, .m1)
        XCTAssertEqual(new.lastRequest?.prompt.version, "test-injected.2")
    }

    func testConfigurationChangeInterruptsInFlightRequestAndRejectsLateResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let held = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: held)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "配置变化前的原话")
        try await waitUntil { held.pending != nil }
        let request = try XCTUnwrap(held.request)
        let sessionID = try XCTUnwrap(store.state.session?.id)

        store.configurationDidChange()
        try await waitUntil { store.state.phase == .editing }
        for _ in 0..<200 {
            if (try await repo.session(id: sessionID))?.requestEpoch == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let refreshedSession = try await repo.session(id: sessionID)
        XCTAssertEqual(refreshedSession?.requestEpoch, 1)
        let interrupted = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.mentorAuditToken!.requestID.uuidString]) }
        XCTAssertEqual(interrupted, "interrupted")

        held.pending?.resume(returning: try await MentorStoreFixtureTransport().complete(request))
        held.pending = nil
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(held.wasCancelled)
        XCTAssertFalse(store.state.timeline.contains { $0.kind != .user }, "a late response from the old configuration must not be committed")
        XCTAssertEqual(store.state.retryableRequest?.id, request.mentorAuditToken?.requestID)
        XCTAssertEqual(store.state.inputText, "配置变化前的原话")
        await store.flushUsageEvents()
        let facts = try await usageFacts(db)
        XCTAssertEqual(facts.filter { $0.kind == "request_finished" }.count, 1)
        XCTAssertEqual(facts.first { $0.kind == "request_finished" }?.attributes["reason"], "interrupted")
    }

    func testStoreDeadlineTimesOutHeldRequestAndRejectsLateResponse() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let held = HeldMentorTransport()
        let store = MentorFeatureStore(repository: repo, transport: held,
            requestWaitingNoticeAfter: .milliseconds(2), requestDeadlineAfter: .milliseconds(20))
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing }
        store.submit(text: "需要一个明确的超时边界")
        try await waitUntil { held.pending != nil }
        let request = try XCTUnwrap(held.request)
        let sessionID = try XCTUnwrap(store.state.session?.id)

        try await waitUntil {
            if case .failed = store.state.phase { return store.state.retryableRequest != nil }
            return false
        }
        XCTAssertFalse(store.state.requestWaitingNotice)
        XCTAssertNotNil(store.state.retryableRequest)

        let state = try await db.dbQueue.read { try String.fetchOne($0,
            sql: "SELECT state FROM mentor_requests WHERE id = ?",
            arguments: [request.mentorAuditToken!.requestID.uuidString]) }
        XCTAssertEqual(state, MentorRequestEndReason.timedOut.rawValue)
        XCTAssertEqual(store.state.session?.id, sessionID)

        held.pending?.resume(returning: try await MentorStoreFixtureTransport().complete(request))
        held.pending = nil
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(held.wasCancelled)
        XCTAssertFalse(store.state.timeline.contains { $0.kind != .user }, "a late response after the store deadline must be ignored")
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
        XCTAssertNil(before, "A blank entry stays in memory until the first draft flush.")
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

    func testDiscardUnsavedDraftAndExitKeepsLastPersistedDraft() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let store = MentorFeatureStore(repository: repo, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss", initialText: "已保存的草稿")
        try await waitUntil { store.state.phase == .editing && !store.state.hasUnsavedDraft }
        let id = try XCTUnwrap(store.state.session?.id)

        try await db.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER fail_discard_exit BEFORE UPDATE OF draft_text ON mentor_sessions WHEN NEW.draft_revision > OLD.draft_revision BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        store.updateInputText("确认后会放弃的未保存文字")
        store.pause()
        try await waitUntil { !store.state.isTransitioningSession && store.state.draftSaveError != nil }
        let beforeDiscard = try await repo.session(id: id)
        XCTAssertEqual(beforeDiscard?.draftText, "已保存的草稿")

        let discarded = await store.discardUnsavedDraftAndExit()
        XCTAssertTrue(discarded)
        try await waitUntil { store.state.phase == .paused && !store.state.isTransitioningSession }
        let saved = try await repo.session(id: id)
        XCTAssertEqual(saved?.draftText, "已保存的草稿")
        XCTAssertEqual(store.state.inputText, "已保存的草稿")
        XCTAssertFalse(store.state.hasUnsavedDraft)
        XCTAssertNil(store.state.draftSaveError)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_discard_exit") }
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

    private struct UsageFact {
        let attemptID: String
        let sessionID: String?
        let kind: String
        let attributes: [String: String]
    }

    private func usageFacts(_ database: AppDatabase) async throws -> [UsageFact] {
        try await database.dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT attempt_id, session_id, event_kind, attributes_json FROM mentor_usage_events ORDER BY rowid").map { row in
                let json: String = row["attributes_json"]
                return UsageFact(attemptID: row["attempt_id"], sessionID: row["session_id"], kind: row["event_kind"],
                    attributes: try JSONDecoder().decode([String: String].self, from: Data(json.utf8)))
            }
        }
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
    var materialQuestions: [String] = []
    var draftFailure: Error?
    private(set) var calls = 0
    private(set) var lastRequest: LLMRequest?
    func complete(_ request: LLMRequest) async throws -> Data {
        calls += 1
        lastRequest = request
        if request.prompt.id == .mentorDraftUnderstanding, let draftFailure { throw draftFailure }
        let context = try? JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
        let source = context?.latestUserSourceRef?.value ?? context?.sources.first { $0.role == .user && $0.isCurrent }?.ref.value ??
            request.sourceRecordIDs.first ?? "item:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        if request.prompt.id == .mentorDraftUnderstanding {
            return try JSONSerialization.data(withJSONObject: [
                "schema_version": "1.0.0", "text": "我会先确认实际效果", "source_refs": [source]
            ])
        }
        if context?.initialEntry == "review", context?.sources.contains(where: { $0.role == .user }) != true {
            return try JSONSerialization.data(withJSONObject: [
                "schema_version": "1.0.0", "action": "clarify", "material_status": "missing",
                "body": "可以从最后处理的一件事、一次停顿，或一段沟通开始。",
                "question": "你想先从哪一个片段开始？", "question_purpose": "material",
                "source_refs": [], "lesson_ref": NSNull(), "suggested_actions": ["finish"]
            ])
        }
        let sourceRefs = context?.latestUserSourceRef.map { [$0.value] }
            ?? context?.sources.first { $0.role == .user && $0.isCurrent }.map { [$0.ref.value] }
            ?? []
        if !materialQuestions.isEmpty {
            return try JSONSerialization.data(withJSONObject: [
                "schema_version": "1.0.0", "action": "clarify", "material_status": "missing",
                "body": "你提到了这件事，还需要一个具体细节。", "question": materialQuestions.removeFirst(),
                "question_purpose": "material", "source_refs": sourceRefs,
                "lesson_ref": NSNull(), "suggested_actions": ["reply"]
            ])
        }
        return try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "explain", "material_status": "usable",
            "body": "把完成动作和实际效果分开看。", "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": sourceRefs, "lesson_ref": NSNull(), "suggested_actions": suggestedActions
        ])
    }
}

@MainActor
private final class HeldMentorTransport: MentorTransport {
    var pending: CheckedContinuation<Data, Error>?
    var request: LLMRequest?
    var wasCancelled = false
    var didReturn = false
    @MainActor
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

private final class UngroundedMentorTransport: MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "explain", "material_status": "usable",
            "body": "请说说你的感受", "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": [], "lesson_ref": NSNull(), "suggested_actions": ["finish"]
        ])
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

extension MentorFeatureStoreTests {
    func testSingleCaptureEntersLocallyAndFirstRequestUsesOnlySelectedMaterial() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let captures = SQLiteCaptureFragmentRepository(database: database)
        let selected = try await captures.save(CaptureFragment(rawText: "会议结束后还不确定谁验收。", dayKey: "2026-10-03"))
        _ = try await captures.save(CaptureFragment(rawText: "未选择的私人事项", dayKey: selected.dayKey))
        let repository = SQLiteMentorRepository(database: database), transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repository, transport: transport)
        let started = await store.startCaptureSession(from: selected.id)
        XCTAssertTrue(started)
        XCTAssertEqual(transport.calls, 0, "Entering or inspecting a capture must remain offline")
        XCTAssertEqual(store.state.phase, .editing)
        XCTAssertEqual(store.state.inputText, "")
        let originalItem = try XCTUnwrap(store.state.timeline.first)
        let captureRef = try MentorSourceReference("capture:\(selected.id.uuidString)")
        XCTAssertEqual(store.state.borrowedCaptureSources[originalItem.id], [captureRef])
        let details = await store.sourceDetails(for: [captureRef, try MentorSourceReference("capture:\(UUID().uuidString)")])
        XCTAssertEqual(details[0].content, selected.rawText)
        XCTAssertEqual(details[0].status, .available)
        XCTAssertFalse(details[1].isAvailable)
        store.submit()
        try await waitUntil { store.state.phase == .showingResponse }
        XCTAssertEqual(transport.calls, 1)
        let request = try XCTUnwrap(transport.lastRequest)
        let sent = try JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
        XCTAssertEqual(sent.initialEntry, "capture")
        XCTAssertEqual(sent.sources.filter { $0.role == .user }.map(\.content), [selected.rawText])
        XCTAssertEqual(request.sourceRecordIDs, ["item:\(originalItem.id.uuidString)"])
        XCTAssertFalse(request.inputSummary.contains("未选择的私人事项"))
        let savedItems = try await repository.items(sessionID: try XCTUnwrap(store.state.session).id)
        XCTAssertEqual(savedItems.filter { $0.kind == .user }.count, 1, "The selected material must not be resubmitted as a second user message")
    }

    func testCaptureSessionRestoresSourceSnapshotAndDoesNotOverwriteOriginal() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let captures = SQLiteCaptureFragmentRepository(database: database)
        let capture = try await captures.save(CaptureFragment(rawText: "我还没看清验收负责人。", dayKey: "2026-10-03"))
        let baseline = try await captures.fragments(forDayKey: capture.dayKey, statuses: nil)
        let repository = SQLiteMentorRepository(database: database)
        let store = MentorFeatureStore(repository: repository, transport: MentorStoreFixtureTransport())
        let started = await store.startCaptureSession(from: capture.id)
        XCTAssertTrue(started)
        store.updateInputText("后续补充仍是草稿")
        store.finish()
        try await waitUntil { store.state.phase == .ended && !store.state.isTransitioningSession }
        let sessionID = try XCTUnwrap(store.state.session).id
        let restored = MentorFeatureStore(repository: SQLiteMentorRepository(database: database), transport: MentorStoreFixtureTransport())
        restored.viewSession(id: sessionID)
        try await waitUntil { restored.state.isViewingHistory && !restored.state.isTransitioningSession }
        XCTAssertEqual(restored.state.inputText, "后续补充仍是草稿")
        let reference = try MentorSourceReference("capture:\(capture.id.uuidString)")
        let details = await restored.sourceDetails(for: [reference])
        XCTAssertEqual(details.first?.content, capture.rawText)
        XCTAssertEqual(details.first?.status, .available)
        let remaining = try await captures.fragments(forDayKey: capture.dayKey, statuses: nil)
        XCTAssertEqual(remaining, baseline)
    }

    func testCaptureEntryPreservesCurrentUnsavedDraftOnSaveFailureAndCanRetry() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let capture = try await SQLiteCaptureFragmentRepository(database: database).save(CaptureFragment(rawText: "下一件事", dayKey: "2026-10-03"))
        let repository = SQLiteMentorRepository(database: database)
        let store = MentorFeatureStore(repository: repository, transport: MentorStoreFixtureTransport())
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        let previousID = try XCTUnwrap(store.state.session).id
        store.updateInputText("当前未保存的文字")
        try await database.dbQueue.write {
            try $0.execute(sql: "CREATE TRIGGER fail_capture_previous_draft BEFORE UPDATE OF draft_text ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        let failed = await store.startCaptureSession(from: capture.id)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.state.session?.id, previousID)
        XCTAssertEqual(store.state.inputText, "当前未保存的文字")
        XCTAssertTrue(store.state.hasUnsavedDraft)
        XCTAssertFalse(store.state.isTransitioningSession)
        try await database.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_capture_previous_draft") }
        let retried = await store.startCaptureSession(from: capture.id)
        XCTAssertTrue(retried)
        let previous = try await repository.session(id: previousID)
        XCTAssertEqual(previous?.lifecycle, .paused)
        XCTAssertEqual(previous?.draftText, "当前未保存的文字")
        XCTAssertNotEqual(store.state.session?.id, previousID)
        let attempts = try await database.dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT session_id, attributes_json FROM mentor_usage_events WHERE event_kind = 'entry_started'")
                .compactMap { row -> (String?, String)? in
                    let attributes: String = row["attributes_json"]
                    let object = try JSONDecoder().decode([String: String].self, from: Data(attributes.utf8))
                    return object["entry"] == "capture" ? (row["session_id"], attributes) : nil
                }
        }
        XCTAssertEqual(attempts.count, 2, "The failed entry remains an attempt alongside the successful retry")
        XCTAssertTrue(attempts.contains { $0.0 == nil })
        XCTAssertTrue(attempts.contains { $0.0 == store.state.session?.id.uuidString })
        XCTAssertTrue(attempts.allSatisfy { !$0.1.contains("当前未保存的文字") && !$0.1.contains("下一件事") })
    }
}

extension MentorFeatureStoreTests {
    func testFirstDebouncedUnderstandingEditCreatesDraftBeforeSavingAndConfirmsWithoutModel() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let repository = SQLiteMentorRepository(database: database), transport = MentorStoreFixtureTransport()
        let store = MentorFeatureStore(repository: repository, transport: transport)
        store.start(entry: "discuss")
        try await waitUntil { store.state.phase == .editing && !store.state.isTransitioningSession }
        let sessionID = try XCTUnwrap(store.state.session).id
        store.beginUnderstanding()
        XCTAssertNil(store.state.understanding)
        let before = try await repository.session(id: sessionID)
        XCTAssertNil(before, "An empty editor must stay in memory")
        store.updateUnderstandingText("我需要先确认谁负责验收。")
        try await waitUntil { store.state.understanding?.text == "我需要先确认谁负责验收。" && store.state.pendingUnderstandingOperations == 0 }
        XCTAssertFalse(store.state.hasUnsavedUnderstanding)
        XCTAssertNil(store.state.understandingError)
        store.confirmUnderstanding()
        try await waitUntil { store.state.understanding?.state == .confirmed && store.state.pendingUnderstandingOperations == 0 }
        let notes = try await repository.understandings(sessionID: sessionID)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.text, "我需要先确认谁负责验收。")
        XCTAssertEqual(transport.calls, 0)
    }
}


extension MentorFeatureStoreTests {
    func testLegacyHistoryAndContinuedSourcesRemainScopedReadOnlyAndRejectChangedOrMissingOriginal() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID(), foreignID = UUID()
        let original = SingleNudgeSession(id: rootID, dayKey: "2026-10-03", input: "原来的用户表达",
            question: "旧模型的问题", diagnosis: "旧模型的分析", after: "用户的回答", lifecycle: .completed)
        try await legacy.save(original)
        try await legacy.save(SingleNudgeSession(id: foreignID, dayKey: "2026-10-03", input: "无关私密历史"))
        let repository = SQLiteMentorRepository(database: database), transport = MentorStoreFixtureTransport()
        let adapter = LegacyNudgeAdapter(database: database)
        let store = MentorFeatureStore(repository: repository, transport: transport, legacyNudgeAdapter: adapter)
        let refs = try [MentorSourceReference("legacy-nudge:\(rootID.uuidString)"),
                        MentorSourceReference("legacy-nudge:\(foreignID.uuidString)")]
        store.viewSession(id: rootID)
        try await waitUntil { store.state.legacyChain?.rootID == rootID && !store.state.isTransitioningSession }
        let readOnly = await store.sourceDetails(for: refs)
        XCTAssertTrue(readOnly[0].isAvailable)
        XCTAssertFalse(readOnly[1].isAvailable)
        XCTAssertFalse(readOnly[0].content?.contains("无关私密历史") ?? true)
        let unwrapped = try await repository.session(id: rootID)
        XCTAssertNil(unwrapped, "Viewing a source must not create a Mentor wrapper")
        store.continueSession(id: rootID)
        try await waitUntil { store.state.session?.originLegacyRootID == rootID && !store.state.isViewingHistory && !store.state.isTransitioningSession }
        let sessionID = try XCTUnwrap(store.state.session?.id)
        let before = try await repository.session(id: sessionID)
        let continued = await store.sourceDetails(for: refs)
        XCTAssertEqual(continued[0].content, readOnly[0].content)
        XCTAssertFalse(continued[1].isAvailable)
        let after = try await repository.session(id: sessionID)
        XCTAssertEqual(before, after)
        XCTAssertEqual(transport.calls, 0)
        let baseline = try await legacy.session(id: rootID)
        XCTAssertEqual(baseline?.input, original.input)
        var changed = original
        changed.diagnosis = "被改写后的模型分析"
        try await legacy.save(changed)
        let mismatched = await store.sourceDetails(for: [refs[0]])
        XCTAssertFalse(mismatched[0].isAvailable)
        XCTAssertNil(mismatched[0].content)
        try await database.dbQueue.write { try $0.execute(sql: "DELETE FROM single_nudge_sessions WHERE id = ?", arguments: [rootID.uuidString]) }
        let removed = await store.sourceDetails(for: [refs[0]])
        XCTAssertFalse(removed[0].isAvailable)
        XCTAssertNil(removed[0].content)
        let preserved = try await repository.items(sessionID: sessionID)
        XCTAssertFalse(preserved.isEmpty, "Losing a borrowed source must not erase this conversation")
        XCTAssertEqual(transport.calls, 0)
    }
}

private final class EnvelopeMentorTransport: MentorTransport {
    func complete(_ request: LLMRequest) async throws -> Data {
        let data = try await MentorStoreFixtureTransport().complete(request)
        return try JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": String(decoding: data, as: UTF8.self)]]]])
    }
}

/// A scripted transport verifies request continuity, not model reasoning quality.
private final class MentorCriteriaFixtureTransport: MentorTransport {
    private(set) var requests: [LLMRequest] = []
    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
        let source = try XCTUnwrap(context.latestUserSourceRef)
        let body = requests.count == 1
            ? "兼职保留这次三百元收入，聚餐保留这次相聚时间；同一半天不能同时完整用于两件事。偏向哪边取决于你这次更想保留哪一种价值，目前没有依据替你排序。"
            : "按你补充的标准，这次我偏向陪父母聚餐：房租已经留够，两周内又没有其他相聚机会，而你明确更在意这次相聚。代价是放弃这次三百元收入；这个建议只针对你刚说的条件。"
        return try JSONSerialization.data(withJSONObject: ["schema_version": "1.0.0", "action": requests.count == 1 ? "compare" : "advise",
            "material_status": "usable", "body": body, "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": [source.value], "lesson_ref": NSNull(), "suggested_actions": ["finish"]])
    }
}
