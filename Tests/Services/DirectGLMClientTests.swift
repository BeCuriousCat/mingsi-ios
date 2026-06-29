import XCTest
@testable import MingSi

final class DirectGLMClientTests: XCTestCase {

    override func tearDown() {
        GLMStubURLProtocol.responses = []
        GLMStubURLProtocol.requestBodies = []
        GLMStubURLProtocol.requestTimeouts = []
        super.tearDown()
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

    func testConfiguration_defaultTimeoutAllowsLongGLMResponses() {
        let configuration = GLMClientConfiguration()

        XCTAssertEqual(configuration.requestTimeout, 180)
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

    func testStream_keepsRequestTimeoutAsIdleTimeoutForDisconnectedStreams() async throws {
        GLMStubURLProtocol.responses = [
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
                requestTimeout: 180
            )
        )

        for try await _ in client.stream(makeRequest()) {}

        XCTAssertEqual(GLMStubURLProtocol.requestTimeouts, [180])
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

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestBodies.append(Self.bodyString(for: request))
        Self.requestTimeouts.append(request.timeoutInterval)

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
            for line in response.body.split(separator: "\n", omittingEmptySubsequences: false) {
                client?.urlProtocol(self, didLoad: Data("\(line)\n".utf8))
            }
        } else {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

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
