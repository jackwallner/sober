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
    @State private var draftMood: Int?
    @State private var draftNote: String = ""
    @State private var pendingSlipDay: Date?

    private var checkInsByDay: [Date: DailyCheckIn] {
        Dictionary(checkIns.map { (DateHelpers.startOfDay($0.day), $0) }, uniquingKeysWith: { a, _ in a })
    }
    private var earliestStart: Date? { journeys.last?.startDate }
    private var activeStart: Date? { journeys.first(where: { $0.isActive })?.startDate }

    /// Sober days accrued as of a given calendar date. Looks up whichever
    /// historical journey covered that date so the tree preview keeps showing
    /// past growth after a relapse reset.
    private func soberDays(on date: Date) -> Int {
        let d = DateHelpers.startOfDay(date)
        let covering = journeys.first { j in
            let s = DateHelpers.startOfDay(j.startDate)
            guard d >= s else { return false }
            if let end = j.endDate {
                return d <= DateHelpers.startOfDay(end)
            }
            return true
        }
        guard let j = covering else { return 0 }
        // 1-based to match the headline counter (the start day is Day 1).
        return DateHelpers.daysBetween(j.startDate, d) + 1
    }

    private var bonsaiStyle: BonsaiStyle {
        switch gardenStates.first?.activeBonsaiStyleID {
        case "cascade-bonsai": return .cascade
        case "windswept-bonsai": return .windswept
        case "sakura-bonsai": return .sakura
        case "maple-bonsai": return .maple
        case "pine-bonsai": return .pine
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

                if !selectedIsFuture {
                    Section("Check-in") {
                        checkInEditor
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
            .onAppear { loadDraft() }
            .onChange(of: selectedDate) { _, _ in loadDraft() }
            .alert(
                "Log a slip?",
                isPresented: Binding(get: { pendingSlipDay != nil }, set: { if !$0 { pendingSlipDay = nil } }),
                presenting: pendingSlipDay
            ) { day in
                Button("Cancel", role: .cancel) { pendingSlipDay = nil }
                Button("Log slip & reset", role: .destructive) { confirmSlip(on: day) }
            } message: { _ in
                Text("Logging a slip resets your day counter to start fresh. Your calendar history and grove of completed trees stay.")
            }
        }
    }

    private func loadDraft() {
        let checkIn = checkInsByDay[DateHelpers.startOfDay(selectedDate)]
        draftMood = checkIn?.mood
        draftNote = checkIn?.note ?? ""
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
                .font(Theme.title(weight: .semibold))
                .foregroundStyle(Theme.brandPrimary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(Theme.caption(weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Measured in the same elapsed-day unit as the headline counter
    /// (`daysSinceStart`), so "Current" can never read higher than "Longest"
    /// on an unbroken journey. Counting raw sober check-ins instead would
    /// include the start day and drift one ahead of the day counter.
    private var longestStreak: Int {
        SobrietyService(context: context).longestStreakDays()
    }

    // MARK: - Month grid

    private var monthNav: some View {
        HStack {
            Button { shift(months: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(monthTitle).font(Theme.heading(weight: .semibold))
            Spacer()
            Button { shift(months: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next month")
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
                    .font(Theme.caption(weight: .semibold))
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
            .font(Theme.caption(weight: .bold))
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
                        .font(Theme.body())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Day \(dayCount) · \(stage.title)")
                        .font(Theme.subhead())
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
            if dayCount <= 1 {
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
                .font(Theme.caption())
                .foregroundStyle(Theme.brandPrimary)
            Text(text)
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Check-in editor

    private var selectedIsFuture: Bool {
        DateHelpers.startOfDay(selectedDate) > DateHelpers.startOfDay()
    }

    @ViewBuilder
    private var checkInEditor: some View {
        let day = DateHelpers.startOfDay(selectedDate)
        let existing = checkInsByDay[day]

        if let checkIn = existing {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: checkIn.wasSober ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(checkIn.wasSober ? Theme.success : Theme.danger)
                    .frame(width: 28)
                Text(checkIn.wasSober ? "Logged sober" : "Logged a slip")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
        }

        // Mood + note appear before the log buttons too, so retroactive
        // entries can capture context without a second tap.
        moodPicker(existing: existing)
        noteField(existing: existing)

        if let checkIn = existing {
            Button(role: checkIn.wasSober ? .destructive : nil) {
                if checkIn.wasSober { pendingSlipDay = day }
                else { logCheckIn(on: day, wasSober: true) }
            } label: {
                Label(checkIn.wasSober ? "Change to slip" : "Change to sober",
                      systemImage: "arrow.left.arrow.right")
            }
            if checkIn.wasSober {
                Button(role: .destructive) {
                    deleteCheckIn(checkIn)
                } label: {
                    Label("Delete log", systemImage: "trash")
                }
            }
        } else {
            Button {
                logCheckIn(on: day, wasSober: true)
            } label: {
                Label("Log as sober", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                pendingSlipDay = day
            } label: {
                Label("Log a slip", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func confirmSlip(on day: Date) {
        let trimmed = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        CheckInService(context: context).checkIn(
            for: day, wasSober: false, mood: draftMood, note: trimmed.isEmpty ? nil : trimmed
        )
        // Slip resets the journey; a past-dated slip starts the fresh streak
        // the day after, and Home's auto-fill makes the calendar agree.
        let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        SobrietyService(context: context).resetJourney(startingAt: dayAfter)
        GardenService(context: context).resetForNewJourney()
        WidgetSnapshotPump.push(context: context)
        pendingSlipDay = nil
    }

    /// 1...5 mood scale, ordered rough → excellent to match the journal's
    /// feeling scale. Tapping the active mood again clears it. Works before
    /// the day has been logged (writes only to draft) and after (mirrors into
    /// the existing check-in immediately).
    private func moodPicker(existing: DailyCheckIn?) -> some View {
        let symbols = ["cloud.rain.fill", "cloud.fill", "cloud.sun.fill", "sun.max.fill", "sparkles"]
        let labels = ["Rough", "Low", "OK", "Good", "Great"]
        return VStack(alignment: .leading, spacing: 4) {
            Text("Mood").font(Theme.caption(weight: .semibold)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: Theme.Space.m) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        draftMood = (draftMood == value) ? nil : value
                        if let ci = existing {
                            ci.mood = draftMood
                            saveCheckInEdit()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: symbols[value - 1])
                                .font(.title3)
                                .foregroundStyle(draftMood == value ? Theme.brandPrimary : Theme.textTertiary)
                            Text(labels[value - 1])
                                .font(Theme.caption(weight: .semibold))
                                .foregroundStyle(draftMood == value ? Theme.brandPrimary : Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func noteField(existing: DailyCheckIn?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Note").font(Theme.caption(weight: .semibold)).foregroundStyle(Theme.textSecondary)
            TextField("How did the day go?", text: $draftNote, axis: .vertical)
                .lineLimit(1...4)
                .onChange(of: draftNote) { _, new in
                    if let ci = existing {
                        ci.note = new.isEmpty ? nil : new
                        saveCheckInEdit()
                    }
                }
        }
    }

    private func saveCheckInEdit() {
        try? context.save()
        WidgetSnapshotPump.push(context: context)
    }

    private func logCheckIn(on day: Date, wasSober: Bool) {
        let trimmed = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        CheckInService(context: context).checkIn(
            for: day,
            wasSober: wasSober,
            mood: draftMood,
            note: trimmed.isEmpty ? nil : trimmed
        )
        WidgetSnapshotPump.push(context: context)
    }

    private func deleteCheckIn(_ checkIn: DailyCheckIn) {
        context.delete(checkIn)
        try? context.save()
        WidgetSnapshotPump.push(context: context)
    }
}
