import SwiftData
import SwiftUI

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @State private var showPaywall = false

    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section(title: "Time Milestones",
                            items: AchievementCatalog.all.filter { $0.kind == .timeMilestone })
                    section(title: "Streaks",
                            items: AchievementCatalog.all.filter { $0.kind == .streak })
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Achievements")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func section(title: String, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(_ a: Achievement) -> some View {
        let unlocked = days >= a.dayThreshold
        let pro = subscriptions.isProSubscriber
        return HStack(spacing: 12) {
            Image(systemName: a.icon)
                .font(.title2)
                .foregroundStyle(unlocked ? Theme.accent : Theme.textTertiary)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(unlocked ? Theme.textPrimary : Theme.textSecondary)
                Text(a.description).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !pro {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.textTertiary)
                    .onTapGesture { showPaywall = true }
            } else if unlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
            }
        }
        .padding()
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .opacity(unlocked || pro ? 1 : 0.6)
    }
}
