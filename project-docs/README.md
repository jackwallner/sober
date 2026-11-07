# Project documentation

Developer notes and historical audits for this repository. The published site remains in the docs directory.

## Audits

- [audit823.md](audits/audit823.md): Sober audit823
- [ios27Sober.md](audits/ios27Sober.md): iOS 27 compatibility audit: Sober
- [reg93.md](audits/reg93.md): Sober build 83 to build 87 regression audit
- [reg94.md](audits/reg94.md): Sober build 83 to build 88 regression audit
- [state-machines-2026-11-06.md](audits/state-machines-2026-11-06.md): state machines, invariants and 19 reachable bugs, with a repro suite
- [state-machines-2026-11-06-review.md](audits/state-machines-2026-11-06-review.md): independent review of that audit: 6 confirmed, 11 minor, 2 rejected, with method changes for the fleet pilot
- [state-machines-2026-11-06-fixes.md](audits/state-machines-2026-11-06-fixes.md): fixes for the review's 19 in-scope claims, with regression tests and final suite results (J4 reworked after the first verify pass, its floor capped at now after the second)
- [state-machines-2026-11-06-verify.md](audits/state-machines-2026-11-06-verify.md): independent check of those fixes (third pass): the Z1 crash is fixed and all 21 hold on their routes, but S1's undo rule with J4's trim refuses the next slip's undo after the start is moved earlier past a Reset or leftover onboarding run

## Marketing

- [aso-plan.md](marketing/aso-plan.md): aso-plan.md: Sober Tracker ASO Plan
- [social-kit](marketing/social-kit/README.md): Sober TikTok, Instagram and YouTube kit: 42 posts, builder, profile copy

## QA

- [2026-10-11-bloom-day-zero](qa/2026-10-11-bloom-day-zero/): 1.3.3 goal step, trial page, Home cards, playbook and craving exit card captures, plus the CTA frame dump

## ASO

- [ASO pass index](aso/README.md): dated App Store metadata research and changes.
