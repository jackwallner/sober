import XCTest

/// The craving session is the moment the app exists for, so both ends of its
/// save are driven for real: a session that lands says "Logged.", and one the
/// store rejects closes the session and says "Not saved" instead.
final class CravingFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += ["-seedDemo"] + extra
        app.launch()
        return app
    }

    private func rideOutACraving(in app: XCUIApplication) {
        let start = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Home never showed the craving button")
        start.tap()
        let through = app.buttons["I'm through it"]
        XCTAssertTrue(through.waitForExistence(timeout: 10))
        through.tap()
        let passed = app.buttons["It passed"]
        XCTAssertTrue(passed.waitForExistence(timeout: 10))
        passed.tap()
    }

    func testRiddenOutCravingIsLogged() {
        let app = launch()
        rideOutACraving(in: app)
        XCTAssertTrue(app.staticTexts["Logged."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Not saved"].exists)
        app.buttons["Back to the garden"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Not saved"].exists)
    }

    func testFailedSaveClosesSessionAndSaysNotSaved() {
        let app = launch(["-simulateCravingSaveFailure"])
        rideOutACraving(in: app)
        XCTAssertTrue(app.alerts["Not saved"].waitForExistence(timeout: 10), "The failure alert never appeared")
        XCTAssertFalse(app.staticTexts["Logged."].exists)
        app.alerts["Not saved"].buttons["OK"].tap()
        // Back on Home, not on a "Logged." screen celebrating a row that is not on disk.
        let start = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isHittable, "The session cover is still on screen after the failed save")
        XCTAssertFalse(app.staticTexts["Logged."].exists)
    }
}
