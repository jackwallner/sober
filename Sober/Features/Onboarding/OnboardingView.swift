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
                .font(.system(size: 80))
            Text("Sober").font(.system(size: 56, weight: .bold, design: .rounded))
            Text("Track your sobriety, grow your garden, watch your health return.")
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.horizontal, Theme.Space.l)
            Spacer()
            primaryButton("Get Started") { step = 1 }
        }
    }

    private var startDateStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("When did your sober journey begin?")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
            Spacer()
            primaryButton("Continue") { step = 2 }
        }
    }

    private var spendStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Text("How much did you typically spend per day?")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.Space.s) {
                Text("$\(Int(costPerDay)) / day").font(.largeTitle.bold())
                Slider(value: $costPerDay, in: 0...200, step: 5)
            }
            VStack(spacing: Theme.Space.s) {
                Text("Calories per day").font(.caption).foregroundStyle(.white.opacity(0.85))
                Text("\(Int(caloriesPerDay)) cal").font(.title2.bold())
                Slider(value: $caloriesPerDay, in: 0...3000, step: 50)
            }
            savingsProjection
            Spacer(minLength: Theme.Space.s)
            primaryButton("Continue") { step = 3 }
        }
    }

    private var savingsProjection: some View {
        let yearlyDollars = Int(costPerDay * 365)
        let yearlyCalories = Int(caloriesPerDay * 365)
        let yearlyPounds = Double(yearlyCalories) / 3500.0  // ~3,500 kcal per lb of fat
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        let dollarStr = f.string(from: NSNumber(value: yearlyDollars)) ?? "$\(yearlyDollars)"
        return VStack(spacing: 4) {
            Text("In a year, that's")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(dollarStr)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("plus \(yearlyCalories.formatted()) calories — about \(yearlyPounds.formatted(.number.precision(.fractionLength(0)))) lb of fat — you won't have to spend")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.m)
        .padding(.horizontal, Theme.Space.m)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private var reminderStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("Daily reminder time")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            Picker("Hour", selection: $reminderHour) {
                ForEach(0..<24) { h in
                    Text(formatHour(h)).tag(h)
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
    /// gives them a moment to lock in before the journey begins.
    private var commitStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .opacity(0.92)
            Text("Make it official")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Recovery starts with a decision. This is yours — for today, and the days that follow.")
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, Theme.Space.l)
            Spacer()
            primaryButton("I commit to getting better") { complete() }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.m)
        }
        .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h
        let d = Calendar.current.date(from: comps) ?? .now
        return f.string(from: d)
    }

    private func complete() {
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int(costPerDay * 100)
        settings.caloriesPerDay = Int(caloriesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.hasCompletedOnboarding = true

        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour)
        }
        WidgetSnapshotPump.push(context: context)
    }
}
