#!/usr/bin/env python3
"""Verify fastlane metadata against locale_aso_spec; write JSON report."""
from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
META = ROOT / "fastlane/metadata"

sys.path.insert(0, str(SCRIPTS))
from locale_aso_spec import LOCALE_ASO  # noqa: E402
from pack_sober_keywords import (  # noqa: E402
    _overlaps_indexed,
    indexed_terms,
    title_subtitle_overlap,
    validate_packed_keywords,
    validate_title_subtitle,
)


def main() -> int:
    report: dict[str, dict] = {}
    issues: list[str] = []

    for loc, spec in sorted(LOCALE_ASO.items()):
        d = META / loc
        if not d.is_dir():
            issues.append(f"{loc}: missing metadata folder")
            continue
        title = (d / "name.txt").read_text(encoding="utf-8").strip()
        subtitle = (d / "subtitle.txt").read_text(encoding="utf-8").strip()
        keywords = (d / "keywords.txt").read_text(encoding="utf-8").strip()
        idx = indexed_terms(title, subtitle)
        kw_overlap = [
            t.strip()
            for t in keywords.split(",")
            if t.strip() and _overlaps_indexed(t.strip().lower(), idx)
        ]
        errs = (
            validate_title_subtitle(loc, title, subtitle)
            + validate_packed_keywords(loc, keywords)
            + ([f"{loc}: kw overlap {kw_overlap}"] if kw_overlap else [])
        )
        if len(title) <= 24:
            errs.append(f"{loc}: title short {len(title)}")
        if len(subtitle) <= 24:
            errs.append(f"{loc}: subtitle short {len(subtitle)}")
        if len(keywords) < 94:
            errs.append(f"{loc}: keywords short {len(keywords)}")
        issues.extend(errs)
        report[loc] = {
            "title": title,
            "subtitle": subtitle,
            "keywords": keywords,
            "title_len": len(title),
            "subtitle_len": len(subtitle),
            "keywords_len": len(keywords),
            "indexed_terms": sorted(idx),
            "keyword_overlaps": kw_overlap,
            "title_subtitle_overlap": title_subtitle_overlap(title, subtitle),
            "rationale": spec.rationale,
            "astro_proof": list(spec.astro_proof),
            "store": spec.store,
            "ok": not errs,
        }

    out = SCRIPTS / "aso-locale-verification-report.json"
    out.write_text(json.dumps({"issues": issues, "locales": report}, ensure_ascii=False, indent=2), encoding="utf-8")
    ok_count = sum(1 for v in report.values() if v["ok"])
    print(f"Report: {out} ({ok_count}/{len(report)} locales OK, {len(issues)} issues)")
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
