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
        let rows = [PaneCut.Row(minY: 100, maxY: 300, card: nil),
                    PaneCut.Row(minY: 316, maxY: 574, card: nil),
                    PaneCut.Row(minY: 590, maxY: 700, card: nil)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 574, card: nil))
    }

    @Test func aSlicedCardIsHiddenWhole() {
        let rows = [PaneCut.Row(minY: 300, maxY: 500, card: nil),
                    PaneCut.Row(minY: 516, maxY: 640, card: nil)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 516, card: nil))
    }

    @Test func aSlicedListRowClosesItsCardAboveTheSeparator() {
        let rows = [PaneCut.Row(minY: 360, maxY: 494, card: .groupedList),
                    PaneCut.Row(minY: 494, maxY: 630, card: .groupedList)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 493, card: .groupedList))
    }

    @Test func aHeaderGoesWithItsFirstRow() {
        // The header's frame is stretched by its keep-with-next allowance.
        let rows = [PaneCut.Row(minY: 540, maxY: 560 + 72, card: nil),
                    PaneCut.Row(minY: 568, maxY: 700, card: .groupedList)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 540, card: nil))
    }

    @Test func aTallRowIsSlicedRatherThanEmptyThePane() {
        let rows = [PaneCut.Row(minY: 574 - PaneCut.maxLift - 1, maxY: 900, card: nil)]
        #expect(PaneCut.make(line: 574, rows: rows) == PaneCut(y: 574, card: nil))
    }
}

@Suite("Health rows in the pane")
struct BenefitRowStyleTests {
    @Test func foldedEarnedBenefitsShowInFull() {
        #expect(!BenefitRowStyle.isCollapsed(isPane: false, unlocked: true, expanded: false))
    }

    @Test func paneListsEarnedBenefitsOneLineEachUntilTapped() {
        #expect(BenefitRowStyle.isCollapsed(isPane: true, unlocked: true, expanded: false))
        #expect(!BenefitRowStyle.isCollapsed(isPane: true, unlocked: true, expanded: true))
    }

    @Test func lockedRowsKeepTheirTease() {
        #expect(!BenefitRowStyle.isCollapsed(isPane: true, unlocked: false, expanded: false))
    }
}
