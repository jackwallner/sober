import XCTest

/// QA capture for the 1.3.3 day-zero Bloom+ work: the trial CTA's frame against
/// the Continue button before it, Home's goal and milestone cards, the craving
/// exit card, and the playbook. Screenshots are kept as attachments so they can
/// be exported from the result bundle.
///
/// Order matters and the names encode it: the first test needs a fresh,
/// not-yet-onboarded install; the later ones seed their own state.
final class BloomDayZeroCaptureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sober")
        app.launchArguments += args
        app.launch()
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func test1TrialCTASitsOnTheContinueFrame() {
        var app = launch(["-onboardingStep", "3", "-previewStore"])
        let goToNext = app.buttons["Continue"]
        XCTAssertTrue(goToNext.waitForExistence(timeout: 20))
        let continueFrame = goToNext.frame
        app.terminate()

        app = launch(["-onboardingStep", "4", "-previewStore"])
        let cta = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Start my")).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 20))
        let ctaFrame = cta.frame
        print("AXFRAME continue=\(continueFrame) trialCTA=\(ctaFrame)")
        let dump = XCTAttachment(string: "continue=\(continueFrame)\ntrialCTA=\(ctaFrame)\n\n\(app.debugDescription)")
        dump.name = "ax-frames"
        dump.lifetime = .keepAlways
        add(dump)
        XCTAssertEqual(ctaFrame.minY, continueFrame.minY, "The trial CTA moved off the Continue button's y")
        XCTAssertEqual(ctaFrame.height, continueFrame.height)
        XCTAssertEqual(ctaFrame.minX, continueFrame.minX)
        XCTAssertEqual(ctaFrame.width, continueFrame.width)
    }

    func test2HomeLockedCards() {
        let app = launch(["-seedDemo", "-seedDays", "0", "-seedGoal", "30"])
        let craving = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(craving.waitForExistence(timeout: 20))
        sleep(1)
        keep(app, "03-home-top")
        // Start on the garden: the swipe has to scroll Home, not pan the tree.
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        let countdown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "to go")).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "No goal countdown")
        XCTAssertTrue(countdown.isHittable, "Home did not scroll to the goal card")
        sleep(1)
        keep(app, "04-home-cards-locked")
    }

    func test3CravingExitCard() {
        let app = launch([])
        let start = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        let through = app.buttons["I'm through it"]
        XCTAssertTrue(through.waitForExistence(timeout: 10))
        through.tap()
        let social = app.buttons["Social event"]
        XCTAssertTrue(social.waitForExistence(timeout: 10))
        social.tap()
        app.buttons["It passed"].tap()
        XCTAssertTrue(app.staticTexts["Logged."].waitForExistence(timeout: 10))
        let card = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Your plan for next time")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No playbook card on the exit screen")
        keep(app, "05-craving-exit-card")
        card.tap()
        sleep(3)
        keep(app, "06-playbook-locked-pitch")
    }

    func test4PlaybookForBloomPlus() {
        let app = launch(["-demoPro", "-showPlaybook"])
        XCTAssertTrue(app.navigationBars["Playbook"].waitForExistence(timeout: 20))
        keep(app, "07-playbook-list")
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Social, or offered one")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Social, or offered one"].waitForExistence(timeout: 5))
        keep(app, "08-playbook-plan")
        app.terminate()

        let home = launch(["-demoPro"])
        XCTAssertTrue(home.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch.waitForExistence(timeout: 20))
        let homeWindow = home.windows.firstMatch
        homeWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: homeWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        sleep(1)
        keep(home, "09-home-cards-bloomplus")
    }

    /// The `trial_note` test: no note in the control, the note under the
    /// benefit card in the indie arm, and the CTA in the same place in both.
    func test5TrialNoteArms() {
        let note = "We're a small indie studio. Your trial helps us keep building. Not for you? Cancel anytime and tell us what to fix."
        var ctaFrames: [CGRect] = []
        for arm in ["none", "indie"] {
            let app = launch(["-onboardingStep", "4", "-previewStore", "-trialNote.arm", arm])
            let cta = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Start my")).firstMatch
            XCTAssertTrue(cta.waitForExistence(timeout: 20))
            ctaFrames.append(cta.frame)
            let text = app.staticTexts[note]
            XCTAssertEqual(text.exists, arm == "indie", "\(arm): note presence")
            if arm == "indie" {
                XCTAssertLessThan(text.frame.maxY, cta.frame.minY, "indie: note runs into the CTA")
            }
            keep(app, "trial_note_\(arm)")
            app.terminate()
        }
        XCTAssertEqual(ctaFrames.first, ctaFrames.last, "CTA moved between arms")
    }
}
