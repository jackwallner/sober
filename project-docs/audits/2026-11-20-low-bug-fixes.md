# Low bug fixes, 2026-11-20

Catalog: `2026-11-20-bug-ux.html`. Base commit: `5a6406da`. Branch `fleet/20261120-211217-bc5b-claude`.

| Id | Title | Outcome | Commit | Proof | What changed |
|---|---|---|---|---|---|
| B4 | Reset counter then "Welcome back, still sober?" | fixed | 5f5af061 | `ResetCounterMissedDaysTests` (3 tests): fail on the base code (run `...234537-15982`: 10 and 5 days instead of 3 and 0, old days promoted to logged), pass now (run `...224050-11898`) | `daysSinceLastCheckIn` and `backfillSoberDays` start no earlier than the active run's start day. |
| B5 | Craving clock stops in the background | fixed | fe18daf7 (test fix fb6f632f) | `CravingSessionClockTests` (3 tests), run `...224050-11898`. The helper is new, so these cannot compile on base; the view wiring has no test | Elapsed seconds come from `Date.now - startedAt` (`CravingService.elapsedSeconds`), synced on every tick, on advance and on finish. |
| B6 | Stored currency never read | fixed | c2895752 (test fix 719d4721) | `StoredCurrencyTests` (8 tests), run `...224050-11898` | Home, Bloom+ tab, paywall hero, goal card, trial recap and Settings format money with `settings.currencyCode` (`Money.format`); spend controls size from it (`SpendScale(settings:)`). One-time `SettingsService.settleCurrencyIfNeeded` gives upgrading installs the device currency in place of the stale "USD" default. |
| B7 | Cold-start trial reminder tap lands on Home | fixed (race not observed) | 23a11b7f | `NotificationRouteInboxTests` (3 tests), run `...224050-11898` | The tap is stored in `NotificationRouteInbox`; `MainTabView` takes it on appear and on change. Cold-launch ordering was never observed, so this closes the race by construction rather than disproving or reproducing it. The unused `.soberOpenBloomPlus` name is gone. |
| B8 | Timeline note saves per keystroke | fixed | 14abe060 | `DebouncedActionTests` (2 tests), run `...224050-11898`. Lag was not measured | Note edits write the row at once; save and widget/Watch push run once 0.7 s after the last keystroke, and on day change or disappear (`DebouncedAction`). |

## Verification
- Final full-suite run: `sober@20261120-211217-bc5b-claude-imaccdfd-1120-224050-11898`, 330 tests, 0 failed, 0 skipped. Last code commit is 719d4721 (this doc is the only later change).
- Earlier runs: `...211626-16995` failed to compile two of my new tests; `...213329-23212` crashed on a test that let its in-memory store deallocate. Both are test bugs, fixed in fb6f632f and 719d4721.
- Tests failing on the base commit too: none seen. The base was not run in full; only the B4 suite was run against base code.
- No new or changed user-facing strings (`Tools/Localization/check.py`: 789 keys, 23 languages, 0 problems).

## For the reviewer
- B6 upgrade stamp: installs from before 2026-10-30 hold the "USD" default whatever they used. The stamp takes the device currency at first launch of this build, only for a "USD" row that finished onboarding on a non-USD device. A US-onboarded user who already moved abroad before updating would be stamped with the new currency; that cannot be told apart from the stale default.
- B6 left alone: onboarding formats with the device region (it is what gets stored), `SavingsAnchorCard` and `TrialOfferSheet` (DEBUG harness only), and StoreKit prices.
- B4: a slip's run starts the day after the slip, so the slip-day tap still anchors the same way as before. Stores without journeys (widget, tests) keep the old behavior.
- B8: a note typed on an assumed day still flips it to "Logged sober" on the first character (unchanged; the catalog listed it as impact, not a defect).
- B7: a reminder tap delivered while onboarding is showing waits in the inbox until Home exists.

## Needs Jack
Nothing blocking. The held items in the catalog stay held.
