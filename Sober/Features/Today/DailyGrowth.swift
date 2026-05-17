import Foundation

/// Deterministic "today's growth" phrasing keyed off the current day in the
/// bonsai's annual cycle. The bonsai renderer is a continuous function of day,
/// so something does change every day — this surfaces it in copy.
enum DailyGrowth {
    private static let phrases: [String] = [
        "a new leaf unfurled",
        "the trunk gained a hair of girth",
        "a fresh shoot pushed out",
        "the canopy filled in a touch",
        "bark hardened another shade",
        "a tiny bud appeared",
        "roots spread a fingerwidth",
        "the silhouette sharpened",
        "moss crept a little further",
        "needles deepened in color",
        "a branch tip lengthened",
        "the crown stretched higher",
    ]

    static func note(forDayInCycle day: Int) -> String {
        guard day > 0 else { return "the seed is settling in" }
        if day >= 365 { return "the tree is complete — and the next cycle begins" }
        let idx = abs(day) % phrases.count
        return phrases[idx]
    }
}
