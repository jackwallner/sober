import Foundation

/// Bonsai visual style. Each has its own native renderer in `BonsaiRenderer`.
/// `.sakura` is a cherry-blossom tree (Claude Design) with a distinct
/// single-fork trunk, blossom canopy, falling petals, and celadon pot.
enum BonsaiStyle: String, CaseIterable, Sendable {
    case traditional
    case cascade
    case windswept
    case sakura

    var displayName: String {
        switch self {
        case .traditional: return "Traditional"
        case .cascade: return "Cascading"
        case .windswept: return "Windswept"
        case .sakura: return "Cherry Blossom"
        }
    }
}
