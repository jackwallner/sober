import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @State private var monthAnchor: Date = DateHelpers.startOfDay()
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]

    private var checkInsByDay: [Date: DailyCheckIn] {
        Dictionary(uniqueKeysWithValues: checkIns.map { ($0.day, $0) })
    }

    private var earliestStart: Date? { journeys.last?.startDate }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    monthNav
                    monthGrid
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Sobriety Calendar")
        }
    }

    private var summaryCard: some View {
        let active = journeys.first(where: { $0.isActive })
        let days = active.map { SobrietyService.daysSinceStart($0.startDate) } ?? 0
        let totalSober = checkIns.filter { $0.wasSober }.count
        return HeroCard {
            HStack {
                HeroStat(value: "\(days)", label: "Current Days")
                Divider().frame(height: 40).overlay(.white.opacity(0.3))
                HeroStat(value: "\(totalSober)", label: "Sober Days")
                Divider().frame(height: 40).overlay(.white.opacity(0.3))
                HeroStat(value: active.map { successRate(start: $0.startDate) } ?? "—",
                         label: "Success Rate")
            }
        }
    }

    private func successRate(start: Date) -> String {
        let totalDays = max(1, DateHelpers.daysBetween(start, .now) + 1)
        let sober = checkIns.filter { $0.wasSober && $0.day >= start }.count
        let pct = Double(sober) / Double(totalDays) * 100
        return String(format: "%.0f%%", pct)
    }

    private var monthNav: some View {
        HStack {
            Button { shift(months: -1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthTitle).font(.title3.weight(.semibold))
            Spacer()
            Button { shift(months: 1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMMy")
        return f.string(from: monthAnchor)
    }

    private func shift(months: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: months, to: monthAnchor) {
            monthAnchor = new
        }
    }

    private var monthGrid: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        let firstOfMonth = cal.date(from: comps) ?? monthAnchor
        let range = cal.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<31
        let leadingBlanks = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
        let days = Array(range)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym).font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 36) }
            ForEach(days, id: \.self) { day in
                dayCell(date: cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) ?? firstOfMonth)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let f = DateFormatter()
        return f.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    }

    private func dayCell(date: Date) -> some View {
        let day = DateHelpers.startOfDay(date)
        let checkIn = checkInsByDay[day]
        let inFuture = day > DateHelpers.startOfDay()
        let beforeStart = earliestStart.map { day < DateHelpers.startOfDay($0) } ?? false

        let bg: Color
        if inFuture || beforeStart { bg = .clear }
        else if checkIn?.wasSober == true { bg = Theme.success.opacity(0.85) }
        else if checkIn?.wasSober == false { bg = Theme.danger.opacity(0.75) }
        else { bg = Theme.cardSurface }

        return Text("\(Calendar.current.component(.day, from: date))")
            .font(.caption.bold())
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(bg, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(checkIn != nil ? .white : Theme.textPrimary)
            .opacity(inFuture || beforeStart ? 0.25 : 1)
    }
}
