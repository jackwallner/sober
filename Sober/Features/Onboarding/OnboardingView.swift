import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step: Int = 0
    @State private var startDate: Date = .now
    @State private var costPerDay: Double = 20
    @State private var caloriesPerDay: Double = 600
    @State private var reminderHour: Int = 9

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
                default: welcome
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.l)
            .foregroundStyle(.white)
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
                .font(.title2)
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            primaryButton("Get Started") { step = 1 }
        }
    }

    private var startDateStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("When did your sober journey begin?")
                .font(Theme.display(34))
                .multilineTextAlignment(.center)
            DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.white)
            Spacer()
            primaryButton("Continue") { step = 2 }
        }
    }

    private var spendStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Text("How much did you typically spend per day?")
                .font(Theme.display(34))
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.Space.s) {
                Text("$\(Int(costPerDay)) / day")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Slider(value: $costPerDay, in: 0...200, step: 5)
                    .tint(.white)
            }
            VStack(spacing: Theme.Space.s) {
                Text("Calories per day")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(Int(caloriesPerDay)) cal")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Slider(value: $caloriesPerDay, in: 0...3000, step: 50)
                    .tint(.white)
            }
            savingsProjection
            Spacer(minLength: Theme.Space.s)
            primaryButton("Continue") { step = 3 }
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
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                if dollars > 0 {
                    Text(formatCurrency(yearlyDollars))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }
                if calories > 0 {
                    Text(dollars > 0
                         ? "plus \(yearlyCalories.formatted()) calories you won't have to spend. About \(yearlyPounds.formatted(.number.precision(.fractionLength(0)))) lb of body fat."
                         : "\(yearlyCalories.formatted()) calories you won't have to spend — about \(yearlyPounds.formatted(.number.precision(.fractionLength(0)))) lb of body fat.")
                        .font(.footnote)
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
                .font(Theme.display(34))
                .multilineTextAlignment(.center)
            Picker("Hour", selection: $reminderHour) {
                ForEach(0..<24) { h in
                    Text(formatHour(h)).font(.title2).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)
            Spacer()
            primaryButton("Continue") { step = 4 }
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
                .font(Theme.display(34))
                .multilineTextAlignment(.center)
            Text("Recovery starts with a decision. This is yours, for today and the days that follow.")
                .multilineTextAlignment(.center)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            VStack(spacing: Theme.Space.s) {
                primaryButton("I commit to getting better") { complete(committed: true) }
                Button { complete(committed: false) } label: {
                    Text("Not now")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .underline()
                        .padding(.vertical, 6)
                }
                Text("Either way is fine. You can revisit this any time in Settings.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Space.m)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
        }
        .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
    }

    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h
        let d = Calendar.current.date(from: comps) ?? .now
        return f.string(from: d)
    }

    private func complete(committed: Bool = true) {
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int(costPerDay * 100)
        settings.caloriesPerDay = Int(caloriesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.hasCompletedOnboarding = true
        settings.madeCommitment = committed

        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour, committed: committed)
        }
        WidgetSnapshotPump.push(context: context)
    }
}
