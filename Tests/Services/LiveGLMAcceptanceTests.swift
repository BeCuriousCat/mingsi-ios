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

    func testHarnessAcceptsStandardBYOKEnvironmentKeys() throws {
        let appKeyHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_GLM_API_KEY": " app-secret "
        ])
        let genericKeyHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "GLM_API_KEY": " generic-secret "
        ])
        let precedenceHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_API_KEY": " live-secret ",
            "MINGSI_GLM_API_KEY": " app-secret ",
            "GLM_API_KEY": " generic-secret "
        ])

        XCTAssertEqual(try appKeyHarness.resolvedAPIKey(), "app-secret")
        XCTAssertEqual(try genericKeyHarness.resolvedAPIKey(), "generic-secret")
        XCTAssertEqual(try precedenceHarness.resolvedAPIKey(), "live-secret")
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

    func testHarnessProbeUsesFiveMinuteRequestTimeout() {
        let harness = LiveGLMAcceptanceHarness(environment: [:])

        XCTAssertEqual(harness.requestTimeout, GLMClientConfiguration.defaultRequestTimeout)
    }

    func testLiveGLMCompleteReturnsJSONWhenExplicitlyEnabled() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: ProcessInfo.processInfo.environment)

        guard harness.isEnabled else {
            throw XCTSkip("Set MINGSI_LIVE_GLM_ACCEPTANCE=1 and one of MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, or GLM_API_KEY to run the live BYOK GLM acceptance test.")
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

    var requestTimeout: TimeInterval {
        GLMClientConfiguration().requestTimeout
    }

    var isEnabled: Bool {
        value("MINGSI_LIVE_GLM_ACCEPTANCE") == "1"
    }

    func runCompleteProbe() async throws -> Data {
        guard let apiKey = try resolvedAPIKey() else {
            throw XCTSkip("No live BYOK GLM API key is set; provide MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY, or a Keychain key to run this test.")
        }

        let client = DirectGLMClient(
            apiKey: apiKey,
            configuration: GLMClientConfiguration(
                baseURL: baseURL(),
                model: value("MINGSI_LIVE_GLM_MODEL") ?? GLMClientConfiguration().model,
                temperature: 0,
                requestTimeout: requestTimeout,
                maxRetryAttempts: 0,
                retryBaseDelay: 0
            )
        )

        return try await client.complete(Self.probeRequest)
    }

    func resolvedAPIKey() throws -> String? {
        for key in ["MINGSI_LIVE_GLM_API_KEY", "MINGSI_GLM_API_KEY", "GLM_API_KEY"] {
            if let environmentAPIKey = value(key), !environmentAPIKey.isEmpty {
                return environmentAPIKey
            }
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
