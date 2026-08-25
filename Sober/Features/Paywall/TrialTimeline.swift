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
    /// `.horizontal` lays the three steps out as columns. Same content, about
    /// half the height: on the Bloom+ tab the vertical version was the single
    /// tallest block on a page that already didn't fit inside the tab bar.
    var layout: Layout = .vertical

    enum Layout {
        case vertical
        case horizontal
    }

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

    private var steps: [(icon: String, title: String, detail: String, short: String, highlight: Bool)] {
        [
            ("lock.open.fill", "Today", "Everything unlocks. Full access, $0 due now.",
             "Everything unlocks, $0 due now.", true),
            ("bell.fill", "Day \(reminderDay)",
             remindersEnabled
                ? "We'll remind you before your trial ends."
                : "Sober shows you a heads-up in the app before it ends.",
             remindersEnabled ? "We remind you before it ends." : "A heads-up in the app first.",
             false),
            ("flag.checkered", "Day \(trialDays)",
             billingNote ?? "Your subscription starts. Cancel any time before then.",
             billingNote ?? "Billing starts. Cancel by then.", false),
        ]
    }

    /// The reminder step promises a push, but at the time this screen is shown
    /// permission usually hasn't been asked for yet (we ask when the trial
    /// actually starts). If they decline it there, the promise is already made
    /// and there's no going back to correct it, so the condition is stated here
    /// rather than discovered later.
    private var reminderFootnote: String? {
        remindersEnabled ? "Reminder needs notifications turned on." : nil
    }

    var body: some View {
        switch layout {
        case .vertical: verticalBody
        case .horizontal: horizontalBody
        }
    }

    /// Three columns joined by a rule that runs behind the markers. Details are
    /// the `short` variants: a column is roughly a third of the width, and the
    /// full sentences wrap to four lines there and give back the height this
    /// layout exists to save.
    private var horizontalBody: some View {
        VStack(spacing: 7) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    VStack(spacing: 5) {
                        marker(icon: step.icon, highlight: step.highlight)
                        Text(step.title)
                            .font(Theme.caption(weight: .bold))
                            .foregroundStyle(primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(step.short)
                            .font(Theme.caption())
                            .foregroundStyle(secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .background(alignment: .top) {
                GeometryReader { geo in
                    Rectangle()
                        .fill(accent.opacity(0.25))
                        .frame(width: geo.size.width / 3 * 2, height: 2)
                        .position(x: geo.size.width / 2, y: 14)
                }
            }

            if let reminderFootnote {
                Text(reminderFootnote)
                    .font(Theme.caption())
                    .foregroundStyle(secondary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Opaque under the connecting rule, so the line reads as joining the
    /// markers rather than passing through them.
    private func marker(icon: String, highlight: Bool) -> some View {
        ZStack {
            Circle()
                .fill(onBrand ? Theme.brandPrimary : Theme.cardSurface)
                .frame(width: 28, height: 28)
            Circle()
                .fill(highlight ? accent : accent.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(highlight ? (onBrand ? Theme.brandPrimary : .white) : accent)
        }
    }

    private var verticalBody: some View {
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

            if let reminderFootnote {
                Text(reminderFootnote)
                    .font(Theme.caption())
                    .foregroundStyle(secondary.opacity(0.75))
                    .padding(.top, compact ? 6 : 8)
                    .padding(.leading, 42)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
