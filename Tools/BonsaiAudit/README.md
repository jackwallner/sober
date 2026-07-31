# BonsaiAudit

Headless silhouette audit for `Shared/Bonsai/BonsaiRenderer.swift`.

The trees are drawn procedurally in a SwiftUI `Canvas` — there are no image
assets — so "the tree looks broken" is always a geometry bug. This tool renders
the real shipping `BonsaiView` off-screen for every (style, day, render size)
and measures the result, instead of relying on someone spotting a bad frame.

The renderer files are symlinked into `Sources/`, so the audit always runs
against the current working copy.

```bash
cd Tools/BonsaiAudit
swift build -c release

# Full sweep: 6 styles x 366 days x 6 configs (~7 min)
./.build/release/BonsaiAudit --stride=1 --out=/tmp/audit

# Quick pass while iterating (~25s)
./.build/release/BonsaiAudit --stride=5 --style=traditional --out=/tmp/audit

# Zoom-box check: declared content rect vs. ink actually painted
./.build/release/BonsaiAudit --mode=bbox --stride=5 --out=/tmp/audit
```

Writes `report.csv` (per-frame numbers), `flags.md` (day ranges per style), and
an annotated PNG per flagged frame — magenta = detached piece, orange =
enclosed background pocket.

## What it detects

| check | meaning |
|---|---|
| **detached** | a structural piece (≥400pt²) not connected to the main silhouette, with the gap measured in design pt via a chamfer distance transform. This is the "floating foliage" bug. |
| **hole** | background fully enclosed by ink. Often legitimate (sky under a cascade's bend), so read these with the annotated PNG. |
| **hairline** | a join that breaks when the mask is eroded by 1/2/3pt. A neck thinner than ~13 design pt is not reliably visible on the watch, where 600pt of design space lands in ~44pt. |
| **clipped** | ink running off the frame edge, i.e. `bonsaiContentRect` under-reports and `fill: true` crops the tree. The bottom edge is exempt — fill mode bottom-anchors the pot on purpose. |
| **pop** | day-over-day jump in area or centroid. The day 7 → 8 handoff from the bespoke sprout to the trunk pipeline shows up here by design. |
| **alpha-sensitive** | a piece that is connected at alpha cut 40 but detached at 128, i.e. it only joins via a nearly transparent overlap. |

## Configs

Mirrors the real call sites, because a gap that is invisible in the 600pt design
square is magnified by the `fill: true` zoom on the home centerpiece:
`design600`, `home320`, `home320-dry` (vitality 0.3, the floor `GardenService`
decays to), `grove44`, `collect90`, `timeline200`.

## Known, accepted findings

- **cascade holes, days 8–105** — the V between the riser and the fall, closed
  at the bottom by the pot rim. Anatomically correct, not a defect.
- **maple detached, days 11–12 at `home320` only** — a 1.2pt near-touch on the
  sapling that antialiasing bridges at every other zoom level.
- **hairline necks on young trunks** — young trunks really are thin. Worth a
  minimum-width floor on `tipW` if the watch/widget ever looks broken.
