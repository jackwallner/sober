import Testing
import Foundation
@testable import Sober

@Suite("Garden stage progression")
struct GardenServiceTests {
    @Test func seedAtZero() {
        #expect(GardenService.stage(forDays: 0) == .seed)
    }

    @Test func seedlingAtWeek() {
        #expect(GardenService.stage(forDays: 7) == .seedling)
    }

    @Test func adolescentAtMonth() {
        #expect(GardenService.stage(forDays: 30) == .adolescent)
    }

    @Test func legendaryAtYear() {
        #expect(GardenService.stage(forDays: 365) == .legendary)
    }

}

@Suite("Health benefit catalog")
struct HealthBenefitCatalogTests {
    @Test func bloodAlcoholClearingUnlocksAtSixHours() {
        let unlocked = HealthBenefitCatalog.unlocked(hoursSober: 6)
        #expect(unlocked.contains { $0.id == "blood-alcohol-clearing" })
    }

    @Test func nothingUnlockedAtZero() {
        #expect(HealthBenefitCatalog.unlocked(hoursSober: 0).isEmpty)
    }

    @Test func nextBenefitProgresses() {
        let next = HealthBenefitCatalog.next(after: 0)
        #expect(next?.id == "blood-alcohol-clearing")
    }
}

@Suite("Sobriety day counting")
struct SobrietyServiceTests {
    @Test func startDayIsDayOne() {
        // 1-based: the moment you start, you're on Day 1.
        let now = Date()
        #expect(SobrietyService.daysSinceStart(now, asOf: now) == 1)
    }

    @Test func eighthDayAfterAWeek() {
        // Start day is Day 1, so seven calendar days later is Day 8.
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        #expect(SobrietyService.daysSinceStart(weekAgo, asOf: now) == 8)
    }
}
