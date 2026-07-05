import XCTest

final class MingSiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        let acceptPrescription = app.buttons["today.training-prescription.accept-action"]
        XCTAssertTrue(acceptPrescription.waitForExistence(timeout: 8))
        acceptPrescription.tap()
        tapPrimaryAction(in: app, expectingState: "answer_questions")

        typeFirstQuestionAnswer("事实是会议结束后没有明确负责人；验收标准是明天会议记录里写出负责人和可检查结果，再验证最小行动是否降低返工。", in: app)
        tapPrimaryAction(in: app, expectingState: "review_quests")

        tapPrimaryAction(in: app, expectingState: "extract_principle")
        tapPrimaryAction(in: app, expectingState: "session_complete")

        XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
    }

    func testTodayTrainingPrescriptionShowsPrimaryFocusAndBaselineChecks() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        XCTAssertTrue(app.staticTexts["明思观察了你的材料"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["诊断主要缺口"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["推荐训练处方"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["教练判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["当前阶段：补证据"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["建议：先减缓收敛，补齐关键证据。"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["缺口：缺观察事实、缺基线"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["主练：证据意识"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["底盘检查"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["证据缺口"].exists)
    }

    func testTodayTrainingPrescriptionShowsTeachingRoute() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        XCTAssertFalse(app.staticTexts["本轮漏想点"].exists)
        XCTAssertFalse(app.staticTexts["本轮练什么"].exists)
        XCTAssertFalse(app.staticTexts["为什么不能直接给答案"].exists)
        XCTAssertFalse(app.staticTexts["补缺动作"].exists)
        XCTAssertFalse(app.staticTexts["怎么练"].exists)
        XCTAssertFalse(app.staticTexts["训练目标"].exists)
        XCTAssertFalse(app.staticTexts["教练追问"].exists)
        XCTAssertFalse(app.staticTexts["训练契约"].exists)
        XCTAssertFalse(app.staticTexts["训练边界"].exists)
        XCTAssertFalse(app.staticTexts["训练路线"].exists)

        let routeToggle = app.buttons["today.training-prescription.teaching-toggle"]
        XCTAssertTrue(routeToggle.waitForExistence(timeout: 4))
        routeToggle.tap()

        XCTAssertTrue(app.staticTexts["本轮漏想点"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["本轮练什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["为什么不能直接给答案"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["建议补充"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["怎么练"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["训练契约"].exists)
        XCTAssertFalse(app.staticTexts["训练边界"].exists)
        XCTAssertFalse(app.staticTexts["训练路线"].exists)
        XCTAssertFalse(app.staticTexts["补缺动作"].exists)
        let missingMove = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "可观察证据")
        ).firstMatch
        XCTAssertTrue(missingMove.waitForExistence(timeout: 4))
        let routeStep = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "补上一个可观察事实")
        ).firstMatch
        XCTAssertTrue(routeStep.waitForExistence(timeout: 4))
    }

    func testTodayTrainingPrescriptionOverrideShowsCoachAuditBoundary() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        let overrideAction = app.buttons["today.lens.opposingView-action"]
        scrollToElement(overrideAction, in: app)
        overrideAction.tap()

        let overrideAudit = app.descendants(matching: .any)["today.training-prescription.decision-override-audit"]
        scrollToElement(overrideAudit, in: app)
        XCTAssertTrue(overrideAudit.waitForExistence(timeout: 4))
        XCTAssertTrue(overrideAudit.label.contains("改选为「反方视角」"))
        XCTAssertTrue(overrideAudit.label.contains("教练推荐「证据校验」"))
        XCTAssertTrue(overrideAudit.label.contains("仍保留为审计"))
    }

    func testTodayReviewCardsSeedExposesActionAndCardControls() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 8))
        XCTAssertTrue(primaryAction.isEnabled)
        XCTAssertTrue(app.buttons["today.card.confirm-action"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["today.card.exclude-action"].exists)
    }

    func testTodayReviewCardsCanNavigateBackToCaptureWithPreviousAction() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        let previousAction = app.buttons["today.previous-action"]
        XCTAssertTrue(previousAction.waitForExistence(timeout: 8))
        previousAction.tap()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.primary-action"].waitForExistence(timeout: 4))
    }

    func testTodayCaptureShowsMaterialScaffold() throws {
        let app = seededTodayApp(stage: "capture")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["今日理解闭环"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["今天内容 → 今日复盘"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["行动验证闭环"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["明日验证 → 结果校准"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["闭环一：今天内容与今日复盘"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["先把今天发生了什么、你怎么做、你怎么想讲清楚；这里只完成理解，不设计明天行动。"].exists)
        let boundaryToggle = app.buttons["today.loop-boundary-toggle"]
        XCTAssertTrue(boundaryToggle.waitForExistence(timeout: 4))
        boundaryToggle.tap()
        XCTAssertTrue(app.staticTexts["先把今天发生了什么、你怎么做、你怎么想讲清楚；这里只完成理解，不设计明天行动。"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["今天内容"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["本页只写今天内容"].exists)
        XCTAssertFalse(app.staticTexts["基础能力训练"].exists)
        XCTAssertTrue(app.buttons["today.capture.guidance-toggle"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["发生了什么"].waitForExistence(timeout: 4))
    }

    func testTodayCaptureShowsCoachObservationFromCurrentDraft() throws {
        let app = seededTodayApp(stage: "capture", input: "先让 Alex 写清验收标准。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["本句观察"].waitForExistence(timeout: 4))
        let goalGap = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "行动不能先替代目标")
        ).firstMatch
        XCTAssertTrue(goalGap.waitForExistence(timeout: 4))
        let serviceObjectAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题会变少")
        ).firstMatch
        XCTAssertTrue(serviceObjectAsk.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["本次练什么"].exists)
        let trainingContract = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "不是让 AI 替你给答案")
        ).firstMatch
        XCTAssertFalse(trainingContract.exists)
        XCTAssertTrue(app.staticTexts["建议补充"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["下一句训练"].exists)
        XCTAssertFalse(app.staticTexts["自检标准"].exists)

        let trainingToolsToggle = app.buttons["today.capture.training-tools-toggle"]
        XCTAssertTrue(trainingToolsToggle.waitForExistence(timeout: 4))
        trainingToolsToggle.tap()

        XCTAssertTrue(app.staticTexts["本次练什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(trainingContract.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["自检标准"].waitForExistence(timeout: 4))
        let selfCheck = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "服务对象、成功标准和可观察信号")
        ).firstMatch
        XCTAssertTrue(selfCheck.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesVagueStoryAsDescriptionTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "今天有点乱，感觉推进不下去。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let provided = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "已说清")
        ).firstMatch
        XCTAssertTrue(provided.waitForExistence(timeout: 4))
        let descriptionTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "沟通力中的描述力")
        ).firstMatch
        XCTAssertTrue(descriptionTraining.waitForExistence(timeout: 4))
        let narrativeOrder = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还缺")
        ).firstMatch
        XCTAssertTrue(narrativeOrder.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "我作为听众现在只能听懂")
        ).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "我听不懂的是")
        ).firstMatch.exists)
        let concreteAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "什么背景下，谁做了什么，触发点是什么，后来发生了什么")
        ).firstMatch
        XCTAssertTrue(concreteAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesExperienceReplayWithoutFitCheck() throws {
        let app = seededTodayApp(stage: "capture", input: "之前这样做有效，所以这次我也打算照着做。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let replayTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "过往经验复现训练")
        ).firstMatch
        XCTAssertTrue(replayTraining.waitForExistence(timeout: 4))
        let fitCheck = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "复现、调整，还是否定")
        ).firstMatch
        XCTAssertTrue(fitCheck.waitForExistence(timeout: 4))
        let conditionGap = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "条件差异")
        ).firstMatch
        XCTAssertTrue(conditionGap.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesBlockedProgressAsConstraintTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "今天在项目沟通中，我和产品团队讨论接口方案，但推进不下去，后来决定先暂停方案调整。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let analysisTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力中的分析力")
        ).firstMatch
        XCTAssertTrue(analysisTraining.waitForExistence(timeout: 4))
        let missingConstraint = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还没说清具体限制")
        ).firstMatch
        XCTAssertTrue(missingConstraint.waitForExistence(timeout: 4))
        let constraintAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "时间、资源、权限、信息、关系还是系统边界")
        ).firstMatch
        XCTAssertTrue(constraintAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesCausalShortcutAsAnalysisTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "我看到会议结束后没有明确负责人，后来接口方案实际返工。因为大家都不想负责，所以方案没有通过。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let analysisTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力中的分析力")
        ).firstMatch
        XCTAssertTrue(analysisTraining.waitForExistence(timeout: 4))
        let causalShortcut = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "跳步的因果解释")
        ).firstMatch
        XCTAssertTrue(causalShortcut.waitForExistence(timeout: 4))
        let mechanismAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "A 到 B 中间发生了什么")
        ).firstMatch
        XCTAssertTrue(mechanismAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesUnchallengedExplanationAsCounterexampleTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "我看到用户代表在评审里提出三处流程问题，后来方案实际延期。我认为延期是因为流程问题影响了验收判断，中间链条是评审问题先让验收标准变模糊，再导致方案延期。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let analysisTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力中的分析力")
        ).firstMatch
        XCTAssertTrue(analysisTraining.waitForExistence(timeout: 4))
        let counterexampleTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "反例")
        ).firstMatch
        XCTAssertTrue(counterexampleTraining.waitForExistence(timeout: 4))
        let alternativeAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "替代解释")
        ).firstMatch
        XCTAssertTrue(alternativeAsk.waitForExistence(timeout: 4))
        let weakenAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "削弱当前解释")
        ).firstMatch
        XCTAssertTrue(weakenAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesActionWithoutGoalAsJudgmentTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "先让 Alex 写清验收标准。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let judgmentTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力中的判断力")
        ).firstMatch
        XCTAssertTrue(judgmentTraining.waitForExistence(timeout: 4))
        let actionBeforeGoal = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "行动不能先替代目标")
        ).firstMatch
        XCTAssertTrue(actionBeforeGoal.waitForExistence(timeout: 4))
        let serviceObjectAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题会变少")
        ).firstMatch
        XCTAssertTrue(serviceObjectAsk.waitForExistence(timeout: 4))
        let successCriteriaAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "成功标准")
        ).firstMatch
        XCTAssertTrue(successCriteriaAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesVagueActionAsExecutionTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "为了让 Alex 减少返工，明天推进方案处理一下。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let executionTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "执行力")
        ).firstMatch
        XCTAssertTrue(executionTraining.waitForExistence(timeout: 4))
        let checkableResult = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还不是可检查结果")
        ).firstMatch
        XCTAssertTrue(checkableResult.waitForExistence(timeout: 4))
        let concreteAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "完成后留下什么证据")
        ).firstMatch
        XCTAssertTrue(concreteAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesJudgmentWithoutEvidenceAsObservationTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "我觉得这个方案大概率会返工。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let observationTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "观察力")
        ).firstMatch
        XCTAssertTrue(observationTraining.waitForExistence(timeout: 4))
        let prematureConclusion = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "判断不能先当结论")
        ).firstMatch
        XCTAssertTrue(prematureConclusion.waitForExistence(timeout: 4))
        let evidenceAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "可观察事实")
        ).firstMatch
        XCTAssertTrue(evidenceAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesJudgmentWithoutStandardAsJudgmentTraining() throws {
        let app = seededTodayApp(
            stage: "capture",
            input: "我看到客服记录了 12 条用户反馈，3 个用户卡在注册步骤。我判断注册流程需要优先改。"
        )
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let judgmentTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力中的判断力")
        ).firstMatch
        XCTAssertTrue(judgmentTraining.waitForExistence(timeout: 4))
        let conclusionGap = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "判断不能只停在结论")
        ).firstMatch
        XCTAssertTrue(conclusionGap.waitForExistence(timeout: 4))
        let standardAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "判断标准")
        ).firstMatch
        XCTAssertTrue(standardAsk.waitForExistence(timeout: 4))
        let tradeoffAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "取舍依据")
        ).firstMatch
        XCTAssertTrue(tradeoffAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesJudgmentWithoutCalibrationSignalAsCalibrationTraining() throws {
        let app = seededTodayApp(
            stage: "capture",
            input: "我看到客服记录了 12 条用户反馈，3 个用户卡在注册步骤。我判断注册流程需要优先改，判断标准是影响新用户完成首次使用。"
        )
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let calibrationTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力中的校准力")
        ).firstMatch
        XCTAssertTrue(calibrationTraining.waitForExistence(timeout: 4))
        let futureSignal = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "判断需要未来信号")
        ).firstMatch
        XCTAssertTrue(futureSignal.waitForExistence(timeout: 4))
        let signalAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "明天或近期哪个信号")
        ).firstMatch
        XCTAssertTrue(signalAsk.waitForExistence(timeout: 4))
        let updateAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "更新判断")
        ).firstMatch
        XCTAssertTrue(updateAsk.waitForExistence(timeout: 4))
    }

    func testTodayCaptureChallengesMissingObjectAsDescriptionTraining() throws {
        let app = seededTodayApp(stage: "capture", input: "今天需求评审后，我打算先重写方案，后来方案没有通过。")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        let descriptionTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "沟通力中的描述力")
        ).firstMatch
        XCTAssertTrue(descriptionTraining.waitForExistence(timeout: 4))
        let missingObject = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还没说清服务对象")
        ).firstMatch
        XCTAssertTrue(missingObject.waitForExistence(timeout: 4))
        let impactAsk = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题")
        ).firstMatch
        XCTAssertTrue(impactAsk.waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsSeedCanTypeThroughAccessibilityIdentifier() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        typeFirstQuestionAnswer("事实是会议结束后没有明确负责人；验收标准是明天会议记录里写出负责人和可检查结果，再验证最小行动是否降低返工。", in: app)

        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(primaryAction.isEnabled)
    }

    func testTodayAnswerQuestionsPrioritizesQuestionAndAnswerBeforeDiagnostics() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["闭环一：今天内容与今日复盘"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["教练追问"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["回答一个关键问题。"].exists)
        XCTAssertTrue(app.staticTexts["修补一个关键缺口。"].waitForExistence(timeout: 4))

        let questionText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "先补上一个可观察事实")
        ).firstMatch
        XCTAssertTrue(questionText.waitForExistence(timeout: 4))

        XCTAssertTrue(app.staticTexts["本轮训练"].waitForExistence(timeout: 4))
        let primaryTraining = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "主练")
        ).firstMatch
        XCTAssertTrue(primaryTraining.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["本题练：分离事实解释"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先补：缺观察事实"].waitForExistence(timeout: 4))
        let notAnswer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "不是让 AI 替你给答案")
        ).firstMatch
        XCTAssertFalse(notAnswer.exists)
        XCTAssertTrue(app.staticTexts["先补"].waitForExistence(timeout: 4))

        let answerField = app.textFields.matching(identifier: "today.question.answer-field").firstMatch
        XCTAssertTrue(answerField.waitForExistence(timeout: 4))
        XCTAssertLessThan(answerField.frame.minY, primaryTraining.frame.minY)

        let coachBasisToggle = app.buttons["today.question.coach-basis-toggle"].firstMatch
        XCTAssertTrue(coachBasisToggle.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["能力训练诊断"].exists)
        XCTAssertFalse(app.staticTexts["训练动作"].exists)
        XCTAssertFalse(app.staticTexts["作答方式"].exists)

        coachBasisToggle.tap()
        XCTAssertTrue(app.staticTexts["这一题练什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["为什么现在问"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["答案会改变"].exists)
        XCTAssertTrue(app.staticTexts["答完要更清楚"].waitForExistence(timeout: 4))
        let answerUpdateCopy = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "这次作答会")
        ).firstMatch
        XCTAssertTrue(answerUpdateCopy.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["什么时候继续"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["怎么回答"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["训练动作"].exists)
        XCTAssertFalse(app.staticTexts["补的缺口"].exists)
        XCTAssertFalse(app.staticTexts["作答要更新"].exists)
        XCTAssertFalse(app.staticTexts["作答方式"].exists)

        let diagnosisToggle = app.buttons["today.answer.diagnosis-toggle"].firstMatch
        scrollToElement(diagnosisToggle, in: app)
        XCTAssertTrue(diagnosisToggle.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["能力训练诊断"].exists)

        diagnosisToggle.tap()
        XCTAssertTrue(app.staticTexts["能力训练诊断"].waitForExistence(timeout: 4))
        let abilityDiagnosis = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "本轮主练：思考力中的判断力")
        ).firstMatch
        XCTAssertTrue(abilityDiagnosis.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["材料分离训练"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["讲述训练"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["已说清"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["推进标准"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["我观察到"].exists)
        XCTAssertFalse(app.staticTexts["当前主要缺口"].exists)
        XCTAssertFalse(app.staticTexts["请你补充"].exists)
    }

    func testTodaySelectLensShowsObservationInventoryBeforeLensChoice() throws {
        let app = seededTodayApp(stage: "select_lens")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.select_lens"].waitForExistence(timeout: 8))
        let coachObservationTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "coach observation")
        ).firstMatch
        XCTAssertTrue(coachObservationTitle.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["能力训练诊断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["已说清"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先补"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["我观察到"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["当前主要缺口"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["本轮训练"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["请你补充"].waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsShowsCoachGapPreviewAfterTyping() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        typeFirstQuestionAnswer("先让 Alex 写清验收标准。", in: app)

        XCTAssertTrue(app.staticTexts["教练批改"].waitForExistence(timeout: 4))
        let coachCritique = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "这不是合格复盘")
        ).firstMatch
        XCTAssertTrue(coachCritique.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "我听到的是行动安排")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还缺：服务对象、成功标准和可观察信号")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "听众回放")
        ).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "我没听懂的是")
        ).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还要训练")
        ).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["本句观察"].exists)
        XCTAssertFalse(app.staticTexts["你刚补上"].exists)
        XCTAssertFalse(app.staticTexts["能否进入明日验证"].exists)
        let optionalCoachSuggestion = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "也可以带着没讲清的地方继续")
        ).firstMatch
        XCTAssertTrue(optionalCoachSuggestion.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["建议补充"].waitForExistence(timeout: 4))
        let nextRepairQuestion = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题会变少")
        ).firstMatch
        XCTAssertTrue(nextRepairQuestion.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["需要补充"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["下一句修补"].exists)
        XCTAssertFalse(app.staticTexts["我还没听懂"].exists)
        XCTAssertFalse(app.staticTexts["当前仍缺"].exists)
        XCTAssertTrue(app.buttons["带着缺口继续"].waitForExistence(timeout: 4))
        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 4))
        XCTAssertTrue(primaryAction.label.contains("先修补追问"))
        XCTAssertFalse(primaryAction.label.contains("设计明日验证"))
        XCTAssertFalse(primaryAction.isEnabled)
        XCTAssertFalse(app.staticTexts["能力缺口"].exists)
        XCTAssertFalse(app.staticTexts["听众卡点"].exists)
        XCTAssertFalse(app.staticTexts["训练产物"].exists)
        XCTAssertFalse(app.staticTexts["可复述材料"].exists)
        XCTAssertFalse(app.staticTexts["自检标准"].exists)
        XCTAssertFalse(app.staticTexts["能力修补"].exists)
        XCTAssertFalse(app.staticTexts["复盘训练契约"].exists)
        let gapPreview = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "观察事实")
        ).firstMatch
        XCTAssertTrue(gapPreview.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["过往经验复现"].waitForExistence(timeout: 4))
        let replayDecision = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "复现：条件相同")
        ).firstMatch
        XCTAssertTrue(replayDecision.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "调整：条件不同")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "否定：这条经验为什么不适用")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "先判断：复现、调整，还是否定")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "再写一句条件差异")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["判断句训练"].exists)

        dismissKeyboardIfPresent(in: app)
        let trainingToolsToggle = app.buttons["today.answer.training-tools-toggle"].firstMatch
        scrollToElement(trainingToolsToggle, in: app)
        XCTAssertTrue(trainingToolsToggle.waitForExistence(timeout: 4))
        trainingToolsToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "收起训练标准")).firstMatch.waitForExistence(timeout: 4))

        XCTAssertTrue(app.staticTexts["本句观察"].waitForExistence(timeout: 4))
        let answerMaterialObservation = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "行动不能先替代目标")
        ).firstMatch
        XCTAssertTrue(answerMaterialObservation.waitForExistence(timeout: 4))
        let answerMaterialGap = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题会变少")
        ).firstMatch
        XCTAssertTrue(answerMaterialGap.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["具体还缺"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["哪里没听懂"].exists)
        XCTAssertFalse(app.staticTexts["能力缺口"].exists)
        let abilityGap = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "你想行动")
        ).firstMatch
        XCTAssertTrue(abilityGap.waitForExistence(timeout: 4))
        let listenerGap = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "还不清楚")
        ).firstMatch
        XCTAssertTrue(listenerGap.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["可复述材料"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["训练产物"].exists)
        let trainingOutput = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "别人能复述")
        ).firstMatch
        XCTAssertTrue(trainingOutput.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["自检标准"].waitForExistence(timeout: 4))
        let selfCheck = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题会变少")
        ).firstMatch
        XCTAssertTrue(selfCheck.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["能力修补"].exists)
        XCTAssertTrue(app.staticTexts["本次练什么"].waitForExistence(timeout: 4))
        let trainingRepair = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "不是让 AI 替你给答案")
        ).firstMatch
        XCTAssertTrue(trainingRepair.waitForExistence(timeout: 4))
        let replayContract = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "先补到别人能复述")
        ).firstMatch
        XCTAssertTrue(replayContract.waitForExistence(timeout: 4))
        let foundationalAbility = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "思考力")
        ).firstMatch
        XCTAssertTrue(foundationalAbility.waitForExistence(timeout: 4))

        let judgmentTitle = app.staticTexts["判断句训练"].firstMatch
        scrollDownUntilElementExists(judgmentTitle, in: app)
        let judgmentTemplate = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "我现在相信 X")
        ).firstMatch
        scrollDownUntilElementExists(judgmentTemplate, in: app)
        let calibrationTemplate = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "明天用 Y")
        ).firstMatch
        scrollDownUntilElementExists(calibrationTemplate, in: app)
    }

    func testTodayAnswerQuestionsCanNavigateBackToThinkingCardsWhileAnswerFieldIsActive() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        typeFirstQuestionAnswer("先验证最小行动", in: app)

        let reviewCardsProgress = app.buttons["回到思考卡片"]
        XCTAssertTrue(reviewCardsProgress.waitForExistence(timeout: 8))
        reviewCardsProgress.tap()

        XCTAssertTrue(app.staticTexts["today.state.review_cards"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.card.confirm-action"].waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsSeedCanRejectReferencedPrinciple() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        let noteField = app.textFields["today.principle.feedback.note-field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 8))
        noteField.tap()
        noteField.typeText("这个场景不是会议")
        noteField.typeText("\n")

        let notApplicableButton = app.buttons["today.principle.feedback.not-applicable-action"]
        XCTAssertTrue(notApplicableButton.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.principle.feedback.helpful-action"].exists)
        XCTAssertTrue(app.buttons["today.principle.feedback.misrecalled-action"].exists)

        notApplicableButton.tap()

        let removed = NSPredicate(format: "exists == false")
        expectation(for: removed, evaluatedWith: notApplicableButton)
        waitForExpectations(timeout: 4)
    }

    func testTodayAnswerQuestionsSeedShowsReferencedPrincipleRetrievalReason() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["召回依据"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["命中信号：命中会议负责人"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Visual QA seed matched meeting ownership with 会前确认负责人 using local keyword policy; score=4."].waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["过往经验复现"].waitForExistence(timeout: 4))
        let replayPrompt = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "这次先判断")
        ).firstMatch
        XCTAssertTrue(replayPrompt.waitForExistence(timeout: 4))
        XCTAssertTrue(replayPrompt.label.contains("复现、调整"))
        let helpfulAction = app.buttons["today.principle.feedback.helpful-action"].firstMatch
        scrollToElement(helpfulAction, in: app)
        XCTAssertTrue(helpfulAction.label.contains("适用"))
        let adaptedAction = app.buttons["today.principle.feedback.adapted-action"].firstMatch
        XCTAssertTrue(adaptedAction.waitForExistence(timeout: 4))
        XCTAssertTrue(adaptedAction.label.contains("调整"))
        XCTAssertTrue(app.buttons["today.principle.feedback.not-applicable-action"].firstMatch.label.contains("不复现"))
        XCTAssertTrue(app.buttons["today.principle.feedback.misrecalled-action"].firstMatch.label.contains("召回错了"))
    }

    func testTodayReviewQuestsSeedShowsQuestCalibrationTarget() throws {
        let app = seededTodayApp(stage: "review_quests")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["闭环二：明日验证与结果校准"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["把今日复盘后的一个判断变成明天的验证行动；明天回来只校准结果，不继续写今天复盘。"].exists)
        XCTAssertTrue(app.staticTexts["明日验证"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["本页只设计明天的验证行动"].exists)
        XCTAssertFalse(app.staticTexts["今日复盘交接点"].exists)
        XCTAssertTrue(app.buttons["today.review-quests.guidance-toggle"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["今天待验证判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["下面的验证行动只验证这个判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["校准目标"].waitForExistence(timeout: 4))
    }

    func testTodayReviewQuestsMissingCalibrationTargetCanReturnToReview() throws {
        let app = seededTodayApp(stage: "review_quests", missingCalibrationTarget: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["今天待验证判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["还没有明确的待验证判断。请回到今日复盘，把一个判断写成明天能观察的信号。"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["进入条件：先补上今天待验证判断，再保存明日验证。 训练理由：验证行动要验证今天的判断，不是普通待办。"].waitForExistence(timeout: 4))

        let repairAction = app.buttons["today.return-to-review-for-judgment-action"]
        scrollToElement(repairAction, in: app)
        repairAction.tap()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["本页只复盘今天"].waitForExistence(timeout: 4))
    }

    func testTodayVerifyYesterdayFramesResultCalibration() throws {
        let app = seededTodayApp(stage: "verify_yesterday")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.verify_yesterday"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["闭环二：结果校准"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["只回看昨天设计的验证行动：做没做、有没有价值、判断如何更新；完成后才进入今天内容。"].exists)
        XCTAssertTrue(app.staticTexts["结果校准"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["先校准昨天的明日验证，再开始收集今天的新材料。"].exists)
        XCTAssertFalse(app.staticTexts["本页只校准昨天结果"].exists)
        XCTAssertFalse(app.staticTexts["只检查做没做、有没有实际价值、昨天判断要不要更新；新的今日内容在下一段填写。"].exists)
        XCTAssertTrue(app.staticTexts["昨天判断怎么更新？"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["确认判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["调整判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["推翻判断"].waitForExistence(timeout: 4))
    }

    func testTodayReviewQuestsSeedShowsQuestTrainingTarget() throws {
        let app = seededTodayApp(stage: "review_quests")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["为什么不是普通待办"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "不是普通待办")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["验证判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["完成证据"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["阻力预案"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["结果校准信号"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["本轮练什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["复现哪条原则"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["执行训练契约"].exists)
        XCTAssertFalse(app.staticTexts["执行力训练"].exists)
        XCTAssertFalse(app.staticTexts["训练原则"].exists)
        XCTAssertTrue(app.staticTexts["Visual QA - 会前确认负责人"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["命中信号：写出负责人"].waitForExistence(timeout: 4))
    }

    func testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier() throws {
        let app = settingsApp()
        app.launch()

        let installAction = app.descendants(matching: .any)["settings.asset-pack-manifest.install-action"]
        XCTAssertTrue(installAction.waitForExistence(timeout: 8))
        XCTAssertTrue(installAction.isEnabled)
        installAction.tap()

        let message = app.staticTexts["settings.asset-pack-manifest.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        XCTAssertTrue(message.label.contains("安装资产包清单失败"))
    }

    func testSettingsAssetPackManifestRemoteURLInstallReportsFetchFailureThroughIdentifier() throws {
        let app = settingsApp()
        app.launch()

        let urlField = app.textFields["settings.asset-pack-manifest.remote-url-field"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 8))
        XCTAssertEqual(urlField.value as? String, "http://127.0.0.1:1/mingsi-asset-pack-manifest.json")

        let remoteInstallAction = app.descendants(matching: .any)["settings.asset-pack-manifest.remote-install-action"]
        XCTAssertTrue(remoteInstallAction.waitForExistence(timeout: 8))
        XCTAssertTrue(remoteInstallAction.isEnabled)
        remoteInstallAction.tap()

        let message = app.staticTexts["settings.asset-pack-manifest.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        XCTAssertTrue(message.label.contains("获取远程资产包清单失败"))
    }

    func testSettingsAssetPackRegistryCatalogFetchReportsFailureThroughIdentifier() throws {
        let app = settingsApp()
        app.launch()

        let catalogURLField = app.textFields["settings.asset-pack-registry.catalog-url-field"]
        XCTAssertTrue(catalogURLField.waitForExistence(timeout: 8))
        XCTAssertEqual(catalogURLField.value as? String, "http://127.0.0.1:1/mingsi-asset-pack-catalog.json")

        let fetchAction = app.descendants(matching: .any)["settings.asset-pack-registry.catalog-fetch-action"]
        XCTAssertTrue(fetchAction.waitForExistence(timeout: 8))
        XCTAssertTrue(fetchAction.isEnabled)
        fetchAction.tap()

        let message = app.staticTexts["settings.asset-pack-manifest.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        XCTAssertTrue(message.label.contains("获取远程资产包目录失败"))
    }

    func testSettingsAssetPackRegistrySubscriptionControlsRenderThroughIdentifiers() throws {
        let app = settingsApp()
        app.launch()

        let nameField = app.textFields["settings.asset-pack-registry.subscription-name-field"]
        scrollToElement(nameField, in: app)
        XCTAssertTrue(nameField.exists)

        let urlField = app.textFields["settings.asset-pack-registry.subscription-url-field"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["settings.asset-pack-registry.subscription-save-action"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.asset-pack-registry.subscription-sync-action"].exists)
    }

    func testSettingsPromptAssetQualitySummaryRendersThroughIdentifier() throws {
        let app = settingsApp()
        app.launch()

        let section = app.staticTexts["settings.prompt-asset-quality.section"]
        scrollToElement(section, in: app)
        XCTAssertTrue(section.exists)

        let row = app.staticTexts["settings.prompt-asset-quality.mingsi_builtin_prompts.organizeCards.connection-test"]
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        XCTAssertTrue(row.label.contains("失败率 100%"))
    }

    func testGrowthPrinciplePracticeCorrectionActionRendersThroughIdentifier() throws {
        let app = seededGrowthApp()
        app.launch()

        let disputeAction = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", ".dispute-action")).firstMatch
        scrollToElement(disputeAction, in: app)
        XCTAssertTrue(disputeAction.exists)
    }

    func testGrowthPrinciplePracticeCorrectionActionRemovesLatestEvidence() throws {
        let app = seededGrowthApp()
        app.launch()

        let latestEvidence = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "最近证据：")).firstMatch
        scrollToElement(latestEvidence, in: app)
        XCTAssertTrue(latestEvidence.exists)

        let disputeAction = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", ".dispute-action")).firstMatch
        XCTAssertTrue(disputeAction.exists)
        disputeAction.tap()

        let removed = NSPredicate(format: "exists == false")
        expectation(for: removed, evaluatedWith: latestEvidence)
        waitForExpectations(timeout: 4)
        XCTAssertTrue(app.staticTexts["已标记这条原则练习归因不准确。"].waitForExistence(timeout: 4))

        let disputedAudit = app.staticTexts.matching(NSPredicate(format: "identifier ENDSWITH %@", ".disputed-audit")).firstMatch
        scrollToElement(disputedAudit, in: app)
        XCTAssertTrue(disputedAudit.label.contains("已否认归因："))
        XCTAssertTrue(disputedAudit.label.contains("验证中实践了验收标准"))
    }

    func testGrowthNeedsReviewRecallAuditRendersThroughIdentifier() throws {
        let app = seededGrowthApp()
        app.launch()

        let recallAudit = app.staticTexts.matching(NSPredicate(format: "identifier ENDSWITH %@", ".negative-audit")).firstMatch
        scrollToElement(recallAudit, in: app)
        XCTAssertTrue(recallAudit.exists)
        XCTAssertTrue(recallAudit.label.contains("复审依据："))
        XCTAssertTrue(recallAudit.label.contains("命中信号：命中会议负责人"))
        XCTAssertTrue(recallAudit.label.contains("Owner keyword was a false positive."))
    }

    private func seededTodayApp(
        stage: String,
        input: String = """
        事实：会议结束后没有明确负责人。
        风险：验收标准缺失会导致明天返工。
        """,
        missingCalibrationTarget: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_INPUT"] = input
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MODE"] = "standard"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_STAGE"] = stage
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        if missingCalibrationTarget {
            app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MISSING_CALIBRATION_TARGET"] = "1"
        }
        return app
    }

    private func settingsApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "settings"
        app.launchEnvironment["MINGSI_VISUAL_QA_SETTINGS_AUDIT_PROOF"] = "1"
        app.launchEnvironment["MINGSI_VISUAL_QA_SETTINGS_ASSET_PACK_MANIFEST"] = "1"
        return app
    }

    private func seededGrowthApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "growth"
        return app
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = primaryScrollView(in: app)

        var remainingScrolls = 12
        while (!element.exists || !isElementInTappableScrollArea(element, app: app)) && remainingScrolls > 0 {
            let beforeMidY = element.exists ? element.frame.midY : nil
            if element.exists, element.frame.midY < app.frame.height * 0.24 {
                drag(scrollView, fromY: 0.35, toY: 0.62)
            } else {
                drag(scrollView, fromY: 0.72, toY: 0.45)
            }
            if let beforeMidY, element.exists, abs(element.frame.midY - beforeMidY) < 1 {
                if element.frame.midY < app.frame.height * 0.24 {
                    scrollView.swipeDown()
                } else {
                    scrollView.swipeUp()
                }
            }
            remainingScrolls -= 1
        }

        XCTAssertTrue(element.waitForExistence(timeout: 4))
        XCTAssertTrue(
            isElementInTappableScrollArea(element, app: app),
            "Element frame \(element.frame) is outside tappable area for app frame \(app.frame)."
        )
    }

    private func isElementInTappableScrollArea(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        let bottomOverlayTop = app.buttons["today.primary-action"].firstMatch.exists
            ? app.buttons["today.primary-action"].firstMatch.frame.minY
            : app.frame.height * 0.46
        let keyboardTop = app.keyboards.firstMatch.exists
            ? app.keyboards.firstMatch.frame.minY
            : app.frame.height
        let tappableBottom = min(bottomOverlayTop, keyboardTop) - 12
        return element.frame.minY >= app.frame.minY + 44 &&
            element.frame.maxY <= tappableBottom
    }

    private func primaryScrollView(in app: XCUIApplication) -> XCUIElement {
        let scrollViews = app.scrollViews
        let first = scrollViews.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 8))

        for index in 0..<scrollViews.count {
            let candidate = scrollViews.element(boundBy: index)
            guard candidate.exists else { continue }
            if candidate.frame.height >= app.frame.height * 0.5 {
                return candidate
            }
        }

        return first
    }

    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
    }

    private func scrollDownUntilElementExists(_ element: XCUIElement, in app: XCUIApplication) {
        if element.waitForExistence(timeout: 2) { return }

        let scrollView = primaryScrollView(in: app)
        var remainingScrolls = 6
        while !element.exists && remainingScrolls > 0 {
            scrollView.swipeUp()
            if element.waitForExistence(timeout: 1) { return }
            remainingScrolls -= 1
        }

        XCTAssertTrue(element.waitForExistence(timeout: 4))
    }

    private func typeFirstQuestionAnswer(_ text: String, in app: XCUIApplication) {
        let answerFields = app.textFields.matching(identifier: "today.question.answer-field")
        let answerField = answerFields.element(boundBy: 0)
        XCTAssertTrue(answerField.waitForExistence(timeout: 8))
        if !answerField.isHittable {
            scrollToElement(answerField, in: app)
            positionQuestionAnswerFieldForTyping(answerField, in: app)
        }

        answerField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        app.typeText(text)
    }

    private func positionQuestionAnswerFieldForTyping(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = primaryScrollView(in: app)

        var remainingAdjustments = 4
        while element.exists, element.frame.minY < app.frame.minY + 96, remainingAdjustments > 0 {
            drag(scrollView, fromY: 0.35, toY: 0.62)
            remainingAdjustments -= 1
        }

        while element.exists, element.frame.maxY > app.frame.height * 0.74, remainingAdjustments > 0 {
            drag(scrollView, fromY: 0.72, toY: 0.45)
            remainingAdjustments -= 1
        }

        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.frame.minY >= app.frame.minY + 96)
        XCTAssertTrue(element.frame.maxY <= app.frame.height * 0.74)
    }

    private func drag(_ scrollView: XCUIElement, fromY: CGFloat, toY: CGFloat) {
        scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
            .press(forDuration: 0.01, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY)))
    }

    private func tapPrimaryAction(in app: XCUIApplication, expectingState state: String) {
        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 8))
        XCTAssertTrue(primaryAction.isEnabled)
        primaryAction.tap()

        let stateMarker = app.descendants(matching: .any)["today.state.\(state)"]
        XCTAssertTrue(stateMarker.waitForExistence(timeout: 8))
    }
}
