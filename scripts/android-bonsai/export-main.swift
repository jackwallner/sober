import SwiftUI

// Records the real Swift bonsai scenes for the Android parity tests. Built by
// scripts/sync-android-bonsai.py together with Shared/Bonsai/*.swift (BonsaiScene.swift with its
// recorded layers made readable, BonsaiWind.swift with its bend shear captured).
//
// usage: export <out.jsonl> <vitality> <scale> <styles|all> <days|all>
//        export <out.jsonl> wind
//
// Per scene it writes, for every recorded layer, the ink, clip and motion indices, and how much of
// a 2 unit sampling grid over the 600x600 design square the layer covers (count and centroid).
// Coverage is measured on the path with its clip chain applied, so it does not depend on how the
// path was built (Android combines booleans with PathOperation, SwiftUI with Path.union).

let grid = 2.0
// Offset so the cell centres never fall exactly on the integer edges most shapes have.
let gridX = 0.137, gridY = 0.291
let cells = Int(600 / grid)

func r(_ v: Double) -> Double { (v * 100_000).rounded() / 100_000 }

func rgba(_ c: Color) -> [Double] {
    let x = c.resolve(in: EnvironmentValues())
    return [r(Double(x.red)), r(Double(x.green)), r(Double(x.blue)), r(Double(x.opacity))]
}

func inkJSON(_ ink: BonsaiInk) -> Any {
    switch ink.kind {
    case .color(let c): return rgba(c)
    case .linear(let g, let a, let b):
        return ["g": g.stops.map { rgba($0.color) }, "s": [r(a.x), r(a.y), r(b.x), r(b.y)]]
    }
}

// SwiftUI's Path.contains is conservative on curves (it tests a curve's control points), so the
// sampling goes through CGPath, whose containment test is exact.
func covers(_ path: Path, _ clips: [(path: CGPath, inverse: Bool, box: CGRect)]) -> (count: Int, sx: Double, sy: Double) {
    let cg = path.cgPath
    var box = path.boundingRect
    for c in clips where !c.inverse { box = box.intersection(c.box) }
    guard !box.isNull, box.width >= 0, box.height >= 0 else { return (0, 0, 0) }
    let i0 = max(0, Int(((box.minX - gridX) / grid - 0.5).rounded(.up))), i1 = min(cells - 1, Int(((box.maxX - gridX) / grid - 0.5).rounded(.down)))
    let j0 = max(0, Int(((box.minY - gridY) / grid - 0.5).rounded(.up))), j1 = min(cells - 1, Int(((box.maxY - gridY) / grid - 0.5).rounded(.down)))
    guard i0 <= i1, j0 <= j1 else { return (0, 0, 0) }
    var count = 0, sx = 0.0, sy = 0.0
    for j in j0...j1 {
        for i in i0...i1 {
            let p = CGPoint(x: (Double(i) + 0.5) * grid + gridX, y: (Double(j) + 0.5) * grid + gridY)
            guard cg.contains(p) else { continue }
            var inside = true
            for c in clips where c.path.contains(p) == c.inverse { inside = false; break }
            if inside { count += 1; sx += p.x; sy += p.y }
        }
    }
    return (count, count > 0 ? sx / Double(count) : 0, count > 0 ? sy / Double(count) : 0)
}

func motionJSON(_ m: BonsaiMotion) -> [Any] {
    switch m {
    case .still: return ["still"]
    case .bent: return ["bent"]
    case .drift(let p): return ["drift", r(p.x), r(p.y)]
    case .limb(let a, let b): return ["limb", r(a.x), r(a.y), r(b.x), r(b.y)]
    }
}

func frameJSON(style: BonsaiStyle, day: Int, vitality: Double, scale: Double) -> [String: Any] {
    let scene = bonsaiScene(day: day, style: style, vitality: vitality, scale: scale)
    let rect = bonsaiContentRect(day: day, style: style)
    let chains = scene.clips.map { chain in chain.map { (path: $0.path.cgPath, inverse: $0.inverse, box: $0.path.boundingRect) } }
    let layers: [[Any]] = scene.layers.map { l in
        let c = covers(l.path, chains[l.clip])
        return [l.clip, l.motion, inkJSON(l.ink), c.count, r(c.sx), r(c.sy)]
    }
    let clips: [[Any]] = scene.clips.map { chain in
        chain.map { c in
            let b = c.path.boundingRect
            return [c.inverse ? 1 : 0, r(b.minX), r(b.minY), r(b.maxX), r(b.maxY)] as [Any]
        }
    }
    return [
        "style": style.rawValue, "day": day, "vitality": vitality, "scale": scale,
        "rect": [r(rect.minX), r(rect.minY), r(rect.width), r(rect.height)],
        "pivot": [r(scene.pivot.x), r(scene.pivot.y)], "sprout": scene.sprout,
        "motions": scene.motions.map(motionJSON), "clips": clips, "layers": layers,
    ]
}

@MainActor
func windJSON() -> [[String: Any]] {
    var out: [[String: Any]] = []
    let pivot = CGPoint(x: 300, y: 410)
    for t in [0.0, 731.0, 2400.0, 5600.0, 9000.0, 17_333.0, 61_000.0] {
        let wind = BonsaiWind(t: t)
        var entry: [String: Any] = ["t": t]
        for sprout in [false, true] {
            exportedShear = 0
            let view = Canvas { ctx, _ in
                var c = ctx
                wind.bend(&c, pivot: pivot, sprout: sprout)
            }.frame(width: 4, height: 4)
            let renderer = ImageRenderer(content: view)
            _ = renderer.cgImage
            entry[sprout ? "bendSprout" : "bend"] = exportedShear
        }
        entry["drift"] = [(150.0, 250.0), (300.0, 410.0), (410.0, 120.0)].map { p -> [Double] in
            let d = wind.drift(p.0, p.1, pivot: pivot)
            return [p.0, p.1, d.width, d.height]
        }
        entry["fall"] = [(0.2, 0.9, 280.0, 240.0, 409.0, 40.0), (0.77, 0.1, 330.0, 200.0, 412.0, -75.0), (0.5, 0.5, 300.0, 300.0, 408.0, 0.0)]
            .map { a -> [Double] in
                let f = wind.fall(seed: a.0, pace: a.1, x: a.2, top: a.3, bottom: a.4, rotDeg: a.5)
                return [a.0, a.1, a.2, a.3, a.4, a.5, f.x, f.y, f.rotDeg, f.opacity]
            }
        out.append(entry)
    }
    return out
}

@MainActor
func run() throws {
    let args = CommandLine.arguments
    let output = URL(fileURLWithPath: args[1])
    var lines = Data()
    func put(_ object: Any) throws {
        lines.append(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
        lines.append(10)
    }
    if args[2] == "wind" {
        for entry in windJSON() { try put(entry) }
    } else {
        let vitality = Double(args[2])!
        let scale = Double(args[3])!
        let styles = args[4] == "all"
            ? BonsaiStyle.allCases
            : args[4].split(separator: ",").map { BonsaiStyle(rawValue: String($0))! }
        let days: [Int] = args[5] == "all" ? Array(0...365) : args[5].split(separator: ",").map { Int($0)! }
        for style in styles {
            for day in days { try put(frameJSON(style: style, day: day, vitality: vitality, scale: scale)) }
        }
    }
    try lines.write(to: output)
}

MainActor.assumeIsolated { try! run() }
