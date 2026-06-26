# aso-plan.md — Sober Tracker ASO Plan

> Written 2026-06-25. App: **Sober Tracker - Alcohol Free** (ID `6768869215`, repo `~/sober`). Methodology: `~/Desktop/aso.md`.

---

## 0. TL;DR

- **Positioning:** alcohol-free day counter / sobriety tracker — NOT moderation drink-logging (Reframe/Sunnyside).
- **Anchor term:** `dry days` #76 (pop 12) — only pop>5 term with coverage.
- **HOLD metadata ~2 weeks** if Jun-26 keyword refresh still re-indexing (benchmark terms collapsed: sober tracker 177→1000, alcohol free 229→1000).
- **When stable:** keyword field removes moderation false-friends; adds abstinence cluster vocabulary.

---

## STEP 0 — Re-pull

Check whether `sober tracker`, `alcohol free`, `dry days` rankings stabilized post Jun-26 refresh before shipping.

---

## 1. Competitor tiers

| Tier | Apps |
|---|---|
| **WALL** | I Am Sober (181k★), Sober Time (39k★), Days Since/DayCount, Reframe (42k★) on moderation terms |
| **WINNABLE PEERS** | Dry Days by AlcoChange (745★), TRY DRY (2.8k★), Sober Days (142★), Clean Day (1.7k★), Soberly (48★) |
| **ADJACENT** | Days Since (multi-purpose), Nomo (multi-addiction) |

**SERP FAIL in current field:** `drink`, `less`, `log`, `diary`, `control`, `check` → Reframe moderation SERP. `habit` → generic habit wall. `app` → wasted slot.

---

## 2. US metadata change (staged — ship when stable)

**Keep title + subtitle** (subtitle correctly owns `dry days` anchor):
- subtitle: `Dry Days: Sobriety Counter` ✓

**Keywords:**
- OUT: `habit,app,log,diary,drink,less,control,check`
- IN: `abstinence,since,clean,january`

**Proposed field (98/100):**
`countdown,quit,drinking,cut,time,streak,recovery,daily,abstinence,since,clean,january,widget`

`widget` is **product-gated** if no home-screen widget — drop if feature absent.

---

## 3. Astro state (done 2026-06-25, tag migration complete)

**US:** 29 keywords · **global:** ~90. Moderation false-friends removed; wall terms re-added for ceiling tracking; legacy tags retired.

| Tag | Keywords |
|---|---|
| `deployed` | countdown, quit, drinking, cut, time, streak, recovery, daily, abstinence, since, clean, january, widget |
| `target` | dry days, dry january, alcohol countdown, sober countdown, sober app, quit drinking, abstinence tracker, apple watch sober |
| `wall` | sober tracker, i am sober, alcohol free, habit tracker, drink less, alcohol tracker |

---

## 4. Rollout

**Wait for re-index normalization**, then bundle with next build. Manual release. Monitor `dry days` weekly — defend #76 band.
