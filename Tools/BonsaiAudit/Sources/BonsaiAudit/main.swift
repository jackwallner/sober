import AppKit
import SwiftUI

// Headless audit of BonsaiRenderer. Renders the real shipping Canvas code and
// measures six failure modes:
//
//   1. DETACHED   structural piece not connected to the main silhouette.
//   2. HOLE       background pocket fully enclosed by ink.
//   3. HAIRLINE   join that breaks when the mask is eroded by r pt.
//   4. CLIPPED    ink running off the frame edge (fill-mode zoom cropping).
//   5. POP        day-over-day jump in area or centroid (growth discontinuity).
//   6. FADED      a piece visible at alpha cut 40 but gone at cut 128, i.e. it
//                 only just survives the vitality/opacity stack.
//
// Configs cover the real call sites: 600pt design square (geometry truth),
// the home centerpiece and grove/collection thumbnails at fill:true, and
// vitality 0.3 (the floor GardenService decays to) as well as 1.0.

struct Config {
    var name: String
    var frame: Double        // pt the view is given
    var fill: Bool
    var vitality: Double
    var scale: Double        // render scale (device @3x etc.)
    var px: Int { Int(frame * scale) }
    /// Design pt per rendered px, used to convert measurements back to design space.
    var designPerPx: Double { 600.0 / (frame * scale) }
}

let configs: [Config] = [
    Config(name: "design600",   frame: 600, fill: false, vitality: 1.0, scale: 2),
    Config(name: "home320",     frame: 320, fill: true,  vitality: 1.0, scale: 3),
    Config(name: "home320-dry", frame: 320, fill: true,  vitality: 0.3, scale: 3),
    Config(name: "grove44",     frame: 44,  fill: true,  vitality: 1.0, scale: 3),
    Config(name: "collect90",   frame: 90,  fill: true,  vitality: 1.0, scale: 3),
    Config(name: "timeline200", frame: 200, fill: false, vitality: 1.0, scale: 3),
]

let alphaMain: UInt8 = 90
let alphaLow: UInt8 = 40
let alphaHigh: UInt8 = 128

// MARK: - Render

@MainActor
func renderRGBA(style: BonsaiStyle, day: Int, cfg: Config) -> [UInt8]? {
    let view = BonsaiView(day: day, style: style, vitality: cfg.vitality, fill: cfg.fill)
        .frame(width: cfg.frame, height: cfg.frame)
    let renderer = ImageRenderer(content: view)
    renderer.scale = cfg.scale
    renderer.isOpaque = false
    guard let cg = renderer.cgImage else { return nil }
    let n = cfg.px
    var buf = [UInt8](repeating: 0, count: n * n * 4)
    guard let ctx = CGContext(
        data: &buf, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
    return buf
}

// MARK: - Grid helpers (size passed explicitly so configs can differ)

struct Component {
    var label = 0, area = 0
    var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
    var sumX = 0, sumY = 0
}

func components(_ mask: [Bool], _ n: Int, connectivity8: Bool = true) -> (labels: [Int], comps: [Component]) {
    var labels = [Int](repeating: 0, count: n * n)
    var comps: [Component] = []
    var stack: [Int] = []
    stack.reserveCapacity(1 << 16)
    var next = 0
    for start in 0..<(n * n) where mask[start] && labels[start] == 0 {
        next += 1
        var c = Component(label: next)
        labels[start] = next
        stack.append(start)
        while let idx = stack.popLast() {
            let x = idx % n, y = idx / n
            c.area += 1; c.sumX += x; c.sumY += y
            c.minX = min(c.minX, x); c.maxX = max(c.maxX, x)
            c.minY = min(c.minY, y); c.maxY = max(c.maxY, y)
            for dy in -1...1 {
                let ny = y + dy
                if ny < 0 || ny >= n { continue }
                for dx in -1...1 {
                    if !connectivity8 && dx != 0 && dy != 0 { continue }
                    let nx = x + dx
                    if nx < 0 || nx >= n { continue }
                    let m = ny * n + nx
                    if mask[m] && labels[m] == 0 { labels[m] = next; stack.append(m) }
                }
            }
        }
        comps.append(c)
    }
    return (labels, comps)
}

func distance(_ n: Int, seed: (Int) -> Bool) -> [Double] {
    let big = 1 << 28
    var d = [Int](repeating: big, count: n * n)
    for i in 0..<(n * n) where seed(i) { d[i] = 0 }
    @inline(__always) func relax(_ i: Int, _ j: Int, _ w: Int) {
        let v = d[j] + w; if v < d[i] { d[i] = v }
    }
    for y in 0..<n {
        for x in 0..<n {
            let i = y * n + x
            if d[i] == 0 { continue }
            if y > 0 {
                relax(i, i - n, 3)
                if x > 0 { relax(i, i - n - 1, 4) }
                if x < n - 1 { relax(i, i - n + 1, 4) }
            }
            if x > 0 { relax(i, i - 1, 3) }
        }
    }
    for y in stride(from: n - 1, through: 0, by: -1) {
        for x in stride(from: n - 1, through: 0, by: -1) {
            let i = y * n + x
            if d[i] == 0 { continue }
            if y < n - 1 {
                relax(i, i + n, 3)
                if x < n - 1 { relax(i, i + n + 1, 4) }
                if x > 0 { relax(i, i + n - 1, 4) }
            }
            if x < n - 1 { relax(i, i + 1, 3) }
        }
    }
    return d.map { Double($0) / 3.0 }
}

// MARK: - Findings

struct Piece { var areaPt: Double, cx: Double, cy: Double, gapPt: Double }

struct DayReport {
    var config: String, style: BonsaiStyle, day: Int
    var mainAreaPt: Double = 0
    var detached: [Piece] = []
    var detachedLowAlpha = 0        // count at the permissive threshold
    var detachedHighAlpha = 0       // count at the strict threshold
    var specks = 0
    var holes: [Piece] = []
    var hairlineAt: Double = 0
    var clippedEdgePx = 0           // ink pixels touching the frame border
    var areaJumpPct: Double = 0     // vs previous sampled day
    var centroidJumpPt: Double = 0
    var flagged: Bool {
        !detached.isEmpty || !holes.isEmpty || hairlineAt > 0 || clippedEdgePx > 0
    }
}

let structuralPt: Double = 400     // design pt^2 — a real limb/blob
let speckPt: Double = 8
let erodeRadii: [Double] = [1, 2, 3]

/// Count of disconnected structural components at a given alpha threshold.
func detachedCount(_ rgba: [UInt8], _ n: Int, _ cut: UInt8, _ areaScale: Double) -> Int {
    var mask = [Bool](repeating: false, count: n * n)
    for i in 0..<(n * n) { mask[i] = rgba[i * 4 + 3] >= cut }
    let (_, comps) = components(mask, n)
    guard let main = comps.max(by: { $0.area < $1.area }) else { return 0 }
    return comps.filter { $0.label != main.label && Double($0.area) * areaScale >= structuralPt }.count
}

@MainActor
func audit(style: BonsaiStyle, day: Int, cfg: Config, prev: (Double, Double, Double)?,
           dumpTo: String?) -> (DayReport, (Double, Double, Double))? {
    guard let rgba = renderRGBA(style: style, day: day, cfg: cfg) else { return nil }
    let n = cfg.px
    let dpp = cfg.designPerPx
    let areaScale = dpp * dpp          // px^2 -> design pt^2

    var mask = [Bool](repeating: false, count: n * n)
    for i in 0..<(n * n) { mask[i] = rgba[i * 4 + 3] >= alphaMain }
    let (labels, comps) = components(mask, n)
    guard let main = comps.max(by: { $0.area < $1.area }) else { return nil }

    var r = DayReport(config: cfg.name, style: style, day: day)
    r.mainAreaPt = Double(main.area) * areaScale

    // 1. Detached structural pieces.
    let others = comps.filter { $0.label != main.label && Double($0.area) * areaScale >= speckPt }
    let structural = others.filter { Double($0.area) * areaScale >= structuralPt }
    r.specks = others.count - structural.count
    if !structural.isEmpty {
        let dist = distance(n) { labels[$0] == main.label }
        for c in structural {
            var best = Double.infinity
            for y in c.minY...c.maxY {
                for x in c.minX...c.maxX where labels[y * n + x] == c.label {
                    best = min(best, dist[y * n + x])
                }
            }
            r.detached.append(Piece(areaPt: Double(c.area) * areaScale,
                                    cx: Double(c.sumX) / Double(c.area) * dpp,
                                    cy: Double(c.sumY) / Double(c.area) * dpp,
                                    gapPt: best * dpp))
        }
        r.detached.sort { $0.areaPt > $1.areaPt }
    }

    // 6. Alpha sensitivity.
    r.detachedLowAlpha = detachedCount(rgba, n, alphaLow, areaScale)
    r.detachedHighAlpha = detachedCount(rgba, n, alphaHigh, areaScale)

    // 2. Interior holes.
    let (bgLabels, bgComps) = components(mask.map { !$0 }, n, connectivity8: false)
    var borderLabels = Set<Int>()
    for x in 0..<n { borderLabels.insert(bgLabels[x]); borderLabels.insert(bgLabels[(n - 1) * n + x]) }
    for y in 0..<n { borderLabels.insert(bgLabels[y * n]); borderLabels.insert(bgLabels[y * n + n - 1]) }
    var holeLabels = Set<Int>()
    for c in bgComps where !borderLabels.contains(c.label) && Double(c.area) * areaScale >= speckPt * 4 {
        holeLabels.insert(c.label)
        r.holes.append(Piece(areaPt: Double(c.area) * areaScale,
                             cx: Double(c.sumX) / Double(c.area) * dpp,
                             cy: Double(c.sumY) / Double(c.area) * dpp, gapPt: 0))
    }
    r.holes.sort { $0.areaPt > $1.areaPt }

    // 3. Hairline joins.
    let inward = distance(n) { !mask[$0] }
    let baseFrag = comps.filter { Double($0.area) * areaScale >= structuralPt }.count
    for radius in erodeRadii {
        let px = radius / dpp
        var eroded = [Bool](repeating: false, count: n * n)
        for i in 0..<(n * n) { eroded[i] = inward[i] > px }
        let (_, ec) = components(eroded, n)
        if ec.filter({ Double($0.area) * areaScale >= structuralPt }).count > baseFrag {
            r.hairlineAt = radius
            break
        }
    }

    // 4. Clipping: ink on the frame border. Fill mode deliberately bottom-
    // anchors the pot against the bottom edge, so that side never counts.
    var edge = 0
    for x in 0..<n {
        if mask[x] { edge += 1 }
        if !cfg.fill && mask[(n - 1) * n + x] { edge += 1 }
    }
    for y in 1..<(n - 1) {
        if mask[y * n] { edge += 1 }
        if mask[y * n + n - 1] { edge += 1 }
    }
    r.clippedEdgePx = edge > 2 ? edge : 0

    // 5. Day-over-day pop.
    let totalArea = comps.reduce(0.0) { $0 + Double($1.area) * areaScale }
    let cx = Double(main.sumX) / Double(main.area) * dpp
    let cy = Double(main.sumY) / Double(main.area) * dpp
    if let (pa, pcx, pcy) = prev, pa > 0 {
        r.areaJumpPct = (totalArea - pa) / pa * 100
        r.centroidJumpPt = hypot(cx - pcx, cy - pcy)
    }

    if let path = dumpTo, r.flagged {
        var buf = rgba
        let detLabels = Set(structural.map(\.label))
        for i in 0..<(n * n) {
            let a = Double(buf[i * 4 + 3]) / 255
            let isDet = detLabels.contains(labels[i])
            let isHole = labels[i] == 0 && holeLabels.contains(bgLabels[i])
            for ch in 0..<3 {
                var v = Double(buf[i * 4 + ch]) + 255 * (1 - a)
                if isDet { v = ch == 1 ? v * 0.25 : min(255, v * 0.4 + 190) }
                if isHole { v = ch == 2 ? v * 0.2 : (ch == 0 ? min(255, v * 0.3 + 200) : v * 0.5) }
                buf[i * 4 + ch] = UInt8(max(0, min(255, v)))
            }
            buf[i * 4 + 3] = 255
        }
        buf.withUnsafeMutableBytes { raw in
            let c = CGContext(data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8,
                              bytesPerRow: n * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
            try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
        }
    }
    return (r, (totalArea, cx, cy))
}

// MARK: - Main

let args = CommandLine.arguments
let stride_ = Int(args.first(where: { $0.hasPrefix("--stride=") })?.dropFirst(9) ?? "") ?? 1
let outDir = args.first(where: { $0.hasPrefix("--out=") })?.dropFirst(6).description
    ?? FileManager.default.currentDirectoryPath + "/audit-out"
let onlyStyle = args.first(where: { $0.hasPrefix("--style=") })?.dropFirst(8).description
let onlyCfg = args.first(where: { $0.hasPrefix("--config=") })?.dropFirst(9).description
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Pops are only meaningful when consecutive days are actually sampled.
let popAreaPct = 12.0
let popCentroidPt = 10.0

// MARK: - bbox mode: declared content rect vs. actually drawn ink
//
// Renders in design space (fill:false, no zoom, nothing clipped), measures the
// true ink bounding box, and compares it to what `bonsaiContentRect` claims.
// Positive overflow on a side = that side gets cropped in fill mode.

@MainActor
func bboxMode(_ styles: [BonsaiStyle], stride: Int, outDir: String) {
    let cfg = Config(name: "design600", frame: 600, fill: false, vitality: 1.0, scale: 2)
    let n = cfg.px, dpp = cfg.designPerPx
    var csv = "style,day,ink_minX,ink_minY,ink_maxX,ink_maxY,rect_minX,rect_minY,rect_maxX,rect_maxY,over_left,over_top,over_right,over_bottom,over_pct\n"
    var worst: [String: (Double, Int, String)] = [:]
    for style in styles {
        var days = Array(Swift.stride(from: 0, through: 365, by: stride))
        if days.last != 365 { days.append(365) }
        for day in days {
            guard let rgba = renderRGBA(style: style, day: day, cfg: cfg) else { continue }
            var lo = CGPoint(x: 1e9, y: 1e9), hi = CGPoint(x: -1e9, y: -1e9)
            for y in 0..<n {
                for x in 0..<n where rgba[(y * n + x) * 4 + 3] >= alphaMain {
                    lo.x = min(lo.x, Double(x) * dpp); hi.x = max(hi.x, Double(x) * dpp)
                    lo.y = min(lo.y, Double(y) * dpp); hi.y = max(hi.y, Double(y) * dpp)
                }
            }
            if lo.x > hi.x { continue }
            let r = bonsaiContentRect(day: day, style: style)
            let oL = Double(r.minX) - lo.x, oT = Double(r.minY) - lo.y
            let oR = hi.x - Double(r.maxX), oB = hi.y - Double(r.maxY)
            let pct = max(max(oL, oR) / Double(r.width), max(oT, oB) / Double(r.height)) * 100
            csv += String(format: "%@,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n",
                          style.rawValue, day, lo.x, lo.y, hi.x, hi.y,
                          r.minX, r.minY, r.maxX, r.maxY, oL, oT, oR, oB, pct)
            if pct > (worst[style.rawValue]?.0 ?? -1e9) {
                worst[style.rawValue] = (pct, day, String(format: "L%.1f T%.1f R%.1f B%.1f", oL, oT, oR, oB))
            }
        }
        FileHandle.standardError.write("bbox \(style.rawValue) done\n".data(using: .utf8)!)
    }
    try? csv.write(toFile: outDir + "/bbox.csv", atomically: true, encoding: .utf8)
    print("style        worst_overflow  day   sides(pt, + = cropped)")
    for style in styles {
        guard let w = worst[style.rawValue] else { continue }
        print(String(format: "%-12@ %+8.1f%%      %3d   %@", style.rawValue, w.0, w.1, w.2))
    }
}

if args.contains("--mode=bbox") {
    MainActor.assumeIsolated {
        bboxMode(BonsaiStyle.allCases.filter { onlyStyle == nil || $0.rawValue == onlyStyle! },
                 stride: stride_, outDir: outDir)
    }
    exit(0)
}

MainActor.assumeIsolated {
    var csv = "config,style,day,main_area_pt,detached,detached_area_pt,max_gap_pt,worst_cx,worst_cy,specks,det_alpha40,det_alpha128,holes,hole_area_pt,hairline_pt,clipped_edge_px,area_jump_pct,centroid_jump_pt\n"
    var all: [DayReport] = []
    let styles = BonsaiStyle.allCases.filter { onlyStyle == nil || $0.rawValue == onlyStyle! }
    let cfgs = configs.filter { onlyCfg == nil || $0.name == onlyCfg! }

    for cfg in cfgs {
        for style in styles {
            var days = Array(Swift.stride(from: 0, through: 365, by: stride_))
            if days.last != 365 { days.append(365) }
            var prev: (Double, Double, Double)? = nil
            for day in days {
                let dump = outDir + "/flag-\(cfg.name)-\(style.rawValue)-d\(String(format: "%03d", day)).png"
                guard let (r, state) = audit(style: style, day: day, cfg: cfg, prev: prev, dumpTo: dump)
                else { continue }
                prev = state
                all.append(r)
                let w = r.detached.first
                csv += String(format: "%@,%@,%d,%.0f,%d,%.0f,%.2f,%.1f,%.1f,%d,%d,%d,%d,%.0f,%.1f,%d,%.2f,%.2f\n",
                              cfg.name, style.rawValue, day, r.mainAreaPt, r.detached.count,
                              r.detached.reduce(0) { $0 + $1.areaPt }, r.detached.map(\.gapPt).max() ?? 0,
                              w?.cx ?? 0, w?.cy ?? 0, r.specks, r.detachedLowAlpha, r.detachedHighAlpha,
                              r.holes.count, r.holes.reduce(0) { $0 + $1.areaPt },
                              r.hairlineAt, r.clippedEdgePx, r.areaJumpPct, r.centroidJumpPt)
            }
            FileHandle.standardError.write("\(cfg.name)/\(style.rawValue) done\n".data(using: .utf8)!)
        }
    }
    try? csv.write(toFile: outDir + "/report.csv", atomically: true, encoding: .utf8)

    func ranges(_ days: [Int]) -> String {
        guard !days.isEmpty else { return "none" }
        var out: [String] = []; var s = days[0]; var p = days[0]
        for d in days.dropFirst() {
            if d - p <= stride_ { p = d } else { out.append(s == p ? "\(s)" : "\(s)–\(p)"); s = d; p = d }
        }
        out.append(s == p ? "\(s)" : "\(s)–\(p)")
        return out.joined(separator: ", ")
    }

    var md = "# Bonsai silhouette audit\n\nday stride \(stride_) · structural ≥ \(Int(structuralPt))pt² · alpha \(alphaMain)/255 (sensitivity at \(alphaLow) and \(alphaHigh))\n\n"
    md += "| config | frame | fill | vit | detached | holes | hairline | clipped | pops | clean |\n|---|---|---|---|---|---|---|---|---|---|\n"
    for cfg in cfgs {
        let rs = all.filter { $0.config == cfg.name }
        guard !rs.isEmpty else { continue }
        let pops = rs.filter { abs($0.areaJumpPct) > popAreaPct || $0.centroidJumpPt > popCentroidPt }
        md += String(format: "| %@ | %.0fpt | %@ | %.1f | %d | %d | %d | %d | %d | %d/%d |\n",
                     cfg.name, cfg.frame, cfg.fill ? "yes" : "no", cfg.vitality,
                     rs.filter { !$0.detached.isEmpty }.count,
                     rs.filter { !$0.holes.isEmpty }.count,
                     rs.filter { $0.hairlineAt > 0 }.count,
                     rs.filter { $0.clippedEdgePx > 0 }.count,
                     pops.count, rs.filter { !$0.flagged }.count, rs.count)
    }
    md += "\n"

    for cfg in cfgs {
        let cr = all.filter { $0.config == cfg.name }
        guard !cr.isEmpty else { continue }
        md += "## \(cfg.name)\n\n"
        for style in styles {
            let rs = cr.filter { $0.style == style }
            guard !rs.isEmpty else { continue }
            let det = rs.filter { !$0.detached.isEmpty }
            let hol = rs.filter { !$0.holes.isEmpty }
            let hair = rs.filter { $0.hairlineAt > 0 }
            let clip = rs.filter { $0.clippedEdgePx > 0 }
            let pops = rs.filter { abs($0.areaJumpPct) > popAreaPct || $0.centroidJumpPt > popCentroidPt }
            let alphaDiff = rs.filter { $0.detachedLowAlpha != $0.detachedHighAlpha }
            if det.isEmpty && hol.isEmpty && hair.isEmpty && clip.isEmpty && pops.isEmpty {
                md += "- **\(style.rawValue)**: clean\n"; continue
            }
            md += "- **\(style.rawValue)**"
            if !det.isEmpty {
                md += String(format: " · detached %@ (max gap %.1fpt, largest %.0fpt²)",
                             ranges(det.map(\.day)),
                             det.flatMap { $0.detached.map(\.gapPt) }.max() ?? 0,
                             det.flatMap { $0.detached.map(\.areaPt) }.max() ?? 0)
            }
            if !hol.isEmpty {
                md += String(format: " · holes %@ (max %.0fpt²)", ranges(hol.map(\.day)),
                             hol.flatMap { $0.holes.map(\.areaPt) }.max() ?? 0)
            }
            if !hair.isEmpty { md += " · hairline \(ranges(hair.map(\.day)))" }
            if !clip.isEmpty { md += " · CLIPPED \(ranges(clip.map(\.day)))" }
            if !pops.isEmpty {
                md += String(format: " · pops %@ (max area %+.0f%%, centroid %.1fpt)",
                             ranges(pops.map(\.day)),
                             pops.map(\.areaJumpPct).max(by: { abs($0) < abs($1) }) ?? 0,
                             pops.map(\.centroidJumpPt).max() ?? 0)
            }
            if !alphaDiff.isEmpty { md += " · alpha-sensitive \(ranges(alphaDiff.map(\.day)))" }
            md += "\n"
        }
        md += "\n"
    }
    try? md.write(toFile: outDir + "/flags.md", atomically: true, encoding: .utf8)
    print("flagged \(all.filter(\.flagged).count)/\(all.count) frames → \(outDir)/flags.md")
}
