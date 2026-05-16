# Brief 03 — App icon

Current icon is a stand-in. Replace with a final design.

## Concept direction (pick one, or propose)

1. **A single bonsai silhouette** on the brand gradient, dead-center. Calmest.
2. **A leaf** (single, slightly curled) on the gradient. Most abstract.
3. **A koi pond stone with ripples** — most metaphorical (every day is a stone).

Recommendation: option 1, but designer's judgment trumps this.

## Specs (Apple)

- 1024×1024 master PNG (sRGB, no alpha for the App Store icon).
- Single source — Xcode generates the other sizes from the asset catalog single-image slot.
- Light AND dark + tinted variants (iOS 18+). Three masters total.

## Constraints

- No text in the icon.
- No iOS UI chrome inside the icon.
- Must read at 60×60pt (home screen) and 29×29pt (settings).
- Stay inside Apple's safe area — keep critical detail within 80% of the canvas.

## Output

```
output/app-icon/
├── icon-1024-light.png
├── icon-1024-dark.png
├── icon-1024-tinted.png
└── source.svg    (or .sketch / .fig — your master)
```
