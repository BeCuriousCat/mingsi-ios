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

    func testSelectedHistoryCannotReplaceAnUnselectedCurrentRequest() throws {
        let s = session()
        let old = try user(s, 1, "以前我只关心完成速度。")
        let latest = try user(s, 3, "现在更在意可靠性，按新标准比较，不要重复旧结论。")
        let fragment = try XCTUnwrap(MentorContextBuilder.materialSelectionCandidates(items: [old]).first)
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s,
            items: [old, assistant(s, 2), latest], intent: "reply", selectedMaterialFragments: [fragment]),
            "Selecting historical material must not relabel it as the latest request")
    }

    func testSelectedAssistantBodyDoesNotSendItsUnselectedQuestionOrOriginalUserText() throws {
        let s = session()
        let old = try user(s, 1, "未选中的私人原话不应发送。")
        let reply = MentorTimelineItem(id: UUID(), sessionID: s.id, sequence: 2, kind: .assistant,
            payloadJSON: "{\"body\":\"完成是动作结束，有效是目标结果发生变化。\",\"question\":\"未选中的旧问题也不应发送？\",\"source_refs\":[\"未选中的内部引用\"]}")
        let latest = try user(s, 3, "请解释选中的这段话，不补问。")
        let candidates = MentorContextBuilder.materialSelectionCandidates(items: [old, reply, latest])
        let body = try XCTUnwrap(candidates.first { $0.sourceID == reply.id && $0.text.hasPrefix("完成是") })
        let current = try XCTUnwrap(candidates.first { $0.sourceID == latest.id })
        let built = try MentorContextBuilder().build(session: s, items: [old, reply, latest], intent: "reply",
            selectedMaterialFragments: [body, current])
        XCTAssertTrue(built.json.contains(body.text))
        XCTAssertFalse(built.json.contains("未选中的"))
        XCTAssertNil(built.payload.conversationState.previousAssistantQuestion)
        XCTAssertEqual(built.payload.latestUserSourceRef, try MentorSourceReference("item:" + latest.id.uuidString))
        XCTAssertEqual(built.payload.sources.filter { $0.role == .assistant }.count, 1)
        XCTAssertFalse(built.validation.userExpressionSources.contains(try MentorSourceReference("item:" + reply.id.uuidString)))
    }

    func testExplicitSelectionRetainsAllChosenGroupsAndRejectsBudgetOverflow() throws {
        let s = session()
        let items = try (1...9).map { try user(s, $0, "Selected source \($0)") }
        let fragments = MentorContextBuilder.materialSelectionCandidates(items: items)
        let built = try MentorContextBuilder().build(session: s, items: items, intent: "reply", selectedMaterialFragments: fragments)
        XCTAssertEqual(built.payload.recentExchanges.count, 9)
        XCTAssertEqual(built.payload.sources.count, 9)
        XCTAssertTrue(built.omittedItemIDs.isEmpty)
        XCTAssertEqual(built.payload.conversationState.usesSelectedExcerpts, true)
        XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: items, intent: "reply",
            characterLimit: 800, selectedMaterialFragments: fragments)) { error in
            guard case MentorContextError.requiresMaterialSelection = error else { return XCTFail("Expected budget error, got \(error)") }
        }
    }

    func testOnlyExplicitlySelectedQuestionIsSentAndOlderReplyIsNotAdjacent() throws {
        let s = session()
        let first = try user(s, 1, "Old private text")
        let reply = MentorTimelineItem(id: UUID(), sessionID: s.id, sequence: 2, kind: .assistant,
            payloadJSON: "{\"body\":\"Omitted body\",\"question\":\"Which result changed?\"}")
        let middle = try user(s, 3, "Omitted middle")
        let adjacent = assistant(s, 4)
        let latest = try user(s, 5, "Explain that question")
        let items = [first, reply, middle, adjacent, latest]
        let candidates = MentorContextBuilder.materialSelectionCandidates(items: items)
        let chosen = candidates.filter { $0.sourceID == latest.id || ($0.sourceID == reply.id && $0.field == .assistantQuestion) }
        let built = try MentorContextBuilder().build(session: s, items: items, intent: "reply", selectedMaterialFragments: chosen)
        XCTAssertTrue(built.json.contains("Which result changed?"))
        XCTAssertFalse(built.json.contains("Omitted"))
        XCTAssertNil(built.payload.conversationState.previousAssistantRef)
        XCTAssertNil(built.payload.conversationState.previousAssistantQuestion)
        XCTAssertEqual(built.payload.currentExchangeRefs, [try MentorSourceReference("item:" + latest.id.uuidString)])
        let paired = try MentorContextBuilder().build(session: s, items: [first, reply, latest], intent: "reply", selectedMaterialFragments: chosen)
        XCTAssertEqual(paired.payload.conversationState.previousAssistantQuestion, "Which result changed?")
    }

    func testForgedExcerptAndWrongFieldAreRejected() throws {
        let s = session()
        let latest = try user(s, 1, "Only this source text")
        for fragment in [
            MentorMaterialFragment(id: UUID(), sourceID: latest.id, label: "", text: "invented"),
            MentorMaterialFragment(id: UUID(), sourceID: UUID(), label: "", text: "Only"),
            MentorMaterialFragment(id: UUID(), sourceID: latest.id, label: "", text: "Only", field: .assistantBody)
        ] {
            XCTAssertThrowsError(try MentorContextBuilder().build(session: s, items: [latest], intent: "reply",
                selectedMaterialFragments: [fragment])) { XCTAssertEqual($0 as? MentorContextError, .invalidMaterialSelection) }
        }
    }

    func testExcerptMetadataIsOptionalForLegacyDecodeAndFrozenReplay() throws {
        let s = session()
        let item = try user(s, 1, "Current source")
        let builder = MentorContextBuilder()
        let legacy = try builder.build(session: s, items: [item], intent: "reply")
        XCTAssertFalse(legacy.json.contains("usesSelectedExcerpts"))
        XCTAssertNil(try builder.replay(json: legacy.json, session: s).payload.conversationState.usesSelectedExcerpts)
        let fragments = MentorContextBuilder.materialSelectionCandidates(items: [item])
        let selected = try builder.build(session: s, items: [item], intent: "reply", selectedMaterialFragments: fragments)
        XCTAssertEqual(try builder.replay(json: selected.json, session: s).payload.conversationState.usesSelectedExcerpts, true)
        let teaching = try builder.build(session: s, items: [item], intent: "explain", responseIntent: .directTeaching,
            selectedMaterialFragments: fragments, suppressCurrentUserAnchor: true)
        XCTAssertNil(teaching.payload.latestUserSourceRef)
        XCTAssertFalse(teaching.payload.allowsMaterialQuestion)
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

    func testVisibleTurnIndexIsIndependentOfRecentExchangeWindowAndMaterialSelection() throws {
        let s = session()
        var items: [MentorTimelineItem] = []
        for index in 0..<8 {
            items.append(try user(s, index * 2 + 1, "Original \(index)"))
            items.append(assistant(s, index * 2 + 2))
        }
        let latest = try user(s, 17, "请继续解释")
        items.append(latest)
        let builder = MentorContextBuilder()
        let built = try builder.build(session: s, items: items, intent: "reply")
        XCTAssertEqual(built.payload.recentExchanges.count, 6)
        XCTAssertEqual(built.payload.conversationState.visibleTurnIndex, 9)

        let fragment = try XCTUnwrap(MentorContextBuilder.materialSelectionCandidates(items: [latest]).first)
        let selected = try builder.build(session: s, items: items, intent: "reply",
            selectedMaterialFragments: [fragment])
        XCTAssertEqual(selected.payload.sources.filter { $0.role == .user }.map(\.content), [fragment.text])
        XCTAssertEqual(selected.payload.conversationState.visibleTurnIndex, 9)
    }

    func testBudgetCannotDiscardPreviousResponseNeededByShortFollowUp() throws {
        let s = session()
        let first = try user(s, 1, "解释一下动作和效果的区别")
        let previous = MentorTimelineItem(id: UUID(), sessionID: s.id, sequence: 2, kind: .assistant,
            payloadJSON: String(decoding: try JSONEncoder().encode([
                "body": String(repeating: "A detailed response. ", count: 150),
                "question": "Which outcome changed?"
            ]), as: UTF8.self))
        let latest = try user(s, 3, "这是什么意思？")
        let builder = MentorContextBuilder()
        let full = try builder.build(session: s, items: [first, previous, latest], intent: "reply")
        XCTAssertEqual(full.payload.conversationState.previousAssistantQuestion, "Which outcome changed?")

        XCTAssertThrowsError(try builder.build(session: s, items: [first, previous, latest],
            intent: "reply", characterLimit: 2000)) { error in
            guard case MentorContextError.requiresMaterialSelection = error else {
                return XCTFail("The previous response must not silently disappear: \(error)")
            }
        }
    }

    func testCorrectionMarksEarlierAssistantAsHistoricalAndRejectsItsReuseAsCurrentEvidence() throws {
        let s = session(), original = try user(s, 1, "所有人失败")
        let oldResponse = assistant(s, 2)
        let correction = try user(s, 3, "仅一人失败", correcting: original.id)
        let built = try MentorContextBuilder().build(session: s, items: [original, oldResponse, correction], intent: "reply")
        let oldRef = try MentorSourceReference("item:" + oldResponse.id.uuidString)
        XCTAssertEqual(built.payload.sources.first { $0.ref == oldRef }?.isCurrent, false)
        XCTAssertTrue(built.validation.supersededSources.contains(oldRef))
        let data = try JSONSerialization.data(withJSONObject: [
            "schema_version": "1.0.0", "action": "explain", "material_status": "usable", "body": "沿用旧判断",
            "question": NSNull(), "question_purpose": NSNull(), "source_refs": [oldRef.value],
            "lesson_ref": NSNull(), "suggested_actions": []
        ])
        XCTAssertThrowsError(try MentorResponseParser().parseTurn(data, context: built.validation))
    }

    func testPayloadExplicitlyAnchorsLatestUserExpressionAndCurrentExchange() throws {
        let s = session()
        let first = try user(s, 1, "旧问题")
        let oldResponse = assistant(s, 2)
        let latest = try user(s, 3, "我改成想听直接解释")
        let built = try MentorContextBuilder().build(session: s, items: [first, oldResponse, latest], intent: "reply")
        let latestRef = try MentorSourceReference("item:" + latest.id.uuidString)
        let oldResponseRef = try MentorSourceReference("item:" + oldResponse.id.uuidString)
        XCTAssertEqual(built.payload.latestUserSourceRef, latestRef)
        XCTAssertEqual(built.payload.currentExchangeRefs, [oldResponseRef, latestRef])
        let decoded = try JSONDecoder().decode(MentorContextPayload.self, from: Data(built.json.utf8))
        XCTAssertEqual(decoded.latestUserSourceRef, latestRef)
        XCTAssertEqual(decoded.currentExchangeRefs, [oldResponseRef, latestRef])
        XCTAssertTrue(decoded.conversationState.hasNewUserExpression)
        XCTAssertEqual(decoded.conversationState.previousAssistantRef, oldResponseRef)
        XCTAssertNil(decoded.conversationState.previousAssistantQuestion)
    }

    func testConversationStateCarriesPreviousQuestionWithoutTreatingItAsUserEvidence() throws {
        let s = session()
        let first = try user(s, 1, "我总觉得这次改动没有效果")
        let oldResponse = MentorTimelineItem(id: UUID(), sessionID: s.id, sequence: 2, kind: .assistant,
            payloadJSON: "{\"schema_version\":\"1.0.0\",\"action\":\"clarify\",\"material_status\":\"missing\",\"body\":\"先确认一个具体变化。\",\"question\":\"这次具体哪一步发生了变化？\",\"question_purpose\":\"material\",\"source_refs\":[],\"lesson_ref\":null,\"suggested_actions\":[]}")
        let latest = try user(s, 3, "我想先听你解释为什么要区分动作和效果")
        let built = try MentorContextBuilder().build(session: s, items: [first, oldResponse, latest], intent: "reply")
        XCTAssertEqual(built.payload.conversationState.visibleTurnIndex, 2)
        XCTAssertTrue(built.payload.conversationState.hasNewUserExpression)
        XCTAssertEqual(built.payload.conversationState.previousAssistantRef,
                       try MentorSourceReference("item:" + oldResponse.id.uuidString))
        XCTAssertEqual(built.payload.conversationState.previousAssistantQuestion, "这次具体哪一步发生了变化？")
        XCTAssertEqual(built.payload.conversationState.previousAssistantQuestionPurpose, .material)
        XCTAssertEqual(built.validation.previousAssistantQuestion, "这次具体哪一步发生了变化？")
        XCTAssertEqual(built.validation.latestUserExpressionSource,
                       try MentorSourceReference("item:" + latest.id.uuidString))
    }

    func testSecondReviewTurnKeepsUnusedRecallBudgetAvailable() throws {
        let s = session()
        let opening = MentorTimelineItem(id: UUID(), sessionID: s.id, sequence: 1, kind: .assistant,
            payloadJSON: """
            {"schema_version":"1.0.0","action":"clarify","material_status":"missing","body":"可以从一个让你停下来的时刻开始。","question":"今天有没有哪件事让你停下来或改了原计划？","question_purpose":"material","source_refs":[],"lesson_ref":null,"suggested_actions":[]}
            """)
        let reply = try user(s, 2, "今天主要在开发，上午改了一个接口，下午补了文档；还没说清楚具体哪一步值得回看。")

        let built = try MentorContextBuilder().build(session: s, items: [opening, reply], intent: "reply")

        XCTAssertEqual(built.payload.initialEntry, "review")
        XCTAssertEqual(built.payload.conversationState.visibleTurnIndex, 2)
        XCTAssertEqual(built.payload.materialQuestionCount, 0)
        XCTAssertTrue(built.payload.allowsMaterialQuestion)
        XCTAssertEqual(built.payload.conversationState.previousAssistantQuestionPurpose, .material)
        XCTAssertEqual(built.payload.latestUserSourceRef,
                       try MentorSourceReference("item:" + reply.id.uuidString))
    }

    func testExplicitTeachingIntentDoesNotReusePreviousUserAsCurrentAsk() throws {
        let s = session()
        let first = try user(s, 1, "上一轮的具体问题")
        let response = assistant(s, 2)
        let built = try MentorContextBuilder().build(session: s, items: [first, response], intent: "explain",
            responseIntent: .directTeaching, suppressCurrentUserAnchor: true)
        XCTAssertNil(built.payload.latestUserSourceRef)
        XCTAssertEqual(built.payload.currentExchangeRefs.count, 2)
        XCTAssertTrue(built.validation.userExpressionSources.contains(try MentorSourceReference("item:" + first.id.uuidString)))
        XCTAssertFalse(built.payload.allowsMaterialQuestion)
    }

    func testLegacyPayloadWithoutTurnAnchorsStillDecodes() throws {
        let json = """
        {"schema_version":"1.0.0","session_id":"\(session().id.uuidString)","semantic_revision":0,"request_epoch":0,"initial_entry":"review","intent":"reply","material_question_count":0,"allows_material_question":true,"sources":[],"recent_exchanges":[],"lesson_candidates":[]}
        """
        let decoded = try JSONDecoder().decode(MentorContextPayload.self, from: Data(json.utf8))
        XCTAssertNil(decoded.latestUserSourceRef)
        XCTAssertTrue(decoded.currentExchangeRefs.isEmpty)
        XCTAssertEqual(decoded.conversationState, .empty)
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

    func testExplicitMaterialFragmentsAreTheOnlyUserTextSent() throws {
        let s = session()
        let original = try user(s, 1, String(repeating: "完整事实", count: 5000))
        let candidates = MentorContextBuilder.materialSelectionCandidates(items: [original], maximumCharacters: 1000)
        XCTAssertEqual(candidates.count, 20)
        let built = try MentorContextBuilder().build(session: s, items: [original], intent: "reply",
            characterLimit: 24_000, selectedMaterialFragments: [candidates[2]])
        let source = try XCTUnwrap(built.payload.sources.first { $0.role == .user })
        XCTAssertEqual(source.content, candidates[2].text)
        XCTAssertEqual(built.json.filter { $0 == "完" }.count, candidates[2].text.filter { $0 == "完" }.count)
        XCTAssertTrue(built.validation.userExpressionSources.contains(source.ref))
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
        XCTAssertEqual(built.payload.conversationState.visibleTurnIndex, 6)
        XCTAssertEqual(built.payload.recentExchanges.last?.last, try MentorSourceReference("item:" + items.last!.id.uuidString))
        XCTAssertEqual(built.validation.userExpressionSources.count, 6)
        for group in built.payload.recentExchanges { XCTAssertEqual(group.count, 2) }
    }
}
