import SwiftData
import SwiftUI

/// Timeline: one scrubbable time axis. The calendar grid up top doubles as a
/// date picker; selecting a day morphs the bonsai below to how it looked then,
/// with a day-over-day growth note. Merges the old Calendar + Growth Log.
struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var gardenStates: [GardenState]

    @State private var monthAnchor: Date = DateHelpers.startOfDay()
    @State private var selectedDate: Date = DateHelpers.startOfDay()

    private var checkInsByDay: [Date: DailyCheckIn] {
        Dictionary(checkIns.map { (DateHelpers.startOfDay($0.day), $0) }, uniquingKeysWith: { a, _ in a })
    }
    private var earliestStart: Date? { journeys.last?.startDate }
    private var activeStart: Date? { journeys.first(where: { $0.isActive })?.startDate }

    /// Sober days accrued as of a given calendar date (0 before the journey).
    private func soberDays(on date: Date) -> Int {
        guard let start = activeStart else { return 0 }
        let s = DateHelpers.startOfDay(start)
        let d = DateHelpers.startOfDay(date)
        guard d >= s else { return 0 }
        return DateHelpers.daysBetween(s, d)
    }

    private var bonsaiStyle: BonsaiStyle {
        switch gardenStates.first?.activeBonsaiStyleID {
        case "cascade-bonsai": return .cascade
        case "windswept-bonsai": return .windswept
        default: return .traditional
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    monthNav
                    monthGrid
                    treeForSelectedDay
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Timeline")
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let active = journeys.first(where: { $0.isActive })
        let days = active.map { SobrietyService.daysSinceStart($0.startDate) } ?? 0
        let totalSober = checkIns.filter { $0.wasSober }.count
        return HeroCard {
            HStack {
                HeroStat(value: "\(days)", label: "Current Streak")
                Divider().frame(height: 40).overlay(.white.opacity(0.3))
                HeroStat(value: "\(longestStreak)", label: "Longest Streak")
                Divider().frame(height: 40).overlay(.white.opacity(0.3))
                HeroStat(value: "\(totalSober)", label: "Sober Days")
            }
        }
    }

    private var longestStreak: Int {
        let sortedSoberDays = checkIns
            .filter { $0.wasSober }
            .map { DateHelpers.startOfDay($0.day) }
            .sorted()
        guard !sortedSoberDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<sortedSoberDays.count {
            let gap = Calendar.current.dateComponents([.day], from: sortedSoberDays[i - 1], to: sortedSoberDays[i]).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else if gap > 1 {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Month grid

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
        let isSelected = day == DateHelpers.startOfDay(selectedDate)

        let bg: Color
        if inFuture || beforeStart { bg = .clear }
        else if checkIn?.wasSober == true { bg = Theme.success.opacity(0.85) }
        else if checkIn?.wasSober == false { bg = Theme.danger.opacity(0.75) }
        else { bg = Theme.cardSurface }

        return Text("\(Calendar.current.component(.day, from: date))")
            .font(.caption.bold())
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.brandPrimary : .clear, lineWidth: 2)
            )
            .foregroundStyle(checkIn != nil ? .white : Theme.textPrimary)
            .opacity(inFuture || beforeStart ? 0.25 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !inFuture && !beforeStart else { return }
                withAnimation(.easeInOut(duration: 0.35)) { selectedDate = day }
            }
    }

    // MARK: - Reconstructed tree for the selected day

    private var treeForSelectedDay: some View {
        let dayCount = soberDays(on: selectedDate)
        let cycle = GardenService.cycleProgress(forDays: dayCount)
        let stage = GardenService.stage(forDays: dayCount)
        let isToday = DateHelpers.startOfDay(selectedDate) == DateHelpers.startOfDay()

        return SectionCard {
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isToday ? "Today" : DateHelpers.mediumDate(selectedDate))
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Day \(dayCount) · \(stage.title)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Theme.skyGradient)
                    BonsaiView(day: cycle.dayInCycle, style: bonsaiStyle, vitality: 1.0)
                        .padding(8)
                        .id(cycle.dayInCycle)
                        .transition(.opacity)
                }
                .frame(height: 220)

                diffNarration(dayCount: dayCount)
            }
        }
    }

    @ViewBuilder
    private func diffNarration(dayCount: Int) -> some View {
        let prevDay = max(0, dayCount - 1)
        let todayCycle = GardenService.cycleProgress(forDays: dayCount).dayInCycle
        let prevStage = GardenService.stage(forDays: prevDay)
        let curStage = GardenService.stage(forDays: dayCount)

        VStack(alignment: .leading, spacing: 6) {
            if dayCount == 0 {
                growthLine(icon: "sparkle", text: "The seed is settling in. Your journey starts here.")
            } else {
                growthLine(icon: "arrow.up.forward",
                           text: "vs. yesterday: \(DailyGrowth.note(forDayInCycle: todayCycle))")
                if curStage != prevStage {
                    growthLine(icon: "leaf.fill",
                               text: "Stage advanced: \(prevStage.title) → \(curStage.title)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func growthLine(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.brandPrimary)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
    }
}
