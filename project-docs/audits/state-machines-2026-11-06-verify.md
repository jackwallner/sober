VERDICT: FAIL

# Verification of the Sober state machine fixes, 2026-11-06

Independent check of [the fixes](state-machines-2026-11-06-fixes.md) against [the review](state-machines-2026-11-06-review.md), reading `git diff 7199ab04ccd9d17e411f5717e3ea46d24890f24c..HEAD` (HEAD `d6326cd`; the fixes are `21c68fb` and `552aee8`). Every route below was walked through the views that ship, not only the services.

**Result: 18 of 19 fixes work as claimed and the full suite is green, but the J4 fix breaks a neighbouring route.** Its new start date floor also stops at a Reset. After Home › Reset counter, Settings › Sobriety Start can no longer be moved earlier, so an accidental or early Reset can't be corrected any more. The same floor locks the start for long-time users who still have the leftover closed run older onboarding builds created. A probe test fails on HEAD for both and passes on 7199ab0.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| N1 | Yes | Clean | Every route in the review now requeues: slip and undo (`SlipRecorder.swift:103`, `:142`), Reset (`HomeView.swift:146`), Timeline log and delete (`TimelineView.swift:632`, `:651`), start edit (`SettingsView.swift:293`), check-in and Still sober (`HomeView.swift:583`, `:482`), Home refresh (`:673`). `ReminderSync.apply` replaces all three reminders from the store (`ReminderSync.swift:94-112`). Revert run: the eve stays on day 30 and the lapse keeps "28" after a slip (`StateMachineFixTests.swift:90`, `:91` fail, the eve control at `:82` passes). |
| S1 | Yes | Clean | `reversibleSplit` takes only the latest closed run, and only when a slip closed it (`SobrietyService.swift:194-201`). Slips logged before this build all carry `"slip"` (Timeline used `resetJourney` since `6bf94d4`; Home's old "Start fresh" wrote no slip row, so it never offered undo), so upgraded users keep their undo. Revert run: 3 of the 4 S1 tests fail. `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater` still passes with S1 reverted, because J1's split is what guards route (b). Both fixes are in, so the behaviour holds. |
| N2 | Yes | Clean, see note 3 | The opt-in is now the source of truth (`ReminderSync.swift:78-89`), and Settings syncs on return from iOS Settings (`SettingsView.swift:217-221`). Revert run: `n2_permissionGrantedLaterStartsTheDailyReminder` fails with 0 daily requests. |
| J3 | Yes | Clean, see note 4 | `updateStartDate` drops unlogged, sober rows with no mood and no note between the old and new start (`SobrietyService.swift:41-58`). Tapped days, slips and anything with a note or mood stay. The deletion only runs on the user's own start edit. |
| T2 | Yes | Clean, see note 5 | `willRenew` (billing retry counts as renewing, the same rule `TrialNote` uses) reaches `TrialLifecycle.sync` (`SubscriptionService.swift:490`). A trial with renewal off is cleared (`TrialLifecycle.swift:115-118`). Membership (`entitlementActive`) is untouched. |
| J1 | Yes | Clean | An older slip splits the closed run it falls in (`SlipRecorder.swift:89-94`, `SobrietyService.swift:216-237`). The rest of the run keeps its reason and goal and is marked garden-untouched, so undo works newest first and leaves the tree alone. |
| C1 | Yes | Clean | `checkIn` refuses to turn a logged slip sober unless `overwritingSlip` (`CheckInService.swift:33`); only `SlipRecorder.undo` passes it (`SlipRecorder.swift:139`). Home re-reads the store before a check-in (`HomeView.swift:572-578`), so a stale Duo Home shows the slip card. No other caller writes a sober check-in onto a slip day (Timeline offers "Log as sober" only on unlogged days, `TimelineView.swift:534-542`). |
| N3 | Yes | Clean, see note 2 | 30 dated one-shot requests, each with its own count (`NotificationService.swift:111-138`). The old repeating id is in the cancel list, so upgraded users lose the frozen request on the first sync (`:82-84`). 33 of the 64 pending slots are used, counting the trial reminder. |
| G4 | Yes | Clean | Carryover halves the day in the current cycle (`GardenService.swift:219-222`). Under a year it is unchanged (`g4_underAYearStillBanksHalf`). |
| G1 | Yes | Clean, see note 7 | The grove baseline comes back from the slip's snapshot (`GardenService.swift:261-263`). |
| T1 | Yes | Clean | A repeat sync of a known trial only checks permission (`TrialLifecycle.swift:145-148`), so no prompt is raised on a Home visit. It schedules once permission exists, and stops after that (`t1_` asserts 1 schedule and 1 prompt). |
| T3 | Yes | Clean | The scheduled summary is remembered and compared (`TrialLifecycle.swift:120-129`). Home's recap refresh calls `resync()` (`HomeView.swift:780`), which is a no-op once T2 or a conversion has cleared the trial. |
| G5 | Yes | Clean | Undo moves a goal set or cleared after the slip onto the reopened run (`SobrietyService.swift:153-158`). A goal the slip carried unchanged is kept as it was. |
| G2 | Yes | Clean | Each slip stores its own snapshot on the run it starts (`SlipRecorder.swift:87`). The new attribute is optional with a default (`SobrietyJourney.swift:19`), the same lightweight migration as `goalDate`. |
| G3 | Yes | Clean | Vitality, watering and the decay counter come back from the snapshot. If the tree was watered since the slip, only what the slip took is handed back (`GardenService.swift:264-273`). |
| J4 | Yes, on its route | **Regression** | Correct for a slip at −10: the floor is −9. But `earliestStartDate` also treats any closed run that didn't end in a slip as a floor at its end instant (`SobrietyService.swift:70`), and `updateStartDate` clamps to it (`:45`). See "Must change". |
| Z1 | Yes | Clean | Run starts, ends and goals sitting on the old zone's midnights move with the rows. Runs started at a moment keep it (`CheckInService.swift:280`, `:299-317`). It only runs when a zone was recorded and changed, so nothing moves on upgrade. |
| Missed: reminder after check-in | Yes | Clean | Today's request is left out once today is logged, sober or slip (`NotificationService.swift:121`). Check-ins resync. |
| Missed: title a day ahead | Yes | Clean | Title and body both use the count on the firing day (`NotificationService.swift:141-159`). Same catalog keys, and `Tools/Localization/check.py` reports 0 problems across 23 languages. |

## Must change

**J4: don't put a floor at a Reset or at any other closed run that didn't end in a slip.**

- Route 1, any user: Home ⋯ › Reset counter (`HomeView.swift:139-146` calls `SobrietyService.reset()`, which closes the run at `.now` with no reason, `SobrietyService.swift:101-106`). Then Settings › Sobriety Start. `earliestStartDate` returns the Reset instant (`SobrietyService.swift:70`, `:76`), so the picker's range is today only (`SettingsView.swift:64`), and `updateStartDate` clamps anything earlier back to it (`:45`). On 7199ab0 the start could be set to any past day. Two cases are now stuck: someone who drank three days ago and hit Reset (the obvious button) before setting the real date, and someone who hit Reset by mistake and used to repair it in Settings. Reset has no undo, and Timeline can't move the counter, so nothing else gets either of them back.
- Route 2, users who onboarded before `ff76571` (2026-10-31) and passed setup twice: the leftover closed run from that pass ends at the onboarding instant with no reason. `earliestStartDate` returns `min(that end, active start)`, which is the current start, so the start can never be moved earlier.
- Proof, probe `J4ResetProbeTests` (temporary, not committed): Reset, then `updateStartDate(daysAgo(3))`. HEAD reads day 1 instead of 4. A leftover onboarding run, then `updateStartDate(daysAgo(60))`. HEAD reads 41 instead of 61. Run ids are under "Test results".
- Fix: only logged slips should set the floor (slip-closed runs and `lastSlipDate`). When the start moves before a closed run that didn't end in a slip, trim that run's end to the new start instead of refusing, so runs still don't overlap. Add both probe routes as regression tests.

## Disputed

The fixes doc has no "Disputed" section, and it lists no item as disputed. Nothing to rule on. The review's two NOT A BUG claims (J2, K1) were left alone: the diff doesn't touch the Reset-then-slip boundary rule or `CravingModeView`.

## Scope (check 4)

- All 19 in-scope claims appear in the fixes table. Nothing was skipped or held against the rules. The review had no UNVERIFIED claims.
- No change to onboarding, paywall, prices, offers, membership or when a paywall or trial offer appears. `SubscriptionService` only gains the `willRenew` argument. No backend, App Store Connect or RevenueCat change is needed.
- The held item (a cleanup of J3 rows written before this build) was not implemented.
- Stored data: one optional SwiftData attribute with a default (lightweight), plus two new App Group keys. No format change resets data.
- Teardown on an inferred state: T2 clears the tracked trial and its reminder when the CustomerInfo's `willRenew` is false. That is a reminder about the trial's renewal, not membership or user data. It reads the same field `TrialNote.whatToFixDue` already acts on (`SubscriptionService.swift:498`). If a stale cache ever says false, the next fresh true re-tracks the trial. J3's deletion runs only on the user's own start edit, not on an inferred state. Neither counts as a check 4 failure.

## Test results

| Run | gh-sim id | GitHub run | Result |
|---|---|---|---|
| Full suite on HEAD, plus Home and Timeline screenshots | `sober@20261106-211001-7e24-claude-mbpro38e82-1106-211054-24127` | 42341622160 | 261 passed, 0 failed, 0 skipped (iPhone 17, iOS 27.2). Same count as the fixes doc's final run. No new failures. |
| Fixes reverted (N1, S1, N2), tests kept | `revert-mbpro38e82-1106-231200-18281` | 42350265512 | 6 failed, 1 passed: both n1, n2, and three of four s1 fail. `s1_undoDoesNotRunThroughAnOlderSlipEnteredLater` passes (guarded by J1, see the S1 row). |
| First attempt at the revert run | `sober@20261106-211001-7e24-claude-mbpro38e82-1106-221051-14736` | 42345847471 | Ran 0 tests: Swift Testing ids need a trailing `()` in `--only`. Proves nothing; rerun above. |
| J4 probe on HEAD | `probe-head-mbpro38e82-1106-234740-30443` | 42352750770 | 2 failed: Reset then back-date reads 1 (want 4); leftover onboarding run then back-date reads 41 (want 61). |
| J4 probe on 7199ab0 | `probe-base-mbpro38e82-1107-002523-8022` | 42355427188 | 2 passed: Reset then back-date reads 4, leftover onboarding run then back-date reads 61. The behaviour the probe expects is what shipped before the fix. |

How the revert was done: a throwaway branch `scratch-revert` (commit `e79e2af`, since deleted). It restored the old `reversibleSplit` and removed both `ReminderSync.sync` calls from `SlipRecorder`. N2 was reverted by gating `ReminderSync.sync`'s daily requests on a daily reminder already pending in the real center, the old `refreshDailyReminder` rule. The test files were unchanged. This branch ends with only this doc on top of `d6326cd`.

## Screens (check 5)

Home (`-tab 0`) and Timeline (`-tab 1`) on a seeded 128-day demo render normally: counter, garden, check-in card, calendar and the streak summary agree (128 current, longest and total). The visible change in the diff is the Settings start date picker's lower bound. Settings is a sheet off Home's ⋯ menu, and no launch argument opens it, so it wasn't captured. The rest of the view changes (Home, Timeline) are action handlers with no layout change.

## Notes

1. **Fixes doc bookkeeping.** Rows T2, T1 and T3 still say `COMMIT_TRIAL`; they landed in `21c68fb` and `552aee8`. The second-pass commit is cited as `ede3cf3`, which doesn't exist in this repo; it is `552aee8` here.
2. **N3 trade-off.** Someone who doesn't open the app for 30 days stops getting the daily reminder (the lapse nudge fires once at day 3). The doc discloses this. A repeating generic request after the dated window would keep the daily nudge going for that user without stale counts. Worth considering, not a failure.
3. **N2 reach.** Users who onboarded before `9eb0ff4` (2026-07-26) stored `dailyReminderEnabled = true` by default. Onboarding asked for permission then. If they later granted permission for another reason (the trial prompt), they now start getting the daily reminder. They already got the milestone and lapse nudges under the same rule, so this matches the review's reading of the opt-in.
4. **J3 and pre-`wasLogged` taps.** The fixes doc already holds this for Jack: a sober day tapped before 2026-09-03, with no mood or note, inside the dropped range goes with the assumed rows.
5. **T2 limits.** The reminder is only dropped once the app sees the cancel (next launch or foreground). A user who cancels and never reopens still gets it, and that can't be fixed without a server push. The Home recap banner is also hidden for a cancelled trial. That is a heads-up card, not a paywall or offer, and its copy ("cancel any time") had the same wrong premise.
6. **J4 by design.** The floor on the review's own route (a logged slip) is right. Only the Reset and leftover-run cases above are wrong.
7. **G1 legacy edge.** Undoing a slip logged before this build, when the restored run crosses a 365-day boundary in between, sets the baseline one low, so that crossing doesn't add its tree. It needs a pre-upgrade slip, a year-long run and an undo at the boundary. Cosmetic.
8. Watch and widgets don't call any changed path (`SoberWatch`, `SoberWidgets` don't use `SlipRecorder`, `ReminderSync`, `updateStartDate` or `normalizeDayKeys`). Widget snapshots are still pushed after every write as before. iPhone Duo: the Timeline pane writes through the same `SlipRecorder` and `ReminderSync` paths, and C1 covers the stale Home beside it.
