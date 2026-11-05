---
paths:
  - "artifacts/asc-screenshots/**"
  - "fastlane/screenshots/**"
---

# Localized store sets

Run `artifacts/asc-screenshots/l10n-20261105/tools/capture.sh` from the repo root, then run the kit's `tools/compose.py`. The capture script accepts optional store locales and always includes English. Build the kit's native tools first with `tools/build.sh` and install its Python requirements into the kit's `.venv`.

The phone set uses `-seedDemo -seedDays 127 -storeScreenshots -demoPro`. The progress frame also uses `-showProgress -scrollProgressSaved`; it shows the current savings section. The capture run requests a short recording to give the multi-scene job enough time. Frame 6 uses a currency-free offer badge, while values inside the app use the locale's formatter. Review every generated contact sheet and gate result before copying the PNGs into fastlane.

The current screens differ from the live English captures, so raw-image matching scores poorly. The shared phone opening was measured from the bezel at `[238, 900, 814, 1715]`; check its alignment against a fresh sheet after layout changes. Header plates restore the curved decoration where the English copy was removed.

This run retained the consistent 25-day German pilot after the 128-day capture failed. The locale exclusions in `frames.json` record incomplete draws or a progress sheet that did not reach savings. After recapturing, inspect the sheets and remove an exclusion only when that scene is complete. The gate checks only retained frames, so a pass does not imply that a locale has all six.
