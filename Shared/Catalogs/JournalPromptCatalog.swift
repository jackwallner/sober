import Foundation

struct JournalPrompt: Identifiable, Hashable {
    let id: String
    let kind: JournalKind
    let text: String
}

enum JournalPromptCatalog {
    static let all: [JournalPrompt] = [
        JournalPrompt(id: "p1", kind: .daily, text: String(localized: "How has my daily life changed since I stopped drinking?")),
        JournalPrompt(id: "p2", kind: .daily, text: String(localized: "What's one thing I'm grateful for today?")),
        JournalPrompt(id: "p3", kind: .daily, text: String(localized: "Where did I feel strongest today?")),
        JournalPrompt(id: "p4", kind: .challenge, text: String(localized: "What triggers came up today, and how did I respond?")),
        JournalPrompt(id: "p5", kind: .daily, text: String(localized: "Describe a moment of peace I experienced recently.")),
        JournalPrompt(id: "p6", kind: .daily, text: String(localized: "What's going well today? How can I keep this momentum?")),
        JournalPrompt(id: "p7", kind: .challenge, text: String(localized: "If I had a drink today, what would I lose?")),
        JournalPrompt(id: "p8", kind: .daily, text: String(localized: "Who supported me today, even in a small way?")),
        JournalPrompt(id: "p9", kind: .daily, text: String(localized: "What did my body thank me for today?")),
        JournalPrompt(id: "p10", kind: .daily, text: String(localized: "What am I looking forward to this week?")),
        JournalPrompt(id: "p11", kind: .challenge, text: String(localized: "Name a situation that used to involve drinking. How did I navigate it?")),
        JournalPrompt(id: "p12", kind: .daily, text: String(localized: "What's one healthy habit I'd like to build next?")),
        JournalPrompt(id: "p13", kind: .daily, text: String(localized: "How is my sleep different now?")),
        JournalPrompt(id: "p14", kind: .daily, text: String(localized: "What did I do today that my future self will thank me for?")),
        JournalPrompt(id: "p15", kind: .challenge, text: String(localized: "Where do I notice cravings hide?")),
        JournalPrompt(id: "p16", kind: .daily, text: String(localized: "What does sobriety give me that drinking never could?")),
        JournalPrompt(id: "p17", kind: .daily, text: String(localized: "Describe a small win from today.")),
        JournalPrompt(id: "p18", kind: .daily, text: String(localized: "What's a relationship that's improving since I quit?")),
        JournalPrompt(id: "p19", kind: .challenge, text: String(localized: "What would a 'reset' actually cost me, in days and dollars?")),
        JournalPrompt(id: "p20", kind: .daily, text: String(localized: "Three words to describe how I feel right now.")),
    ]

    /// Deterministic prompt-of-day so widgets and the app agree on what to show.
    static func promptOfDay(for date: Date = .now) -> JournalPrompt {
        let idx = DateHelpers.dayOfYear(date) % all.count
        return all[idx]
    }

    static func prompt(id: String) -> JournalPrompt? {
        all.first { $0.id == id }
    }
}
