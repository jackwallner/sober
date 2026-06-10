#!/usr/bin/env python3
"""Validate App Store Connect metadata character limits (en-US)."""
from __future__ import annotations

import sys
from pathlib import Path

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100}
META = Path("fastlane/metadata/en-US")


def read(field: str) -> str:
    p = META / f"{field}.txt"
    return p.read_text().strip() if p.exists() else ""


def tokens(text: str) -> set[str]:
    return set(text.lower().replace("&", " ").replace("-", " ").replace(",", " ").split())


def main() -> int:
    name = read("name")
    subtitle = read("subtitle")
    keywords = read("keywords")
    ok = True

    print("ASC metadata limits (en-US)\n")
    for field, limit in LIMITS.items():
        val = {"name": name, "subtitle": subtitle, "keywords": keywords}[field]
        n = len(val)
        status = "OK" if n <= limit else "OVER"
        if n > limit:
            ok = False
        print(f"  {field:9} {n:3}/{limit}  {status}  {val!r}")

    if keywords:
        dup = set(keywords.split(",")) & (tokens(name) | tokens(subtitle))
        if dup:
            print(f"\n  keywords duplicate name/subtitle (wasted slots): {sorted(dup)}")
        print(f"\n  keywords comma tokens: {len(keywords.split(','))}")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
