---
paths:
  - "Sober/App.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/Features/Calendar/TimelineView.swift"
  - "SoberTests/UnfoldedSplitTests.swift"
---

# Sober: iPhone Duo (2026-10-22, bars, pane and cut fixed 2026-10-23)

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
  (on screen from launch, it would pitch every cold start) and is a column of
  cards (`paneScroll`), not the phone's List: month, selected day (tree
  thumbnail beside its caption), streak summary, then the check-in. The List
  kept the landscape status bar's trailing inset (about 65 pt) all the way
  down, so the pane sat off-centre; the cards ignore the trailing safe area
  and a 100 pt header row keeps the calendar below the status bar (the
  pane has no top safe-area inset; the status bar runs about 100 pt down its
  top trailing corner). Day cells
  are 32 pt there so the first screen holds whole cards.
- Each pane gets `horizontalSizeClass = .compact`, so it lays out as on a phone.
- One navigation on every tab: split, each tab applies `.leadingPaneTab`, i.e.
  `toolbarVerticalBehavior(.disabled)` plus `clearsFloatingTabBar`. Without
  the first, iOS 27.1 put the toolbar and tab bar in a vertical rail on tabs
  with toolbar items (Home, Journal) and a bottom bar on the rest.
- `clearsFloatingTabBar` ends content a 12 pt gap above the bar (the Timeline
  pane: above the home indicator) and never slices a row there: rows tagged
  `.paneRow()` (cards, section headers with `keepWithNext`) or
  `.paneListRow()` (inset grouped rows, measured through their row
  background) report their frames, and `PaneCut` (tested) moves the mask up
  to the top of any row the line would cut, rounding the card's bottom
  corners when the cut falls between rows of one card. A fade replaced by
  this was rejected twice: it sliced rows and left a ghost gap. A bottom
  `contentMargins` lets the last row scroll up to the line (`safeAreaPadding`
  outside a tab's NavigationStack never reached its scroll views). Folded,
  the mask is fully open and no row reports. Home reads `\.isUnfoldedPane`
  and sizes its top block to end above the line, with a lower garden floor.
  A new card in a split tab needs the tag, or the line slices it.
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
