import XCTest
@testable import MingSi

final class PromptEvalFixtureTests: XCTestCase {
    private var parser: TodayAIResponseParser!

    override func setUp() {
        super.setUp()
        parser = TodayAIResponseParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testOrganizeCards_messyDailyInputProducesTypedSensitiveCards() throws {
        let data = fixtureData(
            """
            {
              "cards": [
                {
                  "type": "communication",
                  "title": "会前没有明确要确认的决策",
                  "body": "会议推进时先讨论细节，最后才发现负责人和验收标准没有写清。",
                  "importance": "high",
                  "sensitivity": "normal",
                  "confidence": "high",
                  "reason": "这是可复用的沟通流程问题。"
                },
                {
                  "type": "risk",
                  "title": "内部项目名需要抽象化",
                  "body": "用户提到具体内部项目和客户语境，后续模型调用应避免重复细节。",
                  "importance": "medium",
                  "sensitivity": "possibly_sensitive",
                  "confidence": "medium",
                  "reason": "符合隐私边界要求。"
                },
                {
                  "type": "task",
                  "title": "下次会议前写出决策清单",
                  "body": "列出本次会议要确认的事项、负责人和完成标准。",
                  "importance": "high",
                  "sensitivity": "normal",
                  "confidence": "high",
                  "reason": "可转化为明日验证。"
                }
              ]
            }
            """
        )

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.map(\.type), [.communication, .risk, .task])
        XCTAssertTrue(cards.contains { $0.sensitivity == .possiblySensitive })
        XCTAssertTrue(cards.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
    }

    func testQuestionsEval_requiresConcreteLensSpecificQuestions() throws {
        let data = fixtureData(
            """
            {
              "questions": [
                {
                  "question": "这次会议中，哪些内容是事实，哪些只是你对对方意图的判断？",
                  "why_this_matters": "证据校验透镜要求先分开事实和解释，避免把感觉当结论。",
                  "expected_answer_type": "fact"
                },
                {
                  "question": "如果你对会议低效的判断是错的，最可能被哪条证据推翻？",
                  "why_this_matters": "反方问题可以阻止只证明自己原本的看法。",
                  "expected_answer_type": "validation"
                },
                {
                  "question": "明天只做一件事时，哪一个动作最能减少后续返工？",
                  "why_this_matters": "杠杆分析必须把思考落到可执行取舍。",
                  "expected_answer_type": "tradeoff"
                }
              ]
            }
            """
        )

        let questions = try parser.parseQuestions(from: data)

        XCTAssertEqual(questions.count, 3)
        XCTAssertTrue(questions.contains { $0.question.contains("事实") && $0.question.contains("判断") })
        XCTAssertTrue(questions.contains { $0.question.contains("最可能") && $0.question.contains("推翻") })
        XCTAssertTrue(questions.contains { $0.question.contains("明天") || $0.question.contains("一件事") })
    }

    func testQuestsEval_requiresSingleMainQuestWithVerifiableCriteria() throws {
        let data = fixtureData(
            """
            {
              "main_quest": {
                "type": "main",
                "title": "会前写出决策清单并确认负责人",
                "why_it_matters": "这是减少会议返工的最高杠杆动作。",
                "completion_criteria": "会议开始前完成一页清单，包含要确认的决策、负责人、验收标准，并在会后发出确认摘要。",
                "expected_resistance": "临时事项会诱导你直接开会而不先写清楚目标。",
                "reflection_question": "这次准备是否让会议少绕了一轮？",
                "lens_move": "leverage_tradeoff",
                "linked_cards": ["会前没有明确要确认的决策"]
              },
              "side_quests": [],
              "observation_quest": null,
              "rejected_low_value_tasks": ["先把会议纪要排版得更完整"]
            }
            """
        )

        let quests = try parser.parseQuests(from: data)

        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests[0].type, .main)
        XCTAssertTrue(quests[0].completionCriteria.contains("包含"))
        XCTAssertTrue(quests[0].completionCriteria.contains("负责人"))
        XCTAssertTrue(quests[0].completionCriteria.count > quests[0].title.count)
    }

    func testPrincipleEval_acceptsBehaviorRuleAndRejectsSlogan() throws {
        let valid = fixtureData(
            """
            {
              "principle_candidate": {
                "title": "会议前先定义要确认的决策",
                "summary": "重要会议前先写清要确认什么、谁负责、什么算完成。",
                "trigger_context": "跨角色会议或需要推进协作时。",
                "actions": ["写出要确认的决策", "标出负责人", "写出验收标准", "会后发送确认摘要"],
                "success_criteria": "参会者能复述下一步负责人和完成标准。",
                "exceptions": "低风险同步会可以只写一句目标。",
                "source_card_titles": ["会议目标不清", "接口归属未确认"]
              }
            }
            """
        )
        let slogan = fixtureData(
            """
            {
              "principle_candidate": {
                "title": "要更主动",
                "summary": "主动一点就会更好。",
                "trigger_context": "",
                "actions": [],
                "success_criteria": "",
                "exceptions": ""
              }
            }
            """
        )

        let principles = try parser.parsePrinciples(from: valid)
        let rejected = try parser.parsePrinciples(from: slogan)

        XCTAssertEqual(principles.count, 1)
        XCTAssertEqual(principles[0].actions.count, 4)
        XCTAssertTrue(principles[0].successCriteria.contains("负责人"))
        XCTAssertEqual(principles[0].sourceCardTitles, ["会议目标不清", "接口归属未确认"])
        XCTAssertTrue(rejected.isEmpty)
    }

    func testGrowthContributionEval_requiresEvidenceRefsAndClampsDelta() throws {
        let sourceDailyEntryId = UUID()
        let snapshotId = UUID()
        let data = fixtureData(
            """
            {
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.45,
                  "title": "会议目标更清晰",
                  "reason": "用户在任务中明确要求会前写出决策、负责人和验收标准。",
                  "source_type": "quest",
                  "source_id": "quest-001",
                  "source_daily_entry_id": "\(sourceDailyEntryId.uuidString)"
                },
                {
                  "metric": "reflection_depth",
                  "direction": "negative",
                  "delta": 0.08,
                  "title": "缺少反方验证",
                  "reason": "复盘没有记录什么证据会推翻当前判断。",
                  "source_type": "thinking_card",
                  "source_id": "card-002",
                  "source_daily_entry_id": "\(sourceDailyEntryId.uuidString)"
                }
              ]
            }
            """
        )

        let contributions = try parser.parseMetricContributions(from: data, snapshotId: snapshotId)

        XCTAssertEqual(contributions.count, 2)
        XCTAssertEqual(contributions[0].snapshotId, snapshotId)
        XCTAssertEqual(contributions[0].metric, .clarity)
        XCTAssertEqual(contributions[0].direction, .positive)
        XCTAssertEqual(contributions[0].delta, 0.30, accuracy: 0.001)
        XCTAssertEqual(contributions[0].sourceDailyEntryId, sourceDailyEntryId)
        XCTAssertEqual(contributions[1].direction, .negative)
    }

    func testGrowthContributionEval_rejectsItemsWithoutSourceEvidence() {
        let snapshotId = UUID()
        let data = fixtureData(
            """
            {
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.10,
                  "title": "更清晰",
                  "reason": "看起来更清楚。",
                  "source_type": "quest",
                  "source_id": "",
                  "source_daily_entry_id": ""
                }
              ]
            }
            """
        )

        XCTAssertThrowsError(try parser.parseMetricContributions(from: data, snapshotId: snapshotId)) { error in
            XCTAssertEqual(error as? TodayAIParsingError, .emptyResult)
        }
    }

    func testPromptEvalRunner_recordsSuiteMetadataAndCaseResults() throws {
        let provider = LocalPromptProvider()
        let runner = PromptEvalRunner(promptProvider: provider, parser: parser)

        let runs = runner.runFixedSuite()

        XCTAssertFalse(runs.isEmpty)
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.organizeCards.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.generateQuestions.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.generateQuests.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.extractPrinciple.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.weeklyCalibration.rawValue })
        XCTAssertTrue(runs.allSatisfy { !$0.promptVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.systemPolicyVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.contextPolicyVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.evalSuiteVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.caseResults.isEmpty })
        XCTAssertTrue(runs.allSatisfy { $0.status == .passed })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.inputSummary.isEmpty })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.expectedBehavior.isEmpty })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.actualObservation.isEmpty })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.diagnosticReason.isEmpty })

        let questionsRun = runs.first { $0.promptId == PromptID.generateQuestions.rawValue }
        XCTAssertEqual(questionsRun?.evalSuiteVersion, provider.template(for: .generateQuestions, mode: .standard).evalSuiteVersion)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.concrete_lens_specific" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.evidence_gap_taxonomy" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.answer_use_not_pseudo_depth" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.lens_move_taxonomy" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.source_card_grounding" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.calibration_target_declared" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.lens_feedback_tunes_moves" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.prompt_declares_non_appeasing_coach_stance" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_functional_coach_fields" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_blocks_appeasing_output" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_blocks_generic_uncalibratable_output" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_honors_avoid_lens_moves" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_adjusted_lens_move" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_reinforced_lens_move" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_system_thinking_lens_move" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_selected_lens_move" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_training_dimension_alignment" } ?? false)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.quality_gate_requires_primary_training_dimension_focus" } ?? false)
        let questionsCase = try XCTUnwrap(questionsRun?.caseResults.first { $0.caseId == "questions.concrete_lens_specific" })
        XCTAssertTrue(questionsCase.inputSummary.contains("meeting"))
        XCTAssertTrue(questionsCase.expectedBehavior.contains("lens-specific"))
        XCTAssertTrue(questionsCase.actualObservation.contains("passed"))
        XCTAssertTrue(questionsCase.diagnosticReason.contains("fixed-suite"))

        let questsRun = runs.first { $0.promptId == PromptID.generateQuests.rawValue }
        XCTAssertTrue(questsRun?.caseResults.contains { $0.caseId == "quests.calibration_signal_task" } ?? false)
        XCTAssertTrue(questsRun?.caseResults.contains { $0.caseId == "quests.quality_gate_blocks_busywork_without_calibration" } ?? false)
        XCTAssertTrue(questsRun?.caseResults.contains { $0.caseId == "quests.quality_gate_blocks_appeasing_output" } ?? false)
        XCTAssertTrue(questsRun?.caseResults.contains { $0.caseId == "quests.quality_gate_requires_source_grounding" } ?? false)
        XCTAssertTrue(questsRun?.caseResults.contains { $0.caseId == "quests.quality_gate_requires_selected_lens_move" } ?? false)

        let verifyRun = runs.first { $0.promptId == PromptID.verifyQuest.rawValue }
        XCTAssertTrue(verifyRun?.caseResults.contains { $0.caseId == "verify.judgment_update_from_evidence" } ?? false)
        XCTAssertTrue(verifyRun?.caseResults.contains { $0.caseId == "verify.quality_gate_blocks_weak_calibration_note" } ?? false)
        XCTAssertTrue(verifyRun?.caseResults.contains { $0.caseId == "verify.quality_gate_blocks_weak_recommendation" } ?? false)
        let principleRun = runs.first { $0.promptId == PromptID.extractPrinciple.rawValue }
        XCTAssertTrue(principleRun?.caseResults.contains { $0.caseId == "principle.quality_gate_requires_source_grounding" } ?? false)
        XCTAssertTrue(principleRun?.caseResults.contains { $0.caseId == "principle.quality_gate_requires_actionability" } ?? false)
        XCTAssertTrue(principleRun?.caseResults.contains { $0.caseId == "principle.quality_gate_blocks_appeasing_output" } ?? false)
    }

    func testPromptCoachingQualityPolicy_flagsGenericQuestionsVagueTargetsAndAvoidedMoves() throws {
        let avoidedFeedback = [
            PromptContextPayload.LensFeedbackContext(
                lensId: ThinkingLens.judgmentCalibration.rawValue,
                lensTitle: ThinkingLens.judgmentCalibration.title,
                signal: "avoid",
                completion: YesterdayCompletion.missed.rawValue,
                valueRating: YesterdayValueRating.low.rawValue,
                calibrationNote: "上一次预测校准问题太抽象，未产生可观察信号。",
                recommendation: "下一次先明确证据缺口。",
                questionTargets: ["用户的思考"],
                evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
            )
        ]
        let questions = [
            ReflectionQuestion(
                question: "你怎么看这个情况？",
                whyItMatters: "帮助你思考。",
                evidenceGapType: nil,
                answerUse: nil,
                lensMove: .predictionCalibration,
                sourceCardTitles: [],
                calibrationTarget: "用户的思考"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            lensFeedback: avoidedFeedback
        )

        XCTAssertTrue(issues.contains { $0.reason == .genericQuestion })
        XCTAssertTrue(issues.contains { $0.reason == .missingEvidenceGapType })
        XCTAssertTrue(issues.contains { $0.reason == .missingAnswerUse })
        XCTAssertTrue(issues.contains { $0.reason == .missingSourceGrounding })
        XCTAssertTrue(issues.contains { $0.reason == .vagueCalibrationTarget })
        XCTAssertTrue(issues.contains { $0.reason == .repeatedAvoidedLensMove })
    }

    func testPromptCoachingQualityPolicy_flagsUnadjustedLensMoveAfterAdjustFeedback() throws {
        let adjustFeedback = [
            PromptContextPayload.LensFeedbackContext(
                lensId: ThinkingLens.judgmentCalibration.rawValue,
                lensTitle: ThinkingLens.judgmentCalibration.title,
                signal: "adjust",
                completion: YesterdayCompletion.partial.rawValue,
                valueRating: YesterdayValueRating.medium.rawValue,
                calibrationNote: "预测校准方向有用，但目标太大，完成后仍不知道验收机制是否真的减少返工。",
                recommendation: "下一次把 prediction_calibration 缩小到一个可观察信号。",
                questionTargets: ["验收机制减少返工"],
                evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
            )
        ]
        let questions = [
            ReflectionQuestion(
                question: "明天能观察到哪个信号，证明验收机制减少返工？",
                whyItMatters: "它继续校准同一个判断。",
                evidenceGapType: .missingCalibrationSignal,
                answerUse: .watchCalibrationSignal,
                lensMove: .predictionCalibration,
                sourceCardTitles: ["验收机制不清"],
                calibrationTarget: "验收机制减少返工"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            lensFeedback: adjustFeedback
        )

        XCTAssertTrue(issues.contains { $0.reason == .unadjustedLensMove })
    }

    func testPromptCoachingQualityPolicy_flagsMissingReinforcedLensMove() throws {
        let reinforceFeedback = [
            PromptContextPayload.LensFeedbackContext(
                lensId: ThinkingLens.judgmentCalibration.rawValue,
                lensTitle: ThinkingLens.judgmentCalibration.title,
                signal: "reinforce",
                completion: YesterdayCompletion.done.rawValue,
                valueRating: YesterdayValueRating.high.rawValue,
                calibrationNote: "prediction_calibration 产生了清晰的校准证据。",
                recommendation: "继续使用预测校准，但换到今天的证据和目标。",
                questionTargets: ["书面验收减少返工"],
                evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
            )
        ]
        let questions = [
            ReflectionQuestion(
                question: "还有什么替代解释能说明今天的返工？",
                whyItMatters: "它检查解释是否过早收敛。",
                evidenceGapType: .missingCounterexample,
                answerUse: .testAssumption,
                lensMove: .alternativeExplanation,
                sourceCardTitles: ["今天返工来自验收口径"],
                calibrationTarget: "今天返工主要来自验收口径不清"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            lensFeedback: reinforceFeedback
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingReinforcedLensMove })
    }

    func testPromptCoachingQualityPolicy_flagsMissingSystemThinkingLensMove() throws {
        let questions = [
            ReflectionQuestion(
                question: "还有什么替代解释能说明今天的返工？",
                whyItMatters: "它检查解释是否过早收敛。",
                evidenceGapType: .missingCounterexample,
                answerUse: .testAssumption,
                lensMove: .alternativeExplanation,
                sourceCardTitles: ["临时修复带来返工"],
                calibrationTarget: "返工主要来自解释过早收敛"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            selectedLens: .systemThinking
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingSystemThinkingLensMove })
    }

    func testPromptCoachingQualityPolicy_flagsMissingSelectedLensMove() throws {
        let questions = [
            ReflectionQuestion(
                question: "还有什么替代解释能说明今天的返工？",
                whyItMatters: "它检查解释是否过早收敛。",
                evidenceGapType: .missingCounterexample,
                answerUse: .testAssumption,
                lensMove: .alternativeExplanation,
                sourceCardTitles: ["会议返工来自低价值任务"],
                calibrationTarget: "明天最能减少返工的是最高杠杆动作"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            selectedLens: .leverageAnalysis
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingSelectedLensMove })
    }

    func testPromptCoachingQualityPolicy_flagsQuestionNotAlignedToTrainingDimensions() throws {
        let questions = [
            ReflectionQuestion(
                question: "明天应该优先做哪个动作来减少会议返工？",
                whyItMatters: "它帮助选择下一步动作。",
                evidenceGapType: EvidenceGapType.none,
                answerUse: .chooseAction,
                lensMove: .leverageTradeoff,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "优先做高杠杆动作能减少会议返工"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            primaryTrainingDimension: .evidenceDiscipline,
            baselineTrainingDimensions: [.counterexampleSeeking]
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingTrainingDimensionAlignment })
    }

    func testPromptCoachingQualityPolicy_flagsQuestionIgnoringNotReadyCoachTurn() throws {
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "验收口径不清，需要先补事实和基线。",
            openEvidenceGaps: [.missingObservation, .missingBaseline],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Turn 1: ask evidence questions before converging."
        )
        let questions = [
            ReflectionQuestion(
                question: "明天应该优先做哪个动作来减少会议返工？",
                whyItMatters: "它帮助选择下一步动作。",
                evidenceGapType: EvidenceGapType.none,
                answerUse: .chooseAction,
                lensMove: .leverageTradeoff,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "优先做高杠杆动作能减少会议返工"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            coachTurnState: turn
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingCoachTurnAlignment })
    }

    func testPromptCoachingQualityPolicy_flagsMissingFunctionalCoachFields() throws {
        let questions = [
            ReflectionQuestion(
                question: "这次会议返工里，哪条是可观察事实？",
                whyItMatters: "它把事实和解释拆开。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "验收口径不清是本次会议返工的主要原因"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(questions)

        XCTAssertTrue(issues.contains { $0.reason == .missingFunctionalCoachField })
    }

    func testPromptCoachingQualityPolicy_flagsQuestionThatDoesNotTargetMissingThinkingMaterial() throws {
        let questions = [
            ReflectionQuestion(
                question: "这次会议返工里，哪条事实最重要？",
                whyItMatters: "它帮助你排序事实。",
                whyNow: "现在需要先看事实。",
                expectedUpdate: "答案会改变你对会议返工原因的判断。",
                proceedWhen: "当你选出一个事实时就可以继续。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "验收口径不清是本次会议返工的主要原因"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(questions)

        XCTAssertTrue(issues.map(\.reason.rawValue).contains("missingThinkingMaterialTarget"))
    }

    func testPromptCoachingQualityPolicy_allowsQuestionThatTargetsMissingThinkingMaterial() throws {
        let questions = [
            ReflectionQuestion(
                question: "这次返工里还缺哪条可观察证据，能支撑“验收口径不清是主因”的判断？",
                whyItMatters: "它要求先补上判断所需的证据，再决定原因是否成立。",
                whyNow: "现在你的记录已经有结论，但还缺少能被他人复核的事实材料。",
                expectedUpdate: "答案会让你知道这个判断是否有足够证据，还是需要改成其他解释。",
                proceedWhen: "当你写出一条可观察证据，或承认当前证据不足时就可以继续。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "验收口径不清是本次会议返工的主要原因"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(questions)

        XCTAssertFalse(issues.contains { $0.reason == .missingThinkingMaterialTarget })
    }

    func testPromptCoachingQualityPolicy_flagsQuestionThatIgnoresRelevantPrincipleReplay() throws {
        let questions = [
            ReflectionQuestion(
                question: "这次返工里还缺哪条可观察证据，能支撑“验收口径不清是主因”的判断？",
                whyItMatters: "它要求先补上判断所需的证据，再决定原因是否成立。",
                whyNow: "现在你的记录已经有结论，但还缺少能被他人复核的事实材料。",
                expectedUpdate: "答案会让你知道这个判断是否有足够证据，还是需要改成其他解释。",
                proceedWhen: "当你写出一条可观察证据，或承认当前证据不足时就可以继续。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "验收口径不清是本次会议返工的主要原因"
            )
        ]
        let principles = [
            PromptContextPayload.PrincipleContext(
                id: UUID().uuidString,
                title: "会议结束前写清负责人和验收口径",
                summary: "类似协作问题里，先把负责人、验收口径和完成标准写出来。",
                triggerContext: "跨角色会议或返工复盘",
                successCriteria: "他人能复述负责人和验收口径。",
                exceptions: "低风险同步会可以简化。",
                status: .active
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            relevantPrinciples: principles
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingPrincipleReplay })
    }

    func testPromptCoachingQualityPolicy_allowsQuestionThatReplaysRelevantPrinciple() throws {
        let questions = [
            ReflectionQuestion(
                question: "过往“会议结束前写清负责人和验收口径”这条经验，今天应该复用、调整还是拒绝？还缺哪条证据来判断？",
                whyItMatters: "它训练你把旧经验迁移到今天，而不是机械套用原则。",
                whyNow: "现在有相似的会议返工场景，但还缺少判断这条经验是否适用的证据。",
                expectedUpdate: "答案会更新今天是否复用这条经验，或需要把它调整成更具体的做法。",
                proceedWhen: "当你说明复用、调整或拒绝，并写出一条支撑证据时就可以继续。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "验收口径不清是本次会议返工的主要原因"
            )
        ]
        let principles = [
            PromptContextPayload.PrincipleContext(
                id: UUID().uuidString,
                title: "会议结束前写清负责人和验收口径",
                summary: "类似协作问题里，先把负责人、验收口径和完成标准写出来。",
                triggerContext: "跨角色会议或返工复盘",
                successCriteria: "他人能复述负责人和验收口径。",
                exceptions: "低风险同步会可以简化。",
                status: .active
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            relevantPrinciples: principles
        )

        XCTAssertFalse(issues.contains { $0.reason == .missingPrincipleReplay })
    }

    func testPromptCoachingQualityPolicy_flagsQuestionThatIgnoresNarrativeObservationGap() throws {
        let questions = [
            ReflectionQuestion(
                question: "这次方案推进不下去，还缺哪条可观察证据？",
                whyItMatters: "它要求先补上判断所需的证据。",
                whyNow: "现在材料还缺少事实支撑。",
                expectedUpdate: "答案会让你知道这个判断是否成立。",
                proceedWhen: "当你写出一条可观察事实时就可以继续。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["今天很乱"],
                calibrationTarget: "方案推进不下去"
            )
        ]
        let observation = PromptContextPayload.CoachObservationContext(
            CoachObservation(
                policyVersion: CoachObservationPolicy.policyVersion,
                providedMaterials: [.feeling],
                missingMaterials: [.background, .object, .trigger, .action, .result],
                thinkingProcessObservation: "当前讲述只有感受，别人还不能复盘前因后果。",
                primaryGap: .narrative,
                secondaryGaps: [],
                trainingAbility: .description,
                feedback: CoachObservationFeedback(
                    observed: "你说出了感受。",
                    diagnosis: "当前是讲述 gap。",
                    training: "本轮训练沟通力中的描述力。",
                    ask: "请补充背景、对象、触发点、行动和结果。",
                    proceedWhen: "当背景、触发点、行动和结果说清楚时推进。"
                ),
                experienceReplayPrompt: ""
            )
        )

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            coachObservation: observation
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingNarrativeRepair })
    }

    func testPromptCoachingQualityPolicy_allowsQuestionThatRepairsNarrativeObservationGap() throws {
        let questions = [
            ReflectionQuestion(
                question: "请把这件事的背景、涉及对象、触发点、你当时怎么做，以及后来结果补完整。",
                whyItMatters: "它训练你先把事情讲清楚，让别人能复盘前因后果。",
                whyNow: "当前材料只有感受，缺少背景、对象、触发、行动和结果。",
                expectedUpdate: "答案会让这件事从情绪描述变成可复盘的事件描述。",
                proceedWhen: "当背景、对象、触发点、行动和结果都说清楚时就可以继续。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["今天很乱"],
                calibrationTarget: "方案推进不下去"
            )
        ]
        let observation = PromptContextPayload.CoachObservationContext(
            CoachObservation(
                policyVersion: CoachObservationPolicy.policyVersion,
                providedMaterials: [.feeling],
                missingMaterials: [.background, .object, .trigger, .action, .result],
                thinkingProcessObservation: "当前讲述只有感受，别人还不能复盘前因后果。",
                primaryGap: .narrative,
                secondaryGaps: [],
                trainingAbility: .description,
                feedback: CoachObservationFeedback(
                    observed: "你说出了感受。",
                    diagnosis: "当前是讲述 gap。",
                    training: "本轮训练沟通力中的描述力。",
                    ask: "请补充背景、对象、触发点、行动和结果。",
                    proceedWhen: "当背景、触发点、行动和结果说清楚时推进。"
                ),
                experienceReplayPrompt: ""
            )
        )

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            coachObservation: observation
        )

        XCTAssertFalse(issues.contains { $0.reason == .missingNarrativeRepair })
    }

    func testPromptCoachingQualityPolicy_flagsAppeasingQuestionsWithoutCorrection() throws {
        let questions = [
            ReflectionQuestion(
                question: "你已经想得很充分了，可以继续按这个方向推进吗？",
                whyItMatters: "你的想法很有价值，这个问题帮助你更有信心地行动。",
                whyNow: "当前最重要的是认可你已经做出的判断。",
                expectedUpdate: "答案会让你更确定自己原来的方向。",
                proceedWhen: "当你觉得有信心时就可以推进。",
                evidenceGapType: EvidenceGapType.none,
                answerUse: .chooseAction,
                lensMove: .leverageTradeoff,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "继续按当前判断推进"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(questions)

        XCTAssertTrue(issues.contains { $0.reason == .appeasingWithoutCorrection })
    }

    func testPromptCoachingQualityPolicy_flagsEmpathyUsedAsAgreementWithoutCorrection() throws {
        let questions = [
            ReflectionQuestion(
                question: "我理解你最近压力很大，要不要先继续按原计划推进？",
                whyItMatters: "你的处境确实不容易，这个问题帮助你先保护节奏。",
                whyNow: "当前最重要的是承认这个情况很困难。",
                expectedUpdate: "答案会让你觉得现在这样也合理。",
                proceedWhen: "当你觉得被理解时就可以推进。",
                evidenceGapType: EvidenceGapType.none,
                answerUse: .chooseAction,
                lensMove: .leverageTradeoff,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "继续按原计划推进"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(questions)

        XCTAssertTrue(issues.contains { $0.reason == .appeasingWithoutCorrection })
    }

    func testPromptCoachingQualityPolicy_flagsAcknowledgedGapThatStillLetsUserProceed() throws {
        let questions = [
            ReflectionQuestion(
                question: "虽然现在证据不足，但你压力很大，是否先继续推进当前方案？",
                whyItMatters: "它承认目前还有证据缺口，同时帮助你保持推进节奏。",
                whyNow: "当前可以先继续推进，后面再慢慢补证据。",
                expectedUpdate: "答案会让你决定是否维持原方案。",
                proceedWhen: "当你决定先推进时就可以进入行动。",
                evidenceGapType: .missingObservation,
                answerUse: .chooseAction,
                lensMove: .leverageTradeoff,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "继续按当前方案推进能减少会议返工"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(questions)

        XCTAssertTrue(issues.contains { $0.reason == .appeasingWithoutCorrection })
    }

    func testPromptCoachingQualityPolicy_flagsAppeasingQuestsWithoutCorrection() throws {
        let quests = [
            Quest(
                type: .main,
                title: "继续按当前方案推进",
                whyItMatters: "你已经想得很充分了，这会让你更有信心。",
                completionCriteria: "明天完成推进并确认自己更有信心。",
                expectedResistance: "可能担心还没准备好，但你的判断已经够好了。",
                reflectionQuestion: "你是否更认可自己当前的方向？",
                calibrationTarget: "继续按当前判断推进",
                lensMove: .leverageTradeoff,
                sourceCardTitles: ["会议返工来自验收口径不清"]
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuests(quests)

        XCTAssertTrue(issues.contains { $0.reason == .appeasingWithoutCorrection })
    }

    func testPromptCoachingQualityPolicy_flagsAppeasingPrinciplesWithoutCorrection() throws {
        let principles = [
            PrincipleAsset(
                title: "相信自己当前判断",
                summary: "你的想法很有价值，后续可以继续按当前判断推进。",
                triggerContext: "当你觉得方向已经明确时。",
                actions: ["认可自己的判断", "继续推进当前方案"],
                successCriteria: "自己觉得更有信心。",
                exceptions: "无。",
                sourceCardTitles: ["会议返工来自验收口径不清"]
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluatePrinciples(principles)

        XCTAssertTrue(issues.contains { $0.reason == .appeasingWithoutCorrection })
    }

    func testPromptCoachingQualityPolicy_allowsQuestionAlignedToEvidenceTrainingDimension() throws {
        let questions = [
            ReflectionQuestion(
                question: "这次会议返工里，哪条是可观察事实，哪条只是你对原因的解释？",
                whyItMatters: "它把事实和解释拆开，先补上判断所需的证据。",
                evidenceGapType: .missingObservation,
                answerUse: .collectEvidence,
                lensMove: .factInterpretationSplit,
                sourceCardTitles: ["会议返工来自验收口径不清"],
                calibrationTarget: "验收口径不清是本次会议返工的主要原因"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            primaryTrainingDimension: .evidenceDiscipline,
            baselineTrainingDimensions: [.counterexampleSeeking]
        )

        XCTAssertFalse(issues.contains { $0.reason == .missingTrainingDimensionAlignment })
    }

    func testPromptCoachingQualityPolicy_flagsFirstQuestionThatSkipsPrimaryTrainingDimension() throws {
        let questions = [
            ReflectionQuestion(
                question: "还有哪个反例会推翻验收口径不清是返工主因？",
                whyItMatters: "它检查当前解释是否过早收敛。",
                evidenceGapType: .missingCounterexample,
                answerUse: .testAssumption,
                lensMove: .alternativeExplanation,
                sourceCardTitles: ["验收口径导致返工"],
                calibrationTarget: "验收口径不清是返工主要原因"
            ),
            ReflectionQuestion(
                question: "明天能观察到哪个信号，证明书面验收减少了一轮返工？",
                whyItMatters: "它把判断变成可校准的结果。",
                evidenceGapType: .missingCalibrationSignal,
                answerUse: .watchCalibrationSignal,
                lensMove: .predictionCalibration,
                sourceCardTitles: ["验收口径导致返工"],
                calibrationTarget: "书面验收能减少一轮返工"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuestions(
            questions,
            primaryTrainingDimension: .judgmentCalibration,
            baselineTrainingDimensions: [.counterexampleSeeking]
        )

        XCTAssertTrue(
            issues.map(\.reason.rawValue).contains("missingPrimaryTrainingDimensionFocus")
        )
        XCTAssertFalse(issues.contains { $0.reason == .missingTrainingDimensionAlignment })
    }

    func testPromptCoachingQualityPolicy_flagsBusyworkQuestWithoutCalibration() throws {
        let quests = [
            Quest(
                type: .main,
                title: "整理会议纪要排版",
                whyItMatters: "看起来更完整。",
                completionCriteria: "把会议纪要排版好。",
                expectedResistance: "会觉得还有很多要补。",
                reflectionQuestion: "今天感觉如何？",
                calibrationTarget: "这个情况"
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuests(quests)

        XCTAssertTrue(issues.contains { $0.reason == .busyworkQuest })
        XCTAssertTrue(issues.contains { $0.reason == .weakCompletionCriteria })
        XCTAssertTrue(issues.contains { $0.reason == .vagueCalibrationTarget })
    }

    func testPromptCoachingQualityPolicy_flagsQuestWithoutSourceGrounding() throws {
        let quests = [
            Quest(
                type: .main,
                title: "用一次小验收测试返工来源",
                whyItMatters: "它补上返工判断里的证据缺口。",
                completionCriteria: "明天下午前完成一次小范围验收，记录是否减少一轮返工，并写下一个可观察的校准信号。",
                expectedResistance: "你会想先继续推进功能，因为短期看起来更快。",
                reflectionQuestion: "这次验收有没有减少一轮返工？",
                calibrationTarget: "小验收能比继续补说明更有效地减少返工",
                sourceCardTitles: []
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuests(quests)

        XCTAssertTrue(issues.contains { $0.reason == .missingSourceGrounding })
    }

    func testPromptCoachingQualityPolicy_flagsQuestWithoutSelectedLensAlignment() throws {
        let quests = [
            Quest(
                type: .main,
                title: "访谈一个反对方来测试解释",
                whyItMatters: "它可以检查当前解释是否过早收敛。",
                completionCriteria: "明天完成一次 15 分钟访谈，记录一个反方证据和一个可观察的校准信号。",
                expectedResistance: "你会想直接推进当前判断，因为找反方反馈比较慢。",
                reflectionQuestion: "这条反方证据是否推翻了当前解释？",
                calibrationTarget: "返工主要来自对方没有理解当前解释",
                sourceCardTitles: ["会议返工来自低价值任务"]
            )
        ]

        let issues = PromptCoachingQualityPolicy.evaluateQuests(
            quests,
            selectedLens: .leverageAnalysis
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingSelectedLensMove })
    }

    func testPromptCoachingQualityPolicy_flagsWeakVerificationCalibrationNote() throws {
        let result = VerifyQuestResult(
            calibrationNote: "The quest was useful.",
            likelyIssue: nil,
            recommendation: "Keep going."
        )

        let issues = PromptCoachingQualityPolicy.evaluateVerification(
            result,
            targetJudgment: "Written owner acknowledgement reduces ambiguity"
        )

        XCTAssertTrue(issues.contains { $0.reason == .weakVerificationCalibrationNote })
    }

    func testPromptCoachingQualityPolicy_flagsVerificationWithoutCompletionCriteriaEvidence() throws {
        let result = VerifyQuestResult(
            calibrationNote: "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied and the thread became quieter. Evidence gained: written acknowledgement was an observable signal. Judgment update: keep written owner confirmation before execution.",
            likelyIssue: "none",
            recommendation: "Next calibration: test whether earlier owner confirmation reduces rework."
        )

        let issues = PromptCoachingQualityPolicy.evaluateVerification(
            result,
            targetJudgment: "Written owner acknowledgement reduces ambiguity"
        )

        XCTAssertTrue(issues.contains { $0.reason == .weakVerificationCalibrationNote })
    }

    func testPromptCoachingQualityPolicy_flagsWeakVerificationRecommendation() throws {
        let result = VerifyQuestResult(
            calibrationNote: "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
            likelyIssue: "none",
            recommendation: "Keep going."
        )

        let issues = PromptCoachingQualityPolicy.evaluateVerification(
            result,
            targetJudgment: "Written owner acknowledgement reduces ambiguity"
        )

        XCTAssertTrue(issues.contains { $0.reason == .weakVerificationRecommendation })
    }

    func testPromptCoachingQualityPolicy_flagsMissingExpectedPrinciplePracticeAssessment() throws {
        let result = VerifyQuestResult(
            calibrationNote: "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
            likelyIssue: "none",
            recommendation: "Next calibration: test whether earlier owner confirmation reduces rework."
        )

        let issues = PromptCoachingQualityPolicy.evaluateVerification(
            result,
            targetJudgment: "Written owner acknowledgement reduces ambiguity",
            hasTrainingPrinciple: true
        )

        XCTAssertTrue(issues.contains { $0.reason == .missingExpectedPrinciplePracticeAssessment })
    }

    func testPromptCoachingQualityPolicy_flagsUngroundedPrinciple() throws {
        let principle = PrincipleAsset(
            title: "会议前先定义要确认的决策",
            summary: "重要会议前先写清要确认什么、谁负责、什么算完成。",
            triggerContext: "跨角色会议或需要推进协作时。",
            actions: ["写出要确认的决策", "标出负责人", "写出验收标准"],
            successCriteria: "参会者能复述下一步负责人和完成标准。",
            exceptions: "低风险同步会可以只写一句目标。",
            sourceCardTitles: []
        )

        let issues = PromptCoachingQualityPolicy.evaluatePrinciples([principle])

        XCTAssertTrue(issues.contains { $0.reason == .missingPrincipleSourceGrounding })
    }

    func testPromptCoachingQualityPolicy_flagsWeakPrincipleActionability() throws {
        let principle = PrincipleAsset(
            title: "保持清晰",
            summary: "清晰沟通很重要。",
            triggerContext: "工作中需要沟通时。",
            actions: ["做得更好"],
            successCriteria: "事情更顺利。",
            exceptions: "无。",
            sourceCardTitles: ["会议目标不清"]
        )

        let issues = PromptCoachingQualityPolicy.evaluatePrinciples([principle])

        XCTAssertTrue(issues.contains { $0.reason == .weakPrincipleActionability })
    }

    func testPromptEvalReleaseGate_blocksMissingStaleAndFailedRuns() throws {
        let provider = LocalPromptProvider()
        let runner = PromptEvalRunner(promptProvider: provider, parser: parser)
        let passingRuns = runner.runFixedSuite(createdAt: Date(timeIntervalSince1970: 200))

        let passingGate = PromptEvalReleaseGate.evaluate(
            runs: passingRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(passingGate.status, .passed)
        XCTAssertTrue(passingGate.canShipPromptAssets)
        XCTAssertEqual(passingGate.totalPromptCount, PromptID.allCases.count)
        XCTAssertEqual(passingGate.passedPromptCount, PromptID.allCases.count)
        XCTAssertEqual(passingGate.failedPromptCount, 0)
        XCTAssertEqual(passingGate.missingPromptCount, 0)
        XCTAssertEqual(passingGate.stalePromptCount, 0)
        XCTAssertEqual(passingGate.runnerMismatchCount, 0)
        XCTAssertTrue(passingGate.blockingIssues.isEmpty)

        let missingRun = passingRuns.filter { $0.promptId != PromptID.generateQuestions.rawValue }
        let missingGate = PromptEvalReleaseGate.evaluate(
            runs: missingRun,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(missingGate.status, .blocked)
        XCTAssertFalse(missingGate.canShipPromptAssets)
        XCTAssertEqual(missingGate.missingPromptCount, 1)
        XCTAssertTrue(missingGate.blockingIssues.contains { $0.promptId == PromptID.generateQuestions.rawValue && $0.reason == .missingRun })

        var staleRuns = passingRuns
        let staleIndex = try XCTUnwrap(staleRuns.firstIndex { $0.promptId == PromptID.generateQuests.rawValue })
        staleRuns[staleIndex].promptVersion = "quests.old"
        let staleGate = PromptEvalReleaseGate.evaluate(
            runs: staleRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(staleGate.status, .blocked)
        XCTAssertEqual(staleGate.stalePromptCount, 1)
        XCTAssertTrue(staleGate.blockingIssues.contains { $0.promptId == PromptID.generateQuests.rawValue && $0.reason == .staleVersion })

        var failedRuns = passingRuns
        let failedIndex = try XCTUnwrap(failedRuns.firstIndex { $0.promptId == PromptID.extractPrinciple.rawValue })
        failedRuns[failedIndex].caseResults = [
            PromptEvalCaseResult(
                caseId: "principle.behavior_rule_not_slogan",
                name: "Principle is a behavior rule rather than a slogan",
                status: .failed,
                failureReason: "Expected concrete actions."
            )
        ]
        let failedGate = PromptEvalReleaseGate.evaluate(
            runs: failedRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(failedGate.status, .blocked)
        XCTAssertEqual(failedGate.failedPromptCount, 1)
        XCTAssertTrue(failedGate.blockingIssues.contains { $0.promptId == PromptID.extractPrinciple.rawValue && $0.reason == .failedCases })

        var runnerMismatchRuns = passingRuns
        let mismatchIndex = try XCTUnwrap(runnerMismatchRuns.firstIndex { $0.promptId == PromptID.weeklyCalibration.rawValue })
        runnerMismatchRuns[mismatchIndex].runnerVersion = "prompt-eval-runner.old"
        let runnerMismatchGate = PromptEvalReleaseGate.evaluate(
            runs: runnerMismatchRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(runnerMismatchGate.status, .blocked)
        XCTAssertEqual(runnerMismatchGate.runnerMismatchCount, 1)
        XCTAssertTrue(runnerMismatchGate.blockingIssues.contains { $0.promptId == PromptID.weeklyCalibration.rawValue && $0.reason == .runnerMismatch })
    }

    func testPromptEvalReleaseGate_findsRollbackCandidatesFromPassingHistory() throws {
        let provider = RollbackFixturePromptProvider()
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let currentFailedRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: template.version,
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(
                    caseId: "questions.current_failure",
                    name: "Current prompt version failed",
                    status: .failed,
                    failureReason: "Regression in current questions prompt."
                )
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let rollbackTemplate = try XCTUnwrap(
            provider.template(
                for: .generateQuestions,
                mode: .standard,
                version: template.rollbackTargetVersion ?? ""
            )
        )
        let rollbackPassingRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: rollbackTemplate.version,
            systemPolicyVersion: rollbackTemplate.systemPolicyVersion,
            contextPolicyVersion: rollbackTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: rollbackTemplate.outputSchemaVersion,
            evalSuiteVersion: rollbackTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(
                    caseId: "questions.previous_pass",
                    name: "Previous prompt version passed",
                    status: .passed
                )
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let gate = PromptEvalReleaseGate.evaluate(
            runs: [currentFailedRun, rollbackPassingRun],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )

        XCTAssertEqual(gate.status, .blocked)
        XCTAssertEqual(gate.failedPromptCount, 1)
        XCTAssertEqual(gate.rollbackReadyCount, 1)
        XCTAssertEqual(gate.manualReviewCount, PromptID.allCases.count - 1)
        let candidate = try XCTUnwrap(gate.rollbackCandidates.first)
        XCTAssertEqual(candidate.promptId, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(candidate.currentVersion, "1.11.0")
        XCTAssertEqual(candidate.rollbackTargetVersion, "1.10.0")
        XCTAssertEqual(candidate.lastPassingRunId, rollbackPassingRun.id)
        XCTAssertEqual(candidate.reason, .failedCases)
        XCTAssertTrue(gate.blockingIssues.contains {
            $0.promptId == PromptID.generateQuestions.rawValue &&
            $0.reason == .failedCases &&
                $0.rollbackCandidate?.rollbackTargetVersion == "1.10.0"
        })
    }

    func testPromptAssetQualityGate_flagsHighOperationalFailureSignalsAfterMinimumSample() throws {
        let runs = [
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 100)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "upstream failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 101)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "empty result",
                error: "TodayAIParsingError.emptyResult",
                createdAt: Date(timeIntervalSince1970: 102)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "denied result",
                responseJSON: "{}",
                userFeedback: .denied,
                createdAt: Date(timeIntervalSince1970: 103)
            )
        ]
        let summaries = PromptAssetRunQualitySummary.summaries(for: runs)

        let gate = PromptAssetQualityGate.evaluate(
            summaries: summaries,
            policy: PromptAssetQualityGatePolicy(
                minimumSampleCount: 4,
                failureRateThreshold: 0.5,
                emptyResultRateThreshold: 0.25,
                userDenialRateThreshold: 0.25
            )
        )

        XCTAssertEqual(gate.status, .needsReview)
        XCTAssertEqual(gate.needsReviewAssetCount, 1)
        XCTAssertEqual(gate.issueCount, 3)
        XCTAssertEqual(Set(gate.issues.map(\.reason)), [
            .highFailureRate,
            .highEmptyResultRate,
            .highUserDenialRate
        ])
        XCTAssertTrue(gate.issues.allSatisfy {
            $0.promptId == PromptID.generateQuestions.rawValue &&
                $0.promptVersion == "1.0.0" &&
                $0.sampleCount == 4
        })

        let underSampledGate = PromptAssetQualityGate.evaluate(
            summaries: summaries,
            policy: PromptAssetQualityGatePolicy(minimumSampleCount: 5)
        )
        XCTAssertEqual(underSampledGate.status, .passed)
        XCTAssertTrue(underSampledGate.issues.isEmpty)
    }

    func testPromptAssetQualityGate_marksImportedPackRollbackReadyFromPassingEvalHistory() throws {
        let provider = ImportedPromptPackRollbackFixtureProvider()
        let currentTemplate = provider.template(for: .generateQuestions, mode: .standard)
        let currentRuns = [
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 100)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "second success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 101)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "upstream failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 102)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "second upstream failure",
                error: "HTTP 502",
                createdAt: Date(timeIntervalSince1970: 103)
            )
        ]
        let summaries = PromptAssetRunQualitySummary.summaries(for: currentRuns)
        let rollbackTemplate = try XCTUnwrap(provider.template(for: .generateQuestions, mode: .standard, version: "1.0.0"))
        let passingRollbackRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: rollbackTemplate.version,
            promptSourceKind: rollbackTemplate.sourceKind,
            promptPackId: rollbackTemplate.packId,
            promptPackVersion: rollbackTemplate.packVersion,
            promptPackDisplayName: rollbackTemplate.packDisplayName,
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "imported.questions.pass", name: "Imported previous prompt passed", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 90)
        )

        let gate = PromptAssetQualityGate.evaluate(
            summaries: summaries,
            policy: PromptAssetQualityGatePolicy(
                minimumSampleCount: 4,
                failureRateThreshold: 0.5,
                emptyResultRateThreshold: 0.25,
                userDenialRateThreshold: 0.25
            ),
            evalRuns: [passingRollbackRun],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )

        XCTAssertEqual(gate.status, .needsReview)
        XCTAssertEqual(gate.needsReviewAssetCount, 1)
        XCTAssertEqual(gate.rollbackReadyAssetCount, 1)
        XCTAssertEqual(gate.manualReviewAssetCount, 0)
        let issue = try XCTUnwrap(gate.issues.first)
        XCTAssertEqual(issue.reason, .highFailureRate)
        let candidate = try XCTUnwrap(issue.rollbackCandidate)
        XCTAssertEqual(candidate.promptId, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(candidate.currentVersion, "1.1.0")
        XCTAssertEqual(candidate.rollbackTargetVersion, "1.0.0")
        XCTAssertEqual(candidate.promptPackId, "marketplace.prompts.coach")
        XCTAssertEqual(candidate.currentPromptPackVersion, "2026.06")
        XCTAssertEqual(candidate.rollbackPromptPackVersion, "2026.05")
        XCTAssertEqual(candidate.lastPassingRunId, passingRollbackRun.id)
    }

    func testPromptEvalReleaseGate_passesAfterPromptAssetRollbackUsesTargetVersionHistory() throws {
        let provider = AppliedRollbackFixturePromptProvider()
        let template = provider.template(for: .generateQuestions, mode: .standard)
        XCTAssertEqual(template.version, "0.9.0")

        let priorPassingRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "0.9.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.previous_pass", name: "Previous pass", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let supersededFailedRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.current_failure", name: "Current failure", status: .failed)
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let otherRuns = PromptID.allCases
            .filter { $0 != .generateQuestions }
            .map { promptID -> PromptEvalRun in
                let prompt = provider.template(for: promptID, mode: .standard)
                return PromptEvalRun(
                    promptId: promptID.rawValue,
                    promptVersion: prompt.version,
                    systemPolicyVersion: prompt.systemPolicyVersion,
                    contextPolicyVersion: prompt.contextPolicyVersion,
                    inputSchemaVersion: 1,
                    outputSchemaVersion: prompt.outputSchemaVersion,
                    evalSuiteVersion: prompt.evalSuiteVersion,
                    runnerVersion: PromptEvalRunner.currentRunnerVersion,
                    caseResults: [
                        PromptEvalCaseResult(caseId: "\(promptID.rawValue).pass", name: "\(promptID.displayName) pass", status: .passed)
                    ],
                    createdAt: Date(timeIntervalSince1970: 250)
                )
            }

        let gate = PromptEvalReleaseGate.evaluate(
            runs: otherRuns + [priorPassingRun, supersededFailedRun],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )

        XCTAssertEqual(gate.status, .passed)
        XCTAssertEqual(gate.passedPromptCount, PromptID.allCases.count)
        XCTAssertEqual(gate.failedPromptCount, 0)
        XCTAssertEqual(gate.rollbackReadyCount, 0)
    }

    func testPromptEvalSchedulePolicy_runsForMissingOrExpiredHistoryAndSkipsFreshPassingHistory() {
        let provider = LocalPromptProvider()
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = PromptEvalSchedulePolicy(minimumRunInterval: 60)

        let missingDecision = policy.decision(
            runs: [],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            now: now
        )

        XCTAssertTrue(missingDecision.shouldRun)
        XCTAssertEqual(missingDecision.reason, .missingRequiredRun)

        let freshRuns = PromptEvalRunner(promptProvider: provider)
            .runFixedSuite(mode: .standard, createdAt: now.addingTimeInterval(-30))
        let freshDecision = policy.decision(
            runs: freshRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            now: now
        )

        XCTAssertFalse(freshDecision.shouldRun)
        XCTAssertNil(freshDecision.reason)

        let expiredRuns = PromptEvalRunner(promptProvider: provider)
            .runFixedSuite(mode: .standard, createdAt: now.addingTimeInterval(-61))
        let expiredDecision = policy.decision(
            runs: expiredRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            now: now
        )

        XCTAssertTrue(expiredDecision.shouldRun)
        XCTAssertEqual(expiredDecision.reason, .minimumIntervalElapsed)
    }

    private func fixtureData(_ json: String) -> Data {
        Data(json.utf8)
    }
}

private struct RollbackFixturePromptProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        base.template(for: id, mode: mode, version: version)
    }
}

private struct AppliedRollbackFixturePromptProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        if id == .generateQuestions {
            return template(for: id, mode: mode, version: "0.9.0")!
        }
        return base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let template = base.template(for: id, mode: mode)
        guard id == .generateQuestions, version == "0.9.0" else {
            return template.version == version ? template : nil
        }
        return PromptTemplate(
            id: template.id,
            version: "0.9.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            rollbackTargetVersion: nil,
            systemText: template.systemText,
            userText: template.userText,
            outputSchemaVersion: template.outputSchemaVersion
        )
    }
}

private struct ImportedPromptPackRollbackFixtureProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        if id == .generateQuestions {
            return importedTemplate(version: "1.1.0", packVersion: "2026.06", rollbackTargetVersion: "1.0.0")
        }
        return base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        guard id == .generateQuestions else {
            let template = base.template(for: id, mode: mode)
            return template.version == version ? template : nil
        }
        switch version {
        case "1.1.0":
            return importedTemplate(version: "1.1.0", packVersion: "2026.06", rollbackTargetVersion: "1.0.0")
        case "1.0.0":
            return importedTemplate(version: "1.0.0", packVersion: "2026.05", rollbackTargetVersion: nil)
        default:
            return nil
        }
    }

    private func importedTemplate(
        version: String,
        packVersion: String,
        rollbackTargetVersion: String?
    ) -> PromptTemplate {
        let baseTemplate = base.template(for: .generateQuestions, mode: .standard)
        return PromptTemplate(
            id: .generateQuestions,
            version: version,
            systemPolicyVersion: baseTemplate.systemPolicyVersion,
            contextPolicyVersion: baseTemplate.contextPolicyVersion,
            evalSuiteVersion: baseTemplate.evalSuiteVersion,
            rollbackTargetVersion: rollbackTargetVersion,
            sourceKind: .marketplace,
            packId: "marketplace.prompts.coach",
            packVersion: packVersion,
            packDisplayName: "Coach Prompt Pack",
            systemText: baseTemplate.systemText,
            userText: "Imported questions prompt \(version).",
            outputSchemaVersion: baseTemplate.outputSchemaVersion
        )
    }
}
