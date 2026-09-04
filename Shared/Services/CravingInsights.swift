import Foundation

/// One logged urge, detached from SwiftData so the analysis can be written and
/// tested as pure functions.
struct CravingFacts: Equatable, Sendable {
    let startedAt: Date
    let secondsElapsed: Int
    let outcome: CravingOutcome
    let intensity: Int
    let trigger: String?
}

/// A single thing the app can say back to the user about their own record.
struct CravingInsight: Identifiable, Equatable, Sendable {
    let id: String
    let icon: String
    let headline: String
    let detail: String
}

/// What Bloom+ is actually for.
///
/// The free app owns everything that can be computed from a start date, which
/// is most of what a sobriety tracker has ever sold. This file owns the part
/// that cannot: the shape of one particular person's urges, which only exists
/// because they logged it and which no competitor can copy off a screenshot.
///
/// Two rules run through all of it:
///
///   * **Every number has a floor.** Below its minimum sample an insight
///     returns nil rather than a confident-sounding claim built on two data
///     points. `nextUnlock` tells the user what is still coming instead, which
///     is also the only honest thing to put on a nearly-empty screen.
///   * **Nothing here is clinical.** These are descriptions of a log, phrased
///     as observations, never as advice, diagnosis, or prediction.
enum CravingInsights {
    /// Sample floors. Deliberately small, because a user with 30 logged urges
    /// is not the user this has to work for; a user with five is.
    static let minimumForRate = 3
    static let minimumForTiming = 4
    static let minimumForTrigger = 3
    static let minimumForWeekly = 4
    static let minimumSlipsForMood = 2

    // MARK: - Individual readings

    /// Share of resolved sessions the user stayed with. Unresolved sessions are
    /// excluded rather than counted as failures: someone who closed the screen
    /// did not necessarily drink, and guessing against them would make the one
    /// number they see about themselves quietly pessimistic.
    static func rideOutRate(_ facts: [CravingFacts]) -> (rode: Int, resolved: Int)? {
        let resolved = facts.filter { $0.outcome == .rodeItOut || $0.outcome == .gaveIn }
        guard resolved.count >= minimumForRate else { return nil }
        return (resolved.filter { $0.outcome == .rodeItOut }.count, resolved.count)
    }

    /// Median rather than mean: one 10-minute session should not move a number
    /// the user reads as "how long mine last".
    static func medianRideOutSeconds(_ facts: [CravingFacts]) -> Int? {
        let lengths = facts.filter { $0.outcome == .rodeItOut }.map(\.secondsElapsed).sorted()
        guard lengths.count >= minimumForRate else { return nil }
        let mid = lengths.count / 2
        return lengths.count.isMultiple(of: 2) ? (lengths[mid - 1] + lengths[mid]) / 2 : lengths[mid]
    }

    /// The three-hour stretch holding the most urges. Three hours because an
    /// hour is noise at these sample sizes and a half-day is not actionable.
    static func peakWindow(_ facts: [CravingFacts], calendar: Calendar = .current) -> (startHour: Int, count: Int)? {
        guard facts.count >= minimumForTiming else { return nil }
        var byHour = [Int](repeating: 0, count: 24)
        for fact in facts {
            byHour[calendar.component(.hour, from: fact.startedAt)] += 1
        }
        var best = (startHour: 0, count: -1)
        for start in 0..<24 {
            let count = (0..<3).reduce(0) { $0 + byHour[($1 + start) % 24] }
            if count > best.count { best = (start, count) }
        }
        // A window holding everything the user has ever logged says nothing
        // beyond "you log at some point in the day".
        guard best.count >= 2, best.count < facts.count || facts.count >= minimumForTiming else { return nil }
        return best
    }

    static func topTrigger(_ facts: [CravingFacts]) -> (name: String, count: Int)? {
        let tagged = facts.compactMap(\.trigger)
        guard tagged.count >= minimumForTrigger else { return nil }
        let counts = Dictionary(tagged.map { ($0, 1) }, uniquingKeysWith: +)
        guard let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else { return nil }
        guard best.value >= 2 else { return nil }
        return (best.key, best.value)
    }

    static func hardestWeekday(_ facts: [CravingFacts], calendar: Calendar = .current) -> (weekday: Int, count: Int)? {
        guard facts.count >= minimumForTiming else { return nil }
        let counts = Dictionary(
            facts.map { (calendar.component(.weekday, from: $0.startedAt), 1) },
            uniquingKeysWith: +
        )
        guard let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), best.value >= 2 else { return nil }
        return (best.key, best.value)
    }

    /// This week against the one before it, so the screen can show movement
    /// rather than only a standing total.
    static func weeklyChange(
        _ facts: [CravingFacts],
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> (thisWeek: Int, lastWeek: Int)? {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let thisWeek = facts.filter { $0.startedAt > weekAgo && $0.startedAt <= now }.count
        let lastWeek = facts.filter { $0.startedAt > twoWeeksAgo && $0.startedAt <= weekAgo }.count
        guard thisWeek + lastWeek >= minimumForWeekly else { return nil }
        return (thisWeek, lastWeek)
    }

    /// Average mood on the two days before a slip against every other day with
    /// a recorded mood. Reported only when both groups have enough entries and
    /// the gap is big enough to be worth a sentence.
    static func moodDipBeforeSlips(
        _ checkIns: [CheckInFacts],
        calendar: Calendar = .current
    ) -> Double? {
        // Every day boundary here comes from the injected calendar. Reaching
        // for DateHelpers, which is hardwired to Calendar.current, put the
        // run-up window a day off whenever the two disagreed.
        let startOfDay = { calendar.startOfDay(for: $0) }
        let slipDays = checkIns.filter { !$0.wasSober }.map { startOfDay($0.day) }
        guard slipDays.count >= minimumSlipsForMood else { return nil }

        let runUp = Set(slipDays.flatMap { day in
            (1...2).compactMap { calendar.date(byAdding: .day, value: -$0, to: day) }
        })

        let before = checkIns.filter { runUp.contains(startOfDay($0.day)) }.compactMap(\.mood)
        let rest = checkIns
            .filter { $0.wasSober && !runUp.contains(startOfDay($0.day)) }
            .compactMap(\.mood)
        guard before.count >= 3, rest.count >= 3 else { return nil }

        let mean = { (values: [Int]) in Double(values.reduce(0, +)) / Double(values.count) }
        let dip = mean(rest) - mean(before)
        return dip >= 0.5 ? dip : nil
    }

    // MARK: - Presentation

    static func insights(
        cravings: [CravingFacts],
        checkIns: [CheckInFacts],
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> [CravingInsight] {
        var result: [CravingInsight] = []

        if let rate = rideOutRate(cravings) {
            result.append(CravingInsight(
                id: "rate",
                icon: "wind",
                headline: "\(rate.rode) of \(rate.resolved) ridden out",
                detail: "Every one of those was a \(HabitVocabulary.urgeNoun) that ended without \(HabitVocabulary.habitInstance)."
            ))
        }

        if let window = peakWindow(cravings, calendar: calendar) {
            result.append(CravingInsight(
                id: "window",
                icon: "clock.fill",
                headline: "Hardest between \(hourLabel(window.startHour, calendar: calendar)) and \(hourLabel(window.startHour + 3, calendar: calendar))",
                detail: "\(window.count) of your \(cravings.count) logged \(HabitVocabulary.urgeNounPlural) land in that stretch."
            ))
        }

        if let seconds = medianRideOutSeconds(cravings) {
            result.append(CravingInsight(
                id: "length",
                icon: "hourglass",
                headline: "Yours usually pass in \(spokenDuration(seconds))",
                detail: "Measured from the sessions you stayed with, not an average of everyone."
            ))
        }

        if let trigger = topTrigger(cravings) {
            result.append(CravingInsight(
                id: "trigger",
                icon: "tag.fill",
                headline: "\(trigger.name) comes up most",
                detail: "You've tagged it \(trigger.count) times."
            ))
        }

        if let day = hardestWeekday(cravings, calendar: calendar) {
            result.append(CravingInsight(
                id: "weekday",
                icon: "calendar",
                headline: "\(weekdayLabel(day.weekday, calendar: calendar)) is your heaviest day",
                detail: "\(day.count) logged so far."
            ))
        }

        if let change = weeklyChange(cravings, asOf: now, calendar: calendar) {
            let headline: String
            if change.thisWeek < change.lastWeek {
                headline = "Fewer this week than last"
            } else if change.thisWeek > change.lastWeek {
                headline = "More this week than last"
            } else {
                headline = "Level with last week"
            }
            result.append(CravingInsight(
                id: "weekly",
                icon: "chart.line.uptrend.xyaxis",
                headline: headline,
                detail: "\(change.thisWeek) in the last seven days, \(change.lastWeek) the week before."
            ))
        }

        if moodDipBeforeSlips(checkIns, calendar: calendar) != nil {
            result.append(CravingInsight(
                id: "mood",
                icon: "cloud.sun.fill",
                headline: "Your mood tends to dip before a slip",
                detail: "The days leading up to one read lower than your usual. Worth noticing early."
            ))
        }

        return result
    }

    /// What is still coming, for a screen that does not have enough data yet.
    /// This is the retention loop for a subscriber: the tool is free, and using
    /// it is what fills in the part they paid for.
    static func nextUnlock(_ cravings: [CravingFacts]) -> String? {
        let needed = max(minimumForRate, minimumForTiming)
        guard cravings.count < needed else { return nil }
        let remaining = needed - cravings.count
        return remaining == 1
            ? "One more logged \(HabitVocabulary.urgeNoun) and your patterns start filling in."
            : "\(remaining) more logged \(HabitVocabulary.urgeNounPlural) and your patterns start filling in."
    }

    /// The one personal line the ride-it-out screen can show mid-session.
    /// Nil for a user without the history to support it, which keeps the free
    /// session identical to what it always was rather than a nagged version.
    static func coachLine(_ facts: [CravingFacts]) -> String? {
        guard let seconds = medianRideOutSeconds(facts) else { return nil }
        return "Yours usually pass in \(spokenDuration(seconds))."
    }

    // MARK: - Formatting

    static func spokenDuration(_ seconds: Int) -> String {
        if seconds < 90 { return "about a minute" }
        let minutes = Int((Double(seconds) / 60).rounded())
        return "about \(minutes) minutes"
    }

    static func hourLabel(_ hour: Int, calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.hour = hour % 24
        components.minute = 0
        let date = calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter.string(from: date)
    }

    static func weekdayLabel(_ weekday: Int, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        let symbols = formatter.standaloneWeekdaySymbols ?? []
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index] + "s"
    }
}
