import Foundation

/// Expresses a Bloom+ price in the user's own habit spend — "about a day and a
/// half of drinking" — which is the one anchor this app has that the App Store
/// cannot provide. Everywhere else a price appears it competes with other apps;
/// here it competes with the thing the user is trying to stop paying for.
///
/// Deliberately names no amount. The real localized price is always displayed
/// separately (Apple 3.1.2), and a figure written here would be a literal that
/// goes stale on the next ladder move.
enum HabitPriceComparison {
    /// Past this many habit-days the line stops flattering the price and starts
    /// drawing attention to the total, so it is suppressed instead.
    static let maxDays: Double = 10

    /// `price` and `costPerDay` have to be the same currency. Both come from the
    /// user's own storefront (StoreKit price, and a figure they typed into a
    /// slider labelled in their locale's currency), so they are.
    static func daysOfHabit(price: Double, costPerDay: Double) -> Double? {
        guard price > 0, costPerDay > 0 else { return nil }
        let days = price / costPerDay
        guard days <= maxDays else { return nil }
        return days
    }

    /// "about a day and a half of drinking", or nil when the comparison doesn't
    /// help. `habitNoun` keeps this reusable across the fork (Quit Zyn spends
    /// on pouches, not drinks).
    static func phrase(price: Double, costPerDay: Double, habitNoun: String = "drinking") -> String? {
        guard let days = daysOfHabit(price: price, costPerDay: costPerDay) else { return nil }
        return "\(dayCount(days)) of \(habitNoun)"
    }

    /// Rounds to the nearest half day and spells it out. Half-day granularity is
    /// deliberate: "1.4 days" reads like a calculation, "about a day and a half"
    /// reads like something a person would say.
    static func dayCount(_ days: Double) -> String {
        if days < 0.75 { return "less than a day" }
        if days < 1.25 { return "about a day" }
        if days < 1.75 { return "about a day and a half" }
        let halves = (days * 2).rounded()
        let whole = Int(halves / 2)
        return halves.truncatingRemainder(dividingBy: 2) == 0
            ? "about \(whole) days"
            : "about \(whole) and a half days"
    }
}
