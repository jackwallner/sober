import Foundation

/// Count labels shown beside a number that is drawn separately ("127" over
/// "DAYS SOBER"). A catalog plural variant has to contain its number, so these
/// labels cannot be plural keys themselves. Instead the catalog's
/// `"%lld plural category"` key returns the CLDR category for the user's
/// language ("few 3"), and each label has one whole key per category.
enum PluralLabel {
    enum Category: String {
        case one, few, many, other
    }

    static func category(_ count: Int) -> Category {
        let token = String(localized: "\(count) plural category")
        let word = token.split(separator: " ").first.map(String.init) ?? ""
        return Category(rawValue: word) ?? (count == 1 ? .one : .other)
    }

    /// "Day Sober" / "Days Sober", under Home's counter.
    static func daysSoberTitle(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "Day Sober")
        case .few: String(localized: "Days Sober (few)")
        case .many: String(localized: "Days Sober (many)")
        case .other: String(localized: "Days Sober")
        }
    }

    /// "day sober" / "days sober", under the widget and Watch counters.
    static func daysSober(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "day sober")
        case .few: String(localized: "days sober (few)")
        case .many: String(localized: "days sober (many)")
        case .other: String(localized: "days sober")
        }
    }

    /// "day" / "days", under the circular widget's counter.
    static func days(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "day")
        case .few: String(localized: "days (few)")
        case .many: String(localized: "days (many)")
        case .other: String(localized: "days")
        }
    }

    /// "day to go" / "days to go", beside the goal countdown.
    static func daysToGo(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "day to go")
        case .few: String(localized: "days to go (few)")
        case .many: String(localized: "days to go (many)")
        case .other: String(localized: "days to go")
        }
    }

    /// "craving ridden out" / "cravings ridden out", under Patterns' total.
    static func riddenOut(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "craving ridden out")
        case .few: String(localized: "cravings ridden out (few)")
        case .many: String(localized: "cravings ridden out (many)")
        case .other: String(localized: "cravings ridden out")
        }
    }
}
