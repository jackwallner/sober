---
paths:
  - "Shared/Services/JanuaryChallenge.swift"
  - "Sober/Features/Challenge/**"
  - "SoberUITests/JanuaryChallengeUITests.swift"
---

# Sober: Dry January 2027 challenge (added 2026-11-18)

The real, dated thing behind the App Store in-app event "Dry January 2027" (January 1
to 31, 2027; App Review 2.3.13 wants an event to be timely and its link to land
on it). Event spec, art and state: `~/ios/growth/2026-11-18-listing-strategy/january-events/`.

- `JanuaryChallenge` (Shared) is pure date math over the January check-ins:
  each day is dry, slip, open or ahead. A slip never erases the other days.
- Timeline shows the row (top section, above the streak stats) from December 18, 2026 (the day the App Store starts
  promoting the event) to February 7, 2027. The sheet shows the count, the
  month and the badge. Nothing in it is paid.
- `sober://dry-january` opens the sheet (`RootView.onOpenURL` sets
  `ChallengeLinkInbox.shared.pending` and switches to Timeline (unfolded, the
  Timeline pane is already on screen), which consumes it, so a cold launch and
  onboarding both work). From February 8, 2027 the link just opens Timeline. The
  URL scheme `sober` is in `Sober/Info.plist`; keep it while the event is
  approved or published.
- The badge `dry-january-2027` is `AchievementCatalog.dryJanuary`, kept out of `all`,
  earned by `AchievementService` once January 31 has come and all 31 days are
  dry. It is never locked behind the paywall.
- DEBUG launch args: `-challengeNow 2027-01-12` sets the date the challenge
  reads, `-openChallenge` does what the link does (`simctl openurl` stops on a
  confirmation alert). UI tests run under the `SoberUITests` scheme:
  `gh-sim test --scheme SoberUITests --only SoberUITests/JanuaryChallengeUITests`.
- After February 2027 the code can be removed, or re-dated for the next
  January: change `year`, the achievement id and the four catalog keys.

- Moved off Home on 2026-11-19 (Jack): Home stays as it was, the challenge
  extends the month view it belongs to. All dates use `JanuaryChallenge.calendar`
  (Gregorian, device time zone): on a Buddhist or Islamic device calendar
  `Calendar.current` read 2027 as its own year and hid the challenge. Timeline
  opens on `JanuaryChallenge.clock()`, so a `-challengeNow` capture shows
  January; its grid still greys days after the real today in a capture.
- The app fills unlogged past days as sober (`fillJourney`), so the challenge
  counts dry days, not daily check-ins: copy says "every dry day", never
  "check in each day".
- Timeline fills unlogged past days itself (`refreshChallengeDays`, the same
  `fillJourney` Home runs) on appear and when the link arrives: the event link
  lands on Timeline, often before Home has appeared that launch, and the count
  read short until it did.
