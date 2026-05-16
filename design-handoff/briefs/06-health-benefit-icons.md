# Brief 06 — Health benefit icons

13 small icons, one per NIAAA milestone in our health-benefit timeline (`Shared/Catalogs/HealthBenefitCatalog.swift`).

## Why

Today the timeline uses generic SF Symbols. Custom icons would make the Pro feature feel premium.

## Spec

- **Canvas:** 120×120 SVG.
- **Style:** line + accent fill. Single accent color from palette (`brandPrimary` for unlocked, `textTertiary` opacity 0.4 for locked). Designer can specify exact treatment.
- Must work at 24×24pt (timeline row icon).

## Milestones to depict

(Designer should pull the canonical list from `Shared/Catalogs/HealthBenefitCatalog.swift`. The IDs below are the file names to use.)

- `blood-alcohol-clearing` (6h) — droplet clearing
- `improved-sleep` (24h) — moon + zZ
- `liver-recovery-starts` (72h) — abstract organ + green tick
- `hydration-restored` (1w) — water glass
- `mood-stabilizing` (2w) — wave settling
- `liver-fat-reduces` (1mo)
- `bp-improves` (1mo)
- `skin-clearer` (1mo)
- `weight-loss` (3mo)
- `cancer-risk-drops` (6mo)
- `liver-significantly-recovered` (1y)
- `cardiovascular-restored` (1y)
- `cognitive-improvement` (1y)

(Verify the exact list against the catalog — designer should treat the code as the source of truth.)

## Output

```
output/health-icons/
├── health-blood-alcohol-clearing.svg
├── health-improved-sleep.svg
└── … (one per milestone)
```

## Priority

Low. Ship v1 with SF Symbols; revisit for v1.1.
