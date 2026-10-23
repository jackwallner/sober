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

/// Heights for the leading pane's clearance above the floating tab bar. Split,
/// a tab's content fades out over `fade` and is gone `gap` above the bar's
/// safe-area edge, so no row ever sits under the bar or shows through it;
/// bottom safe-area padding of `fade + gap` lets the last row scroll fully
/// clear of the fade. Folded, every height is zero and the phone layout is
/// untouched.
struct TabBarClearance: Equatable, Sendable {
    var fade: CGFloat
    /// Masked out below the fade: the bar's inset plus the gap.
    var hidden: CGFloat
    /// Added to the content's bottom safe area so scrolled-to-end rows clear the fade.
    var contentPadding: CGFloat

    static let fadeHeight: CGFloat = 36
    static let gap: CGFloat = 8

    static func make(isSplit: Bool, barInset: CGFloat) -> TabBarClearance {
        guard isSplit else { return TabBarClearance(fade: 0, hidden: 0, contentPadding: 0) }
        return TabBarClearance(
            fade: fadeHeight,
            hidden: max(barInset, 0) + gap,
            contentPadding: fadeHeight + gap
        )
    }
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

    /// See `TabBarClearance`. The mask stays in place folded (fully open
    /// there), so folding never rebuilds the tab.
    func clearsFloatingTabBar(_ isSplit: Bool) -> some View {
        modifier(ClearsFloatingTabBar(isSplit: isSplit))
    }
}

private struct ClearsFloatingTabBar: ViewModifier {
    let isSplit: Bool
    @State private var barInset: CGFloat = 0

    private var clearance: TabBarClearance {
        .make(isSplit: isSplit, barInset: barInset)
    }

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, clearance.contentPadding)
            .bottomScrollEdgeEffectHidden(isSplit)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    // Eased, so a row low in the fade is gone rather than a
                    // faint sliver above the cut.
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black.opacity(0.45), location: 0.4),
                            .init(color: .black.opacity(0.08), location: 0.7),
                            .init(color: .clear, location: 0.85),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: clearance.fade)
                    Color.clear.frame(height: clearance.hidden)
                }
                .ignoresSafeArea()
            }
            // The bar floats on the page's own cream, not on a cut-off row.
            .background(Theme.background.ignoresSafeArea())
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { barInset = $0 }
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
