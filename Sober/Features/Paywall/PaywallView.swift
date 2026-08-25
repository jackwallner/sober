import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Apple-required legal links for the paywall and any other upsell surface.
enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/sober/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Native Bloom+ paywall. Purchases flow through `SubscriptionService.purchase`
/// → `Purchases.shared.purchase`, so RevenueCat records transactions, trials,
/// and renewals — only the presentation layer is custom.
///
/// Layout (cream "slow morning" surface, matching the rest of the app):
///   1. Savings hero — the money already back in their pocket. The "whoa, I've
///      saved a lot" moment, reframed as a reason to treat themselves.
///   2. Benefit showcase — what Bloom+ unlocks (`BloomFeature`).
///   3. Plan stack: yearly value, monthly default, lifetime last. The real price
///      is always visible on every card (Apple 3.1.2) — trials show as a badge.
///   4. Anchored purchase dock — CTA, trust row, legal links. Pinned to the
///      bottom so the action never drifts as the top content scrolls.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var settingsRows: [UserSettings]
    @Query private var checkIns: [DailyCheckIn]

    /// Set to `false` when embedded as tab content or after the trial sheet.
    var displayCloseButton: Bool = true

    /// When set, the paywall leads with this locked feature (intent-driven pitch).
    var focus: BloomFeature? = nil

    /// Lifetime is deliberately absent from every *pitch* paywall. It carries no
    /// free trial, so putting it in front of someone we're asking to start one
    /// offers them a way out of the funnel we're trying to move them through,
    /// and Health & Fitness runs two-plan layouts on 60% of paywalls, the
    /// highest of any category. It stays available on the Bloom+ tab for anyone
    /// who goes looking for it.
    var showsLifetime: Bool = false

    /// RevenueCat custom-paywall impression id for this entry point.
    var impressionId: String = "sober_paywall_sheet"

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var isRestoring = false
    /// Drives the trial timeline's reminder step. `.notDetermined` counts as
    /// enabled: starting the trial is what triggers the permission prompt, so
    /// the promise is one we're about to be able to keep.
    @State private var remindersDenied = false
    /// `-paywallMetrics` only. What the page was given against what the stack
    /// laid out to, which is what the ramps in `PaywallMetrics` are calibrated
    /// against.
    @State private var layoutProbe = PaywallLayoutProbe()

    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }

    private var lifetimeSoberDays: Int { checkIns.filter { $0.wasSober }.count }

    private var heroDays: Int { max(lifetimeSoberDays, days) }

    private var costPerDayCents: Int { settingsRows.first?.costPerDayCents ?? 0 }

    private var hasSavings: Bool { heroDays > 0 && costPerDayCents > 0 }

    private var savedCents: Int { heroDays * costPerDayCents }

    private var moneySaved: String {
        let dollars = Double(savedCents) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private var yearlySpend: Int { Int((Double(costPerDayCents) * 365 / 100).rounded()) }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            #if canImport(RevenueCat)
            if subscriptions.isConfigured {
                if subscriptions.isLoadingProducts && subscriptions.packages.isEmpty {
                    loadingState
                } else if subscriptions.packages.isEmpty {
                    emptyState
                } else {
                    paywallContent
                }
            } else {
                #if DEBUG
                devPlaceholder
                #else
                emptyState
                #endif
            }
            #else
            devPlaceholder
            #endif

            if displayCloseButton {
                closeButton
            }
        }
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            // Only auto-dismiss when presented as a sheet — the Bloom+ tab
            // stays put and swaps to the subscriber hub instead.
            if isPro && displayCloseButton { dismiss() }
        }
        .task {
            remindersDenied = await NotificationService.isDenied()
            ConversionDiagnostics.record(.trialOfferReached)
            subscriptions.trackPaywallImpression(id: impressionId)
            #if canImport(RevenueCat)
            if subscriptions.isConfigured, subscriptions.packages.isEmpty {
                await subscriptions.fetchProducts()
            }
            selectDefaultPackageIfNeeded()
            #endif
        }
        #if canImport(RevenueCat)
        .onChange(of: subscriptions.packages.count) { _, _ in
            selectDefaultPackageIfNeeded()
        }
        #endif
    }

    /// The ramps in `PaywallMetrics` were calibrated on the Bloom+ tab, whose
    /// header is the savings hero and whose stack carries three plans. A pitch
    /// paywall swaps in a two-line focus headline and the habit-comparison
    /// line, and drops the lifetime card; measured on a 6.3" screen that
    /// combination runs about 35pt heavier overall. Taking it off the height
    /// handed to the metrics keeps `size` meaning the one thing it is
    /// calibrated to mean — how much slack this page has — on both variants,
    /// rather than needing a second set of ramps.
    private var pitchHeaderPremium: CGFloat { showsLifetime ? 0 : 35 }

    // MARK: - Native paywall

    /// Value (savings + benefits) up top, the plan stack in the middle, and the
    /// purchase dock pinned to the bottom as a safe-area inset.
    #if canImport(RevenueCat)
    private var paywallContent: some View {
        // The dock is an inset rather than the last rows of a stack that is
        // merely *told* to be one page tall. Measuring the page against
        // `proxy.size.height` looked right and wasn't: that height runs to the
        // bottom of the screen, underneath the tab bar, so on the Bloom+ tab the
        // stack ended behind the bar and took Restore/Terms/Privacy with it.
        // Losing those is an App Store 3.1.2 problem, and a stack sized past the
        // viewport clips silently instead of complaining, so the guarantee needs
        // to be structural: an inset cannot be covered by the bar, and the
        // scroll view is inset by exactly the dock's height.
        //
        // The outer reader measures the whole page, dock included. That is the
        // number `PaywallMetrics` wants — how big this device is — and it has
        // to be available to the dock as well, which is built outside the inner
        // reader and so cannot see it.
        GeometryReader { page in
            let m = PaywallMetrics(pageHeight: page.size.height - pitchHeaderPremium)
            GeometryReader { proxy in
                // `proxy.size.height` is already the region left over once the
                // status bar, the tab bar, and the dock are taken out, because
                // the reader sits inside all three. (`safeAreaInsets` reports
                // what was removed, so subtracting it here takes the same 330pt
                // off twice and leaves a 200pt page.) It is handed to the stack
                // as a number rather than as a proposal, because a scroll view
                // will not commit to a height along its own scroll axis.
                ScrollView(showsIndicators: false) {
                    paywallStack(m, fitting: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { purchaseDock(m) }
        }
    }

    /// Tapping a plan card used to rebuild this stack four ways at once: the
    /// VStack spacing changed, the habit line swapped text (and height), the
    /// benefit list grew or shrank by two rows, and the trial timeline was
    /// inserted or removed outright. All of it inside a GeometryReader whose
    /// minHeight forces the ScrollView to re-measure, with no explicit
    /// animation, so SwiftUI popped every change on a different implicit curve.
    /// That is the "glitchy" selection: the page visibly reflowed on every tap.
    ///
    /// The fix is to make selection change appearance, not layout. Spacing is
    /// fixed, the benefit list is a fixed length, and the timeline slot holds
    /// its height while its contents cross-fade. One animation, keyed to the
    /// selected plan, drives what is left.
    ///
    /// The four blocks are laid out by `PaywallPageLayout`, which splits
    /// whatever is left over evenly between them. Splitting the surplus is only
    /// half the fix, though: three equal spacers were still three equal holes
    /// back when the only thing that ever grew was the space between the cards.
    /// The other half is `PaywallMetrics`, which has already spent most of this
    /// device's extra height on the blocks themselves, so by the time the
    /// layout gets here there is not much surplus left to split.
    private func paywallStack(_ m: PaywallMetrics, fitting pageHeight: CGFloat) -> some View {
        let top = m.stackTopPadding(hasCloseButton: displayCloseButton)
        return PaywallPageLayout(
            pageHeight: max(0, pageHeight - top - Self.stackBottomPadding),
            minGap: m.blockGap
        ) {
            VStack(spacing: 0) {
                savingsValueHeader(m)
                habitComparisonLine(m)
                    .padding(.top, m.lerp(8, 12))
            }
            benefitShowcase(m)
            planCards(m)
            trialTimelineSlot(m)
        }
        .modifier(PaywallStackProbe())
        .padding(.horizontal, m.horizontalGutter)
        .padding(.top, top)
        .padding(.bottom, Self.stackBottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: selectedPackage?.identifier)
        .overlay(alignment: .topTrailing) { metricsReadout(m, fitting: pageHeight) }
        .onPreferenceChange(PaywallLayoutProbeKey.self) { layoutProbe = $0 }
    }

    private static let stackBottomPadding: CGFloat = 2

    /// `-paywallMetrics` prints the page height, the height left for the stack,
    /// what the stack laid out to, and `size`. Every ramp in `PaywallMetrics`
    /// was calibrated against these numbers on real device geometry, so keeping
    /// the readout means the next tune-up doesn't start by guessing them again.
    /// `c` above `fit` is the page overflowing: the trial timeline is being
    /// scrolled out of sight and the ramps are spending more than they have.
    @ViewBuilder
    private func metricsReadout(_ m: PaywallMetrics, fitting pageHeight: CGFloat) -> some View {
        #if DEBUG
        if PaywallLayoutProbe.isEnabled {
            Text("h \(Int(m.pageHeight)) fit \(Int(pageHeight)) c \(Int(layoutProbe.content)) t \(String(format: "%.2f", m.size))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.85), in: Capsule())
        }
        #endif
    }

    /// CTA, price disclosure, trust line, and the legal links, held out of the
    /// scroll so they are on screen whatever the device, the Dynamic Type size,
    /// or the length of the copy above them. The cream background runs to the
    /// bottom of the screen (behind the tab bar) and fades in above the CTA, so
    /// content scrolling underneath dissolves instead of being sliced off.
    private func purchaseDock(_ m: PaywallMetrics) -> some View {
        VStack(spacing: m.dockSpacing) {
            purchaseSection(m)
            trustRow(m)
            footerLinks(m)
        }
        .padding(.horizontal, m.horizontalGutter)
        .padding(.top, m.lerp(6, 10))
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background { Theme.background.ignoresSafeArea(edges: .bottom) }
        // The fade belongs to the dock's height. Hung above it as an offset
        // overlay it drew over live content instead of reserving room, so at
        // rest the card above the CTA dissolved halfway through and read as a
        // clipped card rather than a scroll edge.
        .padding(.top, Self.dockFadeHeight)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.dockFadeHeight)
        }
    }

    private static let dockFadeHeight: CGFloat = 10

    /// Reserved height whenever *any* offered plan carries a trial, so moving
    /// between a trial plan and Lifetime fades the card instead of collapsing
    /// the stack under the user's thumb.
    ///
    /// Both states are always built and cross-faded by opacity, so the slot is
    /// as tall as the taller of the two. A hardcoded 92pt used to do this job
    /// and was short by roughly eighty points (the compact timeline is three
    /// labelled steps plus a footnote), so selecting Lifetime on the Bloom+ tab
    /// dropped the whole purchase dock down the screen.
    @ViewBuilder
    private func trialTimelineSlot(_ m: PaywallMetrics) -> some View {
        if anyPackageOffersTrial {
            let showsTimeline = selectedTrialDays != nil
            ZStack {
                trialTimelineCard(days: selectedTrialDays ?? longestOfferedTrialDays ?? 0, m)
                    .opacity(showsTimeline ? 1 : 0)
                    .accessibilityHidden(!showsTimeline)
                // Lifetime has no trial, so it gets the same card at the same
                // size rather than a bare sentence floating in the gap the
                // reserved height leaves behind.
                lifetimeNoteCard(m)
                    .opacity(showsTimeline ? 0 : 1)
                    .accessibilityHidden(showsTimeline)
            }
        }
    }

    private func trialTimelineCard(days: Int, _ m: PaywallMetrics) -> some View {
        TrialTimeline(
            trialDays: days,
            billingNote: nil,
            remindersEnabled: !remindersDenied,
            compact: true,
            layout: .horizontal,
            sizing: TrialTimeline.Sizing(
                marker: m.timelineMarkerSize,
                glyph: m.timelineGlyphSize,
                title: m.timelineTitleSize,
                detail: m.timelineDetailSize,
                rowGap: m.timelineRowGap,
                columnGap: m.timelineColumnGap
            )
        )
        .padding(.horizontal, m.timelinePaddingH)
        .padding(.vertical, m.timelinePaddingV)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: m.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: m.cardRadius)
                .stroke(Theme.ringTrack.opacity(0.6), lineWidth: 1)
        }
    }

    /// Deliberately not `maxHeight: .infinity`: a greedy card ate the stack's
    /// flexible spacer and drew itself as a near-empty box half the screen tall
    /// once the timeline it shares a slot with became a three-column strip. It
    /// now sizes to its content and centres in the slot.
    private func lifetimeNoteCard(_ m: PaywallMetrics) -> some View {
        HStack(spacing: m.lerp(11, 14)) {
            Image(systemName: "infinity")
                .font(.system(size: m.timelineGlyphSize + 2, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: m.timelineMarkerSize, height: m.timelineMarkerSize)
                .background(Theme.brandPrimary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("One-time purchase")
                    .font(m.rounded(m.benefitTitleSize, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("No trial, no renewal. Bloom+ stays unlocked.")
                    .font(m.rounded(m.timelineDetailSize))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, m.timelinePaddingH + 2)
        .padding(.vertical, m.timelinePaddingV + 4)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: m.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: m.cardRadius)
                .stroke(Theme.ringTrack.opacity(0.6), lineWidth: 1)
        }
    }

    private var anyPackageOffersTrial: Bool {
        sortedPackages.contains { subscriptions.isEligibleForIntroOffer($0) }
    }

    /// Sizes the hidden timeline while a no-trial plan is selected: the longest
    /// offer on the stack is the tallest that card can ever be.
    private var longestOfferedTrialDays: Int? {
        sortedPackages.compactMap { trialDays(for: $0) }.max()
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Theme.brandPrimary)
            Text("Loading plans…")
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            // Terms, Privacy, and Restore must stay reachable from every paywall
            // state (Apple 3.1.2), not just the loaded one.
            footerLinks(.compact)
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 52 : 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("Couldn't Load Plans")
                .font(Theme.body(weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(subscriptions.lastError ?? "Check your connection and try again.")
                .font(Theme.subhead())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task {
                    await subscriptions.fetchProducts()
                    selectDefaultPackageIfNeeded()
                }
            }
            .font(Theme.subhead(weight: .semibold))
            .foregroundStyle(Theme.brandPrimary)
            Spacer()
            // Even when plans fail to load, a returning subscriber must be able to
            // restore, and Terms/Privacy must remain available (Apple 3.1.2).
            footerLinks(.compact)
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 52 : 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func eyebrow(_ text: String, size: CGFloat = 11) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(Theme.brandPrimary.opacity(0.9))
    }

    /// Savings-led hero. When we have real spend + streak data we lead with the
    /// money already saved — the "whoa, I've saved a lot" moment — and frame the
    /// upgrade as treating themselves to the tools that keep it going. Falls back
    /// to a focus/feature pitch when there's no savings data yet.
    @ViewBuilder
    private func savingsValueHeader(_ m: PaywallMetrics) -> some View {
        VStack(alignment: .leading, spacing: m.heroLineSpacing) {
            if let focus {
                Text(focus.pitchHeadline)
                    .font(m.rounded(m.heroHeadlineSize, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(hasSavings
                     ? "You've already saved \(moneySaved) staying sober. Treat yourself to the tools that keep it growing."
                     : focus.pitchSubheadline)
                    .font(m.rounded(m.heroSubheadSize))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if hasSavings {
                eyebrow("YOU'VE SAVED SO FAR", size: m.heroEyebrowSize)
                Text(moneySaved)
                    .font(.system(size: m.heroAmountSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Across \(heroDays) sober day\(heroDays == 1 ? "" : "s"). Put a fraction toward keeping it.")
                    .font(m.rounded(m.heroSubheadSize))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if costPerDayCents > 0 {
                eyebrow("YOUR MONEY, KEPT", size: m.heroEyebrowSize)
                let yearlyLabel = Self.currencyFormatter.string(from: NSNumber(value: yearlySpend)) ?? "$\(yearlySpend)"
                Text("Up to \(yearlyLabel)/yr")
                    .font(.system(size: m.heroAmountSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Stays in your pocket, not on alcohol. Bloom+ keeps the streak that gets you there.")
                    .font(m.rounded(m.heroSubheadSize))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                eyebrow("BLOOM+", size: m.heroEyebrowSize)
                Text("Unlock the full toolkit")
                    .font(m.rounded(m.heroHeadlineSize + 2, .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Your garden, journal, health timeline, and savings. Everything that keeps you sober.")
                    .font(m.rounded(m.heroSubheadSize))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The one price anchor the App Store can't offer: what Bloom+ costs in the
    /// units the user is already trying to spend less of. Tracks the selected
    /// plan so switching to monthly re-frames the sentence rather than leaving
    /// a stale yearly comparison on screen.
    ///
    /// Only on pitch paywalls, which can afford the row: they drop the lifetime
    /// card, where the Bloom+ tab carries all three plans and is the variant
    /// that runs out of page first.
    @ViewBuilder
    /// Only rendered on pitch paywalls (never the Bloom+ tab, which shows
    /// Lifetime), so its text changes with selection but its presence does not.
    private func habitComparisonLine(_ m: PaywallMetrics) -> some View {
        if !showsLifetime,
           let sentence = selectedPackage?.soberHabitComparisonSentence(costPerDayCents: costPerDayCents) {
            HStack(spacing: m.lerp(7, 9)) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: m.lerp(11, 13), weight: .bold))
                    .foregroundStyle(Theme.brandPrimary.opacity(0.85))
                Text(sentence)
                    .font(m.rounded(m.benefitTitleSize, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, m.lerp(13, 15))
            .padding(.vertical, m.lerp(10, 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.brandPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: m.lerp(12, 15)))
        }
    }

    /// Length of the trial the selected plan actually carries, or nil when this
    /// user isn't being offered one. Derived from the store product every time.
    private var selectedTrialDays: Int? {
        selectedPackage.flatMap { trialDays(for: $0) }
    }

    private func trialDays(for package: Package) -> Int? {
        guard subscriptions.isEligibleForIntroOffer(package),
              let label = package.soberIntroOfferLabel else { return nil }
        let digits = String(label.drop { !$0.isNumber }.prefix { $0.isNumber })
        return Int(digits)
    }

    /// Always the same number of rows, whatever plan is selected.
    ///
    /// This used to return all four benefits for a no-trial plan and two for a
    /// trial plan. Since Lifetime carries no trial, tapping between Lifetime and
    /// Yearly added or removed two rows mid-stack, which was the single largest
    /// jump in the selection glitch. The trim itself is still right — at the
    /// moment someone is deciding, "when am I charged?" outranks a fourth
    /// bullet — so it is now unconditional rather than selection-dependent.
    ///
    /// The focused feature always survives, so a contextual paywall still leads
    /// with the thing the user just tapped.
    private var visibleBenefits: [BloomFeature] {
        let all = BloomFeature.allCases
        let limit = 3
        var kept = all.filter { $0 == focus }
        for feature in all where kept.count < limit && !kept.contains(feature) {
            kept.append(feature)
        }
        return all.filter { kept.contains($0) }
    }

    /// On a screen with room, each benefit says what it *is* as well as what
    /// it's called, and the card gets a label. Three one-line rows blown up to
    /// fill a 6.9" phone is still three one-line rows; what a big screen should
    /// buy the reader is more of the pitch, not a bigger version of less of it.
    private func benefitShowcase(_ m: PaywallMetrics) -> some View {
        VStack(alignment: .leading, spacing: m.lerp(5, 9)) {
            if m.showsExpandedBenefits {
                eyebrow("WHAT BLOOM+ UNLOCKS", size: m.sectionLabelSize)
                    .padding(.leading, 2)
            }
            VStack(alignment: .leading, spacing: m.benefitRowSpacing) {
                ForEach(visibleBenefits, id: \.self) { feature in
                    benefitRow(feature, highlighted: focus == feature, m)
                }
            }
            .padding(.horizontal, m.benefitCardPaddingH)
            .padding(.vertical, m.benefitCardPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: m.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: m.cardRadius)
                    .stroke(Theme.ringTrack.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
    }

    private func benefitRow(_ feature: BloomFeature, highlighted: Bool, _ m: PaywallMetrics) -> some View {
        HStack(alignment: .center, spacing: m.lerp(12, 14)) {
            Image(systemName: feature.icon)
                .font(.system(size: m.benefitGlyphSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: m.benefitIconSize, height: m.benefitIconSize)
                .background(Theme.brandGradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(m.rounded(m.benefitTitleSize, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if m.showsExpandedBenefits {
                    Text(feature.detail)
                        .font(m.rounded(m.benefitDetailSize))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.system(size: m.lerp(12, 14), weight: .heavy))
                .foregroundStyle(Theme.brandPrimary.opacity(highlighted ? 1 : 0.55))
        }
        .frame(minHeight: m.benefitIconSize)
        .padding(.horizontal, highlighted ? 8 : 0)
        .padding(.vertical, highlighted ? m.lerp(2, 5) : 0)
        .background(
            highlighted ? Theme.brandPrimary.opacity(0.08) : .clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private var sortedPackages: [Package] {
        let order: [SoberPackageKind: Int] = [.yearly: 0, .monthly: 1, .lifetime: 2]
        return subscriptions.packages
            .filter { showsLifetime || $0.soberPackageKind != .lifetime }
            .sorted { (order[$0.soberPackageKind] ?? 9) < (order[$1.soberPackageKind] ?? 9) }
    }

    private var monthlyPackage: Package? {
        subscriptions.packages.first { $0.soberPackageKind == .monthly }
    }

    private func planCards(_ m: PaywallMetrics) -> some View {
        VStack(spacing: m.planSpacing) {
            ForEach(sortedPackages, id: \.identifier) { package in
                PlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: subscriptions.isEligibleForIntroOffer(package),
                    monthlyReference: monthlyPackage,
                    metrics: m
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    private func purchaseSection(_ m: PaywallMetrics) -> some View {
        VStack(spacing: m.dockInnerSpacing) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(m.rounded(m.ctaTitleSize, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: m.ctaHeight)
            }
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: m.ctaRadius))
            .shadow(color: Theme.brandPrimary.opacity(0.3), radius: 12, y: 6)
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedPackage == nil)

            disclosureSlot(m)

            if let errorMessage {
                Text(errorMessage)
                    .font(m.rounded(m.disclosureSize))
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            } else if let restoreMessage {
                Text(restoreMessage)
                    .font(m.rounded(m.disclosureSize))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Small trust signals. The billing reassurance used to read "Apple handles
    /// billing reminders", which isn't true: Apple does not reliably notify
    /// before a free trial converts, and users who relied on it got charged and
    /// left one-star reviews saying so. The reminder Sober schedules itself is
    /// the real one, and it now has its own step in the trial timeline above, so
    /// this row sticks to claims that hold.
    ///
    /// Both variants are always built and cross-faded, like the disclosure and
    /// the timeline: the trial line wraps to two lines where the no-trial one
    /// fits on one, and a row that changes height under a bottom-anchored dock
    /// moves the CTA out from under the user's thumb.
    private func trustRow(_ m: PaywallMetrics) -> some View {
        let showsTrialTrust = selectedPackage.map { subscriptions.isEligibleForIntroOffer($0) } ?? false
        return ZStack {
            trustLine(
                icon: "bell.fill",
                text: "No payment now · Cancel any time · Data stays on-device",
                m
            )
            .opacity(showsTrialTrust ? 1 : 0)
            .accessibilityHidden(!showsTrialTrust)

            trustLine(icon: "lock.fill", text: "Your data stays on this device", m)
                .opacity(showsTrialTrust ? 0 : 1)
                .accessibilityHidden(showsTrialTrust)
        }
        .padding(.horizontal, 4)
    }

    private func trustLine(icon: String, text: String, _ m: PaywallMetrics) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: m.lerp(11, 12), weight: .semibold))
                .foregroundStyle(Theme.brandPrimary.opacity(0.8))
            Text(text)
                .font(m.rounded(m.trustSize))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private func footerLinks(_ m: PaywallMetrics) -> some View {
        HStack(spacing: m.lerp(12, 16)) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)
            Text("·")
            Link("Terms", destination: PaywallLinks.standardEULA)
            Text("·")
            Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
        }
        .font(m.rounded(m.footerSize))
        .foregroundStyle(Theme.textTertiary)
        .tint(Theme.brandPrimary)
    }

    private var ctaTitle: String {
        guard let package = selectedPackage else { return "Continue" }
        if package.soberPackageKind == .lifetime { return "Unlock Lifetime" }
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.soberIntroOfferLabel {
            let period = trial.replacingOccurrences(of: " free trial", with: "", options: .caseInsensitive)
            return "Start \(period.capitalized) Free Trial"
        }
        return "Continue with Bloom+"
    }

    /// Apple 3.1.2: full billed price, trial terms, auto-renew, and how to manage.
    /// Cancellation is in disclosure only — not a separate trust-row CTA.
    ///
    /// Every plan's disclosure is laid out at once and all but the selected one
    /// hidden, so the slot is as tall as the longest of them. The lifetime line
    /// is a line shorter than the auto-renew one, and this text sits between
    /// the CTA and the bottom-anchored footer, so letting it resize moved the
    /// button on every selection change.
    private func disclosureSlot(_ m: PaywallMetrics) -> some View {
        ZStack {
            ForEach(sortedPackages, id: \.identifier) { package in
                let isSelected = package.identifier == selectedPackage?.identifier
                Text(disclosure(for: package))
                    .font(m.rounded(m.disclosureSize))
                    // Tertiary sand-gray on cream is the palette's lightest text
                    // and this is the one block on the paywall a user actually
                    // has to be able to read before paying. Secondary keeps it
                    // quiet without making it a squint.
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(!isSelected)
            }
        }
    }

    private func disclosure(for package: Package) -> String {
        let price = package.soberPriceLabel
        if package.soberPackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews until cancelled in Settings, at least 24 hours before renewal."
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.soberIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
    }

    /// Yearly-first default keeps the one-tap trial aligned with the best value;
    /// monthly remains the lower-commitment alternative.
    private func selectDefaultPackageIfNeeded() {
        #if DEBUG
        if let mode = PaywallScreenshotMode.current, !subscriptions.packages.isEmpty {
            switch mode {
            case .monthly:
                selectedPackage = subscriptions.packages.first { $0.soberPackageKind == .monthly }
            case .lifetime:
                selectedPackage = subscriptions.packages.first { $0.soberPackageKind == .lifetime }
            case .yearly, .trial:
                selectedPackage = subscriptions.packages.first { $0.soberPackageKind == .yearly }
            }
            return
        }
        #endif
        // Select from the *visible* stack: with lifetime filtered out of pitch
        // paywalls, falling back to `packages.first` could preselect a card the
        // user can't see.
        guard selectedPackage == nil, !sortedPackages.isEmpty else { return }
        selectedPackage = sortedPackages.first { $0.soberPackageKind == .yearly }
            ?? sortedPackages.first { $0.soberPackageKind == .monthly }
            ?? sortedPackages.first
    }

    private func startPurchase() {
        guard let package = selectedPackage else { return }
        ConversionDiagnostics.record(.trialCTATapped)
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    ConversionDiagnostics.record(.purchaseSucceeded)
                    break // onChange(of: isProSubscriber) dismisses the sheet
                case .pending:
                    ConversionDiagnostics.record(.purchasePending)
                    // Deferred (Ask to Buy / SCA / parental approval): the
                    // transaction isn't complete yet. Keep the sheet open with a
                    // confirmation so it doesn't look like nothing happened; the
                    // PurchasesDelegate flips isProSubscriber and dismisses once
                    // it's approved.
                    restoreMessage = "Your purchase is awaiting approval. Bloom+ unlocks as soon as it's confirmed."
                case .cancelled:
                    ConversionDiagnostics.record(.purchaseCancelled)
                    errorMessage = "Purchase cancelled. Tap again to continue."
                }
            } catch {
                ConversionDiagnostics.record(.purchaseFailed)
                errorMessage = "Couldn't complete the purchase. Please try again."
            }
        }
    }

    private func startRestore() {
        errorMessage = nil
        restoreMessage = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            await subscriptions.restorePurchases()
            if !subscriptions.isProSubscriber {
                restoreMessage = subscriptions.lastError
                    ?? "No active Bloom+ purchase found for this Apple ID."
            }
        }
    }
    #endif

    // MARK: - Dev placeholder (no RC key / simulator without StoreKit)
    // DEBUG-only: never compiled into App Store (Release) builds, so the
    // free-unlock "Continue (dev)" button can never reach end users or reviewers.

    #if DEBUG || !canImport(RevenueCat)
    private var devPlaceholder: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                savingsValueHeader(.compact)
                benefitShowcase(.compact)
                // No amounts here. A price the store did not hand us is worse
                // than no price at all, and a literal drifts a tier out of date
                // the moment pricing moves.
                Text("Prices come from the App Store and aren't available in this build.")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    subscriptions.setLocalOverride(isPro: true)
                    dismiss()
                } label: {
                    Text("Continue (dev)")
                        .font(Theme.body(weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 16))
                Button("Restore Purchases") {
                    Task { await subscriptions.refresh() }
                }
                .font(Theme.caption())
                .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 22)
            .padding(.top, displayCloseButton ? 56 : 24)
            .padding(.bottom, 32)
        }
    }
    #endif

    // MARK: - Shared chrome

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Spacer()
        }
    }
}

#if canImport(RevenueCat)
private struct PlanCard: View {
    let package: Package
    let isSelected: Bool
    let showsTrialBadge: Bool
    /// Used to derive a "save X%" badge and a strikethrough anchor price on
    /// non-monthly plans. Nil hides the comparison.
    let monthlyReference: Package?
    /// Every dimension on the card, ramped to the height of the page it sits
    /// on. A plan row that is 52pt tall on a 6.9" screen is a control, not a
    /// choice worth making.
    let metrics: PaywallMetrics
    let onTap: () -> Void

    private var kind: SoberPackageKind { package.soberPackageKind }

    private var savingsPercent: Int? {
        guard kind == .yearly else { return nil }
        return package.soberSavingsPercent(vsMonthly: monthlyReference)
    }

    private var anchorPrice: String? {
        guard kind == .yearly else { return nil }
        return package.soberAnchorPriceLabel(vsMonthly: monthlyReference)
    }

    private var subtitle: String? {
        // Keep this short: trial + per-month on one line truncates on Pro widths.
        if kind == .yearly, let perMonth = package.soberPerMonthLabel {
            // Derived, never literal: a hardcoded "7 days free" here silently
            // misstates the offer the second the intro period changes in ASC.
            if showsTrialBadge, let trial = package.soberIntroOfferLabel {
                let period = trial.replacingOccurrences(
                    of: " free trial", with: "", options: .caseInsensitive
                )
                return "\(period) free · \(perMonth)"
            }
            return perMonth
        }
        // Monthly's trial lives in its badge, which spells out the length. A
        // "7-Day Free Trial" subtitle under a "7-DAY FREE TRIAL" badge said the
        // same thing twice and cost the card a third row.
        if kind == .monthly { return nil }
        if kind == .lifetime { return "One-time · no subscription" }
        return nil
    }

    /// One superlative per stack. Lifetime used to carry "BEST DEAL", which
    /// competed with yearly's badge for the same slot and pointed the loudest
    /// label on the screen at the only plan with no free trial. Its subtitle
    /// already says "One-time · no subscription", so the badge said nothing the
    /// card didn't.
    private var badgeLabel: String? {
        if kind == .yearly, let pct = savingsPercent { return "RECOMMENDED · SAVE \(pct)%" }
        if showsTrialBadge, kind == .monthly {
            return package.soberIntroOfferLabel?.uppercased() ?? "FREE TRIAL"
        }
        return nil
    }

    /// Dropped to when the full badge won't fit, on a 4.7" screen or at a large
    /// Dynamic Type size. Scaling the type down only bought a few points before
    /// the label truncated to "RECOMMENDED · SAVE 7…", which turns the one badge
    /// carrying the offer into a riddle; the discount is the part worth keeping.
    private var shortBadgeLabel: String? {
        if kind == .yearly, let pct = savingsPercent { return "SAVE \(pct)%" }
        if showsTrialBadge, kind == .monthly { return "FREE TRIAL" }
        return nil
    }

    private var badgeFill: Color {
        kind == .lifetime ? Theme.accent : Theme.brandPrimary
    }

    private var titleView: some View {
        Text(package.soberDisplayName)
            .font(metrics.rounded(metrics.planTitleSize, .bold))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
    }

    @ViewBuilder
    private func badge(_ text: String?) -> some View {
        if let text {
            badgeChip(text)
        }
    }

    private func badgeChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: metrics.planBadgeSize, weight: .heavy))
            .foregroundStyle(.white)
            // Shrink-to-fit rather than `fixedSize`. Held at its ideal width the
            // badge and the price together demanded ~356pt, more than a 375pt
            // phone has after gutters, so the card grew past the screen and
            // pulled every other card in the stack out with it.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, metrics.lerp(7, 9))
            .padding(.vertical, metrics.lerp(3, 4))
            .background(badgeFill, in: Capsule())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: metrics.lerp(14, 16)) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.brandPrimary : Theme.ringTrack, lineWidth: 2)
                        .frame(width: metrics.planRadioSize, height: metrics.planRadioSize)
                    if isSelected {
                        Circle()
                            .fill(Theme.brandPrimary)
                            .frame(width: metrics.planRadioSize * 0.55, height: metrics.planRadioSize * 0.55)
                    }
                }

                VStack(alignment: .leading, spacing: metrics.lerp(3, 4)) {
                    // One decision, made where the width is actually known.
                    // Nesting a second ViewThatFits inside the badge made the
                    // choice against a proposal the outer stack had already
                    // narrowed, so a 6.1" screen with room for the full badge
                    // still got the short one.
                    //
                    // Shortening the label is preferred over dropping it to a
                    // second row: the wrapped badge made the recommended plan a
                    // row taller than the two under it, which is 18pt the
                    // 6.1" class does not have and an uneven stack besides.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: metrics.lerp(6, 8)) {
                            titleView
                            badge(badgeLabel)
                        }
                        HStack(spacing: metrics.lerp(6, 8)) {
                            titleView
                            badge(shortBadgeLabel ?? badgeLabel)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            titleView
                            badge(shortBadgeLabel ?? badgeLabel)
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(metrics.rounded(metrics.planSubtitleSize, .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Spacer(minLength: 8)

                // The real billed price is always visible (Apple 3.1.2). Trials
                // are communicated by the badge + subtitle, never by hiding price.
                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.soberPriceLabel)
                        .font(metrics.rounded(metrics.planPriceSize, .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let anchorPrice {
                        Text(anchorPrice)
                            .font(metrics.rounded(metrics.planAnchorSize).monospacedDigit())
                            .strikethrough(true, color: Theme.textTertiary)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                // Priority, not a fixed width: the price still wins the space it
                // needs against the title column, but on a narrow screen it can
                // scale down instead of forcing the card wider than the phone.
                .layoutPriority(1)
            }
            .padding(.horizontal, metrics.planPaddingH)
            // Vertical padding as well as a floor: the recommended plan wraps
            // its badge under the title on narrow widths, and a card with only
            // a minimum height let those three lines run into its own border.
            .padding(.vertical, metrics.planPaddingV)
            .frame(minHeight: metrics.planMinHeight)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Theme.brandPrimary.opacity(0.08) : Theme.cardSurface,
                in: RoundedRectangle(cornerRadius: metrics.planRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: metrics.planRadius)
                    .stroke(isSelected ? Theme.brandPrimary : Theme.ringTrack.opacity(0.6),
                            lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif


/// DEBUG calibration plumbing for `-paywallMetrics`. Compiled always (it costs
/// one transparent background) so the readout can't rot between tune-ups.
struct PaywallLayoutProbe: Equatable {
    /// The laid-out stack's height. Above the page height it is overflowing and
    /// the trial timeline is being scrolled out of sight.
    var content: CGFloat = 0

    #if DEBUG
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-paywallMetrics")
    #else
    static let isEnabled = false
    #endif
}

struct PaywallLayoutProbeKey: PreferenceKey {
    static let defaultValue = PaywallLayoutProbe()
    static func reduce(value: inout PaywallLayoutProbe, nextValue: () -> PaywallLayoutProbe) {
        value.content = max(value.content, nextValue().content)
    }
}

private struct PaywallStackProbe: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            if PaywallLayoutProbe.isEnabled {
                GeometryReader { g in
                    Color.clear.preference(
                        key: PaywallLayoutProbeKey.self,
                        value: PaywallLayoutProbe(content: g.size.height)
                    )
                }
            }
        }
    }
}


/// Lays the paywall's four blocks down one page and splits whatever is left
/// over evenly between them.
///
/// This is a `Layout` rather than a `VStack` of `Spacer(minLength:)`s because
/// the stack version was not deterministic. Inside a `ScrollView`, whether a
/// flexible spacer expands depends on whether the proposal that reaches it is
/// definite, and that answer changed with the content: the same page filled
/// correctly at one size and left a 70pt hole above the CTA one step up. A
/// layout handed the page height outright cannot be talked out of it.
///
/// It also makes the fallback explicit. When the blocks want more than the page
/// has — a 4.7" screen, or a large Dynamic Type size — the layout reports its
/// natural height and the scroll view takes over, rather than silently pinning
/// the gaps to their minimum and clipping the last card.
struct PaywallPageLayout: Layout {
    /// The height to fill, from the reader around the scroll view rather than
    /// from the proposal — a scroll view will not commit to a height along its
    /// scroll axis, which is the whole reason the spacers were unreliable.
    let pageHeight: CGFloat
    /// The floor for each gap. Anything the blocks didn't take is shared out
    /// above it, evenly, so surplus never pools in one place.
    let minGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let heights = blockHeights(subviews, width: width)
        return CGSize(width: width, height: max(naturalHeight(heights), pageHeight))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let heights = blockHeights(subviews, width: bounds.width)
        let gaps = gapCount(heights)
        let content = heights.reduce(0, +)
        let gap = gaps > 0 ? max(minGap, (bounds.height - content) / CGFloat(gaps)) : 0

        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let height = heights[index]
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: height)
            )
            // An absent block (the timeline slot, when no plan offers a trial)
            // takes no room and earns no gap.
            guard height > 0.5 else { continue }
            y += height + gap
        }
    }

    private func blockHeights(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    private func gapCount(_ heights: [CGFloat]) -> Int {
        max(0, heights.filter { $0 > 0.5 }.count - 1)
    }

    private func naturalHeight(_ heights: [CGFloat]) -> CGFloat {
        heights.reduce(0, +) + minGap * CGFloat(gapCount(heights))
    }
}
