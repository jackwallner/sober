# Current State

What exists in the codebase **today** (2026-05-15), with file references. Read this before designing — your work replaces or supplements specific things here.

## Garden — implemented in code

The garden centerpiece is a hand-drawn SwiftUI illustration made from primitives (capsules, circles, paths). It's functional but flat.

- `Sober/Features/Garden/BonsaiView.swift` — three styles × nine stages, all SwiftUI shapes.
- `Sober/Features/Garden/GardenItemRenderer.swift` — 11 garden items (bamboo, lotus, lantern, koi pond, pagoda, etc.) all rendered as primitive shapes.
- `Sober/Features/Garden/GardenSceneView.swift` — composes the scene (sky + bonsai + placed items + ground).
- `Shared/Models/GardenItem.swift` — data model and catalog of all unlockable items.
- `Shared/Services/GardenService.swift` — `BonsaiStage` enum (seed → legendary) and progression logic.

**Status:** Compiles and renders. Looks like programmer art. **Replace with real illustration.**

To preview locally:
```bash
xcodegen generate
open Sober.xcodeproj
# Cmd+1 to canvas, open BonsaiView.swift, hit resume on the Preview.
```

## Bonsai stages (9)

| Index | Stage         | Day threshold |
|-------|---------------|---------------|
| 0     | Seed          | 0             |
| 1     | Sprout        | 3             |
| 2     | Seedling      | 7             |
| 3     | Young Bonsai  | 14            |
| 4     | Adolescent    | 30            |
| 5     | Mature        | 60            |
| 6     | Refined       | 90            |
| 7     | Ancient       | 180           |
| 8     | Legendary     | 365           |

JSON: `reference/bonsai-stage-spec.json`.

## Bonsai styles (3)

- **Traditional** — symmetric, upright, balanced. Default.
- **Cascade** — leans/falls to one side, mimicking a cliff tree.
- **Windswept** — leaning, all foliage on one side, shaped by wind.

## Garden items (14, including 3 bonsai styles)

Full machine-readable list at `reference/garden-item-catalog.json`. Highlights:
- Day 3: Moss Ground (free taste)
- Day 7: River Stone
- Day 10: Bamboo
- Day 14: Stone Lantern
- Day 21: White Lotus
- Day 30: Cascading Bonsai
- Day 45: Zen Sand Garden
- Day 60: Koi Pond
- Day 90: Miniature Pine
- Day 120: Moon Gate
- Day 180: Meditation Pagoda
- Day 270: Wind Chime
- Day 365: Windswept Bonsai

## What's NOT implemented yet

- App icon refinement (current asset is a stand-in).
- Paywall hero art (`Sober/Features/Paywall/PaywallView.swift` uses RevenueCat's default UI).
- Onboarding illustrations (`Sober/Features/Onboarding/`).
- Health benefit illustrations (timeline uses SF Symbols today).
- Empty-state art for Journal, Calendar, etc.

## How the garden gets rendered (so your art slots in cleanly)

`GardenSceneView` composes layers in this order from back to front:
1. Sky gradient (built-in).
2. Background **features** (pagoda, moon gate) — top corners, ~28-35% from top.
3. Ground texture (moss, zen sand, or default dirt).
4. **Bonsai centerpiece** — center, occupies ~35% width × 45% height. Stage-dependent vertical position.
5. **Plants** flanking the bonsai (bamboo, lotus, pine).
6. **Decorations** in corners (river stone, lantern, wind chime).
7. **Foreground features** (koi pond, bottom-center).
8. Stage badge (top-right HUD).

Your SVGs should have transparent backgrounds and be designed to composite at those positions.
