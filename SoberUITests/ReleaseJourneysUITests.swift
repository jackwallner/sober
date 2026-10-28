import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1FirstCounterAndOptionalTrial() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        QA.launch(app, arguments: ["-previewStore"])
        tap(L("Start my counter"), in: app)
        checkpoint("start-date", button: L("Continue"), in: app)
        tap(L("Continue"), in: app)
        checkpoint("daily-savings", button: L("Continue"), in: app)
        tap(L("Continue"), in: app)
        checkpoint("goal", button: L("Continue"), in: app)
        tap(L("Continue"), in: app)
        XCTAssertTrue(app.buttons[L("Get started")].waitForExistence(timeout: 20))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap(L("Get started"), in: app)
        let free = app.alerts[L("Keep the free version?")].buttons[L("Get started")]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()
        checkpoint("reminders", button: L("Not now"), in: app)
        tap(L("Not now"), in: app)
        home("first-counter", in: app)
    }

    func test2CravingTimelineUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore"])
        home("home", in: app)
        craving(in: app).tap()
        checkpoint("craving-session", button: L("I'm through it"), in: app)
        tap(L("I'm through it"), in: app)
        checkpoint("craving-reflection", button: L("It passed"), in: app)
        tap(L("It passed"), in: app)
        checkpoint("craving-logged", button: L("Back to the garden"), in: app)
        tap(L("Back to the garden"), in: app)
        home("home-after-craving", in: app)

        for tab in ["Timeline", "Health", "Journal", "Upgrade"] {
            let button = tabButton(tab, in: app)
            // The unfolded Duo shows Timeline as a pane beside the tabs, not in the bar.
            if tab == "Timeline", tabButton("Health", in: app).waitForExistence(timeout: 10), !button.exists { continue }
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            QA.checkpoint(app, tab.lowercased(), paywall: tab == "Upgrade")
        }
        tabButton("Home", in: app).tap()
        home("home-after-upgrade", in: app)
        QA.interrupt(app)
        home("home-after-background", in: app)
        QA.relaunch(app)
        home("home-after-relaunch", in: app)
    }

    func testCoreLoopCheckInIsLoggedAndSurvivesRelaunch() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore"])
        home("home-before-check-in", in: app)
        XCTAssertFalse(app.staticTexts[L("Today is logged")].exists)

        let checkIn = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", L("Check in for today"))).firstMatch
        XCTAssertTrue(checkIn.waitForExistence(timeout: 15))
        checkIn.tap()
        XCTAssertTrue(app.navigationBars[L("Checked in")].waitForExistence(timeout: 10))
        QA.checkpoint(app, "check-in-sheet")

        app.buttons["checkin.mood.4"].tap()
        let note = app.textFields[L("Anything you want to remember about today?")]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Journey note")
        QA.checkpoint(app, "check-in-filled")
        app.buttons[L("Save")].tap()

        XCTAssertTrue(app.staticTexts[L("Today is logged")].waitForExistence(timeout: 10))
        XCTAssertFalse(checkIn.exists)
        XCTAssertFalse(app.alerts[L("Not saved")].exists)
        QA.checkpoint(app, "check-in-logged")

        QA.relaunch(app)
        home("home-after-relaunch", in: app)
        XCTAssertTrue(app.staticTexts[L("Today is logged")].waitForExistence(timeout: 10))
        XCTAssertFalse(checkIn.exists)
        QA.checkpoint(app, "check-in-persisted")
    }

    /// The German strings the journeys look for; other personas see the English source.
    private static let german = [
        "Start my counter": "Zähler starten", "Continue": "Weiter", "Get started": "Los geht's",
        "Keep the free version?": "Kostenlose Version behalten?", "Not now": "Nicht jetzt",
        "I'm through it": "Ich hab's geschafft", "It passed": "Es ist vorbei",
        "Back to the garden": "Zurück zum Garten", "Timeline": "Verlauf", "Health": "Gesundheit",
        "Journal": "Tagebuch", "Home": "Start", "I'm having a": "Ich spüre Verlangen",
        "Check in for today": "Heute einchecken", "Today is logged": "Heute eingetragen",
        "Checked in": "Eingecheckt", "Good": "Gut", "Save": "Speichern", "Not saved": "Nicht gespeichert",
        "Anything you want to remember about today?": "Möchtest du dir etwas von heute merken?",
    ]

    private func L(_ english: String) -> String {
        QA.persona == "german" ? Self.german[english] ?? english : english
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
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", L("I'm having a"))).firstMatch
    }

    /// The tab bar's button; the unfolded Duo draws the tabs as a rail that is not a tab bar.
    private func tabButton(_ tab: String, in app: XCUIApplication) -> XCUIElement {
        let inBar = app.tabBars.buttons[L(tab)]
        return inBar.exists ? inBar : app.buttons.matching(NSPredicate(format: "label == %@", L(tab))).firstMatch
    }

    private func home(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(craving(in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, name)
    }
}
