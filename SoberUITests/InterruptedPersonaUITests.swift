import XCTest

/// Persona audit: a tired user is interrupted mid-task (call, notification, app
/// switch, kill) and comes back expecting the work to still be there. Each test
/// starts interacting immediately so it fits the 120s recording window.
final class InterruptedPersonaUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += args
        app.launch()
        return app
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func note(_ text: String) {
        print("PERSONA \(text)")
        let a = XCTAttachment(string: text)
        a.name = "note"
        a.lifetime = .keepAlways
        add(a)
    }

    private func interrupt(seconds: UInt32) {
        XCUIDevice.shared.press(.home)
        sleep(seconds)
    }

    // MARK: Journal draft

    func testJournalDraftSurvivesInterruption() {
        var app = launch(["-seedDemo", "-demoPro", "-tab", "3"])
        let compose = app.buttons["New entry"]
        XCTAssertTrue(compose.waitForExistence(timeout: 20))
        compose.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        editor.typeText("Called mid-sentence, writing about the hard part of tonight")
        keep("j1-typed")

        interrupt(seconds: 4)
        app.activate()
        sleep(1)
        keep("j2-after-app-switch")
        note("after app switch editor value: \(app.textViews.firstMatch.value as? String ?? "nil")")

        // Accidental swipe-down dismissal of the sheet (phone call / pocket).
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        start.press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        sleep(2)
        keep("j3-after-swipe-down")
        note("sheet still showing after swipe-down: \(app.textViews.firstMatch.exists)")
        app.buttons["New entry"].tap()
        sleep(1)
        let v = app.textViews.firstMatch.value as? String ?? "nil"
        note("reopened editor value: \(v)")
        keep("j4-reopened")
        XCTAssertTrue(v.contains("Called mid-sentence"), "Draft lost after accidental dismiss: '\(v)'")

        // Kill and return.
        app.textViews.firstMatch.tap()
        app.textViews.firstMatch.typeText("second attempt text")
        app.terminate()
        app = launch(["-seedDemo", "-demoPro", "-tab", "3"])
        XCTAssertTrue(app.buttons["New entry"].waitForExistence(timeout: 20))
        app.buttons["New entry"].tap()
        sleep(1)
        let v2 = app.textViews.firstMatch.value as? String ?? "nil"
        note("after kill editor value: \(v2)")
        keep("j5-after-kill")
        XCTAssertTrue(v2.contains("second attempt"), "Draft lost after app kill: '\(v2)'")
    }

    // MARK: Craving session

    func testCravingSessionAfterBackground() {
        let app = launch(["-seedDemo"])
        let start = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        sleep(3)
        keep("c1-running")
        let before = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\d:\\d\\d")).firstMatch
        note("timer before interrupt: \(before.exists ? before.label : "none")")
        interrupt(seconds: 30)
        app.activate()
        sleep(1)
        keep("c2-after-30s-away")
        let after = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\d:\\d\\d")).firstMatch
        note("timer after 30s away: \(after.exists ? after.label : "none")")
        // Wall clock moved 30s+; a faithful timer would have dropped by ~30s.
        app.terminate()
        let app2 = launch(["-seedDemo"])
        XCTAssertTrue(app2.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch.waitForExistence(timeout: 20))
        keep("c3-after-kill-home")
        app2.tabBars.buttons["Health"].tap()
        sleep(1)
    }

    // MARK: Onboarding

    func testOnboardingResumeAfterKill() {
        var app = launch([])
        let next = app.buttons.element(boundBy: 0)
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        keep("o1-first")
        // Advance as far as the cost step.
        for _ in 0..<2 {
            let cont = app.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "Get started", "Begin", "Next", "Let's go"])).firstMatch
            if cont.waitForExistence(timeout: 5) { cont.tap() }
            sleep(1)
        }
        keep("o2-mid")
        note("mid-onboarding buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        app.terminate()
        app = launch([])
        sleep(3)
        keep("o3-after-kill")
        note("after kill buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
    }
}
