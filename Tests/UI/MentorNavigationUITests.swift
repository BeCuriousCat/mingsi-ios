import XCTest

final class MentorNavigationUITests: XCTestCase {
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
        app.swipeDown()
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        XCTAssertTrue(app.buttons["带我回看"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeConversationUnderstandingAndResumeWithoutModel() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--mentor-ui-test", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
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
