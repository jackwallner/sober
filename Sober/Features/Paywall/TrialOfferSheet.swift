import SwiftUI

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

    private var headline: String {
        if let focus { return focus.pitchHeadline }
        if let offerLabel { return "\(offerLabel.capitalized), on us." }
        return "Try Bloom+ free."
    }

    private var subheadline: String {
        if let focus {
            return offerLabel != nil
                ? focus.pitchSubheadline + " Free during your trial."
                : focus.pitchSubheadline
        }
        return offerLabel != nil
            ? "Grow your full garden, journal, and health timeline free. No charge until your trial ends."
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

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.brandPrimary.opacity(0.35), radius: 12, y: 4)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(headline)
                        .font(Theme.display(26, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(subheadline)
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

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
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
        }
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
