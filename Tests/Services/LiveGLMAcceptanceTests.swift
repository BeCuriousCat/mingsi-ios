import XCTest
@testable import MingSi

final class LiveGLMAcceptanceTests: XCTestCase {
    func testLiveLensGoalsWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["MINGSI_LIVE_LENS_GOALS_JSON"] else {
            throw XCTSkip("Explicit synthetic GPT lens-goal evaluation only")
        }
        struct Step: Decodable { let answer: String?; let mode: String; let goals: [String] }
        struct Scenario: Decodable {
            let id: String; let lens: String; let text: String; let steps: [Step]
        }
        let cases = try JSONDecoder().decode([Scenario].self, from: Data(raw.utf8))
        guard !cases.isEmpty, cases.count <= 20,
              cases.reduce(0, { $0 + $1.steps.count }) <= 24,
              Set(cases.map(\.id)).count == cases.count,
              cases.allSatisfy({ ThinkingLens(rawValue: $0.lens) != nil && !$0.steps.isEmpty && $0.steps.allSatisfy({ ["question", "explanation", "none"].contains($0.mode) }) }) else {
            throw NSError(domain: "LensGoals", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid bounded scenario dataset"])
        }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let config = try harness.mentorConfiguration()
        for scenario in cases {
            let card = ThinkingCard(type: .decision, title: "合成场景·" + scenario.id, body: scenario.text, isConfirmed: true)
            let draft = DailyEntryDraft(rawText: scenario.text, selectedLens: ThinkingLens(rawValue: scenario.lens))
            var answered: [ReflectionQuestion] = []
            for (offset, step) in scenario.steps.enumerated() {
                let id = scenario.id + "-turn-" + String(offset + 1)
                if let answer = step.answer {
                    guard !answered.isEmpty else { XCTFail("Missing actual prior question for " + id); break }
                    answered[answered.count - 1].answer = answer
                }
                let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: config))
                var report: [String: Any] = ["case_id": id, "lens": scenario.lens,
                    "expected_mode": step.mode, "semantic_goals": step.goals, "semantic_review_required": true]
                let start = ContinuousClock.now
                do {
                    let turn = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                        .generateQuestionTurnWithTrace(for: TodayAIContext(draft: draft, confirmedCards: [card], questions: answered)).value
                    var accepted: [String: Any] = ["questions": try JSONSerialization.jsonObject(with: JSONEncoder().encode(turn.questions))]
                    if let explanation = turn.explanation {
                        accepted["explanation"] = ["text": explanation.text, "source_card_titles": explanation.sourceCardTitles]
                    }
                    report["accepted_turn"] = accepted
                    let mode = !turn.questions.isEmpty ? "question" : (turn.explanation == nil ? "none" : "explanation")
                    report["actual_mode"] = mode
                    report["structural_pass"] = mode == step.mode && turn.questions.count <= 1
                    XCTAssertEqual(mode, step.mode, id)
                    XCTAssertLessThanOrEqual(turn.questions.count, 1, id)
                    for question in turn.questions { XCTAssertEqual(question.sourceCardTitles, [card.title], id) }
                    if let explanation = turn.explanation { XCTAssertEqual(explanation.sourceCardTitles, [card.title], id) }
                    answered.append(contentsOf: turn.questions)
                } catch {
                    report["structural_pass"] = false
                    report["error"] = String(describing: error)
                    XCTFail(id + ": " + String(describing: error))
                }
                let duration = start.duration(to: .now).components
                report["seconds"] = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
                report["model_alias"] = config.model
                report["http_request_records"] = client.records.count
                XCTAssertEqual(client.records.count, 1, "One request per synthetic turn; no retry")
                for record in client.records {
                    try attachMentorRequest(record.request, caseID: "lens-goal-" + id)
                    report["prompt_version"] = record.request.prompt.version
                    if let data = record.data {
                        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                        attachment.name = "lens-goal-" + id + "-response"; attachment.lifetime = .keepAlways; add(attachment)
                    }
                }
                let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
                attachment.name = "lens-goal-" + id + "-result"; attachment.lifetime = .keepAlways; add(attachment)
                // Infrastructure failure ends the paid batch. A completed response rejected
                // by the production parser is retained and other distinct cases may continue.
                if client.records.last?.data == nil { return }
            }
        }
    }

    @MainActor
    func testLiveAuditedMentorStreamingWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_MENTOR_STREAMING"] == "1" else { throw XCTSkip("Explicit single streaming acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let config = try harness.mentorConfiguration()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-mentor-stream-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("conversation.sqlite")
        let db = try AppDatabase(url: url)
        let repository = SQLiteMentorRepository(database: db)
        let runs = SQLitePromptRunRepository(database: db)
        let capture = LiveMentorStoreCaptureTransport(base: DirectGLMClient(apiKey: key, configuration: config))
        let gateway = CentralLLMDecisionCenter(base: PromptTracingLLMClient(base: capture, repository: runs,
            modelProvider: "Responses", modelName: config.model, mentorAudit: repository))
        let store = MentorFeatureStore(repository: repository, transport: gateway,
            catalog: try MentorLessonCatalog.loadBundled(), requestPolicy: .forProtocol(config.protocolKind))
        store.start(entry: "discuss")
        for _ in 0..<100 where store.state.phase != .editing { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(store.state.phase, .editing)
        let start = ContinuousClock.now
        var firstPreview: Double?, longestPreview = 0
        store.submit(text: "请直接解释‘按计划完成一次尝试’和‘有证据说明有效’的区别，用一个明确标为假设的小例子。不要追问，也不要给练习。")
        let deadline = start.advanced(by: .seconds(610))
        while ContinuousClock.now < deadline {
            if store.state.phase == .submitting, !store.state.streamingPreview.isEmpty {
                if firstPreview == nil {
                    let elapsed = start.duration(to: .now).components
                    firstPreview = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                }
                longestPreview = max(longestPreview, store.state.streamingPreview.count)
            }
            if store.state.phase == .showingResponse { break }
            if case .failed = store.state.phase { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let elapsed = start.duration(to: .now).components
        let total = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        let metadata: [String: Any] = ["firstPreviewSeconds": firstPreview ?? -1,
            "completionSeconds": total, "longestPreviewCharacters": longestPreview,
            "requests": capture.records.count, "completed": store.state.phase == .showingResponse]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json")
        attachment.name = "mentor-streaming-timing"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertNotNil(firstPreview, "Live transport must expose body before completion")
        XCTAssertGreaterThan(longestPreview, 0)
        XCTAssertEqual(capture.records.count, 1, "Never retry this paid request")
        guard store.state.phase == .showingResponse else {
            XCTFail("Single streaming request did not finish; no retry was sent"); return
        }
        XCTAssertLessThan(try XCTUnwrap(firstPreview), total)
        XCTAssertTrue(store.state.streamingPreview.isEmpty)
        let savedRuns = try await runs.recentPromptRuns(limit: 10)
        XCTAssertEqual(savedRuns.count, 1)
        XCTAssertEqual(savedRuns.first?.id, capture.records.first?.request.traceID)
        let response = try XCTUnwrap(store.state.response?.response)
        XCTAssertEqual(response.action, .explain)
        XCTAssertNil(response.question)
        let id = try XCTUnwrap(store.state.session?.id)
        let reopened = try await SQLiteMentorRepository(database: AppDatabase(url: url)).items(sessionID: id)
        XCTAssertEqual(reopened.filter { $0.kind == .assistant }.count, 1)
        let responseAttachment = XCTAttachment(data: try JSONEncoder().encode(reopened), uniformTypeIdentifier: "public.json")
        responseAttachment.name = "mentor-streaming-persisted-timeline"; responseAttachment.lifetime = .keepAlways; add(responseAttachment)
    }

    func testLiveSelectedTeacherExcerptWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_SELECTED_EXCERPT"] == "1" else { throw XCTSkip("Explicit selected-excerpt acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let config = try harness.mentorConfiguration()
        let session = MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now)
        let old = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 1, kind: .user,
            payloadJSON: "{\"text\":\"未选私密标记：海蓝色信封。\"}")
        let teacher = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 2, kind: .assistant,
            payloadJSON: "{\"body\":\"完成是动作结束，有效是目标结果发生变化。\",\"question\":\"未选问题标记：周三下午。\"}")
        let current = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 3, kind: .user,
            payloadJSON: "{\"text\":\"请直接解释选中的这句话是什么意思，给一个明确标成假设的例子，不要猜我的过去经历，也不要再提问或布置任务。\"}")
        let items = [old, teacher, current]
        let fragments = MentorContextBuilder.materialSelectionCandidates(items: items).filter {
            $0.sourceID == current.id || ($0.sourceID == teacher.id && $0.field == .assistantBody)
        }
        let built = try MentorContextBuilder().build(session: session, items: items, intent: "reply", selectedMaterialFragments: fragments)
        XCTAssertFalse(built.json.contains("未选"))
        var request = LLMRequest(prompt: LocalPromptProvider().template(for: .mentorRespond, mode: .standard), inputSummary: built.json)
        request.mentorExecutionPolicy = MentorRequestPolicy.forProtocol(config.protocolKind)
        try attachMentorRequest(request, caseID: "selected-excerpt-v216")
        let data = try await completeMentorLiveRequest(request,
            client: DirectGLMClient(apiKey: key, configuration: config), caseID: "selected-excerpt-v216")
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "selected-excerpt-v216-normalized-response"; attachment.lifetime = .keepAlways; add(attachment)
        let response = try MentorResponseParser().parseTurn(data, context: built.validation).response
        try MentorResponseQualityPolicy.validate(response, context: built.validation, initialEntry: "discuss", intent: "reply")
        XCTAssertEqual(response.action, .explain)
        XCTAssertNil(response.question)
        XCTAssertFalse(response.body.contains("海蓝色信封"))
        XCTAssertFalse(response.body.contains("周三下午"))
    }

    @MainActor
    func testLiveMentorUncertaintyAndBoundaryAcrossThreeTurnsWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_MENTOR_UNCERTAINTY"] == "1" else { throw XCTSkip("Explicit new mentor uncertainty and boundary acceptance only") }
        let texts = [
            "同事连续三次下班前把当天的任务交给我，我每次都做到深夜。分工约定这些由他负责，我今晚已决定按时回家。对方为什么这样我不知道，也不想猜。帮我写一句拒绝接活的话，不要再补问。",
            "我还是不知道他是不是故意的。但我愿意继续聊，他今天说‘反正你最后总会做完’，这能证明他故意利用我吗？直接解释，不追加问题。",
            "懂了。我可以不判断他的动机，也坚持今天不接。今天就到这里，不要再帮我准备别的。"
        ]
        try await runPersistedMentorRequestTurns(environment: env, caseID: "mentor-uncertainty",
            texts: texts, expectedActions: [[.explain, .compare, .advise], [.explain, .compare, .advise], [.close]])
    }

    @MainActor
    func testLiveMentorFatigueAndRequestedHelpWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_MENTOR_REQUEST"] == "1" else { throw XCTSkip("Explicit fatigue/request-mode acceptance only") }
        try await runPersistedMentorRequestTurns(environment: env, caseID: "mentor-request",
            texts: [
                "我今天很累，不想再自己列清单。我周日只有半天，兼职能赚三百元，也能陪父母吃饭。这个月房租已留够，未来两周都没别的相聚机会，这次我更在意陪伴。请按这些条件直接建议我怎么选，简短说理由，不要补问，也别只安慰我。",
                "这件事先不分析了。我现在只是想说今天真的很累，你听我说就好，不给建议、不总结、不提问。",
                "现在我想再比较一下：如果下个月房租还差三百元，兼职是这周唯一能补足它的机会，而父母下周也有空，刚才的建议会怎样变？请直接比较一个关键取舍，不问问题，也不要安排任务。"
            ], expectedActions: [[.advise], [.close], [.compare, .advise]])
    }

    @MainActor
    func testLiveMentorRequestedQuestionAndQuotedWordingWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_REQUEST_BOUNDARIES"] == "1" else { throw XCTSkip("Explicit requested-question and quoted-wording acceptance only") }
        try await runPersistedMentorRequestTurns(environment: env, caseID: "mentor-request-boundaries",
            texts: [
                "我今天很累，周六可以接一场兼职，也可以去朋友的告别聚会，时间冲突。两种安排都现实可行，我还没想清自己更在意什么。请先只问我一个现在能回答的问题，帮我厘清选择标准；别替我排序，不要安排调查或练习。",
                "我更在意这次告别，兼职的钱这月并不缺，但我还想问清兼职能否改到周日。请只帮我写一句发给组织者的询问，用问句，不替我承诺周日一定参加，也不要对我追问或安排其他步骤。"
            ], expectedActions: [[.clarify, .compare, .explain], [.explain, .advise]],
            expectedQuestionPresence: [true, false])
    }

    @MainActor
    private func runPersistedMentorRequestTurns(environment env: [String: String], caseID: String,
        texts: [String], expectedActions: [[MentorAction]], expectedQuestionPresence: [Bool]? = nil) async throws {
        precondition(texts.count == expectedActions.count)
        let questionPresence = expectedQuestionPresence ?? Array(repeating: false, count: texts.count)
        precondition(questionPresence.count == texts.count)
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let config = try harness.mentorConfiguration()
        let policy = MentorRequestPolicy.forProtocol(config.protocolKind)
        let transport = LiveMentorStoreCaptureTransport(base: DirectGLMClient(apiKey: key, configuration: config))
        defer {
            for (index, record) in transport.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "\(caseID)-v\(record.request.prompt.version)-turn-\(index + 1)")
                var metadata: [String: Any] = ["deadlineSeconds": record.request.mentorExecutionPolicy?.timeoutInterval ?? 0,
                    "elapsedSeconds": record.elapsedSeconds ?? 0, "hasResponse": record.data != nil,
                    "hasTransportFailure": record.errorDomain != nil]
                if let domain = record.errorDomain { metadata["errorDomain"] = domain }
                if let code = record.errorCode { metadata["errorCode"] = code }
                if let kind = record.failureKind { metadata["failureKind"] = kind }
                if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]) {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "\(caseID)-v\(record.request.prompt.version)-turn-\(index + 1)-metadata"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "\(caseID)-v\(record.request.prompt.version)-turn-\(index + 1)-normalized-response"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
        func wait(_ predicate: () -> Bool) async throws -> Bool {
            let deadline = ContinuousClock.now.advanced(by: policy.deadline + .seconds(5))
            while ContinuousClock.now < deadline {
                if predicate() { return true }
                try await Task.sleep(for: .milliseconds(50))
            }
            return predicate()
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-mentor-request-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("conversation.sqlite")
        let repository = SQLiteMentorRepository(database: try AppDatabase(url: url))
        let catalog = try MentorLessonCatalog.loadBundled()
        let first = MentorFeatureStore(repository: repository, transport: transport, catalog: catalog, requestPolicy: policy)
        first.start(entry: "discuss")
        guard try await wait({ first.state.phase == .editing && !first.state.isTransitioningSession }) else {
            XCTFail("Isolated session failed to open"); return
        }
        var current = first
        var sessionID: UUID?
        for (index, text) in texts.enumerated() {
            let previousID = current.state.responseItemID
            current.submit(text: text)
            guard try await wait({
                if case .failed = current.state.phase { return true }
                return current.state.phase == .showingResponse && current.state.responseItemID != previousID
            }), current.state.phase == .showingResponse else {
                XCTFail("Distinct turn \(index + 1) failed; no retry or further model call was sent"); return
            }
            let id = try XCTUnwrap(current.state.responseItemID)
            let response = try XCTUnwrap(current.state.response?.response)
            let storedSessionID = try XCTUnwrap(current.state.session?.id)
            if let sessionID { XCTAssertEqual(storedSessionID, sessionID) } else { sessionID = storedSessionID }
            XCTAssertEqual(response.question != nil, questionPresence[index])
            guard (response.question != nil) == questionPresence[index] else { return }
            XCTAssertTrue(expectedActions[index].contains(response.action), "Wrong help mode for the current request")
            guard expectedActions[index].contains(response.action) else { return }
            current.acknowledgeResponse(itemID: id)
            guard try await wait({ current.state.acknowledgedResponseItemID == id }) else {
                XCTFail("Response appearance receipt was not saved"); return
            }
            let sent = try XCTUnwrap(transport.records.last?.request)
            let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(sent.inputSummary.utf8))
            XCTAssertEqual(context.sources.first { $0.ref == context.latestUserSourceRef }?.content, text)
            XCTAssertEqual(context.conversationState.visibleTurnIndex, index + 1)
            XCTAssertEqual(transport.records.count, index + 1)
            // Reopen the same SQLite file after every turn; restore never calls the model.
            let reopened = MentorFeatureStore(repository: SQLiteMentorRepository(database: try AppDatabase(url: url)),
                transport: transport, catalog: catalog, requestPolicy: policy)
            reopened.continueSession(id: storedSessionID)
            guard try await wait({ reopened.state.phase == .showingResponse && !reopened.state.isTransitioningSession }) else {
                XCTFail("Saved response did not reopen"); return
            }
            XCTAssertEqual(reopened.state.response?.response, response)
            XCTAssertEqual(transport.records.count, index + 1)
            reopened.acknowledgeResponse(itemID: id)
            guard try await wait({ reopened.state.acknowledgedResponseItemID == id }) else {
                XCTFail("Restored response receipt was not saved"); return
            }
            current = reopened
        }
        let saved = try await repository.items(sessionID: XCTUnwrap(sessionID))
        XCTAssertEqual(saved.filter { $0.kind == .user }.count, texts.count)
        XCTAssertEqual(saved.filter { $0.kind == .assistant }.count, texts.count)
        let attachment = XCTAttachment(data: try JSONEncoder().encode(saved), uniformTypeIdentifier: "public.json")
        attachment.name = "\(caseID)-persisted-timeline"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testLiveMentorCriteriaAcrossPersistedTurnsWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_MENTOR_CRITERIA"] == "1" else { throw XCTSkip("Explicit new-version mentor criteria acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let configuration = try harness.mentorConfiguration()
        let policy = MentorRequestPolicy.forProtocol(configuration.protocolKind)
        let transport = LiveMentorStoreCaptureTransport(base: DirectGLMClient(apiKey: key, configuration: configuration))
        defer {
            for (index, record) in transport.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "mentor-criteria-v213-turn-\(index + 1)")
                var metadata: [String: Any] = ["deadlineSeconds": record.request.mentorExecutionPolicy?.timeoutInterval ?? 0,
                    "elapsedSeconds": record.elapsedSeconds ?? 0, "hasResponse": record.data != nil]
                if let domain = record.errorDomain { metadata["errorDomain"] = domain }
                if let code = record.errorCode { metadata["errorCode"] = code }
                if let kind = record.failureKind { metadata["failureKind"] = kind }
                if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]) {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "mentor-criteria-v213-turn-\(index + 1)-transport-metadata"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "mentor-criteria-v213-turn-\(index + 1)-normalized-response"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
        func wait(_ predicate: () -> Bool) async throws -> Bool {
            let clock = ContinuousClock(), deadline = ContinuousClock.now.advanced(by: policy.deadline + .seconds(5))
            while clock.now < deadline {
                if predicate() { return true }
                try await Task.sleep(for: .milliseconds(50))
            }
            return predicate()
        }
        func isFailed(_ store: MentorFeatureStore) -> Bool {
            if case .failed = store.state.phase { return true }; return false
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-mentor-criteria-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("conversation.sqlite")
        let database = try AppDatabase(url: url)
        let repository = SQLiteMentorRepository(database: database)
        let catalog = try MentorLessonCatalog.loadBundled()
        let first = MentorFeatureStore(repository: repository, transport: transport, catalog: catalog, requestPolicy: policy)
        first.start(entry: "discuss")
        let started = try await wait { first.state.phase == .editing && !first.state.isTransitioningSession }
        guard started else { XCTFail("Isolated mentor session did not open"); return }
        let original = "周日只有半天，兼职能赚三百元，也想陪父母聚餐，两件事都重要。我还没有说哪一个更重要。请先说明一个取舍，让我看清不同标准会怎样影响选择，不要替我排序，不提问也不安排任务。"
        first.submit(text: original)
        let firstFinished = try await wait { first.state.phase == .showingResponse || isFailed(first) }
        guard firstFinished, first.state.phase == .showingResponse else {
            XCTFail("First new-version mentor request produced no validated response; no retry or follow-up request was sent")
            return
        }
        let sessionID = try XCTUnwrap(first.state.session?.id)
        let firstID = try XCTUnwrap(first.state.responseItemID)
        let firstTurn = try XCTUnwrap(first.state.response)
        XCTAssertNil(firstTurn.response.question)
        guard firstTurn.response.question == nil else { return }
        XCTAssertTrue([MentorAction.compare, .explain].contains(firstTurn.response.action))
        let firstItems = try await repository.items(sessionID: sessionID)
        XCTAssertEqual(firstItems.filter { $0.kind == .assistant }.map(\.id), [firstID])
        first.acknowledgeResponse(itemID: firstID)
        let acknowledged = try await wait { first.state.acknowledgedResponseItemID == firstID }
        guard acknowledged else { XCTFail("First response receipt was not saved"); return }

        // Reopen the actual SQLite file through a new repository and store;
        // no network is used to restore the first model response.
        let reopened = MentorFeatureStore(repository: SQLiteMentorRepository(database: try AppDatabase(url: url)), transport: transport, catalog: catalog, requestPolicy: policy)
        reopened.continueSession(id: sessionID)
        let restored = try await wait { reopened.state.phase == .showingResponse && !reopened.state.isTransitioningSession }
        guard restored else { XCTFail("Persisted dialogue did not restore"); return }
        XCTAssertEqual(reopened.state.response, firstTurn)
        XCTAssertEqual(reopened.state.responseItemID, firstID)
        XCTAssertEqual(transport.records.count, 1)
        reopened.acknowledgeResponse(itemID: firstID)
        let restoredReceipt = try await wait { reopened.state.acknowledgedResponseItemID == firstID }
        guard restoredReceipt else { XCTFail("Restored response receipt was not saved"); return }
        let priority = "我想清楚了，本月房租已留够，接下来两周没有其他和父母相聚的机会，这次我更在意相聚。兼职可以不接。按这个标准你现在建议怎么选？直接给建议，不要追加问题或安排任务。"
        reopened.submit(text: priority)
        let secondFinished = try await wait {
            (reopened.state.phase == .showingResponse && reopened.state.responseItemID != firstID) || isFailed(reopened)
        }
        guard secondFinished, reopened.state.phase == .showingResponse else {
            XCTFail("Second distinct mentor turn produced no validated response; no retry was sent")
            return
        }
        let secondTurn = try XCTUnwrap(reopened.state.response)
        XCTAssertEqual(secondTurn.response.action, .advise)
        XCTAssertNil(secondTurn.response.question)
        XCTAssertEqual(reopened.state.session?.id, sessionID)
        XCTAssertEqual(transport.records.count, 2, "One call per distinct turn; never retry paid requests")
        let latest = try JSONDecoder().decode(MentorContextPayload.self,
            from: Data(try XCTUnwrap(transport.records.last).request.inputSummary.utf8))
        XCTAssertEqual(latest.sessionID, sessionID)
        XCTAssertEqual(latest.conversationState.visibleTurnIndex, 2)
        XCTAssertEqual(latest.sources.first { $0.ref == latest.latestUserSourceRef }?.content, priority)
        XCTAssertTrue(latest.sources.contains { $0.ref.value == "item:" + firstID.uuidString && $0.role == .assistant })
        XCTAssertTrue(secondTurn.response.sourceRefs.contains(try XCTUnwrap(latest.latestUserSourceRef)))
        let persisted = try await repository.items(sessionID: sessionID)
        let attachment = XCTAttachment(data: try JSONEncoder().encode(persisted), uniformTypeIdentifier: "public.json")
        attachment.name = "mentor-criteria-v213-persisted-timeline"
        attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertEqual(persisted.filter { $0.kind == .user }.count, 2)
        XCTAssertEqual(persisted.filter { $0.kind == .assistant }.count, 2)
    }

    @MainActor
    func testLiveDirectExplanationWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_DIRECT_EXPLANATION"] == "1" else { throw XCTSkip("Explicit streamed schema-7 direct-help acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let configuration = try harness.mentorConfiguration()
        let client = LiveTodayStreamingCaptureClient(base: DirectGLMClient(apiKey: key, configuration: configuration))
        defer {
            let capture = client.capture
            for request in capture.requests {
                try? attachMentorRequest(request, caseID: "direct-help-v129-reversible-stream")
            }
            if !capture.rawText.isEmpty {
                let body = XCTAttachment(data: Data(capture.rawText.utf8), uniformTypeIdentifier: "public.json")
                body.name = "direct-help-v129-reversible-stream-assistant-text"
                body.lifetime = .keepAlways; add(body)
            }
            var metadata: [String: Any] = ["streamCalls": capture.streamCalls, "completeCalls": capture.completeCalls,
                "httpAttempts": capture.httpAttempts, "completed": capture.completed,
                "requestTimeoutSeconds": configuration.requestTimeout, "automaticRetries": configuration.maxRetryAttempts]
            if let domain = capture.errorDomain { metadata["errorDomain"] = domain }
            if let code = capture.errorCode { metadata["errorCode"] = code }
            if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "direct-help-v129-reversible-stream-metadata"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        let text = "我在考虑报名一个课程，条款是报名后一周内可全额退款，但已经投入的时间回不来。我想理解可逆决策该怎么用在这里。请直接讲清可退费和可恢复时间的区别，不替我决定是否报名，也不要让我先报名试试或安排任务。"
        let entry = DailyEntryDraft(rawText: text, state: .capture)
        let trainingCase = TrainingCase(dailyEntryId: entry.id, title: "课程退款与时间成本")
        let card = ThinkingCard(trainingCaseId: trainingCase.id, type: .decision,
            title: trainingCase.title, body: text, isConfirmed: true)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-direct-stream-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("direct-help.sqlite")
        let database = try AppDatabase(url: url)
        let entries = SQLiteDailyEntryRepository(database: database)
        let sessions = SQLiteTrainingCaseSessionRepository(database: database)
        try await entries.saveDraft(entry)
        try await SQLiteTrainingCaseRepository(database: database).saveCase(trainingCase)
        try await SQLiteThinkingCardRepository(database: database).saveCards([card], dailyEntryId: entry.id, trainingCaseId: trainingCase.id)
        try await sessions.saveSession(TrainingCaseSession(caseId: trainingCase.id, loopState: .reviewCards))
        @MainActor func makeStore(_ db: AppDatabase) -> AppStore {
            AppStore(todayDraft: entry, dailyEntryRepository: SQLiteDailyEntryRepository(database: db),
                thinkingCardRepository: SQLiteThinkingCardRepository(database: db),
                questRepository: SQLiteQuestRepository(database: db), lensSessionRepository: SQLiteLensSessionRepository(database: db),
                trainingCaseRepository: SQLiteTrainingCaseRepository(database: db),
                trainingCaseSessionRepository: SQLiteTrainingCaseSessionRepository(database: db),
                trainingCaseRelationshipRepository: SQLiteTrainingCaseRelationshipRepository(database: db),
                todayAIService: TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client),
                refreshesAIServiceFromKeychain: false, trainingCasesVNextEnabled: true)
        }
        let store = makeStore(database)
        await store.loadPersistedState()
        await store.openTrainingCase(trainingCase.id)
        // Enter the already-confirmed question stage directly; this acceptance
        // deliberately spends no call on initial organization or recommendation.
        store.todayDraft.state = .selectLens
        store.todayDraft.selectedLens = .reversibleDecision
        store.submitTodayStep()
        let deadline = ContinuousClock().now.advanced(by: .seconds(130))
        while ContinuousClock().now < deadline && store.todayDraft.state != .answerQuestions && !store.canRetryCurrentAI {
            try await Task.sleep(for: .milliseconds(50))
        }
        guard store.todayDraft.state == .answerQuestions, let explanation = store.coachExplanation else {
            store.cancelCurrentAIRequest()
            XCTFail("Streamed direct help produced no accepted explanation; no retry was sent")
            return
        }
        XCTAssertTrue(store.questions.isEmpty)
        XCTAssertEqual(explanation.sourceCardTitles, [card.title])
        XCTAssertFalse(explanation.text.isEmpty)
        XCTAssertFalse(explanation.text.contains("？"))
        XCTAssertFalse(explanation.text.contains("?"))
        XCTAssertTrue(store.answerReviewPrimaryActionSaves)
        XCTAssertTrue(client.capture.completed)
        XCTAssertEqual(client.capture.streamCalls, 1)
        XCTAssertEqual(client.capture.completeCalls, 0)
        XCTAssertEqual(client.capture.httpAttempts, 1)
        await store.saveAnswerReviewAndReturn()
        let storedSession = try await sessions.session(for: trainingCase.id)
        let saved = try XCTUnwrap(storedSession)
        XCTAssertEqual(saved.reflectionState?.explanation, explanation)
        XCTAssertEqual(saved.loopState, .answerQuestions)
        let reopened = makeStore(try AppDatabase(url: url))
        await reopened.loadPersistedState()
        await reopened.openTrainingCase(trainingCase.id)
        XCTAssertEqual(reopened.coachExplanation, explanation)
        XCTAssertEqual(reopened.activeTrainingCase?.id, trainingCase.id)
        XCTAssertEqual(client.capture.streamCalls, 1, "Reading saved help does not issue another model request")
        XCTAssertTrue(reopened.quests.isEmpty)
        XCTAssertTrue(reopened.principles.isEmpty)
        let attachment = XCTAttachment(data: try JSONEncoder().encode(saved.reflectionState), uniformTypeIdentifier: "public.json")
        attachment.name = "direct-help-v129-reversible-persisted-reflection"
        attachment.lifetime = .keepAlways; add(attachment)
        await reopened.returnToTodayOverview()
    }

    func testLivePerspectiveUnderstandingAndUserStopWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_PERSPECTIVE_UNDERSTANDING"] == "1" else { throw XCTSkip("Explicit new-version perspective acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
        defer {
            for (index, record) in client.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "perspective-v128-turn-" + String(index + 1))
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "perspective-v128-turn-" + String(index + 1) + "-normalized-response"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
        let text = "同事说本周只有两人值班，想把演示延后一周。我想按期展示工作。他提出延期让我觉得他不重视我，但我知道这只是我的猜测。我愿意想一想双方的侧重点，不要替他猜真实动机。"
        let draft = DailyEntryDraft(rawText: text, selectedLens: .perspectiveTaking)
        let card = ThinkingCard(type: .decision, title: "演示排期与两人值班", body: text, isConfirmed: true)
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let first = try await service.generateQuestions(for: TodayAIContext(
            draft: draft, confirmedCards: [card]))
        XCTAssertEqual(first.count, 1, "A voluntary, answerable difference should receive useful reflection")
        var answered = try XCTUnwrap(first.first)
        XCTAssertEqual(answered.sourceCardTitles, [card.title])
        answered.answer = "我重视按期展示成果，他明说的是本周只有两人值班。延期可能在回应人员安排，不等于已经证明他重视或不重视我。我先保留这个理解，今天到这里，不再追问，也不安排任务。"
        let second = try await service.generateQuestions(for: TodayAIContext(
            draft: draft, confirmedCards: [card], questions: [answered]))
        XCTAssertTrue(second.isEmpty, "A user's explicit stopping boundary must end questions")
        XCTAssertEqual(client.records.count, 2, "One request per distinct turn; never repeat a paid request")
    }

    func testLiveExpandedLensLibraryWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_LENS_LIBRARY"] == "1" else { throw XCTSkip("Explicit synthetic lens library acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let cases: [(ThinkingLens, String)] = [
            (.opportunityCost, "周末只剩半天。我想接一个付费兼职，也想陪父母吃饭，两件事都对我重要，时间确实冲突。我愿意比较这两个选择，请用一个问题帮我看清取舍，不要替我排序，也不要安排任务。"),
            (.reversibleDecision, "我在考虑加入朋友的周末项目。我知道可以先按周参与，退出要提前一周说，不需要投钱；长期承诺的时间成本还不清楚。我愿意检查承诺边界，请问一个能用这些已知条件想清的问题，不要让我先试验。"),
            (.perspectiveTaking, "同事原话是这周人手不足，想把演示延后一周。我理解成他根本不重视我的工作，但他没有说过这句话。我想更准确地理解双方差别，愿意回答一个区分已知表达和推测的问题，不要替他猜真实动机。"),
            (.controlBoundary, "今天公共交通停运，我无法保证准点到达。我已经知道可以提前告知并改线上，但一直纠结领导会不会生气。我愿意分清自己能决定和不能决定的部分，请围绕这一点问一个问题，不要把他人的反应算成我的责任。")
        ]
        for (lens, text) in cases {
            let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
            defer {
                for (index, record) in client.records.enumerated() {
                    try? attachMentorRequest(record.request, caseID: "lens-" + lens.rawValue + "-" + String(index))
                    if let data = record.data {
                        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                        attachment.name = "lens-" + lens.rawValue + "-normalized-response"
                        attachment.lifetime = .keepAlways; add(attachment)
                    }
                }
            }
            do {
                let card = ThinkingCard(type: .decision, title: lens.title + "合成验收", body: text, isConfirmed: true)
                let result = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .generateQuestions(for: TodayAIContext(draft: DailyEntryDraft(rawText: text, selectedLens: lens), confirmedCards: [card]))
                XCTAssertEqual(result.count, 1, "Voluntary reflection should provide one useful distinction for " + lens.rawValue)
                if let question = result.first {
                    XCTAssertEqual(question.sourceCardTitles, [card.title])
                    XCTAssertFalse(question.whyItMatters.isEmpty)
                    XCTAssertFalse(question.expectedUpdate?.isEmpty ?? true)
                    XCTAssertFalse(question.proceedWhen?.isEmpty ?? true)
                }
            } catch { XCTFail("Lens " + lens.rawValue + " failed: " + String(describing: error)) }
            XCTAssertEqual(client.records.count, 1, "Do not automatically repeat a paid request")
        }
    }

    func testLiveAnswerReviewChoiceWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_ANSWER_REVIEW"] == "1" else { throw XCTSkip("Explicit synthetic answer-review acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let scenarios = [
            ("uncertainty-is-clear", "晚交两天是我观察到的；故意不配合是我的推测。原因还不清楚，目前也没有别的材料。我已经能分清这两点，想保留这个理解，原因暂时未知。", false),
            ("requested-explanation", "我知道报告晚交两天，但不太明白为什么不能就说他故意不配合。请直接用这件事给我解释观察和意图之间差了哪一步，也不要安排任务。", false),
            ("useful-known-distinction", "我想继续检查这个判断。我记得约定交付时间时的一段对话，能说清楚，但还没写在这里。请问我一个能分清双方是否约定了同一个交付时间的问题，只围绕这段已发生的对话，不让我调查或安排任务。", true)
        ]
        for (id, answer, expectsQuestion) in scenarios {
            let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
            defer {
                for record in client.records {
                    try? attachMentorRequest(record.request, caseID: "answer-choice-" + id)
                    if let data = record.data {
                        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                        attachment.name = "answer-choice-" + id + "-normalized-response"
                        attachment.lifetime = .keepAlways; add(attachment)
                    }
                }
            }
            do {
                let card = ThinkingCard(type: .fact, title: "报告晚交两天", body: "我观察到同事的报告比我预期晚交两天。我据此觉得他故意不配合，还不知道原因。", isConfirmed: true)
                let question = ReflectionQuestion(question: "晚交和故意不配合之间，哪些是观察，哪些是推测？", whyItMatters: "区分结果和意图。", answer: answer)
                let decision = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .review(context: CoachAnswerReviewContext(caseId: UUID(), caseTitle: "晚交与意图", mode: .standard,
                        cards: [card], questions: [question], previousTurn: CoachTurnState(
                            phase: .fillEvidenceGap, readiness: .notReady, recommendedMove: .surfaceEvidenceGap,
                            reason: "结果不能直接证明意图。", openEvidenceGaps: [.missingCausalLink], baselineChecks: [],
                            decisionSource: .coachRecommended, policyVersion: "synthetic-answer-choice", turnSummary: "区分观察与推测。")))
                XCTAssertNotEqual(decision.turn.readiness, .ready)
                XCTAssertFalse(decision.feedback.canProceedToValidation)
                XCTAssertFalse(decision.feedback.hasStopped, "No useful question must not imply the user refused to continue")
                XCTAssertEqual(!decision.feedback.nextRepairQuestion.isEmpty, expectsQuestion, id)
                XCTAssertTrue(decision.feedback.experienceReplayPrompt.isEmpty)
                XCTAssertTrue(decision.feedback.judgmentSentencePrompt.isEmpty)
                XCTAssertFalse(decision.feedback.coachCritiqueLine.isEmpty)
            } catch { XCTFail("Answer review " + id + " failed: " + String(describing: error)) }
            XCTAssertEqual(client.records.count, 1, "Each paid scenario runs once")
        }
    }

    @MainActor
    func testImportModelConnectionWhenExplicitlyEnabled() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_IMPORT_MODEL_CONNECTION"] == "1" else { throw XCTSkip("Explicit connection import only") }
        let kind = try XCTUnwrap(env["MINGSI_LIVE_MODEL_PROTOCOL"].flatMap(GLMClientConfiguration.ProtocolKind.init(rawValue:)))
        let key = try XCTUnwrap(env["MINGSI_LIVE_GLM_API_KEY"])
        let baseURL = try XCTUnwrap(env["MINGSI_LIVE_GLM_BASE_URL"])
        let model = try XCTUnwrap(env["MINGSI_LIVE_GLM_MODEL"])
        guard !key.isEmpty, URL(string: baseURL)?.scheme == "https", URL(string: baseURL)?.host != nil, !model.isEmpty else {
            throw LLMClientError.invalidEndpoint
        }
        let saved = KeychainAPIKeyStore()
        let previous = try saved.loadProtocolKind()
        try saved.saveProtocolKind(kind)
        do {
            try saved.saveBaseURL(baseURL)
            try saved.saveModelName(model)
            try saved.saveAPIKey(key)
            XCTAssertFalse(try saved.loadAPIKey()?.isEmpty ?? true)
            XCTAssertEqual(try saved.loadProtocolKind(), kind)
            XCTAssertEqual(try saved.loadBaseURL(), baseURL)
            XCTAssertEqual(try saved.loadModelName(), model)
            let loadedURL = try XCTUnwrap(try saved.loadBaseURL())
            let parsedURL = try XCTUnwrap(URL(string: loadedURL))
            XCTAssertNotNil(parsedURL.host, "Imported connection must have a URL host: \(loadedURL)")
            XCTAssertEqual(parsedURL.scheme, "https")
            let configuration = try saved.loadClientConfiguration()
            XCTAssertEqual(configuration.protocolKind, kind)
        } catch {
            try? saved.saveProtocolKind(previous)
            throw error
        }
    }

    func testLiveInitialCoachEvidenceWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_INITIAL_COACH_EVIDENCE"] == "1" else {
            throw XCTSkip("Explicit synthetic initial coach evidence only")
        }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key,
            configuration: try harness.mentorConfiguration()))
        var scenarios: [(String, String)] = [
            ("observed-cause-unknown", "两次提交同一文件都在上传时超时，日志都显示 timeout，发生在今天 10:05 和 10:10。我猜是网络，但没有证据，权限是否限制上传也未知。我想分清已经看见的现象和未知原因；不要再让我补已经提供的超时事实。"),
            ("stop-with-unknown", "今天 10:05 提交同一文件时上传超时，日志写着 timeout。原因仍不知道；我现在只想保留这段记录，不想继续调查、回忆、安排任务或接受训练，今天先到这里。"),
            ("voluntary-natural-retry", "今天同一文件上传一次超时，日志显示 timeout。明天本来就会自然重试一次，文件和操作不变。我自愿想观察网络恢复后能否提交成功，先暂定网络恢复可能让这次重试成功。只看原本要发生的重试；没重试或条件不清楚就先保留未知，不新增任务。")
        ]
        if env["MINGSI_LIVE_INITIAL_COACH_POSITIVE_ONLY"] == "1" {
            scenarios = [("unsupported-intent-needs-evidence", "同事把周二约好的报告晚交了两天。这是我唯一知道的一次，我没有问过原因，也没有相关消息或其他记录。我就觉得他肯定故意不配合。我现在希望你帮我检查这个推断缺少什么证据，指出最值得澄清的一处；请不要把我的感觉当成他真实的动机，也别给我安排新任务。")]
        }
        defer {
            for (index, record) in client.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "initial-coach-" + scenarios[index].0)
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "initial-coach-" + scenarios[index].0 + "-normalized-response"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
        let service = CoachDecisionAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        for (id, text) in scenarios {
            let caseID = UUID()
            var card = ThinkingCard(type: .idea, title: id, body: text, isConfirmed: true)
            card.trainingCaseId = caseID
            let result = try await service.decide(context: .init(caseId: caseID, caseTitle: "上传回看", mode: .standard, cards: [card]))
            let turn = CoachTurnPolicy().makeInitialTurn(cards: [card], diagnosis: result.diagnosis)
            XCTAssertEqual(turn.openEvidenceGaps, result.diagnosis.openEvidenceGaps, id)
            if id == "unsupported-intent-needs-evidence" {
                XCTAssertFalse(turn.openEvidenceGaps.isEmpty, "An explicit request to examine an unsupported motive attribution still needs substantive guidance")
            } else {
                XCTAssertFalse(turn.openEvidenceGaps.contains(.missingObservation), id)
                XCTAssertFalse(turn.openEvidenceGaps.contains(.missingBaseline), id)
            }
            if id == "stop-with-unknown" {
                XCTAssertEqual(result.diagnosis.readiness, .notReady)
                XCTAssertTrue(turn.openEvidenceGaps.isEmpty)
            }
        }
        XCTAssertEqual(client.records.count, scenarios.count, "One request per scenario, no retry")
    }

    func testHarnessRequiresExplicitLiveAcceptanceFlag() {
        let disabledHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_API_KEY": "secret"
        ])
        let enabledHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_API_KEY": "secret"
        ])

        XCTAssertFalse(disabledHarness.isEnabled)
        XCTAssertTrue(enabledHarness.isEnabled)
    }

    func testHarnessAcceptsSimulatorChildEnvironmentKeys() throws {
        let harness = LiveGLMAcceptanceHarness(environment: [
            "SIMCTL_CHILD_MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "SIMCTL_CHILD_MINGSI_LIVE_GLM_API_KEY": " simctl-secret "
        ])

        XCTAssertTrue(harness.isEnabled)
        XCTAssertEqual(try harness.resolvedAPIKey(), "simctl-secret")
    }

    func testHarnessAcceptsStandardBYOKEnvironmentKeys() throws {
        let appKeyHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_GLM_API_KEY": " app-secret "
        ])
        let genericKeyHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "GLM_API_KEY": " generic-secret "
        ])
        let precedenceHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_API_KEY": " live-secret ",
            "MINGSI_GLM_API_KEY": " app-secret ",
            "GLM_API_KEY": " generic-secret "
        ])

        XCTAssertEqual(try appKeyHarness.resolvedAPIKey(), "app-secret")
        XCTAssertEqual(try genericKeyHarness.resolvedAPIKey(), "generic-secret")
        XCTAssertEqual(try precedenceHarness.resolvedAPIKey(), "live-secret")
    }

    func testHarnessFallsBackToKeychainAPIKeyWhenEnvironmentKeyIsMissing() throws {
        var loadCount = 0
        let harness = LiveGLMAcceptanceHarness(
            environment: ["MINGSI_LIVE_GLM_ACCEPTANCE": "1"],
            keychainAPIKey: {
                loadCount += 1
                return " keychain-secret "
            }
        )

        XCTAssertEqual(try harness.resolvedAPIKey(), "keychain-secret")
        XCTAssertEqual(loadCount, 1)
    }

    func testHarnessProbeUsesTenMinuteRequestTimeout() {
        let harness = LiveGLMAcceptanceHarness(environment: [:])

        XCTAssertEqual(harness.requestTimeout, GLMClientConfiguration.defaultRequestTimeout)
    }

    func testMentorHarnessHonorsExplicitModelAndEndpointBeforeDeviceDefaults() throws {
        for prefix in ["", "SIMCTL_CHILD_"] {
            let harness = LiveGLMAcceptanceHarness(
                environment: [
                    prefix + "MINGSI_LIVE_GLM_BASE_URL": " https://example.test/v1/chat/completions ",
                    prefix + "MINGSI_LIVE_GLM_MODEL": " requested-model ",
                    prefix + "MINGSI_LIVE_MODEL_PROTOCOL": "openAICompatible"
                ],
                keychainBaseURL: { XCTFail("Explicit endpoint should not load the device default"); return nil },
                keychainModelName: { XCTFail("Explicit model should not load the device default"); return nil }
            )
            let configuration = try harness.mentorConfiguration()
            XCTAssertEqual(configuration.baseURL.absoluteString, "https://example.test/v1")
            XCTAssertEqual(configuration.model, "requested-model")
            XCTAssertEqual(configuration.requestTimeout, 30)
            XCTAssertEqual(configuration.maxRetryAttempts, 0)
        }
    }

    func testResponsesMentorHarnessUsesProductionBudgetWithoutRetries() throws {
        let harness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_BASE_URL": "https://example.test/v1",
            "MINGSI_LIVE_GLM_MODEL": "fixture-model",
            "MINGSI_LIVE_MODEL_PROTOCOL": "responses"
        ])
        let configuration = try harness.mentorConfiguration()
        XCTAssertEqual(configuration.requestTimeout, MentorRequestPolicy.responses.timeoutInterval)
        XCTAssertEqual(configuration.maxRetryAttempts, 0)
    }

    func testMentorHarnessUsesSavedDeviceConfigurationWhenNoOverridesExist() throws {
        let harness = LiveGLMAcceptanceHarness(environment: [:],
            keychainBaseURL: { "https://example.test/saved/v1" },
            keychainModelName: { "saved-model" })
        let configuration = try harness.mentorConfiguration()
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://example.test/saved/v1")
        XCTAssertEqual(configuration.model, "saved-model")
    }

    func testCareerGoldenRequiresSeparateOptInAndExplicitBYOKKey() {
        let disabledHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_API_KEY": "secret"
        ])
        let keychainOnlyHarness = LiveGLMAcceptanceHarness(
            environment: [
                "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
                "MINGSI_LIVE_GLM_CAREER_GOLDEN": "1"
            ],
            keychainAPIKey: { "secret" }
        )
        let enabledHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_CAREER_GOLDEN": "1",
            "MINGSI_GLM_API_KEY": " explicit-secret "
        ])

        XCTAssertFalse(disabledHarness.isCareerGoldenEnabled)
        XCTAssertTrue(keychainOnlyHarness.isCareerGoldenEnabled)
        XCTAssertNil(keychainOnlyHarness.explicitBYOKAPIKey())
        XCTAssertEqual(enabledHarness.explicitBYOKAPIKey(), "explicit-secret")
    }

    func testCareerGoldenHarnessRunsThreeStructuredScenariosWithoutNetwork() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: [:])
        let client = CareerGoldenFixtureClient()

        let results = try await harness.runCareerGolden(with: client)

        XCTAssertEqual(results.map(\.caseID), [
            "career.student.synthesis.v1",
            "career.programmer.synthesis.v1",
            "career.finance.synthesis.v1"
        ])
        XCTAssertTrue(results.allSatisfy { $0.questions.count >= 1 && $0.denialViolations.isEmpty })
        XCTAssertEqual(client.requests.count, 3)
        XCTAssertTrue(client.requests.allSatisfy { $0.prompt.id == .generateQuestions })
        XCTAssertTrue(client.requests.allSatisfy { $0.prompt.version == LocalPromptProvider().template(for: .generateQuestions, mode: .standard).version })
        XCTAssertTrue(client.requests.allSatisfy { request in
            let rawText = request.contextPayload?.currentInput.rawText ?? ""
            return rawText.contains("职业标签仅作为情境") && rawText.contains("拒绝基于职业标签")
        })
    }

    func testLiveGLMCompleteReturnsJSONWhenExplicitlyEnabled() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: ProcessInfo.processInfo.environment)

        guard harness.isEnabled else {
            throw XCTSkip("Set MINGSI_LIVE_GLM_ACCEPTANCE=1 and one of MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, or GLM_API_KEY to run the live BYOK GLM acceptance test.")
        }

        let data = try await harness.runCompleteProbe()
        let response = try JSONDecoder().decode(GLMChatCompletionResponse.self, from: data)
        let content = try XCTUnwrap(response.choices.first?.message?.content)

        XCTAssertTrue(content.contains("ok"))
    }

    func testLiveGLMCareerGoldenQuestionsWhenExplicitlyEnabled() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: ProcessInfo.processInfo.environment)

        guard harness.isCareerGoldenEnabled else {
            throw XCTSkip("Set MINGSI_LIVE_GLM_ACCEPTANCE=1, MINGSI_LIVE_GLM_CAREER_GOLDEN=1, and an explicit MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, or GLM_API_KEY to run the live BYOK GLM career golden test.")
        }
        guard harness.explicitBYOKAPIKey() != nil else {
            throw XCTSkip("The live career golden test requires an explicit BYOK environment key; Keychain-only configuration is intentionally skipped.")
        }

        let results = try await harness.runLiveCareerGolden()
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { !$0.questions.isEmpty && $0.denialViolations.isEmpty })
    }
}

private struct LiveGLMAcceptanceHarness {
    let environment: [String: String]
    var keychainAPIKey: () throws -> String? = {
        try KeychainAPIKeyStore().loadAPIKey()
    }
    var keychainBaseURL: () throws -> String? = {
        try KeychainAPIKeyStore().loadBaseURL()
    }
    var keychainModelName: () throws -> String? = {
        try KeychainAPIKeyStore().loadModelName()
    }

    func mentorConfiguration() throws -> GLMClientConfiguration {
        let rawURL = try value("MINGSI_LIVE_GLM_BASE_URL") ?? keychainBaseURL()
        let kind = value("MINGSI_LIVE_MODEL_PROTOCOL").flatMap(GLMClientConfiguration.ProtocolKind.init(rawValue:))
            ?? (try? KeychainAPIKeyStore().loadProtocolKind()) ?? .openAICompatible
        let url = rawURL.flatMap(URL.init(string:)).map { GLMClientConfiguration.normalizeBaseURL($0, protocolKind: kind) }
            ?? GLMClientConfiguration().baseURL
        let model = try value("MINGSI_LIVE_GLM_MODEL") ?? keychainModelName() ?? GLMClientConfiguration().model
        return GLMClientConfiguration(baseURL: url, model: model,
            temperature: 0, requestTimeout: value("MINGSI_LIVE_MENTOR_STREAMING") == "1" ? GLMClientConfiguration.defaultRequestTimeout : MentorRequestPolicy.forProtocol(kind).timeoutInterval, protocolKind: kind, maxRetryAttempts: 0)
    }

    var requestTimeout: TimeInterval {
        GLMClientConfiguration().requestTimeout
    }

    var isEnabled: Bool {
        value("MINGSI_LIVE_GLM_ACCEPTANCE") == "1"
    }

    var isCareerGoldenEnabled: Bool {
        isEnabled && value("MINGSI_LIVE_GLM_CAREER_GOLDEN") == "1"
    }

    func runCompleteProbe() async throws -> Data {
        guard let apiKey = try resolvedAPIKey() else {
            throw XCTSkip("No live BYOK GLM API key is set; provide MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY, or a Keychain key to run this test.")
        }

        let selected = try mentorConfiguration()
        let client = DirectGLMClient(apiKey: apiKey, configuration: GLMClientConfiguration(
            baseURL: selected.baseURL, model: selected.model, temperature: 0,
            requestTimeout: requestTimeout, protocolKind: selected.protocolKind,
            maxRetryAttempts: 0, retryBaseDelay: 0))

        return try await client.complete(Self.probeRequest)
    }

    func resolvedAPIKey() throws -> String? {
        for key in ["MINGSI_LIVE_GLM_API_KEY", "MINGSI_GLM_API_KEY", "GLM_API_KEY"] {
            if let environmentAPIKey = value(key), !environmentAPIKey.isEmpty {
                return environmentAPIKey
            }
        }

        let keychainKey = try keychainAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return keychainKey?.isEmpty == false ? keychainKey : nil
    }

    func explicitBYOKAPIKey() -> String? {
        for key in ["MINGSI_LIVE_GLM_API_KEY", "MINGSI_GLM_API_KEY", "GLM_API_KEY"] {
            if let environmentAPIKey = value(key), !environmentAPIKey.isEmpty {
                return environmentAPIKey
            }
        }
        return nil
    }

    func runLiveCareerGolden() async throws -> [LiveGLMCareerGoldenResult] {
        guard let apiKey = explicitBYOKAPIKey() else {
            throw XCTSkip("No explicit live BYOK GLM API key is set for the career golden test.")
        }

        let client = DirectGLMClient(
            apiKey: apiKey,
            configuration: GLMClientConfiguration(
                baseURL: baseURL(),
                model: value("MINGSI_LIVE_GLM_MODEL") ?? GLMClientConfiguration().model,
                temperature: 0,
                requestTimeout: requestTimeout,
                maxRetryAttempts: 0,
                retryBaseDelay: 0
            )
        )
        return try await runCareerGolden(with: client)
    }

    func runCareerGolden(with client: LLMClient) async throws -> [LiveGLMCareerGoldenResult] {
        let parser = TodayAIResponseParser()
        var results: [LiveGLMCareerGoldenResult] = []
        for scenario in Self.careerScenarios {
            let request = scenario.request
            let data = try await client.complete(request)
            let questions = try parser.parseQuestions(from: data)
            let issues = PromptCoachingQualityPolicy.evaluateQuestions(
                questions,
                selectedLens: scenario.selectedLens,
                primaryTrainingDimension: scenario.selectedLens.primaryTrainingDimension,
                maxQuestionsPerTurn: 1
            )
            guard issues.isEmpty else {
                throw TodayAIParsingError.qualityGateFailed(
                    Array(Set(issues.map { $0.reason.rawValue })).sorted()
                )
            }

            let outputText = questions
                .map { [$0.question, $0.whyItMatters, $0.whyNow ?? "", $0.expectedUpdate ?? "", $0.proceedWhen ?? "", $0.calibrationTarget ?? ""].joined(separator: " ") }
                .joined(separator: " ")
            results.append(LiveGLMCareerGoldenResult(
                caseID: scenario.caseID,
                questions: questions,
                denialViolations: Self.forbiddenOutputPhrases.filter {
                    outputText.localizedCaseInsensitiveContains($0)
                }
            ))
        }
        return results
    }

    private func baseURL() -> URL {
        guard let rawURL = value("MINGSI_LIVE_GLM_BASE_URL"),
              let url = URL(string: rawURL)
        else {
            return GLMClientConfiguration().baseURL
        }
        return GLMClientConfiguration.normalizeBaseURL(url)
    }

    private func value(_ key: String) -> String? {
        let raw = environment[key] ?? environment["SIMCTL_CHILD_\(key)"]
        return raw?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let probeRequest = LLMRequest(
        prompt: PromptTemplate(
            id: .organizeCards,
            version: "live-acceptance.v1",
            systemText: "Return valid JSON only.",
            userText: "Reply with {\"ok\":true}. Do not add prose.",
            outputSchemaVersion: 1
        ),
        inputSummary: "live BYOK GLM acceptance probe",
        contextPayload: PromptContextPayload(
            currentInput: .init(rawText: "live glm acceptance probe"),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue)
        ),
        contextVersion: 1
    )

    private static let forbiddenOutputPhrases = [
        "因为你是学生", "学生天生", "作为学生你应该", "程序员天生", "因为你是程序员",
        "金融人都", "因为你的职业", "答案是", "直接照做", "加油", "你一定可以", "继续努力"
    ]

    private static let careerScenarios: [LiveGLMCareerGoldenScenario] = [
        .init(
            caseID: "career.student.synthesis.v1",
            careerLabel: "学生",
            selectedLens: .evidenceCheck,
            cards: [
                .init(id: "career-student-fact", type: "fact", title: "练习提交记录", body: "周三18:00提交练习，系统记录3次编译失败；这是可观察事实。", priority: "medium", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-student-interpretation", type: "problem", title: "把失败归因于粗心", body: "我判断失败来自粗心，但还没有逐条检查日志，解释与事实需要分开。", priority: "high", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-student-task", type: "task", title: "补一条反例证据", body: "查看一次失败日志，记录触发条件，并写下什么结果会推翻当前判断。", priority: "high", sensitivity: "normal", isExcludedFromModel: false)
            ]
        ),
        .init(
            caseID: "career.programmer.synthesis.v1",
            careerLabel: "软件工程师",
            selectedLens: .evidenceCheck,
            cards: [
                .init(id: "career-programmer-fact", type: "fact", title: "接口测试结果", body: "接口测试在本地通过，但集成环境有2次超时；这是可观察事实，不是原因结论。", priority: "high", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-programmer-interpretation", type: "risk", title: "猜测缓存导致超时", body: "我推测缓存失效是主因，但尚未比较请求耗时和依赖服务状态，仍有证据缺口。", priority: "high", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-programmer-task", type: "task", title: "做一次最小对照", body: "固定请求参数，对比命中缓存与未命中缓存的耗时和超时次数。", priority: "high", sensitivity: "normal", isExcludedFromModel: false)
            ]
        ),
        .init(
            caseID: "career.finance.synthesis.v1",
            careerLabel: "金融从业者",
            selectedLens: .evidenceCheck,
            cards: [
                .init(id: "career-finance-fact", type: "fact", title: "报表差异记录", body: "月度报表与明细表相差1.8%，差异集中在两个日期；这是核对事实。", priority: "high", sensitivity: "possibly_sensitive", isExcludedFromModel: false),
                .init(id: "career-finance-interpretation", type: "problem", title: "推测为汇率口径差异", body: "我推测汇率口径造成差异，但还没有核对汇率来源、日期和四舍五入规则。", priority: "high", sensitivity: "possibly_sensitive", isExcludedFromModel: false),
                .init(id: "career-finance-task", type: "task", title: "补齐口径核对证据", body: "抽取两个差异日期，逐项记录汇率来源、计算口径和舍入结果。", priority: "high", sensitivity: "possibly_sensitive", isExcludedFromModel: false)
            ]
        )
    ]
}

private struct LiveGLMCareerGoldenScenario {
    let caseID: String
    let careerLabel: String
    let selectedLens: ThinkingLens
    let cards: [PromptContextPayload.Card]

    var request: LLMRequest {
        let rawText = """
        职业背景：\(careerLabel)。职业标签仅作为情境，不是能力、动机、偏好、收入、责任或任何判断的证据。
        拒绝基于职业标签的刻板推断，不迎合用户，也不要替用户下结论或给出直接答案。
        请只根据下列确认材料提出可验证的追问。
        """
        let template = LocalPromptProvider().template(for: .generateQuestions, mode: .standard)
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: caseID, rawText: rawText),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue, selectedLens: selectedLens.rawValue),
            cards: cards,
            directives: .init(
                privacyRules: "Synthetic evaluation only. Do not infer personal attributes from the career label."
            )
        )
        return LLMRequest(
            prompt: template,
            inputSummary: "careerGolden=\(caseID); careerLabel=context-only; denialGuidance=enabled; cards=\(cards.map(\.title).joined(separator: ", "))",
            contextPayload: payload,
            sourceRecordIDs: cards.map(\.id),
            contextVersion: 1,
            contextRecordIDs: cards.map(\.id)
        )
    }
}

private struct LiveGLMCareerGoldenResult {
    let caseID: String
    let questions: [ReflectionQuestion]
    let denialViolations: [String]
}

private final class CareerGoldenFixtureClient: LLMClient {
    private(set) var requests: [LLMRequest] = []

    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        let titles = request.contextPayload?.cards.map(\.title) ?? []
        let payload: [String: Any] = [
            "questions": [[
                "question": "哪些记录是事实，哪些只是对当前原因的解释？",
                "why_this_matters": "先分离事实和解释，避免把未经核对的归因当成结论。",
                "why_now": "当前材料仍缺少能支持或推翻解释的可观察证据。",
                "expected_update": "补齐对照记录后，更新对当前原因解释的可信度。",
                "proceed_when": "记录一条支持或推翻解释的可复查证据后再决定下一步。",
                "evidence_gap_type": "missing_observation",
                "answer_use": "collect_evidence",
                "lens_move": "fact_interpretation_split",
                "source_card_titles": titles,
                "calibration_target": "当前原因解释是否得到可复查证据支持"
            ]]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}

// Synthetic materials only. Raw output attachments permit semantic review;
// successful schema parsing alone does not establish helpful coaching.
extension LiveGLMAcceptanceTests {
    func testLiveOutcomeGuidanceWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_OUTCOME_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Explicit synthetic action, calibration, and principle acceptance only")
        }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key,
            configuration: try harness.mentorConfiguration()))
        defer {
            for (index, record) in client.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "outcome-\(index)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "outcome-\(index)-normalized-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let card = ThinkingCard(type: .problem, title: "一次未完成不能确定入口设计有问题",
            body: "一位朋友试过新入口但没完成，后来发现当时断网。我不知道是设计还是网络影响。明天愿意在网络正常时，请同一位朋友自愿再试同一任务一次，只看完成情况和卡住的位置，不先改设计。", isConfirmed: true)
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let quests = try await service.generateQuests(for: TodayAIContext(
            draft: DailyEntryDraft(rawText: card.body), confirmedCards: [card]))
        XCTAssertEqual(quests.count, 1)
        let quest = try XCTUnwrap(quests.first)
        XCTAssertEqual(quest.type, .main)
        XCTAssertEqual(quest.sourceCardTitles, [card.title])
        XCTAssertFalse((quest.calibrationTarget ?? "").isEmpty)

        let review = try await service.verifyQuest(input: VerifyQuestInput(
            sourceRecordIDs: [quest.id.uuidString], questTitle: quest.title,
            completionCriteria: quest.completionCriteria, targetJudgment: quest.calibrationTarget,
            completion: "done", valueRating: "high", judgmentUpdate: "confirmed",
            rawText: "我点了已完成，觉得这次很有价值，也选了判断已确认。但我没有记录朋友有没有完成、网络是否正常或卡在哪儿，也没有其他观察或反馈。"), sessionMode: .standard)
        XCTAssertFalse(review.calibrationNote.isEmpty)
        XCTAssertFalse((review.recommendation ?? "").isEmpty)
        XCTAssertEqual(review.calibrationAssessment?.evidenceStatus, .missing)
        XCTAssertEqual(review.calibrationAssessment?.criteriaStatus, .notAssessable)
        XCTAssertEqual(review.calibrationAssessment?.judgmentStatus, .unresolved)
        XCTAssertTrue(review.growthEvidenceItems.isEmpty,
            "Completion and a positive rating without observations cannot prove new behavior or growth")

        let single = ThinkingCard(type: .fact, title: "一次补示例后对方完成填写",
            body: "这次我在表单里加了一个字段示例，对方后来填完了。只有这一次，没有其他记录；我还不知道是不是示例起了作用。", isConfirmed: true)
        let noPrinciple = try await service.extractPrinciple(for: TodayAIContext(
            draft: DailyEntryDraft(rawText: single.body), confirmedCards: [single]))
        XCTAssertTrue(noPrinciple.isEmpty, "One favorable outcome must not become a reusable rule")

        let repeated = [
            ThinkingCard(type: .fact, title: "四月交接先确认验收记录",
                body: "四月的交接只说按旧版做，对方交回后发现验收口径不同，返工了一次。", isConfirmed: true),
            ThinkingCard(type: .fact, title: "六月交接再次出现口径不同",
                body: "六月另一项交接也只口头说按旧版做，交回后又因验收口径不同返工。这是另一次独立任务。", isConfirmed: true),
            ThinkingCard(type: .decision, title: "我想试用的交接规则",
                body: "我想把它作为待验证的规则：跨人交接且验收口径没确认时，先写下交付物和验收条件，再请接手人用自己的话确认。下次看双方是否在动手前确认了同一标准，之后是否还有口径不同造成的返工。紧急且可逆的小事可先处理；这仍是我的假设，不能保证消除返工。", isConfirmed: true)
        ]
        let candidates = try await service.extractPrinciple(for: TodayAIContext(
            draft: DailyEntryDraft(rawText: repeated.map(\.body).joined(separator: "\n")), confirmedCards: repeated))
        XCTAssertEqual(candidates.count, 1, "A bounded user-stated rule with repeated concrete examples should remain available as a candidate")
        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertTrue(Set(candidate.sourceCardTitles).isSubset(of: Set(repeated.map(\.title))))
    }

    func testResultCalibrationScenariosSeparateEvidenceFromPositiveSelfRatings() {
        let cases = resultCalibrationScenarios()
        XCTAssertEqual(cases.map(\.id), ["observed-support", "observed-counterexample", "conflicting-records"])
        XCTAssertEqual(cases.map { $0.expected.evidenceStatus }, [.observed, .observed, .conflicting])
        XCTAssertEqual(cases.map { $0.expected.criteriaStatus }, [.met, .notMet, .notAssessable])
        XCTAssertEqual(cases.map { $0.expected.judgmentStatus }, [.supported, .weakened, .unresolved])
        for scenario in cases {
            XCTAssertEqual(scenario.input.completion, "done")
            XCTAssertEqual(scenario.input.valueRating, "high")
            XCTAssertEqual(scenario.input.judgmentUpdate, "confirmed")
            XCTAssertFalse(scenario.input.rawText.isEmpty)
            XCTAssertFalse(scenario.input.sourceRecordIDs.isEmpty)
        }
    }

    func testLiveActionDoesNotTurnHistoricalLabelsIntoTrainingWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_TOPIC_BOUNDARY"] == "1" else { throw XCTSkip("Explicit synthetic topic boundary acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
        var scenarios = [
            ("network-not-communication", "一位朋友填写页面时退出，我原先怀疑说明不清。后来日志确认他在提交前断网了；还不知道恢复网络后能否提交。我不想重写说明，也不想做沟通训练。愿意下次只看这位朋友网络恢复后的提交结果，保持说明不变。"),
            ("compare-existing-records", "我过去两次被问过验收标准，但这并不说明我有沟通问题。这次返工少了，可任务范围也缩小了。我已决定只对照两份已有交接记录的范围和返工，暂不新增测试或要求同事配合；对照结果仍可能不能说明原因。")
        ]
        if env["MINGSI_LIVE_ACTION_CLARITY"] == "1" {
            scenarios.append(("negative-observable-prediction", "我今天在网络正常时用这个账号提交表单，返回了403，没有成功。我暂时要检验的判断是：下次即使网络正常，这个账号仍可能因权限问题无法提交。我只愿意等自己的下一次自然提交，看是否成功和已有错误码，不改权限、不催别人、不新增测试；没有重试就暂不能判断。403也不能独自证明具体权限原因。"))
        }
        if env["MINGSI_LIVE_ACTION_CLARITY_REMAINING"] == "1" {
            scenarios.removeFirst() // First real response is replayed offline after the local gate fix.
        }
        defer {
            for (index, record) in client.records.enumerated() {
                let name = scenarios[index].0
                try? attachMentorRequest(record.request, caseID: "topic-boundary-\(name)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "topic-boundary-\(name)-normalized-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let retired = CoachPatternSummary(policyVersion: "coach-pattern-summary.local-v1", analyzedRecordCount: 14,
            totalSignalCount: 14, sourceDailyEntryIds: [UUID().uuidString], topPatterns: [
                CoachPatternSignal(primaryGap: .narrativeUnclear, foundationalAbility: .communication,
                    count: 14, latestDate: .now, minimalTrainingAction: "重写背景对象触发行动结果并训练沟通力。")
            ], guidanceLine: "缺少沟通力，需要训练描述。")
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        for (id, text) in scenarios {
            let card = ThinkingCard(type: .decision, title: id == "network-not-communication" ? "先观察恢复网络后的提交" : (id == "compare-existing-records" ? "只比较已有交接记录" : "等这个账号自然重试"),
                body: text, isConfirmed: true)
            let quests = try await service.generateQuests(for: TodayAIContext(draft: DailyEntryDraft(rawText: text),
                confirmedCards: [card], coachPatternSummary: retired))
            XCTAssertEqual(quests.count, 1)
            XCTAssertEqual(quests.first?.type, .main)
            XCTAssertEqual(quests.first?.sourceCardTitles, [card.title])
            XCTAssertNil(client.records.last?.request.contextPayload?.coachPatternSummary)
            XCTAssertNil(client.records.last?.request.contextPayload?.directives.coachPatternSummaryRule)
        }
        XCTAssertEqual(client.records.count, scenarios.count)
    }

    func testLiveHistoricalEvidenceBoundaryWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_HISTORY_EVIDENCE"] == "1" else { throw XCTSkip("Explicit synthetic historical evidence acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
        let names = ["history-current-question", "history-single-action", "history-growth-no-outcomes"]
        defer {
            for (index, record) in client.records.enumerated() {
                let name = index < names.count ? names[index] : "unexpected-\(index)"
                try? attachMentorRequest(record.request, caseID: name)
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "\(name)-normalized-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let historyID = UUID()
        let assessment = CalibrationAssessment(evidenceStatus: .conflicting, criteriaStatus: .notAssessable,
            judgmentStatus: .unresolved, evidenceQuotes: ["甲说完成，乙说未完成"])
        let history = PromptContextPayload.LensFeedbackContext(lensId: ThinkingLens.judgmentCalibration.rawValue,
            lensTitle: ThinkingLens.judgmentCalibration.title, signal: "reinforce", completion: "done", valueRating: "high",
            calibrationNote: "两条结果记录冲突，无法核实完成或判断；高价值是个人自评。",
            recommendation: nil, questionTargets: ["字段示例能帮助朋友独立完成填写"], evidenceGapTypes: ["missing_observation"],
            lensMoves: ["prediction_calibration"], verificationId: historyID.uuidString,
            evidenceText: "甲说完成，乙说未完成，来源和时间未核实。", calibrationAssessment: assessment)
        let card = ThinkingCard(type: .decision, title: "任务变简单也可能减少返工",
            body: "同事这次把验收标准写清后返工少了，但这次任务可能比上次简单，尚未比较任务范围。我现在还不能把改善归因于书面验收。我愿意先用已有记录比较范围，不再追加测试。", isConfirmed: true)
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let context = TodayAIContext(draft: DailyEntryDraft(rawText: card.body, selectedLens: .judgmentCalibration),
            confirmedCards: [card], lensFeedback: [history])
        let questions = try await service.generateQuestions(for: context)
        XCTAssertLessThanOrEqual(questions.count, 1)
        // A confirmed open gap plus the user's chosen comparison route is enough for one action.
        let quests = try await service.generateQuests(for: context)
        XCTAssertEqual(quests.filter { $0.type == .main }.count, 1)
        XCTAssertEqual(quests.count, 1)
        let records = (0..<3).map { index -> GrowthRecordSummary in
            let entryID = UUID()
            let verification = Verification(questId: UUID(), questTitle: "历史行动 \(index)", sourceDailyEntryId: entryID,
                completion: .done, valueRating: .high, judgmentUpdate: .confirmed, evidenceText: "只选了已完成和高价值，没有记录任何实际结果。",
                calibrationNote: "没有可核对的结果，验收和判断仍未确定。",
                calibrationAssessment: CalibrationAssessment(evidenceStatus: .missing, criteriaStatus: .notAssessable,
                    judgmentStatus: .unresolved, evidenceQuotes: []))
            return GrowthRecordSummary(dailyEntryId: entryID, date: Calendar.current.date(byAdding: .day, value: -index, to: .now)!,
                confirmedCardCount: 1, hasMainQuest: true, mainQuestTitle: verification.questTitle,
                mainQuestCompletionCriteria: "留下独立完成的结果记录", verificationCompletion: "done", verificationValueRating: "high",
                calibrationNote: verification.calibrationNote, hasLensSessionAnswers: true, principleTitles: [],
                verificationId: verification.id, verificationEvidenceText: verification.evidenceText,
                calibrationAssessment: verification.calibrationAssessment, verifications: [HistoricalVerificationEvidence(verification)])
        }
        let report = try await GrowthAIService(promptProvider: LocalPromptProvider(), llmClient: client).generateMonthlyReport(context:
            GrowthReportContext(period: "monthly", startDate: nil, endDate: nil, completeLoopCount: 3, historyRecords: records,
                previousSnapshot: nil, dismissedContributionTitles: []))
        XCTAssertFalse(report.snapshot.canDisplayScores)
        XCTAssertTrue(report.contributions.isEmpty)
        XCTAssertEqual(client.records.count, 3)
    }

    func testLiveResultCalibrationWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_RESULT_CALIBRATION"] == "1" else {
            throw XCTSkip("Explicit synthetic observed and conflicting result calibration only")
        }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key,
            configuration: try harness.mentorConfiguration()))
        let scenarios = resultCalibrationScenarios()
        defer {
            for (index, record) in client.records.enumerated() {
                let id = scenarios[index].id
                try? attachMentorRequest(record.request, caseID: "result-\(id)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "result-\(id)-normalized-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        for scenario in scenarios {
            let result = try await service.verifyQuest(input: scenario.input, sessionMode: .standard)
            let assessment = try XCTUnwrap(result.calibrationAssessment, scenario.id)
            XCTAssertEqual(assessment.evidenceStatus, scenario.expected.evidenceStatus, scenario.id)
            XCTAssertEqual(assessment.criteriaStatus, scenario.expected.criteriaStatus, scenario.id)
            XCTAssertEqual(assessment.judgmentStatus, scenario.expected.judgmentStatus, scenario.id)
            XCTAssertTrue(assessment.isGrounded(in: scenario.input.rawText,
                hasGrowthEvidence: !result.growthEvidenceItems.isEmpty), scenario.id)
            if scenario.expected.evidenceStatus == .conflicting {
                XCTAssertTrue(result.growthEvidenceItems.isEmpty, "Unresolved incompatible records cannot establish new behavior")
            }
            XCTAssertFalse(result.calibrationNote.isEmpty, scenario.id)
        }
    }

    func testLiveGuidanceSelectionWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_GUIDANCE_SELECTION"] == "1" else { throw XCTSkip("Explicit synthetic guidance selection only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
        let item = try XCTUnwrap(BuiltinGuidanceCatalog.items.first { $0.hintId == "judgment.observable_evidence" })
        let scenarios: [(id: String, raw: String, reflection: GuidanceReflectionContext, expected: GuidanceDecision.Action)] = [
            ("values-already-explained-stop", "我在晚间兼职和陪孩子之间选陪孩子，这段时间家庭优先。请只解释机会成本，不要再让我补材料。",
             GuidanceReflectionContext(userQuestionsAndAnswers: [ReflectionQuestion(question: "你更看重什么？", whyItMatters: "以用户价值为准。", answer: "家庭，已经想清楚，今天先到这里。")],
                modelExplanation: CoachExplanation(text: "选择陪伴的机会成本是放弃这次兼职收入；这不说明收入永远不重要，而是你当前优先家庭。", sourceCardTitles: ["晚间取舍"]), modelReview: nil), .hold),
            ("intent-inference-existing-observations", "朋友取消了周五见面，所以他一定不重视我。我想检查这个判断，目前知道他取消了，但还没有区分哪些是观察、哪些是我对原因的解释。",
             GuidanceReflectionContext(userQuestionsAndAnswers: [], modelExplanation: nil, modelReview: nil), .show)
        ]
        defer {
            for (index, record) in client.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "guidance-selection-\(scenarios[index].id)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "guidance-selection-\(scenarios[index].id)-normalized-response"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
            }
        }
        let service = GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        for scenario in scenarios {
            let context = GuidanceDecisionContext(stage: .judgment, triggerKeys: [item.triggerKey],
                candidates: [GuidanceDecisionCandidate(hintId: item.hintId, copy: item.copy, explanation: item.explanation,
                    stage: item.stage, triggerKey: item.triggerKey)], states: [], currentCaseId: UUID().uuidString,
                currentCaseTitle: scenario.id, evidenceSummary: scenario.raw, reflection: scenario.reflection)
            let result = try await service.choose(context: context)
            XCTAssertEqual(result.action, scenario.expected, scenario.id)
            // Stop on unexpected behavior; do not retry or proceed to another paid call.
            guard result.action == scenario.expected else { return }
        }
        XCTAssertEqual(client.records.count, 2)
    }

    func testLiveGuidanceEvidenceWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_GUIDANCE_EVIDENCE"] == "1" else { throw XCTSkip("Explicit synthetic guidance evidence only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: try harness.mentorConfiguration()))
        let item = try XCTUnwrap(BuiltinGuidanceCatalog.items.first { $0.hintId == "action.completion_criteria" })
        let scenarios: [(String, String, GuidanceEvidenceResult)] = [
            ("unknown-process-good-outcome", "交回后没有返工，但我记不清动手前有没有写完成标准，只知道把高价值和判断已确认勾上了。没有当时的过程记录。", .insufficient),
            ("reported-behavior-failed-outcome", "接手人动手前，我写明了交付物、三条完成标准，并请对方核对一致。交回后仍因记录中没覆盖的例外返工两次。做过确认动作，不知道是否减少了返工。", .supports),
            ("explicit-non-use-good-outcome", "这次动手前没有写任何完成标准，也没有约定怎样算做完。交回后恰好没返工，但任务范围小很多，我不知道原因。", .counterexample)
        ]
        defer {
            for (index, record) in client.records.enumerated() {
                let id = scenarios[index].0
                try? attachMentorRequest(record.request, caseID: "guidance-evidence-\(id)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "guidance-evidence-\(id)-normalized-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let service = GuidanceAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        for (id, raw, expected) in scenarios {
            let quest = Quest(type: .main, title: "交接前写清完成标准并记录结果",
                whyItMatters: "保留可核对的标准和结果。", completionCriteria: "动手前有明确标准，并记录交回是否返工。",
                expectedResistance: "可能赶时间。", reflectionQuestion: "本次结果能说明什么？",
                calibrationTarget: "明确标准可能减少口径不同造成的返工，单次结果不证明因果。")
            let verification = Verification(questId: quest.id, questTitle: quest.title, sourceDailyEntryId: UUID(),
                completion: .done, valueRating: .high, judgmentUpdate: .confirmed, evidenceText: raw,
                calibrationNote: "只有本次结果，无法确认因果。", calibrationAssessment: CalibrationAssessment(
                    evidenceStatus: .observed, criteriaStatus: .notAssessable, judgmentStatus: .unresolved,
                    evidenceQuotes: [raw]))
            let result = try await service.evaluateEvidence(item: item, quest: quest, verification: verification)
            XCTAssertEqual(result.result, expected, id)
        }
    }

    func testLivePrinciplePracticeWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_PRINCIPLE_PRACTICE"] == "1" else {
            throw XCTSkip("Explicit synthetic principle behavior classification only")
        }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key,
            configuration: try harness.mentorConfiguration()))
        let scenarios: [(String, String, PrinciplePracticeAssessment.Status, CalibrationAssessment.EvidenceStatus)] = [
            ("selected-good-outcome-without-action",
             "我选了这条原则，也把完成、高价值和判断已确认勾上了。这次没有写验收标准，也没有请接手人复述。交回后恰好没有返工，但这次任务范围小了很多，我不知道没返工的原因。",
             .notPracticed, .observed),
            ("performed-actions-outcome-failed",
             "交接开始前，我把交付物和验收标准写进记录，请接手人用自己的话复述，对方复述的内容和记录一致。交回后仍因一个记录中没覆盖的例外返工两次。标准确认动作做了，但不能说明它减少返工。",
             .practiced, .observed),
            ("partial-actions-outcome-unknown",
             "交接开始前我写了交付物和验收标准，但没有请接手人复述确认。对方还没交回，没有任何后续结果或反馈。",
             .partiallyPracticed, .missing),
            ("outcome-does-not-reveal-process",
             "我只保留了交回后没有返工的记录，记不清当时是否写了标准、是否请对方复述。虽然选过这条原则，我没有当时的动作记录，也不想现在补做练习。",
             .notAssessable, .observed)
        ]
        defer {
            for (index, record) in client.records.enumerated() {
                let id = scenarios[index].0
                try? attachMentorRequest(record.request, caseID: "principle-practice-\(id)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "principle-practice-\(id)-normalized-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        for (id, rawText, expectedPractice, expectedOutcome) in scenarios {
            let principleID = UUID()
            let result = try await service.verifyQuest(input: VerifyQuestInput(sourceRecordIDs: [UUID().uuidString],
                questTitle: "本次交接前确认验收标准并观察返工",
                completionCriteria: "动手前双方确认同一验收标准，并记录交回后是否返工及原因。",
                targetJudgment: "这次交接前确认验收标准可能减少口径不同造成的返工；单次无返工不能确认因果。",
                trainingPrinciple: .init(principleId: principleID, principleTitle: "交接前写明标准并请接手人复述",
                    matchSignal: "用户选择", triggerContext: "跨人交接，接手人开始动手前",
                    actions: ["写明交付物和验收标准", "请接手人用自己的话复述并核对双方理解"],
                    successCriteria: "动手前有双方确认一致的记录；交回后另行观察是否存在口径不同造成的返工",
                    exceptions: "紧急且可逆的小事可简化，不保证消除全部返工"),
                completion: "done", valueRating: "high", judgmentUpdate: "confirmed", rawText: rawText), sessionMode: .standard)
            XCTAssertEqual(result.principlePracticeAssessment?.status, expectedPractice, id)
            XCTAssertEqual(result.principlePracticeAssessment?.principleId, principleID, id)
            XCTAssertEqual(result.calibrationAssessment?.evidenceStatus, expectedOutcome, id)
            if expectedOutcome == .missing { XCTAssertTrue(result.growthEvidenceItems.isEmpty, id) }
        }
    }

    private func resultCalibrationScenarios() -> [(id: String, input: VerifyQuestInput, expected: CalibrationAssessment)] {
        let support = VerifyQuestInput(sourceRecordIDs: [UUID().uuidString],
            questTitle: "请朋友自愿再试一次字段示例", completionCriteria: "朋友看示例后独立完成本次三个字段，并记录其反馈。",
            targetJudgment: "这位朋友这次对字段含义不清楚，补充示例可能有助于其独立填写。",
            completion: "done", valueRating: "high", judgmentUpdate: "confirmed",
            rawText: "网络正常。我只加了字段示例，没有口头讲解。朋友看完示例后独立填完三个字段，说：原来这个字段要填的是付款方，不是收款方，示例让我看懂了。只观察这一次，我不知道熟悉任务是否也有影响，不能推广到别人。")
        let counterexample = VerifyQuestInput(sourceRecordIDs: [UUID().uuidString],
            questTitle: "网络恢复后请同一朋友重试", completionCriteria: "在网络正常且设计不变时，朋友能独立完成本次三个字段。",
            targetJudgment: "网络中断是上次未完成的唯一障碍，网络恢复且设计不变时，这位朋友本次能独立完成三个字段。",
            completion: "done", valueRating: "high", judgmentUpdate: "confirmed",
            rawText: "这次网络全程正常，入口和字段设计没改，仍是同一位朋友。他只填了第一个字段，后两个留空，说不知道这里要填谁的信息，最后退出，没有提交。我选了已完成和判断已确认，但实际只完成了重试动作，没有完成原先预测的填写结果。")
        let conflict = VerifyQuestInput(sourceRecordIDs: [UUID().uuidString],
            questTitle: "核对本次填写结果", completionCriteria: "本次三个字段全部填写并提交成功，且有同一次操作的记录。",
            targetJudgment: "字段示例已经让这位朋友本次独立完成全部填写。",
            completion: "done", valueRating: "high", judgmentUpdate: "confirmed",
            rawText: "我保留了两份都标为本次同一操作的记录。记录甲写：三个字段填完并提交成功。记录乙写：第二、第三字段留空，未提交就退出。两份记录的时间和来源还没核对，朋友也说记不清哪份准确。我无法判断哪份对应这次，不能择一作为结果。")
        return [
            ("observed-support", support, CalibrationAssessment(evidenceStatus: .observed, criteriaStatus: .met, judgmentStatus: .supported, evidenceQuotes: [])),
            ("observed-counterexample", counterexample, CalibrationAssessment(evidenceStatus: .observed, criteriaStatus: .notMet, judgmentStatus: .weakened, evidenceQuotes: [])),
            ("conflicting-records", conflict, CalibrationAssessment(evidenceStatus: .conflicting, criteriaStatus: .notAssessable, judgmentStatus: .unresolved, evidenceQuotes: []))
        ]
    }

    func testLiveTodayQuestionAndStopBoundaryWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_TODAY_ACCEPTANCE"] == "1" else { throw XCTSkip("Explicit synthetic Today acceptance only") }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        let key = try XCTUnwrap(try harness.resolvedAPIKey())
        let configuration = try harness.mentorConfiguration()
        let client = LiveTodayCaptureClient(base: DirectGLMClient(apiKey: key, configuration: configuration))
        defer {
            for (index, record) in client.records.enumerated() {
                try? attachMentorRequest(record.request, caseID: "today-\(index)")
                if let data = record.data {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "today-guidance-\(index)-raw-response"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
        let caseID = UUID()
        let positivePurposeOnly = env["MINGSI_LIVE_QUESTION_PURPOSE_POSITIVE"] == "1"
        let card = positivePurposeOnly
            ? ThinkingCard(type: .problem, title: "报告晚交两天",
                body: "同事把报告晚交两天，我就认定他肯定故意不配合。我们还没谈过原因。请帮我检查这个判断中哪一步推得太远，我愿意分清事实和推测。", isConfirmed: true)
            : ThinkingCard(type: .problem, title: "一次未完成不足以证明设计失败",
                body: "只请一位朋友试过新入口，他没能完成，后来发现网络断了。我原以为是设计失败，现在还不能分清原因。", isConfirmed: true)
        let today = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let questions = try await today.generateQuestions(for: TodayAIContext(
            draft: DailyEntryDraft(rawText: card.body), confirmedCards: [card]))
        XCTAssertLessThanOrEqual(questions.count, 1)
        if positivePurposeOnly {
            let question = try XCTUnwrap(questions.first, "An explicit request to inspect unsupported intent should receive one useful distinction")
            XCTAssertEqual(question.sourceCardTitles, [card.title])
            XCTAssertFalse(question.whyItMatters.isEmpty)
            XCTAssertNotNil(question.whyNow)
            XCTAssertNotNil(question.expectedUpdate)
            XCTAssertNotNil(question.proceedWhen)
            return
        }
        guard var answered = questions.first else {
            // A valid empty question result must not be converted into an
            // artificial turn just so this harness can run a stopping check.
            let attachment = XCTAttachment(string: "No question was chosen. Stop-boundary review was not executed; this run only proves the no-question path.")
            attachment.name = "today-stop-review-not-executed"
            attachment.lifetime = .keepAlways
            add(attachment)
            return
        }
        answered.answer = "只有这位朋友的一次尝试，后来发现网络断了，没有其他测试或记录；我不知道设计有没有问题。今天不想继续回忆，别再问了，也先不要替我安排验证任务。"
        let review = try await CoachAnswerReviewAIService(promptProvider: LocalPromptProvider(), llmClient: client).review(
            context: CoachAnswerReviewContext(caseId: caseID, caseTitle: "入口的一次尝试", mode: .standard,
                cards: [card], questions: [answered], previousTurn: CoachTurnState(
                    phase: .fillEvidenceGap, readiness: .notReady, recommendedMove: .surfaceEvidenceGap,
                    reason: "原因尚未确定", openEvidenceGaps: [.missingObservation], baselineChecks: [],
                    decisionSource: .coachRecommended, policyVersion: "synthetic-live", turnSummary: "只知道一次未完成和断网")))
        XCTAssertTrue(review.feedback.nextRepairQuestion.isEmpty)
        XCTAssertTrue(review.feedback.hasStopped)
        XCTAssertTrue(review.feedback.experienceReplayPrompt.isEmpty)
        XCTAssertTrue(review.feedback.judgmentSentencePrompt.isEmpty)
        XCTAssertTrue(review.feedback.teachingPlan.experienceReplayPrompt.isEmpty)
        XCTAssertNil(review.referenceSuggestion)
        XCTAssertFalse(review.feedback.canProceedToValidation,
            "Stopping is a boundary, not new evidence that the cause is established")
        XCTAssertNotEqual(review.turn.readiness, .ready)
    }

    func testMentorSemanticCasesPreserveExactUserMaterialsAndCurrentPrompt() throws {
        let cases = try mentorSemanticCases()
        XCTAssertEqual(cases.count, 9)
        for scenario in cases {
            let template = LocalPromptProvider().template(for: scenario.promptID, mode: .standard)
            XCTAssertEqual(template.version, scenario.promptID == .mentorRespond ? "2.17.0" : "2.6.0")
            let replay = try JSONDecoder().decode(MentorContextPayload.self, from: Data(scenario.context.json.utf8))
            XCTAssertEqual(replay.sources.filter { $0.role == .user }.map(\.content), scenario.userTexts)
            if let latest = replay.latestUserSourceRef {
                XCTAssertTrue(replay.sources.contains { $0.ref == latest && $0.role == .user })
                XCTAssertTrue(replay.currentExchangeRefs.contains(latest))
            }
        }
        XCTAssertEqual(cases[1].context.validation.intent, .directTeaching)
        XCTAssertEqual(cases[2].context.payload.sources.filter { $0.role == .user }.count, 2)
        XCTAssertEqual(cases[4].context.payload.materialQuestionCount, 2)
        XCTAssertFalse(cases[4].context.payload.allowsMaterialQuestion)
        let recallFollowUp = try XCTUnwrap(cases.first { $0.id == "review-recall-follow-up" })
        XCTAssertEqual(recallFollowUp.context.payload.initialEntry, "review")
        XCTAssertEqual(recallFollowUp.context.payload.conversationState.visibleTurnIndex, 2)
        XCTAssertEqual(recallFollowUp.context.payload.materialQuestionCount, 0)
        XCTAssertTrue(recallFollowUp.context.payload.allowsMaterialQuestion)
        let multiTurnAdvice = try XCTUnwrap(cases.first { $0.id == "multi-turn-advice" })
        XCTAssertEqual(multiTurnAdvice.context.payload.conversationState.visibleTurnIndex, 2)
        XCTAssertEqual(multiTurnAdvice.context.payload.conversationState.previousAssistantQuestion,
            "你补上字段示例后，对方的执行结果有变化吗？")
        XCTAssertEqual(multiTurnAdvice.context.payload.materialQuestionCount, 1)
        XCTAssertEqual(multiTurnAdvice.userTexts.count, 2)
    }

    func testMentorLiveFollowUpPreservesParsedEnvelopeQuestionAndResponse() throws {
        let conversation = try mentorMultiTurnConversation()
        let firstUserRef = try XCTUnwrap(conversation.openingContext.payload.latestUserSourceRef)
        let opening = MentorTurnResponse(schemaVersion: "1.0.0", action: .clarify,
            materialStatus: .usable, body: "目前还不能判断是文档还是阅读的问题。",
            question: "补上请求字段示例后，对方是否完成了？", questionPurpose: .material,
            sourceRefs: [firstUserRef], lessonRef: nil, suggestedActions: [.reply])
        let content = String(decoding: try JSONEncoder().encode(opening), as: UTF8.self)
        let wireResponse = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["role": "assistant", "content": content]]]
        ])
        let parsed = try MentorResponseParser().parseTurn(wireResponse,
            context: conversation.openingContext.validation).response
        let followUp = try conversation.followUpContext(assistantResponse: parsed)

        XCTAssertEqual(followUp.payload.conversationState.visibleTurnIndex, 2)
        XCTAssertEqual(followUp.payload.materialQuestionCount, 1)
        XCTAssertEqual(followUp.payload.conversationState.previousAssistantQuestion, opening.question)
        XCTAssertEqual(followUp.validation.previousAssistantQuestion, opening.question)
        let assistantSource = try XCTUnwrap(followUp.payload.sources.first { $0.role == .assistant })
        XCTAssertEqual(try JSONDecoder().decode(MentorTurnResponse.self, from: Data(assistantSource.content.utf8)), opening)
        let latestUserRef = try XCTUnwrap(followUp.payload.latestUserSourceRef)
        XCTAssertEqual(followUp.payload.sources.first { $0.ref == latestUserRef }?.content, conversation.followUpText)

        let repeated = MentorTurnResponse(schemaVersion: "1.0.0", action: .clarify,
            materialStatus: .usable, body: "还需要确认补上示例的结果。",
            question: opening.question, questionPurpose: .material, sourceRefs: [latestUserRef],
            lessonRef: nil, suggestedActions: [.reply])
        XCTAssertThrowsError(try MentorResponseParser().parseTurn(JSONEncoder().encode(repeated),
            context: followUp.validation)) { error in
            XCTAssertEqual(error as? MentorResponseError, .repeatedQuestion)
        }
    }

    func testLiveMentorSemanticCasesWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["MINGSI_LIVE_MENTOR_ACCEPTANCE"] == "1" || env["SIMCTL_CHILD_MINGSI_LIVE_MENTOR_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Set MINGSI_LIVE_MENTOR_ACCEPTANCE=1 to run synthetic mentor cases using the configured BYOK model.")
        }
        let harness = LiveGLMAcceptanceHarness(environment: env)
        guard let key = try harness.resolvedAPIKey() else {
            throw XCTSkip("No BYOK API key available for live mentor semantic acceptance.")
        }
        let configuration = try harness.mentorConfiguration()
        let client = DirectGLMClient(apiKey: key, configuration: configuration)
        let metadata = XCTAttachment(data: try JSONSerialization.data(withJSONObject: [
            "model": configuration.model, "endpoint": configuration.endpoint.absoluteString,
            "protocol": configuration.protocolKind.rawValue,
            "mentor_prompt_version": LocalPromptProvider().template(for: .mentorRespond, mode: .standard).version,
            "understanding_prompt_version": LocalPromptProvider().template(for: .mentorDraftUnderstanding, mode: .standard).version,
            "semantic_review_required": true
        ], options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        metadata.name = "mentor-semantic-run-metadata"
        metadata.lifetime = .keepAlways
        add(metadata)
        for scenario in try mentorSemanticCases() {
            if scenario.id == "multi-turn-advice" {
                let conversation = try mentorMultiTurnConversation()
                var openingRequest = LLMRequest(
                    prompt: LocalPromptProvider().template(for: .mentorRespond, mode: .standard),
                    inputSummary: conversation.openingContext.json
                )
                openingRequest.mentorExecutionPolicy = .m1
                try attachMentorRequest(openingRequest, caseID: "multi-turn-opening")
                let openingData = try await completeMentorLiveRequest(openingRequest, client: client, caseID: "multi-turn-opening")
                let openingAttachment = XCTAttachment(data: openingData, uniformTypeIdentifier: "public.json")
                openingAttachment.name = "mentor-semantic-multi-turn-opening-raw-response"
                openingAttachment.lifetime = .keepAlways
                add(openingAttachment)

                let opening = try MentorResponseParser().parseTurn(openingData,
                    context: conversation.openingContext.validation).response
                XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(
                    opening,
                    context: conversation.openingContext.validation,
                    initialEntry: conversation.openingContext.payload.initialEntry,
                    intent: conversation.openingContext.payload.intent
                ))
                XCTAssertEqual(opening.action, .clarify,
                    "The first turn should follow the user's request to clarify before giving advice.")
                XCTAssertEqual(opening.questionPurpose, .material)
                guard let openingQuestion = opening.question else {
                    XCTFail("The first turn should ask the one requested material question.")
                    return
                }

                let followUpContext = try conversation.followUpContext(
                    assistantResponse: opening
                )
                XCTAssertEqual(followUpContext.payload.conversationState.visibleTurnIndex, 2)
                XCTAssertEqual(followUpContext.payload.conversationState.previousAssistantQuestion, openingQuestion)
                var followUpRequest = LLMRequest(
                    prompt: LocalPromptProvider().template(for: .mentorRespond, mode: .standard),
                    inputSummary: followUpContext.json
                )
                followUpRequest.mentorExecutionPolicy = .m1
                try attachMentorRequest(followUpRequest, caseID: "multi-turn-follow-up")
                let followUpData = try await completeMentorLiveRequest(followUpRequest, client: client, caseID: "multi-turn-follow-up")
                let followUpAttachment = XCTAttachment(data: followUpData, uniformTypeIdentifier: "public.json")
                followUpAttachment.name = "mentor-semantic-multi-turn-follow-up-raw-response"
                followUpAttachment.lifetime = .keepAlways
                add(followUpAttachment)

                let response = try MentorResponseParser().parseTurn(followUpData,
                    context: followUpContext.validation).response
                XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(
                    response,
                    context: followUpContext.validation,
                    initialEntry: followUpContext.payload.initialEntry,
                    intent: followUpContext.payload.intent
                ))
                XCTAssertTrue([MentorAction.advise, .compare].contains(response.action),
                    "A direct request for advice must be answered in the follow-up turn.")
                XCTAssertNil(response.question,
                    "The mentor should answer the new request instead of reopening the prior question.")
                try recordSemanticSignal(MentorSemanticAcceptancePolicy.hasMultiTurnRecommendation(response.body),
                    caseID: "multi-turn-advice", requirement: "Use the new result and state a useful preference.")
                continue
            }

            var request = LLMRequest(prompt: LocalPromptProvider().template(for: scenario.promptID, mode: .standard), inputSummary: scenario.context.json)
            request.mentorExecutionPolicy = .m1
            try attachMentorRequest(request, caseID: scenario.id)
            let result = try await completeMentorLiveRequest(request, client: client, caseID: scenario.id)
            let attachment = XCTAttachment(data: result, uniformTypeIdentifier: "public.json")
            attachment.name = "mentor-semantic-\(scenario.id)-raw-response"
            attachment.lifetime = .keepAlways
            add(attachment)
            if scenario.promptID == .mentorDraftUnderstanding {
                _ = try MentorResponseParser().parseUnderstanding(result, context: scenario.context.validation)
            } else {
                let response = try MentorResponseParser().parseTurn(result, context: scenario.context.validation).response
                XCTAssertNoThrow(try MentorResponseQualityPolicy.validate(
                    response,
                    context: scenario.context.validation,
                    initialEntry: scenario.context.payload.initialEntry,
                    intent: scenario.context.payload.intent
                ))
                if scenario.id == "tired" {
                    XCTAssertNil(response.question)
                    try recordSemanticSignal(MentorSemanticAcceptancePolicy.acknowledgesListeningRequest(response.body),
                        caseID: scenario.id, requirement: "A tired user asking for company should receive company without coaching.")
                }
                if scenario.id == "teaching" {
                    XCTAssertEqual(response.action, .explain)
                    XCTAssertNil(response.question)
                    try recordSemanticSignal(MentorSemanticAcceptancePolicy.explainsRequestedComparison(response.body),
                        caseID: scenario.id, requirement: "Explain a concrete difference with appropriate conditions and boundaries.")
                }
                if scenario.id == "budget" { XCTAssertNil(response.question) }
                if scenario.id == "correction" {
                    let latestSource = try XCTUnwrap(scenario.context.payload.latestUserSourceRef)
                    XCTAssertTrue(response.sourceRefs.contains(latestSource),
                        "A correction response must cite the latest user expression.")
                    try recordSemanticSignal(MentorSemanticAcceptancePolicy.usesCorrectedEvidence(response.body),
                        caseID: scenario.id, requirement: "Use the corrected scope and network cause and withdraw the superseded conclusion.")
                }
                if scenario.id == "recommendation" {
                    XCTAssertTrue([MentorAction.advise, .compare].contains(response.action))
                    XCTAssertNil(response.question)
                    try recordSemanticSignal(MentorSemanticAcceptancePolicy.hasConditionalPreference(response.body),
                        caseID: scenario.id, requirement: "State a preference grounded in the user's aim, with conditions and limitations.")
                }
                if scenario.id == "challenge" {
                    XCTAssertNotEqual(response.action, .close)
                    XCTAssertFalse(response.sourceRefs.isEmpty)
                    try recordSemanticSignal(MentorSemanticAcceptancePolicy.identifiesChallenge(response.body),
                        caseID: scenario.id, requirement: "Name the premise and its weak inference without inventing user facts.")
                }
                if scenario.id == "review-recall-follow-up" {
                    XCTAssertTrue(response.requiresMaterial,
                        "An unresolved zero-material review may use the remaining recall budget after its opening turn.")
                    XCTAssertEqual(response.questionPurpose, .material)
                }
            }
        }
    }

    private func completeMentorLiveRequest(_ request: LLMRequest, client: DirectGLMClient, caseID: String) async throws -> Data {
        let clock = ContinuousClock()
        let start = clock.now
        print("Mentor live request started: \(caseID)")
        do {
            let data = try await client.complete(request)
            print("Mentor live request returned: \(caseID), elapsed=\(start.duration(to: clock.now))")
            return data
        } catch {
            // Report only error type/domain/code, never request headers or credentials.
            if case LLMClientError.httpStatus(let status, let data) = error {
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let providerError = object?["error"] as? [String: Any]
                let providerCode = providerError?["code"].map { String(describing: $0) } ?? "unknown"
                print("Mentor live HTTP failure: \(caseID), status=\(status), provider_code=\(providerCode)")
            }
            let underlying: Error
            if case LLMClientError.transport(let transport) = error { underlying = transport }
            else { underlying = error }
            let nsError = underlying as NSError
            print("Mentor live request failed: \(caseID), type=\(String(reflecting: type(of: error))), domain=\(nsError.domain), code=\(nsError.code)")
            throw error
        }
    }

    private func attachMentorRequest(_ request: LLMRequest, caseID: String) throws {
        var snapshot: [String: Any] = [
            "prompt_id": request.prompt.id.rawValue, "prompt_version": request.prompt.version,
            "system_text": request.prompt.systemText, "user_text": request.prompt.userText,
            "input_summary": request.inputSummary
        ]
        if let payload = request.contextPayload {
            snapshot["context_payload"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload))
        }
        snapshot["source_record_ids"] = request.sourceRecordIDs
        let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "mentor-semantic-\(caseID)-request"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func recordSemanticSignal(_ passed: Bool, caseID: String, requirement: String) throws {
        // Natural language synonyms made these lexical checks report false
        // failures on real outputs. Keep them as review signals, never as a
        // semantic verdict. Protocol, sources, intent and production quality
        // gates above remain strict; every captured output needs separate review.
        let data = try JSONSerialization.data(withJSONObject: [
            "case_id": caseID, "lexical_signal_passed": passed,
            "semantic_review_required": true, "requirement": requirement
        ], options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "mentor-semantic-\(caseID)-review-signal"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMentorSemanticAcceptancePolicyRejectsNeutralAdviceAndGenericChallenge() {
        XCTAssertFalse(MentorSemanticAcceptancePolicy.hasConditionalPreference("首页入口和二级目录各有优缺点。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.hasConditionalPreference("我建议用首页快捷入口。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.hasConditionalPreference("按你希望少一步来看，我建议优先选首页入口。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.identifiesChallenge("桌面入口可能有帮助，可以再观察看看。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.identifiesChallenge("桌面入口只能减少操作步骤，不能保证用户每天记录；入口本身不等于形成习惯。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.acknowledgesListeningRequest("你今天可以再深入思考一下。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.acknowledgesListeningRequest("听起来你今天确实很累，可以先不用总结，我陪你聊一会儿。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.acknowledgesListeningRequest("那就先不总结，累的时候什么都不用整理。我在这里，安静待一会儿也行。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.acknowledgesListeningRequest("你很累，现在请分析今天的三个问题。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.explainsRequestedComparison("菜单入口和首页按钮各有优缺点。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.explainsRequestedComparison("首页按钮少一步点击，菜单入口则更适合低频功能。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.usesCorrectedEvidence("看来产品设计确实失败了，需要重新设计。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.usesCorrectedEvidence("这次只有一位朋友遇到问题，而且当时网络断了，所以设计还是普遍失败。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.usesCorrectedEvidence("这次只有一位朋友遇到问题，而且当时网络断了，不能据此判断设计普遍失败。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.usesCorrectedEvidence("一位朋友遇到了网络故障，所有人都没能完成就不再成立，之前设计普遍失效的判断需要撤回。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.usesCorrectedEvidence("一位朋友遇到网络故障，这说明设计普遍失败的判断仍成立。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.identifiesChallenge("如果没有记录动机，把图标放到桌面并不会改变行为；入口只能降低记录的摩擦。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.identifiesChallenge("把入口放到桌面，就能让用户每天记录。"))
        XCTAssertFalse(MentorSemanticAcceptancePolicy.hasMultiTurnRecommendation("补上示例后对方一次完成了，建议继续观察。"))
        XCTAssertTrue(MentorSemanticAcceptancePolicy.hasMultiTurnRecommendation("这次字段示例让对方一次完成；考虑需求变化，我建议先做最小模板，再按需补充。"))
    }

    private struct MentorSemanticCase {
        let id: String
        let promptID: PromptID
        let context: MentorBuiltContext
        let userTexts: [String]
    }

    private func mentorSemanticCases() throws -> [MentorSemanticCase] {
        let samples: [(String, [String], String, Int, PromptID)] = [
            ("tired", ["我今天只是很累，不想总结，陪我说说。"], "reply", 0, .mentorRespond),
            ("teaching", ["菜单入口和首页按钮到底怎么比较？直接讲。"], "explain", 0, .mentorRespond),
            ("correction", ["所有人都没能完成，看来设计失败了。", "更正，是一位朋友，后来发现网络断了。"], "reply", 0, .mentorRespond),
            ("uncertain", ["你说这方法有用，但我还不知道适不适合我。"], "draft_understanding", 0, .mentorDraftUnderstanding),
            ("budget", ["想不起来，别问了。"], "reply", 2, .mentorRespond),
            ("recommendation", ["首页快捷入口和二级目录都能打开今日闪念，你建议我选哪个？我希望少一步。"], "reply", 0, .mentorRespond),
            ("challenge", ["我认为只要把入口放到桌面，用户就一定会每天记录。请找出这个判断的漏洞。"], "reply", 0, .mentorRespond)
        ]
        let standardCases = try samples.map { id, texts, intent, count, promptID in
            let session = MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .active,
                draftText: "", draftRevision: 0, activityAt: .now, recallCount: count)
            var items: [MentorTimelineItem] = []
            for text in texts {
                items.append(MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: items.count + 1, kind: .user,
                    payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: ["text": text]), as: UTF8.self)))
                if id == "correction", items.count == 1 {
                    items.append(MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 2, kind: .assistant,
                        payloadJSON: "{\"body\":\"设计普遍失效了，需要重新设计。\"}"))
                }
            }
            let context = try MentorContextBuilder().build(session: session, items: items, intent: intent,
                responseIntent: intent == "explain" ? .directTeaching : .discuss)
            return MentorSemanticCase(id: id, promptID: promptID, context: context, userTexts: texts)
        }
        let reviewSession = MentorSession(id: UUID(), initialEntry: "review", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now, recallCount: 0)
        let opening = MentorTimelineItem(id: UUID(), sessionID: reviewSession.id, sequence: 1, kind: .assistant,
            payloadJSON: """
            {"schema_version":"1.0.0","action":"clarify","material_status":"missing","body":"可以从一个让你停下来的时刻开始。","question":"今天有没有哪件事让你停下来或改了原计划？","question_purpose":"material","source_refs":[],"lesson_ref":null,"suggested_actions":[]}
            """)
        let replyText = "今天主要在开发，上午改了一个接口，下午补了文档；还没说清楚具体哪一步值得回看。"
        let reply = MentorTimelineItem(id: UUID(), sessionID: reviewSession.id, sequence: 2, kind: .user,
            payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: ["text": replyText]), as: UTF8.self))
        let reviewContext = try MentorContextBuilder().build(session: reviewSession, items: [opening, reply], intent: "reply")
        let multiTurnSession = MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now, recallCount: 1)
        let firstUserText = "我想把接口文档一次写完整，免得同事反复问。但上周我确实没说清请求格式，也不知道是不是这个原因导致返工。"
        let firstUser = MentorTimelineItem(id: UUID(), sessionID: multiTurnSession.id, sequence: 1, kind: .user,
            payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: ["text": firstUserText]), as: UTF8.self))
        let firstUserRef = try MentorSourceReference("item:\(firstUser.id.uuidString)").value
        let firstAssistantPayload: [String: Any] = [
            "schema_version": "1.0.0",
            "action": "clarify",
            "material_status": "usable",
            "body": "目前能确认请求格式没有说清，但还不知道补上示例后是否能减少返工。",
            "question": "你补上字段示例后，对方的执行结果有变化吗？",
            "question_purpose": "material",
            "source_refs": [firstUserRef],
            "lesson_ref": NSNull(),
            "suggested_actions": []
        ]
        let firstAssistant = MentorTimelineItem(id: UUID(), sessionID: multiTurnSession.id, sequence: 2, kind: .assistant,
            payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: firstAssistantPayload), as: UTF8.self))
        let followUpText = "补上字段示例后，他一次就完成了。可需求经常变化，我不想每次都维护整篇文档。请基于这次经历，建议我先定一个最小接口模板，还是出问题后再补？"
        let followUp = MentorTimelineItem(id: UUID(), sessionID: multiTurnSession.id, sequence: 3, kind: .user,
            payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: ["text": followUpText]), as: UTF8.self))
        let multiTurnContext = try MentorContextBuilder().build(session: multiTurnSession,
            items: [firstUser, firstAssistant, followUp], intent: "reply")
        return standardCases + [
            MentorSemanticCase(id: "review-recall-follow-up", promptID: .mentorRespond,
                context: reviewContext, userTexts: [replyText]),
            MentorSemanticCase(id: "multi-turn-advice", promptID: .mentorRespond,
                context: multiTurnContext, userTexts: [firstUserText, followUpText])
        ]
    }

    private struct MentorMultiTurnConversation {
        let session: MentorSession
        let firstUser: MentorTimelineItem
        let firstUserText: String
        let followUpText: String
        let openingContext: MentorBuiltContext

        func followUpContext(assistantResponse: MentorTurnResponse) throws -> MentorBuiltContext {
            let assistant = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 2, kind: .assistant,
                payloadJSON: String(decoding: try JSONEncoder().encode(assistantResponse), as: UTF8.self))
            let followUp = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 3, kind: .user,
                payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: ["text": followUpText]), as: UTF8.self))
            var presentedSession = session
            if assistantResponse.requiresMaterial {
                presentedSession.recallCount += 1
            }
            return try MentorContextBuilder().build(session: presentedSession, items: [firstUser, assistant, followUp], intent: "reply")
        }
    }

    private func mentorMultiTurnConversation() throws -> MentorMultiTurnConversation {
        let session = MentorSession(id: UUID(), initialEntry: "discuss", lifecycle: .active,
            draftText: "", draftRevision: 0, activityAt: .now, recallCount: 0)
        let firstUserText = "同事没按接口文档完成，我觉得是他没认真看。但也可能是我的文档没说清。请先只问我一个能区分这两种原因的问题，不要先把所有可能性和建议都讲出来。"
        let firstUser = MentorTimelineItem(id: UUID(), sessionID: session.id, sequence: 1, kind: .user,
            payloadJSON: String(decoding: try JSONSerialization.data(withJSONObject: ["text": firstUserText]), as: UTF8.self))
        let followUpText = "我查到文档里漏了请求字段示例；补上后对方一次完成。需求还经常变，帮我建议先定一个最小模板，还是每次有问题后再补？"
        let openingContext = try MentorContextBuilder().build(session: session, items: [firstUser], intent: "reply")
        return MentorMultiTurnConversation(session: session, firstUser: firstUser, firstUserText: firstUserText,
            followUpText: followUpText, openingContext: openingContext)
    }
}

private final class LiveTodayStreamingCaptureClient: LLMClient, StreamingLLMClient {
    struct Capture {
        var requests: [LLMRequest] = []
        var streamCalls = 0
        var completeCalls = 0
        var httpAttempts = 0
        var rawText = ""
        var completed = false
        var errorDomain: String?
        var errorCode: Int?
    }
    private let state = Locked(Capture())
    private let base: DirectGLMClient
    var capture: Capture { state.value }
    init(base: DirectGLMClient) { self.base = base }
    func complete(_ request: LLMRequest) async throws -> Data {
        state.withLock { $0.completeCalls += 1 }
        throw LLMClientError.invalidResponse
    }
    func stream(_ request: LLMRequest, isolation: isolated (any Actor)?) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        state.withLock { $0.requests.append(request); $0.streamCalls += 1 }
        let upstream = base.stream(request, isolation: isolation)
        let state = self.state
        return AsyncThrowingStream { continuation in
            let task = Task {
                _ = isolation
                do {
                    for try await event in upstream {
                        state.withLock { capture in
                            switch event {
                            case .requestStarted: capture.httpAttempts += 1
                            case .token(let text): capture.rawText += text
                            case .completed: capture.completed = true
                            case .connected, .receivedEvent: break
                            }
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    let metadata: NSError
                    if case LLMClientError.transport(let underlying) = error { metadata = underlying as NSError }
                    else { metadata = error as NSError }
                    state.withLock { $0.errorDomain = metadata.domain; $0.errorCode = metadata.code }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private final class LiveTodayCaptureClient: LLMClient {
    struct Record { var request: LLMRequest; var data: Data? }
    let base: DirectGLMClient
    private(set) var records: [Record] = []
    init(base: DirectGLMClient) { self.base = base }
    func complete(_ request: LLMRequest) async throws -> Data {
        records.append(Record(request: request, data: nil))
        let data = try await base.complete(request)
        records[records.count - 1].data = data
        return data
    }
}

private enum MentorSemanticAcceptancePolicy {
    static func hasConditionalPreference(_ body: String) -> Bool {
        let namesOption = ["首页", "快捷入口", "二级目录"].contains(where: body.contains)
        let statesPreference = ["建议", "推荐", "优先", "首选", "更适合", "更合适", "最好", "倾向"].contains(where: body.contains)
        let statesCondition = ["按", "因为", "考虑", "如果", "希望", "在意"].contains(where: body.contains)
        return namesOption && statesPreference && statesCondition
    }

    static func acknowledgesListeningRequest(_ body: String) -> Bool {
        let acknowledgesFatigue = ["累", "疲惫", "休息"].contains(where: body.contains)
        let offersCompany = ["陪", "聊", "不用总结", "先放下", "我在这里", "安静待"].contains(where: body.contains)
        return acknowledgesFatigue && offersCompany
    }

    static func explainsRequestedComparison(_ body: String) -> Bool {
        let mentionsEntryPoints = ["菜单", "首页"].contains(where: body.contains)
        let namesConcreteDifference = ["点击", "步骤", "低频", "常用", "更快", "更容易"].contains(where: body.contains)
        return mentionsEntryPoints && namesConcreteDifference
    }

    static func usesCorrectedEvidence(_ body: String) -> Bool {
        let narrowsScope = ["一位", "一个", "朋友"].contains(where: body.contains)
        let usesNetworkEvidence = ["网络", "断网", "断开", "中断"].contains(where: body.contains)
        let limitsInference = ["不能据此", "不足以", "不代表", "不能说明", "并不能", "还不能", "不等于", "无法推出", "不再成立", "判断需要撤回"].contains(where: body.contains)
        return narrowsScope && usesNetworkEvidence && limitsInference
    }

    static func identifiesChallenge(_ body: String) -> Bool {
        let namesPremise = ["桌面", "入口", "快捷"].contains(where: body.contains)
        let namesOutcome = ["每天", "记录", "习惯"].contains(where: body.contains)
        let challengesInference = ["不能保证", "不等于", "不能推出", "不足以", "不一定", "并不保证", "还不能说明", "不代表", "并不会改变行为"].contains(where: body.contains)
        return namesPremise && namesOutcome && challengesInference
    }

    static func hasMultiTurnRecommendation(_ body: String) -> Bool {
        let usesNewEvidence = ["字段示例", "示例", "一次完成", "一次就完成"].contains(where: body.contains)
        let statesPreference = ["建议", "推荐", "优先", "更适合", "倾向"].contains(where: body.contains)
        let namesAPath = ["最小", "模板", "按需补", "出问题后"].contains(where: body.contains)
        let groundsPreference = ["需求", "考虑", "因为", "变化", "基于"].contains(where: body.contains)
        return usesNewEvidence && statesPreference && namesAPath && groundsPreference
    }
}

private final class LiveMentorStoreCaptureTransport: MentorTransport, LLMClient {
    struct Record {
        let request: LLMRequest
        var data: Data?
        var elapsedSeconds: TimeInterval?
        var failureKind: String?
        var errorDomain: String?
        var errorCode: Int?
    }
    let base: DirectGLMClient
    private(set) var records: [Record] = []
    init(base: DirectGLMClient) { self.base = base }
    func complete(_ request: LLMRequest) async throws -> Data {
        let index = records.count, start = ContinuousClock().now
        records.append(Record(request: request))
        defer {
            let elapsed = start.duration(to: ContinuousClock().now).components
            records[index].elapsedSeconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
        do {
            let data = try await base.complete(request)
            records[index].data = data
            return data
        } catch {
            // Error descriptions/bodies can contain endpoint or credential data.
            // Capture only typed failure class and numeric underlying transport metadata.
            records[index].failureKind = String(reflecting: type(of: error))
            let safeError: NSError
            if case LLMClientError.transport(let underlying) = error { safeError = underlying as NSError }
            else { safeError = error as NSError }
            records[index].errorDomain = safeError.domain
            records[index].errorCode = safeError.code
            throw error
        }
    }
}
