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
  `scripts/sync-android-bonsai.py` (bonsai parity fixtures, see Bonsai parity).
  Rerun after any catalog or bonsai change; `BonsaiParityTest` and `PortParityTest` pin parity.
- Play In-App Review: no enjoyment question first, never from a button.
- Reminders use `AlarmManager.setWindow` (15 min) re-armed on delivery;
  `setInexactRepeating` drifted up to 18 h.
- R8: keep Room's generated `WorkDatabase_Impl` (Glance pulls in WorkManager);
  stripping it crashed release builds at launch. Always smoke-test `assembleQa`
  (release minification, debuggable) on the emulator after dependency changes.

## Bonsai parity

- The garden's bonsai is a Kotlin port of `Shared/Bonsai/{BonsaiRenderer,BonsaiPaint,BonsaiScene,BonsaiWind}.swift`
  in `android/app/src/main/java/com/jackwallner/sober/ui/bonsai/`
  (`BonsaiRenderer.kt`, `BonsaiPaint.kt`, `BonsaiScene.kt`, `BonsaiWind.kt`, `BonsaiMath.kt`,
  `BonsaiGraphics.kt` geometry, `BonsaiView.kt` Compose). Keep the Swift operation order. Math goes
  through the StrictMath wrappers in `BonsaiMath.kt` and Swift's `.rounded()` is `swiftRounded()`.
  Path booleans (`union`, `intersection`, `subtracting`) stay lazy in `BonsaiPath` and are combined
  once per scene with Compose `PathOperation`. The scene is recorded once per (style, day, detail,
  vitality) and replayed each frame; only the wind (bend, drift, limb stretch, petals) is per frame.
  The scene is built off the main thread in `BonsaiView`; the wind clock is `rememberWindClock()`.
- Parity guard. `scripts/sync-android-bonsai.py` (macOS, Xcode) compiles the real Swift with
  `scripts/android-bonsai/export-main.swift` and records, per scene, each layer's ink, clip chain,
  wind motion and coverage of a 2 unit sampling grid (count and centroid), plus the wind math, into
  `android/app/src/test/resources/bonsai/` with a manifest of the SHA-256 of every
  `Shared/Bonsai/*.swift` file. `BonsaiParityTest` fails when any of those Swift files changes
  (`swiftBonsaiFilesMatchManifest`), compares the Kotlin scenes to the recording within a small tolerance
  (`scenesMatchSwift`), and compares the wind math tightly (`windMathMatchesSwift`).
- When Swift bonsai changes: 1. port it to Kotlin, 2. run `scripts/sync-android-bonsai.py`,
  3. `fm-gradle -p android testDebugUnitTest`, 4. look at the compare images below. Re-recording
  without porting fails `scenesMatchSwift`; do not loosen the tolerance or re-pin the manifest to
  get green.
- Not in the fixtures: airborne petals and leaves (their paths move every frame, only the wind math
  is pinned) and anti-aliasing. Check them by eye. Debug launch extras
  `--ez gallery true --es galleryStyle sakura --ei galleryDay 365 [--ei galleryWindMs 1400]` draw one
  320 dp tree on white, framed like `Tools/BonsaiAudit --mode=render --config=home320 --days=365
  [--wind=1400]`. Screenshot it on the emulator, scale the iOS render to the same size and put them
  side by side in `android/build/bonsai-compare/` (gitignored). The 2026-10-27 port matched iOS at
  ink overlap 0.977 or better on every style at days 7, 30, 90 and 365.
- GitHub-built debug APKs use a new debug keystore each run, so `adb uninstall` before
  reinstalling. The software-GL emulator needs 20 to 45 s after launch to draw the first frame; take
  the screenshot late, and retake a blank one.

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
  `gallery`, `galleryStyle`, `galleryDay`, `galleryWindMs`, `testReminderIn`, `uiTest` (see `DebugLaunchOptions.kt`).
- When Pro is overloaded (load above 10, the emulator's watchdog kills it) the iMac (`ssh imac`,
  Ubuntu, KVM) has the idle `agent-emu-1` AVD: start it on port 5560 with
  `$HOME/Android/sdk/emulator/emulator -avd agent-emu-1 -port 5560 -no-window -no-audio
  -no-boot-anim -no-snapshot-save -gpu swiftshader_indirect` under `setsid nohup`, drive it with
  `$HOME/Android/sdk/platform-tools/adb` over ssh, and stop it with `adb -s emulator-5560 emu kill`.
  Leave `mahj-live` (port 5556) alone.
