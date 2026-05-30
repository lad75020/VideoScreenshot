import XCTest

final class CaptureControlsUITests: XCTestCase {
    func testMainControlsExist() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        let hasMainWindow = app.windows.firstMatch.waitForExistence(timeout: 5) || app.staticTexts["VideoScreenshot"].waitForExistence(timeout: 5)
        XCTAssertTrue(hasMainWindow)
    }
}
