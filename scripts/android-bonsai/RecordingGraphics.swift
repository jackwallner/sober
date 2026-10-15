import CoreGraphics
import Foundation

// Record the original Swift drawing code as portable native-canvas commands.
// These types shadow SwiftUI's drawing types only in this standalone exporter.
struct Color {
    let red: Double
    let green: Double
    let blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func opacity(_ amount: Double) -> Color {
        var copy = self
        copy.alpha *= amount
        return copy
    }

    var values: [Double] { [red, green, blue, alpha] }
}

struct Gradient { let colors: [Color] }
struct Angle {
    let radians: Double
    static func degrees(_ value: Double) -> Angle { Angle(radians: value * .pi / 180) }
}

enum LineCap { case butt, round, square }
struct StrokeStyle {
    let lineWidth: Double
    var lineCap: LineCap = .butt
}

struct Path {
    var values: [Double] = []

    init() {}
    init(ellipseIn rect: CGRect) {
        values = [4, rect.minX, rect.minY, rect.width, rect.height]
    }

    mutating func move(to point: CGPoint) { values += [0, point.x, point.y] }
    mutating func addLine(to point: CGPoint) { values += [1, point.x, point.y] }
    mutating func addQuadCurve(to point: CGPoint, control: CGPoint) {
        values += [2, control.x, control.y, point.x, point.y]
    }
    mutating func closeSubpath() { values += [3] }

    var boundingRect: CGRect {
        let path = CGMutablePath()
        var index = 0
        while index < values.count {
            let operation = Int(values[index])
            index += 1
            switch operation {
            case 0:
                path.move(to: CGPoint(x: values[index], y: values[index + 1]))
                index += 2
            case 1:
                path.addLine(to: CGPoint(x: values[index], y: values[index + 1]))
                index += 2
            case 2:
                path.addQuadCurve(to: CGPoint(x: values[index + 2], y: values[index + 3]),
                                  control: CGPoint(x: values[index], y: values[index + 1]))
                index += 4
            case 3:
                path.closeSubpath()
            case 4:
                path.addEllipse(in: CGRect(x: values[index], y: values[index + 1],
                                          width: values[index + 2], height: values[index + 3]))
                index += 4
            default:
                fatalError("Unsupported path command")
            }
        }
        return path.boundingBoxOfPath
    }
}

enum Paint {
    case color(Color)
    case linearGradient(Gradient, startPoint: CGPoint, endPoint: CGPoint)
}

final class DrawingRecord {
    var commands: [[String: Any]] = []
}

struct GraphicsContext {
    let record: DrawingRecord
    var transform = CGAffineTransform.identity
    var opacity: Double = 1

    mutating func translateBy(x: Double, y: Double) { transform = transform.translatedBy(x: x, y: y) }
    mutating func scaleBy(x: Double, y: Double) { transform = transform.scaledBy(x: x, y: y) }
    mutating func rotate(by angle: Angle) { transform = transform.rotated(by: angle.radians) }

    func fill(_ path: Path, with paint: Paint) { append(path, paint: paint, width: nil) }
    func stroke(_ path: Path, with paint: Paint, style: StrokeStyle) {
        append(path, paint: paint, width: style.lineWidth, cap: style.lineCap)
    }
    func stroke(_ path: Path, with paint: Paint, lineWidth: Double) {
        append(path, paint: paint, width: lineWidth)
    }

    private func append(_ path: Path, paint: Paint, width: Double?, cap: LineCap = .butt) {
        var command: [String: Any] = [
            "p": path.values.map { ($0 * 1000).rounded() / 1000 },
            "t": [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map(rounded),
            "o": rounded(opacity),
        ]
        switch paint {
        case .color(let color):
            command["c"] = color.values.map(rounded)
        case .linearGradient(let gradient, let start, let end):
            command["g"] = gradient.colors.map { $0.values.map(rounded) }
            command["s"] = [start.x, start.y, end.x, end.y].map(rounded)
        }
        if let width {
            command["w"] = rounded(width)
            command["cap"] = cap == .round ? 1 : (cap == .square ? 2 : 0)
        }
        record.commands.append(command)
    }
}

private func rounded(_ value: Double) -> Double { (value * 100_000).rounded() / 100_000 }

enum BonsaiStyle: String, CaseIterable {
    case traditional, cascade, windswept, sakura, maple, pine
}
