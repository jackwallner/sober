#!/usr/bin/env python3
"""Pack keywords + sync locale_aso_spec → aso_native_metadata → fastlane."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent

sys.path.insert(0, str(SCRIPTS))
from locale_aso_spec import LOCALE_ASO  # noqa: E402
from pack_sober_keywords import (  # noqa: E402
    _overlaps_indexed,
    indexed_terms,
    pack_keywords,
    validate_packed_keywords,
    validate_title_subtitle,
)


def rewrite_locales_in_source(packed: dict[str, tuple[str, str, str]]) -> None:
    path = SCRIPTS / "aso_native_metadata.py"
    text = path.read_text(encoding="utf-8")

    for loc, (name, subtitle, keywords) in packed.items():
        if loc not in LOCALE_ASO:
            continue
        block_re = re.compile(
            rf'("{re.escape(loc)}": \{{\s*"name": )"[^"]*"(,\s*"subtitle": )"[^"]*"(,\s*"keywords": )"[^"]*"',
            re.S,
        )
        repl = rf"\1{json.dumps(name, ensure_ascii=False)}\2{json.dumps(subtitle, ensure_ascii=False)}\3{json.dumps(keywords, ensure_ascii=False)}"
        text, n = block_re.subn(repl, text, count=1)
        if n != 1:
            raise RuntimeError(f"Failed to rewrite {loc} in aso_native_metadata.py")

    path.write_text(text, encoding="utf-8")


def main() -> int:
    packed: dict[str, tuple[str, str, str]] = {}
    leak_errs: list[str] = []

    for loc, spec in sorted(LOCALE_ASO.items()):
        name, subtitle = spec.title, spec.subtitle
        keywords = pack_keywords(name, subtitle, spec.keyword_pool, limit=100)
        packed[loc] = (name, subtitle, keywords)

        leak_errs.extend(validate_packed_keywords(loc, keywords))
        leak_errs.extend(validate_title_subtitle(loc, name, subtitle))
        indexed = indexed_terms(name, subtitle)
        for term in keywords.split(","):
            t = term.strip().lower()
            if t and _overlaps_indexed(t, indexed):
                leak_errs.append(f"{loc}: keyword {t!r} overlaps title/subtitle")
        if len(name) <= 24:
            leak_errs.append(f"{loc}: title short {len(name)}")
        if len(subtitle) <= 24:
            leak_errs.append(f"{loc}: subtitle short {len(subtitle)}")
        if len(keywords) < 94:
            leak_errs.append(f"{loc}: keywords short {len(keywords)}")

    if leak_errs:
        for e in leak_errs:
            print("ERROR:", e)
        return 1

    rewrite_locales_in_source(packed)
    print(f"Updated aso_native_metadata.py ({len(packed)} locales)")

    subprocess.run([sys.executable, str(SCRIPTS / "aso-apply-locale-optimizations.py")], check=True)

    lengths = [len(kw) for _, _, kw in packed.values()]
    print(
        f"Keyword lengths: min={min(lengths)} max={max(lengths)} "
        f"avg={sum(lengths)/len(lengths):.1f} "
        f"≥94 chars: {sum(1 for x in lengths if x >= 94)}/{len(lengths)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
