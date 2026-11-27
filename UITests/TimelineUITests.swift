import XCTest
final class TimelineUITests: XCTestCase {
    func testAddFromHome() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test"]
        app.launch()
        app.buttons["添加记录"].firstMatch.tap()
        let title = app.textFields["标题"]
        title.tap()
        title.typeText("Weekend walk")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@", "Weekend walk")).firstMatch.waitForExistence(timeout:8))
        XCTAssertFalse(title.exists)
    }
}
