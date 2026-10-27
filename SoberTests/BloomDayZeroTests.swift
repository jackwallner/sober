import Foundation
import Testing
@testable import Sober

/// Fixed calendar and zone so dates and day counts do not depend on where the
/// suite runs.
private var utc: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    cal.locale = Locale(identifier: "en_US")
    return cal
}

private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, year: Int = 2026) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Suite("Goal projection")
struct GoalProjectionTests {
    @Test func presetLandsOnTheDayTheCounterReadsIt() {
        let start = date(3, 1, 10)
        #expect(GoalPreset.thirtyDays.date(from: start, calendar: utc) == date(3, 30))
        #expect(GoalPreset.ninetyDays.date(from: start, calendar: utc) == date(5, 29))
        #expect(GoalPreset.oneYear.date(from: start, calendar: utc) == date(2, 28, year: 2027))
    }

    @Test func passedPresetsAreNotOffered() {
        let start = date(1, 1, 9)
        let now = date(2, 15, 9)
        #expect(!GoalPreset.thirtyDays.isAhead(start: start, now: now, calendar: utc))
        #expect(GoalPreset.ninetyDays.isAhead(start: start, now: now, calendar: utc))
    }

    @Test func storedDateReadsBackAsItsPreset() {
        let start = date(3, 1, 10)
        #expect(GoalPreset.matching(goal: date(5, 29), start: start, calendar: utc) == .ninetyDays)
        #expect(GoalPreset.matching(goal: date(5, 28), start: start, calendar: utc) == nil)
    }

    @Test func thirtyDayGoalProjectsThirtyDaysOfSpend() {
        let start = date(3, 1, 10)
        let p = GoalProjection(
            start: start, goal: date(3, 30), now: start,
            costPerDayCents: 2000, caloriesPerDay: 600, calendar: utc
        )
        #expect(p.daysToGo == 29)
        #expect(p.dayCountAtGoal == 30)
        #expect(p.moneyCents == 60_000)
        #expect(p.calories == 18_000)
        #expect(p.habitInstances == 18_000 / HabitVocabulary.caloriesPerInstance)
        // A 30-day goal covers the milestones labelled 30 days as well.
        #expect(p.milestonesPassed.count == 8)
        #expect(p.milestonesStillAhead.count == 8)
        #expect(!p.isReached)
    }

    @Test func milestonesAlreadyBehindAreNotStillAhead() {
        let start = date(3, 1, 10)
        let p = GoalProjection(
            start: start, goal: date(3, 30), now: date(3, 10, 10),
            costPerDayCents: 2000, caloriesPerDay: 0, calendar: utc
        )
        #expect(p.daysToGo == 20)
        #expect(p.milestonesPassed.count == 8)
        // The two-week and the two 30-day milestones are still to come.
        #expect(p.milestonesStillAhead.map(\.id) == ["reduced-anxiety", "liver-fat-reduction", "weight-stabilization"])
        #expect(p.habitInstances == nil)
    }

    @Test func pitchLineNeedsSpend() {
        let start = Date.now
        let goal = GoalPreset.thirtyDays.date(from: start)
        let withSpend = GoalProjection(start: start, goal: goal, costPerDayCents: 2000, caloriesPerDay: 600)
        let line = withSpend.pitchLine ?? ""
        #expect(line.hasPrefix("By "))
        #expect(line.contains("600 kept and"))
        #expect(line.hasSuffix("milestones passed"))
        let noSpend = GoalProjection(start: start, goal: goal, costPerDayCents: 0, caloriesPerDay: 600)
        #expect(noSpend.pitchLine == nil)
    }

    @Test func oneYearGoalCoversTheOneYearMilestone() {
        let start = date(3, 1, 10)
        let p = GoalProjection(
            start: start, goal: GoalPreset.oneYear.date(from: start, calendar: utc), now: start,
            costPerDayCents: 0, caloriesPerDay: 0, calendar: utc
        )
        #expect(p.milestonesPassed.count == HealthBenefitCatalog.all.count)
    }

    @Test func goalDayIsReached() {
        let p = GoalProjection(
            start: date(3, 1, 10), goal: date(3, 30), now: date(3, 30, 18),
            costPerDayCents: 0, caloriesPerDay: 0, calendar: utc
        )
        #expect(p.isReached)
        #expect(p.daysToGo == 0)
    }

    @Test func goalDateShowsTheYearOnlyWhenItDiffers() {
        let en = Locale(identifier: "en_US")
        let now = date(10, 12, 9)
        #expect(GoalProjection.shortDate(date(11, 10), now: now, calendar: utc, locale: en) == "Nov 10")
        // A 1-year goal started Oct 12 lands Oct 11 next year, not yesterday.
        let yearOut = GoalPreset.oneYear.date(from: now, calendar: utc)
        #expect(GoalProjection.shortDate(yearOut, now: now, calendar: utc, locale: en) == "Oct 11, 2027")
    }

    @Test func aSlipCarriesOnlyAGoalStillAhead() {
        let now = Date.now
        let ahead = SobrietyJourney(startDate: now, goalDate: now.addingTimeInterval(10 * 86_400))
        let behind = SobrietyJourney(startDate: now, goalDate: now.addingTimeInterval(-2 * 86_400))
        #expect(SobrietyService.carriedGoal(from: ahead, now: now) == ahead.goalDate)
        #expect(SobrietyService.carriedGoal(from: behind, now: now) == nil)
        #expect(SobrietyService.carriedGoal(from: nil, now: now) == nil)
    }

    @Test func goalChoiceRoundTrips() {
        let start = Date.now
        let ninety = GoalPreset.ninetyDays.date(from: start)
        #expect(GoalChoice.from(goal: ninety, start: start) == .preset(.ninetyDays))
        #expect(GoalChoice.from(goal: nil, start: start) == .none)
        #expect(GoalChoice.none.resolvedDate(start: start, customDate: start) == nil)
    }
}

@Suite("Dated milestones")
struct MilestoneScheduleTests {
    /// iOS formats times with a narrow no-break space before AM/PM.
    private func label(_ d: Date, now: Date) -> String {
        MilestoneSchedule.label(for: d, now: now, calendar: utc, locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func nextThreeFromDayZero() {
        let start = date(3, 1, 15, 14)
        let next = MilestoneSchedule.upcoming(start: start, now: start)
        #expect(next.map(\.id) == ["blood-alcohol-clearing", "blood-sugar-stabilization", "rehydration"])
        #expect(next[0].date == date(3, 1, 21, 14))
        #expect(MilestoneSchedule.remainingCount(start: start, now: start) == HealthBenefitCatalog.all.count)
    }

    @Test func passedMilestonesDropOff() {
        let start = date(3, 1, 9)
        let next = MilestoneSchedule.upcoming(start: start, now: date(3, 4, 12))
        #expect(next.first?.id == "mental-clarity")
        #expect(next.count == 3)
    }

    @Test func labelsReadLikeAPlan() {
        let now = date(3, 1, 14)
        #expect(label(date(3, 1, 20, 14), now: now) == "Tonight 8:14 PM")
        #expect(label(date(3, 1, 15), now: now) == "Today 3:00 PM")
        #expect(label(date(3, 2, 14, 32), now: now) == "Tomorrow 2:32 PM")
        #expect(label(date(3, 6, 10), now: now) == "Fri, Mar 6")
        #expect(label(date(3, 6, 10, year: 2027), now: now) == "Mar 6, 2027")
    }

    @Test func pitchLineCountsTheRest() {
        let start = Date.now
        let line = MilestoneSchedule.pitchLine(start: start, now: start)
        #expect(line.hasSuffix(": Blood Alcohol Clearing. Then 12 more, each dated."))
    }

    @Test func pitchLineAfterTheLastMilestone() {
        let start = Date.now.addingTimeInterval(-400 * 86_400)
        #expect(MilestoneSchedule.pitchLine(start: start).hasPrefix("All 13"))
    }
}

@Suite("Urge playbook")
struct UrgePlaybookTests {
    @Test func everyTriggerHasAPlan() {
        for trigger in UrgeTrigger.allCases {
            let plans = UrgePlaybookCatalog.all.filter { $0.trigger == trigger }
            #expect(plans.count == 1, "\(trigger) needs exactly one plan")
            guard let plan = plans.first else { continue }
            #expect((3...4).contains(plan.steps.count), "\(trigger) has \(plan.steps.count) steps")
            #expect(plan.steps.allSatisfy { !$0.isEmpty })
            #expect(!plan.script.isEmpty, "\(trigger) has no script")
            #expect(!plan.title.isEmpty && !plan.situation.isEmpty)
        }
    }

    @Test func everyTriggerChipMapsToAPlan() {
        for tag in HabitVocabulary.triggers {
            #expect(UrgePlaybookCatalog.plan(forTag: tag) != nil, "chip \(tag) has no plan")
        }
        #expect(UrgePlaybookCatalog.plan(forTag: nil) == nil)
    }

    @Test func playbookOffersAReplacementDrink() {
        let text = UrgePlaybookCatalog.all
            .flatMap { [$0.title, $0.situation, $0.script] + $0.steps }
            .joined(separator: " ")
        #expect(text.contains("a soda water with lime"))
        #expect(UrgePlaybookCatalog.scriptHeading.hasSuffix("a drink"))
    }

    @Test func everyTriggerChipHasALabel() {
        for tag in HabitVocabulary.triggers {
            #expect(!HabitVocabulary.triggerLabel(tag).isEmpty)
        }
    }
}

@Suite("Bloom+ feature order")
@MainActor
struct BloomFeatureOrderTests {
    @Test func paywallOrderLeadsWithDayZeroValue() {
        #expect(BloomFeature.allCases == [
            .patterns, .goalProjection, .urgePlaybook,
            .healthTimeline, .savingsTracking, .journal, .gardenSpecies,
        ])
    }

    @Test func newIntentsFocusTheirFeature() {
        #expect(TrialOfferCoordinator.Intent.goalProjection.focusFeature == .goalProjection)
        #expect(TrialOfferCoordinator.Intent.urgePlaybook.focusFeature == .urgePlaybook)
    }
}
