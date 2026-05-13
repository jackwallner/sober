# Sober — Claude Project Guide

iOS + watchOS app that helps users track sobriety (alcohol-specific in v1). Day counter, sobriety calendar, virtual garden that grows with sober days, health-benefit timeline, journal, achievements, money/calories saved. Freemium with RevenueCat: core counter + garden + calendar are free, the rest is gated behind a Pro entitlement.

## Tech stack
- Swift 6 strict concurrency, SwiftUI, SwiftData (App Group store).
- iOS 17, watchOS 10.
- XcodeGen (`project.yml`).
- RevenueCat 5.14+ via SPM.
- WidgetKit for iOS home/lock-screen widgets.

## Build & run
```bash
xcodegen generate
xcodebuild -project Sober.xcodeproj -scheme Sober \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcodebuild test -project Sober.xcodeproj -scheme Sober \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

TestFlight: `./scripts/testflight.sh` (auto-bumps build, generates project, archives, uploads).

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

## Pro entitlement (`"pro"`)
- Free: day counter, single check-in/day, calendar, basic garden, first 2 health benefits.
- Pro: full health timeline + sources, journal compose, achievement unlocks, money/calories saved, additional garden species.

`SubscriptionService.shared.setLocalOverride(isPro: true)` flips Pro on for dev without a live RC key. Settings has a button to toggle it.

## Phase plan
- Phase 1: scaffold + builds ✅
- Phase 2: Onboarding + Today + Calendar
- Phase 3: Garden visualization
- Phase 4: Pro features (Health, Journal, Achievements, Stats) + Paywall
- Phase 5: Widgets + Watch
- Phase 6: Polish + TestFlight

## Gotchas
- App Group entitlement requires the paid Apple Dev account (team `YXG4MP6W39`).
- `Sober.storekit` lets you test the paywall in the simulator without RevenueCat dashboard config.
- `SubscriptionService.apiKey` is a placeholder — replace with the live RC SDK key before TestFlight.
- SwiftData migrations: any change to a `@Model`'s stored properties needs a schema migration (lightweight is fine for now; we wipe-and-retry on corruption).
- Widget snapshots are decoupled from SwiftData via `WidgetSnapshotStore` so the widget doesn't need a SwiftData schema.
