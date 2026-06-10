#!/usr/bin/env python3
"""
Build a <=100-char ASC keyword field (comma-separated, no spaces).
Skips tokens already present in name.txt and subtitle.txt.
"""
from __future__ import annotations

import argparse
from pathlib import Path

META = Path("fastlane/metadata/en-US")
DEFAULT_CANDIDATES = [
    # Tier A/B single-word tokens (Astro research) — order = priority
    "sobriety",
    "drink",
    "less",
    "quit",
    "recovery",
    "widget",
    "watch",
    "streak",
    "journal",
    "calendar",
    "private",
    "milestone",
    "relapse",
    "diary",
    "craving",
    "abstinence",
    "companion",
    "timeline",
]


def tokens(text: str) -> set[str]:
    return set(text.lower().replace("&", " ").replace("-", " ").replace(",", " ").split())


def build(candidates: list[str], used: set[str], limit: int = 100) -> str:
    picked: list[str] = []
    for word in candidates:
        w = word.strip().lower()
        if not w or w in used or w in picked:
            continue
        trial = ",".join(picked + [w]) if picked else w
        if len(trial) <= limit:
            picked.append(w)
    return ",".join(picked)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="Write fastlane/metadata/en-US/keywords.txt")
    parser.add_argument("--extra", nargs="*", default=[])
    args = parser.parse_args()

    name = (META / "name.txt").read_text().strip() if (META / "name.txt").exists() else ""
    subtitle = (META / "subtitle.txt").read_text().strip() if (META / "subtitle.txt").exists() else ""
    used = tokens(name) | tokens(subtitle)
    candidates = list(dict.fromkeys(list(args.extra) + DEFAULT_CANDIDATES))
    field = build(candidates, used)

    print(f"name ({len(name)}/30): {name}")
    print(f"subtitle ({len(subtitle)}/30): {subtitle}")
    print(f"keywords ({len(field)}/100): {field}")
    if used & set(field.split(",")):
        print("warning: overlap remains")

    if args.write:
        (META / "keywords.txt").write_text(field + "\n")
        print(f"wrote {META / 'keywords.txt'}")


if __name__ == "__main__":
    main()
