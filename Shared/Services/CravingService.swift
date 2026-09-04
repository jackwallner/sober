import Foundation
import SwiftData

/// Storage for ride-it-out sessions. Deliberately thin: the analysis lives in
/// `CravingInsights` so it can be unit-tested without a ModelContext, and the
/// UI owns the session clock.
@MainActor
final class CravingService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Persist a finished session. The episode is written once, at the end,
    /// rather than opened at the start and updated: a session the user
    /// abandons by force-quitting mid-urge should not leave a dangling row
    /// that later reads as an unresolved craving they never actually logged.
    @discardableResult
    func record(
        startedAt: Date,
        secondsElapsed: Int,
        outcome: CravingOutcome,
        intensity: Int,
        trigger: String? = nil,
        now: Date = .now
    ) -> CravingEpisode {
        let episode = CravingEpisode(
            startedAt: startedAt,
            endedAt: now,
            intensity: min(5, max(1, intensity)),
            outcome: outcome,
            trigger: trigger,
            secondsElapsed: max(0, secondsElapsed)
        )
        context.insert(episode)
        try? context.save()
        return episode
    }

    func all() -> [CravingEpisode] {
        let descriptor = FetchDescriptor<CravingEpisode>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Detached from SwiftData so `CravingInsights` can stay pure.
    func facts() -> [CravingFacts] {
        all().map {
            CravingFacts(
                startedAt: $0.startedAt,
                secondsElapsed: $0.secondsElapsed,
                outcome: $0.outcome,
                intensity: $0.intensity,
                trigger: $0.trigger
            )
        }
    }

    func recent(limit: Int = 5) -> [CravingEpisode] {
        Array(all().prefix(limit))
    }

    /// Total ridden out, ever. Used for the one line the app says back to the
    /// user right after a session, which is the whole reward loop for logging.
    func rodeOutCount() -> Int {
        all().filter { $0.outcome == .rodeItOut }.count
    }
}
