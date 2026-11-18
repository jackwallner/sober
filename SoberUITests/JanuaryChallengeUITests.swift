import XCTest

/// Dry January, the in-app event behind the App Store event card: the Home
/// card, the sheet in each phase, and the `sober://dry-january` link.
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

    func test1CardOpensTheSheetAndDoneClosesIt() {
        let app = launch(["-challengeNow", "2027-01-12"])
        waitForHome(app)
        // Start on the garden: the swipe has to scroll Home, not pan the tree.
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        let card = app.buttons["januaryChallengeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        keep(app, "01-home-card")
        card.tap()
        let title = app.navigationBars["Dry January"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["of 31 dry days"].exists)
        keep(app, "02-sheet-active")
        app.buttons["Done"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10))
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
        XCTAssertTrue(app.staticTexts["31"].waitForExistence(timeout: 10))
        keep(app, "05-sheet-complete")
    }

    func test5AfterItIsPutAwayTheLinkOpensHomeOnly() throws {
        let app = launch(["-challengeNow", "2027-02-20"])
        waitForHome(app)
        app.open(try XCTUnwrap(URL(string: "sober://dry-january")))
        XCTAssertFalse(app.navigationBars["Dry January"].waitForExistence(timeout: 5))
    }
}
