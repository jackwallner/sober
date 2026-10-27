import SwiftUI

/// The next three health milestones with their real dates. Free for everyone:
/// the first five milestones are free already, and a date is what makes the
/// next one worth staying for. Past the free window a row keeps its date but
/// hides its title, the same rule the Health tab applies.
struct UpcomingMilestonesCard: View {
    let start: Date
    let isPro: Bool
    var now: Date = .now
    let onLockedTap: () -> Void

    static let freeRevealCount = 5

    var body: some View {
        let upcoming = MilestoneSchedule.upcoming(start: start, now: now)
        if !upcoming.isEmpty {
            AheadCard(icon: "heart.text.square.fill", title: String(localized: "Coming up")) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    ForEach(upcoming) { milestone in row(milestone) }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ milestone: DatedMilestone) -> some View {
        let revealed = isPro || milestone.index < Self.freeRevealCount
        let content = HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            Text(MilestoneSchedule.label(for: milestone.date, now: now))
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.brandPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 128, alignment: .leading)
            Text(revealed ? milestone.benefit.title : String(localized: "A Bloom+ milestone"))
                .font(Theme.subhead())
                .foregroundStyle(revealed ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if !revealed {
                Image(systemName: "lock.fill")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        if revealed {
            content.accessibilityElement(children: .combine)
        } else {
            Button(action: onLockedTap) { content }
                .buttonStyle(.plain)
        }
    }
}

/// The goal the user set in onboarding or Settings. Free counts down to it;
/// Bloom+ projects what they will have by then.
struct GoalCard: View {
    let start: Date
    let goal: Date?
    let isPro: Bool
    let costPerDayCents: Int
    let caloriesPerDay: Int
    var now: Date = .now
    let onEdit: () -> Void
    let onLockedTap: () -> Void

    var body: some View {
        if let goal {
            let projection = GoalProjection(
                start: start, goal: goal, now: now,
                costPerDayCents: costPerDayCents, caloriesPerDay: caloriesPerDay
            )
            AheadCard(icon: "flag.checkered", title: String(localized: "Goal · \(GoalProjection.shortDate(projection.goalDate))"), trailing: editButton) {
                if projection.isReached {
                    reached(projection)
                } else {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        countdown(projection)
                        if isPro { projectionRows(projection) } else { lockedRow }
                    }
                }
            }
        } else {
            Button(action: onEdit) {
                AheadCard(icon: "flag.checkered", title: String(localized: "Goal")) {
                    HStack(spacing: Theme.Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pick a date to work toward")
                                .font(Theme.subhead(weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("30 days, 90 days, a year, or a date of your own.")
                                .font(Theme.caption())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        chevron
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var editButton: some View {
        Button("Edit", action: onEdit)
            .font(Theme.caption(weight: .semibold))
            .foregroundStyle(Theme.brandPrimary)
    }

    private func countdown(_ p: GoalProjection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(p.daysToGo)")
                .font(Theme.bigNumber(40))
                .foregroundStyle(Theme.brandPrimary)
            Text("\(p.daysToGo) days to go")
                .font(Theme.subhead(weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Text("Day \(p.dayCountAtGoal)")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var lockedRow: some View {
        Button(action: onLockedTap) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("See what you'll have by then")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Money kept, calories, and milestones passed, with Bloom+")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Theme.Space.m)
            .background(Theme.brandPrimary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func projectionRows(_ p: GoalProjection) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if p.hasSpend { stat(p.moneyText, String(localized: "kept")) }
            if p.calories > 0 { stat(p.calories.formatted(), String(localized: "calories")) }
            if let count = p.habitInstances, count > 0 {
                stat(count.formatted(), String(localized: "drinks not had"))
            }
            stat(String(localized: "\(p.milestonesPassed.count) of \(HealthBenefitCatalog.all.count)"), String(localized: "milestones passed"))
            if !p.milestonesStillAhead.isEmpty {
                Text("Still ahead before then: \(Self.list(p.milestonesStillAhead.map(\.title)))")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(Theme.body(weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(Theme.subhead())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func reached(_ p: GoalProjection) -> some View {
        Button(action: onEdit) {
            HStack(spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You made it to your goal")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Set the next one when you're ready.")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                chevron
            }
        }
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(Theme.caption(weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
    }

    /// "A, B and 2 more".
    static func list(_ titles: [String]) -> String {
        guard titles.count > 2 else { return ListFormatter.localizedString(byJoining: titles) }
        return String(localized: "\(titles[0]), \(titles[1]) and \(titles.count - 2) more")
    }
}

/// The urge playbook's door on Home.
struct PlaybookCard: View {
    let isPro: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AheadCard(icon: "list.bullet.clipboard", title: String(localized: "Craving playbook")) {
                HStack(spacing: Theme.Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("A plan for the first craving")
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Six triggers, each with steps and what to say when you're offered a drink.")
                            .font(Theme.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isPro ? "chevron.right" : "lock.fill")
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Shared chrome for the cards below the garden: a small labelled header and
/// a warm-white surface, matching the check-in card above them.
struct AheadCard<Content: View, Trailing: View>: View {
    let icon: String
    let title: String
    let trailing: Trailing
    let content: Content

    init(icon: String, title: String, trailing: Trailing, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Theme.caption(weight: .bold))
                Text(title.uppercased())
                    .font(Theme.caption(weight: .bold))
                    .tracking(1.2)
                Spacer(minLength: 0)
                trailing
            }
            .foregroundStyle(Theme.textSecondary)
            content
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ringTrack, lineWidth: 1))
    }
}

extension AheadCard where Trailing == EmptyView {
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.init(icon: icon, title: title, trailing: EmptyView(), content: content)
    }
}
