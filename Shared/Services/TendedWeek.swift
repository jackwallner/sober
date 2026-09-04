import Foundation

/// A day's check-in, detached from SwiftData so the week summary can be built
/// and tested without a ModelContext.
struct CheckInFacts: Equatable, Sendable {
    let day: Date
    let wasSober: Bool
    let wasLogged: Bool
    let mood: Int?
}

/// One cell of the week strip.
struct TendedDay: Equatable, Identifiable, Sendable {
    enum Mark: Equatable, Sendable {
        /// The user tapped for this day.
        case tended
        /// Sober, but the app filled it in rather than the user.
        case assumed
        case slip
        /// Nothing recorded at all (before the journey started, or a gap).
        case blank
    }

    let day: Date
    let mark: Mark
    let mood: Int?

    var id: Date { day }
}

/// The last seven days, as something to look at.
///
/// This exists because the daily check-in had no consequence: the counter runs
/// on wall-clock time and the calendar was backfilled either way, so the one
/// action the app asks for every day changed nothing the user could see. The
/// strip is the smallest honest answer to that. A tended day looks different
/// from a day that merely elapsed.
enum TendedWeek {
    static let length = 7

    /// Oldest first, ending on `endingOn` inclusive.
    static func days(endingOn end: Date = .now, facts: [CheckInFacts]) -> [TendedDay] {
        let byDay = Dictionary(
            facts.map { (DateHelpers.startOfDay($0.day), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return (0..<length).reversed().map { offset in
            let day = DateHelpers.daysAgo(offset, from: end)
            guard let fact = byDay[day] else {
                return TendedDay(day: day, mark: .blank, mood: nil)
            }
            let mark: TendedDay.Mark = {
                if !fact.wasSober { return .slip }
                return fact.wasLogged ? .tended : .assumed
            }()
            return TendedDay(day: day, mark: mark, mood: fact.mood)
        }
    }

    static func tendedCount(_ days: [TendedDay]) -> Int {
        days.filter { $0.mark == .tended }.count
    }

    /// Mood labels, ordered 1...5 to match the check-in sheet's scale.
    static let moodLabels = ["rough", "low", "okay", "good", "great"]

    /// "mostly good" from whatever moods the week actually has, or nil when it
    /// has none. Averaging two entries is not a trend, so it says "mostly"
    /// rather than pretending to more precision than three taps can carry.
    static func moodSummary(_ days: [TendedDay]) -> String? {
        let moods = days.compactMap(\.mood).filter { (1...5).contains($0) }
        guard !moods.isEmpty else { return nil }
        let mean = Double(moods.reduce(0, +)) / Double(moods.count)
        let index = min(4, max(0, Int(mean.rounded()) - 1))
        return "mostly \(moodLabels[index])"
    }

    /// The line under the strip. Deliberately never scolds: a low count is
    /// reported, not judged, because the one thing that reliably makes someone
    /// stop opening a recovery app is being told off by it.
    static func summary(_ days: [TendedDay]) -> String {
        let tended = tendedCount(days)
        switch tended {
        case 0: return "Tend a day to start your week"
        case length: return "All \(length) days tended"
        default: return "\(tended) of \(length) days tended"
        }
    }
}
