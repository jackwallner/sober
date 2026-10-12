import Foundation

/// The three goals offered in onboarding and Settings. A preset is a day count,
/// not a date: "30 days" means the day the counter reads 30, so it is resolved
/// against the journey's start every time it is shown.
enum GoalPreset: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case ninetyDays = 90
    case oneYear = 365

    var id: Int { rawValue }
    var dayCount: Int { rawValue }

    var label: String {
        switch self {
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .oneYear: "1 year"
        }
    }

    /// The start of the day the counter reads `dayCount`. Day 1 is the start
    /// day itself, so day N is N - 1 days after it.
    func date(from start: Date, calendar: Calendar = .current) -> Date {
        let first = calendar.startOfDay(for: start)
        return calendar.date(byAdding: .day, value: dayCount - 1, to: first) ?? first
    }

    /// A preset the user has already passed is not a goal, so it is not offered.
    func isAhead(start: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        date(from: start, calendar: calendar) > calendar.startOfDay(for: now)
    }

    /// The preset a stored goal date corresponds to, if any.
    static func matching(goal: Date, start: Date, calendar: Calendar = .current) -> GoalPreset? {
        allCases.first { calendar.isDate($0.date(from: start, calendar: calendar), inSameDayAs: goal) }
    }
}

/// What the user will have by their goal date, computed from the same daily
/// figures the free "kept so far" numbers use. A projection, never a promise.
///
/// Day counts follow `SobrietyService.daysSinceStart`: the start day is day 1,
/// so the money kept by the goal day is that day's count times the daily spend,
/// the same rule the Progress sheet applies to the days already behind.
struct GoalProjection: Equatable {
    let goalDate: Date
    /// Calendar days from today to the goal day. Zero on the day itself and
    /// after it.
    let daysToGo: Int
    /// What the counter will read on the goal day.
    let dayCountAtGoal: Int
    let moneyCents: Int
    let calories: Int
    /// Nil when there is no calorie figure to derive it from.
    let habitInstances: Int?
    /// Every health milestone passed by the end of the goal day.
    let milestonesPassed: [HealthBenefit]
    /// The subset still ahead of the user today.
    let milestonesStillAhead: [HealthBenefit]

    var isReached: Bool { daysToGo == 0 }

    init(
        start: Date,
        goal: Date,
        now: Date = .now,
        costPerDayCents: Int,
        caloriesPerDay: Int,
        calendar: Calendar = .current
    ) {
        let goalDay = calendar.startOfDay(for: goal)
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: start)
        goalDate = goalDay
        daysToGo = max(0, calendar.dateComponents([.day], from: today, to: goalDay).day ?? 0)
        dayCountAtGoal = max(0, calendar.dateComponents([.day], from: startDay, to: goalDay).day ?? 0) + 1
        moneyCents = dayCountAtGoal * max(0, costPerDayCents)
        calories = dayCountAtGoal * max(0, caloriesPerDay)
        let perInstance = HabitVocabulary.caloriesPerInstance
        habitInstances = (caloriesPerDay > 0 && perInstance > 0) ? calories / perInstance : nil

        // "By Nov 9" reads as by the end of that day, so a milestone landing
        // that evening counts.
        let horizon = calendar.date(byAdding: .day, value: 1, to: goalDay) ?? goalDay
        let schedule = MilestoneSchedule.all(start: start)
        milestonesPassed = schedule.filter { $0.date <= horizon }.map(\.benefit)
        milestonesStillAhead = schedule.filter { $0.date <= horizon && $0.date > now }.map(\.benefit)
    }

    var hasSpend: Bool { moneyCents > 0 }

    static func currency(cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let dollars = Double(cents) / 100
        return formatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    var moneyText: String { Self.currency(cents: moneyCents) }

    /// "Nov 9" in the user's locale.
    static func shortDate(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    /// The trial page's lead line, or nil when there is no spend figure to
    /// make it concrete (the page falls back to the year-ahead line).
    var pitchLine: String? {
        guard hasSpend else { return nil }
        let count = milestonesPassed.count
        return "By \(Self.shortDate(goalDate)): \(moneyText) kept and \(count) \(count == 1 ? "milestone" : "milestones") passed"
    }
}
