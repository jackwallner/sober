---
paths:
  - "Shared/Bonsai/**"
  - "Sober/Features/Garden/**"
---

# Garden motion (added 2026-10-23)

`BonsaiWind` (Shared/Bonsai/BonsaiWind.swift) gives the bonsai idle life: the
plant bends (a shear, base planted) about 1.3 degrees over its soil line, foliage trails the lean with
a lag that grows with distance from the pivot, and the sakura and maple
mid-air petals and leaves fall on seeded loops. Method: the rossark motion
skill (calm, small amplitudes, pivots, nothing teleports).

- A nil wind must draw exactly the still tree. Widgets, picker thumbnails,
  the collection grid, the growth celebration and Reduce Motion rely on it.
- Only `GardenSceneView` drives wind, through `WindClock`: 60 fps, paused
  off screen and outside `.active`, and resuming continues from the held pose.
- The pot and fallen petals or needles on the soil never move. Foliage offsets
  come from one smooth field (`drift`), so a branch tip and its blossom move
  together; sort draw order by the still position, never the moved one.
- The app has its own `TimelineView` (Calendar), so SwiftUI's is written
  `SwiftUI.TimelineView`.
- Proof: `~/fleet/ai/fleet-record60.py capture` on the Air sim; Reduce Motion
  must record zero motion frames.
