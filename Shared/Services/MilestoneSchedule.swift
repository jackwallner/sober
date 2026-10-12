import Foundation

/// A health milestone pinned to the moment it lands for this user.
struct DatedMilestone: Identifiable, Equatable {
    let benefit: HealthBenefit
    let date: Date
    /// Position in `HealthBenefitCatalog.all`. The free window is the first
    /// five, so callers decide what to reveal from this.
    let index: Int

    var id: String { benefit.id }
}

/// Turns the start date into real dates for every milestone, so "in 2w"
/// becomes "Fri, Oct 24": a date is something to look forward to, a duration
/// is just arithmetic.
enum MilestoneSchedule {
    static func all(start: Date) -> [DatedMilestone] {
        HealthBenefitCatalog.all.enumerated().map { index, benefit in
            DatedMilestone(
                benefit: benefit,
                date: start.addingTimeInterval(benefit.hoursRequired * 3600),
                index: index
            )
        }
    }

    /// The next `limit` milestones still ahead of `now`, soonest first.
    static func upcoming(start: Date, now: Date = .now, limit: Int = 3) -> [DatedMilestone] {
        Array(all(start: start).filter { $0.date > now }.prefix(limit))
    }

    static func remainingCount(start: Date, now: Date = .now) -> Int {
        all(start: start).filter { $0.date > now }.count
    }

    /// "Tonight 9:14 PM", "Today 11:30 AM", "Tomorrow 2:32 PM", "Fri, Oct 17",
    /// or "Oct 17, 2027" once it is in another year. The time is only shown
    /// while it is close enough to plan an evening around.
    static func label(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let evening = calendar.component(.hour, from: date) >= 17
            return "\(evening ? "Tonight" : "Today") \(format(date, "jmm", calendar, locale))"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(format(date, "jmm", calendar, locale))"
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return format(date, "EEEMMMd", calendar, locale)
        }
        return format(date, "yMMMd", calendar, locale)
    }

    /// The trial page's milestone line.
    static func pitchLine(start: Date, now: Date = .now) -> String {
        let remaining = all(start: start).filter { $0.date > now }
        guard let next = remaining.first else {
            return "All \(HealthBenefitCatalog.all.count) recovery milestones, each with its source."
        }
        let head = "\(label(for: next.date, now: now)): \(next.benefit.title)."
        let more = remaining.count - 1
        guard more > 0 else { return "\(head) The last one on the timeline." }
        return "\(head) Then \(more) more, each dated."
    }

    private static func format(_ date: Date, _ template: String, _ calendar: Calendar, _ locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
