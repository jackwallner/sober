import SwiftUI

/// Idle life for the bonsai, in the 600×600 design space. The plant leans a
/// degree or so around its soil line, the foliage trails the lean (further
/// from the pivot moves later and further), and the petals or leaves the
/// sakura and maple hold in mid-air fall and drift. `t` is a clock in ms. A
/// nil wind draws the still tree, which widgets, thumbnails and Reduce Motion use.
struct BonsaiWind {
    let t: Double

    /// The same wind, later in its cycle, so grove trees don't sway in step.
    func offset(by ms: Double) -> BonsaiWind { BonsaiWind(t: t + ms) }

    /// Bends everything drawn after this call: a horizontal shear about the
    /// soil line, so the trunk's base stays planted in the roots and the top
    /// travels furthest. A rotation would rock the whole tree on a hinge.
    /// A sprout bends more than a tree.
    func bend(_ ctx: inout GraphicsContext, pivot: CGPoint, sprout: Bool = false) {
        let amp = sprout ? 2.4 : 1.3
        let deg = amp * (0.72 * wave(5600, 0) + 0.28 * wave(8900, 0.31))
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: tan(deg * .pi / 180), d: 1, tx: 0, ty: 0))
        ctx.translateBy(x: -pivot.x, y: -pivot.y)
    }

    /// Foliage offset at (x, y): the lean's wave, delayed by distance from the
    /// pivot, plus a small rustle. A smooth field, so a branch tip and the
    /// blossom on it move together.
    func drift(_ x: Double, _ y: Double, pivot: CGPoint) -> CGSize {
        let reach = min(1.2, hypot(x - pivot.x, y - pivot.y) / 220)
        let lag = -0.07 * reach
        let rustle = 0.35 * wave(2300, 0.004 * x + 0.003 * y)
        return CGSize(width: 2.4 * reach * (0.8 * wave(5600, lag) + rustle),
                      height: 0.6 * reach * wave(5600, lag + 0.25))
    }

    /// An airborne petal or leaf: it falls from `top` to `bottom` on its own
    /// loop (`seed` and `pace` in 0...1 pick phase and speed), swinging side
    /// to side like a pendulum as it drifts downwind. It tips into each swing
    /// and sinks slower at the ends of one. It fades only as it appears and lands.
    func fall(seed: Double, pace: Double, x: Double, top: Double, bottom: Double, rotDeg: Double)
        -> (x: Double, y: Double, rotDeg: Double, opacity: Double) {
        let period = 5200 + 2800 * pace
        var p = (t / period + seed).truncatingRemainder(dividingBy: 1)
        if p < 0 { p += 1 }
        let swing = 0.75 * wave(1500 + 500 * pace, seed * 3) + 0.25 * wave(2300, seed * 7)
        let width = 7 + 6 * seed
        let sink = top + (bottom - top) * p - 3 * abs(swing)
        return (x: x + 14 * p + width * swing * (1 - p * 0.6),
                y: min(bottom, sink),
                rotDeg: rotDeg + 40 * swing,
                opacity: min(1, p / 0.12) * min(1, (1 - p) / 0.08))
    }

    private func wave(_ period: Double, _ phase: Double) -> Double {
        sin((t / period + phase) * .pi * 2)
    }
}

/// Runs a `BonsaiWind` at 60 fps while the garden is on screen and the app is
/// active; 120 Hz would double the cost for a sway nobody can tell apart.
/// Pausing holds the pose and resuming continues from it, so the tree never
/// jumps. Reduce Motion gets the still tree.
struct WindClock<Content: View>: View {
    @ViewBuilder let content: (BonsaiWind?) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var onScreen = false
    @State private var start = Date()
    @State private var pausedAt: Date?

    private var paused: Bool { scenePhase != .active || !onScreen }

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused || reduceMotion)) { tl in
            let now = pausedAt ?? tl.date
            content(reduceMotion ? nil : BonsaiWind(t: now.timeIntervalSince(start) * 1000))
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .onChange(of: paused) { _, isPaused in
            if isPaused {
                pausedAt = .now
            } else if let at = pausedAt {
                start += Date.now.timeIntervalSince(at)
                pausedAt = nil
            }
        }
    }
}
