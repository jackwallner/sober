#!/usr/bin/env python3
"""Pack App Store keyword fields to ~100 chars without title/subtitle overlap."""
from __future__ import annotations

import re
from typing import Iterable


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9\u0080-\uffff]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def _overlaps_indexed(kw: str, indexed: set[str]) -> bool:
    if kw in indexed:
        return True
    for t in indexed:
        if len(kw) >= 4 and (kw in t or t in kw):
            return True
    return False


def pack_keywords(
    name: str,
    subtitle: str,
    candidates: Iterable[str],
    *,
    limit: int = 100,
) -> str:
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    used = 0
    seen: set[str] = set()

    for raw in candidates:
        kw = raw.strip().lower().replace(" ", "")
        if not kw or kw in seen or _overlaps_indexed(kw, indexed):
            continue
        add = len(kw) + (1 if kept else 0)
        if used + add > limit:
            continue
        kept.append(kw)
        seen.add(kw)
        used += add

    if used < limit - 4:
        for raw in candidates:
            kw = raw.strip().lower().replace(" ", "")
            if not kw or kw in seen or _overlaps_indexed(kw, indexed):
                continue
            add = len(kw) + (1 if kept else 0)
            if used + add <= limit:
                kept.append(kw)
                seen.add(kw)
                used += add

    return ",".join(kept)


# US-market filler — must not leak into non-English keyword fields.
ENGLISH_ONLY_TERMS = frozenset(
    {
        "reframe", "helper", "thrive", "adhd", "habittracker", "goaltracker",
        "goalplanner", "goal", "planner", "countdown", "mindful", "drinkless",
        "iamsober", "nomo", "daycount", "sunflower", "sobo", "cleanday",
        "dryjanuary", "try dry", "alcochange",
    }
)


def validate_packed_keywords(locale: str, keywords: str) -> list[str]:
    if locale.startswith("en-"):
        return []
    errors: list[str] = []
    for term in keywords.split(","):
        t = term.strip().lower()
        if t in ENGLISH_ONLY_TERMS:
            errors.append(f"{locale}: English-only term {t!r} in keywords")
    return errors


def title_subtitle_overlap(name: str, subtitle: str) -> list[str]:
    nw = [w.lower() for w in re.findall(r"[a-z0-9\u0080-\uffff]+", name, flags=re.I) if len(w) >= 2]
    sw = [w.lower() for w in re.findall(r"[a-z0-9\u0080-\uffff]+", subtitle, flags=re.I) if len(w) >= 2]
    hits: set[str] = set(nw) & set(sw)
    for a in nw:
        for b in sw:
            if len(a) >= 4 and len(b) >= 4 and (a in b or b in a):
                hits.add(a if a in b or len(a) <= len(b) else b)
    return sorted(hits)


def validate_title_subtitle(locale: str, name: str, subtitle: str) -> list[str]:
    errs: list[str] = []
    for label, val, lim in [("title", name, 30), ("subtitle", subtitle, 30)]:
        if len(val) > lim:
            errs.append(f"{locale}: {label} {len(val)}>{lim}: {val!r}")
    overlap = title_subtitle_overlap(name, subtitle)
    if overlap:
        errs.append(f"{locale}: title/subtitle overlap {overlap}: {name!r} | {subtitle!r}")
    return errs


# US Astro-backed: sober tracker / quit drinking / dry days SERPs (pop≥5, alcohol intent).
# Title indexes: sober, tracker, alcohol, free, dry, days, sobriety, counter, garden.
# Excluded: habit/habits (fitness SERP), reframe/helper/thrive (competitor brands).
US_EN_CANDIDATES = [
    "drink",       # 6 — quit drinking extract
    "less",        # cut back intent
    "quit",        # 8
    "stop",        # 49 — quit drinking extract
    "dry",         # 13 — dry days pop12 rank82
    "days",        # 9
    "recovery",    # 6
    "sobriety",    # core intent
    "addiction",   # recovery orbit
    "relapse",     # journey
    "cravings",    # quit intent
    "mood",        # check-in feature
    "streak",      # 6
    "abstinence",  # recovery
    "daily",       # check-in
    "clean",       # clean days
    "calendar",    # feature
    "journal",     # pro feature
    "garden",      # differentiator
    "widget",      # feature
    "wine",        # alcohol type
    "beer",        # alcohol type
    "detox",       # quit journey
    "january",     # 18 — dry january
    "health",      # timeline
    "private",     # privacy
]
