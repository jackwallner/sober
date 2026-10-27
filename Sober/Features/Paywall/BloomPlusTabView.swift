import SwiftData
import SwiftUI

/// Omnipresent Bloom+ tab — mirrors Vitals' Upgrade tab. Free users see the
/// full paywall embedded (no close button); subscribers get a real savings &
/// insights dashboard so the tab earns its place in the bar rather than just
/// confirming what's unlocked.
struct BloomPlusTabView: View {
    @Environment(SubscriptionService.self) private var subscriptions

    var body: some View {
        Group {
            if subscriptions.isProSubscriber {
                BloomPlusHubView()
            } else {
                PaywallView(displayCloseButton: false, showsLifetime: true, impressionId: "sober_bloom_tab")
            }
        }
    }
}

// MARK: - Subscriber dashboard

/// What Bloom+ *does* for a subscriber, made tangible: the money and calories
/// they've kept out of their life, the next milestones coming up, and a
/// year-ahead projection. This is the payoff screen — the reason to tap the tab
/// after subscribing.
private struct BloomPlusHubView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var settingsRows: [UserSettings]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var unlockedAchievements: [UnlockedAchievement]
    @Query private var episodes: [CravingEpisode]

    @State private var showProgress = false

    private var settings: UserSettings? { settingsRows.first }
    private var costPerDayCents: Int { settings?.costPerDayCents ?? 0 }
    private var caloriesPerDay: Int { settings?.caloriesPerDay ?? 0 }

    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }

    /// Lifetime is the headline basis so a relapse reset never wipes earned
    /// progress — matches the Progress sheet's "lifetime" column.
    private var lifetimeSoberDays: Int { checkIns.filter { $0.wasSober }.count }
    private var heroDays: Int { max(lifetimeSoberDays, days) }

    private var lifetimeMoneySaved: Double { Double(heroDays * costPerDayCents) / 100 }
    private var lifetimeCalories: Int { heroDays * caloriesPerDay }
    /// Body fat in the unit the user's region weighs in (~3,500 kcal per lb,
    /// ~7,700 per kg).
    private var bodyFatText: String {
        let mass = Locale.current.measurementSystem == .us
            ? Measurement(value: Double(lifetimeCalories) / 3500, unit: UnitMass.pounds)
            : Measurement(value: Double(lifetimeCalories) / 7700, unit: UnitMass.kilograms)
        return mass.formatted(.measurement(
            width: .abbreviated,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(1))
        ))
    }
    private var yearlyProjection: Double { Double(costPerDayCents) * 365 / 100 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    moneyHero.paneRow()
                    statRow.paneRow()
                    if yearlyProjection > 0 { projectionCard.paneRow() }
                    patternsCard.paneRow()
                    milestonesCard
                    Button { showProgress = true } label: {
                        HStack {
                            Label("See full progress", systemImage: "chart.bar.fill")
                            Spacer()
                            Image(systemName: "chevron.right").font(Theme.caption(weight: .semibold))
                        }
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity)
                        .background(Theme.brandPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .paneRow()
                }
                .padding(Theme.Space.l)
            }
            .themedScrollBackground()
            .navigationTitle("Bloom+")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProgress) {
                ProgressSheet(
                    days: days,
                    gardenState: GardenService(context: context).current(),
                    isPro: true
                )
            }
        }
    }

    private var moneyHero: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(Theme.caption(weight: .semibold))
                Text("BLOOM+ ACTIVE")
                    .font(Theme.caption(weight: .bold))
                    .tracking(1.4)
            }
            .foregroundStyle(Theme.brandPrimary)

            Text(Self.currency.string(from: NSNumber(value: lifetimeMoneySaved)) ?? "0")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("kept in your pocket across \(heroDays) sober days")
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.l)
        .background(Theme.brandPrimary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private var statRow: some View {
        HStack(spacing: Theme.Space.m) {
            statTile("flame.fill", lifetimeCalories.formatted(), String(localized: "calories avoided"))
            statTile("scalemass.fill", bodyFatText, String(localized: "of body fat"))
        }
    }

    private func statTile(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.brandPrimary)
            Text(value)
                .font(Theme.heading(weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.m)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var projectionCard: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("On track to save")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                Text("\(Self.currency.string(from: NSNumber(value: yearlyProjection)) ?? "0") a year")
                    .font(Theme.body(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(Theme.Space.m)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    /// The reason to open this tab on a day nothing happened. Money kept is a
    /// number the free app already shows; this is the one thing here that only
    /// exists because the subscriber logged it.
    private var patternsCard: some View {
        NavigationLink {
            PatternsView()
        } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.brandGradient, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your patterns")
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(patternsSubtitle)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Theme.Space.m)
            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var patternsSubtitle: String {
        let rodeOut = episodes.filter { $0.outcome == .rodeItOut }.count
        guard rodeOut > 0 else {
            return String(localized: "When your cravings hit and what sets them off")
        }
        return String(localized: "\(rodeOut) cravings ridden out so far")
    }

    private var milestonesCard: some View {
        let nextMilestone = AchievementCatalog.nextTimeMilestone(after: days)
        let hours = Double(max(0, days - 1)) * 24
        let nextBenefit = HealthBenefitCatalog.next(after: hours)
        let earned = unlockedAchievements.count
        // Rows report one by one, so the unfolded pane closes the card after
        // the rows that fit rather than hide it whole above an empty band.
        return VStack(spacing: 0) {
            milestoneRow(
                icon: "flag.fill",
                title: nextMilestone?.title ?? String(localized: "Year One"),
                trailing: nextMilestone.map { String(localized: "in \(max(1, $0.dayThreshold - days)) days") } ?? String(localized: "Crushed it")
            )
            Divider().padding(.leading, 48)
            milestoneRow(
                icon: "heart.fill",
                title: nextBenefit?.title ?? String(localized: "All benefits unlocked"),
                trailing: nextBenefit.map { String(localized: "at \($0.displayWait)") } ?? ""
            )
            Divider().padding(.leading, 48)
            milestoneRow(
                icon: "checkmark.seal.fill",
                title: String(localized: "Achievements earned"),
                trailing: earned.formatted()
            )
        }
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func milestoneRow(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)
            Text(title)
                .font(Theme.body())
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(trailing)
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
        }
        .padding(Theme.Space.m)
        .paneCardRow(Self.milestonesCardShape)
    }

    private static let milestonesCardShape = PaneCut.Card(inset: Theme.Space.l, cornerRadius: 16)

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
