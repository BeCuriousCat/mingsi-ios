import XCTest
@testable import MingSi

final class MentorContextBuilderTests: XCTestCase {
    private func session() -> MentorSession {
        MentorSession(id: UUID(), initialEntry: "review", lifecycle: .active, draftText: "", draftRevision: 0, activityAt: .now)
    }
    private func user(_ session: MentorSession, _ sequence: Int, _ text: String, correcting: UUID? = nil) throws -> MentorTimelineItem {
        MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: sequence, kind: .user,
            payloadJSON: String(decoding: try JSONEncoder().encode(["text": text]), as: UTF8.self), supersedesItemID: correcting)
    }
    private func assistant(_ session: MentorSession, _ sequence: Int) -> MentorTimelineItem {
        MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: sequence, kind: .assistant, payloadJSON: "{\"body\":\"A historical response\"}")
    }

    func testRemovedCandidateIsAlsoRemovedFromResponseWhitelist() throws {
        let s = session()
        func lesson(_ hash: String) -> MentorLesson {
            MentorLesson(id: "L01", version: "1.0", editorialOrder: 1, title: "A concrete lesson", theme: .observation,
                applicableContexts: ["An explicit situation"], claim: String(repeating: "观点", count: 1500),
                example: "Full example is not a directory summary", boundary: "Only applies in this situation", observation: nil,
                sourceType: .teachingExample, citations: [], contentHash: hash,
                review: .init(status: .approved, reviewedBy: "Fixture editor", reviewedAt: .now, note: nil))
        }
        let candidate = lesson(MentorLessonCatalog.contentHash(for: lesson("")))
        let complete = try MentorContextBuilder().build(session: s, items: [], intent: "explain", eligibleLessons: [candidate])
        XCTAssertEqual(complete.payload.lessonCandidates.first?.applicableContexts, candidate.applicableContexts)
        XCTAssertTrue(complete.validation.sentSources.contains(try MentorSourceReference("lesson:L01@1.0")))
        let reduced = try MentorContextBuilder().build(session: s, items: [], intent: "explain", eligibleLessons: [candidate], characterLimit: 1000)
        XCTAssertTrue(reduced.payload.lessonCandidates.isEmpty)
        XCTAssertTrue(reduced.validation.eligibleLessons.isEmpty)
        XCTAssertFalse(reduced.validation.sentSources.contains(try MentorSourceReference("lesson:L01@1.0")))
    }

    func testOldNaturalCorrectionSurvivesRecentSixExchangeWindow() throws {
        let s = session()
        var items = [try user(s, 1, "我以为所有用户都失败了。"), assistant(s, 2), try user(s, 3, "更正一下，只有一位用户失败了。"), assistant(s, 4)]
        for index in 0..<8 {
            items.append(try user(s, 5 + index * 2, "后续原话 \(index)"))
            items.append(assistant(s, 6 + index * 2))
        }
        let built = try MentorContextBuilder().build(session: s, items: items, intent: "reply")
        XCTAssertEqual(built.payload.recentExchanges.count, 6)
        XCTAssertTrue(built.json.contains("只有一位用户失败了"))
        XCTAssertTrue(built.json.contains("我以为所有用户都失败了"))
        XCTAssertEqual(built.validation.userExpressionSources.count, 10)
        XCTAssertTrue(built.omittedItemIDs.contains(items[1].id))
        XCTAssertFalse(built.validation.sentSources.contains(try MentorSourceReference("item:" + items[1].id.uuidString)))
        let decoded = try JSONDecoder().decode(MentorContextPayload.self, from: Data(built.json.utf8))
        XCTAssertEqual(decoded, built.payload)
    }

    func testExplicitCorrectionChainMarksSupersededEvidence() throws {
        let s = session(), first = try user(s, 1, "ten")
        let second = try user(s, 2, "two", correcting: first.id)
        let third = try user(s, 3, "one", correcting: second.id)
        let built = try MentorContextBuilder().build(session: s, items: [third, first, second], intent: "reply")
        XCTAssertEqual(built.validation.supersededSources.count, 2)
        XCTAssertEqual(built.validation.userExpressionSources, [try MentorSourceReference("item:" + third.id.uuidString)])
        XCTAssertEqual(built.payload.sources.last?.supersedes, try MentorSourceReference("item:" + second.id.uuidString))
        let orphan = try user(s, 4, "unknown", correcting: UUID())
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: [first, orphan], intent: "reply"))
        let branch = try user(s, 5, "branch", correcting: first.id)
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: [first, second, branch], intent: "reply"))
    }

    func testOversizedUserMaterialFailsWithoutTruncation() throws {
        let s = session(), text = String(repeating: "完整原话", count: 7000)
        let item = try user(s, 1, text)
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: [item], intent: "reply")) {
            guard case MentorContextError.requiresMaterialSelection(let count, let limit) = $0 else { return XCTFail("Expected explicit material selection") }
            XCTAssertGreaterThan(count, limit)
            XCTAssertEqual(limit, 24000)
        }
        let stored = try JSONDecoder().decode([String: String].self, from: Data(item.payloadJSON.utf8))
        XCTAssertEqual(stored["text"], text)
    }

    func testForeignTimelineAndUnconfirmedUnderstandingRejected() throws {
        let s = session(), foreign = session()
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: [user(foreign, 1, "private")], intent: "reply"))
        let draft = MentorUnderstanding(id: UUID(), sessionID: s.id, groupID: UUID(), revision: 1, previousRevisionID: nil,
            state: .draft, text: "not confirmed", origin: "user_note", editRevision: 1, confirmedAt: nil)
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: [], intent: "reply", selectedUnderstanding: draft))
        let built = try MentorContextBuilder().build(session: s, items: [], intent: "explain", responseIntent: .directTeaching)
        XCTAssertTrue(built.validation.userExpressionSources.isEmpty, "Teaching button cannot become user evidence")
        XCTAssertFalse(built.payload.allowsMaterialQuestion)
    }

    func testBudgetDropsWholeOlderExchangesAndPreservesLatest() throws {
        let s = session()
        var items: [MentorTimelineItem] = []
        for index in 0..<6 {
            items.append(try user(s, index * 2 + 1, "Original \(index)"))
            items.append(MentorTimelineItem(id: UUID(), sessionID: s.id, sequence: index * 2 + 2, kind: .assistant,
                payloadJSON: String(repeating: "long historical response ", count: 30)))
        }
        let built = try MentorContextBuilder().build(session: s, items: items, intent: "reply", characterLimit: 4000)
        XCTAssertLessThanOrEqual(built.json.unicodeScalars.count, 4000)
        XCTAssertLessThan(built.payload.recentExchanges.count, 6)
        XCTAssertEqual(built.payload.recentExchanges.last?.last, try MentorSourceReference("item:" + items.last!.id.uuidString))
        XCTAssertEqual(built.validation.userExpressionSources.count, 6)
        for group in built.payload.recentExchanges { XCTAssertEqual(group.count, 2) }
    }
}
