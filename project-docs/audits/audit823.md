# Sober audit823

Date: 2026-08-23

Scope: Sober only, repository at /Users/jackwallner/sober. This is a fresh max-reasoning rerun. The audit is read-only and this file is the only requested output.

Focus: downloads, App Store conversion, trial starts, purchase flow, RevenueCat instrumentation, ratings and review funnel, onboarding and product UX, native paywall experiments, website and legal consistency, crash and regression detection, and Cursor, Claude, and Codex documentation hygiene.

Compliance boundary: Sober is a health and wellness tracker. Recommendations below must not turn the product into a diagnostic, treatment, cure, withdrawal-management, or disease-prevention product. Copy about health outcomes must remain educational, sourced, variable, and clearly non-personalized. The existing safety language about seeking qualified clinical help when stopping alcohol could be medically risky should remain and be reviewed by the appropriate owner.

## 0. Executive verdict

Sober has a coherent free-to-paid product shape, a relatively strong privacy posture, a real contextual paywall system, and a review funnel that waits for positive moments. The current repository also shows recent focused work on trial disclosure, reminder permission, paywall rendering, and purchase lifecycle tests.

The highest-risk problems are release and evidence consistency, not a lack of ideas:

1. The live App Store Connect evidence observed in the signed-in session is iOS version 1.2.8 in READY_FOR_DISTRIBUTION, while the repository is prepared for marketing version 1.3.0, build 76. Local ASC state files still say live 1.2.6 and draft 1.2.7. This makes it easy for an agent or reviewer to reason from the wrong release.
2. App Review instructions are stale. They describe a four-tab app, a commitment step that current onboarding does not show, and monthly and lifetime prices that do not match the current local StoreKit test configuration. This can directly impair review and makes release handoffs unreliable.
3. Data persistence failure handling can delete the on-device store and fall back to memory. Saves are often ignored with try-question-mark behavior. There is no durable remote signal for a recovery, failed save, crash, hang, or broken purchase flow. A live regression spike may therefore be invisible until reviews or support reports appear.
4. Health benefit and weight-related language is more deterministic than the product safety posture supports. The in-app catalog and landing page contain phrases such as blood sugar stabilization, liver fat reduction, full body recovery, and pounds of body fat. Existing disclaimers help, but they do not remove the need for a copy and compliance review.
5. Trial analytics are not yet a trustworthy event stream. Trial CTA counts include lifetime and other non-trial purchases, local trial-claimed state is declared but never written, conversion attributes are uploaded only on background, and there are no explicit durable events for trial conversion, expiration, renewal, cancellation, dismissal, or restore outcome.
6. The native paywall has good experiment surfaces, but package selection, entry context, eligibility, notification permission, and purchase outcomes are not consistently attributed. The current code needs a release QA matrix before interpreting any A/B result.
7. The code is more current than the agent-facing documentation. CLAUDE.md has an old entitlement name, old feature paths, and an incomplete funnel description. Design handoffs and ASO notes contain older product rules. There is no root README, while archive documentation points agents to one.

Recommended order:

- P0: align the release evidence and App Review instructions before any submission or external review.
- P0: review health and landing copy for non-deterministic wellness language.
- P1: add a durable operational signal for data-store recovery and important save failures, then add crash and hang monitoring outside the app.
- P1: make trial and purchase measurement semantically correct and release-safe.
- P1: exercise the full native paywall and onboarding matrix on real devices and StoreKit test configurations.
- P2: run controlled activation and paywall experiments with clear guardrails.
- P2: establish a single agent documentation index and mark historical material visibly.

## 1. Evidence register and confidence

The labels below separate what was observed from what should be tested.

| ID | Evidence | Source and confidence |
| --- | --- | --- |
| E1 | Local source and configuration | Repository files and symbols listed throughout this document. High confidence for the checked-out tree. |
| E2 | Live ASC status | Signed-in App Store Connect app list observed on 2026-08-23: Sober: Sobriety Day Counter, app ID 6768869215, iOS 1.2.8, READY_FOR_DISTRIBUTION. High confidence for that session and timestamp. |
| E3 | RevenueCat project identity | Sober project was visible in the signed-in RevenueCat context, project short ID 10cf6202, production mode. High confidence for identity. Sober-specific dashboard metrics and offering configuration were not captured. |
| E4 | Historical conversion baseline | docs/conversion-baseline-1.2.1.md, generated 2026-07-26. High confidence as a local historical report, low confidence as a current KPI because the sample is small and privacy-thresholded. |
| E5 | Historical ASO notes | docs/astro-aso-setup.md, docs/aso-plan.md, and scripts/.astro-app.json. Useful for context, not proof of current ranking or current metadata. |
| I1 | Likely conversion or release risk | Inference from code paths, stale documents, and missing telemetry. Validate using the tests listed in each section. |
| N1 | Not observed | No current Sober-specific live rating count, current Sober-specific RevenueCat trial or revenue report, or crash dashboard was available in the checked repository or captured context. No numbers are invented below. |

## 2. Product and release identity

### 2.1 Current local product shape

Evidence:

- CLAUDE.md describes an iOS and watchOS alcohol-specific sobriety tracker with a day counter, calendar, virtual garden, health-benefit timeline, journal, achievements, money and calories saved, and a RevenueCat-gated Pro tier.
- project.yml declares iOS 17.0, watchOS 10.0, Swift 6.0, Xcode 16, and XcodeGen 2.38.
- Local bundle IDs are com.jackwallner.sober, com.jackwallner.sober.watch, and com.jackwallner.sober.widgets.
- App Group is group.com.jackwallner.sober.
- The current root flow is SoberApp to RootView to OnboardingView or MainTabView.
- Current MainTabView in Sober/App.swift has Home, Timeline, Health, Journal, and a Bloom+ or Upgrade tab.
- SubscriptionService.swift uses the named entitlement Sober Tracker - Alcohol Free Pro, with a fallback that accepts any active entitlement.
- The current local project says marketing version 1.3.0 and project version/build 76.

Inference:

The repository represents a release candidate or staged state ahead of the live 1.2.8 binary. The audit should not assume that behavior in the repository is behavior currently experienced by live users. Every implementation handoff should identify whether a finding applies to live 1.2.8, staged 1.3.0 build 76, or both.

Validation:

1. In ASC, record the live version, build number, release date, phased release status, and current metadata snapshot in a dated file that is clearly labeled as an observation.
2. In the next release branch, record the exact commit, marketing version, build, and ASC build before testing.
3. Verify the binary's CFBundleShortVersionString and CFBundleVersion match the release record.
4. Do not use scripts that bump, commit, push, upload, or mutate ASC as part of a read-only audit.

### 2.2 Release evidence drift

| Evidence | Current value |
| --- | --- |
| Live ASC version observed | 1.2.8, READY_FOR_DISTRIBUTION |
| Local project.yml marketing version | 1.3.0 |
| Local project.yml build | 76 |
| scripts/.asc-state.json liveVersion | 1.2.6 |
| scripts/.asc-state.json draftVersion | 1.2.7 |
| scripts/.asc-state.json updated | 2026-08-17 |
| docs/index.html schema softwareVersion | 1.2.6 |
| docs/astro-aso-setup.md app naming | Sober Tracker - Alcohol Free |
| Current en-US App Store metadata file name | Sober: Sobriety Day Counter |

Priority: P0 for release operations.

Evidence: The values above are in project.yml, scripts/.asc-state.json, docs/index.html, docs/astro-aso-setup.md, and fastlane/metadata/en-US. The live ASC value was observed in the signed-in session.

Impact:

- An implementer can fix the repository and believe the live app has the fix.
- A reviewer can follow stale steps and fail to reach the intended trial or tabs.
- A release automation script can target an old draft version.
- Landing-page structured data can expose an old version to search engines.
- Conversion reports can be incorrectly attributed to the wrong release.

Action:

Create one release evidence record per submission with app ID, live version, candidate version, build, commit, metadata commit, price snapshot, offering snapshot, and test date. Make stale state files either generated artifacts with a freshness rule or move them under a clearly dated archive. Do not make the audit file itself the source of truth for release state.

Validation:

- Read-only ASC check confirms the candidate build and live version.
- A static check fails if project.yml, .asc-state.json, landing schema, and release notes disagree without an explicit staged or historical label.
- A manual reviewer follows App Review notes against the candidate binary.

## 3. Priority queue

| Priority | Finding | Evidence | Likely effect | Concrete next action |
| --- | --- | --- | --- | --- |
| P0 | App Review notes are stale on tabs, onboarding, and price | fastlane/metadata/review_information/notes.txt versus OnboardingView.swift, App.swift, and Sober.storekit | Review friction, failed review, misleading handoff | Rewrite notes for the exact candidate build and test them from a clean install |
| P0 | Live, local, ASC-state, and website versions disagree | E2, project.yml, scripts/.asc-state.json, docs/index.html | Wrong regression assumptions and stale public evidence | Establish a release evidence record and freshness check |
| P0 | Deterministic health and weight claims need compliance review | Shared/Models/HealthBenefitCatalog.swift and docs/index.html | App Review, trust, and health-wellness compliance risk | Rewrite or source-review the claims with variable educational framing |
| P1 | Store corruption recovery can delete the local store and saves are silently ignored | Shared/Services/DataService.swift | Lost check-ins, journal entries, settings, and invisible incidents | Preserve before recovery, surface state, count events, and test migration/corruption |
| P1 | No remote crash, hang, or production regression signal is present | No MetricKit, Crashlytics, Sentry, Bugsnag, or equivalent reference found; Console logs only | Multi-user crash spikes may be discovered late | Add an external crash and hang monitor, plus a release watch checklist |
| P1 | Trial events are semantically incomplete | Shared/Services/ConversionDiagnostics.swift and SubscriptionService.swift | Trial start and conversion rates cannot be trusted | Split trial events from purchase events and persist outcome timestamps |
| P1 | Trial-claimed local state is declared but never written | SubscriptionService.swift trialClaimedKey/hasClaimedTrial and repo-wide references | Passive nudge gating can reoffer or drift | Use one canonical trial state, add tests for claimed, active, expired, and converted |
| P1 | RC attributes sync only on background and lack entry/package context | SubscriptionService.syncConversionAttributes and trackPaywallImpression | Crash or force-quit sessions disappear; experiments are not attributable | Add bounded event queue or durable snapshots and context attributes |
| P1 | Paywall needs a full release QA matrix | PaywallView.swift, TrialOfferSheet.swift, NotificationService.swift | Broken disclosure, inaccessible CTA, wrong package, or reminder promise | Test devices, locales, Dynamic Type, denied notifications, pending purchase, restore, and failure |
| P2 | Onboarding asks optional financial and calorie inputs before the first core success | OnboardingView.swift | Extra friction before day-counter activation | Experiment deferred inputs against current flow |
| P2 | Paywall has many good A/B surfaces but no variant contract | PaywallView.swift and TrialOfferCoordinator | Noisy tests or conclusions that mix entry types | Define variant, exposure, eligibility, primary metric, and guardrails first |
| P2 | Review funnel has no remote prompt outcome metrics | ReviewPromptTracker.swift and ReviewPromptSheet.swift | Cannot tune timing or detect fatigue | Record bounded prompt outcome and correlate with app version and positive moment |
| P2 | Support page and feature docs lag legal pages and current source | docs/support.html, docs/terms.html, docs/privacy-policy.html | Customer confusion and agent misimplementation | Put last-reviewed dates and source links on every agent-facing doc |
| P2 | Agent docs use old entitlement and feature structure | CLAUDE.md, design-handoff, docs/aso-plan.md | Cursor, Claude, and Codex implement against stale rules | Create a current source-of-truth index and archive historical plans |
| P3 | No root README despite archive pointing agents to it | archive/README.md and root file list | Poor discovery for new agents | Add a root README or change archive guidance in a future docs-only task |
| P3 | Dead or duplicate state keys increase maintenance risk | SubscriptionService.swift and TrialLifecycle.swift | Future fixes may update the wrong state machine | Remove or clearly deprecate old keys after tests confirm no migration need |

## 4. Current user and purchase flow

### 4.1 Reconstructed flow

1. SoberApp configures RevenueCat on a device, skips production RevenueCat configuration in a simulator, sets the notification delegate, and starts WatchConnectivity.
2. RootView shows OnboardingView if settings are absent or onboarding is incomplete.
3. Onboarding step 0 presents the day-counter and private on-device value proposition.
4. Step 1 collects the sobriety start date.
5. Step 2 optionally collects daily spending and calories, with a projection.
6. resolveTrialAndContinue persists the initial settings, resolves RevenueCat offering and introductory eligibility, then goes to the trial screen if eligible.
7. The trial screen presents benefit bullets, trial length, charge date, and a direct trial CTA. A user can continue with the free version through a confirmation.
8. A purchased result finishes onboarding. A pending result also finishes onboarding with a pending message. Errors allow retry or free continuation.
9. MainTabView exposes the free core and Bloom+ or Upgrade tab.
10. Contextual trial or paywall pitches can arise from onboarding, a locked garden species, Health, Journal, savings, progress, growth, check-in milestones, passive use, or the Bloom+ tab.
11. PaywallView loads the RevenueCat current or default offering, selects yearly first when available, offers monthly and optionally lifetime, presents a trial timeline when eligible, and handles purchase and restore.
12. TrialLifecycle and NotificationService store trial end state, show a final-stretch recap, and attempt a reminder two days before the trial ends.
13. ReviewPromptTracker waits for positive moments and gates the native review prompt or direct App Store review link.

### 4.2 Strong parts worth preserving

- Free value is visible before purchase: counter, daily check-in, calendar, basic garden, and past savings are not all hidden.
- The onboarding trial screen derives trial duration and charge date from the package rather than assuming seven days in the UI.
- Paywall copy distinguishes trial, renewal, and lifetime purchase.
- The native paywall uses a ScrollView, which addresses earlier clipping risk.
- The app asks for notification permission when it needs a reminder, rather than pretending a reminder is guaranteed.
- Review prompting is delayed until positive moments and has a feedback route for users who are not satisfied.
- Journal content remains local, and the review funnel does not ask for a review directly after a failed purchase.
- Simulator configuration avoids the production RevenueCat key, reducing fake production customers during local testing.

### 4.3 Main flow risks

#### Onboarding persistence before trial resolution

Evidence: OnboardingView.resolveTrialAndContinue calls persistSetup before the eligibility and package resolution completes. finishOnboarding calls persistSetup again.

Inference: This is defensible for preserving user input, but an interrupted eligibility resolution can leave a partially initialized journey. Validate relaunch after force quit, no network, RevenueCat unavailable, and StoreKit pending purchase.

Validation:

- Start onboarding, enter non-default spend and calories, kill the app during package loading, relaunch, and verify values and onboarding step.
- Make a purchase pending, relaunch, and verify the app neither promises Pro prematurely nor traps the user in onboarding.
- Verify that a user who skipped the trial does not receive a duplicate post-onboarding paywall merely because the persistence call happened before trial resolution.

#### Pending purchase handling

Evidence: startOnboardingTrial maps a pending purchase to a pending message and finishes onboarding.

Inference: The user can enter the free shell while the transaction is unresolved. This may be the right escape hatch, but entitlement refresh and the next surface need to be deterministic.

Validation:

- Use StoreKit testing to produce a pending transaction.
- Kill and relaunch before resolution.
- Verify entitlement refresh, notification scheduling, paywall state, restore behavior, and no duplicate purchase request.
- Verify a pending user sees an accurate status that does not imply a completed trial or purchase.

#### Optional inputs before first success

Evidence: Step 2 asks for spending and calorie inputs before the trial or free version is selected. The values are optional, but the flow still inserts a screen between date and activation.

Inference: This may lower onboarding completion for users who only want a day counter. The historical conversion report showed only 2 free trial starts from 91 first-time downloads in a 2026-06-20 through 2026-07-25 cohort, but it cannot establish causality and is not a current KPI.

Recommendation:

Test a deferred-input variant:

- Step A: start date, then immediate first check-in or counter.
- Step B: trial offer after the first successful core action.
- Step C: spend and calories in Bloom+ setup or after the first meaningful moment.

Guardrails: onboarding completion, first check-in rate, trial start rate, trial-to-paid, D1 and D7 retention, journal creation, refund rate, support contacts, and negative review rate.

## 5. Downloads and App Store conversion

### 5.1 Current en-US metadata

Evidence from fastlane/metadata/en-US:

| Field | Current value or observation | Assessment |
| --- | --- | --- |
| Name | Sober: Sobriety Day Counter | Within the 30-character limit used by the local validator |
| Subtitle | Quit Drinking, Grow Each Day | Within the 30-character limit |
| Keywords | alcohol, tracker, diary, cravings, relapse, calendar, watch, private, abstinence, recovery, streak, checkin | Within the 100-character limit, 12 tokens |
| Promotional text | Private sober tracking with a growing bonsai, recovery milestones, journal, and savings. Try every Bloom+ tool free for 7 days. | Strong feature and trial framing, but verify that the exact trial is still offered in all target territories |
| Description | Free counter, check-in, calendar, virtual garden, local storage, optional Bloom+ timeline, journal, milestones, savings, species, Watch, and widgets | Broad and feature-rich; needs current feature and compliance review |
| Support URL | https://jackwallner.github.io/sober/support.html | Must be checked for deployed content and redirect behavior |
| Marketing URL | https://jackwallner.github.io/sober/ | Must be checked against the canonical URL in the page |
| Privacy URL | https://jackwallner.github.io/sober/privacy-policy.html | Must be checked for deployed content |
| EULA link in description | Apple Standard EULA URL | Consistent with current ASC copy, but decide whether a custom terms link is also needed |
| Release notes | Generic behind-the-scenes improvements and fixes | Low conversion value and weak release transparency |

Evidence: 50 actual locale directories are present. review_information is not a locale and should not be counted as one. en-AU, en-CA, en-GB, and en-US currently share the same English core copy. Localized fields exist broadly, but translation quality and exact pricing/trial wording were not independently verified in this audit.

Recommendation:

- Preserve the clear core promise, but put the first user outcome earlier in the description: start a private counter, check in in seconds, and see progress without an account.
- Make the free versus Bloom+ boundary concrete and current. The phrase “every Bloom+ tool” is only safe if every listed tool is actually included and eligible in every supported market.
- Test a subtitle that emphasizes private daily progress against the current growth framing. Do not change title, subtitle, keyword, and landing message in the same experiment if download attribution matters.
- Add a release note that names user-visible improvements when a release actually changes onboarding, trial disclosure, reminders, or paywall behavior.
- Review keywords for duplicated concepts and for terms that could imply treatment or recovery guarantees. Keep search language aligned with the actual user task.
- Validate every translated trial, renewal, lifetime, and wellness statement with a native reviewer. Do not machine-translate safety disclaimers without review.

Validation:

1. Run scripts/validate-asc-metadata.py and extend the future scanner to all 50 locales, not only en-US.
2. Check name, subtitle, keywords, description, promotional text, URLs, and release notes for each locale.
3. Check for stale prices, stale version references, missing trial disclosures, non-working links, unreviewed medical-sounding claims, and literal translation artifacts.
4. Compare metadata to the binary and to the landing page using a generated normalized feature vocabulary.
5. Use ASC read-only data to compare product page views, impressions, downloads, trial starts, and proceeds by version, territory, and source after the next release.

### 5.2 Historical download evidence

Evidence: docs/conversion-baseline-1.2.1.md reports a privacy-thresholded cohort generated 2026-07-26:

- 91 first-time downloads from 2026-06-20 through 2026-07-25.
- 2 free trial starts, 2.2 percent of first-time downloads.
- 2 trial-to-paid conversions, 100 percent of the 2 observed starts.
- 0 direct full-price starts.
- 3 paid purchase rows and 49.46 dollars in proceeds.
- 547 thresholded impressions, 5 product page views, and 24 sessions with a 41.5 second average.
- Download sources: 65 App Store search, 17 web referrer, 8 app referrer, 1 browse.
- Versions in that report include 1.1.3, 1.1.4, 1.1.5, 1.0, 1.1.1, 1.2.1, and 1.2.0.

Interpretation:

- Trial starts were the weak point in that small historical cohort, but the sample is too small to conclude that the paywall or onboarding caused it.
- The observed paid conversion rate is not reliable enough to scale because the denominator is only two trial starts and privacy thresholding can suppress cells.
- Search was the dominant identified download source. The landing page and App Store metadata should therefore use the same search intent and first-session promise.
- The report predates the current paywall and onboarding work. Rebaseline after the live 1.2.8 or candidate 1.3.0 release.

Required current report:

For each version and territory where ASC permits reporting, capture:

- impressions to product page view rate
- product page view to download rate
- download to onboarding completion
- onboarding completion to trial offer reached
- trial offer reached to trial CTA
- trial CTA to active trial
- active trial to first paid period
- active trial to cancellation or expiration
- renewal and refund outcomes
- source, device, locale, and paywall entry

Do not expose small cells or personal data in a shared agent report.

### 5.3 Landing page and structured data

Evidence from docs/index.html:

- The page title is Sober: Sobriety Day Counter for iPhone and Apple Watch.
- The page contains app ID 6768869215 and App Store download links.
- JSON-LD offers include 0 dollars, 9.99 dollars monthly, 29.99 dollars yearly, and 69.99 dollars lifetime.
- The JSON-LD softwareVersion is 1.2.6, stale against live ASC 1.2.8 and local 1.3.0.
- The canonical in the page is https://jackwallner.com/ios/sober/, while ASC metadata URLs use the github.io domain.
- The page says 13 health benefits backed by NIAAA, CDC, and AHA, including blood sugar stabilization at 24 hours, liver health improvement at 30 days, and full recovery at 365 days.
- The page says “calories avoided” and displays pounds of body fat in the Bloom+ area.
- The page says “no analytics, no ads, no third-party accounts beyond StoreKit.” This audit does not treat the RevenueCat disclosure as an inconsistency because the user explicitly excluded that review.

Priority: P0 for version and health copy, P1 for conversion consistency.

Actions:

- Update softwareVersion only from the release pipeline, or remove it if it cannot stay reliable.
- Decide whether jackwallner.com or github.io is the public canonical origin. Use one canonical origin for the landing page, ASC marketing URL, support links, and legal links where possible. Verify redirects, HTTPS, mobile rendering, and App Store deep links.
- Create a single feature and price data source for the site, metadata generator, local StoreKit test file, and release checklist. Do not blindly use local StoreKit prices as live evidence.
- Rewrite deterministic health claims as variable educational information. A safer direction is to explain that the app presents selected public-health information and that timelines vary by person, rather than promising a blood, liver, or whole-body result.
- Replace “pounds of body fat” with an explicitly user-entered estimate or remove it. A fixed 3,500-calorie conversion is not a measurement of a person’s body composition.
- Verify every CTA on a small iPhone, with content blockers and without JavaScript assumptions, and measure App Store click-through by tagged campaign where permitted.

## 6. Trial starts and purchase flow

### 6.1 Local offer definition

Evidence:

- Sober.storekit contains a lifetime non-consumable com.jackwallner.sober.pro.lifetime at a local display price of 69.99.
- It contains monthly com.jackwallner.sober.pro.monthly at 9.99 with a one-week introductory offer.
- It contains yearly com.jackwallner.sober.pro.yearly at 29.99 with a one-week introductory offer.
- Shared/Services/PaywallPreviewStore.swift mirrors 9.99, 29.99, and 69.99 for previews.
- The local StoreKit file is for tests and previews. It is not proof of live ASC or RevenueCat product configuration.

Stale evidence:

- fastlane/metadata/review_information/notes.txt says monthly 4.99, yearly 29.99, and lifetime 59.99.
- The same notes describe four tabs and a four-step commitment flow that do not match current source.

Priority: P0.

Validation:

- Read the live products and introductory offer configuration from ASC and RevenueCat without changing them.
- Verify product IDs, subscription group, entitlement attachment, offering package identifiers, localized prices, trial eligibility, and country-specific taxes.
- Test a new eligible account, an ineligible account, an active trial, a converted subscriber, a cancelled subscription, and a lifetime purchaser.
- Verify the price and charge-date disclosure in the exact locale and storefront used for testing.

### 6.2 RevenueCat code path

Evidence from Shared/Services/SubscriptionService.swift:

- Production uses a public RevenueCat app key in source. This is expected to be a public client key, not a server credential, but it should still be checked against the intended Sober project.
- The entitlement string is Sober Tracker - Alcohol Free Pro.
- configure returns early in a simulator to avoid production activity.
- Product loading uses offering identifier default, then current.
- Product fetch errors and empty packages are represented in local state, but refresh network errors can leave the previous state and are not durably counted.
- Customer info is applied to isPro and TrialLifecycle.
- A purchase returns purchased if any active entitlement exists, otherwise pending.
- Restore returns an active entitlement or a no-active-purchase error.
- Paywall impressions can be sent with an ID and optional package.
- syncConversionAttributes writes funnel event counts as RevenueCat subscriber attributes on background.

Unknown:

- The current RevenueCat default offering, current offering, package identifiers, product attachment, entitlement spelling, trial eligibility rules, and live prices were not independently verified in the captured context.
- No Sober-specific active trials, conversions, MRR, refunds, or churn report was captured. The overall RevenueCat account snapshot seen in context is fleet-level and must not be attributed to Sober.

Required RevenueCat read-only checklist:

1. Project identity is 10cf6202, API project form is referenced by scripts/rc-funnel.py as proj10cf6202.
2. Default offering has the expected monthly, yearly, and lifetime packages.
3. Product IDs exactly match the StoreKit and code constants.
4. Entitlement exactly matches Sober Tracker - Alcohol Free Pro.
5. Monthly and yearly introductory offers are configured only where intended.
6. Any trial or discount eligibility rule agrees with ASC.
7. The package order and default package shown in each Sober entry surface are intentional.
8. RevenueCat charts and exports are filtered to the Sober project, not the fleet.
9. Subscriber attributes are bounded, non-sensitive, and do not contain journal text, health details, or precise financial data.

### 6.3 Trial state machine

| State | Current evidence | Missing or risky behavior | Validation |
| --- | --- | --- | --- |
| Eligibility unknown | resolveOnboardingTrial waits for RevenueCat eligibility | Loading can fail and fall back to free; no durable reason is reported | Simulate no network, timeout, empty offering, and server error |
| Eligible, offer reached | trialOfferReached is recorded and paywall impression is tracked | Entry and package context are not always attached | Compare onboarding and contextual entries |
| CTA tapped | ConversionDiagnostics records trialCTATapped | The same event is used for lifetime and non-trial purchases | Split trial CTA from purchase CTA |
| Active trial | CustomerInfo and TrialLifecycle can store an end date | No explicit active-trial analytics event with source or package | Record bounded active-trial state and entry |
| Pending purchase | PurchaseState.pending is handled in the UI | Relaunch and later entitlement update need proof | StoreKit pending test and relaunch |
| Purchased | PurchaseState.purchased and trial lifecycle sync | No explicit trial converted versus direct purchase event | Derive from prior active-trial state and product type |
| Cancelled or expired | TrialLifecycle clears when no trial is active | No explicit cancellation or expiration event | Test expiry and ASC/RevenueCat reporting |
| Restored | restorePurchase checks active entitlement | Restore started, succeeded, empty, and failed are not separate funnel events | Add outcomes and test a second device |
| Claimed trial | trialClaimedKey and hasClaimedTrial exist | Repo-wide search found no writer for trialClaimed; this state is not authoritative | Decide whether RC/StoreKit is canonical and remove duplicate local state |

### 6.4 ConversionDiagnostics gaps

Current local event names in Shared/Services/ConversionDiagnostics.swift:

- onboardingReached
- onboardingCompleted
- trialOfferReached
- trialCTATapped
- freeVersionChosen
- purchaseCancelled
- purchaseFailed
- purchasePending
- purchaseSucceeded

Missing or ambiguous events:

- product fetch started, succeeded, empty, and failed
- trial eligibility resolved, ineligible, unknown, or failed
- trial CTA shown versus purchase CTA shown
- selected package kind and package identifier
- paywall dismissed
- paywall entry and focus feature
- purchase started
- restore started, succeeded, empty, and failed
- active trial observed
- trial converted
- trial expired
- renewal observed
- cancellation observed
- notification authorization status and reminder scheduled
- review prompt shown and outcome
- app version and build attached to the event

Priority: P1.

Recommendation:

Keep the existing on-device cumulative counters as a compatibility layer, but add a small bounded event or snapshot model with:

- schema version
- event timestamp or relative day bucket
- app version and build
- source surface
- paywall ID
- focus feature
- product kind, not raw price
- trial eligibility state
- result

Flush only non-sensitive bounded data. Avoid raw journal content, sobriety start dates, precise daily spending, precise calorie values, or health timeline interactions. If events are sent through RevenueCat attributes, remember that attributes are latest-value state, not a reliable event stream. A durable local queue or release report is required for exact funnel accounting.

Important implementation point:

syncConversionAttributes currently runs on background. A crash, force quit, or device termination before background can lose the most important event. Use immediate local persistence at the event boundary, then upload or aggregate later. Do not make a network call on the purchase UI critical path solely for measurement.

## 7. RevenueCat custom attributes and event design

### 7.1 Existing attributes

Evidence: SubscriptionService.syncConversionAttributes reads ConversionDiagnostics.counts and writes attributes named funnel_<event>. It intentionally does not attach custom paywall impressions to those counters.

Strength:

- The existing attribute names are bounded and do not include user-entered journal content.

Weakness:

- Cumulative counts have no timestamp, release build, source, package, or eligibility dimension.
- The same customer can carry counts across releases without a schema marker.
- Background-only sync misses abrupt exits.
- TrialCTATapped is not trial-specific.
- A single latest attribute cannot represent multiple paywall exposures or exact sequence.

### 7.2 Recommended bounded attributes

Use only if the product owner accepts the data-minimization implications and updates any needed documentation. These are suggestions for implementation, not claims that they are currently present.

| Attribute | Set at | Values |
| --- | --- | --- |
| funnel_schema | app configure or first event | Integer or short version string |
| app_version | app launch | Short version |
| app_build | app launch | Build number |
| onboarding_last_step | each onboarding step | Small enum |
| onboarding_completed | finishOnboarding | 0 or 1 |
| last_paywall_entry | paywall presentation | onboarding, bloom_tab, health, journal, garden, savings, progress, checkin, settings |
| last_paywall_id | paywall impression | Existing stable ID |
| last_focus_feature | contextual paywall | garden, health, journal, savings, general |
| last_selected_package_kind | package selection | yearly, monthly, lifetime |
| last_offer_days | eligibility resolved | Small integer such as 0 or 7 |
| intro_eligibility_state | eligibility resolved | unknown, eligible, ineligible, error |
| last_purchase_outcome | purchase result | started, purchased, pending, cancelled, failed |
| last_restore_outcome | restore result | started, active, empty, failed |
| active_trial_state | CustomerInfo or TrialLifecycle | none, active, converted, expired, unknown |
| active_journey_day_bucket | check-in or launch | 0, 1, 2-3, 4-7, 8-14, 15-30, 31+ |
| checkin_count_bucket | check-in | 0, 1, 2-3, 4-7, 8+ |
| journal_entry_count_bucket | journal save | 0, 1, 2-3, 4+ |
| notification_auth_status | authorization check | not_determined, denied, authorized, provisional |
| review_prompt_outcome | ReviewPromptSheet | shown, app_store_link, native_request, feedback, later |
| experiment_variant | exposure | short predefined variant ID |

Avoid:

- journal text or title
- sobriety start date
- daily spending amount
- precise calorie amount
- individual health benefit content
- support resource usage
- free-form error messages
- arbitrary URLs or campaign strings

### 7.3 Exact insertion points

Use these locations for future implementation tickets:

- Sober/Features/Onboarding/OnboardingView.swift on step appearance, trial eligibility resolution, trial CTA, free-version choice, purchase result, and finishOnboarding.
- Sober/Features/Paywall/PaywallView.swift on paywall task, package selection, purchase start, purchase result, dismiss, and restore.
- Sober/Features/Paywall/TrialOfferSheet.swift on direct trial exposure, direct CTA, see-all-plans, and not-now.
- Sober/App.swift where the paywall impression ID and trial coordinator intent are selected.
- Sober/Features/Paywall/BloomFeature.swift where intent, locked feature, usage threshold, and passive nudge are selected.
- Shared/Services/SubscriptionService.swift where eligibility, package, entitlement, purchase, and restore results are known.
- Shared/Services/TrialLifecycle.swift where active trial and expiration state are synchronized.
- Shared/Services/NotificationService.swift where authorization and trial reminder scheduling are attempted.
- Shared/Services/ReviewPromptTracker.swift and Sober/Views/ReviewPromptSheet.swift for prompt outcome.

## 8. Native paywall and A/B test opportunities

### 8.1 Current paywall surfaces

| Surface | Current source | Entry or focus | Experiment value |
| --- | --- | --- | --- |
| Onboarding trial screen | OnboardingView.swift | New install after date and optional inputs | High activation and trial-start impact |
| Direct trial sheet | TrialOfferSheet.swift | Contextual one-tap offer | High friction comparison |
| Full contextual paywall | PaywallView.swift | Garden, Health, Journal, Savings, General | High intent matching |
| Bloom+ tab paywall | BloomPlusTabView.swift | Broad value and lifetime visible | High revenue mix value |
| Progress or growth pitch | TrialOfferCoordinator and HomeView.swift | Positive progress moment | High emotional context, review interference risk |
| Locked feature pitch | BloomFeature.swift and feature views | User requested a gated feature | High intent, should preserve context |

### 8.2 Experiment matrix

Run one meaningful variable per experiment and keep legal price and renewal disclosure unchanged.

| Test | Control | Variant | Primary metric | Guardrails |
| --- | --- | --- | --- | --- |
| Activation timing | Current trial screen during onboarding | Free first check-in, then trial after first positive action | Trial starts per install | Onboarding completion, D1 retention, free core use, support complaints |
| Optional inputs | Spend and calorie screen before trial | Defer inputs until after activation | Onboarding completion and first check-in | Trial start, data-entry abandonment, journal use |
| Default package | Yearly selected first | Monthly selected first | Trial start and paid revenue per install | Refunds, cancellation, lifetime mix, disclosure comprehension |
| Lifetime visibility | Hidden on pitch, shown in Bloom+ tab | Visible in all full paywalls | Revenue per paywall exposure | Trial starts, yearly mix, purchase cancellation, refund |
| Paywall form | Full PaywallView | TrialOfferSheet direct CTA with see-all-plans | Completed trial starts | Dismissals, package selection, pending/error rate, user confusion |
| Benefit density | Two benefit rows when timeline is shown | Four benefit rows with scroll | CTA completion | Scroll depth, CTA visibility, Dynamic Type, loading time |
| Contextual focus | Feature-specific headline and benefits | Generic Bloom+ value proposition | Purchase or trial start by entry | Cross-entry consistency, comprehension, review sentiment |
| Journal gate | One free journal entry | Free preview plus compose after trial | Onboarding or contextual trial start | Journal completion, data trust, deletion requests |
| Health gate | First five benefits free | Different preview count or timeline preview | Health-to-trial conversion | Health copy comprehension and compliance review |
| Trial reminder | Current two-day reminder and banner | Alternative timing or clearer date/price | Trial-to-paid | Notification opt-in, reminder delivery, cancellations, complaints |
| Review timing | Two positive moments and current cooldown | Later or milestone-only prompt | Positive review rate per eligible user | Negative feedback, prompt fatigue, slips, support contacts |

Experiment rules:

- Assign a variant before exposure and persist it locally.
- Include variant, app build, surface, eligibility, selected package kind, and outcome in the bounded measurement.
- Do not compare a contextual journal paywall with a Bloom+ tab paywall without stratifying by entry.
- Do not interpret a higher trial start rate as success if trial-to-paid, retention, refund, or review quality falls.
- Do not run price or disclosure experiments that create ambiguity about auto-renewal, charge date, or lifetime purchase.
- Stop a test if error, pending, restore, or accessibility rates worsen.

### 8.3 Paywall-specific UX checks

Evidence from PaywallView.swift:

- Yearly is sorted and selected first when available.
- Lifetime can be hidden or shown based on showsLifetime.
- Trial badges are package-dependent.
- The paywall uses focus-specific copy and a trial timeline when eligible.
- The disclosure and error region use line limits and small-scale text.
- The paywall has Restore Purchases, Apple Terms, and Privacy links.
- A normal paywall impression can omit package context even though trackPaywallImpression accepts a package.
- The onboarding impression ID includes a 1_2_2 suffix that looks version-specific and should be treated as a stale identifier unless intentionally versioned.

Required QA:

- iPhone SE-sized display and large Dynamic Type.
- Right-to-left locale and long localized product names.
- No network, slow network, empty offering, and RevenueCat configuration error.
- Eligible and ineligible introductory offer.
- Yearly, monthly, and lifetime selection before purchase.
- Trial CTA, lifetime CTA, pending purchase, cancellation, purchase error, restore success, restore empty, and restore error.
- Notification authorization not determined, denied, provisional, and authorized.
- Close button true and false.
- Bloom+ user opening an already-paid paywall.
- Device rotation policy and safe-area behavior.
- VoiceOver labels for plan cards, trial disclosure, purchase CTA, restore, and legal links.
- No accidental double purchase from rapid taps.
- Relaunch after purchase returns, pending transaction, or app termination.

## 9. Onboarding, core UX, and retention

### 9.1 Onboarding

Strengths:

- The first screen communicates a simple private counter and garden concept.
- The date picker is explicit.
- Spend and calories are optional and have visible projections.
- Trial length and charge date derive from the actual package.
- Continue with free version is available and confirmed.
- Terms, Privacy, and Restore are visible on the trial footer.

Risks:

- The user must enter optional projections before seeing the trial decision.
- The current code persists settings before the trial resolution finishes.
- madeCommitment is persisted as false by onboarding. The commitment control is in Settings, not current onboarding.
- The trial subhead can promise a reminder, but notification authorization may be denied or scheduling may fail.
- A free continuation after an error may make the user believe the trial was unavailable for them rather than temporarily unavailable.

Recommendations:

- Test an activation-first onboarding path.
- Explain why spending and calorie inputs are optional and let users skip them without a confirmation loop.
- Make the free path explicit when RevenueCat is unavailable: “Continue free. You can try Bloom+ later.”
- State the exact reminder condition, not a guarantee. If permission is denied, say the app cannot send the reminder until permission is enabled.
- Add an in-app trial status surface with end date, price, and reminder status.

### 9.2 Home and daily check-in

Evidence:

- HomeView backfills check-ins through yesterday, refreshes garden vitality, updates widgets, schedules reminders, and evaluates retention and trial nudges on appearance.
- Growth and check-in milestones can trigger trial pitch and review flows.
- The check-in flow handles sober and slipped states.

UX opportunities:

- Keep the daily action one tap from the home surface.
- Measure time to first check-in and completion rate, not only onboarding completion.
- Separate recovery support language from monetization in the slipped state. Do not show a sales pitch in a moment of distress.
- Validate that reminder, milestone, review, and trial sheets cannot stack. The code has coordination flags, but the real device sequence needs proof.
- Treat a missed check-in as a retention opportunity, not as a failure message.

### 9.3 Garden

Evidence:

- Garden style access is checked again in GardenService.setBonsaiStyle(styleID:isPro:), providing defense in depth.
- Vitality decay has a floor and does not imply a punitive reset.
- The garden and growth celebration are high-emotion moments and can trigger a contextual pitch.

Opportunities:

- Test a soft preview of locked species against the current lock state.
- Use a specific value statement tied to the requested species, not a generic subscription message.
- Ensure a locked tap never loses the user's selected style or changes the garden before entitlement confirms.
- Measure style customization attempts, paywall exposure, and completed purchase.

### 9.4 Health timeline

Evidence:

- HealthView shows 13 benefits and reveals the first five free, with remaining content gated.
- The footer says general wellness information, not medical advice, and says timelines vary.
- HealthBenefitCatalog.swift contains deterministic or medical-sounding labels and descriptions, including Blood Sugar Stabilization, Liver Fat Reduction, Blood Pressure Drops, Immune System Boost, and Full Body Recovery.

Priority: P0 compliance review.

Recommendation:

- Review every benefit title, timeframe, detail, source, and landing-page statement.
- Prefer labels such as “public-health information associated with alcohol-free days” or “possible changes people report,” only where the cited source supports that wording.
- Avoid presenting a health event as a promised result on a user-specific timeline.
- Add a clear point-of-use note that the information is educational, not a prediction, diagnosis, or treatment plan.
- Do not imply that a user can safely stop alcohol without clinical advice.
- Make source links specific and inspect the source content, publication date, and population studied.
- Keep wellness education separate from purchase pressure. A health benefit should not be framed as something a user must buy to become safe.

### 9.5 Journal

Evidence:

- Journal allows one real free entry and gates later composition for non-Pro users.
- Journal data is local and no journal text is put into the recommended RevenueCat attributes.
- Journal visits contribute to usage-based trial pitches.

Opportunities:

- Preserve the first free entry as an activation path.
- Explain the local storage model at the composer and settings, not only in the legal page.
- Test a locked composer preview versus the current paywall after the first entry.
- Verify editing, deletion, export expectations, and reinstall behavior so the privacy promise is understandable.
- Do not send journal text, titles, or sensitive emotional states to RevenueCat.

### 9.6 Savings and calories

Evidence:

- The app collects user-entered daily spending and calorie values.
- Bloom+ displays savings, calories avoided, yearly projection, and pounds of body fat based on derived values.

Inference:

The feature may create a strong concrete reward, but body-composition wording can be interpreted as a health or weight outcome. It also depends on user estimates, not measurements.

Recommendation:

- Label all values as user-entered estimates or projections.
- Avoid presenting a fixed conversion as actual body change.
- Let users disable or reset these fields without losing the core counter.
- Test whether savings alone activates better than combining spending and calorie language.

### 9.7 Apple Watch and widgets

Evidence:

- WatchConnectivity activates and sends application context.
- SoberWatch is display-oriented and derives the day count live from the start date.
- The widget computes a live day count and timeline around the next midnight.
- Watch connectivity errors and context updates are not durably reported.

Opportunities:

- Add a watch or widget action for a fast daily check-in if platform rules and UX support it.
- Add a complication that makes the next meaningful milestone visible.
- Measure widget install, watch app launch, and check-in from a widget or watch if available.
- Test stale snapshot behavior after changing start date, reinstalling, or crossing midnight.

## 10. Ratings and review funnel

### 10.1 Current implementation

Evidence:

- ReviewPromptTracker gates on release launches, days since first open, positive moments, and cooldown.
- Current thresholds include at least 3 release launches, at least 3 days since first open, at least 2 positive moments, and a 120-day cooldown. Milestones can bypass tenure but still require setup and 2 launches.
- HomeView waits about 3.5 seconds after a positive moment before checking the gate.
- ReviewPromptSheet lets a satisfied user open the App Store write-review URL, a dissatisfied user email feedback, and a user who chooses later receive the native review request after dismissal.
- AppStoreReviewLinks uses app ID 6768869215 and a storefront-aware review URL.
- The app avoids directly requesting a review immediately after a failed purchase in the inspected flow.

Assessment:

This is directionally good. It asks after an achieved moment, offers feedback, and uses both the native request and a direct review route. It needs production measurement and edge-case QA rather than a wholesale redesign.

Risks:

- There is no current remote prompt-outcome metric in the repository.
- The outcome is terminal after an App Store link or feedback path, so a user who acted too early may never be asked again.
- Review or trial presentation coordination depends on runtime flags. A slip, distressed check-in, or notification interruption must be tested to ensure monetization and review prompts do not overlap.
- Current live ratings, review count, review themes, and rating by version were not available in the repository or captured context. Do not use an invented rating baseline.

Recommendations:

- Export ASC ratings and review themes by app version weekly after each release.
- Track only bounded prompt outcome, app version, positive-moment type, and cooldown state.
- Keep the feedback route available from Settings.
- Do not ask for a review in a slip, crisis, failed purchase, or blocked notification state.
- Test the direct App Store link in every supported storefront and confirm the app ID remains correct.
- Consider resetting a terminal later state after a long cooldown, but do not change that behavior without a measured reason.

### 10.2 Review validation matrix

- First launch, fewer than 2 positive moments: no prompt.
- Positive moment number 2 after the minimum launch and day thresholds: prompt eligible.
- Milestone before tenure threshold: prompt only if launch and setup requirements pass.
- App Store link opened: cooldown and terminal state persist.
- Feedback selected: mail composer has no sensitive journal content prefilled.
- Maybe later: native request appears only after the sheet is dismissed.
- Slip flow: no review sheet.
- Trial or purchase sheet already present: no review sheet.
- Reinstall or new App Group state: behavior is intentional and documented.
- iOS native review quota suppression: app remains functional and does not show a stuck state.

## 11. Website, terms, privacy, and consistency

### 11.1 Consistency matrix

| Area | Local source | Website or legal evidence | Finding |
| --- | --- | --- | --- |
| Product name | fastlane/metadata/en-US and project.yml | docs/astro-aso-setup.md and scripts/.astro-app.json use Sober Tracker - Alcohol Free | Naming is not unified across current and historical documents |
| Live version | ASC observed 1.2.8 | docs/index.html schema 1.2.6, local project 1.3.0 | Release staging is unclear |
| Monthly price | Sober.storekit and PaywallPreviewStore 9.99 | review notes say 4.99; landing schema says 9.99 | Review notes are stale |
| Yearly price | 29.99 | review notes and landing schema 29.99 | Current local and site agree, review flow is not fully current |
| Lifetime price | 69.99 | review notes say 59.99; landing schema says 69.99 | Review notes are stale |
| Trial | RevenueCat and StoreKit local config use one week where eligible | Metadata, site, terms, and support say 7 days | Confirm live eligibility and all territory wording |
| Tabs | App.swift has Home, Timeline, Health, Journal, Bloom+ or Upgrade | Review notes say four tabs | Review notes are stale |
| Onboarding | Current source has start screen, date, optional inputs, trial, free continuation | Review notes describe a commitment step | Review notes are stale |
| Health access | HealthView free reveal count is five, full catalog is 13 | Design handoff says first two free | Design handoff is stale |
| Support freshness | support.html last updated May 25, 2026 | terms and privacy last updated Aug 17, 2026 | Support page needs a source review |
| Software version | local 1.3.0 and live 1.2.8 | JSON-LD 1.2.6 | Site schema stale |
| Legal footer | Paywall links Apple Standard EULA and privacy | Settings links Privacy and Terms pages | Decide and document legal link strategy |

### 11.2 Support page

Evidence from docs/support.html:

- It says onboarding sets start date, daily spending, calories, and reminder time.
- Current onboarding does not ask for a reminder time. It starts with dailyReminderEnabled false, and reminder controls live in Settings.
- It says the Health first five benefits are free and all 13 are Bloom+, which matches current source better than the stale design handoff.
- It says Journal, achievements, and stats require Pro. Current source treats some past values as free and gates future or additional capability, so this wording may be too broad.
- It says monthly and yearly plans have a 7-day free trial.
- It says widgets update every 30 minutes and the app can be opened to refresh. Current widget source derives values live around the next midnight, so the support copy should be checked against actual widget refresh behavior.
- It links legal pages and support contact paths.

Actions:

- Update the onboarding description to describe the current flow, including that reminder permission is configured later.
- Define the exact free and Bloom+ boundary for Journal, achievements, savings, and Health, then use the same vocabulary in app, site, metadata, and support.
- Verify widget refresh claims on iOS versions supported by the project.
- Add a visible last-reviewed date and source commit to agent-facing support content, not necessarily to customer copy.

### 11.3 Terms and privacy

Evidence:

- docs/terms.html was last updated Aug 17, 2026.
- The terms describe journaling, habit awareness, health timelines, savings, reminders, and general educational information. They explicitly avoid diagnosis, prevention, treatment, and cure claims.
- docs/privacy-policy.html was last updated Aug 17, 2026.
- It describes no account, local SwiftData, UserDefaults, App Group storage, no Apple Health, Apple purchase processing, and RevenueCat processing of anonymous ID, purchase and entitlement data, and limited technical context.
- This audit intentionally does not report a RevenueCat disclosure inconsistency because the user excluded that specific review.
- PrivacyInfo.xcprivacy says tracking false and no collected data types, with UserDefaults usage. No HealthKit entitlement or HealthKit usage description was found.

Actions:

- Keep legal wording synchronized with actual in-app feature names, especially Bloom+ and “future” versus “past” value.
- Review the proposed bounded RevenueCat attributes with the privacy owner before implementation.
- Ensure all wellness copy in the website and app follows the safer boundary in the terms.
- Test that legal links work offline enough to show a useful fallback and that the in-app settings links open the intended page.
- Do not use the terms page as the only control against over-promising health results in the product UI.

## 12. Crash, regression, and watchdog signals

### 12.1 Current signals found

Evidence:

- os.Logger is used in SubscriptionService, ConversionDiagnostics, and DataService.
- ConversionDiagnostics stores cumulative counters in the App Group.
- No reference to MetricKit, Crashlytics, Sentry, Bugsnag, or another persistent crash and hang service was found in the inspected repository.
- RevenueCat errors are partly logged or stored in transient lastError state.
- Notification scheduling commonly uses try-question-mark and does not persist failure outcomes.
- WatchConnectivity activation and context update errors are not durably counted.
- DataService can remove the store after a container failure and retry with an in-memory fallback.
- Save calls are frequently ignored with try-question-mark behavior.
- scripts/rc-funnel.py reads RevenueCat attributes for customers first seen after the 1.2.7 date and therefore does not provide a complete historical funnel.
- No live crash spike or crash-free session metric was available in repository or captured context.

### 12.2 Urgent production watch list

For every new release, watch these signals for at least the first 24 hours and again after 72 hours:

1. Crash-free sessions and crash-free users by app version and build.
2. Launch crash, first-screen crash, onboarding-step crash, and paywall crash separately.
3. Hang or watchdog termination during RevenueCat configure, product fetch, purchase, restore, and DataService initialization.
4. Store-container recovery count, failed save count, in-memory fallback count, and journal or check-in write errors.
5. Trial offer reached, trial CTA, active trial, purchase success, purchase pending, purchase failure, restore success, restore empty, and restore failed by build.
6. Paywall load failure, empty offering, missing product, and disclosure render failure.
7. Notification authorization result, trial reminder scheduling result, and reminder delivery where platform data permits.
8. Watch context update failure and widget snapshot age.
9. Review prompt presentation and negative feedback rate, without recording review text in app telemetry.
10. Support contacts and low-rating review volume, especially in the first 72 hours.

### 12.3 Watchdog scaffold requirements for a future script

This audit does not create the requested Mac watchdog script because the latest task explicitly limits writes to audit823.md. The implementation handoff should specify:

- Configurable app IDs, bundle IDs, release version, time window, email destination, and cooldown.
- Read-only ASC and RevenueCat API checks where credentials are available.
- Crash and hang provider API checks, or local MetricKit export ingestion if a provider is not used.
- Threshold alerts such as absolute crash count, percentage increase against the prior release, purchase failure rate, and store recovery count.
- One alert per incident window with a local state file to prevent mail storms.
- Redacted reports containing app version, build, timestamp, category, and counts only.
- A dry-run mode that prints the alert without sending mail.
- A daily summary mode and an urgent threshold mode.
- No production app mutation, no ASC upload, no TestFlight upload, and no code signing operation.
- Explicit handling for missing credentials, unavailable API, partial data, ASC privacy thresholds, and clock skew.

### 12.4 Release regression test matrix

Run on a headless leased simulator with StoreKit test configuration, then repeat purchase and notification cases on a real device or TestFlight:

- clean install and onboarding completion
- date changes across local midnight
- start date edited after check-ins exist
- no network during RevenueCat configure
- empty and malformed offering
- eligible trial, ineligible trial, direct lifetime purchase
- pending purchase and relaunch
- purchase cancellation and failure
- restore active, restore empty, restore error
- notification permission denied, granted, provisional, and changed in Settings
- trial reminder around time zone and daylight saving transition
- DataService migration from the previous schema
- simulated store open failure and recovery
- journal save, edit, delete, and relaunch
- widget and watch snapshot update
- Dynamic Type and VoiceOver on paywall and onboarding
- RTL locale and long localized prices
- review gating after positive moment and after slip
- app background, termination, relaunch, and memory pressure at each step

Do not use a production RevenueCat key in a simulator. Do not use named simulator destinations when the repository conventions require a leased headless pool device.

## 13. Agent documentation hygiene

### 13.1 Current canonical arrangement

Evidence:

- Root AGENTS.md is a symlink to CLAUDE.md.
- CLAUDE.md is the main project guide and describes the XcodeGen project, targets, architecture, entitlement, free versus Bloom+ boundaries, review and trial triggers, and shared ios-dev conventions.
- No root .cursor, .codex, .claude, or .agents project instruction directory was found.

Assessment:

The symlink is a good single-source arrangement for Claude Code and Codex. Cursor can consume the canonical guide if its project rules point there, but the repository does not currently contain explicit Cursor-specific guidance. The problem is not the absence of three copies. The problem is that the one canonical guide is partly stale.

### 13.2 CLAUDE.md drift

Evidence:

- It says RevenueCat 5.14 or later, while project.yml uses 5.67.0.
- It calls the entitlement “pro,” while current source uses Sober Tracker - Alcohol Free Pro and an any-active-entitlement fallback.
- It lists Sober/Features/Achievements, Stats, and Components, but the current feature directories are Calendar, Garden, Health, Journal, Onboarding, Paywall, Settings, Today, and shared Views or Utilities.
- It summarizes only two review or trial triggers, while current code has onboarding, locked-feature, passive, usage, progress, growth, and check-in milestone paths.
- It says earned achievement badges and past money and calories are free, but the exact current gates should be sourced from BloomFeature and feature views rather than from the guide.

Priority: P1 for implementation safety.

Recommended future docs task:

- Replace copied feature lists with links to current directories and source symbols.
- Put exact product IDs, entitlement name, and source-of-truth file in one table.
- Add a current flow section generated or checked from source.
- Add a release and incident section pointing to the read-only checks and watchdog requirements in this audit.
- Add a historical docs rule: any document with a date or old version must state whether it is normative, reference-only, or archived.
- Add a do-not-use note for old paywall, pricing, and health copy.

### 13.3 Stale or misleading documents

| File | Evidence of staleness | Agent risk | Future disposition |
| --- | --- | --- | --- |
| fastlane/metadata/review_information/notes.txt | Old commitment step, four tabs, old monthly and lifetime prices | Review instructions fail against current binary | Rewrite for exact candidate build |
| scripts/.asc-state.json | Live 1.2.6 and draft 1.2.7 while ASC observed 1.2.8 and local is 1.3.0 | Automation targets wrong version | Regenerate or archive with freshness rule |
| docs/index.html | JSON-LD 1.2.6 and health claims needing review | Search and customer copy are stale or risky | Generate version and pricing data; review claims |
| docs/support.html | May 25, 2026 and old onboarding reminder description | Users and agents learn wrong flow | Update and source-link |
| docs/astro-aso-setup.md | June 23, 2026 naming and historic ranking context | Agent may treat old ASO plan as current | Mark historical and add current metadata snapshot |
| docs/aso-plan.md | Old title, subtitle, and keyword plan | ASO work can regress current metadata | Move under dated plan archive or mark non-normative |
| design-handoff/README.md | RC pro name, first two free health benefits, old garden and feature assumptions | Designer or coding agent implements old paywall | Archive or rewrite as current design source |
| design-handoff/CURRENT-STATE.md | Requires source comparison before use | Current-state label may be false | Rename or add last verified commit |
| archive/ux-audit-2026-07-17.md | Historical issues include items now fixed in current source | Agent may re-open fixed bugs | Keep archived, add explicit revalidation warning |
| archive/README.md | Points to a root README that is absent | New agent cannot find entry point | Add root README or correct the pointer |

### 13.4 Proposed source-of-truth map

Use this map in a future docs-only cleanup:

| Question | Source of truth |
| --- | --- |
| Bundle IDs, deployment targets, packages | project.yml |
| Product IDs and local StoreKit behavior | Sober.storekit and SubscriptionService.swift |
| Live offering, product, price, and entitlement | RevenueCat and ASC read-only release snapshot |
| Free versus Bloom+ gates | BloomFeature.swift plus the feature implementation |
| Onboarding flow | OnboardingView.swift |
| Tabs and entry surfaces | Sober/App.swift |
| Trial lifecycle and reminders | TrialLifecycle.swift and NotificationService.swift |
| Review gating and outcomes | ReviewPromptTracker.swift, ReviewPromptSheet.swift, AppStoreReviewLinks.swift |
| Current customer copy | fastlane/metadata and docs pages, validated against source |
| Historical decisions | dated docs under archive or a clearly named decision log |
| Agent workflow and safety | CLAUDE.md or a single canonical agent guide |

## 14. Validation plan for the implementing agent

### Phase 1: read-only inventory

- Record git commit, branch, project version, build, live ASC version, and candidate version.
- Search all product IDs, entitlement strings, price literals, trial-day literals, health claim phrases, support URLs, legal URLs, and version strings.
- Compare the 50 locales for field presence, placeholders, stale prices, stale trial days, and unsafe or untranslated terms.
- Read RevenueCat project offering and entitlement configuration without modifying it.
- Export current ASC rating and review summary if available, preserving privacy thresholds.
- Confirm no unrelated file changes before implementing.

### Phase 2: release correctness

- Rewrite App Review notes for the candidate binary.
- Align support, landing, metadata, and terms feature vocabulary.
- Resolve version and price source-of-truth.
- Complete health and weight copy review.
- Re-run static metadata and legal-link checks.

### Phase 3: purchase and notification behavior

- Run StoreKit test cases for every state in section 12.4.
- Test live sandbox or TestFlight with a non-production test account.
- Confirm entitlement transitions after pending, restore, cancellation, expiration, and reinstall.
- Confirm trial reminder condition and permission wording.
- Confirm paywall and trial flows are accessible and localized.

### Phase 4: instrumentation

- Implement bounded event semantics.
- Persist locally before attempting upload.
- Add version, build, source, entry, package kind, eligibility, and outcome.
- Add tests for no duplicate events, force quit, retry, and schema migration.
- Validate RevenueCat attributes in the Sober project only.

### Phase 5: production watch

- Establish a baseline from the previous live release.
- Monitor crash-free sessions, hangs, store recovery, paywall errors, purchase failures, trial starts, trial conversions, restore outcomes, notifications, and reviews.
- Set thresholds before release so the alert is not tuned after a regression.
- Document rollback or pause criteria without attempting any release mutation in the audit process.

## 15. Detailed implementation backlog

### SBR-001, release evidence and App Review notes

Priority: P0.

Evidence: E2, project.yml, scripts/.asc-state.json, fastlane/metadata/review_information/notes.txt.

Work:

- Create a candidate release record.
- Update App Review steps to match the current onboarding, five-tab layout, entitlement, products, and exact trial eligibility.
- Remove the old commitment-step instruction unless the product intentionally restores that step.
- Replace old 4.99 and 59.99 values with the prices actually configured for the candidate, after confirming live ASC and RevenueCat.
- Add a clean-install path and an ineligible-account path.

Acceptance:

- A reviewer can reach the trial and free flow from a clean install.
- Every price, tab, and screen name in the notes matches the binary.
- A read-only static check flags future drift.

### SBR-002, health copy safety review

Priority: P0.

Evidence: HealthBenefitCatalog.swift and docs/index.html.

Work:

- Inventory every benefit title, timeframe, description, landing-page statement, metadata statement, and source.
- Rewrite deterministic statements as variable, educational language supported by the cited sources.
- Remove or reframe body-composition output that appears to measure a person.
- Keep the no-diagnosis, no-treatment, and seek-qualified-help boundary visible.

Acceptance:

- A reviewer cannot reasonably read the product as promising a personal medical result.
- App, web, metadata, and legal copy agree.
- Source links are specific enough to validate.

### SBR-003, data-store recovery and save observability

Priority: P1.

Evidence: DataService.swift.

Work:

- Preserve a recoverable copy before deleting any store, WAL, or SHM file.
- Track recovery attempt, success, fallback, failed save, and migration error with bounded counters.
- Surface a clear user action when data may not have persisted.
- Decide whether a failed store should be retried, restored, or exported before fallback.

Acceptance:

- A corruption test does not silently destroy the only user copy.
- Check-in and journal save failures are observable.
- Recovery behavior is tested across app relaunch and upgrade.

### SBR-004, crash and hang monitoring

Priority: P1.

Evidence: no persistent crash provider reference or current live crash evidence.

Work:

- Choose a crash and hang provider or an approved MetricKit ingestion path.
- Add release version and build dimensions.
- Define threshold alerts and a Mac-readable report format.
- Build the future dry-run watchdog described in section 12.3.

Acceptance:

- A simulated crash and test hang appear with app version and build.
- A multi-user spike triggers one deduplicated notification.
- Missing credentials and privacy-thresholded data produce a visible non-alert error.

### SBR-005, canonical trial state

Priority: P1.

Evidence: SubscriptionService trialClaimedKey and TrialLifecycle keys.

Work:

- Decide whether Apple or RevenueCat is authoritative for introductory offer eligibility.
- Remove or migrate unused bloomTrialEndsAt and bloomTrialClaimed keys if safe.
- Make trial claimed, active, converted, expired, and restored states explicit.
- Add tests for every transition and for force quit between transitions.

Acceptance:

- Passive and locked-feature pitches never reoffer an ineligible consumed trial.
- An active trial is never counted as a new start twice.
- A converted trial is distinct from a direct lifetime purchase.

### SBR-006, conversion event semantics

Priority: P1.

Evidence: ConversionDiagnostics.swift and syncConversionAttributes.

Work:

- Rename or split trialCTATapped so lifetime and non-trial purchase events are not included.
- Add product fetch, eligibility, impression, selection, purchase, restore, active-trial, conversion, expiry, and notification outcomes.
- Persist before background upload.
- Add schema and build dimensions.

Acceptance:

- A funnel report can distinguish exposure, CTA, active trial, conversion, direct purchase, pending, cancel, and failure.
- The report can be stratified by paywall entry and package kind.
- No sensitive free-form user content is sent.

### SBR-007, native paywall QA and experiment contract

Priority: P1.

Evidence: PaywallView.swift, TrialOfferSheet.swift, NotificationService.swift.

Work:

- Implement the matrix in sections 8.3 and 12.4.
- Normalize impression IDs and pass package context when known.
- Define experiment assignment and guardrails before shipping a variant.
- Verify legal disclosure and accessibility in every variant.

Acceptance:

- No paywall state clips or hides a required disclosure or CTA.
- Purchase and restore outcomes are correct after relaunch.
- A report can identify which entry and variant produced a result.

### SBR-008, agent documentation cleanup

Priority: P2.

Evidence: CLAUDE.md, design-handoff, docs, archive.

Work:

- Update CLAUDE.md to current symbols, paths, entitlement, package version, and trigger map.
- Establish current versus historical labels and last-verified commit fields.
- Fix root entry-point documentation.
- Ensure Cursor, Claude, and Codex all consume the same canonical guide.

Acceptance:

- A new agent can locate current architecture, current product rules, release checks, and historical warnings in under five minutes.
- No normative document contains old prices or old product gates without an explicit label.

## 16. Static checks that can be automated without AI

These are recommended for the future fleet script and are specific to Sober:

1. Parse project.yml and compare marketing version and build against a release record.
2. Parse scripts/.asc-state.json and flag live or draft versions older than the observed ASC version.
3. Parse Sober.storekit and PaywallPreviewStore.swift for product IDs and local prices, then compare them to the approved release snapshot.
4. Search the repository for old prices 4.99 and 59.99 and list every occurrence.
5. Search for old entitlement string pro and the current entitlement string, then classify each occurrence as normative, test, archived, or stale.
6. Search for app version literals such as 1.2.6, 1.2.7, and 1.2.8 in landing pages, scripts, docs, and ASC state.
7. Enumerate fastlane/metadata locale directories and check required fields, character limits, empty translations, placeholders, and duplicate keywords.
8. Verify every support, marketing, privacy, terms, EULA, and App Store URL is syntactically valid and optionally reachable in a read-only HTTP check.
9. Compare feature names and free or Bloom+ labels in metadata, support, landing, terms, and source.
10. Search for deterministic health language and flag it for human review. The checker should report, not auto-rewrite.
11. Search for try-question-mark patterns around DataService saves, notification scheduling, WatchConnectivity updates, and purchase refreshes.
12. Search for MetricKit, crash provider, hang provider, and alert configuration references, and report their absence.
13. Search for ConversionDiagnostics event names and confirm every event is persisted and has an upload path.
14. Search for custom RevenueCat attribute names and flag unbounded or raw user-input values.
15. Search for old design-handoff and archive documents and require an explicit historical marker.
16. Confirm AGENTS.md is a symlink to CLAUDE.md and report missing root README or missing agent entry point.
17. Verify no production RevenueCat key is configured in simulator test paths.
18. Verify test coverage exists for trial, restore, notification, review, migration, and paywall accessibility states.
19. Produce a machine-readable JSON report plus a human-readable Markdown report. Do not send email by default.
20. Add a dry-run and a non-zero exit code for P0 and configured P1 findings.

## 17. Decisions for the owner

These are product decisions the implementing agent should not guess:

1. Is the canonical public product name Sober: Sobriety Day Counter or Sober Tracker: Alcohol Free?
2. Is the live pricing source ASC, RevenueCat, or an approved release snapshot generated from both?
3. Should Lifetime be visible on contextual trial pitches or only on the Bloom+ tab?
4. Should optional spending and calorie inputs remain before the trial decision?
5. Is the first free journal entry the intended permanent activation wedge?
6. Is the current five-free, thirteen-total Health boundary intentional?
7. Should body-composition estimates remain in the product at all?
8. Is the two-day trial reminder promise acceptable when permission is denied or scheduling fails?
9. Should a user who chooses App Store review or feedback be permanently suppressed, or only cooled down?
10. Which crash and hang provider or MetricKit ingestion path is approved?
11. Are bounded RevenueCat attributes acceptable, and which fields are allowed?
12. Should the root agent guide remain CLAUDE.md with an AGENTS.md symlink, or should a generated current-state index be added?

## 18. Final handoff summary

The Sober audit should be implemented in this order:

1. Make release state and App Review instructions truthful for the exact candidate.
2. Resolve health and weight copy before optimizing conversion.
3. Protect and observe local data recovery.
4. Establish a reliable crash, hang, and production regression signal.
5. Make trial and purchase events semantically correct, durable, and package-aware.
6. QA the native paywall and notification promise across failure, accessibility, and localization states.
7. Run activation and paywall experiments with guardrails.
8. Clean the agent documentation so Cursor, Claude, and Codex use current source symbols and clearly marked history.

No current Sober-specific live rating, RevenueCat revenue, trial, or crash numbers were available in the inspected evidence. The historical conversion report is useful for forming hypotheses, not for claiming current performance. All live claims in this audit are timestamped or explicitly marked as not verified.

## Activity and success context, 2026-08-23

Classification: **active monetizing**. Confidence: **high**. Trend: **no ASC comparison displayed**.

ASC release state: `iOS 1.2.8 Ready for Distribution`. ASC evidence: [Analytics Overview](https://appstoreconnect.apple.com/apps/6768869215/analytics/overview?dateSpec=d90), selected range `dateSpec=d90`.
RevenueCat evidence: [Project Overview](https://app.revenuecat.com/projects/10cf6202/overview), production mode, selected range `Last 28 days, 2026-07-27 through 2026-08-23`.

### Observed activity

| Source | Metric | Value | Window or comparison |
| --- | --- | ---: | --- |
| ASC | First-time downloads | 354 | 90-day Analytics Overview |
| ASC | Redownloads | 10 | 90-day Analytics Overview |
| ASC | Conversion rate | 3.66% | comparison not displayed |
| ASC | Proceeds | $142 | 90-day Analytics Overview |
| ASC | In-app purchases | 29 | 90-day Analytics Overview |
| RevenueCat | New customers | 236 | last 28 days |
| RevenueCat | Active customers | 262 | last 28 days |
| RevenueCat | Active trials | 4 | current total |
| RevenueCat | Active subscriptions | 9 | current total |
| RevenueCat | MRR | $18 | current total |
| RevenueCat | Revenue | $114 | last 28 days |

A missing value above means the source did not expose that metric in this read-only snapshot. It is not a zero.

### Interpretation and implementation focus

Sober is active and monetizing at a useful scale: 354 ASC first-time downloads, 3.66% ASC conversion, $142 ASC proceeds, 236 RevenueCat new customers, 4 active trials, 9 active subscriptions, and $114 RevenueCat revenue. The next agent should treat this as a working funnel, not a blank-slate redesign. Focus on trial eligibility, renewal and retention, health-safe trust copy, and release regression monitoring.

The deterministic classifier recommends: Protect the current paid path, then use release and cohort baselines to decide whether acquisition or conversion is the next constraint.

- Join ASC first-time download, first launch, first value, paywall shown, offer loaded, trial started, trial canceled, trial converted, entitlement active, restore, and purchase failure events with the app version and build.
- Keep ASC's 90-day acquisition and proceeds window separate from RevenueCat's 28-day customer and revenue window. Do not calculate a conversion rate by dividing values from different windows.
- Use a mature trial cohort and a minimum sample before choosing a native paywall or onboarding A/B winner. Record the offering identifier, package, placement, experiment variant, and build.
- Put the app's classification and the next baseline date in the release handoff so Cursor, Claude, and Codex do not optimize from an old qualitative audit.

### Boundary on success or death

This snapshot supports the label **active monetizing**, not a lifetime verdict. The app has current paid activity, but ASC does not expose a positive comparison for the selected window. A later decision should include a clean 28-day RevenueCat trend, ASC acquisition and conversion trend, ratings and review count, crash and hang evidence, and a release-specific cohort.
This dated section supersedes earlier statements in this file that per-app ASC or RevenueCat activity was unavailable as of 2026-08-23. Earlier statements remain historical evidence boundaries for their original audit pass.
