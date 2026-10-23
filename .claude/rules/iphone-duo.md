---
paths:
  - "Sober/App.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/Features/Calendar/TimelineView.swift"
  - "SoberTests/UnfoldedSplitTests.swift"
---

# Sober: iPhone Duo (2026-10-22, bars and pane fixed 2026-10-23)

- Unfolded (regular width, at least 720 pt), `MainTabView` frames the tab view
  (Home, Health, Journal, Bloom+ and the tab bar) on the leading side of the
  fold and Timeline on the trailing side. The Timeline tab leaves the bar while
  split; a `-tab 1` or a tap that lands there while split goes to Home.
  Fold edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split. Every compact width and the
  unfolded Duo held in portrait (669 pt) keep the single column.
- The Timeline pane is built the first time the Duo unfolds and stays mounted, so
  folding only moves frames and the pane keeps its selected day. Ordinary
  iPhones never build it. `TimelineView(isPane: true)` skips the appear nudge
  (on screen from launch, it would pitch every cold start), uses an inline
  title, shows the selected day's tree as a thumbnail beside its caption and
  growth note, and moves the current/longest/total summary below the
  check-in. The full-size 200 pt tree card started below the 669 pt viewport
  and read as an empty sky box.
- Each pane gets `horizontalSizeClass = .compact`, so it lays out as on a phone.
- One navigation on every tab: split, each tab applies `.leadingPaneTab`, i.e.
  `toolbarVerticalBehavior(.disabled)` plus `clearsFloatingTabBar`. Without
  the first, iOS 27.1 put the toolbar and tab bar in a vertical rail on tabs
  with toolbar items (Home, Journal) and a bottom bar on the rest. The second
  masks tab content out above the floating bar (eased fade, `TabBarClearance`,
  tested) and adds a bottom `contentMargins` so the last row scrolls clear
  (`safeAreaPadding` outside a tab's NavigationStack never reached its scroll
  views or Home's GeometryReader); the bar sits on the cream page. The mask
  stays folded (fully open) so folding never rebuilds a tab. The Timeline pane
  gets the same fade above the home indicator, so no row is sliced at the
  screen edge. Home reads `\.isUnfoldedPane` and sizes its top block to end
  above the fade, with a lower garden floor.
- Captures: one `gh-sim all --device 'iPhone Duo'` run with
  `--args "-seedDemo -seedDays 127 -seedGoal 365 -demoPro"` and one
  `--screen "-tab N"` per surface (0 Home, 2 Health, 3 Journal, 4 Bloom+).
  No `--url`: `simctl openurl` raises a confirm alert. The seed processes
  achievement unlocks, so a run that opens on Bloom+ shows earned badges.
  `-tourTab N` switches tab nine seconds in, for a recording with motion.
  Leave `--record-seconds` off `gh-sim all`: its test-phase recorder never
  finalizes and then blocks the launch recorders. Record with a separate
  `gh-sim launch --record-seconds 20`.
- Not yet split-aware: sheets (Progress, Customize garden, trial pitch) and the
  craving cover present at regular width across the whole inner display.
