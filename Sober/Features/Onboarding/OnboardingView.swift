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
                default: welcome
                }
            }
            .padding()
            .foregroundStyle(.white)
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
            Text("Sober").font(.system(size: 56, weight: .bold, design: .rounded))
            Text("Track your sobriety, grow your garden, watch your health return.")
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.horizontal)
            Spacer()
            Button("Get Started") { withAnimation { step = 1 } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white.opacity(0.25))
                .padding(.bottom, 40)
        }
    }

    private var startDateStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("When did your sober journey begin?")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            Spacer()
            primaryButton("Continue") { step = 2 }
        }
    }

    private var spendStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How much did you typically spend per day?")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
            VStack {
                Text("$\(Int(costPerDay)) / day").font(.largeTitle.bold())
                Slider(value: $costPerDay, in: 0...200, step: 5)
            }
            Text("Calories per day:")
                .padding(.top)
            VStack {
                Text("\(Int(caloriesPerDay)) cal").font(.title2.bold())
                Slider(value: $caloriesPerDay, in: 0...3000, step: 50)
            }
            Spacer()
            primaryButton("Continue") { step = 3 }
        }
    }

    private var reminderStep: some View {
        VStack(spacing: 24) {
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
            primaryButton("Start My Journey") { complete() }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 40)
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

        _ = SobrietyService(context: context).startJourney(at: DateHelpers.startOfDay(startDate))
        _ = GardenService(context: context).current()
        try? context.save()

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour)
        }
        WidgetSnapshotPump.push(context: context)
    }
}
