import Foundation

/// Bonsai visual style. Only `.traditional` has a delivered illustration set
/// (Claude Design round 1); `.cascade` / `.windswept` fall back to traditional
/// rendering until their anchor sets land.
enum BonsaiStyle: String, CaseIterable, Sendable {
    case traditional
    case cascade
    case windswept

    var displayName: String {
        switch self {
        case .traditional: return "Traditional"
        case .cascade: return "Cascading"
        case .windswept: return "Windswept"
        }
    }
}
