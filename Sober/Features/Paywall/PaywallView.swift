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
/// Layout is structured around proven high-conversion patterns:
///   1. Personalized hero (money saved / day count) — anchored to actual progress.
///   2. Outcome-framed bullets — garden first, mirrors the product spine.
///   3. Plan stack with annual visually dominant: savings %, per-month anchor,
///      strikethrough monthly×12 price.
///   4. Trial-first CTA with disclosure inline (Apple 3.1.2).
///   5. Trust row above legal links (billing reminder, on-device — no cancel CTA).
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

    /// RevenueCat custom-paywall impression id for this entry point.
    var impressionId: String = "sober_paywall_sheet"

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }

    private var lifetimeSoberDays: Int { checkIns.filter { $0.wasSober }.count }

    /// Lifetime sober days is the single source of truth for "money saved" so
    /// the paywall, trial nudge, and Progress sheet never disagree by one or
    /// two days of streak vs. lifetime drift.
    private var heroDays: Int { max(lifetimeSoberDays, days) }

    private var costPerDayCents: Int { settingsRows.first?.costPerDayCents ?? 0 }

    private var moneySaved: String {
        let cents = heroDays * costPerDayCents
        let dollars = Double(cents) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    /// Outcome-framed bullets, garden first. Each line names a tangible thing
    /// the user will *do* in Bloom+, not just a feature module. Every bullet
    /// must map to a real Bloom+ gate — free features don't belong here.
    private let benefits: [(symbol: String, title: String)] = [
        ("leaf.fill", "Grow all 6 bonsai species as you go"),
        ("heart.text.square.fill", "Unlock the full 13-milestone health timeline"),
        ("book.closed.fill", "Daily journal prompts and reflections"),
        ("dollarsign.circle.fill", "Every dollar and calorie saved, tracked")
    ]

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()

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
        .foregroundStyle(.white)
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            if isPro && displayCloseButton { dismiss() }
        }
        .task {
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

    /// Single-viewport layout: every device must show the hero, benefits,
    /// plans, CTA, and trust row without scrolling. We use a fixed VStack
    /// with proportional spacers; the long-press benefit list is the only
    /// element that scales typography down on very short screens.
    #if canImport(RevenueCat)
    private var paywallContent: some View {
        VStack(spacing: 14) {
            savingsHero
            valueProof
            planCards
            purchaseSection
            trustRow
            footerLinks
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 52 : 20)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(.white)
            Text("Loading plans…")
                .font(Theme.caption())
                .foregroundStyle(.white.opacity(0.75))
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
                .foregroundStyle(.white.opacity(0.7))
            Text("Couldn't Load Plans")
                .font(Theme.body())
            Text(subscriptions.lastError ?? "Check your connection and try again.")
                .font(Theme.subhead())
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task {
                    await subscriptions.fetchProducts()
                    selectDefaultPackageIfNeeded()
                }
            }
            .font(Theme.subhead(weight: .semibold))
            .foregroundStyle(.white)
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

    /// Yearly spend on the habit (== projected yearly savings), for the anchor.
    private var yearlySpend: Int { Int((Double(costPerDayCents) * 365 / 100).rounded()) }

    /// Clean price of the yearly plan ("$29.99 / year" -> "$29.99") — the anchor
    /// always compares against the annual plan, regardless of which row is selected.
    private var yearlyAnchorPrice: String? {
        let yearly = subscriptions.packages.first { $0.soberPackageKind == .yearly }
        guard let raw = yearly?.soberPriceLabel else { return nil }
        return raw.components(separatedBy: " /").first?.trimmingCharacters(in: .whitespaces)
    }

    private var showsSpendAnchor: Bool {
        subscriptions.hasTrialOfferAvailable && yearlySpend >= 60 && yearlyAnchorPrice != nil
    }

    /// When a trial is on the table and we know the user's spend, lead the value
    /// case with the spend→price anchor (their habit costs $X/yr, Bloom+ is a
    /// fraction). Otherwise fall back to the outcome-framed benefit list.
    @ViewBuilder private var valueProof: some View {
        if showsSpendAnchor, let price = yearlyAnchorPrice {
            SavingsAnchorCard(
                yearlySpend: yearlySpend,
                spendCaption: "a year on alcohol",
                priceLabel: price,
                priceCaption: "a year of Bloom+",
                onBrand: true
            )
        } else {
            benefitList
        }
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(benefits, id: \.title) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.symbol)
                        .font(Theme.caption(weight: .semibold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                    Text(item.title)
                        .font(Theme.caption())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
    }

    private var monthlyPackage: Package? {
        subscriptions.packages.first { $0.soberPackageKind == .monthly }
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(subscriptions.packages, id: \.identifier) { package in
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
        VStack(spacing: 10) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(Theme.body(weight: .bold))
                        .foregroundStyle(Theme.brandPrimary)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(Theme.brandPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedPackage == nil)

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Small trust signals. We deliberately omit a "Cancel anytime in Settings"
    /// line: it isn't App Store mandated and drawing attention to cancellation
    /// before purchase suppresses conversions. Apple's renewal notification
    /// for trials is the only billing reassurance kept.
    private var trustRow: some View {
        VStack(spacing: 4) {
            if let pkg = selectedPackage,
               subscriptions.isEligibleForIntroOffer(pkg) {
                trustItem("checkmark.circle.fill", "No payment due now")
                trustItem("bell.fill", "Apple reminds you before the trial ends")
            }
            trustItem("iphone", "Your data stays on this device")
        }
    }

    private func trustItem(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(Theme.caption(weight: .semibold))
            Text(text)
                .font(Theme.caption())
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 6)
    }

    private var footerLinks: some View {
        HStack(spacing: 12) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(Theme.caption())
                    .underline()
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)
            Text("·")
            Link("Terms", destination: PaywallLinks.standardEULA)
            Text("·")
            Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
        }
        .font(Theme.caption())
        .foregroundStyle(.white.opacity(0.7))
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
    private var disclosureText: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.soberPriceLabel
        if package.soberPackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings."
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.soberIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
    }

    /// Annual-first default — the highest-LTV plan also doubles as the lowest
    /// per-month anchor, so pre-selecting it sets the right comparison frame.
    private func selectDefaultPackageIfNeeded() {
        guard selectedPackage == nil, !subscriptions.packages.isEmpty else { return }
        selectedPackage = subscriptions.packages.first { $0.soberPackageKind == .yearly }
            ?? subscriptions.packages.first
    }

    private func startPurchase() {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    break // onChange(of: isProSubscriber) dismisses the sheet
                case .pending:
                    // Deferred (Ask to Buy / SCA / parental approval): the
                    // transaction isn't complete yet. Keep the sheet open with a
                    // confirmation so it doesn't look like nothing happened; the
                    // PurchasesDelegate flips isProSubscriber and dismisses once
                    // it's approved.
                    restoreMessage = "Your purchase is awaiting approval. Bloom+ unlocks as soon as it's confirmed."
                case .cancelled:
                    errorMessage = "Purchase cancelled. Tap again to continue."
                }
            } catch {
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
            VStack(spacing: 24) {
                savingsHero
                benefitListPlaceholder
                Spacer(minLength: 8)
                Text("$4.99 / mo · $29.99 / yr · $79.99 lifetime")
                    .font(Theme.caption())
                Button {
                    subscriptions.setLocalOverride(isPro: true)
                    dismiss()
                } label: {
                    Text("Continue (dev)")
                        .font(Theme.body(weight: .bold))
                        .foregroundStyle(Theme.brandPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                Button("Restore Purchases") {
                    Task { await subscriptions.refresh() }
                }
                .font(Theme.caption())
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 22)
            .padding(.top, displayCloseButton ? 56 : 24)
            .padding(.bottom, 32)
        }
    }

    private var benefitListPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(benefits, id: \.title) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.symbol)
                        .font(Theme.subhead(weight: .semibold))
                        .frame(width: 22, height: 22)
                    Text(item.title)
                        .font(Theme.subhead())
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
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
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Spacer()
        }
    }

    /// Hero copy keys off real user progress. Personalization on a paywall is
    /// the single biggest conversion lever short of pricing — "you've already
    /// saved $X" reframes the purchase as reinvesting earned value, not
    /// spending new money. Falls back through three tiers as data thins.
    @ViewBuilder
    private var savingsHero: some View {
        let hasSavings = heroDays > 0 && costPerDayCents > 0
        let trialEligible = selectedPackage.map { subscriptions.isEligibleForIntroOffer($0) } ?? subscriptions.hasTrialOfferAvailable

        if let focus {
            VStack(spacing: 6) {
                Image(systemName: focus.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.95))
                Text(focus.pitchHeadline)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(focus.pitchSubheadline)
                    .font(Theme.caption())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
            }
        } else if trialEligible, let trial = selectedPackage?.soberIntroOfferLabel ?? subscriptions.trialOfferHeadlineLabel {
            let days = String(trial.drop { !$0.isNumber }.prefix { $0.isNumber })
            VStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.95))
                Text(days.isEmpty ? "Free trial" : "\(days) days free")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                Text(yearlyAnchorPrice.map { "Full access now. Then \($0)/yr — cancel anytime." }
                     ?? "Full access now. No charge until your trial ends.")
                    .font(Theme.caption())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
            }
        } else if heroDays <= 1 && costPerDayCents > 0 {
            // Brand-new user (day counting is 1-based, so a journey started in
            // onboarding is already "day 1"): earned savings are a meaningless
            // anchor ($20), but we know their daily spend — project the year so
            // the price anchors against thousands saved, not dollars spent.
            let yearly = Double(costPerDayCents) * 365 / 100
            let yearlyLabel = Self.currencyFormatter.string(from: NSNumber(value: yearly)) ?? "$\(Int(yearly))"
            VStack(spacing: 4) {
                Text("Your first sober year saves")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text(yearlyLabel)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Watch it add up — and your tree grow — day by day.")
                    .font(Theme.caption())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
            }
        } else if hasSavings {
            VStack(spacing: 4) {
                Text("You've already saved")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text(moneySaved)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("across \(heroDays) sober day\(heroDays == 1 ? "" : "s"). Reinvest a fraction in your growth.")
                    .font(Theme.caption())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
            }
        } else if heroDays >= 7 {
            VStack(spacing: 6) {
                Text("Day \(heroDays)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("Your tree's already growing.\nKeep watching it bloom.")
                    .font(Theme.caption())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
            }
        } else if heroDays >= 1 {
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))
                Text("You've started growing")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Bloom+ unlocks the rest of the journey.")
                    .font(Theme.caption())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44))
                Text("Bloom+")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Everything that grows with you.")
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.85))
            }
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
        if kind == .yearly, let perMonth = package.soberPerMonthLabel {
            // Lead with the free trial when one is on the table — reinforcing
            // it on the card (not just the CTA) is what moves trial starts.
            if showsTrialBadge, let trial = package.soberIntroOfferLabel {
                return "\(trial.capitalized) · \(perMonth)"
            }
            return perMonth
        }
        if kind == .lifetime { return "One-time · no subscription" }
        if showsTrialBadge, let trial = package.soberIntroOfferLabel {
            return trial.capitalized
        }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(package.soberDisplayName)
                            .font(Theme.subhead(weight: .bold))
                        if let pct = savingsPercent {
                            Text("SAVE \(pct)%")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white, in: Capsule())
                                .foregroundStyle(Theme.brandPrimary)
                        } else if kind == .lifetime {
                            Text("BEST DEAL")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.35), in: Capsule())
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.caption(weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.soberPriceLabel)
                        .font(Theme.subhead(weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                    if let anchorPrice {
                        Text(anchorPrice)
                            .font(Theme.caption().monospacedDigit())
                            .strikethrough()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white.opacity(isSelected ? 0.22 : 0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
