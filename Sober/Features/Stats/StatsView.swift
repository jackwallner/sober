import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var settingsRows: [UserSettings]
    @State private var showPaywall = false

    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var settings: UserSettings? { settingsRows.first }

    private var moneySaved: String {
        let cents = days * (settings?.costPerDayCents ?? 0)
        let dollars = Double(cents) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }
    private var caloriesAvoided: Int {
        days * (settings?.caloriesPerDay ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !subscriptions.isProSubscriber {
                        proGate
                    } else {
                        bigStat(label: "Money Saved", value: moneySaved, sub: "$\((settings?.costPerDayCents ?? 0) / 100) per day", color: Theme.brandPrimary)
                        bigStat(label: "Calories Avoided", value: "\(caloriesAvoided.formatted())", sub: "\(settings?.caloriesPerDay ?? 0) per day", color: Theme.accent)
                        bigStat(label: "Days Sober", value: "\(days)", sub: "and counting", color: Theme.success)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Your Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var proGate: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 48))
            Text("Pro Only").font(.title.bold())
            Text("See exactly how much money and how many calories you've spared yourself.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            Button("Upgrade to Pro") { showPaywall = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandPrimary)
        }
        .padding()
    }

    private func bigStat(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
            Text(value).font(Theme.bigNumber(48)).foregroundStyle(color)
            Text(sub).font(.footnote).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
