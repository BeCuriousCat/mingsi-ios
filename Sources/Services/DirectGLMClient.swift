import Foundation

struct GLMClientConfiguration: Hashable {
    enum ProtocolKind: String, Hashable, CaseIterable {
        case openAICompatible
        case responses

        var displayTitle: String {
            switch self {
            case .openAICompatible: return "Chat Completions（GLM 等）"
            case .responses: return "Responses（Codex 订阅接口等）"
            }
        }
    }

    // This is an idle timeout: a stream may continue beyond ten minutes while it keeps delivering content.
    static let defaultRequestTimeout: TimeInterval = 10 * 60

    let baseURL: URL
    let model: String
    let temperature: Double
    let requestTimeout: TimeInterval
    let protocolKind: ProtocolKind
    let usesJSONResponseFormat: Bool
    let maxRetryAttempts: Int
    let retryBaseDelay: TimeInterval

    init(
        baseURL: URL = URL(string: "https://api.z.ai/api/paas/v4")!,
        model: String = "glm-4.5-flash",
        temperature: Double = 0.2,
        requestTimeout: TimeInterval = GLMClientConfiguration.defaultRequestTimeout,
        protocolKind: ProtocolKind = .openAICompatible,
        usesJSONResponseFormat: Bool = true,
        maxRetryAttempts: Int = 2,
        retryBaseDelay: TimeInterval = 1.5
    ) {
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.requestTimeout = requestTimeout
        self.protocolKind = protocolKind
        self.usesJSONResponseFormat = usesJSONResponseFormat
        self.maxRetryAttempts = max(0, maxRetryAttempts)
        self.retryBaseDelay = max(0, retryBaseDelay)
    }

    init(
        endpoint: URL,
        model: String = "glm-4.5-flash",
        temperature: Double = 0.2,
        requestTimeout: TimeInterval = GLMClientConfiguration.defaultRequestTimeout,
        protocolKind: ProtocolKind = .openAICompatible,
        usesJSONResponseFormat: Bool = true,
        maxRetryAttempts: Int = 2,
        retryBaseDelay: TimeInterval = 1.5
    ) {
        self.init(
            baseURL: Self.baseURL(from: endpoint, protocolKind: protocolKind),
            model: model,
            temperature: temperature,
            requestTimeout: requestTimeout,
            protocolKind: protocolKind,
            usesJSONResponseFormat: usesJSONResponseFormat,
            maxRetryAttempts: maxRetryAttempts,
            retryBaseDelay: retryBaseDelay
        )
    }

    var endpoint: URL {
        switch protocolKind {
        case .openAICompatible:
            return Self.endpoint(from: baseURL, pathSuffix: "chat/completions")
        case .responses:
            return Self.endpoint(from: Self.baseURL(from: baseURL, protocolKind: .responses), pathSuffix: "responses")
        }
    }

    static func normalizeBaseURL(_ url: URL, protocolKind: ProtocolKind = .openAICompatible) -> URL {
        baseURL(from: url, protocolKind: protocolKind)
    }

    private static func baseURL(from url: URL, protocolKind: ProtocolKind) -> URL {
        switch protocolKind {
        case .responses:
            let absolute = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return URL(string: absolute.hasSuffix("/responses") ? String(absolute.dropLast("/responses".count)) : absolute) ?? url
        case .openAICompatible:
            let suffixes = [
                "/chat/completions",
                "/chat/completion",
                "/completions"
            ]
            let absolute = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if absolute == "https://open.bigmodel.cn/api/anthropic" {
                return URL(string: "https://open.bigmodel.cn/api/coding/paas/v4") ?? url
            }
            if absolute == "https://api.z.ai/api/anthropic" {
                return URL(string: "https://api.z.ai/api/coding/paas/v4") ?? url
            }
            for suffix in suffixes where absolute.hasSuffix(suffix) {
                let base = String(absolute.dropLast(suffix.count))
                return URL(string: base) ?? url
            }
            return URL(string: absolute) ?? url
        }
    }

    private static func endpoint(from baseURL: URL, pathSuffix: String) -> URL {
        let absolute = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(absolute)/\(pathSuffix)") ?? baseURL
    }
}

final class DirectGLMClient: LLMClient, StreamingLLMClient {
    private let apiKey: String
    private let configuration: GLMClientConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let mentorExecutor: MentorRequestExecutor

    init(
        apiKey: String,
        configuration: GLMClientConfiguration = GLMClientConfiguration(),
        session: URLSession = .shared,
        mentorExecutor: MentorRequestExecutor = MentorRequestExecutor()
    ) {
        self.apiKey = apiKey
        self.configuration = configuration
        self.session = session
        self.mentorExecutor = mentorExecutor
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        if let policy = request.mentorExecutionPolicy {
            // Bypass both the recoverable-status loop and the response_format fallback.
            return try await mentorExecutor.execute({ [self] in
                try await send(request, usesJSONResponseFormat: configuration.usesJSONResponseFormat)
            }, policy: policy, startedAt: request.mentorStartedAt, progress: request.mentorStreamProgress).data
        }
        var lastError: Error?
        for attempt in 0...configuration.maxRetryAttempts {
            do {
                return try await completeAttempt(request)
            } catch LLMClientError.httpStatus(let status, let data)
                where Self.shouldRetryHTTPStatus(status: status, data: data) && attempt < configuration.maxRetryAttempts {
                lastError = LLMClientError.httpStatus(status, data)
                try await sleepBeforeRetry(attempt: attempt)
            } catch LLMClientError.transport(let error)
                where Self.shouldRetryRecoverableTransport(error) && attempt < configuration.maxRetryAttempts {
                lastError = LLMClientError.transport(error)
                try await sleepBeforeRetry(attempt: attempt)
            } catch {
                throw error
            }
        }
        throw lastError ?? LLMClientError.invalidResponse
    }

    private func completeAttempt(_ request: LLMRequest) async throws -> Data {
        do {
            return try await send(request, usesJSONResponseFormat: configuration.usesJSONResponseFormat)
        } catch LLMClientError.httpStatus(let status, let data)
            where configuration.protocolKind == .openAICompatible && configuration.usesJSONResponseFormat && Self.shouldRetryWithoutJSONResponseFormat(status: status, data: data) {
            return try await send(request, usesJSONResponseFormat: false)
        }
    }

    private func send(_ request: LLMRequest, usesJSONResponseFormat: Bool) async throws -> Data {
        if request.mentorStreamProgress != nil { return try await sendMentorStream(request) }
        if configuration.protocolKind == .responses {
            return try await sendResponses(request)
        }
        var urlRequest = try makeURLRequest(
            request,
            usesJSONResponseFormat: usesJSONResponseFormat,
            stream: false
        )
        if let policy = request.mentorExecutionPolicy {
            let components = policy.deadline.components
            let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
            urlRequest.timeoutInterval = min(configuration.requestTimeout, seconds)
        } else {
            urlRequest.timeoutInterval = configuration.requestTimeout
        }


        return try await observeMentorHTTP(request) { delegate in
            do {
                let (data, response) = try await session.data(for: urlRequest, delegate: delegate)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LLMClientError.invalidResponse
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw LLMClientError.httpStatus(httpResponse.statusCode, data)
                }

                return data
            } catch let error as LLMClientError {
                throw error
            } catch {
                throw LLMClientError.transport(error)
            }
        }
    }

    func stream(_ request: LLMRequest, isolation: isolated (any Actor)?) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        guard request.mentorExecutionPolicy == nil else {
            return AsyncThrowingStream { $0.finish(throwing: MentorRequestExecutionError.unsupportedStreaming) }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                _ = isolation
                do {
                    try await streamAttemptingRetries(request, continuation: continuation)
                } catch let error as LLMClientError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMClientError.transport(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func streamAttemptingRetries(
        _ request: LLMRequest,
        continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation
    ) async throws {
        for attempt in 0...configuration.maxRetryAttempts {
            var hasReceivedStreamEvent = false
            do {
                continuation.yield(.requestStarted)
                var urlRequest = try makeURLRequest(
                    request,
                    usesJSONResponseFormat: false,
                    stream: true
                )
                urlRequest.timeoutInterval = configuration.requestTimeout
                let (bytes, response) = try await session.bytes(for: urlRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LLMClientError.invalidResponse
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    let data = try await Self.collectStreamErrorBody(from: bytes)
                    if Self.shouldRetryHTTPStatus(status: httpResponse.statusCode, data: data),
                       attempt < configuration.maxRetryAttempts {
                        try await sleepBeforeRetry(attempt: attempt)
                        continue
                    }
                    throw LLMClientError.httpStatus(httpResponse.statusCode, data)
                }
                continuation.yield(.connected)

                let lineIterator = AsyncIteratorBox(bytes.lines.makeAsyncIterator())
                var responses = ResponsesStreamAccumulator()
                var chat = ChatStreamAccumulator(requiresStopReason: false)
                while let line = try await nextLineWithIdleTimeout(from: lineIterator) {
                    try Task.checkCancellation()
                    if Self.isNonTerminalSSEDataLine(line) {
                        hasReceivedStreamEvent = true
                        continuation.yield(.receivedEvent)
                    }
                    if configuration.protocolKind == .responses {
                        let token = try responses.consume(line: line)
                        if let token { continuation.yield(.token(token)) }
                        if responses.isCompleted {
                            continuation.yield(.completed)
                            continuation.finish()
                            return
                        }
                        continue
                    }
                    if let token = try chat.consume(line: line) { continuation.yield(.token(token)) }
                    if chat.isCompleted {
                        continuation.yield(.completed)
                        continuation.finish()
                        return
                    }
                }
                throw LLMClientError.incompleteResponse
            } catch LLMClientError.transport(let error)
                where !hasReceivedStreamEvent && Self.shouldRetryRecoverableTransport(error) && attempt < configuration.maxRetryAttempts {
                try await sleepBeforeRetry(attempt: attempt)
                continue
            } catch let error as LLMClientError {
                throw error
            } catch {
                if !hasReceivedStreamEvent && Self.shouldRetryRecoverableTransport(error) && attempt < configuration.maxRetryAttempts {
                    try await sleepBeforeRetry(attempt: attempt)
                    continue
                }
                throw LLMClientError.transport(error)
            }
        }

        throw LLMClientError.invalidResponse
    }

    private func makeURLRequest(
        _ request: LLMRequest,
        usesJSONResponseFormat: Bool,
        stream: Bool
    ) throws -> URLRequest {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw LLMClientError.missingAPIKey
        }

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("MingSi/1.0", forHTTPHeaderField: "User-Agent")
        if stream || configuration.protocolKind == .responses {
            urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }

        do {
            if configuration.protocolKind == .responses {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
                    "model": configuration.model,
                    "instructions": request.prompt.systemText,
                    "input": [["role": "user", "content": GLMChatCompletionRequest.userContent(for: request)]],
                    "store": false,
                    "stream": true
                ])
                return urlRequest
            }
            urlRequest.httpBody = try encoder.encode(
                GLMChatCompletionRequest(
                    request,
                    model: configuration.model,
                    temperature: configuration.temperature,
                    stream: stream,
                    usesJSONResponseFormat: usesJSONResponseFormat,
                    reasoningEffort: mentorReasoningEffort(for: request)
                )
            )
        } catch {
            throw LLMClientError.encodingFailed(error)
        }
        return urlRequest
    }

    /// One audited request. Never restart a partially received answer or persist a
    /// preview as a completed response. Final content still goes through the parser.
    private func sendMentorStream(_ request: LLMRequest) async throws -> Data {
        let urlRequest = try makeURLRequest(request, usesJSONResponseFormat: false, stream: true)
        return try await observeMentorHTTP(request) { delegate in
            do {
                let (bytes, response) = try await session.bytes(for: urlRequest, delegate: delegate)
                defer { bytes.task.cancel() }
                guard let http = response as? HTTPURLResponse else { throw LLMClientError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    throw LLMClientError.httpStatus(http.statusCode, try await Self.collectStreamErrorBody(from: bytes))
                }
                var responses = ResponsesStreamAccumulator()
                var chat = ChatStreamAccumulator(requiresStopReason: true)
                for try await line in bytes.lines {
                    try Task.checkCancellation()
                    if configuration.protocolKind == .responses {
                        if let token = try responses.consume(line: line) { try request.mentorStreamProgress?.receive(token) }
                        if responses.isCompleted { return try responses.normalizedResponse() }
                        continue
                    }
                    if let token = try chat.consume(line: line) { try request.mentorStreamProgress?.receive(token) }
                    if chat.isCompleted {
                        return try JSONSerialization.data(withJSONObject: ["choices": [[
                            "message": ["role": "assistant", "content": chat.text], "finish_reason": "stop"]]])
                    }
                }
                throw LLMClientError.incompleteResponse
            } catch let error as LLMClientError { throw error }
            catch is CancellationError { throw CancellationError() }
            catch { throw LLMClientError.transport(error) }
        }
    }

    /// Responses providers may require SSE even for a logically complete request.
    /// Keep this within the existing mentor executor's single request/deadline.
    private func sendResponses(_ request: LLMRequest) async throws -> Data {
        var urlRequest = try makeURLRequest(request, usesJSONResponseFormat: false, stream: true)
        if let policy = request.mentorExecutionPolicy {
            let components = policy.deadline.components
            urlRequest.timeoutInterval = min(configuration.requestTimeout,
                Double(components.seconds) + Double(components.attoseconds) / 1e18)
        }
        return try await observeMentorHTTP(request) { delegate in
            do {
                let (bytes, response) = try await session.bytes(for: urlRequest, delegate: delegate)
                defer { bytes.task.cancel() }
                guard let http = response as? HTTPURLResponse else { throw LLMClientError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    throw LLMClientError.httpStatus(http.statusCode, try await Self.collectStreamErrorBody(from: bytes))
                }
                let iterator = AsyncIteratorBox(bytes.lines.makeAsyncIterator())
                var accumulator = ResponsesStreamAccumulator()
                while let line = try await nextLineWithIdleTimeout(from: iterator) {
                    try Task.checkCancellation()
                    _ = try accumulator.consume(line: line)
                    if accumulator.isCompleted { return try accumulator.normalizedResponse() }
                }
                throw LLMClientError.incompleteResponse
            } catch let error as LLMClientError {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw LLMClientError.transport(error)
            }
        }
    }

    private func observeMentorHTTP(
        _ request: LLMRequest,
        operation: (MentorHTTPMetricsDelegate?) async throws -> Data
    ) async throws -> Data {
        let kind: MentorHTTPProtocol = configuration.protocolKind == .responses ? .responses : .openAICompatible
        let attempt = try await request.mentorHTTPObservation?.beginAttempt(protocolKind: kind)
        let result: Result<Data, Error>
        do {
            try Task.checkCancellation()
            result = .success(try await operation(attempt?.delegate))
        } catch { result = .failure(error) }
        switch result {
        case .success(let data):
            try await attempt?.finish(.returnedData)
            return data
        case .failure(let error):
            let cancelled = Task.isCancelled || error is CancellationError ||
                (error as? URLError)?.code == .cancelled || {
                    if case LLMClientError.transport(let underlying) = error {
                        return (underlying as? URLError)?.code == .cancelled
                    }
                    return false
                }()
            try await attempt?.finish(cancelled ? .cancelled : .failed)
            throw error
        }
    }

    private func mentorReasoningEffort(for request: LLMRequest) -> String? {
        // GLM-5.3 always reasons and defaults to "max". Its documented "low"
        // setting fits the mentor's 30-second foreground budget without sending
        // the unsupported thinking.type=disabled. Limit this provider extension
        // to the official endpoints and models whose contract is verified.
        // https://docs.z.ai/guides/llm/glm-5.3
        guard request.mentorExecutionPolicy != nil,
              ["api.z.ai", "open.bigmodel.cn"].contains(configuration.baseURL.host?.lowercased() ?? ""),
              ["glm-5.3", "glm-5.3-flash"].contains(configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
            return nil
        }
        return "low"
    }

    private static func shouldRetryWithoutJSONResponseFormat(status: Int, data: Data) -> Bool {
        guard status == 400 || status == 422 else { return false }
        let body = String(decoding: data, as: UTF8.self).lowercased()
        return body.contains("response_format") || body.contains("response format")
    }

    private static func shouldRetryRecoverableStatus(status: Int) -> Bool {
        status == 429 || status == 529 || status == 500 || status == 502 || status == 503 || status == 504
    }

    private static func shouldRetryRecoverableTransport(_ error: Error) -> Bool {
        let code: URLError.Code?
        if let urlError = error as? URLError {
            code = urlError.code
        } else {
            let nsError = error as NSError
            code = nsError.domain == NSURLErrorDomain
                ? URLError.Code(rawValue: nsError.code)
                : nil
        }

        switch code {
        case .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let delay = configuration.retryBaseDelay * pow(2, Double(attempt))
        guard delay > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func nextLineWithIdleTimeout<I>(
        from iterator: AsyncIteratorBox<I>
    ) async throws -> String? where I: AsyncIteratorProtocol & SendableMetatype, I.Element == String {
        let idleTimeout = configuration.requestTimeout
        guard idleTimeout > 0 else {
            return try await iterator.next()
        }

        return try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                try await iterator.next()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(idleTimeout * 1_000_000_000))
                throw LLMClientError.transport(URLError(.timedOut))
            }

            let result = try await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }

    private static func shouldRetryHTTPStatus(status: Int, data: Data) -> Bool {
        let details = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let reason = ProviderStreamFailure.classify(details?["error"] as? [String: Any] ?? [:])
        guard ![.quota, .authentication, .contextLimit].contains(reason) else { return false }
        return shouldRetryRecoverableStatus(status: status)
    }

    private static func isNonTerminalSSEDataLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return false }
        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        return !payload.isEmpty && payload != "[DONE]"
    }

    private static func collectStreamErrorBody(
        from bytes: URLSession.AsyncBytes
    ) async throws -> Data {
        var body = Data()
        for try await byte in bytes {
            body.append(byte)
        }
        return body
    }
}

private final class AsyncIteratorBox<I: AsyncIteratorProtocol>: @unchecked Sendable {
    private var iterator: I

    init(_ iterator: I) {
        self.iterator = iterator
    }

    func next() async throws -> I.Element? {
        try await iterator.next()
    }
}

/// Only typed, allowlisted metadata survives parsing. Provider messages, params,
/// request IDs, unknown codes and refusal text are never retained in this error.
struct ProviderStreamFailure: Equatable, Sendable {
    enum Event: String, Sendable {
        case responsesFailed = "responses_failed", responsesIncomplete = "responses_incomplete"
        case responsesError = "responses_error", responsesRefusal = "responses_refusal"
        case chatError = "chat_error", chatFinish = "chat_finish", chatUnsupported = "chat_unsupported"
    }
    enum Reason: String, Sendable {
        case quota, rateLimit = "rate_limit", authentication, unavailable
        case contextLimit = "context_limit", outputLimit = "output_limit"
        case contentFiltered = "content_filtered", refusal, unsupportedOutput = "unsupported_output", unknown
    }
    let event: Event
    let reason: Reason
    var diagnosticCode: String { event.rawValue + "." + reason.rawValue }

    static func classify(_ details: [String: Any]) -> Reason {
        // Match protocol codes, never human-readable message text. Unknown or
        // malformed values remain unknown, even when their text mentions quota.
        for field in ["code", "type"] {
            let value = details[field] as? String ?? (details[field] as? NSNumber)?.stringValue
            switch value {
            case "insufficient_quota", "billing_hard_limit_reached", "1113": return .quota
            case "rate_limit_exceeded", "1302": return .rateLimit
            case "invalid_api_key", "authentication_error", "permission_denied": return .authentication
            case "server_error", "service_unavailable", "overloaded_error": return .unavailable
            case "context_length_exceeded", "context_window_exceeded": return .contextLimit
            default: continue
            }
        }
        return .unknown
    }
}

/// [DONE] is an explicit terminal signal. EOF, error payloads and non-stop
/// finish reasons must not turn a partially rendered answer into success.
struct ChatStreamAccumulator {
    let requiresStopReason: Bool
    private(set) var text = ""
    private(set) var isCompleted = false
    private var sawStop = false

    init(requiresStopReason: Bool) { self.requiresStopReason = requiresStopReason }

    mutating func consume(line: String) throws -> String? {
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }
        if payload == "[DONE]" {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !requiresStopReason || sawStop else { throw LLMClientError.incompleteResponse }
            isCompleted = true
            return nil
        }
        guard let object = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any] else {
            throw LLMClientError.invalidResponse
        }
        if let error = object["error"], !(error is NSNull) {
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .chatError,
                reason: ProviderStreamFailure.classify(error as? [String: Any] ?? [:])))
        }
        guard let choices = object["choices"] as? [[String: Any]], choices.count <= 1 else {
            throw LLMClientError.invalidResponse
        }
        guard let choice = choices.first else { return nil } // usage-only event
        guard !sawStop else { throw LLMClientError.incompleteResponse }
        let delta = choice["delta"] as? [String: Any] ?? [:]
        if delta["refusal"] is String {
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .chatUnsupported, reason: .refusal))
        }
        if ["tool_calls", "function_call"].contains(where: { delta[$0] != nil && !(delta[$0] is NSNull) }) {
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .chatUnsupported, reason: .unsupportedOutput))
        }
        if let finish = choice["finish_reason"] as? String {
            if finish == "stop" { sawStop = true }
            else {
                let reason: ProviderStreamFailure.Reason
                switch finish {
                case "length": reason = .outputLimit
                case "content_filter": reason = .contentFiltered
                case "tool_calls", "function_call": reason = .unsupportedOutput
                default: reason = .unknown
                }
                throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .chatFinish, reason: reason))
            }
        }
        guard let content = delta["content"] as? String, !content.isEmpty else { return nil }
        text += content
        return content
    }
}

/// Only assistant output_text is product content. Reasoning, tool calls and
/// partial output must never masquerade as a successfully completed response.
struct ResponsesStreamAccumulator {
    private(set) var isCompleted = false
    private(set) var text = ""
    private var responseID: String?
    private var model: String?
    private var usage: [String: Int] = [:]

    mutating func consume(line: String) throws -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }
        guard payload != "[DONE]" else {
            if !isCompleted { throw LLMClientError.incompleteResponse }
            return nil
        }
        guard let object = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
              let type = object["type"] as? String else { throw LLMClientError.invalidResponse }
        switch type {
        case "response.failed":
            let response = object["response"] as? [String: Any]
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .responsesFailed,
                reason: ProviderStreamFailure.classify(response?["error"] as? [String: Any] ?? [:])))
        case "response.incomplete":
            let response = object["response"] as? [String: Any]
            let details = response?["incomplete_details"] as? [String: Any]
            let reason: ProviderStreamFailure.Reason
            switch details?["reason"] as? String {
            case "max_output_tokens": reason = .outputLimit
            case "content_filter": reason = .contentFiltered
            default: reason = .unknown
            }
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .responsesIncomplete, reason: reason))
        case "error":
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .responsesError,
                reason: ProviderStreamFailure.classify(object["error"] as? [String: Any] ?? object)))
        case "response.refusal.delta", "response.refusal.done":
            throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .responsesRefusal, reason: .refusal))
        case "response.output_text.delta":
            guard let delta = object["delta"] as? String else { throw LLMClientError.invalidResponse }
            text += delta
            return delta.isEmpty ? nil : delta
        case "response.completed":
            guard let response = object["response"] as? [String: Any],
                  response["status"] as? String == "completed",
                  response["error"] == nil || response["error"] is NSNull,
                  let output = response["output"] as? [[String: Any]] else {
                throw LLMClientError.incompleteResponse
            }
            var finalText = ""
            for item in output {
                // Unknown output and tool requests cannot be silently dropped.
                guard let kind = item["type"] as? String else { throw LLMClientError.invalidResponse }
                if kind == "reasoning" { continue }
                guard kind == "message", item["role"] as? String == "assistant",
                      item["status"] as? String == "completed",
                      let content = item["content"] as? [[String: Any]] else { throw LLMClientError.invalidResponse }
                for part in content {
                    if part["type"] as? String == "refusal" {
                        throw LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .responsesRefusal, reason: .refusal))
                    }
                    guard part["type"] as? String == "output_text",
                          let value = part["text"] as? String else { throw LLMClientError.providerResponseFailed }
                    finalText += value
                }
            }
            guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.isEmpty || text == finalText else { throw LLMClientError.incompleteResponse }
            let remaining = text.isEmpty ? finalText : nil
            text = finalText
            responseID = response["id"] as? String
            model = response["model"] as? String
            if let values = response["usage"] as? [String: Any] {
                for (source, target) in [("input_tokens", "prompt_tokens"), ("output_tokens", "completion_tokens"), ("total_tokens", "total_tokens")] {
                    if let value = values[source] as? Int { usage[target] = value }
                }
            }
            isCompleted = true
            return remaining
        default:
            return nil
        }
    }

    func normalizedResponse() throws -> Data {
        guard isCompleted else { throw LLMClientError.incompleteResponse }
        var result: [String: Any] = [
            "choices": [["index": 0, "message": ["role": "assistant", "content": text], "finish_reason": "stop"]],
            "usage": usage
        ]
        if let responseID { result["id"] = responseID }
        if let model { result["model"] = model }
        return try JSONSerialization.data(withJSONObject: result)
    }
}

private struct GLMChatCompletionRequest: Encodable {
    let model: String
    let messages: [GLMChatMessage]
    let temperature: Double
    let stream: Bool
    let responseFormat: GLMResponseFormat?
    let reasoningEffort: String?

    init(
        _ request: LLMRequest,
        model: String,
        temperature: Double,
        stream: Bool,
        usesJSONResponseFormat: Bool,
        reasoningEffort: String?
    ) {
        self.model = model
        self.messages = [
            GLMChatMessage(role: "system", content: request.prompt.systemText),
            GLMChatMessage(role: "user", content: Self.userContent(for: request))
        ]
        self.temperature = temperature
        self.stream = stream
        self.responseFormat = usesJSONResponseFormat && !stream ? GLMResponseFormat(type: "json_object") : nil
        self.reasoningEffort = reasoningEffort
    }

    static func userContent(for request: LLMRequest) -> String {
        let payloadText = request.contextPayload?.renderedJSON() ?? "{}"

        return """
        Prompt ID: \(request.prompt.id.rawValue)
        Prompt version: \(request.prompt.version)
        Context version: \(request.contextVersion)
        Output schema version: \(request.prompt.outputSchemaVersion)

        Task:
        \(request.prompt.userText)

        Input summary:
        \(request.inputSummary)

        Payload:
        \(payloadText.isEmpty ? "{}" : payloadText)
        """
    }
}

private struct GLMChatMessage: Encodable {
    let role: String
    let content: String
}

private struct GLMResponseFormat: Encodable {
    let type: String
}

struct GLMChatCompletionResponse: Decodable, Hashable {
    let id: String?
    let model: String?
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable, Hashable {
        let index: Int?
        let message: Message?
        let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable, Hashable {
        let role: String?
        let content: String?
    }

    struct Usage: Decodable, Hashable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

extension LLMClientError {
    /// Suitable for bounded acceptance records. Never returns provider text,
    /// unknown code strings, URLs, credentials or arbitrary NSError domains.
    var safeDiagnosticCode: String {
        switch self {
        case .providerStreamFailure(let failure): return failure.diagnosticCode
        case .httpStatus(let status, let data):
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let reason = ProviderStreamFailure.classify(object?["error"] as? [String: Any] ?? [:])
            return "http_" + ((100...599).contains(status) ? String(status) : "unknown") + "." + reason.rawValue
        case .incompleteResponse: return "incomplete_response"
        case .providerResponseFailed: return "provider_response_failed"
        case .missingAPIKey: return "missing_api_key"
        case .invalidEndpoint: return "invalid_endpoint"
        case .invalidResponse: return "invalid_response"
        case .encodingFailed: return "encoding_failed"
        case .transport(let error):
            let value = error as NSError
            return value.domain == NSURLErrorDomain ? "transport_url_" + String(value.code) : "transport_unknown"
        }
    }

    var userFacingMessage: String {
        switch self {
        case .missingAPIKey:
            return "缺少 API Key。"
        case .invalidEndpoint:
            return "API 地址无效。"
        case .invalidResponse:
            return "服务返回了无法识别的响应。"
        case .incompleteResponse:
            return "模型回复中断，尚未完整生成。原话会保留，请重新请求。"
        case .providerResponseFailed:
            return "模型未能完成这次回复。原话会保留，请稍后重试或检查模型权限与额度。"
        case .providerStreamFailure(let failure):
            switch failure.reason {
            case .quota:
                return "模型服务额度或计费受限。请检查账户余额、套餐与接口是否匹配，处理后再试。"
            case .rateLimit:
                return "模型服务暂时限制了请求频率，请稍后手动重试。"
            case .authentication:
                return "模型服务未授权。请检查 API Key、接口地址和模型权限。"
            case .unavailable:
                return "模型服务暂时不可用，请稍后重试。"
            case .contextLimit:
                return "材料超出模型上下文限制。请减少本次选用的材料后再试。"
            case .outputLimit:
                return "这次回复达到输出上限，尚未完整生成。可以缩短材料或缩小本次问题后重新请求。"
            case .contentFiltered:
                return "模型服务中止了这次输出。可以调整表达或结束交流。"
            case .refusal:
                return "模型没有提供这次回复。可以调整表达或结束交流。"
            case .unsupportedOutput:
                return "模型返回了当前不支持的输出，未保存为完整回复。请使用支持直接文字回复的配置。"
            case .unknown:
                return failure.event == .responsesIncomplete
                    ? "模型回复未完整生成。原话会保留，请检查已有预览后再决定是否重新请求。"
                    : "模型服务未能完成这次回复，原因尚不明确。原话会保留，请稍后重试或检查服务配置。"
            }
        case .httpStatus(let status, let data):
            if status == 429,
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let details = object["error"] as? [String: Any],
               let code = details["code"].map({ String(describing: $0) }), code == "1113" {
                return "模型服务余额不足或没有对应资源包。请检查账户余额、套餐与接口是否匹配，处理后再试。"
            }
            if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                let reason = ProviderStreamFailure.classify(object["error"] as? [String: Any] ?? [:])
                if reason == .quota || reason == .contextLimit {
                    return LLMClientError.providerStreamFailure(ProviderStreamFailure(event: .responsesError, reason: reason)).userFacingMessage
                }
            }
            switch status {
            case 401, 403:
                return "模型服务未授权（HTTP \(status)）。请检查 API Key、接口地址和模型权限。"
            case 429:
                return "模型服务暂时限制了请求（HTTP 429）。请检查账户限额或稍后再试。"
            case 500...599:
                return "模型服务暂时不可用（HTTP \(status)），请稍后再试。"
            default:
                return "模型服务拒绝了请求（HTTP \(status)）。请检查接口地址、模型名称和账户权限。"
            }
        case .encodingFailed:
            return "请求编码失败。"
        case .transport(let error):
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
                return "请求超时。较长时间没有收到新内容，请稍后重试或换用更快模型。"
            }
            if nsError.domain == NSURLErrorDomain, nsError.code == URLError.networkConnectionLost.rawValue {
                return "网络连接中断。若刚刚锁屏或切换应用，请回到明思前台后重试。"
            }
            if nsError.domain == NSURLErrorDomain, nsError.code == URLError.notConnectedToInternet.rawValue {
                return "当前没有网络连接。原话会保留，请连接网络后重试。"
            }
            return "网络请求未完成。请检查网络与接口地址后重试。"
        }
    }
}
