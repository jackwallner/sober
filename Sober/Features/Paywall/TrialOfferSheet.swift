import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Lightweight trial pitch — one tap starts the yearly free trial. The full
/// plan picker is secondary ("See all plans"). This is the conversion surface
/// surfaced post-onboarding, on the Health tab, and from every locked feature.
///
/// Designed to *sell*, not just inform: an animated glow + sparkle hero, a
/// price-anchor card (a year of savings struck through against the plan price),
/// and a glowing CTA. The plain three-bullet version converted poorly.
struct TrialOfferSheet: View {
    let focus: BloomFeature?
    let offerLabel: String?
    let priceLabel: String?
    let directPurchase: Bool
    let isPurchasing: Bool
    let errorMessage: String?
    let onStartTrial: () -> Void
    let onSeeAllPlans: () -> Void
    let onDismiss: () -> Void

    @Query private var settingsRows: [UserSettings]
    @State private var glowPulse = false

    private var costPerDayCents: Int { settingsRows.first?.costPerDayCents ?? 0 }
    private var projectedYearlySavings: Int { Int((Double(costPerDayCents) * 365 / 100).rounded()) }
    private var showsAnchor: Bool { projectedYearlySavings >= 60 }

    /// Strip the period suffix ("$29.99 / year" -> "$29.99") for the anchor card.
    private var cleanPrice: String? {
        guard let priceLabel else { return nil }
        return priceLabel.components(separatedBy: " /").first?.trimmingCharacters(in: .whitespaces)
    }

    private var headline: String {
        if let focus { return focus.pitchHeadline }
        if offerLabel != nil { return "Unlock everything, free." }
        return "Try Bloom+ free."
    }

    private var subheadline: String {
        if let focus {
            return offerLabel != nil
                ? focus.pitchSubheadline + " Free for your whole trial."
                : focus.pitchSubheadline
        }
        return offerLabel != nil
            ? "Your full garden, journal, health timeline, and savings — free until your trial ends. Cancel anytime."
            : "Unlock everything that grows with you — free for eligible new subscribers."
    }

    private var bulletFeatures: [BloomFeature] {
        let base: [BloomFeature] = [.gardenSpecies, .healthTimeline, .savingsTracking]
        guard let focus else { return base }
        return Array(([focus] + base.filter { $0 != focus }).prefix(3))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                hero
                    .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(headline)
                        .font(Theme.display(27, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(subheadline)
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                if showsAnchor, let cleanPrice {
                    SavingsAnchorCard(
                        yearlySavings: projectedYearlySavings,
                        priceLabel: cleanPrice,
                        priceCaption: offerLabel != nil ? "after your free trial" : "a full year of Bloom+"
                    )
                }

                featureBullets

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .safeAreaInset(edge: .bottom, spacing: 0) { ctaStack }
        }
        .onAppear { glowPulse = true }
    }

    // MARK: - Hero (animated glow + sparkle)

    private var hero: some View {
        ZStack {
            Circle()
                .fill(Theme.brandGradient)
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .opacity(glowPulse ? 0.55 : 0.3)
                .scaleEffect(glowPulse ? 1.05 : 0.85)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowPulse)

            ZStack {
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: Theme.brandPrimary.opacity(0.5), radius: 16, y: 6)
                Image(systemName: focus?.icon ?? "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }

            // orbiting sparkles
            sparkle(size: 16, x: -58, y: -36, delay: 0)
            sparkle(size: 11, x: 60, y: -20, delay: 0.5)
            sparkle(size: 13, x: 46, y: 44, delay: 1.0)
            sparkle(size: 9, x: -52, y: 40, delay: 1.5)
        }
        .frame(height: 120)
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Theme.brandPrimary.opacity(0.85))
            .offset(x: x, y: y)
            .opacity(glowPulse ? 0.9 : 0.25)
            .scaleEffect(glowPulse ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(delay), value: glowPulse)
    }

    private var featureBullets: some View {
        VStack(spacing: 8) {
            ForEach(bulletFeatures, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(Theme.subhead(weight: feature == focus ? .semibold : .regular))
                            .foregroundStyle(Theme.textPrimary)
                        Text(feature.detail)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, feature == focus ? 12 : 0)
                .padding(.vertical, feature == focus ? 10 : 0)
                .background {
                    if feature == focus {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.brandPrimary.opacity(0.08))
                    }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaStack: some View {
        VStack(spacing: 10) {
            if directPurchase, let priceLabel {
                Text("Free during trial, then \(priceLabel). Auto-renews unless cancelled 24h before trial ends.")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onStartTrial) {
                ZStack {
                    Text("Start My Free Trial")
                        .font(Theme.body(weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.brandPrimary.opacity(glowPulse ? 0.45 : 0.25), radius: glowPulse ? 18 : 10, y: 6)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowPulse)
            .buttonStyle(.plain)
            .disabled(isPurchasing)

            HStack(spacing: 16) {
                reassurancePill("checkmark.shield.fill", "No payment now")
                reassurancePill("bell.fill", "Reminder before billing")
            }

            Button("See all plans", action: onSeeAllPlans)
                .font(Theme.subhead(weight: .semibold))
                .foregroundStyle(Theme.brandPrimary)

            Button("Not now", action: onDismiss)
                .font(Theme.caption())
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    private func reassurancePill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.brandPrimary)
            Text(text)
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
