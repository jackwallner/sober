# Astro ASO Phase B report — Sober

**Date:** 2026-05-26  
**ASC draft version:** 1.0 (`PREPARE_FOR_SUBMISSION`)  
**ASC app ID:** 6768869215  
**Astro app ID:** 103 (pre-launch “Sober”)

## Summary

| Item | Result |
|------|--------|
| ASC locales optimized | **50** (true multi-language name/subtitle/keywords/description) |
| ASC upload (API PATCH) | **50/50** ok |
| fastlane deliver (appInfo + version) | **Success** (after review contact + Fastfile fix) |
| Astro stores synced | **91/91** (`_summary.json` · `FULL_SYNC_DONE` 2026-05-26) |
| Astro keyword sync | Full pass complete; prune partial (MCP flaps — re-run `./scripts/astro-prune-all-stores.sh` when Astro idle) |
| Competitor scan | `scripts/astro-competitor-research.json` |
| Prune pass | `scripts/astro-prune-all-stores.log` |

## Pull backup

- `fastlane/metadata.bak.20260525-190649`

## Pre-upload backup (native copy)

- `fastlane/metadata.bak.pre-upload-native-20260526-090332`

## en-US (primary)

| Field | Before | After | Len |
|-------|--------|-------|-----|
| Name | Sober Tracker - Alcohol Free | *(unchanged)* | 28/30 |
| Subtitle | *(empty on ASC)* | Dry Days Counter & Garden | 25/30 |
| Keywords | *(empty)* | sobriety,drink,less,quit,recovery,widget,watch,streak,journal,calendar,private,milestone,relapse | 96/100 |
| Description | *(empty)* | Full EN listing (FREE + Bloom+ sections) | ~1.1k chars |

## Multi-language (all 50 ASC locales)

**Before:** English name everywhere; empty keywords/descriptions on most locales after first pull.

**After:** Per-locale native copy from `scripts/aso_native_metadata.py`:

| Locale family | Name example | Subtitle example |
|---------------|--------------|------------------|
| de-DE | Sober: Alkoholfrei Tracker | Trockene Tage & Garten |
| fr-FR | Sober – Suivi sobriété | Jours secs & jardin |
| es-ES | Sober – Contador sobrio | Días secos y jardín |
| ja | ソーバー：禁酒カウンター | 乾いた日数とガーデン |
| zh-Hans | 清醒助手 - 戒酒计数器 | 干燥天数与花园 |
| ar-SA | سوبر - عداد التعافي | أيام جافة وحديقة |
| hi | सोबर – शराब मुक्त ट्रैकर | शुष्क दिन और बगीचा |

Full before/after per locale: `scripts/aso-locale-optimization-report.json`

## Upload confirmation

```
Draft: 1.0 · PREPARE_FOR_SUBMISSION
Patched 50 locale(s) via asc-upload-metadata.sh
deliver: fastlane.tools finished successfully
Draft appInfo locales: 50
```

## Astro

- Store plans: `scripts/astro-keywords-by-store/*.json` (91 targets)
- US curated list: `scripts/astro-keywords-us.json` (58 terms)
- Re-sync after metadata edits: `./scripts/astro-sync-all-stores.sh`

## go refine (calendar)

**~2026-06-09** (14 days): re-pull ASC → `astro-optimize --all-stores` → tune from ranks → upload.

## Blockers / notes

- Astro MCP shared with other app repos → intermittent HTTP 500 / timeout during 91-store `add_keywords`. Re-run `./scripts/astro-sync-all-stores.sh` when Astro is idle.
- Review contact fields were empty; filled in `fastlane/metadata/review_information/` for deliver.
- `fastlane/Fastfile`: `version_check_wait_retry_limit` must be ≥ 1 (set to 7).
