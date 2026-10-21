import XCTest
import GRDB
@testable import MingSi

@MainActor
final class LegacyNudgeAdapterTests: XCTestCase {
    func testSummaryPaginationGroupsRoundsUsesExactCursorAndHidesWrappedRoots() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let adapter = LegacyNudgeAdapter(database: database)
        let rootID = UUID(), secondID = UUID(), olderID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-10-03", input: String(repeating: "原", count: 100),
            lifecycle: .completed, result: .completed, createdAt: date(100), updatedAt: date(100)))
        try await legacy.save(SingleNudgeSession(dayKey: "2026-10-03", input: "子轮次", parentSessionID: rootID,
            rootSessionID: rootID, createdAt: date(101), updatedAt: date(102.25)))
        try await legacy.save(SingleNudgeSession(id: secondID, dayKey: "2026-10-03", input: "第二根",
            lifecycle: .completed, result: .completed, createdAt: date(102.1), updatedAt: date(102.1)))
        try await legacy.save(SingleNudgeSession(id: olderID, dayKey: "2026-10-03", input: "第三根",
            lifecycle: .completed, result: .completed, createdAt: date(99), updatedAt: date(99)))
        let first = try await adapter.recentSummaries(limit: 1)
        XCTAssertEqual(first.sessions.map(\.id), [rootID])
        XCTAssertEqual(first.sessions[0].activityAt, date(102.25))
        XCTAssertEqual(first.sessions[0].lifecycle, .paused)
        XCTAssertEqual(first.sessions[0].preview, String(repeating: "原", count: 80))
        let cursor = try XCTUnwrap(first.nextCursor)
        _ = try await adapter.deleteLegacyChain(rootID: rootID)
        let next = try await adapter.recentSummaries(after: cursor, limit: 1)
        XCTAssertEqual(next.sessions.map(\.id), [secondID])
        let wrapper = try await adapter.continueChain(rootID: secondID)
        let remaining = try await adapter.recentSummaries()
        XCTAssertEqual(remaining.sessions.map(\.id), [olderID])
        XCTAssertNil(remaining.nextCursor)
        let savedWrapper = try await SQLiteMentorRepository(database: database).session(id: wrapper.id)
        XCTAssertEqual(savedWrapper?.originLegacyRootID, secondID)
    }

    func testSummaryReadingDoesNotLoadPromptAuditsOrRequireIntactLineage() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let rootID = UUID(), orphanID = UUID()
        try await SQLiteSingleNudgeSessionRepository(database: database).save(SingleNudgeSession(id: orphanID,
            dayKey: "2026-10-03", input: " 保留缺根记录 ", parentSessionID: UUID(), rootSessionID: rootID,
            createdAt: date(100), updatedAt: date(101)))
        try await database.dbQueue.write { try $0.execute(sql: "ALTER TABLE prompt_runs RENAME TO unavailable_prompt_runs") }
        let summaries = try await LegacyNudgeAdapter(database: database).recentSummaries()
        XCTAssertEqual(summaries.sessions.map(\.id), [rootID])
        XCTAssertEqual(summaries.sessions.first?.preview, "保留缺根记录")
        XCTAssertEqual(summaries.sessions.first?.lifecycle, .paused)
        let wrappers = try await database.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_sessions") }
        XCTAssertEqual(wrappers, 0)
    }

    func testLoadsCompleteChainAndBothPromptRunsWithoutCopyingBeforeContinue() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        let childID = UUID()
        let questionRunID = UUID()
        let reviewRunID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "根输入",
            question: "根问题", diagnosis: "根诊断", before: "之前", after: "之后",
            promptRunID: questionRunID, reviewPromptRunID: reviewRunID,
            rootSessionID: rootID, createdAt: date(100), updatedAt: date(100)))
        try await legacy.save(SingleNudgeSession(id: childID, dayKey: "2026-09-17", input: "第二轮输入",
            question: "第二轮问题", diagnosis: "第二轮诊断", after: "第二轮回答",
            parentSessionID: rootID, rootSessionID: rootID,
            continuationKind: .deeper, createdAt: date(101), updatedAt: date(102)))
        let prompts = SQLitePromptRunRepository(database: database)
        try await prompts.savePromptRun(prompt(id: questionRunID, created: date(100), label: "question"))
        try await prompts.savePromptRun(prompt(id: reviewRunID, created: date(100), label: "review"))

        let adapter = LegacyNudgeAdapter(database: database)
        let loadedChain = try await adapter.chain(rootID: rootID)
        let chain = try XCTUnwrap(loadedChain)
        XCTAssertTrue(chain.canContinueAutomatically)
        XCTAssertEqual(chain.rounds.map(\.id), [rootID, childID])
        XCTAssertEqual(chain.rounds[0].promptRun?.id, questionRunID)
        XCTAssertEqual(chain.rounds[0].reviewPromptRun?.id, reviewRunID)
        XCTAssertEqual(chain.rounds[1].session.after, "第二轮回答")
        let recent = try await adapter.recentChains(limit: 20)
        XCTAssertEqual(recent.map(\.id), [rootID])
        let wrapped = try await adapter.wrappedSession(rootID: rootID)
        XCTAssertNil(wrapped)
        let wrappers = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_sessions") ?? 0
        }
        XCTAssertEqual(wrappers, 0, "Read-only legacy inspection must not copy a wrapper")
    }

    func testContinueIsIdempotentProjectsReadOnlyTimelineAndHidesLegacyRoot() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        let childID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "先说一件事",
            question: "你真正担心什么？", diagnosis: "证据还不够", before: "模糊", after: "先找证据",
            rootSessionID: rootID, createdAt: date(200), updatedAt: date(200)))
        try await legacy.save(SingleNudgeSession(id: childID, dayKey: "2026-09-17", input: "补充事实",
            question: "哪个事实会改变判断？", diagnosis: "待验证", after: "确认边界",
            parentSessionID: rootID, rootSessionID: rootID, createdAt: date(201), updatedAt: date(201)))
        let adapter = LegacyNudgeAdapter(database: database)

        let first = try await adapter.continueChain(rootID: rootID, at: date(210))
        let replay = try await adapter.continueChain(rootID: rootID, at: date(211))
        XCTAssertEqual(first.id, replay.id)
        XCTAssertEqual(first.originLegacyRootID, rootID)
        XCTAssertEqual(first.activityAt, date(210))
        let recent = try await adapter.recentChains(limit: 20)
        XCTAssertEqual(recent.count, 0)

        let mentor = SQLiteMentorRepository(database: database)
        let items = try await mentor.items(sessionID: first.id)
        XCTAssertEqual(items.count, 4, "Each old round is projected as user input plus assistant material")
        XCTAssertEqual(items.filter { $0.kind == .user }.count, 2)
        XCTAssertEqual(items.filter { $0.kind == .assistant }.count, 2)
        let links = try await mentor.sourceLinks(sessionID: first.id)
        XCTAssertEqual(links.count, 4)
        XCTAssertTrue(links.allSatisfy { $0.sourceKind == "legacy-nudge" })
        XCTAssertTrue(items.allSatisfy { $0.payloadJSON.contains("legacy-nudge") || $0.kind == .user })
    }

    func testBrokenLineageIsReadableButCannotAutoContinueAndAllowsExplicitBorrowedRound() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        let orphanID = UUID()
        let missingParentID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "仍然有效的原话",
            question: "原来的问题", diagnosis: "原来的判断", rootSessionID: rootID,
            createdAt: date(300), updatedAt: date(300)))
        try await legacy.save(SingleNudgeSession(id: orphanID, dayKey: "2026-09-17", input: "孤立轮次",
            question: "孤立问题", parentSessionID: missingParentID, rootSessionID: rootID,
            createdAt: date(301), updatedAt: date(301)))
        let adapter = LegacyNudgeAdapter(database: database)
        let loadedChain = try await adapter.chain(rootID: rootID)
        let chain = try XCTUnwrap(loadedChain)
        XCTAssertFalse(chain.canContinueAutomatically)
        XCTAssertTrue(chain.issues.contains(.missingParent(roundID: orphanID, parentID: missingParentID)))
        do {
            _ = try await adapter.continueChain(rootID: rootID)
            XCTFail("Broken lineage must not be continued automatically")
        } catch {
            XCTAssertEqual(error as? LegacyNudgeAdapterError, .ambiguousLineage(rootID))
        }

        let independent = try await adapter.startIndependentSession(fromRoundID: orphanID, at: date(302))
        XCTAssertNil(independent.originLegacyRootID, "A selected old fragment only borrows its source")
        let mentor = SQLiteMentorRepository(database: database)
        let links = try await mentor.sourceLinks(sessionID: independent.id)
        XCTAssertEqual(Set(links.map(\.sourceID)), Set([orphanID.uuidString]))
        let orphan = try await legacy.session(id: orphanID)
        XCTAssertNotNil(orphan)
    }

    func testCycleIsExplicitlyReported() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        let childID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "环起点",
            parentSessionID: childID, rootSessionID: rootID, createdAt: date(400), updatedAt: date(400)))
        try await legacy.save(SingleNudgeSession(id: childID, dayKey: "2026-09-17", input: "环下一轮",
            parentSessionID: rootID, rootSessionID: rootID, createdAt: date(401), updatedAt: date(401)))
        let loadedChain = try await LegacyNudgeAdapter(database: database).chain(rootID: rootID)
        let chain = try XCTUnwrap(loadedChain)
        XCTAssertFalse(chain.canContinueAutomatically)
        XCTAssertTrue(chain.issues.contains { issue in
            if case .cycle = issue { return true }
            return false
        })
    }

    func testDeletingWrapperRemovesOwnedLegacyGraphAndPrivateRequestsWithoutGhostRoot() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        let promptID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "要删除的旧交流",
            question: "旧问题", diagnosis: "旧判断", promptRunID: promptID, rootSessionID: rootID,
            createdAt: date(500), updatedAt: date(500)))
        try await SQLitePromptRunRepository(database: database).savePromptRun(
            prompt(id: promptID, created: date(500), label: "legacy-owned")
        )
        let adapter = LegacyNudgeAdapter(database: database)
        let wrapper = try await adapter.continueChain(rootID: rootID, at: date(501))
        let mentor = SQLiteMentorRepository(database: database)
        _ = try await mentor.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: wrapper.id,
            text: "包装后的新原话", intent: "reply", contextSnapshotJSON: "{}"))
        let deleted = try await adapter.deleteWrapper(sessionID: wrapper.id)
        XCTAssertEqual(deleted.rootID, rootID)
        XCTAssertEqual(deleted.deletedRoundCount, 1)
        let removedWrapper = try await mentor.session(id: wrapper.id)
        let removedRoot = try await legacy.session(id: rootID)
        let recent = try await adapter.recentChains(limit: 20)
        XCTAssertNil(removedWrapper)
        XCTAssertNil(removedRoot)
        XCTAssertTrue(recent.isEmpty)
        let promptCount = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM prompt_runs WHERE id = ?", arguments: [promptID.uuidString]) ?? 0
        }
        XCTAssertEqual(promptCount, 0, "Deleting a legacy chain removes its owned audit copy")
        let privateRequests = try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mentor_requests") ?? 0
        }
        XCTAssertEqual(privateRequests, 0)
    }

    func testMentorStoreViewsLegacyRootAndContinuesOnlyAfterExplicitAction() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "历史原话",
            question: "历史问题", diagnosis: "历史判断", after: "历史回答", rootSessionID: rootID,
            lifecycle: .completed, result: .completed, createdAt: date(600), updatedAt: date(600)))
        let mentor = SQLiteMentorRepository(database: database)
        let store = MentorFeatureStore(repository: mentor, transport: FixtureTransport(),
            legacyNudgeAdapter: LegacyNudgeAdapter(database: database))
        store.loadRecentSessions(limit: 3)
        try await waitUntil { !store.state.isLoadingHistory }
        XCTAssertEqual(store.state.recentSessions.first?.originLegacyRootID, rootID)

        store.viewSession(id: rootID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .assistant }.count, 1)
        let beforeContinueWrapper = try await LegacyNudgeAdapter(database: database).wrappedSession(rootID: rootID)
        XCTAssertNil(beforeContinueWrapper)

        store.continueSession(id: rootID)
        try await waitUntil { !store.state.isViewingHistory && !store.state.isTransitioningSession }
        let wrappedID = try XCTUnwrap(store.state.session?.id)
        XCTAssertNotEqual(wrappedID, rootID)
        XCTAssertEqual(store.state.session?.originLegacyRootID, rootID)

        store.viewSession(id: wrappedID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        let deleted = await store.deleteViewedSession()
        XCTAssertTrue(deleted)
        let recent = try await LegacyNudgeAdapter(database: database).recentChains(limit: 20)
        XCTAssertTrue(recent.isEmpty)
    }

    func testDamagedLegacyLineageStaysReadableAndCanBorrowOneRoundExplicitly() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID()
        let orphanID = UUID()
        let missingParentID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-09-17", input: "完整保留的旧原话",
            question: "先看哪个事实？", diagnosis: "需要补证据", after: "从一条事实开始", rootSessionID: rootID,
            lifecycle: .completed, result: .completed, createdAt: date(700), updatedAt: date(700)))
        try await legacy.save(SingleNudgeSession(id: orphanID, dayKey: "2026-09-17", input: "孤立的旧轮次",
            question: "孤立问题", diagnosis: "无法确认", parentSessionID: missingParentID, rootSessionID: rootID,
            lifecycle: .completed, result: .completed, createdAt: date(701), updatedAt: date(701)))

        let mentor = SQLiteMentorRepository(database: database)
        let store = MentorFeatureStore(repository: mentor, transport: FixtureTransport(),
            legacyNudgeAdapter: LegacyNudgeAdapter(database: database))
        store.viewSession(id: rootID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.legacyChain?.canContinueAutomatically, false)
        XCTAssertEqual(store.state.legacyChain?.rounds.count, 2)

        store.continueSession(id: rootID)
        try await waitUntil { store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertEqual(store.state.legacyChain?.canContinueAutomatically, false,
                       "A damaged chain must not silently become a normal continuation")

        store.startIndependentLegacySession(fromRoundID: rootID)
        try await waitUntil { !store.state.isViewingHistory && !store.state.isTransitioningSession }
        XCTAssertNil(store.state.legacyChain)
        XCTAssertNil(store.state.session?.originLegacyRootID)
        XCTAssertEqual(store.state.phase, .showingResponse)
        XCTAssertEqual(store.state.timeline.filter { $0.kind == .assistant }.count, 1)
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    private func prompt(id: UUID, created: Date, label: String) -> PromptRun {
        PromptRun(id: id, promptId: PromptID.singleNudge.rawValue, promptVersion: "1.1.0",
            outputSchemaVersion: 1, modelProvider: "test", modelName: "legacy", sessionMode: "standard",
            sourceRecordIds: [label], requestSummary: label, responseJSON: "{\"ok\":true}",
            createdAt: created)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for legacy adapter state")
    }

    private struct FixtureTransport: MentorTransport {
        func complete(_ request: LLMRequest) async throws -> Data {
            Data("{\"schema_version\":\"1.0.0\",\"action\":\"close\",\"material_status\":\"not_needed\",\"body\":\"完成\",\"question\":null,\"question_purpose\":null,\"source_refs\":[],\"lesson_ref\":null,\"suggested_actions\":[]}".utf8)
        }
    }
}


extension LegacyNudgeAdapterTests {
    func testSourceReadsOnlyExplicitlyLinkedRoundsAndTheirPromptRunsWithoutWriting() async throws {
        let database = try AppDatabase(dbQueue: DatabaseQueue())
        let legacy = SQLiteSingleNudgeSessionRepository(database: database)
        let rootID = UUID(), otherID = UUID(), questionID = UUID(), reviewID = UUID()
        try await legacy.save(SingleNudgeSession(id: rootID, dayKey: "2026-10-03", input: "选中原话", question: "选中问题",
            promptRunID: questionID, reviewPromptRunID: reviewID))
        try await legacy.save(SingleNudgeSession(id: otherID, dayKey: "2026-10-03", input: "无关私人记录"))
        let prompts = SQLitePromptRunRepository(database: database)
        try await prompts.savePromptRun(prompt(id: questionID, created: date(100), label: "question"))
        try await prompts.savePromptRun(prompt(id: reviewID, created: date(100), label: "review"))
        let adapter = LegacyNudgeAdapter(database: database)
        let session = try await adapter.continueChain(rootID: rootID)
        let repository = SQLiteMentorRepository(database: database)
        let before = try await repository.items(sessionID: session.id)
        let rounds = try await adapter.sourceRounds(sessionID: session.id, roundIDs: [rootID, otherID])
        XCTAssertEqual(rounds.map(\.id), [rootID])
        XCTAssertEqual(rounds.first?.promptRun?.id, questionID)
        XCTAssertEqual(rounds.first?.reviewPromptRun?.id, reviewID)
        let foreign = try await adapter.sourceRounds(sessionID: UUID(), roundIDs: [rootID])
        XCTAssertTrue(foreign.isEmpty)
        let historical = try await adapter.sourceRounds(sessionID: rootID, roundIDs: [rootID, otherID], historyRootID: rootID)
        XCTAssertEqual(historical.map(\.id), [rootID])
        let links = try await repository.sourceLinks(sessionID: session.id)
        XCTAssertTrue(links.allSatisfy { $0.contentHash == MentorSourceResolver.hash(MentorSourceResolver.legacyContent(rounds[0].session)) })
        let after = try await repository.items(sessionID: session.id)
        XCTAssertEqual(before, after)
        do {
            _ = try await adapter.sourceRounds(sessionID: session.id, roundIDs: [rootID], historyRootID: rootID)
            XCTFail("A foreign legacy root cannot authorize a Mentor source lookup")
        } catch {
            XCTAssertEqual(error as? LegacyNudgeAdapterError, .invalidStoredValue("legacy_source_scope"))
        }
    }
}
