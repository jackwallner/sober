import Foundation

/// Deterministic "today's growth" phrasing keyed off the current day in the
/// bonsai's annual cycle. The bonsai renderer is a continuous function of day,
/// so something does change every day — this surfaces it in copy.
enum DailyGrowth {
    private static var phrases: [String] { [
        String(localized: "a new leaf unfurled"),
        String(localized: "the trunk gained a hair of girth"),
        String(localized: "a fresh shoot pushed out"),
        String(localized: "the canopy filled in a touch"),
        String(localized: "bark hardened another shade"),
        String(localized: "a tiny bud appeared"),
        String(localized: "roots spread a fingerwidth"),
        String(localized: "the silhouette sharpened"),
        String(localized: "moss crept a little further"),
        String(localized: "needles deepened in color"),
        String(localized: "a branch tip lengthened"),
        String(localized: "the crown stretched higher"),
    ] }

    static func note(forDayInCycle day: Int) -> String {
        guard day > 0 else { return String(localized: "the seed is settling in") }
        if day >= 365 { return String(localized: "the tree is complete, and the next cycle begins") }
        let idx = abs(day) % phrases.count
        return phrases[idx]
    }
}
