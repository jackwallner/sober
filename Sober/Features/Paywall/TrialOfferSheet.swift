import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Trial pitch — one tap starts the free trial. The decision we want the user to
/// make here is *"start the free trial,"* not *"buy a year,"* so the sheet leads
/// with the free days (large), keeps the price small and matter-of-fact, shows a
/// "how your trial works" timeline to kill billing anxiety, and anchors the
/// eventual price against a year of habit spend. The full plan picker is
/// secondary ("See all plans").
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
    private var yearlySpend: Int { Int((Double(costPerDayCents) * 365 / 100).rounded()) }
    private var showsAnchor: Bool { yearlySpend >= 60 }

    /// Trial length in days, parsed from the offer label ("7-day free trial").
    private var trialDays: Int {
        guard let offerLabel, let n = offerLabel.firstMatchInt else { return 7 }
        return n
    }

    private var hasTrial: Bool { offerLabel != nil }

    /// Small billing disclosure (Apple 3.1.2) kept out of the hero.
    private var trialBillingNote: String? {
        guard hasTrial, let priceLabel else { return nil }
        return "After \(trialDays) days, \(priceLabel) unless you cancel."
    }

    /// Strip the period suffix ("$29.99 / year" -> "$29.99").
    private var cleanPrice: String? {
        guard let priceLabel else { return nil }
        return priceLabel.components(separatedBy: " /").first?.trimmingCharacters(in: .whitespaces)
    }

    private var headline: String {
        hasTrial ? "\(trialDays) days free" : (focus?.pitchHeadline ?? "Try Bloom+ free")
    }

    private var subheadline: String {
        if let focus {
            return focus.pitchSubheadline
        }
        return "Full access to your garden, journal, health timeline, and savings. Free until your trial ends."
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                hero
                    .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(headline)
                        .font(Theme.display(34, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subheadline)
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.top, 2)
                }

                if hasTrial {
                    TrialTimeline(trialDays: trialDays, billingNote: trialBillingNote)
                        .padding(.horizontal, 4)
                }

                if showsAnchor {
                    SavingsAnchorCard(
                        yearlySpend: yearlySpend,
                        spendCaption: "a year on alcohol",
                        trialDays: hasTrial ? trialDays : nil,
                        priceLabel: hasTrial ? nil : cleanPrice,
                        rightCaption: hasTrial ? "full Bloom+ access" : "a year of Bloom+"
                    )
                }

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
                Image(systemName: hasTrial ? "gift.fill" : (focus?.icon ?? "sparkles"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }

            sparkle(size: 16, x: -58, y: -36, delay: 0)
            sparkle(size: 11, x: 60, y: -20, delay: 0.5)
            sparkle(size: 13, x: 46, y: 44, delay: 1.0)
            sparkle(size: 9, x: -52, y: 40, delay: 1.5)
        }
        .frame(height: 116)
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

    // MARK: - CTA

    private var ctaStack: some View {
        VStack(spacing: 10) {
            Button(action: onStartTrial) {
                ZStack {
                    Text(hasTrial ? "Start My \(trialDays)-Day Free Trial" : "Continue")
                        .font(Theme.body(weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(isPurchasing ? 0 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

            if let trialBillingNote {
                Text(trialBillingNote)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
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

private extension String {
    /// First run of digits in the string as an Int ("7-day free trial" -> 7).
    var firstMatchInt: Int? {
        var digits = ""
        for ch in self {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}
