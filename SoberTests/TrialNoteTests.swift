import XCTest
@testable import Sober

final class TrialNoteTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "TrialNoteTests")
        defaults.removePersistentDomain(forName: "TrialNoteTests")
    }

    func testMissingOrUnknownMetadataIsTheLivePitch() {
        XCTAssertEqual(TrialNote.config(from: nil), .none)
        XCTAssertEqual(TrialNote.config(from: ["trial_note": "loud"]), .none)
        XCTAssertEqual(TrialNote.config(from: ["trial_note": "split"]), .split)
        XCTAssertFalse(TrialNote.shows(.none, defaults, coin: { true }))
        XCTAssertTrue(TrialNote.shows(.indie, defaults, coin: { false }))
    }

    func testSplitDealsOnceAndTheSwitchStopsIt() {
        XCTAssertTrue(TrialNote.shows(.split, defaults, coin: { true }))
        XCTAssertTrue(TrialNote.shows(.split, defaults, coin: { false }), "kept for good")
        XCTAssertFalse(TrialNote.shows(.none, defaults, coin: { true }), "none stops it for everyone")
    }

    func testWhatToFixOnlyAfterTheNoteAndARenewalSwitchedOff() {
        XCTAssertFalse(TrialNote.whatToFixDue(inTrial: true, willRenew: false, defaults), "never saw the pitch")
        TrialNote.markSeen(showedNote: false, defaults)
        XCTAssertFalse(TrialNote.whatToFixDue(inTrial: true, willRenew: false, defaults), "control arm")
        TrialNote.markSeen(showedNote: true, defaults)
        XCTAssertEqual(TrialNote.seenArm(defaults), "indie")
        XCTAssertFalse(TrialNote.whatToFixDue(inTrial: true, willRenew: true, defaults), "still renewing")
        XCTAssertFalse(TrialNote.whatToFixDue(inTrial: false, willRenew: false, defaults), "paid, not a trial")
        XCTAssertTrue(TrialNote.whatToFixDue(inTrial: true, willRenew: false, defaults))
        TrialNote.markAsked(defaults)
        XCTAssertFalse(TrialNote.whatToFixDue(inTrial: true, willRenew: false, defaults), "asked once")
    }
}
