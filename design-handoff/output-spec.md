# Output spec

How to deliver. Drop everything under `design-handoff/output/`.

## Folder layout (final state)

```
design-handoff/output/
├── bonsai/                       ← brief 01 — THE PITCH
│   ├── traditional/  *.svg
│   ├── cascade/      *.svg
│   ├── windswept/    *.svg
│   ├── growth-schedule.json      ← required: per-day parameter table
│   └── contact-sheet-*.png       ← review aid
├── items/                        ← brief 02
│   ├── item-{id}.svg
│   └── items-sheet@3x.png
├── app-icon/                     ← brief 03
│   ├── icon-1024-light.png
│   ├── icon-1024-dark.png
│   └── icon-1024-tinted.png
├── paywall/                      ← brief 04
│   └── paywall-hero@{1,2,3}x.png
├── onboarding/                   ← brief 05
│   └── onboard-{01,02,03}-*.svg
├── health-icons/                 ← brief 06
│   └── health-{id}.svg
└── empty-states/                 ← brief 07
    └── empty-{screen}.svg
```

## Vector requirements (all SVGs)

- **Transparent background.**
- **No baked-in shadows.** We add them in SwiftUI when needed.
- Inline styles only (no external CSS).
- Use named groups for animated elements: `<g id="glow">`, `<g id="leaves">`, `<g id="trunk">`. Naming follows the brief.
- No raster images embedded.
- One paths-per-color rule: separate paths/groups by fill color so the engineer can re-color or animate per layer.
- Strokes that need to scale: use `vector-effect="non-scaling-stroke"` where applicable. (Don't use it on the bonsai trunk — we want that to scale.)

## Color tokens

When a color in your design maps to a brand token (see `reference/theme-palette.json`), use that exact RGB value. The engineer will sometimes substitute the token at runtime (e.g. for dark mode) so consistency matters.

## File naming

- All lowercase, dash-separated.
- Use the exact IDs from the reference JSONs (`item-koi-pond.svg`, not `item-koi_pond.svg`).
- Bonsai anchor day: zero-padded 3 digits (`bonsai-traditional-d047.svg`).

## Review process

1. Designer pushes a batch to `output/`.
2. Engineer (or me) opens the contact sheets first.
3. Comments left in `output/REVIEW-NOTES.md` (designer creates it on first delivery).
4. Iterate.

## Per-brief priority for delivery

| Brief | Priority | Notes                                |
|-------|----------|--------------------------------------|
| 01 — Bonsai daily growth | P0 — blocks v1 launch | Highest quality bar. Iterate. |
| 02 — Garden items        | P1                    | Can land 2 weeks after 01.    |
| 03 — App icon            | P1                    | Needed for TestFlight polish. |
| 04 — Paywall hero        | P2                    | Can launch with placeholder.  |
| 05 — Onboarding          | P3                    | Defer if needed.              |
| 06 — Health icons        | P3                    | SF Symbols ship-acceptable.   |
| 07 — Empty states        | P3                    | Text-only ship-acceptable.    |
