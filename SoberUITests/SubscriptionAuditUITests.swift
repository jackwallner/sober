import XCTest

/// Persona audit walk: a skeptical free user finds what is paid, tries the
/// locked doors, looks for Restore and for a way to cancel, and backs out.
/// Screenshots are kept as attachments; the run is screen-recorded.
final class SubscriptionAuditUITests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func note(_ text: String) {
        print("AUDIT \(text)")
        let a = XCTAttachment(string: text)
        a.name = "note"
        a.lifetime = .keepAlways
        add(a)
    }

    private func closePitch(_ app: XCUIApplication) -> Bool {
        for label in ["Not now", "Close", "Maybe later"] {
            let b = app.buttons[label]
            if b.waitForExistence(timeout: 2) { b.tap(); return true }
        }
        return false
    }

    func testFreeUserWalk() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += ["-seedDemo", "-seedDays", "10", "-previewStore"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Health"].waitForExistence(timeout: 30))
        sleep(1)
        keep(app, "a01-home")

        // Health: locked rows
        app.tabBars.buttons["Health"].tap()
        sleep(1)
        keep(app, "a02-health")
        let unlockRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Bloom+")).firstMatch
        if unlockRow.waitForExistence(timeout: 3) {
            unlockRow.tap()
            sleep(2)
            keep(app, "a03-health-pitch")
            note("health pitch closed=\(closePitch(app))")
            sleep(1)
            keep(app, "a04-after-health-pitch")
        } else { note("no Bloom+ row in health") }

        // Journal: pencil
        app.tabBars.buttons["Journal"].tap()
        sleep(3)
        keep(app, "a05-journal")
        let pencil = app.buttons["New entry"]
        if pencil.exists {
            pencil.tap()
            sleep(2)
            keep(app, "a06-journal-pencil")
            note("journal pitch closed=\(closePitch(app))")
        }
        sleep(1)

        // Upgrade tab
        app.tabBars.buttons["Upgrade"].tap()
        sleep(3)
        keep(app, "a07-upgrade-tab")
        app.swipeUp()
        sleep(1)
        keep(app, "a08-upgrade-scrolled")
        let restore = app.buttons["Restore Purchases"]
        note("paywall restore exists=\(restore.exists) hittable=\(restore.isHittable)")
        if restore.exists && restore.isHittable {
            restore.tap()
            sleep(3)
            keep(app, "a09-paywall-restore-result")
        }

        // Settings from Home
        app.tabBars.buttons["Home"].tap()
        sleep(1)
        app.navigationBars.buttons.matching(NSPredicate(format: "label != %@", "Progress")).firstMatch.tap()
        sleep(1)
        keep(app, "a10-home-menu")
        let settings = app.buttons["Settings"]
        if settings.waitForExistence(timeout: 3) {
            settings.tap()
            sleep(2)
            keep(app, "a11-settings")
            let r = app.buttons["Restore Purchases"]
            if r.waitForExistence(timeout: 3) {
                r.tap()
                sleep(3)
                keep(app, "a12-settings-restore-result")
            }
        } else { note("no Settings in menu") }
    }
}
