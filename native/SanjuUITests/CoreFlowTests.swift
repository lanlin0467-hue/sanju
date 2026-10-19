import XCTest

final class CoreFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func configuredApp(demo: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--test-library", UUID().uuidString]
        if demo { app.launchArguments.append("--demo") }
        else { app.launchArguments += ["--api-base-url", "http://127.0.0.1:3001"] }
        return app
    }
    private func prepare(_ app: XCUIApplication) {
        let scene = app.descendants(matching: .any).matching(identifier: "sceneInput").firstMatch
        XCTAssertTrue(scene.waitForExistence(timeout: 8)); scene.tap(); scene.typeText("黄昏的海边")
        app.buttons["平静"].tap()
        app.buttons["写出三句"].tap()
    }
    func testCreateSwapFavoriteAndReloadLibrary() {
        let app = configuredApp(); app.launch(); prepare(app)
        let original = "海风照常吹过，心里的热闹却已经提前散场。"
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["三句写好了，已存入句库"].waitForNonExistence(timeout: 4))
        let result = XCTAttachment(screenshot: app.screenshot()); result.name = "水彩生成结果页"; result.lifetime = .keepAlways; add(result)
        app.buttons["收藏冷峻这句"].tap()
        app.buttons["换这句"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["海浪从不解释来去，岸上的人却总要一个答案。"].waitForExistence(timeout: 8))
        app.tabBars.buttons["句库"].tap()
        let library = XCTAttachment(screenshot: app.screenshot()); library.name = "纸色句库全部创作"; library.lifetime = .keepAlways; add(library)
        app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["句库"].tap()
        app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "句库保留换句前的收藏"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testHistoryRestoreFavoriteDetailAndSearch() {
        let app = configuredApp(); app.launch()
        app.tabBars.buttons["句库"].tap()
        XCTAssertTrue(app.staticTexts["第一句，留给今天吧"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts["把喜欢的句子留下来"].waitForExistence(timeout: 3))
        app.tabBars.buttons["创作"].tap(); prepare(app)
        let original = "海风照常吹过，心里的热闹却已经提前散场。"
        let replacement = "海浪从不解释来去，岸上的人却总要一个答案。"
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        app.buttons["收藏冷峻这句"].tap()
        app.buttons["复制"].firstMatch.tap()
        XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        app.buttons["换这句"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[replacement].waitForExistence(timeout: 8))
        app.buttons["冷峻更多操作"].tap(); app.buttons["查看本次旧句"].tap()
        XCTAssertTrue(app.navigationBars["冷峻的本次版本"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["dismissSentenceHistory"].isHittable)
        app.buttons["dismissSentenceHistory"].tap()
        XCTAssertTrue(app.navigationBars["本次三句"].waitForExistence(timeout: 4))
        app.buttons["冷峻更多操作"].tap(); app.buttons["查看本次旧句"].tap()
        XCTAssertTrue(app.navigationBars["冷峻的本次版本"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[original].exists)
        let history = XCTAttachment(screenshot: app.screenshot()); history.name = "本次旧句与恢复入口"; history.lifetime = .keepAlways; add(history)
        app.buttons["用这一句"].tap()
        XCTAssertTrue(app.navigationBars["本次三句"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[original].exists)
        XCTAssertTrue(app.staticTexts["还可换 2 句"].exists)
        app.tabBars.buttons["句库"].tap()
        app.segmentedControls.buttons["全部"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 4)); search.tap(); search.typeText("散场")
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 3))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "不存在的内容")
        XCTAssertTrue(app.staticTexts["没有找到相关句子"].waitForExistence(timeout: 3))
        app.buttons["清空搜索"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["收藏"].tap()
        app.staticTexts[original].tap()
        XCTAssertTrue(app.navigationBars["收藏的句子"].waitForExistence(timeout: 4))
        app.buttons["复制"].tap()
        XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        let favorite = XCTAttachment(screenshot: app.screenshot()); favorite.name = "收藏详情与复制分享"; favorite.lifetime = .keepAlways; add(favorite)
        app.buttons["查看本次三句"].tap()
        XCTAssertTrue(app.navigationBars["本次三句"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[original].exists)
    }
    func testReadingWithLargeText() {
        let app = configuredApp()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let scene = app.descendants(matching: .any).matching(identifier: "sceneInput").firstMatch
        XCTAssertTrue(scene.waitForExistence(timeout: 8)); scene.tap(); scene.typeText("海边的晚风")
        app.buttons["填写心情"].tap(); app.textFields["moodInput"].typeText("平静")
        app.buttons["dismissCreationKeyboard"].tap(); app.buttons["写出三句"].tap()
        let original = "海风照常吹过，心里的热闹却已经提前散场。"
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 8))
        app.buttons["收藏冷峻这句"].tap()
        app.buttons["复制"].firstMatch.tap()
        XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        let result = XCTAttachment(screenshot: app.screenshot()); result.name = "结果页最大辅助字号操作"; result.lifetime = .keepAlways; add(result)
        app.tabBars.buttons["句库"].tap(); app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5)); app.staticTexts[original].tap()
        XCTAssertTrue(app.navigationBars["收藏的句子"].waitForExistence(timeout: 4))
        app.buttons["复制"].tap()
        XCTAssertTrue(app.buttons["已复制"].waitForExistence(timeout: 2))
        let favorite = XCTAttachment(screenshot: app.screenshot()); favorite.name = "收藏详情最大辅助字号操作"; favorite.lifetime = .keepAlways; add(favorite)
    }
    func testCreationCustomMoodDraftAndValidation() {
        let app = configuredApp(); app.launch()
        let write = app.buttons["写出三句"]
        XCTAssertTrue(write.waitForExistence(timeout: 8)); XCTAssertFalse(write.isEnabled)
        let initial = XCTAttachment(screenshot: app.screenshot()); initial.name = "水彩创作页首屏"; initial.lifetime = .keepAlways; add(initial)
        app.buttons["writeWithoutPhoto"].tap()
        let scene = app.descendants(matching: .any).matching(identifier: "sceneInput").firstMatch
        scene.typeText("雨后的窗台，还有一点光")
        app.buttons["填写心情"].tap()
        let mood = app.textFields["moodInput"]
        XCTAssertTrue(mood.waitForExistence(timeout: 3)); mood.typeText("安静地期待")
        app.buttons["dismissCreationKeyboard"].tap()
        XCTAssertTrue(write.isEnabled)
        let composed = XCTAttachment(screenshot: app.screenshot()); composed.name = "自定义心情与输入布局"; composed.lifetime = .keepAlways; add(composed)
        app.terminate(); app.launch()
        XCTAssertTrue(scene.waitForExistence(timeout: 8))
        XCTAssertEqual(scene.value as? String, "雨后的窗台，还有一点光")
        XCTAssertEqual(mood.value as? String, "安静地期待")
        app.buttons["清空画面描述"].tap()
        XCTAssertFalse(write.isEnabled)
        scene.typeText("黄昏的海边")
        app.buttons["填写心情"].tap()
        app.buttons["清空心情"].tap()
        XCTAssertFalse(write.isEnabled)
        mood.typeText("平静")
        app.buttons["dismissCreationKeyboard"].tap()
        XCTAssertTrue(write.isEnabled)
    }
    func testPhotoPickerSelectionAndRemoval() {
        let app = configuredApp(); app.launch()
        XCTAssertTrue(app.buttons["添加一张照片"].waitForExistence(timeout: 8))
        app.buttons["添加一张照片"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label == 'Cancel' OR label == '取消'")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        let picker = XCTAttachment(screenshot: app.screenshot()); picker.name = "一键进入系统相册"; picker.lifetime = .keepAlways; add(picker)
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo,' OR label BEGINSWITH '照片'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5)); photo.tap()
        let remove = app.buttons["移除照片"]
        XCTAssertTrue(remove.waitForExistence(timeout: 10))
        let selected = XCTAttachment(screenshot: app.screenshot()); selected.name = "已选照片与更换移除入口"; selected.lifetime = .keepAlways; add(selected)
        XCTAssertTrue(app.buttons["更换照片"].exists)
        remove.tap()
        XCTAssertTrue(app.buttons["添加一张照片"].waitForExistence(timeout: 3))
        app.buttons["添加一张照片"].tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        XCTAssertTrue(app.buttons["添加一张照片"].waitForExistence(timeout: 3))
    }
    func testCreationWithLargeText() {
        let app = configuredApp()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let scene = app.descendants(matching: .any).matching(identifier: "sceneInput").firstMatch
        XCTAssertTrue(scene.waitForExistence(timeout: 8))
        scene.tap(); scene.typeText("海边的晚风")
        app.buttons["填写心情"].tap()
        let mood = app.textFields["moodInput"]
        mood.typeText("期待")
        let keyboard = XCTAttachment(screenshot: app.screenshot()); keyboard.name = "最大辅助字号与键盘输入"; keyboard.lifetime = .keepAlways; add(keyboard)
        app.buttons["dismissCreationKeyboard"].tap()
        XCTAssertTrue(app.buttons["写出三句"].isEnabled)
    }
    func testInvitationGenerationAndKeychainSurviveRelaunch() {
        let app = configuredApp(demo: false)
        app.launchArguments = ["--test-library", UUID().uuidString, "--api-base-url", "http://127.0.0.1:3002", "--require-invitation"]
        app.launch()
        XCTAssertTrue(app.buttons["输入邀请码，开始内测"].waitForExistence(timeout: 8))
        app.buttons["输入邀请码，开始内测"].tap()
        let invite = app.secureTextFields["betaInviteInput"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5)); invite.tap(); invite.typeText("sanju-uitest-invite-for-local-only")
        app.buttons["加入内测"].tap()
        XCTAssertTrue(app.buttons["写出三句"].waitForExistence(timeout: 8))
        prepare(app)
        XCTAssertTrue(app.buttons["同意并继续"].waitForExistence(timeout: 5)); app.buttons["同意并继续"].tap()
        let original = "海风照常吹过，心里的热闹却已经提前散场。"
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 10))
        app.buttons["收藏冷峻这句"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["写出三句"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["输入邀请码，开始内测"].exists)
        app.tabBars.buttons["句库"].tap(); app.segmentedControls.buttons["收藏"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "邀请码与钥匙串重启恢复"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testCoreFlowThroughLocalAPI() {
        let app = configuredApp(demo: false); app.launch(); prepare(app)
        XCTAssertTrue(app.buttons["同意并继续"].waitForExistence(timeout: 5)); app.buttons["同意并继续"].tap()
        XCTAssertTrue(app.staticTexts["海风照常吹过，心里的热闹却已经提前散场。"].waitForExistence(timeout: 15))
        app.buttons["换这句"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["海浪从不解释来去，岸上的人却总要一个答案。"].waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "SwiftUI新接口联调结果"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
