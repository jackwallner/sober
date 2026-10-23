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
        #expect(TabBarClearance.make(isSplit: false, barInset: 81) == TabBarClearance(hidden: 0, contentPadding: 0))
    }

    @Test func splitHidesEverythingUnderTheBar() {
        let clearance = TabBarClearance.make(isSplit: true, barInset: 81)
        // Content is gone a gap above the bar's top edge.
        #expect(clearance.hidden == 81 + TabBarClearance.gap)
        // The last row can scroll all the way up to that line, so it is never cut.
        #expect(clearance.contentPadding == TabBarClearance.gap)
    }

    @Test func negativeInsetNeverUncoversTheBar() {
        #expect(TabBarClearance.make(isSplit: true, barInset: -4).hidden == TabBarClearance.gap)
    }

    // Pane cut: the line sits at 574 in each case.

    @Test func rowsClearOfTheLineCutAtTheLine() {
        let rows = [PaneCut.Row(minY: 100, maxY: 300, inGroupedCard: false),
                    PaneCut.Row(minY: 316, maxY: 574, inGroupedCard: false),
                    PaneCut.Row(minY: 590, maxY: 700, inGroupedCard: false)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 574, closesCard: false))
    }

    @Test func aSlicedCardIsHiddenWhole() {
        let rows = [PaneCut.Row(minY: 300, maxY: 500, inGroupedCard: false),
                    PaneCut.Row(minY: 516, maxY: 640, inGroupedCard: false)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 516, closesCard: false))
    }

    @Test func aSlicedListRowClosesItsCardAboveTheSeparator() {
        let rows = [PaneCut.Row(minY: 360, maxY: 494, inGroupedCard: true),
                    PaneCut.Row(minY: 494, maxY: 630, inGroupedCard: true)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 493, closesCard: true))
    }

    @Test func aHeaderGoesWithItsFirstRow() {
        // The header's frame is stretched by its keep-with-next allowance.
        let rows = [PaneCut.Row(minY: 540, maxY: 560 + 72, inGroupedCard: false),
                    PaneCut.Row(minY: 568, maxY: 700, inGroupedCard: true)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 540, closesCard: false))
    }

    @Test func aTallRowIsSlicedRatherThanEmptyThePane() {
        let rows = [PaneCut.Row(minY: 574 - PaneCut.maxLift - 1, maxY: 900, inGroupedCard: false)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 574, closesCard: false))
    }
}
