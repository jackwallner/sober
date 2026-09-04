import SwiftData
import SwiftUI

/// The Bloom+ headline: the app reading the user's own record back to them.
///
/// Everything else the subscription has ever sold could be computed from a
/// start date, which is why it always felt like a bigger version of the free
/// app. This screen cannot exist without the user's own logging, which is what
/// makes it worth a subscription and what makes the free craving tool worth
/// keeping free.
struct PatternsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CravingEpisode.startedAt, order: .reverse) private var episodes: [CravingEpisode]
    @Query private var checkIns: [DailyCheckIn]

    private var cravings: [CravingFacts] {
        episodes.map {
            CravingFacts(
                startedAt: $0.startedAt,
                secondsElapsed: $0.secondsElapsed,
                outcome: $0.outcome,
                intensity: $0.intensity,
                trigger: $0.trigger
            )
        }
    }

    private var checkInFacts: [CheckInFacts] {
        checkIns.map { CheckInFacts(day: $0.day, wasSober: $0.wasSober, wasLogged: $0.wasLogged, mood: $0.mood) }
    }

    private var insights: [CravingInsight] {
        CravingInsights.insights(cravings: cravings, checkIns: checkInFacts)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                if cravings.isEmpty {
                    emptyState
                } else {
                    header
                    if cravings.count >= CravingInsights.minimumForTiming { hourChart }
                    ForEach(insights) { insightCard($0) }
                    if let next = CravingInsights.nextUnlock(cravings) {
                        hint(next)
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .themedScrollBackground()
        .background(Theme.background)
        .navigationTitle("Your patterns")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(Theme.brandPrimary)
            Text("Nothing to read yet")
                .font(Theme.title())
                .foregroundStyle(Theme.textPrimary)
            Text("Every time you ride out a \(HabitVocabulary.urgeNoun), this page learns something about yours: when they hit, what sets them off, and how long they actually last.")
                .font(Theme.body())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Space.xxl)
    }

    private var header: some View {
        let rodeOut = cravings.filter { $0.outcome == .rodeItOut }.count
        return VStack(spacing: 4) {
            Text("\(rodeOut)")
                .font(Theme.bigNumber(56))
                .foregroundStyle(Theme.brandPrimary)
                .monospacedDigit()
            Text(rodeOut == 1
                 ? "\(HabitVocabulary.urgeNoun) ridden out"
                 : "\(HabitVocabulary.urgeNounPlural) ridden out")
                .font(Theme.caption(weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
            Text("out of \(cravings.count) logged")
                .font(Theme.caption())
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.l)
        .background(Theme.brandPrimary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    /// Twenty-four bars, no axis furniture. The shape is the point: people
    /// recognise their own evening before they read a label.
    private var hourChart: some View {
        let counts = hourCounts
        let peak = max(1, counts.max() ?? 1)
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("By time of day")
                .font(Theme.body(weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.brandPrimary.opacity(counts[hour] == 0 ? 0.12 : 0.85))
                        .frame(height: max(3, 56 * CGFloat(counts[hour]) / CGFloat(peak)))
                }
            }
            .frame(height: 56, alignment: .bottom)
            HStack {
                Text(CravingInsights.hourLabel(0))
                Spacer()
                Text(CravingInsights.hourLabel(12))
                Spacer()
                Text(CravingInsights.hourLabel(23))
            }
            .font(Theme.caption())
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cravings by time of day")
    }

    private var hourCounts: [Int] {
        var counts = [Int](repeating: 0, count: 24)
        for craving in cravings {
            counts[Calendar.current.component(.hour, from: craving.startedAt)] += 1
        }
        return counts
    }

    private func insightCard(_ insight: CravingInsight) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: insight.icon)
                .font(Theme.body(weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.brandGradient, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.headline)
                    .font(Theme.body(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption())
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(Theme.Space.m)
    }
}
