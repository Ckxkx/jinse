import XCTest
final class TimelineUITests:XCTestCase {
    func testAddFromEmptyTimeline(){
        let app=XCUIApplication();app.launchArguments=["--ui-test"];app.launch()
        app.buttons["collection.all"].tap()
        app.buttons["写下第一条记录"].tap()
        app.textFields["小标题"].tap();app.textFields["小标题"].typeText("Weekend walk")
        app.buttons["暂时挂起"].tap();app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["Weekend walk"].waitForExistence(timeout:10))
        app.buttons["Weekend walk"].tap();XCTAssertTrue(app.buttons["编辑"].exists)
    }
}

extension TimelineUITests {
    func testLargeTextDarkTimeline(){
        let app=XCUIApplication()
        app.launchArguments=["--ui-test","--preview-data","-AppleInterfaceStyle","Dark","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXL"]
        app.launchArguments += ["--compact-preview"]
        app.launch()
        let homeShot=XCTAttachment(screenshot:app.screenshot());homeShot.name="暗色卡片首页";homeShot.lifetime = .keepAlways;add(homeShot)
        app.buttons["collection.all"].tap()
        let first=app.buttons["趁潮水退去之前，把环岛路最后一段也走完"]
        XCTAssertTrue(first.waitForExistence(timeout:20))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="紧凑宽度 · 深色 · 辅助字号";shot.lifetime = .keepAlways;add(shot)
        first.tap()
        XCTAssertTrue(app.buttons["返回"].exists)
    }
}

extension TimelineUITests {
    func testDirectorySearchAndAppearance(){
        let app=XCUIApplication()
        app.launchArguments=["--ui-test","--preview-data","-AppleInterfaceStyle","Light"]
        app.launch()
        let search=app.textFields["搜索"]
        search.tap()
        search.typeText("xyzzy")
        XCTAssertTrue(app.staticTexts["没有匹配的时间线"].waitForExistence(timeout:5))
        app.buttons["清除搜索"].tap()
        app.buttons["个人设置"].tap()
        app.buttons["深色"].tap()
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["collection.all"].waitForExistence(timeout:5))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.lifetime = .keepAlways;shot.name="深色首页";add(shot)
    }
}
