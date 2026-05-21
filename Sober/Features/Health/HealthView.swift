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
            List {
                Section {
                    recoveryHeaderRow
                    if let n = HealthBenefitCatalog.next(after: hours) {
                        nextUpRow(n)
                    }
                }

                Section("Benefits") {
                    ForEach(Array(HealthBenefitCatalog.all.enumerated()), id: \.element.id) { idx, benefit in
                        let unlocked = hours >= benefit.hoursRequired
                        let visible = unlocked && (subscriptions.isProSubscriber || idx < freeRevealCount)
                        BenefitRow(benefit: benefit, unlocked: visible, blurred: unlocked && !visible)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if unlocked && !subscriptions.isProSubscriber && idx >= freeRevealCount {
                                    showPaywall = true
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Health")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var recoveryHeaderRow: some View {
        let unlocked = HealthBenefitCatalog.unlocked(hoursSober: hours).count
        let total = HealthBenefitCatalog.all.count
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(unlocked)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.brandPrimary)
                    .monospacedDigit()
                Text("/ \(total) benefits")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            ProgressView(value: Double(unlocked), total: Double(total))
                .tint(Theme.brandPrimary)
        }
        .padding(.vertical, Theme.Space.xs)
    }

    private func nextUpRow(_ n: HealthBenefit) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Next up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(n.title)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: Theme.Space.s)
            Text(n.displayWait)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
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
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: leadingIcon)
                .font(.title3)
                .foregroundStyle(leadingTint)
                .frame(width: 32)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: Theme.Space.s) {
                    Text(benefit.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Theme.Space.xs)
                    trailingLabel
                }
                Text(benefit.summary)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if unlocked {
                    Text(benefit.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 2)
                    if let url = benefit.sourceURL {
                        Link(destination: url) {
                            Label(benefit.sourceLabel, systemImage: "link")
                                .font(.caption2)
                                .foregroundStyle(Theme.brandPrimary)
                        }
                        .padding(.top, 2)
                    }
                } else if proGated {
                    HStack(spacing: 4) {
                        Text("Unlock with Bloom+")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.brandPrimary)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }

    private var leadingIcon: String {
        if unlocked { return "checkmark.circle.fill" }
        if proGated { return "crown.fill" }
        return "lock.fill"
    }

    private var leadingTint: Color {
        if unlocked { return Theme.brandPrimary }
        if proGated { return Theme.brandPrimary }
        return Theme.textTertiary
    }

    @ViewBuilder
    private var trailingLabel: some View {
        if unlocked {
            EmptyView()
        } else if proGated {
            Text("Bloom+")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandPrimary)
        } else {
            Text(benefit.displayWait)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .monospacedDigit()
        }
    }
}
