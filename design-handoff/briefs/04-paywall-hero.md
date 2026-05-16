# Brief 04 — Paywall hero

One hero illustration that sits at the top of the Pro upsell screen and on the in-app paywall.

## What it communicates

"What your garden could be." The user already has a sapling; this image shows the **fully grown garden** they're working toward — pagoda, koi pond, mature bonsai, lanterns, the works.

It is **aspirational, not transactional**. No price tags, no crowns, no "PRO" stamps.

## Spec

- **Canvas:** 1170×900 (3× of 390×300 — sized for paywall hero region on all current iPhones).
- **Composition:** wide landscape garden scene. Mature/legendary bonsai centered, surrounded by lit lanterns, koi pond in foreground, pagoda mid-distance, moon gate in the distance.
- **Lighting:** golden hour / soft evening — warm sand light spilling across the scene. Lanterns lit.
- **Mood:** earned peace.

## Constraints

- Must work behind a translucent title overlay (top 30% of image will have ~40% black overlay + white text).
- Composition should leave the **upper third visually quiet** (sky/distance) so text reads.
- No human figures.

## Output

```
output/paywall/
├── paywall-hero@1x.png   (390×300)
├── paywall-hero@2x.png   (780×600)
├── paywall-hero@3x.png   (1170×900)
└── source.svg            (master, vector if possible)
```
