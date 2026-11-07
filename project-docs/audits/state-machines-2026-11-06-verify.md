VERDICT: FAIL

# Verification of the Sober state machine fixes, 2026-11-06 (second pass)

Independent check of [the fixes](state-machines-2026-11-06-fixes.md) against [the review](state-machines-2026-11-06-review.md). I read the whole of `git diff 7199ab04ccd9d17e411f5717e3ea46d24890f24c..HEAD` at HEAD `1804795`, which includes the J4 rework ("fix: only a logged slip floors the start date, a Reset run is trimmed instead"). This replaces the first verify doc, which failed the first J4 fix. I walked every route through the views that ship, not only through the services.

**Result:** all 21 fixes work on the review's routes, the J4 rework fixes the Reset and leftover-run regression from the first pass, and the full suite is green (264 passed). It still fails on one real regression: J4's new lower bound on the Settings start picker, combined with Z1's re-keying of run starts, can crash Settings. After a westward time zone change, Z1 can move the active run's start past the current moment. `earliestStartDate()` then returns a date later than now, and `SettingsView` builds `earliest...Date.now`, a `ClosedRange` whose lower bound is above its upper bound. Swift traps on that. A probe test proves the bound passes now. On 7199ab0 the picker was `...Date.now`, which has no lower bound and cannot trap.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| N1 | Yes | Clean | Every route the review named now requeues reminders: slip and undo (`SlipRecorder.swift:103`, `:142`), Reset (`HomeView.swift:146`), check-in and Still sober (`:583`, `:482`), Home refresh (`:673`), Timeline log and delete (`TimelineView.swift:632`, `:651`), start date edit (`SettingsView.swift:293`). `ReminderSync.apply` removes and re-adds the daily, eve and lapse requests from the store (`ReminderSync.swift:94-112`). Revert run: both n1 tests fail. In `n1_aSlip...` the pre-slip controls pass and the post-slip copy check fails. |
| S1 | Yes | Clean, see note 3 | `reversibleSplit` only takes the latest closed run, and only when a slip closed it (`SobrietyService.swift:208-217`). Revert run: 3 of 4 S1 tests fail. `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater` still passes with S1 reverted because J1's split guards route (b). Both fixes ship, so the behaviour holds. |
| N2 | Yes | Clean | The opt-in is now the source of truth (`ReminderSync.swift:99-107`), and Settings syncs when the app returns from iOS Settings (`SettingsView.swift:220`). Revert run: `n2_...` fails with 0 daily requests (want 29 or more). |
| J3 | Yes | Clean, see note 4 | `updateStartDate` deletes rows only in [old start, new start), and only rows that are unlogged, sober, and have no mood or note (`SobrietyService.swift:48-58`). It runs only when the user edits the start. Rows from before `wasLogged` existed were all marked logged by `migrateLegacyCheckInsIfNeeded` (`App.swift:82`), so upgraded taps are kept. |
| T2 | Yes | Clean, see note 5 | `willRenew` (billing retry counts as renewing) reaches `TrialLifecycle.sync` (`SubscriptionService.swift:490`). A trial with renewal off is cleared (`TrialLifecycle.swift:115`). Membership and `isProSubscriber` are untouched. |
| J1 | Yes | Clean | An older slip splits the closed run it falls in (`SlipRecorder.swift:89-90`, `SobrietyService.swift:232-253`). The rest of the run keeps its reason and goal and is marked garden-untouched, so undo works newest first and leaves the tree alone. |
| C1 | Yes | Clean | `checkIn` refuses to turn a logged slip sober unless `overwritingSlip` is set (`CheckInService.swift:33`), and only `SlipRecorder.undo` sets it (`SlipRecorder.swift:139`). Home re-reads the store before a check-in (`HomeView.swift:574`). Every other sober writer skips slips: Timeline "Log as sober" only shows on unlogged days, and `backfillSoberDays` only marks rows that are already sober. |
| N3 | Yes | Clean, see note 2 | 30 dated one-shot requests, each with its own count (`NotificationService.swift:111-138`). The old repeating id is in the cancel list (`:82-84`), so upgraded users lose the frozen request on the first sync. 33 of 64 pending slots are used. Onboarding (unchanged) still calls `scheduleDailyReminder`, which now goes through the same dated requests. |
| G4 | Yes | Clean | Carryover halves the day in the current cycle (`GardenService.swift:219-222`). Under a year, `treeDays` caps at 364, so nothing changes there (`g4_underAYearStillBanksHalf`). |
| G1 | Yes | Clean | The grove baseline is restored from the slip's snapshot (`GardenService.swift:263`). |
| T1 | Yes | Clean | A repeat sync of a known trial only checks permission and never prompts (`TrialLifecycle.swift:145-147`). It schedules once permission exists, then stops (`t1_` asserts 1 schedule and 1 prompt). |
| T3 | Yes | Clean | The scheduled summary is remembered and compared (`TrialLifecycle.swift:121-128`). Home's recap refresh calls `resync()` (`HomeView.swift:780`). That does nothing once T2 or a conversion has cleared the trial. |
| G5 | Yes | Clean | Undo moves a goal set or cleared after the slip onto the reopened run (`SobrietyService.swift:171-173`). A goal the slip carried and the user never changed is kept. |
| G2 | Yes | Clean | Each slip stores its own snapshot on the run it starts (`SlipRecorder.swift:87`). The new attribute is optional with a default (`SobrietyJourney.swift:19`), which is a lightweight migration. |
| G3 | Yes | Clean | Vitality, watering and the decay counter come back from the snapshot. If the tree was watered since the slip, only what the slip took is handed back (`GardenService.swift:261-273`). |
| J4 | Yes on its route, and the first-pass regression is fixed | **Regression** (with Z1) | Only slips set the floor now (`SobrietyService.swift:70-82`). A Reset run, or the leftover run older onboarding builds left behind, is trimmed instead (`:87-93`). The three new J4 tests pass on HEAD and fail with the rework reverted (fixes doc, GitHub run 42365509593). But the floor can now land after now. See "Must change". |
| Z1 | Yes | **Regression** (with J4) | Run starts, ends and goals that sit on the old zone's midnights move with the rows (`CheckInService.swift:299-317`). Moving a start to the new zone's midnight of the same calendar day moves it later in absolute time whenever the zone moves west. That can put the start in the future, and J4's picker cannot handle it. See "Must change". |
| Missed: reminder after check-in | Yes | Clean | Today's request is left out once today is logged, sober or slip (`NotificationService.swift:121`). Check-ins resync. |
| Missed: title a day ahead | Yes | Clean | Title and body both use the count on the day the reminder fires (`NotificationService.swift:127`, `:147`). Same catalog keys. `Tools/Localization/check.py`: 778 keys, 23 languages, 0 problems. |

## Must change

**Settings crashes when the active run's start is later than now.**

- Route: Home ⋯ › I slipped, pick yesterday, Log. `SlipRecorder` starts the new run at today's local midnight. The zone then moves west before the new zone reaches that calendar day: a road trip across a zone line after midnight, a manual zone change, or any shift west of k hours within the first k hours of the day. The next `normalizeDayKeys` (app launch, any check-in or fill) runs `rekeyJourneyDays`. It moves the start to the new zone's midnight of the same date (`CheckInService.swift:305-313`), which has not arrived yet there. Then Home ⋯ › Settings. The Start section shows for every user with a journey (`SettingsView.swift:59`). `earliestStartDate()` returns `min(bound, active.startDate)` (`SobrietyService.swift:81`), and both terms are now later than now. `SettingsView.swift:64` evaluates `earliest...Date.now`, and `ClosedRange` traps ("Range requires lowerBound <= upperBound"). The app crashes every time Settings opens until the new zone's midnight. Reach is narrow, but it is a hard crash, and nothing in 7199ab0 could cause it: there the picker was `...Date.now` and run starts were never moved.
- A device clock set back past the run start gives the same state without any zone change.
- Proof, probe `VerifyProbeZoneTests/probe_startPickerLowerBoundNeverPassesNow` (temporary, not committed). It builds the state `SlipRecorder` leaves after "I slipped yesterday" in Pacific/Kiritimati, then switches to Pacific/Pago_Pago and calls `normalizeDayKeys`. Control 1 (bound ≤ now before the move) passes. Control 2 (the re-key put the run start after now) passes. The claim fails: `earliestStartDate()` is later than `Date.now`. Run ids are under "Test results". No 7199ab0 comparison is possible because `earliestStartDate` does not exist there. The base picker's range has no lower bound, so it cannot trap.
- Fix: never return a floor later than now (`min(bound, active.startDate, .now)` in `earliestStartDate`, or clamp the lower bound in `SettingsView`). Better still, `rekeyJourneyDays` should not move a start past now. Add the probe as a regression test.

## Disputed

The fixes doc's "Disputed" section says "None. Every item in the regression check was correct." Nothing is listed, so there is nothing to rule on. The first pass's one finding (J4 floor at a Reset or a leftover run) is reworked, and I confirm it is fixed (J4 row). The review's two NOT A BUG claims (J2, K1) were left alone. The diff does not touch the Reset-then-slip boundary rule or `CravingModeView`.

## Scope (check 4)

- All 19 in-scope claims and the two missed reminder bugs are in the fixes table. None were skipped or held against the rules. The review had no UNVERIFIED claims.
- No change to onboarding (no diff in `OnboardingView`), the trial flow, the paywall, prices, offers, how membership is judged, or when or to whom a paywall appears. `SubscriptionService` only gains the `willRenew` argument. The trial-ending reminder T2 drops opens the Bloom+ tab (`App.swift:397-399`), but it fires while the trial is still active, so for these users that tab shows member content, not a paywall. The recap banner T2 hides has only a "Got it" button. No backend, App Store Connect or RevenueCat change is needed.
- The held item (cleanup of J3 rows written before this build) is not implemented.
- Stored data: one optional SwiftData attribute with a default (lightweight), plus two new App Group keys. No format change resets data.
- Teardown on an inferred state: T2 clears the app's own record of the trial reminder when CustomerInfo reports `willRenew == false`. That is the store's positive statement that renewal is off, not an absence or a failed call. The pre-existing code already cleared the same record on the same CustomerInfo whenever `isTrialing` was false. If a stale cache ever says false, the next fresh true re-tracks the trial and reschedules the reminder. The only thing lost is a "Got it" dismissal of the recap banner. J3's deletion runs only on the user's own start edit. Neither is a check 4 failure.

## Test results

| Run | gh-sim id | GitHub run | Result |
|---|---|---|---|
| Full suite on HEAD, with Home and Timeline screenshots | `sober@20261107-033553-be65-claude-imac74d4-1107-033719-1368` | 42368963451 | 264 passed, 0 failed, 0 skipped (iPhone 17, iOS 27.2). Same count as the fixes doc's final run (42362521342). No new failures, and every test the change added or edited passes. |
| N1, S1, N2 reverted, tests kept (top three by the review's rank) | `sober@20261107-033553-be65-claude-imac74d4-1107-040148-26412` | 42370691623 | 6 failed, 1 passed. Fail: both n1, n2, and `s1_slipWithALaterSlipIsNotUndoable`, `s1_aResetAfterASlipCannotBeUndoneThroughIt`, `s1_aResetOnTheSlipDayCannotBeUndoneThroughIt` (each `canUndo` reads true). Passes: `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater` (guarded by J1). |
| Z1 and J4 crash probe on HEAD | `sober@20261107-033553-be65-claude-imac74d4-1107-042928-13287` | (gh-sim id only) | 1 failed: both controls pass, and `earliestStartDate()` is later than now. |

How the revert was done: a throwaway branch `scratch-revert` (commit `d5e8a76`, since deleted). It restored the old `reversibleSplit` body and removed both `ReminderSync.sync` calls from `SlipRecorder`. For N2 it restored the old rule inside `ReminderSync`: the first sync stands in for the Settings toggle and schedules once (a no-op without permission), and after that the daily requests are only re-added when a daily reminder is already queued. That is the old `refreshDailyReminder` rule, and it keeps n1's pre-slip controls valid. The test files were unchanged. This branch ends with only this doc commit on top of `1804795`.

## Screens (check 5)

On a seeded 128-day demo, Home (`-tab 0`) and Timeline (`-tab 1`) render normally. Counter 129, garden, check-in card and the coming-up list all show, and Timeline's Current, Longest and Total agree at 129. The diff's only layout-visible change is the Settings start picker's lower bound. Settings is a sheet off Home's ⋯ menu and no launch argument opens it, so it was not captured. The other view changes (Home, Timeline) are action handlers with no layout change. Duo: the Timeline pane writes through the same `SlipRecorder` and `ReminderSync` paths, and C1's guard covers the stale Home beside it.

## Notes

1. **Fixes doc.** Its J4 row and test runs match what I found. The first pass's bookkeeping note is resolved: commits are cited by subject.
2. **N3 trade-off.** Someone who doesn't open the app for 30 days stops getting the daily reminder (the lapse nudge fires once at day 3). This is disclosed in the doc. A generic repeating request after the dated window would keep the nudge going without stale counts.
3. **Zero-length runs after a J4 trim.** Moving the start back past a Reset run's own start leaves that run zero-length inside the active span (`SobrietyService.swift:91`). It counts as 1 in `longestStreakDays`, which is harmless. Timeline's tree preview for that one day picks it first and shows a day-1 tree (`TimelineView.swift:41`). It also becomes the "predecessor", so a slip right before that Reset can't be undone. That matches S1's intended refusal to undo through a Reset. Cosmetic.
4. **J3 with legacy overlapping runs.** For users whose runs already overlap (the J4 bug on 7199ab0, or the double-onboarding leftover), moving the start later can trim a slip-closed run and delete assumed rows that run still covers. This needs pre-existing corrupt data. Note only.
5. **T2 limits.** The reminder is only dropped once the app sees the cancel (next launch or foreground). That can't be helped without a server push.
6. Watch and widgets call none of the changed paths (`SoberWatch`, `SoberWidgets` use none of `SlipRecorder`, `ReminderSync`, `updateStartDate`, `normalizeDayKeys`). Widget snapshots are still pushed after every write. Run re-keying only happens when a zone was recorded and has changed, so nothing moves on upgrade.
