import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var step: Int = 0
    @State private var startDate: Date = .now
    @State private var costPerDay: Double = 20
    @State private var caloriesPerDay: Double = 600
    @State private var reminderHour: Int = 9
    @State private var trialInFlight = false
    @State private var trialResolutionInFlight = false
    @State private var trialResolutionError: String?
    @State private var trialError: String?
    @State private var restoreInFlight = false
    @State private var showPaywallFallback = false
    @State private var didShowOnboardingTrial = false
    @State private var madeCommitment = false

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            VStack {
                switch step {
                case 0: welcome
                case 1: startDateStep
                case 2: spendStep
                case 3: reminderStep
                case 4: commitStep
                case 5: trialStep
                default: welcome
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.l)
            .foregroundStyle(Color.white)
        }
        .sheet(isPresented: $showPaywallFallback, onDismiss: { finishOnboarding() }) {
            PaywallView(impressionId: "sober_onboarding_trial_fallback")
        }
        .task {
            #if canImport(RevenueCat)
            if subscriptions.isConfigured, subscriptions.packages.isEmpty {
                await subscriptions.fetchProducts()
            }
            #endif
        }
    }

    private var welcome: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 96))
            Text("Sober").font(Theme.display(64, weight: .semibold))
            Text("Track your sobriety, grow your garden, watch your health return.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            bottomBar(primaryTitle: "Get Started") { step = 1 }
        }
    }

    private var startDateStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("When did your sober journey begin?")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.white)
            Spacer()
            bottomBar(primaryTitle: "Continue") { step = 2 }
        }
    }

    private var spendStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Text("How much did you typically spend per day?")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.Space.s) {
                Text("$\(Int(costPerDay)) / day")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Slider(value: $costPerDay, in: 0...200, step: 5)
                    .tint(.white)
            }
            VStack(spacing: Theme.Space.s) {
                Text("Calories per day")
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(Int(caloriesPerDay)) cal")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Slider(value: $caloriesPerDay, in: 0...3000, step: 50)
                    .tint(.white)
            }
            savingsProjection
            Spacer(minLength: Theme.Space.s)
            bottomBar(primaryTitle: "Continue") { step = 3 }
        }
    }

    @ViewBuilder
    private var savingsProjection: some View {
        let dollars = Int(costPerDay)
        let calories = Int(caloriesPerDay)
        if dollars > 0 || calories > 0 {
            let yearlyDollars = dollars * 365
            let yearlyCalories = calories * 365
            let yearlyPounds = Double(yearlyCalories) / 3500.0  // ~3,500 kcal per lb of fat
            VStack(spacing: 4) {
                Text("In a year, that's")
                    .font(Theme.subhead())
                    .foregroundStyle(.white.opacity(0.75))
                if dollars > 0 {
                    Text(formatCurrency(yearlyDollars))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }
                if calories > 0 {
                    Text(dollars > 0
                         ? "plus \(yearlyCalories.formatted()) calories you won't have to spend. About \(yearlyPounds.formatted(.number.precision(.fractionLength(0)))) lb of body fat."
                         : "\(yearlyCalories.formatted()) calories you won't have to spend. That's about \(yearlyPounds.formatted(.number.precision(.fractionLength(0)))) lb of body fat.")
                        .font(Theme.caption())
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.m)
            .padding(.horizontal, Theme.Space.m)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func formatCurrency(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    private var reminderStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("Daily reminder time")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Picker("Hour", selection: $reminderHour) {
                ForEach(0..<24) { h in
                    Text(formatHour(h)).font(Theme.body()).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)
            Spacer()
            bottomBar(primaryTitle: "Continue") { step = 4 }
        }
    }

    /// Final step: a deliberate commitment. Recovery starts with a decision —
    /// asking the user to actively pledge (rather than tap a neutral "Done")
    /// gives them a moment to lock in before the journey begins. A quieter
    /// "Not now" path lets reluctant users continue without forcing a pledge
    /// they don't mean — the answer is also a signal we use to tune the tone
    /// of nudges throughout the app.
    private var commitStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .opacity(0.92)
            Text("Make it official")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Text("Recovery starts with a decision. This is yours, for today and the days that follow.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            bottomBar(
                primaryTitle: trialResolutionInFlight ? "Checking trial availability…" : "I commit to getting better",
                busy: trialResolutionInFlight,
                above: {
                    VStack(spacing: Theme.Space.s) {
                        Button { commit(committed: false) } label: {
                            Text("Not now")
                                .font(Theme.subhead(weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .underline()
                                .padding(.vertical, 6)
                        }
                        .disabled(trialResolutionInFlight)
                        Text("Either way is fine. You can revisit this any time in Settings.")
                            .font(Theme.caption())
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Space.m)
                        if let trialResolutionError {
                            Text(trialResolutionError)
                                .font(Theme.caption(weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.68))
                                .multilineTextAlignment(.center)
                            HStack(spacing: Theme.Space.l) {
                                Button("Retry") { resolveTrialAfterCommit() }
                                Button("Continue free") { finishOnboarding() }
                            }
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(.white)
                        }
                    }
                }
            ) { commit(committed: true) }
        }
    }

    /// Trial step — shown right after the commitment while motivation (and the
    /// just-entered spend numbers) peak. Styled as the next onboarding step
    /// (same moss chrome, type scale, and CTA slot as steps 0-4), not a
    /// paywall: short pitch + three benefit bullets, soft "Get Started" free
    /// exit above the primary, and the Apple 3.1.2 disclosure adjacent to the
    /// button. Only reached when a free trial is actually on the table;
    /// otherwise we skip straight to finishing onboarding.
    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Image(systemName: trialEligible ? "gift.fill" : "checkmark.circle.fill")
                .font(.system(size: 72))
                .opacity(0.92)
            Text(trialEligible ? "Make your commitment count" : "You're all set")
                .font(Theme.display())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.m)
            Text(trialEligible
                 ? "You just committed. Try every tool that keeps you on track, free for \(trialDays) days."
                 : "Your garden is planted. Let's begin.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.m)

            if trialEligible {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    trialBullet(icon: "heart.text.square.fill", text: "Full health timeline with 13 recovery milestones")
                    trialBullet(icon: "book.closed.fill", text: "Daily journal prompts for the hard days")
                    trialBullet(icon: "dollarsign.circle.fill", text: savingsBulletText)
                }
                .padding(.horizontal, Theme.Space.m)
                .padding(.top, Theme.Space.s)
            }

            Spacer(minLength: Theme.Space.s)

            if trialEligible {
                bottomBar(
                    primaryTitle: trialCTATitle,
                    busy: trialInFlight,
                    showLegalFooter: true,
                    above: { trialAboveButton }
                ) { startOnboardingTrial() }
            } else {
                bottomBar(primaryTitle: "Start growing") { finishOnboarding() }
            }
        }
        .onAppear {
            #if canImport(RevenueCat)
            // The trial-first onboarding step is a paywall surface — measure it like
            // the others (sober_bloom_tab / sober_trial_sheet) so view→trial-start
            // conversion for the new step shows up in RevenueCat.
            if trialEligible {
                subscriptions.trackPaywallImpression(
                    id: "sober_onboarding_trial",
                    package: subscriptions.directTrialPackage,
                    oncePerSession: true
                )
                // Start the passive-nudge cooldown at this pitch. Without it the
                // gate is empty on first run and the Home passive nudge re-pitches
                // TrialOfferSheet ~6s after the user just declined this step.
                TrialNudgeGate.markShown()
            }
            #endif
        }
    }

    private func trialBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(Theme.body(weight: .semibold))
                .frame(width: 24)
                .opacity(0.92)
            Text(text)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// One small savings mention inside a benefit bullet (the timeline hero and
    /// savings card read too paywall-ish for an onboarding step).
    private var savingsBulletText: String {
        let dollars = Int(costPerDay)
        if dollars > 0 {
            return "Money and calories saved, on pace for \(formatCurrency(dollars * 365)) a year"
        }
        return "Money and calories saved, tracked automatically"
    }

    /// Trial-only content that sits ABOVE the primary CTA (absorbed by the
    /// Spacer so it never shifts the button): soft free exit, billing
    /// disclosure, error.
    @ViewBuilder
    private var trialAboveButton: some View {
        VStack(spacing: Theme.Space.s) {
            // Soft free exit sits ABOVE the primary so the trial button lands in
            // the exact spot the user has been tapping Continue. Rev A: labeled
            // "Get Started" (StatScout soft-exit label), visually secondary.
            Button { finishOnboarding() } label: {
                Text("Get Started")
                    .font(Theme.subhead(weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .underline()
                    .padding(.vertical, 6)
            }
            .disabled(trialInFlight)

            // No disclosure until the package (and its real price) loads — never
            // a placeholder price (Apple 3.1.2).
            if let disclosure = trialDisclosureText {
                Text(disclosure)
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.m)
            }

            if let trialError {
                Text(trialError)
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.68))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Shared bottom CTA bar rendered on EVERY step so the primary button's
    /// frame is pixel-identical across the whole flow (Rev A zero-shift bar):
    /// variable content goes ABOVE the button, and a fixed-height legal-footer
    /// slot below it is rendered on every step — real Terms/Privacy/Restore on
    /// the trial step, the exact same view invisible elsewhere — so the
    /// distance from the button to the screen bottom never changes.
    private func bottomBar<Above: View>(
        primaryTitle: String,
        busy: Bool = false,
        showLegalFooter: Bool = false,
        @ViewBuilder above: () -> Above = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Theme.Space.s) {
            above()
            Button(action: { withAnimation { action() } }) {
                ZStack {
                    Text(primaryTitle)
                        .font(Theme.body(weight: .semibold))
                        .opacity(busy ? 0 : 1)
                    if busy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
            }
            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            .disabled(busy)

            legalFooter
                .opacity(showLegalFooter ? 1 : 0)
                .allowsHitTesting(showLegalFooter)
                .accessibilityHidden(!showLegalFooter)
        }
    }

    /// Terms / Privacy / Restore. Rendered on every onboarding step (invisible
    /// off the trial step) so its height reserves the same space under the CTA.
    private var legalFooter: some View {
        HStack(spacing: 12) {
            Button { restorePurchasesFromOnboarding() } label: {
                Text(restoreInFlight ? "Restoring…" : "Restore")
                    .underline()
            }
            .disabled(restoreInFlight)
            Text("·")
            Link("Terms of Use", destination: PaywallLinks.standardEULA)
            Text("·")
            Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
        }
        .font(Theme.caption())
        .foregroundStyle(.white.opacity(0.75))
        .tint(.white)
    }

    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h
        let d = Calendar.current.date(from: comps) ?? .now
        return f.string(from: d)
    }

    // MARK: - Trial step plumbing

    private var trialEligible: Bool {
        #if canImport(RevenueCat)
        return !subscriptions.isProSubscriber && subscriptions.hasTrialOfferAvailable
        #else
        return false
        #endif
    }

    /// Apple 3.1.2 disclosure adjacent to the primary CTA: trial length, real
    /// loaded price, auto-renew + cancel path. Nil until the package loads.
    private var trialDisclosureText: String? {
        #if canImport(RevenueCat)
        return subscriptions.directTrialCTADisclosureText
        #else
        return nil
        #endif
    }

    private var trialCTATitle: String {
        #if canImport(RevenueCat)
        if let label = subscriptions.directTrialPackage?.soberIntroOfferLabel {
            return "Start my \(label)"
        }
        #endif
        return "Start my free trial"
    }

    /// Trial length in days, parsed from the offer label ("7-day free trial").
    private var trialDays: Int {
        #if canImport(RevenueCat)
        if let label = subscriptions.directTrialPackage?.soberIntroOfferLabel {
            let digits = String(label.drop { !$0.isNumber }.prefix { $0.isNumber })
            if let n = Int(digits) { return n }
        }
        #endif
        return 7
    }

    /// Persist setup, then wait for a real RevenueCat eligibility decision. A
    /// loading or network failure is never treated as a consumed trial.
    private func commit(committed: Bool) {
        persistSetup(committed: committed)
        resolveTrialAfterCommit()
    }

    private func resolveTrialAfterCommit() {
        guard !trialResolutionInFlight else { return }
        trialResolutionError = nil
        trialResolutionInFlight = true
        Task { @MainActor in
            defer { trialResolutionInFlight = false }
            #if canImport(RevenueCat)
            guard subscriptions.isConfigured else {
                trialResolutionError = "Couldn't check trial availability. Retry, or continue with the free version."
                return
            }
            switch await subscriptions.resolveOnboardingTrial() {
            case .eligible:
                didShowOnboardingTrial = true
                withAnimation { step = 5 }
            case .ineligible:
                finishOnboarding()
            case .unavailable, .failed:
                trialResolutionError = "Couldn't check trial availability. Retry, or continue with the free version."
            }
            #else
            finishOnboarding()
            #endif
        }
    }

    private func startOnboardingTrial() {
        #if canImport(RevenueCat)
        // Products failing to load falls back to the full paywall rather than a
        // dead button; dismissing that paywall finishes onboarding.
        guard let package = subscriptions.directTrialPackage else {
            showPaywallFallback = true
            return
        }
        trialError = nil
        trialInFlight = true
        Task { @MainActor in
            defer { trialInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased, .pending:
                    finishOnboarding()
                case .cancelled:
                    trialError = "Trial start cancelled. Tap again to begin."
                }
            } catch {
                trialError = "Couldn't start your trial. Please try again."
            }
        }
        #else
        finishOnboarding()
        #endif
    }

    /// Restore from the trial step's legal footer. Success (an active
    /// entitlement) finishes onboarding — the user is already Pro.
    private func restorePurchasesFromOnboarding() {
        guard !restoreInFlight else { return }
        restoreInFlight = true
        Task { @MainActor in
            defer { restoreInFlight = false }
            await subscriptions.restorePurchases()
            if subscriptions.isProSubscriber { finishOnboarding() }
        }
    }

    /// Save everything except the onboarding-complete flag, so the trial step can
    /// still render before RootView swaps to the main app. Notifications are
    /// requested after the trial step so the permission prompt doesn't interrupt
    /// the paywall flow.
    private func persistSetup(committed: Bool) {
        madeCommitment = committed
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int(costPerDay * 100)
        settings.caloriesPerDay = Int(caloriesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.madeCommitment = committed

        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()
    }

    /// Flip onboarding complete (swaps RootView to the main app) and queue the
    /// lighter post-onboarding popup. That popup auto-skips when the user already
    /// started the trial here (they're Pro), so they never see it twice.
    private func finishOnboarding() {
        let settings = SettingsService(context: context).current()
        settings.hasCompletedOnboarding = true
        try? context.save()

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour, committed: madeCommitment)
        }

        // Only queue the immediate Home popup when we *didn't* already pitch the
        // trial in onboarding — otherwise the user would see the same sheet twice
        // within a second. When the onboarding step ran, the "quick popup later"
        // is the cooldown-gated Health nudge instead.
        if !didShowOnboardingTrial {
            AppGroup.defaults.set(true, forKey: AppGroup.postOnboardingPaywallKey)
        }
        WidgetSnapshotPump.push(context: context)
    }
}
