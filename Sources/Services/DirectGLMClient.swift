import Foundation

struct GLMClientConfiguration: Hashable {
    enum ProtocolKind: String, Hashable {
        case openAICompatible
    }

    let baseURL: URL
    let model: String
    let temperature: Double
    let requestTimeout: TimeInterval
    let protocolKind: ProtocolKind
    let usesJSONResponseFormat: Bool

    init(
        baseURL: URL = URL(string: "https://api.z.ai/api/paas/v4")!,
        model: String = "glm-4.5-flash",
        temperature: Double = 0.2,
        requestTimeout: TimeInterval = 180,
        protocolKind: ProtocolKind = .openAICompatible,
        usesJSONResponseFormat: Bool = true
    ) {
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.requestTimeout = requestTimeout
        self.protocolKind = protocolKind
        self.usesJSONResponseFormat = usesJSONResponseFormat
    }

    init(
        endpoint: URL,
        model: String = "glm-4.5-flash",
        temperature: Double = 0.2,
        requestTimeout: TimeInterval = 180,
        protocolKind: ProtocolKind = .openAICompatible,
        usesJSONResponseFormat: Bool = true
    ) {
        self.init(
            baseURL: Self.baseURL(from: endpoint, protocolKind: protocolKind),
            model: model,
            temperature: temperature,
            requestTimeout: requestTimeout,
            protocolKind: protocolKind,
            usesJSONResponseFormat: usesJSONResponseFormat
        )
    }

    var endpoint: URL {
        switch protocolKind {
        case .openAICompatible:
            return Self.endpoint(from: baseURL, pathSuffix: "chat/completions")
        }
    }

    static func normalizeBaseURL(_ url: URL, protocolKind: ProtocolKind = .openAICompatible) -> URL {
        baseURL(from: url, protocolKind: protocolKind)
    }

    private static func baseURL(from url: URL, protocolKind: ProtocolKind) -> URL {
        switch protocolKind {
        case .openAICompatible:
            let suffixes = [
                "/chat/completions",
                "/chat/completion",
                "/completions"
            ]
            let absolute = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
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

    init(
        apiKey: String,
        configuration: GLMClientConfiguration = GLMClientConfiguration(),
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.configuration = configuration
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        do {
            return try await send(request, usesJSONResponseFormat: configuration.usesJSONResponseFormat)
        } catch LLMClientError.httpStatus(let status, let data)
            where configuration.usesJSONResponseFormat && Self.shouldRetryWithoutJSONResponseFormat(status: status, data: data) {
            return try await send(request, usesJSONResponseFormat: false)
        }
    }

    private func send(_ request: LLMRequest, usesJSONResponseFormat: Bool) async throws -> Data {
        var urlRequest = try makeURLRequest(
            request,
            usesJSONResponseFormat: usesJSONResponseFormat,
            stream: false
        )
        urlRequest.timeoutInterval = configuration.requestTimeout


        do {
            let (data, response) = try await session.data(for: urlRequest)
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

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeURLRequest(
                        request,
                        usesJSONResponseFormat: false,
                        stream: true
                    )
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMClientError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw LLMClientError.httpStatus(
                            httpResponse.statusCode,
                            try await Self.collectStreamErrorBody(from: bytes)
                        )
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let event = Self.streamEvent(fromSSELine: line) else { continue }
                        continuation.yield(event)
                    }
                    continuation.yield(.completed)
                    continuation.finish()
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
        if stream {
            urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }

        do {
            urlRequest.httpBody = try encoder.encode(
                GLMChatCompletionRequest(
                    request,
                    model: configuration.model,
                    temperature: configuration.temperature,
                    stream: stream,
                    usesJSONResponseFormat: usesJSONResponseFormat
                )
            )
        } catch {
            throw LLMClientError.encodingFailed(error)
        }
        return urlRequest
    }

    private static func shouldRetryWithoutJSONResponseFormat(status: Int, data: Data) -> Bool {
        guard status == 400 || status == 422 else { return false }
        let body = String(decoding: data, as: UTF8.self).lowercased()
        return body.contains("response_format") || body.contains("response format")
    }

    private static func streamEvent(fromSSELine line: String) -> LLMStreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload != "[DONE]" else { return .completed }
        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(GLMChatCompletionStreamChunk.self, from: data)
        else { return nil }
        let content = chunk.choices.compactMap(\.delta.content).joined()
        return content.isEmpty ? nil : .token(content)
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

private struct GLMChatCompletionRequest: Encodable {
    let model: String
    let messages: [GLMChatMessage]
    let temperature: Double
    let stream: Bool
    let responseFormat: GLMResponseFormat?

    init(
        _ request: LLMRequest,
        model: String,
        temperature: Double,
        stream: Bool,
        usesJSONResponseFormat: Bool
    ) {
        self.model = model
        self.messages = [
            GLMChatMessage(role: "system", content: request.prompt.systemText),
            GLMChatMessage(role: "user", content: Self.userContent(for: request))
        ]
        self.temperature = temperature
        self.stream = stream
        self.responseFormat = usesJSONResponseFormat && !stream ? GLMResponseFormat(type: "json_object") : nil
    }

    private static func userContent(for request: LLMRequest) -> String {
        let payloadText = request.contextPayload?.renderedJSON() ?? legacyPayloadLines(for: request)

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

    private static func legacyPayloadLines(for request: LLMRequest) -> String {
        request.jsonPayload
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}

private struct GLMChatCompletionStreamChunk: Decodable, Hashable {
    let choices: [Choice]

    struct Choice: Decodable, Hashable {
        let delta: Delta
    }

    struct Delta: Decodable, Hashable {
        let content: String?
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
    var userFacingMessage: String {
        switch self {
        case .missingAPIKey:
            return "缺少 API Key。"
        case .invalidEndpoint:
            return "API 地址无效。"
        case .invalidResponse:
            return "服务返回了无法识别的响应。"
        case .httpStatus(let status, let data):
            let body = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let clipped = body.count > 220 ? "\(body.prefix(220))..." : body
            if clipped.isEmpty {
                return "HTTP \(status)。请检查 Base URL、模型名、Key 权限或额度。"
            }
            return "HTTP \(status)：\(clipped)"
        case .encodingFailed:
            return "请求编码失败。"
        case .transport(let error):
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
                return "请求超时。已等待较长时间仍未收到完整响应，请稍后重试或换用更快模型。"
            }
            return "网络请求失败：\(error.localizedDescription)"
        }
    }
}
