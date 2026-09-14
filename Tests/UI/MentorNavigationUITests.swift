import XCTest

final class MentorNavigationUITests: XCTestCase {
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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mentor-home-after-local-conversation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
