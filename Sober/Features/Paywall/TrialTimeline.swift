import SwiftUI

/// "How your free trial works" — a 3-step vertical timeline. Showing the user
/// exactly when (and whether) they'll be charged removes billing anxiety and
/// keeps the free part front and center.
///
/// The middle step is the one that does the work. The two moments people cancel
/// are day 1 ("is this for me?") and the day before billing ("am I about to get
/// charged?"), and naming the reminder out loud converts the second one from a
/// fear into a promise. Blinkist reported a 23% lift in conversion and a 55%
/// drop in billing complaints from exactly this, so the reminder is a headline
/// here rather than fine print.
struct TrialTimeline: View {
    /// Trial length in days. Always read from the store product, never a
    /// literal — the whole point is that this tracks the real offer.
    let trialDays: Int
    /// Optional billing note for the final step (small disclosure copy only).
    var billingNote: String? = nil
    var onBrand: Bool = false
    /// Whether the app can actually deliver the reminder it promises in step 2.
    /// False when notifications are denied, in which case the step describes the
    /// in-app heads-up instead of promising a push that will never arrive.
    var remindersEnabled: Bool = true
    /// Tighter connectors and row spacing, for the one-page paywall where the
    /// timeline has to share a screen with the plan stack.
    var compact: Bool = false

    private var primary: Color { onBrand ? .white : Theme.textPrimary }
    private var secondary: Color { onBrand ? .white.opacity(0.8) : Theme.textSecondary }
    private var accent: Color { onBrand ? .white : Theme.brandPrimary }

    /// Mirrors `NotificationService.trialReminderLeadDays` rather than repeating
    /// the number, so the day shown here can never drift from the day the
    /// reminder actually fires. Static so a test can hold the two in step.
    static func reminderDay(forTrialOf days: Int) -> Int {
        max(1, days - NotificationService.trialReminderLeadDays)
    }

    private var reminderDay: Int { Self.reminderDay(forTrialOf: trialDays) }

    private var steps: [(icon: String, title: String, detail: String, highlight: Bool)] {
        [
            ("lock.open.fill", "Today", "Everything unlocks. Full access, $0 due now.", true),
            ("bell.fill", "Day \(reminderDay)",
             remindersEnabled
                ? "We'll remind you before your trial ends."
                : "Sober shows you a heads-up in the app before it ends.",
             false),
            ("flag.checkered", "Day \(trialDays)",
             billingNote ?? "Your subscription starts. Cancel any time before then.", false),
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
                                .frame(width: 2, height: compact ? 16 : 26)
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
                    .padding(.bottom, idx < steps.count - 1 ? (compact ? 4 : 8) : 0)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
