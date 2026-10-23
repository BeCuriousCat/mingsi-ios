import Foundation
struct LocalPromptID { let rawValue = "isolated-cancellation" }
struct LocalPrompt {
 let id = LocalPromptID()
 let systemText = "synthetic"
 let userText = "synthetic"
 let version = "fixture"
 let outputSchemaVersion = "fixture"
}
struct LocalPayload { func renderedJSON() -> String { "{}" } }
struct LLMRequest {
 let traceID = UUID()
 let prompt = LocalPrompt()
 let inputSummary = "synthetic"
 var contextPayload: LocalPayload? = nil
 let contextVersion = 1
 var mentorExecutionPolicy: MentorRequestPolicy? = nil
 var mentorStartedAt: ContinuousClock.Instant? = nil
 var mentorStreamProgress: MentorStreamProgress? = nil
 var mentorHTTPObservation: MentorHTTPObservation? = nil
}
enum LLMClientError: Error {
    case missingAPIKey
    case invalidEndpoint
    case invalidResponse
    case incompleteResponse
    case providerResponseFailed
    case providerStreamFailure(ProviderStreamFailure)
    case httpStatus(Int, Data)
    case encodingFailed(Error)
    case transport(Error)
}

protocol LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data
}

enum LLMStreamEvent: Hashable {
    /// The request task started. It does not mean the remote endpoint has accepted it yet.
    case requestStarted
    /// HTTP headers arrived from a successful streaming response.
    case connected
    /// A non-terminal SSE data packet arrived, even when it has no displayable content.
    case receivedEvent
    case token(String)
    case completed
}

protocol StreamingLLMClient {
    func stream(_ request: LLMRequest, isolation: isolated (any Actor)?) -> AsyncThrowingStream<LLMStreamEvent, Error>
}

extension StreamingLLMClient {
    func stream(_ request: LLMRequest, caller: isolated (any Actor)? = #isolation) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        stream(request, isolation: caller)
    }
}

