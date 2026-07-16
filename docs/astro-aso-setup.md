# Astro ASO setup — Sober (US)

> **Repeat:** [Astro setup process](~/ios/aso/astro-setup-process.md) + **"go"**  
> **Re-score keywords:** `./scripts/astro-fetch-metrics.sh && python3 scripts/astro-curate-keywords.py`

Last optimized: **2026-06-23** — app is **LIVE**. Migrated Astro tracking from the temp pre-launch app `103` to the live App Store listing `6768869215`; merged the **58 curated** US terms onto it (now pulling real ranks, not pre-launch 1000s).

## App

| Field | Value |
|-------|-------|
| App Store name | Sober Tracker - Alcohol Free |
| **Astro tracked app (live)** | **`6768869215`** — listed as "Sober Tracker - Alcohol Free" |
| Astro pre-launch app (retired) | Temp **Sober** — ID `103` (kept for historical scores only) |
| App Store Connect ID | `6768869215` |
| Bundle ID | `com.jackwallner.sober` |
| Store | `us` |

> **Live-app note:** `scripts/.astro-app.json` `appId` now points at `6768869215`; all sync/fetch scripts target the live app. The old `103` is preserved as `preLaunchAppId`. First post-launch US ranks (2026-06-23): apple watch sober **#35**, dry days **#75**, alcohol diary **#119**, sober tracker **#149**, sober days **#200**, sober streak **#206**, alcohol free **#219**, sober app **#226**; remaining terms still indexing.

---

## Keyword strategy (popularity × difficulty)

Pre-launch Astro scores **search demand** (popularity) and **competition** (difficulty). Rank is 1000 until live; use this table to pick fights.

### Tier A — target first (high pop, lower difficulty)

| Keyword | Pop | Diff | Why |
|---------|-----|------|-----|
| **dry days** | 8 | 44 | Best sober-specific sweet spot; in **subtitle** |
| **drink less** | 9 | 50 | Quit/moderation intent without “AA” niche |
| **day counter** | 9 | 65 | Volume; pair with “sober” in description |
| **streak counter** | 9 | 60 | Streak/check-in loop |
| drink control | 6 | 48 | Adjacent to DrinkControl category |
| alcohol diary | 5 | 42 | Journal feature |
| drinking diary | 5 | 48 | Journal variant |
| booze tracker | 5 | 49 | Less crowded than “alcohol tracker” |
| sober companion | 5 | 47 | Low competition |
| body recovery | 5 | 44 | Health timeline |
| **liver recovery** | 5 | **5** | Tiny competition; unique benefit |
| mindful drinking | 5 | 42 | Moderation angle |
| craving tracker | 5 | 52 | Recovery intent |

### Tier B — volume stretch (worth metadata; harder)

| Keyword | Pop | Diff | Why |
|---------|-----|------|-----|
| **alcohol free tracker** | **30** | 67 | **Highest sober-adjacent volume** — lead description |
| daily check in | 16 | 70 | Matches daily loop; competitive |
| alcohol tracker | 7 | 60 | Core category head term |
| alcohol free | 7 | 66 | Already in app **name** |
| sobriety tracker | 5 | 64 | Category head term |
| sober counter | 5 | 60 | Variant |
| quit drinking | 5 | 62 | High intent |
| virtual garden | 5 | 55 | **Differentiator** — use in screenshots/copy |
| private tracker | 5 | 60 | Privacy positioning |

### Tier C — brand defense (track, don’t optimize ASC for)

`sober tracker`, `sober day counter`, `sober calendar`, `sober widget`, `apple watch sober`, `sober journal`, `days sober`, `relapse prevention`, `addiction recovery`, etc.

### Tier D — avoid (wrong fight)

| Keyword | Pop | Diff | Why skip |
|---------|-----|------|----------|
| days since | 50 | 64 | Dominated by “Days Since: Quit Habit Tracker” |
| apple health / health app | 55–60 | 65–80 | Wrong category |
| loosid | 28 | 40 | Competitor brand |
| aa app | 22 | 62 | AA niche; not your positioning |
| healthkit | 19 | 59 | Not user search intent |
| free tracker / app tracker | 5–16 | 70–75 | Generic noise |

Full tier lists: `scripts/astro-keyword-strategy.json`

---

## Live ASC metadata (name + subtitle + keywords)

Apple limits (en-US): **name 30**, **subtitle 30**, **keywords 100** (comma-separated, `WORD,WORD` — no spaces).

| Field | Chars | Limit | Value | Role |
|-------|-------|-------|-------|------|
| **Name** | 28 | 30 | Sober Tracker - Alcohol Free | Brand + **alcohol free** (feeds “alcohol free tracker”, pop 30) |
| **Subtitle** | 25 | 30 | Dry Days Counter & Garden | Tier-A **dry days** + differentiator **garden** |
| **Keywords** | 96 | 100 | `sobriety,drink,less,quit,recovery,widget,watch,streak,journal,calendar,private,milestone,relapse` | Only tokens **not** already in name/subtitle |

**Do not repeat** name/subtitle words in the keyword field — Apple already indexes those; duplicates waste the 100-char budget. Removed from keywords: `sober`, `alcohol`, `tracker`, `counter`, `dry`, `days`, `garden`, `free`.

Validate anytime:

```bash
python3 scripts/validate-asc-metadata.py
python3 scripts/astro-build-asc-keywords.py --write   # rebuild keywords from name+subtitle
```

### Optional A/B (all ≤30 chars)

| Slot | Alt copy | Notes |
|------|----------|-------|
| Name | `Sober: Dry Days Tracker` (23) | Moves Tier-A into name; weaker “alcohol free” |
| Name | `Sober - Sobriety Tracker` (24) | Head-term “sobriety tracker” |
| Subtitle | `Day Counter, Garden & Watch` (27) | Widget/Watch angle |
| Subtitle | `Alcohol-Free Day Counter` (24) | Volume phrase split across name+sub |

Current pick keeps **alcohol free** in the name and **dry days** in the subtitle — best match to Astro Tier A/B.

Files: `fastlane/metadata/en-US/{name,subtitle,keywords,description}.txt`

**Description** (unlimited) carries phrases: alcohol-free day counter, dry days, virtual garden, private, Watch/widgets — see `description.txt`.

**Multi-language:** edit `scripts/aso_native_metadata.py` → `python3 scripts/aso-apply-locale-optimizations.py` → `./scripts/asc-finish-missed.sh`. See `docs/localization-aso.md` and `docs/astro-phase-b-report.md`.

Upload draft: `./scripts/asc-finish-missed.sh`

---

## Astro tracking

| Artifact | Purpose |
|----------|---------|
| `scripts/astro-keywords-us.json` | 58 curated terms in Astro (after prune) |
| `scripts/astro-keyword-strategy.json` | Tiers, priority list, rationale |
| `scripts/astro-keyword-metrics.json` | Refresh via `./scripts/astro-fetch-metrics.sh` |
| `scripts/.astro-app.json` | Live Astro app `6768869215` (`preLaunchAppId` `103`) |

**Priority tags** (optimize first in Astro):  
`alcohol free tracker`, `dry days`, `drink less`, `streak counter`, `day counter`, `alcohol tracker`, `sobriety tracker`, `sober counter`, `quit drinking`, `virtual garden`, `liver recovery`, `private tracker`, `daily check in`

---

## Prune junk keywords (MCP)

```bash
./scripts/astro-prune-keywords.sh
```

Uses `remove_keywords` — drops Tier D terms (`days since`, `health app`, `apple health`, `loosid`, `aa app`, etc.) and probe noise not in the curated list.

---

## Weekly routine (~10 min)

1. `./scripts/astro-fetch-metrics.sh` → `python3 scripts/astro-curate-keywords.py`
2. Astro → Sober → US → sort by **popularity** and **rank change**
3. Double down on Tier A/B terms moving into top 200
4. Drop Tier D terms stuck at 1000 for 3+ weeks
5. After ASC copy changes, wait 7–14 days before judging rank shifts

---

## Re-sync

```bash
./scripts/pull-appstore-metadata.sh
./scripts/sync-astro-keywords.sh
# or full rebuild:
./scripts/astro-setup.sh --skip-pull
```

---

## Next experiments

1. **Screenshot captions** — “Dry days”, “Virtual garden”, “Private — no account”
2. **A/B subtitle** — `Sober Counter, Garden & Watch` vs current
3. **Promotional text** — rotate `alcohol free tracker` / `dry days` seasonally
4. **At launch** — link Astro to `6768869215`; retire temp app if duplicate
