import XCTest
@testable import MingSi

final class DirectGLMClientTests: XCTestCase {

    override func tearDown() {
        GLMStubURLProtocol.responses = []
        GLMStubURLProtocol.requestBodies = []
        GLMStubURLProtocol.requestTimeouts = []
        GLMStubURLProtocol.responseDelays = []
        GLMStubURLProtocol.transportErrors = []
        GLMStubURLProtocol.hangs = false
        GLMStubURLProtocol.onStopLoading = nil
        super.tearDown()
    }

    func testExpiredForegroundBudgetNeverStartsHTTP() async throws {
        var request = makeRequest()
        request.mentorExecutionPolicy = .m1
        request.mentorStartedAt = ContinuousClock().now.advanced(by: .seconds(-31))
        do { _ = try await makeClient().complete(request); XCTFail("Expired preparation budget") }
        catch { XCTAssertEqual(error as? MentorRequestExecutionError, .timedOut) }
        XCTAssertTrue(GLMStubURLProtocol.requestBodies.isEmpty)
    }

    func testMentorDeadlineCancelsActualURLSessionTask() async throws {
        GLMStubURLProtocol.hangs = true
        let stopped = expectation(description: "URLSession stopped the request")
        GLMStubURLProtocol.onStopLoading = { stopped.fulfill() }
        var request = makeRequest()
        request.mentorExecutionPolicy = MentorRequestPolicy(deadline: .milliseconds(100), waitingNoticeAfter: .milliseconds(10), maxHTTPAttempts: 1, allowsFormatFallback: false)
        do { _ = try await makeClient().complete(request); XCTFail("Expected total deadline") }
        catch { XCTAssertEqual(error as? MentorRequestExecutionError, .timedOut) }
        await fulfillment(of: [stopped], timeout: 1)
        XCTAssertEqual(GLMStubURLProtocol.requestBodies.count, 1)
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

    private func makeClient(
        configuration clientConfiguration: GLMClientConfiguration = GLMClientConfiguration(
            baseURL: URL(string: "https://glm.test/api/paas/v4")!
        )
    ) -> DirectGLMClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GLMStubURLProtocol.self]

        return DirectGLMClient(
            apiKey: "test-key",
            configuration: clientConfiguration,
            session: URLSession(configuration: configuration)
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

private struct StubbedHTTPResponse {
    let statusCode: Int
    let body: String
}

private final class GLMStubURLProtocol: URLProtocol {
    static var responses: [StubbedHTTPResponse] = []
    static var requestBodies: [String] = []
    static var requestTimeouts: [TimeInterval] = []
    static var responseDelays: [Duration] = []
    static var transportErrors: [URLError?] = []
    static var hangs = false
    static var onStopLoading: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestBodies.append(Self.bodyString(for: request))
        Self.requestTimeouts.append(request.timeoutInterval)
        if Self.hangs { return }

        let requestIndex = Self.requestBodies.count - 1
        if Self.transportErrors.indices.contains(requestIndex),
           let error = Self.transportErrors[requestIndex] {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = Self.responses.isEmpty
            ? StubbedHTTPResponse(statusCode: 500, body: #"{"error":"missing stub"}"#)
            : Self.responses.removeFirst()

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
                    if index < Self.responseDelays.count {
                        try? await Task.sleep(for: Self.responseDelays[index])
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
