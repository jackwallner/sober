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

    /// Run alone on a fresh simulator: any earlier -seedDemo launch persists
    /// the completed-onboarding flag and lands this test on Home.
    func testOnboardingResumeAfterKill() {
        var app = launch([])
        let start = app.buttons["Start my counter"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        keep("o1-first")
        start.tap()
        sleep(2)
        keep("o2-step1-start-date")
        note("step 1 buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 5) { cont.tap(); sleep(2) }
        keep("o3-step2-savings")
        note("step 2 buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        app.terminate()
        app = launch([])
        sleep(4)
        keep("o4-after-kill")
        let back = app.buttons["Start my counter"].exists
        note("after kill buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        note("restarted at step 0: \(back)")
        XCTAssertFalse(back, "Onboarding restarted at step 0 after kill")
    }

    // MARK: Timeline note draft

    func testTimelineNoteDraft() {
        var app = launch(["-seedDemo", "-demoPro", "-tab", "1"])
        let field = app.textFields["How did the day go?"]
        let scroll = app.tables.firstMatch
        var tries = 0
        while !field.exists && tries < 6 { scroll.swipeUp(); tries += 1 }
        XCTAssertTrue(field.waitForExistence(timeout: 20), "note field missing")
        keep("t1-before")
        field.tap()
        field.typeText("Rough evening, wrote this before the phone rang")
        keep("t2-typed")
        interrupt(seconds: 4)
        app.activate()
        sleep(1)
        keep("t3-after-app-switch")
        note("after app switch note: \(app.textFields.matching(NSPredicate(format: \"value CONTAINS 'Rough evening'\")).count)")
        app.terminate()
        app = launch(["-seedDemo", "-demoPro", "-tab", "1"])
        sleep(3)
        tries = 0
        while !app.textFields["How did the day go?"].exists && tries < 6 { app.tables.firstMatch.swipeUp(); tries += 1 }
        keep("t4-after-kill")
        let f2 = app.textFields["How did the day go?"]
        let v = f2.value as? String ?? "nil"
        note("after kill note value: \(v)")
        XCTAssertTrue(v.contains("Rough evening"), "Timeline note draft lost after kill: '\(v)'")
    }
}
