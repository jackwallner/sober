import CoreGraphics
import SwiftUI

/// Pane frames for the unfolded iPhone Duo: the tabs on the leading side of the
/// fold, Timeline on the trailing side, so nothing straddles the crease. `nil`
/// keeps the single-column layout (every ordinary iPhone, the folded Duo, and
/// the unfolded Duo held in portrait, where each half would be too narrow).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the compact Home and Timeline layouts.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }
}

extension GeometryProxy {
    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}

/// Heights for a pane's clearance above its floating tab bar (the Timeline
/// pane: above the home indicator). Split, content ends `gap` above the bar's
/// safe-area edge, and a bottom scroll content margin of `gap` lets the last
/// row scroll up to that line. Folded, both are zero and the phone layout is
/// untouched.
struct TabBarClearance: Equatable, Sendable {
    /// Masked out from the bottom: the bar's inset plus the gap.
    var hidden: CGFloat
    /// Bottom scroll content margin, so a scrolled-to-end row meets the line.
    var contentPadding: CGFloat

    static let gap: CGFloat = 12

    static func make(isSplit: Bool, barInset: CGFloat) -> TabBarClearance {
        guard isSplit else { return TabBarClearance(hidden: 0, contentPadding: 0) }
        return TabBarClearance(hidden: max(barInset, 0) + gap, contentPadding: gap)
    }
}

/// Where a pane's content stops above its bar. A row the clearance line would
/// slice is hidden whole instead: the cut moves up to that row's top, so the
/// pane never shows half a card or a ghost of one fading out. A row that
/// starts more than `maxLift` above the line is sliced at the line rather
/// than leave the pane mostly empty.
struct PaneCut: Equatable, Sendable {
    /// In the same space as the rows' frames.
    var y: CGFloat
    /// The cut runs between two rows of one grouped list card, so the card
    /// gets rounded bottom corners there, as if the section ended.
    var closesCard: Bool

    struct Row: Equatable, Sendable {
        var minY: CGFloat
        var maxY: CGFloat
        var inGroupedCard: Bool
    }

    static let maxLift: CGFloat = 220
    /// An inset grouped list card's inset from the pane edge and its corners.
    static let cardInset: CGFloat = 20
    static let cardCornerRadius: CGFloat = 24

    static func make(line: CGFloat, rows: some Sequence<Row>) -> PaneCut {
        let sliced = rows.filter { row in
            row.minY < line - 0.5 && row.maxY > line + 0.5 && line - row.minY <= maxLift
        }
        guard let first = sliced.min(by: { $0.minY < $1.minY }) else {
            return PaneCut(y: line, closesCard: false)
        }
        // A grouped row's separator sits on the row above, so cut a point higher.
        return PaneCut(y: first.minY - (first.inGroupedCard ? 1 : 0), closesCard: first.inGroupedCard)
    }
}

extension EnvironmentValues {
    /// True inside a pane of the unfolded Duo split, for the rare screen that
    /// must size itself to the pane rather than to a phone (Home's top block).
    @Entry var isUnfoldedPane: Bool = false
    /// The split pane's row frames, for `PaneCut`. `nil` folded, so the phone
    /// layout does no bookkeeping while it scrolls.
    @Entry var paneRows: PaneRows? = nil
}

/// Row frames reported by `paneRow()` and read by the pane's mask.
@MainActor @Observable
final class PaneRows {
    var rows: [UUID: PaneCut.Row] = [:]
}

extension View {
    /// One pane of the unfolded split keeps the phone's horizontal bars. iOS
    /// 27.1 otherwise moves a tab's toolbar, and the tab bar with it, into a
    /// vertical rail against the fold on tabs that have toolbar items (Home,
    /// Journal) and leaves a bottom bar on tabs that don't (Health, Bloom+),
    /// so the same app showed two navigations. Folded, the system default.
    @ViewBuilder
    func horizontalBarsInPane(_ isSplit: Bool) -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(isSplit ? .disabled : .automatic)
        } else {
            self
        }
    }

    /// See `TabBarClearance` and `PaneCut`. The mask stays in place folded
    /// (fully open there), so folding never rebuilds the tab. The Timeline
    /// pane, which has no tab bar, uses it too, so no row is sliced at the
    /// screen edge.
    func clearsFloatingTabBar(_ isSplit: Bool, backdrop: Color = Theme.background) -> some View {
        modifier(ClearsFloatingTabBar(isSplit: isSplit, backdrop: backdrop))
    }

    /// A whole card or line the pane cut hides rather than slices.
    /// `keepWithNext` holds a section header back with its first row.
    func paneRow(keepWithNext: CGFloat = 0) -> some View {
        modifier(PaneRowReporter(keepWithNext: keepWithNext, inGroupedCard: false))
    }

    /// A row of an inset grouped List. It reports its cell's frame through
    /// the row background, which fills the cell, padding included.
    func paneListRow() -> some View {
        modifier(PaneListRow())
    }
}

private struct ClearsFloatingTabBar: ViewModifier {
    let isSplit: Bool
    let backdrop: Color
    @State private var barInset: CGFloat = 0
    @State private var rows = PaneRows()

    private var clearance: TabBarClearance {
        .make(isSplit: isSplit, barInset: barInset)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.paneRows, isSplit ? rows : nil)
            // Scroll content margins, not safe-area padding: the margin reaches
            // the scroll views inside each tab's NavigationStack, padding didn't.
            .contentMargins(.bottom, clearance.contentPadding, for: .scrollContent)
            .bottomScrollEdgeEffectHidden(isSplit)
            .mask {
                PaneCutMask(rows: rows, hidden: clearance.hidden, isSplit: isSplit)
                    .ignoresSafeArea()
            }
            // The bar floats on the page's own colour, not on a cut-off row.
            .background(backdrop.ignoresSafeArea())
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { barInset = $0 }
    }
}

private struct PaneCutMask: View {
    let rows: PaneRows
    let hidden: CGFloat
    let isSplit: Bool

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let cut = isSplit
                ? PaneCut.make(line: frame.maxY - hidden, rows: rows.rows.values)
                : PaneCut(y: frame.maxY, closesCard: false)
            let y = min(max(cut.y - frame.minY, 0), frame.height)
            let radius = cut.closesCard ? min(PaneCut.cardCornerRadius, y / 2) : 0
            // Two overlapping shapes rather than one path, so no seam shows
            // where the straight part meets the rounded card bottom.
            ZStack(alignment: .top) {
                Rectangle().frame(height: y - radius)
                if radius > 0 {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: radius,
                        bottomTrailingRadius: radius,
                        style: .continuous
                    )
                    .frame(height: radius * 2)
                    .padding(.horizontal, PaneCut.cardInset)
                    .offset(y: y - radius * 2)
                }
            }
            .frame(width: frame.width, height: frame.height, alignment: .top)
        }
    }
}

private struct PaneRowReporter: ViewModifier {
    let keepWithNext: CGFloat
    let inGroupedCard: Bool
    @Environment(\.paneRows) private var paneRows
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                let row = PaneCut.Row(minY: frame.minY, maxY: frame.maxY + keepWithNext, inGroupedCard: inGroupedCard)
                if paneRows?.rows[id] != row { paneRows?.rows[id] = row }
            }
            .onDisappear { paneRows?.rows[id] = nil }
    }
}

private struct PaneListRow: ViewModifier {
    @Environment(\.paneRows) private var paneRows

    func body(content: Content) -> some View {
        // Folded, the system's own row background, untouched.
        content.listRowBackground(
            paneRows.map { _ in
                Color(.secondarySystemGroupedBackground)
                    .modifier(PaneRowReporter(keepWithNext: 0, inGroupedCard: true))
            }
        )
    }
}

private extension View {
    @ViewBuilder
    func bottomScrollEdgeEffectHidden(_ hidden: Bool) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(hidden, for: .bottom)
        } else {
            self
        }
    }
}
