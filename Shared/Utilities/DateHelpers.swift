import Foundation

enum DateHelpers {
    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func daysAgo(_ days: Int, from date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: startOfDay(date))
            ?? startOfDay(date)
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let dayA = cal.startOfDay(for: a)
        let dayB = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: dayA, to: dayB).day ?? 0
    }

    static func hoursBetween(_ a: Date, _ b: Date) -> Double {
        b.timeIntervalSince(a) / 3600.0
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    static func dayOfYear(_ date: Date = .now) -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    private static let mediumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    static func mediumDate(_ date: Date) -> String { mediumFormatter.string(from: date) }
    static func dayOfWeek(_ date: Date) -> String { dayOfWeekFormatter.string(from: date) }
}
