---
paths:
  - "Sober/App.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/Features/Calendar/TimelineView.swift"
---

# Sober: iPhone Duo (2026-10-22)

- Unfolded (regular width, at least 720 pt), `MainTabView` frames the tab view
  (Home, Health, Journal, Bloom+ and the tab bar) on the leading side of the
  fold and Timeline on the trailing side. The Timeline tab leaves the bar while
  split; a `-tab 1` or a tap that lands there while split goes to Home.
  Fold edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split. Every compact width and the
  unfolded Duo held in portrait (669 pt) keep the single column.
- The Timeline pane is built the first time the Duo unfolds and stays mounted, so
  folding only moves frames and the pane keeps its selected day. Ordinary
  iPhones never build it. It passes `nudgesOnAppear: false`: it is on screen from
  launch, so its appear nudge would pitch every cold start.
- Each pane gets `horizontalSizeClass = .compact`, so it lays out as on a phone.
- Captures: `gh-sim launch --device 'iPhone Duo'` with
  `-seedDemo -seedDays 127 -seedGoal 365 -demoPro -tab N` (one inner surface per
  job; `simctl openurl` raises a confirm alert, so there are no URL routes).
  `-tourTab N` switches tab nine seconds in, for a recording with motion.
