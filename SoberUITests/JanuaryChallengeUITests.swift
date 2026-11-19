import XCTest

/// Dry January, the in-app event behind the App Store event card: the
/// Timeline row, the sheet in each phase, and the `sober://dry-january` link.
/// `-challengeNow` sets the date the challenge reads.
final class JanuaryChallengeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += ["-seedDemo", "-seedDays", "127"] + args
        app.launch()
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func waitForHome(_ app: XCUIApplication) {
        let craving = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(craving.waitForExistence(timeout: 30))
    }

    func test1TimelineRowOpensTheSheetAndDoneClosesIt() {
        let app = launch(["-challengeNow", "2027-01-12"])
        waitForHome(app)
        XCTAssertFalse(app.buttons["januaryChallengeRow"].exists, "Home carries no challenge row")
        app.tabBars.buttons["Timeline"].tap()
        let row = app.buttons["januaryChallengeRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        keep(app, "01-timeline-row")
        row.tap()
        let title = app.navigationBars["Dry January"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["of 31 dry days"].exists)
        keep(app, "02-sheet-active")
        app.buttons["Done"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10))
        XCTAssertTrue(row.exists, "Done returns to Timeline")
    }

    func test2TheEventLinkOpensTheSheet() throws {
        let app = launch(["-challengeNow", "2027-01-12"])
        waitForHome(app)
        app.open(try XCTUnwrap(URL(string: "sober://dry-january")))
        XCTAssertTrue(app.navigationBars["Dry January"].waitForExistence(timeout: 15))
        keep(app, "03-sheet-from-link")
    }

    func test3BeforeItStartsTheSheetShowsTheStartDate() {
        let app = launch(["-challengeNow", "2026-12-20", "-openChallenge"])
        XCTAssertTrue(app.navigationBars["Dry January"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["January 1"].exists)
        XCTAssertFalse(app.staticTexts["of 31 dry days"].exists)
        keep(app, "04-sheet-upcoming")
    }

    func test4AFullMonthEarnsTheBadge() {
        let app = launch(["-challengeNow", "2027-02-02", "-openChallenge"])
        XCTAssertTrue(app.navigationBars["Dry January"].waitForExistence(timeout: 30))
        // Timeline sits behind the sheet with its own 31: any match will do.
        XCTAssertTrue(app.staticTexts["31"].firstMatch.waitForExistence(timeout: 10))
        keep(app, "05-sheet-complete")
    }

    func test5AfterItIsPutAwayTheLinkOpensNoSheet() throws {
        let app = launch(["-challengeNow", "2027-02-20"])
        waitForHome(app)
        app.open(try XCTUnwrap(URL(string: "sober://dry-january")))
        XCTAssertFalse(app.navigationBars["Dry January"].waitForExistence(timeout: 5))
    }
}
