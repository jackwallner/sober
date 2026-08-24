import Testing
import Foundation
import SwiftData
@testable import Sober

#if canImport(RevenueCat)
import RevenueCat

@Suite("Trial package preference")
struct TrialPackagePreferenceTests {
    @Test func yearlyWinsWhenBothTrialsExist() {
        #expect(SubscriptionService.preferredTrialKind(from: [.monthly, .yearly]) == .yearly)
    }

    @Test func monthlyIsTheFallback() {
        #expect(SubscriptionService.preferredTrialKind(from: [.monthly]) == .monthly)
    }

    @Test func unknownPackageIsStillUsable() {
        #expect(SubscriptionService.preferredTrialKind(from: [.other]) == .other)
    }

    @Test func emptyPackagesStayUnavailable() {
        #expect(SubscriptionService.preferredTrialKind(from: []) == nil)
    }

    @Test func yearlyWinsRegardlessOfPackageOrder() {
        #expect(SubscriptionService.preferredTrialKind(from: [.other, .monthly, .yearly]) == .yearly)
    }
}

@MainActor
private final class RecordingTrialNotificationScheduler: TrialNotificationScheduling {
    var authorizationRequests = 0
    var scheduledReminder: (endsAt: Date, summary: String?, now: Date)?
    var cancellations = 0

    func ensureAuthorized() async -> Bool {
        authorizationRequests += 1
        return true
    }

    func scheduleTrialEndingReminder(endsAt: Date, summary: String?, now: Date) async {
        scheduledReminder = (endsAt, summary, now)
    }

    func cancelTrialEndingReminder() {
        cancellations += 1
    }
}

@Suite("Trial purchase lifecycle")
@MainActor
struct TrialPurchaseLifecycleTests {
    @Test func trialCustomerInfoRequestsPermissionAndSchedulesDayTwelve() async {
        let scheduler = RecordingTrialNotificationScheduler()
        let previousScheduler = TrialLifecycle.notificationScheduler
        let service = SubscriptionService()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = now.addingTimeInterval(14 * 86_400)

        TrialLifecycle.notificationScheduler = scheduler
        defer {
            _ = service.processPurchaseResult(
                customerInfo: Self.customerInfo(isActive: false, periodType: .normal, expirationDate: nil, now: now),
                userCancelled: false,
                now: now
            )
            TrialLifecycle.notificationScheduler = previousScheduler
        }

        let state = service.processPurchaseResult(
            customerInfo: Self.customerInfo(
                isActive: true,
                periodType: .trial,
                expirationDate: endsAt,
                now: now
            ),
            userCancelled: false,
            now: now
        )

        for _ in 0..<3 { await Task.yield() }

        #expect(state == .purchased)
        #expect(service.isProSubscriber)
        #expect(scheduler.authorizationRequests == 1)
        #expect(scheduler.scheduledReminder?.endsAt == endsAt)
        #expect(scheduler.scheduledReminder?.now == now)
        #expect(TrialLifecycle.endsAt == endsAt)

        let fireDate = NotificationService.trialReminderFireDate(endsAt: endsAt, now: now)
        #expect(fireDate == endsAt.addingTimeInterval(-2 * 86_400))
        #expect(TrialTimeline.reminderDay(forTrialOf: 14) == 12)
    }

    private static func customerInfo(
        isActive: Bool,
        periodType: PeriodType,
        expirationDate: Date?,
        now: Date
    ) -> CustomerInfo {
        let entitlement = EntitlementInfo(
            identifier: SubscriptionService.proEntitlement,
            isActive: isActive,
            willRenew: isActive,
            periodType: periodType,
            latestPurchaseDate: now,
            originalPurchaseDate: now,
            expirationDate: expirationDate,
            store: .appStore,
            productIdentifier: "com.jackwallner.sober.pro.yearly",
            isSandbox: true,
            ownershipType: .purchased
        )
        let entitlements = EntitlementInfos(
            entitlements: [SubscriptionService.proEntitlement: entitlement]
        )
        return CustomerInfo(
            entitlements: entitlements,
            requestDate: now,
            firstSeen: now,
            originalAppUserId: "trial-lifecycle-test"
        )
    }
}

/// The Apple ID that has already used its intro offer is the case that used to
/// fall out of onboarding and land on a paywall sheet a second later: the
/// direct-trial package is nil for them, so the offer step had nothing to sell.
@Suite("Offer for an account with no trial left")
@MainActor
struct OnboardingOfferWithoutTrialTests {
    @Test func anIneligibleAccountStillHasAPlanToBuy() {
        let service = SubscriptionService()
        service.loadPreviewStore(trialDays: 7, introEligible: false)

        #expect(service.hasTrialOfferAvailable == false)
        #expect(service.directTrialPackage == nil)
        #expect(service.directOfferPackage?.soberPackageKind == .yearly)
    }

    @Test func theirPriceHeadlinePromisesNoTrial() {
        let service = SubscriptionService()
        service.loadPreviewStore(trialDays: 7, introEligible: false)

        let headline = service.directTrialPriceHeadline
        #expect(headline != nil)
        #expect(headline?.localizedCaseInsensitiveContains("free") == false)
    }

    @Test func anEligibleAccountStillLeadsWithTheTrial() {
        let service = SubscriptionService()
        service.loadPreviewStore(trialDays: 7)

        #expect(service.directOfferPackage?.identifier == service.directTrialPackage?.identifier)
        #expect(service.directTrialPriceHeadline?.localizedCaseInsensitiveContains("free") == true)
    }
}
#endif

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

@Suite("Garden year cycles")
struct GardenCycleTests {
    @Test func firstYearHasNoCompletedTrees() {
        let c = GardenService.cycleProgress(forDays: 365)
        #expect(c.completed == 0)
        #expect(c.dayInCycle == 365)
    }

    @Test func dayAfterAYearStartsFreshSapling() {
        let c = GardenService.cycleProgress(forDays: 366)
        #expect(c.completed == 1)
        #expect(c.dayInCycle == 1)
    }

    @Test func everyYearBoundaryCountsOneTree() {
        for years in 1...10 {
            let endOfYear = GardenService.cycleProgress(forDays: years * 365)
            #expect(endOfYear.completed == years - 1)
            #expect(endOfYear.dayInCycle == 365)

            let nextDay = GardenService.cycleProgress(forDays: years * 365 + 1)
            #expect(nextDay.completed == years)
            #expect(nextDay.dayInCycle == 1)
        }
    }

    @Test func stageRestartsEachCycle() {
        // Day 400 = day 35 of year two → adolescent, not stuck at legendary.
        #expect(GardenService.stage(forDays: 400) == .adolescent)
        #expect(GardenService.stage(forDays: 365 * 2) == .legendary)
    }
}

@Suite("Garden growth events")
struct GardenGrowthEventTests {
    @Test func stageAdvanceWithinCycle() {
        #expect(GardenService.growthEvent(previousDays: 6, currentDays: 7) == .newStage(.seedling))
    }

    @Test func noEventWithoutChange() {
        #expect(GardenService.growthEvent(previousDays: 10, currentDays: 10) == nil)
    }

    @Test func crossingYearBoundaryCompletesTree() {
        #expect(GardenService.growthEvent(previousDays: 364, currentDays: 366)
            == .treeCompleted(total: 1))
    }

    @Test func completionOutranksStageAdvance() {
        // 360 → 370 crosses the boundary AND would be a stage change;
        // the grove handoff is the story that explains the reset tree.
        #expect(GardenService.growthEvent(previousDays: 360, currentDays: 370)
            == .treeCompleted(total: 1))
    }

    @Test func freshWatermarkNeverAmbushes() {
        // First-ever check after a back-dated 40-year onboarding: no celebration.
        #expect(GardenService.growthEvent(previousDays: 0, currentDays: 365 * 40) == nil)
    }

    @Test func fortyYearBoundaryCounts() {
        #expect(GardenService.growthEvent(previousDays: 365 * 39, currentDays: 365 * 39 + 1)
            == .treeCompleted(total: 39))
    }

    @Test func stageAdvanceDeepIntoYearForty() {
        #expect(GardenService.growthEvent(previousDays: 365 * 39 + 29, currentDays: 365 * 39 + 30)
            == .newStage(.adolescent))
    }
}

@Suite("Garden grove across resets")
@MainActor
struct GardenGroveResetTests {
    @Test func completionsAfterResetStillJoinGrove() throws {
        let container = try ModelContainer(
            for: GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let svc = GardenService(context: container.mainContext)

        // Two years sober → two trees in the grove.
        svc.processCycleCompletions(days: 365 * 2 + 1)
        #expect(svc.current().completedTreeStyles.count == 2)

        // Slip → reset. The grove is a permanent record and survives.
        svc.resetForNewJourney()
        #expect(svc.current().completedTreeStyles.count == 2)

        // The new journey's first completed year must still join the grove
        // (journey cycle count restarts; the baseline keeps it from being
        // absorbed by the pre-reset trees).
        svc.processCycleCompletions(days: 366)
        #expect(svc.current().completedTreeStyles.count == 3)
    }

    @Test func backdatedOnboardingBackfillsWholeGrove() throws {
        let container = try ModelContainer(
            for: GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let svc = GardenService(context: container.mainContext)

        // 40 years sober at first launch → 39 completed trees, year 40 running.
        svc.processCycleCompletions(days: 365 * 40)
        #expect(svc.current().completedTreeStyles.count == 39)
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

@Suite("Milestone-eve reminder scheduling")
struct MilestoneEveTests {
    private static let calendar = Calendar(identifier: .gregorian)

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func firesTheEveningBeforeTheMilestoneLands() {
        let now = Self.date(2026, 8, 1, 8)
        let fire = NotificationService.milestoneEveFireDate(
            currentDays: 5, milestoneDays: 7, hour: 20, now: now, calendar: Self.calendar
        )
        // Day 5 today means day 7 lands in two days, so the nudge is tomorrow.
        #expect(fire == Self.date(2026, 8, 2, 20))
    }

    @Test func firesTodayWhenTheMilestoneIsTomorrow() {
        let now = Self.date(2026, 8, 1, 8)
        let fire = NotificationService.milestoneEveFireDate(
            currentDays: 6, milestoneDays: 7, hour: 20, now: now, calendar: Self.calendar
        )
        #expect(fire == Self.date(2026, 8, 1, 20))
    }

    @Test func skipsWhenTodaysSlotAlreadyPassed() {
        let now = Self.date(2026, 8, 1, 21)
        let fire = NotificationService.milestoneEveFireDate(
            currentDays: 6, milestoneDays: 7, hour: 20, now: now, calendar: Self.calendar
        )
        #expect(fire == nil)
    }

    @Test func skipsWhenTheMilestoneIsAlreadyReached() {
        let now = Self.date(2026, 8, 1, 8)
        let fire = NotificationService.milestoneEveFireDate(
            currentDays: 7, milestoneDays: 7, hour: 20, now: now, calendar: Self.calendar
        )
        #expect(fire == nil)
    }
}

@Suite("Trial-ending reminder timing")
struct TrialReminderTimingTests {
    @Test func firesTwoDaysBeforeASevenDayTrial() {
        let now = Date()
        let ends = now.addingTimeInterval(7 * 86_400)
        let fire = NotificationService.trialReminderFireDate(endsAt: ends, now: now)
        let expected = ends.addingTimeInterval(-2 * 86_400)
        #expect(fire != nil)
        #expect(abs(fire!.timeIntervalSince(expected)) < 1)
    }

    @Test func usesTheMidpointForShortTrials() {
        let now = Date()
        let ends = now.addingTimeInterval(86_400)
        let fire = NotificationService.trialReminderFireDate(endsAt: ends, now: now)
        // A 1-day trial can't get a 2-day lead, so warn halfway through instead
        // of not at all.
        #expect(fire != nil)
        #expect(abs(fire!.timeIntervalSince(now.addingTimeInterval(43_200))) < 1)
    }

    @Test func skipsTrialsAboutToEnd() {
        let now = Date()
        #expect(NotificationService.trialReminderFireDate(endsAt: now.addingTimeInterval(600), now: now) == nil)
    }

    @Test func skipsTrialsAlreadyOver() {
        let now = Date()
        #expect(NotificationService.trialReminderFireDate(endsAt: now.addingTimeInterval(-86_400), now: now) == nil)
    }
}

@Suite("Review prompt milestone bypass")
@MainActor
struct ReviewPromptMilestoneTests {
    /// Snapshots and restores the shared app-group state the tracker persists,
    /// so running the suite doesn't leave a simulator install mid-funnel.
    private func withCleanTracker(_ body: () -> Void) {
        let launches = ReviewPromptTracker.appLaunchCount
        let firstOpen = ReviewPromptTracker.firstAppOpenDate
        let lastShown = ReviewPromptTracker.lastShownDate
        let outcome = ReviewPromptTracker.outcome
        let moments = ReviewPromptTracker.positiveMomentCount
        defer {
            ReviewPromptTracker.appLaunchCount = launches
            ReviewPromptTracker.firstAppOpenDate = firstOpen
            ReviewPromptTracker.lastShownDate = lastShown
            ReviewPromptTracker.outcome = outcome
            ReviewPromptTracker.positiveMomentCount = moments
        }
        ReviewPromptTracker.outcome = nil
        ReviewPromptTracker.lastShownDate = nil
        body()
    }

    @Test func milestoneSkipsTenureGates() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 2
            ReviewPromptTracker.positiveMomentCount = 1
            ReviewPromptTracker.firstAppOpenDate = .now
            #expect(ReviewPromptTracker.canPresentEnjoymentPrompt(hasCompletedSetup: true, isMilestone: true))
        }
    }

    @Test func passivePromptStillWaitsOutTheGates() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 2
            ReviewPromptTracker.positiveMomentCount = 1
            ReviewPromptTracker.firstAppOpenDate = .now
            #expect(!ReviewPromptTracker.canPresentEnjoymentPrompt(hasCompletedSetup: true))
        }
    }

    @Test func milestoneStillRespectsAResolvedPrompt() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.outcome = .openedWriteReview
            #expect(!ReviewPromptTracker.canPresentEnjoymentPrompt(hasCompletedSetup: true, isMilestone: true))
        }
    }

    @Test func milestoneStillRequiresFinishedOnboarding() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            #expect(!ReviewPromptTracker.canPresentEnjoymentPrompt(hasCompletedSetup: false, isMilestone: true))
        }
    }
}

@Suite("Habit price comparison")
struct HabitPriceComparisonTests {
    @Test func yearlyAgainstTwentyADayReadsAsADayAndAHalf() {
        #expect(HabitPriceComparison.phrase(price: 29.99, costPerDay: 20) == "about a day and a half of drinking")
    }

    @Test func monthlyAgainstTwentyADayIsUnderADay() {
        #expect(HabitPriceComparison.phrase(price: 9.99, costPerDay: 20) == "less than a day of drinking")
    }

    @Test func habitNounIsCallerSupplied() {
        #expect(HabitPriceComparison.phrase(price: 34.99, costPerDay: 9, habitNoun: "pouches") == "about 4 days of pouches")
    }

    @Test func lightSpendersGetNoComparison() {
        // $29.99 at $2/day is 15 habit-days, past the point where the
        // comparison flatters the price, so it is suppressed entirely.
        #expect(HabitPriceComparison.phrase(price: 29.99, costPerDay: 2) == nil)
    }

    @Test func missingSpendDataProducesNothing() {
        #expect(HabitPriceComparison.phrase(price: 29.99, costPerDay: 0) == nil)
        #expect(HabitPriceComparison.daysOfHabit(price: 0, costPerDay: 20) == nil)
    }

    @Test func exactlyAtTheCeilingStillRenders() {
        #expect(HabitPriceComparison.phrase(price: 100, costPerDay: 10) == "about 10 days of drinking")
    }

    @Test func halfDaysAreSpelledOut() {
        #expect(HabitPriceComparison.dayCount(0.5) == "less than a day")
        #expect(HabitPriceComparison.dayCount(1.0) == "about a day")
        #expect(HabitPriceComparison.dayCount(1.5) == "about a day and a half")
        #expect(HabitPriceComparison.dayCount(2.0) == "about 2 days")
        #expect(HabitPriceComparison.dayCount(2.4) == "about 2 and a half days")
        #expect(HabitPriceComparison.dayCount(3.0) == "about 3 days")
    }
}

@Suite("Trial timeline days")
@MainActor
struct TrialTimelineDayTests {
    /// The paywall tells the user "Day 12: we'll remind you". If that number and
    /// the day `scheduleTrialEndingReminder` actually fires ever drift apart, the
    /// paywall is making a promise the app doesn't keep — which is the exact
    /// class of bug that left "7 days free" hardcoded in the yearly card while
    /// the real offer changed underneath it.
    @Test(arguments: [3, 7, 14, 30])
    func timelineReminderDayMatchesWhenTheReminderFires(trialDays: Int) {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = now.addingTimeInterval(TimeInterval(trialDays) * 86_400)

        guard let fireDate = NotificationService.trialReminderFireDate(endsAt: endsAt, now: now) else {
            Issue.record("No reminder scheduled for a \(trialDays)-day trial")
            return
        }

        let shownDay = TrialTimeline.reminderDay(forTrialOf: trialDays)
        let firedDay = Int((fireDate.timeIntervalSince(now) / 86_400).rounded())
        #expect(shownDay == firedDay)
    }

    @Test func theReminderNeverLandsOnOrAfterTheChargeDay() {
        for days in 1...30 {
            #expect(TrialTimeline.reminderDay(forTrialOf: days) < max(2, days))
        }
    }
}
