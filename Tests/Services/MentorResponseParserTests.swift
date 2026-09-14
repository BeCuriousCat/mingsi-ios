import XCTest
@testable import MingSi

final class MentorResponseParserTests: XCTestCase {
    private let user = "item:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private let assistant = "item:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    private let lesson = "lesson:L01@1.0"
    private let parser = MentorResponseParser()

    func testMentorPreviewTemplatesReturnValidContractsWithoutInventingUserExpression() async throws {
        let session = MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now)
        let item = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 1, kind: .user,
            payloadJSON: "{\"text\":\"我想先区分动作与效果\"}")
        let built = try MentorContextBuilder().build(session: session, items: [item], intent: "reply")
        let client = MockLLMClient()
        let provider = LocalPromptProvider()
        for id in [PromptID.mentorRespond, .mentorDraftUnderstanding] {
            let request = LLMRequest(prompt: provider.template(for: id, mode: .standard), inputSummary: built.json)
            let data = try await client.complete(request)
            if id == .mentorRespond {
                XCTAssertEqual(try parser.parseTurn(data, context: built.validation).response.schemaVersion, "1.0.0")
            } else {
                let draft = try parser.parseUnderstanding(data, context: built.validation)
                XCTAssertEqual(draft.text, "我想先区分动作与效果")
                XCTAssertEqual(draft.sourceRefs, [try MentorSourceReference("item:" + item.id.uuidString)])
            }
        }
        let empty = try MentorContextBuilder().build(session: session, items: [], intent: "explain")
        do {
            _ = try await client.complete(LLMRequest(prompt: provider.template(for: .mentorDraftUnderstanding, mode: .standard), inputSummary: empty.json))
            XCTFail("Preview invented an understanding without user expression")
        } catch MentorContextError.invalidUnderstanding {}
    }

    private func context(count: Int = 0, intent: MentorResponseValidationContext.Intent = .discuss, hasUser: Bool = true, superseded: Bool = false) throws -> MentorResponseValidationContext {
        let userRef = try MentorSourceReference(user)
        return try MentorResponseValidationContext(sentSources: [userRef, MentorSourceReference(assistant), MentorSourceReference(lesson)],
            userExpressionSources: hasUser && !superseded ? [userRef] : [], supersededSources: superseded ? [userRef] : [],
            eligibleLessons: [.init(id: "L01", version: "1.0")], materialQuestionCount: count, intent: intent)
    }

    private func turn(_ mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var value: [String: Any] = ["schema_version": "1.0.0", "action": "explain", "material_status": "usable",
            "body": "区分完成修改和改善效果，可以为下一次观察留下明确方向。", "question": NSNull(), "question_purpose": NSNull(),
            "source_refs": [user], "lesson_ref": NSNull(), "suggested_actions": ["reply", "draft_understanding", "finish"]]
        mutate(&value)
        return try JSONSerialization.data(withJSONObject: value)
    }

    func testFiveActionsAndRequiredNullRoundTrip() throws {
        for action in MentorAction.allCases {
            let data = try turn {
                $0["action"] = action.rawValue
                if action == .clarify { $0["question"] = "这次具体改了哪一步？"; $0["question_purpose"] = "material" }
            }
            let parsed = try parser.parseTurn(data, context: context())
            XCTAssertEqual(parsed.response.action, action)
            let encoded = try JSONEncoder().encode(parsed.response)
            let again = try parser.parseTurn(encoded, context: context())
            XCTAssertEqual(parsed, again)
        }
    }

    func testStrictStructuralCounterexamples() throws {
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["create_task"] = true }, { $0.removeValue(forKey: "question") },
            { $0.removeValue(forKey: "lesson_ref") }, { $0["schema_version"] = "2.0.0" },
            { $0["action"] = "notify" }, { $0["body"] = " \n " },
            { $0["body"] = String(repeating: "a", count: 12001) },
            { $0["action"] = "clarify" }, { $0["question_purpose"] = "material" },
            { $0["question"] = "具体是什么？" },
            { $0["question"] = ["one", "two"] },
            { $0["question"] = "为什么？"; $0["question_purpose"] = "reflection"; $0["material_status"] = "missing" },
            { $0["suggested_actions"] = ["finish", "finish"] },
            { $0["suggested_actions"] = ["save_understanding"] },
            { $0["source_refs"] = ["item:not-a-uuid"] },
            { $0["source_refs"] = [self.user, self.user.uppercased().replacingOccurrences(of: "ITEM:", with: "item:")] },
            { $0["lesson_ref"] = ["id": "L01", "version": "1.0", "body": "unreviewed"] },
            { $0["lesson_ref"] = ["id": "L01"] },
            { $0["lesson_ref"] = ["id": "L01\n", "version": "1.0"] }
        ]
        for (index, mutation) in mutations.enumerated() {
            XCTAssertThrowsError(try parser.parseTurn(turn(mutation), context: context()), "Counterexample \(index)")
        }
        XCTAssertThrowsError(try parser.parseTurn(Data("```json\n{}\n```".utf8), context: context()))
    }

    func testActualSourceSetAndEligibleLessonRequired() throws {
        XCTAssertThrowsError(try parser.parseTurn(turn { $0["source_refs"] = ["item:cccccccc-cccc-4ccc-8ccc-cccccccccccc"] }, context: context())) {
            guard case MentorResponseError.unsentSource = $0 else { return XCTFail("Expected unsent source") }
        }
        XCTAssertThrowsError(try parser.parseTurn(turn(), context: context(superseded: true))) {
            guard case MentorResponseError.supersededSource = $0 else { return XCTFail("Expected superseded source") }
        }
        XCTAssertThrowsError(try parser.parseTurn(turn { $0["lesson_ref"] = ["id": "L01", "version": "2.0"] }, context: context())) {
            XCTAssertEqual($0 as? MentorResponseError, .ineligibleLesson)
        }
        let valid = try parser.parseTurn(turn { $0["lesson_ref"] = ["id": "L01", "version": "1.0"]; $0["source_refs"] = [self.lesson] }, context: context())
        XCTAssertEqual(valid.response.lessonRef?.id, "L01")
    }

    func testBudgetAppliesToEveryActionAndTeachingIntentWins() throws {
        for action in MentorAction.allCases {
            let data = try turn { $0["action"] = action.rawValue; $0["question"] = "今天还有什么片段？"; $0["question_purpose"] = "material" }
            XCTAssertNoThrow(try parser.parseTurn(data, context: context(count: 1)))
            XCTAssertThrowsError(try parser.parseTurn(data, context: context(count: 2))) {
                XCTAssertEqual($0 as? MentorResponseError, .materialBudgetExhausted)
            }
            XCTAssertThrowsError(try parser.parseTurn(data, context: context(intent: .directTeaching)))
        }
        XCTAssertNoThrow(try parser.parseTurn(turn(), context: context(intent: .directTeaching)))
        let reflection = try turn { $0["question"] = "愿意试着区分一下吗？"; $0["question_purpose"] = "reflection" }
        XCTAssertNoThrow(try parser.parseTurn(reflection, context: context(count: 2)))
        XCTAssertThrowsError(try parser.parseTurn(turn(), context: context(intent: .finish)))
    }

    func testSuggestionsCannotGrantCapabilitiesOrUserAuthorship() throws {
        let parsed = try parser.parseTurn(turn(), context: context(hasUser: false))
        XCTAssertEqual(parsed.availableSuggestedActions, [.reply, .finish])
        let limited = try MentorResponseValidationContext(sentSources: [MentorSourceReference(user)], userExpressionSources: [], materialQuestionCount: 0, availableActions: [.finish])
        let result = try parser.parseTurn(turn(), context: limited)
        XCTAssertEqual(result.availableSuggestedActions, [.finish])
        XCTAssertThrowsError(try MentorResponseValidationContext(sentSources: [MentorSourceReference(lesson)], userExpressionSources: [MentorSourceReference(lesson)], materialQuestionCount: 0))
    }

    func testUnderstandingMustRemainDraftAndUseOnlyUserWords() throws {
        func draft(_ refs: [String], confirmed: Bool = false) throws -> Data {
            var value: [String: Any] = ["schema_version": "1.0.0", "text": "我想先明确改动希望改善什么。", "source_refs": refs]
            if confirmed { value["confirmed"] = true }
            return try JSONSerialization.data(withJSONObject: value)
        }
        let accepted = try parser.parseUnderstanding(draft([user]), context: context())
        XCTAssertEqual(accepted.sourceRefs, [try MentorSourceReference(user)])
        XCTAssertThrowsError(try parser.parseUnderstanding(draft([user], confirmed: true), context: context()))
        for refs in [[], [lesson], [assistant], [user, assistant]] {
            XCTAssertThrowsError(try parser.parseUnderstanding(draft(refs), context: context()))
        }
        XCTAssertThrowsError(try parser.parseUnderstanding(draft([user]), context: context(hasUser: false))) {
            XCTAssertEqual($0 as? MentorResponseError, .noUserExpression)
        }
    }
}
