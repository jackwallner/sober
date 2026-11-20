# Project documentation

Developer notes and historical audits for this repository. The published site remains in the docs directory.

## Audits

- [audit823.md](audits/audit823.md): Sober audit823
- [ios27Sober.md](audits/ios27Sober.md): iOS 27 compatibility audit: Sober
- [reg93.md](audits/reg93.md): Sober build 83 to build 87 regression audit
- [reg94.md](audits/reg94.md): Sober build 83 to build 88 regression audit
- [state-machines-2026-11-06.md](audits/state-machines-2026-11-06.md): state machines, invariants and 19 reachable bugs, with a repro suite
- [state-machines-2026-11-06-review.md](audits/state-machines-2026-11-06-review.md): independent review of that audit: 6 confirmed, 11 minor, 2 rejected, with method changes for the fleet pilot
- [state-machines-2026-11-06-fixes.md](audits/state-machines-2026-11-06-fixes.md): fixes for the review's 19 in-scope claims, with regression tests and final suite results (J4 reworked after the first verify pass, its floor capped at now after the second, S1's undo rule reworked after the third and fifth, J1's split hardened after the fifth, J4's trim replaced by a read-time cut and J3's cleanup limited to days no closed run covers after the sixth, and the onboarding leftover run kept from protecting days after the seventh)
- [state-machines-2026-11-06-verify.md](audits/state-machines-2026-11-06-verify.md): independent check of those fixes (seventh pass): FAIL, J3's row cleanup now keeps the assumed days the onboarding leftover run covers, so for users onboarded 2026-08-24 to 2026-10-31 moving the start later no longer clears them (probe fails on HEAD, passes on 5d833d9); the sixth pass's finding is fixed, the other fixes hold, 282 tests green, and N1, S1 and N2 tests fail with their fixes reverted
- [presubmit-review-2026-11-07.md](audits/presubmit-review-2026-11-07.md): 1.3.8 pre-submit deep pass: 8 P1 fixed, P2 risks listed
- [2026-11-20-bug-ux.html](audits/2026-11-20-bug-ux.html): Bug and UX catalog, 2026-11-20: 8 bugs (1 high, 2 medium, 5 low; 4 confirmed), 19 UX items, October audit items rechecked. Catalog only, nothing fixed.

## Marketing

- [aso-plan.md](marketing/aso-plan.md): aso-plan.md: Sober Tracker ASO Plan
- [social-kit](marketing/social-kit/README.md): Sober TikTok, Instagram and YouTube kit: 42 posts, builder, profile copy

## QA

- [2026-10-11-bloom-day-zero](qa/2026-10-11-bloom-day-zero/): 1.3.3 goal step, trial page, Home cards, playbook and craving exit card captures, plus the CTA frame dump

## ASO

- [ASO pass index](aso/README.md): dated App Store metadata research and changes.
