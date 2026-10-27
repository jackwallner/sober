import Foundation
import SwiftData

enum JournalKind: String, Codable, CaseIterable {
    case daily
    case challenge
    case freeform
}

@Model
final class JournalEntry {
    var id: UUID
    var createdAt: Date
    var promptID: String?
    var kindRaw: String
    var text: String
    var feeling: String?   // e.g. "good", "excellent", "neutral"

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        promptID: String? = nil,
        kind: JournalKind = .daily,
        text: String,
        feeling: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.promptID = promptID
        self.kindRaw = kind.rawValue
        self.text = text
        self.feeling = feeling
    }

    var kind: JournalKind { JournalKind(rawValue: kindRaw) ?? .daily }
}

extension JournalEntry {
    /// The stored feeling ("good", "tough") as a label in the user's language.
    /// Unknown values pass through so old entries still show something.
    static func feelingLabel(_ feeling: String) -> String {
        switch feeling {
        case "excellent": String(localized: "Excellent")
        case "good": String(localized: "Good")
        case "neutral": String(localized: "Neutral")
        case "tough": String(localized: "Tough")
        case "rough": String(localized: "Rough")
        default: feeling
        }
    }
}
