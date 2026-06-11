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
# Use the dedicated device — see "Simulator — dedicated, headless" section below
UDID=$(agent-sim boot sober)
xcodebuild -project Sober.xcodeproj -scheme Sober \
  -configuration Debug -destination "id=$UDID" build
xcodebuild test -project Sober.xcodeproj -scheme Sober -destination "id=$UDID"
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

## App Store reviews
- Enjoyment funnel after **daily check-in** or **garden unlock celebration** (3.5s delay); explicit Rate → `AppStoreReviewLinks.writeReviewURL`; `requestReview()` only after Yes + "Maybe later" dismiss. Settings → **Rate or Send Feedback**. Playbook: `~/Desktop/app-store-5-star-review-strategy.md`.

## Gotchas
- App Group entitlement requires the paid Apple Dev account (team `YXG4MP6W39`).
- `Sober.storekit` lets you test the paywall in the simulator without RevenueCat dashboard config.
- `SubscriptionService.apiKey` is a placeholder — replace with the live RC SDK key before TestFlight.
- SwiftData migrations: any change to a `@Model`'s stored properties needs a schema migration (lightweight is fine for now; we wipe-and-retry on corruption).
- Widget snapshots are decoupled from SwiftData via `WidgetSnapshotStore` so the widget doesn't need a SwiftData schema.

## Simulator — dedicated, headless (required)

This project owns the simulator device `agent-sober`. Multiple agents work in
parallel on this machine: NEVER build/test against a shared named destination
(e.g. `name=iPhone 17 Pro`) and NEVER open Simulator.app — it steals Jack's
mouse/keyboard. Everything runs headless. Full guide: `~/docs/ios-agent-simulators.md`

```bash
UDID=$(agent-sim boot sober)        # create if needed + boot headless; prints UDID
xcodebuild -project Sober.xcodeproj -scheme Sober -destination "id=$UDID" build
xcodebuild test -project Sober.xcodeproj -scheme Sober -destination "id=$UDID"
APP=$(find ~/Library/Developer/Xcode/DerivedData/Sober-*/Build/Products -maxdepth 2 -name "*.app" -path "*iphonesimulator*" | head -1)
xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" "$(defaults read "$APP/Info" CFBundleIdentifier)"
axe describe-ui --udid "$UDID"        # inspect UI via accessibility tree
axe tap --label "Continue" --udid "$UDID"   # interact without mouse/keyboard
agent-sim screenshot sober          # PNG at /tmp/agent-sober.png
agent-sim shutdown sober            # free resources when done
```

## TestFlight on every update

After finishing a change and pushing to git, ALWAYS upload a new TestFlight build by
running `./scripts/testflight.sh` — do this unprompted on every push that changes app
code. Jack tests every update on his device and shouldn't have to ask.
