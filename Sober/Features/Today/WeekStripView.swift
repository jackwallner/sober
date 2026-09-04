import SwiftUI

/// Seven dots: what the last week actually looked like.
///
/// The point of the strip is that it is not derivable from the day counter. A
/// 40-day streak can be 40 days of tending or 40 days of the clock running,
/// and until this existed the app drew both identically.
struct WeekStripView: View {
    let days: [TendedDay]
    var dotSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { day in
                dot(for: day.mark)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TendedWeek.summary(days))
    }

    @ViewBuilder
    private func dot(for mark: TendedDay.Mark) -> some View {
        switch mark {
        case .tended:
            Circle()
                .fill(Theme.brandPrimary)
                .frame(width: dotSize, height: dotSize)
        case .assumed:
            Circle()
                .stroke(Theme.brandPrimary.opacity(0.45), lineWidth: 1.5)
                .frame(width: dotSize, height: dotSize)
        case .slip:
            Circle()
                .fill(Theme.danger.opacity(0.75))
                .frame(width: dotSize, height: dotSize)
        case .blank:
            Circle()
                .fill(Theme.ringTrack)
                .frame(width: dotSize, height: dotSize)
        }
    }
}
