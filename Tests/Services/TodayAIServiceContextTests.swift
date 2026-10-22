import XCTest
@testable import MingSi

final class TodayAIServiceContextTests: XCTestCase {
    func testCapturedGPTPerspectiveInterpretationIsNotMistakenForFeelingUnderstood() async throws {
        let response = #"""
        {"questions":[{
          "question":"把你希望周五晚上发布，与他希望周一有人能处理问题时再发并排看，你认为双方真正需要协调的是哪一点？",
          "why_this_matters":"界定分歧，能避免把发布时间的争议直接当作对成果的否定。",
          "why_now":"你已区分他说过的话与自己的理解，但尚未界定双方诉求的具体冲突。",
          "expected_update":"更新对这次分歧焦点的判断：成果是否被认可，还是发布安排如何协调。",
          "proceed_when":"按双方已表达的诉求指出一个分歧即可，未表达的动机可以保持未知。",
          "evidence_gap_type":"none", "answer_use":"update_judgment", "lens_move":"alternative_explanation",
          "source_card_titles":["合成场景·new-perspective-oncall"],
          "calibration_target":"同事要求推迟发布是否应被理解为反对我的成果。", "expected_answer_type":"judgment"
        }],"explanation":null}
        """#
        let card = ThinkingCard(type: .decision, title: "合成场景·new-perspective-oncall",
            body: "我希望周五晚上直接发布功能，同事明确说自己周末不值班，希望周一有人能处理问题时再发。我把这理解成他反对我的成果，但我知道他没说过这句话。我想比较我们已说出来的侧重点，不要猜他的真实动机，问我一个问题就好。", isConfirmed: true)
        let client = CapturingLLMClient(response: Data(response.utf8))
        let questions = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            .generateQuestions(for: TodayAIContext(draft: DailyEntryDraft(rawText: card.body, selectedLens: .perspectiveTaking), confirmedCards: [card]))
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions[0].calibrationTarget, "同事要求推迟发布是否应被理解为反对我的成果。")
        XCTAssertEqual(client.requests.count, 1)
        // Genuine reassurance without correction is still blocked independently
        // of a well-formed lens label and a concrete source.
        for target in ["这次分歧里我感觉被理解", "这次分歧里我更有信心继续推进"] {
            var question = questions[0]
            question.question = "你觉得被理解了吗？"
            question.whyItMatters = "让你感觉被理解。"
            question.whyNow = "目前最重要的是你的感受。"
            question.expectedUpdate = "继续按当前判断。"
            question.proceedWhen = "感到有信心即可。"
            question.calibrationTarget = target
            XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .appeasingWithoutCorrection })
        }
    }

    func testCapturedGPTBottleneckComparisonPassesWithoutChangingItsWordingAndStillRejectsInvalidContracts() async throws {
        // Unchanged normalized response from the 2026-10-22 paid baseline.
        let response = #"""
        {"questions":[{
          "question":"在“简化注册”和“调整编辑器配色”之间比较，你目前知道的注册卡点，是两小时内的简化能直接处理的吗？不确定也可以。",
          "why_this_matters":"注册处流失更多，但优先价值还取决于这两小时能否触及实际卡点。",
          "why_now":"你报告四位试用者卡在注册，但尚未说明可做的简化是否对应这些卡点。",
          "expected_update":"判断这两小时是否更值得优先用于简化注册，而非调整配色。",
          "proceed_when":"说明已知卡点与可做简化是否对应；若不知道卡点，明确未知即可。",
          "evidence_gap_type":"missing_causal_link", "answer_use":"choose_action", "lens_move":"leverage_tradeoff",
          "source_card_titles":["合成场景·leverage-onboarding"],
          "calibration_target":"两小时内简化注册，比调整编辑器配色更可能帮助新用户完成首次记录。",
          "expected_answer_type":"judgment"
        }],"explanation":null}
        """#
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
        let card = ThinkingCard(type: .decision, title: "合成场景·leverage-onboarding",
            body: "下周要让新用户更容易完成首次记录。五位试用者中四位卡在注册，进到编辑器的那位顺利记录了。我只有两小时，可以简化注册，也可以调整编辑器配色。帮我比较哪个更值得先做，我愿意回答一个问题。", isConfirmed: true)
        for variant in 0..<5 {
            var object = original
            var questions = try XCTUnwrap(object["questions"] as? [[String: Any]])
            switch variant {
            case 1: questions[0]["source_card_titles"] = ["其他事项"]
            case 2: questions[0]["source_card_titles"] = [String]()
            case 3: questions[0]["calibration_target"] = "这个情况"
            case 4: questions[0]["expected_update"] = ""
            default: break
            }
            object["questions"] = questions
            let client = CapturingLLMClient(response: try JSONSerialization.data(withJSONObject: object))
            do {
                let result = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                    .generateQuestions(for: TodayAIContext(draft: DailyEntryDraft(rawText: card.body, selectedLens: .leverageAnalysis), confirmedCards: [card]))
                XCTAssertEqual(variant, 0, "Invalid contracts must still be rejected")
                XCTAssertEqual(result.first?.question, questions[0]["question"] as? String)
            } catch {
                XCTAssertNotEqual(variant, 0, "Original real response must be admitted unchanged: \(error)")
            }
            XCTAssertEqual(client.requests.count, 1)
        }
    }

    func testDirectExplanationUsesOnlyConfirmedCurrentSources() async throws {
        for title in ["报告晚交两天", "另一件事", "未确认的猜测"] {
            let json: [String: Any] = ["questions": [], "explanation": ["text": "晚交是已知事实，故意不配合仍是推测，原因目前未知。", "source_card_titles": [title]]]
            let client = CapturingLLMClient(response: try JSONSerialization.data(withJSONObject: json))
            let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            let cards = [ThinkingCard(type: .fact, title: "报告晚交两天", body: "晚交两天，请直接解释，不要提问。", isConfirmed: true),
                ThinkingCard(type: .fact, title: "未确认的猜测", body: "猜测", isConfirmed: false)]
            do {
                let generated = try await service.generateQuestionTurnWithTrace(for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: cards[0].body), confirmedCards: cards.filter(\.isConfirmed)))
                XCTAssertEqual(title, "报告晚交两天", "Foreign sources must fail, not silently disappear")
                XCTAssertTrue(generated.value.questions.isEmpty)
                XCTAssertEqual(generated.value.explanation?.sourceCardTitles, [title])
            } catch {
                XCTAssertNotEqual(title, "报告晚交两天", "Valid direct help must reach the caller: \(error)")
            }
            XCTAssertEqual(client.requests.count, 1)
        }
    }


    func testGroundedPerspectiveCanRepresentKnownPrioritiesWithoutAnEvidenceDeficit() async throws {
        let text = "同事说本周只有两人值班，想把演示延后一周。我想按期展示工作。他提出延期让我觉得他不重视我。我愿意想一想双方的侧重点。"
        let response = #"""
        {"questions":[{
          "question":"按同事所说的两人排班，他提出延后一周更可能是在保护哪一项交付要求？",
          "why_this_matters":"读准对方请求，才能比较双方真正的侧重点。",
          "why_now":"你重视按期展示，他提到的是两人排班，双方关注点可以分别表述。",
          "expected_update":"把延期请求看成可能的交付取舍，保留对其态度的判断。",
          "proceed_when":"说出一种可能的交付取舍即可；也可以说暂时想不到。",
          "evidence_gap_type":"none", "answer_use":"update_judgment",
          "lens_move":"alternative_explanation", "source_card_titles":["演示排期"],
          "calibration_target":"延期请求是否必然表示同事不重视我的工作", "expected_answer_type":"judgment"
        }]}
        """#
        let client = CapturingLLMClient(response: Data(response.utf8))
        let card = ThinkingCard(type: .decision, title: "演示排期", body: text, isConfirmed: true)
        let result = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            .generateQuestions(for: TodayAIContext(draft: DailyEntryDraft(rawText: text, selectedLens: .perspectiveTaking), confirmedCards: [card]))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.evidenceGapType, EvidenceGapType.none)
        XCTAssertEqual(result.first?.sourceCardTitles, [card.title])
        XCTAssertEqual(client.requests.count, 1)
        let current = try XCTUnwrap(client.requests.first?.contextPayload?.userChoice.lensCatalog)
        XCTAssertTrue(current.questionStrategy.contains("双方侧重点"))
        var saved = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        saved["version"] = "builtin.v2"
        saved.removeValue(forKey: "packVersion")
        saved["purpose"] = "准确理解另一方表达与处境，区分理解、认同和替对方找理由。"
        let restored = try JSONDecoder().decode(PromptContextPayload.LensCatalogContext.self,
            from: JSONSerialization.data(withJSONObject: saved))
        XCTAssertEqual(restored.version, "builtin.v2")
        XCTAssertEqual(restored.packVersion, "builtin.v2")
        XCTAssertEqual(restored.purpose, saved["purpose"] as? String)
    }

    func testFramingWithoutEvidenceDeficitStillRequiresSourceAndSpecificJudgment() {
        var question = ReflectionQuestion(question: "按这次排班，他提出延期更可能是在保护哪项交付要求？", whyItMatters: "读准请求。",
            whyNow: "双方关注点可以分别表述。", expectedUpdate: "比较两种可能的交付取舍。", proceedWhen: "表达一种可能，也允许暂时想不到。",
            evidenceGapType: EvidenceGapType.none, answerUse: .updateJudgment, lensMove: .alternativeExplanation,
            sourceCardTitles: ["演示排期"], calibrationTarget: "延期请求是否必然表示同事不重视我的工作")
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question], selectedLens: .perspectiveTaking,
            allowedSourceCardTitles: ["演示排期"]).isEmpty)
        question.sourceCardTitles = ["另一件事"]
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question], selectedLens: .perspectiveTaking,
            allowedSourceCardTitles: ["演示排期"]).contains { $0.reason == .invalidSourceGrounding })
        question.sourceCardTitles = []
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .missingThinkingMaterialTarget })
        question.sourceCardTitles = ["演示排期"]
        question.calibrationTarget = "这个情况"
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .missingThinkingMaterialTarget })
        question.calibrationTarget = "延期请求是否必然表示同事不重视我的工作"
        question.expectedUpdate = ""
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .missingFunctionalCoachField })
    }


    func testCapturedExpandedLensResponsesPassWithoutRewordingOrPaidRetry() async throws {
        let scenarios: [(ThinkingLens, String, String)] = [
            (.controlBoundary, "今天公共交通停运，我无法保证准点到达。我已经知道可以提前告知并改线上，但一直纠结领导会不会生气。我愿意分清自己能决定和不能决定的部分，请围绕这一点问一个问题，不要把他人的反应算成我的责任。", #"""
            {
              "questions": [
                {
                  "question": "即使领导仍然生气，在“提前告知、改线上”这件事上，你认为自己能决定并负责的部分到哪里为止？",
                  "why_this_matters": "明确责任边界，避免把他人的情绪当成自己必须保证的结果。",
                  "why_now": "你已知道可选做法，但对领导反应的担忧仍未与自己的责任分开。",
                  "expected_update": "明确是否能用自己可控的沟通行为，而非领导是否生气，判断是否尽责。",
                  "proceed_when": "说清自己能决定的部分即可；领导会怎样反应可以仍然未知。",
                  "evidence_gap_type": "missing_constraint",
                  "answer_use": "update_judgment",
                  "lens_move": "constraint_decomposition",
                  "source_card_titles": ["可控边界合成验收"],
                  "calibration_target": "这次沟通是否尽责，应以自己可控的行为还是领导的情绪反应为判断标准。",
                  "expected_answer_type": "judgment"
                }
              ]
            }
            """#),
            (.perspectiveTaking, "同事原话是这周人手不足，想把演示延后一周。我理解成他根本不重视我的工作，但他没有说过这句话。我想更准确地理解双方差别，愿意回答一个区分已知表达和推测的问题，不要替他猜真实动机。", #"""
            {
              "questions": [
                {
                  "question": "在你已经知道的言行中，除了这次提出延期，还有什么具体依据支持“他根本不重视我的工作”这一判断？如果没有或不确定，也可以直接说明。",
                  "why_this_matters": "这能区分延期请求与对工作重视程度的判断，避免把两者直接等同。",
                  "why_now": "你已分清原话与推测，但尚未说明这一推测是否有其他依据。",
                  "expected_update": "决定是否保留“他根本不重视我的工作”的判断，或将其暂列为未证实的解释。",
                  "proceed_when": "指出一条已知的具体依据，或说明没有其他依据、目前不确定即可。",
                  "evidence_gap_type": "missing_causal_link",
                  "answer_use": "update_judgment",
                  "lens_move": "alternative_explanation",
                  "source_card_titles": ["换位理解合成验收"],
                  "calibration_target": "同事提出延期意味着他根本不重视我的工作。",
                  "expected_answer_type": "fact"
                }
              ]
            }
            """#),
            (.reversibleDecision, "我在考虑加入朋友的周末项目。我知道可以先按周参与，退出要提前一周说，不需要投钱；长期承诺的时间成本还不清楚。我愿意检查承诺边界，请问一个能用这些已知条件想清的问题，不要让我先试验。", #"""
            {
              "questions": [
                {
                  "question": "只看“退出需提前一周告知”这一条，它是否超出了你愿意为这个项目承担的时间安排约束？",
                  "why_this_matters": "可以退出，不等于退出条件对你而言可以接受。",
                  "why_now": "你已说明退出规则，但尚未说明这条规则是否符合你的承诺边界。",
                  "expected_update": "判断是否接受这条已知退出条件，而不是直接决定是否长期加入。",
                  "proceed_when": "说明可接受、不可接受，或因具体时间占用未知而暂时无法判断即可。",
                  "evidence_gap_type": "missing_constraint",
                  "answer_use": "choose_action",
                  "lens_move": "constraint_decomposition",
                  "source_card_titles": [
                    "可逆决策合成验收"
                  ],
                  "calibration_target": "退出需提前一周告知，是否在我愿意接受的时间安排约束内。",
                  "expected_answer_type": "judgment"
                }
              ]
            }
            """#),
            (.opportunityCost, "周末只剩半天。我想接一个付费兼职，也想陪父母吃饭，两件事都对我重要，时间确实冲突。我愿意比较这两个选择，请用一个问题帮我看清取舍，不要替我排序，也不要安排任务。", #"""
            {
              "questions": [
                {
                  "question": "如果这半天只能选一件，就你已知的情况，错过这次付费兼职与错过这顿陪父母的饭，哪一种损失更难在之后弥补？",
                  "why_this_matters": "比较放弃各自意味着什么，能避免只看所选一方的好处。",
                  "why_now": "你已明确两件事都重要且时间冲突，但尚未比较放弃各自的代价。",
                  "expected_update": "帮助你判断这半天更愿意留给兼职还是陪父母吃饭，不预设哪项优先。",
                  "proceed_when": "说明哪种损失更难弥补及理由即可；同样难弥补或暂不清楚也可以。",
                  "evidence_gap_type": "missing_constraint",
                  "answer_use": "choose_action",
                  "lens_move": "leverage_tradeoff",
                  "source_card_titles": [
                    "机会成本合成验收"
                  ],
                  "calibration_target": "这半天选择兼职或陪父母吃饭时，哪一方被放弃的价值更难在之后弥补。",
                  "expected_answer_type": "tradeoff"
                }
              ]
            }
            """#)
        ]
        for (lens, body, exactAssistantText) in scenarios {
            let wire = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": exactAssistantText]]]])
            let client = CapturingLLMClient(response: wire)
            let card = ThinkingCard(type: .decision, title: lens.title + "合成验收", body: body, isConfirmed: true)
            let result = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                .generateQuestions(for: TodayAIContext(draft: DailyEntryDraft(rawText: body, selectedLens: lens), confirmedCards: [card]))
            XCTAssertEqual(result.count, 1)
            let raw = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(exactAssistantText.utf8)) as? [String: Any])
            let original = try XCTUnwrap((raw["questions"] as? [[String: Any]])?.first)
            XCTAssertEqual(result.first?.question, original["question"] as? String)
            XCTAssertEqual(result.first?.proceedWhen, original["proceed_when"] as? String)
            XCTAssertEqual(result.first?.sourceCardTitles, [card.title])
            XCTAssertEqual(client.requests.count, 1)
        }
    }

    func testBoundaryMaterialGateStillRequiresGroundingAndSpecificTarget() {
        var question = ReflectionQuestion(question: "自己的责任到哪里为止？", whyItMatters: "明确责任边界。",
            whyNow: "担忧仍与责任混在一起。", expectedUpdate: "区分自己的行为和他人的反应。",
            proceedWhen: "说清自己能决定的部分即可。", evidenceGapType: .missingConstraint,
            answerUse: .updateJudgment, lensMove: .constraintDecomposition,
            sourceCardTitles: ["出行受阻"], calibrationTarget: "是否把领导情绪当作自己尽责的标准")
        XCTAssertFalse(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .missingThinkingMaterialTarget })
        question.sourceCardTitles = []
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .missingThinkingMaterialTarget })
        question.sourceCardTitles = ["出行受阻"]
        question.calibrationTarget = "这个情况"
        XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question]).contains { $0.reason == .missingThinkingMaterialTarget })
    }

    func testExpandedLensesCarryTheirOwnBoundaryAndDoNotForceQuestions() async throws {
        for lens in [ThinkingLens.opportunityCost, .reversibleDecision, .perspectiveTaking, .controlBoundary] {
            let client = CapturingLLMClient(response: Data("{\"questions\":[]}".utf8))
            let draft = DailyEntryDraft(rawText: "只看已有材料，原因可以未知。", selectedLens: lens)
            let result = try await TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
                .generateQuestions(for: TodayAIContext(draft: draft))
            XCTAssertTrue(result.isEmpty, "Selecting a lens must not force a question")
            let payload = try XCTUnwrap(client.requests.first?.contextPayload)
            let item = try XCTUnwrap(payload.userChoice.lensCatalog)
            XCTAssertEqual(item.localId, lens.rawValue)
            XCTAssertEqual(item.promptId, lens.catalogItem.promptId)
            XCTAssertEqual(item.promptGuidance, lens.catalogItem.promptGuidance)
            XCTAssertEqual(item.disableConditions, lens.catalogItem.disableConditions)
            XCTAssertEqual(item.packVersion, "builtin.v3")
            XCTAssertEqual(payload.userChoice.selectedLens, lens.rawValue)
            XCTAssertEqual(client.requests.count, 1)
        }
    }

    func testExpandedLensQualityGateUsesTheIntendedMoveWithoutChangingOldMoves() {
        let pairs: [(ThinkingLens, QuestionLensMove)] = [(.opportunityCost, .leverageTradeoff),
            (.reversibleDecision, .constraintDecomposition), (.perspectiveTaking, .alternativeExplanation),
            (.controlBoundary, .constraintDecomposition)]
        for (lens, move) in pairs {
            var question = ReflectionQuestion(question: "哪一部分是你可以选择的？", whyItMatters: "明确这一处判断的边界。",
                lensMove: move, sourceCardTitles: ["当前事项"], calibrationTarget: "这一部分可以选择")
            XCTAssertFalse(PromptCoachingQualityPolicy.evaluateQuestions([question], selectedLens: lens)
                .contains { $0.reason == .missingSelectedLensMove })
            question.lensMove = .predictionCalibration
            XCTAssertTrue(PromptCoachingQualityPolicy.evaluateQuestions([question], selectedLens: lens)
                .contains { $0.reason == .missingSelectedLensMove })
        }
        XCTAssertEqual(Set(LensGroup.allCases.flatMap(\.lenses)), Set(ThinkingLens.allCases))
        XCTAssertEqual(LensGroup.allCases.flatMap(\.lenses).count, ThinkingLens.allCases.count)
    }

    func testExplicitNoActionIsAValidCoachingOutcomeWithUnresolvedMaterial() async throws {
        let client = CapturingLLMClient(response: Data(#"{"main_quest":null,"side_quests":[],"observation_quest":null}"#.utf8))
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let quests = try await service.generateQuests(for: TodayAIContext(
            draft: DailyEntryDraft(rawText: "这次只想保留这段复盘，不想安排后续任务。"),
            coachTurnState: CoachTurnState(phase: .fillEvidenceGap, readiness: .notReady,
                recommendedMove: .surfaceEvidenceGap, reason: "没有进一步的可观察材料。",
                openEvidenceGaps: [.missingObservation], baselineChecks: [.evidenceGap],
                decisionSource: .coachRecommended, policyVersion: CoachTurnPolicy.policyVersion,
                turnSummary: "允许保留未知。")
        ))
        XCTAssertTrue(quests.isEmpty)
        XCTAssertEqual(client.requests.count, 1)
    }

    // Exact normalized assistant body from the first 1.12.0 real call. The
    // transport succeeded; the old local verb whitelist incorrectly rejected it.
    func testActionClarityCapturedNaturalRetryPassesWithoutNewArtifactOrDeadline() async throws {
        let response = #"""
        {
          "main_quest": {
            "type": "main",
            "title": "等自然重试时观察这位朋友的提交结果",
            "why_it_matters": "据你所述，日志显示提交前断网，但尚不能确定退出原因；这次结果也不能单独证明说明清楚或不清楚。",
            "completion_criteria": "若这位朋友自然重试，观察网络已恢复且说明未变时，提交是否成功；未重试、网络状态不明或说明已变，则结果仍未知。",
            "expected_resistance": "只等自然机会，不催促朋友，不改说明，不做沟通训练。",
            "reflection_question": "这次结果支持、削弱还是仍无法判断该预测，哪些观察条件限制了判断？",
            "calibration_target": "这位朋友在网络恢复、说明不变时再次提交，可能成功。",
            "lens_move": "prediction_calibration",
            "linked_cards": [
              "先观察恢复网络后的提交"
            ]
          },
          "side_quests": [],
          "observation_quest": null,
          "rejected_low_value_tasks": []
        }
        """#
        let client = CapturingLLMClient(response: Data(response.utf8))
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let card = ThinkingCard(type: .decision, title: "先观察恢复网络后的提交",
            body: "一位朋友填写页面时退出，我原先怀疑说明不清。后来日志确认他在提交前断网了；还不知道恢复网络后能否提交。我不想重写说明，也不想做沟通训练。愿意下次只看这位朋友网络恢复后的提交结果，保持说明不变。", isConfirmed: true)
        let quests = try await service.generateQuests(for: TodayAIContext(draft: DailyEntryDraft(rawText: card.body), confirmedCards: [card]))
        let quest = try XCTUnwrap(quests.first)
        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quest.completionCriteria, "若这位朋友自然重试，观察网络已恢复且说明未变时，提交是否成功；未重试、网络状态不明或说明已变，则结果仍未知。")
        XCTAssertEqual(quest.expectedResistance, "只等自然机会，不催促朋友，不改说明，不做沟通训练。")
        XCTAssertEqual(client.requests.count, 1)
    }

    func testOrganizeCards_doesNotInjectPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let principle = PrincipleAsset(
            title: "Clarify before meetings",
            summary: "Write decisions before meeting.",
            triggerContext: "meeting",
            actions: ["Write decision list"],
            successCriteria: "People know next actions.",
            exceptions: "Casual sync"
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "meeting ownership was unclear"),
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = request.contextPayload?.legacyKeyValues ?? [:]
        XCTAssertNil(legacy["relevantPrinciples"])
        XCTAssertFalse(request.contextRecordIDs.contains(principle.id.uuidString))
        XCTAssertEqual(request.contextVersion, 1)
    }

    func testOrganizeCards_exposesStructuredContextPayloadWithoutPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let principle = PrincipleAsset(
            title: "Clarify before meetings",
            summary: "Write decisions before meeting.",
            triggerContext: "meeting",
            actions: ["Write decision list"],
            successCriteria: "People know next actions.",
            exceptions: "Casual sync"
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "meeting ownership was unclear",
                    sessionMode: .quick
                ),
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.currentInput.rawText, "meeting ownership was unclear")
        XCTAssertEqual(payload.userChoice.sessionMode, SessionMode.quick.rawValue)
        XCTAssertTrue(try XCTUnwrap(payload.privacy.rules).contains("confidential"))
        XCTAssertTrue(payload.principles.isEmpty)
    }

    func testOrganizeCards_doesNotInjectCoachDiagnosis() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let diagnosis = CoachDiagnosis(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .slowDownConvergence,
            reason: "证据不足，先补证据。",
            source: .coachRecommended,
            policyVersion: CoachEngine.policyVersion
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "验收口径不清。"),
                coachDiagnosis: diagnosis
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertNil(payload.coachDiagnosis)
        XCTAssertNil(payload.legacyKeyValues["coachThinkingPhase"])
        XCTAssertNil(payload.legacyKeyValues["coachDiagnosisSource"])
        XCTAssertNil(payload.legacyKeyValues["coachDiagnosisRule"])
    }

    func testOrganizeCards_doesNotInjectCoachTurnState() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "证据不足，先补证据。",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Turn 1: identify the missing observation."
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "验收口径不清。"),
                coachTurnState: turn
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertNil(payload.coachTurnState)
        XCTAssertNil(payload.legacyKeyValues["coachTurnPhase"])
        XCTAssertNil(payload.legacyKeyValues["coachTurnRule"])
    }

    func testOrganizeCards_doesNotInjectCoachObservation() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .decision,
            title: "验收口径不清",
            body: "会议里团队讨论方案返工，我认为原因是验收口径不清，但还缺少事实支撑。",
            isConfirmed: true
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "验收口径不清。"),
                confirmedCards: [card]
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.coachObservation)
        XCTAssertNil(payload.legacyKeyValues["coachObservationPrimaryGap"])
        XCTAssertNil(payload.legacyKeyValues["coachObservationRule"])
    }

    func testLegacyPatternDiagnosisCannotEnterAnyProductionPrompt() throws {
        let sourceID = UUID().uuidString
        let summary = CoachPatternSummary(
            policyVersion: CoachPatternSummaryPolicy.policyVersion,
            analyzedRecordCount: 3,
            totalSignalCount: 3,
            sourceDailyEntryIds: [sourceID],
            topPatterns: [
                CoachPatternSignal(
                    primaryGap: .evidenceGap,
                    foundationalAbility: .thinking,
                    count: 2,
                    latestDate: Date(timeIntervalSince1970: 300),
                    minimalTrainingAction: "补一个可观察事实。"
                )
            ],
            guidanceLine: "历史只作为提示：最近常见的是证据不足。"
        )
        let context = TodayAIContext(
            draft: DailyEntryDraft(rawText: "我觉得方案不可行。"),
            coachPatternSummary: summary
        )
        let assembler = DefaultContextAssembler()

        let questionsContext = assembler.assemble(promptID: .generateQuestions, context: context)
        XCTAssertNil(questionsContext.contextPayload.coachPatternSummary)
        XCTAssertNil(questionsContext.contextPayload.legacyKeyValues["coachPatternSummaryRule"])
        XCTAssertFalse(questionsContext.contextRecordIDs.contains(sourceID))

        let questsContext = assembler.assemble(promptID: .generateQuests, context: context)
        XCTAssertNil(questsContext.contextPayload.coachPatternSummary)
        XCTAssertNil(questsContext.contextPayload.legacyKeyValues["coachPatternSummaryTopGaps"])
        XCTAssertFalse(questsContext.contextRecordIDs.contains(sourceID))
        XCTAssertNil(questsContext.contextPayload.legacyKeyValues["coachPatternSummaryRule"])

        for promptID in PromptID.allCases {
            let payload = assembler.assemble(promptID: promptID, context: context)
            XCTAssertNil(payload.contextPayload.coachPatternSummary, promptID.rawValue)
            XCTAssertNil(payload.contextPayload.legacyKeyValues["coachPatternSummaryRule"], promptID.rawValue)
            XCTAssertFalse(payload.contextRecordIDs.contains(sourceID), promptID.rawValue)
        }

        let organizeContext = assembler.assemble(promptID: .organizeCards, context: context)
        XCTAssertNil(organizeContext.contextPayload.coachPatternSummary)
        XCTAssertNil(organizeContext.contextPayload.legacyKeyValues["coachPatternSummaryRule"])
        XCTAssertFalse(organizeContext.contextRecordIDs.contains(sourceID))
    }

    func testOrganizeCards_doesNotInjectCoachContextMemory() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
            recommendationReason: "历史教练建议不应该影响原始事实拆解。",
            confidence: 0.8,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.opposingView.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            finalLensId: ThinkingLens.evidenceCheck.rawValue,
            source: .coachRecommended
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "今天先记录原始事实，不套历史结论。"),
                lensFeedback: [
                    Self.lensFeedback(
                        lens: .evidenceCheck,
                        signal: "reinforce",
                        target: "旧目标"
                    )
                ],
                trainingPrescription: prescription
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertNil(payload.trainingPrescription)
        XCTAssertTrue(payload.lensFeedback.isEmpty)
        XCTAssertNil(payload.legacyKeyValues["coachRecommendedLens"])
        XCTAssertNil(payload.legacyKeyValues["lensFeedback"])
    }

    func testPromptContextPayloadEncodingOmitsUnstructuredExtraDictionary() throws {
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: "entry-structured", rawText: "typed source"),
            userChoice: .init(sessionMode: SessionMode.deep.rawValue),
            privacy: .init(rules: "typed privacy")
        )

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["extra"])
        XCTAssertEqual(object["currentInput"] as? [String: String], [
            "dailyEntryId": "entry-structured",
            "rawText": "typed source"
        ])
    }

    func testStreamOrganizedCards_yieldsDraftUpdatesAndReturnsDomainCards() async throws {
        let client = StreamingCapturingLLMClient(tokens: [
            "<MINGSI_STREAM version=\"1\"><CARD><TYPE>problem</TYPE><TITLE>",
            "会议目标不清楚</TITLE><BODY>会前没有列出必须确认的问题。</BODY>",
            "<IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>影响结论质量</REASON></CARD></MINGSI_STREAM>"
        ])
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        var updates: [[StreamingCardDraft]] = []

        let cards = try await service.streamOrganizedCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "今天开会但目标不清楚。",
                    sessionMode: .standard,
                    hasSelectedSessionMode: true
                )
            ),
            onUpdate: { drafts in updates.append(drafts) }
        )

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "会议目标不清楚")
        XCTAssertEqual(cards[0].priority, .high)
        XCTAssertFalse(updates.isEmpty)
        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["streamProtocol"], "MINGSI_STREAM_V2")
    }

    func testGenerateQuestions_usesStreamingClientWhenAvailable() async throws {
        let client = StreamingCapturingLLMClient(tokens: [
            #"{"questions":["#,
            #"{"question":"哪个可观察信号能证明这个判断需要更新？","#,
            #""why_this_matters":"把判断变成可以校准的训练。","#,
            #""why_now":"当前材料已经有判断，但缺少未来校准信号。","#,
            #""expected_update":"补上判断更新所需的结果信号。","#,
            #""proceed_when":"能说出一个明天可观察的校准信号。","#,
            #""evidence_gap_type":"missing_calibration_signal","#,
            #""answer_use":"watch_calibration_signal","#,
            #""lens_move":"prediction_calibration","#,
            #""source_card_titles":["优先改注册流程"],"#,
            #""calibration_target":"优先改注册流程能改善新用户首次使用"}"#,
            #"]}"#
        ])
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let questions = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "我判断应该优先改注册流程。",
                    sessionMode: .standard,
                    hasSelectedSessionMode: true
                ),
                confirmedCards: [
                    ThinkingCard(
                        type: .decision,
                        title: "优先改注册流程",
                        body: "我判断应该优先改注册流程，标准是影响新用户首次使用。"
                    )
                ]
            )
        )

        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(client.streamRequestCount, 1)
        XCTAssertEqual(client.completeRequestCount, 0)
    }

    func testGenerateQuestions_forwardsStreamProgressBeforeTheFinalJSONIsParsed() async throws {
        let client = StreamingCapturingLLMClient(tokens: [
            #"{"questions":[{"question":"补上一个可观察事实"}]}"#
        ])
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        var progress: [LLMStreamEvent] = []

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(
                        rawText: "我判断应该优先改注册流程。",
                        sessionMode: .standard,
                        hasSelectedSessionMode: true
                    )
                ),
                onProgress: { event in
                    progress.append(event)
                }
            )
        } catch {
            // The fixture is intentionally minimal; this test is about event delivery before parsing.
        }

        XCTAssertEqual(progress, [.token(#"{"questions":[{"question":"补上一个可观察事实"}]}"#), .completed])
    }

    func testOrganizeCardsPrompt_usesStreamingXMLInstructions() {
        let template = LocalPromptProvider().template(for: .organizeCards, mode: .standard)

        XCTAssertTrue(template.systemText.contains("MINGSI_STREAM_V2"))
        XCTAssertFalse(template.systemText.contains("Return valid JSON only"))
        XCTAssertTrue(template.userText.contains("<CARD>"))
        XCTAssertTrue(template.userText.contains("</CARD>"))
    }

    func testGrowthAIService_exposesStructuredGrowthContextPayload() async throws {
        let entryID = UUID()
        let client = CapturingLLMClient(response: Self.growthReportResponse(entryID: entryID))
        let previousSnapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.2,
            valueJudgment: 3.1,
            executionReliability: 3.0,
            calibration: 2.9,
            reflectionDepth: 3.3,
            summary: "previous",
            positiveContributionRefs: ["previous-positive"],
            completeLoopCount: 3
        )
        let service = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateWeeklyReport(
            context: GrowthReportContext(
                period: "weekly",
                startDate: nil,
                endDate: nil,
                completeLoopCount: 3,
                historyRecords: [
                    GrowthRecordSummary(
                        dailyEntryId: entryID,
                        date: Date(timeIntervalSince1970: 0),
                        confirmedCardCount: 2,
                        hasMainQuest: true,
                        mainQuestTitle: "Prepare meeting decision list",
                        mainQuestCompletionCriteria: "Decision list sent before meeting",
                        verificationCompletion: "done",
                        verificationValueRating: "high",
                        calibrationNote: "Prepared agenda reduced meeting drift.",
                        hasLensSessionAnswers: true,
                        principleTitles: ["Clarify before meeting"]
                    )
                ],
                previousSnapshot: previousSnapshot,
                dismissedContributionTitles: ["Overstated clarity gain"]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let growth = try XCTUnwrap(payload.growth)
        XCTAssertEqual(growth.period, "weekly")
        XCTAssertEqual(growth.completeLoopCount, 3)
        XCTAssertEqual(growth.records.map(\.dailyEntryId), [entryID.uuidString])
        XCTAssertEqual(growth.records.map(\.mainQuestTitle), ["Prepare meeting decision list"])
        XCTAssertEqual(growth.records.map(\.principleTitles), [["Clarify before meeting"]])
        XCTAssertEqual(growth.previousSnapshot?.clarity, 3.2)
        XCTAssertEqual(growth.dismissedContributionTitles, ["Overstated clarity gain"])
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["period"], "weekly")
        XCTAssertEqual(legacy["record_count"], "1")
        XCTAssertEqual(legacy["complete_loop_count"], "3")
        XCTAssertEqual(legacy["previous_clarity"], "3.2")
        XCTAssertEqual(legacy["previous_reflection_depth"], "3.3")
        XCTAssertEqual(legacy["dismissed_contributions"], "Overstated clarity gain")
        XCTAssertTrue(try XCTUnwrap(legacy["evidence_summaries"]).contains(entryID.uuidString))
    }

    func testGrowthAIService_usesStructuredContextAsLegacyPayloadSource() async throws {
        let entryID = UUID()
        let client = CapturingLLMClient(response: Self.growthReportResponse(entryID: entryID))
        let service = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateWeeklyReport(
            context: GrowthReportContext(
                period: "weekly",
                startDate: nil,
                endDate: nil,
                completeLoopCount: 3,
                historyRecords: [
                    GrowthRecordSummary(
                        dailyEntryId: entryID,
                        date: Date(timeIntervalSince1970: 0),
                        confirmedCardCount: 2,
                        hasMainQuest: true,
                        mainQuestTitle: "Prepare meeting decision list",
                        mainQuestCompletionCriteria: "Decision list sent before meeting",
                        verificationCompletion: "done",
                        verificationValueRating: "high",
                        calibrationNote: "Prepared agenda reduced meeting drift.",
                        hasLensSessionAnswers: true,
                        principleTitles: ["Clarify before meeting"]
                    )
                ],
                previousSnapshot: nil,
                dismissedContributionTitles: ["Overstated clarity gain"]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertNotNil(payload.growth)
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["period"], "weekly")
        XCTAssertEqual(legacy["dismissed_contributions"], "Overstated clarity gain")
    }

    func testGrowthAIService_omitsPreviousScoresWhenSnapshotIsInsufficientEvidence() async throws {
        let entryID = UUID()
        let client = CapturingLLMClient(response: Self.growthReportResponse(entryID: entryID))
        let service = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let insufficientSnapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.2,
            valueJudgment: 3.1,
            executionReliability: 3.0,
            calibration: 2.9,
            reflectionDepth: 3.3,
            summary: "not enough evidence",
            status: .insufficientEvidence,
            completeLoopCount: 1
        )

        _ = try await service.generateWeeklyReport(
            context: GrowthReportContext(
                period: "weekly",
                startDate: nil,
                endDate: nil,
                completeLoopCount: 3,
                historyRecords: [
                    GrowthRecordSummary(
                        dailyEntryId: entryID,
                        date: Date(timeIntervalSince1970: 0),
                        confirmedCardCount: 2,
                        hasMainQuest: true,
                        mainQuestTitle: "Prepare meeting decision list",
                        mainQuestCompletionCriteria: "Decision list sent before meeting",
                        verificationCompletion: "done",
                        verificationValueRating: "high",
                        calibrationNote: nil,
                        hasLensSessionAnswers: true,
                        principleTitles: []
                    )
                ],
                previousSnapshot: insufficientSnapshot,
                dismissedContributionTitles: []
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertNil(payload.growth?.previousSnapshot)
        XCTAssertNil(legacy["previous_clarity"])
        XCTAssertNil(legacy["previous_reflection_depth"])
    }

    func testGenerateQuestions_injectsRelevantPrinciplesAndContextIds() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let relevantPrinciple = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )
        let unrelatedPrinciple = PrincipleAsset(
            title: "Protect deep work",
            summary: "Batch shallow notifications.",
            triggerContext: "focus time",
            actions: ["Mute notifications"],
            successCriteria: "One uninterrupted block.",
            exceptions: "Urgent incident"
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [relevantPrinciple, unrelatedPrinciple]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        let relevantPrinciples = try XCTUnwrap(legacy["relevantPrinciples"])
        XCTAssertTrue(relevantPrinciples.contains("Clarify meeting ownership"))
        XCTAssertFalse(relevantPrinciples.contains("Protect deep work"))
        XCTAssertTrue(request.contextRecordIDs.contains(relevantPrinciple.id.uuidString))
        XCTAssertFalse(request.contextRecordIDs.contains(unrelatedPrinciple.id.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(card.id.uuidString))
        XCTAssertTrue(request.inputSummary.contains("principles=Clarify meeting ownership"))
        XCTAssertTrue(
            try XCTUnwrap(request.contextPayload?.directives.principleSelectionRule)
                .contains("final decision maker")
        )
    }

    func testGenerateQuestions_exposesStructuredContextPayloadWithCardsLensModeAndPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let relevantPrinciple = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )
        let inactivePrinciple = PrincipleAsset(
            title: "Archived meeting checklist",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .archived
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    sessionMode: .deep,
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [relevantPrinciple, inactivePrinciple]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.cards.map(\.title), ["Meeting ownership unclear"])
        XCTAssertEqual(payload.cards.map(\.body), ["The meeting ended without owner and acceptance criteria."])
        XCTAssertEqual(payload.userChoice.selectedLens, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(payload.userChoice.sessionMode, SessionMode.deep.rawValue)
        XCTAssertEqual(payload.principles.map(\.title), ["Clarify meeting ownership"])
        XCTAssertEqual(payload.principles.map(\.retrievalPolicyVersion), [LocalPrincipleRetriever.policyVersion])
        XCTAssertEqual(payload.principles.map(\.retrievalSignal), ["meeting ownership"])
        XCTAssertTrue(try XCTUnwrap(payload.principles.first?.retrievalReason).contains("meeting ownership"))
        XCTAssertFalse(payload.principles.map(\.title).contains("Archived meeting checklist"))
    }

    func testStructuredContextPayload_keepsLegacyCompatibilityExportForDirectGLM() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let principle = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    sessionMode: .standard,
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertTrue(try XCTUnwrap(legacy["confirmedCards"]).contains("Meeting ownership unclear"))
        XCTAssertEqual(legacy["selectedLens"], "evidence_check")
        XCTAssertEqual(legacy["sessionMode"], SessionMode.standard.rawValue)
        XCTAssertTrue(try XCTUnwrap(legacy["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(try XCTUnwrap(legacy["principleUsageRule"]).contains("Do not force"))
    }

    // MARK: - Subtask 042: Lens Prompt Context Wiring

    func testGenerateQuestions_sendsPromptFacingLensId_forFirstPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.firstPrinciplesQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What are the fundamentals?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["selectedLens"], "first_principles")
    }

    func testGenerateQuests_sendsPromptFacingLensId_forLeverageAnalysis() async throws {
        let client = CapturingLLMClient(response: Self.questsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What is the leverage point?",
                    selectedLens: .leverageAnalysis
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["selectedLens"], "leverage_analysis")
    }

    func testStructuredContext_exposesLocalSelectedLens_forFirstPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.firstPrinciplesQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What are the fundamentals?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.selectedLens, .firstPrinciples)
    }

    func testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.firstPrinciplesQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What are the fundamentals?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let catalog = try XCTUnwrap(payload.userChoice.lensCatalog)
        XCTAssertEqual(catalog.localId, "firstPrinciples")
        XCTAssertEqual(catalog.promptId, "first_principles")
        XCTAssertEqual(catalog.version, "builtin.v3")
        XCTAssertEqual(catalog.title, "第一性原理")
        XCTAssertTrue(catalog.promptGuidance.contains("non-negotiable facts"))
        XCTAssertTrue(catalog.purpose.contains("必要条件"))
        XCTAssertTrue(catalog.questionStrategy.contains("硬约束"))
        XCTAssertTrue(catalog.taskSelectionRule.contains("用户主动"))
        XCTAssertTrue(catalog.applicability.contains("规则"))
        XCTAssertTrue(catalog.disableConditions.contains { $0.contains("已知现实限制") })
        XCTAssertEqual(catalog.uiMetadata.symbolName, "square.stack.3d.down.right")
        XCTAssertEqual(catalog.uiMetadata.accentRole, .principle)
        XCTAssertEqual(catalog.uiMetadata.methodIndex, 4)
        XCTAssertEqual(catalog.sourceKind, .builtin)
        XCTAssertEqual(catalog.packId, "mingsi.builtin.lenses")
        XCTAssertEqual(catalog.packVersion, "builtin.v3")
        XCTAssertEqual(catalog.packDisplayName, "MingSi Built-in Lens Pack")
    }

    func testStructuredContext_exposesLensCatalogMetadata_forSystemThinking() async throws {
        let client = CapturingLLMClient(response: Self.systemThinkingQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "临时修复越来越多，后面返工也越来越多。",
                    selectedLens: .systemThinking
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let catalog = try XCTUnwrap(payload.userChoice.lensCatalog)
        XCTAssertEqual(payload.userChoice.selectedLens, ThinkingLens.systemThinking.rawValue)
        XCTAssertEqual(payload.legacyKeyValues["selectedLens"], "system_thinking")
        XCTAssertEqual(catalog.localId, "systemThinking")
        XCTAssertEqual(catalog.promptId, "system_thinking")
        XCTAssertEqual(catalog.title, "系统思维")
        XCTAssertTrue(catalog.promptGuidance.contains("feedback loops"))
        XCTAssertTrue(catalog.promptGuidance.contains("delayed effects"))
        XCTAssertTrue(catalog.questionStrategy.contains("反馈回路"))
        XCTAssertTrue(catalog.taskSelectionRule.contains("校准信号"))
        XCTAssertEqual(catalog.uiMetadata.methodIndex, 5)
    }

    func testStructuredContext_exposesLensCatalogMetadata_forJudgmentCalibration() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "我原本预测返工会减少，但实际证据相反。",
                    selectedLens: .judgmentCalibration
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let catalog = try XCTUnwrap(payload.userChoice.lensCatalog)
        XCTAssertEqual(payload.userChoice.selectedLens, ThinkingLens.judgmentCalibration.rawValue)
        XCTAssertEqual(payload.legacyKeyValues["selectedLens"], "judgment_calibration")
        XCTAssertEqual(catalog.localId, "judgmentCalibration")
        XCTAssertEqual(catalog.promptId, "judgment_calibration")
        XCTAssertEqual(catalog.title, "判断校准")
        XCTAssertTrue(catalog.promptGuidance.contains("prediction"))
        XCTAssertTrue(catalog.promptGuidance.contains("actual evidence"))
        XCTAssertTrue(catalog.questionStrategy.contains("原判断"))
        XCTAssertTrue(catalog.taskSelectionRule.contains("校准信号"))
        XCTAssertEqual(catalog.uiMetadata.methodIndex, 6)
    }

    func testLocalTrainingPrescription_recommendsCoachLensWithAuditMetadata() throws {
        let cards = [
            ThinkingCard(
                type: .risk,
                title: "验收口径不清",
                body: "上线前必须确认依据，否则判断只是估计。",
                priority: .high
            ),
            ThinkingCard(
                type: .fact,
                title: "客户还没回复",
                body: "这是当前唯一确定事实。",
                priority: .high
            )
        ]

        let prescription = LocalTrainingPrescriptionPolicy().prescribe(
            cards: cards,
            mode: .standard,
            userSelectedLens: nil
        )

        XCTAssertEqual(prescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.finalLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.source, .coachRecommended)
        XCTAssertEqual(prescription.policyVersion, LocalTrainingPrescriptionPolicy.policyVersion)
        XCTAssertGreaterThanOrEqual(prescription.confidence, 0.60)
        XCTAssertTrue(prescription.recommendationReason == ThinkingLens.evidenceCheck.catalogItem.recommendedReason)
        XCTAssertTrue(prescription.baselineChecks.contains(.evidenceGap))
        XCTAssertTrue(prescription.baselineChecks.contains(.counterexample))
        XCTAssertFalse(prescription.alternativeLensIds.isEmpty)
        XCTAssertEqual(prescription.primaryTrainingDimension, .evidenceDiscipline)
        XCTAssertTrue(prescription.secondaryTrainingDimensions.contains(.counterexampleSeeking))
        XCTAssertTrue(prescription.baselineTrainingDimensions.contains(.judgmentCalibration))
    }

    func testLocalTrainingPrescription_recordsUserOverrideSeparatelyFromCoachRecommendation() throws {
        let cards = [
            ThinkingCard(
                type: .risk,
                title: "验收口径不清",
                body: "上线前必须确认依据，否则判断只是估计。",
                priority: .high
            ),
            ThinkingCard(
                type: .fact,
                title: "客户还没回复",
                body: "这是当前唯一确定事实。",
                priority: .high
            )
        ]

        let prescription = LocalTrainingPrescriptionPolicy().prescribe(
            cards: cards,
            mode: .standard,
            userSelectedLens: .opposingView
        )

        XCTAssertEqual(prescription.recommendedLensId, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(prescription.userSelectedLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(prescription.finalLensId, ThinkingLens.opposingView.rawValue)
        XCTAssertEqual(prescription.source, .userOverride)
        XCTAssertTrue(prescription.overrideBoundary.contains("用户改选"))
    }

    func testStructuredContext_excludesCoachTrainingPrescriptionFromQuestionGeneration() async throws {
        let client = CapturingLLMClient(response: Self.opposingViewQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
            recommendationReason: "当前材料里有事实和风险，需要先验清依据。",
            confidence: 0.78,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.opposingView.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .counterexample],
            userSelectedLensId: ThinkingLens.opposingView.rawValue,
            finalLensId: ThinkingLens.opposingView.rawValue,
            source: .userOverride,
            overrideBoundary: "用户改选为反方视角，保留教练推荐作为审计。"
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "验收口径不清，但我想先找反方意见。",
                    selectedLens: .opposingView
                ),
                trainingPrescription: prescription
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.trainingPrescription)
        XCTAssertNil(payload.legacyKeyValues["coachRecommendedLens"])
        XCTAssertNil(payload.legacyKeyValues["primaryTrainingDimension"])
        XCTAssertNil(payload.legacyKeyValues["finalTrainingLens"])
        // The visible lens remains available as a user-facing viewing choice.
        XCTAssertEqual(payload.userChoice.selectedLens, ThinkingLens.opposingView.rawValue)
    }

    func testStructuredContext_excludesCoachTeachingPlanFromQuestionGeneration() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
            recommendationReason: "当前材料暴露证据缺口，先练证据意识。",
            confidence: 0.78,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.opposingView.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .testableAction],
            primaryTrainingDimension: .evidenceDiscipline,
            finalLensId: ThinkingLens.evidenceCheck.rawValue,
            source: .coachRecommended
        )
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "验收口径不清，需要先补观察事实和基线。",
            openEvidenceGaps: [.missingObservation, .missingBaseline],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Turn 1: slow down and ask for evidence before action."
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "验收口径不清，缺少事实支撑。",
                    selectedLens: .evidenceCheck
                ),
                trainingPrescription: prescription,
                coachTurnState: turn
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.coachTeachingPlan)
        XCTAssertNil(payload.legacyKeyValues["coachTeachingMissingMove"])
        XCTAssertNil(payload.legacyKeyValues["coachTeachingRule"])
        XCTAssertNil(payload.directives.coachTeachingRule)
    }

    func testStructuredContext_reframesRecalledPrinciplesAsExperienceReplay() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let principle = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [principle]
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertTrue(try XCTUnwrap(payload.directives.principleUsageRule).contains("experience replay"))
        XCTAssertTrue(try XCTUnwrap(payload.directives.principleUsageRule).contains("Do not force"))
        XCTAssertTrue(try XCTUnwrap(payload.legacyKeyValues["principleUsageRule"]).contains("experience replay"))
    }

    func testStructuredContext_excludesCoachDiagnosisFromQuestionGeneration() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let diagnosis = CoachDiagnosis(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .slowDownConvergence,
            reason: "当前材料暴露出风险或问题，但关键证据不足，先补证据再收敛。",
            source: .userSlowDown,
            policyVersion: CoachEngine.policyVersion
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "验收口径不清，缺少事实支撑。",
                    selectedLens: .evidenceCheck
                ),
                coachDiagnosis: diagnosis
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.coachDiagnosis)
        XCTAssertNil(payload.legacyKeyValues["coachThinkingPhase"])
        XCTAssertNil(payload.legacyKeyValues["coachDiagnosisRule"])
        XCTAssertNil(payload.directives.coachDiagnosisRule)
    }

    func testStructuredContext_excludesCoachTurnStateFromQuestionGeneration() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "验收口径不清，需要先补观察事实和基线。",
            openEvidenceGaps: [.missingObservation, .missingBaseline],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Turn 1: slow down and ask for evidence before action."
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "验收口径不清，缺少事实支撑。",
                    selectedLens: .evidenceCheck
                ),
                coachTurnState: turn
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.coachTurnState)
        XCTAssertNil(payload.legacyKeyValues["coachTurnPhase"])
        XCTAssertNil(payload.legacyKeyValues["coachTurnRule"])
        XCTAssertNil(payload.directives.coachTurnRule)
    }

    func testStructuredContext_doesNotInjectLocalCoachObservationForQuestionGeneration() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .decision,
            title: "Meeting ownership unclear",
            body: "会议里团队讨论方案返工，我认为原因是验收口径不清，但还缺少事实支撑。",
            isConfirmed: true
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "我认为方案返工是因为验收口径不清。",
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card]
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.coachObservation)
        XCTAssertNil(payload.legacyKeyValues["coachObservationPrimaryGap"])
        XCTAssertNil(payload.legacyKeyValues["coachObservationTrainingAbility"])
        XCTAssertNil(payload.legacyKeyValues["coachObservationRule"])
        XCTAssertNil(payload.directives.coachObservationRule)
    }

    func testStructuredContext_exposesRuntimeLensAssetMetadata() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let lens = LensAssetPack(
            id: "marketplace.roles.coach",
            version: "2026.06",
            displayName: "Coach Role Cards",
            sourceKind: .marketplace,
            items: [
                LensCatalogItem(
                    lensId: "role-coach",
                    promptId: "role_coach",
                    version: "role.v1",
                    title: "Coach Role",
                    subtitle: "Use a coaching voice.",
                    shortLabel: "Coach",
                    methodLine: "What would a coach ask first?",
                    promptGuidance: "Ask coaching-style reflection questions.",
                    symbolName: "person.wave.2",
                    recommendedReason: "Imported role card pack.",
                    questionSeeds: ["What would a coach ask first?"],
                    accentRole: .accent,
                    methodIndex: 10
                )
            ]
        ).stampedItems[0]

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "meeting ownership was unclear",
                    sessionMode: .standard,
                    selectedCustomLensId: lens.id
                ),
                confirmedCards: [],
                selectedLensItem: lens
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let catalog = try XCTUnwrap(payload.userChoice.lensCatalog)
        XCTAssertEqual(payload.userChoice.selectedLens, "role-coach")
        XCTAssertEqual(catalog.localId, "role-coach")
        XCTAssertEqual(catalog.promptId, "role_coach")
        XCTAssertEqual(catalog.sourceKind, .marketplace)
        XCTAssertEqual(catalog.packId, "marketplace.roles.coach")
        XCTAssertEqual(catalog.packVersion, "2026.06")
        XCTAssertEqual(catalog.packDisplayName, "Coach Role Cards")
        XCTAssertEqual(payload.legacyKeyValues["lensPackId"], "marketplace.roles.coach")
    }

    func testLensCatalogContext_decodesLegacyBuiltinContextWithBuiltinPackMetadata() throws {
        let legacyJSON = """
        {
          "localId": "firstPrinciples",
          "promptId": "first_principles",
          "version": "builtin.v1",
          "title": "第一性原理",
          "methodLine": "先问：如果从零开始，这件事必须成立的条件是什么？",
          "promptGuidance": "Decompose the situation into non-negotiable facts.",
          "purpose": "拆掉默认前提。",
          "questionStrategy": "先识别硬事实。",
          "taskSelectionRule": "优先设计能验证核心前提的明日验证行动。",
          "applicability": "适用于前提混杂的场景。",
          "disableConditions": ["不要用抽象原则替代当天具体证据。"],
          "uiMetadata": {
            "symbolName": "square.stack.3d.down.right",
            "accentRole": "principle",
            "methodIndex": 4
          }
        }
        """.data(using: .utf8)!

        let catalog = try JSONDecoder().decode(PromptContextPayload.LensCatalogContext.self, from: legacyJSON)

        XCTAssertEqual(catalog.sourceKind, .builtin)
        XCTAssertEqual(catalog.packId, "mingsi.builtin.lenses")
        XCTAssertEqual(catalog.packVersion, "builtin.v1")
        XCTAssertEqual(catalog.packDisplayName, "MingSi Built-in Lens Pack")
    }

    func testGenerateQuestions_injectsLensPromptGuidance_fromCatalog() async throws {
        let client = CapturingLLMClient(response: Self.firstPrinciplesQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "Which assumptions are actually necessary?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["selectedLens"], "first_principles")
        XCTAssertTrue(try XCTUnwrap(legacy["lensPromptGuidance"]).contains("non-negotiable facts"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensMethodLine"]).contains("规则"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensPurpose"]).contains("必要条件"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensQuestionStrategy"]).contains("硬约束"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensTaskSelectionRule"]).contains("用户主动"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensApplicability"]).contains("规则"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensDisableConditions"]).contains("现实限制"))
        XCTAssertEqual(legacy["lensSourceKind"], "builtin")
        XCTAssertEqual(legacy["lensPackId"], "mingsi.builtin.lenses")
        XCTAssertEqual(legacy["lensPackVersion"], "builtin.v3")
        XCTAssertEqual(legacy["lensPackDisplayName"], "MingSi Built-in Lens Pack")
    }

    func testGenerateQuestsCarriesOpenGapAsContextWithoutReopeningTheQuestionnaire() throws {
        let turn = CoachTurnState(phase: .formAction, readiness: .ready,
            recommendedMove: .generateQuest, reason: "用户选择带着缺口继续。",
            openEvidenceGaps: [.missingObservation], baselineChecks: [],
            decisionSource: .userOverrideProgress, policyVersion: "fixture", turnSummary: "保留未知，先观察。")
        let diagnosis = CoachDiagnosis(phase: .fillEvidenceGap, readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap, reason: "仍缺观察。",
            source: .coachRecommended, policyVersion: "fixture")
        let assembled = DefaultContextAssembler().assemble(promptID: .generateQuests,
            context: TodayAIContext(draft: DailyEntryDraft(rawText: "我不想再回答，先观察一次。"),
                coachDiagnosis: diagnosis, coachTurnState: turn))
        let payload = assembled.contextPayload

        XCTAssertEqual(payload.coachTurnState?.decisionSource, .userOverrideProgress)
        XCTAssertEqual(payload.coachTurnState?.openEvidenceGaps, [.missingObservation])
        XCTAssertNotNil(payload.coachDiagnosis)
        XCTAssertNotNil(payload.coachTeachingPlan)
        // Only the versioned action-design contract supplies instructions;
        // stored coach plans must not inject another mandatory review question.
        XCTAssertNil(payload.directives.coachDiagnosisRule)
        XCTAssertNil(payload.directives.coachTurnRule)
        XCTAssertNil(payload.directives.coachTeachingRule)
        for key in ["coachDiagnosisRule", "coachTurnRule", "coachTeachingRule"] {
            XCTAssertNil(payload.legacyKeyValues[key])
        }
    }

    func testGenerateQuests_injectsRelevantPrinciplesAndGroundingPayload() async throws {
        let client = CapturingLLMClient(response: Self.groundedQuestsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .task,
            title: "Prepare meeting decisions",
            body: "The next meeting needs clear owner and acceptance criteria.",
            isConfirmed: true
        )
        let question = ReflectionQuestion(
            question: "Which decision matters most?",
            whyItMatters: "It turns the lens into a concrete action.",
            answer: "Confirm owner before implementation."
        )
        let principle = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "Tomorrow I need to make meeting ownership explicit.",
                    selectedLens: .leverageAnalysis
                ),
                confirmedCards: [card],
                questions: [question],
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .generateQuests)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertTrue(try XCTUnwrap(legacy["confirmedCards"]).contains("Prepare meeting decisions"))
        XCTAssertTrue(try XCTUnwrap(legacy["reflectionAnswers"]).contains("Confirm owner"))
        XCTAssertTrue(try XCTUnwrap(legacy["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(try XCTUnwrap(legacy["principleUsageRule"]).contains("Do not force"))
        XCTAssertTrue(request.contextRecordIDs.contains(card.id.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(question.id.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(principle.id.uuidString))
    }

    func testGenerateQuestsCarriesQuestionCalibrationTargetsIntoAnswersContext() async throws {
        let client = CapturingLLMClient(response: Self.judgmentCalibrationQuestResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let question = ReflectionQuestion(
            question: "What would prove a small acceptance check reduces rework?",
            whyItMatters: "The answer should produce a calibration target for tomorrow's task.",
            calibrationTarget: "Small acceptance checks reduce rework more than adding implementation detail",
            answer: "Ask one stakeholder to accept or reject the criteria before implementation."
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "I need a smaller way to test acceptance.",
                    selectedLens: .judgmentCalibration
                ),
                questions: [question]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(
            payload.answers.first?.calibrationTarget,
            "Small acceptance checks reduce rework more than adding implementation detail"
        )
        XCTAssertTrue(
            try XCTUnwrap(payload.legacyKeyValues["reflectionAnswers"])
                .contains("calibrationTarget: Small acceptance checks reduce rework more than adding implementation detail")
        )
    }

    func testGenerateQuestionsIncludesLensFeedbackInStructuredAndLegacyContext() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "接口归属仍然造成返工。",
                    selectedLens: .judgmentCalibration
                ),
                lensFeedback: [
                    PromptContextPayload.LensFeedbackContext(
                        lensId: ThinkingLens.judgmentCalibration.rawValue,
                        lensTitle: ThinkingLens.judgmentCalibration.title,
                        signal: "reinforce",
                        completion: YesterdayCompletion.done.rawValue,
                        valueRating: YesterdayValueRating.high.rawValue,
                        calibrationNote: "原判断是书面验收能减少返工；实际证据显示返工减少。",
                        recommendation: "继续让任务先声明可观察校准信号。",
                        questionTargets: ["书面验收减少返工"],
                        evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                        lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
                    )
                ]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.lensFeedback.count, 1)
        XCTAssertEqual(payload.lensFeedback.first?.lensId, ThinkingLens.judgmentCalibration.rawValue)
        XCTAssertEqual(payload.lensFeedback.first?.signal, "reinforce")
        XCTAssertEqual(payload.lensFeedback.first?.questionTargets, ["书面验收减少返工"])
        XCTAssertEqual(payload.lensFeedback.first?.lensMoves, [QuestionLensMove.predictionCalibration.rawValue])
        let legacy = try XCTUnwrap(payload.legacyKeyValues["lensFeedback"])
        XCTAssertTrue(legacy.contains("lens=判断校准"))
        XCTAssertTrue(legacy.contains("signal=reinforce"))
        XCTAssertTrue(legacy.contains("evidenceGaps=missing_calibration_signal"))
        XCTAssertTrue(legacy.contains("lensMoves=prediction_calibration"))
    }

    func testGenerateQuestionsUsesOnlyCurrentLensFeedbackWithinMemoryBudget() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "接口归属仍然造成返工。",
                    selectedLens: .judgmentCalibration
                ),
                lensFeedback: [
                    Self.lensFeedback(lens: .evidenceCheck, signal: "avoid", target: "旧证据检查"),
                    Self.lensFeedback(lens: .judgmentCalibration, signal: "reinforce", target: "校准目标 1"),
                    Self.lensFeedback(lens: .judgmentCalibration, signal: "adjust", target: "校准目标 2"),
                    Self.lensFeedback(lens: .judgmentCalibration, signal: "avoid", target: "校准目标 3")
                ]
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertEqual(payload.lensFeedback.map(\.lensId), [
            ThinkingLens.judgmentCalibration.rawValue,
            ThinkingLens.judgmentCalibration.rawValue
        ])
        XCTAssertEqual(payload.lensFeedback.map { $0.questionTargets.first ?? "" }, ["校准目标 1", "校准目标 2"])
        XCTAssertFalse(try XCTUnwrap(payload.legacyKeyValues["lensFeedback"]).contains("旧证据检查"))
    }

    func testGenerateQuestionsQualityGateUsesPromptMemorySelection() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client,
            contextAssembler: FixedMemoryContextAssembler(
                lensFeedback: []
            )
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting ownership was unclear.",
                    selectedLens: .judgmentCalibration
                ),
                confirmedCards: [
                    ThinkingCard(
                        type: .problem,
                        title: "Meeting ownership unclear",
                        body: "No owner was named.",
                        isConfirmed: true
                    )
                ],
                lensFeedback: [
                    PromptContextPayload.LensFeedbackContext(
                        lensId: ThinkingLens.judgmentCalibration.rawValue,
                        lensTitle: ThinkingLens.judgmentCalibration.title,
                        signal: "avoid",
                        completion: YesterdayCompletion.missed.rawValue,
                        valueRating: YesterdayValueRating.low.rawValue,
                        calibrationNote: "The model did not receive this feedback in prompt context.",
                        recommendation: "Avoid prediction calibration.",
                        questionTargets: ["Written ownership acknowledgement reduces meeting rework"],
                        evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
                        lensMoves: [QuestionLensMove.predictionCalibration.rawValue]
                    )
                ]
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertTrue(payload.lensFeedback.isEmpty)
    }

    func testGenerateQuestions_rejectsGenericUncalibratableAIOutput() async throws {
        let client = CapturingLLMClient(response: Self.lowQualityQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "The meeting ownership was unclear.", selectedLens: .judgmentCalibration),
                    confirmedCards: [
                        ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named.")
                    ]
                )
            )
            XCTFail("Expected generic questions to be rejected by coaching quality gate.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.genericQuestion.rawValue))
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.vagueCalibrationTarget.rawValue))
        }
    }

    func testGenerateQuestions_rejectsMoreThanOneQuestionInCurrentTurn() async throws {
        let client = CapturingLLMClient(response: Self.twoQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "会议返工来自验收口径不清。", selectedLens: .judgmentCalibration),
                    confirmedCards: [
                        ThinkingCard(type: .problem, title: "会议返工来自验收口径不清", body: "当前判断需要一个可观察的校准信号。")
                    ]
                )
            )
            XCTFail("Expected the current-turn question budget to reject a question batch.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.tooManyCurrentTurnQuestions.rawValue))
        }
    }

    func testGenerateQuestions_rejectsAppeasingOutputWithoutCorrection() async throws {
        let client = CapturingLLMClient(response: Self.appeasingQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(
                        rawText: "会议返工来自验收口径不清，但我想先继续推进。",
                        selectedLens: .leverageAnalysis
                    ),
                    confirmedCards: [
                        ThinkingCard(
                            type: .task,
                            title: "会议返工来自验收口径不清",
                            body: "我想先继续推进，但没有补事实、目标或反例。"
                        )
                    ]
                )
            )
            XCTFail("Expected appeasing output without correction to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.appeasingWithoutCorrection.rawValue))
        }
    }

    func testGenerateQuestions_rejectsAcknowledgedGapThatStillLetsUserProceed() async throws {
        let client = CapturingLLMClient(response: Self.acknowledgedGapProceedQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(
                        rawText: "我知道证据不足，但今天压力很大，想先继续推进当前方案。",
                        selectedLens: .leverageAnalysis
                    ),
                    confirmedCards: [
                        ThinkingCard(
                            type: .problem,
                            title: "证据不足但想推进",
                            body: "当前判断缺少事实支撑，但用户想先按原方案行动。"
                        )
                    ]
                )
            )
            XCTFail("Expected acknowledged evidence gap that still lets the user proceed to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.appeasingWithoutCorrection.rawValue))
        }
    }

    func testGenerateQuestions_rejectsSystemThinkingOutputWithoutSystemMove() async throws {
        let client = CapturingLLMClient(response: Self.nonSystemThinkingQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(
                        rawText: "临时修复越来越多，后面返工也越来越多。",
                        selectedLens: .systemThinking
                    ),
                    confirmedCards: [
                        ThinkingCard(type: .problem, title: "临时修复带来返工", body: "每次临时补丁都会让下一轮返工更多。")
                    ]
                )
            )
            XCTFail("Expected system thinking output without a system lens move to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingSystemThinkingLensMove.rawValue))
        }
    }

    func testGenerateQuestions_rejectsOutputWithoutSelectedLensMove() async throws {
        let client = CapturingLLMClient(response: Self.nonLeverageQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(
                        rawText: "今天做了很多看起来忙的事，但返工没有减少。",
                        selectedLens: .leverageAnalysis
                    ),
                    confirmedCards: [
                        ThinkingCard(type: .task, title: "忙碌但低杠杆", body: "很多动作没有改变返工结果。")
                    ]
                )
            )
            XCTFail("Expected output without selected lens move to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingSelectedLensMove.rawValue))
        }
    }

    func testGenerateQuestions_usesTrainingPrescriptionFinalLensForQualityGate() async throws {
        let client = CapturingLLMClient(response: Self.nonLeverageQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.leverageAnalysis.rawValue,
            recommendedPromptId: ThinkingLens.leverageAnalysis.catalogItem.promptId,
            recommendationReason: "当前材料已经出现任务或决策，适合收敛最高杠杆动作。",
            confidence: 0.72,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.opposingView.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .counterexample],
            finalLensId: ThinkingLens.leverageAnalysis.rawValue,
            source: .coachRecommended
        )

        do {
            _ = try await service.generateQuestions(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "今天做了很多看起来忙的事，但返工没有减少。"),
                    confirmedCards: [
                        ThinkingCard(type: .task, title: "忙碌但低杠杆", body: "很多动作没有改变返工结果。")
                    ],
                    trainingPrescription: prescription
                )
            )
            XCTFail("Expected output without prescribed final lens move to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingSelectedLensMove.rawValue))
        }
    }

    func testGenerateQuestions_doesNotRejectEvidenceGroundedMoveForStaleTrainingDimension() async throws {
        let client = CapturingLLMClient(response: Self.dimensionMisalignedLeverageQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.leverageAnalysis.rawValue,
            recommendedPromptId: ThinkingLens.leverageAnalysis.catalogItem.promptId,
            recommendationReason: "本次最终透镜是杠杆分析，但教练希望主练证据意识，避免过早选择动作。",
            confidence: 0.72,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.evidenceCheck.rawValue],
            baselineChecks: [.counterexample],
            primaryTrainingDimension: .evidenceDiscipline,
            baselineTrainingDimensions: [.counterexampleSeeking],
            finalLensId: ThinkingLens.leverageAnalysis.rawValue,
            source: .coachRecommended
        )

        let questions = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "今天做了很多看起来忙的事，但返工没有减少。"),
                confirmedCards: [
                    ThinkingCard(type: .task, title: "忙碌但低杠杆", body: "很多动作没有改变返工结果。")
                ],
                trainingPrescription: prescription
            )
        )

        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions.first?.answerUse, .chooseAction)
        XCTAssertEqual(questions.first?.lensMove, .leverageTradeoff)
    }

    func testGenerateQuests_rejectsBusyworkWithoutCalibrationSignal() async throws {
        let client = CapturingLLMClient(response: Self.lowQualityQuestsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuests(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "The meeting ownership was unclear.", selectedLens: .leverageAnalysis),
                    confirmedCards: [
                        ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named.")
                    ]
                )
            )
            XCTFail("Expected busywork quest to be rejected by coaching quality gate.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.busyworkQuest.rawValue))
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.vagueCalibrationTarget.rawValue))
        }
    }

    func testGenerateQuests_rejectsQuestWhenCoachTurnIsNotReady() async throws {
        let client = CapturingLLMClient(response: Self.questsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "验收口径不清，需要先补观察事实和基线。",
            openEvidenceGaps: [.missingObservation, .missingBaseline],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Turn 1: ask evidence questions before converging."
        )

        do {
            _ = try await service.generateQuests(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "验收口径不清。", selectedLens: .leverageAnalysis),
                    confirmedCards: [
                        ThinkingCard(
                            type: .risk,
                            title: "Meeting ownership unclear",
                            body: "The owner is not written.",
                            isConfirmed: true
                        )
                    ],
                    coachTurnState: turn
                )
            )
            XCTFail("Expected coach turn quality gate to reject quests before readiness.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingCoachTurnAlignment.rawValue))
        }
    }

    func testGenerateQuestsCarriesCurrentTurnButBudgetsHistoricalLensFeedback() async throws {
        let client = CapturingLLMClient(response: Self.judgmentCalibrationQuestResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let turn = CoachTurnState(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "回答已经补足证据，可以生成可校准行动。",
            openEvidenceGaps: [],
            baselineChecks: [.evidenceGap, .testableAction],
            decisionSource: .coachAccepted,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Turn 1: generate a calibrated action."
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "验收标准不清造成返工。", selectedLens: .judgmentCalibration),
                confirmedCards: [
                    ThinkingCard(type: .problem, title: "Acceptance criteria unclear", body: "The team reworked the feature.")
                ],
                questions: [
                    ReflectionQuestion(
                        question: "原判断是什么？",
                        whyItMatters: "用于校准。",
                        answer: "我判断书面验收会减少返工。"
                    )
                ],
                lensFeedback: [
                    Self.lensFeedback(lens: .evidenceCheck, signal: "avoid", target: "旧证据检查"),
                    Self.lensFeedback(lens: .judgmentCalibration, signal: "reinforce", target: "校准目标 1"),
                    Self.lensFeedback(lens: .judgmentCalibration, signal: "adjust", target: "校准目标 2"),
                    Self.lensFeedback(lens: .judgmentCalibration, signal: "avoid", target: "校准目标 3")
                ],
                coachTurnState: turn
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertEqual(payload.coachTurnState?.readiness, .ready)
        XCTAssertEqual(payload.coachTurnState?.recommendedMove, .generateQuest)
        XCTAssertEqual(payload.lensFeedback.map { $0.questionTargets.first ?? "" }, ["校准目标 1", "校准目标 2"])
        XCTAssertFalse(try XCTUnwrap(payload.legacyKeyValues["lensFeedback"]).contains("旧证据检查"))
    }

    func testGenerateQuestsQualityGateUsesPromptMemorySelection() async throws {
        let client = CapturingLLMClient(response: Self.judgmentCalibrationQuestResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client,
            contextAssembler: FixedMemoryContextAssembler(
                lensFeedback: [],
                coachTurnState: nil
            )
        )
        let notReadyTurn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "The model did not receive this coach turn in prompt context.",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Previous hidden turn."
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "验收标准不清造成返工。",
                    selectedLens: .judgmentCalibration
                ),
                confirmedCards: [
                    ThinkingCard(
                        type: .problem,
                        title: "Acceptance criteria unclear",
                        body: "The team reworked the feature.",
                        isConfirmed: true
                    )
                ],
                questions: [
                    ReflectionQuestion(
                        question: "原判断是什么？",
                        whyItMatters: "用于校准。",
                        answer: "我判断书面验收会减少返工。"
                    )
                ],
                coachTurnState: notReadyTurn
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertNil(payload.coachTurnState)
    }

    func testGenerateQuests_rejectsUngroundedQuestOutput() async throws {
        let client = CapturingLLMClient(response: Self.ungroundedQuestsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.generateQuests(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "Small acceptance checks keep reducing rework.", selectedLens: .judgmentCalibration),
                    confirmedCards: [
                        ThinkingCard(type: .problem, title: "Acceptance criteria unclear", body: "The owner accepted late.")
                    ]
                )
            )
            XCTFail("Expected ungrounded quest to be rejected by coaching quality gate.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingSourceGrounding.rawValue))
        }
    }

    func testGenerateQuests_acceptsGroundedActionDespiteDifferentLensMove() async throws {
        let client = CapturingLLMClient(response: Self.nonLeverageQuestResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let quests = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "今天做了很多看起来忙的事，但返工没有减少。",
                    selectedLens: .leverageAnalysis
                ),
                confirmedCards: [
                    ThinkingCard(type: .task, title: "忙碌但低杠杆", body: "很多动作没有改变返工结果。")
                ]
            )
        )
        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests.first?.lensMove, .alternativeExplanation)
    }

    func testGenerateQuests_doesNotTreatPrescriptionAsMethodMandate() async throws {
        let client = CapturingLLMClient(response: Self.nonLeverageQuestResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.leverageAnalysis.rawValue,
            recommendedPromptId: ThinkingLens.leverageAnalysis.catalogItem.promptId,
            recommendationReason: "当前材料已经出现任务或决策，适合收敛最高杠杆动作。",
            confidence: 0.72,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.opposingView.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .counterexample],
            finalLensId: ThinkingLens.leverageAnalysis.rawValue,
            source: .coachRecommended
        )

        let quests = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "今天做了很多看起来忙的事，但返工没有减少。"),
                confirmedCards: [
                    ThinkingCard(type: .task, title: "忙碌但低杠杆", body: "很多动作没有改变返工结果。")
                ],
                trainingPrescription: prescription
            )
        )
        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests.first?.lensMove, .alternativeExplanation)
    }

    func testGenerateQuests_acceptsLiveExistingRecordComparisonButRejectsInventedSource() async throws {
        // Synthetic actual response from the first 2026-10-18 history acceptance:
        // the old selected-lens gate rejected alternative_explanation.
        let response = Data(#"""
{
  "main_quest": {
    "type": "main",
    "title": "明天仅用已有记录对照两次任务范围",
    "why_it_matters": "目前缺少两次任务范围的对照，返工减少还不能归因于书面验收。此次只检查“任务更简单”这一替代解释，不追加测试；即使范围相近，也不能单凭这组对照证明书面验收有效。",
    "completion_criteria": "基于已有记录，留下一个简短对照：用两次记录中可比的范围信息，标出本次更少、相近或更多的内容，并注明记录依据；最终得到“范围明显缩小”“未见明显缩小”或“记录不足，无法比较”之一。缺失信息标为未知，不补采、不追加测试，也无需分享内部记录。",
    "expected_resistance": "两次记录的详细程度可能不同，不能把未记录的内容直接当成不存在；无法比较时允许保留未知。",
    "reflection_question": "若范围明显缩小，你是否应更重视任务简单这一解释；若未见明显缩小，是否只能削弱该解释而仍不能确认书面验收的作用；若记录不足，是否继续保留原判断？",
    "calibration_target": "目前还不能把返工减少归因于书面验收，因为尚未排查本次任务范围更小这一替代解释。",
    "lens_move": "alternative_explanation",
    "linked_cards": [
      "任务变简单也可能减少返工"
    ]
  },
  "side_quests": [],
  "observation_quest": null,
  "rejected_low_value_tasks": [
    "追加测试或重新安排一次任务来验证书面验收",
    "把范围相近直接当作书面验收有效的证据"
  ]
}
"""#.utf8)
        let cardTitle = "任务变简单也可能减少返工"
        for usesActualSource in [true, false] {
            let client = CapturingLLMClient(response: response)
            let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            let card = ThinkingCard(type: .decision, title: usesActualSource ? cardTitle : "另一个事项",
                body: "同事这次把验收标准写清后返工少了，但任务可能更简单。我愿意用已有记录比较范围，不追加测试。", isConfirmed: true)
            do {
                let quests = try await service.generateQuests(for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: card.body, selectedLens: .judgmentCalibration), confirmedCards: [card]))
                XCTAssertTrue(usesActualSource, "Changing method flexibility must not allow an invented source")
                XCTAssertEqual(quests.count, 1)
                XCTAssertEqual(quests.first?.lensMove, .alternativeExplanation)
                XCTAssertEqual(quests.first?.sourceCardTitles, [cardTitle])
            } catch TodayAIParsingError.qualityGateFailed(let reasons) {
                XCTAssertFalse(usesActualSource)
                XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.invalidSourceGrounding.rawValue))
            }
        }
    }

    func testExtractPrinciple_includesExistingPrinciplesForDedupe() async throws {
        let client = CapturingLLMClient(response: Self.principlesResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let existing = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Owner and acceptance criteria are visible before execution.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.extractPrinciple(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "Meeting ownership should be explicit."),
                principles: [existing]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .extractPrinciple)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertTrue(try XCTUnwrap(payload.legacyKeyValues["existingPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertEqual(payload.existingPrinciples.map(\.title), ["Clarify meeting ownership"])
        XCTAssertTrue(request.contextRecordIDs.contains(existing.id.uuidString))
    }

    func testExtractPrincipleDoesNotInjectCoachTurnOrLensFeedback() async throws {
        let client = CapturingLLMClient(response: Self.principlesResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let existing = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Owner and acceptance criteria are visible before execution.",
            exceptions: "Low-stakes sync"
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
            recommendationReason: "Keep dedupe aware of today's training plan.",
            confidence: 0.78,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.judgmentCalibration.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            finalLensId: ThinkingLens.evidenceCheck.rawValue,
            source: .coachRecommended
        )
        let diagnosis = CoachDiagnosis(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "Historical coach state must not shape principle extraction.",
            source: .coachRecommended,
            policyVersion: CoachEngine.policyVersion
        )
        let turn = CoachTurnState(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "Historical turn should not be injected into principle extraction.",
            openEvidenceGaps: [],
            baselineChecks: [.evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Previous coach turn outcome."
        )

        _ = try await service.extractPrinciple(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "Meeting ownership should be explicit.",
                    selectedLens: .evidenceCheck
                ),
                principles: [existing],
                lensFeedback: [
                    Self.lensFeedback(lens: .evidenceCheck, signal: "avoid", target: "旧证据检查")
                ],
                trainingPrescription: prescription,
                coachDiagnosis: diagnosis,
                coachTurnState: turn
            )
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertEqual(payload.existingPrinciples.map(\.title), ["Clarify meeting ownership"])
        XCTAssertNotNil(payload.trainingPrescription)
        XCTAssertTrue(payload.lensFeedback.isEmpty)
        XCTAssertNil(payload.coachDiagnosis)
        XCTAssertNil(payload.coachTurnState)
        XCTAssertNil(payload.legacyKeyValues["lensFeedback"])
        XCTAssertNil(payload.legacyKeyValues["coachDiagnosisReason"])
        XCTAssertNil(payload.legacyKeyValues["coachTurnPhase"])
    }

    func testRecommendLensesDoesNotInjectCoachContextMemory() throws {
        let assembler = DefaultContextAssembler()
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendedPromptId: ThinkingLens.evidenceCheck.catalogItem.promptId,
            recommendationReason: "Recommendation prompt must not inherit prior coaching.",
            confidence: 0.78,
            policyVersion: LocalTrainingPrescriptionPolicy.policyVersion,
            alternativeLensIds: [ThinkingLens.judgmentCalibration.rawValue],
            baselineChecks: [.factInterpretationSplit, .evidenceGap],
            finalLensId: ThinkingLens.evidenceCheck.rawValue,
            source: .coachRecommended
        )
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .surfaceEvidenceGap,
            reason: "Historical turn must not pre-shape lens recommendation.",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.evidenceGap],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "Previous turn."
        )
        let principle = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner and acceptance criteria"],
            successCriteria: "Owner and acceptance criteria are visible.",
            exceptions: ""
        )

        let promptContext = assembler.assemble(
            promptID: .recommendLenses,
            context: TodayAIContext(
                draft: DailyEntryDraft(rawText: "今天只需要先看原始材料。"),
                principles: [principle],
                lensFeedback: [
                    Self.lensFeedback(lens: .evidenceCheck, signal: "reinforce", target: "旧目标")
                ],
                trainingPrescription: prescription,
                coachTurnState: turn
            )
        )

        let payload = promptContext.contextPayload
        XCTAssertTrue(payload.principles.isEmpty)
        XCTAssertTrue(payload.existingPrinciples.isEmpty)
        XCTAssertTrue(payload.lensFeedback.isEmpty)
        XCTAssertNil(payload.trainingPrescription)
        XCTAssertNil(payload.coachTurnState)
        XCTAssertNil(payload.legacyKeyValues["coachRecommendedLens"])
        XCTAssertNil(payload.legacyKeyValues["lensFeedback"])
        XCTAssertNil(payload.legacyKeyValues["coachTurnPhase"])
    }

    func testExtractPrinciple_rejectsUngroundedPrincipleOutput() async throws {
        let client = CapturingLLMClient(response: Self.ungroundedPrincipleResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.extractPrinciple(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "Meeting ownership should be explicit."),
                    confirmedCards: [
                        ThinkingCard(
                            type: .problem,
                            title: "Meeting ownership unclear",
                            body: "We left without a clear owner.",
                            priority: .high,
                            isConfirmed: true
                        )
                    ]
                )
            )
            XCTFail("Expected ungrounded principle output to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingPrincipleSourceGrounding.rawValue))
        }
    }

    func testExtractPrinciple_rejectsWeakPrincipleActionabilityOutput() async throws {
        let client = CapturingLLMClient(response: Self.weakPrincipleActionabilityResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.extractPrinciple(
                for: TodayAIContext(
                    draft: DailyEntryDraft(rawText: "Meeting ownership should be explicit."),
                    confirmedCards: [
                        ThinkingCard(
                            type: .problem,
                            title: "Meeting ownership unclear",
                            body: "We left without a clear owner.",
                            priority: .high,
                            isConfirmed: true
                        )
                    ]
                )
            )
            XCTFail("Expected weak principle actionability output to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.weakPrincipleActionability.rawValue))
        }
    }

    func testVerifyQuest_recordsSourceIdsAsRequestAndContextIds() async throws {
        let client = CapturingLLMClient(response: Self.verificationResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let sourceIds = [UUID().uuidString, UUID().uuidString]

        _ = try await service.verifyQuest(
            input: VerifyQuestInput(
                sourceRecordIDs: sourceIds,
                questTitle: "Confirm owner",
                completionCriteria: "Owner acknowledged in writing.",
                completion: "done",
                valueRating: "high",
                judgmentUpdate: "confirmed",
                rawText: "It reduced ambiguity."
            ),
            sessionMode: .standard
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .verifyQuest)
        XCTAssertEqual(request.sourceRecordIDs, sourceIds)
        XCTAssertEqual(request.contextRecordIDs, sourceIds)
    }

    func testVerifyQuestCurrentSchemaAcceptsShortNaturalMissingEvidenceReview() async throws {
        let response = Data("""
        {
          "calibration_assessment": {"evidence_status":"missing","criteria_status":"not_assessable","judgment_status":"unresolved","evidence_quotes":[]},
          "calibration_note": "你选了已完成，但没有提供重试结果，暂时无法核对验收条件。关于设计的解释仍应保持开放。",
          "likely_issue": "none",
          "recommendation": "若还有可回查的信息，可留下一条已有观察，不必追加测试。",
          "growth_evidence_items": []
        }
        """.utf8)
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: CapturingLLMClient(response: response))
        let result = try await service.verifyQuest(input: VerifyQuestInput(
            questTitle: "重试入口", completionCriteria: "网络正常时记录是否完成",
            targetJudgment: "入口设计导致未完成", completion: "done", valueRating: "high",
            judgmentUpdate: "confirmed", rawText: "没有记录结果，只点了已完成。"), sessionMode: .standard)
        XCTAssertEqual(result.calibrationAssessment?.judgmentStatus, .unresolved)
        XCTAssertTrue(result.growthEvidenceItems.isEmpty)
    }

    func testCalibrationAssessmentRejectsInventedQuotesAndUnsupportedConfirmation() {
        let missing = CalibrationAssessment(evidenceStatus: .missing, criteriaStatus: .notAssessable,
            judgmentStatus: .unresolved, evidenceQuotes: [])
        XCTAssertTrue(missing.isGrounded(in: "我选了已确认，但没有观察结果。", hasGrowthEvidence: false))
        XCTAssertFalse(missing.isGrounded(in: "没有观察结果。", hasGrowthEvidence: true))
        var contradictory = missing
        contradictory.judgmentStatus = .supported
        XCTAssertFalse(contradictory.isGrounded(in: "没有观察结果。", hasGrowthEvidence: false))
        contradictory = missing
        contradictory.criteriaStatus = .met
        XCTAssertFalse(contradictory.isGrounded(in: "没有观察结果。", hasGrowthEvidence: false))
        let observed = CalibrationAssessment(evidenceStatus: .observed, criteriaStatus: .met,
            judgmentStatus: .supported, evidenceQuotes: ["朋友没有完成"])
        XCTAssertTrue(observed.isGrounded(in: "网络正常，朋友没有完成，停在第三步。", hasGrowthEvidence: false))
        XCTAssertFalse(observed.isGrounded(in: "我没有记录朋友的结果。", hasGrowthEvidence: false))
        var duplicate = observed
        duplicate.evidenceQuotes.append("朋友没有完成")
        XCTAssertFalse(duplicate.isGrounded(in: "朋友没有完成", hasGrowthEvidence: false))
        var empty = observed
        empty.evidenceQuotes = []
        XCTAssertFalse(empty.isGrounded(in: "朋友没有完成", hasGrowthEvidence: false))
    }

    func testVerifyQuest_usesStructuredContextAsLegacyPayloadSource() async throws {
        let client = CapturingLLMClient(response: Self.strongVerificationResponse(reportedEvidence: "It reduced ambiguity."))
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.verifyQuest(
            input: VerifyQuestInput(
                sourceRecordIDs: [UUID().uuidString],
                questTitle: "Confirm owner",
                completionCriteria: "Owner acknowledged in writing.",
                targetJudgment: "Written owner acknowledgement reduces ambiguity",
                completion: "done",
                valueRating: "high",
                judgmentUpdate: "confirmed",
                rawText: "It reduced ambiguity."
            ),
            sessionMode: .deep
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(payload.verification?.questTitle, "Confirm owner")
        XCTAssertEqual(payload.verification?.targetJudgment, "Written owner acknowledgement reduces ambiguity")
        XCTAssertEqual(payload.verification?.judgmentUpdate, "confirmed")
        XCTAssertEqual(legacy["questTitle"], "Confirm owner")
        XCTAssertEqual(legacy["completionCriteria"], "Owner acknowledged in writing.")
        XCTAssertEqual(legacy["targetJudgment"], "Written owner acknowledgement reduces ambiguity")
        XCTAssertEqual(legacy["completion"], "done")
        XCTAssertEqual(legacy["valueRating"], "high")
        XCTAssertEqual(legacy["judgmentUpdate"], "confirmed")
        XCTAssertEqual(legacy["sessionMode"], SessionMode.deep.rawValue)
    }

    func testVerifyQuest_includesSelectedTrainingPrincipleInStructuredAndLegacyContext() async throws {
        let principleID = UUID()
        var response = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.strongVerificationResponse(reportedEvidence: "The criteria reduced rework.")) as? [String: Any])
        response["principle_practice_assessment"] = ["principle_id": principleID.uuidString, "status": "not_assessable", "evidence_quotes": [], "reason": "A favorable outcome does not describe whether the actions occurred."]
        let client = CapturingLLMClient(response: try JSONSerialization.data(withJSONObject: response))
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.verifyQuest(
            input: VerifyQuestInput(
                sourceRecordIDs: [UUID().uuidString],
                questTitle: "Confirm acceptance criteria",
                completionCriteria: "Acceptance criteria are written and acknowledged.",
                targetJudgment: "Written acceptance criteria reduce rework",
                trainingPrinciple: .init(
                    principleId: principleID,
                    principleTitle: "先写验收标准",
                    matchSignal: "用户选择", triggerContext: "Before handoff",
                    actions: ["Write criteria", "Ask receiver to restate"],
                    successCriteria: "Receiver confirms shared criteria", exceptions: "Low-risk reversible work"
                ),
                completion: "done",
                valueRating: "high",
                judgmentUpdate: "confirmed",
                rawText: "The criteria reduced rework."
            ),
            sessionMode: .standard
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let verification = try XCTUnwrap(payload.verification)
        XCTAssertEqual(verification.trainingPrinciple?.principleId, principleID.uuidString)
        XCTAssertEqual(verification.trainingPrinciple?.principleTitle, "先写验收标准")
        XCTAssertEqual(verification.trainingPrinciple?.matchSignal, "用户选择")
        XCTAssertEqual(verification.trainingPrinciple?.actions, ["Write criteria", "Ask receiver to restate"])
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(
            legacy["trainingPrinciple"],
            "id: \(principleID.uuidString), title: 先写验收标准, matchSignal: 用户选择, triggerContext: Before handoff, actions: Write criteria; Ask receiver to restate, successCriteria: Receiver confirms shared criteria, exceptions: Low-risk reversible work"
        )
    }

    func testPrinciplePracticeAssessmentValidatesOwnershipQuotesAndUnknown() {
        let id = UUID()
        let result = "我写了标准，但没有请对方复述。"
        let valid = PrinciplePracticeAssessment(principleId: id, status: .partiallyPracticed,
            evidenceQuotes: [result], reason: "Only the first action was reported.")
        XCTAssertTrue(valid.isGrounded(in: result, expectedPrincipleID: id))
        XCTAssertFalse(valid.isGrounded(in: result, expectedPrincipleID: UUID()))
        XCTAssertFalse(valid.isGrounded(in: result, expectedPrincipleID: nil))
        var invalid = valid
        invalid.evidenceQuotes = ["我请对方复述了"]
        XCTAssertFalse(invalid.isGrounded(in: result, expectedPrincipleID: id))
        invalid.evidenceQuotes = [result, result]
        XCTAssertFalse(invalid.isGrounded(in: result, expectedPrincipleID: id))
        invalid.evidenceQuotes = []
        XCTAssertFalse(invalid.isGrounded(in: result, expectedPrincipleID: id))
        invalid.status = .notAssessable
        XCTAssertTrue(invalid.isGrounded(in: result, expectedPrincipleID: id))
    }

    func testVerifyQuestRejectsPracticeWithoutBehaviorContextOrWithInventedSources() async throws {
        let id = UUID()
        for scenario in ["missing", "wrong-id", "invented-quote", "no-details", "no-principle"] {
            var response: [String: Any] = [
                "calibration_assessment": ["evidence_status": "missing", "criteria_status": "not_assessable", "judgment_status": "unresolved", "evidence_quotes": []],
                "calibration_note": "后续结果尚未返回，无法核对完成标准。原判断仍未确定。",
                "likely_issue": "none", "recommendation": "若以后有反馈，可再自愿更新。",
                "expected_principle_practice_assessment": "仅根据本次行为记录评估，不证明效果。",
                "growth_evidence_items": []
            ]
            if scenario != "missing" {
                response["principle_practice_assessment"] = ["principle_id": scenario == "wrong-id" ? UUID().uuidString : id.uuidString,
                    "status": "practiced", "evidence_quotes": [scenario == "invented-quote" ? "对方已经复述确认" : "交接前我写了标准"], "reason": "Claims a reported action."]
            }
            let client = CapturingLLMClient(response: try JSONSerialization.data(withJSONObject: response))
            let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
            do {
                _ = try await service.verifyQuest(input: VerifyQuestInput(
                    questTitle: "交接", completionCriteria: "后续没有返工",
                    trainingPrinciple: scenario == "no-principle" ? nil : .init(principleId: id, principleTitle: "先写标准", matchSignal: "用户选择",
                        triggerContext: scenario == "no-details" ? nil : "交接前", actions: scenario == "no-details" ? nil : ["写标准"]),
                    completion: "done", valueRating: "high", judgmentUpdate: "confirmed", rawText: "交接前我写了标准；结果还没回来。"), sessionMode: .standard)
                XCTFail("Expected invalid practice classification to fail: \(scenario)")
            } catch TodayAIParsingError.qualityGateFailed(let reasons) {
                XCTAssertTrue(reasons.contains(scenario == "missing" ? "missingPrinciplePracticeAssessment" : (scenario == "no-details" ? "missingPrincipleBehaviorContext" : "invalidPrinciplePracticeAssessment")))
            }
            XCTAssertEqual(client.requests.count, 1)
        }
    }

    func testVerifyQuest_rejectsWeakCalibrationNoteWhenTargetJudgmentPresent() async throws {
        let client = CapturingLLMClient(response: Self.weakVerificationResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.verifyQuest(
                input: VerifyQuestInput(
                    sourceRecordIDs: [UUID().uuidString],
                    questTitle: "Confirm owner",
                    completionCriteria: "Owner acknowledged in writing.",
                    targetJudgment: "Written owner acknowledgement reduces ambiguity",
                    completion: "done",
                    valueRating: "high",
                    judgmentUpdate: "confirmed",
                    rawText: "It reduced ambiguity."
                ),
                sessionMode: .standard
            )
            XCTFail("Expected weak verification calibration note to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.weakVerificationCalibrationNote.rawValue))
        }
    }

    func testVerifyQuest_rejectsCalibrationNoteWithoutCompletionCriteriaEvidence() async throws {
        let client = CapturingLLMClient(response: Self.verificationWithoutCriteriaEvidenceResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.verifyQuest(
                input: VerifyQuestInput(
                    sourceRecordIDs: [UUID().uuidString],
                    questTitle: "Confirm owner",
                    completionCriteria: "Owner acknowledged in writing.",
                    targetJudgment: "Written owner acknowledgement reduces ambiguity",
                    completion: "done",
                    valueRating: "high",
                    judgmentUpdate: "confirmed",
                    rawText: "The owner replied and ambiguity dropped."
                ),
                sessionMode: .standard
            )
            XCTFail("Expected verification without completion-criteria evidence to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains("invalidCalibrationAssessment"))
        }
    }

    func testVerifyQuest_rejectsWeakRecommendationWhenTargetJudgmentPresent() async throws {
        let client = CapturingLLMClient(response: Self.verificationWeakRecommendationResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.verifyQuest(
                input: VerifyQuestInput(
                    sourceRecordIDs: [UUID().uuidString],
                    questTitle: "Confirm owner",
                    completionCriteria: "Owner acknowledged in writing.",
                    targetJudgment: "Written owner acknowledgement reduces ambiguity",
                    completion: "done",
                    valueRating: "high",
                    judgmentUpdate: "confirmed",
                    rawText: "The owner replied and ambiguity dropped."
                ),
                sessionMode: .standard
            )
            XCTFail("Expected weak verification recommendation to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.weakVerificationRecommendation.rawValue))
        }
    }

    func testVerifyQuest_rejectsMissingExpectedPrinciplePracticeAssessmentWhenTrainingPrinciplePresent() async throws {
        let client = CapturingLLMClient(response: Self.verificationMissingExpectedPrincipleAssessmentResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        do {
            _ = try await service.verifyQuest(
                input: VerifyQuestInput(
                    sourceRecordIDs: [UUID().uuidString],
                    questTitle: "Confirm owner",
                    completionCriteria: "Owner acknowledged in writing.",
                    targetJudgment: "Written owner acknowledgement reduces ambiguity",
                    trainingPrinciple: .init(
                        principleId: UUID(),
                        principleTitle: "先写验收标准",
                        matchSignal: "用户选择"
                    ),
                    completion: "done",
                    valueRating: "high",
                    judgmentUpdate: "confirmed",
                    rawText: "The owner replied and ambiguity dropped."
                ),
                sessionMode: .standard
            )
            XCTFail("Expected missing expected principle practice assessment to be rejected.")
        } catch TodayAIParsingError.qualityGateFailed(let reasons) {
            XCTAssertTrue(reasons.contains(PromptCoachingQualityIssueReason.missingExpectedPrinciplePracticeAssessment.rawValue))
        }
    }

    func testRelevantPrinciples_areCappedAtThreeAndExcludeInactive() async throws {
        let client = CapturingLLMClient(response: Self.evidenceCheckQuestionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let principles = (0..<5).map { index in
            PrincipleAsset(
                title: "Meeting ownership rule \(index)",
                summary: "Clarify meeting ownership before execution.",
                triggerContext: "meeting ownership",
                actions: ["Write owner"],
                successCriteria: "Owner is known.",
                exceptions: "Low-stakes sync",
                status: index == 4 ? .archived : .active
            )
        }

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "The meeting ownership was unclear.", selectedLens: .evidenceCheck),
                confirmedCards: [
                    ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named.")
                ],
                principles: principles
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        let relevantPrinciples = try XCTUnwrap(legacy["relevantPrinciples"])
        XCTAssertEqual(request.contextRecordIDs.filter { id in principles.map(\.id.uuidString).contains(id) }.count, 3)
        XCTAssertFalse(relevantPrinciples.contains("Meeting ownership rule 4"))
    }

    func testRelevantPrinciples_negativeRecallFeedbackDemotesMisrecalledPrinciples() async throws {
        let penalizedPrinciple = PrincipleAsset(
            title: "Meeting ownership escalation",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync"
        )
        let unchallengedPrinciple = PrincipleAsset(
            title: "Meeting ownership alignment",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync"
        )
        let context = TodayAIContext(
            draft: DailyEntryDraft(rawText: "The meeting ownership owner was unclear.", selectedLens: .evidenceCheck),
            confirmedCards: [
                ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named for meeting ownership.")
            ],
            principles: [penalizedPrinciple, unchallengedPrinciple],
            principleRecallFeedback: [
                PrincipleRecallFeedback(
                    principleId: penalizedPrinciple.id,
                    promptId: .generateQuestions,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier recall was too broad.",
                    retrievalSignal: "meeting ownership",
                    feedback: .misrecalled,
                    createdAt: Date(timeIntervalSince1970: 200)
                ),
                PrincipleRecallFeedback(
                    principleId: penalizedPrinciple.id,
                    promptId: .generateQuests,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier recall did not apply.",
                    retrievalSignal: "meeting ownership",
                    feedback: .notApplicable,
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            ]
        )

        let retrieved = LocalPrincipleRetriever()
            .retrievePrinciples(for: context, promptID: .generateQuestions, limit: 2)

        XCTAssertEqual(retrieved.map(\.principle.id), [unchallengedPrinciple.id, penalizedPrinciple.id])
        XCTAssertLessThan(
            try XCTUnwrap(retrieved.first(where: { $0.principle.id == penalizedPrinciple.id })?.score),
            try XCTUnwrap(retrieved.first(where: { $0.principle.id == unchallengedPrinciple.id })?.score)
        )
        XCTAssertTrue(
            try XCTUnwrap(retrieved.first(where: { $0.principle.id == penalizedPrinciple.id })?.retrievalReason)
                .contains("negative recall feedback")
        )
        XCTAssertEqual(
            retrieved.first(where: { $0.principle.id == penalizedPrinciple.id })?.retrievalSignal,
            "meeting ownership"
        )
    }

    func testRelevantPrinciples_negativeRecallFeedbackOnlyPenalizesMatchingRetrievalSignal() async throws {
        let principle = PrincipleAsset(
            title: "Acceptance contract",
            summary: "Clarify meeting ownership and acceptance contract before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance contract"],
            successCriteria: "Acceptance contract is known.",
            exceptions: "Low-stakes sync"
        )
        let sameSignalContext = TodayAIContext(
            draft: DailyEntryDraft(rawText: "The meeting ownership was unclear.", selectedLens: .evidenceCheck),
            confirmedCards: [
                ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named.")
            ],
            principles: [principle],
            principleRecallFeedback: [
                PrincipleRecallFeedback(
                    principleId: principle.id,
                    promptId: .generateQuestions,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier meeting ownership recall was wrong.",
                    retrievalSignal: "meeting ownership",
                    feedback: .misrecalled,
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            ]
        )
        let differentSignalContext = TodayAIContext(
            draft: DailyEntryDraft(rawText: "The acceptance contract was unclear.", selectedLens: .evidenceCheck),
            confirmedCards: [
                ThinkingCard(type: .problem, title: "Acceptance contract unclear", body: "No acceptance contract was written.")
            ],
            principles: [principle],
            principleRecallFeedback: [
                PrincipleRecallFeedback(
                    principleId: principle.id,
                    promptId: .generateQuestions,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier meeting ownership recall was wrong.",
                    retrievalSignal: "meeting ownership",
                    feedback: .misrecalled,
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            ]
        )

        let retriever = LocalPrincipleRetriever()
        let sameSignal = try XCTUnwrap(
            retriever.retrievePrinciples(for: sameSignalContext, promptID: .generateQuestions, limit: 1).first
        )
        let differentSignal = try XCTUnwrap(
            retriever.retrievePrinciples(for: differentSignalContext, promptID: .generateQuestions, limit: 1).first
        )

        XCTAssertEqual(sameSignal.retrievalSignal, "meeting ownership")
        XCTAssertTrue(sameSignal.retrievalReason.contains("negative recall feedback penalty=1"))
        XCTAssertEqual(differentSignal.retrievalSignal, "acceptance contract")
        XCTAssertFalse(differentSignal.retrievalReason.contains("negative recall feedback penalty"))
    }

    func testRelevantPrinciples_adaptedRecallFeedbackDoesNotPenalizeRetrievalSignal() async throws {
        let adapted = try XCTUnwrap(PrincipleRecallFeedbackValue(rawValue: "adapted"))
        let principle = PrincipleAsset(
            title: "Meeting ownership alignment",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync"
        )
        let context = TodayAIContext(
            draft: DailyEntryDraft(rawText: "The meeting ownership owner was unclear.", selectedLens: .evidenceCheck),
            confirmedCards: [
                ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named for meeting ownership.")
            ],
            principles: [principle],
            principleRecallFeedback: [
                PrincipleRecallFeedback(
                    principleId: principle.id,
                    promptId: .generateQuestions,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier recall needed adaptation, not rejection.",
                    retrievalSignal: "meeting ownership",
                    feedback: adapted,
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            ]
        )

        let retrieved = try XCTUnwrap(
            LocalPrincipleRetriever()
                .retrievePrinciples(for: context, promptID: .generateQuestions, limit: 1)
                .first
        )

        XCTAssertEqual(retrieved.principle.id, principle.id)
        XCTAssertEqual(retrieved.retrievalSignal, "meeting ownership")
        XCTAssertFalse(retrieved.retrievalReason.contains("negative recall feedback penalty"))
    }

    private static let cardsResponse = Data(
        """
        {
          "cards": [
            {
              "type": "problem",
              "title": "Meeting ownership unclear",
              "body": "The owner was not explicit.",
              "importance": "high",
              "sensitivity": "normal",
              "confidence": "high",
              "reason": "The input names ownership ambiguity."
            }
          ]
        }
        """.utf8
    )

    private static let questionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "What observable signal tomorrow would show written ownership reduced meeting rework?",
              "why_this_matters": "It turns the ownership judgment into a calibration signal that can update the next decision.",
              "why_now": "The coach turn is ready to turn ownership into a visible calibration signal.",
              "expected_update": "The answer will update whether written ownership should drive tomorrow's quest.",
              "proceed_when": "Proceed when one observable signal can confirm or weaken the ownership judgment.",
              "evidence_gap_type": "missing_calibration_signal",
              "answer_use": "watch_calibration_signal",
              "lens_move": "prediction_calibration",
              "source_card_titles": ["Meeting ownership unclear"],
              "calibration_target": "Written ownership acknowledgement reduces meeting rework",
              "expected_answer_type": "prediction"
            }
          ]
        }
        """.utf8
    )

    private static let twoQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "哪一个可观察信号会改变你对验收口径的判断？",
              "why_this_matters": "它把判断连接到可以核对的结果。",
              "why_now": "当前还缺少校准判断的结果信号。",
              "expected_update": "答案会更新验收口径是否是主要原因的判断。",
              "proceed_when": "说出一个明天可以核对的结果信号时推进。",
              "evidence_gap_type": "missing_calibration_signal",
              "answer_use": "watch_calibration_signal",
              "lens_move": "prediction_calibration",
              "source_card_titles": ["会议返工来自验收口径不清"],
              "calibration_target": "验收口径不清是会议返工的主要原因"
            },
            {
              "question": "如果这个判断是错的，哪条事实最先会出现？",
              "why_this_matters": "它提供了一个反例入口。",
              "why_now": "同一轮不需要预先展开第二个问题。",
              "expected_update": "答案会更新当前判断的可信度。",
              "proceed_when": "说出一条反例事实时推进。",
              "evidence_gap_type": "missing_counterexample",
              "answer_use": "test_assumption",
              "lens_move": "alternative_explanation",
              "source_card_titles": ["会议返工来自验收口径不清"],
              "calibration_target": "当前判断能够经受反例检验"
            }
          ]
        }
        """.utf8
    )

    private static let evidenceCheckQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "Should the previous principle about clarifying meeting ownership be reused, adapted, or rejected here, and which observed fact supports that choice?",
              "why_this_matters": "It separates facts from assumptions while training experience replay instead of mechanically applying an old principle.",
              "why_now": "The coach turn has a relevant prior principle, but today's ownership issue still needs observable evidence before converging on an action.",
              "expected_update": "The answer will update whether the prior ownership principle should be reused, adapted, or rejected for this case.",
              "proceed_when": "Proceed when the answer names reuse, adapt, or reject and separates at least one observed fact from one interpretation.",
              "evidence_gap_type": "missing_observation",
              "answer_use": "collect_evidence",
              "lens_move": "fact_interpretation_split",
              "source_card_titles": ["Meeting ownership unclear"],
              "calibration_target": "The ownership issue is based on observable evidence rather than interpretation",
              "expected_answer_type": "fact"
            }
          ]
        }
        """.utf8
    )

    private static let opposingViewQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "如果验收口径不清不是主要风险，还有什么替代解释能说明当前判断？",
              "why_this_matters": "它要求先寻找相反证据，避免只证明默认判断。",
              "why_now": "当前教练轮次需要先检查默认解释是否过早收敛。",
              "expected_update": "答案会更新验收口径不清是否仍是主解释。",
              "proceed_when": "当答案给出一个可检验的替代解释时推进。",
              "evidence_gap_type": "missing_counterexample",
              "answer_use": "test_assumption",
              "lens_move": "alternative_explanation",
              "source_card_titles": ["Meeting ownership unclear"],
              "calibration_target": "验收口径不清是当前判断的主要风险",
              "expected_answer_type": "counterexample"
            }
          ]
        }
        """.utf8
    )

    private static let firstPrinciplesQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "Which non-negotiable facts must be true before this plan can work?",
              "why_this_matters": "It separates hard constraints from inherited assumptions.",
              "why_now": "The coach turn needs to decompose constraints before choosing an action.",
              "expected_update": "The answer will update which assumptions are real constraints.",
              "proceed_when": "Proceed when one non-negotiable fact or constraint is named.",
              "evidence_gap_type": "missing_constraint",
              "answer_use": "test_assumption",
              "lens_move": "constraint_decomposition",
              "source_card_titles": ["Meeting ownership unclear"],
              "calibration_target": "The plan depends on a real constraint rather than an inherited assumption",
              "expected_answer_type": "validation"
            }
          ]
        }
        """.utf8
    )

    private static let systemThinkingQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "这个临时修复不断制造返工的反馈回路里，还缺哪条因果链证据？",
              "why_this_matters": "它把单次返工放回系统回路里，同时补上判断回路是否成立的因果证据。",
              "why_now": "当前教练轮次需要先识别反馈回路并补因果链，而不是只修单点症状。",
              "expected_update": "答案会更新对返工结构的系统判断。",
              "proceed_when": "当答案能说出一个可观察的回路节点和一条因果链证据时推进。",
              "evidence_gap_type": "missing_causal_link",
              "answer_use": "update_judgment",
              "lens_move": "feedback_loop",
              "source_card_titles": ["临时修复带来返工"],
              "calibration_target": "临时修复正在形成返工反馈回路",
              "expected_answer_type": "judgment"
            }
          ]
        }
        """.utf8
    )

    private static let questsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Confirm meeting owner",
            "why_it_matters": "It reduces ambiguity.",
            "completion_criteria": "Owner and acceptance criteria are written and acknowledged before implementation starts.",
            "expected_resistance": "People may assume it is obvious.",
            "reflection_question": "Did written ownership reduce ambiguity?",
            "calibration_target": "Written ownership acknowledgement reduces meeting ambiguity",
            "lens_move": "leverage_tradeoff",
            "linked_cards": ["Meeting ownership unclear"]
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let groundedQuestsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Confirm meeting owner",
            "why_it_matters": "It reduces ambiguity.",
            "completion_criteria": "Owner and acceptance criteria are written and acknowledged before implementation starts.",
            "expected_resistance": "People may assume it is obvious.",
            "reflection_question": "Did written ownership reduce ambiguity?",
            "calibration_target": "Written ownership acknowledgement reduces meeting ambiguity",
            "lens_move": "leverage_tradeoff",
            "linked_cards": ["Prepare meeting decisions"]
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let judgmentCalibrationQuestResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Run one small acceptance check",
            "why_it_matters": "It tests whether a smaller acceptance signal reduces rework.",
            "completion_criteria": "Before implementation starts, ask one stakeholder to accept or reject the written criteria and record the observable calibration signal.",
            "expected_resistance": "It may feel slower than continuing implementation.",
            "reflection_question": "Did this small check update the prediction about rework?",
            "calibration_target": "Small acceptance checks reduce rework more than adding implementation detail",
            "lens_move": "prediction_calibration",
            "linked_cards": ["Acceptance criteria unclear"]
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let lowQualityQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "What do you think about the situation?",
              "why_this_matters": "It helps you reflect.",
              "why_now": "",
              "expected_update": "",
              "proceed_when": "",
              "evidence_gap_type": "",
              "answer_use": "",
              "lens_move": "prediction_calibration",
              "source_card_titles": [],
              "calibration_target": "the situation",
              "expected_answer_type": "judgment"
            }
          ]
        }
        """.utf8
    )

    private static let appeasingQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "你已经想得很充分了，可以继续按这个方向推进吗？",
              "why_this_matters": "你的想法很有价值，这个问题帮助你更有信心地行动。",
              "why_now": "当前最重要的是认可你已经做出的判断。",
              "expected_update": "答案会让你更确定自己原来的方向。",
              "proceed_when": "当你觉得有信心时就可以推进。",
              "evidence_gap_type": "none",
              "answer_use": "choose_action",
              "lens_move": "leverage_tradeoff",
              "source_card_titles": ["会议返工来自验收口径不清"],
              "calibration_target": "继续按当前判断推进",
              "expected_answer_type": "judgment"
            }
          ]
        }
        """.utf8
    )

    private static let acknowledgedGapProceedQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "虽然现在证据不足，但你压力很大，是否先继续推进当前方案？",
              "why_this_matters": "这能帮助你在压力下保持行动。",
              "why_now": "当前可以先继续推进，后面再慢慢补证据。",
              "expected_update": "答案会让你选择继续当前方案还是稍后补证据。",
              "proceed_when": "当你决定先推进时就可以进入行动。",
              "evidence_gap_type": "missing_observation",
              "answer_use": "choose_action",
              "lens_move": "leverage_tradeoff",
              "source_card_titles": ["证据不足但想推进"],
              "calibration_target": "先推进当前方案是否能缓解压力",
              "expected_answer_type": "judgment"
            }
          ]
        }
        """.utf8
    )

    private static let nonSystemThinkingQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "还有什么替代解释能说明今天的返工？",
              "why_this_matters": "它检查解释是否过早收敛。",
              "why_now": "当前教练轮次需要检查是否偏离系统思维训练。",
              "expected_update": "答案会更新是否应回到反馈回路分析。",
              "proceed_when": "当答案说明替代解释如何影响系统判断时推进。",
              "evidence_gap_type": "missing_counterexample",
              "answer_use": "test_assumption",
              "lens_move": "alternative_explanation",
              "source_card_titles": ["临时修复带来返工"],
              "calibration_target": "返工主要来自解释过早收敛",
              "expected_answer_type": "validation"
            }
          ]
        }
        """.utf8
    )

    private static let nonLeverageQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "还有什么替代解释能说明今天的返工？",
              "why_this_matters": "它检查解释是否过早收敛。",
              "why_now": "当前教练轮次需要检查是否偏离杠杆分析训练。",
              "expected_update": "答案会更新最高杠杆动作是否仍成立。",
              "proceed_when": "当答案说明替代解释是否改变行动取舍时推进。",
              "evidence_gap_type": "missing_counterexample",
              "answer_use": "test_assumption",
              "lens_move": "alternative_explanation",
              "source_card_titles": ["忙碌但低杠杆"],
              "calibration_target": "最高杠杆动作能减少明天返工",
              "expected_answer_type": "validation"
            }
          ]
        }
        """.utf8
    )

    private static let dimensionMisalignedLeverageQuestionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "明天应该优先做哪个动作来减少会议返工？",
              "why_this_matters": "它帮助选择下一步动作，但没有先补证据或反例。",
              "why_now": "当前教练轮次需要检查行动选择是否跳过证据训练重点。",
              "expected_update": "答案会更新下一步行动边界。",
              "proceed_when": "当答案给出一个可执行动作和取舍理由时推进。",
              "evidence_gap_type": "none",
              "answer_use": "choose_action",
              "lens_move": "leverage_tradeoff",
              "source_card_titles": ["忙碌但低杠杆"],
              "calibration_target": "优先做高杠杆动作能减少会议返工",
              "expected_answer_type": "action"
            }
          ]
        }
        """.utf8
    )

    private static let lowQualityQuestsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Polish the meeting notes",
            "why_it_matters": "It looks more complete.",
            "completion_criteria": "Polish the notes.",
            "expected_resistance": "There may be many details.",
            "reflection_question": "How do you feel?",
            "calibration_target": "the situation"
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let ungroundedQuestsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Run one small acceptance check",
            "why_it_matters": "It closes the evidence gap around rework.",
            "completion_criteria": "Before implementation starts, ask one stakeholder to accept or reject the written criteria and record the observable calibration signal.",
            "expected_resistance": "It may feel slower than continuing implementation.",
            "reflection_question": "Did the check reduce a rework loop?",
            "calibration_target": "Small acceptance checks reduce rework more than adding implementation detail",
            "lens_move": "prediction_calibration",
            "linked_cards": []
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let nonLeverageQuestResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "访谈一个反对方来测试解释",
            "why_it_matters": "它可以检查当前解释是否过早收敛。",
            "completion_criteria": "明天完成一次 15 分钟访谈，记录一个反方证据和一个可观察的校准信号。",
            "expected_resistance": "你会想直接推进当前判断，因为找反方反馈比较慢。",
            "reflection_question": "这条反方证据是否推翻了当前解释？",
            "calibration_target": "返工主要来自对方没有理解当前解释",
            "lens_move": "alternative_explanation",
            "linked_cards": ["忙碌但低杠杆"]
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let principlesResponse = Data(
        """
        {
          "principle_candidate": {
            "title": "Clarify ownership before execution",
            "summary": "Make owner and done criteria explicit before work continues.",
            "trigger_context": "Cross-role work.",
            "actions": ["Write owner", "Write acceptance criteria"],
            "success_criteria": "Owner and acceptance criteria are visible before execution.",
            "exceptions": "Low-stakes sync.",
            "source_card_titles": ["Meeting ownership unclear"]
          }
        }
        """.utf8
    )

    private static let ungroundedPrincipleResponse = Data(
        """
        {
          "principle_candidate": {
            "title": "Clarify ownership before execution",
            "summary": "Make owner and done criteria explicit before work continues.",
            "trigger_context": "Cross-role work.",
            "actions": ["Write owner", "Write acceptance criteria"],
            "success_criteria": "Owner and acceptance criteria are visible before execution.",
            "exceptions": "Low-stakes sync.",
            "source_card_titles": []
          }
        }
        """.utf8
    )

    private static let weakPrincipleActionabilityResponse = Data(
        """
        {
          "principle_candidate": {
            "title": "Keep clear",
            "summary": "Clear communication is important.",
            "trigger_context": "Cross-role work.",
            "actions": ["Be better"],
            "success_criteria": "Things go smoother.",
            "exceptions": "Low-stakes sync.",
            "source_card_titles": ["Meeting ownership unclear"]
          }
        }
        """.utf8
    )

    private static let verificationResponse = Data(
        """
        {
          "calibration_assessment": {"evidence_status": "missing", "criteria_status": "not_assessable", "judgment_status": "unresolved", "evidence_quotes": []},
          "calibration_note": "The quest was useful and verifiable.",
          "likely_issue": "none",
          "recommendation": "Keep criteria explicit."
        }
        """.utf8
    )

    private static func strongVerificationResponse(reportedEvidence: String) -> Data {
        Data(
        """
        {
          "calibration_assessment": {"evidence_status":"observed","criteria_status":"met","judgment_status":"supported","evidence_quotes":["\(reportedEvidence)"]},
          "calibration_note": "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
          "likely_issue": "none",
          "recommendation": "Next calibration: test whether adding acceptance criteria further reduces rework.",
          "expected_principle_practice_assessment": "The expected principle was practiced because the owner acknowledgement matched the selected training signal and produced observable completion evidence."
        }
        """.utf8
    )
    }

    private static let verificationMissingExpectedPrincipleAssessmentResponse = Data(
        """
        {
          "calibration_assessment": {"evidence_status": "observed", "criteria_status": "met", "judgment_status": "supported", "evidence_quotes": ["The owner replied and ambiguity dropped."]},
          "calibration_note": "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
          "likely_issue": "none",
          "recommendation": "Next calibration: test whether adding acceptance criteria further reduces rework."
        }
        """.utf8
    )

    private static let weakVerificationResponse = Data(
        """
        {
          "calibration_assessment": {"evidence_status": "missing", "criteria_status": "not_assessable", "judgment_status": "unresolved", "evidence_quotes": []},
          "calibration_note": "The quest was useful.",
          "likely_issue": null,
          "recommendation": "Keep going."
        }
        """.utf8
    )

    private static let verificationWithoutCriteriaEvidenceResponse = Data(
        """
        {
          "calibration_note": "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied and the thread became quieter. Evidence gained: written acknowledgement was an observable signal. Judgment update: keep written owner confirmation before execution.",
          "likely_issue": "none",
          "recommendation": "Next calibration: test whether earlier owner confirmation reduces rework."
        }
        """.utf8
    )

    private static let verificationWeakRecommendationResponse = Data(
        """
        {
          "calibration_assessment": {"evidence_status": "observed", "criteria_status": "met", "judgment_status": "supported", "evidence_quotes": ["The owner replied and ambiguity dropped."]},
          "calibration_note": "Original prediction: written owner acknowledgement reduces ambiguity. Actual evidence: the owner replied in writing and follow-up ambiguity dropped. Evidence gained: the acknowledgement was the observable signal. Completion criteria met: owner acknowledgement was written before execution. Judgment update: keep written owner confirmation before execution.",
          "likely_issue": "none",
          "recommendation": "Keep going."
        }
        """.utf8
    )

    private static func growthReportResponse(entryID: UUID) -> Data {
        Data(
            """
            {
              "insufficient_evidence": false,
              "summary": "Weekly growth has evidence.",
              "metrics": {
                "clarity": {"value": 3.5, "delta": 0.2, "reason": "More explicit meeting goals."}
              },
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.12,
                  "title": "Prepared meeting decisions",
                  "reason": "The record shows a concrete pre-meeting decision list.",
                  "source_type": "daily_entry",
                  "source_id": "\(entryID.uuidString)",
                  "source_daily_entry_id": "\(entryID.uuidString)"
                }
              ],
              "next_training_focus": "Keep writing meeting decisions before discussions."
            }
            """.utf8
        )
    }

    func testSingleNudge_sendsOnlyCurrentInputAndRecordsSessionSource() async throws {
        let client = CapturingLLMClient(response: Data("{\"question\":\"下一步确认什么？\"}".utf8))
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let sessionID = UUID().uuidString
        let generated = try await service.generateSingleNudge(
            input: "我担心验收范围还不清楚。",
            sessionMode: .standard,
            sourceRecordIDs: [sessionID]
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(generated.promptRunId, request.traceID)
        XCTAssertEqual(payload.currentInput.rawText, "我担心验收范围还不清楚。")
        XCTAssertTrue(payload.cards.isEmpty)
        XCTAssertTrue(payload.answers.isEmpty)
        XCTAssertTrue(payload.quests.isEmpty)
        XCTAssertTrue(payload.principles.isEmpty)
        XCTAssertEqual(request.sourceRecordIDs, [sessionID])
    }

    func testSingleNudgeReview_includesBeforeEvidenceForCognitiveShift() async throws {
        let response = "{\"diagnosis\":\"材料不足。\",\"cognitive_shift\":\"发生变化\",\"thinking_action\":null,\"unresolved_uncertainty\":\"仍需确认\",\"transition_to_verification\":true}"
        let client = CapturingLLMClient(response: Data(response.utf8))
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let result = try await service.reviewSingleNudge(
            input: "我担心范围不清楚", question: "下一步确认什么？", answer: "我会确认验收负责人", before: "我还没有确认负责人", sessionMode: .standard
        )

        let payload = try XCTUnwrap(client.requests.first?.contextPayload)
        XCTAssertEqual(result.value.cognitiveShift, "发生变化")
        XCTAssertTrue(payload.cards.isEmpty)
        XCTAssertTrue(payload.answers.isEmpty)
        XCTAssertTrue(payload.quests.isEmpty)
        XCTAssertTrue(payload.principles.isEmpty)
        XCTAssertTrue(payload.currentInput.rawText?.contains("回答前想法:\n我还没有确认负责人") == true)
    }

    func testSingleNudgeContinuationCarriesOnlyDirectParentRoundAndAuditIDs() async throws {
        let client = CapturingLLMClient(response: Data("{\"question\":\"你刚才没有比较的哪种错题最能检验这个安排？\"}".utf8))
        let service = TodayAIService(promptProvider: LocalPromptProvider(), llmClient: client)
        let parent = SingleNudgeSession(
            dayKey: "2026-09-02",
            input: "学生担心复习安排没有效果。",
            question: "哪一次练习最能说明安排有效？",
            diagnosis: "先把效果标准说清楚。",
            after: "我还没比较错题类型。",
            lifecycle: .receiptPresented
        )
        let childID = UUID().uuidString
        _ = try await service.generateSingleNudge(
            input: parent.input,
            sessionMode: .standard,
            sourceRecordIDs: [childID, parent.id.uuidString],
            continuationKind: .deeper,
            previousRound: parent
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(request.sourceRecordIDs, [childID, parent.id.uuidString])
        XCTAssertTrue(payload.currentInput.rawText?.contains("原卡点：学生担心复习安排没有效果。") == true)
        XCTAssertTrue(payload.currentInput.rawText?.contains("上一问：哪一次练习最能说明安排有效？") == true)
        XCTAssertTrue(payload.currentInput.rawText?.contains("上一轮表达：我还没比较错题类型。") == true)
        XCTAssertTrue(payload.currentInput.rawText?.contains("上一轮点拨：先把效果标准说清楚。") == true)
        XCTAssertTrue(payload.directives.privacyRules?.contains("continuation_mode=deeper") == true)
        XCTAssertTrue(payload.cards.isEmpty)
        XCTAssertTrue(payload.answers.isEmpty)
        XCTAssertTrue(payload.quests.isEmpty)
        XCTAssertTrue(payload.principles.isEmpty)
    }

    func testSingleNudgePromptV110HasRollbackAndGuardrailCoverage() throws {
        let provider = LocalPromptProvider()
        let current = provider.template(for: .singleNudge, mode: .standard)
        XCTAssertEqual(current.version, "1.1.0")
        XCTAssertEqual(current.rollbackTargetVersion, "1.0.0")
        XCTAssertNotNil(provider.template(for: .singleNudge, mode: .standard, version: "1.0.0"))

        // Fixed guardrails that make representative quality deterministic
        // without claiming anything about live model output.
        let guardrails: [(fragment: String, meaning: String)] = [
            ("high-leverage gap", "finds one gap, not a survey"),
            ("Do not give an answer, recommendation, plan, or task", "never answers for the user"),
            ("Do not decide for the user", "no substituted judgment"),
            ("你怎么看", "rejects the generic non-question"),
            ("exactly one concrete question they can answer now", "answerable now"),
            ("Do not infer a role, ability, motive, or stereotype", "no profession stereotypes"),
            ("single-line question with exactly one question mark", "one line, one question mark"),
            ("alternateAngle", "continuation must change entry point"),
            ("deeper", "continuation follows the stated expression")
        ]
        for guardrail in guardrails {
            XCTAssertTrue(
                current.userText.contains(guardrail.fragment),
                "1.1.0 must keep guardrail for \(guardrail.meaning)"
            )
        }
    }

    /// Fixed representative accept/reject matrix for the student, programmer,
    /// and finance contexts. It pins the deterministic quality gate (the
    /// parser), not live model behavior.
    func testSingleNudgeQualityGateAcceptsAndRejectsRepresentativeOutputs() throws {
        let parser = TodayAIResponseParser()
        let accepted: [(context: String, question: String)] = [
            ("学生", "这次复习里，哪一类错题最能说明安排没有效果？"),
            ("程序员", "评审拖慢的三次发布里，哪一次的返工数据最能检验这个判断？"),
            ("金融", "客户这次真正担心的波动范围，哪一个可观察数据能先核对？")
        ]
        for representative in accepted {
            let payload = "{\"question\":\"\(representative.question)\"}"
            let parsed = try parser.parseSingleNudge(from: Data(payload.utf8))
            XCTAssertEqual(parsed, representative.question, "\(representative.context) representative output should parse")
            XCTAssertFalse(parsed.contains("你怎么看"), "\(representative.context) must not degrade to a generic ask")
        }

        // Deterministic rejects: generic ask, direct answer, multiple questions,
        // newlines, role stereotypes. The newline case uses an escaped \n so it
        // exercises the gate itself rather than failing as broken JSON.
        let rejected = [
            "你怎么看？",
            "建议先停掉所有评审会。",
            "先确认返工次数？再确认评审耗时？",
            "哪一次返工最能说明问题？\\n谁来确认？",
            "程序员是不是天生不擅长沟通？"
        ]
        for output in rejected {
            let payload = "{\"question\":\"\(output)\"}"
            XCTAssertThrowsError(
                try parser.parseSingleNudge(from: Data(payload.utf8)),
                "gate must reject: \(output)"
            )
        }
    }

    private static func lensFeedback(
        lens: ThinkingLens,
        signal: String,
        target: String
    ) -> PromptContextPayload.LensFeedbackContext {
        PromptContextPayload.LensFeedbackContext(
            lensId: lens.rawValue,
            lensTitle: lens.title,
            signal: signal,
            completion: YesterdayCompletion.done.rawValue,
            valueRating: signal == "avoid" ? YesterdayValueRating.low.rawValue : YesterdayValueRating.high.rawValue,
            calibrationNote: "历史验证：\(target)",
            recommendation: "按 \(target) 调整下一轮问题。",
            questionTargets: [target],
            evidenceGapTypes: [EvidenceGapType.missingCalibrationSignal.rawValue],
            lensMoves: lens == .judgmentCalibration
                ? [QuestionLensMove.predictionCalibration.rawValue]
                : [QuestionLensMove.factInterpretationSplit.rawValue]
        )
    }
}

private final class CapturingLLMClient: LLMClient {
    private let response: Data
    private(set) var requests: [LLMRequest] = []

    init(response: Data) {
        self.response = response
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        return response
    }
}

private struct FixedMemoryContextAssembler: ContextAssembler {
    var lensFeedback: [PromptContextPayload.LensFeedbackContext]
    var coachTurnState: CoachTurnState?

    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext {
        let payload = PromptContextPayload(
            currentInput: .init(
                dailyEntryId: context.draft.id.uuidString,
                rawText: context.draft.rawText
            ),
            userChoice: .init(
                sessionMode: context.draft.sessionMode.rawValue,
                selectedLens: context.draft.selectedLens?.rawValue
            ),
            cards: context.confirmedCards.map { card in
                .init(
                    id: card.id.uuidString,
                    type: card.type.rawValue,
                    title: card.title,
                    body: card.body,
                    priority: card.priority.rawValue,
                    sensitivity: card.sensitivity.rawValue,
                    isExcludedFromModel: card.isExcludedFromModel
                )
            },
            answers: context.questions.map { question in
                .init(
                    id: question.id.uuidString,
                    question: question.question,
                    answer: question.answer,
                    calibrationTarget: question.calibrationTarget
                )
            },
            lensFeedback: lensFeedback,
            coachTurnState: coachTurnState.map(PromptContextPayload.CoachTurnStateContext.init)
        )

        var sourceRecordIDs = [context.draft.id.uuidString]
        sourceRecordIDs.append(contentsOf: context.confirmedCards.map { $0.id.uuidString })
        sourceRecordIDs.append(contentsOf: context.questions.map { $0.id.uuidString })
        sourceRecordIDs.append(contentsOf: context.quests.map { $0.id.uuidString })
        sourceRecordIDs = Array(Set(sourceRecordIDs)).sorted()

        return PromptContext(
            version: 1,
            inputSummary: "fixed-memory-test",
            contextPayload: payload,
            sourceRecordIDs: sourceRecordIDs,
            contextRecordIDs: sourceRecordIDs
        )
    }
}

private final class StreamingCapturingLLMClient: LLMClient, StreamingLLMClient {
    private let tokens: [String]
    private(set) var requests: [LLMRequest] = []
    private(set) var completeRequestCount = 0
    private(set) var streamRequestCount = 0

    init(tokens: [String]) {
        self.tokens = tokens
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        completeRequestCount += 1
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest, isolation: isolated (any Actor)?) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        streamRequestCount += 1
        requests.append(request)
        return AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(.token(token))
            }
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}
