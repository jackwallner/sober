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

    /// Leans everything drawn after this call about `pivot`. A seed (day 0)
    /// stays still; a sprout bends more than a tree.
    func bend(_ ctx: inout GraphicsContext, pivot: CGPoint, sprout: Bool = false) {
        let amp = sprout ? 2.2 : 1.0
        let deg = amp * (0.72 * wave(5600, 0) + 0.28 * wave(8900, 0.31))
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: .degrees(deg))
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
    /// loop (`seed` and `pace` in 0...1 pick phase and speed), drifting
    /// downwind and rocking. It fades only as it appears and lands.
    func fall(seed: Double, pace: Double, x: Double, top: Double, bottom: Double, rotDeg: Double)
        -> (x: Double, y: Double, rotDeg: Double, opacity: Double) {
        let period = 8000 + 4500 * pace
        var p = (t / period + seed).truncatingRemainder(dividingBy: 1)
        if p < 0 { p += 1 }
        return (x: x + 16 * p + 5 * wave(2600, seed),
                y: top + (bottom - top) * p,
                rotDeg: rotDeg + 150 * p + 16 * wave(1900, seed + 0.2),
                opacity: min(1, p / 0.12) * min(1, (1 - p) / 0.18))
    }

    private func wave(_ period: Double, _ phase: Double) -> Double {
        sin((t / period + phase) * .pi * 2)
    }
}

/// Runs a `BonsaiWind` at 30 fps while the garden is on screen and the app is
/// active. The sway moves well under a point per frame, so 60 fps would only
/// cost battery. Pausing holds the pose and resuming continues from it, so
/// the tree never jumps. Reduce Motion gets the still tree.
struct WindClock<Content: View>: View {
    @ViewBuilder let content: (BonsaiWind?) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var onScreen = false
    @State private var start = Date()
    @State private var pausedAt: Date?

    private var paused: Bool { scenePhase != .active || !onScreen }

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { tl in
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
