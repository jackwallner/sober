import SwiftData
import SwiftUI

struct HealthView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]

    private var hours: Double {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return DateHelpers.hoursBetween(j.startDate, .now)
    }

    /// Free users see the first 5 unlocked benefits + locked previews. This
    /// covers the high-motivation early-recovery wins (through ~2 weeks) so
    /// non-Pro users get tangible feedback before the paywall pinches.
    private let freeRevealCount = 5

    var body: some View {
        NavigationStack {
            List {
                Section {
                    recoveryHeaderRow
                    if let n = HealthBenefitCatalog.next(after: hours) {
                        if subscriptions.isProSubscriber {
                            nextUpRow(n)
                        } else {
                            nextUpLockedRow
                        }
                    }
                }

                Section {
                    ForEach(Array(HealthBenefitCatalog.all.enumerated()), id: \.element.id) { idx, benefit in
                        let unlocked = hours >= benefit.hoursRequired
                        let inFreeWindow = subscriptions.isProSubscriber || idx < freeRevealCount
                        let visible = unlocked && inFreeWindow
                        // Beyond the free window, *all* future milestones (earned or
                        // not-yet-earned) are part of the Bloom+ value prop and
                        // render as a Pro tease rather than revealing the title.
                        BenefitRow(benefit: benefit, unlocked: visible, blurred: !visible && !inFreeWindow)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !subscriptions.isProSubscriber && idx >= freeRevealCount {
                                    TrialOfferCoordinator.shared.request(.healthTimeline)
                                }
                            }
                    }
                } header: {
                    Text("Benefits")
                } footer: {
                    Text("General wellness information, not medical advice. Timelines vary from person to person — for medical concerns, talk to a healthcare professional.")
                }
            }
            .listStyle(.insetGrouped)
            .themedScrollBackground()
            .navigationTitle("Health")
        }
        .task { await maybeNudgeTrial() }
    }

    /// Passive trial surfacing: the Health tab is a high-intent recovery surface,
    /// so a free, trial-eligible user who lingers here gets one gentle trial
    /// offer — cooldown-gated (a few days) so it never nags. Tapping a locked
    /// benefit still triggers the focused pitch immediately; this catches users
    /// who browse without tapping.
    private func maybeNudgeTrial() async {
        guard !subscriptions.isProSubscriber,
              !subscriptions.hasClaimedTrial,
              subscriptions.hasTrialOfferAvailable,
              TrialNudgeGate.canShow()
        else { return }
        // Let the screen settle before surfacing anything.
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        guard !Task.isCancelled, !subscriptions.isProSubscriber else { return }
        TrialNudgeGate.markShown()
        TrialOfferCoordinator.shared.request(.healthTimeline)
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
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            ProgressView(value: Double(unlocked), total: Double(total))
                .tint(Theme.brandPrimary)
        }
        .padding(.vertical, Theme.Space.xs)
    }

    /// Free users see a Bloom+ tease instead of the next benefit's title.
    /// Future health milestones are part of the Bloom+ value prop, so we
    /// don't spoil them for non-subscribers.
    private var nextUpLockedRow: some View {
        Button { TrialOfferCoordinator.shared.request(.healthTimeline) } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next up")
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Unlock what's coming with Bloom+")
                        .font(Theme.body())
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: Theme.Space.s)
                Image(systemName: "chevron.right")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func nextUpRow(_ n: HealthBenefit) -> some View {
        // The next-up row is always about a *time* gate (the benefit isn't
        // reached yet) — keep the hourglass to distinguish from subscription
        // gates elsewhere on the screen.
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "hourglass")
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Next up")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(n.title)
                    .font(Theme.body())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: Theme.Space.s)
            Text("in \(n.displayWait)")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
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
                    Text(proGated ? "A future milestone" : benefit.title)
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Theme.Space.xs)
                    trailingLabel
                }
                if !proGated {
                    Text(benefit.summary)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if unlocked {
                    Text(benefit.detail)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 2)
                    if let url = benefit.sourceURL {
                        Link(destination: url) {
                            Label(benefit.sourceLabel, systemImage: "link")
                                .font(Theme.caption())
                                .foregroundStyle(Theme.brandPrimary)
                        }
                        .padding(.top, 2)
                    }
                } else if proGated {
                    HStack(spacing: 4) {
                        Text("Unlock with Bloom+")
                            .font(Theme.caption(weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(Theme.caption(weight: .semibold))
                    }
                    .foregroundStyle(Theme.brandPrimary)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }

    /// Three visual states so users can tell at a glance *why* a benefit is
    /// not yet open: time gate (hourglass), earned-but-subscription gate
    /// (crown), or revealed (check). The previous lock icon was used for both
    /// gates and made paywalled-but-earned benefits feel indistinguishable
    /// from ones the user hadn't reached yet.
    private var leadingIcon: String {
        if unlocked { return "checkmark.circle.fill" }
        if proGated { return "crown.fill" }
        return "hourglass"
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
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.brandPrimary)
        } else {
            Text("in \(benefit.displayWait)")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .monospacedDigit()
        }
    }
}
