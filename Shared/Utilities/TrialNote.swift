import Foundation

/// A short note from the studio under the onboarding trial pitch. The `default`
/// offering's `trial_note` metadata switches it, so it starts and stops without
/// a release: `none` (or missing) is the live pitch, `indie` shows the note to
/// everyone, `split` deals each install one arm, 50/50, kept for good. The app
/// reads the `default` offering, not `current`, so a RevenueCat Experiment
/// cannot reach the pitch; the split is how it is tested.
///
/// The note promises "tell us what to fix", so a customer who saw it and then
/// switches the trial's renewal off is asked exactly that, once. The arm rides
/// to RevenueCat as the `trial_note` attribute once the pitch has been seen.
/// Readout: `~/ios/growth/indie-note-test.md`.
enum TrialNote {
    enum Config: String, Sendable {
        case none
        case indie
        case split
    }

    static let metadataKey = "trial_note"
    static let attributeKey = "trial_note"

    private enum Key {
        static let arm = "trialNote.arm"
        static let seen = "trialNote.seen"
        static let asked = "trialNote.whatToFixAsked"
    }

    static func config(from metadata: [String: Any]?) -> Config {
        guard let raw = metadata?[metadataKey] as? String else { return .none }
        return Config(rawValue: raw) ?? .none
    }

    /// Whether the pitch shows the note. Deals a `split` install its arm on the
    /// first call and keeps it; `none` overrides a kept arm, so the switch
    /// stops the note for everyone.
    static func shows(_ config: Config, _ defaults: UserDefaults = .standard, coin: () -> Bool = { Bool.random() }) -> Bool {
        #if DEBUG
        if let pinned = launchOverride { return pinned }
        #endif
        switch config {
        case .none: return false
        case .indie: return true
        case .split:
            if let kept = defaults.object(forKey: Key.arm) as? Bool { return kept }
            let dealt = coin()
            defaults.set(dealt, forKey: Key.arm)
            return dealt
        }
    }

    /// The pitch was on screen; `showedNote` is the arm it was drawn in.
    static func markSeen(showedNote: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(showedNote ? "indie" : "none", forKey: Key.seen)
    }

    /// `indie` or `none` once the pitch was seen while the test was on.
    static func seenArm(_ defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: Key.seen)
    }

    /// True once: the note was seen, the customer is in a free trial, and its
    /// renewal is off.
    static func whatToFixDue(inTrial: Bool, willRenew: Bool, _ defaults: UserDefaults = .standard) -> Bool {
        seenArm(defaults) == "indie" && !defaults.bool(forKey: Key.asked) && inTrial && !willRenew
    }

    static func markAsked(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Key.asked)
    }

    #if DEBUG
    /// `-trialNote.arm none|indie` pins the arm for captures.
    private static var launchOverride: Bool? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-trialNote.arm"), index + 1 < args.count else { return nil }
        return args[index + 1] == "indie"
    }
    #endif
}
