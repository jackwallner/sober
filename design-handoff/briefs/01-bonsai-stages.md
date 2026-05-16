# Brief 01 — Bonsai growth ⭐⭐⭐ THE PITCH

> **This is the entire app's promise.** The bonsai is what gets put on the App Store screenshots. It's why someone downloads. It's why they open the app on day 47 even though "nothing important" happens that day. Every day must feel like it mattered.

## Goal

A bonsai that **visibly grows every single day for 365 days**, in three styles (Traditional, Cascade, Windswept). Day 12 must look different from day 11. Day 200 must feel meaningfully older than day 180.

This brief replaces the original "9 stages" idea — 9 stages is too coarse. Users feel cheated when they open the app on day 8 and it looks identical to day 7.

## Deliverable shape (read this section carefully)

We need **both**:

### Part A — Anchor illustrations (artist-drawn)
~30 hand-crafted keyframes per style, distributed non-uniformly to match human perception of growth (more keyframes early, fewer late):

| Day range  | Keyframes              | Why                              |
|------------|------------------------|----------------------------------|
| 0–7        | every day (8 frames)   | First week is highest engagement |
| 8–30       | every 3 days (~8)      | Visible weekly growth             |
| 31–90      | every 7 days (~9)      | Slowing but clear progress        |
| 91–180     | every 14 days (~7)     | Maturing                         |
| 181–365    | every 30 days (~6)     | Refinement, not size              |

Total per style ≈ **38 anchor frames**. × 3 styles = **114 anchor illustrations**.

### Part B — Growth parameter schedule (a single JSON/CSV)
For every day 0–365, a record of growth parameters that drive code-side interpolation between the anchors:

```json
{
  "day": 47,
  "trunkThickness": 0.62,      // 0..1 — how thick the trunk is
  "trunkHeight":    0.55,      // 0..1
  "canopyRadius":   0.48,      // 0..1
  "foliageClusters": 4,        // integer count
  "leafSaturation": 0.92,      // 0..1 — color richness
  "barkTexture":   0.18,       // 0..1 — gnarl/age cues
  "mossOnTrunk":   0.0,        // 0..1
  "exposedRoots":  0.0,        // 0..1
  "anchorBefore":  "day-45",
  "anchorAfter":   "day-49",
  "anchorBlend":   0.5         // 0..1 — where between anchors this day sits
}
```

This lets us:
- Render every day's bonsai by blending the two nearest anchors using the params.
- Animate **between days** smoothly (a check-in on day 30 → next-morning unlock to day 31 should feel alive).
- Make micro-changes (leaf saturation, moss creep) on days where no new keyframe exists.

The full schedule (one row per day, 366 rows) is **the centerpiece of this delivery**. Without it, daily-growth is impossible. With it, we can render any day in code.

## What "growth" means qualitatively

Not just "bigger." Real bonsai mature in stages:

- **Days 0–7**: sprout pushing through soil; first true leaves; tender stem.
- **Days 8–30**: trunk thickens, first branching, canopy starts to fill.
- **Days 31–90**: tree shape becomes characteristic of its style; secondary branches; full canopy.
- **Days 91–180**: trunk gains character — slight gnarl, subtle bark texture, color depth.
- **Days 181–365**: age/refinement cues — moss creeps up the trunk, exposed roots, a few leaves turn for seasonal interest, lichen, weather marks.

After day 365, the bonsai stops growing in size but **continues to gain character** — leave room for v2 to extend the schedule.

## Per-illustration spec (anchor frames)

- **Canvas:** 600×600 SVG, transparent background.
- **Safe area:** 64px padding (keep art inside a 472×472 box).
- **Pot baseline** at vertical position `y = 460` — **identical across every anchor of a style**. Critical for interpolation; the trunk must anchor cleanly.
- Cascade style: art may extend below `y=460` down to `y=560` (foliage cascades below the pot).

## Style differentiators (re-emphasized)

- **Traditional** — vertical trunk, balanced symmetrical-but-not-mirror canopy, slight S-curve.
- **Cascade** — trunk arcs from pot, foliage cascades **below** the pot baseline. Most dramatic silhouette.
- **Windswept** — trunk leans 15–25° from vertical, ALL foliage on the leeward side, exposed bare branches on the windward side. Sparse and dignified.

A style should be readable from the silhouette alone, by day 14.

## Naming convention

Anchor frames:
```
bonsai-traditional-d000.svg
bonsai-traditional-d001.svg
…
bonsai-traditional-d365.svg
bonsai-cascade-d000.svg
…
bonsai-windswept-d365.svg
```

Use the exact day number of the keyframe (zero-padded to 3 digits). The growth schedule references these filenames.

## Output bundle

```
output/bonsai/
├── traditional/
│   ├── bonsai-traditional-d000.svg
│   ├── bonsai-traditional-d001.svg
│   ├── … (~38 frames)
│   └── bonsai-traditional-d365.svg
├── cascade/
│   └── … (~38 frames)
├── windswept/
│   └── … (~38 frames)
├── growth-schedule.json          ← the 366-row schedule (Part B)
├── contact-sheet-traditional.png ← all anchors in a grid, for review
├── contact-sheet-cascade.png
└── contact-sheet-windswept.png
```

## Quality bar

This is what the App Store screenshots will show. Treat it like a children's-book-quality illustrated set, not an icon pack. We will iterate. Plan for **2–3 review rounds.**

If anchor density needs to be higher in places where the design demands it (e.g. the first 3 days each look very different from each other), use designer judgment — the table above is a minimum, not a ceiling.

## Tested-against checklist

- [ ] Open any two consecutive days in the schedule. They should look *visibly different.*
- [ ] Pot baseline `y=460` consistent across every anchor of the same style.
- [ ] Style readable from silhouette by day 14.
- [ ] Growth schedule covers every day 0–365 with no gaps.
- [ ] Every anchor referenced in the schedule exists as a file.
- [ ] No paths under 1.5px stroke at 600×600 (won't render at 80×80 thumb).
- [ ] Transparent background, no baked-in shadows.
- [ ] Style coherence: all three styles look like they belong in the same world.
