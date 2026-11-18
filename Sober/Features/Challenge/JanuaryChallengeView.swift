import SwiftData
import SwiftUI

/// Carries a challenge link from `RootView.onOpenURL` to Home, which may not
/// exist yet (cold launch, or onboarding still in front of it).
@MainActor
@Observable
final class ChallengeLinkInbox {
    static let shared = ChallengeLinkInbox()
    var pending = false
}

/// January's check-ins, read live so a check-in or a slip redraws the month.
@MainActor
private struct JanuaryCheckIns: DynamicProperty {
    @Query private var rows: [DailyCheckIn]

    init() {
        let days = JanuaryChallenge.days()
        let first = days.first ?? .distantPast
        let last = days.last ?? .distantPast
        _rows = Query(filter: #Predicate<DailyCheckIn> { $0.day >= first && $0.day <= last }, sort: \.day)
    }

    func snapshot(now: Date) -> JanuaryChallenge.Snapshot {
        let facts = rows.map {
            CheckInFacts(day: $0.day, wasSober: $0.wasSober, wasLogged: $0.wasLogged, mood: $0.mood)
        }
        return JanuaryChallenge.snapshot(now: now, facts: facts)
    }
}

private func startDateLabel(_ snapshot: JanuaryChallenge.Snapshot) -> String {
    (snapshot.days.first?.date ?? .now).formatted(.dateTime.month(.wide).day())
}

/// Dry January's door on Home.
struct JanuaryChallengeCard: View {
    let now: Date
    let onTap: () -> Void
    private let checkIns = JanuaryCheckIns()

    var body: some View {
        let snapshot = checkIns.snapshot(now: now)
        Button(action: onTap) {
            AheadCard(icon: "calendar", title: String(localized: "Dry January")) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if case .upcoming(let days) = snapshot.phase {
                        Text(startDateLabel(snapshot))
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("in \(days) days")
                            .font(Theme.subhead())
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("\(snapshot.dryDays)")
                            .font(Theme.bigNumber(40))
                            .foregroundStyle(Theme.brandPrimary)
                        Text("of 31 dry days")
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("januaryChallengeCard")
    }
}

/// The challenge itself: the count, the month, and the badge it earns.
struct JanuaryChallengeSheet: View {
    let now: Date
    @Environment(\.dismiss) private var dismiss
    @Query private var unlocked: [UnlockedAchievement]
    private let checkIns = JanuaryCheckIns()

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        let snapshot = checkIns.snapshot(now: now)
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    hero(snapshot)
                    month(snapshot)
                    badge(earned: snapshot.isComplete || unlocked.contains { $0.achievementID == JanuaryChallenge.achievementID })
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Dry January")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func hero(_ snapshot: JanuaryChallenge.Snapshot) -> some View {
        VStack(spacing: Theme.Space.xs) {
            if case .upcoming(let days) = snapshot.phase {
                Text(startDateLabel(snapshot))
                    .font(Theme.display())
                    .foregroundStyle(Theme.brandPrimary)
                Text("in \(days) days")
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("\(snapshot.dryDays)")
                    .font(Theme.bigNumber(88))
                    .foregroundStyle(Theme.brandPrimary)
                Text("of 31 dry days")
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, Theme.Space.l)
        .accessibilityElement(children: .combine)
    }

    private func month(_ snapshot: JanuaryChallenge.Snapshot) -> some View {
        let calendar = Calendar.current
        let firstWeekday = calendar.component(.weekday, from: snapshot.days.first?.date ?? .now)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        return VStack(spacing: Theme.Space.s) {
            HStack(spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Self.columns, spacing: 6) {
                // Negative ids: a day's id is its number, and blanks must not share one.
                ForEach((0..<leadingBlanks).map { -1 - $0 }, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(snapshot.days) { dayCell($0) }
            }
        }
        .padding(Theme.Space.l)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ringTrack, lineWidth: 1))
    }

    private var weekdaySymbols: [String] {
        let raw = DateFormatter().veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let first = Calendar.current.firstWeekday - 1
        return Array(raw[first...] + raw[..<first])
    }

    private func dayCell(_ day: JanuaryChallenge.Day) -> some View {
        let fill: Color
        let text: Color
        switch day.mark {
        case .dry: (fill, text) = (Theme.success.opacity(0.85), .white)
        case .slip: (fill, text) = (Theme.danger.opacity(0.75), .white)
        case .open: (fill, text) = (.clear, Theme.textPrimary)
        case .ahead: (fill, text) = (.clear, Theme.textTertiary)
        }
        return Text("\(day.number)")
            .font(Theme.caption(weight: .bold))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(fill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(day.isToday ? Theme.brandPrimary : .clear, lineWidth: 2)
            )
            .accessibilityLabel(Text(day.date.formatted(.dateTime.month(.wide).day())))
            .accessibilityValue(dayValue(day.mark))
    }

    private func dayValue(_ mark: JanuaryChallenge.Mark) -> Text {
        switch mark {
        case .dry: Text("Logged sober")
        case .slip: Text("Logged a slip")
        case .open, .ahead: Text(verbatim: "")
        }
    }

    private func badge(earned: Bool) -> some View {
        let achievement = AchievementCatalog.dryJanuary
        return HStack(spacing: Theme.Space.m) {
            Image(systemName: achievement.icon)
                .font(.title3)
                .foregroundStyle(earned ? Theme.brandPrimary : Theme.textTertiary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(achievement.description)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if earned {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.brandPrimary)
            }
        }
        .padding(Theme.Space.l)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ringTrack, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
