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
- Each tree is recorded once per (style, day, detail) into a `BonsaiScene`
  (`BonsaiScene.swift`, LRU `BonsaiSceneCache`) and replayed every frame; the
  wind only bends, drifts and stretches recorded pieces (`BonsaiMotion`).
  Painters write into `BonsaiLayers`, never a GraphicsContext. Avoid clips and
  path booleans in painters where a nested outline will do: both cost far more
  than a fill.
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
