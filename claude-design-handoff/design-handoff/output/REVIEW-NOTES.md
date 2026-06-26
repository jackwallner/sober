# Review notes — Traditional bonsai, round 1

Created by designer (this batch). Engineer/PM: leave round-1 review comments below.

## Round 1 delivery (2026-05-15)

- 13 anchor SVGs at days `0, 1, 3, 5, 7, 10, 14, 21, 30, 60, 90, 180, 365`.
- `growth-schedule.json` covers all 366 days; anchors carry hand-tuned values, in-between rows linearly interpolate between bracketing anchors.
- `contact-sheet-traditional.png` shows all 13 anchors in one row at consistent baseline.

## Designer self-notes for next round

- Densify days **1–30** before any other work — that's the highest-engagement window and 3-day anchor spacing past day 10 still feels like a perceptible jump.
- Bark texture is currently driven by `trunkGnarl` (knuckle ellipses at trunk bends). It reads at 300pt but disappears below ~120pt. May want a secondary "trunk shading" param for smaller sizes.
- Autumn leaf flecks on `d180` / `d365` are small + scattered to avoid the "single orange ball" failure mode. If we want stronger seasonal interest, switch them to a tone parameter on whole clusters rather than dotted accents.
- Pot is **identical** across all 13 frames — confirmed by the baseline guide line in the contact sheet.

## Open questions for round 2

1. Are the **silhouette** changes between consecutive anchors strong enough? (d010 → d014 → d021 grows monotonically; verify with engineer once interpolation is wired up.)
2. Should `mossOnTrunk` start earlier (say day 60 instead of day 60-with-0.05)? Brand asks for "ancient" cues; the moss is currently very subtle until day 90+.
3. Do we want a **leaf-fall** stage between 180 → 365, or is the gradual autumn-fleck count enough?

## Round 1 review (engineer / PM — fill in)

> _Add comments here. Reference specific anchors as `d030`, `d365`, etc._

-
