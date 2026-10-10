# Sober: Google Play listing (en-US)

Source of truth for the Play Console store listing. Adapted from
`fastlane/metadata/en-US/` for the Android build (no Watch app; home-screen
widget; Google Play billing and cancellation wording). No prices in copy:
Play shows them.

## App name (27/30)

Sober: Sobriety Day Counter

## Short description (75/80)

Count sober days, ride out cravings, and grow a bonsai with every day you keep

## Full description

Sober helps you stay alcohol free with a clear day counter, a one-tap daily check-in, and a bonsai that grows with every sober day.

FREE, FOR EVERYONE
• Sober day counter with your longest streak and every sober day you have counted
• One-tap daily check-in with mood and a note
• Timeline calendar that shows the tree as it looked on any day
• A growing bonsai garden, with a new tree joining your grove each full year
• Craving mode: a few minutes of guided box breathing to ride out an urge, free and unlimited
• Slips don't erase your garden: your tree keeps half its growth, your history stays
• Money and calories kept so far
• The first health milestones, with sources
• Home-screen widget
• Private on your phone, no account

BLOOM+ (OPTIONAL)
• Your craving patterns: when they hit, what sets them off, and how long yours last
• The full health timeline, 13 milestones with sources
• Your year ahead: what you will have kept by this time next year
• Daily journal with prompts for hard days
• All 6 bonsai species: traditional, cascading, windswept, cherry blossom, Japanese maple, and black pine

Whether you are quitting drinking, cutting back, or building dry days, Sober keeps recovery simple and kind. Logging a slip is an ordinary entry, never a reset of everything you built.

Eligible new subscribers can try Bloom+ free for 7 days. Bloom+ is available monthly or yearly, plus a one-time lifetime option. Prices are shown in the app before you buy and vary by region. Payment is charged to your Google Play account. Subscriptions renew automatically until canceled; cancel any time in Google Play under Payments & subscriptions.

Sober is a wellness tracker, not medical care, diagnosis, or treatment. If stopping alcohol may put you at risk of withdrawal, contact a qualified clinician. In the US, the SAMHSA National Helpline (1-800-662-4357) is free, confidential, and open 24/7.

Privacy Policy: https://jackwallner.github.io/sober/android-privacy.html
Terms of Use: https://jackwallner.github.io/sober/android-terms.html

## Graphics

- App icon: `icon-512.png` (512 x 512), from the iOS icon (`scripts/make_android_icon.py`)
- Feature graphic: `feature-graphic.png` (1024 x 500)
- Phone screenshots: `screenshots/` (1080 x 1920), captured from the debug build
  with launch extras and composited by `scripts/play_screenshot_compositor.py`

## Store settings

- Category: Health & Fitness. Tags: addiction recovery, habit tracking.
- Contact email: jackwallner+st@gmail.com. Website: https://jackwallner.github.io/sober/
- Privacy policy: https://jackwallner.github.io/sober/android-privacy.html

## Products

RevenueCat project `proj15d6bf77` (Sober Android): Test Store app
`app0e47955aca`, Play app created after the Play package exists. Entitlement
`pro` (`entl67f6732b0f`), offering `android` (current, `ofrngf70313fafd`).

| Play product | Type | Base plan / offer | RevenueCat package |
|---|---|---|---|
| `com.jackwallner.sober.pro.monthly` | Subscription | base plan `monthly` (P1M), offer `trial-7d` (P1W free, new customers) | `$rc_monthly` |
| `com.jackwallner.sober.pro.yearly` | Subscription | base plan `yearly` (P1Y), offer `trial-7d` (P1W free, new customers) | `$rc_annual` |
| `com.jackwallner.sober.pro.lifetime` | One-time product | none | `$rc_lifetime` |

US prices follow the live iOS ladder ($9.99 / $29.99 / $69.99, verified in ASC
2026-08-16). Review Play's converted local prices before activating. The iOS
RevenueCat project `proj10cf6202` is untouched.

## Policy answers (from the code)

- Ads: no. App access: everything without an account. Reviewer access to
  Bloom+: long press Settings > About > Version, enter the private code
  (`SOBER_PLAY_REVIEW_CODE` in `~/.sober_credentials`), tap Unlock.
- Target audience: 18+ only (alcohol recovery).
- Content rating: references to alcohol in a recovery context; no violence,
  sexuality, gambling, user-generated sharing, or location.
- Health apps declaration: addiction and substance-use support (sobriety
  tracking, general wellness information with sources). Not a medical device;
  no Health Connect access.
- Data Safety: collected by the RevenueCat SDK only. Financial info > Purchase
  history; App activity > App interactions (purchase-screen counts, app-open
  counts, funnel step counts); Device or other IDs (RevenueCat's anonymous app
  user ID, not a hardware or advertising ID). Purposes: app functionality and
  analytics. Encrypted in transit. Not shared (RevenueCat is a service
  provider). Not optional. Deletion by email request. Sobriety records,
  journal, cravings and settings never leave the device.
- Notifications: optional reminders, permission asked only when the user turns
  them on (onboarding or Settings) or starts a trial.
