VERDICT: PASS

# Verification of the Sober state machine fixes, 2026-11-06 (fourth pass)

Independent check of [the fixes](state-machines-2026-11-06-fixes.md) against [the review](state-machines-2026-11-06-review.md), at HEAD `6115ae2` (top fix commit "fix: let a slip be undone past a Reset or leftover onboarding run", `e08987d`). I read the whole `git diff 7199ab04ccd9d17e411f5717e3ea46d24890f24c..HEAD` and walked each review route through the views that ship. This replaces the third verify doc, which failed on S1's undo rule meeting J4's trim.

**Result:** the third pass's regression is fixed, every fix holds on the review's route, the full suite is green (271 passed, 0 failed), and all 46 tests in `StateMachineFixTests` pass on HEAD. With N1, S1 and N2 reverted and their tests kept, all six of their behaviour tests fail and every other test in both suites passes. No regression and no scope failure found.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| N1 | Yes | Clean | Every route the review named now requeues reminders from the store: slip and undo (`Shared/Services/SlipRecorder.swift:103`, `:142`), Reset (`Sober/Features/Today/HomeView.swift:146`), check-in and Still sober (`:583`, `:482`), Home refresh (`:673`), Timeline log and delete (`Sober/Features/Calendar/TimelineView.swift:632`, `:651`), start date edit (`Sober/Features/Settings/SettingsView.swift:293`). Timeline's slip sheet and undo go through `SlipRecorder`, so they are covered too. `ReminderSync.apply` clears and requeues daily, eve and lapse (`Shared/Services/ReminderSync.swift:94-108`). Both n1 tests fail with the two `SlipRecorder` syncs removed (revert run below). Device check left open: the live `UNUserNotificationCenter` (`ReminderSync.swift:13-25`), which the tests replace with a fake. |
| S1 | Yes | Clean (third pass regression fixed) | `reversibleSplit` takes the slip-closed run ending on the day and refuses if any other closed run that is non-empty or slip-closed began after it (`Shared/Services/SobrietyService.swift:219-231`). Walked: (a) slip yesterday then today leaves today's empty slip-closed run after it, refused; (b) the older slip at -50 is split off by J1, so undoing -10 reopens only `[-49, -10]` and the counter reads 50, not 101; a Reset after a slip leaves a non-empty run after it, refused. The third pass's routes (Reset or leftover run, start moved earlier, then a slip) now undo, because the trimmed run is empty and not a slip. I also walked Reset, repair the start to the day after the slip, then undo the slip: allowed, the same as on 7199ab0. With S1 reverted, three s1 tests fail (`canUndo` true). |
| N2 | Yes | Clean | The opt-in plus permission is the source of truth; no pending request is needed (`ReminderSync.swift:99-107`). Settings syncs on return from iOS Settings (`SettingsView.swift:220`), Home on scene-active (`HomeView.swift:673`). Toggle off still cancels everything without needing permission (`ReminderSync.swift:99-101`). `n2_` fails with 0 daily requests when the old "only refresh a pending one" rule is restored. Device check left open: the real return from iOS Settings and the `scenePhase` hook. |
| J3 | Yes | Clean | `updateStartDate` deletes only unlogged, sober, mood-less, note-less rows in [old start, new start) (`SobrietyService.swift:48-58`). Only the user's own start edit reaches it (`SettingsView.swift:283`). |
| T2 | Yes | Clean, see scope | `willRenew` (billing retry counts as renewing) reaches `TrialLifecycle.sync` (`Shared/Services/SubscriptionService.swift:489-490`); renewal off clears the reminder (`Shared/Services/TrialLifecycle.swift:115`). `entitlementActive` is untouched. `t2_aCancelledTrialFromRevenueCatIsNotReminded` drives the real `processPurchaseResult` path. |
| J1 | Yes | Clean | An out-of-order slip splits the closed run it falls in (`SlipRecorder.swift:89`, `SobrietyService.swift:246-266`). The rest keeps reason and goal and is marked garden-untouched, so undoing it later leaves the tree alone (`j1_bothSlipsUndoNewestFirst`). |
| C1 | Yes | Clean | `checkIn` refuses to turn a logged slip sober unless `overwritingSlip` (`Shared/Services/CheckInService.swift:33`); only `SlipRecorder.undo` sets it (`SlipRecorder.swift:139`). Home re-reads the store before checking in (`HomeView.swift:574`). The other sober writers never meet a logged slip: Timeline's "Log as sober" shows only on unlogged days (`TimelineView.swift:534-538`), `backfillSoberDays` skips logged slips, and the `-storeScreenshots` seed is debug-only. Device check left open: an unfolded Duo with Home beside Timeline. |
| N3 | Yes | Clean, see note 2 | 30 dated one-shot requests, each with its own count (`Shared/Services/NotificationService.swift:111-138`). The old repeating id is in the cancel list (`:83`), so upgraded users lose the frozen request on first sync. Onboarding's `scheduleDailyReminder` call (`Sober/Features/Onboarding/OnboardingView.swift:809`) now queues the same 30. 33 of 64 pending slots used. |
| G4 | Yes | Clean | Carryover halves the day in the current cycle (`Shared/Services/GardenService.swift:219-221`); under a year this equals the old value (`g4_underAYearStillBanksHalf`). |
| G1 | Yes | Clean | The grove baseline comes back from the slip's snapshot (`GardenService.swift:263`). Slips logged by older builds take the `.legacy` branch (`:274-283`), covered by `upgrade_undoOfASlipFromBeforeSnapshots`. |
| T1 | Yes | Clean | A known trial is re-checked with `isAuthorized` (no prompt) and scheduled once permission exists (`TrialLifecycle.swift:145-157`). |
| T3 | Yes | Clean | The scheduled summary is stored and compared (`TrialLifecycle.swift:121-128`); Home's recap refresh calls `resync()` (`HomeView.swift:780`), which returns at once when no trial is tracked. |
| G5 | Yes | Clean | Undo moves a goal set or cleared after the slip onto the reopened run (`SobrietyService.swift:173-175`). |
| G2 | Yes | Clean | Each slip-started run keeps its own snapshot (`SlipRecorder.swift:87`, `Shared/Models/SobrietyJourney.swift:19`, optional with a default, a lightweight migration). Undo reads it before the run is deleted (`SlipRecorder.swift:134`). |
| G3 | Yes | Clean | Vitality, watering and decay come back from the snapshot; if watered since, only the 0.3 the slip took is returned (`GardenService.swift:264-272`). |
| J4 | Yes | Clean | Floor is the day after the latest logged slip, capped at the active start and at now (`SobrietyService.swift:72-84`), so `SettingsView.swift:64`'s range can't reverse. Reset and leftover runs are trimmed, not used as a floor (`:89-95`); the empty run the trim leaves no longer blocks S1 (above). |
| Z1 | Yes | Clean | Run starts, ends and goals on the old zone's exact midnights move with the rows (`CheckInService.swift:280`, `:299-318`). Runs only when the stored zone differs from the current one; same-zone upgrades change nothing. The store guard `holds` keeps widget or test stores without the model safe. |
| Missed: reminder after check-in | Yes | Clean | Today's request is dropped once today is logged (`NotificationService.swift:121`); check-ins resync. |
| Missed: title a day ahead | Yes | Clean | Title and body name the same count (`NotificationService.swift:146-150`). Same catalog keys; `Tools/Localization/check.py`: 778 keys, 23 languages, 0 problems. |

## Must change

Nothing.

## Disputed

The fixes doc's "Disputed" section reads "None. Every item in all three regression checks was correct." There is nothing to rule on. The three earlier findings (J4 floor at a Reset, J4 floor with Z1, S1 rule with J4 trim) are fixed, as the J4 and S1 rows show. The review's NOT A BUG claims were left alone: J2's route (Reset, then a slip today) still banks half of the closed run and still undoes; `CravingModeView` (K1) is not in the diff.

## Scope (check 4)

- All 17 surviving claims and both missed reminder bugs are in the fixes table as Fixed. None skipped or held against the rules. The review had no UNVERIFIED claims.
- Onboarding (no diff), the trial flow, paywall, prices, offers, how membership is judged and when or to whom a paywall appears are unchanged. `SubscriptionService` only passes `willRenew` into `TrialLifecycle`. T2 also hides the "Cancel any time in Settings" trial recap banner for a cancelled trial; that banner is not a paywall or offer.
- Teardown on an inferred state: T2 clears the app's own trial-reminder bookkeeping when CustomerInfo says `willRenew == false`, including the cached CustomerInfo at launch (`SubscriptionService.swift:177`). That is not a membership or a user setting, 7199ab0 already cleared the same record on cached info whenever `isTrialing` was false, and the next fresh `willRenew == true` re-tracks and reschedules. J3's row deletion runs only on the user's own start edit. Neither fails check 4.
- Stored data: one optional SwiftData attribute with a default and two App Group keys. Nothing resets existing data.
- The held item (cleanup of J3 rows from before this build) is not implemented.

## Test results

| Run | gh-sim id | GitHub run | Result |
|---|---|---|---|
| Full suite on HEAD, with Home and Timeline screenshots | `sober@20261107-072346-5ffd-claude-mbpro3f9a1-1107-072521-24825` | 42386306199 | 271 passed, 0 failed, 0 skipped (iPhone 17, iOS 27.2). Same count as the fixes doc's final run (42384253904). All 46 tests in `SoberTests/StateMachineFixTests.swift` and the edited `SoberServicesTests` pass. The build compiled SoberWatch and SoberWidgets, which share the changed services. |
| N1, S1, N2 reverted, tests kept (the review's top three) | `sober@20261107-072346-5ffd-claude-mbpro3f9a1-1107-073512-21154` | 42387105299 | `ReminderSyncRegressionTests` and `SlipHistoryRegressionTests`: 31 passed, 6 failed. Failing: `n1_aSlipRequeuesTheRemindersAtTheNewStreak` (tomorrow's request still on the old streak; its pre-slip controls passed), `n1_undoingASlipRequeuesTheRestoredStreak` (nothing requeued), `n2_permissionGrantedLaterStartsTheDailyReminder` (0 daily requests, want 29 or more), `s1_slipWithALaterSlipIsNotUndoable`, `s1_aResetAfterASlipCannotBeUndoneThroughIt`, `s1_aResetOnTheSlipDayCannotBeUndoneThroughIt` (each `canUndo` true). `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater` passes with S1 reverted because J1's split guards that route. The `j4_s1_` tests pass too, as 7199ab0 matched on end date. |

How the revert was done: throwaway branch `scratch-revert` (commit `fa6c3fb`) in this worktree, switched back and deleted once gh-sim had pushed its snapshot. It restored 7199ab0's `reversibleSplit` body (S1), removed both `ReminderSync.sync` calls from `SlipRecorder` (N1), and inside `ReminderSync` restored 7199ab0's N2 rule: the first sync per store stands in for the Settings toggle, and later syncs re-add the daily requests only when one is already queued (the old `refreshDailyReminder`). Test files unchanged. This branch ends with only this doc commit on top of `6115ae2`.

Corroboration, not my proof: the fixer's S1-rework revert artifact (`sober61db-revert-mbpro33779-1107-070933-496`, GitHub run 42385010480) is on this machine, and its log shows the four `j4_s1_` tests and `s1_aLeftoverOnboardingRunDoesNotBlockUndoOfASlipBeforeSetup` failing on `canUndo`, as the fixes doc says.

## Screens (check 5)

Seeded 128-day demo (`-seedDemo -seedDays 127`). Home (launch): counter 128, garden, "Check in for today", craving card and Coming up render normally. Timeline (`-tab 1`): Current, Longest and Total all 128, November filled through today, selected day reads "Day 128". The views only changed in action handlers and the Settings start picker's range; no layout changed. Settings is a sheet off Home's ⋯ menu with no launch argument or deep link, so the picker was not captured.

## Notes

1. **Fixes doc.** Rows, test counts and run ids match what I found.
2. **N3 trade-off** (disclosed). Someone who doesn't open the app for 30 days stops getting the daily reminder until they return; 7199ab0's repeating request fired forever with frozen copy. The lapse nudge fires once at day 3. A product call for Jack, not a defect.
3. **J3 with leftover runs.** For a user onboarded before 2026-10-31, moving the start later deletes assumed rows that the leftover closed run also spans. That run is a phantom of old onboarding, so this matches J3's intent.
4. **Refusal copy edge.** Reset today, then Timeline › yesterday › Log a slip, then Change to sober is refused with "A slip can only be taken back while it's the most recent one", although it is the only slip. 7199ab0 refused the same undo (no run ended on that day), so this is not a regression; only the copy is imprecise.
5. **T2 timing.** The reminder is dropped once the app sees the cancel (next launch or foreground).
6. **Watch and widgets** use only `GardenService.stage` and `cycleProgress`, which are unchanged. Snapshots are still pushed after every write.
7. **Duo.** The Timeline pane writes through the same `SlipRecorder` and `ReminderSync` paths, and C1's guard covers the stale Home beside it. No layout code changed.
8. **Coming up** on Home lists "Wed, Dec 30" twice in the demo. `MilestoneSchedule` is not in this diff, so this is outside the change.
