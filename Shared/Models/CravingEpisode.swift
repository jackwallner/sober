import Foundation
import SwiftData

/// How a logged urge ended.
enum CravingOutcome: String, Codable, CaseIterable, Sendable {
    /// The user stayed with it and it passed.
    case rodeItOut
    /// The user left the session without saying how it went. Recorded rather
    /// than discarded: someone who opens the tool and bails is still telling
    /// us the urge happened, and dropping those would flatter every stat.
    case unresolved
    /// The user drank. Logged without penalty so the honest number stays
    /// honest; a slip is recorded separately and only if they say so.
    case gaveIn

    var label: String {
        switch self {
        case .rodeItOut: return "It passed"
        case .unresolved: return "Not sure"
        case .gaveIn: return "I gave in"
        }
    }
}

/// One logged urge: when it hit, how strong it felt, and how it ended.
///
/// This is the only model in the app written *during* a hard moment rather
/// than after a good one, which is why nothing about it is gated. The log is
/// what makes the ride-it-out tool work, and putting a purchase decision in
/// front of someone mid-craving would be both cruel and bad business.
@Model
final class CravingEpisode {
    var id: UUID
    var startedAt: Date
    /// Nil only while a session is on screen; set the moment it resolves.
    var endedAt: Date?
    /// 1...5 when answered, or 0 when skipped. Captured after the session.
    /// Keeping an unanswered sentinel preserves the existing stored schema.
    /// Asking someone
    /// to rate an urge before riding it out adds friction at the worst
    /// possible second, and the retrospective rating is the one that predicts
    /// anything anyway.
    var intensity: Int
    var outcomeRaw: String
    var trigger: String?
    /// Seconds the user actually stayed in the session, which is not the same
    /// as the session length they picked.
    var secondsElapsed: Int

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        intensity: Int = 3,
        outcome: CravingOutcome = .unresolved,
        trigger: String? = nil,
        secondsElapsed: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.intensity = intensity
        self.outcomeRaw = outcome.rawValue
        self.trigger = trigger
        self.secondsElapsed = secondsElapsed
    }

    var outcome: CravingOutcome {
        get { CravingOutcome(rawValue: outcomeRaw) ?? .unresolved }
        set { outcomeRaw = newValue.rawValue }
    }
}
