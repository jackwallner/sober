# Sober Tracker — App Store Preview Frames

> **Audience:** Claude Design
> **Deliverable:** 6 marketing preview frames sized for the App Store iPhone 6.7" slot (1290 × 2796), each combining (a) one supplied raw simulator screenshot, (b) a headline + sub-copy band, and (c) brand-consistent background art.
> **Source screenshots:** `./screenshots/raw_*.png` (iPhone 17 Pro, 1206 × 2622, light-mode UI). Status bar already shows 9:41 / full signal / 100% battery — do not overpaint it.

This replaces the current live 1.1.4 screenshot set, which has two disqualifying defects: a **"◀ TestFlight" breadcrumb baked into the status bar** of two frames, and **incoherent seeded data** (one frame reads 345 days, the next 1,836, another "0 total"). Every number in the new raws derives from a single 128-day journey and agrees across frames — keep it that way; do not retouch any value inside the device screen.

---

## 1. Product One-Liner

**Sober Tracker** counts alcohol-free days and turns the streak into something you can see grow: a bonsai that develops as you stay sober, a calendar of every dry day, a timeline of health returning (NIAAA milestones), a private journal, and the money and calories you're not spending on drinking.

Audience: people who have decided to stop or cut back on alcohol and want a gentle, non-clinical daily companion — not a 12-step program, not a medical device. Skews toward the "sober-curious" and dry-challenge crowd as well as long-term abstinence.

Tone: **calm, warm, earned.** Encouraging without being preachy or clinical. Never shameful, never boastful. This is the emotional opposite of StatScout's sportsbook confidence — quiet and reassuring.

### Compliance (App Review 1.4.1) — read before writing copy
This is a wellness app, **not** a medical one. Marketing copy must **never** claim to treat, cure, prevent, or diagnose alcohol use disorder or any condition. Frame benefits as *tracking*, *support*, and *motivation*. The health timeline reflects general NIAAA-style recovery information the app displays; describe it as "see your body recover," not "we heal you." No before/after medical claims, no sobriety-as-treatment language.

---

## 2. Brand Visual System

The app is a warm, organic, cream-and-moss system — treat the frames as an extension of it, not a separate marketing universe. The opposite of a clinical white recovery app.

### 2.1 Color tokens (use exactly)

| Token | Hex | Usage in frames |
|---|---|---|
| `cream` | `#F6EFE0` | Primary background canvas behind the device — matches the in-app background |
| `moss` | `#2F5B45` | Primary headline band background; emphasis word on light bands |
| `mossLight` | `#4F8568` | Secondary accent, calendar fills, progress bars |
| `sand` | `#C49C6C` | Warm accent / underline flourish — use sparingly, never for whole words of copy |
| `warmWhite` | `#FFFDF9` | Card/sheet white inside screenshots |
| `ink` | `#1A1A18` | Primary headline text on cream/light bands |
| `inkOnDark` | `#FFFFFF` | Headline text on the moss band |
| `terracotta` | `#D9735C` | Reserved — do NOT use in marketing copy; it reads as "danger/relapse" in-app |

**No gradients beyond a single soft sky-to-cream one if needed behind the bonsai. No neon, no drop shadows beyond a soft device shadow. Flat, warm, organic.**

### 2.2 Type

- **Headline:** SF Pro Rounded or a warm humanist serif, Heavy/Bold, 64–80pt at 1290px width. The app's counter uses an italic serif ("128 DAYS SOBER") — a serif headline would tie the frames to that signature, but rounded-sans is acceptable if cleaner. Two lines max, deliberate line breaks.
- **Sub-copy:** SF Pro, Semibold, 30–34pt, one line where possible, in `textSecondary` warm gray on light or 80% white on moss.
- Headlines may emphasize **one** word — in `moss` on a light band, or `sand` on the moss band. Never two emphasis colors per frame.

### 2.3 Layout grid

Two stacked bands per frame. **Alternate band position across the set** (top / bottom / top …) so adjacent search-result thumbnails don't merge — this is the single biggest lever; the current set fails it by using one flat background everywhere.

```
┌─────────────────────────┐        ┌─────────────────────────┐
│  COPY BAND (top ~22%)   │   or   │                         │
│  Headline + sub-copy    │        │   DEVICE FRAME          │
├─────────────────────────┤        │                         │
│   DEVICE FRAME          │        ├─────────────────────────┤
│   (centered, ~76% h)    │        │  COPY BAND (bottom)     │
└─────────────────────────┘        └─────────────────────────┘
```

Device: black titanium iPhone Pro shell, single soft shadow (≤12px blur, 30%), no glare, no hand mockups, no Dynamic Island callouts.

**Background variety is mandatory.** Rotate the canvas behind the device across the set: cream, moss band-heavy, warm-white. No two adjacent frames share the same dominant field.

---

## 3. Frame-by-Frame Brief

Frames 1–3 are mandatory and carry the search-result thumbnail; 4–6 recommended.

### Frame 1 — Hero / Day Counter + Bonsai
- **Asset:** `raw_01_today.png` (128 DAYS SOBER, grown bonsai)
- **Headline:** `128 days.` / `Watch it grow.`
- **Sub-copy:** `Every alcohol-free day grows your bonsai.`
- **Emphasis:** "grow." in `moss`.
- **Layout:** Copy band **top**, cream canvas. The big italic "128" and the tree must remain fully visible — this is the frame that has to win the thumbnail, so lead with the number, not chrome.

### Frame 2 — Timeline / Calendar
- **Asset:** `raw_02_timeline.png` (128 current / longest / total; July filled 1–14)
- **Headline:** `Every dry day,` / `counted.`
- **Sub-copy:** `Your streak and calendar at a glance.`
- **Emphasis:** "counted." in `moss`.
- **Layout:** Copy band **bottom** so the 128/128/128 stat row and the filled calendar lead. (These three numbers agreeing is the fix for the old "0 total" frame — let them read first.)

### Frame 3 — Health Recovery Timeline
- **Asset:** `raw_03_health.png` (10/13 benefits, Blood Alcohol Clearing, Blood Sugar Stabilization…)
- **Headline:** `See your body` / `come back.`
- **Sub-copy:** `Recovery milestones, day by day.`
- **Emphasis:** "come back." in `moss`.
- **Layout:** Copy band **top**, warm-white canvas. NB compliance: "see your body come back" describes the app surfacing recovery information — do not escalate to "heal" / "cure."

### Frame 4 — Money & Calories Saved (Pro)
- **Asset:** `raw_06_paywall.png` (Bloom+ active: $2,560 saved, 76,800 calories avoided, 21.9 lb)
- **Headline:** `$2,560 back` / `in your pocket.`
- **Sub-copy:** `See what sobriety saves — money and calories.`
- **Emphasis:** "$2,560" in `moss`.
- **Layout:** Copy band **bottom**, moss-heavy canvas. This screenshot already carries big numbers — keep the added headline short so it doesn't compete.

### Frame 5 — Journal
- **Asset:** `raw_04_journal.png` (prompt of the day + three real entries)
- **Headline:** `A private place` / `to reflect.`
- **Sub-copy:** `Daily prompts and a journal only you can see.`
- **Emphasis:** "private" in `moss`.
- **Layout:** Copy band **top**, cream canvas.

### Frame 6 — Progress / Achievements
- **Asset:** `raw_05_stats.png` (Your progress: Half-Year Hero in 52 days, achievements, money/calories)
- **Headline:** `Milestones` / `worth keeping.`
- **Sub-copy:** `Achievements, savings, and what's next.`
- **Emphasis:** "keeping." in `moss`.
- **Layout:** Copy band **bottom**, warm-white canvas.

If a headline reads awkwardly, flag it and propose an alternative rather than guessing.

---

## 4. Output Specifications

- **Dimensions:** 1290 × 2796 px, PNG, sRGB.
- **Device shell:** iPhone 15/16/17 Pro (black titanium), single soft shadow ≤12px / 30%, no glow.
- **Filename convention:** `appstore_preview_<NN>_<slug>.png` (e.g. `appstore_preview_01_grow.png`).
- **Safe zone:** headline text ≥ 64px from any edge.
- **Export location:** `/Users/jackwallner/sober/fastlane/screenshots/en-US/` (overwrite; current set is stale).
- **Provide both:** (a) the 6 individual PNGs, (b) one contact-sheet PNG at 25% scale for review.

---

## 5. What NOT to do

- ❌ No medical/treatment/cure claims (App Review 1.4.1). Track and support, never heal.
- ❌ No `terracotta` in copy — it's the in-app relapse/danger color.
- ❌ No shame framing, no "before/after," no bottle/glass imagery.
- ❌ No flat single-background set — alternate band position AND canvas field across frames.
- ❌ No fake/marketing UI — every pixel inside the device frame comes from the supplied screenshot, unchanged. Crop only; do not retouch any number.
- ❌ No emojis, no "Available on the App Store" badge (the store adds it).
- ❌ No two emphasis colors per frame.

---

## 6. Reference

| File | What it is |
|---|---|
| `screenshots/raw_01_today.png` | Day counter + grown bonsai (hero) |
| `screenshots/raw_02_timeline.png` | Streak stats + filled July calendar |
| `screenshots/raw_03_health.png` | Health recovery timeline |
| `screenshots/raw_04_journal.png` | Journal with prompt + entries |
| `screenshots/raw_05_stats.png` | Progress sheet: achievements + savings |
| `screenshots/raw_06_paywall.png` | Bloom+ savings ($/calories/body fat) |

Reference winners (same house style, for tone/format calibration): StatScout (`~/baseball/claude-design/BRIEF.md`) and Vitals/Total Calories — both convert ~11% US search vs ~2% for the rest of the fleet. The three things they do that this set must also do: **alternating backgrounds**, **screens full of real coherent data**, and **an outcome headline with one emphasis word**.
