# Sober — Claude Project Guide

iOS + watchOS app that helps users track sobriety (alcohol-specific in v1). Day counter, sobriety calendar, virtual garden that grows with sober days, health-benefit timeline, journal, achievements, money/calories saved. Freemium with RevenueCat: core counter + garden + calendar are free, the rest is gated behind a Pro entitlement.

XcodeGen project/scheme: `Sober`, sim lease owner `sober`.

## Tech stack
- Swift 6 strict concurrency, SwiftUI, SwiftData (App Group store).
- iOS 17, watchOS 10. XcodeGen (`project.yml`). RevenueCat 5.14+ via SPM. WidgetKit.

## Targets (project.yml)
- `Sober` (iOS app) — bundle `com.jackwallner.sober`
- `SoberWatch` (watchOS app) — `com.jackwallner.sober.watch`
- `SoberWidgets` (iOS widget extension) — `com.jackwallner.sober.widgets`
- `SoberTests` (unit tests)

All share App Group `group.com.jackwallner.sober` for SwiftData container + widget snapshots.

## Architecture
- `Shared/Models/` — SwiftData `@Model` types: SobrietyJourney, DailyCheckIn, JournalEntry, GardenState, UserSettings, UnlockedAchievement, UnlockedHealthBenefit.
- `Shared/Services/` — DataService (container), SobrietyService, CheckInService, SettingsService, GardenService, NotificationService, SubscriptionService (RevenueCat wrapper), WidgetSnapshotPump.
- `Shared/Catalogs/` — static content: HealthBenefitCatalog (13 NIAAA milestones), AchievementCatalog, JournalPromptCatalog, GardenSpeciesCatalog.
- `Shared/Utilities/` — Theme, DateHelpers, AppGroup, WidgetSnapshot.
- `Sober/Features/` — feature folders (Onboarding, Today, Calendar, Health, Journal, Achievements, Stats, Settings, Paywall, Components).

Root flow: `SoberApp → RootView → (OnboardingView | MainTabView)`.

## Craving mode + slips (added 2026-09-03)
The two features aimed at the moments the app used to have nothing to say to.
Both cores are in `Shared/`, both are **free and ungated**, and every
habit-specific word in them lives in `Shared/Utilities/HabitVocabulary.swift`.
**That file is the fork point**: porting all of this to Quit Zyn is an edit to
it, not a sweep through the feature code. Never write "alcohol" or "drink" in
craving/slip/patterns code, add a term there instead.
- **Craving mode** (`Sober/Features/Craving/CravingModeView.swift`): full-screen
  box-breathing ride-it-out session, logged as `CravingEpisode`. No paywall
  anywhere in the flow. Intensity and trigger are captured on the way *out*, not
  the way in. Copy arc lives in `Shared/Catalogs/CravingCoachCatalog.swift`.
- **Slips don't erase the garden.** `GardenService.recordSlip` banks half the
  tree's growth into `GardenState.carryoverDays`; the tree renders at
  `GardenService.treeDays(streakDays:carryover:)` while the counter keeps showing
  the honest streak. Carryover is clamped below the 365-day cycle so it can never
  wrap and shrink the tree. Everything that logs a slip goes through
  `SlipRecorder` so Home and Timeline can't drift apart again.
- **`DailyCheckIn.wasLogged`** separates a day the user tapped from one
  `fillJourney` filled in. Home's week strip (`TendedWeek` + `WeekStripView`) and
  Timeline's calendar shading both key off it, and so does
  `daysSinceLastCheckIn` (counting rows made it permanently return 1).

## Pro entitlement (`"pro"`, shown as Bloom+)
The line is drawn by **tense**, not by feature count (re-cut 2026-08-21). Selling a
bigger version of a complete free app is what put trial starts at 3%.
- **Free owns the past**: day counter, single check-in/day, calendar, basic garden,
  first 5 health benefits, earned achievement badges, and **money/calories kept so
  far** (moved out of Pro in the Wave 1 re-cut, so the paywall can open with a
  number the user already earned).
- **Bloom+ owns the future**: the year-ahead projection, full health timeline +
  sources, journal compose, additional garden species.
- **Bloom+ owns *you*** (added 2026-09-03, now the headline): `CravingInsights`
  reads the user's own logged urges back to them, and `BloomFeature.patterns`
  leads the paywall. The enum's declaration order *is* the paywall's priority
  order. Every reading has a sample floor and returns nil below it rather than
  inventing a claim; `nextUnlock` says what's still coming. Riding out an urge
  routes to the `.patterns` pitch, the highest-intent moment in the app.

Prices are never literals: read them from StoreKit, and express them against the
user's own habit spend via `HabitPriceComparison` rather than quoting figures.

## App-specific notes
- Enjoyment funnel triggers after **daily check-in** or **garden unlock celebration** (3.5s delay). (Shared funnel mechanics + playbook in the `ios-dev` skill.)
- `Sober.storekit` tests the paywall in the simulator without RevenueCat dashboard config.
- SwiftData migrations: any change to a `@Model`'s stored properties needs a schema migration (lightweight is fine for now; wipe-and-retry on corruption).
- Widget snapshots are decoupled from SwiftData via `WidgetSnapshotStore` so the widget doesn't need a SwiftData schema.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, RevenueCat dev tips, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill.

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
