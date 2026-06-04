import XCTest

@MainActor
final class __APP_NAME__UITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() async throws {
        app = nil
    }

    /// Sample UI test — replace with your own scenarios.
    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
