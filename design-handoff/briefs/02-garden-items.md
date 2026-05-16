# Brief 02 — Garden items

11 unlockable items (excluding the 3 bonsai styles, which are covered in brief 01).

Each item has one **placed state** (in scene) and one **locked state** (silhouette/lock overlay handled in code — you only need the placed state).

## Item list

Read the full catalog with descriptions/colors from `reference/garden-item-catalog.json`. Summary:

| ID              | Type        | Day | Notes                                            |
|-----------------|-------------|-----|--------------------------------------------------|
| `moss`          | ground      | 3   | Ground cover. Renders as a horizontal band.      |
| `river-stone`   | decoration  | 7   | Small. Tucked in corners.                        |
| `bamboo`        | plant       | 10  | 3 stalks of varying height.                      |
| `stone-lantern` | decoration  | 14  | Japanese Tōrō. Has a "fire window" that glows.   |
| `white-lotus`   | plant       | 21  | Single bloom + stem. Small.                      |
| `zen-garden`    | ground      | 45  | Raked sand + one feature stone.                  |
| `koi-pond`      | feature     | 60  | Bottom-center. Includes 2 koi fish.              |
| `miniature-pine`| plant       | 90  | Triangular foliage, dark green.                  |
| `moon-gate`     | feature     | 120 | Circular gate. Top-left of scene.                |
| `pagoda`        | feature     | 180 | 3-tier pagoda. Top-right of scene.               |
| `wind-chime`    | decoration  | 270 | Hanging tubes. Suggest gentle sway.              |

## Per-item spec

- **Canvas:** 300×300 SVG, transparent background.
- **Anchor:** items use a bottom-center anchor (the rendering code positions them by their bottom edge). Design with the base of the object at `y=290`.
- **Scale calibration:** the renderer assigns size buckets (small/medium/large). Just make sure your art **fills the canvas** — we scale uniformly.

## Style coherence with bonsai

Same flat-painterly treatment as the bonsai. Same palette. Items should feel like they belong in *the same garden* as the trees.

## "Glow" / "vitality" rule

Items that have a glowing element (stone lantern, koi pond water) need a clearly-named layer in the SVG so we can animate the glow tied to `vitality`:

- `<g id="glow">…</g>` — this layer's opacity we'll multiply by `0.4 + 0.4 * vitality` at runtime.

If your tool can't export named groups, deliver a **separate SVG** for the glow element: `stone-lantern-glow.svg`.

## Output

- 11 SVGs: `item-{id}.svg` (e.g. `item-koi-pond.svg`).
- Optional separate glow SVGs where applicable: `item-stone-lantern-glow.svg`, `item-koi-pond-water.svg`.
- One contact sheet PNG at 3× showing all 11 items: `items-sheet@3x.png`.

## Tested-against checklist

- [ ] All items use base at `y=290` (bottom-anchored).
- [ ] Glowing items have a separate or named-group glow layer.
- [ ] At 1× (each item rendered at ~30–60pt in the scene), all items remain distinguishable from each other.
- [ ] Ground items (moss, zen-garden) work as a repeating/wide band, not a single shape.
