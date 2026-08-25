import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var step = 0
    #if DEBUG
    /// `-onboardingStep N` jumps straight to a step. The start-date wheel picker
    /// wedges the accessibility bridge, so this is the only way to inspect the
    /// trial screen on a headless simulator.
    private static var launchStep: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-onboardingStep"),
              index + 1 < args.count else { return nil }
        return Int(args[index + 1])
    }
    #endif
    @State private var startDate: Date = .now
    @State private var costPerDay: Double = 20
    @State private var caloriesPerDay: Double = 600
    @State private var trialInFlight = false
    @State private var trialResolutionInFlight = false
    @State private var trialResolutionError: String?
    @State private var trialError: String?
    @State private var restoreInFlight = false
    @State private var didShowOnboardingTrial = false
    @State private var reminderRequestInFlight = false
    /// Set by the reminders step, read by `persistSetup`. Onboarding used to
    /// hard-code this to false and nothing ever raised the system prompt, so a
    /// user who never opened Settings had every nudge in the app scheduled and
    /// silently dropped.
    @State private var dailyRemindersOptIn = false
    /// False once the store confirms this Apple ID has already used its intro
    /// offer. The offer step still runs; it just sells the plan instead of a
    /// trial, and never says the word "free".
    @State private var offerIncludesTrial = true
    @State private var showSkipTrialConfirm = false

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            Group {
                switch step {
                case 0: promiseStep
                case 1: startDateStep
                case 2: savingsStep
                case 3: trialStep
                case 4: remindersStep
                default: promiseStep
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.l)
            .foregroundStyle(.white)
        }
        .task {
            ConversionDiagnostics.record(.onboardingReached)
            #if canImport(RevenueCat)
            if subscriptions.isConfigured, subscriptions.packages.isEmpty {
                await subscriptions.fetchProducts()
            }
            #endif
            #if DEBUG
            if let launchStep = Self.launchStep {
                // The offer step normally learns this from
                // `resolveTrialAndContinue`, which a direct jump skips. Read it
                // from the store instead so `-previewTrialUsed` renders the
                // no-trial copy rather than a trial the account can't have.
                #if canImport(RevenueCat)
                offerIncludesTrial = subscriptions.directTrialPackage != nil
                #endif
                step = launchStep
            }
            #endif
        }
    }

    private var promiseStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 150, height: 150)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 76, weight: .semibold))
            }
            VStack(spacing: Theme.Space.m) {
                Text("Your sober days, growing.")
                    .font(Theme.display(44, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("Count every day, grow a private bonsai, and see what your body and wallet get back.")
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Space.s)
            }
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                promiseRow(icon: "calendar", text: "A clear sobriety counter and calendar")
                promiseRow(icon: "tree.fill", text: "A garden that changes with your streak")
                promiseRow(icon: "lock.fill", text: "Private on your device, no account")
            }
            .padding(.horizontal, Theme.Space.m)
            Spacer()
            bottomBar(primaryTitle: "Start my counter") { step = 1 }
        }
    }

    private func promiseRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(Theme.body(weight: .semibold))
                .frame(width: 24)
            Text(text)
                .font(Theme.body())
            Spacer(minLength: 0)
        }
    }

    private var startDateStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer(minLength: Theme.Space.s)
            Text("When did your sober journey begin?")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Text("Today is fine. You can change this later.")
                .font(Theme.subhead())
                .foregroundStyle(.white.opacity(0.8))
            DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.white)
            Spacer(minLength: Theme.Space.s)
            bottomBar(primaryTitle: "Continue") { step = 2 }
        }
    }

    private var savingsStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Text("See what drinking used to cost")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Text("Optional. Use zero if you only want the day counter and garden.")
                .font(Theme.subhead())
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(spacing: Theme.Space.s) {
                Text("Typical daily spend")
                    .font(Theme.subhead())
                    .foregroundStyle(.white.opacity(0.82))
                Text("$\(Int(costPerDay)) / day")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Slider(value: $costPerDay, in: 0...200, step: 5)
                    .tint(.white)
            }

            VStack(spacing: Theme.Space.s) {
                Text("Typical calories")
                    .font(Theme.subhead())
                    .foregroundStyle(.white.opacity(0.82))
                Text("\(Int(caloriesPerDay)) / day")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Slider(value: $caloriesPerDay, in: 0...3000, step: 50)
                    .tint(.white)
            }

            savingsProjection
            Spacer(minLength: Theme.Space.s)
            bottomBar(
                primaryTitle: trialResolutionInFlight ? "Checking trial availability…" : "Continue",
                busy: trialResolutionInFlight,
                above: { resolutionError }
            ) { resolveTrialAndContinue() }
        }
    }

    @ViewBuilder
    private var savingsProjection: some View {
        let yearlyDollars = Int(costPerDay) * 365
        let yearlyCalories = Int(caloriesPerDay) * 365
        VStack(spacing: 5) {
            Text("One alcohol-free year keeps")
                .font(Theme.subhead())
                .foregroundStyle(.white.opacity(0.78))
            if yearlyDollars > 0 {
                Text(formatCurrency(yearlyDollars))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
            }
            if yearlyCalories > 0 {
                Text("and \(yearlyCalories.formatted()) calories out of your routine")
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.m)
        .padding(.horizontal, Theme.Space.m)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var resolutionError: some View {
        if let trialResolutionError {
            VStack(spacing: Theme.Space.s) {
                Text(trialResolutionError)
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.72))
                    .multilineTextAlignment(.center)
                Button("Get started") { finishOnboarding() }
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .semibold))
            VStack(spacing: Theme.Space.s) {
                Text(trialHeadline)
                    .font(Theme.display(42, weight: .bold))
                    .multilineTextAlignment(.center)
                    // "14 days of Bloom+ free" is two characters longer than the
                    // 7-day version and truncated to "14 days of Bloom…" at 42pt.
                    // Let it wrap, and shrink before it ever clips again.
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trialSubhead)
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    // Without this the parent compresses it to a single clipped
                    // line, which hid the charge-date half of the sentence.
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Theme.Space.m) {
                trialBenefit(icon: "tree.fill", text: "Grow and switch every bonsai species")
                trialBenefit(icon: "heart.text.square.fill", text: "Follow 13 sourced recovery milestones")
                trialBenefit(icon: "chart.line.uptrend.xyaxis", text: trialSavingsText)
                trialBenefit(icon: "book.closed.fill", text: "Journal privately through difficult moments")
            }
            .padding(Theme.Space.m)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: Theme.Space.s)
            bottomBar(
                primaryTitle: trialCTATitle,
                busy: trialInFlight,
                showLegalFooter: true,
                above: { trialAboveButton },
                below: {
                    VStack(spacing: Theme.Space.s) {
                        trialRenewalDisclosure
                        skipTrialLink
                    }
                }
            ) { startOnboardingTrial() }
        }
        // Cancel role sits on "stay", not on "skip": an alert dismissed by
        // gesture resolves to the cancel action, and that must not be the path
        // that silently gives up the trial.
        .alert("Keep the free version?", isPresented: $showSkipTrialConfirm) {
            Button("Get started") {
                ConversionDiagnostics.record(.freeVersionChosen)
                finishOnboarding()
            }
            Button("Keep my free trial", role: .cancel) {}
        } message: {
            Text("You'll keep the day counter, the calendar, and your tree. Your year-ahead projection, the full health timeline, the journal, and the other species stay locked.")
        }
        .onAppear {
            didShowOnboardingTrial = true
            ConversionDiagnostics.record(.trialOfferReached)
            #if canImport(RevenueCat)
            subscriptions.trackPaywallImpression(
                id: offerIncludesTrial
                    ? "sober_onboarding_trial_1_2_2"
                    : "sober_onboarding_offer_no_trial",
                package: subscriptions.directOfferPackage,
                oncePerSession: true
            )
            #endif
            TrialNudgeGate.markShown()
        }
    }

    /// The objection at this moment is "am I about to be charged", not "what do
    /// I get" — the benefit card below already answers the second one. Naming
    /// the charge date is what converts, so the subhead states it plainly and
    /// derives it, and says nothing about a date when the length is unknown.
    private var trialSubhead: String {
        guard offerIncludesTrial else {
            return "Every tool that keeps the streak visible, unlocked today."
        }
        guard let trialDays else {
            return "Every tool that keeps the streak visible. Nothing is charged today."
        }
        return "Every tool that keeps the streak visible. Nothing is charged for \(trialDays) days."
    }

    /// One line, not the paywall's three-step timeline: onboarding is a
    /// momentum moment and a full "here is when you get charged" diagram turns a
    /// single tap into a deliberation. But the charge date is the objection that
    /// actually stops people, and Apple sends nothing before a trial converts,
    /// so a reminder we genuinely schedule is worth naming once.
    ///
    /// A real date beats a duration: "free until 5 Sep" is checkable in a way
    /// that "14 days free" is not.
    private var trialChargeDateLine: String? {
        guard offerIncludesTrial,
              let trialDays,
              let end = Calendar.current.date(byAdding: .day, value: trialDays, to: .now) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "MMMd", options: 0, locale: .current
        )
        return "Free until \(formatter.string(from: end)). We'll remind you before it ends."
    }

    /// Same condition the paywall's timeline states. We ask for notification
    /// permission when the trial starts, not here, so the promise above is made
    /// before the user has had the chance to decline it.
    private var trialReminderCaveat: String? {
        trialChargeDateLine == nil ? nil : "Reminder needs notifications turned on."
    }

    private func trialBenefit(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(Theme.body(weight: .semibold))
                .frame(width: 24)
            Text(text)
                .font(Theme.body())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var trialSavingsText: String {
        let yearlyDollars = Int(costPerDay) * 365
        guard yearlyDollars > 0 else { return "Project the year ahead, not just the days behind" }
        return "Project the \(formatCurrency(yearlyDollars)) you'd keep over the next year"
    }

    /// The opt-out used to sit above the CTA at the same visual weight as the
    /// action we want, at the moment the user has the least reason to choose
    /// it. It now lives under the button as a quiet, un-underlined link behind
    /// one confirmation. The path stays fully available; it just stops being
    /// the default-looking one.
    @ViewBuilder
    private var skipTrialLink: some View {
        Button { showSkipTrialConfirm = true } label: {
            Text("Get started")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 2)
        }
        .disabled(trialInFlight)
    }

    /// Order here is deliberate, and it changed: the price used to be the least
    /// prominent thing on the screen. Two full-width cards (habit comparison,
    /// reminder) sat above a caption-sized 75%-opacity paragraph that opened
    /// with the price and then buried it in auto-renew boilerplate. That is the
    /// classic 3.1.2 rejection, and it also just reads badly.
    ///
    /// Now: the price is stated once, prominently, immediately above the button
    /// that charges it. The habit comparison keeps its card because it is the
    /// argument. The reminder drops to a caption because it is reassurance, not
    /// a headline, and three stacked cards was the reason this screen felt like
    /// it had no point of view.
    @ViewBuilder
    private var trialAboveButton: some View {
        VStack(spacing: Theme.Space.s) {
            if let habitLine = habitComparisonText {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(habitLine)
                        .font(Theme.subhead(weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
            }

            if let reassurance = trialChargeDateLine {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(trialReminderCaveat.map { "\(reassurance) \($0)" } ?? reassurance)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .font(Theme.caption())
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            if let priceHeadline = trialPriceHeadline {
                Text(priceHeadline)
                    .font(Theme.body(weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }

            if let trialError {
                Text(trialError)
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.72))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Auto-renew terms sit under the button, between the CTA and the legal
    /// footer, so the price above is not swallowed by the boilerplate.
    @ViewBuilder
    private var trialRenewalDisclosure: some View {
        if let renewal = trialRenewalText {
            disclosureLine(renewal)
        }
    }

    private func disclosureLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption())
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Space.s)
    }

    /// The tallest thing any step puts under its primary button: the offer
    /// step's auto-renew disclosure, opt-out link and legal footer. Laid out
    /// hidden on every step so the button itself never moves between taps.
    ///
    /// It is built from the real views and the real disclosure string rather
    /// than a reserved point height, so it cannot drift when the copy or the
    /// user's type size changes.
    private var subDockReserve: some View {
        VStack(spacing: Theme.Space.s) {
            VStack(spacing: Theme.Space.s) {
                disclosureLine(SubscriptionService.autoRenewDisclosure)
                skipTrialLink
            }
            legalFooter
        }
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Every step docks its primary button on the same pixel.
    ///
    /// The dock is bottom-anchored, so what sits *under* the button decides how
    /// high it floats. The offer step carries a disclosure, an opt-out link and
    /// the legal footer; the steps before it carried a 14pt spacer, which left
    /// their CTA roughly 90pt lower and moved the target out from under the
    /// thumb on the walk into the one tap that matters. The slot below the
    /// button is now `subDockReserve` on every step, with the real content laid
    /// over it.
    private func bottomBar<Above: View, Below: View>(
        primaryTitle: String,
        busy: Bool = false,
        showLegalFooter: Bool = false,
        @ViewBuilder above: () -> Above = { EmptyView() },
        @ViewBuilder below: () -> Below = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Theme.Space.s) {
            above()
            Button(action: { withAnimation { action() } }) {
                ZStack {
                    Text(primaryTitle)
                        .font(Theme.body(weight: .semibold))
                        .opacity(busy ? 0 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if busy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
            }
            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            .disabled(busy)

            ZStack(alignment: .top) {
                subDockReserve
                VStack(spacing: Theme.Space.s) {
                    below()
                    if showLegalFooter { legalFooter }
                }
            }
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 12) {
            Button { restorePurchasesFromOnboarding() } label: {
                Text(restoreInFlight ? "Restoring…" : "Restore")
            }
            .disabled(restoreInFlight)
            Text("·")
            Link("Terms", destination: PaywallLinks.standardEULA)
            Text("·")
            Link("Privacy", destination: PaywallLinks.privacyPolicy)
        }
        .font(Theme.caption())
        .foregroundStyle(.white.opacity(0.75))
        .tint(.white)
    }

    /// The last step, and the only place the app has ever asked for
    /// notifications on the free path.
    ///
    /// Every reminder we schedule is guarded by `NotificationService
    /// .isAuthorized`, and `persistSetup` used to hard-code `dailyReminderEnabled
    /// = false`, so the daily nudge, the milestone eve, the lapse nudge and the
    /// trial warning were all dead for anyone who never went looking in
    /// Settings. Asking here, after the offer is resolved, keeps the prompt off
    /// the paid decision and still lands while the user is set-up minded.
    private var remindersStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 150, height: 150)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 68, weight: .semibold))
            }
            VStack(spacing: Theme.Space.m) {
                Text("One nudge a day, if you want it.")
                    .font(Theme.display(40, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A reminder to log the day and water your bonsai, a note when a milestone is a day out, and a heads-up before a free trial converts. Nothing else, and you can turn it all off in Settings.")
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.s)
            }
            Spacer()
            bottomBar(
                primaryTitle: "Turn on reminders",
                busy: reminderRequestInFlight,
                below: { skipRemindersLink }
            ) { enableRemindersAndFinish() }
        }
        .onAppear { ConversionDiagnostics.record(.remindersStepReached) }
    }

    @ViewBuilder
    private var skipRemindersLink: some View {
        Button { completeOnboarding() } label: {
            Text("Not now")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 2)
        }
        .disabled(reminderRequestInFlight)
    }

    private func enableRemindersAndFinish() {
        guard !reminderRequestInFlight else { return }
        reminderRequestInFlight = true
        Task { @MainActor in
            let granted = await NotificationService.ensureAuthorized()
            reminderRequestInFlight = false
            dailyRemindersOptIn = granted
            ConversionDiagnostics.record(granted ? .remindersGranted : .remindersDeclined)
            if granted {
                let settings = SettingsService(context: context).current()
                let hour = settings.dailyReminderHour
                let committed = settings.madeCommitment
                let streak = SobrietyService.daysSinceStart(min(startDate, .now))
                // Home schedules the milestone and lapse nudges on its own once
                // the opt-in is stored; the daily one is the only reminder
                // nothing else creates.
                await NotificationService.scheduleDailyReminder(
                    hour: hour,
                    committed: committed,
                    streakDays: streak
                )
            }
            completeOnboarding()
        }
    }

    private func resolveTrialAndContinue() {
        guard !trialResolutionInFlight else { return }
        persistSetup()
        trialResolutionError = nil
        trialResolutionInFlight = true
        Task { @MainActor in
            defer { trialResolutionInFlight = false }
            #if canImport(RevenueCat)
            guard subscriptions.isConfigured else {
                trialResolutionError = "Bloom+ plans are temporarily unavailable. You can retry or start free."
                return
            }
            var resolution = await subscriptions.resolveOnboardingTrial()
            if resolution == .failed || resolution == .unavailable {
                // Give the network a beat. Retrying in the same runloop tick
                // against a flaky connection just reproduces the same failure,
                // and every failure here costs a trial offer at the highest
                // intent moment the app ever gets.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                resolution = await subscriptions.resolveOnboardingTrial()
            }
            switch resolution {
            case .eligible:
                offerIncludesTrial = true
                withAnimation { step = 3 }
            case .ineligible:
                // "Ineligible" is mostly "already used the trial on this Apple
                // ID", not "has nothing to buy". Dropping straight into
                // `finishOnboarding` here is what handed those users a paywall
                // sheet on Home a second after onboarding vanished: the offer
                // belongs in the flow, so show the same step without the trial
                // language. Only a real subscriber, or a store with no
                // purchasable plan, skips it.
                if subscriptions.isProSubscriber || subscriptions.directOfferPackage == nil {
                    finishOnboarding()
                } else {
                    offerIncludesTrial = false
                    withAnimation { step = 3 }
                }
            case .unavailable, .failed:
                trialResolutionError = "Bloom+ plans are temporarily unavailable. You can retry or start free."
            }
            #else
            finishOnboarding()
            #endif
        }
    }

    private func startOnboardingTrial() {
        #if canImport(RevenueCat)
        guard let package = subscriptions.directOfferPackage else {
            trialError = offerIncludesTrial
                ? "Couldn't load the trial plan. Please try again."
                : "Couldn't load the Bloom+ plan. Please try again."
            return
        }
        ConversionDiagnostics.record(.trialCTATapped)
        trialError = nil
        trialInFlight = true
        Task { @MainActor in
            defer { trialInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    ConversionDiagnostics.record(.purchaseSucceeded)
                    finishOnboarding()
                case .pending:
                    ConversionDiagnostics.record(.purchasePending)
                    finishOnboarding()
                case .cancelled:
                    ConversionDiagnostics.record(.purchaseCancelled)
                    trialError = "Trial start cancelled. Tap again when you're ready."
                }
            } catch {
                ConversionDiagnostics.record(.purchaseFailed)
                trialError = "Couldn't start your trial. Please try again."
            }
        }
        #else
        finishOnboarding()
        #endif
    }

    private func restorePurchasesFromOnboarding() {
        guard !restoreInFlight else { return }
        restoreInFlight = true
        Task { @MainActor in
            defer { restoreInFlight = false }
            await subscriptions.restorePurchases()
            if subscriptions.isProSubscriber { finishOnboarding() }
        }
    }

    private func persistSetup() {
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int(costPerDay * 100)
        settings.caloriesPerDay = Int(caloriesPerDay)
        settings.dailyReminderEnabled = dailyRemindersOptIn
        settings.madeCommitment = false
        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()
    }

    /// Every exit from the offer step lands here: purchased, skipped, or the
    /// store never answered. It no longer ends onboarding, it advances to the
    /// reminders step, which is what actually completes it.
    private func finishOnboarding() {
        guard step != 4 else { return }
        persistSetup()
        withAnimation { step = 4 }
    }

    private func completeOnboarding() {
        persistSetup()
        let settings = SettingsService(context: context).current()
        settings.hasCompletedOnboarding = true
        try? context.save()
        ConversionDiagnostics.record(.onboardingCompleted)

        if !didShowOnboardingTrial {
            AppGroup.defaults.set(true, forKey: AppGroup.postOnboardingPaywallKey)
        }
        WidgetSnapshotPump.push(context: context)
    }

    /// The closing argument, in the units the user set two screens ago: what a
    /// year of Bloom+ costs measured against what they were spending on
    /// alcohol. Never quotes an amount: the disclosure right below it carries
    /// the real localized price (3.1.2).
    private var habitComparisonText: String? {
        #if canImport(RevenueCat)
        guard let package = subscriptions.directOfferPackage else { return nil }
        return package.soberHabitComparisonSentence(costPerDayCents: Int(costPerDay * 100))
        #else
        return nil
        #endif
    }

    private var trialPriceHeadline: String? {
        #if canImport(RevenueCat)
        subscriptions.directTrialPriceHeadline
        #else
        nil
        #endif
    }

    private var trialRenewalText: String? {
        #if canImport(RevenueCat)
        subscriptions.directTrialRenewalDisclosure
        #else
        nil
        #endif
    }

    private var trialCTATitle: String {
        guard offerIncludesTrial else { return "Unlock Bloom+" }
        guard let trialDays else { return "Start my free trial" }
        return "Start my \(trialDays)-day free trial"
    }

    /// Nil until the store tells us how long the trial actually is.
    ///
    /// This used to fall back to a literal 7, which is the same bug that left
    /// "7 days free" on the paywall: the moment App Store Connect moves to 14
    /// days, a slow product load makes onboarding advertise an offer that no
    /// longer exists. Every piece of copy on this screen degrades to a
    /// length-free version instead of guessing.
    private var trialDays: Int? {
        #if canImport(RevenueCat)
        subscriptions.trialOfferDayCount
        #else
        nil
        #endif
    }

    private var trialHeadline: String {
        guard offerIncludesTrial else { return "Unlock Bloom+" }
        guard let trialDays else { return "Bloom+, free to try" }
        return "\(trialDays) days of Bloom+ free"
    }

    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
