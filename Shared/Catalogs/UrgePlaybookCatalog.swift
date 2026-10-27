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
/// outcome or gives medical advice (App Review 1.4.1). Copy is whole sentences
/// in the string catalog, so a fork rewrites the habit words there.
enum UrgePlaybookCatalog {
    /// Header for the script, the same across plans.
    static var scriptHeading: String { String(localized: "When you're offered a drink") }

    static let all: [UrgePlan] = [
        UrgePlan(
            trigger: .eveningAlone,
            title: String(localized: "Evening alone"),
            icon: "moon.stars.fill",
            situation: String(localized: "The house is quiet and the old routine starts knocking."),
            steps: [
                String(localized: "Change rooms or step outside for five minutes. Urges are tied to the place they usually happen."),
                String(localized: "Make a soda water with lime, or something warm, and keep it in your hand."),
                String(localized: "Text one person. Even \"hey\" breaks the loop."),
                String(localized: "If it's still loud, start a breathing session and let it crest."),
            ],
            script: String(localized: "No thanks, I'm set for tonight.")
        ),
        UrgePlan(
            trigger: .social,
            title: String(localized: "Social, or offered one"),
            icon: "person.2.fill",
            situation: String(localized: "Friends, a party, a work thing, or someone handing you a drink."),
            steps: [
                String(localized: "Have a soda water with lime in hand before anyone asks."),
                String(localized: "Decide when you're leaving before you arrive, and tell one person."),
                String(localized: "Stand near someone who knows you're not drinking."),
                String(localized: "Step outside for two minutes when the next round comes."),
            ],
            script: String(localized: "I'm good, thanks. Already got this one.")
        ),
        UrgePlan(
            trigger: .stress,
            title: String(localized: "Stress"),
            icon: "bolt.heart.fill",
            situation: String(localized: "A hard day, an argument, or a lot landing at once."),
            steps: [
                String(localized: "Name it out loud: \"This is stress looking for a way out.\""),
                String(localized: "Do three minutes of breathing before you decide anything."),
                String(localized: "Walk for ten minutes. Moving burns off the edge the urge rides on."),
                String(localized: "Write down the one thing weighing on you and the next small step on it."),
            ],
            script: String(localized: "Not today. I want a clear head for this one.")
        ),
        UrgePlan(
            trigger: .boredom,
            title: String(localized: "Boredom"),
            icon: "hourglass",
            situation: String(localized: "Nothing to do, and the old habit offers to fill the time."),
            steps: [
                String(localized: "Set a 15-minute timer and keep your hands busy: dishes, a walk, a game."),
                String(localized: "Eat something. Hunger and boredom both get mistaken for cravings."),
                String(localized: "Plan one good thing for tomorrow so tonight has a shape."),
            ],
            script: String(localized: "I'm not drinking right now. Want to do something else instead?")
        ),
        UrgePlan(
            trigger: .celebration,
            title: String(localized: "Celebration"),
            icon: "party.popper.fill",
            situation: String(localized: "A birthday, a win, a holiday, a toast."),
            steps: [
                String(localized: "Pick what you'll raise in advance: a soda water with lime."),
                String(localized: "Tell the host or one friend ahead of time, so nobody pushes."),
                String(localized: "Celebrate with something you'll remember: the food, dessert, a photo."),
                String(localized: "Leave while it's still good."),
            ],
            script: String(localized: "Cheers! I'm celebrating with this one.")
        ),
        UrgePlan(
            trigger: .habitCue,
            title: String(localized: "The usual time"),
            icon: "clock.fill",
            situation: String(localized: "After work, with dinner, the moment it always used to happen."),
            steps: [
                String(localized: "Change the first ten minutes: a different route home, seat, or glass."),
                String(localized: "Have a soda water with lime ready before the usual moment."),
                String(localized: "Keep none at home for the first few weeks if you can."),
                String(localized: "Put something on the calendar at the time it usually hits."),
            ],
            script: String(localized: "I'm taking a break from it. Feeling better for it, too.")
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
