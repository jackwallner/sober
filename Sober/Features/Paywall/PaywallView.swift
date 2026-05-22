import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// Shows the hosted RevenueCat paywall when configured, otherwise renders a placeholder
/// so the paywall flow can still be exercised in development.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var settingsRows: [UserSettings]
    @Query private var checkIns: [DailyCheckIn]

    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }

    /// Total sober days ever logged — basis for the "lifetime savings" hero
    /// so a relapse-reset paywall never says "$0 saved."
    private var lifetimeSoberDays: Int { checkIns.filter { $0.wasSober }.count }

    /// Day count that drives the hero: prefer lifetime so past investment
    /// keeps showing through a reset; fall back to the active streak.
    private var heroDays: Int { max(lifetimeSoberDays, days) }

    private var moneySaved: String {
        let cents = heroDays * (settingsRows.first?.costPerDayCents ?? 0)
        let dollars = Double(cents) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    var body: some View {
        #if canImport(RevenueCatUI)
        if subscriptions.isConfigured {
            RevenueCatUI.PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in
                    Task { await subscriptions.refresh() }
                    dismiss()
                }
                .onRestoreCompleted { _ in
                    Task { await subscriptions.refresh() }
                    dismiss()
                }
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                savingsHero
                VStack(alignment: .leading, spacing: 12) {
                    benefit("Grow & swap different bonsai species")
                    benefit("Look back at how your tree grew, day by day")
                    benefit("All 13 health benefits with sources")
                    benefit("Journal with daily prompts")
                    benefit("Achievements, money & calories saved")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                Spacer()

                if !subscriptions.hasClaimedTrial {
                    Button {
                        subscriptions.startComplimentaryTrial(days: 7)
                        dismiss()
                    } label: {
                        VStack(spacing: 2) {
                            Text("Start 7-day free trial")
                                .font(.headline)
                            Text("then $4.99 / mo · $29.99 / yr · $79.99 lifetime")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("$4.99 / mo · $29.99 / yr · $79.99 lifetime")
                        .font(.footnote)
                    Button {
                        subscriptions.setLocalOverride(isPro: true)
                        dismiss()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                }

                Button("Restore Purchases") {
                    Task { await subscriptions.refresh() }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var savingsHero: some View {
        let hasSavings = heroDays > 0 && (settingsRows.first?.costPerDayCents ?? 0) > 0
        let usingLifetime = lifetimeSoberDays > days
        if hasSavings {
            VStack(spacing: 8) {
                Text(usingLifetime ? "You've already saved (lifetime)" : "You've already saved")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                Text(moneySaved)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("across \(heroDays) sober day\(heroDays == 1 ? "" : "s"). Reinvest a fraction of it in your growth.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("Bloom+")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text(text)
            Spacer()
        }
    }
}
