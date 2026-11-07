VERDICT: FAIL

# Verification of the Sober state machine fixes, 2026-11-06 (third pass)

Independent check of [the fixes](state-machines-2026-11-06-fixes.md) against [the review](state-machines-2026-11-06-review.md), at HEAD `5018206`. That HEAD includes "fix: keep the Settings start floor at or before now after a zone change". I read the whole `git diff 7199ab04ccd9d17e411f5717e3ea46d24890f24c..HEAD` and walked each route through the views that ship. This replaces the second verify doc, which failed on the J4 floor combined with the Z1 crash.

**Result:** the second pass's crash is fixed. All 21 fixes hold on the review's routes, and the full suite is green (265 passed). It fails on one real regression in the undo path. The rule S1 added (only the run directly before the active one, closed by a slip, can be reopened) now meets J4's trim (a closed run the moved start reaches into is cut back to it). The trim leaves a zero-length run sitting on its own start. When the user moved the start *earlier* than that run's start, that empty run now has the latest start of any closed run. S1 picks it as "the run before", sees no slip reason, and refuses to undo the user's next slip. On 7199ab0 the same undo works. A probe proves it: it fails on HEAD with its controls passing, and passes on 7199ab0.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| N1 | Yes | Clean | Every route the review named now requeues reminders: slip and undo (`Shared/Services/SlipRecorder.swift:103`, `:142`), Reset (`Sober/Features/Today/HomeView.swift:146`), check-in and Still sober (`:583`, `:482`), Home refresh (`:673`), Timeline log and delete (`Sober/Features/Calendar/TimelineView.swift:632`, `:651`), start date edit (`Sober/Features/Settings/SettingsView.swift:293`). `ReminderSync.apply` clears and requeues daily, eve and lapse from the store (`Shared/Services/ReminderSync.swift:94-110`). With the fix reverted, both n1 tests fail (run 42379400868); `n1_aSlip...`'s pre-slip controls pass first. Device check left open: the live `UNUserNotificationCenter` path (`ReminderSync.swift:13-25`), which the fake center replaces. |
| S1 | Yes on its route | **Regression** with J4 (see "Must change") | `reversibleSplit` takes the closed run with the latest start, and only when a slip closed it (`Shared/Services/SobrietyService.swift:212-219`). With the fix reverted, `s1_slipWithALaterSlipIsNotUndoable` and both Reset tests fail with `canUndo` true (run 42379400868). `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater` passes with S1 reverted because J1's split guards route (b). |
| N2 | Yes | Clean | The opt-in is the source of truth (`ReminderSync.swift:99-107`). Settings syncs when the app comes back from iOS Settings (`SettingsView.swift:220`), and so does Home's scene-active refresh. With the fix reverted, `n2_` fails with 0 daily requests (want 29 or more, run 42379400868). Device check left open: the real return from iOS Settings and the `scenePhase` hook, which no unit test drives. |
| J3 | Yes | Clean, see note 3 | `updateStartDate` deletes only unlogged, sober rows with no mood or note, and only in [old start, new start) (`SobrietyService.swift:49-58`). It runs only on the user's own start edit (`SettingsView.swift:283`). |
| T2 | Yes | Clean, see scope | `willRenew` (billing retry counts as renewing) reaches `TrialLifecycle.sync` (`Shared/Services/SubscriptionService.swift:489-490`). A trial with renewal off is cleared (`Shared/Services/TrialLifecycle.swift:115`). `entitlementActive` is untouched. |
| J1 | Yes | Clean | An older slip splits the closed run it falls in (`SlipRecorder.swift:89`, `SobrietyService.swift:234-255`). The second part keeps the run's reason and goal and is marked garden-untouched. |
| C1 | Yes | Clean | `checkIn` refuses to turn a logged slip sober unless `overwritingSlip` is set (`Shared/Services/CheckInService.swift:33`). Only `SlipRecorder.undo` sets it (`SlipRecorder.swift:139`). Home re-reads the store first (`HomeView.swift:574`). The other sober writers never meet a logged slip: Timeline's "Log as sober" only shows on unlogged days (`TimelineView.swift:536`), and `backfillSoberDays` only touches sober rows. Device check left open: the unfolded Duo with Home and Timeline side by side. |
| N3 | Yes | Clean, see note 2 | 30 dated one-shot requests, each carrying its own count (`Shared/Services/NotificationService.swift:111-138`). The old repeating id is in the cancel list (`:83`), so upgraded users lose the frozen request on the first sync. 33 of the 64 pending slots are used. |
| G4 | Yes | Clean | Carryover halves the day in the current cycle (`Shared/Services/GardenService.swift:219-221`). Under a year this equals the old value (`g4_underAYearStillBanksHalf`). |
| G1 | Yes | Clean | The grove baseline comes back from the slip's snapshot (`GardenService.swift:263`). Slips logged before snapshots existed take the `.legacy` branch (`:274-283`), covered by `upgrade_undoOfASlipFromBeforeSnapshots`. |
| T1 | Yes | Clean | A known trial is re-checked without a prompt and scheduled once permission exists (`TrialLifecycle.swift:139-148`). |
| T3 | Yes | Clean | The scheduled summary is stored and compared (`TrialLifecycle.swift:121-128`). Home's recap refresh calls `resync()` (`HomeView.swift:780`). |
| G5 | Yes | Clean | Undo moves a goal set or cleared after the slip onto the reopened run (`SobrietyService.swift:173-175`). |
| G2 | Yes | Clean | Each run keeps its own snapshot (`SlipRecorder.swift:87`, `Shared/Models/SobrietyJourney.swift:19`, optional with a default, a lightweight migration). |
| G3 | Yes | Clean | Vitality, watering and decay come back from the snapshot. If the tree was watered since, only what the slip took is returned (`GardenService.swift:261-273`). |
| J4 | Yes on its route, and the second pass's crash is fixed | **Regression** with S1 (see "Must change") | The floor is the day after the latest logged slip, capped at the active start and at now (`SobrietyService.swift:72-84`). In `SettingsView.swift:64` the left side is evaluated before `Date.now`, so the range can't reverse. Reset runs and leftover runs are trimmed (`:89-95`). That trim is what feeds the regression below. |
| Z1 | Yes | Clean | Run starts, ends and goals sitting on the old zone's midnights move with the rows (`CheckInService.swift:280`, `:299-318`). With J4's cap, a start re-keyed past now no longer reaches the picker. It runs only when the stored zone differs from the current one, so nothing moves on upgrade for users in the same zone. |
| Missed: reminder after check-in | Yes | Clean | Today's request is dropped once today is logged (`NotificationService.swift:121`). Check-ins resync. |
| Missed: title a day ahead | Yes | Clean | Title and body name the same count (`NotificationService.swift:127`, `:147`). Same catalog keys. `Tools/Localization/check.py`: 778 keys, 23 languages, 0 problems. |

## Must change

**After the start is moved earlier past a Reset run or a leftover onboarding run, the user's next slip can't be undone.**

- Route A (current build): Home ⋯ › Reset counter. Then Settings › Sobriety Start: pick a date earlier than the first run's start. The picker has no floor without a slip (`SobrietyService.swift:82`). The same happens when the user picks the original day itself and the Reset happened at an earlier hour than setup did, because the date-only picker keeps the current start's time of day. That second case is the "mistaken Reset repair" the J4 rework advertises (`j4_aMistakenResetCanBeUndoneFromSettings`). Later: Home ⋯ › I slipped › Log. Then Timeline › that day. "Change to sober" is missing, and the app shows "A slip can only be taken back while it's the most recent one on your record." (`TimelineView.swift:530`). That is false: it is the most recent slip.
- Route B (existing users): every user who onboarded before `ff76571` (2026-10-31) has at least one leftover closed run. The old `persistSetup` called `startJourney` (`ff76571^:Sober/Features/Onboarding/OnboardingView.swift:917`) from both `finishOnboarding` and `completeOnboarding` (`:926`, `:932`), and `startJourney` closes the open run at now with no reason (`SobrietyService.swift:22-24`). If such a user has never slipped and moves the start earlier in Settings (the route `j4_aLeftoverOnboardingRunDoesNotLockTheStart` covers), their next slip can't be undone.
- Mechanism: `trimClosedJourneys` sets a closed run's end to `max(j.startDate, start)` (`SobrietyService.swift:93`). A run that began after the new start ends up zero-length at its own start. That start is later than the active run's. `reversibleSplit` takes the closed run with the latest start (`:212-214`). It then requires a slip reason (`:218`), which a Reset or leftover run never has, so it returns nil. On 7199ab0 it matched the closed run ending on the slip day and allowed the undo.
- Proof, temporary probe suite `VerifyProbeUndoTests` (not committed). It builds the run shapes each route leaves, calls `updateStartDate`, records a slip today, then asks `canUndo` and `undo`. Each test checks its controls first (the counter after the move, then 1 after the slip).
  - On HEAD (run 42380179313): 3 failed, 1 passed. The controls pass. `canUndo` is false and `undo` returns false in `probe_resetThenEarlierStartThenSlipTodayIsUndoable`, `probe_resetRepairedToTheSameDayThenSlipTodayIsUndoable` and `probe_leftoverOnboardingRunThenEarlierStartThenSlipTodayIsUndoable`. The control `probe_leftoverOnboardingRunThenSlipTodayIsUndoable` (no start move) passes.
  - On 7199ab0 (run 42381195997): 4 passed, and the undo puts the counter back to 61 and 41.
- Fix (for the fixer): don't let a closed run that isn't a slip block the undo. Either pick the predecessor by latest end, not latest start, or skip zero-length non-slip runs. Alternatively, have `trimClosedJourneys` delete a closed non-slip run that the new start fully covers instead of leaving it zero-length. Add the three probes as regression tests. The S1 and J4 tests must stay green.

## Disputed

The fixes doc's "Disputed" section reads "None. Every item in both regression checks was correct." There is nothing to rule on. The first two passes' findings (J4 floor at a Reset; J4 floor with Z1) are both fixed, as the J4 and Z1 rows above confirm. The review's NOT A BUG claims, J2 and K1, were left alone. I traced J2's route (Reset, then a slip today) through the new code: it still banks half of the 100-day run, and the slip still undoes back to the post-Reset run. `CravingModeView` is not in the diff.

## Scope (check 4)

- All 19 in-scope claims and both missed reminder bugs are in the fixes table as Fixed. None were skipped or held against the rules, and the review had no UNVERIFIED claims.
- Onboarding (no diff), the trial flow, the paywall, prices, offers, how membership is judged and when or to whom a paywall appears are all unchanged. `SubscriptionService` only passes `willRenew` into `TrialLifecycle`. T2 also hides the trial recap banner for a cancelled trial. That banner has only a "Got it" button (`HomeView.swift:438-448`) and says "Cancel any time in Settings", which is the same confusion T2 fixes. It is not a paywall. No backend, App Store Connect or RevenueCat change is needed.
- Teardown on an inferred state: T2 clears the app's own trial reminder record when CustomerInfo says `willRenew == false`, including the cached CustomerInfo applied at launch (`SubscriptionService.swift:177`). That is not a membership or user setting. 7199ab0 already cleared the same record on the same cached info whenever `isTrialing` was false. The next fresh true re-tracks the trial and reschedules. J3's row deletion runs only on the user's own start edit. Neither is a check 4 failure.
- Stored data: one optional SwiftData attribute with a default, and two new App Group keys. Nothing resets existing data.
- The held item (cleanup of J3 rows from before this build) is not implemented.

## Test results

| Run | gh-sim id | GitHub run | Result |
|---|---|---|---|
| Full suite on HEAD, with Home and Timeline screenshots | `sober@20261107-053952-ca59-claude-mbpro34055-1107-054052-1619` | 42378069967 | 265 passed, 0 failed, 0 skipped (iPhone 17, iOS 27.2). Same count as the fixes doc's final run (42376736755). Nothing newly fails, and every test the change added or edited passes. The build compiled SoberWatch and SoberWidgets, which share `ReminderSync` and the other changed services. |
| N1, S1, N2 reverted, tests kept (the review's top three) | `vp-revert-mbpro34055-1107-055842-11056` | 42379400868 | `ReminderSyncRegressionTests` and `SlipHistoryRegressionTests`: 25 passed, 6 failed. Failing: both n1 tests (tomorrow's request still reads the old streak), `n2_` (0 daily requests), and `s1_slipWithALaterSlipIsNotUndoable`, `s1_aResetAfterASlipCannotBeUndoneThroughIt`, `s1_aResetOnTheSlipDayCannotBeUndoneThroughIt` (each `canUndo` true). All other tests in both suites pass. |
| Undo probe on HEAD | `vp-head-mbpro34055-1107-060822-7203` | 42380179313 | 3 failed, 1 passed (control). The controls inside the failing tests pass. |
| Undo probe on 7199ab0 | `vp-base-mbpro34055-1107-062108-9979` | 42381195997 | 4 passed. |

How the revert was done: a throwaway branch `scratch-revert` (commit `20f7b8e`), in a temporary worktree so this branch never moved; both are now deleted. It restored the base `reversibleSplit` body and removed both `ReminderSync.sync` calls from `SlipRecorder`. For N2 it restored the old rule inside `ReminderSync`: the first sync stands in for the Settings toggle, and after that the daily requests are re-added only when one is already queued (the old `refreshDailyReminder`). Test files were unchanged. This branch ends with only this doc commit on top of `5018206`.

## Screens (check 5)

On a seeded 128-day demo, Home (launch) and Timeline (`-tab 1`) render normally. The counter reads 128, and the garden, check-in card, craving card and coming-up list all show. Timeline's Current, Longest and Total agree at 128, and the November calendar is filled through today. Home and Timeline only changed in action handlers, with no layout change. The one changed control is the Settings start picker's range. Settings is a sheet off Home's ⋯ menu, and no launch argument or deep link opens it, so it was not captured.

## Notes

1. **Fixes doc.** Its rows, test counts and run ids match what I found. It does not mention the S1 and J4 interaction above.
2. **N3 trade-off** (disclosed). Someone away for 30 days stops getting the daily reminder until they return. The lapse nudge fires once at day 3.
3. **J3 with leftover runs.** For a pre-116 user, moving the start later deletes assumed rows the leftover closed run also spans. That run is a phantom of the old onboarding, and the user is saying their start is later, so this matches J3's intent. Note only.
4. **T2 timing.** The reminder is dropped only once the app sees the cancel (next launch or foreground). That can't be helped without a server push.
5. **Watch and widgets** call none of the changed paths. They read `GardenService.stage` and `cycleProgress`, which are unchanged. Widget snapshots are still pushed after every write.
6. **Duo.** The Timeline pane writes through the same `SlipRecorder` and `ReminderSync` paths, and C1's guard covers the stale Home beside it. No layout code changed.
