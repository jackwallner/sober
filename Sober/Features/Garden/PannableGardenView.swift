import SwiftUI

/// Hosts `GardenSceneView` in a world larger than the viewport so the garden
/// can be dragged and pinch-zoomed, so you actually explore your growth instead
/// of squinting at a 300pt box.
struct PannableGardenView: View {
    let days: Int
    let vitality: Double
    let activeBonsaiStyleID: String
    let isPro: Bool
    var completedTreeStyles: [String] = []
    var onSwapBonsai: (() -> Void)? = nil

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 3.0

    @State private var scale: CGFloat = 1.0
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1.0
    @GestureState private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size
            // The world matches the viewport so the whole garden (every placed
            // asset) is framed and centered at base zoom. Panning only unlocks
            // once you pinch-zoom in (the bounds are zero while it fits), so
            // you can't drag off into empty space.
            let world = viewport
            let liveScale = GardenPanPhysics.rubberBandScale(scale * pinch, min: minScale, max: maxScale)
            let limits = GardenPanPhysics.limits(scale: liveScale, world: world, viewport: viewport)
            // Past an edge the garden follows the finger with growing
            // resistance instead of hitting a wall.
            let liveOffset = CGSize(
                width: GardenPanPhysics.rubberBand(offsetX + drag.width, limit: limits.width, dimension: viewport.width),
                height: GardenPanPhysics.rubberBand(offsetY + drag.height, limit: limits.height, dimension: viewport.height)
            )

            ZStack {
                GardenSceneView(
                    days: days,
                    vitality: vitality,
                    activeBonsaiStyleID: activeBonsaiStyleID,
                    isPro: isPro,
                    completedTreeStyles: completedTreeStyles,
                    onSwapBonsai: onSwapBonsai
                )
                .frame(width: world.width, height: world.height)
                .scaleEffect(liveScale)
                .offset(liveOffset)
            }
            .frame(width: viewport.width, height: viewport.height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .contentShape(Rectangle())
            // Pan only once zoomed in. At base zoom there is nothing to pan to,
            // and an always-on drag would swallow the vertical swipe that
            // scrolls Home to the cards below.
            .gesture(
                DragGesture()
                    .updating($dragging) { _, state, _ in state = true }
                    .onChanged { value in drag = value.translation }
                    .onEnded { value in
                        release(velocity: value.velocity, displayed: liveOffset, world: world, viewport: viewport)
                    },
                including: scale > minScale ? .all : .subviews
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in
                        // Start from the rubber-banded scale on screen so a
                        // pinch past the limits springs back without a jump.
                        scale = GardenPanPhysics.rubberBandScale(scale * value, min: minScale, max: maxScale)
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                            scale = min(maxScale, max(minScale, scale))
                            settle(world: world, viewport: viewport)
                        }
                    }
            )
            // A drag the system cancels never reaches onEnded; settle it here.
            .onChange(of: dragging) { _, isDragging in
                guard !isDragging, drag != .zero else { return }
                release(velocity: .zero, displayed: liveOffset, world: world, viewport: viewport)
            }
            .overlay(alignment: .bottomTrailing) {
                if scale > minScale || offsetX != 0 || offsetY != 0 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scale = minScale
                            offsetX = 0
                            offsetY = 0
                        }
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .font(Theme.body())
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(12)
                    .transition(.opacity)
                }
            }
        }
    }

    /// Lifts the finger: the garden keeps the release velocity and coasts to
    /// where that momentum would carry it, stopping at the edges.
    private func release(velocity: CGSize, displayed: CGSize, world: CGSize, viewport: CGSize) {
        let limits = GardenPanPhysics.limits(scale: scale, world: world, viewport: viewport)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            offsetX = displayed.width
            offsetY = displayed.height
            drag = .zero
        }
        let targetX = GardenPanPhysics.target(from: displayed.width, velocity: velocity.width, limit: limits.width)
        let targetY = GardenPanPhysics.target(from: displayed.height, velocity: velocity.height, limit: limits.height)
        withAnimation(GardenPanPhysics.coast(from: displayed.width, to: targetX, velocity: velocity.width)) {
            offsetX = targetX
        }
        withAnimation(GardenPanPhysics.coast(from: displayed.height, to: targetY, velocity: velocity.height)) {
            offsetY = targetY
        }
    }

    private func settle(world: CGSize, viewport: CGSize) {
        let limits = GardenPanPhysics.limits(scale: scale, world: world, viewport: viewport)
        offsetX = min(limits.width, max(-limits.width, offsetX))
        offsetY = min(limits.height, max(-limits.height, offsetY))
    }
}

/// Pan and zoom feel, kept pure so it can be tested.
enum GardenPanPhysics {
    /// UIScrollView's edge resistance constant.
    static let resistance: CGFloat = 0.55
    /// UIScrollView's normal deceleration rate, per millisecond.
    static let deceleration: CGFloat = 0.998

    /// How far the offset may travel from center on each axis at `scale`.
    static func limits(scale: CGFloat, world: CGSize, viewport: CGSize) -> CGSize {
        CGSize(
            width: max(0, (world.width * scale - viewport.width) / 2),
            height: max(0, (world.height * scale - viewport.height) / 2)
        )
    }

    /// Inside `-limit...limit` the value passes through. Past it, the overshoot
    /// is compressed on an asymptotic curve that never reaches `dimension`.
    static func rubberBand(_ value: CGFloat, limit: CGFloat, dimension: CGFloat) -> CGFloat {
        guard abs(value) > limit, dimension > 0 else { return value }
        let overshoot = abs(value) - limit
        let eased = (overshoot * dimension * resistance) / (dimension + resistance * overshoot)
        return (limit + eased) * (value < 0 ? -1 : 1)
    }

    /// Scale past `min` or `max` keeps moving under the fingers, with resistance.
    static func rubberBandScale(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        if value > upper { return upper * pow(value / upper, 0.3) }
        if value < lower { return lower * pow(value / lower, 0.3) }
        return value
    }

    /// Distance a release at `velocity` (points per second) coasts before stopping.
    static func projection(velocity: CGFloat) -> CGFloat {
        (velocity / 1000) * deceleration / (1 - deceleration)
    }

    /// Where a release at `position` comes to rest, inside the edges.
    static func target(from position: CGFloat, velocity: CGFloat, limit: CGFloat) -> CGFloat {
        let projected = position + projection(velocity: velocity)
        return min(limit, max(-limit, projected))
    }

    /// A critically damped spring that starts at the finger's speed.
    static func coast(from start: CGFloat, to end: CGFloat, velocity: CGFloat) -> Animation {
        let distance = end - start
        guard abs(distance) > 0.5 else { return .spring(duration: 0.35, bounce: 0) }
        // SwiftUI's spring velocity is in units of the total distance per second.
        let relative = Double(velocity / distance)
        return .interpolatingSpring(duration: 0.6, bounce: 0, initialVelocity: max(-40, min(relative, 40)))
    }
}
