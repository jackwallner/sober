#!/usr/bin/env python3
"""
Score and curate Astro keywords from astro-keyword-metrics.json.

Tiers (pre-launch; uses popularity + difficulty only):
  A — sweet spot: pop>=8, diff<=55
  B — core sober: pop>=5, diff<=65, keyword matches recovery/sober/alcohol/drink
  C — volume play: pop>=12 (worth ASC/description even if harder)
  D — deprioritize: pop<5 or diff>72 or generic noise (health app, app tracker)
"""
from __future__ import annotations

import json
import re
from pathlib import Path

SOBER_RE = re.compile(
    r"sober|sobriety|alcohol|drink|recovery|addiction|dry|quit|relapse|"
    r"abstin|clean|journal|calendar|counter|streak|milestone|widget|watch|garden",
    re.I,
)
GENERIC_DROP = {
    "health app",
    "apple health",
    "healthkit",
    "app tracker",
    "daily tracker",
    "free tracker",
    "tracker alcohol",
    "sober tracker - alcohol free",
}


def tier(kw: str, pop: int, diff: int) -> str:
    if kw in GENERIC_DROP:
        return "D"
    if pop >= 8 and diff <= 55:
        return "A"
    if pop >= 5 and diff <= 65 and SOBER_RE.search(kw):
        return "B"
    if pop >= 12 and diff <= 75:
        return "C"
    if pop >= 5 and diff <= 62:
        return "B"
    if pop < 5 or diff > 72:
        return "D"
    return "C"


def main() -> None:
    metrics_path = Path("scripts/astro-keyword-metrics.json")
    if not metrics_path.exists():
        raise SystemExit(f"missing {metrics_path} — fetch via MCP first")

    rows = json.loads(metrics_path.read_text())
    scored = []
    for r in rows:
        kw = r["keyword"]
        pop = int(r.get("popularity") or 0)
        diff = int(r.get("difficulty") or 99)
        t = tier(kw, pop, diff)
        score = pop * 3 - diff + (10 if t == "A" else 5 if t == "B" else 0)
        scored.append(
            {
                "keyword": kw,
                "popularity": pop,
                "difficulty": diff,
                "tier": t,
                "score": score,
                "appsCount": r.get("appsCount"),
            }
        )

    by_tier = {t: [] for t in "ABCD"}
    for s in sorted(scored, key=lambda x: -x["score"]):
        by_tier[s["tier"]].append(s)

    print("=== TIER A (sweet spot) ===")
    for s in by_tier["A"]:
        print(f"  {s['popularity']:2} pop  {s['difficulty']:2} diff  {s['keyword']}")

    print("\n=== TIER B (core sober) ===")
    for s in by_tier["B"]:
        print(f"  {s['popularity']:2} pop  {s['difficulty']:2} diff  {s['keyword']}")

    print("\n=== TIER C (volume / stretch) ===")
    for s in by_tier["C"]:
        print(f"  {s['popularity']:2} pop  {s['difficulty']:2} diff  {s['keyword']}")

    print("\n=== TIER D (deprioritize) ===")
    for s in by_tier["D"]:
        print(f"  {s['popularity']:2} pop  {s['difficulty']:2} diff  {s['keyword']}")

    # Final track list: all A+B, top C by score, cap 55
    keep = by_tier["A"] + by_tier["B"]
    keep += sorted(by_tier["C"], key=lambda x: -x["score"])[:8]
    keywords = [s["keyword"] for s in sorted(keep, key=lambda x: -x["score"])]
    keywords = list(dict.fromkeys(keywords))

    # Prefer strategy file ASC field when present (hand-tuned 100-char field)
    strategy_path = Path("scripts/astro-keyword-strategy.json")
    if strategy_path.exists():
        asc_field = json.loads(strategy_path.read_text()).get("ascKeywords", "")
    else:
        asc_tokens = []
        for s in sorted(keep, key=lambda x: (-x["popularity"], x["difficulty"])):
            for part in s["keyword"].replace("-", " ").split():
                if len(part) >= 3 and part not in asc_tokens:
                    asc_tokens.append(part)
        asc_field = ",".join(asc_tokens[:17])[:100]

    out = {
        "store": "us",
        "appName": "Sober Tracker - Alcohol Free",
        "ascKeywords": asc_field,
        "keywords": keywords,
        "tiers": {t: [s["keyword"] for s in by_tier[t]] for t in "ABCD"},
    }
    Path("scripts/astro-keywords-us.json").write_text(json.dumps(out, indent=2) + "\n")
    Path("scripts/astro-keyword-strategy.json").write_text(json.dumps(out, indent=2) + "\n")
    print(f"\nWrote {len(keywords)} curated keywords → scripts/astro-keywords-us.json")
    print(f"Suggested ASC field ({len(asc_field)} chars): {asc_field}")


if __name__ == "__main__":
    main()
