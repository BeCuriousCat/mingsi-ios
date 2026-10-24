import XCTest
import Synchronization
@testable import MingSi

final class DirectGLMClientTests: XCTestCase {
    @MainActor
    func testChatUsageOnlyEventIsRecordedAfterStopBeforeDoneWithoutBecomingContent() async throws {
        let body = #"""
        data: {"choices":[{"delta":{"content":"{\"body\":\"fixture\"}"}}],"usage":null}

        data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

        data: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":8,"total_tokens":20,"completion_tokens_details":{"reasoning_tokens":5},"private":"PRIVATE_USAGE_SENTINEL"}}

        data: [DONE]

        """#
        for host in ["api.openai.com", "custom.test"] {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [.init(statusCode: 200, body: body)]
            let store = RecordingHTTPObservationStore()
            var request = makeRequest(); request.mentorExecutionPolicy = .m1
            request.mentorStreamProgress = MentorStreamProgress()
            request.mentorHTTPObservation = observationChannel(request, store: store)
            let data = try await makeClient(configuration: GLMClientConfiguration(baseURL: URL(string: "https://\(host)/v1")!)).complete(request)
            let records = await store.snapshot()
            XCTAssertEqual(records.outcomes, [.returnedData])
            XCTAssertEqual(records.usages.count, 1)
            XCTAssertEqual(records.usages.first?.source, .chatStream)
            XCTAssertEqual(records.usages.first?.inputTokens, 12)
            XCTAssertEqual(records.usages.first?.reasoningTokens, 5)
            XCTAssertEqual(records.usages.first?.totalTokens, 20)
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("PRIVATE_USAGE_SENTINEL"))
            let raw = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let options = payload["stream_options"] as? [String: Any]
            XCTAssertEqual(options?["include_usage"] as? Bool, host == "api.openai.com" ? true : nil)
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    @MainActor
    func testNonStreamingChatRecordsPartialReportedUsageWithoutInventingTotal() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200,
            body: #"{"choices":[],"model":"PRIVATE_MODEL_SENTINEL","usage":{"prompt_tokens":0,"completion_tokens":7}}"#)]
        let store = RecordingHTTPObservationStore()
        var request = makeRequest(); request.mentorExecutionPolicy = .m1
        request.mentorHTTPObservation = observationChannel(request, store: store)
        _ = try await makeClient().complete(request)
        let records = await store.snapshot()
        XCTAssertEqual(records.usages.count, 1)
        XCTAssertEqual(records.usages.first?.source, .chatCompletion)
        XCTAssertEqual(records.usages.first?.inputTokens, 0)
        XCTAssertEqual(records.usages.first?.outputTokens, 7)
        XCTAssertNil(records.usages.first?.totalTokens)
        XCTAssertNil(records.usages.first?.reasoningTokens)
    }

    @MainActor
    func testReportedChatUsageDoesNotTurnTruncatedStreamIntoSuccess() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: #"""
        data: {"choices":[{"delta":{"content":"partial"}}]}

        data: {"choices":[],"usage":{"prompt_tokens":11,"completion_tokens":2,"total_tokens":13}}

        """#)]
        let store = RecordingHTTPObservationStore()
        var request = makeRequest(); request.mentorExecutionPolicy = .m1
        request.mentorStreamProgress = MentorStreamProgress()
        request.mentorHTTPObservation = observationChannel(request, store: store)
        do { _ = try await makeClient().complete(request); XCTFail("Missing terminal event") }
        catch LLMClientError.incompleteResponse { }
        let records = await store.snapshot()
        XCTAssertEqual(records.outcomes, [.failed])
        XCTAssertEqual(records.usages.first?.totalTokens, 13)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    @MainActor
    func testResponsesRecordsUsageForCompletedAndOutputLimitedAttemptsOnBothPaths() async throws {
        let limited = #"""
        data: {"type":"response.incomplete","response":{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"usage":{"input_tokens":9,"output_tokens":16,"total_tokens":25,"output_tokens_details":{"reasoning_tokens":16}}}}

        """#
        for streaming in [false, true] {
            for completed in [false, true] {
                GLMStubURLProtocol.requestBodies = []
                GLMStubURLProtocol.responses = [.init(statusCode: 200, body: completed ? responsesSSE() : limited)]
                let store = RecordingHTTPObservationStore()
                var request = makeRequest(); request.mentorExecutionPolicy = .responses
                if streaming { request.mentorStreamProgress = MentorStreamProgress() }
                request.mentorHTTPObservation = observationChannel(request, store: store)
                do {
                    _ = try await makeClient(configuration: responsesConfiguration()).complete(request)
                    XCTAssertTrue(completed, "An output limit cannot become success")
                } catch LLMClientError.providerStreamFailure(let failure) {
                    XCTAssertFalse(completed); XCTAssertEqual(failure.reason, .outputLimit)
                }
                let records = await store.snapshot()
                XCTAssertEqual(records.outcomes, [completed ? .returnedData : .failed])
                XCTAssertEqual(records.usages.count, 1)
                XCTAssertEqual(records.usages.first?.source, .responsesEvent)
                XCTAssertEqual(records.usages.first?.inputTokens, completed ? 12 : 9)
                XCTAssertEqual(records.usages.first?.reasoningTokens, completed ? nil : 16)
                XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
            }
        }
    }

    @MainActor
    func testSentOutputBudgetMatchesAttemptMetadataForEachSupportedContract() async throws {
        let cases: [(GLMClientConfiguration.ProtocolKind, String, String?, Int?)] = [
            (.openAICompatible, "api.z.ai", "max_tokens", 8_192),
            (.openAICompatible, "open.bigmodel.cn", "max_tokens", 8_192),
            (.openAICompatible, "api.openai.com", "max_completion_tokens", 8_192),
            (.openAICompatible, "custom.test", nil, nil),
            (.responses, "custom.test", "max_output_tokens", 16_000)
        ]
        for (kind, host, field, amount) in cases {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [.init(statusCode: 200,
                body: kind == .responses ? responsesSSE() : "{\"choices\":[]}")]
            let observations = RecordingHTTPObservationStore()
            var request = makeRequest()
            request.mentorExecutionPolicy = MentorRequestPolicy.forProtocol(kind)
            request.mentorHTTPObservation = observationChannel(request, store: observations)
            _ = try await makeClient(configuration: GLMClientConfiguration(baseURL: URL(string: "https://\(host)/v1")!, protocolKind: kind)).complete(request)
            let raw = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            for candidate in ["max_tokens", "max_completion_tokens", "max_output_tokens"] {
                XCTAssertEqual(payload[candidate] as? Int, candidate == field ? amount : nil)
            }
            let recorded = await observations.snapshot()
            XCTAssertEqual(recorded.fields, [field])
            XCTAssertEqual(recorded.budgets, [amount])
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    @MainActor
    func testProviderBudgetRejectionCannotStripFieldAndResend() async throws {
        for (kind, host, field) in [(GLMClientConfiguration.ProtocolKind.openAICompatible, "api.openai.com", "max_completion_tokens"),
                                   (.responses, "custom.test", "max_output_tokens")] {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [.init(statusCode: 400, body: "unsupported output budget"),
                .init(statusCode: 200, body: "unused")]
            var request = makeRequest()
            request.mentorExecutionPolicy = MentorRequestPolicy.forProtocol(kind)
            do {
                _ = try await makeClient(configuration: GLMClientConfiguration(baseURL: URL(string: "https://\(host)/v1")!, protocolKind: kind)).complete(request)
                XCTFail("Budget rejection must be terminal")
            } catch LLMClientError.httpStatus(let status, _) { XCTAssertEqual(status, 400) }
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
            let raw = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            XCTAssertEqual(payload[field] as? Int, MentorRequestPolicy.forProtocol(kind).outputTokenBudget)
        }
    }

    @MainActor
    func testMentorObservationRegistersEachCompleteTransportPathWithoutGuessingNativeMetrics() async throws {
        for (kind, streaming) in [(GLMClientConfiguration.ProtocolKind.openAICompatible, false), (.openAICompatible, true), (.responses, true)] {
            GLMStubURLProtocol.requestBodies = []
            let chatSSE = "data: {\"choices\":[{\"delta\":{\"content\":\"{\\\"body\\\":\\\"fixture\\\"}\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
            GLMStubURLProtocol.responses = [.init(statusCode: 200,
                body: kind == .responses ? responsesSSE() : (streaming ? chatSSE : "{\"choices\":[]}"))]
            let observations = RecordingHTTPObservationStore()
            var request = makeRequest()
            request.mentorExecutionPolicy = MentorRequestPolicy.forProtocol(kind)
            if streaming { request.mentorStreamProgress = MentorStreamProgress() }
            request.mentorHTTPObservation = observationChannel(request, store: observations)
            _ = try await makeClient(configuration: GLMClientConfiguration(baseURL: URL(string: "https://glm.test/v4")!, protocolKind: kind)).complete(request)
            let recorded = await observations.snapshot()
            XCTAssertEqual(recorded.identities.count, 1)
            XCTAssertEqual(recorded.identities.first?.traceID, request.traceID)
            XCTAssertEqual(recorded.kinds, [kind == .responses ? .responses : .openAICompatible])
            XCTAssertEqual(recorded.outcomes, [.returnedData])
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
            // URLProtocol does not establish native task-metrics support. The
            // SQLite tests separately prove missing callbacks remain unknown.
            if kind == .openAICompatible { XCTAssertTrue(recorded.usages.isEmpty, "Missing usage remains unknown") }
        }
    }

    @MainActor
    func testMentorObservationFailureBeforeDispatchMakesNoHTTPRequest() async throws {
        let observations = RecordingHTTPObservationStore(rejectRegistration: true)
        var request = makeRequest()
        request.mentorExecutionPolicy = .m1
        request.mentorHTTPObservation = observationChannel(request, store: observations)
        do { _ = try await makeClient().complete(request); XCTFail("Registration must succeed before HTTP") }
        catch MentorHTTPObservationError.unavailable { }
        XCTAssertTrue(GLMStubURLProtocol.requestBodies.isEmpty)
        let recorded = await observations.snapshot()
        XCTAssertTrue(recorded.outcomes.isEmpty)
    }

    @MainActor
    func testMentorHTTPFailureIsAccountedOnceWithoutFallbackOrRetry() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 400, body: "response_format unsupported"),
            .init(statusCode: 200, body: "unused")]
        let observations = RecordingHTTPObservationStore()
        var request = makeRequest()
        request.mentorExecutionPolicy = .m1
        request.mentorHTTPObservation = observationChannel(request, store: observations)
        do { _ = try await makeClient().complete(request); XCTFail("HTTP failure") }
        catch LLMClientError.httpStatus(let status, _) { XCTAssertEqual(status, 400) }
        let recorded = await observations.snapshot()
        XCTAssertEqual(recorded.identities.count, 1)
        XCTAssertEqual(recorded.outcomes, [.failed])
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    private func observationChannel(_ request: LLMRequest, store: any MentorHTTPObservationStore) -> MentorHTTPObservation {
        MentorHTTPObservation(traceID: request.traceID, sessionID: UUID(), requestID: UUID(),
            requestEpoch: 0, semanticRevision: 0, store: store)
    }

    func testGenericChatEOFDoesNotTurnPartialTextIntoCompletedOrRetry() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200,
            body: "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n")]
        var tokens = ""
        var completed = false
        do {
            for try await event in makeClient().stream(makeRequest()) {
                if case .token(let value) = event { tokens += value }
                if case .completed = event { completed = true }
            }
            XCTFail("EOF must report an interrupted response")
        } catch { }
        XCTAssertEqual(tokens, "partial")
        XCTAssertFalse(completed)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testGenericChatInBandErrorDoesNotBecomeSuccessfulCompletion() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200,
            body: "data: {\"error\":{\"code\":\"insufficient_quota\",\"message\":\"private provider diagnostic\"}}\n\ndata: [DONE]\n\n")]
        var completed = false
        do {
            for try await event in makeClient().stream(makeRequest()) {
                if case .completed = event { completed = true }
            }
            XCTFail("An HTTP-200 SSE error is still a failure")
        } catch let error as LLMClientError {
            XCTAssertFalse(error.userFacingMessage.contains("private provider diagnostic"))
        }
        XCTAssertFalse(completed)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testTransportUserMessageNeverEchoesSystemDiagnosticOrURL() {
        let error = NSError(domain: NSURLErrorDomain, code: URLError.unknown.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "private provider diagnostic https://example.test/?api_key=private"])
        let message = LLMClientError.transport(error).userFacingMessage
        XCTAssertFalse(message.contains("private"))
        XCTAssertFalse(message.contains("example.test"))
    }

    func testResponsesFailureDiagnosticsOnlyRetainAllowlistedReasonAndEvent() throws {
        let cases: [([String: Any], ProviderStreamFailure.Event, ProviderStreamFailure.Reason)] = [
            (["type": "response.failed", "response": ["error": ["code": "server_error", "message": "PRIVATE_PROVIDER_BODY"]]], .responsesFailed, .unavailable),
            (["type": "response.incomplete", "response": ["incomplete_details": ["reason": "max_output_tokens"]]], .responsesIncomplete, .outputLimit),
            (["type": "response.incomplete", "response": ["incomplete_details": ["reason": "content_filter"]]], .responsesIncomplete, .contentFiltered),
            (["type": "error", "code": "insufficient_quota", "message": "PRIVATE_PROVIDER_BODY", "param": "PRIVATE_PARAM"], .responsesError, .quota),
            (["type": "error", "code": "rate_limit_exceeded"], .responsesError, .rateLimit),
            (["type": "response.refusal.done", "refusal": "PRIVATE_REFUSAL"], .responsesRefusal, .refusal),
            (["type": "error", "code": "PRIVATE_UNKNOWN_CODE", "message": "insufficient_quota PRIVATE_PROVIDER_BODY"], .responsesError, .unknown)
        ]
        for (object, expectedEvent, expectedReason) in cases {
            var parser = ResponsesStreamAccumulator()
            let data = try JSONSerialization.data(withJSONObject: object)
            do {
                _ = try parser.consume(line: "data: " + String(decoding: data, as: UTF8.self))
                XCTFail("Failure event must terminate parsing")
            } catch LLMClientError.providerStreamFailure(let failure) {
                XCTAssertEqual(failure.event, expectedEvent)
                XCTAssertEqual(failure.reason, expectedReason)
                let error = LLMClientError.providerStreamFailure(failure)
                for value in [error.userFacingMessage, error.safeDiagnosticCode, String(describing: error)] {
                    XCTAssertFalse(value.contains("PRIVATE"))
                }
            }
            XCTAssertFalse(parser.isCompleted)
        }
    }

    func testSSEProviderFailureKeepsExistingPreviewAndMakesOneHTTPRequest() async throws {
        let errors = [
            "data: {\"type\":\"error\",\"code\":\"insufficient_quota\",\"message\":\"PRIVATE_PROVIDER_BODY\"}\n\n",
            "data: {\"type\":\"response.incomplete\",\"response\":{\"incomplete_details\":{\"reason\":\"max_output_tokens\"}}}\n\n"
        ]
        for ending in errors {
            GLMStubURLProtocol.requestBodies = []
            let delta = try JSONSerialization.data(withJSONObject: [
                "type": "response.output_text.delta", "delta": "{\"body\":\"partial"
            ])
            GLMStubURLProtocol.responses = [.init(statusCode: 200,
                body: "data: " + String(decoding: delta, as: UTF8.self) + "\n\n" + ending),
                .init(statusCode: 200, body: responsesSSE())]
            let previews = Locked<[String]>([])
            var request = makeRequest()
            request.mentorExecutionPolicy = .responses
            request.mentorStreamProgress = MentorStreamProgress { token in previews.withLock { $0.append(token) } }
            do {
                _ = try await makeClient(configuration: responsesConfiguration()).complete(request)
                XCTFail("Incomplete output is not a successful response")
            } catch let error as LLMClientError {
                XCTAssertFalse(error.userFacingMessage.contains("PRIVATE"))
                XCTAssertNotEqual(error.safeDiagnosticCode, "provider_response_failed")
            }
            XCTAssertEqual(previews.withLock { $0.joined() }, "partial")
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    func testChatNonStopFinishReasonsCannotBeOverriddenByDone() async throws {
        for finish in ["length", "content_filter", "tool_calls"] {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [.init(statusCode: 200,
                body: "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"" + finish + "\"}]}\n\ndata: [DONE]\n\n")]
            var completed = false
            var text = ""
            do {
                for try await event in makeClient().stream(makeRequest()) {
                    if case .completed = event { completed = true }
                    if case .token(let token) = event { text += token }
                }
                XCTFail("Non-stop finish reason must fail")
            } catch LLMClientError.providerStreamFailure { }
            XCTAssertFalse(completed)
            XCTAssertEqual(text, "partial")
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    func testKnownQuotaFailureDoesNotRetryNonMentorCompleteOrStream() async throws {
        for streaming in [false, true] {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [.init(statusCode: 429,
                body: "{\"error\":{\"code\":\"insufficient_quota\",\"message\":\"PRIVATE_PROVIDER_BODY\"}}"),
                .init(statusCode: 200, body: "unused")]
            let client = makeClient(configuration: GLMClientConfiguration(
                baseURL: URL(string: "https://glm.test/api/paas/v4")!, retryBaseDelay: 0))
            do {
                if streaming { for try await _ in client.stream(makeRequest()) { } }
                else { _ = try await client.complete(makeRequest()) }
                XCTFail("Known quota error must return without retry")
            } catch let error as LLMClientError {
                XCTAssertEqual(error.safeDiagnosticCode, "http_429.quota")
                XCTAssertTrue(error.userFacingMessage.contains("额度"))
                XCTAssertFalse(error.userFacingMessage.contains("PRIVATE"))
            }
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    func testInsufficientBalanceIsDistinguishedFromOtherHTTP429Failures() throws {
        for code: Any in ["1113", 1113] {
            let data = try JSONSerialization.data(withJSONObject: ["error": ["code": code, "message": "provider diagnostic"]])
            let message = LLMClientError.httpStatus(429, data).userFacingMessage
            XCTAssertTrue(message.contains("余额不足"))
            XCTAssertTrue(message.contains("资源包"))
            XCTAssertFalse(message.contains("provider diagnostic"))
        }
        for body in [#"{"error":{"code":"1302","message":"provider diagnostic"}}"#, "not JSON"] {
            let message = LLMClientError.httpStatus(429, Data(body.utf8)).userFacingMessage
            XCTAssertFalse(message.contains("余额不足"))
            XCTAssertTrue(message.contains("限额"))
            XCTAssertFalse(message.contains("provider diagnostic"))
        }
        let serverMessage = LLMClientError.httpStatus(503, Data("internal diagnostic".utf8)).userFacingMessage
        XCTAssertTrue(serverMessage.contains("暂时不可用"))
        XCTAssertFalse(serverMessage.contains("internal diagnostic"))
    }

    override func tearDown() {
        GLMStubURLProtocol.responses = []
        GLMStubURLProtocol.requestBodies = []
        GLMStubURLProtocol.requestTimeouts = []
        GLMStubURLProtocol.responseDelays = []
        GLMStubURLProtocol.transportErrors = []
        GLMStubURLProtocol.hangs = false
        GLMStubURLProtocol.onStartLoading = nil
        GLMStubURLProtocol.onStopLoading = nil
        super.tearDown()
    }

    func testAuditedMentorChatStreamsPreviewAndRequiresExplicitCompletion() async throws {
        let raw = #"{"body":"逐步回应"}"#
        let delta = try JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": raw], "finish_reason": NSNull()]]])
        let packets = "data: " + String(decoding: delta, as: UTF8.self) + "\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n"
        let previews = Locked<[String]>([])
        var request = makeRequest(); request.mentorExecutionPolicy = .m1
        request.mentorStreamProgress = MentorStreamProgress { value in previews.withLock { $0.append(value) } }
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: packets)]
        _ = try await makeClient().complete(request)
        XCTAssertEqual(previews.value.last, "逐步回应")
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        XCTAssertTrue(GLMStubURLProtocol.requestBodies[0].contains(#""stream":true"#))
        XCTAssertEqual(GLMStubURLProtocol.requestTimeouts.first, 600)
        GLMStubURLProtocol.requestBodies = []
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: "data: " + String(decoding: delta, as: UTF8.self) + "\n")]
        do { _ = try await makeClient().complete(request); XCTFail("No completed marker") }
        catch { guard case LLMClientError.incompleteResponse = error else { return XCTFail("Unexpected error") } }
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testAuditedMentorResponsesPreviewDoesNotRetryProviderFailure() async throws {
        let previews = Locked<[String]>([])
        var request = makeRequest(); request.mentorExecutionPolicy = .responses
        request.mentorStreamProgress = MentorStreamProgress { value in previews.withLock { $0.append(value) } }
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: responsesSSE())]
        let data = try await makeClient(configuration: responsesConfiguration()).complete(request)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("choices"))
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        let firstBody = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
        let firstPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(firstBody.utf8)) as? [String: Any])
        XCTAssertEqual(firstPayload["max_output_tokens"] as? Int, 16_000)
        GLMStubURLProtocol.requestBodies = []
        GLMStubURLProtocol.responses = [.init(statusCode: 503, body: "busy"), .init(statusCode: 200, body: responsesSSE())]
        do { _ = try await makeClient(configuration: responsesConfiguration()).complete(request); XCTFail("No hidden retry") }
        catch { guard case LLMClientError.httpStatus(503, _) = error else { return XCTFail("Unexpected error") } }
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testExpiredForegroundBudgetNeverStartsHTTP() async throws {
        var request = makeRequest()
        request.mentorExecutionPolicy = .m1
        request.mentorStartedAt = ContinuousClock().now.advanced(by: .seconds(-31))
        do { _ = try await makeClient().complete(request); XCTFail("Expired preparation budget") }
        catch { XCTAssertEqual(error as? MentorRequestExecutionError, .timedOut) }
        XCTAssertTrue(GLMStubURLProtocol.requestBodies.isEmpty)
    }

    @MainActor
    func testMentorDeadlineCancelsActualURLSessionTask() async throws {
        try await verifyDeadlineCancelsStartedURLSession(configuration: GLMClientConfiguration(
            baseURL: URL(string: "https://glm.test/api/paas/v4")!))
    }

    func testMentorPolicyMakesExactlyOneHTTPAttemptForRecoverableErrors() async throws {
        for status in [429, 500, 503] {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [StubbedHTTPResponse(statusCode: status, body: "server busy"),
                StubbedHTTPResponse(statusCode: 200, body: #"{"choices":[{"message":{"content":"{}"}}]}"#)]
            var request = makeRequest(); request.mentorExecutionPolicy = .m1
            do { _ = try await makeClient().complete(request); XCTFail("Must return first error") }
            catch { guard case LLMClientError.httpStatus(let actual, _) = error else { return XCTFail("Unexpected error: \(error)") }; XCTAssertEqual(actual, status) }
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    func testMentorPolicyDoesNotRetryResponseFormatRejectionOrTransportError() async throws {
        GLMStubURLProtocol.responses = [StubbedHTTPResponse(statusCode: 400, body: #"{"error":"response_format is not supported"}"#)]
        var request = makeRequest(); request.mentorExecutionPolicy = .m1
        do { _ = try await makeClient().complete(request); XCTFail("Must not fallback") } catch {}
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        XCTAssertTrue(GLMStubURLProtocol.requestBodies[0].contains("response_format"))
        GLMStubURLProtocol.requestBodies = []
        GLMStubURLProtocol.transportErrors = [URLError(.networkConnectionLost)]
        do { _ = try await makeClient().complete(request); XCTFail("Must not retry transport failure") } catch {}
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testMentorSuccessUsesBoundedTimeoutAndRejectsStreamingBypass() async throws {
        GLMStubURLProtocol.responses = [StubbedHTTPResponse(statusCode: 200, body: #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#)]
        var request = makeRequest(); request.mentorExecutionPolicy = .m1
        let data = try await makeClient().complete(request)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("choices"))
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        XCTAssertEqual(GLMStubURLProtocol.requestTimeouts.first, 30)
        do {
            var iterator = makeClient().stream(request).makeAsyncIterator()
            _ = try await iterator.next()
            XCTFail("Mentor streaming is unavailable")
        } catch { XCTAssertEqual(error as? MentorRequestExecutionError, .unsupportedStreaming) }
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testMentorGLM53UsesLightweightReasoningOnOfficialEndpoints() async throws {
        for host in ["api.z.ai", "open.bigmodel.cn"] {
            for model in ["glm-5.3", "glm-5.3-flash"] {
                GLMStubURLProtocol.requestBodies = []
                GLMStubURLProtocol.responses = [StubbedHTTPResponse(statusCode: 200, body: #"{"choices":[{"message":{"content":"{}"}}]}"#)]
                var request = makeRequest()
                request.mentorExecutionPolicy = .m1
                _ = try await makeClient(configuration: GLMClientConfiguration(
                    baseURL: URL(string: "https://\(host)/api/paas/v4")!, model: model
                )).complete(request)

                XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
                let body = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
                XCTAssertEqual(payload["reasoning_effort"] as? String, "low")
                XCTAssertEqual(payload["max_tokens"] as? Int, 8_192)
                XCTAssertNil(payload["max_completion_tokens"])
                XCTAssertNil(payload["thinking"], "GLM-5.3 rejects disabled thinking")
                XCTAssertEqual(payload["stream"] as? Bool, false)
                XCTAssertEqual((payload["response_format"] as? [String: String])?["type"], "json_object")
                XCTAssertEqual(GLMStubURLProtocol.requestTimeouts.last, 30)
            }
        }
    }

    func testLightweightReasoningIsNotInjectedIntoOtherRequestContracts() async throws {
        let cases: [(String, String, Bool)] = [
            ("api.z.ai", "glm-5.3", false),
            ("api.z.ai", "glm-4.5-flash", true),
            ("api.z.ai", "another-model", true),
            ("custom.example", "glm-5.3", true)
        ]
        for (host, model, isMentor) in cases {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [StubbedHTTPResponse(statusCode: 200, body: #"{"choices":[{"message":{"content":"{}"}}]}"#)]
            var request = makeRequest()
            if isMentor { request.mentorExecutionPolicy = .m1 }
            _ = try await makeClient(configuration: GLMClientConfiguration(
                baseURL: URL(string: "https://\(host)/api/paas/v4")!, model: model
            )).complete(request)
            let body = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
            XCTAssertNil(payload["reasoning_effort"], "Unexpected extension for \(host)/\(model), mentor=\(isMentor)")
            XCTAssertNil(payload["thinking"])
        }
    }

    func testKnownOpenAIChatContractUsesMaxCompletionTokens() async throws {
        GLMStubURLProtocol.responses = [StubbedHTTPResponse(statusCode: 200, body: #"{"choices":[{"message":{"content":"{}"}}]}"#)]
        var request = makeRequest(); request.mentorExecutionPolicy = .m1
        _ = try await makeClient(configuration: GLMClientConfiguration(baseURL: URL(string: "https://api.openai.com/v1")!)).complete(request)
        let body = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
        XCTAssertEqual(payload["max_completion_tokens"] as? Int, 8_192)
        XCTAssertNil(payload["max_tokens"])
    }

    func testComplete_retriesWithoutResponseFormatWhenEndpointRejectsIt() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 400,
                body: #"{"error":"response_format is not supported"}"#
            ),
            StubbedHTTPResponse(
                statusCode: 200,
                body: #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
            )
        ]

        let client = makeClient()

        _ = try await client.complete(makeRequest())

        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 2)
        XCTAssertTrue(GLMStubURLProtocol.requestBodies[0].contains("response_format"))
        XCTAssertFalse(GLMStubURLProtocol.requestBodies[1].contains("response_format"))
    }

    func testComplete_keepsResponseFormatWhenEndpointAcceptsIt() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
            )
        ]

        let client = makeClient()

        _ = try await client.complete(makeRequest())

        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        XCTAssertTrue(GLMStubURLProtocol.requestBodies[0].contains("response_format"))
    }

    func testConfiguration_defaultTimeoutAllowsTenMinutesOfNoStreamProgress() {
        let configuration = GLMClientConfiguration()

        XCTAssertEqual(GLMClientConfiguration.defaultRequestTimeout, 10 * 60)
        XCTAssertEqual(configuration.requestTimeout, GLMClientConfiguration.defaultRequestTimeout)
    }

    func testConfiguration_normalizesBigModelAnthropicCodingPlanURLToOpenAICompatibleEndpoint() {
        let configuration = GLMClientConfiguration(
            baseURL: GLMClientConfiguration.normalizeBaseURL(
                URL(string: "https://open.bigmodel.cn/api/anthropic")!
            )
        )

        XCTAssertEqual(
            configuration.baseURL.absoluteString,
            "https://open.bigmodel.cn/api/coding/paas/v4"
        )
        XCTAssertEqual(
            configuration.endpoint.absoluteString,
            "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions"
        )
    }

    func testConfiguration_normalizesZAIAnthropicCodingPlanURLToOpenAICompatibleEndpoint() {
        let configuration = GLMClientConfiguration(
            baseURL: GLMClientConfiguration.normalizeBaseURL(
                URL(string: "https://api.z.ai/api/anthropic")!
            )
        )

        XCTAssertEqual(
            configuration.baseURL.absoluteString,
            "https://api.z.ai/api/coding/paas/v4"
        )
        XCTAssertEqual(
            configuration.endpoint.absoluteString,
            "https://api.z.ai/api/coding/paas/v4/chat/completions"
        )
    }

    func testComplete_retriesRecoverableRateLimitStatus() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 529,
                body: #"{"error":"temporarily overloaded"}"#
            ),
            StubbedHTTPResponse(
                statusCode: 429,
                body: #"{"error":"rate limit"}"#
            ),
            StubbedHTTPResponse(
                statusCode: 200,
                body: #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
            )
        ]

        let client = makeClient(
            configuration: GLMClientConfiguration(
                baseURL: URL(string: "https://glm.test/api/paas/v4")!,
                retryBaseDelay: 0
            )
        )

        _ = try await client.complete(makeRequest())

        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 3)
    }

    func testStream_retriesRecoverableRateLimitStatusBeforeYieldingTokens() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 529,
                body: #"{"error":"temporarily overloaded"}"#
            ),
            StubbedHTTPResponse(
                statusCode: 200,
                body: """
                data: {"choices":[{"delta":{"content":"<CARD>"}}]}

                data: [DONE]

                """
            )
        ]

        let client = makeClient(
            configuration: GLMClientConfiguration(
                baseURL: URL(string: "https://glm.test/api/paas/v4")!,
                retryBaseDelay: 0
            )
        )
        var tokens: [String] = []

        for try await event in client.stream(makeRequest()) {
            if case .token(let token) = event {
                tokens.append(token)
            }
        }

        XCTAssertEqual(tokens, ["<CARD>"])
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 2)
    }

    func testStream_retriesNetworkConnectionLostBeforeYieldingTokens() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: """
                data: {"choices":[{"delta":{"content":"<CARD>"}}]}

                data: [DONE]

                """
            )
        ]
        GLMStubURLProtocol.transportErrors = [URLError(.networkConnectionLost), nil]

        let client = makeClient(
            configuration: GLMClientConfiguration(
                baseURL: URL(string: "https://glm.test/api/paas/v4")!,
                retryBaseDelay: 0
            )
        )
        var tokens: [String] = []

        for try await event in client.stream(makeRequest()) {
            if case .token(let token) = event {
                tokens.append(token)
            }
        }

        XCTAssertEqual(tokens, ["<CARD>"])
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 2)
    }

    func testStream_sendsStreamTrueAndYieldsDeltaContent() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: """
                data: {"choices":[{"delta":{"content":"<CARD>"}}]}

                data: {"choices":[{"delta":{"content":"<TITLE>Test</TITLE>"}}]}

                data: [DONE]

                """
            )
        ]

        let client = makeClient()
        var tokens: [String] = []
        for try await event in client.stream(makeRequest()) {
            if case .token(let token) = event {
                tokens.append(token)
            }
        }

        XCTAssertEqual(tokens, ["<CARD>", "<TITLE>Test</TITLE>"])
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        XCTAssertTrue(GLMStubURLProtocol.requestBodies[0].contains(#""stream":true"#))
        XCTAssertFalse(GLMStubURLProtocol.requestBodies[0].contains("response_format"))
    }

    func testStream_reportsConnectionAndPacketProgressBeforeContent() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: """
                data: {"choices":[{"delta":{"reasoning_content":"internal planning"}}]}

                data: {"choices":[{"delta":{"content":"usable output"}}]}

                data: [DONE]

                """
            )
        ]

        let client = makeClient()
        var events: [LLMStreamEvent] = []
        for try await event in client.stream(makeRequest()) {
            events.append(event)
        }

        XCTAssertEqual(events, [
            .requestStarted,
            .connected,
            .receivedEvent,
            .receivedEvent,
            .token("usable output"),
            .completed
        ])
    }

    func testStream_appliesDefaultTenMinuteTimeoutToStreamingRequests() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: """
                data: {"choices":[{"delta":{"content":"<CARD>"}}]}

                data: [DONE]

                """
            )
        ]

        let client = makeClient()

        for try await _ in client.stream(makeRequest()) {}

        XCTAssertEqual(GLMStubURLProtocol.requestTimeouts, [GLMClientConfiguration.defaultRequestTimeout])
    }

    func testStream_allowsLongTotalDurationWhenTokensKeepArrivingBeforeIdleTimeout() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: """
                data: {"choices":[{"delta":{"content":"A"}}]}

                data: {"choices":[{"delta":{"content":"B"}}]}

                data: [DONE]

                """
            )
        ]
        GLMStubURLProtocol.responseDelays = [
            .milliseconds(0),
            .milliseconds(0),
            .milliseconds(80),
            .milliseconds(0),
            .milliseconds(80)
        ]

        let client = makeClient(
            configuration: GLMClientConfiguration(
                baseURL: URL(string: "https://glm.test/api/paas/v4")!,
                requestTimeout: 0.12
            )
        )

        var tokens: [String] = []
        for try await event in client.stream(makeRequest()) {
            if case .token(let token) = event {
                tokens.append(token)
            }
        }

        XCTAssertEqual(tokens, ["A", "B"])
    }

    func testComplete_prefersStructuredContextPayloadOverLegacyFlattenedPayload() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
            )
        ]
        let request = LLMRequest(
            prompt: PromptTemplate(
                id: .generateQuestions,
                version: "questions.test",
                systemText: "Return JSON only.",
                userText: "Return {\"ok\":true}.",
                outputSchemaVersion: 1
            ),
            inputSummary: "structured context test",
            contextPayload: PromptContextPayload(
                currentInput: .init(dailyEntryId: "entry-1", rawText: "raw evidence"),
                userChoice: .init(sessionMode: SessionMode.standard.rawValue, selectedLens: ThinkingLens.firstPrinciples.rawValue),
                cards: [
                    .init(
                        id: "card-1",
                        type: "assumption",
                        title: "Owner unclear",
                        body: "The meeting had no owner.",
                        priority: "high",
                        sensitivity: "normal",
                        isExcludedFromModel: false
                    )
                ],
                privacy: .init(rules: "Use structured evidence only.")
            )
        )

        _ = try await makeClient().complete(request)

        let body = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
        let userContent = try userMessageContent(from: body)
        XCTAssertTrue(userContent.contains(#""currentInput":{"dailyEntryId":"entry-1","rawText":"raw evidence"}"#))
        XCTAssertTrue(userContent.contains(#""cards":[{"body":"The meeting had no owner.""#))
        XCTAssertFalse(userContent.contains("purpose: legacy fallback only"))
    }

    func testComplete_withoutStructuredContextDoesNotRenderLegacyPayloadLines() async throws {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 200,
                body: #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
            )
        ]

        _ = try await makeClient().complete(makeRequest())

        let body = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
        let userContent = try userMessageContent(from: body)
        XCTAssertTrue(userContent.contains("Payload:\n{}"))
        XCTAssertFalse(userContent.contains("purpose: test"))
    }

    func testStream_preservesErrorBodyForNonSuccessStatus() async {
        GLMStubURLProtocol.responses = [
            StubbedHTTPResponse(
                statusCode: 401,
                body: #"{"error":"invalid api key"}"#
            )
        ]

        let client = makeClient()

        do {
            for try await _ in client.stream(makeRequest()) {}
            XCTFail("Expected stream to throw.")
        } catch LLMClientError.httpStatus(let status, let data) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"error":"invalid api key"}"#)
        } catch {
            XCTFail("Expected httpStatus, got \(error).")
        }
    }

    func testResponsesNormalizesEndpointAndPreservesCodexPath() {
        for raw in ["https://example.test/codex", "https://example.test/codex/responses/"] {
            let kind = GLMClientConfiguration.ProtocolKind.responses
            let config = GLMClientConfiguration(baseURL: GLMClientConfiguration.normalizeBaseURL(URL(string: raw)!, protocolKind: kind), protocolKind: kind)
            XCTAssertEqual(config.endpoint.absoluteString, "https://example.test/codex/responses")
        }
    }

    func testResponsesCompleteUsesFullPromptAndOnlyNormalizesFinalAssistantText() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: responsesSSE())]
        var request = makeRequest(); request.mentorExecutionPolicy = .responses
        let data = try await makeClient(configuration: responsesConfiguration()).complete(request)
        let normalized = try JSONDecoder().decode(GLMChatCompletionResponse.self, from: data)
        XCTAssertEqual(normalized.choices.first?.message?.content, "{\"ok\":true}")
        XCTAssertEqual(normalized.usage?.promptTokens, 12)
        XCTAssertEqual(normalized.usage?.completionTokens, 4)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        let body = try XCTUnwrap(GLMStubURLProtocol.requestBodies.first)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
        XCTAssertEqual(object["instructions"] as? String, request.prompt.systemText)
        let input = try XCTUnwrap(object["input"] as? [[String: String]])
        XCTAssertEqual(input.first?["role"], "user")
        XCTAssertTrue(input.first?["content"]?.contains(request.prompt.userText) == true)
        XCTAssertTrue(input.first?["content"]?.contains(request.inputSummary) == true)
        XCTAssertEqual(object["store"] as? Bool, false)
        XCTAssertEqual(object["stream"] as? Bool, true)
        for forbidden in ["messages", "temperature", "response_format", "reasoning_effort", "previous_response_id", "tools"] {
            XCTAssertNil(object[forbidden])
        }
        XCTAssertEqual(GLMStubURLProtocol.requestTimeouts.first, 120)
    }

    func testResponsesStreamingYieldsOnlyOutputTextAndRequiresCompletion() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: responsesSSE())]
        var tokens = ""; var completed = false
        for try await event in makeClient(configuration: responsesConfiguration()).stream(makeRequest()) {
            if case .token(let text) = event { tokens += text }
            if case .completed = event { completed = true }
        }
        XCTAssertEqual(tokens, "{\"ok\":true}")
        XCTAssertTrue(completed)
        XCTAssertFalse(tokens.contains("private reasoning"))
    }

    func testResponsesRejectsTruncatedStreamAndExplicitFailureWithoutRetry() async throws {
        for ending in ["", "data: [DONE]\n\n", "data: {\"type\":\"response.failed\",\"response\":{\"error\":{\"message\":\"provider private detail\"}}}\n\n", "data: {\"type\":\"response.incomplete\"}\n\n", "data: {\"type\":\"error\"}\n\n"] {
            GLMStubURLProtocol.requestBodies = []
            GLMStubURLProtocol.responses = [.init(statusCode: 200, body: "data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}\n\n" + ending)]
            var request = makeRequest(); request.mentorExecutionPolicy = .m1
            do { _ = try await makeClient(configuration: responsesConfiguration()).complete(request); XCTFail("Must reject partial/failure") }
            catch let error as LLMClientError { XCTAssertFalse(error.userFacingMessage.contains("provider private detail")) }
            XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        }
    }

    func testResponsesStreamingDoesNotMarkEOFAsCompleteOrRetryAfterOutput() async throws {
        GLMStubURLProtocol.responses = [.init(statusCode: 200, body: "data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}\n\n")]
        var completed = false
        do {
            for try await event in makeClient(configuration: responsesConfiguration()).stream(makeRequest()) {
                if case .completed = event { completed = true }
            }
            XCTFail("Expected incomplete response")
        } catch { guard case LLMClientError.incompleteResponse = error else { return XCTFail("Unexpected error") } }
        XCTAssertFalse(completed)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testResponsesRejectsEmptyToolRefusalAndMismatchedFinalOutput() throws {
        for item in [
            ["type": "function_call", "name": "run_shell"],
            ["type": "message", "role": "assistant", "status": "completed", "content": [["type": "refusal", "refusal": "No"]]],
            ["type": "message", "role": "assistant", "status": "completed", "content": [["type": "output_text", "text": "different"]]],
            ["type": "reasoning", "summary": [["type": "summary_text", "text": "private reasoning"]]]
        ] as [[String: Any]] {
            var parser = ResponsesStreamAccumulator()
            _ = try parser.consume(line: "data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}")
            let data = try JSONSerialization.data(withJSONObject: ["type": "response.completed", "response": ["status": "completed", "output": [item]]])
            XCTAssertThrowsError(try parser.consume(line: "data: " + String(decoding: data, as: UTF8.self)))
        }
    }

    func testResponsesAcceptsFinalOnlyOutputButRejectsFalseCompletion() throws {
        var parser = ResponsesStreamAccumulator()
        let line = try XCTUnwrap(responsesSSE().components(separatedBy: "\n").first { $0.contains("response.completed") })
        XCTAssertEqual(try parser.consume(line: line), "{\"ok\":true}")
        XCTAssertTrue(parser.isCompleted)
        for response in [["status": "incomplete", "output": []], ["status": "completed", "output": [], "error": ["message": "failure"]]] as [[String: Any]] {
            var failed = ResponsesStreamAccumulator()
            let data = try JSONSerialization.data(withJSONObject: ["type": "response.completed", "response": response])
            XCTAssertThrowsError(try failed.consume(line: "data: " + String(decoding: data, as: UTF8.self)))
        }
    }

    @MainActor
    func testResponsesMentorDeadlineCancelsUnderlyingTask() async throws {
        try await verifyDeadlineCancelsStartedURLSession(configuration: responsesConfiguration())
    }

    @MainActor
    private func verifyDeadlineCancelsStartedURLSession(configuration: GLMClientConfiguration) async throws {
        let clock = ControlledGLMExecutionClock()
        defer { clock.finish() }
        GLMStubURLProtocol.hangs = true
        let started = expectation(description: "URLSession started the request")
        let stopped = expectation(description: "URLSession stopped the started request")
        let accounted = expectation(description: "Cancelled transport remains accounted after foreground deadline")
        let observations = RecordingHTTPObservationStore(onFinish: { accounted.fulfill() })
        GLMStubURLProtocol.onStartLoading = { started.fulfill() }
        GLMStubURLProtocol.onStopLoading = { stopped.fulfill() }
        defer { GLMStubURLProtocol.onStartLoading = nil; GLMStubURLProtocol.onStopLoading = nil }
        let client = makeClient(configuration: configuration, mentorExecutor: clock.executor)
        var request = makeRequest()
        let policy = MentorRequestPolicy.forProtocol(configuration.protocolKind)
        request.mentorExecutionPolicy = policy
        request.mentorHTTPObservation = observationChannel(request, store: observations)
        let operation = Task { try await client.complete(request) }
        await fulfillment(of: [started], timeout: 10)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
        clock.advance(by: policy.deadline + .milliseconds(1))
        do { _ = try await operation.value; XCTFail("Expected deadline") }
        catch { XCTAssertEqual(error as? MentorRequestExecutionError, .timedOut) }
        await fulfillment(of: [stopped], timeout: 10)
        await fulfillment(of: [accounted], timeout: 10)
        let recorded = await observations.snapshot()
        XCTAssertEqual(recorded.identities.count, 1)
        XCTAssertEqual(recorded.outcomes, [.cancelled])
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
    }

    func testSwitchingProtocolKeepsLegacyGLMCredentialsSeparate() throws {
        let saved = KeychainAPIKeyStore(service: "mingsi.protocol-test." + UUID().uuidString)
        defer {
            for kind in GLMClientConfiguration.ProtocolKind.allCases {
                try? saved.saveProtocolKind(kind)
                try? saved.deleteAPIKey(); try? saved.deleteBaseURL(); try? saved.deleteModelName()
            }
        }
        XCTAssertEqual(try saved.loadProtocolKind(), .openAICompatible)
        try saved.saveAPIKey("glm-fixture-key")
        try saved.saveBaseURL("https://glm.test/v4")
        try saved.saveModelName("glm-fixture")
        try saved.saveProtocolKind(.responses)
        XCTAssertNil(try saved.loadAPIKey())
        XCTAssertThrowsError(try saved.loadClientConfiguration(), "Must not send a Responses key to the default GLM endpoint")
        try saved.saveAPIKey("responses-fixture-key")
        try saved.saveBaseURL("https://subscription.test/codex/responses")
        try saved.saveModelName("subscription-model")
        XCTAssertEqual(try saved.loadClientConfiguration().endpoint.absoluteString, "https://subscription.test/codex/responses")
        try saved.saveProtocolKind(.openAICompatible)
        XCTAssertEqual(try saved.loadAPIKey(), "glm-fixture-key")
        XCTAssertEqual(try saved.loadClientConfiguration().model, "glm-fixture")
        try saved.saveProtocolKind(.responses)
        XCTAssertEqual(try saved.loadAPIKey(), "responses-fixture-key")
        XCTAssertEqual(try saved.loadClientConfiguration().model, "subscription-model")
    }

    private func responsesConfiguration() -> GLMClientConfiguration {
        GLMClientConfiguration(baseURL: URL(string: "https://subscription.test/codex")!, model: "fixture-model", protocolKind: .responses, maxRetryAttempts: 0)
    }

    private func responsesSSE() -> String {
        #"""
        event: response.created
        data: {"type":"response.created"}

        data: {"type":"response.reasoning_summary_text.delta","delta":"private reasoning"}

        data: {"type":"response.output_text.delta","delta":"{\"ok\":true}"}

        data: {"type":"response.completed","response":{"id":"resp_fixture","model":"fixture-model","status":"completed","error":null,"output":[{"type":"reasoning","summary":[]},{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"{\"ok\":true}"}]}],"usage":{"input_tokens":12,"output_tokens":4,"total_tokens":16}}}

        """#
    }

    private func makeClient(
        configuration clientConfiguration: GLMClientConfiguration = GLMClientConfiguration(
            baseURL: URL(string: "https://glm.test/api/paas/v4")!
        ),
        mentorExecutor: MentorRequestExecutor = MentorRequestExecutor()
    ) -> DirectGLMClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GLMStubURLProtocol.self]

        return DirectGLMClient(
            apiKey: "test-key",
            configuration: clientConfiguration,
            session: URLSession(configuration: configuration),
            mentorExecutor: mentorExecutor
        )
    }

    private func makeRequest() -> LLMRequest {
        LLMRequest(
            prompt: PromptTemplate(
                id: .organizeCards,
                version: "test",
                systemText: "Return JSON only.",
                userText: "Return {\"ok\":true}.",
                outputSchemaVersion: 1
            ),
            inputSummary: "connection test",
            contextPayload: nil
        )
    }

    private func userMessageContent(from requestBody: String) throws -> String {
        let data = Data(requestBody.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let messages = try XCTUnwrap(object?["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.first { $0["role"] as? String == "user" })
        return try XCTUnwrap(userMessage["content"] as? String)
    }
}

private actor RecordingHTTPObservationStore: MentorHTTPObservationStore {
    private let rejectRegistration: Bool
    private let onFinish: @Sendable () -> Void
    private var identities: [MentorHTTPAttemptIdentity] = []
    private var kinds: [MentorHTTPProtocol] = []
    private var outcomes: [MentorHTTPAttemptOutcome] = []
    private var fields: [String?] = []
    private var budgets: [Int?] = []
    private var usages: [MentorServiceUsage] = []
    init(rejectRegistration: Bool = false, onFinish: @escaping @Sendable () -> Void = {}) {
        self.rejectRegistration = rejectRegistration; self.onFinish = onFinish
    }
    func beginAttempt(_ identity: MentorHTTPAttemptIdentity, protocolKind: MentorHTTPProtocol, at: Date,
                      outputBudgetField: String?, outputBudget: Int?) async throws {
        if rejectRegistration { throw MentorHTTPObservationError.unavailable }
        identities.append(identity); kinds.append(protocolKind)
        fields.append(outputBudgetField); budgets.append(outputBudget)
    }
    func recordMetrics(_ metrics: MentorHTTPMetrics, identity: MentorHTTPAttemptIdentity) async throws { }
    func recordServiceUsage(_ usage: MentorServiceUsage, identity: MentorHTTPAttemptIdentity) async throws {
        usages.append(usage)
    }
    func recordTiming(_ stage: MentorRequestTimingStage, elapsedMilliseconds: Int64, identity: MentorHTTPAttemptIdentity) async throws { }
    func finishAttempt(_ identity: MentorHTTPAttemptIdentity, outcome: MentorHTTPAttemptOutcome, elapsedMilliseconds: Int64) async throws {
        outcomes.append(outcome); onFinish()
    }
    func snapshot() -> (identities: [MentorHTTPAttemptIdentity], kinds: [MentorHTTPProtocol], outcomes: [MentorHTTPAttemptOutcome], fields: [String?], budgets: [Int?], usages: [MentorServiceUsage]) {
        (identities, kinds, outcomes, fields, budgets, usages)
    }
}

private struct StubbedHTTPResponse {
    let statusCode: Int
    let body: String
}

/// Time advances only after the test has observed actual URLProtocol startup.
/// All mutable state is protected by the mutex, including waiter installation.
private final class ControlledGLMExecutionClock: @unchecked Sendable {
    private struct Sleeper {
        let deadline: ContinuousClock.Instant
        let continuation: CheckedContinuation<Void, Error>
    }
    private struct State {
        var now = ContinuousClock.now
        var sleepers: [Sleeper] = []
        var finished = false
    }
    private let state = Mutex(State())

    var executor: MentorRequestExecutor {
        MentorRequestExecutor(now: { self.state.withLock { $0.now } }, sleepUntil: { deadline in
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.state.withLock { state in
                    if state.finished || Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                    else if deadline <= state.now { continuation.resume() }
                    else { state.sleepers.append(Sleeper(deadline: deadline, continuation: continuation)) }
                }
            }
            try Task.checkCancellation()
        })
    }

    func advance(by duration: Duration) {
        let ready = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let ready = state.sleepers.filter { $0.deadline <= state.now }
            state.sleepers.removeAll { $0.deadline <= state.now }
            return ready
        }
        ready.forEach { $0.continuation.resume() }
    }

    func finish() {
        let pending = state.withLock { state in
            state.finished = true
            let pending = state.sleepers
            state.sleepers.removeAll()
            return pending
        }
        pending.forEach { $0.continuation.resume(throwing: CancellationError()) }
    }
}

// URLSession owns the inherited request/client lifecycle. This stub adds no mutable
// instance state, and every shared fixture value is protected by the mutex below.
private final class GLMStubURLProtocol: URLProtocol, @unchecked Sendable {
    private struct State {
        var responses: [StubbedHTTPResponse] = []
        var requestBodies: [String] = []
        var requestTimeouts: [TimeInterval] = []
        var responseDelays: [Duration] = []
        var transportErrors: [URLError?] = []
        var hangs = false
        var onStartLoading: (@Sendable () -> Void)?
        var onStopLoading: (@Sendable () -> Void)?
    }

    private static let state = Mutex(State())
    static var responses: [StubbedHTTPResponse] {
        get { state.withLock { $0.responses } }
        set { state.withLock { $0.responses = newValue } }
    }
    static var requestBodies: [String] {
        get { state.withLock { $0.requestBodies } }
        set { state.withLock { $0.requestBodies = newValue } }
    }
    static var requestTimeouts: [TimeInterval] {
        get { state.withLock { $0.requestTimeouts } }
        set { state.withLock { $0.requestTimeouts = newValue } }
    }
    static var responseDelays: [Duration] {
        get { state.withLock { $0.responseDelays } }
        set { state.withLock { $0.responseDelays = newValue } }
    }
    static var transportErrors: [URLError?] {
        get { state.withLock { $0.transportErrors } }
        set { state.withLock { $0.transportErrors = newValue } }
    }
    static var hangs: Bool {
        get { state.withLock { $0.hangs } }
        set { state.withLock { $0.hangs = newValue } }
    }
    static var onStopLoading: (@Sendable () -> Void)? {
        get { state.withLock { $0.onStopLoading } }
        set { state.withLock { $0.onStopLoading = newValue } }
    }
    static var onStartLoading: (@Sendable () -> Void)? {
        get { state.withLock { $0.onStartLoading } }
        set { state.withLock { $0.onStartLoading = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = Self.bodyString(for: request)
        let delivery = Self.state.withLock { state in
            state.requestBodies.append(body)
            state.requestTimeouts.append(request.timeoutInterval)
            let requestIndex = state.requestBodies.count - 1
            let error = state.transportErrors.indices.contains(requestIndex) ? state.transportErrors[requestIndex] : nil
            let response = state.hangs || error != nil || state.responses.isEmpty
                ? StubbedHTTPResponse(statusCode: 500, body: #"{"error":"missing stub"}"#)
                : state.responses.removeFirst()
            return (hangs: state.hangs, error: error, response: response, delays: state.responseDelays)
        }
        Self.onStartLoading?()
        if delivery.hangs { return }
        if let error = delivery.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = delivery.response

        let url = request.url ?? URL(string: "https://glm.test")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let data = Data(response.body.utf8)

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        if response.body.contains("\n") {
            let lines = response.body.split(separator: "\n", omittingEmptySubsequences: false)
            Task {
                for (index, line) in lines.enumerated() {
                    if index < delivery.delays.count {
                        try? await Task.sleep(for: delivery.delays[index])
                    }
                    client?.urlProtocol(self, didLoad: Data("\(line)\n".utf8))
                }
                client?.urlProtocolDidFinishLoading(self)
            }
        } else {
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() { Self.onStopLoading?() }

    private static func bodyString(for request: URLRequest) -> String {
        if let body = request.httpBody {
            return String(decoding: body, as: UTF8.self)
        }

        guard let stream = request.httpBodyStream else { return "" }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: buffer.count)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else {
                break
            }
        }

        return String(decoding: data, as: UTF8.self)
    }
}
