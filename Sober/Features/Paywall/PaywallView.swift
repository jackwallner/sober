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
        GeometryReader { proxy in
            // `proxy.size.height` is already the region left over once the
            // status bar, the tab bar, and the dock are taken out, because the
            // reader sits inside all three. (`safeAreaInsets` reports what was
            // removed, so subtracting it here takes the same 330pt off twice and
            // leaves a 200pt page.) Filling that height is what lets the spacers
            // share the slack on a tall screen instead of pooling it all in one
            // hole above the CTA.
            ScrollView(showsIndicators: false) {
                paywallStack
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseDock }
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
    /// Slack is shared by three equal spacers rather than spent on one. A single
    /// spacer put every spare point of a 6.9" screen in the same place, so the
    /// page read as four blocks crammed under the status bar and a hole above
    /// the CTA. Split, each section breathes by the same amount.
    ///
    /// Every gap is a spacer's `minLength` and nothing else, so the floor and
    /// the flex are one number. Stack spacing *plus* spacers charged every
    /// device for the tightest one: the 6.1" class paid for a gap it could not
    /// afford while the 6.9" spent its surplus twice.
    private var paywallStack: some View {
        VStack(spacing: 0) {
            savingsValueHeader
            habitComparisonLine
                .padding(.top, 8)

            Spacer(minLength: 8)
            benefitShowcase

            Spacer(minLength: 8)
            planCards

            Spacer(minLength: 8)
            trialTimelineSlot
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 38 : 10)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: selectedPackage?.identifier)
    }

    /// CTA, price disclosure, trust line, and the legal links, held out of the
    /// scroll so they are on screen whatever the device, the Dynamic Type size,
    /// or the length of the copy above them. The cream background runs to the
    /// bottom of the screen (behind the tab bar) and fades in above the CTA, so
    /// content scrolling underneath dissolves instead of being sliced off.
    private var purchaseDock: some View {
        VStack(spacing: 8) {
            purchaseSection
            trustRow
            footerLinks
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
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
    private var trialTimelineSlot: some View {
        if anyPackageOffersTrial {
            let showsTimeline = selectedTrialDays != nil
            ZStack {
                trialTimelineCard(days: selectedTrialDays ?? longestOfferedTrialDays ?? 0)
                    .opacity(showsTimeline ? 1 : 0)
                    .accessibilityHidden(!showsTimeline)
                // Lifetime has no trial, so it gets the same card at the same
                // size rather than a bare sentence floating in the gap the
                // reserved height leaves behind.
                lifetimeNoteCard
                    .opacity(showsTimeline ? 0 : 1)
                    .accessibilityHidden(showsTimeline)
            }
        }
    }

    private func trialTimelineCard(days: Int) -> some View {
        TrialTimeline(
            trialDays: days,
            billingNote: nil,
            remindersEnabled: !remindersDenied,
            compact: true,
            layout: .horizontal
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ringTrack.opacity(0.6), lineWidth: 1)
        }
    }

    /// Deliberately not `maxHeight: .infinity`: a greedy card ate the stack's
    /// flexible spacer and drew itself as a near-empty box half the screen tall
    /// once the timeline it shares a slot with became a three-column strip. It
    /// now sizes to its content and centres in the slot.
    private var lifetimeNoteCard: some View {
        HStack(spacing: 11) {
            Image(systemName: "infinity")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.brandPrimary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("One-time purchase")
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("No trial, no renewal. Bloom+ stays unlocked.")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
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
            footerLinks
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
            footerLinks
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 52 : 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(Theme.brandPrimary.opacity(0.9))
    }

    /// Savings-led hero. When we have real spend + streak data we lead with the
    /// money already saved — the "whoa, I've saved a lot" moment — and frame the
    /// upgrade as treating themselves to the tools that keep it going. Falls back
    /// to a focus/feature pitch when there's no savings data yet.
    @ViewBuilder
    private var savingsValueHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let focus {
                Text(focus.pitchHeadline)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(hasSavings
                     ? "You've already saved \(moneySaved) staying sober. Treat yourself to the tools that keep it growing."
                     : focus.pitchSubheadline)
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if hasSavings {
                eyebrow("YOU'VE SAVED SO FAR")
                Text(moneySaved)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Across \(heroDays) sober day\(heroDays == 1 ? "" : "s"). Put a fraction toward keeping it.")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if costPerDayCents > 0 {
                eyebrow("YOUR MONEY, KEPT")
                let yearlyLabel = Self.currencyFormatter.string(from: NSNumber(value: yearlySpend)) ?? "$\(yearlySpend)"
                Text("Up to \(yearlyLabel)/yr")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Stays in your pocket, not on alcohol. Bloom+ keeps the streak that gets you there.")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                eyebrow("BLOOM+")
                Text("Unlock the full toolkit")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Your garden, journal, health timeline, and savings. Everything that keeps you sober.")
                    .font(Theme.subhead())
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
    private var habitComparisonLine: some View {
        if !showsLifetime,
           let sentence = selectedPackage?.soberHabitComparisonSentence(costPerDayCents: costPerDayCents) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.brandPrimary.opacity(0.85))
                Text(sentence)
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.brandPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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

    private var benefitShowcase: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(visibleBenefits, id: \.self) { feature in
                benefitRow(feature, highlighted: focus == feature)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ringTrack.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private func benefitRow(_ feature: BloomFeature, highlighted: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.brandGradient, in: Circle())

            Text(feature.title)
                .font(Theme.subhead(weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.brandPrimary.opacity(highlighted ? 1 : 0.55))
        }
        .frame(height: 26)
        .padding(.horizontal, highlighted ? 8 : 0)
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

    private var planCards: some View {
        VStack(spacing: 6) {
            ForEach(sortedPackages, id: \.identifier) { package in
                PlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: subscriptions.isEligibleForIntroOffer(package),
                    monthlyReference: monthlyPackage
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 9) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(Theme.body(weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.brandPrimary.opacity(0.3), radius: 12, y: 6)
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedPackage == nil)

            disclosureSlot

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            } else if let restoreMessage {
                Text(restoreMessage)
                    .font(Theme.caption())
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
    private var trustRow: some View {
        let showsTrialTrust = selectedPackage.map { subscriptions.isEligibleForIntroOffer($0) } ?? false
        return ZStack {
            trustLine(
                icon: "bell.fill",
                text: "No payment now · Cancel any time · Data stays on-device"
            )
            .opacity(showsTrialTrust ? 1 : 0)
            .accessibilityHidden(!showsTrialTrust)

            trustLine(icon: "lock.fill", text: "Your data stays on this device")
                .opacity(showsTrialTrust ? 0 : 1)
                .accessibilityHidden(showsTrialTrust)
        }
        .padding(.horizontal, 4)
    }

    private func trustLine(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.brandPrimary.opacity(0.8))
            Text(text)
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private var footerLinks: some View {
        HStack(spacing: 12) {
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
        .font(Theme.caption())
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
    private var disclosureSlot: some View {
        ZStack {
            ForEach(sortedPackages, id: \.identifier) { package in
                let isSelected = package.identifier == selectedPackage?.identifier
                Text(disclosure(for: package))
                    .font(Theme.caption())
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
                savingsValueHeader
                benefitShowcase
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
            .font(Theme.subhead(weight: .bold))
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
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.white)
            // Shrink-to-fit rather than `fixedSize`. Held at its ideal width the
            // badge and the price together demanded ~356pt, more than a 375pt
            // phone has after gutters, so the card grew past the screen and
            // pulled every other card in the stack out with it.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeFill, in: Capsule())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.brandPrimary : Theme.ringTrack, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.brandPrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
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
                        HStack(spacing: 6) {
                            titleView
                            badge(badgeLabel)
                        }
                        HStack(spacing: 6) {
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
                            .font(Theme.caption(weight: .semibold))
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
                        .font(Theme.subhead(weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let anchorPrice {
                        Text(anchorPrice)
                            .font(Theme.caption().monospacedDigit())
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
            .padding(.horizontal, 16)
            // Vertical padding as well as a floor: the recommended plan wraps
            // its badge under the title on narrow widths, and a card with only
            // a minimum height let those three lines run into its own border.
            .padding(.vertical, 7)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Theme.brandPrimary.opacity(0.08) : Theme.cardSurface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.brandPrimary : Theme.ringTrack.opacity(0.6),
                            lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
