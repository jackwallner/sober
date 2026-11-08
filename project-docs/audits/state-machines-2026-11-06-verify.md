VERDICT: FAIL

# Verification of the Sober state machine fixes, 2026-11-06 (seventh pass)

An independent check of [the fixes](state-machines-2026-11-06-fixes.md) against [the review](state-machines-2026-11-06-review.md), at HEAD `75f03f1`. The top fix commit is "fix: make a Settings start edit reversible, a Reset run is cut at read time" (`7997bff`). I read the whole `git diff b8db9769effbe097c56b8bb60ea7f6d29839232a..HEAD` (14 code and test files) and walked each review route through the views that ship. This doc replaces the sixth verify doc.

**Result.** The sixth pass's finding is fixed: a start moved back past a Reset and forward again now gives the Reset run back its tail and days. The full suite is green (282 passed, 0 failed). The N1, S1 and N2 tests fail with their fixes reverted.

That same fix broke J3 for a large group of users. To protect a Reset run's days, the start-date row cleanup now skips any day a closed run covers in the store. Builds from 2026-08-24 to 2026-10-31 left a closed onboarding run in place for every user who finished setup, with the same start as the user's run. That run covers the very days J3 must delete, so for those users moving the start later deletes nothing (or almost nothing) again. Proven by probe: it fails on HEAD and passes on `5d833d9`, the commit just before this change.

The rebase onto `b8db976` is clean. `git range-diff` shows all 16 fix commits identical (`=`), and `d7cdb91..bf7507b` differs only by origin/main's mood picker change. That change is layout only and touches no handler this branch changed.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| N1 | Yes | Clean | Every route the review named now requeues reminders from the store: slip and undo (`Shared/Services/SlipRecorder.swift:103`, `:142`), Reset (`Sober/Features/Today/HomeView.swift:146`), Still sober and check-in (`:482`, `:583`), Home refresh (`:673`), Timeline log and delete (`Sober/Features/Calendar/TimelineView.swift:642`, `:661`), and the start date edit (`Sober/Features/Settings/SettingsView.swift:293`). The trial reminder id is not in `ReminderSync.allIdentifiers`, so it is never touched. `n1_aSlipRequeuesTheRemindersAtTheNewStreak` fails with the `SlipRecorder` syncs removed (run below). Device check left open: the live `UNUserNotificationCenter`, which the tests replace with a fake. |
| S1 | Yes | Clean | `reversibleSplit` takes the slip-closed run ending on the day and refuses only when a closed run lies between it and the active run (`Shared/Services/SobrietyService.swift:257-289`, block test `:281`). A later slip or a Reset after the slip always lies between them, so both block the undo. `s1_slipWithALaterSlipIsNotUndoable` fails with `b8db976`'s body restored (run below). |
| N2 | Yes | Clean | The opt-in plus permission is the source of truth, so no pending request is needed (`Shared/Services/ReminderSync.swift`, `apply`). Settings syncs when the app returns from iOS Settings (`SettingsView.swift:220`). `n2_permissionGrantedLaterStartsTheDailyReminder` fails under an emulation of the old pending-only rule (run below). Device check left open: the real return from iOS Settings. |
| J3 | **No, for users onboarded 2026-08-24 to 2026-10-31** | **Regression** from `7997bff` (Must change 1) | The cleanup skips any row a closed run covers as stored (`SobrietyService.swift:60`, `covers` `:67-73`). The onboarding leftover run starts where the user's run starts, so on the review's own route ("100 days ago to 5 days ago") it covers most or all of the range J3 must clear. Probe: lifetime 66 and 100, want 5. Both pass on `5d833d9`. |
| T2 | Yes | Clean | `willRenew` reaches `TrialLifecycle.sync`, and a billing retry still counts as renewing (`Shared/Services/SubscriptionService.swift:490`, `:498`). With renewal off the trial is cleared (`Shared/Services/TrialLifecycle.swift:115`). `entitlementActive` is untouched. |
| J1 | Yes | Clean | An older slip splits the closed run it falls in, preferring the slip-closed run (`SobrietyService.swift:302-328`, `:316`). The rest run is marked garden-untouched (`SlipRecorder.swift:89-90`). |
| C1 | Yes | Clean | `checkIn` refuses to turn a logged slip sober unless `overwritingSlip` is set (`Shared/Services/CheckInService.swift:33`), and only `SlipRecorder.undo` sets it. Home re-reads the store first (`HomeView.swift:574`). The new mood pickers save only mood and note: `saveCheckInEdit` (`TimelineView.swift:628-631`) never calls `checkIn`. Device check left open: an unfolded Duo with Home beside Timeline. |
| N3 | Yes | Clean | 30 dated one-shot requests, each with its own count (`Shared/Services/NotificationService.swift:111-138`). The old repeating id is in the cancel list. |
| G4 | Yes | Clean | Carryover halves the day in the current cycle (`Shared/Services/GardenService.swift:219-221`). Watch and widgets read `treeDays`, `stage` and `cycleProgress`, which are unchanged. |
| G1 | Yes | Clean | The grove baseline is restored from the slip's snapshot (`GardenService.swift:261-272`). Slips from older builds take `.legacy` (`:274`). |
| T1 | Yes | Clean | A known trial is re-checked with `isAuthorized` (no prompt) and scheduled once permission exists (`TrialLifecycle.swift:146-147`). |
| T3 | Yes | Clean | The scheduled summary is stored and compared, and Home's recap refresh calls `resync()` (`HomeView.swift:780`). |
| G5 | Yes | Clean | A goal set or cleared after the slip moves onto the reopened run (`SobrietyService.swift:217`). |
| G2 | Yes | Clean | Each slip-started run keeps its own snapshot (`SlipRecorder.swift:87`, `Shared/Models/SobrietyJourney.swift:19`, optional with a default). |
| G3 | Yes | Clean | Vitality, watering and decay come back from the snapshot. If the tree was watered since, only what the slip took is returned (`GardenService.swift:261-272`). |
| J4 | Yes | Clean apart from its J3 interaction (Must change 1) | The floor is the day after the latest slip, capped at the active start and at now (`SobrietyService.swift:85-97`). Closed runs stay as stored and read cut at read time (`effectiveEnd`, `:113-134`), used by `dayCount` (`:347`), `longestStreakDays` (`:377`), `reversibleSplit` and Timeline's tree preview (`TimelineView.swift:45`). I traced shipped shapes with no start move: Reset (next run starts at the Reset moment), slip today and back-dated, pre-2026-09-04 back-dated slips, J1 rest runs, and Z1 re-keys. None reads differently, except that the onboarding leftover now reads as empty on its start. The user's run covers the same days with the same start, so counts are unchanged. |
| Z1 | Yes | Clean | Run starts, ends and goals that sit on the old zone's midnights move with the rows (`CheckInService.swift:280`, `:299-318`). |
| Missed: reminder after check-in | Yes | Clean | Today's request is dropped once today is logged (`NotificationService.swift:121`). |
| Missed: title a day ahead | Yes | Clean | Title and body name the same count (`NotificationService.swift:147`) and use existing catalog keys. `python3 Tools/Localization/check.py`: 778 keys, 23 languages, 0 problems. |

## Must change

1. **J3 does not hold for users who onboarded on a build from 2026-08-24 to 2026-10-31.** This is a regression from "fix: make a Settings start edit reversible, a Reset run is cut at read time" (`7997bff`).
   - **Who.** From `885f5ea` (2026-08-24) to `ff76571` (2026-10-31), `persistSetup` ran at the offer step (`finishOnboarding`) and again in `completeOnboarding`. Each call went through `startJourney`, which closed the open run at that moment and opened a new one at the same start. So every user who finished setup in that window has a closed run [their start, setup moment] with no reason, beside their own run with the same start. `j4_aLeftoverOnboardingRunDoesNotLockTheStart` and the fixes doc model this exact shape. `ff76571` stopped making new ones, but nothing removed the old ones.
   - **Route.** This is the review's J3 route: Settings › Sobriety Start, move the start later (100 days ago to 5 days ago). The binding calls `updateStartDate` and then `fillJourney` (`SettingsView.swift:279-295`), and the picker has no floor without a slip.
   - **What happens.** `updateStartDate` skips every assumed row that a closed run covers as stored (`SobrietyService.swift:60`, `:67-73`). The leftover covers [start, setup day], so those rows stay. Home keeps reading "Day 6" over "N days sober", lifetime money and calories stay inflated, and the leftover still shows as a past run in Timeline holding those days. That is exactly the J3 symptom.
   - **Before `7997bff`** (`5d833d9`), the cleanup deleted the rows and lifetime read 5. On `b8db976` nothing was deleted (the original J3 bug).
   - **Proof.** Two probes (Settings binding: `updateStartDate` then `fillJourney`) with controls first: lifetime 100 before the move, counter 6 after it.
     - `probe_j3_leftoverUserOnboarded40DaysAgoMovesStartLater` (start 100 days ago, setup 40 days ago, move to 5 days ago) reads lifetime 66, want 5.
     - `probe_j3_leftoverUserOnboarded2DaysAgoMovesStartLater` (setup 2 days ago) reads 100, want 5.
     - Both pass on `5d833d9`. The probe file was never committed.
   - **Direction for the fix.** Keep the protection for a Reset run's own days, but not for the onboarding leftover. The leftover cannot be told apart by `resetReason` (both are nil, `SobrietyService.swift:161-168`), so one option is to judge coverage by the runs as read with the active run at its old start. The leftover then reads as empty (`effectiveEnd` already cuts it at the shared start), while a Reset run the start was moved back into still covers its stored days. Whatever the rule, add both probes as regression tests, and keep `j4_j3_assumedDaysOfAResetRunSurviveAStartMovedBackThenForward` passing. Also cover a Reset run the start was moved back past entirely and then forward again.

## Disputed

The fixes doc's "Disputed" section reads "None. Every item in all five failing regression checks was correct." There is nothing to rule on. The sixth pass's finding is fixed (its two probes are now `j4_j3_assumedDaysOfAResetRunSurviveAStartMovedBackThenForward` and `j4_aResetRunsLengthSurvivesAStartMovedBackThenForward`, both green on HEAD). The review's NOT A BUG claims were left alone: J2's route still banks half the closed run, and `CravingModeView` (K1) is not in the diff.

## Scope (check 4)

- All 17 surviving claims and both missed reminder bugs are in the fixes table as Fixed. None was skipped or held against the rules, and the review had no UNVERIFIED claims.
- Onboarding, the trial flow, paywall, prices, offers, how membership is judged, and when or to whom a paywall appears are all unchanged. `SubscriptionService` only passes `willRenew` into `TrialLifecycle`.
- T2 clears the app's own trial-reminder bookkeeping on `willRenew == false`. That flag is the store's record of the user's cancel, not a cached entitlement or a failed call, and the next fresh `willRenew == true` re-tracks the trial. Not a check 4 failure.
- Stored data: one optional SwiftData attribute with a default, plus App Group keys. `7997bff` writes nothing back to closed runs, and no stored format changed. The J3 row deletion runs only on the user's own start edit.
- The held item (cleanup of J3 rows from before this build) is not implemented.

## Test results

All runs were local on pool slot 2 (`agent-sim-2`, iPhone 18 Pro Max, iOS 27.0, UDID `15AECC26-8726-46EA-A6ED-6B9B6BBFD6A4`), per the local run override. Result bundles are in `/private/tmp/claude-501/-Users-jackwallner-fleet-work-state-machine-clones-sober/9a0ebbd4-0589-4de8-aa8d-390cecb55a9c/scratchpad/results/`.

| Run | Result bundle | Result |
|---|---|---|
| Full suite on HEAD `75f03f1` (`xcodebuild test -scheme Sober`) | `full-head.xcresult` | **282 passed, 0 failed, 0 skipped.** This matches the fixes doc's final run (282). Every test in `SoberTests/StateMachineFixTests.swift` and the edited `SoberServicesTests` passes. The build compiled the embedded SoberWatch and SoberWidgets. |
| N1, S1 and N2 reverted, tests kept (`-only-testing` the three) | `revert-top3.xcresult` | **3 failed, 0 passed.** `n1_aSlipRequeuesTheRemindersAtTheNewStreak`: tomorrow's title is not "Day 2", the eve is not day 7, the lapse body still has 28, and today's request is still queued. Its pre-slip controls passed. `s1_slipWithALaterSlipIsNotUndoable`: `canUndo` true on yesterday, and the counter is not 1 after the undo. `n2_permissionGrantedLaterStartsTheDailyReminder`: 0 daily requests, want at least 29. |
| J3 leftover probe on HEAD | `probe-head.xcresult` | 0 passed, 2 failed (lifetime 66 and 100, want 5). Controls passed. |
| J3 leftover probe on `5d833d9` | `probe-pre.xcresult` | 2 passed, 0 failed. |

**How the revert was done.** I used a throwaway branch `scratch-revert` (commit `018cc37`) in a separate worktree, so that the main tree stayed untouched while the full suite ran. The worktree and branch were removed after. The revert made three changes, and left the tests unchanged:

- It removed both `ReminderSync.sync` calls from `SlipRecorder` (N1).
- It restored `b8db976`'s `reversibleSplit` body (S1).
- It emulated the old N2 rule in `ReminderSync`, which is new and has no `b8db976` version to restore. The first sync per store stands in for the Settings toggle's one schedule call, and later syncs re-add daily requests only when one was already queued.

The probes ran in detached worktrees at HEAD and at `5d833d9`. This branch ends with only this doc commit on top of `75f03f1`.

## Screens (check 5)

I installed the HEAD Debug build on slot 2 with `xcrun simctl` and seeded it with `-seedDemo -seedDays 127`.

- **Home** shows counter 128, the Refined bonsai, "Check in for today", the craving card, Coming up and the tab bar. Nothing is broken.
- **Timeline** (`-tab 1`) shows Current, Longest and Total all at 128, and November filled through today. The selected day reads "Today · Day 128 · Refined" with its tree.

Screenshots: `/private/tmp/claude-501/-Users-jackwallner-fleet-work-state-machine-clones-sober/9a0ebbd4-0589-4de8-aa8d-390cecb55a9c/scratchpad/home.png` and `/private/tmp/claude-501/-Users-jackwallner-fleet-work-state-machine-clones-sober/9a0ebbd4-0589-4de8-aa8d-390cecb55a9c/scratchpad/timeline.png`.

The changed views moved only in action handlers, Timeline's covering-run lookup and the Settings start picker's range. Settings is a sheet off Home's ⋯ menu with no launch argument, so the picker and Must change 1's route were not captured. The probe drives the same calls as the binding.

## Notes

1. **Fixes doc.** Its rows, the 282 test count and its descriptions match what I found. Its sixth-pass section says shipped stores "read as before except where a start move overlaps them". That holds for counts, but the onboarding leftover now reads as empty on its start, which is harmless (note under J4).
2. **J1 with a long leftover run** (pre-existing, from the sixth pass). A leftover onboarding run is never split, so `longestStreakDays` can still read a leftover through an older slip. It shares a root with Must change 1: the leftover runs from 2026-08-24 to 2026-10-31 are phantom data that the held J3 cleanup question could also cover.
3. **N3 trade-off** (disclosed). Someone who doesn't open the app for 30 days stops getting the daily reminder until they return.
4. **Duo.** The Timeline pane writes through the same `SlipRecorder` and `ReminderSync` paths, and C1's guard covers the stale Home beside it. No layout code changed in this diff. The mood picker's accessibility-size layout comes from origin/main, not from this branch.
5. **Test host log.** The full run's app host logged "Local save failed ... isn't enough space" once (`DataService`). The Mac had 39 GB free and no test failed. It comes from the simulator's container, not from a test.
