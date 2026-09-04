import Foundation

/// What the ride-it-out screen says while the clock runs.
///
/// The arc is deliberate and it is the whole point of the feature: an urge
/// feels permanent from the inside, so the copy's job is to keep saying, in
/// different words, that it is not. Nothing here promises an outcome, gives
/// medical advice, or congratulates the user before they have done anything.
///
/// Substance-neutral by construction: the only habit-specific word comes from
/// `HabitVocabulary`, so a fork inherits this file unchanged.
enum CravingCoach {
    /// Fractions of the session at which the message turns over. Keyed to
    /// progress rather than wall-clock seconds so a 1-minute session and a
    /// 10-minute one both get the full arc instead of the first line twice.
    static func line(elapsed: Int, target: Int) -> String {
        let progress = target > 0 ? Double(elapsed) / Double(target) : 1
        switch progress {
        case ..<0.15:
            return "You don't have to do anything else right now. Just stay here and breathe."
        case ..<0.35:
            return "This is near the top of it. \(HabitVocabulary.urgeNounPlural.capitalized) climb fast and then they stop climbing."
        case ..<0.6:
            return "Notice it without arguing with it. You're not trying to win, you're waiting it out."
        case ..<0.85:
            return "It's already smaller than it was a minute ago, even if it doesn't feel finished."
        default:
            return "Almost through. Whatever's left of it is on its way out."
        }
    }

    /// One line for the Home button's subtitle, so the affordance says what it
    /// does rather than only naming the feeling.
    static var buttonSubtitle: String {
        "Ride it out with a few minutes of breathing"
    }
}
