import Foundation
import SwiftUI

enum GardenItemType: String, Codable, CaseIterable, Sendable {
    /// The centerpiece tree style (only one active at a time)
    case bonsai
    /// Companion plants flanking the bonsai
    case plant
    /// Small non-living items (lanterns, stones, etc.)
    case decoration
    /// Large scene-defining items (ponds, pagodas, paths)
    case feature
    /// Ground texture replacement
    case ground

    var displayCategory: String {
        switch self {
        case .bonsai: return "Bonsai Styles"
        case .plant: return "Companion Plants"
        case .decoration: return "Decorations"
        case .feature: return "Garden Features"
        case .ground: return "Ground Covers"
        }
    }
}

enum GardenItemSize: String, Codable, Sendable {
    case small
    case medium
    case large
}

struct GardenItem: Identifiable, Hashable, Sendable {
    let id: String
    let type: GardenItemType
    let size: GardenItemSize
    let displayName: String
    let description: String
    let milestoneDays: Int            // days sober required to unlock
    let sfSymbol: String
    let colors: [Color]               // primary rendering colors
}

// MARK: - Catalog

/// The garden is one bonsai that grows daily. Bloom+ is the *only* gate: it
/// unlocks every species and lets the subscriber swap freely. Days no longer
/// gate anything here — they drive the tree's growth, not what you can pick.
/// `milestoneDays` on each species is retained purely as a stable display order.
enum GardenItemCatalog: Sendable {
    /// The one species a free user gets. Everything else is Bloom+.
    static let freeSpeciesID = "traditional-bonsai"

    /// Every bonsai species, in gallery order (free one first).
    static let all: [GardenItem] = [
        GardenItem(
            id: "traditional-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Traditional Bonsai",
            description: "A timeless upright bonsai. Symmetrical, balanced, serene.",
            milestoneDays: 0,
            sfSymbol: "leaf.fill",
            colors: [Color(red: 0.32, green: 0.52, blue: 0.28), Color(red: 0.45, green: 0.28, blue: 0.12)]
        ),
        GardenItem(
            id: "cascade-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Cascading Bonsai",
            description: "The cascade style mimics a tree growing on a cliff, plunging downward.",
            milestoneDays: 1,
            sfSymbol: "arrow.down.to.line.compact",
            colors: [Color(red: 0.28, green: 0.48, blue: 0.22), Color(red: 0.40, green: 0.24, blue: 0.10)]
        ),
        GardenItem(
            id: "sakura-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Cherry Blossom",
            description: "A flowering sakura wrapped in soft pink bloom. Petals drift down as your streak grows.",
            milestoneDays: 2,
            sfSymbol: "camera.macro",
            colors: [Color(red: 0.95, green: 0.70, blue: 0.80), Color(red: 0.49, green: 0.36, blue: 0.27)]
        ),
        GardenItem(
            id: "maple-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Japanese Maple",
            description: "A lacy maple in warm autumn red and gold. Star-shaped leaves drift down as the days add up.",
            milestoneDays: 3,
            sfSymbol: "leaf.fill",
            colors: [Color(red: 0.78, green: 0.28, blue: 0.16), Color(red: 0.43, green: 0.35, blue: 0.29)]
        ),
        GardenItem(
            id: "pine-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Black Pine",
            description: "An evergreen pine with cloud-like needle tiers and a gnarled, weathered trunk.",
            milestoneDays: 4,
            sfSymbol: "tree.fill",
            colors: [Color(red: 0.18, green: 0.38, blue: 0.29), Color(red: 0.35, green: 0.27, blue: 0.21)]
        ),
        GardenItem(
            id: "windswept-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Windswept Bonsai",
            description: "Shaped by a lifetime of wind. Every branch tells a story of endurance.",
            milestoneDays: 5,
            sfSymbol: "wind",
            colors: [Color(red: 0.22, green: 0.38, blue: 0.16), Color(red: 0.50, green: 0.30, blue: 0.12)]
        ),
    ]

    /// Bonsai species the user can switch between, gallery order.
    static var species: [GardenItem] { all }

    /// Species locked behind Bloom+ (everything except the free one).
    static var premiumSpecies: [GardenItem] { all.filter { $0.id != freeSpeciesID } }

    static func item(id: String) -> GardenItem? {
        all.first { $0.id == id }
    }

    static func isFreeSpecies(_ id: String) -> Bool {
        id == freeSpeciesID
    }

    /// Whether the user may switch to this species: Bloom+ unlocks them all;
    /// free users only get the one free species.
    static func canUseSpecies(id: String, isPro: Bool) -> Bool {
        isPro || isFreeSpecies(id)
    }
}
