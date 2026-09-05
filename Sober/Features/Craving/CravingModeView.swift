import SwiftData
import SwiftUI

/// The ride-it-out tool: the one screen in this app that exists for the moment
/// something is hard rather than the moment something went well.
///
/// Three deliberate choices:
///   * **No gate.** Free, unlimited, no paywall anywhere in the flow. A
///     purchase decision does not belong in front of someone mid-urge.
///   * **No questions on the way in.** Tapping the button starts the breathing
///     immediately. Intensity and trigger are captured on the way out, when
///     the user is calmer and the answers are worth more.
///   * **Nothing is scored.** Giving in is a logged outcome like any other.
///     A tool people lie to is a tool that produces nothing.
struct CravingModeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SubscriptionService.self) private var subscriptions

    /// Called once the episode has been written, with the outcome the user
    /// chose, so Home can react (celebrate, nudge, refresh).
    var onFinish: (CravingOutcome) -> Void = { _ in }

    private enum Step { case breathing, reflect, done }

    @State private var step: Step = .breathing
    @State private var startedAt = Date.now
    @State private var elapsed = 0
    @State private var targetSeconds = HabitVocabulary.typicalUrgeSeconds
    @State private var circleScale: CGFloat = 0.72
    @State private var intensity: Int?
    @State private var hasFinished = false
    @State private var trigger: String?
    @State private var rodeOutTotal = 0
    /// The one personal line Bloom+ adds to the session, resolved once on
    /// appear rather than per tick. Nil for a free subscriber and for anyone
    /// without enough history to say anything true, so the free session is the
    /// session as it always was rather than a nagged version of it.
    @State private var coachLine: String?

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch step {
            case .breathing: breathingStep
            case .reflect: reflectStep
            case .done: doneStep
            }
        }
        .onReceive(tick) { _ in
            guard step == .breathing else { return }
            elapsed += 1
            if elapsed >= targetSeconds { advanceToReflect() }
        }
        .onChange(of: breathPhase) { _, phase in animate(to: phase) }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            animate(to: breathPhase)
            if subscriptions.isProSubscriber {
                coachLine = CravingInsights.coachLine(CravingService(context: context).facts())
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .interactiveDismissDisabled(step == .breathing)
    }

    // MARK: - Breathing

    /// Box breathing, 4 counts a side. Chosen over 4-7-8 because it is
    /// symmetric and therefore legible without instructions, and because it
    /// makes no claim to do anything clinical.
    private enum BreathPhase: Int { case inhale, holdFull, exhale, holdEmpty

        var label: String {
            switch self {
            case .inhale: return "Breathe in"
            case .holdFull, .holdEmpty: return "Hold"
            case .exhale: return "Breathe out"
            }
        }
    }

    private static let phaseSeconds = 4
    private var breathPhase: BreathPhase {
        BreathPhase(rawValue: (elapsed / Self.phaseSeconds) % 4) ?? .inhale
    }

    private func animate(to phase: BreathPhase) {
        let target: CGFloat
        switch phase {
        case .inhale, .holdFull: target = 1.0
        case .exhale, .holdEmpty: target = 0.72
        }
        guard !reduceMotion else { circleScale = target; return }
        // The animation runs the length of the phase, so "hold" phases simply
        // arrive at a value they are already at and sit still. One rule, four
        // phases, no special-casing.
        withAnimation(.easeInOut(duration: Double(Self.phaseSeconds))) {
            circleScale = target
        }
    }

    private var breathingStep: some View {
        VStack(spacing: Theme.Space.xl) {
            HStack {
                Button {
                    finish(outcome: .unresolved)
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(timeRemaining)
                    .font(Theme.body(weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, Theme.Space.m)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(Theme.ringTrack, lineWidth: 1)
                    .frame(width: 260, height: 260)
                Circle()
                    .fill(Theme.brandPrimary.opacity(0.14))
                    .frame(width: 260, height: 260)
                    .scaleEffect(circleScale)
                Circle()
                    .stroke(Theme.brandPrimary.opacity(0.5), lineWidth: 2)
                    .frame(width: 260, height: 260)
                    .scaleEffect(circleScale)
                Text(breathPhase.label)
                    .font(Theme.heading())
                    .foregroundStyle(Theme.brandPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(breathPhase.label)

            VStack(spacing: Theme.Space.s) {
                Text(CravingCoach.line(elapsed: elapsed, target: targetSeconds))
                    .font(Theme.body())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: CravingCoach.line(elapsed: elapsed, target: targetSeconds))
                // Held back until the user is far enough in that a line about
                // their own history reads as reassurance rather than a stat.
                if let coachLine, elapsed >= targetSeconds / 3 {
                    Text(coachLine)
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 320)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeInOut, value: elapsed >= targetSeconds / 3)

            Spacer(minLength: 0)

            VStack(spacing: Theme.Space.m) {
                Button { advanceToReflect() } label: {
                    Text("I'm through it")
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brandPrimary, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    targetSeconds = min(HabitVocabulary.maxUrgeSeconds, targetSeconds + 60)
                } label: {
                    Text("Give me another minute")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)
                }
                .buttonStyle(.plain)
                .opacity(targetSeconds >= HabitVocabulary.maxUrgeSeconds ? 0 : 1)
                .disabled(targetSeconds >= HabitVocabulary.maxUrgeSeconds)
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .padding(.top, Theme.Space.s)
    }

    private var timeRemaining: String {
        let left = max(0, targetSeconds - elapsed)
        return String(format: "%d:%02d", left / 60, left % 60)
    }

    private func advanceToReflect() {
        withAnimation { step = .reflect }
    }

    // MARK: - Reflect

    private var reflectStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("You stayed with it for \(spokenElapsed).")
                        .font(Theme.title())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Two quick questions while it's fresh. Both optional.")
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("How strong was it?")
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: Theme.Space.s) {
                        ForEach(1...5, id: \.self) { value in
                            Button { intensity = intensity == value ? nil : value } label: {
                                Text("\(value)")
                                    .font(Theme.body(weight: .semibold))
                                    .foregroundStyle(intensity == value ? .white : Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        intensity == value ? Theme.brandPrimary : Theme.cardSurface,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Intensity \(value) of 5")
                            .accessibilityAddTraits(intensity == value ? .isSelected : [])
                        }
                    }
                    HStack {
                        Text("Mild").font(Theme.caption()).foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text("Overwhelming").font(Theme.caption()).foregroundStyle(Theme.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("What set it off?")
                        .font(Theme.body(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    TriggerChips(selected: $trigger)
                }

                VStack(spacing: Theme.Space.m) {
                    Button { finish(outcome: .rodeItOut) } label: {
                        Text("It passed")
                            .font(Theme.body(weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.brandPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button { finish(outcome: .unresolved) } label: {
                        Text("Not sure yet. Close session")
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button { finish(outcome: .gaveIn) } label: {
                        Text("I gave in")
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Theme.Space.s)
            }
            .padding(Theme.Space.xl)
        }
    }

    private var spokenElapsed: String {
        if elapsed < 60 { return "\(max(1, elapsed)) seconds" }
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        if seconds == 0 { return minutes == 1 ? "a minute" : "\(minutes) minutes" }
        return "\(minutes)m \(seconds)s"
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "wind")
                .font(.system(size: 48))
                .foregroundStyle(Theme.brandPrimary)
            Text("Logged.")
                .font(Theme.title())
                .foregroundStyle(Theme.textPrimary)
            if rodeOutTotal > 0 {
                Text(rodeOutTotal == 1
                     ? "That's one \(HabitVocabulary.urgeNoun) you've ridden out."
                     : "That's \(rodeOutTotal) \(HabitVocabulary.urgeNounPlural) you've ridden out.")
                    .font(Theme.body())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let doneLine {
                Text(doneLine)
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Back to the garden")
                    .font(Theme.body(weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .padding(Theme.Space.xl)
    }

    /// Bloom+ closes the loop: the session the user just logged changes the
    /// number they see when they finish it.
    private var doneLine: String? {
        guard subscriptions.isProSubscriber,
              let rate = CravingInsights.rideOutRate(CravingService(context: context).facts())
        else { return nil }
        return "\(rate.rode) of your last \(rate.resolved) ended this way."
    }

    // MARK: - Persistence

    private func finish(outcome: CravingOutcome) {
        guard !hasFinished else { return }
        hasFinished = true
        let service = CravingService(context: context)
        service.record(
            startedAt: startedAt,
            secondsElapsed: elapsed,
            outcome: outcome,
            intensity: intensity,
            trigger: trigger
        )
        onFinish(outcome)

        guard outcome == .rodeItOut else { dismiss(); return }
        rodeOutTotal = service.rodeOutCount()
        withAnimation { step = .done }
    }
}

/// Wrapping one-tap trigger tags. Tapping the selected chip clears it, so the
/// question stays genuinely optional.
private struct TriggerChips: View {
    @Binding var selected: String?

    var body: some View {
        FlowLayout(spacing: Theme.Space.s) {
            ForEach(HabitVocabulary.triggers, id: \.self) { tag in
                Button {
                    selected = (selected == tag) ? nil : tag
                } label: {
                    Text(tag)
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(selected == tag ? .white : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selected == tag ? Theme.brandPrimary : Theme.cardSurface,
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(Theme.ringTrack, lineWidth: selected == tag ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal wrapping stack. `LazyVGrid` cannot do ragged rows and the chip
/// labels are localized, so their widths are not knowable up front.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width == .infinity ? rows.map(\.width).max() ?? 0 : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in layout(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.range {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var range: Range<Int>
        var y: CGFloat
        var height: CGFloat
        var width: CGFloat
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var start = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(Row(range: start..<index, y: y, height: rowHeight, width: x - spacing))
                start = index
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if start < subviews.count {
            rows.append(Row(range: start..<subviews.count, y: y, height: rowHeight, width: max(0, x - spacing)))
        }
        return rows
    }
}
