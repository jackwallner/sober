import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1FirstCounterAndOptionalTrial() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        QA.launch(app, arguments: ["-previewStore"])
        tap("Start my counter", in: app)
        checkpoint("start-date", button: "Continue", in: app)
        tap("Continue", in: app)
        checkpoint("daily-savings", button: "Continue", in: app)
        tap("Continue", in: app)
        checkpoint("goal", button: "Continue", in: app)
        tap("Continue", in: app)
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap("Get started", in: app)
        let free = app.alerts["Keep the free version?"].buttons["Get started"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()
        checkpoint("reminders", button: "Not now", in: app)
        tap("Not now", in: app)
        home("first-counter", in: app)
    }

    func test2CravingTimelineUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore"])
        home("home", in: app)
        craving(in: app).tap()
        checkpoint("craving-session", button: "I'm through it", in: app)
        tap("I'm through it", in: app)
        checkpoint("craving-reflection", button: "It passed", in: app)
        tap("It passed", in: app)
        checkpoint("craving-logged", button: "Back to the garden", in: app)
        tap("Back to the garden", in: app)
        home("home-after-craving", in: app)

        for tab in ["Timeline", "Health", "Journal", "Upgrade"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            QA.checkpoint(app, tab.lowercased(), paywall: tab == "Upgrade")
        }
        app.tabBars.buttons["Home"].tap()
        home("home-after-upgrade", in: app)
        QA.interrupt(app)
        home("home-after-background", in: app)
        QA.relaunch(app)
        home("home-after-relaunch", in: app)
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name)
    }

    private func craving(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
    }

    private func home(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(craving(in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, name)
    }
}
