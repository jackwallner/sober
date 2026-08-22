#if DEBUG
import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct PaywallScreenshotHarness: View {
    let mode: PaywallScreenshotMode
    @Environment(\.modelContext) private var context
    @State private var subscriptions = SubscriptionService.shared
    @State private var didSeed = false

    var body: some View {
        Group {
            if mode == .trial {
                trialBackdrop {
                    TrialOfferSheet(
                        focus: nil,
                        offerLabel: trialPackage?.soberIntroOfferLabel ?? "7-day free trial",
                        // No literal fallback. Products don't load in a headless
                        // sim, and the placeholder that used to sit here ($19.99
                        // / year, two ladders out of date) would have been baked
                        // into an App Store screenshot. Nil just drops the
                        // billing line until a real StoreKit price exists.
                        priceLabel: trialPackage?.soberPriceLabel,
                        directPurchase: true,
                        isPurchasing: false,
                        errorMessage: nil,
                        onStartTrial: {},
                        onSeeAllPlans: {},
                        onDismiss: {}
                    )
                }
            } else {
                PaywallView(displayCloseButton: false, showsLifetime: true, impressionId: "snapshot")
            }
        }
        .environment(subscriptions)
        .preferredColorScheme(.light)
        .task {
            seedDemoSavingsIfNeeded()
            if subscriptions.packages.isEmpty { await subscriptions.fetchProducts() }
        }
    }

    /// Paywall screenshots need a real cost-per-day so the savings hero / trial
    /// anchor render. Fresh installs have no settings row yet.
    private func seedDemoSavingsIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = 2000
        settings.caloriesPerDay = 600
        settings.hasCompletedOnboarding = true

        if SobrietyService(context: context).activeJourney() == nil {
            let start = Calendar.current.date(byAdding: .day, value: -25, to: .now) ?? .now
            _ = SobrietyService(context: context).startJourney(at: start)
            CheckInService(context: context).fillJourney(start: start, through: .now)
        }
        _ = GardenService(context: context).current()
        try? context.save()
    }

    #if canImport(RevenueCat)
    private var trialPackage: Package? {
        subscriptions.packages.first { $0.soberPackageKind == .yearly } ?? subscriptions.packages.first
    }
    #endif

    private func trialBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack {
                Spacer()
                content()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.68)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
    }
}
#endif
