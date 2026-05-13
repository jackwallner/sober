import Foundation
import SwiftUI

struct GardenSpecies: Identifiable, Hashable {
    let id: String
    let displayName: String
    let isFree: Bool
    let crownColor: Color
    let trunkColor: Color
}

enum GardenSpeciesCatalog {
    static let all: [GardenSpecies] = [
        GardenSpecies(
            id: "oak",
            displayName: "Oak",
            isFree: true,
            crownColor: Color(red: 0.32, green: 0.62, blue: 0.45),
            trunkColor: Color(red: 0.45, green: 0.30, blue: 0.18)
        ),
        GardenSpecies(
            id: "cherry-blossom",
            displayName: "Cherry Blossom",
            isFree: false,
            crownColor: Color(red: 0.95, green: 0.72, blue: 0.80),
            trunkColor: Color(red: 0.30, green: 0.22, blue: 0.18)
        ),
        GardenSpecies(
            id: "willow",
            displayName: "Willow",
            isFree: false,
            crownColor: Color(red: 0.55, green: 0.78, blue: 0.60),
            trunkColor: Color(red: 0.38, green: 0.28, blue: 0.18)
        ),
        GardenSpecies(
            id: "pine",
            displayName: "Pine",
            isFree: false,
            crownColor: Color(red: 0.20, green: 0.45, blue: 0.32),
            trunkColor: Color(red: 0.40, green: 0.26, blue: 0.16)
        ),
        GardenSpecies(
            id: "maple",
            displayName: "Autumn Maple",
            isFree: false,
            crownColor: Color(red: 0.90, green: 0.45, blue: 0.20),
            trunkColor: Color(red: 0.40, green: 0.26, blue: 0.16)
        ),
    ]

    static func species(id: String) -> GardenSpecies {
        all.first { $0.id == id } ?? all[0]
    }
}
