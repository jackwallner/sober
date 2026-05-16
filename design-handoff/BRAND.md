# Brand

## Positioning

Calm. Patient. Earned. **Not** clinical, not gamified-loud, not preachy. The user is doing hard work; the app is the quiet companion that notices.

Think: a well-kept garden journal, not a fitness tracker.

## Voice

- Short sentences. Plain words.
- Second person ("You've earned…") not first.
- Never use the word "addiction" in UI copy. "Sobriety," "streak," "day," "journey" are fine.
- No exclamation marks except in the unlock-celebration moment.
- No emoji in copy.

## Palette (extracted from `Shared/Utilities/Theme.swift`)

| Token             | Hex (approx) | Use                                  |
|-------------------|--------------|--------------------------------------|
| `brandPrimary`    | `#51 9E 73`  | Sage green. Primary buttons, accents.|
| `brandSecondary`  | `#7B C68C`   | Fresh green. Gradient pair.          |
| `accent`          | `#F2 C773`   | Warm sand. Celebration sparkle.      |
| `streakFlame`     | `#FF 8C 1A`  | Streak heat (used sparingly).        |
| `success`         | `#33 B873`   |                                      |
| `warning`         | `#FF B333`   |                                      |
| `danger`          | `#F2 5C 5C`  |                                      |

Garden-scene specific:
- Sky gradient: `#AD D9 F2 → #EB F5 DB` (top → bottom)
- Default dirt: `#8C 6B 47 → #73 52 33`

A machine-readable copy lives at `reference/theme-palette.json`.

## Typography

- System font (SF) everywhere. Rounded design for big numbers (`Theme.bigNumber(_:)`).
- No custom font budget for v1.

## Illustration style

- **Flat, painterly.** Light noise/grain ok. No outlines unless deliberate.
- **3–5 colors per illustration max.** Use palette tokens where possible.
- **Slight asymmetry.** Bonsai are *not* mirror-symmetric — they have character.
- Background: transparent. We composite on `skyGradient` at runtime.
- No drop shadows in the SVG itself; we add them in SwiftUI if needed.

## Anti-patterns

- ❌ Cartoon faces on plants.
- ❌ Sparkle particles in the base art (we animate those in code).
- ❌ Generic stock-photo trees.
- ❌ Color outside the palette without a flagged reason.
