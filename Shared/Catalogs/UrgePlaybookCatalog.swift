import Foundation

/// The situations the first urges usually come from. Display order.
enum UrgeTrigger: String, CaseIterable, Identifiable {
    case eveningAlone
    case social
    case stress
    case boredom
    case celebration
    case habitCue

    var id: String { rawValue }
}

/// One trigger's plan: a few things to do, in order, and one line to say when
/// someone offers.
struct UrgePlan: Identifiable, Equatable {
    let trigger: UrgeTrigger
    let title: String
    let icon: String
    /// When this plan applies, in the user's words rather than ours.
    let situation: String
    let steps: [String]
    let script: String

    var id: String { trigger.rawValue }
}

/// Bloom+ content: what to do in the first urges, by trigger.
///
/// Practical, behavioural, and modest on purpose. Nothing here promises an
/// outcome or gives medical advice (App Review 1.4.1). Every habit-specific
/// word comes from `HabitVocabulary`, so a fork inherits this file unchanged.
enum UrgePlaybookCatalog {
    private typealias V = HabitVocabulary

    /// Header for the script, the same across plans.
    static var scriptHeading: String { "When you're offered \(V.habitInstance)" }

    static let all: [UrgePlan] = [
        UrgePlan(
            trigger: .eveningAlone,
            title: "Evening alone",
            icon: "moon.stars.fill",
            situation: "The house is quiet and the old routine starts knocking.",
            steps: [
                "Change rooms or step outside for five minutes. Urges are tied to the place they usually happen.",
                "Make \(V.replacementInstance), or something warm, and keep it in your hand.",
                "Text one person. Even \"hey\" breaks the loop.",
                "If it's still loud, start a breathing session and let it crest.",
            ],
            script: "No thanks, I'm set for tonight."
        ),
        UrgePlan(
            trigger: .social,
            title: "Social, or offered one",
            icon: "person.2.fill",
            situation: "Friends, a party, a work thing, or someone handing you \(V.habitInstance).",
            steps: [
                "Have \(V.replacementInstance) in hand before anyone asks.",
                "Decide when you're leaving before you arrive, and tell one person.",
                "Stand near someone who knows you're not \(V.habitGerund).",
                "Step outside for two minutes when the next round comes.",
            ],
            script: "I'm good, thanks. Already got this one."
        ),
        UrgePlan(
            trigger: .stress,
            title: "Stress",
            icon: "bolt.heart.fill",
            situation: "A hard day, an argument, or a lot landing at once.",
            steps: [
                "Name it out loud: \"This is stress looking for a way out.\"",
                "Do three minutes of breathing before you decide anything.",
                "Walk for ten minutes. Moving burns off the edge the urge rides on.",
                "Write down the one thing weighing on you and the next small step on it.",
            ],
            script: "Not today. I want a clear head for this one."
        ),
        UrgePlan(
            trigger: .boredom,
            title: "Boredom",
            icon: "hourglass",
            situation: "Nothing to do, and the old habit offers to fill the time.",
            steps: [
                "Set a 15-minute timer and keep your hands busy: dishes, a walk, a game.",
                "Eat something. Hunger and boredom both get mistaken for \(V.urgeNounPlural).",
                "Plan one good thing for tomorrow so tonight has a shape.",
            ],
            script: "I'm not \(V.habitGerund) right now. Want to do something else instead?"
        ),
        UrgePlan(
            trigger: .celebration,
            title: "Celebration",
            icon: "party.popper.fill",
            situation: "A birthday, a win, a holiday, a toast.",
            steps: [
                "Pick what you'll raise in advance: \(V.replacementInstance).",
                "Tell the host or one friend ahead of time, so nobody pushes.",
                "Celebrate with something you'll remember: the food, dessert, a photo.",
                "Leave while it's still good.",
            ],
            script: "Cheers! I'm celebrating with this one."
        ),
        UrgePlan(
            trigger: .habitCue,
            title: "The usual time",
            icon: "clock.fill",
            situation: "After work, with dinner, the moment it always used to happen.",
            steps: [
                "Change the first ten minutes: a different route home, seat, or glass.",
                "Have \(V.replacementInstance) ready before the usual moment.",
                "Keep none at home for the first few weeks if you can.",
                "Put something on the calendar at the time it usually hits.",
            ],
            script: "I'm taking a break from it. Feeling better for it, too."
        ),
    ]

    static func plan(for trigger: UrgeTrigger) -> UrgePlan {
        all.first { $0.trigger == trigger } ?? all[0]
    }

    /// The plan for a trigger chip the user picked after a session.
    static func plan(forTag tag: String?) -> UrgePlan? {
        guard let tag, let trigger = tagMap[tag] else { return nil }
        return plan(for: trigger)
    }

    /// Every chip in `HabitVocabulary.triggers` maps to a plan. A fork that
    /// renames a chip has to update this table, and a test checks it did.
    static let tagMap: [String: UrgeTrigger] = [
        "Social event": .social,
        "Stress": .stress,
        "Argument": .stress,
        "Boredom": .boredom,
        "After work": .habitCue,
        "With a meal": .habitCue,
        "Celebration": .celebration,
        "Tired": .eveningAlone,
    ]
}
