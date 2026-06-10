import XCTest

final class MingSiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        let firstPrinciplesLens = app.buttons["today.lens.firstPrinciples-action"]
        XCTAssertTrue(firstPrinciplesLens.waitForExistence(timeout: 8))
        firstPrinciplesLens.tap()
        tapPrimaryAction(in: app, expectingState: "answer_questions")

        let answerFields = app.textFields.matching(identifier: "today.question.answer-field")
        let answerField = answerFields.element(boundBy: 0)
        XCTAssertTrue(answerField.waitForExistence(timeout: 8))
        answerField.tap()
        answerField.typeText("先验证最小行动是否真的降低返工。")
        tapPrimaryAction(in: app, expectingState: "review_quests")

        tapPrimaryAction(in: app, expectingState: "extract_principle")
        tapPrimaryAction(in: app, expectingState: "session_complete")

        XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
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

    func testTodayAnswerQuestionsSeedCanTypeThroughAccessibilityIdentifier() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        let answerFields = app.textFields.matching(identifier: "today.question.answer-field")
        let answerField = answerFields.element(boundBy: 0)
        XCTAssertTrue(answerField.waitForExistence(timeout: 8))
        answerField.tap()
        answerField.typeText("先验证最小行动是否真的降低返工。")

        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(primaryAction.isEnabled)
    }

    func testTodayAnswerQuestionsCanNavigateBackToThinkingCardsWhileAnswerFieldIsActive() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        let answerFields = app.textFields.matching(identifier: "today.question.answer-field")
        let answerField = answerFields.element(boundBy: 0)
        XCTAssertTrue(answerField.waitForExistence(timeout: 8))
        answerField.tap()
        answerField.typeText("先验证最小行动")

        let reviewCardsProgress = app.buttons["回到思考卡片"]
        XCTAssertTrue(reviewCardsProgress.waitForExistence(timeout: 8))
        reviewCardsProgress.tap()

        XCTAssertTrue(app.staticTexts["today.state.review_cards"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.card.confirm-action"].waitForExistence(timeout: 4))
    }

    func testTodayAnswerQuestionsSeedCanRejectReferencedPrinciple() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        let notApplicableButton = app.buttons["today.principle.feedback.not-applicable-action"]
        XCTAssertTrue(notApplicableButton.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.principle.feedback.helpful-action"].exists)
        XCTAssertTrue(app.buttons["today.principle.feedback.misrecalled-action"].exists)

        notApplicableButton.tap()

        let removed = NSPredicate(format: "exists == false")
        expectation(for: removed, evaluatedWith: notApplicableButton)
        waitForExpectations(timeout: 4)
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

    private func seededTodayApp(stage: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_INPUT"] = "今天用 UI Test 验证 Today 自动化入口。"
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

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollViews = app.scrollViews
        let scrollView = scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))

        var remainingScrolls = 8
        while !element.exists && remainingScrolls > 0 {
            scrollView.swipeUp()
            remainingScrolls -= 1
        }

        XCTAssertTrue(element.waitForExistence(timeout: 4))
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
