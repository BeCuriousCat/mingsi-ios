import XCTest
@testable import MingSi

final class DirectGLMClientTests: XCTestCase {

    override func tearDown() {
        GLMStubURLProtocol.responses = []
        GLMStubURLProtocol.requestBodies = []
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

    private func makeClient() -> DirectGLMClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GLMStubURLProtocol.self]

        return DirectGLMClient(
            apiKey: "test-key",
            configuration: GLMClientConfiguration(baseURL: URL(string: "https://glm.test/api/paas/v4")!),
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
            jsonPayload: ["purpose": "test"]
        )
    }
}

private struct StubbedHTTPResponse {
    let statusCode: Int
    let body: String
}

private final class GLMStubURLProtocol: URLProtocol {
    static var responses: [StubbedHTTPResponse] = []
    static var requestBodies: [String] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestBodies.append(Self.bodyString(for: request))

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
