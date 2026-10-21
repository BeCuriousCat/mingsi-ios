import XCTest
@testable import MingSi

final class MentorResponseParserTests: XCTestCase {
    private let user = "item:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private let assistant = "item:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    private let lesson = "lesson:L01@1.0"
    private let parser = MentorResponseParser()

    func testSourceResolverUsesOnlyCurrentSessionSnapshots() throws {
        let sessionID = UUID()
        let userID = UUID()
        let assistantID = UUID()
        let otherSessionID = UUID()
        let noteID = UUID()
        let timeline = [
            MentorTimelineItem(id: userID, sessionID: sessionID, sequence: 1, kind: .user,
                payloadJSON: "{\"text\":\"我看到的是一次完成，不确定是否真的改善。\"}"),
            MentorTimelineItem(id: assistantID, sessionID: sessionID, sequence: 2, kind: .assistant,
                payloadJSON: "{\"schema_version\":\"1.0.0\",\"action\":\"explain\",\"material_status\":\"usable\",\"body\":\"把完成和效果分开看。\",\"question\":null,\"question_purpose\":null,\"source_refs\":[\"item:\(userID.uuidString)\"],\"lesson_ref\":null,\"suggested_actions\":[]}"),
            MentorTimelineItem(id: UUID(), sessionID: otherSessionID, sequence: 1, kind: .user,
                payloadJSON: "{\"text\":\"不属于当前交流\"}")
        ]
        let note = MentorUnderstanding(id: noteID, sessionID: sessionID, groupID: UUID(), revision: 1,
            previousRevisionID: nil, state: .confirmed, text: "我会同时检查交付和效果。", origin: "user_note",
            editRevision: 1, confirmedAt: .now)
        let refs = try [
            MentorSourceReference("item:\(userID.uuidString)"),
            MentorSourceReference("item:\(assistantID.uuidString)"),
            MentorSourceReference("understanding:\(noteID.uuidString)"),
            MentorSourceReference("item:\(UUID().uuidString)")
        ]
        let details = MentorSourceResolver().resolve(refs, sessionID: sessionID, timeline: timeline,
            understandings: [note], links: [])
        XCTAssertEqual(details[0].status, .available)
        XCTAssertEqual(details[0].content, "我看到的是一次完成，不确定是否真的改善。")
        XCTAssertEqual(details[1].title, "导师回应")
        XCTAssertEqual(details[2].content, note.text)
        if case .unavailable(let reason) = details[3].status {
            XCTAssertTrue(reason.contains("没有随本次会话保存"))
        } else { XCTFail("An unowned item must not be resolved by UUID shape alone") }
    }

    func testSourceResolverPreservesDeletedAndSnapshotMismatchStates() throws {
        let sessionID = UUID()
        let itemID = UUID()
        let ref = try MentorSourceReference("item:\(itemID.uuidString)")
        let item = MentorTimelineItem(id: itemID, sessionID: sessionID, sequence: 1, kind: .user,
            payloadJSON: "{\"text\":\"原始表达\"}")
        let deleted = MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .item, ownerID: itemID,
            sourceKind: "item", sourceID: itemID.uuidString, sourceVersion: nil, contentHash: nil, availability: .deleted)
        let deletedDetail = MentorSourceResolver().resolve([ref], sessionID: sessionID, timeline: [item], understandings: [], links: [deleted]).first
        XCTAssertEqual(deletedDetail?.status, .deleted)

        let mismatched = MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .item, ownerID: itemID,
            sourceKind: "item", sourceID: itemID.uuidString, sourceVersion: nil, contentHash: "sha256:wrong", availability: .available)
        let mismatchDetail = MentorSourceResolver().resolve([ref], sessionID: sessionID, timeline: [item], understandings: [], links: [mismatched]).first
        if case .unavailable(let reason) = mismatchDetail?.status {
            XCTAssertTrue(reason.contains("内容"))
        } else { XCTFail("A mismatched snapshot must be unavailable") }
    }

    func testLessonSourceResolverReturnsSnapshotAndExternalLinks() throws {
        let sessionID = UUID()
        let lesson = MentorLesson(id: "L01", version: "1.0", editorialOrder: 1, title: "改动与效果",
            theme: .iteration, applicableContexts: ["fixture"], claim: "先说清希望什么变好。",
            example: "检查改动后的实际效果。", boundary: "修复明确错误时可以直接验证。", observation: nil,
            sourceType: .externalReference, citations: [.init(title: "出处", url: "https://example.com/source")],
            contentHash: "", review: .init(status: .approved, reviewedBy: "fixture", reviewedAt: .now, note: nil))
        let signed = MentorLesson(id: lesson.id, version: lesson.version, editorialOrder: lesson.editorialOrder,
            title: lesson.title, theme: lesson.theme, applicableContexts: lesson.applicableContexts, claim: lesson.claim,
            example: lesson.example, boundary: lesson.boundary, observation: lesson.observation, sourceType: lesson.sourceType,
            citations: lesson.citations, contentHash: MentorLessonCatalog.contentHash(for: lesson), review: lesson.review)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = String(decoding: try encoder.encode(signed), as: UTF8.self)
        let item = MentorTimelineItem(id: UUID(), sessionID: sessionID, sequence: 1, kind: .lesson, payloadJSON: payload)
        let ref = try MentorSourceReference("lesson:L01@1.0")
        let detail = MentorSourceResolver().resolve([ref], sessionID: sessionID, timeline: [item], understandings: [], links: []).first
        XCTAssertEqual(detail?.status, .available)
        XCTAssertEqual(detail?.sourceVersion, "1.0")
        XCTAssertEqual(detail?.externalLinks.first?.url.absoluteString, "https://example.com/source")
    }

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
            "source_refs": [user], "lesson_ref": NSNull(), "suggested_actions": ["reply", "finish"]]
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

    func testTransportEnvelopeUnwrapsWithoutRepairingInvalidModelContent() throws {
        func envelope(_ content: String) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": content]]]])
        }
        let content = String(decoding: try turn(), as: UTF8.self)
        XCTAssertEqual(try parser.parseTurn(envelope(content), context: context()),
                       try parser.parseTurn(turn(), context: context()))
        let draft = try JSONSerialization.data(withJSONObject: ["schema_version": "1.0.0", "text": "我还不确定适不适合我", "source_refs": [user]])
        XCTAssertEqual(try parser.parseUnderstanding(envelope(String(decoding: draft, as: UTF8.self)), context: context()).text,
                       "我还不确定适不适合我")
        for invalid in ["```json\n\(content)\n```", "说明\n\(content)", "", "{}"] {
            XCTAssertThrowsError(try parser.parseTurn(envelope(invalid), context: context()))
        }
        for choices: [[String: Any]] in [[], [["message": ["content": content]], ["message": ["content": content]]], [["message": ["content": NSNull()]]]] {
            XCTAssertThrowsError(try parser.parseTurn(JSONSerialization.data(withJSONObject: ["choices": choices]), context: context()))
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
            { $0["suggested_actions"] = ["reply", "finish", "draft_understanding"] },
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
        XCTAssertThrowsError(try parser.parseTurn(reflection, context: context(intent: .directTeaching))) {
            XCTAssertEqual($0 as? MentorResponseError, .intentMismatch)
        }
        XCTAssertThrowsError(try parser.parseTurn(turn(), context: context(intent: .finish)))
    }

    func testRepeatedPreviousQuestionIsRejectedDeterministically() throws {
        let previous = "这次具体哪一步发生了变化？"
        let context = try MentorResponseValidationContext(
            sentSources: [try MentorSourceReference(user)], userExpressionSources: [try MentorSourceReference(user)],
            materialQuestionCount: 0, previousAssistantQuestion: previous)
        let repeated = try turn {
            $0["question"] = "这次具体哪一步发生了变化？"
            $0["question_purpose"] = "material"
        }
        XCTAssertThrowsError(try parser.parseTurn(repeated, context: context)) {
            XCTAssertEqual($0 as? MentorResponseError, .repeatedQuestion)
        }
        let changed = try turn {
            $0["question"] = "哪一个结果最值得先核对？"
            $0["question_purpose"] = "reflection"
        }
        XCTAssertNoThrow(try parser.parseTurn(changed, context: context))
    }

    func testMentorQualityPolicyRequiresGroundingAndAReviewDoorway() throws {
        let grounded = try parser.parseTurn(turn(), context: context())
        XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(grounded.response, context: context(),
            initialEntry: "discuss", intent: "reply"))

        let ungroundedData = try turn { $0["source_refs"] = [] }
        let ungrounded = try parser.parseTurn(ungroundedData, context: context())
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(ungrounded.response, context: context(),
            initialEntry: "discuss", intent: "reply")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.missingSourceGrounding))
        }

        let ungroundedMaterialGapData = try turn {
            $0["material_status"] = "missing"
            $0["action"] = "clarify"
            $0["question"] = "当时具体发生了什么？"
            $0["question_purpose"] = "material"
            $0["source_refs"] = []
        }
        let ungroundedMaterialGap = try parser.parseTurn(ungroundedMaterialGapData, context: context())
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(ungroundedMaterialGap.response, context: context(),
            initialEntry: "discuss", intent: "reply")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.missingSourceGrounding))
        }
        let groundedMaterialGapData = try turn {
            $0["material_status"] = "missing"
            $0["action"] = "clarify"
            $0["question"] = "当时具体发生了什么？"
            $0["question_purpose"] = "material"
        }
        let groundedMaterialGap = try parser.parseTurn(groundedMaterialGapData, context: context())
        XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(groundedMaterialGap.response, context: context(),
            initialEntry: "discuss", intent: "reply"))

        let olderRef = try MentorSourceReference("item:cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let latestRef = try MentorSourceReference(user)
        let multiTurnContext = try MentorResponseValidationContext(
            sentSources: [olderRef, latestRef], userExpressionSources: [olderRef, latestRef],
            materialQuestionCount: 0, latestUserExpressionSource: latestRef)
        let anchoredToOlderTurnData = try turn { $0["source_refs"] = [olderRef.value] }
        let anchoredToOlderTurn = try parser.parseTurn(anchoredToOlderTurnData, context: multiTurnContext)
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(anchoredToOlderTurn.response,
            context: multiTurnContext, initialEntry: "discuss", intent: "reply")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.missingSourceGrounding))
        }
        let anchoredToLatestTurn = try parser.parseTurn(turn(), context: multiTurnContext)
        XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(anchoredToLatestTurn.response,
            context: multiTurnContext, initialEntry: "discuss", intent: "reply"))

        let directTeachingWithoutSource = try parser.parseTurn(
            turn { $0["source_refs"] = [] }, context: context(intent: .directTeaching))
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(directTeachingWithoutSource.response,
            context: context(intent: .directTeaching), initialEntry: "discuss", intent: "explain")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.missingSourceGrounding))
        }

        let genericData = try turn { $0["body"] = "请说说你的感受" }
        let generic = try parser.parseTurn(genericData, context: context())
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(generic.response, context: context(),
            initialEntry: "discuss", intent: "reply")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.genericResponse))
        }

        let hiddenQuestionData = try turn { $0["body"] = "你已经完成了这一步？接下来可以直接结束。" }
        let hiddenQuestion = try parser.parseTurn(hiddenQuestionData, context: context())
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(hiddenQuestion.response, context: context(),
            initialEntry: "discuss", intent: "reply")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.hiddenQuestionInBody))
        }

        let quotedQuestionData = try turn { $0["body"] = "你写过“我是不是漏掉某一步？”；这句话显示你在找因果链。" }
        let quotedQuestion = try parser.parseTurn(quotedQuestionData, context: context())
        XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(quotedQuestion.response, context: context(),
            initialEntry: "discuss", intent: "reply"))

        let demonstrationData = try turn {
            $0["body"] = "可以这样问：“这场兼职能否改到周日，具体时间是什么时候？”；这只是询问，并未承诺参加。"
            $0["question"] = NSNull(); $0["question_purpose"] = NSNull()
        }
        let demonstration = try parser.parseTurn(demonstrationData, context: context())
        XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(demonstration.response, context: context(),
            initialEntry: "discuss", intent: "reply"))
        let hiddenFollowup = try turn {
            $0["body"] = "可以这样问：“这场兼职能否改到周日？”；你打算什么时候去问？"
        }
        let extraQuestion = try parser.parseTurn(hiddenFollowup, context: context())
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(extraQuestion.response, context: context(),
            initialEntry: "discuss", intent: "reply")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.hiddenQuestionInBody))
        }

        let emptyContext = try context(hasUser: false)
        let openingData = try turn { $0["source_refs"] = []; $0["question"] = NSNull(); $0["question_purpose"] = NSNull() }
        let opening = try parser.parseTurn(openingData, context: emptyContext)
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(opening.response, context: emptyContext,
            initialEntry: "review", intent: "review")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.reviewOpeningNeedsQuestion))
        }

        let genericOpeningData = try turn {
            $0["source_refs"] = []
            $0["question"] = "你今天想聊什么？"
            $0["question_purpose"] = "material"
        }
        let genericOpening = try parser.parseTurn(genericOpeningData, context: emptyContext)
        XCTAssertThrowsError(try MentorResponseQualityPolicy.validate(genericOpening.response, context: emptyContext,
            initialEntry: "review", intent: "review")) {
            XCTAssertEqual($0 as? MentorResponseError, .qualityGateFailed(.reviewOpeningNeedsSpecificDoorway))
        }

        let validOpeningData = try turn {
            $0["source_refs"] = []
            $0["question"] = "你想先回想哪一个片段？"
            $0["question_purpose"] = "material"
            $0["material_status"] = "missing"
        }
        let validOpening = try parser.parseTurn(validOpeningData, context: emptyContext)
        XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(validOpening.response, context: emptyContext,
            initialEntry: "review", intent: "review"))
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

extension MentorResponseParserTests {
    func testCaptureSourceResolverRequiresOwnedOriginalSnapshotAndValidHash() throws {
        let sessionID = UUID(), itemID = UUID(), captureID = UUID()
        let reference = try MentorSourceReference("capture:\(captureID.uuidString)")
        let item = MentorTimelineItem(id: itemID, sessionID: sessionID, sequence: 1, kind: .user, payloadJSON: "{\"text\":\"所选择的闪念原文\"}")
        let link = MentorSourceLink(id: UUID(), sessionID: sessionID, ownerKind: .item, ownerID: itemID,
            sourceKind: "capture", sourceID: captureID.uuidString, sourceVersion: nil,
            contentHash: MentorSourceResolver.hash("所选择的闪念原文"), availability: .available)
        let resolver = MentorSourceResolver()
        let resolved = resolver.resolve([reference], sessionID: sessionID, timeline: [item], understandings: [], links: [link])
        XCTAssertEqual(resolved.first?.status, .available)
        XCTAssertEqual(resolved.first?.title, "闪念来源")
        XCTAssertEqual(resolved.first?.content, "所选择的闪念原文")
        XCTAssertFalse(resolver.resolve([reference], sessionID: sessionID, timeline: [item], understandings: [], links: []).first?.isAvailable ?? true)
        XCTAssertFalse(resolver.resolve([reference], sessionID: UUID(), timeline: [item], understandings: [], links: [link]).first?.isAvailable ?? true)
        let mismatched = MentorTimelineItem(id: itemID, sessionID: sessionID, sequence: 1, kind: .user, payloadJSON: "{\"text\":\"被替换的文字\"}")
        XCTAssertFalse(resolver.resolve([reference], sessionID: sessionID, timeline: [mismatched], understandings: [], links: [link]).first?.isAvailable ?? true)
        let deleted = MentorSourceLink(id: link.id, sessionID: sessionID, ownerKind: .item, ownerID: itemID,
            sourceKind: "capture", sourceID: captureID.uuidString, sourceVersion: nil, contentHash: link.contentHash, availability: .deleted)
        XCTAssertEqual(resolver.resolve([reference], sessionID: sessionID, timeline: [item], understandings: [], links: [deleted]).first?.status, .deleted)
    }
}


extension MentorResponseParserTests {
    func testLegacySourcesRequireExplicitScopeAndPreserveOriginalRoles() throws {
        let sessionID = UUID(), roundID = UUID(), itemID = UUID()
        let original = SingleNudgeSession(id: roundID, dayKey: "2026-10-03", input: "  用户原文\n保留换行  ",
            question: "模型提出的问题", diagnosis: "旧模型的判断", before: "最初想法", after: "我后来写的回答",
            cognitiveShift: "模型推测的变化", thinkingAction: "模型给的建议", unresolvedUncertainty: "尚未明确")
        let round = LegacyNudgeRound(session: original, promptRun: nil, reviewPromptRun: nil)
        let ref = try MentorSourceReference("legacy-nudge:\(roundID.uuidString)")
        let item = MentorTimelineItem(id: itemID, sessionID: sessionID, sequence: 1, kind: .user,
            payloadJSON: String(decoding: try JSONEncoder().encode(["text": original.input]), as: UTF8.self))
        func link(owner: UUID = itemID, ownerSession: UUID = sessionID, hash: String? = nil,
                  availability: MentorSourceAvailability = .available) -> MentorSourceLink {
            MentorSourceLink(id: UUID(), sessionID: ownerSession, ownerKind: .item, ownerID: owner,
                sourceKind: "legacy-nudge", sourceID: roundID.uuidString, sourceVersion: nil,
                contentHash: hash, availability: availability)
        }
        let resolver = MentorSourceResolver()
        let content = MentorSourceResolver.legacyContent(original)
        let signed = link(hash: MentorSourceResolver.hash(content))
        let detail = try XCTUnwrap(resolver.resolve([ref], sessionID: sessionID, timeline: [item],
            understandings: [], links: [signed], legacyRounds: [round]).first)
        XCTAssertTrue(detail.isAvailable)
        XCTAssertTrue(try XCTUnwrap(detail.content).contains(original.input))
        XCTAssertTrue(content.contains("当时的问题（AI）\n模型提出的问题"))
        XCTAssertTrue(content.contains("你的回答\n我后来写的回答"))
        XCTAssertTrue(content.contains("当时的分析（AI）\n旧模型的判断"))
        XCTAssertTrue(content.contains("不等于你已确认"))
        for invalid in [[], [link(owner: UUID())], [link(ownerSession: UUID())], [link(hash: "sha256:wrong")]] {
            XCTAssertFalse(resolver.resolve([ref], sessionID: sessionID, timeline: [item], understandings: [],
                links: invalid, legacyRounds: [round]).first?.isAvailable ?? true)
        }
        XCTAssertFalse(resolver.resolve([ref], sessionID: sessionID, timeline: [item], understandings: [],
            links: [signed], legacyRounds: []).first?.isAvailable ?? true)
        XCTAssertEqual(resolver.resolve([ref], sessionID: sessionID, timeline: [item], understandings: [],
            links: [link(availability: .deleted)], legacyRounds: [round]).first?.status, .deleted)
        let history = LegacyNudgeChain(rootID: sessionID, rounds: [round], issues: [])
        XCTAssertTrue(resolver.resolve([ref], sessionID: sessionID, timeline: [], understandings: [], links: [],
            legacyRounds: [round], legacyHistory: history).first?.isAvailable ?? false)
        let foreignHistory = LegacyNudgeChain(rootID: UUID(), rounds: [round], issues: [])
        XCTAssertFalse(resolver.resolve([ref], sessionID: sessionID, timeline: [], understandings: [], links: [],
            legacyRounds: [round], legacyHistory: foreignHistory).first?.isAvailable ?? true)
        // Existing links without hashes remain readable through their real owner.
        XCTAssertTrue(resolver.resolve([ref], sessionID: sessionID, timeline: [item], understandings: [],
            links: [link()], legacyRounds: [round]).first?.isAvailable ?? false)
    }
}
