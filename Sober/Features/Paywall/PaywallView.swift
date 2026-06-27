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

    /// Everything fits on one page — no scrolling. Value (savings + benefits)
    /// sits up top, the plan stack in the middle, and the purchase block anchored
    /// at the bottom, with a single flexible Spacer absorbing device-size
    /// differences so the CTA always lands in the same place.
    #if canImport(RevenueCat)
    private var paywallContent: some View {
        VStack(spacing: 10) {
            savingsValueHeader
            benefitShowcase
            planCards

            Spacer(minLength: 2)

            purchaseSection
            trustRow
            footerLinks
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 40 : 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Across \(heroDays) sober day\(heroDays == 1 ? "" : "s"). You've earned this — put a fraction toward staying sober for good.")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if costPerDayCents > 0 {
                eyebrow("YOUR MONEY, KEPT")
                let yearlyLabel = Self.currencyFormatter.string(from: NSNumber(value: yearlySpend)) ?? "$\(yearlySpend)"
                Text("Up to \(yearlyLabel)/yr")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
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
                Text("Your garden, journal, health timeline, and savings — everything that keeps you sober.")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefitShowcase: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Everything you unlock")
                .font(Theme.subhead(weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(BloomFeature.allCases, id: \.self) { feature in
                benefitRow(feature, highlighted: focus == feature)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.brandGradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(feature.detail)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.brandPrimary.opacity(highlighted ? 1 : 0.55))
        }
        .frame(height: 38)
        .padding(.horizontal, highlighted ? 8 : 0)
        .background(
            highlighted ? Theme.brandPrimary.opacity(0.08) : .clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private var sortedPackages: [Package] {
        let order: [SoberPackageKind: Int] = [.monthly: 0, .yearly: 1, .lifetime: 2]
        return subscriptions.packages.sorted {
            (order[$0.soberPackageKind] ?? 9) < (order[$1.soberPackageKind] ?? 9)
        }
    }

    private var monthlyPackage: Package? {
        subscriptions.packages.first { $0.soberPackageKind == .monthly }
    }

    private var planCards: some View {
        VStack(spacing: 10) {
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
        VStack(spacing: 6) {
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

            if let disclosureText {
                Text(disclosureText)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

    /// Small trust signals. We deliberately omit a "Cancel anytime in Settings"
    /// line: it isn't App Store mandated and drawing attention to cancellation
    /// before purchase suppresses conversions. Apple's renewal notification
    /// for trials is the only billing reassurance kept.
    private var trustRow: some View {
        let showsTrialTrust = selectedPackage.map { subscriptions.isEligibleForIntroOffer($0) } ?? false
        return HStack(spacing: 6) {
            Image(systemName: showsTrialTrust ? "bell.fill" : "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.brandPrimary.opacity(0.8))
            Text(
                showsTrialTrust
                    ? "No payment now · Apple reminds you before billing · Data stays on-device"
                    : "Your data stays on this device"
            )
            .font(Theme.caption())
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 4)
    }

    private var footerLinks: some View {
        HStack(spacing: 12) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
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

    /// Monthly-first default so the glance reads as a small commitment; yearly
    /// stays available for users who want the best per-month value.
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
        guard selectedPackage == nil, !subscriptions.packages.isEmpty else { return }
        selectedPackage = subscriptions.packages.first { $0.soberPackageKind == .monthly }
            ?? subscriptions.packages.first { $0.soberPackageKind == .yearly }
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
            VStack(spacing: 20) {
                savingsValueHeader
                benefitShowcase
                Text("$4.99 / mo · $29.99 / yr · $79.99 lifetime")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
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
        if kind == .yearly, let perMonth = package.soberPerMonthLabel {
            if showsTrialBadge, let trial = package.soberIntroOfferLabel {
                return "\(trial.capitalized) · \(perMonth)"
            }
            return perMonth
        }
        if kind == .monthly, showsTrialBadge, let trial = package.soberIntroOfferLabel {
            return trial.capitalized
        }
        if kind == .lifetime { return "One-time · no subscription" }
        return nil
    }

    private var badgeLabel: String? {
        if kind == .yearly, let pct = savingsPercent { return "SAVE \(pct)%" }
        if kind == .lifetime { return "BEST DEAL" }
        if showsTrialBadge, kind == .monthly { return "FREE TRIAL" }
        return nil
    }

    private var badgeFill: Color {
        kind == .lifetime ? Theme.accent : Theme.brandPrimary
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
                    HStack(spacing: 6) {
                        Text(package.soberDisplayName)
                            .font(Theme.subhead(weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if let badgeLabel {
                            Text(badgeLabel)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(badgeFill, in: Capsule())
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.caption(weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
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
                    }
                }
                .frame(width: 112, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
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
