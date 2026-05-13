import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @State private var showResetAlert = false
    @State private var checkedInToday = false

    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }
    private var days: Int {
        guard let j = activeJourney else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    GardenStageView(days: days)
                        .frame(height: 280)
                        .padding(.horizontal)

                    counterCard

                    checkInCard

                    HStack(spacing: 12) {
                        nextMilestoneCard
                        nextBenefitCard
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showResetAlert = true } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                    }
                }
            }
            .alert("Reset sobriety counter?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    SobrietyService(context: context).reset()
                    WidgetSnapshotPump.push(context: context)
                }
            } message: {
                Text("Your day counter will restart at zero. Your history is kept.")
            }
            .onAppear {
                checkedInToday = CheckInService(context: context).hasCheckedIn()
            }
        }
    }

    private var counterCard: some View {
        VStack(spacing: 6) {
            Text("\(days)")
                .font(Theme.bigNumber(96))
                .foregroundStyle(Theme.brandGradient)
            Text(days == 1 ? "Day Sober" : "Days Sober")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            if let start = activeJourney?.startDate {
                Text("Since \(DateHelpers.mediumDate(start))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var checkInCard: some View {
        Button {
            CheckInService(context: context).checkIn()
            GardenService(context: context).water()
            checkedInToday = true
            WidgetSnapshotPump.push(context: context)
        } label: {
            HStack {
                Image(systemName: checkedInToday ? "checkmark.circle.fill" : "circle")
                Text(checkedInToday ? "Checked in for today" : "Check in for today")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .disabled(checkedInToday)
        .buttonStyle(.borderedProminent)
        .tint(Theme.brandPrimary)
        .padding(.horizontal)
    }

    private var nextMilestoneCard: some View {
        let next = AchievementCatalog.nextTimeMilestone(after: days)
        return VStack(alignment: .leading, spacing: 4) {
            Label("Next Milestone", systemImage: "flag.fill")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(next?.title ?? "Year One")
                .font(.headline)
            Text(next.map { "in \(max(1, $0.dayThreshold - days)) days" } ?? "Crushed it")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var nextBenefitCard: some View {
        let hours = Double(days) * 24
        let next = HealthBenefitCatalog.next(after: hours)
        return VStack(alignment: .leading, spacing: 4) {
            Label("Next Benefit", systemImage: "heart.fill")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(next?.title ?? "All unlocked")
                .font(.headline)
                .lineLimit(2)
            Text(next.map { "at \($0.displayWait)" } ?? "")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
