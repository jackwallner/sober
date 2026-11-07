# Fixes for the Sober state machine review, 2026-11-06

Fixes for every claim [the review](state-machines-2026-11-06-review.md) marked CONFIRMED or CONFIRMED-MINOR, plus the two reminder bugs it found that [the audit](state-machines-2026-11-06.md) missed, in the review's ranked order.

**Summary: 19 in-scope claims (6 CONFIRMED, 11 CONFIRMED-MINOR, 2 missed by the audit). 19 fixed, 0 held, 0 skipped. 2 NOT A BUG left alone (J2, K1).** One follow-up decision is listed under "Held for Jack".

Regression tests live in `SoberTests/StateMachineFixTests.swift`. Each test name starts with its claim id. The audit's repro tests the review called sound are kept there as written; J2's (an opinion against a documented rule) is not. The repro suite itself was never added to the test target.

## In-scope claims

| Rank | ID | Outcome | Commit | Regression test | What changed |
|---|---|---|---|---|---|
| 1 | N1 | Fixed | COMMIT_REMINDERS | `n1_aSlipRequeuesTheRemindersAtTheNewStreak`, `n1_undoingASlipRequeuesTheRestoredStreak` | New `ReminderSync` requeues the daily, milestone-eve and lapse reminders from the store. Called after every slip and undo (`SlipRecorder`), Reset, check-in, "Still sober", Timeline log and delete, start date edit, and Home refresh. |
| 2 | S1 | Fixed | COMMIT_HISTORY | `s1_slipWithALaterSlipIsNotUndoable`, `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater`, `s1_aResetAfterASlipCannotBeUndoneThroughIt`, `s1_aResetOnTheSlipDayCannotBeUndoneThroughIt` | `reversibleSplit` only reverses the run directly before the active one, and only when a slip closed it. Covers the same-day Reset sub-claim (s3). |
| 3 | N2 | Fixed | COMMIT_REMINDERS | `n2_permissionGrantedLaterStartsTheDailyReminder` | The opt-in is the source of truth: a sync with permission schedules the daily reminder whether or not one is pending. Settings also syncs when the app returns from iOS Settings. |
| 4 | J3 | Fixed | COMMIT_START | `j3_movingTheStartLaterRemovesTheDaysItNoLongerCovers`, `j3_daysTheUserTendedSurviveTheMove`, `j3_aMisTapEarlierThenTheRightDateLeavesNoExtraDays` | Moving the start later deletes the app-assumed rows (unlogged, sober, no mood or note) in the range the run no longer covers. Tapped days and anything with a mood or note stay. |
| 5 | T2 | Fixed | COMMIT_TRIAL | `t2_aCancelledTrialDropsItsRenewalReminder`, `t2_aCancelledTrialFromRevenueCatIsNotReminded` | `TrialLifecycle.sync` takes `willRenew` (billing retry still counts as renewing, as `TrialNote` does). A trial with renewal off is cleared: reminder cancelled, recap banner gone. |
| 6 | J1 | Fixed | COMMIT_HISTORY | `j1_olderSlipStopsTheRunItFallsIn`, `j1_bothSlipsUndoNewestFirst` | An older slip entered after a newer one splits the closed run it falls in (`splitClosedJourney`), so the longest streak stops at it. The garden is still left alone, and both slips undo newest first. |
| 7 | C1 | Fixed | COMMIT_CHECKIN | `c1_aCheckInCannotOverwriteALoggedSlip` | `CheckInService.checkIn` refuses to turn a logged slip sober unless `overwritingSlip` is set, which only `SlipRecorder.undo` does. Home's check-in button re-reads the store first, so a stale Duo Home shows the slip card instead. |
| 8 | N3 | Fixed | COMMIT_REMINDERS | `n3_eachQueuedDayCarriesItsOwnCount` | The repeating daily request is replaced by 30 dated one-shot requests, each carrying that day's count. |
| 9 | G4 | Fixed | COMMIT_GARDEN | `g4_aSlipDoesNotGrowTheTree`, `g4_underAYearStillBanksHalf` | `recordSlip` halves the tree on screen (the day in the current cycle), not the whole streak. |
| 9 | G1 | Fixed | COMMIT_GARDEN | `g1_undoPastAYearDoesNotAddATree` | Undo restores the grove baseline from the slip's snapshot. |
| 10 | T1 | Fixed | COMMIT_TRIAL | `t1_reminderIsScheduledOncePermissionArrivesLater` | "Known trial" and "reminder scheduled" are tracked apart, so a trial first seen while notifications were denied gets its reminder on a later sync, once. |
| 10 | T3 | Fixed | COMMIT_TRIAL | `t3_theReminderPicksUpNewRecapNumbers` | The scheduled summary is remembered; Home's recap refresh calls `TrialLifecycle.resync()`, which reschedules when the numbers changed. |
| 11 | G5 | Fixed | COMMIT_GARDEN | `g5_undoKeepsAGoalSetAfterTheSlip`, `g5_undoKeepsTheGoalTheSlipCarried` | Undo moves a goal set or cleared after the slip onto the reopened run. |
| 11 | G2 | Fixed | COMMIT_GARDEN | `g2_undoingTwoSlipsRestoresTheOriginalCarryover` | Each slip stores a garden snapshot on the run it starts (`SobrietyJourney.gardenBeforeSlip`), so undoing two slips walks back through both. |
| 11 | G3 | Fixed | COMMIT_GARDEN | `g3_undoRestoresVitalityAndWatering` | Undo restores vitality, last watering and the decay counter from the snapshot; if the tree was watered since, it keeps that and hands back only what the slip took. |
| 11 | J4 | Fixed | COMMIT_START | `j4_movingTheStartEarlierCannotCrossALoggedSlip`, `j4_aFirstRunHasNoLowerBound` | `SobrietyService.earliestStartDate()` (day after the previous slip, or the Reset moment) bounds both the Settings picker and `updateStartDate`. |
| 11 | Z1 | Fixed | COMMIT_ZONE | `z1_runDaysMoveWithTheRowsOnAZoneChange` | `normalizeDayKeys` re-keys run starts, ends and goals that sit on the old zone's midnights, alongside the rows. Runs started at a moment keep it. |
| missed | Daily reminder fires after today's check-in | Fixed | COMMIT_REMINDERS | `checkedInTodayDropsTodaysReminder`, `aPassedHourLeavesTodayOut` | Today's dated reminder is left out once today is logged (sober or slip); check-ins resync. |
| missed | Title one day ahead of its body | Fixed | COMMIT_REMINDERS | `titleAndBodyNameTheSameDay` | Title and body both name the counter on the day the reminder fires. Existing catalog keys, no new copy. |

Upgrade coverage: `upgrade_undoOfASlipFromBeforeSnapshots` (a run written before `gardenBeforeSlip` existed still undoes, restores the old one-slot carryover and adds no tree) and `upgrade_aTrialTrackedByTheOldBuildIsRescheduledOnce`. `gardenBeforeSlip` is an optional attribute with a default, the same lightweight migration as `goalDate`. Nothing existing is reset or dropped.

## Held for Jack

- **Repair for users who already hit J3.** The fix stops new stale rows. Users who moved their start later before this build still have assumed rows before their first run, inflating lifetime days, money and calories, and Timeline can't reach them. Those rows can't be told apart from real taps logged by builds before `wasLogged` existed, so a cleanup could delete check-ins a long-time user really made. Decision: run a one-time cleanup of unlogged, mood-less, note-less rows before the earliest run start, or leave existing data as it is?

Not held, but worth knowing: N3's fix queues 30 days of dated reminders. Someone who doesn't open the app for 30 days stops getting the daily one until they return (the lapse nudge still reaches them at day 3). A repeating request can't carry changing copy, so this was the trade.

## Skipped

None.

## Test runs

- **Baseline** (before any change, clean worktree at `d04516c`): gh-sim `sober@baseline-430b-mbpro7267-1106-170925-4007`, GitHub run 42322504799, iPhone 17 on iOS 27.2. 225 passed, 0 failed.
- **Final**: FINAL_RUN
