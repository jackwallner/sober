# Pre-submit review, Sober 1.3.8 (build 120), 2026-11-07

Last check before 1.3.8 goes to App Review.

- **Live version:** 1.3.7 (`artifacts/asc-screenshots/l10n-20261105/app.json` records `live_version: 1.3.7`). Its last commit in `project.yml` history is `b2d0a42e` (build 116).
- **Reviewed:** `git diff b2d0a42e..b8db9769` over `Sober/`, `Shared/`, `SoberWatch/`, `SoberWidgets/`, `project.yml`. Nine files changed. `Shared/Services`, `Shared/Models`, the paywall, `SubscriptionService`, onboarding and widgets are byte-identical to 1.3.7.
- **What changed:** Settings Language row plus `UIPrefersShowingLanguageSettings`; seven new languages (et, hu, ro, sv, th, tr, zh-Hans) in the string catalog and all three `CFBundleLocalizations`; two shortened German paywall lines; mood pickers as rows at accessibility text sizes (Home check-in sheet, Timeline edit); a `ViewThatFits` week receipt on Home; Reduce Motion in the craving flow; DEBUG-only screenshot launch arguments (`-freshOnboarding`, `-storeScreenshots`, `-scrollProgressSaved`).

## How it was checked

- Read every hunk of the diff by hand.
- Confirmed every new launch-argument path is inside `#if DEBUG` (`Sober/App.swift:161`, `Sober/Features/Today/HomeView.swift:168`, `ProgressSheet`'s `.task`), so none of it is reachable in Release.
- Wrote a script that walks every key, plural variation and `%#@sub@` substitution in `Shared/Localizable.xcstrings` and compares each translation's argument positions and types with the English source. All 778 keys in 23 languages match: 0 mismatches, so no format-string crash or garbled argument from the new languages.
- The only new keys are `Language` and `Opens iOS Settings`. No English value changed, and only two German values changed.
- Scanned the seven new languages for treat, cure and diagnose words. The only hits are the existing "Find Treatment" crisis-resource link and unrelated senses ("manage", "keep up"). No health claim.
- Scanned the seven new languages for currency literals and other-platform names (Android, Google Play): none.
- Paywall Terms (Apple EULA) and Privacy Policy links and Restore are unchanged and still in the footer.

## Findings

No new defect in the 1.3.8 changes. The rows below are the P1 bugs that the 2026-11-06 state machine review ([review](state-machines-2026-11-06-review.md)) confirmed. Each one already ships in live 1.3.7, and the code behind it has not changed since. I list them so the submission goes in knowing they are open. I did not fix them here: each is a behaviour change across several services, not a release-blocking regression, and none comes from the 1.3.8 diff.

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P1 | `Shared/Services/NotificationService.swift:103` | After a slip, Reset, undo or start-date edit, the repeating daily reminder keeps its old copy ("You're 100 days in") until the app is next opened (state machine N1). | Not fixed: in 1.3.7 too, not part of this diff |
| P1 | `Shared/Services/NotificationService.swift:103` | The daily reminder still fires on days the user already checked in ("Log today and water your bonsai"). Found by the review under "Missed by the audit". | Not fixed: in 1.3.7 too, not part of this diff |
| P1 | `Shared/Services/SobrietyService.swift:130` | `reversibleSplit` lets Change to sober undo a slip that isn't the latest one, which leaves runs overlapping and a counter that reads straight through logged slips (S1). | Not fixed: in 1.3.7 too, not part of this diff |
| P1 | `Sober/Features/Settings/SettingsView.swift:318` | Turning the daily reminder on without permission, then allowing it through the app's own "Allow notifications" prompt, leaves the reminder unscheduled until the toggle or hour changes (N2). | Not fixed: in 1.3.7 too, not part of this diff |
| P1 | `Sober/Features/Settings/SettingsView.swift:278` | Moving the start date later keeps the earlier filled days, so the app shows "Day 5 · 100 days sober", and lifetime money and calories stay inflated. The user cannot delete those rows (J3). | Not fixed: in 1.3.7 too, not part of this diff |
| P1 | `Shared/Services/SlipRecorder.swift:89` | Back-filling an older slip after a newer one leaves the longest streak unchanged, right after the alert says it was corrected (J1). | Not fixed: in 1.3.7 too, not part of this diff |
| P1 | `Shared/Services/CheckInService.swift:26` | iPhone Duo, unfolded only: a slip logged in the Timeline pane can be overwritten by Home's still-visible "Check in" button, which erases the slip (C1). | Not fixed: in 1.3.7 too, not part of this diff |

The review's CONFIRMED-MINOR items (T1 to T3, N3, G1 to G5, J4, Z1) are also unchanged. See the review for routes and evidence.

## Tests

gh-sim `sober@20261108-065906-3402-claude-mbpro346f4-1108-070146-24169` (Xcode 27.1, iPhone 17, iOS 27.2) ran the unit tests (`SoberTests`, scheme `Sober`) at `b8db9769`. Release target built, and all 225 tests passed (0 failed, 0 skipped). This branch makes no code changes, so that run covers the code going to review.
