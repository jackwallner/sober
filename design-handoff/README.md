# Sober — Design Handoff

> **For Claude Design (or a human designer):** read this folder top-to-bottom. Start with `BRAND.md` and `CURRENT-STATE.md`, then work through `briefs/` in numeric order. Drop your output in `output/` following `output-spec.md`.

## What Sober is

iOS + watchOS app helping people track sobriety. v1 is **alcohol-specific**. The hook is a **virtual bonsai garden** that grows as the user accumulates sober days. Freemium with RevenueCat (`pro` entitlement).

- **Free**: day counter, daily check-in, calendar, basic bonsai garden, first 2 health benefits.
- **Pro**: full health timeline, journal compose, achievements, money/calories saved, garden customization (extra bonsai styles, decorations, plants, features).

The garden is the emotional core. **Most of the design asks below are about the garden.** Everything else can ride on iOS defaults until v1.5.

## What's in this folder

```
design-handoff/
├── README.md                 ← you are here
├── BRAND.md                  voice, palette, tone, type
├── CURRENT-STATE.md          what exists today (with file refs); what doesn't
├── briefs/                   one brief per asset family — read in order
│   ├── 01-bonsai-stages.md       ⭐ highest-leverage
│   ├── 02-garden-items.md        ⭐ next
│   ├── 03-app-icon.md
│   ├── 04-paywall-hero.md
│   ├── 05-onboarding-illustrations.md
│   ├── 06-health-benefit-icons.md
│   └── 07-empty-states.md
├── reference/
│   ├── theme-palette.json         colors / radii / spacing
│   ├── garden-item-catalog.json  every unlockable item + milestone days
│   └── bonsai-stage-spec.json    stages, day thresholds
└── output-spec.md            how to deliver (file format, naming, sizing)
```

## Priority order

1. **Bonsai with daily growth** (`briefs/01`) ⭐⭐⭐ — **THE PITCH.** A bonsai that visibly changes every single day for 365 days, in three styles. This is the App Store screenshot, the reason people download, the reason they keep opening. Treat it like the entire product's surface area. Plan for multiple review rounds.
2. **Garden items** (`briefs/02`) — 14 unlockable items the user earns as milestones.
3. **App icon** (`briefs/03`) — current one is a placeholder.
4. **Paywall hero** (`briefs/04`) — drives conversion.
5–7 are nice-to-have for v1.

## Output format we need

SVG paths (or layered SVGs with named groups) are ideal because we render in SwiftUI and can convert them to native `Path`/`Shape` for crisp scaling. PNG at 3× is the fallback. See `output-spec.md`.

## Constraints

- iOS 17 minimum. SwiftUI only (no UIKit views).
- All garden art must read at **80×80pt** (Today screen thumb) AND **300×300pt** (full scene). One source, two scales.
- Dark mode required for everything except the garden scene itself (it has its own sky/ground).
- No copyrighted Japanese garden references — we want "evocative of," not "trademarked from."
