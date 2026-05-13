import SwiftData
import SwiftUI

struct GardenStageView: View {
    let days: Int
    @Query private var gardenStates: [GardenState]

    private var stage: GardenStage { GardenService.stage(forDays: days) }
    private var species: GardenSpecies {
        GardenSpeciesCatalog.species(id: gardenStates.first?.activeSpeciesID ?? "oak")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.skyGradient)
            VStack {
                Spacer()
                tree
                ground
            }
            VStack {
                HStack {
                    Spacer()
                    badge
                }
                Spacer()
            }
            .padding(12)
        }
    }

    private var tree: some View {
        ZStack {
            switch stage {
            case .seed:
                Circle().fill(species.trunkColor)
                    .frame(width: 18, height: 18)
                    .offset(y: 70)
            case .sprout:
                VStack(spacing: -2) {
                    Circle().fill(species.crownColor)
                        .frame(width: 38, height: 38)
                    Capsule().fill(species.trunkColor)
                        .frame(width: 6, height: 24)
                }
                .offset(y: 40)
            case .sapling:
                tree(crownSize: 80, trunkHeight: 50, offset: 20)
            case .youngTree:
                tree(crownSize: 130, trunkHeight: 70, offset: 0)
            case .fullTree:
                tree(crownSize: 180, trunkHeight: 90, offset: -10)
            case .ancient:
                ancientTree
            }
        }
    }

    private func tree(crownSize: CGFloat, trunkHeight: CGFloat, offset: CGFloat) -> some View {
        VStack(spacing: -crownSize * 0.15) {
            Circle().fill(species.crownColor)
                .frame(width: crownSize, height: crownSize)
            Capsule().fill(species.trunkColor)
                .frame(width: crownSize * 0.12, height: trunkHeight)
        }
        .offset(y: offset)
    }

    private var ancientTree: some View {
        VStack(spacing: -28) {
            ZStack {
                Circle().fill(species.crownColor).frame(width: 200, height: 200)
                Circle().fill(species.crownColor.opacity(0.7))
                    .frame(width: 130, height: 130).offset(x: -70, y: 10)
                Circle().fill(species.crownColor.opacity(0.7))
                    .frame(width: 130, height: 130).offset(x: 70, y: 10)
            }
            Capsule().fill(species.trunkColor)
                .frame(width: 30, height: 90)
        }
        .offset(y: -20)
    }

    private var ground: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [Color(red: 0.55, green: 0.42, blue: 0.28), Color(red: 0.45, green: 0.32, blue: 0.20)],
                startPoint: .top, endPoint: .bottom))
            .frame(height: 24)
    }

    private var badge: some View {
        Text(stage.title)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.primary)
    }
}
