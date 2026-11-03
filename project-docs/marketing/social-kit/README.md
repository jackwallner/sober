# Sober social kit

The Sober version of the Mahj Tips channel (`~/ios/growth/social-autopost`): 3 posts a day on TikTok, Instagram and YouTube, every post scheduled ahead, posted as the person who built the app.

## What's built

`python3 build_kit.py` writes everything to iCloud `Sober Social Kit/` (about 8 minutes; `--no-video` skips the Shorts):

| Path | What |
|---|---|
| `Day 01..14/<slot> - <id> <format>/1..5.jpg` | 42 TikTok photo carousels, 1080x1920, two weeks at 3 a day |
| `.../caption.txt` | TikTok caption, Instagram caption, YouTube title and description, pinned comment, reply line, sound |
| `Instagram/<id>/1..5.jpg` | The same carousels cropped to 1080x1440 (3:4) |
| `YouTube Shorts/<id>.mp4` | Each carousel as a 17 s slideshow Short under an original score, under 9.5 MB |
| `Profile/` | `avatar.png`, `youtube-banner.jpg`, `profile.txt` (handle, names, bios, links) |
| `Tracker.csv` | The post ledger: one row per slot, a column per platform for the scheduled date |

Content lives in `posts.py`: 7 formats x 6 posts (first 30 days, craving toolkit, what to say, sober math, evening swaps, milestones, restart kindly). Slide 4 is always the app, with two real 1.3.2 screenshots and the icon.

## Wave 2: the experiment (2026-11-02)

Research in `research-2026-11.md` set a 12-type test. Wave 2 fills it, in iCloud `Sober Social Kit/Wave 2/<type>/`:

| Type | Posts | Built by |
|---|---|---|
| 1 Day counter | N1-N6, tree at that day | `build_v2.py` |
| 4 Bonsai timelapse | T1-T8 videos, the app's real tree growing through 31 to 365 days | `video.py` |
| 5 Craving tools | R1-R4 box-breathing videos, plus wave 1 B posts | `video.py` |
| 6 POV | V1-V12, 7 s text videos | `video.py` |
| 7 Builder | K1-K6, the dev's design choices | `build_v2.py` |
| 8 Common question | Q1-Q6, 3 slides | `build_v2.py` |
| 9 Poll | P1-P6, A or B, 3 slides | `build_v2.py` |
| 10 Signs | S1-S6 | `build_v2.py` |
| 12 Milestone reveal | M1-M6, one tree style at day 1, 30, 100, 365 | `build_v2.py` |
| 13 Seasonal | H1-H12, Thanksgiving to Dry January, each with a schedule-after date | `build_v2.py` |
| 14 Dry January day | J01-J31, "Day N" with the tree at day N and a tip | `build_v2.py` |

Types 2, 3 and 11 use the wave 1 posts. Trees are the app's own `BonsaiView`, rendered headless by `Tools/BonsaiAudit` (`./frames.sh` fills `frames/`, gitignored). Only the traditional tree is free; the other five are Bloom+, and the copy says so.

`schedule.py` writes `Schedule.csv`: 63 posts over Nov 3 to 23 rotating the 12 types across slots, then the dated seasonal posts and the Dry January series. A type wins at 2x the account median views at 72h across its posts; after week 3, drop the bottom three types and double the top three.

## Wave 3 and the TikTok queue (2026-11-02)

The research pass (`research-2026-11b.md`) changed the plan: video first, since SoberTok's repeatable format is a 5 to 12 second text loop with real motion, and photo carousels get far less reach.

- `video3.py`: 21 motion loops (tree sways, push-in, drifting petals or stars, native white text boxes): "Ever notice...?" body-signal hooks (E), builder "ask the room" questions (A), a Friday POV (F) and wave 2's POVs re-cut with motion (V).
- `posts3.py` + `build_v3.py`: carousels in two new looks (night, plain text) and "who you become" identity hooks, each with a no-app cut.
- `tiktok/queue.py`: the 10-day lineup (24 videos, 6 carousels), staged into iCloud `Queue/` with each slot's caption and hashtags. `tiktok/schedule.mjs` fills TikTok Studio over DevTools, verifies every field, then schedules; `tiktok/cdp.mjs` is the DevTools client.
- Judge after 30 posts by median views per format: drop anything under 3k after two tries, make more of anything over 10k. Pause if 3 posts in a row sit under 20 views after 24 hours, and check Studio for an "ineligible for recommendation" flag.

## Rules

- Speak as the builder ("I built this"). Never invent a personal recovery story.
- Health lines stay inside `HealthBenefitCatalog` (NIAAA) with "many people" framing. Nothing treats, cures or diagnoses. Formats A and F carry the withdrawal safety line and the SAMHSA helpline.
- Positive hooks, no em dashes, no pictures of alcohol.
- Every CTA spells "Sober Sobriety Day Counter": it ranks the app #1 on the US App Store, while "sober" and "sober tracker" don't (checked 2026-11-02).
- TikTok: turn on More options > Disclose post content > Your brand on every post.
- Hashtags: #sobertok #sobercurious plus two topic tags matched to the hook (#hangxiety, #mocktails, #cravings). #sober and #soberjourney underperform.

## Slots

TikTok: 07:15, 16:15 and 18:30 America/Los_Angeles (05:30 instead of 07:15 on weekends), 45+ minutes clear of Mahj Tips' 06:30, 11:30 and 17:30. 16:15 and 18:30 PT are 7:15 and 9:30 PM ET, the evening craving peak.

## TikTok first (2026-11-02)

Login: `pro-login sober`, or the QR route (`tiktok.com/login/qrcode` on the 9226 Chrome, scanned from the TikTok app). jmbp2's display sleeps, which blanks the window; `caffeinate -u` over ssh wakes it.


TikTok only for now. Its own Chrome on jmbp2 (`com.jackwallner.sober-chrome`, DevTools 127.0.0.1:9226, profile `SoberSocialAgent`), kept apart from the @mahjtips social Chrome on 9225. Jack signs in once with `pro-login sober` from the Air. The kit's TikTok files (no Shorts or IG crops) are mirrored to jmbp2 `~/sober-social-kit/` so a fleet run can upload from there. Scheduling goes through TikTok Studio web (`tiktok.com/tiktokstudio/upload`, Photos tab), up to 10 days ahead.

## Setup (Jack, once)

1. Create the three accounts with the details in `Profile/profile.txt` (agents can't create accounts). Use a new Google account or a brand channel for YouTube; TikTok as a Business account.
2. Sign them in to the social Chrome on jmbp2, the same one Mahj Tips uses, so scheduling runs there.
3. YouTube: verify the channel by phone so description links are clickable and the daily upload cap lifts.

## Weekly refill (agent)

Same flow as Mahj Tips: schedule 21 posts a week per platform in the web schedulers (TikTok Studio, instagram.com create, YouTube Studio), always 7+ days ahead, and log each one in `Tracker.csv` before adding the next. Write more posts into `posts.py` and rebuild with `--only <ids>` before the 14 days run out.
