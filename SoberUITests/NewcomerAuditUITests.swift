import XCTest

/// First-run walkthrough for the newcomer persona audit: fresh install through
/// onboarding, Home, each tab and one craving session. Observation only, so
/// misses are logged to an attachment rather than failing the run.
final class NewcomerAuditUITests: XCTestCase {
    private var notes: [String] = []

    override func setUp() {
        continueAfterFailure = true
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func labels(_ app: XCUIApplication) -> String {
        let buttons = app.buttons.allElementsBoundByIndex.map { "B[\($0.label)] \($0.frame.integral) hit=\($0.isHittable)" }
        let texts = app.staticTexts.allElementsBoundByIndex.map { "T[\($0.label)]" }
        return (buttons + texts).joined(separator: "\n")
    }

    private func step(_ app: XCUIApplication, _ name: String, tap title: String? = nil) {
        sleep(1)
        keep(app, name)
        notes.append("== \(name)\n\(labels(app))")
        guard let title else { return }
        let b = app.buttons[title]
        if b.waitForExistence(timeout: 5) { b.tap() } else { notes.append("MISSING button \(title)") }
    }

    func testNewcomerFirstRun() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += ["-previewStore"]
        app.launch()
        _ = app.buttons["Start my counter"].waitForExistence(timeout: 30)
        step(app, "01-promise", tap: "Start my counter")
        step(app, "02-start-date", tap: "Continue")
        step(app, "03-savings", tap: "Continue")
        step(app, "04-goal", tap: "Continue")
        step(app, "05-trial")
        let free = app.buttons["Get started"]
        if free.waitForExistence(timeout: 5) { notes.append("trial-exit frame \(free.frame) hittable=\(free.isHittable)"); free.tap() }
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) { keep(app, "05c-alert"); alert.buttons["Get started"].tap() }
        step(app, "06-reminders")
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 5) { notNow.tap() }
        if app.alerts.firstMatch.waitForExistence(timeout: 2) { keep(app, "06b-system-alert"); app.alerts.firstMatch.buttons.element(boundBy: 0).tap() }
        sleep(3)
        step(app, "07-home")
        for tab in ["Timeline", "Health", "Journal"] {
            let t = app.buttons[tab].firstMatch
            if t.exists { t.tap(); step(app, "08-tab-\(tab)") } else { notes.append("MISSING tab \(tab)") }
        }
        if app.buttons["Home"].exists { app.buttons["Home"].firstMatch.tap() }
        sleep(1)
        let craving = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        if craving.waitForExistence(timeout: 5) {
            craving.tap()
            step(app, "09-craving-start")
            sleep(6)
            keep(app, "10-craving-breathing")
            if app.buttons["I'm through it"].exists { app.buttons["I'm through it"].tap() }
            step(app, "11-craving-exit")
        }
        let dump = XCTAttachment(string: notes.joined(separator: "\n\n"))
        dump.name = "notes"
        dump.lifetime = .keepAlways
        add(dump)
    }
}
