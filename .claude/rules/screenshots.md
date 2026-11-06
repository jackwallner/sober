---
paths:
  - "artifacts/asc-screenshots/**"
  - "fastlane/screenshots/**"
---

# Localized store sets

Run `artifacts/asc-screenshots/l10n-20261105/tools/capture.sh` from the repo root, then run the kit's `tools/compose.py`. The capture script accepts optional store locales, reuses complete English reference raws, and captures English when a reference is missing. It waits 11 seconds for batches over 20 screens to fit GH-Sim's 25-minute screenshot step, and 14 seconds for smaller retries. Use `--with-tests` to run `SoberTests` in the same `gh-sim all` job. Build the kit's native tools first with `tools/build.sh` and install its Python requirements into the kit's `.venv`.

The phone set uses `-seedDemo -seedDays 127 -storeScreenshots -demoPro`. The progress frame also uses `-showProgress -scrollProgressSaved`; it shows the current savings section. The capture run requests a short recording to give the multi-scene job enough time. Frame 6 uses a currency-free offer badge, while values inside the app use the locale's formatter. Review every generated contact sheet and gate result before copying the PNGs into fastlane.

The current screens differ from the live English captures, so raw-image matching scores poorly. The shared phone opening was measured from the bezel at `[238, 900, 814, 1715]`; check its alignment against a fresh sheet after layout changes. Header plates restore the curved decoration where the English copy was removed.

The 2026-11-05 refresh uses the same 128-day demo in every target locale. It restores all six frames in all 14 target locales, including the Saved section in frame 3. The frame exclusions are cleared only after the missing scenes were recaptured, composed, gated and visually reviewed.
