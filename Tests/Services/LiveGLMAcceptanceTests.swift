import XCTest
@testable import MingSi

final class LiveGLMAcceptanceTests: XCTestCase {
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

    func testLiveGLMCompleteReturnsJSONWhenExplicitlyEnabled() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: ProcessInfo.processInfo.environment)

        guard harness.isEnabled else {
            throw XCTSkip("Set MINGSI_LIVE_GLM_ACCEPTANCE=1 and MINGSI_LIVE_GLM_API_KEY to run the live BYOK GLM acceptance test.")
        }

        let data = try await harness.runCompleteProbe()
        let response = try JSONDecoder().decode(GLMChatCompletionResponse.self, from: data)
        let content = try XCTUnwrap(response.choices.first?.message?.content)

        XCTAssertTrue(content.contains("ok"))
    }
}

private struct LiveGLMAcceptanceHarness {
    let environment: [String: String]
    var keychainAPIKey: () throws -> String? = {
        try KeychainAPIKeyStore().loadAPIKey()
    }

    var isEnabled: Bool {
        value("MINGSI_LIVE_GLM_ACCEPTANCE") == "1"
    }

    func runCompleteProbe() async throws -> Data {
        guard let apiKey = try resolvedAPIKey() else {
            throw XCTSkip("MINGSI_LIVE_GLM_API_KEY is not set, so the live BYOK GLM acceptance test was skipped.")
        }

        let client = DirectGLMClient(
            apiKey: apiKey,
            configuration: GLMClientConfiguration(
                baseURL: baseURL(),
                model: value("MINGSI_LIVE_GLM_MODEL") ?? GLMClientConfiguration().model,
                temperature: 0,
                requestTimeout: 60,
                maxRetryAttempts: 0,
                retryBaseDelay: 0
            )
        )

        return try await client.complete(Self.probeRequest)
    }

    func resolvedAPIKey() throws -> String? {
        if let environmentAPIKey = value("MINGSI_LIVE_GLM_API_KEY"), !environmentAPIKey.isEmpty {
            return environmentAPIKey
        }

        let keychainKey = try keychainAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return keychainKey?.isEmpty == false ? keychainKey : nil
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
}
