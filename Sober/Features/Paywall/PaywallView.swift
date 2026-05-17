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
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                Text("Bloom+").font(.system(size: 40, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 12) {
                    benefit("All 13 health benefits with sources")
                    benefit("Journal with daily prompts")
                    benefit("Achievements & celebrations")
                    benefit("Money & calories saved tracker")
                    benefit("More garden species to grow")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
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

    private func benefit(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text(text)
            Spacer()
        }
    }
}
