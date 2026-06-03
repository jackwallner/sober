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

enum GardenItemCatalog: Sendable {
    /// Every unlockable item in the game, sorted by milestoneDays ascending.
    static let all: [GardenItem] = [
        // ── Day 0: Your first bonsai ──
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

        // ── Day 3: First taste (free to place) ──
        GardenItem(
            id: "moss",
            type: .ground,
            size: .medium,
            displayName: "Moss Ground",
            description: "A soft blanket of emerald moss settles around your bonsai.",
            milestoneDays: 3,
            sfSymbol: "circle.hexagongrid.fill",
            colors: [Color(red: 0.30, green: 0.62, blue: 0.36)]
        ),

        // ── Day 7 ──
        GardenItem(
            id: "river-stone",
            type: .decoration,
            size: .small,
            displayName: "River Stone",
            description: "A smooth, grey stone worn by centuries of water.",
            milestoneDays: 7,
            sfSymbol: "circle.fill",
            colors: [Color(red: 0.55, green: 0.55, blue: 0.55)]
        ),

        // ── Day 10 ──
        GardenItem(
            id: "bamboo",
            type: .plant,
            size: .medium,
            displayName: "Bamboo",
            description: "Tall green stalks that sway in the wind. A symbol of resilience.",
            milestoneDays: 10,
            sfSymbol: "leaf.arrow.triangle.circlepath",
            colors: [Color(red: 0.40, green: 0.72, blue: 0.38), Color(red: 0.25, green: 0.55, blue: 0.20)]
        ),

        // ── Day 14 ──
        GardenItem(
            id: "stone-lantern",
            type: .decoration,
            size: .medium,
            displayName: "Stone Lantern",
            description: "A traditional Tōrō lantern. Warm light glows through the window.",
            milestoneDays: 14,
            sfSymbol: "light.min",
            colors: [Color(red: 0.50, green: 0.45, blue: 0.38), Color(red: 0.90, green: 0.70, blue: 0.35)]
        ),

        // ── Day 21 ──
        GardenItem(
            id: "white-lotus",
            type: .plant,
            size: .small,
            displayName: "White Lotus",
            description: "A pure white flower rising from still water.",
            milestoneDays: 21,
            sfSymbol: "flower",
            colors: [Color.white, Color(red: 0.85, green: 0.92, blue: 0.85)]
        ),

        // ── Day 30 ──
        GardenItem(
            id: "cascade-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Cascading Bonsai",
            description: "The cascade style mimics a tree growing on a cliff, plunging downward.",
            milestoneDays: 30,
            sfSymbol: "arrow.down.to.line.compact",
            colors: [Color(red: 0.28, green: 0.48, blue: 0.22), Color(red: 0.40, green: 0.24, blue: 0.10)]
        ),

        // ── Day 45 ──
        GardenItem(
            id: "zen-garden",
            type: .ground,
            size: .large,
            displayName: "Zen Sand Garden",
            description: "Raked white sand with a single stone. Contemplation made visible.",
            milestoneDays: 45,
            sfSymbol: "circle.dotted",
            colors: [Color(red: 0.90, green: 0.88, blue: 0.80), Color(red: 0.75, green: 0.72, blue: 0.65)]
        ),

        // ── Day 60 ──
        GardenItem(
            id: "koi-pond",
            type: .feature,
            size: .large,
            displayName: "Koi Pond",
            description: "A small pond with two koi gliding beneath the surface.",
            milestoneDays: 60,
            sfSymbol: "water.waves",
            colors: [Color(red: 0.20, green: 0.50, blue: 0.65), Color(red: 0.90, green: 0.50, blue: 0.20)]
        ),

        // ── Day 90 ──
        GardenItem(
            id: "miniature-pine",
            type: .plant,
            size: .medium,
            displayName: "Miniature Pine",
            description: "A dwarf pine with dark needles. Dignified and ancient.",
            milestoneDays: 90,
            sfSymbol: "tree.fill",
            colors: [Color(red: 0.18, green: 0.40, blue: 0.18), Color(red: 0.30, green: 0.22, blue: 0.10)]
        ),

        // ── Day 100: Cherry blossom bonsai (Bloom+ species) ──
        GardenItem(
            id: "sakura-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Cherry Blossom",
            description: "A flowering sakura wrapped in soft pink bloom. Petals drift down as your streak grows.",
            milestoneDays: 100,
            sfSymbol: "camera.macro",
            colors: [Color(red: 0.95, green: 0.70, blue: 0.80), Color(red: 0.49, green: 0.36, blue: 0.27)]
        ),

        // ── Day 120 ──
        GardenItem(
            id: "moon-gate",
            type: .feature,
            size: .large,
            displayName: "Moon Gate",
            description: "A circular stone gate framing the garden beyond.",
            milestoneDays: 120,
            sfSymbol: "circle.dashed",
            colors: [Color(red: 0.60, green: 0.52, blue: 0.38), Color(red: 0.70, green: 0.65, blue: 0.50)]
        ),

        // ── Day 180 ──
        GardenItem(
            id: "pagoda",
            type: .feature,
            size: .large,
            displayName: "Meditation Pagoda",
            description: "A five-tier pagoda tucked in the corner. Peace emanates from it.",
            milestoneDays: 180,
            sfSymbol: "building.columns.fill",
            colors: [Color(red: 0.60, green: 0.25, blue: 0.10), Color(red: 0.75, green: 0.60, blue: 0.30)]
        ),

        // ── Day 200: Japanese maple bonsai (Bloom+ species) ──
        GardenItem(
            id: "maple-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Japanese Maple",
            description: "A lacy maple in warm autumn red and gold. Star-shaped leaves drift down as the days add up.",
            milestoneDays: 200,
            sfSymbol: "leaf.fill",
            colors: [Color(red: 0.78, green: 0.28, blue: 0.16), Color(red: 0.43, green: 0.35, blue: 0.29)]
        ),

        // ── Day 270 ──
        GardenItem(
            id: "wind-chime",
            type: .decoration,
            size: .small,
            displayName: "Wind Chime",
            description: "Tubular chimes that sing with the breeze. Each note is a day sober.",
            milestoneDays: 270,
            sfSymbol: "music.note.list",
            colors: [Color(red: 0.60, green: 0.55, blue: 0.30), Color(red: 0.80, green: 0.75, blue: 0.50)]
        ),

        // ── Day 300: Black pine bonsai (Bloom+ species) ──
        GardenItem(
            id: "pine-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Black Pine",
            description: "An evergreen pine with cloud-like needle tiers and a gnarled, weathered trunk.",
            milestoneDays: 300,
            sfSymbol: "tree.fill",
            colors: [Color(red: 0.18, green: 0.38, blue: 0.29), Color(red: 0.35, green: 0.27, blue: 0.21)]
        ),

        // ── Day 365: The crown jewel ──
        GardenItem(
            id: "windswept-bonsai",
            type: .bonsai,
            size: .large,
            displayName: "Windswept Bonsai",
            description: "Shaped by a lifetime of wind. Every branch tells a story of endurance.",
            milestoneDays: 365,
            sfSymbol: "wind",
            colors: [Color(red: 0.22, green: 0.38, blue: 0.16), Color(red: 0.50, green: 0.30, blue: 0.12)]
        ),
    ]

    /// Items a free user can place without Pro (a small taste).
    static let freeToPlaceIDs: Set<String> = ["moss"]

    static func item(id: String) -> GardenItem? {
        all.first { $0.id == id }
    }

    /// All items unlocked at or before `days` of sobriety.
    static func unlocked(atDays days: Int) -> [GardenItem] {
        all.filter { days >= $0.milestoneDays }
    }

    /// Items the user has not yet earned.
    static func locked(atDays days: Int) -> [GardenItem] {
        all.filter { days < $0.milestoneDays }
    }

    /// The most recently unlocked item (for celebration).
    static func latestUnlock(atDays days: Int, previouslyNotifiedDays: Int) -> GardenItem? {
        all
            .filter { $0.milestoneDays > previouslyNotifiedDays && $0.milestoneDays <= days }
            .sorted { $0.milestoneDays < $1.milestoneDays }
            .last
    }

    /// Maximum items a free user can have placed (including bonsai style).
    static let freePlacementLimit = 1

    static func canPlace(_ item: GardenItem, isPro: Bool, currentPlacedCount: Int) -> Bool {
        if item.type == .bonsai { return true }          // bonsai is always placeable (it's your active style)
        if isPro { return true }                          // Pro places anything
        if freeToPlaceIDs.contains(item.id) { return true } // free taste items
        return false
    }
}
