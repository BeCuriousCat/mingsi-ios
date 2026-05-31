import Foundation

struct GLMClientConfiguration: Hashable {
    let endpoint: URL
    let model: String
    let temperature: Double
    let requestTimeout: TimeInterval

    init(
        endpoint: URL = URL(string: "https://api.z.ai/api/paas/v4/chat/completions")!,
        model: String = "glm-4.5-flash",
        temperature: Double = 0.2,
        requestTimeout: TimeInterval = 60
    ) {
        self.endpoint = endpoint
        self.model = model
        self.temperature = temperature
        self.requestTimeout = requestTimeout
    }
}

final class DirectGLMClient: LLMClient {
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
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw LLMClientError.missingAPIKey
        }

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            urlRequest.httpBody = try encoder.encode(GLMChatCompletionRequest(request, model: configuration.model, temperature: configuration.temperature))
        } catch {
            throw LLMClientError.encodingFailed(error)
        }

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
}

private struct GLMChatCompletionRequest: Encodable {
    let model: String
    let messages: [GLMChatMessage]
    let temperature: Double
    let stream: Bool
    let responseFormat: GLMResponseFormat

    init(_ request: LLMRequest, model: String, temperature: Double) {
        self.model = model
        self.messages = [
            GLMChatMessage(role: "system", content: request.prompt.systemText),
            GLMChatMessage(role: "user", content: Self.userContent(for: request))
        ]
        self.temperature = temperature
        self.stream = false
        self.responseFormat = GLMResponseFormat(type: "json_object")
    }

    private static func userContent(for request: LLMRequest) -> String {
        let payloadLines = request.jsonPayload
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")

        return """
        Prompt ID: \(request.prompt.id.rawValue)
        Prompt version: \(request.prompt.version)
        Output schema version: \(request.prompt.outputSchemaVersion)

        Task:
        \(request.prompt.userText)

        Input summary:
        \(request.inputSummary)

        Payload:
        \(payloadLines.isEmpty ? "{}" : payloadLines)
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
