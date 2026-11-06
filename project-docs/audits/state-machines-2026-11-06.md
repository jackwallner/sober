# Sober state machine audit, 2026-11-06

Audited `main` at `47e1ad6b` (build 118). 19 bugs found, none fixed yet.

- **Proved by test (12 bugs):** [the repro suite](state-machines-2026-11-06-repro.swift) has 15 tests stating the promised behaviour. 14 fail and the control passes. gh-sim run `sober-mbairee5e-1106-104658-17959`, iPhone 17 on iOS 27.2.
- **Traced in code, not run (7 bugs):** these need the notification center, a live RevenueCat customer, a zone change or a suspended app, so a unit test can't show them.

The repro suite is kept out of `SoberTests` so it doesn't break the build. To fix a bug, move its test across.

## Bugs by impact

| # | Bug | What the user sees | Evidence | Where |
|---|---|---|---|---|
| N1 | A slip doesn't update pending notifications | Slip tonight, close the app, and tomorrow's reminder says "You're 100 days in". "Tomorrow is day 30" and "100 days is still 100 days" can fire too. Same after Reset, undo and a start date edit | Code path | `HomeView.swift:139-146`, `:230-235`, `:765-797`; `TimelineView.swift:548-557`, `:636-644` |
| S1 | Undo can reverse more than the latest slip | The counter jumps past a logged slip. Slips yesterday and today, undo yesterday: counter reads 41 with today still logged as a slip. Older slip entered later, undo the newer: counter reads 101 through the older one. Also undoes a deliberate Reset | Test s1, s2, s3 | `SobrietyService.swift:130-147` |
| N2 | Granting notification permission later never schedules the daily reminder | Reminders read Enabled and the warning clears, but no daily reminder ever arrives until the toggle is flipped | Code path | `SettingsView.swift:185-196`; `NotificationService.swift:110-113`; `HomeView.swift:765-773` |
| T1 | Same gap for the trial reminder | Deny at trial start, allow later, and the promised pre-charge warning never comes | Test t1 | `TrialLifecycle.swift:102`, `:108-118` |
| J3 | Moving the start date later leaves the old days counted | Fix a start date from 100 days ago to 5 days ago: lifetime stays 100, not 5, and lifetime money and calories stay inflated. Every date tapped in the picker writes rows, so a mis-tap sticks | Test j3 | `SettingsView.swift:246-262` |
| C1 | A check-in can overwrite a logged slip | On an unfolded iPhone Duo, log a slip in the Timeline pane and Home still offers "Check in for today". Tapping it turns the day green, the counter stays reset, and undo is gone | Test c1 for the overwrite; Duo route by code path | `CheckInService.swift:25-31`; `HomeView.swift:570-578`, `:1423-1439`; `App.swift:335-344` |
| G1 | Undo past a year adds a phantom tree | Grove count goes from 1 to 2 | Test g1 | `GardenService.swift:182`, `:198-210` |
| G4 | A slip can grow the tree | Slip on day 400: tree goes from Adolescent to Ancient, because carryover halves 400 rather than the day in the cycle | Test g4 | `GardenService.swift:177-178` |
| J2 | A slip after a same-day Reset scores the wiped run | Reset a 100-day run, slip the same day: "kept 50 days from the 100-day run", after the Reset promised a fresh start | Test j2 | `SobrietyService.swift:164-177` |
| J1 | An older slip doesn't stop the run it falls in | Longest streak reads 91, should be 51, though the slip alert promises it "reflects the corrected dates" | Test j1 | `SlipRecorder.swift:78-87` |
| G2 | Undoing two slips loses the earlier carryover | Carryover ends at 0, should be 15 | Test g2 | `GardenService.swift:179`, `:200-202` |
| J4 | Moving the start earlier can cross a logged slip | Counter reads 31 with a logged slip 10 days ago, and the run overlaps the closed one | Test j4 | `SobrietyService.swift:33-37` |
| T2 | A cancelled trial still gets the trial reminder | "Cancel any time before it renews" after they already cancelled | Code path | `SubscriptionService.swift:486-490` |
| N3 | The daily reminder's copy freezes | It repeats with a fixed streak, so someone away for a week reads the same "Day 31 is waiting" every day | Code path | `NotificationService.swift:85-104` |
| G3 | Undo doesn't restore vitality or watering | Vitality 0.4 comes back as 0.6, and `lastWateredAt` stays nil so decay stops until the next check-in | Test g3 | `GardenService.swift:184`, `:207` |
| G5 | Undo drops a goal set after the slip | The goal is gone, because it lived on the deleted run | Test g5 | `SobrietyService.swift:108-110` |
| T3 | The trial reminder's numbers go stale | Its "N sober days and $X saved" is fixed when the trial starts, then fires days later, even after a slip | Code path | `TrialLifecycle.swift:102`, `:106` |
| Z1 | Run dates aren't re-keyed on a zone change | Rows are, runs aren't. Fly west and a run starting at midnight counts one day extra until you return, and undo can vanish | Code path | `CheckInService.swift:241-282`; `SobrietyService.swift:132-142`; `DateHelpers.swift:13-18` |
| K1 | The craving timer stops while suspended | Lock the phone mid-session and the logged duration comes up short | Code path | `CravingModeView.swift:47` |

J3 and J4 test my reading of correct behaviour. A start date edit could reasonably be allowed to override history, so those two are product calls.

## Related fixes, in order

1. **Reminders follow state (N1, N2, N3):** one reschedule call after every slip, undo, Reset and start date edit, plus repair on app open when reminders are enabled but none is pending.
2. **Slip reversal (S1, G1, G2, G3, G5):** only reverse when the closed run is the active run's direct predecessor and was closed by a slip. Store a full garden snapshot per slip.
3. **Trial reminder (T1, T2, T3):** track "scheduled" apart from "known trial", pass `willRenew`, and re-sync when permission changes.
4. **Start date edits (J3, J4):** drop assumed rows outside the run and bound the picker by the latest logged slip.
5. **History (J1, J2, G4):** split the closed run on an older slip, scan newest first on a reset boundary, and halve the day in the cycle.
6. **Mounted Home state (C1):** refresh on data change, and refuse a sober check-in over a logged slip in `CheckInService`.
7. **Z1 and K1:** low priority.

## State machines

### Sobriety run (`SobrietyJourney`, implicit in `endDate` and `resetReason`)

States: Open, Closed by slip, Closed by reset.

Invariants: (I1) one open run after setup. (I2) Runs never overlap. (I3) No run spans a logged slip. (I4) Only the latest event can be reversed.

| From | Event | To | Holds? |
|---|---|---|---|
| None | Onboarding `persistSetup` | Open | Yes |
| Open, setup unfinished | Another setup pass | Open, start moved | Yes |
| Open | Slip on or after the run's start | Closed by slip, plus new Open | Yes |
| Open | Slip before the run's start | Unchanged | No: I3 (J1) |
| Open | Reset | Closed by reset, plus new Open | Yes |
| Open, with slip before it | Undo | Delete Open, reopen matching closed run | No: I1 to I4 (S1) |
| Open | Start date edit | Open, start moved | No: I2, I3 (J4) |

### Calendar day (`DailyCheckIn`, implicit in `wasSober` and `wasLogged`)

States: Missing, Assumed, Tended sober, Slip.

Invariants: (I5) one row per calendar day. (I6) A Slip only leaves through undo. (I7) Sober rows sit inside a run.

| From | Event | To | Holds? |
|---|---|---|---|
| Missing | `fillJourney` | Assumed | Yes |
| Missing or Assumed | Check-in, "Still sober", or `saveDetail` | Tended sober | Yes |
| Assumed | Mood or note edit in Timeline | Tended sober | Yes |
| Any | `SlipRecorder.record` | Slip | Yes |
| Slip | `SlipRecorder.undo` | Tended sober | Yes |
| Slip | `checkIn()` from stale Home state | Tended sober | No: I6 (C1) |
| Tended sober | Delete log | Missing, then Assumed on the next fill | Yes |
| Assumed outside a run | Start moved later | Stays Assumed | No: I7 (J3) |
| Any | Zone change | Re-keyed and merged | Yes for rows, runs left out (Z1) |

### Garden (`GardenState`)

Tracks carryover, `carryoverBeforeSlip`, grove baseline, growth watermark and vitality.

Invariants: (I8) undo restores everything the slip changed. (I9) A slip never grows the tree. (I10) Grove count equals baseline plus completed cycles.

| Event | Effect | Holds? |
|---|---|---|
| Check-in | Water, vitality +0.25, decay counter 0 | Home only: Timeline's "Log as sober" doesn't water |
| Home appears | Charge missed days once, floor 0.3 | Yes |
| Slip | Carryover halved, one-slot snapshot, watermark 0, baseline reset, vitality -0.3, unwatered | No: I9 (G4) |
| Undo | Carryover from snapshot, watermark raised, vitality +0.3 | No: I8, I10 (G1, G2, G3) |
| Reset | Bare soil, grove kept | Yes |
| Cycle crossed | Tree appended | Yes |

### Home check-in control (implicit in `@State` flags)

Checked in order: Welcome back, Slip card, Logged card, Check-in button.

Invariant: (I11) the flags match the store. They refresh on `onAppear`, scene active, day change and time change. That covers a phone, where switching tabs fires `onAppear`. It doesn't cover the Duo, where Home and Timeline are both on screen (C1).

### Onboarding (`step` plus `hasCompletedOnboarding`)

Steps 0 to 3, then trial resolution, offer step 4, reminders step 5, complete. Exits from the offer: purchased, pending, skipped or no store. Cancel stays on step 4. A kill mid-flow restarts at step 0 with saved answers restored, and the open run moves rather than duplicates. No bugs found.

### Entitlement and trial (`SubscriptionService`, `TrialLifecycle`)

States: Unresolved, Check failed, Free, Trial renewing, Trial cancelled, Paid, Purchase pending.

Invariants: (I12) a trial gets a warning if permission allows. (I13) The warning matches renewal state.

| Event | Effect | Holds? |
|---|---|---|
| Customer info with active trial | Store end date, ask permission, schedule | No: I12, a denial is never retried (T1) |
| Same trial seen again | No-op within 60 seconds of the stored end | Part of T1 and T3 |
| Trial cancelled, still active | Treated as trialing | No: I13 (T2) |
| Trial gone or converted | Clear state, cancel reminder | Yes |
| Deferred purchase | Pending, unlocks through the delegate | Yes |
| Offline refresh | Keeps previous state, marks check failed | Yes |

### Reminders (`NotificationService`)

Each of the daily, milestone-eve and lapse reminders is None or Pending, and depends on opt-in, permission and run state.

Invariants: (I14) enabled with permission means daily is pending. (I15) Pending copy matches the current run.

| Event | Effect | Holds? |
|---|---|---|
| Toggle on, permission granted | Schedule all three | Yes |
| Toggle off | Cancel all three | Yes |
| Permission granted outside the app | Lapse and milestone only, on next Home refresh | No: I14 (N2) |
| Home refresh | Reschedule lapse and milestone, re-copy daily if pending | Yes |
| Slip, undo, Reset or start edit, then app closed | Nothing | No: I15 (N1) |
| Days pass with the app closed | Daily repeats fixed copy | No: I15 (N3) |

### Smaller machines, no bugs beyond those above

- **Craving session:** breathing, reflect, done. `hasFinished` stops double logging, and "I gave in" hands off to the cancellable slip sheet. Timer: K1.
- **One-shot prompts:** the post-onboarding paywall flag clears only when presented. The review prompt is gated by second launch, 30-day cooldown and a clear Home.
- **Day key zone:** `checkInDayKeyZone` is marked only after a successful save, so a failure retries. Runs are out of scope for it: Z1.
