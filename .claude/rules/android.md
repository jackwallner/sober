---
paths:
  - "android/**"
  - "scripts/sync-android-*"
  - "scripts/android-export/**"
  - "scripts/play-*"
  - "scripts/play_screenshot_compositor.py"
  - "scripts/make_android_icon.py"
---

# Sober Android rules

## Product

- Native port in `android/`: Kotlin, Compose, Gradle Kotlin DSL, JDK 17,
  minSdk 26, target/compile 36. Package `com.jackwallner.sober` (permanent),
  launcher label "Sober Tracker", Play title "Sober: Sobriety Day Counter".
- Screen-for-screen port of iOS: same copy, tokens, flows, paid boundary and
  product IDs. When iOS changes, port the change. No Watch app; the widget is
  Glance. Light only (iOS forces light). Nunito and Newsreader stand in for SF
  Rounded and New York.
- Content is exported from Swift, never retyped: `scripts/sync-android-content.sh`
  (`scripts/android-export/main.swift` -> `sober-content.json`) and
  `scripts/sync-android-bonsai.py` (renderer parity fixtures). Rerun after any
  catalog or bonsai change; `BonsaiParityTest` and `PortParityTest` pin parity.
- Play In-App Review: no enjoyment question first, never from a button.
- Reminders use `AlarmManager.setWindow` (15 min) re-armed on delivery;
  `setInexactRepeating` drifted up to 18 h.
- R8: keep Room's generated `WorkDatabase_Impl` (Glance pulls in WorkManager);
  stripping it crashed release builds at launch. Always smoke-test `assembleQa`
  (release minification, debuggable) on the emulator after dependency changes.

## Billing

- Moving into the iOS project (2026-10-27): Play app `appa3060708af` in `proj10cf6202` has the Play products on entitlement `Sober Tracker - Alcohol Free Pro` and a non-current `android` offering. The next release swaps `REVENUECAT_PLAY_KEY` to that app's `goog_` key, and the code syncs existing Play purchases once (`SYNCED_TO_SHARED_PROJECT`) so old-project trials keep access. Upload the service-account JSON to that app first. Until then the release ships the old key below.
- RevenueCat project `proj15d6bf77` "Sober Android" (separate from iOS
  `proj10cf6202`). Play app `app4a2732350e` (service-account credentials
  uploaded), Test Store app `app0e47955aca`. Entitlement `pro`, offering
  `android` with `$rc_monthly`, `$rc_annual`, `$rc_lifetime`.
- Debug uses the Test Store key; release uses `goog_`. Keys, upload keystore
  (`~/.android/keystores/sober-upload.p12`, alias `upload`) and
  `PLAY_REVIEW_CODE_SHA256` live in ignored `android/local.properties`; the
  review code and passwords are in `~/.sober_credentials`.
- Android US ladder $7.99 / $24.99 / $54.99 (about 20% under iOS), 7-day
  trial offer `trial-7d` on both subscriptions, local prices = Play conversion
  then the fleet PPP curve. Created by `scripts/play-products.py`
  (idempotent). Never put prices in listing copy or app literals.
- Play reviewers unlock Bloom+ by long-pressing Settings > About > Version and
  entering the review code (hash-checked in release).

## Release

- Listing text and graphics: `android/play-assets/metadata/android/<locale>/`
  (fastlane supply layout, 50 locales, checked by
  `scripts/validate-play-listing.py --app sober`); see `android/play-assets/listing-en-US.md` for the
  upload command, policy answers and Data safety.
- Bundles: `PLAY_SERVICE_ACCOUNT_JSON=~/.config/google-play/mahj-service-account.json
  ./scripts/play-upload.sh internal-draft` (tests, signs, verifies, uploads).
  Bump `versionCode` in `android/app/build.gradle.kts` before every upload.
- Play Console: E3 Apps account `8314164911785412040`, app `4975012758183799641`.
  Managed publishing is off (since 2026-10-12).
- State 2026-10-10: versionCode 1 (1.3.2) live on internal testing; production
  release (178 countries, 12 listing locales, all App content declarations,
  reviewer code in Sign in details) sent for review 2026-10-10. Managed
  publishing: approval does not publish; Jack clicks Publish.
- 2026-10-11: listing text expanded from 12 to 50 locales and staged over the
  API with changes not sent for review; it goes out with the next send.
- 2026-10-12: first review rejected, "Privacy policy link is inactive": the
  Android policy pages never closed `<style>`, so they rendered blank while
  returning 200. Fixed on main (3d29779); all 60 changes resent the same day,
  managed publishing now off. Check policy pages render in a browser, not curl.
- Sign in details: the dialog's Add only stages the entry; the page-level Save
  persists it. Never type the raw review code; Jack pastes it.

## Emulator (remote Pro only)

- Never boot an emulator on this Mac. Pro is `jackwallner@192.168.4.25`
  (BatchMode, strict host key), SDK `/Users/jackwallner/Library/Android/sdk`.
- `small_phone` (port 5554) is the Play AVD with an account: preserve it.
  Debug work uses a temporary config-only AVD `sober_agent_test` on port 5560
  (`emulator-5560`), created by copying `small_phone.avd/config.ini` exactly as
  in `~/ironman/.claude/rules/android.md`. Stop it with
  `adb -s emulator-5560 emu kill` on Pro, then delete only
  `~/.android/avd/sober_agent_test.avd` and `.ini`.
- Debug launch extras (debug build only): `resetAll`, `seedDemo`, `seedDays`,
  `demoPro`, `previewStore`, `seedCravings`, `tab`, `onboardingStep`,
  `gallery`, `testReminderIn`, `uiTest` (see `DebugLaunchOptions.kt`).
