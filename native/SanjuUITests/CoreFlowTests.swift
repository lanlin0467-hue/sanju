import XCTest

final class CoreFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private let original = "海风照常吹过，心里的热闹却已经提前散场。"
    private let replacement = "海浪从不解释来去，岸上的人却总要一个答案。"
    private func configuredApp(demo: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--test-library", UUID().uuidString]
        if demo { app.launchArguments.append("--demo") }
        else { app.launchArguments += ["--api-base-url", "http://127.0.0.1:3001"] }
        return app
    }
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func prepare(_ app: XCUIApplication) {
        let scene = app.textFields["sceneInput"].exists ? app.textFields["sceneInput"] : app.textViews["sceneInput"]
        XCTAssertTrue(scene.waitForExistence(timeout: 8)); scene.tap(); scene.typeText("黄昏的海边")
        app.buttons["dismissCreationKeyboard"].tap()
        app.buttons["平静"].tap()
        app.buttons["generateSentences"].tap()
    }
    func testCreateSwapFavoriteAndReloadLibrary() {
        let app = configuredApp(); app.launch(); prepare(app)
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["三句写好了，已存入句库"].waitForNonExistence(timeout: 4))
        snapshot(app, "极简版生成结果")
        app.buttons["收藏冷峻这句"].tap()
        app.buttons["swap_cool"].tap()
        XCTAssertTrue(app.staticTexts[replacement].waitForExistence(timeout: 8))
        app.tabBars.buttons["句库"].tap()
        snapshot(app, "极简版日期分组句库")
        app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["句库"].tap(); app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
    }
    func testHistoryRestoreFavoriteDetailAndSearch() {
        let app = configuredApp(); app.launch()
        app.tabBars.buttons["句库"].tap()
        XCTAssertTrue(app.staticTexts["还没有句子"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        app.buttons["开始创作"].tap(); prepare(app)
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        app.buttons["收藏冷峻这句"].tap()
        app.buttons["复制"].firstMatch.tap()
        XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        app.buttons["swap_cool"].tap()
        XCTAssertTrue(app.staticTexts[replacement].waitForExistence(timeout: 8))
        app.buttons["sentenceHistory"].tap()
        XCTAssertTrue(app.navigationBars["旧句"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[original].exists)
        snapshot(app, "按文风分组的旧句与收藏")
        app.buttons["restore_cool"].tap()
        XCTAssertTrue(app.staticTexts["当前"].exists)
        app.buttons["dismissSentenceHistory"].tap()
        XCTAssertTrue(app.navigationBars["三句"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[original].exists)
        XCTAssertTrue(app.staticTexts["可换 2 次 · 24 小时内有效"].exists)
        app.tabBars.buttons["句库"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 4)); search.tap(); search.typeText("散场")
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 3))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "不存在的内容")
        XCTAssertTrue(app.buttons["清空搜索"].waitForExistence(timeout: 3)); app.buttons["清空搜索"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label == 'Cancel' OR label == '取消'")).firstMatch
        if cancel.exists { cancel.tap() }
        app.segmentedControls.buttons["收藏"].tap()
        app.staticTexts[original].tap()
        XCTAssertTrue(app.navigationBars["句子详情"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.tabBars.buttons["创作"].isHittable)
        app.buttons["复制"].tap(); XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        snapshot(app, "句子详情与本次三句")
        app.swipeUp()
        app.buttons["detail_romantic"].tap()
        XCTAssertTrue(app.buttons["detail_romantic"].label.contains("正在查看"))
        app.buttons["详情更多操作"].tap(); app.buttons["删除创作"].tap()
        XCTAssertTrue(app.alerts["删除这次创作？"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS '1 句旧句' AND label CONTAINS '1 条收藏'")).firstMatch.exists)
        app.alerts.buttons["取消"].tap()
        app.buttons["详情更多操作"].tap(); app.buttons["删除创作"].tap(); app.alerts.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["还没有句子"].waitForExistence(timeout: 5))
    }
    func testCreationCustomMoodDraftAndValidation() {
        let app = configuredApp(); app.launch()
        let generate = app.buttons["generateSentences"]
        XCTAssertTrue(generate.waitForExistence(timeout: 8)); XCTAssertFalse(generate.isEnabled)
        XCTAssertEqual(generate.label, "添加照片或描述画面")
        snapshot(app, "极简版空白创作页")
        let scene = app.textFields["sceneInput"]
        scene.tap(); scene.typeText("雨后的窗台，还有一点光")
        app.buttons["dismissCreationKeyboard"].tap()
        XCTAssertEqual(generate.label, "选择心情后生成")
        app.buttons["customMood"].tap()
        XCTAssertTrue(app.alerts.textFields.firstMatch.waitForExistence(timeout: 3))
        app.alerts.textFields.firstMatch.tap(); app.alerts.textFields.firstMatch.typeText("安静地期待")
        // Commit text with the system keyboard Done action before closing the alert.
        app.alerts.textFields.firstMatch.typeText("\n")
        XCTAssertTrue(app.alerts["自定义心情"].waitForNonExistence(timeout: 8))
        snapshot(app, "自定义心情确认后")
        XCTAssertTrue(generate.isEnabled, app.debugDescription)
        XCTAssertTrue(app.buttons["安静地期待"].isSelected)
        snapshot(app, "自定义心情与草稿")
        app.terminate(); app.launch()
        XCTAssertTrue(scene.waitForExistence(timeout: 8))
        XCTAssertEqual(scene.value as? String, "雨后的窗台，还有一点光")
        XCTAssertTrue(app.buttons["安静地期待"].isSelected)
        XCTAssertTrue(app.buttons["忽略草稿"].exists)
        app.buttons["忽略草稿"].tap()
        XCTAssertFalse(generate.isEnabled)
        app.buttons["平静"].tap(); XCTAssertTrue(app.buttons["平静"].isSelected)
        app.buttons["平静"].tap(); XCTAssertFalse(app.buttons["平静"].isSelected)
    }
    func testPhotoPickerSelectionAndRemoval() {
        let app = configuredApp(); app.launch()
        XCTAssertTrue(app.buttons["choosePhoto"].waitForExistence(timeout: 8)); app.buttons["choosePhoto"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label == 'Cancel' OR label == '取消'")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo,' OR label BEGINSWITH '照片,'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5)); photo.tap()
        let remove = app.buttons["移除照片"]
        XCTAssertTrue(remove.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["更换照片"].exists)
        snapshot(app, "极简版所选照片")
        remove.tap(); XCTAssertTrue(app.buttons["choosePhoto"].waitForExistence(timeout: 3))
        app.buttons["choosePhoto"].tap(); XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        XCTAssertTrue(app.buttons["choosePhoto"].waitForExistence(timeout: 3))
    }
    func testInputLimits() {
        let app = configuredApp(); app.launch()
        let scene = app.textFields["sceneInput"]
        XCTAssertTrue(scene.waitForExistence(timeout: 8)); scene.tap(); scene.typeText(String(repeating: "a", count: 201))
        XCTAssertEqual((scene.value as? String)?.count, 200)
        app.buttons["dismissCreationKeyboard"].tap()
        app.buttons["customMood"].tap()
        let mood = app.alerts.textFields.firstMatch
        XCTAssertTrue(mood.waitForExistence(timeout: 4)); mood.tap(); mood.typeText(String(repeating: "b", count: 31))
        XCTAssertEqual((mood.value as? String)?.count, 30)
        // Commit text with the system keyboard Done action before closing the alert.
        app.alerts.textFields.firstMatch.typeText("\n")
        XCTAssertTrue(app.alerts["自定义心情"].waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.buttons[String(repeating: "b", count: 30)].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["generateSentences"].isEnabled)
    }
    func testReadingWithLargeText() {
        let app = configuredApp()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let scene = app.textFields["sceneInput"]
        XCTAssertTrue(scene.waitForExistence(timeout: 8)); scene.tap(); scene.typeText("海边的晚风")
        app.buttons["dismissCreationKeyboard"].tap()
        app.swipeUp(); app.buttons["平静"].tap()
        XCTAssertTrue(app.buttons["generateSentences"].isEnabled)
        snapshot(app, "最大辅助字号创作页")
        app.buttons["generateSentences"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        app.buttons["收藏冷峻这句"].tap()
        app.swipeUp(); app.buttons["复制"].firstMatch.tap()
        XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        snapshot(app, "最大辅助字号结果页")
        app.tabBars.buttons["句库"].tap(); app.segmentedControls.buttons["收藏"].tap()
        app.staticTexts[original].tap()
        XCTAssertTrue(app.navigationBars["句子详情"].waitForExistence(timeout: 4))
        app.swipeUp(); app.buttons["复制"].tap()
        snapshot(app, "最大辅助字号句子详情")
    }
    func testInterruptedCreationAppearsInLibraryAndRecoversOriginalResult() {
        let app = configuredApp(); app.launchArguments += ["--test-scenario", "interrupted"]
        app.launch(); prepare(app)
        XCTAssertTrue(app.staticTexts["网络中断，结果待确认"].waitForExistence(timeout: 8))
        snapshot(app, "网络中断待确认")
        app.buttons["稍后在句库查看"].tap()
        XCTAssertTrue(app.buttons["pendingLibraryRecord"].waitForExistence(timeout: 4))
        snapshot(app, "句库中的待确认请求")
        app.buttons["pendingLibraryRecord"].tap()
        app.buttons["找回结果"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        app.tabBars.buttons["句库"].tap()
        XCTAssertFalse(app.buttons["pendingLibraryRecord"].exists)
        app.tabBars.buttons["创作"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["今日剩余 4 次，共 5 次"].exists)
    }
    func testFailureKeepsInputAndSwapRetryKeepsFavorite() {
        let app = configuredApp(); app.launchArguments += ["--test-scenario", "failure"]
        app.launch(); prepare(app)
        XCTAssertTrue(app.staticTexts["这次没有写好"].waitForExistence(timeout: 8))
        snapshot(app, "明确失败与重试入口")
        app.buttons["返回修改"].tap()
        XCTAssertEqual(app.textFields["sceneInput"].value as? String, "黄昏的海边")
        XCTAssertTrue(app.buttons["今日剩余 5 次，共 5 次"].exists)
        app.terminate()
        let swap = configuredApp(); swap.launchArguments += ["--test-scenario", "swapFailure"]
        swap.launch(); prepare(swap)
        XCTAssertTrue(swap.staticTexts[original].waitForExistence(timeout: 8))
        swap.buttons["收藏冷峻这句"].tap(); swap.buttons["swap_cool"].tap()
        XCTAssertTrue(swap.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '没换成，原句已保留'")).firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(swap.staticTexts[original].exists)
        XCTAssertTrue(swap.staticTexts["可换 3 次 · 24 小时内有效"].exists)
        snapshot(swap, "换句失败与原句保留")
        swap.buttons["swap_cool"].tap()
        XCTAssertTrue(swap.staticTexts[replacement].waitForExistence(timeout: 8))
        swap.tabBars.buttons["句库"].tap(); swap.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(swap.staticTexts[original].waitForExistence(timeout: 4))
    }
    func testNativeDarkMode() {
        let app = configuredApp(); app.launchArguments += ["--test-appearance", "dark"]
        app.launch(); XCTAssertTrue(app.buttons["generateSentences"].waitForExistence(timeout: 8)); snapshot(app, "深色创作页"); prepare(app)
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        snapshot(app, "深色三句结果")
        app.buttons["收藏冷峻这句"].tap(); app.tabBars.buttons["句库"].tap()
        snapshot(app, "深色句库")
        app.staticTexts[original].tap()
        XCTAssertTrue(app.navigationBars["句子详情"].waitForExistence(timeout: 4))
        snapshot(app, "深色句子详情")
    }
    func testInvitationGenerationAndKeychainSurviveRelaunch() {
        let app = configuredApp(demo: false)
        app.launchArguments = ["--test-library", UUID().uuidString, "--api-base-url", "http://127.0.0.1:3002", "--require-invitation"]
        app.launch()
        XCTAssertTrue(app.buttons["输入邀请码，开始内测"].waitForExistence(timeout: 8)); app.buttons["输入邀请码，开始内测"].tap()
        let invite = app.secureTextFields["betaInviteInput"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5)); invite.tap(); invite.typeText("sanju-uitest-invite-for-local-only")
        app.buttons["加入内测"].tap()
        XCTAssertTrue(app.buttons["generateSentences"].waitForExistence(timeout: 8))
        prepare(app)
        XCTAssertTrue(app.buttons["同意并生成"].waitForExistence(timeout: 5)); snapshot(app, "数据用途说明"); app.buttons["同意并生成"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 10))
        app.buttons["收藏冷峻这句"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["generateSentences"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["输入邀请码，开始内测"].exists)
        app.tabBars.buttons["句库"].tap(); app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
    }
    func testCoreFlowThroughLocalAPI() {
        let app = configuredApp(demo: false); app.launch(); prepare(app)
        XCTAssertTrue(app.buttons["同意并生成"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["阅读完整隐私说明"].tap()
        XCTAssertTrue(app.navigationBars["隐私说明"].waitForExistence(timeout: 4))
        app.navigationBars["隐私说明"].buttons.element(boundBy: 0).tap()
        app.buttons["暂不"].tap()
        XCTAssertEqual(app.textFields["sceneInput"].value as? String, "黄昏的海边")
        app.buttons["generateSentences"].tap()
        XCTAssertTrue(app.buttons["同意并生成"].waitForExistence(timeout: 4)); app.buttons["同意并生成"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 15))
        app.buttons["swap_cool"].tap()
        XCTAssertTrue(app.staticTexts[replacement].waitForExistence(timeout: 15))
    }
}
