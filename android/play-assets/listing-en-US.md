# Sober: Google Play listing (en-US)

Source of truth for the Play Console store listing. Adapted from
`fastlane/metadata/en-US/` for the Android build (no Watch app; home-screen
widget; Google Play billing and cancellation wording). No prices in copy:
Play shows them.

## Listing text

Title, short and full description per locale live in
`metadata/android/<locale>/` (fastlane supply layout), uploaded with:

    fastlane supply --json_key <service account> --package_name com.jackwallner.sober \
      --metadata_path android/play-assets/metadata/android --track internal \
      --skip_upload_apk true --skip_upload_aab true --skip_upload_changelogs true --sync_image_upload true

Locales: en-US (default), en-GB/AU/CA/IN, de-DE, fr-FR/CA, es-ES/419/US, pt-BR.
ASO: titles lead with "Sober" plus the highest-intent local phrase (sobriety
day counter, alkoholfrei, sin/sem alcohol, jours sobres); short descriptions
open with the local "quit drinking". No prices, no em dashes, no medical claims.
Graphics are en-US only; other locales fall back to them.

## Graphics

- App icon: `icon-512.png` (512 x 512), from the iOS icon (`scripts/make_android_icon.py`)
- Feature graphic: `feature-graphic.png` (1024 x 500)
- Phone screenshots: `screenshots/` (1080 x 1920), captured from the debug build
  with launch extras and composited by `scripts/play_screenshot_compositor.py`,
  copied into `metadata/android/en-US/images/`. No paywall shot: prices vary
  by region and the preview store's prices would drift from Play's.

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

Android US ladder: $7.99 / $24.99 / $54.99, about 20% under the iOS ladder
($9.99 / $29.99 / $69.99), because Android users pay less per install
(decided 2026-10-10). Local prices are Play's conversion of the US price, then
the fleet PPP curve (`~/ios/pricing/refratio.json`) in the same 23 markets iOS
discounts. AR, AZ and UZ bill in USD on Play; ET is not billable. All set by
`scripts/play-products.py`. The iOS RevenueCat project `proj10cf6202` is untouched.

RevenueCat Play app `app4a2732350e` holds the Play service-account credentials
(the shared `revenuecat-service-account`, granted app-level access to Sober
only). Play products: `com.jackwallner.sober.pro.monthly:monthly`,
`com.jackwallner.sober.pro.yearly:yearly`, `com.jackwallner.sober.pro.lifetime`.

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
