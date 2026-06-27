import SwiftUI

/// "How your free trial works" — a 3-step vertical timeline. Showing the user
/// exactly when (and whether) they'll be charged removes billing anxiety and
/// keeps the free part front and center.
struct TrialTimeline: View {
    /// Trial length in days (e.g. 7). Reminder step lands two days before the end.
    let trialDays: Int
    /// Optional billing note for the final step (small disclosure copy only).
    var billingNote: String? = nil
    var onBrand: Bool = false

    private var primary: Color { onBrand ? .white : Theme.textPrimary }
    private var secondary: Color { onBrand ? .white.opacity(0.8) : Theme.textSecondary }
    private var accent: Color { onBrand ? .white : Theme.brandPrimary }

    private var reminderDay: Int { max(1, trialDays - 2) }

    private var steps: [(icon: String, title: String, detail: String, highlight: Bool)] {
        [
            ("lock.open.fill", "Today", "Everything unlocks. Full access, $0 due now.", true),
            ("bell.fill", "Day \(reminderDay)", "We'll remind you before the trial ends.", false),
            ("flag.checkered", "Day \(trialDays)",
             billingNote ?? "Cancel anytime before it ends. No surprise charges.", false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(step.highlight ? accent : accent.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: step.icon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(step.highlight ? (onBrand ? Theme.brandPrimary : .white) : accent)
                        }
                        if idx < steps.count - 1 {
                            Rectangle()
                                .fill(accent.opacity(0.25))
                                .frame(width: 2, height: 26)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title)
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(primary)
                        Text(step.detail)
                            .font(Theme.caption())
                            .foregroundStyle(secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, idx < steps.count - 1 ? 8 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
