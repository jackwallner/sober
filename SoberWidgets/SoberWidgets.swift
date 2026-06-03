import SwiftUI
import WidgetKit

struct SoberEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Day count recomputed from the snapshot's start date at `date`, so the
    /// widget advances with the calendar between app launches.
    let days: Int
}

/// The stored `currentStreakDays` is frozen at the last app launch. Derive the
/// live count from the start date so crossing midnight bumps the widget on its
/// own (matches `SobrietyService.daysSinceStart`).
private func liveDays(_ snap: WidgetSnapshot, asOf date: Date) -> Int {
    guard let start = snap.sobrietyStartDate else { return snap.currentStreakDays }
    // 1-based: the start day is Day 1 (matches `SobrietyService.daysSinceStart`).
    return max(0, DateHelpers.daysBetween(start, date)) + 1
}

struct SoberProvider: TimelineProvider {
    func placeholder(in context: Context) -> SoberEntry {
        SoberEntry(date: .now, snapshot: .empty, days: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SoberEntry) -> Void) {
        let snap = WidgetSnapshotStore.load()
        completion(SoberEntry(date: .now, snapshot: snap, days: liveDays(snap, asOf: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SoberEntry>) -> Void) {
        let now = Date.now
        let snap = WidgetSnapshotStore.load()
        let entry = SoberEntry(date: now, snapshot: snap, days: liveDays(snap, asOf: now))
        // Refresh at the next local midnight so the day count rolls over even if
        // the app isn't opened; fall back to +1h if midnight can't be computed.
        let nextMidnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct SoberDayCounterWidget: Widget {
    let kind: String = "SoberDayCounter"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SoberProvider()) { entry in
            SoberDayCounterView(snapshot: entry.snapshot, days: entry.days)
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
    let days: Int

    private var stage: BonsaiStage { GardenService.stage(forDays: days) }
    private var stageIndex: Int { stage.rawValue }
    private var stageTitle: String { stage.title }
    private var hasItems: Bool { !snapshot.placedItemIDs.isEmpty }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: days).dayInCycle }
    private var bonsaiStyle: BonsaiStyle {
        switch snapshot.bonsaiStyleID {
        case "cascade-bonsai", "cascade": return .cascade
        case "windswept-bonsai", "windswept": return .windswept
        case "sakura-bonsai", "sakura": return .sakura
        default: return .traditional
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack {
                Text("\(days)").font(.title2.bold())
                Text("d").font(.caption2)
            }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "leaf.fill")
                Text("\(days) days sober")
            }
        case .accessoryInline:
            Text("\(days) days sober")
        case .systemMedium:
            HStack(spacing: 12) {
                BonsaiView(day: dayInCycle, style: bonsaiStyle, vitality: snapshot.gardenVitality)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(days)")
                        .font(Theme.bigNumber(44))
                        .foregroundStyle(.white)
                    Text(days == 1 ? "day sober" : "days sober")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(stageTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 2)
                    if let start = snapshot.sobrietyStartDate {
                        Text("Since \(DateHelpers.mediumDate(start))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            ZStack {
                BonsaiView(day: dayInCycle, style: bonsaiStyle, vitality: snapshot.gardenVitality)
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(days)")
                            .font(Theme.bigNumber(34))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        Text(days == 1 ? "day sober" : "days sober")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    }
                }
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
