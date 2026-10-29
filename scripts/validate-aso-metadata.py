#!/usr/bin/env python3
"""Validate App Store metadata field limits and keyword overlap."""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOCALES = ["en-US", "en-CA", "en-GB", "en-AU", "uk", "pl", "de-DE", "nl-NL", "ru"]
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
}
WORD = re.compile(r"[^\W_]+", re.UNICODE)


def read_value(path: Path) -> str:
    raw = path.read_text(encoding="utf-8")
    return raw[:-1] if raw.endswith("\n") else raw


def normalize(value: str) -> str:
    return unicodedata.normalize("NFC", value).casefold()


def words(value: str) -> set[str]:
    return {normalize(word) for word in WORD.findall(value)}


def validate_locale(locale: str) -> list[str]:
    folder = ROOT / "fastlane" / "metadata" / locale
    errors: list[str] = []
    values: dict[str, str] = {}

    for filename, limit in LIMITS.items():
        path = folder / filename
        if not path.is_file():
            errors.append(f"{locale}/{filename}: missing")
            continue
        value = read_value(path)
        values[filename] = value
        if len(value) > limit:
            errors.append(f"{locale}/{filename}: {len(value)} characters, limit {limit}")
        if value != value.strip():
            errors.append(f"{locale}/{filename}: leading or trailing whitespace")
        if "\u2014" in value:
            errors.append(f"{locale}/{filename}: contains em dash")

    keywords = values.get("keywords.txt", "")
    tokens = [normalize(token) for token in keywords.split(",")]
    if any(not token for token in tokens):
        errors.append(f"{locale}/keywords.txt: empty keyword token")
    if any(any(character.isspace() for character in token) for token in tokens):
        errors.append(f"{locale}/keywords.txt: spaces inside comma-separated keyword field")
    if len(tokens) != len(set(tokens)):
        errors.append(f"{locale}/keywords.txt: duplicate keyword token")

    title_tokens = words(values.get("name.txt", "")) | words(values.get("subtitle.txt", ""))
    overlaps = sorted(set(tokens) & title_tokens)
    if overlaps:
        errors.append(f"{locale}/keywords.txt: repeats title or subtitle token(s): {', '.join(overlaps)}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("locales", nargs="*", default=DEFAULT_LOCALES)
    args = parser.parse_args()

    errors = [error for locale in args.locales for error in validate_locale(locale)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Validated {len(args.locales)} locale(s): all field limits and copy checks pass.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
