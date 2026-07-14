import XCTest

final class PromptSpecificationDocumentTests: XCTestCase {
    func testPromptSpecDocumentsQuestCalibrationTargetAndVerificationTargetJudgment() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("\"calibration_target\""))
        XCTAssertTrue(spec.contains("\"linked_cards\""))
        XCTAssertTrue(spec.contains("Quest.sourceCardTitles"))
        XCTAssertTrue(spec.contains("Quest.lensMove"))
        XCTAssertTrue(spec.contains("PrincipleAsset.sourceCardTitles"))
        XCTAssertTrue(spec.contains("persisted with the quest's calibration payload"))
        XCTAssertTrue(spec.contains("persisted with the principle raw payload"))
        XCTAssertTrue(spec.contains("Quest must carry the selected lens's reasoning move into `lens_move`"))
        XCTAssertTrue(spec.contains("Quest must carry the calibration target into tomorrow's verification"))
        XCTAssertTrue(spec.contains("the quest is the action form of the selected thinking lens"))
        XCTAssertTrue(spec.contains("Do not invent `linked_cards`"))
        XCTAssertTrue(spec.contains("Do not invent `source_card_titles`"))
        XCTAssertTrue(spec.contains("targetJudgment"))
        XCTAssertTrue(spec.contains("Verify Quest input"))
        XCTAssertTrue(spec.contains("Compare targetJudgment with actual evidence"))
    }

    func testPromptSpecDocumentsLensFeedbackLoop() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("lensFeedback"))
        XCTAssertTrue(spec.contains("verified outcomes"))
        XCTAssertTrue(spec.contains("reinforce"))
        XCTAssertTrue(spec.contains("avoid"))
        XCTAssertTrue(spec.contains("\"lensMoves\""))
        XCTAssertTrue(spec.contains("Do not repeat a lens move that produced low-value or uncalibratable work"))
    }

    func testPromptSpecDocumentsTrainingDimensionsForCoachLedPlan() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Training Dimension"))
        XCTAssertTrue(spec.contains("primaryTrainingDimension"))
        XCTAssertTrue(spec.contains("secondaryTrainingDimensions"))
        XCTAssertTrue(spec.contains("baselineTrainingDimensions"))
        XCTAssertTrue(spec.contains("evidence_discipline"))
        XCTAssertTrue(spec.contains("counterexample_seeking"))
        XCTAssertTrue(spec.contains("assumption_testing"))
        XCTAssertTrue(spec.contains("system_feedback_awareness"))
        XCTAssertTrue(spec.contains("judgment_calibration"))
        XCTAssertTrue(spec.contains("testable_action_design"))
        XCTAssertTrue(spec.contains("Every question must serve either the primary training dimension or one baseline training dimension"))
        XCTAssertTrue(spec.contains("The generateQuestions prompt must apply this plan before output generation"))
        XCTAssertTrue(spec.contains("Do not rely on the deterministic quality gate as the first place where training-dimension alignment happens"))
    }

    func testPromptSpecDocumentsNonAppeasingCoachStance() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Non-Appeasing Coach Stance"))
        XCTAssertTrue(spec.contains("satisfaction-maximizing assistant"))
        XCTAssertTrue(spec.contains("must forbid"))
        XCTAssertTrue(spec.contains("flattering, reassuring, or agreeing"))
        XCTAssertTrue(spec.contains("Empathy is not agreement"))
        XCTAssertTrue(spec.contains("pressure, ambiguity, or"))
        XCTAssertTrue(spec.contains("context only when"))
        XCTAssertTrue(spec.contains("It must not turn pressure"))
        XCTAssertTrue(spec.contains("generateQuests"))
        XCTAssertTrue(spec.contains("extractPrinciple"))
        XCTAssertTrue(spec.contains("weak claim, missing evidence, premature"))
        XCTAssertTrue(spec.contains("critique must target the thinking move"))
        XCTAssertTrue(spec.contains("action design, or principle candidate, not the person"))
        XCTAssertTrue(spec.contains("must not turn a weak judgment into a quest"))
        XCTAssertTrue(spec.contains("must not turn an unverified story or comforting lesson into"))
        XCTAssertTrue(spec.contains("personality, intelligence, motivation, or hidden intent"))
        XCTAssertTrue(spec.contains("appeasingWithoutCorrection"))
    }

    func testPromptSpecDocumentsEvidenceOwnershipAcrossTheCoachLoop() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Evidence Ownership And Loop Handoff"))
        XCTAssertTrue(spec.contains("reported material"))
        XCTAssertTrue(spec.contains("coach interpretation"))
        XCTAssertTrue(spec.contains("action is not proof"))
        XCTAssertTrue(spec.contains("separate claims"))
        XCTAssertTrue(spec.contains("repeated pattern or a"))
    }

    func testPromptSpecDocumentsCoachTurnStateForStatefulCoachLoop() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")
        let contextPRD = try readRepositoryFile("docs/prompt-context-engineering-prd.md")

        XCTAssertTrue(spec.contains("Coach Turn State"))
        XCTAssertTrue(spec.contains("coachTurnState"))
        XCTAssertTrue(spec.contains("coach-turn.local-v1"))
        XCTAssertTrue(spec.contains("coachTurnRule"))
        XCTAssertTrue(spec.contains("openEvidenceGaps"))
        XCTAssertTrue(spec.contains("baselineChecks"))
        XCTAssertTrue(spec.contains("decisionSource"))
        XCTAssertTrue(spec.contains("turnSummary"))
        XCTAssertTrue(spec.contains("not_ready"))
        XCTAssertTrue(spec.contains("ready"))
        XCTAssertTrue(spec.contains("userOverrideProgress"))
        XCTAssertTrue(spec.contains("ask clarification or evidence-gap questions before converging"))
        XCTAssertTrue(spec.contains("form a verifiable action"))
        XCTAssertTrue(spec.contains("override is permission to proceed, not proof that the coach was wrong"))
        XCTAssertTrue(spec.contains("organizeCards must not receive `coachTurnState`"))
        XCTAssertTrue(contextPRD.contains("Coach Turn State v1"))
        XCTAssertTrue(contextPRD.contains("有状态教练轮次"))
        XCTAssertTrue(contextPRD.contains("不引入 LangChain/LangGraph"))
    }

    func testPromptSpecDocumentsCoachTeachingPlanForMissingThinkingMove() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Coach Teaching Plan"))
        XCTAssertTrue(spec.contains("coachTeachingPlan"))
        XCTAssertTrue(spec.contains("coachTeachingRule"))
        XCTAssertTrue(spec.contains("missingMoveTitle"))
        XCTAssertTrue(spec.contains("trainingTargetTitle"))
        XCTAssertTrue(spec.contains("whyNotAnswer"))
        XCTAssertTrue(spec.contains("proceedStandard"))
        XCTAssertTrue(spec.contains("repairQuestion"))
        XCTAssertTrue(spec.contains("experienceReplayPrompt"))
        XCTAssertTrue(spec.contains("routeSteps"))
        XCTAssertTrue(spec.contains("missing thinking move"))
        XCTAssertTrue(spec.contains("not an AI answer"))
        XCTAssertTrue(spec.contains("organizeCards must not receive `coachTeachingPlan`"))
    }

    func testPromptSpecDocumentsCoachObservationContext() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Coach Observation Context"))
        XCTAssertTrue(spec.contains("coachObservation"))
        XCTAssertTrue(spec.contains("coachObservationRule"))
        XCTAssertTrue(spec.contains("observed material"))
        XCTAssertTrue(spec.contains("primaryGap"))
        XCTAssertTrue(spec.contains("trainingAbility"))
        XCTAssertTrue(spec.contains("feedback.ask"))
        XCTAssertTrue(spec.contains("organizeCards must not receive `coachObservation`"))
    }

    func testPromptSpecDocumentsQuestionTrainingContract() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Question Training Contract"))
        XCTAssertTrue(spec.contains("one primary training contract"))
        XCTAssertTrue(spec.contains("trainingAbility"))
        XCTAssertTrue(spec.contains("primaryGap"))
        XCTAssertTrue(spec.contains("feedback.ask"))
        XCTAssertTrue(spec.contains("produce missing material"))
        XCTAssertTrue(spec.contains("must not provide the missing material"))
        XCTAssertTrue(spec.contains("why_now"))
        XCTAssertTrue(spec.contains("observed gap"))
        XCTAssertTrue(spec.contains("expected_update"))
        XCTAssertTrue(spec.contains("user-owned training output"))
        XCTAssertTrue(spec.contains("proceed_when"))
        XCTAssertTrue(spec.contains("self-checkable standard"))
        XCTAssertTrue(spec.contains("reproduce, adapt, or reject"))
    }

    func testPromptSpecDocumentsXYZJudgmentSentenceTraining() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")

        XCTAssertTrue(spec.contains("Judgment Sentence Training"))
        XCTAssertTrue(spec.contains("我现在相信 X"))
        XCTAssertTrue(spec.contains("明天用 Y"))
        XCTAssertTrue(spec.contains("如果出现 Z"))
        XCTAssertTrue(spec.contains("generateQuestions"))
        XCTAssertTrue(spec.contains("generateQuests"))
        XCTAssertTrue(spec.contains("calibration_target must be X"))
    }

    func testPromptContextPRDDocumentsCoachContextMemoryV1() throws {
        let contextPRD = try readRepositoryFile("docs/prompt-context-engineering-prd.md")

        XCTAssertTrue(contextPRD.contains("Coach Context Memory v1"))
        XCTAssertTrue(contextPRD.contains("coach-context-memory.local-v1"))
        XCTAssertTrue(contextPRD.contains("历史原则、lens feedback、过往教练结果什么时候进入当前教练轮次"))
        XCTAssertTrue(contextPRD.contains("organizeCards"))
        XCTAssertTrue(contextPRD.contains("不接收任何 coach memory"))
        XCTAssertTrue(contextPRD.contains("最多 3 条相关 active 原则"))
        XCTAssertTrue(contextPRD.contains("最多 2 条与 final lens 相同的 verified `lensFeedback`"))
        XCTAssertTrue(contextPRD.contains("历史 coach outcome 不作为独立长期记忆直接注入 Today prompt"))
        XCTAssertTrue(contextPRD.contains("prompt context 和质量门必须使用同一个 memory selection"))
    }

    func testPromptSpecDocumentsDeterministicCoachingQualityGate() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")
        let productRisks = try readRepositoryFile("docs/product-risks-and-design-language.md")

        XCTAssertTrue(spec.contains("PromptCoachingQualityPolicy"))
        XCTAssertTrue(spec.contains("genericQuestion"))
        XCTAssertTrue(spec.contains("vagueCalibrationTarget"))
        XCTAssertTrue(spec.contains("repeatedAvoidedLensMove"))
        XCTAssertTrue(spec.contains("unadjustedLensMove"))
        XCTAssertTrue(spec.contains("missingReinforcedLensMove"))
        XCTAssertTrue(spec.contains("missingSelectedLensMove"))
        XCTAssertTrue(spec.contains("missingTrainingDimensionAlignment"))
        XCTAssertTrue(spec.contains("missingPrimaryTrainingDimensionFocus"))
        XCTAssertTrue(spec.contains("missingCoachTurnAlignment"))
        XCTAssertTrue(spec.contains("missingSystemThinkingLensMove"))
        XCTAssertTrue(spec.contains("weakVerificationCalibrationNote"))
        XCTAssertTrue(spec.contains("weakVerificationRecommendation"))
        XCTAssertTrue(spec.contains("missingPrincipleSourceGrounding"))
        XCTAssertTrue(spec.contains("weakPrincipleActionability"))
        XCTAssertTrue(spec.contains("busyworkQuest"))
        XCTAssertTrue(spec.contains("missingSourceGrounding"))
        XCTAssertTrue(spec.contains("quest output does not include the reasoning move required by the selected built-in lens"))
        XCTAssertTrue(spec.contains("question does not serve the primary training dimension or any baseline training dimension"))
        XCTAssertTrue(spec.contains("first question does not serve the primary training dimension"))
        XCTAssertTrue(spec.contains("qualityGateFailed"))
        XCTAssertTrue(spec.contains("existing fallback and retry path"))
        XCTAssertTrue(productRisks.contains("deterministic coaching quality gate"))
        XCTAssertTrue(productRisks.contains("does not replace human or LLM review"))
        XCTAssertTrue(productRisks.contains("qualityGateFailed"))
        XCTAssertTrue(productRisks.contains("missingCoachTurnAlignment"))
        XCTAssertTrue(productRisks.contains("tomorrow's action remains traceable to today's evidence"))
        XCTAssertTrue(spec.contains("observable evidence or signal"))
        XCTAssertTrue(spec.contains("completion criteria or acceptance criteria evidence"))
        XCTAssertTrue(productRisks.contains("observable signal"))
        XCTAssertTrue(productRisks.contains("completion or acceptance criteria evidence"))
        XCTAssertTrue(productRisks.contains("practice_role"))
        XCTAssertTrue(productRisks.contains("targetedPractice"))
        XCTAssertTrue(productRisks.contains("secondaryPractice"))
        XCTAssertTrue(productRisks.contains("possibleSignal"))
        XCTAssertTrue(productRisks.contains("weak verification recommendations"))
        XCTAssertTrue(productRisks.contains("next calibration action or signal"))
        XCTAssertTrue(productRisks.contains("selected built-in lens"))
        XCTAssertTrue(productRisks.contains("reusable behavior rule grounded in confirmed source cards"))
        XCTAssertTrue(productRisks.contains("actionable and verifiable rather than a slogan"))
        XCTAssertTrue(productRisks.contains("missing source grounding for questions, quests, or principles"))
    }

    func testPromptSpecDocumentsQuestionFieldsAsTeachingCuesAndExperienceReplay() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")
        let productRisks = try readRepositoryFile("docs/product-risks-and-design-language.md")

        XCTAssertTrue(spec.contains("user-visible teaching fields"))
        XCTAssertTrue(spec.contains("why_now"))
        XCTAssertTrue(spec.contains("expected_update"))
        XCTAssertTrue(spec.contains("proceed_when"))
        XCTAssertTrue(spec.contains("why this question now"))
        XCTAssertTrue(spec.contains("what the answer will change"))
        XCTAssertTrue(spec.contains("what is sufficient to proceed"))
        XCTAssertTrue(productRisks.contains("experience replay"))
        XCTAssertTrue(productRisks.contains("not passive references"))
        XCTAssertTrue(productRisks.contains("复现"))
    }

    func testCoachQualityBaselineDocumentsCurrentStageGuardrails() throws {
        let baseline = try readRepositoryFile("docs/coach-quality-baseline.md")

        XCTAssertTrue(baseline.contains("教练质量基线"))
        XCTAssertTrue(baseline.contains("个人思维教练"))
        XCTAssertTrue(baseline.contains("不是 AI 答案工具"))
        XCTAssertTrue(baseline.contains("沟通力"))
        XCTAssertTrue(baseline.contains("思考力"))
        XCTAssertTrue(baseline.contains("执行力"))
        XCTAssertTrue(baseline.contains("校准力"))
        XCTAssertTrue(baseline.contains("讲不清、证据不足、判断跳跃、行动不可验证、旧经验误用"))
        XCTAssertTrue(baseline.contains("只给一个最小训练动作"))
        XCTAssertTrue(baseline.contains("不能把全部历史塞进每次 Prompt"))
        XCTAssertTrue(baseline.contains("至少 20 条典型输入"))
        XCTAssertTrue(baseline.contains("真实手机试用通过"))
        XCTAssertTrue(baseline.contains("Allowed Work"))
        XCTAssertTrue(baseline.contains("Disallowed Work"))
        XCTAssertTrue(baseline.contains("不做商业化功能"))
        XCTAssertTrue(baseline.contains("不做同步和账号系统"))
        XCTAssertTrue(baseline.contains("不无限加 Prompt 规则"))
        XCTAssertTrue(baseline.contains("不让 AI 直接给结论"))
        XCTAssertTrue(baseline.contains("docs/coach-quality-golden-cases.json"))
    }

    func testCoachQualityGoldenCasesCoverStageStopConditions() throws {
        let cases = try readCoachQualityGoldenCases()

        XCTAssertGreaterThanOrEqual(cases.count, 20)
        XCTAssertEqual(Set(cases.map(\.id)).count, cases.count)
        XCTAssertTrue(cases.allSatisfy { !$0.input.isEmpty })
        XCTAssertTrue(cases.allSatisfy { !$0.minimalTrainingAction.isEmpty })
        XCTAssertTrue(cases.allSatisfy { !$0.shouldNotDo.isEmpty })

        let abilities = Set(cases.map(\.expectedAbility))
        XCTAssertTrue(abilities.isSuperset(of: ["communication", "thinking", "execution", "calibration"]))

        let primaryGaps = Set(cases.map(\.expectedPrimaryGap))
        XCTAssertTrue(primaryGaps.isSuperset(of: [
            "narrative_unclear",
            "evidence_gap",
            "judgment_jump",
            "unverifiable_action",
            "experience_misuse"
        ]))

        let coverageTags = Set(cases.flatMap(\.coverageTags))
        XCTAssertTrue(coverageTags.isSuperset(of: [
            "流水账",
            "背景缺失",
            "对象不清",
            "证据不足",
            "判断跳跃",
            "行动替代目标",
            "旧经验误用",
            "明日验证不可检查",
            "用户要求直接给答案"
        ]))
    }

    func testTodayCoachMainPathAvoidsHighCostUserTerms() throws {
        let mainPathSources = [
            "Sources/Features/Today/TodayView.swift",
            "Sources/App/AppStore.swift",
            "Sources/Domain/Models.swift"
        ]
        let forbiddenTerms = [
            "训练处方",
            "审计",
            "闭环",
            "校验依据",
            "能力诊断",
            "推进标准",
            "训练契约",
            "底盘检查",
            "过往经验复现",
            "本轮训练",
            "自检标准",
            "教练批改",
            "具体还缺",
            "可复述材料",
            "判断句训练"
        ]

        for source in mainPathSources {
            let content = try readRepositoryFile(source)
            for term in forbiddenTerms {
                XCTAssertFalse(content.contains(term), "\(source) should not expose high-cost user term: \(term)")
            }
        }
    }

    private func readRepositoryFile(_ relativePath: String) throws -> String {
        let sourceFilePath = String(#filePath)
        guard let testsRange = sourceFilePath.range(of: "/Tests/") else {
            XCTFail("Could not derive repository root from \(sourceFilePath)")
            return ""
        }
        let repositoryRoot = String(sourceFilePath[..<testsRange.lowerBound])
        let fileURL = URL(fileURLWithPath: repositoryRoot).appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func readCoachQualityGoldenCases() throws -> [CoachQualityGoldenCase] {
        let data = try Data(readRepositoryFile("docs/coach-quality-golden-cases.json").utf8)
        return try JSONDecoder().decode([CoachQualityGoldenCase].self, from: data)
    }

    private struct CoachQualityGoldenCase: Decodable {
        var id: String
        var input: String
        var expectedPrimaryGap: String
        var expectedAbility: String
        var minimalTrainingAction: String
        var shouldNotDo: String
        var coverageTags: [String]
    }
}
