import Testing
import Foundation
import SwiftData
@testable import Sober

@Suite("Tree growth carried across a slip")
struct TreeCarryoverTests {
    @Test func noCarryoverMeansTreeDaysEqualsStreak() {
        #expect(GardenService.treeDays(streakDays: 40, carryover: 0) == 40)
        #expect(GardenService.treeDays(streakDays: 0, carryover: 0) == 0)
    }

    @Test func carryoverLiftsTheTreeAboveTheStreak() {
        #expect(GardenService.treeDays(streakDays: 3, carryover: 20) == 23)
    }

    /// The whole mechanic depends on the tree never appearing to shrink, so
    /// carryover must not push the render past the 365-day cycle boundary,
    /// where `cycleProgress` would wrap it back to a sapling.
    @Test func carryoverNeverWrapsTheCycle() {
        let days = GardenService.treeDays(streakDays: 300, carryover: 300)
        #expect(days == 364)
        #expect(GardenService.cycleProgress(forDays: days).completed == 0)
        #expect(GardenService.stage(forDays: days) == .ancient)
    }

    /// Past a full year the streak has outgrown its inheritance, and adding to
    /// it would be the one case that does wrap.
    @Test func aFullYearIgnoresCarryover() {
        #expect(GardenService.treeDays(streakDays: 365, carryover: 200) == 365)
        #expect(GardenService.treeDays(streakDays: 400, carryover: 200) == 400)
    }

    @Test func carryoverAndStreakStayContinuousAcrossTheBoundary() {
        // 364 -> 365 must not jump or regress, or the tree stutters on the day
        // the grove is supposed to gain a tree.
        #expect(GardenService.treeDays(streakDays: 364, carryover: 50) == 364)
        #expect(GardenService.treeDays(streakDays: 365, carryover: 50) == 365)
    }
}

@Suite("Recording a slip")
@MainActor
struct SlipCarryoverTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func slipBanksHalfTheTree() throws {
        let svc = GardenService(context: try container().mainContext)
        #expect(svc.recordSlip(previousStreakDays: 40) == 20)
        #expect(svc.current().carryoverDays == 20)
    }

    /// Two slips in a row must not reduce the tree to nothing in one step, but
    /// they must compound rather than each measuring against the raw streak.
    @Test func repeatedSlipsCompoundFromWhatTheTreeActuallyHad() throws {
        let svc = GardenService(context: try container().mainContext)
        #expect(svc.recordSlip(previousStreakDays: 40) == 20)
        // Streak of 4 on a tree already carrying 20 is a 24-day tree.
        #expect(svc.recordSlip(previousStreakDays: 4) == 12)
    }

    @Test func slipKeepsTheGroveAndDropsVitalityWithoutKillingIt() throws {
        let svc = GardenService(context: try container().mainContext)
        svc.processCycleCompletions(days: 366)
        #expect(svc.current().completedTreeStyles.count == 1)

        svc.recordSlip(previousStreakDays: 30)
        #expect(svc.current().completedTreeStyles.count == 1)
        #expect(svc.current().vitality >= 0.3)
        #expect(svc.current().lastUnlockNotifiedAtDays == 0)
    }

    /// A deliberate reset is the user saying they set the counter up wrong,
    /// which is the one case where the tree really should start over.
    @Test func deliberateResetClearsCarryover() throws {
        let svc = GardenService(context: try container().mainContext)
        svc.recordSlip(previousStreakDays: 40)
        svc.resetForNewJourney()
        #expect(svc.current().carryoverDays == 0)
    }
}

@Suite("Craving session logging")
@MainActor
struct CravingServiceTests {
    private func service() throws -> CravingService {
        let container = try ModelContainer(
            for: CravingEpisode.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CravingService(context: container.mainContext)
    }

    @Test func onlyRiddenOutSessionsCountTowardTheTally() throws {
        let svc = try service()
        svc.record(startedAt: .now, secondsElapsed: 180, outcome: .rodeItOut, intensity: 4)
        svc.record(startedAt: .now, secondsElapsed: 30, outcome: .gaveIn, intensity: 5)
        svc.record(startedAt: .now, secondsElapsed: 10, outcome: .unresolved, intensity: 3)
        #expect(svc.all().count == 3)
        #expect(svc.rodeOutCount() == 1)
    }

    @Test func intensityIsClampedToTheScale() throws {
        let svc = try service()
        let low = svc.record(startedAt: .now, secondsElapsed: 5, outcome: .rodeItOut, intensity: -2)
        let high = svc.record(startedAt: .now, secondsElapsed: 5, outcome: .rodeItOut, intensity: 99)
        #expect(low.intensity == 1)
        #expect(high.intensity == 5)
    }

    @Test func outcomeSurvivesTheRawStringRoundTrip() throws {
        let svc = try service()
        let episode = svc.record(startedAt: .now, secondsElapsed: 60, outcome: .gaveIn, intensity: 3)
        #expect(episode.outcome == .gaveIn)
        episode.outcome = .rodeItOut
        #expect(episode.outcomeRaw == CravingOutcome.rodeItOut.rawValue)
    }
}

@Suite("Craving coach copy")
struct CravingCoachTests {
    /// The arc is keyed to progress, not seconds, so a short session and a
    /// long one both get the whole thing rather than the opening line twice.
    @Test func shortAndLongSessionsBothTravelTheFullArc() {
        let short = (0...60).map { CravingCoach.line(elapsed: $0, target: 60) }
        let long = (0...600).map { CravingCoach.line(elapsed: $0, target: 600) }
        #expect(Set(short).count == Set(long).count)
        #expect(short.first == long.first)
        #expect(short.last == long.last)
    }

    @Test func aZeroLengthSessionDoesNotDivideByZero() {
        #expect(!CravingCoach.line(elapsed: 0, target: 0).isEmpty)
    }
}
