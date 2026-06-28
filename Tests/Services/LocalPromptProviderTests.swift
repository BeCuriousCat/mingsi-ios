import XCTest
@testable import MingSi

final class LocalPromptProviderTests: XCTestCase {
    private let provider = LocalPromptProvider()

    func testEveryPromptTemplate_hasCommonThinkingCoachGuardrails() {
        for promptID in PromptID.allCases {
            let template = provider.template(for: promptID, mode: .standard)
            let combined = "\(template.systemText)\n\(template.userText)"

            if promptID == .organizeCards {
                XCTAssertTrue(combined.contains("MINGSI_STREAM_V1"), "\(promptID.rawValue) must require streaming XML output")
                XCTAssertTrue(combined.contains("Do not return JSON"), "\(promptID.rawValue) must avoid JSON for streaming output")
            } else {
                XCTAssertTrue(combined.contains("Return valid JSON"), "\(promptID.rawValue) must require JSON output")
            }
            XCTAssertTrue(combined.contains("Do not decide for the user"), "\(promptID.rawValue) must not decide for the user")
            XCTAssertTrue(combined.contains("Do not replace the user's thinking"), "\(promptID.rawValue) must preserve user agency")
            XCTAssertTrue(combined.contains("confidential"), "\(promptID.rawValue) must include confidentiality guardrails")
            XCTAssertTrue(combined.contains("默认使用简体中文"), "\(promptID.rawValue) must default to Simplified Chinese output")
            XCTAssertTrue(combined.contains("follow the user's input language"), "\(promptID.rawValue) must follow the user's input language")
            XCTAssertGreaterThan(template.outputSchemaVersion, 0)
        }
    }

    func testOrganizeCardsTemplate_requiresEditableCardsAndSensitivity() {
        let template = provider.template(for: .organizeCards, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("editable thinking cards"))
        XCTAssertTrue(text.contains("Do not summarize into one article"))
        XCTAssertTrue(text.contains("<CARD>"))
        XCTAssertTrue(text.contains("<SENSITIVITY>"))
        XCTAssertTrue(text.contains("possibly_sensitive"))
    }

    func testGenerateQuestionsTemplate_requiresLensSpecificConcreteQuestions() {
        let template = provider.template(for: .generateQuestions, mode: .deep)
        let text = template.userText

        XCTAssertTrue(text.contains("lens-specific"))
        XCTAssertTrue(text.contains("Do not ask generic self-help questions"))
        XCTAssertTrue(text.contains("evidence gap"))
        XCTAssertTrue(text.contains("disconfirming signal"))
        XCTAssertTrue(text.contains("\"questions\""))
        XCTAssertTrue(text.contains("\"expected_answer_type\""))
        XCTAssertTrue(text.contains("deep 4-5"))
    }

    func testGenerateQuestionsTemplate_requiresCoachQualityEvidenceGapAndCalibrationQuestions() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("evidence gap"))
        XCTAssertTrue(text.contains("disconfirming signal"))
        XCTAssertTrue(text.contains("feedback loop"))
        XCTAssertTrue(text.contains("second-order consequence"))
        XCTAssertTrue(text.contains("judgment_calibration"))
        XCTAssertTrue(text.contains("next calibration signal"))
        XCTAssertTrue(text.contains("Do not ask questions that only invite opinions"))
    }

    func testGenerateQuestionsTemplate_requiresStructuredEvidenceGapTaxonomy() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"evidence_gap_type\""))
        XCTAssertTrue(text.contains("missing_observation"))
        XCTAssertTrue(text.contains("missing_baseline"))
        XCTAssertTrue(text.contains("missing_causal_link"))
        XCTAssertTrue(text.contains("missing_counterexample"))
        XCTAssertTrue(text.contains("missing_constraint"))
        XCTAssertTrue(text.contains("missing_calibration_signal"))
        XCTAssertTrue(text.contains("none"))
        XCTAssertTrue(text.contains("Do not label every question as an evidence gap"))
    }

    func testGenerateQuestionsTemplate_requiresAnswerUseAndRejectsPseudoDepth() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"answer_use\""))
        XCTAssertTrue(text.contains("update_judgment"))
        XCTAssertTrue(text.contains("choose_action"))
        XCTAssertTrue(text.contains("test_assumption"))
        XCTAssertTrue(text.contains("collect_evidence"))
        XCTAssertTrue(text.contains("watch_calibration_signal"))
        XCTAssertTrue(text.contains("Do not ask aesthetically smart questions"))
        XCTAssertTrue(text.contains("If the answer would not change a judgment, action, evidence plan, assumption test, or calibration signal, replace the question"))
    }

    func testGenerateQuestionsTemplate_requiresLensMoveTaxonomy() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"lens_move\""))
        XCTAssertTrue(text.contains("fact_interpretation_split"))
        XCTAssertTrue(text.contains("alternative_explanation"))
        XCTAssertTrue(text.contains("leverage_tradeoff"))
        XCTAssertTrue(text.contains("constraint_decomposition"))
        XCTAssertTrue(text.contains("feedback_loop"))
        XCTAssertTrue(text.contains("delayed_effect"))
        XCTAssertTrue(text.contains("second_order_consequence"))
        XCTAssertTrue(text.contains("prediction_calibration"))
        XCTAssertTrue(text.contains("Each question must declare the lens-specific reasoning move it trains"))
    }

    func testGenerateQuestionsTemplate_requiresSourceCardGrounding() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"source_card_titles\""))
        XCTAssertTrue(text.contains("Every question must cite at least one confirmed card title"))
        XCTAssertTrue(text.contains("Do not invent source_card_titles"))
        XCTAssertTrue(text.contains("If a question cannot be tied to a confirmed card, replace it"))
    }

    func testGenerateQuestionsTemplate_requiresCalibrationTarget() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"calibration_target\""))
        XCTAssertTrue(text.contains("Every question must name the judgment or assumption it will calibrate"))
        XCTAssertTrue(text.contains("Do not use vague calibration targets"))
        XCTAssertTrue(text.contains("If the target cannot be stated, replace the question"))
    }

    func testGenerateQuestionsTemplate_trainsXYZJudgmentSentence() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("judgment sentence"))
        XCTAssertTrue(text.contains("我现在相信 X"))
        XCTAssertTrue(text.contains("明天用 Y"))
        XCTAssertTrue(text.contains("如果出现 Z"))
        XCTAssertTrue(text.contains("calibration_target must be X"))
    }

    func testGenerateQuestionsTemplate_requiresFunctionalCoachFields() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"why_now\""))
        XCTAssertTrue(text.contains("\"expected_update\""))
        XCTAssertTrue(text.contains("\"proceed_when\""))
        XCTAssertTrue(text.contains("why this question is the right next move"))
        XCTAssertTrue(text.contains("what judgment, action, evidence plan, or calibration signal the answer is expected to change"))
        XCTAssertTrue(text.contains("what kind of answer is sufficient to move toward action"))
    }

    func testGenerateQuestionsTemplate_usesLensFeedbackToTuneFutureQuestions() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("lensFeedback"))
        XCTAssertTrue(text.contains("reinforce"))
        XCTAssertTrue(text.contains("avoid"))
        XCTAssertTrue(text.contains("verified outcomes"))
        XCTAssertTrue(text.contains("lensMoves"))
        XCTAssertTrue(text.contains("Do not repeat a lens move that produced low-value or uncalibratable work"))
    }

    func testGenerateQuestionsTemplate_usesCoachLedTrainingPlanDimensions() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("trainingPrescription"))
        XCTAssertTrue(text.contains("coach plan, not a lens picker"))
        XCTAssertTrue(text.contains("primaryTrainingDimension"))
        XCTAssertTrue(text.contains("secondaryTrainingDimensions"))
        XCTAssertTrue(text.contains("baselineTrainingDimensions"))
        XCTAssertTrue(text.contains("The first question must train primaryTrainingDimension"))
        XCTAssertTrue(text.contains("Every question must serve either primaryTrainingDimension or one baselineTrainingDimension"))
        XCTAssertTrue(text.contains("Use selectedLens/finalTrainingLens to choose lens_move"))
        XCTAssertTrue(text.contains("Do not treat a user override as proof that the coach diagnosis was wrong"))
    }

    func testGenerateQuestionsTemplate_usesCoachTeachingPlanAsTrainingFrame() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("coachTeachingPlan"))
        XCTAssertTrue(text.contains("missing thinking move"))
        XCTAssertTrue(text.contains("whyNotAnswer"))
        XCTAssertTrue(text.contains("proceedStandard"))
        XCTAssertTrue(text.contains("repairQuestion"))
        XCTAssertTrue(text.contains("experienceReplayPrompt"))
        XCTAssertTrue(text.contains("not an AI answer"))
        XCTAssertTrue(text.contains("Use coachTeachingPlan before wording questions"))
    }

    func testGenerateQuestionsTemplate_usesCoachObservationBeforeQuestions() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("coachObservation"))
        XCTAssertTrue(text.contains("primaryGap"))
        XCTAssertTrue(text.contains("trainingAbility"))
        XCTAssertTrue(text.contains("feedback.ask"))
        XCTAssertTrue(text.contains("experienceReplayPrompt"))
        XCTAssertTrue(text.contains("Use coachObservation before wording questions"))
        XCTAssertTrue(text.contains("not source evidence"))
    }

    func testCurrentTodayLoopTemplates_useTomorrowValidationLanguage() {
        let questionText = provider.template(for: .generateQuestions, mode: .standard).userText
        let questText = provider.template(for: .generateQuests, mode: .standard).userText

        XCTAssertTrue(questionText.contains("明日验证"))
        XCTAssertTrue(questionText.contains("验证行动"))
        XCTAssertFalse(questionText.contains("明日实验"))
        XCTAssertFalse(questionText.contains("明天实验"))

        XCTAssertTrue(questText.contains("明日验证"))
        XCTAssertTrue(questText.contains("验证行动"))
        XCTAssertFalse(questText.contains("明日实验"))
        XCTAssertFalse(questText.contains("明天实验"))
    }

    func testGenerateQuestionsTemplate_declaresNonAppeasingCoachStance() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("not a satisfaction-maximizing assistant"))
        XCTAssertTrue(text.contains("Do not flatter, reassure, or agree"))
        XCTAssertTrue(text.contains("Empathy is not agreement"))
        XCTAssertTrue(text.contains("Acknowledge pressure or context only when it helps the user face the real thinking gap"))
        XCTAssertTrue(text.contains("weak claim, missing evidence, premature conclusion"))
        XCTAssertTrue(text.contains("Critique the thinking move, not the person"))
        XCTAssertTrue(text.contains("Do not diagnose personality, intelligence, motivation, or hidden intent"))
        XCTAssertTrue(text.contains("Every correction must say what was observed"))
    }

    func testGenerateQuestsAndExtractPrincipleTemplatesDeclareEmpathyIsNotAgreement() {
        let questText = provider.template(for: .generateQuests, mode: .standard).userText
        let principleText = provider.template(for: .extractPrinciple, mode: .standard).userText

        XCTAssertTrue(questText.contains("Empathy is not agreement"))
        XCTAssertTrue(questText.contains("Acknowledge pressure or context only when it helps the user face the real action-design gap"))
        XCTAssertTrue(principleText.contains("Empathy is not agreement"))
        XCTAssertTrue(principleText.contains("Acknowledge pressure or context only when it helps the user face the real reusable-rule gap"))
    }

    func testGenerateQuestsTemplate_requiresOneMainQuestAndVerifiableCriteria() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("exactly one main quest"))
        XCTAssertTrue(text.contains("highest-value action"))
        XCTAssertTrue(text.contains("completion criteria"))
        XCTAssertTrue(text.contains("\"main_quest\""))
        XCTAssertTrue(text.contains("\"linked_cards\""))
        XCTAssertTrue(text.contains("rather than inventing a task"))
    }

    func testGenerateQuestsTemplate_designsCalibrationTasksInsteadOfGenericTodos() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("calibration instrument"))
        XCTAssertTrue(text.contains("evidence gap"))
        XCTAssertTrue(text.contains("observable calibration signal"))
        XCTAssertTrue(text.contains("\"calibration_target\""))
        XCTAssertTrue(text.contains("\"lens_move\""))
        XCTAssertTrue(text.contains("Use reflectionAnswers calibrationTarget"))
        XCTAssertTrue(text.contains("Do not invent vague calibration targets"))
        XCTAssertTrue(text.contains("rejected_low_value_tasks"))
        XCTAssertTrue(text.contains("system_thinking"))
        XCTAssertTrue(text.contains("judgment_calibration"))
    }

    func testGenerateQuestsTemplate_reusesXYZJudgmentSentenceAsCalibrationTarget() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("judgment sentence"))
        XCTAssertTrue(text.contains("我现在相信 X"))
        XCTAssertTrue(text.contains("明天用 Y"))
        XCTAssertTrue(text.contains("如果出现 Z"))
        XCTAssertTrue(text.contains("main_quest.calibration_target must be X"))
    }

    func testGenerateQuestsTemplate_usesLensFeedbackToAvoidLowValueQuestDesigns() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("lensFeedback"))
        XCTAssertTrue(text.contains("verified lens outcomes"))
        XCTAssertTrue(text.contains("lensMoves"))
        XCTAssertTrue(text.contains("avoid repeating quest patterns"))
        XCTAssertTrue(text.contains("Reinforce lensMoves that produced high-value calibration evidence"))
        XCTAssertTrue(text.contains("make the same lensMoves smaller, more observable"))
    }

    func testGenerateQuestsTemplate_preservesCoachTeachingProceedStandard() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("coachTeachingPlan"))
        XCTAssertTrue(text.contains("proceedStandard"))
        XCTAssertTrue(text.contains("auditNote"))
        XCTAssertTrue(text.contains("Do not erase unresolved teaching gaps"))
    }

    func testGenerateQuestsTemplate_declaresNonAppeasingCoachStance() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("not a satisfaction-maximizing assistant"))
        XCTAssertTrue(text.contains("Do not turn a weak judgment into a quest just to let the user proceed"))
        XCTAssertTrue(text.contains("name the unresolved evidence gap, skipped tradeoff, premature conclusion, or avoided responsibility"))
        XCTAssertTrue(text.contains("Critique the action design or thinking move, not the person"))
        XCTAssertTrue(text.contains("Do not diagnose personality, intelligence, motivation, or hidden intent"))
    }

    func testVerifyQuestTemplate_requiresPredictionEvidenceAndJudgmentUpdate() {
        let template = provider.template(for: .verifyQuest, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("original prediction"))
        XCTAssertTrue(text.contains("actual evidence"))
        XCTAssertTrue(text.contains("judgment update"))
        XCTAssertTrue(text.contains("evidence gained"))
        XCTAssertTrue(text.contains("observable evidence"))
        XCTAssertTrue(text.contains("completion criteria"))
        XCTAssertTrue(text.contains("acceptance criteria"))
        XCTAssertTrue(text.contains("next calibration"))
        XCTAssertTrue(text.contains("observable signal to watch"))
        XCTAssertTrue(text.contains("do not return generic encouragement"))
        XCTAssertTrue(text.contains("targetJudgment"))
        XCTAssertTrue(text.contains("Compare targetJudgment with actual evidence"))
        XCTAssertTrue(text.contains("trainingPrinciple"))
        XCTAssertTrue(text.contains("expected principle was actually practiced"))
        XCTAssertTrue(text.contains("\"expected_principle_practice_assessment\""))
        XCTAssertTrue(text.contains("Do not use expected_principle_practice_assessment as practice evidence"))
    }

    func testExtractPrincipleTemplate_rejectsSituationalLessonsAndRequiresBehaviorRule() {
        let template = provider.template(for: .extractPrinciple, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("at most one reusable principle"))
        XCTAssertTrue(text.contains("too situational"))
        XCTAssertTrue(text.contains("behavior rule"))
        XCTAssertTrue(text.contains("\"principle_candidate\""))
        XCTAssertTrue(text.contains("\"source_card_titles\""))
        XCTAssertTrue(text.contains("exact titles from confirmedCards"))
        XCTAssertTrue(text.contains("Do not invent source_card_titles"))
        XCTAssertTrue(text.contains("return principle_candidate: null"))
        XCTAssertTrue(text.contains("at least two concrete actions"))
        XCTAssertTrue(text.contains("observable evidence"))
        XCTAssertTrue(text.contains("Do not return vague slogans"))
    }

    func testExtractPrincipleTemplate_declaresNonAppeasingCoachStance() {
        let template = provider.template(for: .extractPrinciple, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("not a satisfaction-maximizing assistant"))
        XCTAssertTrue(text.contains("Do not turn an unverified story or comforting lesson into a principle"))
        XCTAssertTrue(text.contains("name the missing evidence, exception, trigger boundary, or action standard"))
        XCTAssertTrue(text.contains("Critique the reusable rule, not the person"))
        XCTAssertTrue(text.contains("Do not diagnose personality, intelligence, motivation, or hidden intent"))
    }

    func testEveryPromptID_everySessionMode_returnsNonEmptyTemplate() {
        for promptID in PromptID.allCases {
            for mode in SessionMode.allCases {
                let template = provider.template(for: promptID, mode: mode)
                XCTAssertFalse(template.systemText.isEmpty, "\(promptID.rawValue)/\(mode.rawValue) systemText must not be empty")
                XCTAssertFalse(template.userText.isEmpty, "\(promptID.rawValue)/\(mode.rawValue) userText must not be empty")
                XCTAssertFalse(template.version.isEmpty, "\(promptID.rawValue)/\(mode.rawValue) version must not be empty")
                XCTAssertGreaterThan(template.outputSchemaVersion, 0, "\(promptID.rawValue)/\(mode.rawValue) outputSchemaVersion must be positive")
            }
        }
    }

    func testEveryPromptTemplate_exposesVersionedPromptAssetMetadata() {
        for promptID in PromptID.allCases {
            let template = provider.template(for: promptID, mode: .standard)

            XCTAssertFalse(template.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.systemPolicyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.contextPolicyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.evalSuiteVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertGreaterThan(template.outputSchemaVersion, 0)
        }
    }

    func testGenerateQuestionsCurrentTemplate_declaresLocalRollbackTarget() {
        let current = provider.template(for: .generateQuestions, mode: .standard)

        XCTAssertEqual(current.version, "1.11.0")
        XCTAssertEqual(current.outputSchemaVersion, 6)
        XCTAssertEqual(current.rollbackTargetVersion, "1.10.0")
    }

    func testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .generateQuestions, mode: .standard)
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.10.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.10.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.9.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("Generate lens-specific reflection questions") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"evidence_gap_type\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"answer_use\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"lens_move\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"source_card_titles\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"calibration_target\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("primaryTrainingDimension") ?? false)
        XCTAssertTrue(historical?.userText.contains("coachTeachingPlan") ?? false)
        XCTAssertTrue(historical?.userText.contains("not a satisfaction-maximizing assistant") ?? false)
        XCTAssertTrue(historical?.userText.contains("Empathy is not agreement") ?? false)
        XCTAssertTrue(historical?.userText.contains("coachObservation") ?? false)
        XCTAssertTrue(historical?.userText.contains("明日实验") ?? false)
    }

    func testGenerateQuestionsV190HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.9.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.9.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.8.0")
        XCTAssertFalse(historical?.userText.contains("coachObservation") ?? true)
        XCTAssertTrue(historical?.userText.contains("明日实验") ?? false)
    }

    func testGenerateQuestionsV170HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.7.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.7.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.6.0")
        XCTAssertTrue(historical?.userText.contains("Generate lens-specific reflection questions") ?? false)
        XCTAssertTrue(historical?.userText.contains("coachTeachingPlan") ?? false)
        XCTAssertFalse(historical?.userText.contains("not a satisfaction-maximizing assistant") ?? true)
    }

    func testGenerateQuestionsV150HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.5.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.5.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 5)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.4.0")
        XCTAssertTrue(historical?.userText.contains("Generate lens-specific reflection questions") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"evidence_gap_type\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"answer_use\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"lens_move\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"source_card_titles\"") ?? false)
        XCTAssertFalse(historical?.userText.contains("\"calibration_target\"") ?? true)
    }

    func testGenerateQuestionsV140HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.4.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.4.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 4)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.3.0")
        XCTAssertTrue(historical?.userText.contains("\"evidence_gap_type\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"answer_use\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"lens_move\"") ?? false)
        XCTAssertFalse(historical?.userText.contains("\"source_card_titles\"") ?? true)
    }

    func testGenerateQuestionsV130HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.3.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.3.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 3)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.2.0")
        XCTAssertTrue(historical?.userText.contains("\"evidence_gap_type\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"answer_use\"") ?? false)
        XCTAssertFalse(historical?.userText.contains("\"lens_move\"") ?? true)
        XCTAssertFalse(historical?.userText.contains("\"source_card_titles\"") ?? true)
    }

    func testGenerateQuestionsV120HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.2.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.2.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 2)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.1.0")
        XCTAssertTrue(historical?.userText.contains("\"evidence_gap_type\"") ?? false)
        XCTAssertFalse(historical?.userText.contains("\"answer_use\"") ?? true)
        XCTAssertFalse(historical?.userText.contains("\"lens_move\"") ?? true)
    }

    func testGenerateQuestionsV110HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.1.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.1.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 1)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.0.0")
        XCTAssertTrue(historical?.userText.contains("Generate lens-specific reflection questions") ?? false)
        XCTAssertFalse(historical?.userText.contains("\"evidence_gap_type\"") ?? true)
    }

    func testGenerateQuestionsV100HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.0.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.0.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 1)
        XCTAssertEqual(historical?.rollbackTargetVersion, "0.9.0")
        XCTAssertTrue(historical?.userText.contains("Generate lens-specific reflection questions") ?? false)
    }

    func testGenerateQuestionsV090HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "0.9.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "0.9.0")
        XCTAssertNil(historical?.rollbackTargetVersion)
        XCTAssertTrue(historical?.userText.contains("Generate concrete reflection questions") ?? false)
    }

    func testGenerateQuestsCurrentTemplate_declaresLocalRollbackTarget() {
        let current = provider.template(for: .generateQuests, mode: .standard)

        XCTAssertEqual(current.version, "1.6.0")
        XCTAssertEqual(current.outputSchemaVersion, 3)
        XCTAssertEqual(current.rollbackTargetVersion, "1.5.0")
    }

    func testGenerateQuestsRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .generateQuests, mode: .standard)
        let historical = provider.template(for: .generateQuests, mode: .standard, version: "1.5.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.5.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, 3)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.4.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("Generate tomorrow's quests") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"calibration_target\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"lens_move\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("not a satisfaction-maximizing assistant") ?? false)
        XCTAssertTrue(historical?.userText.contains("Empathy is not agreement") ?? false)
        XCTAssertTrue(historical?.userText.contains("coachTeachingPlan") ?? false)
        XCTAssertTrue(historical?.userText.contains("明日实验") ?? false)

        let prior140 = provider.template(for: .generateQuests, mode: .standard, version: "1.4.0")
        XCTAssertEqual(prior140?.version, "1.4.0")
        XCTAssertEqual(prior140?.rollbackTargetVersion, "1.3.0")
        XCTAssertFalse(prior140?.userText.contains("Empathy is not agreement") ?? true)

        let prior130 = provider.template(for: .generateQuests, mode: .standard, version: "1.3.0")
        XCTAssertEqual(prior130?.version, "1.3.0")
        XCTAssertEqual(prior130?.rollbackTargetVersion, "1.2.0")
        XCTAssertFalse(prior130?.userText.contains("not a satisfaction-maximizing assistant") ?? true)

        let prior120 = provider.template(for: .generateQuests, mode: .standard, version: "1.2.0")
        XCTAssertEqual(prior120?.version, "1.2.0")
        XCTAssertEqual(prior120?.rollbackTargetVersion, "1.1.0")
        XCTAssertFalse(prior120?.userText.contains("\"lens_move\"") ?? true)

        let prior110 = provider.template(for: .generateQuests, mode: .standard, version: "1.1.0")
        XCTAssertEqual(prior110?.version, "1.1.0")
        XCTAssertEqual(prior110?.rollbackTargetVersion, "1.0.0")
        XCTAssertFalse(prior110?.userText.contains("\"calibration_target\"") ?? true)
    }

    func testVerifyQuestCurrentTemplate_declaresLocalRollbackTarget() {
        let current = provider.template(for: .verifyQuest, mode: .standard)

        XCTAssertEqual(current.version, "1.6.0")
        XCTAssertEqual(current.outputSchemaVersion, 2)
        XCTAssertEqual(current.rollbackTargetVersion, "1.5.0")
    }

    func testVerifyQuestRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .verifyQuest, mode: .standard)
        let historical = provider.template(for: .verifyQuest, mode: .standard, version: "1.5.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.5.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, 1)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.4.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("trainingPrinciple") ?? false)
        XCTAssertFalse(historical?.userText.contains("\"expected_principle_practice_assessment\"") ?? true)

        let prior140 = provider.template(for: .verifyQuest, mode: .standard, version: "1.4.0")
        XCTAssertEqual(prior140?.version, "1.4.0")
        XCTAssertEqual(prior140?.rollbackTargetVersion, "1.3.0")
        XCTAssertFalse(prior140?.userText.contains("trainingPrinciple") ?? true)
        XCTAssertFalse(prior140?.userText.contains("generic encouragement") ?? true)

        let prior130 = provider.template(for: .verifyQuest, mode: .standard, version: "1.3.0")
        XCTAssertEqual(prior130?.version, "1.3.0")
        XCTAssertEqual(prior130?.rollbackTargetVersion, "1.2.0")
        XCTAssertTrue(historical?.userText.contains("Review yesterday's quest") ?? false)
        XCTAssertTrue(historical?.userText.contains("targetJudgment") ?? false)
        XCTAssertTrue(historical?.userText.contains("observable evidence") ?? false)
        XCTAssertTrue(historical?.userText.contains("acceptance criteria evidence") ?? false)
        XCTAssertTrue(historical?.userText.contains("generic encouragement") ?? false)

        let prior120 = provider.template(for: .verifyQuest, mode: .standard, version: "1.2.0")
        XCTAssertEqual(prior120?.version, "1.2.0")
        XCTAssertEqual(prior120?.rollbackTargetVersion, "1.1.0")
        XCTAssertTrue(prior120?.userText.contains("targetJudgment") ?? false)
        XCTAssertFalse(prior120?.userText.contains("observable evidence") ?? true)

        let prior110 = provider.template(for: .verifyQuest, mode: .standard, version: "1.1.0")
        XCTAssertEqual(prior110?.version, "1.1.0")
        XCTAssertEqual(prior110?.rollbackTargetVersion, "1.0.0")
        XCTAssertFalse(prior110?.userText.contains("targetJudgment") ?? true)

        let prior100 = provider.template(for: .verifyQuest, mode: .standard, version: "1.0.0")
        XCTAssertEqual(prior100?.version, "1.0.0")
        XCTAssertNil(prior100?.rollbackTargetVersion)
    }

    func testExtractPrincipleCurrentTemplate_declaresLocalRollbackTarget() {
        let current = provider.template(for: .extractPrinciple, mode: .standard)

        XCTAssertEqual(current.version, "1.4.0")
        XCTAssertEqual(current.rollbackTargetVersion, "1.3.0")
        XCTAssertTrue(current.userText.contains("exact titles from confirmedCards"))
        XCTAssertTrue(current.userText.contains("Do not invent source_card_titles"))
        XCTAssertTrue(current.userText.contains("at least two concrete actions"))
        XCTAssertTrue(current.userText.contains("Empathy is not agreement"))
    }

    func testExtractPrincipleRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .extractPrinciple, mode: .standard)
        let historical = provider.template(for: .extractPrinciple, mode: .standard, version: "1.3.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.3.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, current.outputSchemaVersion)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.2.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("\"source_card_titles\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("exact titles from confirmedCards") ?? false)
        XCTAssertTrue(historical?.userText.contains("at least two concrete actions") ?? false)
        XCTAssertTrue(historical?.userText.contains("not a satisfaction-maximizing assistant") ?? false)
        XCTAssertFalse(historical?.userText.contains("Empathy is not agreement") ?? true)

        let prior120 = provider.template(for: .extractPrinciple, mode: .standard, version: "1.2.0")
        XCTAssertEqual(prior120?.version, "1.2.0")
        XCTAssertEqual(prior120?.rollbackTargetVersion, "1.1.0")
        XCTAssertFalse(prior120?.userText.contains("not a satisfaction-maximizing assistant") ?? true)

        let prior110 = provider.template(for: .extractPrinciple, mode: .standard, version: "1.1.0")
        XCTAssertEqual(prior110?.version, "1.1.0")
        XCTAssertEqual(prior110?.rollbackTargetVersion, "1.0.0")
        XCTAssertFalse(prior110?.userText.contains("at least two concrete actions") ?? true)

        let prior100 = provider.template(for: .extractPrinciple, mode: .standard, version: "1.0.0")
        XCTAssertEqual(prior100?.version, "1.0.0")
        XCTAssertNil(prior100?.rollbackTargetVersion)
        XCTAssertFalse(prior100?.userText.contains("exact titles from confirmedCards") ?? true)
    }

    func testTemplateVersionLookup_returnsNilForUnknownHistoricalAsset() {
        XCTAssertNil(provider.template(for: .generateQuestions, mode: .standard, version: "0.8.0"))
        XCTAssertNil(provider.template(for: .generateQuests, mode: .standard, version: "0.9.0"))
        XCTAssertNil(provider.template(for: .verifyQuest, mode: .standard, version: "0.9.0"))
        XCTAssertNil(provider.template(for: .extractPrinciple, mode: .standard, version: "0.9.0"))
    }

    func testModeGuidance_changesBySessionMode() {
        let quick = provider.template(for: .generateQuestions, mode: .quick)
        let standard = provider.template(for: .generateQuestions, mode: .standard)
        let deep = provider.template(for: .generateQuestions, mode: .deep)

        XCTAssertTrue(quick.userText.contains("quick 1-2"))
        XCTAssertTrue(standard.systemText.contains("standard is the default full loop"))
        XCTAssertTrue(deep.systemText.contains("deep uses more scrutiny"))
        XCTAssertTrue(deep.userText.contains("stronger opposing-view question"))
    }
}
