import SwiftData
import SwiftUI

struct HealthView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @State private var showPaywall = false

    private var hours: Double {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return DateHelpers.hoursBetween(j.startDate, .now)
    }

    /// Free users see the first 2 unlocked benefits + locked previews.
    private let freeRevealCount = 2

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    headerCard
                    ForEach(Array(HealthBenefitCatalog.all.enumerated()), id: \.element.id) { idx, benefit in
                        let unlocked = hours >= benefit.hoursRequired
                        let visible = unlocked && (subscriptions.isProSubscriber || idx < freeRevealCount)
                        BenefitRow(benefit: benefit, unlocked: visible, blurred: unlocked && !visible)
                            .onTapGesture {
                                if unlocked && !subscriptions.isProSubscriber && idx >= freeRevealCount {
                                    showPaywall = true
                                }
                            }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Health Benefits")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var headerCard: some View {
        let unlocked = HealthBenefitCatalog.unlocked(hoursSober: hours).count
        let total = HealthBenefitCatalog.all.count
        let next = HealthBenefitCatalog.next(after: hours)
        return HeroCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Recovery").font(.headline)
                Text("\(unlocked) / \(total) benefits unlocked")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                ProgressView(value: Double(unlocked), total: Double(total))
                    .tint(.white)
                if let n = next {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("NEXT UP")
                        Text(n.title).fontWeight(.semibold)
                        Spacer()
                        Text(n.displayWait).font(.caption.bold())
                    }
                    .font(.caption)
                    .padding(.top, 4)
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}

private struct BenefitRow: View {
    let benefit: HealthBenefit
    let unlocked: Bool
    let blurred: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: unlocked ? "drop.fill" : "lock.fill")
                    .foregroundStyle(unlocked ? Theme.success : Theme.textTertiary)
                Text(benefit.title).font(.headline)
                Spacer()
                Text(unlocked ? "Unlocked" : "After \(benefit.displayWait) sober")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(unlocked ? Theme.success.opacity(0.15) : Theme.ringTrack,
                                in: Capsule())
                    .foregroundStyle(unlocked ? Theme.success : Theme.textSecondary)
            }
            Text(benefit.summary).font(.subheadline).foregroundStyle(Theme.textSecondary)
            if unlocked {
                Text(benefit.detail).font(.footnote).foregroundStyle(Theme.textTertiary)
                if let url = benefit.sourceURL {
                    Link(destination: url) {
                        Label(benefit.sourceLabel, systemImage: "link")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .blur(radius: blurred ? 6 : 0)
        .overlay {
            if blurred {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Label("Pro", systemImage: "crown.fill")
                            .font(.headline)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                    }
            }
        }
    }
}
