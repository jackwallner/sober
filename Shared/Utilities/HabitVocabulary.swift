import Foundation

/// Every word in the craving, slip, and patterns features that changes when
/// this app is forked to a different habit.
///
/// **This is the fork point.** Nothing in those features names a substance
/// directly, so porting them to Quit Zyn (or any later fork) is an edit to this
/// one file rather than a sweep through the feature code. If you find yourself
/// writing "alcohol" or "drink" anywhere else in a feature, add a term here
/// instead.
///
/// Rules for anything added:
///   * Values are nouns and short phrases, never whole sentences with English
///     grammar baked around them, so a fork can reshape the sentence.
///   * No prices (they go stale), and no treat/cure/diagnose language
///     (App Review 1.4.1).
enum HabitVocabulary {
    /// What the user is abstaining from, lowercase, used mid-sentence.
    /// Sober: "alcohol". Quit Zyn: "nicotine".
    static let substance = "alcohol"

    /// The activity as a gerund, for phrases like "a day and a half of ___".
    /// Sober: "drinking". Quit Zyn: "pouches".
    static let habitGerund = "drinking"

    /// A single instance of the habit, with its article.
    /// Sober: "a drink". Quit Zyn: "a pouch".
    static let habitInstance = "a drink"

    /// What the app calls an urge, lowercase. Both current apps say "craving";
    /// it stays configurable because it is the most-repeated noun in the
    /// feature and a fork may prefer "urge".
    static let urgeNoun = "craving"
    static let urgeNounPlural = "cravings"

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

    /// Example shown in the "why you started" reasons editor.
    static let reasonPlaceholder = "So I can be present with my kids"
}
