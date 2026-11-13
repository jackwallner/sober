import XCTest

/// iPad layout sweep: every main surface in portrait and landscape, kept as
/// attachments (`gh-sim test --only SoberUITests/IPadCaptureUITests`). It never
/// calls XCTFail: a surface it cannot reach goes into the `notes` attachment, so
/// one missing button does not cost the rest of the frames.
@MainActor
final class IPadCaptureUITests: XCTestCase {
    private var notes: [String] = []

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        let note = XCTAttachment(string: notes.joined(separator: "\n"))
        note.name = "notes"
        note.lifetime = .keepAlways
        add(note)
    }

    private func launch(_ args: [String], landscape: Bool) -> XCUIApplication {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        sleep(1)
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += args
        app.launch()
        sleep(3)
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String, wait: UInt32 = 2) {
        sleep(wait)
        // The app screenshot comes back portrait-sized when the device is in
        // landscape on an iPad, clipping the right third. The window's own
        // screenshot has the window's size, so keep that one.
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        if name.hasSuffix("-home") {
            notes.append("\(name): window \(app.windows.firstMatch.frame) orientation \(XCUIDevice.shared.orientation.rawValue)")
            let alt = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            alt.name = name + "-screen"
            alt.lifetime = .keepAlways
            add(alt)
        }
    }

    private func tap(_ element: XCUIElement, _ what: String) -> Bool {
        guard element.waitForExistence(timeout: 8) else {
            notes.append("missing: \(what)")
            return false
        }
        element.tap()
        return true
    }

    private func sweep(landscape: Bool) {
        let o = landscape ? "land" : "port"
        let demo = ["-seedDemo", "-seedDays", "127", "-seedGoal", "365", "-storeScreenshots"]

        for step in 0...5 {
            let app = launch(["-freshOnboarding", "-previewStore", "-onboardingStep", "\(step)"], landscape: landscape)
            keep(app, "\(o)-onboarding-\(step)")
            app.terminate()
        }

        for (tab, name) in [(0, "home"), (2, "health"), (3, "journal"), (4, "bloomplus")] {
            let app = launch(demo + ["-demoPro", "-tab", "\(tab)"], landscape: landscape)
            keep(app, "\(o)-\(name)")
            app.terminate()
        }

        // Free: the Upgrade tab and a locked-feature paywall sheet.
        var app = launch(["-seedDemo", "-seedDays", "127", "-previewStore", "-tab", "4"], landscape: landscape)
        keep(app, "\(o)-upgrade-tab")
        app.terminate()

        app = launch(["-seedDemo", "-seedDays", "127", "-previewStore", "-tab", "3"], landscape: landscape)
        if tap(app.buttons["Write entry"], "Write entry") { keep(app, "\(o)-paywall-sheet", wait: 4) }
        app.terminate()

        app = launch(["-PaywallSnapshot", "trial", "-previewStore", "-seedDemo"], landscape: landscape)
        keep(app, "\(o)-paywall-harness", wait: 4)
        app.terminate()

        // Home sheets and covers.
        app = launch(demo + ["-demoPro", "-showProgress"], landscape: landscape)
        keep(app, "\(o)-progress", wait: 3)
        app.terminate()

        app = launch(demo + ["-demoPro", "-showPlaybook"], landscape: landscape)
        keep(app, "\(o)-playbook", wait: 3)
        app.terminate()

        app = launch(demo + ["-demoPro"], landscape: landscape)
        let craving = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        if tap(craving, "craving button") {
            keep(app, "\(o)-craving", wait: 3)
            if tap(app.buttons["I'm through it"], "I'm through it") {
                keep(app, "\(o)-craving-exit", wait: 2)
            }
        }
        app.terminate()

        app = launch(demo + ["-demoPro"], landscape: landscape)
        if tap(app.buttons["More"], "More menu"), tap(app.buttons["Settings"], "Settings") {
            keep(app, "\(o)-settings", wait: 3)
        }
        app.terminate()
    }

    func testPortrait() { sweep(landscape: false) }
    func testLandscape() { sweep(landscape: true) }
}
