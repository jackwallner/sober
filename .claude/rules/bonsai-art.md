---
paths:
  - "Shared/Bonsai/**"
  - "Tools/BonsaiAudit/**"
---

# Bonsai art (added 2026-10-23)

The trees are drawn in code (`Shared/Bonsai/`), identical in Sober and Quit Zyn:
copy changes across both repos. `BonsaiPaint.swift` holds the shared look; the
renderer only decides geometry and when each part appears.

- Growth is a pure function of the day. Art changes must keep each limb, pad
  and tuft appearing on the same day at the same place; restyle how they are
  painted, not when.
- Nothing pops. In the classic styles a new pad or limb buds at 30% on its
  day and fills out over three weeks (`budding`); its attach point rides the
  limb end, so it never floats. The day-8 trunk takes over from the day-7
  sprout (`girth`, `swing`, `drawSeedLeaves`), and the cascade's fall grows
  out over the rim, never across the pot face. Zoom boxes grow upward only,
  so the pot never shifts. Check with a full 0 to 365 render: no day may
  change more than about 6% of the frame from the day before.
- Each tree is recorded once per (style, day, detail) into a `BonsaiScene`
  (`BonsaiScene.swift`, LRU `BonsaiSceneCache`) and replayed every frame; the
  wind only bends, drifts and stretches recorded pieces (`BonsaiMotion`).
  Painters write into `BonsaiLayers`, never a GraphicsContext. Avoid clips and
  path booleans in painters where a nested outline will do: both cost far more
  than a fill.
- The cascade is one kengai trunk: it rises, arches out over the left rim and
  falls past the pot's foot, with small pads alternating down the fall. Its
  pads are scaled down (`pick` in `paramsForDay`) so the fall stays readable.
- Maple pads are `paintPalmatePad` (a heap of palmate leaves), pine pads
  `paintNeedlePad` (needle-fringed tiers with raked needles); `padDetail`
  scales their texture with on-screen size.
- Classic foliage is `paintPad`: opaque layers (dark lobed outline, mid body lifted off
  its underside, lit crown, a few flecks). Never fake depth or a dry garden with
  alpha: overlapping pads go muddy and a low-vitality tree turns see-through.
  Vitality dulls colour through `RGB.dried`.
- Wood is a filled ribbon (`woodRibbon`, `boughPath`) plus `shadeWood`, never a
  stroked line: limbs must taper into the trunk. Trunks get `nebariPath` root
  flare and are clipped at the soil line (except the cascade, which spills over
  the rim).
- Light comes from the upper left everywhere.
- Proof: render with `Tools/BonsaiAudit` (`--mode=render` for contact sheets,
  `--wind=<ms>` for a sway frame, `--mode=bench` for per-frame cost, the
  default sweep for detached or clipped pieces, `--mode=bbox` for the
  fill-mode zoom box). Its `Sources/` symlinks every `Shared/Bonsai` file; add a
  link when you add a file there.
