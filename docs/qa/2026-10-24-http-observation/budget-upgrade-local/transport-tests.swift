import XCTest
import Synchronization
@testable import MingSi

final class DirectGLMClientTests: XCTestCase {
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

    @MainActor
    func testMentorDeadlineCancelsActualURLSessionTask() async throws {
        try await verifyDeadlineCancelsStartedURLSession(configuration: GLMClientConfiguration(
            baseURL: URL(string: "https://glm.test/api/paas/v4")!))
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

    private func makeRequest() -> LLMRequest { LLMRequest() }
}
private actor RecordingHTTPObservationStore: MentorHTTPObservationStore {
    private let rejectRegistration: Bool
    private let onFinish: @Sendable () -> Void
    private var identities: [MentorHTTPAttemptIdentity] = []
    private var kinds: [MentorHTTPProtocol] = []
    private var outcomes: [MentorHTTPAttemptOutcome] = []
    private var fields: [String?] = []
    private var budgets: [Int?] = []
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
    func finishAttempt(_ identity: MentorHTTPAttemptIdentity, outcome: MentorHTTPAttemptOutcome, elapsedMilliseconds: Int64) async throws {
        outcomes.append(outcome); onFinish()
    }
    func snapshot() -> (identities: [MentorHTTPAttemptIdentity], kinds: [MentorHTTPProtocol], outcomes: [MentorHTTPAttemptOutcome], fields: [String?], budgets: [Int?]) {
        (identities, kinds, outcomes, fields, budgets)
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
