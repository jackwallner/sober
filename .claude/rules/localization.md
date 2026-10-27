---
paths:
  - "Sober/**"
  - "Shared/**"
  - "SoberWatch/**"
  - "SoberWidgets/**"
  - "Tools/Localization/**"
---

# Sober: localization (added 2026-10-27)

The app, widgets and Watch ship in English plus cs, de, el, es, fi, fr, hi, it,
ka, lt, nb, nl, pl, ru, uk, vi (regions with 2+ new customers). Non-English
markets trialed at about 6% against 15 to 19% for US/UK/CA/AU while the App
Store pages were already translated, so the copy inside the app is the lever.

## Setup
- One catalog, `Shared/Localizable.xcstrings` (source `en`, every key
  `extractionState: manual`). `Shared/` is a source of every target, so app,
  widget, Watch and tests all compile it. XcodeGen 2.39+ reads its languages
  into `knownRegions`; each Info.plist also lists them in
  `CFBundleLocalizations`. No `InfoPlist.xcstrings`: there are no permission
  purpose strings, and the display names are the brand.
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on a
  source literal with no key, a key missing a language, or mismatched format
  specifiers. Run it before every build that touches copy.
- `LocalizationTests` proves the catalog compiles to every `.lproj` and that
  Russian plurals pick one/few/many.

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `Section`, `navigationTitle`, `alert`
  and friends localize themselves. Copy held in a `String` (view parameters,
  enums, catalogs, notifications, error messages) must be
  `String(localized: "...")`. Logs, analytics, RevenueCat metadata, stored tags
  and identifiers stay plain.
- Whole sentences only, never spliced fragments. Branch and give each variant
  its own key (see `soberHabitComparisonSentence`: 4 plans x 5 spans = 20
  keys). Counts go in plural variations, or a `%#@n@` substitution when the
  sentence has other arguments; Slavic languages need one/few/many/other.
- A count label shown under a big number ("Days Sober") is a plural key whose
  variants omit the number (`"%lld Days Sober"`, `"%lld ridden out"`,
  `"%lld days sober label"`). Keep the en variants in the catalog, or English
  shows the raw key.
- Stored English values are translated at display time:
  `HabitVocabulary.triggerLabel(_:)` for trigger chips (tags key the playbook
  and saved episodes), `JournalEntry.feelingLabel(_:)` for feelings.
- No `.capitalized`/`.lowercased()` on translated text. Dates use
  `setLocalizedDateFormatFromTemplate` or `formatted()`; units use
  `Measurement` (body fat is kg outside the US); durations use
  `DateComponentsFormatter`.
- Prices only from StoreKit (`localizedPriceString`, `soberPriceLabel`);
  "$0 due now" is `Decimal(0).formatted(.currency(...))`. Trial lengths come
  from `soberIntroOfferDays`, never from parsing a label.
- Brand stays untranslated: Sober, Bloom+, NIAAA/CDC/AHA, the US helpline
  names. Habit words were inlined when `HabitVocabulary` lost its nouns, so a
  fork edits these sentences in the catalog for every language.
- Translations are written to read natively and stay about as long as the
  English; check German and Finnish first on tight rows (plan badges, CTA).

## Proving a change
`gh-sim all` with one `--screen` per language, e.g.
`--screen "-AppleLanguages (de) -AppleLocale de_DE -onboardingStep 4 -previewStore"`
(trial page) and `"... -PaywallSnapshot yearly -previewStore"` (paywall). The
preview store formats prices in en_US, so its "$" is a fixture, not a bug.
