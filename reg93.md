# Sober build 83 to build 87 regression audit

Date: 2026-09-04

## Scope

Compared the currently released App Store Connect build, version 1.3.0 (build 83), with the latest processed TestFlight build, version 1.3.1 (build 87).

Success criterion: identify reproducible regressions, data-integrity bugs, or material user-experience problems introduced or exposed in build 87, with enough evidence to act on them.

## Build identity

| Build | ASC state | Uploaded | Matching source |
|---|---|---|---|
| 1.3.0 (83) | Ready for Sale, processing valid | 2026-08-25 14:03 PDT | `adbbdf9` (`chore(sober): bump build 82 -> 83`) |
| 1.3.1 (87) | Internal beta testing, processing valid | 2026-09-03 22:55 PDT | `8b1e536` (`chore(sober): bump build 86 -> 87`) |

ASC app ID: `6768869215`. Both builds target iOS 17.0 and have valid processing status. Build 87 is not linked to an App Store version yet.

## Method and limitations

- Queried ASC read-only for version, build, processing, beta, and diagnostic metadata.
- Generated and built the exact build 83 source snapshot and the current build 87 source snapshot in the headless shared iOS simulator pool.
- Seeded the same App Group data and compared the Home experience across both snapshots.
- Ran the current shipped test suite: 113 tests passed, 0 failed, 0 skipped.
- ASC provided no usable diagnostic signatures for either build, so this audit cannot establish a crash-rate comparison.
- The App Store Connect binary payloads were not downloaded. Runtime comparisons below use source snapshots that match the ASC build numbers, which verifies the repository state but not archive-only signing or packaging differences.
- No production RevenueCat key was used. Purchase and live-subscription states were not validated.

## Findings

### R93-01: Existing check-ins are demoted to unlogged after upgrade

Severity: P1, high confidence, runtime verified

Affected users: existing users upgrading from build 83 to build 87.

Evidence:

- Build 87 adds `DailyCheckIn.wasLogged`, with a default of `false` for the lightweight migration (`Shared/Models/DailyCheckIn.swift:10-17`).
- Build 87 now uses that field to decide whether Home is checked in (`Shared/Services/CheckInService.swift:36-41`) and to render a solid or faint calendar day (`Sober/Features/Calendar/TimelineView.swift:222-243`).
- There is no migration that marks legacy rows created by build 83 as logged.
- With the same seeded App Group data, build 83 displayed `Today is logged` at 27 days sober. Build 87 displayed `Check in for today` while retaining the same 27-day counter and garden. Historical rows are also treated as assumed rather than tended.

Impact: upgrading changes the apparent status of the user's existing record, can prompt a duplicate check-in for a day already logged, and makes prior history appear faint or incomplete. This is a core trust regression on first launch after an upgrade.

Expected: preserve the meaning of legacy check-in rows during migration, or run a one-time migration that maps pre-`wasLogged` rows to the prior logged behavior.

### R93-02: “Still sober” does not promote the missed days it claims to cover

Severity: P1, high confidence, source verified

Affected users: users returning after more than one day without opening the app.

Reproduction:

1. Start with a journey spanning several days and do not open the app for at least two days.
2. Open Home. `fillJourney` creates assumed rows through yesterday with `wasLogged = false` (`Sober/Features/Today/HomeView.swift:120-129`, `Shared/Services/CheckInService.swift:79-99`).
3. Tap `Still sober`.

`backfillSoberDays` starts after `lastCheckInDate()` (`Shared/Services/CheckInService.swift:102-123`). Since the Home backfill has already created a row through yesterday, the action inserts only today. The existing assumed rows are never promoted to logged. `TendedWeek` and the calendar therefore continue to show the gap as untended.

Impact: the primary re-engagement action says the user confirmed the whole span, but the week strip and calendar still communicate that most of the span was not tended. The passing unit suite does not cover this Home backfill sequence.

Expected: when the user confirms `Still sober`, promote the existing assumed sober rows in the covered range and mark today logged.

### R93-03: Retroactive slip logging uses the current streak instead of the selected day

Severity: P1, high confidence, source verified

Affected users: users logging a slip for a prior date.

`SlipSheet` allows a past date but calculates its carryover preview from `currentStreakDays`, regardless of the selected date (`Sober/Features/Craving/SlipSheet.swift:25-35`, `57-78`). `SlipRecorder` repeats the same mistake: it reads `currentDayCount()` before using the selected slip date (`Shared/Services/SlipRecorder.swift:26-45`).

Reproduction: with a 27-day current run, choose a slip from 10 days ago. The preview, confirmation, and garden carryover calculation all treat it as a slip after a 27-day run. The new journey starts the day after the selected date, so the reset date and the claimed previous streak describe different timelines.

Impact: a backdated slip can grant too much inherited garden growth and displays a misleading confirmation. It also makes the result dependent on when the user enters the history rather than on the date of the event.

Expected: calculate the streak and tree age as of the selected slip date, then derive carryover and the new journey from that same as-of date.

### R93-04: “I gave in” exits without logging a sobriety slip or offering the slip flow

Severity: P1, high confidence, source verified

Affected users: users who finish Craving Mode by choosing `I gave in`.

The button is presented as an explicit outcome (`Sober/Features/Craving/CravingModeView.swift:255-271`). `finish` records only a `CravingEpisode`, calls the parent callback, and dismisses for `.gaveIn` (`Sober/Features/Craving/CravingModeView.swift:340-354`). Home refreshes state but immediately returns for every outcome other than `.rodeItOut` (`Sober/Features/Today/HomeView.swift:533-549`). No `SlipRecorder` call or follow-up prompt is made.

Impact: after the user says they gave in, the sobriety counter and daily record remain unchanged. The app can therefore leave a user looking at a false-looking sober state, with no obvious way forward from the moment they disclosed the slip.

Expected: route this outcome to the existing slip flow, or clearly explain that the craving outcome is separate and provide an immediate `Log a slip` action.

### R93-05: Slip carryover is inconsistent between Home, Timeline, and tree customization

Severity: P2, high confidence, source verified

Home draws the tree using the current streak plus `GardenState.carryoverDays` (`Sober/Features/Today/HomeView.swift:47-55`, `261-269`). After a slip, Timeline reconstructs the selected tree from the raw streak only (`Sober/Features/Calendar/TimelineView.swift:251-275`), and Garden Customization previews the raw streak only (`Sober/Features/Garden/GardenCustomizationView.swift:17-22`, `56-63`).

Impact: after a slip, the same user can see the inherited mature tree on Home, then a seed or day-one tree in Timeline or in the customization screen. This contradicts the slip promise that the tree keeps its growth and makes the garden appear to lose progress when navigating.

Expected: use one carryover-aware, date-aware tree-age calculation across Home, Timeline, widgets, and previews.

### R93-06: Lifetime metrics say “logged” but include app-assumed days

Severity: P2, medium-to-high confidence, source verified

Build 87 introduces an explicit distinction between tended and assumed days, but `lifetimeSoberDayCount()` still counts every `wasSober` row and ignores `wasLogged` (`Shared/Services/CheckInService.swift:126-133`). Home and the slip confirmation describe the result as sober days the user has logged (`Sober/Features/Today/HomeView.swift:247-252`, `884-897`; `Sober/Features/Craving/SlipSheet.swift:71-78`). The test suite also codifies counting auto-filled rows (`SoberTests/TendedWeekTests.swift:146-150`).

Impact: a user who never confirmed a missed span can be told that those days were logged, and money or calorie totals based on the lifetime count can be presented with stronger ownership language than the data supports. This is especially confusing alongside the new faint, assumed-day calendar treatment.

Expected: either count only `wasLogged` rows for metrics described as logged, or change the copy to say sober days counted by the app and explain the distinction.

### R93-07: Repeated same-day slips can shrink carryover repeatedly

Severity: P2, high confidence, source verified

The Home menu continues to offer `I slipped` after a slip (`Sober/Features/Today/HomeView.swift:93-102`). Each submission calls `SlipRecorder.record`, which recomputes carryover from the current streak plus existing carryover and applies the 50% reduction again (`Shared/Services/SlipRecorder.swift:26-45`, `Shared/Services/GardenService.swift:168-178`).

Reproduction: log a slip after a 27-day run, then open the slip flow again on the same day and submit a second slip. The first carryover is about 13 days. The second calculation uses the restarted day-one streak plus that carryover and reduces it to about 7 days.

Impact: duplicate taps or repeated logging of the same event can silently erode the inherited garden. The data record is overwritten for the day while the garden mutation is applied again.

Expected: make same-day slip recording idempotent, or warn that today already has a slip and offer edit rather than applying the carryover rule again.

### R93-08: Patterns can show a peak window from an uninformative sample and then stop explaining the unlock

Severity: P2, medium confidence, source verified

`peakWindow` requires four craving records, but its guard allows a three-hour window containing all four records (`Shared/Services/CravingInsights.swift:68-82`). The surrounding comment says that an all-record window should return no insight. Separately, `nextUnlock` checks only total craving count, not whether the records are resolved or tagged (`Shared/Services/CravingInsights.swift:232-242`).

Impact: four urges clustered in one short period can produce a confident-sounding “Hardest between” pattern even though there is no time preference to compare. Four abandoned or unresolved sessions can also make the Patterns screen stop showing the “more data” explanation while the meaningful insights remain empty.

Expected: require the peak window to contain fewer than all records, and base unlock messaging on the sample needed for the specific insight being presented.

## Checks that did not produce a new regression

- Both source snapshots built successfully for the iOS simulator. Build 87 launched and the new Home layout fit the tested iPhone 17e viewport.
- The existing floating tab bar overlap on lower Timeline and Health content was visible in build 83 as well, so it was not counted as an 83 to 87 regression.
- No crash or diagnostic-signature comparison was possible from ASC because no usable diagnostic data was available.

No application source, project, or configuration files were changed for this audit. This report is the only task-owned artifact.
