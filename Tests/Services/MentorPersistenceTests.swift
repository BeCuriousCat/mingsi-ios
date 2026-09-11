import XCTest
import GRDB
@testable import MingSi

final class MentorPersistenceTests: XCTestCase {
    private func lessonCatalog(version: String = "1.0", claim: String = "A concrete teaching claim") throws -> MentorLessonCatalog {
        let lessons = (1...24).map { index -> MentorLesson in
            func build(_ hash: String) -> MentorLesson {
                MentorLesson(id: String(format: "L%02d", index), version: version, editorialOrder: index,
                    title: "Lesson \(index)", theme: MentorLesson.Theme.allCases[(index - 1) / 4],
                    applicableContexts: ["Test fixture"], claim: claim, example: "A concrete example", boundary: "A bounded application",
                    observation: nil, sourceType: .teachingExample, citations: [], contentHash: hash,
                    review: .init(status: .approved, reviewedBy: "Test fixture only", reviewedAt: Date(timeIntervalSince1970: 0), note: nil))
            }
            return build(MentorLessonCatalog.contentHash(for: build("")))
        }
        return try MentorLessonCatalog(pack: MentorLessonPack(schemaVersion: "1.0.0", packID: "fixture", version: "1.0", lessons: lessons))
    }

    private func listeningSession(_ repo: SQLiteMentorRepository) async throws -> UUID {
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .draft, draftText: "", draftRevision: 0, activityAt: .now))
        return id
    }

    func testLessonSnapshotPresentationResumeAndPosition() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue()), catalog = try lessonCatalog()
        let repo = SQLiteMentorRepository(database: db), timeZone = TimeZone(secondsFromGMT: 0)!
        let date = ISO8601DateFormatter().date(from: "2026-09-11T23:59:00Z")!
        let session = try await listeningSession(repo), item = UUID()
        let first = try await repo.selectNextLesson(sessionID: session, itemID: item, expectedEpoch: 0, catalog: catalog, at: date, timeZone: timeZone)
        XCTAssertEqual(first?.lesson.id, "L01")
        let replay = try await repo.selectNextLesson(sessionID: session, itemID: item, expectedEpoch: 0, catalog: catalog, at: date, timeZone: timeZone)
        XCTAssertEqual(first, replay)
        let foreignSession = try await listeningSession(repo)
        let foreignRead = try await repo.savedLesson(sessionID: foreignSession, itemID: item)
        XCTAssertNil(foreignRead)
        do { _ = try await repo.selectNextLesson(sessionID: foreignSession, itemID: item, expectedEpoch: 0, catalog: catalog, at: date, timeZone: timeZone); XCTFail("Cannot replay another session's selection") } catch {}
        do { try await repo.saveReadingPosition(sessionID: foreignSession, itemID: item, revision: 1, section: .claim); XCTFail("Cannot edit another session's reading position") } catch {}
        let beforeDisplay = try await repo.listeningResume(at: date, timeZone: timeZone)
        XCTAssertNil(beforeDisplay)
        do { _ = try await repo.selectNextLesson(sessionID: session, itemID: UUID(), expectedEpoch: 0, catalog: catalog, at: date, timeZone: timeZone); XCTFail("Must acknowledge existing lesson") } catch {}
        do { try await repo.recordLessonFeedback(sessionID: session, itemID: item, commandID: UUID(), kind: .alreadyKnown, at: date); XCTFail("Unseen lesson cannot have user feedback") } catch {}
        try await repo.acknowledgePresentation(sessionID: session, itemID: item, at: date, timeZone: timeZone)
        try await repo.saveReadingPosition(sessionID: session, itemID: item, revision: 2, section: .example)
        do { try await repo.saveReadingPosition(sessionID: session, itemID: item, revision: 1, section: .claim); XCTFail("Must reject stale position") } catch {}
        do { try await repo.saveReadingPosition(sessionID: session, itemID: item, revision: 2, section: .boundary); XCTFail("Must reject conflicting position") } catch {}
        do { try await repo.saveReadingPosition(sessionID: session, itemID: item, revision: 3, section: .observation); XCTFail("Section must exist") } catch {}
        try await repo.suspendSession(id: session, ending: true, draftRevision: 0, draftText: "")
        let restored = try await SQLiteMentorRepository(database: db).listeningResume(at: date, timeZone: timeZone)
        XCTAssertEqual(restored?.readingSection, .example)
        XCTAssertEqual(restored?.lesson, first?.lesson)
        let lifecycle = try await repo.session(id: session)?.lifecycle
        XCTAssertEqual(lifecycle, .ended)
        let nextDay = try await repo.listeningResume(at: date.addingTimeInterval(120), timeZone: timeZone)
        XCTAssertNil(nextDay)
        let requests = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(requests, 0)
    }

    func testLessonFeedbackScopesResetAndCascadeRebuild() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue()), catalog = try lessonCatalog()
        let repo = SQLiteMentorRepository(database: db), zone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = try await listeningSession(repo), firstID = UUID()
        _ = try await repo.selectNextLesson(sessionID: session, itemID: firstID, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        try await repo.acknowledgePresentation(sessionID: session, itemID: firstID, at: now, timeZone: zone)
        let feedbackID = UUID()
        try await repo.recordLessonFeedback(sessionID: session, itemID: firstID, commandID: feedbackID, kind: .notRelevant, at: now)
        try await repo.recordLessonFeedback(sessionID: session, itemID: firstID, commandID: feedbackID, kind: .notRelevant, at: now)
        do { try await repo.recordLessonFeedback(sessionID: session, itemID: firstID, commandID: feedbackID, kind: .alreadyKnown, at: now); XCTFail("Feedback replay must match") } catch {}
        let rejectedResume = try await repo.listeningResume(at: now, timeZone: zone)
        XCTAssertNil(rejectedResume)
        let nextID = UUID()
        let next = try await repo.selectNextLesson(sessionID: session, itemID: nextID, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        XCTAssertEqual(next?.lesson.id, "L05", "Not relevant excludes this theme only in its session")
        try await repo.acknowledgePresentation(sessionID: session, itemID: nextID, at: now, timeZone: zone)
        let other = try await listeningSession(repo), otherItem = UUID()
        let otherLesson = try await repo.selectNextLesson(sessionID: other, itemID: otherItem, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        XCTAssertEqual(otherLesson?.lesson.id, "L02")
        try await repo.acknowledgePresentation(sessionID: other, itemID: otherItem, at: now, timeZone: zone)
        try await repo.recordLessonFeedback(sessionID: other, itemID: otherItem, commandID: UUID(), kind: .alreadyKnown, at: now)
        let reset = UUID()
        try await repo.resetKnownLessonFeedback(commandID: reset, at: now)
        try await repo.recordLessonFeedback(sessionID: other, itemID: otherItem, commandID: UUID(), kind: .alreadyKnown, at: now)
        try await repo.resetKnownLessonFeedback(commandID: reset, at: now)
        let known = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback WHERE kind = 'already_known' AND revoked_at IS NULL") }
        XCTAssertEqual(known, 1, "Old reset replay must not revoke later feedback")
        let fresh = try await listeningSession(repo)
        let afterReset = try await repo.selectNextLesson(sessionID: fresh, itemID: UUID(), expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        XCTAssertEqual(afterReset?.lesson.id, "L03", "Reset cannot bypass recent presentation facts")
        try await repo.deleteSession(id: session)
        let afterDelete = try await listeningSession(repo)
        let rebuilt = try await repo.selectNextLesson(sessionID: afterDelete, itemID: UUID(), expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        XCTAssertEqual(rebuilt?.lesson.id, "L01", "Deleting source session removes its exclusions")
        let removed = try await repo.savedLesson(sessionID: session, itemID: firstID)
        XCTAssertNil(removed)
    }

    func testLessonNaturalDayWindowVersionDedupAndClockRollback() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue()), catalog = try lessonCatalog()
        let repo = SQLiteMentorRepository(database: db), zone = TimeZone(identifier: "Asia/Shanghai")!
        let now = ISO8601DateFormatter().date(from: "2026-09-01T15:59:00Z")!
        let session = try await listeningSession(repo), item = UUID()
        _ = try await repo.selectNextLesson(sessionID: session, itemID: item, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        try await repo.acknowledgePresentation(sessionID: session, itemID: item, at: now, timeZone: zone)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        for offset in [-30, 13] {
            let other = try await listeningSession(repo)
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let selected = try await repo.selectNextLesson(sessionID: other, itemID: UUID(), expectedEpoch: 0, catalog: lessonCatalog(version: "1.1"), at: date, timeZone: zone)
            XCTAssertEqual(selected?.lesson.id, "L02", "New version and clock rollback must not erase logical-ID exclusion")
        }
        let other = try await listeningSession(repo)
        let afterWindow = calendar.date(byAdding: .day, value: 14, to: now)!
        do { _ = try await repo.selectNextLesson(sessionID: other, itemID: UUID(), expectedEpoch: 0, catalog: lessonCatalog(claim: "Changed same version"), at: afterWindow, timeZone: zone); XCTFail("Must reject altered historical version") } catch {}
        let selected = try await repo.selectNextLesson(sessionID: other, itemID: UUID(), expectedEpoch: 0, catalog: catalog, at: afterWindow, timeZone: zone)
        XCTAssertEqual(selected?.lesson.id, "L01")
        let history = try await repo.savedLesson(sessionID: session, itemID: item)
        XCTAssertEqual(history?.lesson.claim, "A concrete teaching claim")
        let differentZone = try await repo.listeningResume(at: now.addingTimeInterval(120), timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(differentZone?.id, item, "Stored local presentation day is not rewritten on time-zone change")
    }

    func testLessonSnapshotAndFeedbackResetRollback() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue()), catalog = try lessonCatalog()
        let repo = SQLiteMentorRepository(database: db), zone = TimeZone(secondsFromGMT: 0)!, now = Date()
        let session = try await listeningSession(repo), item = UUID()
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_lesson BEFORE INSERT ON mentor_lesson_snapshots BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { _ = try await repo.selectNextLesson(sessionID: session, itemID: item, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone); XCTFail("Expected rollback") } catch {}
        let items = try await repo.items(sessionID: session)
        XCTAssertTrue(items.isEmpty)
        let unchanged = try await repo.session(id: session)
        XCTAssertEqual(unchanged?.lifecycle, .draft)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_lesson") }
        _ = try await repo.selectNextLesson(sessionID: session, itemID: item, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        try await repo.acknowledgePresentation(sessionID: session, itemID: item, at: now, timeZone: zone)
        try await repo.recordLessonFeedback(sessionID: session, itemID: item, commandID: UUID(), kind: .alreadyKnown, at: now)
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_feedback_reset BEFORE UPDATE ON mentor_feedback BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let reset = UUID()
        do { try await repo.resetKnownLessonFeedback(commandID: reset, at: now); XCTFail("Expected rollback") } catch {}
        let receipts = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback_resets") }
        XCTAssertEqual(receipts, 0)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_feedback_reset") }
        try await repo.resetKnownLessonFeedback(commandID: reset, at: now)
        let known = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_feedback WHERE revoked_at IS NULL") }
        XCTAssertEqual(known, 0)
    }

    func testLessonExhaustionDoesNotCreateEmptyTimelineItem() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue()), catalog = try lessonCatalog()
        let repo = SQLiteMentorRepository(database: db), zone = TimeZone(secondsFromGMT: 0)!, now = Date()
        let session = try await listeningSession(repo)
        for expected in 1...24 {
            let item = UUID()
            let selected = try await repo.selectNextLesson(sessionID: session, itemID: item, expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
            XCTAssertEqual(selected?.lesson.editorialOrder, expected)
            try await repo.acknowledgePresentation(sessionID: session, itemID: item, at: now, timeZone: zone)
        }
        let exhausted = try await repo.selectNextLesson(sessionID: session, itemID: UUID(), expectedEpoch: 0, catalog: catalog, at: now, timeZone: zone)
        XCTAssertNil(exhausted)
        let items = try await repo.items(sessionID: session)
        XCTAssertEqual(items.count, 24)
    }

    func testUserUnderstandingConfirmationAndVersionHistory() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID(), draftID = UUID()
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "listen", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let empty = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: draftID)
        XCTAssertEqual(empty.origin, "user_note")
        XCTAssertEqual(empty.state, .draft)
        let emptyList = try await repo.recentSessions()
        XCTAssertTrue(emptyList.sessions.isEmpty)
        do { _ = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: draftID, expectedEditRevision: 0); XCTFail("Empty note must not confirm") } catch {}
        _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: draftID, editRevision: 1, text: "改完不等于效果变好")
        let confirmed = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: draftID, expectedEditRevision: 1)
        let replay = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: draftID, expectedEditRevision: 1)
        XCTAssertEqual(confirmed, replay)
        XCTAssertNotNil(confirmed.confirmedAt)
        let lateBegin = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: draftID)
        XCTAssertEqual(lateBegin, confirmed)
        do { _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: draftID, editRevision: 2, text: "overwrite"); XCTFail("Confirmed text must be immutable") } catch {}
        let nextID = UUID()
        let next = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: nextID, previousRevisionID: draftID)
        XCTAssertEqual(next.revision, 2)
        XCTAssertEqual(next.text, confirmed.text)
        XCTAssertEqual(next.groupID, confirmed.groupID)
        XCTAssertEqual(next.previousRevisionID, draftID)
        do { _ = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: UUID(), previousRevisionID: draftID); XCTFail("Must not branch from old revision") } catch {}
        _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: nextID, editRevision: 1, text: "先明确希望谁的哪一步变容易")
        // Leaving editing preserves the draft without changing the previous confirmation.
        let restored = try await SQLiteMentorRepository(database: db).understandings(sessionID: sessionID)
        XCTAssertEqual(restored.map(\.state), [.confirmed, .draft])
        XCTAssertEqual(restored.first, confirmed)
        _ = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: nextID, expectedEditRevision: 1)
        let history = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(history.map(\.revision), [1, 2])
        XCTAssertEqual(history.map(\.state), [.confirmed, .confirmed])
        let recent = try await repo.recentSessions()
        XCTAssertEqual(recent.sessions.first?.id, sessionID)
        XCTAssertEqual(recent.sessions.first?.preview, "先明确希望谁的哪一步变容易")
        let requests = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(requests, 0, "Handwritten understanding does not require model work")
        try await repo.deleteSession(id: sessionID)
        let deleted = try await repo.understandings(sessionID: sessionID)
        XCTAssertTrue(deleted.isEmpty)
    }

    func testUnderstandingRejectsStaleEditsAndForeignCommands() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID(), otherID = UUID(), draftID = UUID()
        for id in [sessionID, otherID] {
            try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        }
        _ = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: draftID)
        _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: draftID, editRevision: 2, text: "new")
        for (id, revision, text) in [(sessionID, 1, "old"), (sessionID, 2, "conflict"), (otherID, 3, "foreign")] {
            do { _ = try await repo.saveUnderstandingDraft(sessionID: id, draftID: draftID, editRevision: revision, text: text); XCTFail("Must reject invalid edit") } catch {}
        }
        for (id, revision) in [(sessionID, 1), (otherID, 2)] {
            do { _ = try await repo.confirmUnderstanding(sessionID: id, draftID: draftID, expectedEditRevision: revision); XCTFail("Must reject invalid confirmation") } catch {}
        }
        do { _ = try await repo.beginUserUnderstanding(sessionID: otherID, draftID: draftID); XCTFail("Must reject foreign command replay") } catch {}
        _ = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: draftID, expectedEditRevision: 2)
        do { _ = try await repo.beginUserUnderstanding(sessionID: otherID, draftID: UUID(), previousRevisionID: draftID); XCTFail("Must reject foreign predecessor") } catch {}
        do {
            try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_understandings SET text = 'overwrite' WHERE id = ?", arguments: [draftID.uuidString]) }
            XCTFail("Database must reject in-place changes to confirmed revisions")
        } catch {}
        let rows = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(rows.first?.text, "new")
    }

    func testUnderstandingConfirmationRollsBackWithSessionWriteFailure() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID(), draftID = UUID()
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "listen", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        _ = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: draftID)
        _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: draftID, editRevision: 1, text: "preserve")
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_understanding_activity BEFORE UPDATE ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { _ = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: draftID, expectedEditRevision: 1); XCTFail("Expected transaction failure") } catch {}
        do { _ = try await repo.saveUnderstandingDraft(sessionID: sessionID, draftID: draftID, editRevision: 2, text: "unsaved"); XCTFail("Expected transaction failure") } catch {}
        let unchanged = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(unchanged.first?.state, .draft)
        XCTAssertEqual(unchanged.first?.text, "preserve")
        XCTAssertEqual(unchanged.first?.editRevision, 1)
        XCTAssertNil(unchanged.first?.confirmedAt)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_understanding_activity") }
        let confirmed = try await repo.confirmUnderstanding(sessionID: sessionID, draftID: draftID, expectedEditRevision: 1)
        XCTAssertEqual(confirmed.state, .confirmed)
    }

    func testUnderstandingMigrationPreservesUnknownLegacyProvenance() async throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue, upTo: "v61_mentor_recall_continuations")
        let sessionID = UUID(), understandingID = UUID()
        try await queue.write { db in
            try db.execute(sql: "INSERT INTO mentor_sessions (id, initial_entry, lifecycle, draft_text, draft_revision, activity_at) VALUES (?, 'listen', 'ended', '', 0, '2026-09-10T10:00:00Z')", arguments: [sessionID.uuidString])
            try db.execute(sql: "INSERT INTO mentor_understandings (id, session_id, group_id, revision, state, text) VALUES (?, ?, ?, 1, 'confirmed', 'legacy text')", arguments: [understandingID.uuidString, sessionID.uuidString, understandingID.uuidString])
        }
        let db = try AppDatabase(dbQueue: queue)
        let repo = SQLiteMentorRepository(database: db)
        let rows = try await repo.understandings(sessionID: sessionID)
        XCTAssertEqual(rows.first?.text, "legacy text")
        XCTAssertEqual(rows.first?.origin, "legacy")
        XCTAssertNil(rows.first?.confirmedAt, "Migration must not invent confirmation evidence")
        do { _ = try await repo.beginUserUnderstanding(sessionID: sessionID, draftID: UUID(), previousRevisionID: understandingID); XCTFail("Must not silently label legacy content user-authored") } catch {}
    }

    func testMentorPromptAuditValidatesOwnedCurrentRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let mentor = SQLiteMentorRepository(database: db)
        let promptRepo = SQLitePromptRunRepository(database: db)
        let sessionID = UUID()
        try await mentor.createSession(MentorSession(id: sessionID, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await mentor.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: sessionID, text: "今天完成了一个改动", intent: "reply", contextSnapshotJSON: "{}"))
        let token = LLMRequest.MentorAuditToken(sessionID: sessionID, requestID: requestID, requestEpoch: 0, semanticRevision: 0)
        var request = LLMRequest(prompt: PromptTemplate(id: .singleNudge, version: "audit", systemText: "Return JSON", userText: "{}", outputSchemaVersion: 1), inputSummary: "mentor audit")
        request.mentorExecutionPolicy = .m1
        request.mentorAuditToken = token
        let client = PromptTracingLLMClient(base: MockLLMClient(), repository: promptRepo, modelProvider: "mock", modelName: "mentor-audit", mentorAudit: mentor)
        _ = try await client.complete(request)
        let savedRuns = try await promptRepo.recentPromptRuns(limit: 5)
        XCTAssertEqual(savedRuns.count, 1)
        let auditRelation = try await db.dbQueue.read { db in
            try Row.fetchOne(db, sql: "SELECT mentor_session_id, mentor_request_id, mentor_request_epoch, mentor_semantic_revision FROM prompt_runs WHERE id = ?", arguments: [request.traceID.uuidString])
        }
        XCTAssertEqual(auditRelation?["mentor_session_id"] as String?, sessionID.uuidString)
        XCTAssertEqual(auditRelation?["mentor_request_id"] as String?, requestID.uuidString)
        XCTAssertEqual(auditRelation?["mentor_request_epoch"] as Int?, 0)
        XCTAssertEqual(auditRelation?["mentor_semantic_revision"] as Int?, 0)
        try await mentor.finishRequest(sessionID: sessionID, requestID: requestID, reason: .cancelled)
        do { _ = try await client.complete(request); XCTFail("Terminal request cannot be audited again") } catch {
            XCTAssertTrue(error is PromptTracingError || error is MingSi.PersistenceError)
        }
        var foreign = request
        foreign.mentorAuditToken = .init(sessionID: UUID(), requestID: requestID, requestEpoch: 0, semanticRevision: 0)
        do { _ = try await client.complete(foreign); XCTFail("Foreign session cannot audit") } catch {
            XCTAssertTrue(error is PromptTracingError || error is MingSi.PersistenceError)
        }
    }

    func testMentorPromptAuditRejectsStaleEpochAndRevision() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let mentor = SQLiteMentorRepository(database: db)
        let promptRepo = SQLitePromptRunRepository(database: db)
        let sessionID = UUID()
        try await mentor.createSession(MentorSession(id: sessionID, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await mentor.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: sessionID, text: "原始事实", intent: "reply", contextSnapshotJSON: "{}"))
        try await mentor.suspendSession(id: sessionID, ending: false, draftRevision: 0, draftText: "")
        let token = LLMRequest.MentorAuditToken(sessionID: sessionID, requestID: requestID, requestEpoch: 0, semanticRevision: 0)
        var request = LLMRequest(prompt: PromptTemplate(id: .singleNudge, version: "audit", systemText: "Return JSON", userText: "{}", outputSchemaVersion: 1), inputSummary: "stale")
        request.mentorExecutionPolicy = .m1; request.mentorAuditToken = token
        do {
            _ = try await PromptTracingLLMClient(base: MockLLMClient(), repository: promptRepo, modelProvider: "mock", modelName: "stale", mentorAudit: mentor).complete(request)
            XCTFail("Suspended request epoch must be rejected")
        } catch {
            XCTAssertTrue(error is PromptTracingError || error is MingSi.PersistenceError)
        }
        let savedRuns = try await promptRepo.recentPromptRuns(limit: 5)
        XCTAssertEqual(savedRuns.count, 0)
    }

    func testSourceLinksRequireOwnedTypedOwnerAndRoundTrip() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID()
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let requestID = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: sessionID, text: "事实", intent: "reply", contextSnapshotJSON: "{}"))
        let valid = MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .request, ownerID: requestID,
            sourceKind: "item", sourceID: UUID().uuidString, sourceVersion: nil, contentHash: nil, availability: .available)
        try await repo.saveSourceLink(valid)
        let replay = try await repo.sourceLinks(sessionID: sessionID, ownerID: requestID)
        XCTAssertEqual(replay, [valid])
        let cases: [MentorSourceLink] = [
            MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .request, ownerID: UUID(), sourceKind: "item", sourceID: "x", sourceVersion: nil, contentHash: nil, availability: .available),
            MentorSourceLink(id: UUID(), sessionID: UUID(), ownerKind: .request, ownerID: requestID, sourceKind: "item", sourceID: "x", sourceVersion: nil, contentHash: nil, availability: .available),
            MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .item, ownerID: UUID(), sourceKind: "item", sourceID: "x", sourceVersion: nil, contentHash: nil, availability: .available)
        ]
        for link in cases { do { try await repo.saveSourceLink(link); XCTFail("Invalid owner must be rejected") } catch {} }
        try await repo.finishRequest(sessionID: sessionID, requestID: requestID, reason: .cancelled)
        let afterTerminal = MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .request, ownerID: requestID, sourceKind: "item", sourceID: "new", sourceVersion: nil, contentHash: nil, availability: .available)
        try await repo.saveSourceLink(afterTerminal)
        do { try await repo.saveSourceLink(MentorSourceLink(id: valid.id, sessionID: sessionID, ownerKind: .request, ownerID: requestID, sourceKind: "item", sourceID: "different", sourceVersion: nil, contentHash: nil, availability: .available)); XCTFail("Duplicate source link ID must fail") } catch {}
    }

    func testSessionDraftItemsAndCascadeDelete() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        try await repo.saveDraft(sessionID: id, revision: 1, text: "latest")
        try await repo.appendItem(MentorTimelineItem(id: UUID(), sessionID: id, sequence: 1, kind: .user, payloadJSON: "{}"))
        let items = try await repo.items(sessionID: id)
        let savedDraft = try await repo.session(id: id)?.draftText
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(savedDraft, "latest")
        try await repo.deleteSession(id: id)
        let deletedSession = try await repo.session(id: id)
        XCTAssertNil(deletedSession)
        let count = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_items")! }
        XCTAssertEqual(count, 0)
    }

    func testSubmitTurnIsIdempotent() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let sessionID = UUID()
        try await repo.createSession(MentorSession(id: sessionID, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let command = MentorSubmitTurn(commandID: UUID(), sessionID: sessionID, text: "A concrete observation", intent: "reply", contextSnapshotJSON: "{}")
        _ = try await repo.submitTurn(command)
        _ = try await repo.submitTurn(command)
        let items = try await repo.items(sessionID: sessionID)
        XCTAssertEqual(items.count, 1)
    }
    func testSubmissionRollbackAndRetryAfterRequestInsertFailure() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .draft, draftText: "keep", draftRevision: 1, activityAt: .now))
        try await db.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_request BEFORE INSERT ON mentor_requests BEGIN SELECT RAISE(ABORT, 'injected'); END")
        }
        let command = MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "quote \" and newline\n", intent: "reply", contextSnapshotJSON: "{}")
        do { _ = try await repo.submitTurn(command); XCTFail("Expected injected failure") } catch {}
        let empty = try await repo.items(sessionID: id)
        let unchanged = try await repo.session(id: id)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(unchanged?.lifecycle, .draft)
        XCTAssertEqual(unchanged?.draftText, "keep")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_request") }
        let requestID = try await repo.submitTurn(command)
        let replayID = try await repo.submitTurn(command)
        XCTAssertEqual(requestID, replayID)
        let items = try await repo.items(sessionID: id)
        let decoded = try JSONDecoder().decode([String: String].self, from: Data(items[0].payloadJSON.utf8))
        XCTAssertEqual(decoded["text"], command.text)
    }

    func testPendingRequestRejectsNewCommandAndChangedReplay() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let first = MentorSubmitTurn(commandID: UUID(), sessionID: id, text: nil, intent: "explain", contextSnapshotJSON: "{}")
        _ = try await repo.submitTurn(first)
        for commandID in [first.commandID, UUID()] {
            do {
                _ = try await repo.submitTurn(MentorSubmitTurn(commandID: commandID, sessionID: id, text: "changed", intent: "reply", contextSnapshotJSON: "{}"))
                XCTFail("Must reject conflicting or concurrent command")
            } catch {}
        }
        let items = try await repo.items(sessionID: id)
        XCTAssertTrue(items.isEmpty, "Teaching intent must not become user words")
        try await repo.deleteSession(id: id)
        do { _ = try await repo.submitTurn(first); XCTFail("Must not recreate deleted session") } catch {}
    }

    func testSequentialRequestsAllocateDistinctTimelinePositions() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        for index in 1...3 {
            let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "Turn \(index)", intent: "reply", contextSnapshotJSON: "{}"))
            try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_requests SET state = 'committed' WHERE id = ?", arguments: [request.uuidString]) }
        }
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.map(\.sequence), [1, 2, 3])
    }

    func testMigrationPreservesMultipleFoundationRequests() throws {
        let queue = try DatabaseQueue()
        try AppDatabase.makeMigrator().migrate(queue, upTo: "v53_mentor_m1_foundation")
        try queue.write { db in
            try db.execute(sql: "INSERT INTO mentor_sessions (id, initial_entry, lifecycle, activity_at) VALUES ('session', 'topic', 'active', '2026-09-11T00:00:00Z')")
            for id in ["request-a", "request-b"] {
                try db.execute(sql: "INSERT INTO mentor_requests (id, session_id, state, created_at) VALUES (?, 'session', 'failed', '2026-09-11T00:00:00Z')", arguments: [id])
            }
        }
        try AppDatabase.makeMigrator().migrate(queue)
        try queue.read { db in
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT command_id FROM mentor_requests ORDER BY id"), ["request-a", "request-b"])
            XCTAssertEqual(try String.fetchAll(db, sql: "SELECT intent FROM mentor_requests ORDER BY id"), ["legacy", "legacy"])
        }
    }

    func testResponseReplayAndPauseRejectLateResponseAfterResume() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let first = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "one", intent: "reply", contextSnapshotJSON: "{}"))
        let result = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: "{\"body\":\"reply\"}")
        let replay = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: result.payloadJSON)
        XCTAssertEqual(result, replay)
        try await repo.acknowledgePresentation(sessionID: id, itemID: result.id, at: .now, timeZone: TimeZone(secondsFromGMT: 0)!)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: "{}"); XCTFail("Conflicting replay") } catch {}
        let late = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "two", intent: "reply", contextSnapshotJSON: "{}"))
        try await repo.suspendSession(id: id, ending: false, draftRevision: 1, draftText: "saved")
        let paused = try await repo.session(id: id)
        XCTAssertEqual(paused?.lifecycle, .paused)
        XCTAssertEqual(paused?.draftText, "saved")
        _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "resume", intent: "reply", contextSnapshotJSON: "{}"))
        do { _ = try await repo.commitResponse(sessionID: id, requestID: late, payloadJSON: "{}"); XCTFail("Late response survived resume") } catch {}
        try await repo.deleteSession(id: id)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: first, payloadJSON: result.payloadJSON); XCTFail("Deleted response recreated") } catch {}
        let links = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_request_results") }
        XCTAssertEqual(links, 0)
    }

    func testResponseOwnershipAndAtomicRollback() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID(), other = UUID()
        for sessionID in [id, other] {
            try await repo.createSession(MentorSession(id: sessionID, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        }
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "one", intent: "reply", contextSnapshotJSON: "{}"))
        do { _ = try await repo.commitResponse(sessionID: other, requestID: request, payloadJSON: "{}"); XCTFail("Cross-session response") } catch {}
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_result BEFORE INSERT ON mentor_request_results BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}"); XCTFail("Expected failure") } catch {}
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.count, 1)
        let state = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.uuidString]) }
        XCTAssertEqual(state, "prepared")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_result") }
        _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}")
    }

    func testSuspendFailureRollsBackRequestCancellation() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "one", intent: "reply", contextSnapshotJSON: "{}"))
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_pause BEFORE UPDATE ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "new"); XCTFail("Expected failure") } catch {}
        let session = try await repo.session(id: id)
        XCTAssertEqual(session?.lifecycle, .active)
        XCTAssertEqual(session?.draftRevision, 0)
        let state = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.uuidString]) }
        XCTAssertEqual(state, "prepared")
    }

    func testDraftRevisionConflictsAndReplayPreserveStoredText() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        try await repo.saveDraft(sessionID: id, revision: 2, text: "newest")
        let before = try await repo.session(id: id)
        try await repo.saveDraft(sessionID: id, revision: 2, text: "newest")
        let replay = try await repo.session(id: id)
        XCTAssertEqual(before, replay)
        for revision in [-1, 1, 2] {
            do { try await repo.saveDraft(sessionID: id, revision: revision, text: "older"); XCTFail("Rejected stale or conflicting revision") } catch {}
        }
        let saved = try await repo.session(id: id)
        XCTAssertEqual(saved, before)
    }

    func testClosedSessionRejectsDelayedDraftAndSuspendWrites() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        try await repo.suspendSession(id: id, ending: false, draftRevision: 1, draftText: "paused")
        do { try await repo.saveDraft(sessionID: id, revision: 2, text: "late"); XCTFail("Paused draft overwritten") } catch {}
        try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "paused")
        let ended = try await repo.session(id: id)
        try await repo.suspendSession(id: id, ending: true, draftRevision: 1, draftText: "paused")
        do { try await repo.suspendSession(id: id, ending: false, draftRevision: 2, draftText: "late"); XCTFail("Ended session reopened by background callback") } catch {}
        do { try await repo.saveDraft(sessionID: id, revision: 2, text: "late"); XCTFail("Ended draft overwritten") } catch {}
        let final = try await repo.session(id: id)
        XCTAssertEqual(final, ended)
        try await repo.resumeSession(id: id)
        try await repo.saveDraft(sessionID: id, revision: 2, text: "explicit continuation")
        let resumed = try await repo.session(id: id)
        XCTAssertEqual(resumed?.lifecycle, .active)
        XCTAssertEqual(resumed?.draftText, "explicit continuation")
    }

    func testCorrectionPreservesOriginalAndInvalidatesOldRequest() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "old fact", intent: "reply", contextSnapshotJSON: "{}"))
        let before = try await repo.items(sessionID: id)
        let command = UUID()
        let correction = try await repo.correctUserItem(sessionID: id, itemID: before[0].id, commandID: command, expectedRevision: 0, text: "correct fact")
        let replay = try await repo.correctUserItem(sessionID: id, itemID: before[0].id, commandID: command, expectedRevision: 0, text: "correct fact")
        XCTAssertEqual(correction, replay)
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0], before[0])
        XCTAssertEqual(items[1].supersedesItemID, before[0].id)
        let session = try await repo.session(id: id)
        XCTAssertEqual(session?.semanticRevision, 1)
        XCTAssertEqual(session?.requestEpoch, 1)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}"); XCTFail("Old facts accepted") } catch {}
        // Even an erroneous state reset cannot bypass the persisted revision check.
        try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_requests SET state = 'prepared' WHERE id = ?", arguments: [request.uuidString]) }
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{}"); XCTFail("Revision mismatch accepted") } catch {}
        try await db.dbQueue.write { try $0.execute(sql: "UPDATE mentor_requests SET state = 'cancelled' WHERE id = ?", arguments: [request.uuidString]) }
        let fresh = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: nil, intent: "explain", contextSnapshotJSON: "{}"))
        _ = try await repo.commitResponse(sessionID: id, requestID: fresh, payloadJSON: "{}")
        try await repo.deleteSession(id: id)
        let remaining = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_corrections") }
        XCTAssertEqual(remaining, 0)
    }

    func testCorrectionConflictAndFailureRollBackAllEffects() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "old", intent: "reply", contextSnapshotJSON: "{}"))
        let original = try await repo.items(sessionID: id)[0]
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_correction BEFORE UPDATE ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 0, text: "new"); XCTFail("Failure ignored") } catch {}
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items, [original])
        let current = try await repo.session(id: id)
        XCTAssertEqual(current?.semanticRevision, 0)
        let state = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [request.uuidString]) }
        XCTAssertEqual(state, "prepared")
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_correction") }
        _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 0, text: "new")
        do { _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 1, text: "fork"); XCTFail("Correction fork accepted") } catch {}
    }

    func testRecentSessionPaginationHandlesTiesAndDeletedCursor() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var ids: [UUID] = []
        for index in 1...43 {
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
            ids.append(id)
            try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .paused, draftText: "draft", draftRevision: 1, activityAt: date))
        }
        let first = try await repo.recentSessions()
        XCTAssertEqual(first.sessions.map(\.id), Array(ids.reversed().prefix(20)))
        let cursor = try XCTUnwrap(first.nextCursor)
        try await repo.deleteSession(id: first.sessions.last!.id)
        let second = try await repo.recentSessions(after: cursor)
        let third = try await repo.recentSessions(after: try XCTUnwrap(second.nextCursor))
        XCTAssertEqual(first.sessions.count, 20)
        XCTAssertEqual(second.sessions.count, 20)
        XCTAssertEqual(third.sessions.count, 3)
        XCTAssertNil(third.nextCursor)
        XCTAssertEqual((first.sessions + second.sessions + third.sessions).map(\.id), ids.reversed())
    }

    func testRecentSessionPreviewIncludesDraftOrContentButNotEmptyEntry() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let empty = UUID(), draft = UUID(), lesson = UUID()
        for id in [empty, draft, lesson] {
            try await repo.createSession(MentorSession(id: id, initialEntry: "listen", lifecycle: .draft, draftText: id == draft ? String(repeating: "文", count: 200) : "", draftRevision: 0, activityAt: .now))
        }
        try await repo.appendItem(MentorTimelineItem(id: UUID(), sessionID: lesson, sequence: 1, kind: .lesson, payloadJSON: "{\"title\":\"观察和解释\"}"))
        let page = try await repo.recentSessions(limit: 3)
        XCTAssertEqual(Set(page.sessions.map(\.id)), Set([draft, lesson]))
        XCTAssertEqual(page.sessions.first { $0.id == draft }?.preview.count, 80)
        XCTAssertEqual(page.sessions.first { $0.id == lesson }?.preview, "观察和解释")
        XCTAssertNil(page.nextCursor)
        for limit in [0, -1, 21, Int.max] {
            do { _ = try await repo.recentSessions(limit: limit); XCTFail("Invalid limit accepted") } catch {}
        }
    }

    func testPresentationAcknowledgementIsAtomicAndCountsOnlyOnce() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "busy", intent: "reply", contextSnapshotJSON: "{}"))
        let payload = "{\"action\":\"explain\",\"question\":\"What happened?\",\"question_purpose\":\"material\"}"
        let item = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: payload)
        let saved = try await repo.session(id: id)
        XCTAssertEqual(saved?.recallCount, 0)
        do { _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "next", intent: "reply", contextSnapshotJSON: "{}")); XCTFail("Unacknowledged presentation") } catch {}
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_count BEFORE UPDATE OF recall_count ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let zone = TimeZone(secondsFromGMT: 28800)!
        do { try await repo.acknowledgePresentation(sessionID: id, itemID: item.id, at: date, timeZone: zone); XCTFail("Expected failure") } catch {}
        let absent = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT presented_at FROM mentor_items WHERE id = ?", arguments: [item.id.uuidString]) }
        XCTAssertNil(absent)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_count") }
        try await repo.acknowledgePresentation(sessionID: id, itemID: item.id, at: date, timeZone: zone)
        try await repo.acknowledgePresentation(sessionID: id, itemID: item.id, at: date.addingTimeInterval(86400), timeZone: zone)
        let confirmed = try await repo.session(id: id)
        XCTAssertEqual(confirmed?.recallCount, 1)
        let stored = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT presented_at FROM mentor_items WHERE id = ?", arguments: [item.id.uuidString]) }
        XCTAssertEqual(stored, ISO8601DateFormatter().string(from: date))
        _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "next", intent: "reply", contextSnapshotJSON: "{}"))
    }

    func testMaterialBudgetAppliesAcrossActionsAndPresentationOwnership() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        for action in ["explain", "compare"] {
            let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "unsure", intent: "reply", contextSnapshotJSON: "{}"))
            let result = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{\"action\":\"\(action)\",\"question\":\"What happened?\",\"material_status\":\"missing\"}")
            do { try await repo.acknowledgePresentation(sessionID: UUID(), itemID: result.id, at: .now, timeZone: .current); XCTFail("Wrong owner") } catch {}
            try await repo.acknowledgePresentation(sessionID: id, itemID: result.id, at: .now, timeZone: .current)
        }
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "unsure", intent: "reply", contextSnapshotJSON: "{}"))
        do { _ = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: "{\"question\":\"What else?\",\"question_purpose\":\"material\"}"); XCTFail("Third material question accepted") } catch {}
        let final = try await repo.session(id: id)
        XCTAssertEqual(final?.recallCount, 2)
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.filter { $0.kind == .assistant }.count, 2)
        do { try await repo.acknowledgePresentation(sessionID: id, itemID: items[0].id, at: .now, timeZone: .current); XCTFail("User input marked as teaching") } catch {}
    }

    func testStartupRecoveryAndExplicitRetryReuseOriginalUserItem() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "draft", draftRevision: 1, activityAt: .now))
        let original = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "original", intent: "reply", contextSnapshotJSON: "{}"))
        let recovered = try await repo.recoverInterruptedRequests()
        let repeated = try await repo.recoverInterruptedRequests()
        XCTAssertEqual(recovered, 1)
        XCTAssertEqual(repeated, 0)
        let paused = try await repo.session(id: id)
        XCTAssertEqual(paused?.lifecycle, .paused)
        XCTAssertEqual(paused?.requestEpoch, 1)
        XCTAssertEqual(paused?.draftText, "draft")
        do { _ = try await repo.commitResponse(sessionID: id, requestID: original, payloadJSON: "{}"); XCTFail("Interrupted response accepted") } catch {}
        let retryCommand = MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "original", intent: "reply", contextSnapshotJSON: "{}", retryOf: original)
        let retried = try await repo.submitTurn(retryCommand)
        let replay = try await repo.submitTurn(retryCommand)
        XCTAssertNotEqual(retried, original)
        XCTAssertEqual(retried, replay)
        let items = try await repo.items(sessionID: id)
        XCTAssertEqual(items.count, 1)
        _ = try await repo.commitResponse(sessionID: id, requestID: retried, payloadJSON: "{}")
        try await repo.deleteSession(id: id)
        let remaining = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_requests") }
        XCTAssertEqual(remaining, 0)
    }

    func testTerminalRequestCannotBeRevivedAndRetryMustMatchInput() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "topic", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "original", intent: "reply", contextSnapshotJSON: "{}"))
        try await repo.finishRequest(sessionID: id, requestID: request, reason: .timedOut)
        try await repo.finishRequest(sessionID: id, requestID: request, reason: .timedOut)
        do { try await repo.finishRequest(sessionID: id, requestID: request, reason: .failed); XCTFail("Terminal outcome changed") } catch {}
        do { _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "different", intent: "reply", contextSnapshotJSON: "{}", retryOf: request)); XCTFail("Changed input accepted") } catch {}
        let original = try await repo.items(sessionID: id)[0]
        _ = try await repo.correctUserItem(sessionID: id, itemID: original.id, commandID: UUID(), expectedRevision: 0, text: "corrected")
        do { _ = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "original", intent: "reply", contextSnapshotJSON: "{}", retryOf: request)); XCTFail("Obsolete context accepted") } catch {}
    }

    func testExplicitRecallContinuationIsIdempotentAndDoesNotRecountHistory() async throws {
        let db = try AppDatabase(dbQueue: DatabaseQueue())
        let repo = SQLiteMentorRepository(database: db)
        let id = UUID()
        try await repo.createSession(MentorSession(id: id, initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now))
        do { try await repo.continueRecall(sessionID: id, commandID: UUID(), expectedEpoch: 0); XCTFail("Fresh budget reset") } catch {}
        var shown: [MentorTimelineItem] = []
        let question = "{\"question\":\"What happened?\",\"question_purpose\":\"material\"}"
        for _ in 0..<2 {
            let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "unsure", intent: "reply", contextSnapshotJSON: "{}"))
            let item = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: question)
            shown.append(item)
            try await repo.acknowledgePresentation(sessionID: id, itemID: item.id, at: .now, timeZone: .current)
        }
        let oldRequest = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "continue", intent: "reply", contextSnapshotJSON: "{}"))
        let command = UUID()
        try await db.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER fail_recall BEFORE UPDATE OF recall_count ON mentor_sessions BEGIN SELECT RAISE(ABORT, 'injected'); END") }
        do { try await repo.continueRecall(sessionID: id, commandID: command, expectedEpoch: 0); XCTFail("Expected rollback") } catch {}
        let unchanged = try await repo.session(id: id)
        XCTAssertEqual(unchanged?.recallCount, 2)
        let oldState = try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT state FROM mentor_requests WHERE id = ?", arguments: [oldRequest.uuidString]) }
        XCTAssertEqual(oldState, "prepared")
        let noReceipt = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_recall_continuations") }
        XCTAssertEqual(noReceipt, 0)
        try await db.dbQueue.write { try $0.execute(sql: "DROP TRIGGER fail_recall") }
        try await repo.continueRecall(sessionID: id, commandID: command, expectedEpoch: 0)
        do { _ = try await repo.commitResponse(sessionID: id, requestID: oldRequest, payloadJSON: question); XCTFail("Old request survived new segment") } catch {}
        for item in shown { try await repo.acknowledgePresentation(sessionID: id, itemID: item.id, at: .now, timeZone: .current) }
        let request = try await repo.submitTurn(MentorSubmitTurn(commandID: UUID(), sessionID: id, text: "new segment", intent: "reply", contextSnapshotJSON: "{}"))
        let item = try await repo.commitResponse(sessionID: id, requestID: request, payloadJSON: question)
        try await repo.acknowledgePresentation(sessionID: id, itemID: item.id, at: .now, timeZone: .current)
        try await repo.continueRecall(sessionID: id, commandID: command, expectedEpoch: 0)
        let current = try await repo.session(id: id)
        XCTAssertEqual(current?.recallCount, 1, "Replayed command must not clear new progress")
        XCTAssertEqual(current?.requestEpoch, 1)
        do { try await repo.continueRecall(sessionID: id, commandID: UUID(), expectedEpoch: 0); XCTFail("Stale continuation") } catch {}
        try await repo.deleteSession(id: id)
        let receipts = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mentor_recall_continuations") }
        XCTAssertEqual(receipts, 0)
    }

}
