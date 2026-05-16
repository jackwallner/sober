import SwiftUI
import WidgetKit

struct SoberEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SoberProvider: TimelineProvider {
    func placeholder(in context: Context) -> SoberEntry {
        SoberEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SoberEntry) -> Void) {
        completion(SoberEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SoberEntry>) -> Void) {
        let entry = SoberEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SoberDayCounterWidget: Widget {
    let kind: String = "SoberDayCounter"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SoberProvider()) { entry in
            SoberDayCounterView(snapshot: entry.snapshot)
                .containerBackground(Theme.brandGradient, for: .widget)
        }
        .configurationDisplayName("Sober Days")
        .description("How long you've been sober.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SoberDayCounterView: View {
    @Environment(\.widgetFamily) var family
    let snapshot: WidgetSnapshot

    private var stageIndex: Int { snapshot.bonsaiStage }
    private var stageTitle: String {
        ["Seed", "Sprout", "Seedling", "Young", "Adolescent", "Mature", "Refined", "Ancient", "Legendary"]
            .indices.contains(stageIndex) ? ["Seed", "Sprout", "Seedling", "Young", "Adolescent", "Mature", "Refined", "Ancient", "Legendary"][stageIndex] : "Seed"
    }
    private var hasItems: Bool { !snapshot.placedItemIDs.isEmpty }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack {
                Text("\(snapshot.currentStreakDays)").font(.title2.bold())
                Text("d").font(.caption2)
            }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "leaf.fill")
                Text("\(snapshot.currentStreakDays) days sober")
            }
        case .accessoryInline:
            Text("\(snapshot.currentStreakDays) days sober")
        case .systemMedium:
            HStack(spacing: 16) {
                // Garden stage indicator
                VStack(spacing: 2) {
                    Image(systemName: stageIcon)
                        .font(.title2)
                    Text(stageTitle)
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.8))

                Divider().background(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.currentStreakDays)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(snapshot.currentStreakDays == 1 ? "day sober" : "days sober")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    if let start = snapshot.sobrietyStartDate {
                        Text("Since \(DateHelpers.mediumDate(start))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Items count
                if hasItems {
                    VStack(spacing: 2) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                        Text("\(snapshot.placedItemIDs.count)")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
        default:
            VStack(spacing: 4) {
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(snapshot.currentStreakDays == 1 ? "day sober" : "days sober")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var stageIcon: String {
        switch stageIndex {
        case 0: return "circle"
        case 1: return "leaf"
        case 2: return "leaf.fill"
        case 3: return "tree"
        case 4: return "tree.fill"
        case 5: return "crown"
        case 6: return "crown.fill"
        case 7: return "sparkle"
        case 8: return "star.fill"
        default: return "leaf.fill"
        }
    }
}

@main
struct SoberWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SoberDayCounterWidget()
    }
}
