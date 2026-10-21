import XCTest

@MainActor
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

        tapPrimaryAction(in: app, expectingState: "session_complete")

        XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
    }

    func testValidationSaveOffersOptionalPrincipleAndCanFinishInNormalAndLargestText() throws {
        var normalHeight: CGFloat = 0
        for largest in [false, true] {
            let app = seededTodayApp(stage: "review_quests")
            app.launchArguments += ["-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            let optional = app.buttons["today.review-quests.optional-principle-action"]
            XCTAssertTrue(optional.waitForExistence(timeout: 8))
            XCTAssertTrue(optional.isHittable)
            XCTAssertTrue(optional.isEnabled)
            XCTAssertEqual(optional.label, "保存并整理原则候选")
            if largest { XCTAssertGreaterThan(optional.frame.height, normalHeight * 1.2) }
            else { normalHeight = optional.frame.height }
            let primary = app.buttons["today.primary-action"]
            XCTAssertTrue(primary.isHittable)
            XCTAssertEqual(primary.label, "保存验证，今天先到这里")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = largest ? "optional-principle-dark-largest" : "optional-principle-light"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            primary.tap()
            XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
            XCTAssertFalse(app.staticTexts["today.state.extract_principle"].exists)
            app.terminate()
        }
    }

    func testValidationOptionalPrincipleActionStillReachesCandidateReview() throws {
        let app = seededTodayApp(stage: "review_quests")
        app.launch()
        let optional = app.buttons["today.review-quests.optional-principle-action"]
        XCTAssertTrue(optional.waitForExistence(timeout: 8))
        XCTAssertTrue(optional.isHittable)
        optional.tap()
        XCTAssertTrue(app.staticTexts["today.state.extract_principle"].waitForExistence(timeout: 10))
        let skip = app.buttons["today.skip-principle-action"]
        XCTAssertTrue(skip.waitForExistence(timeout: 4))
        XCTAssertTrue(skip.isHittable)
        skip.tap()
        XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["今日沉淀"].exists)
    }

    func testPrincipleCandidateShowsBoundariesAndSavesLatestEditsOnlyOnConfirmation() throws {
        let app = seededTodayApp(stage: "extract_principle")
        app.launch()
        let exception = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "例外条件：")).firstMatch
        scrollToElement(exception, in: app)
        XCTAssertTrue(exception.label.contains("明确负责人"))
        let criteria = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "成功标准：")).firstMatch
        XCTAssertTrue(criteria.exists)
        let edit = app.buttons["today.principle.edit-action"]
        scrollToElement(edit, in: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "principle-candidate-boundaries"
        attachment.lifetime = .keepAlways
        add(attachment)
        edit.tap()
        let title = app.textFields["today.editable-field.标题"]
        scrollToElement(title, in: app)
        title.tap()
        title.typeText("，只作待验证的假设")
        // Confirm directly while still editing: the latest text must be used.
        let save = app.buttons["today.primary-action"]
        XCTAssertEqual(save.label, "保存为我的原则")
        save.tap()
        XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
        let saved = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "只作待验证的假设")).firstMatch
        scrollToElement(saved, in: app)
        XCTAssertTrue(saved.exists)
    }

    func testSingleNudgeVisualFixtureTransitionsToEditableValidationMaterial() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VNEXT_CASES_ENABLED"] = "0"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_INPUT"] = "会议后还没有写清验收负责人。"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MODE"] = "standard"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_STAGE"] = "capture"
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_SINGLE_NUDGE"] = "1"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "0"
        app.launch()

        let open = app.buttons["today.single-nudge.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        XCTAssertTrue(open.isHittable)
        open.tap()
        XCTAssertTrue(app.scrollViews["today.single-nudge.surface"].waitForExistence(timeout: 4))

        let helpful = app.buttons["today.single-nudge.helpful-action"]
        XCTAssertTrue(helpful.waitForExistence(timeout: 8))
        helpful.tap()

        let transition = app.buttons["today.single-nudge.transition-action"]
        XCTAssertTrue(transition.waitForExistence(timeout: 4))
        transition.tap()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 4))
        let material = app.textViews["today.capture.raw-text-field"]
        XCTAssertTrue(material.waitForExistence(timeout: 4))
        XCTAssertTrue((material.value as? String)?.contains("明思一下行动验证素材") == true)
    }

    func testVNextTodayOverviewDisplaysMultipleIndependentCases() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["今日事项"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["事项 A：明确验收负责人"].exists)
        XCTAssertTrue(app.staticTexts["事项 B：验证注册问题"].exists)
        XCTAssertTrue(app.staticTexts["事项 C：准备项目复盘"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "内容较多")).firstMatch.exists)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.overview.case.")).count,
            2
        )
    }

    func testTodayOverviewShowsDailyLifeGuidanceAndDetails() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        let card = app.buttons["today.life-guidance.daily-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(card.isHittable)
        card.tap()

        XCTAssertTrue(app.staticTexts["today.life-guidance.details.title"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先做这一步"].exists)
        XCTAssertTrue(app.staticTexts["适用边界"].exists)
        let save = app.buttons["life-guidance.save"]
        for _ in 0..<4 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.feedback"].waitForExistence(timeout: 4))
        XCTAssertTrue(save.label.contains("已存下来"))
    }

    func testTodayOverviewBrowsesLifeGuidanceCatalogAndFiltersCategory() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        let open = app.buttons["life-guidance.catalog.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        open.tap()
        XCTAssertTrue(app.navigationBars["建议库"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["life-guidance.catalog.life.attention.nonessential-notifications"].exists)
        let picker = app.buttons["life-guidance.catalog.category"]
        XCTAssertTrue(picker.exists)
        picker.tap()
        let attention = app.buttons["注意力"]
        XCTAssertTrue(attention.waitForExistence(timeout: 2))
        attention.tap()
        XCTAssertTrue(app.buttons["life-guidance.catalog.life.attention.batch-messages"].exists)
    }

    func testTodayOverviewBrowsesCompleteLifeGuidanceReferenceBook() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryL", "-AppleInterfaceStyle", "Light"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()

        let open = app.buttons["life-guidance.reference.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        for _ in 0..<4 where !open.isHittable { app.swipeUp() }
        open.tap()
        XCTAssertTrue(app.navigationBars["完整人生指南"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "34 节 · 670 条")).firstMatch.exists)

        let search = app.textFields["life-guidance.reference.search"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("安全带")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "系安全带")).firstMatch.waitForExistence(timeout: 4))
        let row = app.buttons["life-guidance.reference.life-reference.1.1"]
        XCTAssertTrue(row.exists)
        row.tap()
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "reference-details-default-light"; details.lifetime = .keepAlways; add(details)
        let useInToday = app.buttons["life-guidance.reference.use-in-today"]
        XCTAssertTrue(useInToday.waitForExistence(timeout: 4))
        useInToday.tap()
        let input = app.textViews["today.captures.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        let prefill = try XCTUnwrap(input.value as? String)
        XCTAssertTrue(prefill.contains("系安全带"))
        XCTAssertTrue(prefill.contains("- 备注："))
        XCTAssertTrue(prefill.contains("e73cb638b27f12a422546e5c09cadcac6fce03fe"))
        XCTAssertTrue(prefill.contains("我自己的情况："))
        let captureScreenshot = XCTAttachment(screenshot: app.screenshot())
        captureScreenshot.name = "reference-full-prefill"; captureScreenshot.lifetime = .keepAlways; add(captureScreenshot)
        let save = app.buttons["today.captures.save-action"]
        for _ in 0..<4 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "参考《高性价比人生指南》：")).firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        let capture = app.buttons["mentor.quick-capture.open-action"]
        XCTAssertTrue(capture.waitForExistence(timeout: 8))
        capture.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "来源提交：e73cb638")).firstMatch.waitForExistence(timeout: 5))
    }

    func testCompleteLifeGuidanceReferenceSupportsBookmarkAndOriginalText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryL", "-AppleInterfaceStyle", "Light"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()

        let open = app.buttons["life-guidance.reference.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        for _ in 0..<4 where !open.isHittable { app.swipeUp() }
        open.tap()
        let search = app.textFields["life-guidance.reference.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 4))
        search.tap()
        search.typeText("安全带")
        let row = app.buttons["life-guidance.reference.life-reference.1.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        row.tap()

        let bookmark = app.buttons["life-guidance.reference.bookmark"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 4))
        for _ in 0..<5 where !bookmark.isHittable { app.swipeUp() }
        bookmark.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "life-guidance.reference.bookmark", "已收藏")).firstMatch.waitForExistence(timeout: 4))
        let raw = app.descendants(matching: .any)["life-guidance.reference.raw"].firstMatch
        for _ in 0..<8 where !raw.isHittable { app.swipeUp() }
        XCTAssertTrue(raw.isHittable)
        raw.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "### 1.")).firstMatch.waitForExistence(timeout: 4))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let saved = app.buttons["life-guidance.reference.bookmarked.open"]
        XCTAssertTrue(saved.waitForExistence(timeout: 4))
        for _ in 0..<4 where !saved.isHittable { app.swipeDown() }
        saved.tap()
        let rowID = "life-guidance.reference.bookmarked.life-reference.1.1"
        XCTAssertTrue(app.buttons[rowID].waitForExistence(timeout: 4))
        app.buttons[rowID].tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 4))
        XCTAssertTrue(bookmark.label.contains("已收藏"))
        app.terminate()
        app.launch()
        let homeSaved = app.buttons["life-guidance.saved.open"]
        XCTAssertTrue(homeSaved.waitForExistence(timeout: 8))
        for _ in 0..<4 where !homeSaved.isHittable { app.swipeUp() }
        homeSaved.tap()
        let persisted = app.buttons["life-guidance.saved.life-reference.1.1"]
        XCTAssertTrue(persisted.waitForExistence(timeout: 4))
        persisted.tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 4))
        XCTAssertTrue(bookmark.label.contains("已收藏"))
    }

    func testReferenceDailyCardSupportsObservationAtLargestTextInDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test", "--reference-daily-ui-test", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()
        let card = app.buttons["today.life-guidance.daily-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        for _ in 0..<5 where !card.isHittable { app.swipeUp() }
        card.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.details.title"].waitForExistence(timeout: 4))
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "reference-detail-largest-text-dark"; top.lifetime = .keepAlways; add(top)
        let tried = app.buttons["life-guidance.tried"]
        for _ in 0..<8 where !tried.isHittable { app.swipeUp() }
        XCTAssertTrue(tried.isHittable)
        tried.tap()
        let input = app.textViews["life-guidance.observation"]
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        for _ in 0..<5 where !input.isHittable { app.swipeUp() }
        input.tap(); input.typeText("我试过了，这次没有明显变化。")
        let save = app.buttons["life-guidance.observation.save"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable); save.tap()
        app.terminate(); app.launch()
        let saved = app.buttons["life-guidance.saved.open"]
        XCTAssertTrue(saved.waitForExistence(timeout: 8))
        for _ in 0..<5 where !saved.isHittable { app.swipeUp() }
        saved.tap()
        let row = app.buttons["life-guidance.saved.life-reference.34.11"]
        XCTAssertTrue(row.waitForExistence(timeout: 4)); row.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        XCTAssertTrue((input.value as? String)?.contains("这次没有明显变化") == true)
    }

    func testReferenceLongReadsRenderTablesAndOpenInternalLinks() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryL", "-AppleInterfaceStyle", "Light"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()
        let open = app.buttons["life-guidance.reference.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        for _ in 0..<5 where !open.isHittable { app.swipeUp() }
        open.tap()
        let library = app.buttons["长文与术语表"]
        XCTAssertTrue(library.waitForExistence(timeout: 4)); library.tap()
        let tableArticle = app.buttons["life-guidance.reference.document.life-reference.doc.做平台要办哪些证"]
        for _ in 0..<12 where !tableArticle.isHittable { app.swipeUp() }
        XCTAssertTrue(tableArticle.isHittable); tableArticle.tap()
        XCTAssertTrue(app.staticTexts["一、先判断你做的是哪种业务"].waitForExistence(timeout: 4))
        let tableHeader = app.staticTexts["你在做的事"].firstMatch
        for _ in 0..<4 where !tableHeader.isHittable { app.swipeUp() }
        XCTAssertTrue(tableHeader.isHittable)
        XCTAssertTrue(app.staticTexts["对应业务类别"].firstMatch.exists)
        let tableScreenshot = XCTAttachment(screenshot: app.screenshot())
        tableScreenshot.name = "reference-long-read-table"; tableScreenshot.lifetime = .keepAlways; add(tableScreenshot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let linkedArticle = app.buttons["life-guidance.reference.document.life-reference.doc.换工作、换城市之前"]
        for _ in 0..<8 where !linkedArticle.isHittable { app.swipeUp() }
        XCTAssertTrue(linkedArticle.isHittable); linkedArticle.tap()
        let textLink = app.staticTexts["← 回总目录"]
        let link = app.links["← 回总目录"].exists ? app.links["← 回总目录"] : textLink
        XCTAssertTrue(link.waitForExistence(timeout: 4)); link.tap()
        XCTAssertTrue(app.navigationBars["长文与术语表"].waitForExistence(timeout: 4), "内部链接应打开应用内目录")
        XCTAssertTrue(app.buttons["完成"].exists)
    }

    func testTodayOverviewShowsReviewLifeGuidanceAfterCompletedReview() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_LIFE_GUIDANCE_REVIEW"] = "1"
        app.launch()

        let card = app.buttons["today.life-guidance.review-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(card.label.contains("消息") || card.label.contains("通知"))
        card.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.details.title"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["触发这条建议的事件"].exists)
        XCTAssertTrue(app.staticTexts["最近消息通知太多，手机不断打断我的注意力。"].exists)
    }

    func testMentorHomeGuidanceSaveReopenAfterRelaunchAndDismiss() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()
        let card = app.buttons["today.life-guidance.daily-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
        card.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.details.title"].waitForExistence(timeout: 4))
        let save = app.buttons["life-guidance.save"]
        for _ in 0..<4 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.feedback"].waitForExistence(timeout: 4))
        app.terminate()
        app.launch()
        let saved = app.buttons["life-guidance.saved.open"]
        XCTAssertTrue(saved.waitForExistence(timeout: 8))
        for _ in 0..<4 where !saved.isHittable { app.swipeUp() }
        saved.tap()
        let row = app.buttons["life-guidance.saved.life.attention.single-task"]
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        row.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.details.title"].waitForExistence(timeout: 4))
        let dismiss = app.buttons["life-guidance.dismiss"]
        for _ in 0..<4 where !dismiss.isHittable { app.swipeUp() }
        XCTAssertTrue(dismiss.isHittable)
        XCTAssertTrue(save.label.contains("已存下来"))
        dismiss.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.feedback"].waitForExistence(timeout: 4))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["mentor.quick-capture.open-action"].waitForExistence(timeout: 8))
        XCTAssertFalse(card.exists, "不适合的当天入口应在重启后仍隐藏")
        XCTAssertTrue(app.buttons["life-guidance.saved.open"].exists)
    }

    func testGuidanceTryOpensEditableConversationWithoutSubmitting() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()
        let card = app.buttons["today.life-guidance.daily-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        for _ in 0..<4 where !card.isHittable { app.swipeUp() }
        card.tap()
        let action = app.buttons["life-guidance.try"]
        XCTAssertTrue(action.waitForExistence(timeout: 4))
        for _ in 0..<4 where !action.isHittable { app.swipeUp() }
        action.tap()
        let input = app.textViews["你想说的话"]
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        XCTAssertTrue((input.value as? String)?.contains("我想试试这条建议：给重要事情留一段不被打断的时间") == true)
        XCTAssertTrue((input.value as? String)?.contains("我想改善的是：") == true)
        XCTAssertFalse(app.staticTexts["正在查看回顾里是否有相关建议。"].exists)
        XCTAssertTrue(app.navigationBars["这次交流"].buttons["返回"].isHittable)
    }

    func testGuidanceAtLargestTextSizeInDarkModeKeepsActionsAndObservationReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--life-guidance-ui-test", "-UIPreferredContentSizeCategory", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        app.launchEnvironment["MINGSI_LIFE_GUIDANCE_TEST_ID"] = UUID().uuidString
        app.launch()
        let card = app.buttons["today.life-guidance.daily-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        for _ in 0..<10 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.isHittable)
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "life-guidance-home-largest-text-dark"; home.lifetime = .keepAlways; add(home)
        card.tap()
        XCTAssertTrue(app.staticTexts["today.life-guidance.details.title"].waitForExistence(timeout: 4))
        let tried = app.buttons["life-guidance.tried"]
        for _ in 0..<10 where !tried.isHittable { app.swipeUp() }
        XCTAssertTrue(tried.isHittable)
        XCTAssertGreaterThanOrEqual(tried.frame.height, 44)
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "life-guidance-details-largest-text-dark"; details.lifetime = .keepAlways; add(details)
        tried.tap()
        let observation = app.textViews["life-guidance.observation"]
        XCTAssertTrue(observation.waitForExistence(timeout: 4))
        for _ in 0..<10 where !observation.isHittable { app.swipeUp() }
        XCTAssertTrue(observation.isHittable)
        observation.tap()
        observation.typeText("这次试过后没有明显变化。")
        let record = app.buttons["life-guidance.observation.save"]
        for _ in 0..<6 where !record.isHittable { app.swipeUp() }
        XCTAssertTrue(record.isHittable)
        record.tap()
        app.terminate()
        app.launch()
        let saved = app.buttons["life-guidance.saved.open"]
        XCTAssertTrue(saved.waitForExistence(timeout: 8))
        for _ in 0..<10 where !saved.isHittable { app.swipeUp() }
        saved.tap()
        let row = app.buttons["life-guidance.saved.life.attention.single-task"]
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        row.tap()
        for _ in 0..<10 where !observation.isHittable { app.swipeUp() }
        XCTAssertEqual(observation.value as? String, "这次试过后没有明显变化。")
    }

    func testTodayOverviewOpensCaptureSheet() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        let open = app.buttons["today.captures.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        XCTAssertTrue(open.isHittable)
        open.tap()
        XCTAssertTrue(app.scrollViews["today.captures.sheet"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["today.captures.save-action"].exists)
        let speechToggle = app.scrollViews["today.captures.sheet"].buttons["today.captures.input.voice-toggle"]
        XCTAssertTrue(speechToggle.waitForExistence(timeout: 4))
        XCTAssertTrue(speechToggle.label.contains("开始语音输入"))
        XCTAssertTrue(speechToggle.isHittable)

        let input = app.textViews["today.captures.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        XCTAssertLessThanOrEqual(speechToggle.frame.width, 52, "语音入口应保持为小型图标按钮")
        XCTAssertLessThanOrEqual(speechToggle.frame.height, 52, "语音入口应保持为小型图标按钮")
        XCTAssertGreaterThan(speechToggle.frame.midX, input.frame.midX, "语音入口应位于输入框右侧")
        XCTAssertFalse(app.buttons["点击开始录音"].exists, "不应再显示输入框外的横向录音按钮")
    }

    func testTodayOverviewSavesCaptureFragmentAndClearsInput() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        let open = app.buttons["today.captures.open-action"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        open.tap()

        let input = app.textViews["today.captures.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        let capture = "UI 闪念保存验收 20260827"
        input.tap()
        input.typeText(capture)
        let dismissKeyboard = app.buttons["收起键盘"]
        if dismissKeyboard.waitForExistence(timeout: 2) {
            dismissKeyboard.tap()
        } else {
            // Some simulator profiles use a hardware keyboard and do not
            // expose SwiftUI's keyboard toolbar. The input still supports
            // interactive scroll dismissal in that environment.
            app.scrollViews["today.captures.sheet"].swipeDown()
        }

        let save = app.buttons["today.captures.save-action"]
        XCTAssertTrue(save.waitForExistence(timeout: 4))
        XCTAssertTrue(save.isHittable)
        save.tap()

        XCTAssertTrue(app.staticTexts[capture].waitForExistence(timeout: 4))
        XCTAssertEqual(input.value as? String, "")
    }

    func testVNextOverviewMissingKeyCTAOpensAPIConfigurationAtAccessibilityXXXL() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategory",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launchEnvironment["MINGSI_VNEXT_CASES_ENABLED"] = "1"
        app.launch()

        let configureCentralModel = app.buttons["today.central-model-key.settings-action"]
        XCTAssertTrue(configureCentralModel.waitForExistence(timeout: 8))
        XCTAssertTrue(configureCentralModel.label.contains("配置中央模型后整理"))
        // At XXXL the overview adds the quick-capture and single-nudge entries;
        // the CTA may start below the fold, so bring it into the tappable area.
        scrollToElement(configureCentralModel, in: app)
        configureCentralModel.tap()

        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["API 配置"].waitForExistence(timeout: 4))
    }

    func testVNextTodayOverviewSupportsAccessibilityTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategory",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        let title = app.staticTexts["今日概览"]
        let help = app.buttons["today.training-terms-action"]
        let firstCase = app.staticTexts["事项 A：明确验收负责人"]

        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(help.waitForExistence(timeout: 4))
        XCTAssertTrue(firstCase.waitForExistence(timeout: 4))
        XCTAssertLessThan(title.frame.maxX, help.frame.minX)
        XCTAssertLessThan(title.frame.maxY, firstCase.frame.minY)
    }

    func testVNextTodayOverviewCanResumePendingCaseConfirmation() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launch()

        let resume = app.buttons["today.case-confirmation.resume-action"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()

        XCTAssertTrue(app.staticTexts["确认事项"].waitForExistence(timeout: 4))
    }

    func testTodaySideQuestIsOptionalAndCanAwardLifeExperience() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        app.launchEnvironment["MINGSI_VISUAL_QA_VNEXT_OVERVIEW"] = "1"
        app.launchEnvironment["MINGSI_VISUAL_QA_SIDE_QUEST"] = "1"
        app.launch()

        let accept = app.buttons["today.side-quest.accept-action"]
        scrollToElement(accept, in: app)
        XCTAssertTrue(accept.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["做出一个十分钟成品"].exists)
        XCTAssertTrue(app.buttons["today.side-quest.skip-action"].exists)
        accept.tap()

        let complete = app.buttons["today.side-quest.complete-action"]
        scrollToElement(complete, in: app)
        XCTAssertTrue(complete.waitForExistence(timeout: 4))
        complete.tap()
        XCTAssertTrue(app.navigationBars["收下这一刻"].waitForExistence(timeout: 4))
        app.navigationBars["收下这一刻"].buttons["收下"].tap()

        let reward = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "这一刻已被收下")
        ).firstMatch
        XCTAssertTrue(reward.waitForExistence(timeout: 4))
    }

    func testProjectsStatusRailFiltersEvidenceByStatus() throws {
        let app = XCUIApplication()
        app.launchArguments += ["MINGSI_VISUAL_QA_PROJECT_DETAIL"]
        app.launchEnvironment["MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT"] = "normal"
        app.launch()

        let detailNavigationBar = app.navigationBars["长期议题"]
        XCTAssertTrue(detailNavigationBar.waitForExistence(timeout: 8))
        let backButton = detailNavigationBar.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 4))
        backButton.tap()

        let currentFilter = app.buttons["projects.status-filter.all"]
        let activeFilter = app.buttons["projects.status-filter.active"]
        let archivedFilter = app.buttons["projects.status-filter.archived"]
        XCTAssertTrue(currentFilter.waitForExistence(timeout: 6))
        XCTAssertTrue(activeFilter.exists)
        XCTAssertTrue(archivedFilter.exists)

        archivedFilter.tap()
        XCTAssertTrue(app.staticTexts["没有匹配「已结束」状态的项目。"].waitForExistence(timeout: 4))

        currentFilter.tap()
        XCTAssertTrue(app.staticTexts["Visual QA - 会议机制优化"].waitForExistence(timeout: 4))
    }

    func testSideQuestV2SettingsShowsPlaceScopedPracticalSamplesWithoutPlaceNames() throws {
        let app = sideQuestV2App(tab: "settings")
        app.launch()
        openSideQuestSettings(in: app)

        let lifeContext = app.staticTexts["settings.side-quest.life-context.card"]
        scrollToElement(lifeContext, in: app)
        XCTAssertTrue(app.staticTexts["生活情境"].exists)
        XCTAssertTrue(app.staticTexts["家"].exists)
        XCTAssertTrue(app.staticTexts["工作地点"].exists)
        XCTAssertEqual(
            app.textFields["settings.side-quest.practical-place.home.floor-field"].value as? String,
            "12"
        )
        XCTAssertEqual(
            app.textFields["settings.side-quest.practical-place.workplace.floor-field"].value as? String,
            "7"
        )
        XCTAssertTrue(app.descendants(matching: .any)["settings.side-quest.practical-place.home.stairs-picker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.side-quest.practical-place.workplace.stairs-picker"].exists)
        XCTAssertTrue(app.staticTexts["午饭后"].exists)
        XCTAssertTrue(app.staticTexts["离开工作地点时"].exists)
        XCTAssertTrue(app.staticTexts["到家后"].exists)
        XCTAssertFalse(app.staticTexts["Visual QA 工作地点"].exists)
    }

    func testSideQuestV2SettingsCanStartAndEndExplorationSeasonWithReview() throws {
        let app = sideQuestV2App(tab: "settings")
        app.launch()
        openSideQuestSettings(in: app)

        let seasonCard = app.staticTexts["settings.side-quest.season.card"]
        scrollToElement(seasonCard, in: app)
        let start = app.buttons["settings.side-quest.season.start-action"]
        XCTAssertTrue(start.waitForExistence(timeout: 4))
        XCTAssertTrue(start.isEnabled)
        start.tap()

        let end = app.buttons["settings.side-quest.season.end-action"]
        XCTAssertTrue(end.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["城市漫游"].exists)
        scrollToElement(seasonCard, in: app)
        XCTAssertTrue(end.isHittable)
        end.tap()

        let review = app.staticTexts["最近一季回顾：城市漫游"]
        XCTAssertTrue(review.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["settings.side-quest.season.end-action"].exists)
    }

    func testSideQuestV2WorkplaceStairsOfferCanBeAcceptedAndCompleted() throws {
        let app = sideQuestV2App(tab: "today")
        app.launch()

        let card = app.staticTexts["today.side-quest.card"]
        scrollToElement(card, in: app)
        XCTAssertTrue(app.staticTexts["下班前走一段楼梯"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "为你遇见")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "工作地点")).firstMatch.exists)
        let rationale = app.descendants(matching: .any)["today.side-quest.rationale"]
        XCTAssertTrue(rationale.label.contains("第 7 层"))
        XCTAssertTrue(rationale.label.contains("楼梯可用"))

        let sceneMenu = app.buttons["today.side-quest.current-scene-menu"]
        XCTAssertTrue(sceneMenu.waitForExistence(timeout: 4))
        XCTAssertTrue(sceneMenu.label.contains("设置当前粗粒度情境"))
        sceneMenu.tap()
        let workplace = app.buttons["在工作地点"]
        XCTAssertTrue(workplace.waitForExistence(timeout: 4))
        workplace.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当前情境已设为在工作地点")).firstMatch.waitForExistence(timeout: 4))

        let accept = app.buttons["today.side-quest.accept-action"]
        scrollToElement(accept, in: app)
        accept.tap()
        let complete = app.buttons["today.side-quest.complete-action"]
        XCTAssertTrue(complete.waitForExistence(timeout: 4))
        complete.tap()
        XCTAssertTrue(app.navigationBars["收下这一刻"].waitForExistence(timeout: 4))
        app.navigationBars["收下这一刻"].buttons["收下"].tap()

        let reward = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "这一刻已被收下")).firstMatch
        XCTAssertTrue(reward.waitForExistence(timeout: 4))
    }

    func testGrowthShowsWeeklyEvidenceProgressBeforeGenerationIsAvailable() throws {
        let app = seededGrowthApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["最近 7 天：1 / 3 次验证 · 1 / 2 天"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["达到条件后，可以由你主动生成一次下周训练重点。还需 2 次验证，再覆盖 1 天。"].exists)
        XCTAssertFalse(app.buttons["growth.weekly-guidance.generate-action"].exists)
    }

    func testGrowthRecordCountDoesNotClaimGrowthInNormalAndLargestText() throws {
        for variant in ["empty", "three", "legacy"] {
            for largest in [false, true] {
                let app = XCUIApplication()
                app.launchArguments = ["--growth-evidence-ui-fixture", "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                    "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
                if variant == "empty" { app.launchArguments.append("--growth-zero-records") }
                if variant == "legacy" { app.launchArguments.append("--growth-legacy-local") }
                app.launch()
                let progress = app.staticTexts["growth.record-progress"]
                scrollToElement(progress, in: app)
                XCTAssertEqual(progress.label, "当前记录中有 \(variant == "empty" ? 0 : 3) 次完整复盘。")
                XCTAssertFalse(app.staticTexts["已满足展示变化的最小证据"].exists)
                XCTAssertFalse(app.staticTexts["训练指标"].exists)
                let explanation = app.staticTexts["growth.evidence-status"]
                scrollToElement(explanation, in: app)
                XCTAssertTrue(explanation.label.contains(variant == "legacy" ? "旧版汇总" : "次数和自评不代表能力变化"))
                XCTAssertTrue(explanation.isHittable)
                let image = XCTAttachment(screenshot: app.screenshot())
                image.name = "growth-evidence-\(variant)-\(largest ? "dark-largest" : "light")"
                image.lifetime = .keepAlways
                add(image)
                let back = app.buttons["growth.record-progress.continue"]
                scrollToElement(back, in: app)
                XCTAssertTrue(back.isHittable)
                back.tap()
                XCTAssertTrue(app.tabBars.buttons["今日"].isSelected)
                app.terminate()
            }
        }
    }

    func testGrowthShowsBeforeAfterEvidenceAndCanOpenHistorySource() throws {
        let app = seededGrowthApp()
        app.launch()

        let before = app.staticTexts["只要会后补发结论，就能避免后续返工。"]
        let after = app.staticTexts["返工追问减少，但关键参与方仍需在会前参与确认。"]
        XCTAssertTrue(before.waitForExistence(timeout: 8))
        XCTAssertTrue(after.exists)
        XCTAssertTrue(app.staticTexts["判断变化"].exists)
        XCTAssertTrue(app.staticTexts["来源证据 1 条"].exists)

        before.tap()
        XCTAssertTrue(app.staticTexts["已定位到来源证据"].waitForExistence(timeout: 4))
    }

    func testGrowthShowsCycleSummaryOnlyWithReviewableEvidence() throws {
        let app = seededGrowthApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["周期概览"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["本周期把会议推进拆成了可检查的责任和验收条件；会前关键参与方仍需提前确认。"].exists)
        XCTAssertTrue(app.staticTexts["最近报告审查"].exists)
        XCTAssertTrue(app.staticTexts["训练指标"].exists)
        XCTAssertTrue(app.staticTexts["下次会议前确认关键参与方，并在会后记录负责人和验收信号。"].exists)
    }

    func testGrowthReflectionTopicsPreserveUncertaintyAndOpenSourceInNormalAndLargestText() throws {
        for largest in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["--growth-evidence-ui-fixture", "--reflection-topics-populated",
                "-AppleInterfaceStyle", largest ? "Dark" : "Light", "-UIPreferredContentSizeCategory",
                largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            XCTAssertTrue(app.staticTexts["复盘中讨论过"].waitForExistence(timeout: 8))
            XCTAssertFalse(app.staticTexts["讲不清"].exists)
            XCTAssertFalse(app.staticTexts["沟通力"].exists)
            let control = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "比较依据")).firstMatch
            scrollToElement(control, in: app)
            XCTAssertTrue(control.isHittable)
            control.tap()
            let answer = app.staticTexts["这次交接少了一种例外，暂时无法判断是标准还是范围起作用。"]
            scrollToElement(answer, in: app)
            XCTAssertTrue(answer.exists)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = "reflection-topics-\(largest ? "dark-largest" : "light")"
            image.lifetime = .keepAlways
            add(image)
            let source = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "growth.reflection-topic.source.")).firstMatch
            scrollToElement(source, in: app)
            XCTAssertTrue(source.isHittable)
            source.tap()
            XCTAssertTrue(app.staticTexts["已定位到来源证据"].waitForExistence(timeout: 4))
            XCTAssertTrue(app.tabBars.buttons["历史"].isSelected)
            app.terminate()
        }
    }

    func testGrowthGenericRecordsDoNotBecomeAbilityDiagnoses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--growth-evidence-ui-fixture"]
        app.launch()
        XCTAssertTrue(app.staticTexts["复盘中讨论过"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["当前记录中还没有可按主题对照的已回答问题。你仍可以在历史中回看原文。"].exists)
        XCTAssertFalse(app.staticTexts["讲不清"].exists)
        XCTAssertFalse(app.staticTexts["沟通力"].exists)
        XCTAssertFalse(app.staticTexts["出现 3 次"].exists)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "reflection-topics-unclassified"
        image.lifetime = .keepAlways
        add(image)
    }

    func testTodayTrainingPrescriptionShowsPrimaryFocusAndBaselineChecks() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        XCTAssertTrue(app.staticTexts["你已经说了什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先补哪里"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["推荐怎么练"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["诊断主要缺口"].exists)
        XCTAssertFalse(app.staticTexts["推荐训练处方"].exists)
        XCTAssertTrue(app.staticTexts["当前材料的暂定理解"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["当前阶段：补证据"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["建议：先减缓收敛，补齐关键证据。"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["缺口：缺观察事实、缺基线"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["思考方向：证据意识"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["基础检查"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["底盘检查"].exists)
        XCTAssertTrue(app.staticTexts["证据缺口"].exists)
    }

    func testInitialModelGapDoesNotInventObservationAndCanBeSkipped() throws {
        for largest in [false, true] {
            let app = seededTodayApp(stage: "select_lens", input: "事实：两次提交都在上传时超时，权限是否限制重试未知。")
            app.launchEnvironment["MINGSI_VISUAL_QA_INITIAL_COACH_GAP"] = "missing_constraint"
            app.launchArguments += ["-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            let gap = app.staticTexts["today.coach-decision.material-gap"]
            scrollToElement(gap, in: app)
            XCTAssertTrue(isElementInTappableScrollArea(gap, app: app))
            XCTAssertTrue(gap.label.contains("缺约束"))
            XCTAssertFalse(gap.label.contains("缺观察事实"))
            XCTAssertFalse(gap.label.contains("缺基线"))
            let reason = app.staticTexts["today.coach-decision.reason"]
            scrollToElement(reason, in: app)
            XCTAssertTrue(isElementInTappableScrollArea(reason, app: app))
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", reason.label)).count, 1,
                           "Do not repeat the model diagnosis in its optional recommendation card")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "initial-coach-gap-\(largest ? "dark-largest" : "light")"
            shot.lifetime = .keepAlways; add(shot)
            XCTAssertTrue(app.staticTexts["可选视角"].exists, "The fixture must render the actual method recommendation card")
            XCTAssertFalse(app.staticTexts["教练建议 · 84%"].exists)
            XCTAssertFalse(app.buttons["today.training-prescription.teaching-toggle"].exists,
                           "Do not add a locally invented training route to a model suggestion")
            XCTAssertFalse(app.staticTexts["推荐怎么练"].exists, "Local keyword diagnosis must not precede the model decision")
            XCTAssertFalse(app.buttons["today.coach-diagnosis.slow-down-action"].exists)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "建议：先标出")).firstMatch.exists,
                           "A generic move label must not reintroduce an assignment absent from the model reason")
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "轮次：教练初始轮次")).firstMatch.exists,
                           "Do not repeat the same model reason as a turn summary")
            if largest {
                XCTAssertFalse(app.descendants(matching: .any)["today.fixed-action-bar"].exists)
            }
            let accept = app.buttons["today.training-prescription.accept-action"]
            scrollToElement(accept, in: app)
            XCTAssertTrue(accept.isHittable)
            accept.tap()
            let skip = app.buttons[largest ? "today.training-prescription.skip-action" : "today.select-lens.continue-without-lens"]
            scrollToElement(skip, in: app)
            XCTAssertTrue(skip.isHittable)
            skip.tap()
            XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
            app.terminate()
        }
        let app = seededTodayApp(stage: "select_lens", input: "事实：提交超时，原因未知；今天先不继续调查。")
        app.launchEnvironment["MINGSI_VISUAL_QA_INITIAL_COACH_GAP"] = "none"
        app.launch()
        let reason = app.staticTexts["today.coach-decision.reason"]
        scrollToElement(reason, in: app)
        XCTAssertTrue(reason.label.contains("不必继续调查"))
        XCTAssertFalse(app.staticTexts["today.coach-decision.material-gap"].exists)
        app.terminate()
    }

    func testTodayTrainingPrescriptionShowsTeachingRoute() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        XCTAssertFalse(app.staticTexts["哪里没想全"].exists)
        XCTAssertFalse(app.staticTexts["这次练什么"].exists)
        XCTAssertFalse(app.staticTexts["为什么不能直接给答案"].exists)
        XCTAssertFalse(app.staticTexts["为什么先不直接给答案"].exists)
        XCTAssertFalse(app.staticTexts["怎么练"].exists)
        XCTAssertFalse(app.staticTexts["教练追问"].exists)
        XCTAssertFalse(app.staticTexts["训练契约"].exists)
        XCTAssertFalse(app.staticTexts["训练边界"].exists)
        XCTAssertFalse(app.staticTexts["训练路线"].exists)

        let routeToggle = app.buttons["today.training-prescription.teaching-toggle"]
        XCTAssertTrue(routeToggle.waitForExistence(timeout: 4))
        routeToggle.tap()

        XCTAssertTrue(app.staticTexts["哪里没想全"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["这次练什么"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["为什么先不直接给答案"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["建议补充"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["怎么练"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["本轮漏想点"].exists)
        XCTAssertFalse(app.staticTexts["本轮练什么"].exists)
        XCTAssertFalse(app.staticTexts["为什么不能直接给答案"].exists)
        XCTAssertFalse(app.staticTexts["训练契约"].exists)
        XCTAssertFalse(app.staticTexts["训练边界"].exists)
        XCTAssertFalse(app.staticTexts["训练路线"].exists)
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
        XCTAssertTrue(overrideAudit.label.contains("仍保留记录"))
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
        let clarifyStage = app.buttons["today.visible-stage.clarify-today"]
        let judgmentStage = app.buttons["today.visible-stage.examine-judgment"]
        let validationStage = app.buttons["today.visible-stage.define-validation"]
        XCTAssertTrue(clarifyStage.waitForExistence(timeout: 4))
        XCTAssertTrue(clarifyStage.label.contains("讲清今天"))
        XCTAssertTrue(clarifyStage.label.contains("进行中"))
        XCTAssertTrue(judgmentStage.label.contains("找出判断"))
        XCTAssertTrue(judgmentStage.label.contains("待开始"))
        XCTAssertFalse(judgmentStage.isEnabled)
        XCTAssertTrue(validationStage.label.contains("行动验证"))
        XCTAssertTrue(validationStage.label.contains("待开始"))
        XCTAssertFalse(validationStage.isEnabled)
        XCTAssertFalse(app.staticTexts["记录今天 -> 复盘一下"].exists)
        XCTAssertFalse(app.staticTexts["做一步 -> 回来看结果"].exists)
        XCTAssertFalse(app.staticTexts["今日理解闭环"].exists)
        XCTAssertFalse(app.staticTexts["行动验证闭环"].exists)
        XCTAssertFalse(app.staticTexts["闭环一：今天内容与今日复盘"].exists)
        XCTAssertFalse(app.staticTexts["先讲清发生了什么、你做了什么、你怎么理解；这一步不写明天计划。"].exists)
        XCTAssertFalse(app.buttons["today.loop-boundary-toggle"].exists)
        XCTAssertFalse(app.staticTexts["本页只写今天内容"].exists)
        XCTAssertFalse(app.staticTexts["基础能力训练"].exists)
        XCTAssertTrue(app.buttons["today.capture.guidance-toggle"].waitForExistence(timeout: 4))
        let materialEvent = app.staticTexts["today.capture.material-guide.event"]
        let materialAction = app.staticTexts["today.capture.material-guide.action"]
        let materialThought = app.staticTexts["today.capture.material-guide.thought"]
        XCTAssertTrue(materialEvent.waitForExistence(timeout: 4))
        XCTAssertTrue(materialAction.waitForExistence(timeout: 4))
        XCTAssertTrue(materialThought.waitForExistence(timeout: 4))
        XCTAssertLessThan(abs(materialEvent.frame.midY - materialAction.frame.midY), 2)
        XCTAssertLessThan(abs(materialAction.frame.midY - materialThought.frame.midY), 2)
        XCTAssertLessThan(materialEvent.frame.maxX, materialAction.frame.minX)
        XCTAssertLessThan(materialAction.frame.maxX, materialThought.frame.minX)

        let guide = app.buttons["today.capture.guidance-toggle"]
        for _ in 0..<8 where !guide.isHittable { app.swipeUp() }
        guide.tap()
        let optional = app.staticTexts["只选对当前困惑有用的一项，不必逐项填写。"]
        XCTAssertTrue(optional.waitForExistence(timeout: 4))
        for _ in 0..<8 where !optional.isHittable { app.swipeUp() }
        let guideShot = XCTAttachment(screenshot: app.screenshot())
        guideShot.name = "capture-optional-input-guide"
        guideShot.lifetime = .keepAlways; add(guideShot)
        let deepDescription = app.staticTexts["更仔细检查假设和其他解释，不增加提问数量。"]
        for _ in 0..<12 where !deepDescription.isHittable { app.swipeUp() }
        XCTAssertTrue(deepDescription.isHittable)
        XCTAssertFalse(app.staticTexts["追问更深，适合重要事件和周复盘。"].exists)
        let modeShot = XCTAttachment(screenshot: app.screenshot())
        modeShot.name = "capture-mode-matches-prompt"
        modeShot.lifetime = .keepAlways; add(modeShot)

        XCTAssertFalse(app.buttons["today.reset-action"].exists)
        let moreActions = app.buttons["today.more-actions"]
        XCTAssertTrue(moreActions.waitForExistence(timeout: 4))
        moreActions.tap()
        XCTAssertTrue(app.buttons["today.reset-action"].waitForExistence(timeout: 4))
    }

    func testTodayTrainingTermsExplainCardsAndCoachLanguage() throws {
        let app = seededTodayApp(stage: "capture")
        app.launch()

        let termsAction = app.buttons["today.training-terms-action"]
        XCTAssertTrue(termsAction.waitForExistence(timeout: 8))
        termsAction.tap()

        XCTAssertTrue(app.descendants(matching: .any)["today.training-terms-sheet"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["问题卡"].exists)
        XCTAssertTrue(app.staticTexts["教练追问"].exists)
        XCTAssertTrue(app.staticTexts["验证任务"].exists)
        XCTAssertTrue(app.staticTexts["对照写法"].exists)
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
        XCTAssertFalse(app.staticTexts["这次练什么"].exists)
        let trainingContract = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "不是让 AI 替你给答案")
        ).firstMatch
        XCTAssertFalse(trainingContract.exists)
        XCTAssertTrue(app.staticTexts["建议补充"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["下一句训练"].exists)
        XCTAssertFalse(app.staticTexts["怎么算讲清楚"].exists)

        let trainingToolsToggle = app.buttons["today.capture.training-tools-toggle"]
        XCTAssertTrue(trainingToolsToggle.waitForExistence(timeout: 4))
        scrollToElement(trainingToolsToggle, in: app)
        trainingToolsToggle.tap()

        let trainingTarget = app.staticTexts["这次练什么"]
        scrollDownUntilElementExists(trainingTarget, in: app)
        XCTAssertTrue(trainingContract.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["怎么算讲清楚"].waitForExistence(timeout: 4))
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
            NSPredicate(format: "label CONTAINS %@", "想想以前类似情况")
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

    func testVNextAnswerQuestionsKeepsFirstAnswerFieldAbovePrimaryAction() throws {
        let app = seededVNextTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["先写下支持或推翻判断的可观察事实。"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["把事实与解释分开，能减少只凭感受确认原判断。"].exists)
        XCTAssertTrue(app.buttons["反馈"].exists)

        let answerField = app.textFields.matching(identifier: "today.question.answer-field").firstMatch
        let primaryAction = app.buttons["today.primary-action"]
        XCTAssertTrue(answerField.waitForExistence(timeout: 4))
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 4))
        XCTAssertTrue(answerField.isHittable)
        XCTAssertLessThanOrEqual(
            answerField.frame.maxY + 8,
            primaryAction.frame.minY,
            "answerField: \(answerField.frame), primaryAction: \(primaryAction.frame)"
        )
    }

    func testGuidanceLayoutAndDismissalInLightAndLargestDarkText() throws {
        for (name, size, appearance) in [("light-normal", "UICTContentSizeCategoryL", "Light"),
                                         ("dark-largest", "UICTContentSizeCategoryAccessibilityXXXL", "Dark")] {
            let app = seededVNextTodayApp(stage: "answer_questions")
            app.launchArguments = ["--today-loop-ui-fixture", "--guidance-presentation-ui-fixture",
                "-UIPreferredContentSizeCategory", size, "-AppleInterfaceStyle", appearance]
            app.launch()
            let toggle = app.buttons["today.active-guidance-toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 8))
            for _ in 0..<8 where !toggle.isHittable { app.swipeUp() }
            XCTAssertTrue(toggle.isHittable)
            toggle.tap()
            let snooze = app.buttons["暂不显示"]
            let mastered = app.buttons["我已掌握"]
            XCTAssertTrue(snooze.waitForExistence(timeout: 4))
            for _ in 0..<8 where !mastered.isHittable { app.swipeUp() }
            XCTAssertTrue(mastered.isHittable)
            XCTAssertGreaterThanOrEqual(snooze.frame.height, 44)
            XCTAssertGreaterThanOrEqual(mastered.frame.height, 44)
            XCTAssertGreaterThanOrEqual(snooze.frame.minX, 18)
            XCTAssertLessThanOrEqual(mastered.frame.maxX, app.frame.maxX - 18)
            if name == "dark-largest" {
                XCTAssertLessThanOrEqual(snooze.frame.maxY, mastered.frame.minY)
            }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "guidance-expanded-\(name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            for _ in 0..<8 where !snooze.isHittable { app.swipeDown() }
            XCTAssertTrue(snooze.isHittable)
            snooze.tap()
            XCTAssertTrue(toggle.waitForNonExistence(timeout: 4))
            app.terminate()
        }
    }

    func testVNextGuidanceRevealsExplanationAndStateActionsOnDemand() throws {
        let app = seededVNextTodayApp(stage: "answer_questions")
        app.launch()

        let guidanceToggle = app.buttons["today.active-guidance-toggle"]
        XCTAssertTrue(guidanceToggle.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["把事实与解释分开，能减少只凭感受确认原判断。"].exists)

        guidanceToggle.tap()

        XCTAssertTrue(app.staticTexts["把事实与解释分开，能减少只凭感受确认原判断。"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["暂不显示"].exists)
        XCTAssertTrue(app.buttons["我已掌握"].exists)
    }

    func testTodayAnswerQuestionsPrioritizesQuestionAndAnswerBeforeDiagnostics() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        let judgmentStage = app.buttons["today.visible-stage.examine-judgment"]
        XCTAssertTrue(judgmentStage.waitForExistence(timeout: 4))
        XCTAssertTrue(judgmentStage.label.contains("找出判断"))
        XCTAssertTrue(judgmentStage.label.contains("进行中"))
        XCTAssertFalse(app.staticTexts["闭环一：今天内容与今日复盘"].exists)
        XCTAssertTrue(app.staticTexts["教练追问"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["回答一个关键问题。"].exists)
        XCTAssertTrue(app.staticTexts["先补一处没讲清的地方。"].waitForExistence(timeout: 4))

        let questionText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "先补上一个可观察事实")
        ).firstMatch
        XCTAssertTrue(questionText.waitForExistence(timeout: 4))

        XCTAssertTrue(app.staticTexts["先补：缺观察事实"].waitForExistence(timeout: 4))
        let notAnswer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "不是让 AI 替你给答案")
        ).firstMatch
        XCTAssertFalse(notAnswer.exists)
        let answerField = app.textFields.matching(identifier: "today.question.answer-field").firstMatch
        XCTAssertTrue(answerField.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["分离事实解释"].exists)

        let coachBasisToggle = app.buttons["today.question.coach-basis-toggle"].firstMatch
        XCTAssertTrue(coachBasisToggle.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["能力训练诊断"].exists)
        XCTAssertFalse(app.staticTexts["训练动作"].exists)
        XCTAssertFalse(app.staticTexts["作答方式"].exists)

        coachBasisToggle.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "教练判断")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "先补一句")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "为什么这样练")
        ).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["本题练法"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["分离事实解释"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["答案会改变"].exists)
        let conciseJudgment = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "先补缺观察事实")
        ).firstMatch
        XCTAssertTrue(conciseJudgment.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["训练动作"].exists)
        XCTAssertFalse(app.staticTexts["补的缺口"].exists)
        XCTAssertFalse(app.staticTexts["这一题练什么"].exists)
        XCTAssertFalse(app.staticTexts["还缺什么"].exists)
        XCTAssertFalse(app.staticTexts["为什么现在问"].exists)
        XCTAssertFalse(app.staticTexts["答完要更清楚"].exists)
        XCTAssertFalse(app.staticTexts["什么时候继续"].exists)
        XCTAssertFalse(app.staticTexts["怎么回答"].exists)
        XCTAssertFalse(app.staticTexts["作答要更新"].exists)
        XCTAssertFalse(app.staticTexts["作答方式"].exists)
        XCTAssertFalse(app.staticTexts["来源"].exists)
        XCTAssertFalse(app.staticTexts["校准对象"].exists)

        let diagnosisToggle = app.buttons["today.answer.diagnosis-toggle"].firstMatch
        scrollToElement(diagnosisToggle, in: app)
        XCTAssertTrue(diagnosisToggle.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["这次主要练"].exists)
        XCTAssertFalse(app.staticTexts["能力训练诊断"].exists)

        diagnosisToggle.tap()
        XCTAssertTrue(app.staticTexts["这次主要练"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["能力训练诊断"].exists)
        let abilityDiagnosis = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "本轮主练：思考力中的判断力")
        ).firstMatch
        XCTAssertTrue(abilityDiagnosis.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先把材料分开"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["讲清楚训练"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["已说清"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["什么时候继续"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["材料分离训练"].exists)
        XCTAssertFalse(app.staticTexts["讲述训练"].exists)
        XCTAssertFalse(app.staticTexts["推进标准"].exists)
        XCTAssertFalse(app.staticTexts["我观察到"].exists)
        XCTAssertFalse(app.staticTexts["当前主要缺口"].exists)
        XCTAssertFalse(app.staticTexts["请你补充"].exists)
    }

    func testTodaySelectLensShowsObservationInventoryBeforeLensChoice() throws {
        let app = seededTodayApp(stage: "select_lens")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.select_lens"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["教练观察"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["这次主要练"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["Coach Observation"].exists)
        XCTAssertFalse(app.staticTexts["能力训练诊断"].exists)
        XCTAssertTrue(app.staticTexts["已说清"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先补"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["我观察到"].exists)
        XCTAssertFalse(app.staticTexts["当前主要缺口"].exists)
        XCTAssertFalse(app.staticTexts["这次先练"].exists)
        XCTAssertFalse(app.staticTexts["请你补充"].exists)
    }

    func testTodayAnswerQuestionsShowsCoachGapPreviewAfterTyping() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        typeFirstQuestionAnswer("先让 Alex 写清验收标准。", in: app)

        XCTAssertTrue(app.staticTexts["明思听完以后"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["today.answer.coach-reference-suggestion"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["教练建议"].exists)
        XCTAssertTrue(app.buttons["查看对照写法"].exists)
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
        XCTAssertFalse(app.staticTexts["现在能继续吗"].exists)
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
        XCTAssertFalse(app.staticTexts["别人能不能复述"].exists)
        XCTAssertFalse(app.staticTexts["怎么算讲清楚"].exists)
        XCTAssertFalse(app.staticTexts["能力修补"].exists)
        XCTAssertFalse(app.staticTexts["复盘训练契约"].exists)
        let gapPreview = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "观察事实")
        ).firstMatch
        XCTAssertTrue(gapPreview.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["想想以前类似情况"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["过往经验复现"].exists)
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
        XCTAssertFalse(app.staticTexts["把判断说完整"].exists)

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
        XCTAssertTrue(app.staticTexts["还缺什么"].waitForExistence(timeout: 4))
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
        XCTAssertTrue(app.staticTexts["别人能不能复述"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["训练产物"].exists)
        let trainingOutput = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "别人能复述")
        ).firstMatch
        XCTAssertTrue(trainingOutput.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["怎么算讲清楚"].waitForExistence(timeout: 4))
        let selfCheck = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "谁的什么问题会变少")
        ).firstMatch
        XCTAssertTrue(selfCheck.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["能力修补"].exists)
        XCTAssertTrue(app.staticTexts["这次练什么"].waitForExistence(timeout: 4))
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

        let judgmentTitle = app.staticTexts["把判断说完整"].firstMatch
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

    func testTodayAnswerQuestionsCanNavigateBackToClarifyStageWhileAnswerFieldIsActive() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        typeFirstQuestionAnswer("先验证最小行动", in: app)

        let clarifyStage = app.buttons["today.visible-stage.clarify-today"]
        XCTAssertTrue(clarifyStage.waitForExistence(timeout: 8))
        clarifyStage.tap()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textViews["today.capture.raw-text-field"].waitForExistence(timeout: 4))
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

    func testTodayVisibleStageCanReturnToEarlierStage() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        let clarifyStage = app.buttons["today.visible-stage.clarify-today"]
        XCTAssertTrue(clarifyStage.waitForExistence(timeout: 4))
        XCTAssertTrue(clarifyStage.isEnabled)
        XCTAssertTrue(clarifyStage.label.contains("已完成"))
        clarifyStage.tap()

        XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.visible-stage.clarify-today"].label.contains("进行中"))
    }

    func testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["想想以前类似情况"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["过往经验复现"].exists)
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
        let validationStage = app.buttons["today.visible-stage.define-validation"]
        XCTAssertTrue(validationStage.waitForExistence(timeout: 4))
        XCTAssertTrue(validationStage.label.contains("行动验证"))
        XCTAssertTrue(validationStage.label.contains("进行中"))
        XCTAssertFalse(app.staticTexts["闭环二：明日验证与结果校准"].exists)
        XCTAssertTrue(app.staticTexts["设计验证行动"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["本页只设计明天的验证行动"].exists)
        XCTAssertFalse(app.staticTexts["今日复盘交接点"].exists)
        XCTAssertFalse(app.buttons["today.review-quests.guidance-toggle"].exists)
        XCTAssertTrue(app.staticTexts["今天要验证"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["准备怎么做"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先看行动和观察结果，再决定是否保存。"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["对应判断"].exists)
        XCTAssertTrue(app.staticTexts["完成证据"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["校准问题"].waitForExistence(timeout: 4))
        let details = app.buttons["today.quest.details-toggle"].firstMatch
        scrollToElement(details, in: app)
        details.tap()
        for (_, label) in [
            ("today.quest.validation.action", "明天做什么"),
            ("today.quest.validation.evidence", "什么算完成"),
            ("today.quest.validation.judgment", "验证什么判断"),
            ("today.quest.validation.calibration", "结果怎么用")
        ] {
            let qualityCheck = app.staticTexts[label].firstMatch
            XCTAssertTrue(qualityCheck.waitForExistence(timeout: 4))
            XCTAssertEqual(qualityCheck.label, label)
        }
    }

    func testCapturedActionAllowsNaturalRetryAndUnknownResultInLightAndLargestDark() throws {
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
        let target = "这位朋友在网络恢复、说明不变时再次提交，可能成功。"
        let criteria = "若这位朋友自然重试，观察网络已恢复且说明未变时，提交是否成功；未重试、网络状态不明或说明已变，则结果仍未知。"
        for largest in [false, true] {
            let app = seededTodayApp(stage: "review_quests", input: "一位朋友填写页面时退出，我原先怀疑说明不清。后来日志确认他在提交前断网了；还不知道恢复网络后能否提交。我不想重写说明，也不想做沟通训练。愿意下次只看这位朋友网络恢复后的提交结果，保持说明不变。")
            app.launchEnvironment["MINGSI_VISUAL_QA_QUEST_RESPONSE"] = response
            app.launchArguments += ["-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
            let anchor = app.staticTexts[target].firstMatch
            scrollToElement(anchor, in: app)
            XCTAssertTrue(anchor.exists)
            XCTAssertTrue(isElementInTappableScrollArea(anchor, app: app))
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", target)).count, 1)
            XCTAssertFalse(app.staticTexts["对应判断"].exists)
            XCTAssertFalse(app.staticTexts["today.quest.validation.action"].exists)
            let top = XCTAttachment(screenshot: app.screenshot())
            top.name = largest ? "action-target-dark-largest" : "action-target-light"
            top.lifetime = .keepAlways
            add(top)
            let evidence = app.staticTexts[criteria].firstMatch
            scrollToElement(evidence, in: app)
            XCTAssertTrue(isElementInTappableScrollArea(evidence, app: app))
            let signal = XCTAttachment(screenshot: app.screenshot())
            signal.name = largest ? "action-signal-dark-largest" : "action-signal-light"
            signal.lifetime = .keepAlways
            add(signal)
            let review = app.staticTexts["这次结果支持、削弱还是仍无法判断该预测，哪些观察条件限制了判断？"].firstMatch
            scrollToElement(review, in: app)
            XCTAssertTrue(isElementInTappableScrollArea(review, app: app))
            if largest {
                XCTAssertFalse(app.descendants(matching: .any)["today.fixed-action-bar"].exists)
            }
            let primary = app.buttons["today.primary-action"]
            if largest {
                scrollToElement(primary, in: app)
            }
            XCTAssertTrue(primary.isHittable)
            XCTAssertGreaterThanOrEqual(primary.frame.minY, 64)
            XCTAssertLessThanOrEqual(primary.frame.maxY, app.tabBars.firstMatch.frame.minY - 8)
            let actionShot = XCTAttachment(screenshot: app.screenshot())
            actionShot.name = largest ? "action-save-dark-largest" : "action-save-light"
            actionShot.lifetime = .keepAlways
            add(actionShot)
            primary.tap()
            XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
            app.terminate()
        }
    }

    func testTodayReviewQuestsMissingCalibrationTargetCanReturnToReview() throws {
        let app = seededTodayApp(stage: "review_quests", missingCalibrationTarget: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["先补一个判断"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["还没有明确的待验证判断。请回到今日复盘，把一个判断写成明天能观察的信号。"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["对应判断"].exists)

        let repairAction = app.buttons["today.return-to-review-for-judgment-action"]
        scrollToElement(repairAction, in: app)
        repairAction.tap()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["教练追问"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["先补一处没讲清的地方。"].waitForExistence(timeout: 4))
    }

    func testNoActionOutcomeCanBeReadSavedOrReturnedToReview() throws {
        for largest in [false, true] {
            let app = seededTodayApp(stage: "review_quests", input: "我现在只想保留这段回顾，不安排行动。")
            app.launchEnvironment["MINGSI_VISUAL_QA_QUEST_RESPONSE"] = #"{"main_quest":null,"side_quests":[],"observation_quest":null}"#
            app.launchArguments += ["-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            XCTAssertTrue(app.staticTexts["today.state.review_without_action"].waitForExistence(timeout: 8))
            let explanation = app.staticTexts["today.no-action.explanation"]
            scrollToElement(explanation, in: app)
            XCTAssertFalse(app.buttons["today.review-quests.optional-principle-action"].exists)
            XCTAssertFalse(app.staticTexts["先补一个判断"].exists)
            let reading = XCTAttachment(screenshot: app.screenshot())
            reading.name = largest ? "no-action-reading-dark-largest" : "no-action-reading-light"
            reading.lifetime = .keepAlways
            add(reading)
            let save = app.buttons["today.primary-action"]
            XCTAssertEqual(save.label, "保存回顾，今天先到这里")
            if largest { scrollToElement(save, in: app) }
            XCTAssertTrue(save.isHittable)
            save.tap()
            XCTAssertTrue(app.staticTexts["today.state.session_complete"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts["回顾已保存，这次没有安排行动。"].exists)
            XCTAssertFalse(app.staticTexts["明日验证行动"].exists)
            XCTAssertFalse(app.buttons["today.previous-action"].exists)
            app.terminate()
        }
        let app = seededTodayApp(stage: "review_quests")
        app.launchEnvironment["MINGSI_VISUAL_QA_QUEST_RESPONSE"] = #"{"main_quest":null,"side_quests":[],"observation_quest":null}"#
        app.launch()
        let back = app.buttons["today.no-action.return-to-review"]
        scrollToElement(back, in: app)
        back.tap()
        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
    }

    func testTodayVerifyYesterdayFramesResultCalibration() throws {
        let app = seededTodayApp(stage: "verify_yesterday")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.verify_yesterday"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["开始前 · 回看昨天"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["today.visible-stage.clarify-today"].label.contains("待开始"))
        XCTAssertTrue(app.buttons["today.visible-stage.examine-judgment"].label.contains("待开始"))
        XCTAssertTrue(app.buttons["today.visible-stage.define-validation"].label.contains("待开始"))
        XCTAssertFalse(app.staticTexts["闭环二：结果校准"].exists)
        XCTAssertFalse(app.staticTexts["只看昨天那一步：做没做、有没有用、判断要不要改。看完再开始写今天。"].exists)
        XCTAssertTrue(app.staticTexts["回看昨天"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["先校准昨天的明日验证，再开始收集今天的新材料。"].exists)
        XCTAssertFalse(app.staticTexts["本页只校准昨天结果"].exists)
        XCTAssertFalse(app.staticTexts["只检查做没做、有没有实际价值、昨天判断要不要更新；新的今日内容在下一段填写。"].exists)
        XCTAssertTrue(app.staticTexts["你的判断自评"].waitForExistence(timeout: 4))
        for title in ["暂不能判断", "确认判断", "调整判断", "推翻判断"] {
            let option = app.buttons[title]
            scrollToElement(option, in: app)
            XCTAssertTrue(option.isHittable)
        }
    }

    func testResultInputAllowsUnknownAndCancellationKeepsInputInNormalAndLargestText() throws {
        var normalInputHeight: CGFloat = 0
        for largest in [false, true] {
            let app = seededTodayApp(stage: "verify_yesterday")
            app.launchArguments += ["--verification-submission-delay", "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            // This fixture already owns a real in-memory quest; generic stage
            // seeding would trim it away and skip verification on submission.
            app.launchEnvironment.removeValue(forKey: "MINGSI_VISUAL_QA_TODAY_INPUT")
            app.launch()
            XCTAssertTrue(app.staticTexts["网络正常时重试一次填写"].waitForExistence(timeout: 8))
            let resultLabel = app.staticTexts["today.verification.result-label"]
            scrollToElement(resultLabel, in: app)
            XCTAssertTrue(resultLabel.isHittable)
            let field = app.textFields["today.yesterday-evidence.input"]
            scrollToElement(field, in: app)
            XCTAssertTrue(field.isHittable)
            XCTAssertTrue(field.placeholderValue?.contains("没有观察、出现反例或记录冲突") == true)
            if largest { XCTAssertGreaterThan(resultLabel.frame.height, normalInputHeight * 1.15) }
            else { normalInputHeight = resultLabel.frame.height }
            field.tap()
            let input = "我还没有记录重试结果，暂时不能判断。"
            field.typeText(input)
            let dismiss = app.buttons["today.yesterday-evidence.input.keyboard-dismiss"]
            XCTAssertTrue(dismiss.waitForExistence(timeout: 3))
            dismiss.tap()
            for label in ["完成", "不确定", "暂不能判断"] {
                let button = app.buttons[label].firstMatch
                scrollToElement(button, in: app)
                XCTAssertTrue(button.isHittable)
                button.tap()
            }
            let before = XCTAttachment(screenshot: app.screenshot())
            before.name = largest ? "result-input-unknown-dark-largest" : "result-input-unknown-light"
            before.lifetime = .keepAlways
            add(before)
            let primary = app.buttons["today.primary-action"]
            XCTAssertEqual(primary.label, "保存结果回顾")
            primary.tap()
            let cancel = app.buttons["today.cancel-current-ai-action"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 5))
            XCTAssertFalse(primary.isEnabled)
            XCTAssertTrue(cancel.isEnabled)
            XCTAssertTrue(cancel.isHittable)
            cancel.tap()
            XCTAssertTrue(primary.waitForExistence(timeout: 3))
            XCTAssertTrue(primary.isEnabled)
            scrollToElement(field, in: app, towardTop: true)
            XCTAssertEqual(field.value as? String, input)
            let after = XCTAttachment(screenshot: app.screenshot())
            after.name = largest ? "result-input-cancelled-dark-largest" : "result-input-cancelled-light"
            after.lifetime = .keepAlways
            add(after)
            primary.tap()
            XCTAssertTrue(app.staticTexts["today.state.capture"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    func testTodayReviewQuestsSeedShowsQuestTrainingTarget() throws {
        let app = seededTodayApp(stage: "review_quests")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.review_quests"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["today.quest.validation.action"].exists)
        XCTAssertFalse(app.staticTexts["today.quest.validation.evidence"].exists)
        XCTAssertFalse(app.staticTexts["today.quest.validation.judgment"].exists)
        XCTAssertFalse(app.staticTexts["today.quest.validation.calibration"].exists)
        XCTAssertTrue(app.staticTexts["完成证据"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["校准问题"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["为什么重要"].exists)
        XCTAssertFalse(app.staticTexts["阻力预案"].exists)
        XCTAssertFalse(app.staticTexts["训练说明"].exists)
        XCTAssertFalse(app.staticTexts["复现哪条原则"].exists)
        XCTAssertFalse(app.staticTexts["执行训练契约"].exists)
        XCTAssertFalse(app.staticTexts["执行力训练"].exists)
        XCTAssertFalse(app.staticTexts["训练原则"].exists)

        let detailsToggle = app.buttons["today.quest.details-toggle"].firstMatch
        scrollToElement(detailsToggle, in: app)
        detailsToggle.tap()
        XCTAssertTrue(app.staticTexts["为什么重要"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["阻力预案"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["训练说明"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["本次沿用的旧原则"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Visual QA - 会前确认负责人"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["匹配依据：写出负责人。它只用于训练记录，不会替你改变明天要做的事。"].waitForExistence(timeout: 4))
    }

    func testSettingsKeepsAdvancedToolsBehindSingleEntry() throws {
        let app = settingsApp()
        app.launch()

        let action = app.buttons["settings.advanced-tools.action"]
        scrollToElement(action, in: app)
        XCTAssertFalse(app.descendants(matching: .any)["settings.asset-pack-manifest.card"].exists)
        XCTAssertFalse(app.staticTexts["AI 调用审计"].exists)

        action.tap()
        XCTAssertTrue(app.navigationBars["高级工具"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["settings.asset-pack-manifest.card"].waitForExistence(timeout: 4))
    }

    func testSettingsProductionAdvancedToolsKeepRemoteRegistryHidden() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "settings"
        app.launch()
        openSettingsAdvancedTools(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["settings.asset-pack-manifest.import-field"].exists)
        XCTAssertFalse(app.textFields["settings.asset-pack-registry.catalog-url-field"].exists)
        XCTAssertFalse(app.textFields["settings.asset-pack-manifest.remote-url-field"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Marketplace")).firstMatch.exists)
    }

    func testSettingsAssetPackManifestInstallReportsInvalidJSONThroughIdentifier() throws {
        let app = settingsApp()
        app.launch()
        openSettingsAdvancedTools(in: app)

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
        openSettingsAdvancedTools(in: app)

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
        openSettingsAdvancedTools(in: app)

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
        openSettingsAdvancedTools(in: app)

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
        openSettingsAdvancedTools(in: app)

        let section = app.staticTexts["settings.prompt-asset-quality.section"]
        scrollToElement(section, in: app)
        XCTAssertTrue(section.exists)

        let row = app.staticTexts["settings.prompt-asset-quality.mingsi_builtin_prompts.organizeCards.connection-test"]
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        XCTAssertTrue(row.label.contains("失败率 100%"))

        let route = app.staticTexts["路由：整理中心"]
        XCTAssertTrue(route.waitForExistence(timeout: 4))
    }

    func testGrowthPrinciplePracticeCorrectionActionRendersThroughIdentifier() throws {
        let app = seededGrowthApp()
        app.launch()
        expandFirstGrowthPrincipleDetails(in: app)

        let disputeAction = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", ".dispute-action")).firstMatch
        scrollToElement(disputeAction, in: app)
        XCTAssertTrue(disputeAction.exists)
    }

    func testGrowthPracticeDistinguishesBehaviorFromUnassessedHistoryInNormalAndLargestText() throws {
        for largest in [false, true] {
            let app = seededGrowthApp()
            app.launchArguments += ["--principle-practice-ui-fixture", "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            expandFirstGrowthPrincipleDetails(in: app)
            let notice = app.staticTexts.matching(NSPredicate(format: "identifier ENDSWITH %@", ".unassessed-practice")).firstMatch
            scrollToElement(notice, in: app)
            XCTAssertEqual(notice.label, "有 1 条历史关联尚缺实际行为记录，暂不计为实践。")
            let latest = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "最近证据：")).firstMatch
            scrollToElement(latest, in: app)
            XCTAssertTrue(latest.label.contains("交接前我写了验收标准，请对方复述确认"))
            XCTAssertTrue(latest.label.contains("不证明效果或已经内化"))
            let dispute = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", ".dispute-action")).firstMatch
            scrollToElement(dispute, in: app)
            XCTAssertTrue(dispute.isHittable)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = largest ? "practice-record-dark-largest" : "practice-record-light"
            image.lifetime = .keepAlways
            add(image)
            dispute.tap()
            XCTAssertTrue(latest.waitForNonExistence(timeout: 4))
            scrollToElement(notice, in: app, towardTop: true)
            XCTAssertTrue(notice.label.contains("暂不计为实践"))
            app.terminate()
        }
    }

    func testGrowthPrinciplePracticeCorrectionActionRemovesLatestEvidence() throws {
        let app = seededGrowthApp()
        app.launch()
        expandFirstGrowthPrincipleDetails(in: app)

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
        XCTAssertTrue(disputedAudit.label.contains("交接前我写了验收标准"))
    }

    func testGrowthNeedsReviewRecallAuditRendersThroughIdentifier() throws {
        let app = seededGrowthApp()
        app.launch()
        expandGrowthPrincipleDetails(at: 1, in: app)

        let recallAudit = app.staticTexts.matching(NSPredicate(format: "identifier ENDSWITH %@", ".negative-audit")).firstMatch
        scrollToElement(recallAudit, in: app)
        XCTAssertTrue(recallAudit.exists)
        XCTAssertTrue(recallAudit.label.contains("复审依据："))
        XCTAssertTrue(recallAudit.label.contains("命中信号：命中会议负责人"))
        XCTAssertTrue(recallAudit.label.contains("Owner keyword was a false positive."))
    }

    func testHistoryHidesEmptyEvidenceSections() throws {
        let app = historyApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["历史"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["这一天没有沉淀卡片。"].exists)
        XCTAssertFalse(app.staticTexts["这一天没有选择思考透镜。"].exists)
        XCTAssertFalse(app.staticTexts["这一天没有设计明日验证。"].exists)
        XCTAssertFalse(app.staticTexts["这一天没有验证记录。"].exists)
        XCTAssertFalse(app.buttons["history.ai-repair.disclosure"].exists)
    }

    func testResultReviewSeparatesEvidenceAssessmentFromPositiveSelfRating() throws {
        for variant in ["observed", "conflicting", "missing"] {
            let largest = variant == "missing"
            let app = XCUIApplication()
            app.launchArguments = ["--result-review-ui-fixture", "-AppleInterfaceStyle", largest ? "Dark" : "Light",
                "-UIPreferredContentSizeCategory", largest ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launchEnvironment["MINGSI_RESULT_REVIEW_VARIANT"] = variant
            app.launch()
            let title = app.staticTexts[variant == "observed" ? "本次证据削弱原判断" : "原判断仍未确定"]
            scrollToElement(title, in: app)
            XCTAssertTrue(title.exists)
            let status = app.staticTexts[variant == "observed" ? "有结果记录 · 未达到本次验收标准" :
                (variant == "missing" ? "缺少结果证据 · 验收暂不能判断" : "记录存在冲突 · 验收暂不能判断")]
            scrollToElement(status, in: app)
            XCTAssertTrue(status.isHittable)
            XCTAssertFalse(app.staticTexts["本次成长证据"].exists)
            XCTAssertFalse(app.staticTexts["判断更新"].exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "result-review-\(variant)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let details = app.buttons["today.result-review.details"]
            scrollToElement(details, in: app)
            details.tap()
            let selfRating = app.staticTexts["你的判断自评"]
            scrollToElement(selfRating, in: app)
            XCTAssertTrue(selfRating.exists)
            XCTAssertTrue(app.staticTexts["确认判断"].exists)
            if variant == "observed" {
                let quotes = app.buttons["引用的记录"]
                scrollToElement(quotes, in: app)
                quotes.tap()
                XCTAssertTrue(app.staticTexts["“朋友仍有两个字段空着，最后退出”"].exists)
            }
            let dismiss = app.buttons["today.result-review.dismiss"]
            scrollToElement(dismiss, in: app)
            dismiss.tap()
            XCTAssertFalse(app.staticTexts[variant == "observed" ? "本次证据削弱原判断" : "原判断仍未确定"].exists)
            app.terminate()
        }
    }

    func testHistoryCaseSettlementShowsOriginalResultAndJudgmentUpdate() throws {
        let app = historyCaseSettlementApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["结果记录"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["你的判断自评 · 调整判断"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["原判断：只要会后补发结论，就能避免后续返工。"].exists)
        XCTAssertTrue(app.staticTexts["实际结果：返工追问减少，但关键参与方仍需在会前参与确认。"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.case."))
                .firstMatch
                .exists
        )
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
        app.launchArguments = ["--today-loop-ui-fixture"]
        // These regression fixtures exercise the legacy single-entry flow.
        app.launchEnvironment["MINGSI_VNEXT_CASES_ENABLED"] = "0"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_INPUT"] = input
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MODE"] = "standard"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_STAGE"] = stage
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "today"
        if missingCalibrationTarget {
            app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MISSING_CALIBRATION_TARGET"] = "1"
        }
        return app
    }

    private func seededVNextTodayApp(stage: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VNEXT_CASES_ENABLED"] = "1"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_INPUT"] = """
        事实：会议结束后没有明确负责人。
        风险：验收标准缺失会导致明天返工。
        """
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_MODE"] = "standard"
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_STAGE"] = stage
        app.launchEnvironment["MINGSI_VISUAL_QA_TODAY_ACTIVE_CASE"] = "1"
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

    private func sideQuestV2App(tab: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_SIDE_QUEST_V2"] = "1"
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = tab
        return app
    }

    private func openSettingsAdvancedTools(in app: XCUIApplication) {
        let action = app.buttons["settings.advanced-tools.action"]
        scrollToElement(action, in: app)
        action.tap()
        XCTAssertTrue(app.navigationBars["高级工具"].waitForExistence(timeout: 4))
    }

    private func openSideQuestSettings(in app: XCUIApplication) {
        let action = app.buttons["settings.side-quest.action"]
        scrollToElement(action, in: app)
        XCTAssertTrue(action.isHittable)
        action.tap()
        XCTAssertTrue(app.navigationBars["生活奇遇"].waitForExistence(timeout: 4))
    }

    private func seededGrowthApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "growth"
        return app
    }

    private func historyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_TAB"] = "history"
        return app
    }

    private func historyCaseSettlementApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINGSI_VISUAL_QA_HISTORY_CASE_SETTLEMENT"] = "1"
        return app
    }

    private func expandFirstGrowthPrincipleDetails(in app: XCUIApplication) {
        expandGrowthPrincipleDetails(at: 0, in: app)
    }

    private func expandGrowthPrincipleDetails(at index: Int, in app: XCUIApplication) {
        let detailsToggle = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", ".details-toggle")
        ).element(boundBy: index)
        scrollToElement(detailsToggle, in: app)
        detailsToggle.tap()
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        let scrollView = primaryScrollView(in: app)

        // Growth's largest accessibility layout can span more than twelve
        // viewports before its principle section. Keep the same visibility
        // requirements while allowing the full content to be traversed.
        var remainingScrolls = 32
        while (!element.exists || !isElementInTappableScrollArea(element, app: app)) && remainingScrolls > 0 {
            // SwiftUI can expose an offscreen field with an infinite, empty
            // frame. Its position cannot tell us which way to scroll.
            let beforeMidY = element.exists && element.frame.midY.isFinite ? element.frame.midY : nil
            // At accessibility sizes the fixed action bar can start above 72%
            // of the screen. Keep both ends of the gesture in visible content.
            let fixedBar = app.descendants(matching: .any)["today.fixed-action-bar"].firstMatch
            let overlayTop = fixedBar.exists ? fixedBar.frame.minY : app.frame.height
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.height
            let top = max(90, app.frame.height * 0.16)
            let bottom = max(top + 80, min(overlayTop, keyboardTop, app.frame.height * 0.82) - 14)
            let high = (top + (bottom - top) * 0.20) / app.frame.height
            let low = (top + (bottom - top) * 0.85) / app.frame.height
            let scrollDown = beforeMidY != nil ? element.frame.minY < app.frame.minY + 64 : towardTop
            if scrollDown {
                drag(scrollView, fromY: high, toY: low)
            } else {
                drag(scrollView, fromY: low, toY: high)
            }
            if let beforeMidY, element.exists, abs(element.frame.midY - beforeMidY) < 1 {
                if scrollDown {
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
            "Element frame \(element.frame) is outside readable/tappable area for app frame \(app.frame)."
        )
    }

    private func isElementInTappableScrollArea(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        let fixedBar = app.descendants(matching: .any)["today.fixed-action-bar"].firstMatch
        let bottomOverlayTop = fixedBar.exists ? fixedBar.frame.minY : app.frame.height
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.height
        let tabTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.height
        let readableBottom = min(bottomOverlayTop, keyboardTop, tabTop) - 8
        return element.frame.minY >= app.frame.minY + 64 && element.frame.maxY <= readableBottom
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
