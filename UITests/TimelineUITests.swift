import XCTest
final class TimelineUITests:XCTestCase {
    func testAddFromEmptyTimeline(){
        let app=XCUIApplication();app.launchArguments=["--ui-test"];app.launch()
        app.buttons["写下第一条记录"].tap()
        app.textFields["小标题"].tap();app.textFields["小标题"].typeText("Weekend walk")
        app.buttons["暂时挂起"].tap();app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["Weekend walk"].waitForExistence(timeout:10))
        app.buttons["Weekend walk"].tap();XCTAssertTrue(app.buttons["编辑"].exists)
    }
}
