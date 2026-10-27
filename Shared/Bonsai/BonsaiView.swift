import Foundation

/// Bonsai visual style. Each has its own native renderer in `BonsaiRenderer`.
/// `.sakura` is a cherry-blossom tree (Claude Design) with a distinct
/// single-fork trunk, blossom canopy, falling petals, and celadon pot.
enum BonsaiStyle: String, CaseIterable, Sendable {
    case traditional
    case cascade
    case windswept
    case sakura
    case maple
    case pine

    var displayName: String {
        switch self {
        case .traditional: return String(localized: "Traditional")
        case .cascade: return String(localized: "Cascading")
        case .windswept: return String(localized: "Windswept")
        case .sakura: return String(localized: "Cherry Blossom")
        case .maple: return String(localized: "Japanese Maple")
        case .pine: return String(localized: "Black Pine")
        }
    }
}
