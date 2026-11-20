#!/usr/bin/env python3
"""Print per-locale ASO field counts against limits and flag keyword problems.

Usage: scripts/check-aso-locales.py [locale ...]   (defaults to the 2026-11-20 l10n set)
"""

from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "fastlane" / "metadata"
DEFAULT = ["en-GB", "en-CA", "fr-CA", "en-AU", "uk", "pl", "de-DE", "ru", "nl-NL", "es-MX"]
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170, "description": 4000}
WORD = re.compile(r"[^\W_]+", re.UNICODE)


def norm(value: str) -> str:
    return unicodedata.normalize("NFC", value).casefold()


def read(locale: str, field: str) -> str:
    text = (ROOT / locale / f"{field}.txt").read_text(encoding="utf-8")
    return text[:-1] if text.endswith("\n") else text


def check(locale: str) -> int:
    values = {field: read(locale, field) for field in LIMITS}
    counts = " ".join(f"{f}={len(v)}/{LIMITS[f]}" for f, v in values.items())
    problems = [f"{f} over limit" for f, v in values.items() if len(v) > LIMITS[f]]
    tokens = [norm(t) for t in values["keywords"].split(",")]
    title = {norm(w) for f in ("name", "subtitle") for w in WORD.findall(values[f])}
    if set(tokens) & title:
        problems.append("keyword repeats name/subtitle: " + ",".join(sorted(set(tokens) & title)))
    if len(tokens) != len(set(tokens)):
        problems.append("duplicate keyword")
    if " " in values["keywords"] or "app" in tokens:
        problems.append("space or 'app' in keywords")
    if any("—" in v for v in values.values()):
        problems.append("em dash")
    print(f"{locale:6} {counts}", "OK" if not problems else "; ".join(problems))
    return len(problems)


if __name__ == "__main__":
    sys.exit(1 if sum(check(loc) for loc in (sys.argv[1:] or DEFAULT)) else 0)
