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
            List {
                Section {
                    summaryRow
                        .listRowInsets(EdgeInsets(top: Theme.Space.m, leading: Theme.Space.l, bottom: Theme.Space.m, trailing: Theme.Space.l))
                }

                Section {
                    monthNav
                    monthGrid
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.s, bottom: Theme.Space.s, trailing: Theme.Space.s))
                }

                Section("Selected day") {
                    treeRow
                        .listRowInsets(EdgeInsets(top: Theme.Space.s, leading: Theme.Space.l, bottom: Theme.Space.m, trailing: Theme.Space.l))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
        }
    }

    // MARK: - Summary

    private var summaryRow: some View {
        let active = journeys.first(where: { $0.isActive })
        let days = active.map { SobrietyService.daysSinceStart($0.startDate) } ?? 0
        let totalSober = checkIns.filter { $0.wasSober }.count
        return Grid(horizontalSpacing: 0) {
            GridRow {
                statCell(value: "\(days)", label: "Current")
                Divider()
                statCell(value: "\(longestStreak)", label: "Longest")
                Divider()
                statCell(value: "\(totalSober)", label: "Total")
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.brandPrimary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
            Button { shift(months: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            Spacer()
            Text(monthTitle).font(.title3.weight(.semibold))
            Spacer()
            Button { shift(months: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
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
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                Text(sym)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 36) }
            ForEach(days, id: \.self) { day in
                dayCell(date: cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) ?? firstOfMonth)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let f = DateFormatter()
        let raw = f.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        // Rotate so the user's `firstWeekday` lands in column 0 (matches the grid we lay out).
        let first = Calendar.current.firstWeekday - 1
        return Array(raw[first...] + raw[..<first])
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
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.brandPrimary : .clear, lineWidth: 2)
            )
            .foregroundStyle(checkIn != nil ? .white : Theme.textPrimary)
            .opacity(inFuture || beforeStart ? 0.5 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !inFuture && !beforeStart else { return }
                withAnimation(.easeInOut(duration: 0.35)) { selectedDate = day }
            }
    }

    // MARK: - Reconstructed tree for the selected day

    private var treeRow: some View {
        let dayCount = soberDays(on: selectedDate)
        let cycle = GardenService.cycleProgress(forDays: dayCount)
        let stage = GardenService.stage(forDays: dayCount)
        let isToday = DateHelpers.startOfDay(selectedDate) == DateHelpers.startOfDay()

        return VStack(alignment: .leading, spacing: Theme.Space.m) {
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
                RoundedRectangle(cornerRadius: 14).fill(Theme.skyGradient)
                BonsaiView(day: cycle.dayInCycle, style: bonsaiStyle, vitality: 1.0)
                    .padding(8)
                    .id(cycle.dayInCycle)
                    .transition(.opacity)
            }
            .frame(height: 200)

            diffNarration(dayCount: dayCount)
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
