---
paths:
  - "Shared/Utilities/TrialNote.swift"
  - "Sober/Features/Onboarding/OnboardingView.swift"
  - "Sober/Features/Today/HomeView.swift"
---

# Sober: the trial pitch indie note test (2026-10-27)

`TrialNote` adds "We're a small indie studio. Your trial helps us keep
building. Not for you? Cancel anytime and tell us what to fix." under the
onboarding pitch's benefit card. The app reads the `default` offering (never
`current`), so the switch is that offering's `trial_note` metadata: `none` or
missing is the live pitch, `indie` shows it to all, `split` deals each install
one arm 50/50 (`trialNote.arm`) and keeps it. `none` stops it for everyone.

The arm goes to RevenueCat as `trial_note` once the pitch was seen with the
switch on (`trialNote.seen`). A customer who saw the note and switches the
trial's renewal off gets one Home alert asking what to fix, with a mail draft
(`SubscriptionService.whatToFixDue`, `HomeView.presentWhatToFixWhenClear`).
The CTA must not move between arms (`BloomDayZeroCaptureUITests.test5TrialNoteArms`).
`-trialNote.arm none|indie` (DEBUG) pins the arm. Plan, readout and the
pre-registered rule: `~/ios/growth/indie-note-test.md`.
