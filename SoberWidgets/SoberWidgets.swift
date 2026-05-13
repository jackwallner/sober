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
}

@main
struct SoberWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SoberDayCounterWidget()
    }
}
