import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions

    @State private var step = 0
    @State private var startDate: Date = .now
    @State private var costPerDay: Double = 20
    @State private var caloriesPerDay: Double = 600
    @State private var trialInFlight = false
    @State private var trialResolutionInFlight = false
    @State private var trialResolutionError: String?
    @State private var trialError: String?
    @State private var restoreInFlight = false
    @State private var didShowOnboardingTrial = false

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            Group {
                switch step {
                case 0: promiseStep
                case 1: startDateStep
                case 2: savingsStep
                case 3: trialStep
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
                Button("Continue with the free version") { finishOnboarding() }
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(.white)
                    .underline()
            }
        }
    }

    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .semibold))
            VStack(spacing: Theme.Space.s) {
                Text("\(trialDays) days of Bloom+ free")
                    .font(Theme.display(42, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Try every tool that helps you keep the streak visible. Pay nothing today.")
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.Space.m) {
                trialBenefit(icon: "tree.fill", text: "Grow and switch every bonsai species")
                trialBenefit(icon: "heart.text.square.fill", text: "Follow 13 sourced recovery milestones")
                trialBenefit(icon: "dollarsign.circle.fill", text: trialSavingsText)
                trialBenefit(icon: "book.closed.fill", text: "Journal privately through difficult moments")
            }
            .padding(Theme.Space.m)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: Theme.Space.s)
            bottomBar(
                primaryTitle: trialCTATitle,
                busy: trialInFlight,
                showLegalFooter: true,
                above: { trialAboveButton }
            ) { startOnboardingTrial() }
        }
        .onAppear {
            didShowOnboardingTrial = true
            ConversionDiagnostics.record(.trialOfferReached)
            #if canImport(RevenueCat)
            subscriptions.trackPaywallImpression(
                id: "sober_onboarding_trial_1_2_2",
                package: subscriptions.directTrialPackage,
                oncePerSession: true
            )
            #endif
            TrialNudgeGate.markShown()
        }
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
        guard yearlyDollars > 0 else { return "Track money and calories retained" }
        return "See your progress toward keeping \(formatCurrency(yearlyDollars)) this year"
    }

    @ViewBuilder
    private var trialAboveButton: some View {
        VStack(spacing: Theme.Space.s) {
            Button {
                ConversionDiagnostics.record(.freeVersionChosen)
                finishOnboarding()
            } label: {
                Text("Continue with the free version")
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .underline()
                    .padding(.vertical, 4)
            }
            .disabled(trialInFlight)

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
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.72))
                    .multilineTextAlignment(.center)
            }
        }
    }

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
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if busy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
            }
            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            .disabled(busy)

            if showLegalFooter {
                legalFooter
            } else {
                Color.clear
                    .frame(height: 14)
                    .accessibilityHidden(true)
            }
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 12) {
            Button { restorePurchasesFromOnboarding() } label: {
                Text(restoreInFlight ? "Restoring…" : "Restore")
                    .underline()
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
                resolution = await subscriptions.resolveOnboardingTrial()
            }
            switch resolution {
            case .eligible:
                withAnimation { step = 3 }
            case .ineligible:
                finishOnboarding()
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
        guard let package = subscriptions.directTrialPackage else {
            trialError = "Couldn't load the trial plan. Please try again."
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
        settings.dailyReminderEnabled = false
        settings.madeCommitment = false
        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()
    }

    private func finishOnboarding() {
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

    private var trialDisclosureText: String? {
        #if canImport(RevenueCat)
        subscriptions.directTrialCTADisclosureText
        #else
        nil
        #endif
    }

    private var trialCTATitle: String {
        "Start my \(trialDays)-day free trial"
    }

    private var trialDays: Int {
        #if canImport(RevenueCat)
        subscriptions.trialOfferDayCount ?? 7
        #else
        7
        #endif
    }

    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
