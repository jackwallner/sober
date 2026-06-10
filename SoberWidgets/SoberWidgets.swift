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
    /// Past the first year, the bare in-cycle stage reads like a bug next to a
    /// big day count ("14600 days · Seedling") — prefix the year for context,
    /// matching the garden's stage badge.
    private var stageTitle: String {
        let completed = GardenService.cycleProgress(forDays: days).completed
        return completed > 0 ? "Year \(completed + 1) · \(stage.title)" : stage.title
    }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: days).dayInCycle }
    private var bonsaiStyle: BonsaiStyle {
        switch snapshot.bonsaiStyleID {
        case "cascade-bonsai", "cascade": return .cascade
        case "windswept-bonsai", "windswept": return .windswept
        case "sakura-bonsai", "sakura": return .sakura
        case "maple-bonsai", "maple": return .maple
        case "pine-bonsai", "pine": return .pine
        default: return .traditional
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Long streaks reach 4-5 digits (a year-3 user is past 1,000 days;
            // 40 years is ~14,600) — scale the number down rather than truncate.
            VStack(spacing: 0) {
                Text("\(days)")
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
                Text(days == 1 ? "day" : "days").font(.caption2)
            }
            .accessibilityLabel(Text(days == 1 ? "1 day sober" : "\(days) days sober"))
        case .accessoryRectangular:
            HStack {
                Image(systemName: "leaf.fill")
                Text(days == 1 ? "1 day sober" : "\(days) days sober")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(days == 1 ? "1 day sober" : "\(days) days sober"))
        case .accessoryInline:
            Text("\(days) days sober")
        case .systemMedium:
            HStack(spacing: 12) {
                BonsaiView(day: dayInCycle, style: bonsaiStyle, vitality: snapshot.gardenVitality)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(days)")
                        .font(Theme.bigNumber(44))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
            // systemSmall: let the tree fill and bottom-anchor so it owns the
            // tile, and float the count in a top scrim band — the upper sky is
            // the sparsest region, so the number never collides with the
            // trunk/pot the way a bottom overlay did.
            BonsaiView(day: dayInCycle, style: bonsaiStyle, vitality: snapshot.gardenVitality, fill: true)
                .overlay(alignment: .top) {
                    VStack(spacing: -1) {
                        Text("\(days)")
                            .font(Theme.bigNumber(34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 8)
                            .foregroundStyle(.white)
                        Text(days == 1 ? "day sober" : "days sober")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.28), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(days == 1 ? "1 day sober" : "\(days) days sober"))
        }
    }
}

@main
struct SoberWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SoberDayCounterWidget()
    }
}
