# Sober build 83 to build 88 regression audit

Date: 2026-09-04

## Scope

Compared the currently released App Store Connect build, version 1.3.0 (build 83), with the latest uploaded TestFlight build, version 1.3.1 (build 88).

Success criterion: identify reproducible regressions, data-integrity bugs, or material user-experience problems introduced or exposed in build 88, with enough evidence to act on them.

## Build identity

| Build | ASC state | Uploaded | Matching source |
|---|---|---|---|
| 1.3.0 (83) | Ready for Distribution | 2026-08-25 | `adbbdf9` (`chore(sober): bump build 82 -> 83`) |
| 1.3.1 (88) | TestFlight, Ready to Submit, Validated | 2026-09-04 | `b66630f` (`chore(sober): bump build 87 -> 88`) |

ASC app ID: `6768869215`. Both builds use bundle ID `com.jackwallner.sober`, minimum iOS 17.0, and the shared App Group `group.com.jackwallner.sober`.

## Method and limitations

- Queried ASC read-only for the live version, TestFlight build, processing, beta, crash, and screenshot-feedback metadata.
- Generated and built the exact build 83 source snapshot and the current build 88 source snapshot in the headless shared iOS simulator pool.
- Installed build 83 with seeded data, then installed build 88 over it without erasing the app data. This exercised the upgrade migration path.
- Ran the current shipped test suite: 126 tests passed, 0 failed, 0 skipped.
- Exercised the build 88 Home, craving, slip, Timeline, Progress, and StoreKit preview paywall flows on an iPhone 17 Pro simulator.
- Build 88 has 0 TestFlight installs, sessions, crashes, or screenshot feedback in ASC. Its What to Test field is empty and the internal group has two invited testers. The only ASC crash row is from build 0.1.0 (23), not either audited build.
- Runtime comparisons use source snapshots matching the ASC build numbers. The ASC archives were not downloaded, and no real TestFlight device install was available, so archive-only packaging and production-device behavior remain unverified.
- No production RevenueCat key was used. Paywall checks used the local StoreKit preview configuration.

## Findings

### R94-01: Backdated slips create overlapping journeys and corrupt later history

Severity: P1, high confidence, source verified

Affected users: users who enter a slip for a prior date, then view history or enter another slip.

`SlipRecorder` correctly scores the first backdated slip with `SobrietyService.dayCount(asOf:)`, but `resetJourney(startingAt:)` then ends the old journey at `.now` and starts the new journey on the day after the selected slip (`Shared/Services/SlipRecorder.swift:62-74`, `Shared/Services/SobrietyService.swift:50-62`). That leaves the old journey and the new journey covering the same dates. `dayCount(asOf:)` scans journeys oldest-first, and `longestStreakDays()` measures the old journey through its end date (`Shared/Services/SobrietyService.swift:80-117`).

Reproduction:

1. Start a journey 30 days ago.
2. Enter a slip dated 10 days ago.
3. The old journey ends today, while the new journey starts 9 days ago.

The old journey now reports roughly 31 days instead of ending at the 21-day pre-slip run. A later backdated slip inside the overlap resolves to the old journey and can be scored against that inflated run. Carryover, longest-streak summaries, widget snapshots, and later confirmations can therefore overstate the user's history.

The existing backdated-slip tests verify the first slip's as-of score and the new journey's current count, but do not verify non-overlapping journey boundaries or a second backdated event.

Expected: close the previous journey on the selected slip day, or otherwise model the event so journey intervals cannot overlap. Recompute as-of counts, longest streak, and carryover from those non-overlapping intervals.

### R94-02: Timeline "Change to sober" edits the row but does not undo the slip reset

Severity: P1, high confidence, runtime verified on build 88

Affected users: users who accidentally log a slip and then correct it from Timeline.

The Timeline action for an existing slip only calls `CheckInService.checkIn(for:wasSober:)` (`Sober/Features/Calendar/TimelineView.swift:365-371`, `458-466`). It does not restore the previous sobriety journey, clear slip carryover, or rebuild the widget snapshot from a sober state.

Runtime reproduction on the upgraded build 88 install:

1. From a seeded 28-day run, use Home > More > I slipped and confirm.
2. Home correctly changes to 1 day sober and says today is logged as a slip.
3. Open Timeline for today and tap Change to sober.
4. Timeline changes the row to Logged sober.
5. Return to Home. The counter remains at 1 day sober, the pre-slip journey is not restored, and the inherited tree state remains.

The user is therefore shown a green sober check-in beside a counter that still reflects a reset caused by the slip that the user just removed. This is a core record and undo inconsistency.

Expected: make the correction transactional, restoring or rebuilding the journey and garden state, or remove this correction affordance until it can reverse the complete slip operation.

### R94-03: Widget and watch rendering ignore slip carryover

Severity: P2, high confidence, source verified

Affected users: users with a slip who rely on the home-screen widget or Apple Watch companion.

`WidgetSnapshotPump` computes the carryover-aware tree age and stores its stage in `WidgetSnapshot.bonsaiStage` (`Shared/Services/WidgetSnapshotPump.swift:13-24`). The widget ignores that field and derives its stage from the current streak and new journey start date (`SoberWidgets/SoberWidgets.swift:12-19`, `64-72`). The watch does the same (`SoberWatch/SoberWatchApp.swift:19-31`, `68-76`).

After a slip, Home intentionally shows the inherited tree, while the widget and watch derive a day-one stage from the reset journey. The snapshot field that was added for the carryover behavior is therefore not used by either consumer. This contradicts the slip confirmation that the tree kept its growth and makes the same record look different across product surfaces.

Expected: render the carryover-aware tree stage and cycle progress in both consumers, or transport the tree day count directly in the snapshot and use it consistently.

### R94-04: Pattern charts mix unresolved sessions with resolved insights without explaining the distinction

Severity: P2, medium confidence, source and behavior reviewed

Affected users: users who start Craving Mode and close it before choosing an outcome.

Closing the breathing screen records a `CravingEpisode` with outcome `.unresolved` (`Sober/Features/Craving/CravingModeView.swift:105-110`, `Shared/Models/CravingEpisode.swift:4-14`). `PatternsView` passes every episode to `CravingInsights` (`Sober/Features/Patterns/PatternsView.swift:16-34`). Timing and weekday readings, the time-of-day chart, and weekly counts include unresolved episodes, while the ride-out rate, duration, and unlock calculation use only resolved episodes (`Shared/Services/CravingInsights.swift:47-64`, `68-119`, `153-206`, `244-254`).

This can show a time or weekday pattern based on sessions the user abandoned, while outcome-based cards still say there is not enough resolved data. The page copy talks about urges the user rode out and labels the total as logged, but does not tell the user that abandoned sessions feed some cards and not others. The behavior may be intentional, since a started urge is still useful timing data, but the distinction is not legible in the UI.

Expected: either use one consistent resolved-session population for all pattern claims, or label the timing views as started sessions and explain why unresolved sessions are included.

### R94-05: ASC 1.3.1 draft metadata does not match build 88's free and Bloom+ boundary

Severity: P2, high confidence, ASC and runtime verified

The ASC 1.3.1 draft description still lists “Money and calories saved” under `BLOOM+ (OPTIONAL)`. Build 88 makes the historical “Kept so far” money, calorie, and body-fat totals free, and gates only the “Your year ahead” projection (`Sober/Features/Today/HomeView.swift:902-945`, `Sober/Features/Paywall/BloomFeature.swift:5-8`, `35-52`).

This creates a release-listing expectation that conflicts with the actual TestFlight experience. The draft also does not explain the new craving mode, slip carryover, or personal-pattern feature, making it harder for invited testers to discover the changed behavior.

Expected: update the 1.3.1 description and What’s New text to match the build's actual entitlement boundary and new flows before submission.

## Checks that did not produce a new regression

- Build 83 and build 88 source snapshots both built successfully for the iOS simulator.
- Installing build 88 over the seeded build 83 data preserved the 28-day counter, the 7/7 tended week, and the existing garden. The legacy check-in migration behaved as intended.
- The new Home layout fit the tested iPhone 17 Pro viewport. The craving entry point opened a full-screen breathing session with no paywall, and the ride-out reflection completed successfully.
- The first slip flow kept the garden carryover, preserved the longest streak, and showed an honest restarted counter.
- The local paywall preview showed store-derived prices, trial and no-trial states, purchase disclosures, and the lifetime option without visible clipping on the tested viewport.
- The complete current test suite passed: 126 tests, 0 failures.

## Release recommendation

Hold build 88 until R94-01 and R94-02 are fixed and covered by regression tests. Before submission, install the next candidate through TestFlight on a real device and retest backdated slips, slip correction, widget/watch carryover, upgrade migration, and the full craving-to-slip path. Correct the ASC metadata and populate What to Test so the internal group exercises the changed surfaces.

No application source, project, or configuration files were changed for this audit. Only this report was added.
