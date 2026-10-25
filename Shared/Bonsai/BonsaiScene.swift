import SwiftUI

// A tree's geometry is a pure function of its style and day, so it is built
// once and replayed on every animation frame. The painters record into
// `BonsaiLayers` instead of a GraphicsContext; `BonsaiScene.paint` replays the
// recorded fills and only works out the wind: the bend, and how far each piece
// drifts.

/// How a recorded piece moves in the wind.
enum BonsaiMotion: Equatable {
    case still                          // pot, soil, fallen petals
    case bent                           // the plant's shear about its soil line
    case drift(CGPoint)                 // bent, then carried by the drift at this point
    /// Bent, then a limb stretched from `from` (fixed in the wood) to `to`
    /// (carried by the drift there), the way its tip follows its foliage.
    case limb(from: CGPoint, to: CGPoint)
}

/// A fill colour or bark gradient, kept in design space so a recorded
/// transform can move a gradient along with its path.
struct BonsaiInk {
    fileprivate enum Kind { case color(Color), linear(Gradient, CGPoint, CGPoint) }
    fileprivate var kind: Kind

    static func color(_ c: Color) -> BonsaiInk { BonsaiInk(kind: .color(c)) }

    static func linearGradient(_ g: Gradient, startPoint: CGPoint, endPoint: CGPoint) -> BonsaiInk {
        BonsaiInk(kind: .linear(g, startPoint, endPoint))
    }

    fileprivate func shading(_ t: CGAffineTransform) -> GraphicsContext.Shading {
        switch kind {
        case .color(let c): return .color(c)
        case .linear(let g, let a, let b):
            return .linearGradient(g, startPoint: a.applying(t), endPoint: b.applying(t))
        }
    }
}

/// Records fills for a `BonsaiScene`. It mirrors the part of GraphicsContext
/// the painters use: a copy keeps its own transform, clip and motion but
/// writes into the same list, just as a GraphicsContext copy draws into the
/// same canvas.
struct BonsaiLayers {
    fileprivate struct Layer { var path: Path; var shading: GraphicsContext.Shading; var clip, motion: Int }
    fileprivate struct Clip { var path: Path; var inverse: Bool }

    fileprivate final class Store {
        var layers: [Layer] = []
        var clips: [[Clip]] = [[]]
        var motions: [BonsaiMotion] = [.still]
    }

    fileprivate let store = Store()
    private var transform = CGAffineTransform.identity
    private var clip = 0
    private var motion = 0

    /// Everything recorded after this moves with `m`.
    mutating func move(_ m: BonsaiMotion) {
        store.motions.append(m)
        motion = store.motions.count - 1
    }

    mutating func fill(_ path: Path, with ink: BonsaiInk) {
        store.layers.append(Layer(path: transform.isIdentity ? path : path.applying(transform),
                                  shading: ink.shading(transform), clip: clip, motion: motion))
    }

    mutating func stroke(_ path: Path, with ink: BonsaiInk, style: StrokeStyle) {
        fill(path.strokedPath(style), with: ink)
    }

    mutating func clip(to path: Path, options: GraphicsContext.ClipOptions = []) {
        let c = Clip(path: transform.isIdentity ? path : path.applying(transform),
                     inverse: options.contains(.inverse))
        store.clips.append(store.clips[clip] + [c])
        clip = store.clips.count - 1
    }

    mutating func translateBy(x: Double, y: Double) { transform = transform.translatedBy(x: x, y: y) }
    mutating func scaleBy(x: Double, y: Double) { transform = transform.scaledBy(x: x, y: y) }
    mutating func rotate(by angle: Angle) { transform = transform.rotated(by: angle.radians) }
}

/// A recorded tree, ready to paint at any moment of the sway.
struct BonsaiScene {
    fileprivate var layers: [BonsaiLayers.Layer]
    fileprivate var clips: [[BonsaiLayers.Clip]]
    fileprivate var motions: [BonsaiMotion]
    let pivot: CGPoint
    let sprout: Bool
    /// What moves on its own path every frame (falling petals and leaves),
    /// painted over the recorded layers.
    let air: ((inout GraphicsContext, BonsaiWind?) -> Void)?

    init(_ rec: BonsaiLayers, pivot: CGPoint, sprout: Bool = false,
         air: ((inout GraphicsContext, BonsaiWind?) -> Void)? = nil) {
        layers = rec.store.layers
        clips = rec.store.clips
        motions = rec.store.motions
        self.pivot = pivot
        self.sprout = sprout
        self.air = air
    }

    func paint(wind: BonsaiWind?, in ctx: inout GraphicsContext) {
        var bent = ctx
        wind?.bend(&bent, pivot: pivot, sprout: sprout)
        var g = ctx
        var run = (clip: -1, motion: -1)
        for l in layers {
            if l.clip != run.clip || l.motion != run.motion {
                run = (l.clip, l.motion)
                g = place(motions[l.motion], wind: wind, still: ctx, bent: bent)
                for c in clips[l.clip] { g.clip(to: c.path, options: c.inverse ? .inverse : []) }
            }
            g.fill(l.path, with: l.shading)
        }
        air?(&ctx, wind)
    }

    private func place(_ m: BonsaiMotion, wind: BonsaiWind?, still: GraphicsContext,
                       bent: GraphicsContext) -> GraphicsContext {
        switch m {
        case .still: return still
        case .bent: return bent
        case .drift(let p):
            guard let wind else { return bent }
            let d = wind.drift(p.x, p.y, pivot: pivot)
            var g = bent
            g.translateBy(x: d.width, y: d.height)
            return g
        case .limb(let a, let b):
            guard let wind else { return bent }
            let d = wind.drift(b.x, b.y, pivot: pivot)
            var g = bent
            g.concatenate(stretch(from: a, to: b, by: d))
            return g
        }
    }
}

/// The affine map that holds `a` and carries `b` by `d`, moving each point by
/// `d` times how far along a→b it lies. A limb drawn as a quadratic whose tip
/// moves by `d` and control by half of it moves the same way, so this is the
/// recorded limb bending with its foliage.
private func stretch(from a: CGPoint, to b: CGPoint, by d: CGSize) -> CGAffineTransform {
    let cx = b.x - a.x, cy = b.y - a.y
    let l2 = cx * cx + cy * cy
    guard l2 > 1 else { return CGAffineTransform(translationX: d.width, y: d.height) }
    let kx = d.width / l2, ky = d.height / l2
    let along = cx * a.x + cy * a.y
    return CGAffineTransform(a: 1 + kx * cx, b: ky * cx, c: kx * cy, d: 1 + ky * cy,
                             tx: -kx * along, ty: -ky * along)
}

// MARK: - Cache

/// The scenes and zoom boxes of the last few trees drawn. The garden shows a
/// centrepiece and up to six grove trees at once, each redrawn every frame.
final class BonsaiSceneCache: @unchecked Sendable {
    struct Key: Hashable { var style: BonsaiStyle; var day: Int; var detail: Int; var vitality: Double }
    struct RectKey: Hashable { var style: BonsaiStyle; var day: Int }

    static let shared = BonsaiSceneCache()

    private let lock = NSLock()
    private var scenes = Recent<Key, BonsaiScene>(limit: 16)
    private var rects = Recent<RectKey, CGRect>(limit: 64)

    func scene(_ key: Key, build: () -> BonsaiScene) -> BonsaiScene {
        if let s = lock.withLock({ scenes[key] }) { return s }
        // Built outside the lock: two threads may both build one, which is harmless.
        let s = build()
        lock.withLock { scenes[key] = s }
        return s
    }

    func rect(_ key: RectKey, build: () -> CGRect) -> CGRect {
        if let r = lock.withLock({ rects[key] }) { return r }
        let r = build()
        lock.withLock { rects[key] = r }
        return r
    }
}

/// A small dictionary that forgets the least recently used entry.
private struct Recent<K: Hashable, V> {
    let limit: Int
    private var items: [K: V] = [:]
    private var order: [K] = []

    init(limit: Int) { self.limit = limit }

    subscript(key: K) -> V? {
        mutating get {
            guard let v = items[key] else { return nil }
            if order.last != key, let i = order.firstIndex(of: key) {
                order.remove(at: i)
                order.append(key)
            }
            return v
        }
        set {
            guard let newValue else { return }
            if items.updateValue(newValue, forKey: key) == nil {
                order.append(key)
                if order.count > limit { items[order.removeFirst()] = nil }
            }
        }
    }
}
