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

## Rules

- Speak as the builder ("I built this"). Never invent a personal recovery story.
- Health lines stay inside `HealthBenefitCatalog` (NIAAA) with "many people" framing. Nothing treats, cures or diagnoses. Formats A and F carry the withdrawal safety line and the SAMHSA helpline.
- Positive hooks, no em dashes, no pictures of alcohol.
- Every CTA spells "Sober Sobriety Day Counter": it ranks the app #1 on the US App Store, while "sober" and "sober tracker" don't (checked 2026-11-02).
- TikTok: turn on More options > Disclose post content > Your brand on every post.

## Slots

06:30, 11:30 and 17:30 America/Los_Angeles, every day, all three platforms. Day N slot 1 goes at 06:30, and so on.

## TikTok first (2026-11-02)

TikTok only for now. Its own Chrome on jmbp2 (`com.jackwallner.sober-chrome`, DevTools 127.0.0.1:9226, profile `SoberSocialAgent`), kept apart from the @mahjtips social Chrome on 9225. Jack signs in once with `pro-login sober` from the Air. The kit's TikTok files (no Shorts or IG crops) are mirrored to jmbp2 `~/sober-social-kit/` so a fleet run can upload from there. Scheduling goes through TikTok Studio web (`tiktok.com/tiktokstudio/upload`, Photos tab), up to 10 days ahead.

## Setup (Jack, once)

1. Create the three accounts with the details in `Profile/profile.txt` (agents can't create accounts). Use a new Google account or a brand channel for YouTube; TikTok as a Business account.
2. Sign them in to the social Chrome on jmbp2, the same one Mahj Tips uses, so scheduling runs there.
3. YouTube: verify the channel by phone so description links are clickable and the daily upload cap lifts.

## Weekly refill (agent)

Same flow as Mahj Tips: schedule 21 posts a week per platform in the web schedulers (TikTok Studio, instagram.com create, YouTube Studio), always 7+ days ahead, and log each one in `Tracker.csv` before adding the next. Write more posts into `posts.py` and rebuild with `--only <ids>` before the 14 days run out.
