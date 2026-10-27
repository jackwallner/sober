import Foundation

/// The habit-specific numbers and tags behind the craving, slip, and patterns
/// features.
///
/// **This is the fork point** for everything that is not copy. User-facing
/// sentences are whole keys in `Shared/Localizable.xcstrings` (word order and
/// grammar differ per language, so a noun cannot be spliced in), which means a
/// fork renames "alcohol", "a drink" and "craving" there, in every language.
///
/// Rules for anything added:
///   * No prices (they go stale), and no treat/cure/diagnose language
///     (App Review 1.4.1).
enum HabitVocabulary {
    /// Rough calories in one instance, used to turn the user's daily calorie
    /// figure into a count of instances. A standard beer or glass of wine is
    /// about 150. A fork with no calories sets this to 0, which hides the count.
    static let caloriesPerInstance = 150

    /// How long a typical urge takes to crest and fade. Drives the default
    /// ride-it-out session length and the coaching copy. Nicotine urges run
    /// shorter and sharper than alcohol ones, so the fork lowers this.
    static let typicalUrgeSeconds = 180

    /// Bounds on a user-chosen session length.
    static let minUrgeSeconds = 60
    static let maxUrgeSeconds = 600

    /// Situations that commonly set off an urge, offered as one-tap tags after
    /// a session. Display order. Keep to eight or fewer: this is a wrapping
    /// chip row, not a taxonomy, and it has to stay scannable by someone who
    /// has just come through a hard few minutes.
    static let triggers = [
        "Social event",
        "Stress",
        "Boredom",
        "After work",
        "With a meal",
        "Argument",
        "Celebration",
        "Tired",
    ]

    /// The chip's label in the user's language. Tags are stored in English
    /// (they key `UrgePlaybookCatalog.tagMap` and the saved episodes), so this
    /// translates at display time and passes unknown tags through.
    static func triggerLabel(_ tag: String) -> String {
        switch tag {
        case "Social event": String(localized: "Social event")
        case "Stress": String(localized: "Stress")
        case "Boredom": String(localized: "Boredom")
        case "After work": String(localized: "After work")
        case "With a meal": String(localized: "With a meal")
        case "Argument": String(localized: "Argument")
        case "Celebration": String(localized: "Celebration")
        case "Tired": String(localized: "Tired")
        default: tag
        }
    }

    /// Example shown in the "why you started" reasons editor.
    static var reasonPlaceholder: String { String(localized: "So I can be present with my kids") }
}
