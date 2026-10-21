import XCTest
@testable import MingSi

final class LocalPromptProviderTests: XCTestCase {
    private let provider = LocalPromptProvider()
    func testCurrentMentorDoesNotConfuseFatigueOrQuotedWordingWithExtraQuestions() {
        for mode in SessionMode.allCases {
            let current = provider.template(for: .mentorRespond, mode: mode)
            XCTAssertFalse(current.systemText.contains("倾听、疲惫、拒绝、想结束时 question=null。"))
            XCTAssertFalse(current.systemText.contains("body 只写陈述句，不使用问号。"))
            XCTAssertTrue(current.systemText.contains("用户明确希望通过一个问题梳理标准"))
            XCTAssertTrue(current.systemText.contains("引用用户原话或按请求示范给第三方的问句"))
        }
    }

    func testRequestBoundaryRevisionPreservesPriorPromptAndWireContract() throws {
        for mode in SessionMode.allCases {
            let current = provider.template(for: .mentorRespond, mode: mode)
            let prior = try XCTUnwrap(provider.template(for: .mentorRespond, mode: mode, version: "2.16.0"))
            XCTAssertEqual(current.version, "2.17.0")
            XCTAssertEqual(current.rollbackTargetVersion, prior.version)
            XCTAssertEqual(current.outputSchemaVersion, prior.outputSchemaVersion)
            XCTAssertEqual(current.userText, prior.userText)
            XCTAssertEqual(current.contextPolicyVersion, prior.contextPolicyVersion)
            XCTAssertTrue(prior.systemText.contains("倾听、疲惫、拒绝、想结束时 question=null。"))
            XCTAssertTrue(prior.systemText.contains("body 只写陈述句，不使用问号。"))
            XCTAssertTrue(current.systemText.contains("usesSelectedExcerpts=true"))
            XCTAssertTrue(current.systemText.contains("不得把实际向用户的补问放进引号"))
        }
    }

    func testSelectedExcerptsRespectOmittedContentAndPreservePriorAsset() throws {
        let current = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.16.0"))
        let old = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.15.0"))
        XCTAssertEqual(current.version, "2.16.0")
        XCTAssertEqual(current.rollbackTargetVersion, old.version)
        XCTAssertFalse(old.systemText.contains("usesSelectedExcerpts"))
        XCTAssertTrue(current.systemText.contains("usesSelectedExcerpts=true"))
        XCTAssertTrue(current.systemText.contains("不能从来源编号、历史轮数、元数据或指代重建未选原话"))
        XCTAssertTrue(current.systemText.contains("老师片段仅帮助理解"))
        XCTAssertTrue(current.systemText.hasPrefix(old.systemText))
        XCTAssertEqual(current.outputSchemaVersion, old.outputSchemaVersion)
    }

    func testMentorFeelingsDoNotOverrideRequestedHelpOrForceTraining() throws {
        for mode in SessionMode.allCases {
            let current = try XCTUnwrap(provider.template(for: .mentorRespond, mode: mode, version: "2.15.0"))
            let prior = try XCTUnwrap(provider.template(for: .mentorRespond, mode: mode, version: "2.14.0"))
            XCTAssertEqual(current.version, "2.15.0")
            XCTAssertEqual(current.rollbackTargetVersion, prior.version)
            XCTAssertEqual(current.outputSchemaVersion, prior.outputSchemaVersion)
            XCTAssertTrue(prior.userText.contains("只有一个思考动作、至多一个问题"))
            XCTAssertTrue(current.userText.contains("倾听或收束不强加训练"))
            XCTAssertTrue(prior.systemText.contains("疲惫、只想聊、不想总结时回应陪伴，不分析、不安排任务"))
            XCTAssertTrue(prior.systemText.contains("每轮一个而且只有一个可辨认的思考动作"))
            XCTAssertFalse(current.systemText.contains("疲惫、只想聊、不想总结时回应陪伴，不分析、不安排任务"))
            XCTAssertFalse(current.systemText.contains("每轮一个而且只有一个可辨认的思考动作"))
            XCTAssertFalse(current.systemText.contains("Do not decide for the user."))
            XCTAssertTrue(current.systemText.contains("不用安慰替代实际帮助"))
            XCTAssertTrue(current.systemText.contains("倾听、表达示范与收束无需附加训练"))
            XCTAssertTrue(current.systemText.contains("如果随后主动请求帮助，按新的请求继续"))
            XCTAssertTrue(current.systemText.contains("不据此诊断人格或思考能力"))
        }
    }

    func testGuidanceSelectionVersionsDoNotRewriteHistoricalPolicy() throws {
        let current = provider.template(for: .recommendGuidance, mode: .standard)
        let old = try XCTUnwrap(provider.template(for: .recommendGuidance, mode: .standard, version: "1.0.0"))
        XCTAssertEqual(current.version, "1.1.0")
        XCTAssertEqual(current.rollbackTargetVersion, old.version)
        XCTAssertEqual(current.outputSchemaVersion, old.outputSchemaVersion)
        XCTAssertTrue(old.userText.contains("current evidence gap"))
        XCTAssertFalse(old.userText.contains("modelReview"))
        XCTAssertTrue(current.userText.contains("NOT diagnoses"))
        XCTAssertTrue(current.userText.contains("modelReview.userBoundary is stop"))
        XCTAssertTrue(current.userText.contains("do not require an observable evidence gap"))
    }

    func testMentorUncertaintyRevisionKeepsPriorAssetAndWireSchemaFrozen() throws {
        let current = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.14.0"))
        let prior = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.13.0"))
        XCTAssertEqual(current.rollbackTargetVersion, prior.version)
        XCTAssertEqual(current.outputSchemaVersion, prior.outputSchemaVersion)
        XCTAssertEqual(current.userText, prior.userText)
        XCTAssertTrue(prior.systemText.contains("拒绝、不知道或想结束时停止追问。"))
        XCTAssertFalse(current.systemText.contains("拒绝、不知道或想结束时停止追问。"))
        XCTAssertTrue(current.systemText.contains("仅说不知道原因、记不清或不确定，不能推断用户想结束"))
        XCTAssertTrue(current.systemText.contains("不保证拒绝或沟通一定有效"))
    }

    func testDirectHelpSchemaKeepsPreviousQuestionOnlyAssetFrozen() throws {
        let current = provider.template(for: .generateQuestions, mode: .standard)
        let previous = try XCTUnwrap(provider.template(for: .generateQuestions, mode: .standard, version: "1.28.0"))
        XCTAssertEqual(current.rollbackTargetVersion, previous.version)
        XCTAssertEqual(previous.outputSchemaVersion, 6)
        XCTAssertEqual(current.outputSchemaVersion, 7)
        XCTAssertFalse(previous.userText.contains("Direct-help response contract"))
        XCTAssertTrue(current.userText.contains("Direct-help response contract"))
        XCTAssertTrue(current.userText.contains("No hidden questions, homework"))
        XCTAssertFalse(current.userText.contains("or an end, return {\"questions\": []}"))
    }


    func testPerspectivePromptUsesKnownPositionsAndPreservesOldCatalogContract() throws {
        for mode in SessionMode.allCases {
            let current = provider.template(for: .generateQuestions, mode: mode)
            let previous = try XCTUnwrap(provider.template(for: .generateQuestions, mode: mode, version: "1.27.0"))
            XCTAssertEqual(current.version, "1.29.0")
            XCTAssertEqual(current.rollbackTargetVersion, "1.28.0")
            XCTAssertEqual(current.outputSchemaVersion, previous.outputSchemaVersion + 1)
            XCTAssertTrue(previous.userText.contains("grounded in an actual evidence gap or disconfirming signal"))
            XCTAssertFalse(current.userText.contains("grounded in an actual evidence gap or disconfirming signal"))
            XCTAssertTrue(previous.userText.contains("Selected-lens contract (builtin.v2)"))
            XCTAssertTrue(current.userText.contains("Selected-lens contract (builtin.v3)"))
            XCTAssertTrue(current.userText.contains("represent the other person's explicitly stated aim"))
            XCTAssertTrue(current.userText.contains("do not invent a sympathetic story"))
            XCTAssertTrue(current.userText.contains("use evidence_gap_type=none when nothing is missing"))
            let diagnosis = provider.template(for: .diagnoseTrainingCase, mode: mode)
            let oldDiagnosis = try XCTUnwrap(provider.template(for: .diagnoseTrainingCase, mode: mode, version: "1.2.0"))
            XCTAssertTrue(oldDiagnosis.userText.contains("Versioned lens catalog (builtin.v2)"))
            XCTAssertTrue(oldDiagnosis.userText.contains("准确理解另一方表达与处境，区分理解、认同和替对方找理由。"))
            XCTAssertFalse(oldDiagnosis.userText.contains("准确表述双方已知的诉求与限制"))
            XCTAssertTrue(diagnosis.userText.contains("准确表述双方已知的诉求与限制"))
            XCTAssertEqual(diagnosis.rollbackTargetVersion, oldDiagnosis.version)
        }
    }

    func testCoachDecisionNamesMaterialGapAndRetainsHistoricalRollback() throws {
        for mode in SessionMode.allCases {
            let current = provider.template(for: .diagnoseTrainingCase, mode: mode)
            let prior = try XCTUnwrap(provider.template(for: .diagnoseTrainingCase, mode: mode, version: "1.0.0"))
            XCTAssertEqual(current.version, "1.3.0")
            XCTAssertEqual(current.outputSchemaVersion, 2)
            XCTAssertEqual(current.rollbackTargetVersion, "1.2.0")
            XCTAssertEqual(prior.outputSchemaVersion, 1)
            XCTAssertFalse(prior.userText.contains("open_evidence_gaps"))
            for rule in ["at most ONE", "not a diagnosis of the user's ability", "not_ready with []",
                         "Never claim missing observation/baseline just because", "source_refs", "Respect rest, correction and refusal"] {
                XCTAssertTrue(current.userText.contains(rule), rule)
            }
            XCTAssertFalse(current.userText.contains("what the user must repair next"))
        }
    }

    func testMentorUpgradeRetainsHistoricalTemplatesAndRollback() throws {
        for id in [PromptID.mentorRespond, .mentorDraftUnderstanding] {
            let current = provider.template(for: id, mode: .standard)
            let previousEvidenceRefresh = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.6.0"))
            let previousEvidenceUpdate = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "2.5.0"))
            let previousTurnBoundary = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "2.4.0"))
            let previousRecommendation = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "2.3.0"))
            let previousConvergent = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "2.2.0"))
            let previousProgressive = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "2.1.0"))
            let previousCurrent = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "2.0.0"))
            let latestHistorical = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "1.9.0"))
            let prior = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "1.8.0"))
            let previous = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "1.7.0"))
            let earlier = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "1.6.0"))
            let legacy = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "1.5.0"))
            let original = try XCTUnwrap(provider.template(for: id, mode: .standard, version: "1.0.0"))
            XCTAssertEqual(current.version, id == .mentorRespond ? "2.17.0" : "2.6.0")
            XCTAssertEqual(current.rollbackTargetVersion, id == .mentorRespond ? "2.16.0" : "2.5.0")
            XCTAssertEqual(previousEvidenceUpdate.version, "2.5.0")
            XCTAssertEqual(previousEvidenceUpdate.rollbackTargetVersion, "2.4.0")
            XCTAssertEqual(previousTurnBoundary.version, "2.4.0")
            XCTAssertEqual(previousTurnBoundary.rollbackTargetVersion, "2.3.0")
            XCTAssertEqual(previousRecommendation.version, "2.3.0")
            XCTAssertEqual(previousRecommendation.rollbackTargetVersion, "2.2.0")
            XCTAssertEqual(previousConvergent.version, "2.2.0")
            XCTAssertEqual(previousConvergent.rollbackTargetVersion, "2.1.0")
            XCTAssertEqual(previousProgressive.version, "2.1.0")
            XCTAssertEqual(previousProgressive.rollbackTargetVersion, "2.0.0")
            XCTAssertEqual(previousCurrent.version, "2.0.0")
            XCTAssertEqual(previousCurrent.rollbackTargetVersion, "1.9.0")
            XCTAssertEqual(latestHistorical.version, "1.9.0")
            XCTAssertEqual(latestHistorical.rollbackTargetVersion, "1.8.0")
            XCTAssertEqual(prior.rollbackTargetVersion, previous.version)
            XCTAssertEqual(previous.rollbackTargetVersion, earlier.version)
            XCTAssertEqual(legacy.rollbackTargetVersion, "1.4.0")
            XCTAssertEqual(prior.systemPolicyVersion, "mentor.system.1.8.0")
            XCTAssertEqual(previous.systemPolicyVersion, "mentor.system.1.7.0")
            XCTAssertEqual(earlier.systemPolicyVersion, "mentor.system.1.6.0")
            XCTAssertEqual(original.systemPolicyVersion, "mentor.system.1.0.0")
            XCTAssertNotEqual(current.systemText, prior.systemText)
            XCTAssertNotEqual(current.userText, previousCurrent.userText)
            if id == .mentorRespond {
                XCTAssertNotEqual(current.userText, previousEvidenceUpdate.userText)
                XCTAssertEqual(previousEvidenceRefresh.version, "2.6.0")
                XCTAssertEqual(previousEvidenceRefresh.rollbackTargetVersion, "2.5.0")
                XCTAssertTrue(previousEvidenceRefresh.userText.contains("多轮证据更新检查"))
                XCTAssertFalse(current.userText.contains("多轮证据更新检查"))
                XCTAssertLessThan(current.systemText.count + current.userText.count,
                                  previousEvidenceRefresh.systemText.count + previousEvidenceRefresh.userText.count)
            }
            XCTAssertNotEqual(current.userText, previousConvergent.userText)
            XCTAssertNotEqual(current.userText, previousProgressive.userText)
            if id == .mentorRespond {
                XCTAssertNotEqual(current.userText, previousTurnBoundary.userText)
                XCTAssertTrue(current.systemText.contains("当前多轮边界优先于历史问题和旧结论"))
                XCTAssertTrue(current.userText.contains("当前轮与渐进式反馈检查"))
            }
            XCTAssertNotEqual(prior.systemText, previous.systemText)
            XCTAssertNotEqual(previous.systemText, earlier.systemText)
            XCTAssertNotEqual(earlier.systemText, original.systemText)
            XCTAssertNotEqual(current.userText, prior.userText)
            XCTAssertNotEqual(current.userText, previousRecommendation.userText)
            XCTAssertNotEqual(previous.userText, original.userText)
            XCTAssertEqual(current.outputSchemaVersion, original.outputSchemaVersion)
            XCTAssertEqual(current.contextPolicyVersion, original.contextPolicyVersion)
            XCTAssertFalse(original.systemText.contains("最新用户自然语言纠正"))
            XCTAssertFalse(current.systemText.contains("suggested_actions 是最多 5 项"))
            XCTAssertFalse(current.userText.contains("suggested_actions 是最多 5 项"))
            if id == .mentorRespond {
                XCTAssertTrue((previous.systemText + previous.userText).contains("suggested_actions 是最多 5 项"))
            }
            XCTAssertNil(provider.template(for: id, mode: .standard, version: "99.0.0"))
        }
    }

    func testMentorPromptPrioritizesRequestedHelpBeforeOptionalQuestion() {
        let response = provider.template(for: .mentorRespond, mode: .standard)
        let combined = response.systemText + "\n" + response.userText
        XCTAssertEqual(response.version, "2.17.0")
        for phrase in [
            "先辨认用户此刻需要理解、比较、建议、倾听还是纠正",
            "答案会实质改变帮助时才问一项",
            "所有对用户的追问只能放在 question",
            "intent=explain 或用户明确说“直接讲”",
            "latest_user_source_ref",
            "conversation_state",
            "不要一次列出所有可能的解释",
            "需要分析时只推进一个有用的思考动作",
            "当前多轮边界优先于历史问题和旧结论",
            "指出哪条新事实改变了什么",
            "保持一条连续的思考线",
            "说明依据、适用条件和限制",
            "一个关键薄弱处或替代解释",
            "第二个可见回合后的默认收束不是硬上限",
            "这限制补材料问题数，不限制整个对话轮数",
            "不要只写“请说说今天”"
        ] {
            XCTAssertTrue(combined.contains(phrase), "missing mentor guidance: \(phrase)")
        }
        XCTAssertTrue(combined.contains("回看首轮入口不占两轮补材料预算"))
        XCTAssertTrue(combined.contains("`visible_turn_index >= 2`"))
        XCTAssertTrue(combined.contains("讲解、比较、建议、澄清分别采用"))
        XCTAssertTrue(combined.contains("正文不得藏新的反问"))
    }

    func testMentorRecommendationUsesUserOwnedCriteriaRatherThanInventedPriorities() {
        let current = provider.template(for: .mentorRespond, mode: .standard)
        let text = current.systemText + "\n" + current.userText
        XCTAssertEqual(current.version, "2.17.0")
        XCTAssertTrue(text.contains("缺少会改变选择的目标或可接受代价时"))
        XCTAssertTrue(text.contains("给出条件式取舍"))
        XCTAssertTrue(text.contains("不能从“帮我选”推断用户更重视收入、效率、休息或关系"))
        XCTAssertTrue(text.contains("价值偏好属于选择标准"))
        XCTAssertTrue(text.contains("允许未知，不要求用户证明价值偏好"))
    }

    func testMentorSeparatesReportedEventsFromSelfLabelsAndPreservesPriorAsset() throws {
        let current = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.14.0"))
        let old = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.12.0"))
        let prior = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.13.0"))
        XCTAssertEqual(current.rollbackTargetVersion, prior.version)
        XCTAssertEqual(prior.rollbackTargetVersion, old.version)
        XCTAssertEqual(current.outputSchemaVersion, old.outputSchemaVersion)
        XCTAssertTrue(old.systemText.contains("建议的第一段必须给出首选或明确偏向"))
        XCTAssertFalse(old.systemText.contains("给出条件式取舍"))
        XCTAssertTrue(current.systemText.contains("自我标签不等于已证实的人格事实"))
        XCTAssertTrue(current.systemText.contains("一般原则和条件式示例"))
    }

    func testMentorPromptGivesAConditionalRecommendationWhenTheUserAsksForOne() {
        let response = provider.template(for: .mentorRespond, mode: .standard)
        let combined = response.systemText + "\n" + response.userText
        XCTAssertTrue(combined.contains("说明依据、适用条件和限制"))
        XCTAssertTrue(combined.contains("不要以“由你决定”回避判断"))
        XCTAssertTrue(combined.contains("第一段必须给出首选或明确偏向"))
        XCTAssertTrue(combined.contains("指出一个关键薄弱处"))
        XCTAssertTrue(combined.contains("不为了安慰而同意"))
        XCTAssertFalse(combined.contains("最多 5 项不重复建议"))
        XCTAssertTrue(combined.contains("suggested_actions 最多给两个"))
        let draft = provider.template(for: .mentorDraftUnderstanding, mode: .standard)
        XCTAssertTrue(draft.userText.contains("不能写成用户已经认可的决定"))
        XCTAssertFalse(draft.userText.contains("最多 5 项不重复建议"))
    }

    func testMentorSingleQuestionGuardKeepsHistoricalReplayUnchanged() throws {
        let current = provider.template(for: .mentorRespond, mode: .standard)
        let combined = current.systemText + "\n" + current.userText
        let previous = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.7.0"))
        let singleQuestion = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.8.0"))
        let evidenceBoundary = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.9.0"))
        let shortClarification = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.10.0"))
        let routedClarification = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.11.0"))
        let consolidated = try XCTUnwrap(provider.template(for: .mentorRespond, mode: .standard, version: "2.12.0"))
        XCTAssertEqual(current.rollbackTargetVersion, "2.16.0")
        XCTAssertEqual(consolidated.rollbackTargetVersion, routedClarification.version)
        XCTAssertEqual(routedClarification.rollbackTargetVersion, shortClarification.version)
        XCTAssertEqual(shortClarification.rollbackTargetVersion, evidenceBoundary.version)
        XCTAssertEqual(evidenceBoundary.rollbackTargetVersion, singleQuestion.version)
        XCTAssertEqual(singleQuestion.rollbackTargetVersion, previous.version)
        XCTAssertEqual(previous.rollbackTargetVersion, "2.6.0")
        XCTAssertEqual(singleQuestion.systemText, previous.systemText)
        XCTAssertTrue(singleQuestion.userText.hasPrefix(previous.userText))
        XCTAssertTrue(combined.contains("body 的说明使用陈述句"))
        XCTAssertTrue(combined.contains("不得把实际向用户的补问放进引号"))
        XCTAssertTrue(combined.contains("回看补问只选择一个观察角度"))
        XCTAssertFalse(previous.userText.contains("单问输出检查"))
        XCTAssertTrue(evidenceBoundary.userText.hasPrefix(singleQuestion.userText))
        XCTAssertFalse(singleQuestion.userText.contains("证据与提问负担检查"))
        XCTAssertTrue(combined.contains("不代表它们存在因果、先后依赖或价值高低"))
        XCTAssertTrue(combined.contains("只问一个用户凭已有经历就能回答的短问题"))
        XCTAssertTrue(combined.contains("即使没有问号，这些仍然算额外的问题"))
        XCTAssertTrue(combined.contains("首句只确认用户已给出的事实"))
        XCTAssertFalse(evidenceBoundary.userText.contains("clarify 的正文采用更小的固定职责"))
        XCTAssertTrue(current.systemText.contains("本身就是有效帮助"))
        XCTAssertTrue(current.systemText.contains("不能因为已有事项名称"))
        XCTAssertFalse(shortClarification.systemText.contains("当前澄清规则优先于"))
    }

    func testMentorPromptRoutesListeningAndThinkingMovesWithoutForcingAnalysis() {
        let response = provider.template(for: .mentorRespond, mode: .standard)
        let combined = response.systemText + "\n" + response.userText
        for phrase in ["question=null", "分开事实与解释", "区分目标与手段", "说明选项与代价", "关键假设与反例", "可观察信号"] {
            XCTAssertTrue(combined.contains(phrase), "missing mentor guidance: \(phrase)")
        }
        XCTAssertTrue(combined.contains("不能用反问替代回答"))
        XCTAssertTrue(combined.contains("不强行转成教学或行动计划"))
        XCTAssertTrue(combined.contains("思考与引导服从当前请求"))
        XCTAssertTrue(combined.contains("需要分析时只推进一个有用的思考动作"))
        XCTAssertTrue(combined.contains("倾听、表达示范与收束无需附加训练"))
        XCTAssertTrue(combined.contains("有 `latest_user_source_ref` 时，所有非收束回应必须引用这个本轮锚点"))
        XCTAssertTrue(combined.contains("不要只写“请说说今天”"))
    }

    func testMentorUnderstandingPromptCanCombineUserExpressionsWithoutInventingAgreement() {
        let draft = provider.template(for: .mentorDraftUnderstanding, mode: .standard)
        let combined = draft.systemText + "\n" + draft.userText
        XCTAssertTrue(combined.contains("所有仍有效且属于用户的表达"))
        XCTAssertTrue(combined.contains("合并多条表达"))
        XCTAssertTrue(combined.contains("不能替用户补出认识、认可或承诺"))
        XCTAssertTrue(combined.contains("没有合法用户表达时才不生成草稿"))
    }

    func testCoachAnswerReviewPromptStopsWhenReadyAndRetainsRollback() throws {
        let current = provider.template(for: .reviewCoachAnswer, mode: .standard)
        XCTAssertEqual(current.version, "1.5.0")
        XCTAssertEqual(current.rollbackTargetVersion, "1.4.0")
        let v140 = try XCTUnwrap(provider.template(for: .reviewCoachAnswer, mode: .standard, version: "1.4.0"))
        XCTAssertEqual(v140.rollbackTargetVersion, "1.3.0")
        XCTAssertTrue(v140.userText.contains("exactly one concrete repair question"))
        XCTAssertFalse(current.userText.contains("exactly one concrete repair question"))
        let v130 = try XCTUnwrap(provider.template(for: .reviewCoachAnswer, mode: .standard, version: "1.3.0"))
        XCTAssertEqual(v130.rollbackTargetVersion, "1.2.0")
        XCTAssertFalse(v130.userText.contains("all four optional fields above MUST"))
        XCTAssertTrue(current.userText.contains("all optional guidance fields MUST"))
        XCTAssertTrue(current.userText.contains("one or two short sentences"))
        XCTAssertTrue(current.userText.contains("is_latest_answer=true"))
        XCTAssertTrue(current.userText.contains("An unresolved gap does not require a follow-up"))
        XCTAssertTrue(current.userText.contains("single most important remaining gap"))
        XCTAssertTrue(current.userText.contains("at most one of"))
        XCTAssertTrue(current.userText.contains("Never manufacture a follow-up"))
        XCTAssertTrue(current.userText.contains("user_boundary"))
        XCTAssertTrue(current.userText.contains("does not want to continue answering"))

        let previous = try XCTUnwrap(provider.template(for: .reviewCoachAnswer, mode: .standard, version: "1.2.0"))
        XCTAssertEqual(previous.version, "1.2.0")
        XCTAssertEqual(previous.rollbackTargetVersion, "1.1.0")
        XCTAssertNotEqual(previous.userText, current.userText)
        XCTAssertTrue(previous.userText.contains("next_repair_question"))

        let prior = try XCTUnwrap(provider.template(for: .reviewCoachAnswer, mode: .standard, version: "1.1.0"))
        XCTAssertEqual(prior.version, "1.1.0")
        XCTAssertEqual(prior.rollbackTargetVersion, "1.0.0")
        XCTAssertNotEqual(prior.userText, previous.userText)

        let original = try XCTUnwrap(provider.template(for: .reviewCoachAnswer, mode: .standard, version: "1.0.0"))
        XCTAssertEqual(original.version, "1.0.0")
        XCTAssertNil(original.rollbackTargetVersion)
        XCTAssertNotEqual(original.userText, prior.userText)
    }

    func testCurrentCoachAnswerReviewDoesNotRetainQuestionnaireQuotaOrInheritedPrompt() {
        let current = provider.template(for: .reviewCoachAnswer, mode: .standard)
        XCTAssertFalse(current.userText.contains("Question count: quick 1-2"))
        XCTAssertFalse(current.userText.contains("At least one question must"))
        XCTAssertTrue(current.userText.contains("one current matter's latest answer"))
        XCTAssertTrue(current.userText.contains("same training gap"))
        XCTAssertTrue(current.userText.contains("source_refs"))
    }

    func testMentorUnderstandingPromptPreservesUncertaintyAndRejectsAssistantAuthorship() {
        let understanding = provider.template(for: .mentorDraftUnderstanding, mode: .standard)
        XCTAssertTrue(understanding.userText.contains("保留原表达的确定程度、否定、疑问、拒绝和未决定"))
        XCTAssertTrue(understanding.userText.contains("助手的话不等于认可"))
        XCTAssertTrue(understanding.userText.contains("不能写“我认可这个方法，决定每天执行”"))
    }

    func testEveryPromptTemplate_hasCommonThinkingCoachGuardrails() {
        for promptID in PromptID.allCases {
            let template = provider.template(for: promptID, mode: .standard)
            let combined = "\(template.systemText)\n\(template.userText)"

            if promptID == .organizeCards {
                XCTAssertTrue(combined.contains("MINGSI_STREAM_V2"), "\(promptID.rawValue) must require streaming XML output")
                XCTAssertTrue(combined.contains("Do not return JSON"), "\(promptID.rawValue) must avoid JSON for streaming output")
            } else {
                XCTAssertTrue(combined.contains("Return valid JSON"), "\(promptID.rawValue) must require JSON output")
            }
            let authorityRule = promptID == .mentorRespond ? "Preserve the user's authority over choices" : "Do not decide for the user"
            XCTAssertTrue(combined.contains(authorityRule), "\(promptID.rawValue) must preserve the user's authority")
            let thinkingRule = promptID == .mentorRespond ? "do not invent their priorities" : "Do not replace the user's thinking"
            XCTAssertTrue(combined.contains(thinkingRule), "\(promptID.rawValue) must preserve user agency")
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
        XCTAssertTrue(text.contains("Depth changes scrutiny and evidence quality, not the number of questions"))
    }

    func testGenerateQuestionsTemplate_requiresCoachQualityEvidenceGapAndCalibrationQuestions() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("evidence gap"))
        XCTAssertTrue(text.contains("disconfirming signal"))
        XCTAssertTrue(text.contains("feedback_loop"))
        XCTAssertTrue(text.contains("second_order_consequence"))
        XCTAssertTrue(text.contains("prediction_calibration"))
        XCTAssertTrue(text.contains("next calibration signal"))
        XCTAssertTrue(text.contains("values and acceptable costs are valid material for a choice"))
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
        XCTAssertTrue(text.contains("`calibration_target` must be X"))
    }

    func testGenerateQuestionsTemplate_requiresFunctionalCoachFields() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("\"why_now\""))
        XCTAssertTrue(text.contains("\"expected_update\""))
        XCTAssertTrue(text.contains("\"proceed_when\""))
        XCTAssertTrue(text.contains("why this question is the right next move"))
        XCTAssertTrue(text.contains("what judgment, action, evidence plan, or calibration signal the answer is expected to change"))
        XCTAssertTrue(text.contains("what is enough to answer this question, allowing an honest unknown"))
    }

    func testGenerateQuestionsTemplate_keepsHistoryAsReportedEvidence() {
        let text = provider.template(for: .generateQuestions, mode: .standard).userText
        XCTAssertTrue(text.contains("Historical evidence boundary"))
        XCTAssertTrue(text.contains("self_report_only"))
        XCTAssertTrue(text.contains("lensMoves"))
        XCTAssertTrue(text.contains("does not establish"))
        XCTAssertFalse(text.contains("Use lensFeedback as verified outcomes"))
        XCTAssertFalse(text.contains("do not repeat a lens move that produced low-value"))
    }

    func testGenerateQuestionsTemplate_doesNotUseHiddenCoachPlanVocabulary() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertFalse(text.contains("trainingPrescription"))
        XCTAssertFalse(text.contains("primaryTrainingDimension"))
        XCTAssertFalse(text.contains("secondaryTrainingDimensions"))
        XCTAssertFalse(text.contains("baselineTrainingDimensions"))
        XCTAssertFalse(text.contains("coachTeachingPlan"))
        XCTAssertTrue(text.contains("selected lens"))
        XCTAssertTrue(text.contains("optional viewing context"))
    }

    func testGenerateQuestionsTemplate_doesNotUseCoachTeachingPlanAsTrainingFrame() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertFalse(text.contains("coachTeachingPlan"))
        XCTAssertFalse(text.contains("missingMoveTitle"))
        XCTAssertFalse(text.contains("whyNotAnswer"))
        XCTAssertFalse(text.contains("proceedStandard"))
        XCTAssertFalse(text.contains("repairQuestion"))
        XCTAssertFalse(text.contains("experienceReplayPrompt"))
        XCTAssertTrue(text.contains("one primary training contract"))
    }

    func testGenerateQuestionsTemplate_doesNotUseLocalObservationAsOnlineEvidence() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertFalse(text.contains("coachObservation"))
        XCTAssertFalse(text.contains("local heuristic observation"))
        XCTAssertTrue(text.contains("Evidence ownership and precedence"))
        XCTAssertTrue(text.contains("provisional hypotheses or user choices"))
    }

    func testGenerateQuestionsTemplate_declaresQuestionTrainingContract() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("Question training contract"))
        XCTAssertTrue(text.contains("one primary training contract"))
        XCTAssertTrue(text.contains("Confirmed cards and the user's latest answer are the only evidence"))
        XCTAssertTrue(text.contains("provisional hypotheses or user choices"))
        XCTAssertTrue(text.contains("one distinction or piece of information the user can address from the supplied material"))
        XCTAssertTrue(text.contains("must not provide the missing material"))
        XCTAssertTrue(text.contains("`why_now` must name the observed gap"))
        XCTAssertTrue(text.contains("`expected_update` must name the specific judgment or choice"))
        XCTAssertTrue(text.contains("including an honest unknown when evidence is unavailable"))
        XCTAssertFalse(text.contains("experienceReplayPrompt"))
    }

    func testGenerateQuestionsTemplate_prefersOneMinimalTurnOverAQuestionnaire() {
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("This request is one coaching turn"))
        XCTAssertTrue(text.contains("With no prior answer, return zero or one primary question"))
        XCTAssertTrue(text.contains("return an empty questions array"))
        XCTAssertTrue(text.contains("not a questionnaire and not a complete lesson plan"))
    }

    func testCurrentTodayLoopTemplates_useTomorrowValidationLanguage() {
        let questionText = provider.template(for: .generateQuestions, mode: .standard).userText
        let questText = provider.template(for: .generateQuests, mode: .standard).userText

        XCTAssertFalse(questionText.contains("明日验证"))
        XCTAssertFalse(questionText.contains("验证行动"))
        XCTAssertFalse(questionText.contains("明日实验"))
        XCTAssertFalse(questionText.contains("明天实验"))
        XCTAssertFalse(questionText.contains("校准实验"))
        XCTAssertFalse(questionText.contains("小实验"))

        XCTAssertTrue(questText.contains("Never turn waiting into a deadline"))
        XCTAssertTrue(questText.contains("验证行动"))
        XCTAssertFalse(questText.contains("明日实验"))
        XCTAssertFalse(questText.contains("明天实验"))
        XCTAssertFalse(questText.contains("校准实验"))
        XCTAssertFalse(questText.contains("小实验"))
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
        XCTAssertTrue(text.contains("Do not diagnose personality, intelligence, motivation, health, or hidden intent"))
        XCTAssertTrue(text.contains("Every correction must say what was observed"))
    }

    func testGenerateQuestsAndExtractPrincipleTemplatesDeclareEmpathyIsNotAgreement() {
        let questText = provider.template(for: .generateQuests, mode: .standard).userText
        let principleText = provider.template(for: .extractPrinciple, mode: .standard).userText

        XCTAssertTrue(questText.contains("Empathy is not agreement"))
        XCTAssertTrue(questText.contains("Do not invent one to challenge the user"))
        XCTAssertTrue(principleText.contains("Empathy is not agreement"))
        XCTAssertTrue(principleText.contains("Acknowledge pressure or context only when it helps the user face the real reusable-rule gap"))
    }

    func testGenerateQuestsTemplate_requiresOneMainQuestAndVerifiableCriteria() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("exactly one main validation action"))
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

    func testGenerateQuestsTemplateSeparatesObservableTargetFromEvidenceLimits() {
        for mode in SessionMode.allCases {
            let text = provider.template(for: .generateQuests, mode: mode).userText
            XCTAssertTrue(text.contains("starting point when grounded"))
            XCTAssertTrue(text.contains("no implied user endorsement or causal upgrade"))
            XCTAssertTrue(text.contains("concrete negative prediction"))
            XCTAssertTrue(text.contains("leave calibration_target unresolved"))
            XCTAssertTrue(text.contains("not truncation rules"))
            XCTAssertTrue(text.contains("Never turn waiting into a deadline"))
        }
    }

    func testActionPromptDoesNotRequireFirstPersonBeliefOrRepeatedXYZNarrative() {
        let text = provider.template(for: .generateQuests, mode: .standard).userText
        XCTAssertFalse(text.contains("我现在相信 X"), "A suggested hypothesis must not become an invented user belief")
        XCTAssertFalse(text.contains("judgment sentence: keep this shape"), "Field roles should replace repetitive full-sentence coaching")
    }

    func testGenerateQuestsTemplate_doesNotInferMethodEffectivenessFromOutcomes() {
        let text = provider.template(for: .generateQuests, mode: .standard).userText
        XCTAssertTrue(text.contains("Historical evidence boundary"))
        XCTAssertTrue(text.contains("self-ratings only"))
        XCTAssertFalse(text.contains("Use lensFeedback as verified lens outcomes"))
        XCTAssertFalse(text.contains("Reinforce lensMoves that produced high-value calibration evidence"))
        XCTAssertFalse(text.contains("avoid repeating quest patterns"))
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
        XCTAssertTrue(text.contains("Do not turn a weak judgment into a validation action just to let the user proceed"))
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
        XCTAssertTrue(text.contains("Completing an action proves only that the action was attempted"))
        XCTAssertTrue(text.contains("keep the judgment open"))
        XCTAssertTrue(text.contains("two or three short sentences"))
        XCTAssertTrue(text.contains("Put the next test here only, not again in calibration_note"))
        XCTAssertTrue(text.contains("currentInput.rawText as the user's recorded observable evidence"))
    }

    func testCoreCoachPrompts_preserveEvidenceOwnershipAcrossTheLoop() {
        let questions = provider.template(for: .generateQuestions, mode: .standard).userText
        let quests = provider.template(for: .generateQuests, mode: .standard).userText
        let principles = provider.template(for: .extractPrinciple, mode: .standard).userText

        XCTAssertTrue(questions.contains("Confirmed cards and the user's latest answer are the only evidence"))
        XCTAssertTrue(questions.contains("coach context is provisional hypotheses or user choices"))
        XCTAssertTrue(questions.contains("Separate what happened, what the user inferred"))
        XCTAssertTrue(quests.contains("Delivery/completion alone does not establish the target judgment"))
        XCTAssertTrue(quests.contains("discriminating signal"))
        XCTAssertTrue(principles.contains("one favorable outcome is not enough"))
        XCTAssertTrue(principles.contains("preserve it for later verification"))
    }

    func testCoreCoachPrompts_groundWorkInTheConditionThatMatters() {
        let questions = provider.template(for: .generateQuestions, mode: .standard).userText
        let quests = provider.template(for: .generateQuests, mode: .standard).userText

        XCTAssertTrue(questions.contains("one smallest move"))
        XCTAssertTrue(questions.contains("provisional hypotheses"))
        XCTAssertTrue(questions.contains("return an empty questions array"))
        XCTAssertTrue(quests.contains("affected person/object"))
        XCTAssertTrue(quests.contains("not proof of value or improvement"))
        XCTAssertTrue(quests.contains("within the user's permission"))
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

    func testHistoricalEvidencePromptUpgradePreservesPriorAssets() throws {
        for (id, previous, version) in [(PromptID.generateQuestions, "1.24.0", "1.29.0"),
            (.generateQuests, "1.9.0", "1.12.0"), (.weeklyCalibration, "1.0.0", "1.1.0"), (.monthlyGrowth, "1.0.0", "1.1.0")] {
            let current = provider.template(for: id, mode: .standard)
            let legacy = try XCTUnwrap(provider.template(for: id, mode: .standard, version: previous))
            XCTAssertEqual(current.version, version)
            XCTAssertEqual(current.rollbackTargetVersion, id == .generateQuests ? "1.11.0" : (id == .generateQuestions ? "1.28.0" : previous))
            XCTAssertTrue(current.userText.contains("Historical evidence boundary"))
            XCTAssertFalse(legacy.userText.contains("Historical evidence boundary"))
            XCTAssertNotEqual(current.userText, legacy.userText)
        }
    }

    func testQuestionExplanationContractPreservesPriorPromptAndNeverRequiresNewEvidenceForAnAnswer() throws {
        for mode in SessionMode.allCases {
            let current = provider.template(for: .generateQuestions, mode: mode)
            let previous = try XCTUnwrap(provider.template(for: .generateQuestions, mode: mode, version: "1.25.0"))
            XCTAssertEqual(current.rollbackTargetVersion, "1.28.0")
            XCTAssertEqual(previous.rollbackTargetVersion, "1.24.0")
            XCTAssertEqual(current.outputSchemaVersion, previous.outputSchemaVersion + 1)
            XCTAssertTrue(previous.userText.contains("what answer is sufficient to move toward action"))
            XCTAssertFalse(previous.userText.contains("Each explanation field is at most one short sentence"))
            XCTAssertTrue(current.userText.contains("A missing fact may remain unknown"))
            XCTAssertTrue(current.userText.contains("Do not ask for evidence the user has already said is unavailable"))
            XCTAssertTrue(current.userText.contains("None of these fields grants or denies permission to finish reflecting"))
            XCTAssertTrue(current.userText.contains("hide a second question, checklist or assignment in metadata"))
            XCTAssertFalse(current.userText.contains("`expected_update` must name the user-owned training output"))
        }
    }

    func testGenerateQuestionsCurrentTemplate_declaresLocalRollbackTarget() {
        let current = provider.template(for: .generateQuestions, mode: .standard)

        XCTAssertEqual(current.version, "1.29.0")
        XCTAssertEqual(current.outputSchemaVersion, 7)
        XCTAssertEqual(current.rollbackTargetVersion, "1.28.0")
        XCTAssertTrue(current.userText.contains("Turn contract"))
        XCTAssertTrue(current.userText.contains("zero or one question"))
        XCTAssertTrue(current.userText.contains("Never return the original question and a repair question together"))
        XCTAssertTrue(current.userText.contains("not a questionnaire"))
        XCTAssertTrue(current.userText.contains("Evidence ownership and precedence"))
        XCTAssertTrue(current.userText.contains("direct practical answer"))
        XCTAssertTrue(current.userText.contains("optional viewing context"))
        XCTAssertTrue(current.userText.contains("would a tired person understand"))
        XCTAssertTrue(current.userText.contains("userChoice.selectedLens=null"))
        XCTAssertTrue(current.userText.contains("review the confirmed material on its own"))
        XCTAssertTrue(current.userText.contains("Never mention that a lens"))
        XCTAssertFalse(current.userText.contains("trainingPrescription"))
        XCTAssertFalse(current.userText.contains("coachDiagnosis"))
        XCTAssertFalse(current.userText.contains("coachTurnState"))
        XCTAssertFalse(current.userText.contains("coachTeachingPlan"))
        XCTAssertFalse(current.userText.contains("at most two items"))
        XCTAssertFalse(current.userText.contains("standard 3"))
        XCTAssertFalse(current.userText.contains("deep 4-5"))

        let v123 = provider.template(for: .generateQuestions, mode: .standard, version: "1.23.0")
        XCTAssertEqual(v123?.version, "1.23.0")
        XCTAssertEqual(v123?.rollbackTargetVersion, "1.22.0")
        XCTAssertFalse(v123?.userText.contains("userChoice.selectedLens=null") ?? true)

        let v122 = provider.template(for: .generateQuestions, mode: .standard, version: "1.22.0")
        XCTAssertEqual(v122?.version, "1.22.0")
        XCTAssertEqual(v122?.rollbackTargetVersion, "1.21.0")
        XCTAssertTrue(v122?.userText.contains("Evidence ownership and precedence") ?? false)
        XCTAssertTrue(v122?.userText.contains("trainingPrescription") ?? false)

        let rollback = provider.template(for: .generateQuestions, mode: .standard, version: "1.21.0")
        XCTAssertEqual(rollback?.rollbackTargetVersion, "1.20.0")
        XCTAssertTrue(rollback?.userText.contains("Evidence ledger and hypothesis boundary") ?? false)
        XCTAssertFalse(rollback?.userText.contains("coachObservation") ?? true)

        let previous = provider.template(for: .generateQuestions, mode: .standard, version: "1.17.0")
        XCTAssertEqual(previous?.rollbackTargetVersion, "1.16.0")
        XCTAssertTrue(previous?.userText.contains("Active request contract") ?? false)
    }

    func testCurrentPromptModeGuidance_removesLegacyQuestionQuotaFromDownstreamPrompts() {
        for id in [PromptID.organizeCards, .recommendLenses, .generateQuests, .verifyQuest, .extractPrinciple, .reviewCoachAnswer] {
            for mode in SessionMode.allCases {
                let text = provider.template(for: id, mode: mode).userText
                XCTAssertFalse(text.contains("three questions"), "\(id.rawValue)/\(mode.rawValue) still carries the legacy question quota")
                XCTAssertFalse(text.contains("4-5"), "\(id.rawValue)/\(mode.rawValue) still carries the legacy deep quota")
            }
        }
    }

    func testGenerateQuestionsV140HistoricalPromptAsset_stillResolves() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.14.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.14.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.13.0")
        XCTAssertTrue(historical?.userText.contains("This request is one coaching turn") ?? false)
        XCTAssertFalse(historical?.userText.contains("Single-move output boundary") ?? true)
    }

    func testGenerateQuestionsV130HistoricalPromptAsset_stillResolvesForMinimalTurnRollback() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.13.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.13.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.12.0")
        XCTAssertTrue(historical?.userText.contains("True-need grounding") ?? false)
        XCTAssertFalse(historical?.userText.contains("This request is one coaching turn") ?? true)
    }

    func testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .generateQuestions, mode: .standard)
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.12.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.12.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.11.0")
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
        XCTAssertTrue(historical?.userText.contains("明日验证") ?? false)
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

    func testGenerateQuestionsV119HistoricalPromptAsset_stillResolvesForRollbackHistory() {
        let historical = provider.template(for: .generateQuestions, mode: .standard, version: "1.19.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.19.0")
        XCTAssertEqual(historical?.outputSchemaVersion, 6)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.18.0")
        XCTAssertTrue(historical?.userText.contains("Active request contract") ?? false)
        XCTAssertFalse(historical?.userText.contains("User-value gate") ?? true)
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

    func testGenerateQuestsCurrentTemplate_declaresLocalRollbackTarget() throws {
        let current = provider.template(for: .generateQuests, mode: .standard)
        XCTAssertEqual(current.version, "1.12.0")
        XCTAssertEqual(current.outputSchemaVersion, 3)
        XCTAssertEqual(current.rollbackTargetVersion, "1.11.0")
        XCTAssertTrue(current.userText.contains("side_quests` must always be an empty array"))
        XCTAssertTrue(current.userText.contains("observation_quest` must always be null"))
        XCTAssertFalse(current.userText.contains("at most two side quests"))
        XCTAssertTrue(current.userText.contains("repeated discussion topic only describes what was discussed"))
        let prior = try XCTUnwrap(provider.template(for: .generateQuests, mode: .standard, version: "1.11.0"))
        let original = try XCTUnwrap(provider.template(for: .generateQuests, mode: .standard, version: "1.10.0"))
        XCTAssertEqual(prior.rollbackTargetVersion, "1.10.0")
        XCTAssertTrue(prior.userText.hasPrefix(original.userText))
        XCTAssertTrue(prior.userText.contains("Historical topic boundary:"))
        XCTAssertTrue(prior.userText.contains("我现在相信 X"))
        XCTAssertFalse(original.userText.contains("Historical topic boundary:"))
        XCTAssertFalse(current.userText.hasPrefix(original.userText), "Current instructions are standalone, not layered corrections")
    }

    func testGenerateQuestsRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .generateQuests, mode: .standard)
        let historical = provider.template(for: .generateQuests, mode: .standard, version: "1.7.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.7.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, 3)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.6.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("Generate tomorrow's validation actions") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"calibration_target\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"lens_move\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("not a satisfaction-maximizing assistant") ?? false)
        XCTAssertTrue(historical?.userText.contains("Empathy is not agreement") ?? false)
        XCTAssertTrue(historical?.userText.contains("coachTeachingPlan") ?? false)
        XCTAssertTrue(historical?.userText.contains("明日验证") ?? false)

        let prior180 = provider.template(for: .generateQuests, mode: .standard, version: "1.8.0")
        XCTAssertEqual(prior180?.version, "1.8.0")
        XCTAssertEqual(prior180?.rollbackTargetVersion, "1.7.0")
        XCTAssertTrue(prior180?.userText.contains("at most two side quests") ?? false)
        XCTAssertNotEqual(prior180?.userText, current.userText)

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

    func testGuidanceEvidenceSeparatesMissingDescriptionsAndKeepsHistoricalPrompt() throws {
        let current = provider.template(for: .evaluateGuidanceEvidence, mode: .standard)
        XCTAssertEqual(current.version, "1.1.0")
        XCTAssertEqual(current.outputSchemaVersion, 2)
        XCTAssertEqual(current.rollbackTargetVersion, "1.0.0")
        XCTAssertTrue(current.userText.contains("not evidence of regression"))
        XCTAssertTrue(current.userText.contains("evidence_quotes"))
        let original = try XCTUnwrap(provider.template(for: .evaluateGuidanceEvidence, mode: .standard, version: "1.0.0"))
        XCTAssertEqual(original.outputSchemaVersion, 1)
        XCTAssertNil(original.rollbackTargetVersion)
        XCTAssertTrue(original.userText.contains("hinted behavior was missing or contradicted"))
        XCTAssertFalse(original.userText.contains("evidence_quotes"))
    }

    func testVerifyQuestCurrentTemplate_declaresLocalRollbackTarget() {
        let current = provider.template(for: .verifyQuest, mode: .standard)

        XCTAssertEqual(current.version, "1.11.0")
        XCTAssertEqual(current.outputSchemaVersion, 5)
        XCTAssertEqual(current.rollbackTargetVersion, "1.10.0")
        XCTAssertTrue(current.userText.contains("calibration receipt"))
        XCTAssertTrue(current.userText.contains("Completing an action proves only that the action was attempted"))
        XCTAssertTrue(current.userText.contains("growth_evidence_items"))
        XCTAssertTrue(current.userText.contains("Separate reported practice from outcome"))
        XCTAssertTrue(current.userText.contains("principle_practice_assessment"))
        XCTAssertFalse(current.userText.contains("standard is the default full loop"))
    }

    func testVerifyQuestRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .verifyQuest, mode: .standard)
        let prior1100 = provider.template(for: .verifyQuest, mode: .standard, version: "1.10.0")
        XCTAssertEqual(prior1100?.outputSchemaVersion, 4)
        XCTAssertEqual(prior1100?.rollbackTargetVersion, "1.9.0")
        XCTAssertTrue(prior1100?.userText.contains("calibration_assessment") == true)
        XCTAssertFalse(prior1100?.userText.contains("\"principle_practice_assessment\":") == true)
        let previous = provider.template(for: .verifyQuest, mode: .standard, version: "1.9.0")
        XCTAssertEqual(previous?.rollbackTargetVersion, "1.8.0")
        XCTAssertEqual(previous?.outputSchemaVersion, 3)
        XCTAssertTrue(previous?.userText.contains("observed facts, the judgment update, and the next test") ?? false)
        XCTAssertFalse(previous?.userText.contains("two or three short sentences") ?? true)
        let historical = provider.template(for: .verifyQuest, mode: .standard, version: "1.8.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.8.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, 3)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.7.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("trainingPrinciple") ?? false)
        XCTAssertTrue(historical?.userText.contains("\"expected_principle_practice_assessment\"") ?? false)

        let prior170 = provider.template(for: .verifyQuest, mode: .standard, version: "1.7.0")
        XCTAssertEqual(prior170?.version, "1.7.0")
        XCTAssertEqual(prior170?.rollbackTargetVersion, "1.6.0")
        XCTAssertTrue(prior170?.userText.contains("Completing an action proves only that the action was attempted") ?? false)

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

        XCTAssertEqual(current.version, "1.6.0")
        XCTAssertEqual(current.rollbackTargetVersion, "1.5.0")
        XCTAssertTrue(current.userText.contains("candidate extraction step"))
        XCTAssertTrue(current.userText.contains("at least two concrete, independently described instances"))
        XCTAssertTrue(current.userText.contains("source_card_titles"))
        XCTAssertTrue(current.userText.contains("Return exactly:"))
        XCTAssertTrue(current.userText.contains("Empathy is not agreement"))
    }

    func testExtractPrincipleRollbackTarget_resolvesHistoricalPromptAsset() {
        let current = provider.template(for: .extractPrinciple, mode: .standard)
        let historical = provider.template(for: .extractPrinciple, mode: .standard, version: "1.5.0")

        XCTAssertNotNil(historical)
        XCTAssertEqual(historical?.version, "1.5.0")
        XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
        XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
        XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
        XCTAssertEqual(historical?.outputSchemaVersion, current.outputSchemaVersion)
        XCTAssertEqual(historical?.rollbackTargetVersion, "1.4.0")
        XCTAssertNotEqual(historical?.userText, current.userText)
        XCTAssertTrue(historical?.userText.contains("\"source_card_titles\"") ?? false)
        XCTAssertTrue(historical?.userText.contains("exact titles from confirmedCards") ?? false)
        XCTAssertTrue(historical?.userText.contains("at least two concrete actions") ?? false)
        XCTAssertTrue(historical?.userText.contains("not a satisfaction-maximizing assistant") ?? false)
        XCTAssertTrue(historical?.userText.contains("Empathy is not agreement") ?? false)

        let prior140 = provider.template(for: .extractPrinciple, mode: .standard, version: "1.4.0")
        XCTAssertEqual(prior140?.version, "1.4.0")
        XCTAssertEqual(prior140?.rollbackTargetVersion, "1.3.0")

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

        XCTAssertTrue(quick.userText.contains("Choose one primary thinking move for this turn"))
        XCTAssertTrue(standard.systemText.contains("standard is the default full loop"))
        XCTAssertTrue(deep.systemText.contains("deep uses more scrutiny"))
        XCTAssertTrue(deep.userText.contains("Depth changes scrutiny and evidence quality, not the number of questions"))
    }
}
