import XCTest

final class MentorNavigationUITests: XCTestCase {
    @MainActor
    func testCaptureDraftRestoresBodyAndUnacceptedSpeechAfterProcessRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture", "--capture-draft-relaunch-fixture",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-AppleInterfaceStyle", "Dark",
            "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchEnvironment["MINGSI_CAPTURE_DRAFT_TEST_ID"] = UUID().uuidString
        let open = app.buttons["mentor.quick-capture.open-action"]
        let input = app.textViews["today.captures.input"]
        func reopen() {
            XCTAssertTrue(open.waitForExistence(timeout: 15))
            scrollTo(open, in: app)
            open.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
        }
        app.launch()
        reopen()
        input.tap()
        input.typeText("Keep this thought after restart.")
        let original = try XCTUnwrap(input.value as? String)
        app.buttons["today.captures.input.keyboard-dismiss"].tap()
        XCTAssertTrue(app.staticTexts["草稿已保留在本机，重新打开可继续。"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        reopen()
        XCTAssertEqual(input.value as? String, original)
        let voice = app.buttons["today.captures.input.voice-toggle"]
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        // The first fixture recording intentionally never emits a final result.
        // Going home exercises preservation of partial recognition on background.
        XCUIDevice.shared.press(.home)
        app.activate()
        let review = app.textFields["today.captures.input.voice-review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        let recognized = try XCTUnwrap(review.value as? String)
        XCTAssertFalse(recognized.isEmpty)
        attachVoiceScreenshot(app, name: "draft-before-relaunch-unaccepted-speech")
        app.terminate()
        app.launch()
        reopen()
        XCTAssertEqual(input.value as? String, original)
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.value as? String, recognized)
        attachVoiceScreenshot(app, name: "draft-restored-unaccepted-speech-dark-largest")
        let accept = app.buttons["today.captures.input.voice-accept"]
        scrollTo(accept, in: app)
        accept.tap()
        let combined = original + "\n" + recognized
        XCTAssertEqual(input.value as? String, combined)
        XCTAssertTrue(review.waitForNonExistence(timeout: 5))
        app.buttons["today.captures.input.keyboard-dismiss"].tap()
        app.buttons["today.captures.close-action"].tap()
        XCTAssertTrue(app.buttons["保留草稿并关闭"].waitForExistence(timeout: 5))
        app.buttons["保留草稿并关闭"].tap()
        XCTAssertTrue(input.waitForNonExistence(timeout: 5))
        reopen()
        XCTAssertEqual(input.value as? String, combined)
        let save = app.buttons["today.captures.save-action"]
        scrollTo(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts[combined].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        reopen()
        XCTAssertNotEqual(input.value as? String, combined, "Saved body must not return as another unsaved draft")
        XCTAssertFalse(review.exists)
        input.tap()
        input.typeText("Discard this draft.")
        app.buttons["today.captures.input.keyboard-dismiss"].tap()
        app.buttons["today.captures.close-action"].tap()
        app.buttons["丢弃并关闭"].tap()
        XCTAssertTrue(input.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        reopen()
        XCTAssertFalse((input.value as? String)?.contains("Discard this draft.") == true)
        app.terminate()
    }

    @MainActor
    func testQuickCaptureProtectsUnsavedTextAndAllowsExplicitDiscardInNormalAndLargestText() throws {
        var normalDescriptionHeight: CGFloat = 0
        for largest in [false, true] {
            let app = XCUIApplication()
            app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-AppleInterfaceStyle", largest ? "Dark" : "Light", "-UIPreferredContentSizeCategory",
                largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            let open = app.buttons["mentor.quick-capture.open-action"]
            XCTAssertTrue(open.waitForExistence(timeout: 15))
            scrollTo(open, in: app)
            open.tap()
            let input = app.textViews["today.captures.input"]
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            input.tap()
            input.typeText("Unsaved thought: compare the alternatives.")
            let typed = try XCTUnwrap(input.value as? String)
            let description = app.staticTexts["先把想法留下，稍后再决定是否整理。"]
            if largest {
                XCTAssertGreaterThan(description.frame.height, normalDescriptionHeight, "Capture sheet must inherit the selected accessibility text size")
            } else { normalDescriptionHeight = description.frame.height }
            app.buttons["today.captures.input.keyboard-dismiss"].tap()
            attachVoiceScreenshot(app, name: "capture-unsaved-before-close-" + (largest ? "dark-largest" : "light"))
            let close = app.navigationBars["今日闪念"].buttons.matching(NSPredicate(format: "label IN %@", ["完成", "关闭"])).firstMatch
            close.tap()
            let keep = app.buttons["继续编辑"]
            guard keep.waitForExistence(timeout: 5) else {
                attachVoiceScreenshot(app, name: "capture-unsaved-close-lost-draft")
                XCTFail("Closing a typed capture must offer to keep editing before discarding it")
                app.terminate()
                return
            }
            XCTAssertTrue(app.buttons["丢弃并关闭"].exists)
            attachVoiceScreenshot(app, name: "capture-unsaved-confirmation-" + (largest ? "dark-largest" : "light"))
            keep.tap()
            XCTAssertEqual(input.value as? String, typed)
            close.tap()
            app.buttons["丢弃并关闭"].tap()
            XCTAssertTrue(input.waitForNonExistence(timeout: 5))
            scrollTo(open, in: app)
            open.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            XCTAssertNotEqual(input.value as? String, typed)
            app.buttons["today.captures.input.keyboard-dismiss"].tap()
            // An empty input closes immediately without a redundant dialog.
            close.tap()
            XCTAssertTrue(input.waitForNonExistence(timeout: 5))
            XCTAssertFalse(keep.exists)
            // Unaccepted speech is also unsaved input, even with an empty editor.
            scrollTo(open, in: app)
            open.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            let voice = app.buttons["today.captures.input.voice-toggle"]
            voice.tap()
            assertVoiceLabel("停止语音输入", voice)
            close.tap()
            XCTAssertTrue(keep.waitForExistence(timeout: 5))
            keep.tap()
            assertVoiceLabel("停止语音输入", voice)
            voice.tap()
            assertVoiceLabel("取消语音识别", voice)
            voice.tap()
            assertVoiceLabel("开始语音输入", voice)
            voice.tap()
            assertVoiceLabel("停止语音输入", voice)
            voice.tap()
            let review = app.textFields["today.captures.input.voice-review"]
            XCTAssertTrue(review.waitForExistence(timeout: 5))
            let transcript = try XCTUnwrap(review.value as? String)
            close.tap()
            XCTAssertTrue(keep.waitForExistence(timeout: 5))
            keep.tap()
            XCTAssertEqual(review.value as? String, transcript)
            app.buttons["today.captures.input.voice-accept"].tap()
            XCTAssertEqual(input.value as? String, transcript)
            let save = app.buttons["today.captures.save-action"]
            scrollTo(save, in: app)
            save.tap()
            XCTAssertTrue(app.staticTexts[transcript].waitForExistence(timeout: 5))
            close.tap()
            XCTAssertTrue(input.waitForNonExistence(timeout: 5))
            XCTAssertFalse(keep.exists, "A fully saved capture should close without a discard warning")
            app.terminate()
        }
    }

    @MainActor
    func testPerspectiveGuideShowsKnownPositionsInNormalAndLargestText() throws {
        for largest in [false, true] {
            let app = productionStartupApp(extra: ["--today-lens-library-ui-fixture"])
            app.launchArguments.insert(contentsOf: ["-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"], at: 0)
            app.launchEnvironment["OS_ACTIVITY_MODE"] = "disable"
            app.launch()
            let guide = app.buttons["today.lens.perspectiveTaking.guide"]
            XCTAssertTrue(guide.waitForExistence(timeout: 15))
            scrollTo(guide, in: app, attempts: 40)
            XCTAssertTrue(guide.isHittable)
            XCTAssertGreaterThanOrEqual(guide.frame.width, 44)
            guide.tap()
            let purpose = app.staticTexts["准确表述双方已知的诉求与限制，看见分歧可能来自不同侧重点，理解不等于认同。"]
            XCTAssertTrue(purpose.waitForExistence(timeout: 5))
            XCTAssertTrue(purpose.isHittable)
            XCTAssertGreaterThanOrEqual(purpose.frame.minX, app.frame.minX + 18)
            XCTAssertLessThanOrEqual(purpose.frame.maxX, app.frame.maxX - 18)
            XCTAssertGreaterThanOrEqual(purpose.frame.minY, app.frame.minY + 90)
            XCTAssertLessThanOrEqual(purpose.frame.maxY, app.frame.maxY - 80)
            attachVoiceScreenshot(app, name: "perspective-purpose-" + (largest ? "dark-largest" : "light"))
            let example = app.staticTexts["只按已知的表达，对方的请求主要在回应什么处境？"]
            scrollTo(example, in: app, attempts: 25)
            XCTAssertTrue(example.isHittable)
            attachVoiceScreenshot(app, name: "perspective-example-" + (largest ? "dark-largest" : "light"))
            let select = app.buttons["today.lens.guide.select"]
            scrollTo(select, in: app, attempts: 25)
            XCTAssertTrue(select.isHittable)
            XCTAssertGreaterThanOrEqual(select.frame.height, 44)
            select.tap()
            let option = app.buttons["today.lens.perspectiveTaking-action"]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            XCTAssertTrue((option.value as? String)?.contains("已选择") == true)
            app.terminate()
        }
    }

    @MainActor
    func testLensLibrarySelectionAndGuideInLightAndLargestDarkText() throws {
        var normalPurposeHeight: CGFloat = 0
        for largest in [false, true] {
            let app = productionStartupApp(extra: ["--today-lens-library-ui-fixture"])
            app.launchArguments.insert(contentsOf: ["-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"], at: 0)
            app.launch()
            let accept = app.buttons["today.training-prescription.accept-action"]
            scrollTo(accept, in: app, attempts: 30)
            XCTAssertTrue(accept.isHittable)
            XCTAssertGreaterThanOrEqual(accept.frame.height, 44)
            attachVoiceScreenshot(app, name: largest ? "lens-recommendation-dark-largest-actions" : "lens-recommendation-light-actions")
            let ids = largest ? ["controlBoundary"] : ["perspectiveTaking", "opportunityCost", "reversibleDecision", "controlBoundary"]
            for id in ids {
                let option = app.buttons["today.lens." + id + "-action"]
                scrollTo(option, in: app, attempts: 45)
                XCTAssertTrue(option.isHittable)
                XCTAssertGreaterThanOrEqual(option.frame.minX, app.frame.minX + 18)
                XCTAssertLessThanOrEqual(option.frame.maxX, app.frame.maxX - 18)
                XCTAssertGreaterThanOrEqual(option.frame.height, 44)
                option.tap()
                XCTAssertTrue((option.value as? String)?.contains("已选择") == true)
                let info = app.buttons["today.lens." + id + ".guide"]
                scrollTo(info, in: app, attempts: 15)
                XCTAssertTrue(info.isHittable)
                if !largest { attachVoiceScreenshot(app, name: "lens-library-light-" + id) }
            }
            if largest { attachVoiceScreenshot(app, name: "lens-library-dark-largest-selected") }
            let guide = app.buttons["today.lens.controlBoundary.guide"]
            XCTAssertTrue(guide.isHittable)
            XCTAssertGreaterThanOrEqual(guide.frame.width, 44)
            guide.tap()
            let purpose = app.staticTexts["辨认控制范围与责任边界，把精力用在自己能够选择的部分。"]
            XCTAssertTrue(purpose.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(purpose.frame.minX, app.frame.minX + 18)
            if largest { XCTAssertGreaterThan(purpose.frame.height, normalPurposeHeight * 1.3) }
            else { normalPurposeHeight = purpose.frame.height }
            attachVoiceScreenshot(app, name: largest ? "lens-guide-dark-largest-purpose" : "lens-guide-light-purpose")
            let select = app.buttons["today.lens.guide.select"]
            for _ in 0..<24 where !select.isHittable { app.swipeUp(velocity: .slow) }
            XCTAssertTrue(select.isHittable)
            attachVoiceScreenshot(app, name: largest ? "lens-guide-dark-largest-boundary" : "lens-guide-light-boundary")
            select.tap()
            XCTAssertTrue(app.buttons["today.lens.controlBoundary-action"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.otherElements["today.lens.guide.sheet"].exists)
            app.terminate()
        }
    }

    @MainActor
    func testModelQuestionExplainsActualMaterialWithoutInventingTrainingInNormalAndLargestText() throws {
        var normalReasonHeight: CGFloat = 0
        for largest in [false, true] {
            let app = productionStartupApp(extra: ["--today-question-explanation-ui-fixture",
                "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"])
            app.launch()
            let reason = app.staticTexts["today.question.reason"]
            XCTAssertTrue(reason.waitForExistence(timeout: 15))
            readQuestionExplanation(reason, in: app)
            XCTAssertEqual(reason.label, "你观察到了延期，但对方是否故意仍是推测。")
            if largest { XCTAssertGreaterThan(reason.frame.height, normalReasonHeight * 1.3) }
            else { normalReasonHeight = reason.frame.height }
            XCTAssertFalse(app.staticTexts["先补：缺因果链"].exists)
            XCTAssertFalse(app.buttons["today.answer.diagnosis-toggle"].exists)
            attachVoiceScreenshot(app, name: largest ? "question-purpose-dark-largest-reason" : "question-purpose-light-reason")
            let basis = app.buttons["today.question.coach-basis-toggle"].firstMatch
            scrollTo(basis, in: app)
            XCTAssertEqual(basis.label, "为什么问这个问题")
            basis.tap()
            let update = app.staticTexts["区分交付事实与对方意图，调整对故意不配合的确信。"]
            readQuestionExplanation(update, in: app)
            let sufficient = app.staticTexts["说清已知和推测即可；不知道原因也可以。"]
            readQuestionExplanation(sufficient, in: app)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "否则后面的回答容易变成泛泛判断")).firstMatch.exists)
            XCTAssertFalse(app.staticTexts["本题练法"].exists)
            XCTAssertFalse(app.staticTexts["先补一句"].exists)
            attachVoiceScreenshot(app, name: largest ? "question-purpose-dark-largest-unknown" : "question-purpose-light-unknown")
            let source = app.staticTexts["报告晚交两天"]
            readQuestionExplanation(source, in: app)
            XCTAssertTrue(app.textFields["today.question.answer-field"].exists || app.textViews["today.question.answer-field"].exists)
            app.terminate()
        }
    }

    @MainActor
    func testEmptyQuestionResultDoesNotClaimTheCauseIsEstablished() throws {
        let app = productionStartupApp(extra: ["--today-question-explanation-ui-fixture", "--question-explanation-empty"])
        app.launch()
        let explanation = app.staticTexts["today.answer.no-questions"]
        XCTAssertTrue(explanation.waitForExistence(timeout: 15))
        readQuestionExplanation(explanation, in: app)
        XCTAssertTrue(explanation.label.contains("没有追加问题不代表原因已经确定"))
        XCTAssertFalse(app.staticTexts["今日复盘已足够"].exists)
        XCTAssertFalse(app.buttons["today.answer.diagnosis-toggle"].exists)
        XCTAssertFalse(app.buttons["today.question.coach-basis-toggle"].exists)
        XCTAssertTrue(app.buttons["today.primary-action"].isEnabled)
        attachVoiceScreenshot(app, name: "question-purpose-empty-not-certain")
        app.terminate()
    }

    @MainActor
    func testDirectExplanationIsReadableAtNormalAndLargestText() {
        var normalHeight: CGFloat = 0
        for largest in [false, true] {
            let app = productionStartupApp(extra: ["--today-question-explanation-ui-fixture", "--direct-explanation",
                "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"])
            app.launch()
            let text = app.staticTexts["today.answer.explanation"]
            XCTAssertTrue(text.waitForExistence(timeout: 15))
            let primaryAction = app.buttons["today.primary-action"]
            let topTarget = app.frame.minY + 100
            // A long Dynamic Type paragraph is readable across scroll positions,
            // rather than requiring it to fit on a single screen.
            func dragContent(by distance: CGFloat) {
                let startY = (topTarget + primaryAction.frame.minY - 20) / 2
                let delta = max(-180, min(180, distance))
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.width / 2, dy: startY))
                let end = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.width / 2, dy: startY - delta))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            if largest {
                for _ in 0..<16 where abs(text.frame.minY - topTarget) > 16 {
                    dragContent(by: text.frame.minY - topTarget)
                }
                XCTAssertGreaterThanOrEqual(text.frame.minY, app.frame.minY + 40)
                XCTAssertLessThan(text.frame.minY, topTarget + 50)
                XCTAssertTrue(text.isHittable)
                attachVoiceScreenshot(app, name: "direct-explanation-dark-largest-start")
                for part in 0..<8 where text.frame.maxY > primaryAction.frame.minY - 8 {
                    dragContent(by: min(180, text.frame.maxY - primaryAction.frame.minY + 16))
                    attachVoiceScreenshot(app, name: "direct-explanation-dark-largest-part-\(part + 1)")
                }
                XCTAssertLessThanOrEqual(text.frame.maxY, primaryAction.frame.minY - 8)
                XCTAssertGreaterThan(text.frame.maxY, topTarget)
            } else {
                readQuestionExplanation(text, in: app)
            }
            XCTAssertEqual(text.label, "晚交两天是已知事实，故意不配合是对动机的推测。两者之间还缺少能说明原因的信息；目前可以保留不满，同时把原因保持为未知。")
            XCTAssertGreaterThanOrEqual(text.frame.minX, 32)
            XCTAssertLessThanOrEqual(text.frame.maxX, app.frame.width - 32)
            XCTAssertFalse(app.staticTexts["today.answer.no-questions"].exists)
            XCTAssertFalse(app.textViews["today.question.answer"].exists)
            if largest { XCTAssertGreaterThan(text.frame.height, normalHeight * 1.3) }
            else { normalHeight = text.frame.height }
            attachVoiceScreenshot(app, name: largest ? "direct-explanation-dark-largest" : "direct-explanation-light")
            let primary = app.buttons["today.primary-action"]
            XCTAssertTrue(primary.isEnabled)
            app.terminate()
        }
    }

    @MainActor
    private func readQuestionExplanation(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        scrollTo(element, in: app)
        let action = app.buttons["today.primary-action"]
        for _ in 0..<12 where element.frame.maxY > action.frame.minY - 8 {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertGreaterThanOrEqual(element.frame.minY, app.frame.minY + 40)
        XCTAssertLessThanOrEqual(element.frame.maxY, action.frame.minY - 8)
    }

    @MainActor
    func testStoppedTodayReviewDoesNotReopenTrainingInNormalAndLargestText() throws {
        var normalHeight: CGFloat = 0
        for largestText in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--mentor-startup-ui-test", "--today-review-stop-ui-fixture",
                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-AppleInterfaceStyle", largestText ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launchEnvironment["MINGSI_MENTOR_TEST_ID"] = UUID().uuidString
            app.launch()
            let critique = app.staticTexts["目前只有一次未完成，既不能认定设计失败，也不能确认断网就是原因。"]
            XCTAssertTrue(critique.waitForExistence(timeout: 15))
            scrollTo(critique, in: app)
            XCTAssertTrue(critique.isHittable)
            if largestText {
                XCTAssertGreaterThan(critique.frame.height, normalHeight * 1.3)
            } else { normalHeight = critique.frame.height }
            attachVoiceScreenshot(app, name: largestText ? "today-stop-dark-largest-feedback" : "today-stop-light-feedback")
            let closure = app.staticTexts["今天可以到此为止，不必继续回答，也不安排验证任务。"]
            scrollTo(closure, in: app)
            for _ in 0..<12 where closure.frame.maxY > app.buttons["today.primary-action"].frame.minY - 8 {
                app.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(closure.isHittable)
            XCTAssertLessThanOrEqual(closure.frame.maxY, app.buttons["today.primary-action"].frame.minY)
            XCTAssertFalse(app.buttons["today.answer.training-tools-toggle"].exists)
            XCTAssertFalse(app.buttons["today.answer.diagnosis-toggle"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["today.answer.coach-reference-suggestion"].exists)
            XCTAssertFalse(app.staticTexts["想想以前类似情况"].exists)
            XCTAssertFalse(app.staticTexts["需要补充"].exists)
            XCTAssertFalse(app.staticTexts["把判断说完整"].exists)
            attachVoiceScreenshot(app, name: largestText ? "today-stop-dark-largest-closure" : "today-stop-light-closure")
            let finish = app.buttons["today.primary-action"]
            XCTAssertTrue(finish.isEnabled)
            XCTAssertEqual(finish.label, "先到这里，返回今日")
            finish.tap()
            XCTAssertTrue(app.staticTexts["今日事项"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testUncertainReviewWithNoFollowupCanSaveAndReopenInNormalAndLargestText() throws {
        var normalHeight: CGFloat = 0
        for largestText in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--mentor-startup-ui-test", "--today-review-stop-ui-fixture", "--review-no-followup",
                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-AppleInterfaceStyle", largestText ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launchEnvironment["MINGSI_MENTOR_TEST_ID"] = UUID().uuidString
            app.launchEnvironment["OS_ACTIVITY_MODE"] = "disable"
            app.launch()
            let critique = app.staticTexts["目前只有一次未完成，既不能认定设计失败，也不能确认断网就是原因。"]
            XCTAssertTrue(critique.waitForExistence(timeout: 15))
            scrollTo(critique, in: app)
            XCTAssertTrue(critique.isHittable)
            if largestText { XCTAssertGreaterThan(critique.frame.height, normalHeight * 1.3) }
            else { normalHeight = critique.frame.height }
            attachVoiceScreenshot(app, name: largestText ? "answer-choice-dark-largest-feedback" : "answer-choice-light-feedback")
            let choice = app.staticTexts["可以保存这次区分，原因先保持未知。"]
            scrollTo(choice, in: app)
            let finish = app.buttons["today.primary-action"]
            for _ in 0..<12 where choice.frame.maxY > finish.frame.minY - 8 { app.swipeUp(velocity: .slow) }
            XCTAssertTrue(choice.isHittable)
            XCTAssertLessThanOrEqual(choice.frame.maxY, finish.frame.minY)
            XCTAssertFalse(app.buttons["today.answer.training-tools-toggle"].exists)
            XCTAssertFalse(app.buttons["today.answer.override-gap-action"].exists)
            XCTAssertTrue(finish.isEnabled)
            XCTAssertEqual(finish.label, "先保存，返回今日")
            attachVoiceScreenshot(app, name: largestText ? "answer-choice-dark-largest-save" : "answer-choice-light-save")
            finish.tap()
            XCTAssertTrue(app.staticTexts["今日事项"].waitForExistence(timeout: 5))
            attachVoiceScreenshot(app, name: largestText ? "answer-choice-dark-largest-overview" : "answer-choice-light-overview")
            let resume = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.overview.case.")).firstMatch
            scrollTo(resume, in: app)
            resume.tap()
            XCTAssertTrue(critique.waitForExistence(timeout: 5))
            scrollTo(choice, in: app)
            XCTAssertTrue(choice.isHittable)
            XCTAssertEqual(app.buttons["today.primary-action"].label, "先保存，返回今日")
            app.terminate()
        }
    }

    @MainActor
    func testUnansweredFollowupHasWorkingSaveExitInNormalAndLargestText() throws {
        for largestText in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--mentor-startup-ui-test", "--today-review-stop-ui-fixture", "--review-no-followup", "--review-useful-followup",
                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-AppleInterfaceStyle", largestText ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launchEnvironment["MINGSI_MENTOR_TEST_ID"] = UUID().uuidString
            app.launch()
            let save = app.buttons["today.answer.save-return"]
            XCTAssertTrue(save.waitForExistence(timeout: 15))
            XCTAssertTrue(save.isHittable)
            XCTAssertTrue(save.isEnabled)
            XCTAssertGreaterThanOrEqual(save.frame.height, 44)
            XCTAssertEqual(app.buttons["today.primary-action"].label, "回答这条追问")
            attachVoiceScreenshot(app, name: largestText ? "answer-choice-dark-largest-followup-exit" : "answer-choice-light-followup-exit")
            save.tap()
            XCTAssertTrue(app.staticTexts["今日事项"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testAnswerReviewCancellationAndFailureHaveReachableRetryAndKeepDraftInNormalAndLargestText() throws {
        for largest in [false, true] {
            for failsFirst in [false, true] {
                let app = XCUIApplication()
                app.launchArguments = ["--mentor-startup-ui-test", "--today-review-stop-ui-fixture", "--review-no-followup",
                    "--answer-review-retry-ui-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                    "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                    "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
                if failsFirst { app.launchArguments.append("--answer-review-fail-first") }
                app.launchEnvironment["MINGSI_MENTOR_TEST_ID"] = UUID().uuidString
                app.launchEnvironment["OS_ACTIVITY_MODE"] = "disable"
                app.launch()
                let primary = app.buttons["today.primary-action"]
                XCTAssertTrue(primary.waitForExistence(timeout: 15))
                scrollTo(primary, in: app, attempts: 35)
                XCTAssertTrue(primary.isEnabled)
                primary.tap()
                let suffix = (largest ? "dark-largest" : "light") + (failsFirst ? "-failure" : "-cancel")
                if !failsFirst {
                    let cancel = app.buttons["today.cancel-current-ai-action"]
                    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
                    scrollTo(cancel, in: app, attempts: 35)
                    XCTAssertEqual(cancel.label, "取消本次复盘")
                    XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
                    XCTAssertFalse(primary.isEnabled)
                    attachVoiceScreenshot(app, name: "answer-review-waiting-" + suffix)
                    cancel.tap()
                }
                let retry = app.buttons["today.retry-message-action"]
                XCTAssertTrue(retry.waitForExistence(timeout: 5))
                // The error text changes the page height. At the largest size
                // the button may be below the viewport even after returning
                // to the top; choose the direction from its current frame.
                let actionBar = app.otherElements["today.fixed-action-bar"]
                func isFullyVisible(_ element: XCUIElement) -> Bool {
                    element.isHittable && element.frame.minY >= app.frame.minY + 90 &&
                        element.frame.maxY <= actionBar.frame.minY - 8
                }
                func revealFully(_ element: XCUIElement) {
                    for _ in 0..<18 where !isFullyVisible(element) {
                        let frame = element.frame
                        let bottom = actionBar.frame.minY - 8
                        let movement = frame.minY < app.frame.minY + 90
                            ? app.frame.minY + 100 - frame.minY : bottom - 10 - frame.maxY
                        // UIKit consumes the start of a drag before scrolling.
                        // Sub-threshold adjustments can leave a fully readable
                        // target a fraction of a point short of the 8pt gutter.
                        let distance = min(140, max(40, abs(movement)))
                        let delta = movement < 0 ? -distance : distance
                        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.45))
                        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)),
                            withVelocity: .slow, thenHoldForDuration: 0.2)
                    }
                }
                revealFully(retry)
                XCTAssertTrue(isFullyVisible(retry), "Complete retry bounds: \(retry.frame); action bar: \(actionBar.frame)")
                XCTAssertEqual(retry.label, "重试回答复盘")
                XCTAssertTrue(retry.isEnabled)
                XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
                attachVoiceScreenshot(app, name: "answer-review-retry-" + suffix)
                retry.tap()
                let critique = app.staticTexts["合成复盘：已区分观察和推测，原因仍未确定。"]
                XCTAssertTrue(critique.waitForExistence(timeout: 8))
                revealFully(critique)
                XCTAssertTrue(isFullyVisible(critique), "Complete review bounds: \(critique.frame); action bar: \(actionBar.frame)")
                XCTAssertFalse(app.buttons["today.retry-message-action"].exists)
                attachVoiceScreenshot(app, name: "answer-review-recovered-" + suffix)
                let answer = app.textFields["today.question.answer-field"].exists
                    ? app.textFields["today.question.answer-field"] : app.textViews["today.question.answer-field"]
                XCTAssertEqual(answer.value as? String, "未完成是观察，设计失败和断网导致都是推测；我已能区分，具体原因仍未确定。")
                scrollTo(primary, in: app, attempts: 35)
                XCTAssertEqual(primary.label, "先保存，返回今日")
                primary.tap()
                XCTAssertTrue(app.staticTexts["今日事项"].waitForExistence(timeout: 5))
                app.terminate()
            }
        }
    }

    @MainActor
    func testModelProtocolSwitchRestoresSeparateConfigurationInNormalAndLargestText() throws {
        for largestText in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--mentor-startup-ui-test", "--model-protocol-ui-fixture",
                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-AppleInterfaceStyle", largestText ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launchEnvironment["MINGSI_MENTOR_TEST_ID"] = UUID().uuidString
            app.launch()
            let settings = app.tabBars.buttons["设置"]
            XCTAssertTrue(settings.waitForExistence(timeout: 15))
            settings.tap()
            let picker = app.buttons["settings.model-protocol"]
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            scrollTo(picker, in: app)
            picker.tap()
            app.buttons["Responses（Codex 订阅接口等）"].tap()
            XCTAssertTrue(app.staticTexts["App 会自动拼接 /responses。"].waitForExistence(timeout: 5))
            attachVoiceScreenshot(app, name: largestText ? "model-protocol-dark-largest" : "model-protocol-light")
            let url = app.textFields["settings.model-base-url"]
            scrollTo(url, in: app)
            XCTAssertEqual(url.value as? String, "https://subscription.example.test/codex")
            let model = app.textFields["settings.model-name"]
            scrollTo(model, in: app)
            XCTAssertEqual(model.value as? String, "responses-fixture")
            scrollTo(picker, in: app, towardEarlierContent: true)
            picker.tap()
            app.buttons["Chat Completions（GLM 等）"].tap()
            scrollTo(url, in: app)
            XCTAssertEqual(url.value as? String, "https://glm.example.test/v4")
            scrollTo(model, in: app)
            XCTAssertEqual(model.value as? String, "glm-fixture")
            app.terminate()
        }
    }

    @MainActor
    func testMentorStreamShowsGrowingPreviewThenValidatedAnswer() throws {
        try verifyMentorStream(interrupted: false)
    }

    @MainActor
    func testInterruptedMentorStreamKeepsCopyablePreviewAtLargestDarkText() throws {
        try verifyMentorStream(interrupted: true)
    }

    @MainActor
    func testSavedNetworkResponseAllowsNextInputWithoutBenefitFeedback() throws {
        try verifyNextInputAfterSavedResponse(largestText: false)
    }

    @MainActor
    func testSavedNetworkResponseAllowsNextInputAtLargestDarkText() throws {
        try verifyNextInputAfterSavedResponse(largestText: true)
    }

    @MainActor
    func testBottomComposerReviewsSpeechWithoutLosingTypedDraftAtLargestText() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-AppleInterfaceStyle", "Dark",
            "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        defer { app.terminate() }
        let discuss = app.buttons["我有一件事"]
        XCTAssertTrue(discuss.waitForExistence(timeout: 15))
        scrollTo(discuss, in: app)
        discuss.tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("保留原文")
        let voice = app.buttons["speech-input.toggle"]
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("取消语音识别", voice)
        voice.tap()
        assertVoiceLabel("开始语音输入", voice)
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        let review = app.textFields["speech-input.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "保留原文")
        let area = app.scrollViews["mentor.conversation.composer-scroll"]
        XCTAssertTrue(area.waitForExistence(timeout: 5))
        for _ in 0..<8 where !review.isHittable { area.swipeUp(velocity: .slow) }
        review.tap()
        review.typeText("校对")
        let corrected = try XCTUnwrap(review.value as? String)
        XCTAssertTrue(corrected.contains("校对"))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        for _ in 0..<3 where app.keyboards.firstMatch.exists { area.swipeDown(velocity: .slow) }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let accept = app.buttons["speech-input.accept"]
        for _ in 0..<8 where !accept.isHittable { area.swipeUp(velocity: .slow) }
        XCTAssertTrue(accept.isHittable)
        XCTAssertTrue(app.buttons["发送"].isHittable)
        attachVoiceScreenshot(app, name: "bottom-composer-largest-speech-review")
        accept.tap()
        XCTAssertEqual(input.value as? String, "保留原文\n" + corrected.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertTrue(review.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["发送"].isHittable)
        attachVoiceScreenshot(app, name: "bottom-composer-largest-speech-accepted")
    }

    @MainActor
    private func verifyNextInputAfterSavedResponse(largestText: Bool) throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-response-scroll-fixture", "--speech-ui-fixture",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-AppleInterfaceStyle", largestText ? "Dark" : "Light",
            "-UIPreferredContentSizeCategory", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        defer { app.terminate() }
        let discuss = app.buttons["我有一件事"]
        XCTAssertTrue(discuss.waitForExistence(timeout: 15))
        scrollTo(discuss, in: app)
        discuss.tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        scrollTo(input, in: app)
        input.tap()
        input.typeText("我周五有两小时。可以整理已有笔记，也可以学习一个新工具。我暂时没有紧急交付，想把选择依据说清楚。请用中文简短解释两个选择各自适合什么情况，不必追问，也不替我选。")
        app.buttons["speech-input.keyboard-dismiss"].tap()
        let send = app.buttons["发送"]
        scrollTo(send, in: app)
        send.tap()
        let answer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "这两个选择的关键取舍是：")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 8))
        scrollTo(answer, in: app, towardEarlierContent: true)
        XCTAssertTrue(answer.label.hasSuffix("可能仍不确定。"))
        let variant = largestText ? "dark-largest" : "light"
        attachVoiceScreenshot(app, name: "saved-response-\(variant)-before-next-input")

        // Reach the next composer with actual native swipes, leaving optional
        // benefit feedback untouched. This replay is not real-network acceptance.
        scrollTo(input, in: app)
        input.tap()
        let nextTurn = "补充一个条件：下周一要用现有笔记做五分钟分享，新工具没有近期用途。请按这个新条件重新比较，不必布置额外任务。"
        input.typeText(nextTurn)
        XCTAssertEqual(input.value as? String, nextTurn)
        let fullyVisible = NSPredicate { _, _ in
            input.isHittable && app.buttons["speech-input.keyboard-dismiss"].isHittable &&
            input.frame.minY >= app.navigationBars["这次交流"].frame.maxY - 1 &&
            input.frame.maxY <= app.keyboards.firstMatch.frame.minY + 1
        }
        expectation(for: fullyVisible, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        attachVoiceScreenshot(app, name: "saved-response-\(variant)-next-input-keyboard")
        XCTAssertTrue(input.isHittable)
        XCTAssertTrue(app.navigationBars["这次交流"].buttons["到这里"].isHittable)
        XCTAssertTrue(app.buttons["speech-input.keyboard-dismiss"].isHittable)
        XCTAssertGreaterThanOrEqual(input.frame.minY, app.navigationBars["这次交流"].frame.maxY - 1)
        XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        app.buttons["speech-input.keyboard-dismiss"].tap()
        scrollTo(send, in: app)
        XCTAssertTrue(send.isEnabled, "Next turn must not require optional benefit feedback")
        XCTAssertTrue(send.isHittable)
        XCTAssertEqual(input.value as? String, nextTurn)
        attachVoiceScreenshot(app, name: "saved-response-\(variant)-next-send-ready")
        // Do not send a second response or create synthetic benefit feedback.
    }

    @MainActor
    private func verifyMentorStream(interrupted: Bool) throws {
        executionTimeAllowance = 120
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-stream-ui-fixture", "--speech-ui-fixture",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-AppleInterfaceStyle", interrupted ? "Dark" : "Light",
            "-UIPreferredContentSizeCategory", interrupted ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        if interrupted { app.launchArguments.append("--mentor-stream-ui-failure") }
        app.launch()
        let discuss = app.buttons["我有一件事"]
        XCTAssertTrue(discuss.waitForExistence(timeout: 15))
        scrollTo(discuss, in: app)
        discuss.tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Please explain completing versus being effective. No question.")
        app.buttons["speech-input.keyboard-dismiss"].tap()
        let send = app.buttons["发送"]
        scrollTo(send, in: app)
        send.tap()
        let preview = app.staticTexts["mentor.request.stream-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 8))
        let first = preview.label
        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(first.contains("schema_version"))
        XCTAssertFalse(first.contains("source_refs"))
        if !interrupted {
            let grew = NSPredicate { _, _ in preview.exists && preview.label.count > first.count }
            expectation(for: grew, evaluatedWith: nil)
            waitForExpectations(timeout: 4)
        }
        let readingArea = app.scrollViews["mentor.conversation.reading-scroll"]
        XCTAssertTrue(readingArea.waitForExistence(timeout: 5))
        let composerArea = app.scrollViews["mentor.conversation.composer-scroll"]
        XCTAssertTrue(composerArea.waitForExistence(timeout: 5))
        func elementSnapshot(in node: any XCUIElementSnapshot, type: XCUIElement.ElementType,
                             identifier: String) -> (any XCUIElementSnapshot)? {
            if node.elementType == type, node.identifier == identifier || node.label == identifier { return node }
            for child in node.children {
                if let found = elementSnapshot(in: child, type: type, identifier: identifier) { return found }
            }
            return nil
        }
        let visiblePreview = NSPredicate { _, _ in
            // Every frame must come from the same accessibility snapshot.
            // Repeated live queries can mix two stream/layout states and take
            // most of the predicate's observation window on hosted runners.
            guard let root = try? app.snapshot(),
                  let text = elementSnapshot(in: root, type: .staticText, identifier: "mentor.request.stream-preview"),
                  let reading = elementSnapshot(in: root, type: .scrollView, identifier: "mentor.conversation.reading-scroll"),
                  let composer = elementSnapshot(in: root, type: .scrollView, identifier: "mentor.conversation.composer-scroll"),
                  let navigation = elementSnapshot(in: root, type: .navigationBar, identifier: "这次交流") else {
                print("MENTOR_PREVIEW_VISIBILITY missing snapshot element")
                return false
            }
            let textFrame = text.frame
            let readingFrame = reading.frame
            let composerFrame = composer.frame
            guard textFrame.height > 0, textFrame.width > 0 else { return false }
            // A scroll view's AX frame may extend under a safe-area inset.
            // Exclude the fixed composer and navigation bar explicitly.
            let top = max(readingFrame.minY, navigation.frame.maxY)
            let bottom = min(readingFrame.maxY, composerFrame.minY)
            let viewport = CGRect(x: readingFrame.minX, y: top,
                                  width: readingFrame.width, height: max(0, bottom - top))
            let visible = textFrame.intersection(viewport).intersection(root.frame)
            let hittable = preview.isHittable
            let matches = !visible.isNull && hittable && visible.height >= min(80, textFrame.height) &&
                visible.width >= min(100, textFrame.width)
            print("MENTOR_PREVIEW_VISIBILITY preview=\(textFrame) viewport=\(viewport) app=\(root.frame) intersection=\(visible) hittable=\(hittable) matches=\(matches)")
            return matches
        }
        attachVoiceScreenshot(app, name: interrupted ? "mentor-stream-dark-largest-before-auto-visibility-check" : "mentor-stream-light-before-auto-visibility-check")
        print("MENTOR_PREVIEW_GEOMETRY preview=\(preview.frame) reading=\(readingArea.frame) composer=\(composerArea.frame) navigation=\(app.navigationBars["这次交流"].frame)")
        expectation(for: visiblePreview, evaluatedWith: nil)
        waitForExpectations(timeout: 3)
        scrollTo(preview, in: app)
        XCTAssertTrue(preview.isHittable)
        XCTAssertGreaterThanOrEqual(preview.frame.minX, app.frame.minX + 18)
        XCTAssertLessThanOrEqual(preview.frame.maxX, app.frame.maxX - 18)
        attachVoiceScreenshot(app, name: interrupted ? "mentor-stream-dark-largest-preview" : "mentor-stream-light-preview")
        let completeBody = "完成一次尝试，和确认它有效，是两件事。可以先看实际结果改变了什么，再保留暂时无法判断的部分。"
        if interrupted {
            XCTAssertTrue(app.staticTexts["未完成的回应"].waitForExistence(timeout: 20))
            XCTAssertEqual(preview.label, completeBody)
            let retry = app.buttons["重新请求回应"]
            scrollTo(retry, in: app)
            XCTAssertTrue(retry.isHittable)
            scrollTo(preview, in: app, towardEarlierContent: true)
            attachVoiceScreenshot(app, name: "mentor-stream-dark-largest-interrupted")
        } else {
            XCTAssertTrue(app.staticTexts[completeBody].waitForExistence(timeout: 20))
            let settled = NSPredicate { _, _ in !preview.exists }
            expectation(for: settled, evaluatedWith: nil)
            waitForExpectations(timeout: 12)
            let answer = app.staticTexts[completeBody]
            scrollTo(answer, in: app)
            XCTAssertTrue(answer.isHittable)
            attachVoiceScreenshot(app, name: "mentor-stream-light-completed")
        }
        app.terminate()
    }

    @MainActor
    func testBalanceFailureExplainsRecoveryAndKeepsOriginalInNormalAndLargestText() throws {
        var normalFailureHeight: CGFloat = 0
        for largestText in [false, true] {
            let app = XCUIApplication()
            app.launchArguments += ["--mentor-ui-test", "--mentor-service-balance-fixture", "--speech-ui-fixture",
                                    "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                                    "-AppleInterfaceStyle", largestText ? "Dark" : "Light",
                                    "-UIPreferredContentSizeCategory", largestText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            let discuss = app.buttons["我有一件事"]
            XCTAssertTrue(discuss.waitForExistence(timeout: 15))
            scrollTo(discuss, in: app)
            discuss.tap()
            let input = app.textViews["你想说的话"]
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            input.tap()
            input.typeText("Synthetic thought preserved after service failure.")
            app.buttons["speech-input.keyboard-dismiss"].tap()
            let send = app.buttons["发送"]
            scrollTo(send, in: app)
            send.tap()

            let failure = app.staticTexts["mentor.request.failure"]
            XCTAssertTrue(failure.waitForExistence(timeout: 8))
            scrollTo(failure, in: app)
            XCTAssertTrue(failure.isHittable)
            XCTAssertTrue(failure.label.contains("余额不足"))
            XCTAssertTrue(failure.label.contains("资源包"))
            XCTAssertFalse(failure.label.contains("synthetic provider diagnostic"))
            if largestText {
                XCTAssertGreaterThan(failure.frame.height, normalFailureHeight * 1.3,
                    "The accessibility variant must actually render larger text")
            } else { normalFailureHeight = failure.frame.height }
            attachVoiceScreenshot(app, name: largestText ? "mentor-balance-failure-dark-largest" : "mentor-balance-failure")

            let retry = app.buttons["重新请求回应"]
            scrollTo(retry, in: app)
            XCTAssertTrue(retry.isHittable)
            let original = app.staticTexts["Synthetic thought preserved after service failure."]
            scrollTo(original, in: app, towardEarlierContent: true)
            XCTAssertTrue(original.isHittable)
            app.navigationBars["这次交流"].buttons["返回"].tap()
            let resume = app.buttons["继续这次交流"]
            XCTAssertTrue(resume.waitForExistence(timeout: 5))
            scrollTo(resume, in: app, towardEarlierContent: true)
            resume.tap()
            XCTAssertTrue(original.waitForExistence(timeout: 5))
            scrollTo(original, in: app)
            XCTAssertTrue(original.isHittable)
            app.terminate()
        }
    }

    @MainActor
    func testRecallBudgetCanBeReopenedWithoutSendingOrLosingDraft() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-recall-exhausted-fixture",
                                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let resume = app.buttons["继续这次交流"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        resume.tap()
        let continuation = app.buttons["mentor.recall.continue"]
        XCTAssertTrue(continuation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["发送"].isEnabled, "普通交流无需教材即可确认回应呈现并继续发送")
        scrollTo(continuation, in: app)
        attachVoiceScreenshot(app, name: "mentor-recall-before-continuation")
        continuation.tap()
        XCTAssertTrue(continuation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "保留尚未发送的片段")
        XCTAssertFalse(app.staticTexts["在线交流需要先配置模型，输入会保留在这里。"].exists)
        attachVoiceScreenshot(app, name: "mentor-recall-continued-draft")
        app.buttons["speech-input.keyboard-dismiss"].tap()
        app.buttons["到这里"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testLocalCorrectionCancelsWithoutChangesSavesVersionsAndRestoresHistory() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-correction-fixture",
                                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let resume = app.buttons["继续这次交流"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        resume.tap()
        let open = app.buttons["更正这条原话"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let input = app.textViews["mentor.correction.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("取消的修改")
        app.navigationBars["更正原话"].buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["UI 原话：所有人都失败了。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["更正前的原话 · 已保留"].exists)
        open.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "UI 原话：所有人都失败了。")
        input.tap()
        input.typeText("\n更正：只有一位用户失败。")
        let corrected = try XCTUnwrap(input.value as? String)
        XCTAssertTrue(corrected.contains("更正：只有一位用户失败。"))
        app.buttons["mentor.correction.input.keyboard-dismiss"].tap()
        XCTAssertTrue(app.buttons["mentor.correction.input.voice-toggle"].isHittable)
        app.buttons["mentor.correction.save"].tap()
        XCTAssertTrue(app.navigationBars["更正原话"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["更正前的原话 · 已保留"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI 原话：所有人都失败了。"].exists)
        XCTAssertTrue(app.staticTexts["更正后的原话"].exists)
        XCTAssertTrue(app.staticTexts[corrected].exists)
        attachVoiceScreenshot(app, name: "mentor-correction-versions")
        app.buttons["到这里"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForNonExistence(timeout: 5))
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "尚未发送的下一句")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.staticTexts["更正后的原话"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[corrected].exists)
        XCTAssertFalse(app.buttons["更正这条原话"].exists, "只读历史不提供修改")
        attachVoiceScreenshot(app, name: "mentor-correction-history")
    }

    @MainActor
    func testCorrectionSaveFailureKeepsEditedTextAndOriginalUntilCancelled() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-correction-fixture", "--mentor-correction-failure",
                                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let resume = app.buttons["继续这次交流"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        resume.tap()
        app.buttons["更正这条原话"].tap()
        let input = app.textViews["mentor.correction.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("\n尚未保存的更正")
        let edited = input.value as? String
        app.buttons["mentor.correction.input.keyboard-dismiss"].tap()
        let save = app.buttons["mentor.correction.save"]
        save.tap()
        XCTAssertTrue(app.staticTexts["mentor.correction.error"].waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, edited)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["mentor.correction.error"].waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, edited)
        attachVoiceScreenshot(app, name: "mentor-correction-save-failure")
        app.navigationBars["更正原话"].buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["UI 原话：所有人都失败了。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["更正前的原话 · 已保留"].exists)
        XCTAssertTrue(app.buttons["更正这条原话"].exists)
    }

    @MainActor
    func testMentorHomeOffersSharedQuickCaptureEntry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let todayTab = app.buttons["今日"]
        if todayTab.waitForExistence(timeout: 5), !todayTab.isSelected { todayTab.tap() }
        let open = app.buttons["mentor.quick-capture.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        for _ in 0..<4 {
            if open.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(open.isHittable)
        open.tap()

        XCTAssertTrue(app.navigationBars["今日闪念"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["today.captures.input"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "快捷进入今日闪念后应直接聚焦输入框")
        let dismissKeyboard = app.buttons["today.captures.input.keyboard-dismiss"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 5))
        XCTAssertTrue(dismissKeyboard.isHittable, "首次自动聚焦必须提供可点击的键盘收起入口")
        dismissKeyboard.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today.captures.input.voice-toggle"].isHittable)
        XCTAssertTrue(app.buttons["today.captures.save-action"].exists)
        XCTAssertFalse(app.buttons["today.captures.digest-action"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-quick-capture-sheet"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testMentorHomeExplainsUnavailableLessonCatalogWithoutBlockingConversation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let unavailable = app.descendants(matching: .any)["mentor.lesson.catalog-unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 15))

        let listen = app.buttons["听一个新视角"]
        XCTAssertTrue(listen.exists)
        XCTAssertFalse(listen.isEnabled)

        let discuss = app.buttons["我有一件事"]
        XCTAssertTrue(discuss.waitForExistence(timeout: 5))
        for _ in 0..<20 where !discuss.isEnabled {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(discuss.isEnabled)
    }

    @MainActor
    func testHistoricalResponseShowsAvailableAndUnavailableSourceDetails() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-source-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UI 来源原话")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        let source = app.buttons["mentor.sources.open"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap()
        XCTAssertTrue(app.navigationBars["来源详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI 来源原话：先检查实际效果。"].waitForExistence(timeout: 5))
        let unavailable = app.staticTexts["mentor.sources.unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
        XCTAssertTrue(unavailable.label.contains("没有随本次会话保存"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-source-details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["来源详情"].buttons["返回"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(record.waitForExistence(timeout: 5), "History exit observation must preserve the source record and return to the list")
    }

    @MainActor
    func testDistantHistoricalLessonRestoresSectionAfterLayoutChange() throws {
        try verifyDistantHistoricalLesson(additionalArguments: [], screenshotName: "mentor-distant-history-reading-position")
    }

    @MainActor
    func testDistantReadingAtLargestTextSizeInDarkMode() throws {
        try verifyDistantHistoricalLesson(additionalArguments: ["-UIPreferredContentSizeCategory",
            "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"],
            screenshotName: "mentor-distant-history-largest-text-dark")
    }

    @MainActor
    private func verifyDistantHistoricalLesson(additionalArguments: [String], screenshotName: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-lesson-fixture", "--mentor-long-lesson",
                                "--mentor-reading-history-fixture"] + additionalArguments
        app.launch()
        XCTAssertTrue(app.buttons["听一个新视角"].waitForExistence(timeout: 15))
        for _ in 0..<5 {
            if app.buttons["听一个新视角"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["听一个新视角"].tap()
        let boundary = app.staticTexts["适用边界"]
        XCTAssertTrue(boundary.waitForExistence(timeout: 8))
        XCTAssertTrue(boundary.isHittable)
        XCTAssertLessThan(boundary.frame.minY, 200, "A different layout restores the saved section start")
        XCTAssertFalse(app.staticTexts["测试视角 1"].isHittable)
        XCTAssertFalse(app.buttons["mentor.lesson.known"].exists, "Ended listening opens as read-only history")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screenshotName
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLongLessonRestoresReadingSectionAfterReturning() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-lesson-fixture", "--mentor-long-lesson"]
        app.launch()
        XCTAssertTrue(app.buttons["听一个新视角"].waitForExistence(timeout: 15))
        app.buttons["听一个新视角"].tap()
        let boundary = app.staticTexts["适用边界"]
        for _ in 0..<12 {
            if boundary.exists && boundary.frame.minY < 220 { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(boundary.exists)
        // Preserve a real position inside the paragraph, not just its section ID.
        app.swipeUp(velocity: .slow)
        let originalY = boundary.frame.minY
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.buttons["继续这次交流"].waitForExistence(timeout: 5))
        app.buttons["继续这次交流"].tap()
        XCTAssertTrue(boundary.waitForExistence(timeout: 5))
        XCTAssertEqual(boundary.frame.minY, originalY, accuracy: 5)
        XCTAssertFalse(app.staticTexts["测试视角 1"].isHittable)
        XCTAssertTrue(app.buttons["mentor.lesson.another"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-reading-restored-boundary"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLessonPreferenceResetRequiresConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-preferences-fixture"]
        app.launch()
        let reset = app.buttons["mentor.preferences.reset-known"]
        XCTAssertTrue(reset.waitForExistence(timeout: 15))
        reset.tap()
        XCTAssertTrue(app.buttons["保留偏好"].waitForExistence(timeout: 3))
        app.buttons["保留偏好"].tap()
        XCTAssertFalse(app.staticTexts["mentor.preferences.reset-saved"].exists)
        reset.tap()
        app.buttons["确认重置"].tap()
        XCTAssertTrue(app.staticTexts["mentor.preferences.reset-saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(reset.isEnabled)
    }

    @MainActor
    func testLessonFeedbackAndLocalNextLessonWithoutModel() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-lesson-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["听一个新视角"].waitForExistence(timeout: 15))
        app.buttons["听一个新视角"].tap()
        let known = app.buttons["mentor.lesson.known"]
        for _ in 0..<10 {
            if known.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(known.isHittable)
        known.tap()
        let saved = app.staticTexts["mentor.lesson.feedback-saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.label.contains("以后不再自动推荐"))
        let next = app.buttons["mentor.lesson.another"]
        next.tap()
        XCTAssertTrue(saved.waitForNonExistence(timeout: 5))
        let unrelated = app.buttons["mentor.lesson.not-relevant"]
        for _ in 0..<10 {
            if unrelated.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(unrelated.isHittable)
        unrelated.tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.label.contains("这次交流"))
        XCTAssertFalse(app.buttons["打开模型设置"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-lesson-feedback"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testMentorBenefitFeedbackUsesSharedVoiceInput() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-lesson-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let entry = app.buttons["听一个新视角"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()

        let known = app.buttons["mentor.lesson.known"]
        for _ in 0..<10 {
            if known.isHittable { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(known.waitForExistence(timeout: 5))
        known.tap()

        let section = app.descendants(matching: .any).matching(identifier: "mentor.benefit.section").firstMatch
        for _ in 0..<12 {
            if section.isHittable { break }
            app.swipeUp(velocity: .slow)
        }

        let note = app.textViews["mentor.benefit.note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let speechToggle = app.buttons["mentor.benefit.note.voice-toggle"]
        XCTAssertTrue(speechToggle.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(speechToggle.frame.width, 52)
        XCTAssertLessThanOrEqual(speechToggle.frame.height, 52)
        XCTAssertGreaterThan(speechToggle.frame.midX, note.frame.midX)
        XCTAssertFalse(app.buttons["点击开始录音"].exists)

        let feedback = app.buttons["mentor.benefit.benefit_helped"]
        XCTAssertTrue(feedback.isHittable)
        feedback.tap()
        XCTAssertTrue(app.staticTexts["已记录：看清了一件事"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testActiveConversationAtLargestTextSizeKeepsInputAndExitReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--mentor-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleInterfaceStyle", "Dark"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["我有一件事"].waitForExistence(timeout: 15))
        app.buttons["我有一件事"].tap()

        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        XCTAssertTrue(input.isHittable)
        XCTAssertTrue(app.staticTexts["mentor.conversation.multiturn-hint"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["mentor.conversation.multiturn-hint"].label,
                       "支持继续交流：每一轮只推进一个角度，你也可以随时点“到这里”。")
        let voice = app.buttons["speech-input.toggle"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        XCTAssertTrue(voice.isHittable)

        let finish = app.navigationBars["这次交流"].buttons["到这里"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        XCTAssertTrue(finish.isHittable)
        XCTAssertGreaterThanOrEqual(voice.frame.width, 44)
        XCTAssertGreaterThanOrEqual(voice.frame.height, 44)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-active-conversation-largest-text-dark"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        finish.tap()
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testActiveConversationKeyboardKeepsInputAndExitReachable() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        XCTAssertTrue(app.buttons["我有一件事"].waitForExistence(timeout: 15))
        app.buttons["我有一件事"].tap()

        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        input.tap()
        input.typeText("键盘打开时输入和结束操作仍然可达")

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertTrue(input.isHittable, "键盘出现后输入框不能被遮挡")

        let finish = app.navigationBars["这次交流"].buttons["到这里"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        XCTAssertTrue(finish.isHittable, "键盘出现后结束操作仍应可达")
        XCTAssertTrue(app.buttons["收起键盘"].waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-active-conversation-keyboard-visible"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["收起键盘"].tap()
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "键盘打开时输入和结束操作仍然可达")
        let voice = app.buttons["speech-input.toggle"]
        assertVoiceLabel("开始语音输入", voice)
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("取消语音识别", voice)
        voice.tap()
        assertVoiceLabel("开始语音输入", voice)
        XCTAssertEqual(input.value as? String, "键盘打开时输入和结束操作仍然可达")
    }

    @MainActor
    func testMixedHistoryLoadsLegacyRowsOnLaterPagesAndPreservesPositionAfterDeletion() throws {
        try verifyLegacyHistoryPagination(fixture: "--mentor-mixed-history-fixture", nextTitle: "History record 26")
    }

    @MainActor
    func testLegacyOnlyHistoryOffersMorePagesAndPreservesPositionAfterDeletion() throws {
        try verifyLegacyHistoryPagination(fixture: "--mentor-legacy-history-fixture", nextTitle: "Legacy record 26")
    }

    @MainActor
    private func verifyLegacyHistoryPagination(fixture: String, nextTitle: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", fixture, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let all = app.buttons["查看全部交流"]
        XCTAssertTrue(all.waitForExistence(timeout: 15))
        for _ in 0..<5 where !all.isHittable { app.swipeUp() }
        all.tap()
        XCTAssertTrue(app.navigationBars["全部交流"].waitForExistence(timeout: 5))
        let more = app.buttons["加载更多交流"]
        for _ in 0..<12 where !more.isHittable { app.swipeUp() }
        XCTAssertTrue(more.isHittable, "旧点拨也必须能分页")
        more.tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Legacy record 25")).firstMatch
        for _ in 0..<8 where !record.isHittable { app.swipeUp() }
        XCTAssertTrue(record.isHittable, "第二页不能丢掉混排的旧点拨")
        record.tap()
        XCTAssertTrue(app.buttons["继续这件事"].waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.navigationBars["全部交流"].waitForExistence(timeout: 5))
        XCTAssertTrue(record.isHittable)
        record.tap()
        app.buttons["交流操作"].tap()
        app.buttons["删除这次交流"].tap()
        app.buttons["删除整段交流"].tap()
        XCTAssertTrue(app.navigationBars["全部交流"].waitForExistence(timeout: 5))
        XCTAssertTrue(record.waitForNonExistence(timeout: 5))
        let nearby = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", nextTitle)).firstMatch
        XCTAssertTrue(nearby.isHittable, "删除后应停留在附近记录")
        attachVoiceScreenshot(app, name: fixture + "-after-deletion")
        for _ in 0..<14 where !more.isHittable { app.swipeUp() }
        XCTAssertTrue(more.isHittable)
        more.tap()
        let last = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Legacy record 45")).firstMatch
        for _ in 0..<6 where !last.isHittable { app.swipeUp() }
        XCTAssertTrue(last.isHittable)
        XCTAssertFalse(more.exists, "两类来源都耗尽后结束分页")
        attachVoiceScreenshot(app, name: fixture + "-last-page")
    }

    @MainActor
    func testFullHistoryKeepsPositionAfterViewingAndDeleting() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-history-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let all = app.buttons["查看全部交流"]
        XCTAssertTrue(all.waitForExistence(timeout: 15))
        if !all.isHittable { app.swipeUp() }
        all.tap()
        XCTAssertTrue(app.navigationBars["全部交流"].waitForExistence(timeout: 5))
        let more = app.buttons["加载更多交流"]
        for _ in 0..<12 {
            if more.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(more.isHittable)
        more.tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "History record 25")).firstMatch
        for _ in 0..<8 {
            if record.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(record.isHittable)
        record.tap()
        XCTAssertTrue(app.buttons["继续这件事"].waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.navigationBars["全部交流"].waitForExistence(timeout: 5))
        XCTAssertTrue(record.isHittable, "Returning must not reset to the first page")
        record.tap()
        app.buttons["交流操作"].tap()
        app.buttons["删除这次交流"].tap()
        app.buttons["删除整段交流"].tap()
        XCTAssertTrue(app.navigationBars["全部交流"].waitForExistence(timeout: 5))
        XCTAssertTrue(record.waitForNonExistence(timeout: 5))
        let nearby = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "History record 26")).firstMatch
        XCTAssertTrue(nearby.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-history-after-deletion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUnderstandingGroupDeletionCanBeCancelledThenConfirmed() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["我有一件事"].waitForExistence(timeout: 15))
        app.buttons["我有一件事"].tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Keep this conversation")
        app.buttons["收起键盘"].tap()
        app.swipeUp()
        app.buttons["mentor.understanding.begin"].tap()
        let note = app.textViews["mentor.understanding.input"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Delete this understanding")
        app.buttons["收起键盘"].tap()
        app.buttons["mentor.understanding.confirm"].tap()
        XCTAssertTrue(app.buttons["mentor.understanding.begin"].waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["到这里"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Keep this conversation")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let delete = app.buttons["mentor.understanding.delete-group"]
        if !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        app.buttons["保留理解"].tap()
        XCTAssertTrue(app.staticTexts["Delete this understanding"].exists)
        delete.tap()
        app.buttons["删除全部版本"].tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Delete this understanding"].exists)
        XCTAssertTrue(app.buttons["继续这件事"].exists)
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryDeletionRequiresConfirmationAndRemovesRecord() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test"]
        app.launch()
        XCTAssertTrue(app.buttons["我有一件事"].waitForExistence(timeout: 15))
        app.buttons["我有一件事"].tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Delete this conversation")
        app.buttons["收起键盘"].tap()
        app.navigationBars["这次交流"].buttons["到这里"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Delete this conversation")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        app.buttons["交流操作"].tap()
        app.buttons["删除这次交流"].tap()
        XCTAssertTrue(app.buttons["删除整段交流"].waitForExistence(timeout: 3))
        app.buttons["保留交流"].tap()
        XCTAssertTrue(app.buttons["继续这件事"].exists)
        app.buttons["交流操作"].tap()
        app.buttons["删除这次交流"].tap()
        app.buttons["删除整段交流"].tap()
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 5))
        XCTAssertFalse(record.exists)
    }

    @MainActor
    func testDamagedLegacyHistoryOffersRoundLevelRecovery() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-broken-legacy-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "损坏旧点拨原话")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let warning = app.staticTexts["mentor.legacy.lineage-warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        let recovery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mentor.legacy.recover.")).firstMatch
        XCTAssertTrue(recovery.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["继续这件事"].exists == false, "损坏旧链不能显示会失败的整链继续按钮")
        let source = app.buttons.matching(identifier: "mentor.sources.open").firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap()
        XCTAssertTrue(app.navigationBars["来源详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["旧点拨来源"].exists)
        let originalSource = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当时的原话\n损坏旧点拨原话")).firstMatch
        XCTAssertTrue(originalSource.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["mentor.sources.unavailable"].exists)
        attachVoiceScreenshot(app, name: "legacy-history-original-source")
        app.navigationBars["来源详情"].buttons["返回"].tap()
        recovery.tap()

        XCTAssertTrue(app.navigationBars["这次交流"].buttons["到这里"].waitForExistence(timeout: 5))
        XCTAssertFalse(warning.exists)
        XCTAssertTrue(app.buttons["发送"].waitForExistence(timeout: 5))
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap()
        XCTAssertTrue(originalSource.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["mentor.sources.unavailable"].exists)
        attachVoiceScreenshot(app, name: "legacy-borrowed-original-source")
    }

    @MainActor
    func testOriginalTrainingAndAllFiveTabsRemainAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 15))
        for title in ["今日", "历史", "项目", "成长", "设置"] {
            XCTAssertTrue(app.tabBars.buttons[title].exists)
        }
        app.buttons["今日整理"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mentor.legacy-today"].waitForExistence(timeout: 5))
        let quickDiscuss = app.buttons["today.single-nudge.open-action"]
        for _ in 0..<6 where !quickDiscuss.isHittable { app.swipeUp() }
        XCTAssertTrue(quickDiscuss.isHittable, "Today compatibility entry should remain reachable")
        quickDiscuss.tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForExistence(timeout: 5),
                      "Today's quick entry must open the multi-turn Mentor surface")
        XCTAssertTrue(app.staticTexts["mentor.conversation.multiturn-hint"].exists)
        app.navigationBars["这次交流"].buttons["到这里"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForNonExistence(timeout: 5))
        app.swipeDown()
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeConversationUnderstandingAndResumeWithoutModel() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 15))
        app.buttons["我有一件事"].tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("A small change worth checking")
        app.buttons["收起键盘"].tap()
        app.buttons["发送"].tap()
        XCTAssertTrue(app.buttons["打开模型设置"].waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "A small change worth checking")
        app.swipeUp()
        let begin = app.buttons["mentor.understanding.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()
        let note = app.textViews["mentor.understanding.input"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Check the outcome, not only completion.")
        app.buttons["收起键盘"].tap()
        let voice = app.buttons["mentor.understanding.input.voice-toggle"]
        assertVoiceLabel("开始语音输入", voice)
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("取消语音识别", voice)
        voice.tap()
        assertVoiceLabel("开始语音输入", voice)
        XCTAssertEqual(note.value as? String, "Check the outcome, not only completion.")
        attachVoiceScreenshot(app, name: "mentor-understanding-shared-voice")
        app.buttons["mentor.understanding.confirm"].tap()
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.buttons["继续这次交流"].waitForExistence(timeout: 5))
        app.buttons["继续这次交流"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "A small change worth checking")
        app.navigationBars["这次交流"].buttons["到这里"].tap()
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "A small change worth checking")).firstMatch.tap()
        XCTAssertTrue(app.buttons["继续这件事"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["你想说的话"].exists)
        XCTAssertFalse(app.navigationBars["这次交流"].buttons["到这里"].exists)
        app.buttons["继续这件事"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "A small change worth checking")
        app.navigationBars["这次交流"].buttons["到这里"].tap()
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-home-after-local-conversation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

extension MentorNavigationUITests {
    @MainActor
    func testHomeScreenQuickActionOpensCaptureFromSettingsWithoutLosingDraft() throws {
        continueAfterFailure = false
        let app = productionStartupApp()
        app.launch()
        let open = app.buttons["mentor.quick-capture.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        scrollTo(open, in: app)
        open.tap()
        let input = app.textViews["today.captures.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Keep the draft when opening from Home Screen.")
        let original = try XCTUnwrap(input.value as? String)
        app.buttons["today.captures.input.keyboard-dismiss"].tap()
        app.buttons["today.captures.close-action"].tap()
        app.buttons["保留草稿并关闭"].tap()
        XCTAssertTrue(input.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["设置"].tap()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["明思"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        icon.press(forDuration: 1)
        let action = springboard.buttons["com.codex.mingsi.open-today-capture"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Actual Home Screen quick action must land in capture from another tab")
        XCTAssertEqual(input.value as? String, original)
        attachVoiceScreenshot(app, name: "home-screen-shortcut-restored-capture")
        app.buttons["today.captures.input.keyboard-dismiss"].tap()
        app.buttons["today.captures.close-action"].tap()
        app.buttons["保留草稿并关闭"].tap()
        XCTAssertTrue(input.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        XCTAssertFalse(input.exists, "A consumed warm shortcut must not reopen capture on a normal relaunch")
        app.terminate()
    }

    @MainActor
    func testMaterialSelectionFullTextAndCurrentRequestInLightAndLargestDark() throws {
        var normalTextHeight: CGFloat = 0
        for largest in [false, true] {
            let app = XCUIApplication()
            app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture", "--mentor-material-selection-fixture",
                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            // Drag the scroll area's gutter so selectable text cannot consume the gesture.
            func moveContent(by distance: CGFloat) {
                let delta = max(-240, min(240, distance))
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.width * 0.8, dy: app.frame.height * 0.55))
                let end = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.width * 0.8, dy: app.frame.height * 0.55 - delta))
                start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.01)
            }
            func reveal(_ element: XCUIElement, earlier: Bool = false) {
                for _ in 0..<30 {
                    if element.isHittable { return }
                    guard element.exists else {
                        moveContent(by: earlier ? -240 : 240)
                        continue
                    }
                    let frame = element.frame
                    if frame.height > 0, frame.maxY < app.frame.minY + 110 {
                        moveContent(by: -240)
                    } else if frame.height > 0, frame.minY > app.frame.maxY - 100 {
                        moveContent(by: 240)
                    } else {
                        moveContent(by: earlier ? -240 : 240)
                    }
                }
                XCTAssertTrue(element.isHittable)
            }
            let open = app.buttons["继续这次交流"]
            XCTAssertTrue(open.waitForExistence(timeout: 15)); open.tap()
            let original = app.buttons.matching(NSPredicate(format: "label CONTAINS '查看原话全文'")).firstMatch
            reveal(original, earlier: true)
            original.tap()
            XCTAssertTrue(app.navigationBars["原话全文"].waitForExistence(timeout: 5))
            attachVoiceScreenshot(app, name: "long-original-full-start-" + (largest ? "dark-largest" : "light"))
            app.navigationBars["原话全文"].buttons["完成"].tap()
            let input = app.textViews["你想说的话"]
            reveal(input)
            XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap()
            input.typeText("请解释选中的老师原话。")
            if app.buttons["收起键盘"].waitForExistence(timeout: 2) { app.buttons["收起键盘"].tap() }
            let debugOpen = app.buttons["mentor.material-selection.debug-open"]
            reveal(debugOpen); debugOpen.tap()
            let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'mentor.material-selection.fragment.'"))
            XCTAssertEqual(rows.count, 2)
            let teacher = rows.element(boundBy: 1)
            reveal(teacher)
            XCTAssertGreaterThanOrEqual(teacher.frame.height, 44)
            teacher.tap()
            let expand = app.buttons.matching(NSPredicate(format: "label CONTAINS '查看本片段全文'")).firstMatch
            reveal(expand)
            XCTAssertTrue(expand.isHittable)
            XCTAssertGreaterThanOrEqual(expand.frame.height, 44)
            expand.tap()
            let full = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'mentor.material-selection.full-text.'")).firstMatch
            XCTAssertTrue(full.waitForExistence(timeout: 5))
            XCTAssertTrue(full.label.hasSuffix("本段全文到此结束。"))
            if largest { XCTAssertGreaterThan(full.frame.height, normalTextHeight * 1.3) }
            else { normalTextHeight = full.frame.height }
            reveal(full)
            for _ in 0..<20 where abs(full.frame.minY - (app.frame.minY + 120)) > 16 {
                moveContent(by: full.frame.minY - (app.frame.minY + 120))
            }
            XCTAssertGreaterThanOrEqual(full.frame.minY, app.frame.minY + 100)
            XCTAssertGreaterThanOrEqual(full.frame.minX, app.frame.minX + 18)
            XCTAssertLessThanOrEqual(full.frame.maxX, app.frame.maxX - 18)
            attachVoiceScreenshot(app, name: "selected-excerpt-full-start-" + (largest ? "dark-largest" : "light"))
            for _ in 0..<20 where full.frame.maxY > app.frame.maxY - 100 {
                moveContent(by: full.frame.maxY - (app.frame.maxY - 120))
            }
            XCTAssertLessThanOrEqual(full.frame.maxY, app.frame.maxY - 80)
            XCTAssertGreaterThan(full.frame.maxY, app.frame.minY + 100)
            attachVoiceScreenshot(app, name: "selected-excerpt-full-end-" + (largest ? "dark-largest" : "light"))
            let send = app.buttons["mentor.material-selection.submit"]
            reveal(send); send.tap()
            let error = app.staticTexts["mentor.material-selection.error"]
            XCTAssertTrue(error.waitForExistence(timeout: 5))
            reveal(error)
            attachVoiceScreenshot(app, name: "selected-excerpt-current-required-" + (largest ? "dark-largest" : "light"))
            let current = rows.element(boundBy: 0)
            reveal(current, earlier: true)
            current.tap()
            reveal(send)
            XCTAssertGreaterThanOrEqual(send.frame.height, 44)
            send.tap()
            XCTAssertTrue(app.descendants(matching: .any)["mentor.material-selection"].waitForNonExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testOversizedConversationOffersExplicitMaterialSelection() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-material-selection-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let open = app.buttons["继续这次交流"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("再补一条当前判断")
        if app.buttons["收起键盘"].waitForExistence(timeout: 2) { app.buttons["收起键盘"].tap() }
        let debugOpen = app.buttons["mentor.material-selection.debug-open"]
        XCTAssertTrue(debugOpen.waitForExistence(timeout: 5))
        debugOpen.tap()
        let selection = app.descendants(matching: .any)["mentor.material-selection"]
        XCTAssertTrue(selection.waitForExistence(timeout: 8))
        let panelShot = XCTAttachment(screenshot: app.screenshot())
        panelShot.name = "mentor-material-selection-panel"
        panelShot.lifetime = .keepAlways
        add(panelShot)
        XCTAssertTrue(app.staticTexts["本轮材料较长"].exists)
        let fragment = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'mentor.material-selection.fragment.'")).firstMatch
        XCTAssertTrue(fragment.waitForExistence(timeout: 5))
        fragment.tap()
        let send = app.buttons["mentor.material-selection.submit"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        XCTAssertTrue(selection.waitForNonExistence(timeout: 8))
    }

    @MainActor
    func testProjectInputsTransferMicrophoneAndKeepEachFieldsText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--speech-ui-fixture", "MINGSI_VISUAL_QA_PROJECT_DETAIL",
                                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment["MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT"] = "normal"
        app.launch()
        let edit = app.buttons["编辑项目"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        let name = app.textFields["project.edit.name"]
        let goal = app.textViews["project.edit.goal"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let originalName = try XCTUnwrap(name.value as? String)
        let originalGoal = try XCTUnwrap(goal.value as? String)
        let nameVoice = app.buttons["project.edit.name.voice-toggle"]
        let goalVoice = app.buttons["project.edit.goal.voice-toggle"]
        nameVoice.tap()
        assertVoiceLabel("停止语音输入", nameVoice)
        XCTAssertTrue(goalVoice.isHittable)
        goalVoice.tap()
        assertVoiceLabel("停止语音输入", goalVoice)
        assertVoiceLabel("重新录音", nameVoice)
        XCTAssertEqual(app.textFields["project.edit.name.voice-review"].value as? String, "语音测试第 1 次。")
        XCTAssertEqual(name.value as? String, originalName)
        XCTAssertEqual(goal.value as? String, originalGoal)
        attachVoiceScreenshot(app, name: "project-input-microphone-transfer")

        app.buttons["project.edit.name.voice-accept"].tap()
        XCTAssertEqual(name.value as? String, originalName + "\n语音测试第 1 次。")
        assertVoiceLabel("停止语音输入", goalVoice)
        nameVoice.tap()
        assertVoiceLabel("停止语音输入", nameVoice)
        assertVoiceLabel("重新录音", goalVoice)
        nameVoice.tap()
        assertVoiceLabel("重新录音", nameVoice)
        app.buttons["project.edit.name.voice-discard"].tap()
        let acceptGoal = app.buttons["project.edit.goal.voice-accept"]
        for _ in 0..<5 where !acceptGoal.isHittable { app.swipeUp() }
        acceptGoal.tap()
        XCTAssertEqual(goal.value as? String, originalGoal + "\n语音测试第 1 次。")
        attachVoiceScreenshot(app, name: "project-input-separate-results")

        app.navigationBars["编辑长期议题"].buttons["取消"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, originalName)
        XCTAssertEqual(goal.value as? String, originalGoal)
    }

    @MainActor
    func testQuickCaptureVoiceButtonCancelsRestartsAndAppendsReviewedText() throws {
        try verifyQuickCaptureVoiceLifecycle(style: "Light")
    }

    @MainActor
    func testQuickCaptureVoiceLifecycleInDarkMode() throws {
        try verifyQuickCaptureVoiceLifecycle(style: "Dark")
    }

    @MainActor
    private func verifyQuickCaptureVoiceLifecycle(style: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--speech-ui-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-AppleInterfaceStyle", style]
        app.launch()
        let open = app.buttons["mentor.quick-capture.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        for _ in 0..<5 where !open.isHittable { app.swipeUp() }
        open.tap()
        let input = app.textViews["today.captures.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("保留原文")
        let voice = app.buttons["today.captures.input.voice-toggle"]
        XCTAssertGreaterThanOrEqual(voice.frame.width, 44)
        XCTAssertLessThanOrEqual(voice.frame.width, 52)
        XCTAssertGreaterThan(voice.frame.midX, input.frame.midX)
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        voice.tap()
        assertVoiceLabel("取消语音识别", voice)
        voice.tap()
        assertVoiceLabel("开始语音输入", voice)
        XCTAssertEqual(input.value as? String, "保留原文")

        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("重新录音", voice)
        let review = app.textFields["today.captures.input.voice-review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertEqual(review.value as? String, "语音测试第 2 次。")
        XCTAssertEqual(input.value as? String, "保留原文")
        attachVoiceScreenshot(app, name: "quick-capture-voice-review-\(style)")

        // Re-record from the same icon, then recover an interrupted attempt.
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("重新录音", voice)
        XCTAssertTrue(app.staticTexts["录音已中断，请检查已识别的部分。"].exists)
        XCTAssertEqual(review.value as? String, "语音测试第 3 次。")
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("重新录音", voice)
        review.tap()
        review.typeText("已校对")
        let editedRecognition = try XCTUnwrap(review.value as? String)
        XCTAssertTrue(editedRecognition.contains("已校对"))
        XCTAssertTrue(editedRecognition.contains("语音测试第 4 次。"))
        let expectedText = "保留原文\n" + editedRecognition
        app.buttons["today.captures.input.voice-accept"].tap()
        assertVoiceLabel("开始语音输入", voice)
        XCTAssertEqual(input.value as? String, expectedText)
        XCTAssertFalse(review.exists)
        app.buttons["today.captures.save-action"].tap()
        XCTAssertTrue(app.staticTexts[expectedText].waitForExistence(timeout: 5))
        attachVoiceScreenshot(app, name: "quick-capture-voice-saved-\(style)")
    }

    @MainActor
    func testMentorFeedbackUsesSameVoiceLifecycleAndKeepsTypedDraft() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-lesson-fixture", "--speech-ui-fixture",
                                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let entry = app.buttons["听一个新视角"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()
        let known = app.buttons["mentor.lesson.known"]
        for _ in 0..<10 where !known.isHittable { app.swipeUp() }
        known.tap()
        let note = app.textViews["mentor.benefit.note"]
        for _ in 0..<12 where !note.isHittable { app.swipeUp() }
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("已有反馈")
        let voice = app.buttons["mentor.benefit.note.voice-toggle"]
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("取消语音识别", voice)
        voice.tap()
        assertVoiceLabel("开始语音输入", voice)
        voice.tap()
        assertVoiceLabel("停止语音输入", voice)
        voice.tap()
        assertVoiceLabel("重新录音", voice)
        let accept = app.buttons["mentor.benefit.note.voice-accept"]
        for _ in 0..<5 where !accept.isHittable { app.swipeUp() }
        accept.tap()
        assertVoiceLabel("开始语音输入", voice)
        XCTAssertEqual(note.value as? String, "已有反馈\n语音测试第 2 次。")
        attachVoiceScreenshot(app, name: "mentor-feedback-voice-appended")
    }

    @MainActor
    private func assertVoiceLabel(_ label: String, _ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
        XCTAssertTrue(button.isHittable, file: file, line: line)
    }

    @MainActor
    private func attachVoiceScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension MentorNavigationUITests {
    @MainActor
    func testSingleCaptureOpensConversationWithOriginalSourceAndSurvivesFinish() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-capture-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let rawText = "UI 闪念：会议结束后，我还不确定谁负责验收。"
        let open = app.buttons["mentor.quick-capture.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let discuss = app.buttons["mentor.capture.discuss.CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC"]
        XCTAssertTrue(discuss.waitForExistence(timeout: 5), "One capture is sufficient to enter a conversation")
        for _ in 0..<5 where !discuss.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts[rawText].exists)
        discuss.tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["从闪念带入"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[rawText].exists)
        app.buttons["mentor.sources.open"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["来源详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["闪念来源"].exists)
        XCTAssertTrue(app.staticTexts[rawText].exists)
        XCTAssertFalse(app.staticTexts["mentor.sources.unavailable"].exists)
        attachVoiceScreenshot(app, name: "single-capture-original-source")
        app.navigationBars["来源详情"].buttons["返回"].tap()
        let initialReply = app.buttons["聊聊这条闪念"]
        for _ in 0..<6 where !initialReply.isHittable { app.swipeUp() }
        XCTAssertTrue(initialReply.isEnabled, "No additional text is required")
        initialReply.tap()
        let settings = app.buttons["打开模型设置"]
        for _ in 0..<6 where !settings.isHittable { app.swipeDown() }
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Key configuration belongs to the explicit online action")
        app.navigationBars["这次交流"].buttons["到这里"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        let history = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", rawText)).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(app.staticTexts[rawText].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["从闪念带入"].exists)
        app.navigationBars["这次交流"].buttons["返回"].tap()
        open.tap()
        XCTAssertTrue(app.navigationBars["今日闪念"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[rawText].exists, "Finishing a conversation preserves the borrowed flash note")
    }

    @MainActor
    func testCaptureConversationFailureKeepsOriginalOnCapturePageAndAllowsRetry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "--mentor-capture-fixture", "--mentor-capture-failure",
                                "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let open = app.buttons["mentor.quick-capture.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let discuss = app.buttons["mentor.capture.discuss.CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC"]
        XCTAssertTrue(discuss.waitForExistence(timeout: 5))
        for _ in 0..<5 where !discuss.isHittable { app.swipeUp() }
        discuss.tap()
        XCTAssertTrue(app.staticTexts["mentor.capture.discussion-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["今日闪念"].exists)
        XCTAssertTrue(app.staticTexts["UI 闪念：会议结束后，我还不确定谁负责验收。"].exists)
        XCTAssertTrue(discuss.isEnabled)
        discuss.tap()
        XCTAssertTrue(app.staticTexts["mentor.capture.discussion-error"].waitForExistence(timeout: 5))
        attachVoiceScreenshot(app, name: "single-capture-entry-save-failure")
    }
}

// These cases use the production root, file persistence and bundled catalog.
// Only the database and Keychain namespace are isolated from personal data.
extension MentorNavigationUITests {
    @MainActor
    private func productionStartupApp(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--mentor-startup-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-AppleInterfaceStyle", "Light", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryL"]
        if !extra.isEmpty { app.launchArguments = ["--mentor-startup-ui-test"] + extra + Array(app.launchArguments.dropFirst()) }
        app.launchEnvironment["MINGSI_MENTOR_TEST_ID"] = UUID().uuidString
        return app
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 15, towardEarlierContent: Bool = false) {
        for _ in 0..<attempts {
            // A sliver above the tab bar can report hittable even though
            // XCTest's center tap lands on the tab bar. Bring the entry's
            // center into the content area before tapping at large text sizes.
            let captureEntryVisible = element.identifier != "mentor.quick-capture.open-action" ||
                (element.frame.midY < app.frame.maxY - 100 && element.frame.midY > app.frame.minY + 110)
            if element.isHittable && captureEntryVisible { break }
            if towardEarlierContent {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    func testProductionStartupOffersOfflineLessonsAndRestoresAfterRelaunch() throws {
        let app = productionStartupApp()
        app.launch()
        let listen = app.buttons["听一个新视角"]
        XCTAssertTrue(listen.waitForExistence(timeout: 15))
        XCTAssertTrue(listen.isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["mentor.lesson.catalog-unavailable"].exists)
        XCTAssertTrue(app.buttons["mentor.home.model-settings"].exists)
        attachVoiceScreenshot(app, name: "production-home-no-key")
        listen.tap()
        XCTAssertTrue(app.staticTexts["改动之前，先说清希望什么变好。"].waitForExistence(timeout: 10))
        attachVoiceScreenshot(app, name: "production-lesson-full-text")
        scrollTo(app.staticTexts["mentor.lesson.editorial-identity"], in: app)
        XCTAssertEqual(app.staticTexts["mentor.lesson.editorial-identity"].label, "AI 编写与编辑审核，供个人探索。")
        let known = app.buttons["mentor.lesson.known"]
        scrollTo(known, in: app)
        known.tap()
        XCTAssertTrue(app.staticTexts["mentor.lesson.feedback-saved"].waitForExistence(timeout: 5))
        scrollTo(app.buttons["mentor.lesson.another"], in: app)
        app.buttons["mentor.lesson.another"].tap()
        XCTAssertTrue(app.staticTexts["给观察和解释各留一个位置。"].waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.buttons["继续这次交流"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["开始新的回看"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["继续这次交流"].waitForExistence(timeout: 15))
        app.buttons["继续这次交流"].tap()
        XCTAssertTrue(app.staticTexts["给观察和解释各留一个位置。"].waitForExistence(timeout: 5))
        app.buttons["到这里"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testProductionStartupRecoveryFailureCanRetryAndStartFreshWithoutLosingDraft() throws {
        let app = productionStartupApp(extra: ["--mentor-startup-recovery-failure"])
        app.launch()
        XCTAssertTrue(app.staticTexts["mentor.startup.error"].waitForExistence(timeout: 15))
        attachVoiceScreenshot(app, name: "production-startup-recovery-error")
        app.buttons["mentor.startup.retry"].tap()
        XCTAssertTrue(app.buttons["继续这次交流"].waitForExistence(timeout: 10))
        app.buttons["继续这次交流"].tap()
        XCTAssertTrue(app.staticTexts["启动前已提交的原话"].waitForExistence(timeout: 5))
        app.navigationBars["这次交流"].buttons["返回"].tap()
        XCTAssertTrue(app.buttons["开始新的回看"].waitForExistence(timeout: 5))
        app.buttons["开始新的回看"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["启动前已提交的原话"].exists)
        app.navigationBars["这次交流"].buttons["返回"].tap()
        let old = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "启动失败仍保留的草稿")).firstMatch
        XCTAssertTrue(old.waitForExistence(timeout: 5))
        scrollTo(old, in: app)
        old.tap()
        XCTAssertTrue(app.staticTexts["启动前已提交的原话"].waitForExistence(timeout: 5))
        attachVoiceScreenshot(app, name: "production-startup-restored-content")
    }

    @MainActor
    func testProductionOfflineLessonDarkLargestTypeRemainsReadable() throws {
        let app = productionStartupApp(extra: ["-AppleInterfaceStyle", "Dark", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.launch()
        let listen = app.buttons["听一个新视角"]
        XCTAssertTrue(listen.waitForExistence(timeout: 15))
        scrollTo(listen, in: app)
        attachVoiceScreenshot(app, name: "production-home-dark-largest")
        listen.tap()
        XCTAssertTrue(app.staticTexts["改动之前，先说清希望什么变好。"].waitForExistence(timeout: 5))
        attachVoiceScreenshot(app, name: "production-lesson-dark-largest")
        scrollTo(app.staticTexts["mentor.lesson.editorial-identity"], in: app, attempts: 30)
        attachVoiceScreenshot(app, name: "production-lesson-identity-dark-largest")
        scrollTo(app.buttons["mentor.lesson.known"], in: app)
        app.buttons["mentor.lesson.known"].tap()
        XCTAssertTrue(app.staticTexts["mentor.lesson.feedback-saved"].waitForExistence(timeout: 5))
        app.buttons["到这里"].tap()
        XCTAssertTrue(app.navigationBars["这次交流"].waitForNonExistence(timeout: 5))
    }
}
