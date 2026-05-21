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
                LazyVStack(spacing: Theme.Space.m) {
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
                .padding(Theme.Space.l)
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
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Your Recovery").font(.headline)
                Text("\(unlocked) / \(total) benefits unlocked")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                ProgressView(value: Double(unlocked), total: Double(total))
                    .tint(.white)
                if let n = next {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Label("NEXT UP", systemImage: "lock.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer(minLength: 0)
                            Text(n.displayWait)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        Text(n.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(.top, Theme.Space.xs)
                }
            }
        }
    }
}

private struct BenefitRow: View {
    let benefit: HealthBenefit
    /// True when fully revealed (timed-unlock met AND user has access).
    let unlocked: Bool
    /// True when the user has *earned* this benefit by time, but it's gated behind Bloom+.
    let blurred: Bool

    private var proGated: Bool { blurred }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .top, spacing: Theme.Space.s) {
                Image(systemName: leadingIcon)
                    .foregroundStyle(leadingTint)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(benefit.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Space.s)
                statusPill
            }
            Text(benefit.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            if unlocked {
                Text(benefit.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                if let url = benefit.sourceURL {
                    Link(destination: url) {
                        Label(benefit.sourceLabel, systemImage: "link")
                            .font(.caption2)
                    }
                }
            } else if proGated {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                    Text("Unlock the full benefit with Bloom+")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.brandPrimary)
                .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var leadingIcon: String {
        if unlocked { return "drop.fill" }
        if proGated { return "crown.fill" }
        return "lock.fill"
    }

    private var leadingTint: Color {
        if unlocked { return Theme.success }
        if proGated { return Theme.brandPrimary }
        return Theme.textTertiary
    }

    @ViewBuilder
    private var statusPill: some View {
        if unlocked {
            Text("Unlocked")
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.success.opacity(0.18), in: Capsule())
                .foregroundStyle(Theme.success)
        } else if proGated {
            Text("Bloom+")
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.brandPrimary.opacity(0.18), in: Capsule())
                .foregroundStyle(Theme.brandPrimary)
        } else {
            Text(benefit.displayWait)
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.ringTrack, in: Capsule())
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
