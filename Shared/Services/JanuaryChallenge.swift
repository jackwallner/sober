import Foundation

/// Dry January 2027: the month-long challenge behind the App Store event card,
/// opened by `sober://dry-january`. Pure date math over check-in facts, so the
/// Home card, the sheet, the badge and the tests all read one answer.
enum JanuaryChallenge {
    static let year = 2027
    static let length = 31
    static let achievementID = "dry-january-2027"
    static let urlScheme = "sober"
    static let urlHost = "dry-january"

    enum Mark: Equatable, Sendable {
        case dry
        case slip
        /// Today or earlier with nothing on record: before the user's first
        /// day, or today before a check-in.
        case open
        case ahead
    }

    struct Day: Equatable, Identifiable, Sendable {
        let date: Date
        let number: Int
        let mark: Mark
        let isToday: Bool
        var id: Int { number }
    }

    enum Phase: Equatable, Sendable {
        case upcoming(daysUntilStart: Int)
        case active
        case finished
    }

    struct Snapshot: Equatable, Sendable {
        let phase: Phase
        let days: [Day]
        var dryDays: Int { days.filter { $0.mark == .dry }.count }
        var isComplete: Bool { dryDays == JanuaryChallenge.length }
    }

    /// The 31 local midnights of January.
    static func days(calendar: Calendar = .current) -> [Date] {
        let first = date(month: 1, day: 1, year: year, calendar: calendar)
        let last = date(month: 1, day: length, year: year, calendar: calendar)
        return CheckInService.calendarDays(from: first, through: last, calendar: calendar)
    }

    /// Home shows the card from the day the App Store starts promoting the
    /// event (two weeks before) until a week after it ends.
    static func showsCard(now: Date, calendar: Calendar = .current) -> Bool {
        let opens = date(month: 12, day: 18, year: year - 1, calendar: calendar)
        return now >= opens && acceptsLink(now: now, calendar: calendar)
    }

    /// The link opens the challenge any time before it is put away.
    static func acceptsLink(now: Date, calendar: Calendar = .current) -> Bool {
        now < date(month: 2, day: 8, year: year, calendar: calendar)
    }

    static func handles(_ url: URL) -> Bool {
        url.scheme?.lowercased() == urlScheme && url.host?.lowercased() == urlHost
    }

    static func snapshot(now: Date, facts: [CheckInFacts], calendar: Calendar = .current) -> Snapshot {
        let today = calendar.startOfDay(for: now)
        let soberByDay = Dictionary(
            facts.map { (calendar.startOfDay(for: $0.day), $0.wasSober) },
            uniquingKeysWith: { first, _ in first }
        )
        let dates = days(calendar: calendar)
        let marked = dates.enumerated().map { index, date -> Day in
            let mark: Mark
            if date > today {
                mark = .ahead
            } else if let wasSober = soberByDay[date] {
                mark = wasSober ? .dry : .slip
            } else {
                mark = .open
            }
            return Day(date: date, number: index + 1, mark: mark, isToday: date == today)
        }
        return Snapshot(phase: phase(today: today, dates: dates, calendar: calendar), days: marked)
    }

    private static func phase(today: Date, dates: [Date], calendar: Calendar) -> Phase {
        guard let first = dates.first, let last = dates.last else { return .finished }
        if today < first {
            let days = calendar.dateComponents([.day], from: today, to: first).day ?? 1
            return .upcoming(daysUntilStart: max(1, days))
        }
        return today > last ? .finished : .active
    }

    private static func date(month: Int, day: Int, year: Int, calendar: Calendar) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.startOfDay(for: calendar.date(from: components) ?? .distantPast)
    }

    /// The clock the challenge reads. Always the real one in a release build.
    static func clock() -> Date {
        #if DEBUG
        if let debugNow { return debugNow }
        #endif
        return .now
    }

    #if DEBUG
    /// `-challengeNow 2027-01-12`: the challenge's clock for captures and UI
    /// tests, which cannot wait for January.
    static let debugNow: Date? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-challengeNow"), index + 1 < args.count else { return nil }
        let parts = args[index + 1].split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
        return Calendar.current.date(from: components)
    }()
    #endif
}
