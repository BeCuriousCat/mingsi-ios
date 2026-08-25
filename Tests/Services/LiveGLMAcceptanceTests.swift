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

    func testHarnessProbeUsesTenMinuteRequestTimeout() {
        let harness = LiveGLMAcceptanceHarness(environment: [:])

        XCTAssertEqual(harness.requestTimeout, GLMClientConfiguration.defaultRequestTimeout)
    }

    func testCareerGoldenRequiresSeparateOptInAndExplicitBYOKKey() {
        let disabledHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_API_KEY": "secret"
        ])
        let keychainOnlyHarness = LiveGLMAcceptanceHarness(
            environment: [
                "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
                "MINGSI_LIVE_GLM_CAREER_GOLDEN": "1"
            ],
            keychainAPIKey: { "secret" }
        )
        let enabledHarness = LiveGLMAcceptanceHarness(environment: [
            "MINGSI_LIVE_GLM_ACCEPTANCE": "1",
            "MINGSI_LIVE_GLM_CAREER_GOLDEN": "1",
            "MINGSI_GLM_API_KEY": " explicit-secret "
        ])

        XCTAssertFalse(disabledHarness.isCareerGoldenEnabled)
        XCTAssertTrue(keychainOnlyHarness.isCareerGoldenEnabled)
        XCTAssertNil(keychainOnlyHarness.explicitBYOKAPIKey())
        XCTAssertEqual(enabledHarness.explicitBYOKAPIKey(), "explicit-secret")
    }

    func testCareerGoldenHarnessRunsThreeStructuredScenariosWithoutNetwork() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: [:])
        let client = CareerGoldenFixtureClient()

        let results = try await harness.runCareerGolden(with: client)

        XCTAssertEqual(results.map(\.caseID), [
            "career.student.synthesis.v1",
            "career.programmer.synthesis.v1",
            "career.finance.synthesis.v1"
        ])
        XCTAssertTrue(results.allSatisfy { $0.questions.count >= 1 && $0.denialViolations.isEmpty })
        XCTAssertEqual(client.requests.count, 3)
        XCTAssertTrue(client.requests.allSatisfy { $0.prompt.id == .generateQuestions })
        XCTAssertTrue(client.requests.allSatisfy { $0.prompt.version == LocalPromptProvider().template(for: .generateQuestions, mode: .standard).version })
        XCTAssertTrue(client.requests.allSatisfy { request in
            let rawText = request.contextPayload?.currentInput.rawText ?? ""
            return rawText.contains("职业标签仅作为情境") && rawText.contains("拒绝基于职业标签")
        })
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

    func testLiveGLMCareerGoldenQuestionsWhenExplicitlyEnabled() async throws {
        let harness = LiveGLMAcceptanceHarness(environment: ProcessInfo.processInfo.environment)

        guard harness.isCareerGoldenEnabled else {
            throw XCTSkip("Set MINGSI_LIVE_GLM_ACCEPTANCE=1, MINGSI_LIVE_GLM_CAREER_GOLDEN=1, and an explicit MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, or GLM_API_KEY to run the live BYOK GLM career golden test.")
        }
        guard harness.explicitBYOKAPIKey() != nil else {
            throw XCTSkip("The live career golden test requires an explicit BYOK environment key; Keychain-only configuration is intentionally skipped.")
        }

        let results = try await harness.runLiveCareerGolden()
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { !$0.questions.isEmpty && $0.denialViolations.isEmpty })
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

    var isCareerGoldenEnabled: Bool {
        isEnabled && value("MINGSI_LIVE_GLM_CAREER_GOLDEN") == "1"
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

    func explicitBYOKAPIKey() -> String? {
        for key in ["MINGSI_LIVE_GLM_API_KEY", "MINGSI_GLM_API_KEY", "GLM_API_KEY"] {
            if let environmentAPIKey = value(key), !environmentAPIKey.isEmpty {
                return environmentAPIKey
            }
        }
        return nil
    }

    func runLiveCareerGolden() async throws -> [LiveGLMCareerGoldenResult] {
        guard let apiKey = explicitBYOKAPIKey() else {
            throw XCTSkip("No explicit live BYOK GLM API key is set for the career golden test.")
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
        return try await runCareerGolden(with: client)
    }

    func runCareerGolden(with client: LLMClient) async throws -> [LiveGLMCareerGoldenResult] {
        let parser = TodayAIResponseParser()
        var results: [LiveGLMCareerGoldenResult] = []
        for scenario in Self.careerScenarios {
            let request = scenario.request
            let data = try await client.complete(request)
            let questions = try parser.parseQuestions(from: data)
            let issues = PromptCoachingQualityPolicy.evaluateQuestions(
                questions,
                selectedLens: scenario.selectedLens,
                primaryTrainingDimension: scenario.selectedLens.primaryTrainingDimension
            )
            guard issues.isEmpty else {
                throw TodayAIParsingError.qualityGateFailed(
                    Array(Set(issues.map { $0.reason.rawValue })).sorted()
                )
            }

            let outputText = questions
                .map { [$0.question, $0.whyItMatters, $0.whyNow ?? "", $0.expectedUpdate ?? "", $0.proceedWhen ?? "", $0.calibrationTarget ?? ""].joined(separator: " ") }
                .joined(separator: " ")
            results.append(LiveGLMCareerGoldenResult(
                caseID: scenario.caseID,
                questions: questions,
                denialViolations: Self.forbiddenOutputPhrases.filter {
                    outputText.localizedCaseInsensitiveContains($0)
                }
            ))
        }
        return results
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

    private static let forbiddenOutputPhrases = [
        "因为你是学生", "学生天生", "作为学生你应该", "程序员天生", "因为你是程序员",
        "金融人都", "因为你的职业", "答案是", "直接照做", "加油", "你一定可以", "继续努力"
    ]

    private static let careerScenarios: [LiveGLMCareerGoldenScenario] = [
        .init(
            caseID: "career.student.synthesis.v1",
            careerLabel: "学生",
            selectedLens: .evidenceCheck,
            cards: [
                .init(id: "career-student-fact", type: "fact", title: "练习提交记录", body: "周三18:00提交练习，系统记录3次编译失败；这是可观察事实。", priority: "medium", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-student-interpretation", type: "problem", title: "把失败归因于粗心", body: "我判断失败来自粗心，但还没有逐条检查日志，解释与事实需要分开。", priority: "high", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-student-task", type: "task", title: "补一条反例证据", body: "查看一次失败日志，记录触发条件，并写下什么结果会推翻当前判断。", priority: "high", sensitivity: "normal", isExcludedFromModel: false)
            ]
        ),
        .init(
            caseID: "career.programmer.synthesis.v1",
            careerLabel: "软件工程师",
            selectedLens: .evidenceCheck,
            cards: [
                .init(id: "career-programmer-fact", type: "fact", title: "接口测试结果", body: "接口测试在本地通过，但集成环境有2次超时；这是可观察事实，不是原因结论。", priority: "high", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-programmer-interpretation", type: "risk", title: "猜测缓存导致超时", body: "我推测缓存失效是主因，但尚未比较请求耗时和依赖服务状态，仍有证据缺口。", priority: "high", sensitivity: "normal", isExcludedFromModel: false),
                .init(id: "career-programmer-task", type: "task", title: "做一次最小对照", body: "固定请求参数，对比命中缓存与未命中缓存的耗时和超时次数。", priority: "high", sensitivity: "normal", isExcludedFromModel: false)
            ]
        ),
        .init(
            caseID: "career.finance.synthesis.v1",
            careerLabel: "金融从业者",
            selectedLens: .evidenceCheck,
            cards: [
                .init(id: "career-finance-fact", type: "fact", title: "报表差异记录", body: "月度报表与明细表相差1.8%，差异集中在两个日期；这是核对事实。", priority: "high", sensitivity: "possibly_sensitive", isExcludedFromModel: false),
                .init(id: "career-finance-interpretation", type: "problem", title: "推测为汇率口径差异", body: "我推测汇率口径造成差异，但还没有核对汇率来源、日期和四舍五入规则。", priority: "high", sensitivity: "possibly_sensitive", isExcludedFromModel: false),
                .init(id: "career-finance-task", type: "task", title: "补齐口径核对证据", body: "抽取两个差异日期，逐项记录汇率来源、计算口径和舍入结果。", priority: "high", sensitivity: "possibly_sensitive", isExcludedFromModel: false)
            ]
        )
    ]
}

private struct LiveGLMCareerGoldenScenario {
    let caseID: String
    let careerLabel: String
    let selectedLens: ThinkingLens
    let cards: [PromptContextPayload.Card]

    var request: LLMRequest {
        let rawText = """
        职业背景：\(careerLabel)。职业标签仅作为情境，不是能力、动机、偏好、收入、责任或任何判断的证据。
        拒绝基于职业标签的刻板推断，不迎合用户，也不要替用户下结论或给出直接答案。
        请只根据下列确认材料提出可验证的追问。
        """
        let template = LocalPromptProvider().template(for: .generateQuestions, mode: .standard)
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: caseID, rawText: rawText),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue, selectedLens: selectedLens.rawValue),
            cards: cards,
            directives: .init(
                privacyRules: "Synthetic evaluation only. Do not infer personal attributes from the career label."
            )
        )
        return LLMRequest(
            prompt: template,
            inputSummary: "careerGolden=\(caseID); careerLabel=context-only; denialGuidance=enabled; cards=\(cards.map(\.title).joined(separator: ", "))",
            contextPayload: payload,
            sourceRecordIDs: cards.map(\.id),
            contextVersion: 1,
            contextRecordIDs: cards.map(\.id)
        )
    }
}

private struct LiveGLMCareerGoldenResult {
    let caseID: String
    let questions: [ReflectionQuestion]
    let denialViolations: [String]
}

private final class CareerGoldenFixtureClient: LLMClient {
    private(set) var requests: [LLMRequest] = []

    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        let titles = request.contextPayload?.cards.map(\.title) ?? []
        let payload: [String: Any] = [
            "questions": [[
                "question": "哪些记录是事实，哪些只是对当前原因的解释？",
                "why_this_matters": "先分离事实和解释，避免把未经核对的归因当成结论。",
                "why_now": "当前材料仍缺少能支持或推翻解释的可观察证据。",
                "expected_update": "补齐对照记录后，更新对当前原因解释的可信度。",
                "proceed_when": "记录一条支持或推翻解释的可复查证据后再决定下一步。",
                "evidence_gap_type": "missing_observation",
                "answer_use": "collect_evidence",
                "lens_move": "fact_interpretation_split",
                "source_card_titles": titles,
                "calibration_target": "当前原因解释是否得到可复查证据支持"
            ]]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}
