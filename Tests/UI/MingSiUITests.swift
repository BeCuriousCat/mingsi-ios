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

        typeFirstQuestionAnswer("先验证最小行动是否真的降低返工。", in: app)
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

        XCTAssertTrue(app.staticTexts["本轮漏想点"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["训练路线"].waitForExistence(timeout: 4))
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

    func testTodayCaptureShowsReviewScaffold() throws {
        let app = seededTodayApp(stage: "capture")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["基础能力训练"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["讲清楚一件事"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["沟通力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["思考力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["执行力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["发生了什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["我怎么做"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["我怎么想"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["问题类型"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["复盘问题"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["描述力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["观察力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["分析力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["判断力"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["校准力"].waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsSeedCanTypeThroughAccessibilityIdentifier() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        typeFirstQuestionAnswer("先验证最小行动是否真的降低返工。", in: app)

        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(primaryAction.isEnabled)
    }

    func testTodayAnswerQuestionsShowsQuestionTeachingCue() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["教练追问"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["过往经验复现"].waitForExistence(timeout: 4))
        let repairPrompt = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "刚才的回答")
        ).firstMatch
        XCTAssertTrue(repairPrompt.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["训练动作"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["为什么现在问"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["答案会改变"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["推进标准"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["经验判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["复现：照用哪条做法？"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["调整：哪些条件不同？"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["否定：这条经验为什么不适用？"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["作答训练"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["不是 AI 答案"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["补盲区"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["复现经验"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["安排执行"].waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsShowsCoachGapPreviewAfterTyping() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        typeFirstQuestionAnswer("先让 Alex 写清验收标准。", in: app)

        XCTAssertTrue(app.staticTexts["当前仍缺"].waitForExistence(timeout: 4))
        let gapPreview = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "观察事实")
        ).firstMatch
        XCTAssertTrue(gapPreview.waitForExistence(timeout: 4))
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
        XCTAssertTrue(app.buttons["today.principle.feedback.helpful-action"].label.contains("适用"))
        XCTAssertTrue(app.buttons["today.principle.feedback.not-applicable-action"].label.contains("不复现"))
        XCTAssertTrue(app.buttons["today.principle.feedback.misrecalled-action"].label.contains("召回错了"))
    }

    func testTodayReviewQuestsSeedShowsQuestCalibrationTarget() throws {
        let app = seededTodayApp(stage: "review_quests")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["校准目标"].waitForExistence(timeout: 4))
        let calibrationTarget = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "明天最值得验证的关键判断")
        ).firstMatch
        XCTAssertTrue(calibrationTarget.waitForExistence(timeout: 4))
    }

    func testTodayReviewQuestsSeedShowsQuestTrainingTarget() throws {
        let app = seededTodayApp(stage: "review_quests")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["训练原则"].waitForExistence(timeout: 4))
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

    private func seededTodayApp(stage: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_INPUT"] = """
        事实：会议结束后没有明确负责人。
        风险：验收标准缺失会导致明天返工。
        """
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MODE"] = "standard"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_STAGE"] = stage
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
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
        let scrollViews = app.scrollViews
        let scrollView = scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))

        var remainingScrolls = 10
        while (!element.exists || !isElementInTappableScrollArea(element, app: app)) && remainingScrolls > 0 {
            if element.exists, element.frame.midY < app.frame.height * 0.24 {
                scrollView.swipeDown()
            } else {
                scrollView.swipeUp()
            }
            remainingScrolls -= 1
        }

        XCTAssertTrue(element.waitForExistence(timeout: 4))
        XCTAssertTrue(isElementInTappableScrollArea(element, app: app))
    }

    private func isElementInTappableScrollArea(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        return element.frame.minY >= app.frame.minY + 44 &&
            element.frame.midY <= app.frame.height * 0.68
    }

    private func typeFirstQuestionAnswer(_ text: String, in app: XCUIApplication) {
        let answerFields = app.textFields.matching(identifier: "today.question.answer-field")
        var answerField = answerFields.element(boundBy: 0)
        XCTAssertTrue(answerField.waitForExistence(timeout: 8))

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists, answerField.frame.midY > app.frame.height * 0.58 {
            scrollView.swipeUp()
            answerField = answerFields.element(boundBy: 0)
            XCTAssertTrue(answerField.waitForExistence(timeout: 4))
        }

        answerField.tap()
        answerField.typeText(text)
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
