# App Store screenshots — Sober Tracker (iOS)

Produce exactly 6 finished PNGs and nothing else. No preamble, no
explanations, no alternates, no manifest, no follow-up questions.

## Canvas spec (every frame)

- **1320×2868 px portrait**, PNG, sRGB, no transparency. If exact pixels are
  impossible, match the 1320:2868 aspect ratio precisely at max resolution —
  never crop.
- Background: solid cream `#F6EFE0` (the app's own canvas color) for every
  frame so the set reads as one family.
- Headline: top of canvas, centered, set in a warm serif (New York / Georgia
  style — matches the app's serif day counter), ink `#1A1A18`, ~120 px,
  max 2 lines. Subline below it, sans-serif (SF Pro style), warm gray
  `#5B5648`, ~62 px, 1 line.
- Device: iPhone 16/17 Pro Max frame with the screen content, centered
  horizontally, ~74% of canvas height, bottom-anchored with the lower edge
  bleeding slightly off-canvas is fine. Subtle soft shadow. Same frame
  position on all 6 canvases.
- Accent allowed: moss green `#2F5B45` and sand `#C49C6C` only.
- Screen status bar on every recreated frame: **9:41**, full signal, full
  Wi-Fi, full battery. **Remove the "◀ TestFlight" breadcrumb** visible in
  every raw — it must not appear in any output.

## Source material

Raw device captures (1320×2868, same scale as output screens) are in
`claude-design/raw/`. The app's real design tokens are in
`Shared/Utilities/Theme.swift` (cream `#F6EFE0`, ink `#1A1A18`, moss
`#2F5B45`, sand `#C49C6C`, sky gradient `#D4E2E7→cream`). View source lives
under `Sober/Features/`. Recreate screens **pixel-faithful to the raw's
layout, typography, and art** — only the data changes where specified below.
The bonsai/garden artwork must be reproduced exactly in the raw's flat
vector style; do not restyle it.

## Frames, in display order

### 1. `store-1-day-counter.png` — from `raw-1-home-counter-grove.png`
Recreate the home screen faithful to the raw, with these data changes:
- Counter: **128** with **DAYS SOBER** beneath (same serif numeral style).
- Badge top-right: leaf icon + **Sapling** (single badge; drop the
  "Year 6 · Seedling" and "5 trees grown" badges).
- The tree: replace the small seedling with the **mature full bonsai** from
  `raw-2-full-year-celebration.png` (broad green canopy, curved trunk),
  planted in the same large pot. No mini grove trees on the ground shelf.
- Keep the "Switch" pill, the green **Check in for today / Log today sober
  and water your bonsai** button, and the Home/Timeline/Health/Journal tab
  bar exactly as in the raw.
- Headline: **Count every alcohol-free day**
- Subline: **Your sobriety counter — days, streaks, and a tree that grows**

### 2. `store-2-grow-garden.png` — from `raw-2-full-year-celebration.png`
Use the raw's layout as-is (it's already clean): grown bonsai, sparkle,
card reading **A Full Year / Your tree joins the grove / 365 days of
growth, complete. That's 5 trees in your grove — and a fresh sapling
begins.**, green Continue button. Only fix the status bar (9:41, remove
TestFlight breadcrumb).
- Headline: **Stay sober, grow a garden**
- Subline: **Every sober year plants another tree in your grove**

### 3. `store-3-calendar.png` — from `raw-3-timeline-calendar.png`
Recreate the Timeline screen with idealized data:
- Stats row: CURRENT **128** · LONGEST **128** · TOTAL **128**.
- Calendar: **June 2026**, days 1–10 each marked sober (soft moss-tinted
  cells like the raw's marked days), day 10 outlined as today, days 11–30
  unmarked.
- "Selected day" card: **Today / Day 128 · Sapling** with the small garden
  thumbnail (sky gradient, potted tree).
- Timeline tab active in the tab bar, as in the raw.
- Headline: **Your dry days at a glance**
- Subline: **A calendar of every sober day and streak**

### 4. `store-4-daily-checkin.png` — from `raw-4-daily-checkin.png`
Recreate the check-in section of the Timeline screen:
- Keep the "Selected day" card at top: **Today / Day 128 · Sapling**, garden
  thumbnail, caption beneath thumbnail: **↗ vs. yesterday: the crown
  stretched higher**.
- Check-in section: mood row (Rough / Low / OK / Good / Great with the
  raw's weather glyphs) with **Good** selected (moss highlight); note field
  showing placeholder **How did the day go?**; rows **✓ Log as sober**
  (moss) and **⚠ Log a slip** (the raw's muted red) exactly as in the raw.
- Headline: **One honest check-in a day**
- Subline: **Mood, a note, and room for slips — no shame, just progress**

### 5. `store-5-money-saved.png` — from `raw-5-progress-saved.png`
Recreate the "Your progress" sheet with idealized 128-day data:
- "Next up" list: **Half-Year Hero / Six months of sobriety.** with a
  progress ring, then **Diamond Discipline / 100 consecutive check-ins** with
  a filled checkmark.
- "Saved" card: **Money $2,560** (sub: $20 / day · $2,560 lifetime),
  **Calories 76,800** (sub: 600 / day), **Body fat 22 lb** (sub: ~3,500 cal
  per lb). Keep the raw's icons and row layout.
- Footer text and "Bonsai species" section header with the first species row
  (Traditional Bonsai, checked) peeking at the bottom, as in the raw.
- Headline: **See what you get back**
- Subline: **Money saved, calories skipped, milestones earned**

### 6. `store-6-choose-tree.png` — from `raw-6-species-picker.png`
Use the raw's layout as-is with two data fixes: badge top-right reads
**Sapling** only (drop "Year 6 · Seedling" and "5 trees grown"), and the
hero tree is the mature bonsai (as in frame 1) with no mini grove trees on
the shelf. Keep the full **Bonsai Species** grid (Traditional Bonsai ✓,
Cascading Bonsai, Cherry Blossom, Japanese Maple, Black Pine, Windswept
Bonsai) and the "Switch anytime…" copy.
- Headline: **Choose the tree you grow**
- Subline: **Six bonsai species — switch anytime, progress carries over**

## Output

Write the 6 files with exactly the filenames above, in display order,
1320×2868 each.
