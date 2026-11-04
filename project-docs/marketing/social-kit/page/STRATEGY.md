# The sobriety page (2026-11-04)

**Update, same day:** Jack rejected the plain-type look and the advice hooks in `posts.py` as forgettable, then approved the footage samples. The direction is now `hooks-v3.md`: short videos over real footage, with visceral first lines that carry their own drinking cue, so a random scroller knows what it's about, then open a door. `posts_v3.py` holds the posts and `build_v3.py` renders them to iCloud `Page v3/`.

**No app in this phase.** Jack wants the page grown first: no app slides, no app in captions, disclosure off. The app sections below apply only once he says to start. The rules on sourcing and honesty still apply; "Look", "Voice" and "Mix" are replaced.

Replaces the app-led kit after Jack's review: nobody on TikTok knows the app or is motivated by a plant. This is a sobriety page that happens to be run by the app's maker.

## The rules

- A viewer who never hears of the app still gets something useful from every post.
- The bonsai never appears as content or motivation. The tree shows up only if it's part of a real app screen, and the app slides use crops without it.
- 4 of the first 32 posts carry one app slide, and the first is on Day 6. Each slide sits next to the exact problem the post just solved, in the same voice and type, one before the close.
- The app is named only where it is on the slide. Every other caption leaves it out.
- App slides say "We built": it's our app and the page says so. The bio also says so.
- Turn on Your brand disclosure on app-slide posts. Leave it off on the other posts, since they promote nothing.

## Voice

- Second person, plain, warm. A friend who has read the research.
- Never tell a first-person recovery story or invent a testimonial. The page has no story of its own.
- Positive statements. No "this, not that" lines.
- Health facts need a named source and "many people" framing. Nothing treats, cures or diagnoses. Quit-related posts carry the doctor line, and hard ones carry the SAMHSA helpline.
- No alcohol on screen.

## What the page posts

| Type | What | Examples |
|---|---|---|
| Plans | Save-worthy, tied to a real moment | Friday hour by hour, 3 weeks to Thanksgiving |
| Scripts | Words to steal, as message bubbles | Answers to "why aren't you drinking?" |
| Insight | One sourced number at a time | Gallup's 54%, cravings peak near 9 PM, drink sizes |
| Topical | What's happening this week | Sober October ended, clocks changed, football, Friendsgiving |
| Kindness | Hard moments | The 24 hours after a slip |
| POV and questions | Short text videos | Friday night in, "what did you think was normal?" |
| Tools | Use it right now | 30-second breathing guide |

## Look

Plain type on black or white, big and left-aligned, kept in TikTok's safe area. Bubbles, numbers and checklists add variety. Videos use the native white text box over original moving scenes. No AI images, so no AI label.

## Mix and schedule

3 a day in the existing slots: 7:15 AM, 4:15 PM and 6:30 PM PT, 5:30 AM on weekends. 21 carousels and 11 videos, staged by `page/slots.py`.

## Judging it

- Pause rule stays: stop if 3 posts in a row sit under 20 views after 24 hours, and check Studio for an "ineligible" flag.
- After 30 posts compare the post types by median views and by saves plus shares per view.
- App slides: watch profile visits and App Store first-time downloads on those days. Add an app slide more often only if the app-slide posts hold their reach.

## Profile

- Display name: Sober Daily
- Handle: see `page/profile.txt`
- Bio: Sobriety tips for real life. Run by the maker of the Sober app.
- Avatar: `Profile/avatar-page.png`

## Sources

- Gallup 2026 alcohol poll, via [UPI](https://www.upi.com/amp/Top_News/US/2026/08/20/alcohol-consumption/7021787273526/) and [Vinetur](https://www.vinetur.com/en/20260820105871/gallup-finds-54-of-us-adults-drink-alcohol-tying-a-record-low.html)
- [NIAAA standard drinks](https://rethinkingdrinking.niaaa.nih.gov/how-much-too-much/whats-standard-drink)
- [NIAAA, handling urges](https://rethinkingdrinking.niaaa.nih.gov/tools/worksheets-more/how-stop-alcohol-cravings)
- [NIAAA, tips to try](https://rethinkingdrinking.niaaa.nih.gov/thinking-about-change/tips-try)
- [Craving timing study, PMC9246905](https://pmc.ncbi.nlm.nih.gov/articles/PMC9246905)
- Alcohol and sleep reviews: [PMC3083467](https://pmc.ncbi.nlm.nih.gov/articles/PMC3083467), [PMC4427543](https://pmc.ncbi.nlm.nih.gov/articles/PMC4427543/)
- Niche format research: `research-2026-11b.md`
