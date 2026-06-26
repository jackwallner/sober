import SwiftUI

struct BloomPlusTabView: View {
    @Environment(SubscriptionService.self) private var subscriptions

    var body: some View {
        Group {
            if subscriptions.isProSubscriber {
                BloomPlusHubView()
            } else {
                PaywallView(displayCloseButton: false, impressionId: "sober_bloom_tab")
            }
        }
    }
}

private struct BloomPlusHubView: View {
    private let unlocked: [(symbol: String, title: String)] = [
        ("leaf.fill", "All 6 bonsai species"),
        ("heart.text.square.fill", "Full 13-milestone health timeline"),
        ("book.closed.fill", "Daily journal prompts"),
        ("dollarsign.circle.fill", "Money and calories saved")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(Theme.brandPrimary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bloom+ active")
                                .font(Theme.body(weight: .semibold))
                            Text("Everything that grows with you is unlocked.")
                                .font(Theme.caption())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Unlocked") {
                    ForEach(unlocked, id: \.title) { item in
                        Label(item.title, systemImage: item.symbol)
                    }
                }
            }
            .navigationTitle("Bloom+")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
