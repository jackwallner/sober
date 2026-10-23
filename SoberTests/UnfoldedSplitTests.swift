import CoreGraphics
import Testing
@testable import Sober

@Suite("Unfolded split")
struct UnfoldedSplitTests {
    @Test func compactWidthNeverSplits() {
        #expect(UnfoldedSplit.make(width: 951, isRegularWidth: false, fold: 455.5...495.5) == nil)
    }

    @Test func unfoldedPortraitStaysOneColumn() {
        #expect(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil) == nil)
    }

    @Test func panesMeetTheFoldEdges() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: 455.5...495.5)
        #expect(split == UnfoldedSplit(primaryWidth: 455.5, secondaryX: 495.5, secondaryWidth: 455.5))
    }

    @Test func noFoldSplitsEvenly() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: nil)
        #expect(split == UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    @Test func foldLeavingANarrowPaneIsIgnored() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: 600...640)
        #expect(split == UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    @Test func splitsFromTwiceTheMinimumPane() {
        #expect(UnfoldedSplit.make(width: 719, isRegularWidth: true, fold: nil) == nil)
        #expect(UnfoldedSplit.make(width: 720, isRegularWidth: true, fold: nil)?.primaryWidth == 360)
    }

    @Test func foldedKeepsThePhoneLayout() {
        #expect(TabBarClearance.make(isSplit: false, barInset: 81) == TabBarClearance(fade: 0, hidden: 0, contentPadding: 0))
    }

    @Test func splitHidesEverythingUnderTheBar() {
        let clearance = TabBarClearance.make(isSplit: true, barInset: 81)
        // Content is gone a gap above the bar's top edge, and fades out above that.
        #expect(clearance.hidden == 81 + TabBarClearance.gap)
        #expect(clearance.fade > 0)
        // The last row can scroll fully above the fade, so it is never cut.
        #expect(clearance.contentPadding >= clearance.fade + TabBarClearance.gap)
    }

    @Test func negativeInsetNeverUncoversTheBar() {
        #expect(TabBarClearance.make(isSplit: true, barInset: -4).hidden == TabBarClearance.gap)
    }
}
