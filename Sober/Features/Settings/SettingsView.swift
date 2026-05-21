import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query private var settingsRows: [UserSettings]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @State private var showPaywall = false

    private var settings: UserSettings? { settingsRows.first }
    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bloom+") {
                    HStack {
                        Image(systemName: subscriptions.isProSubscriber ? "crown.fill" : "crown")
                        Text(subscriptions.isProSubscriber ? "Bloom+ active" : "Bloom+")
                        Spacer()
                        if !subscriptions.isProSubscriber {
                            Button("Upgrade") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                if let journey = activeJourney {
                    Section {
                        DatePicker(
                            "Start",
                            selection: startDateBinding(journey),
                            in: ...Date.now,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    } header: {
                        Text("Sobriety Start")
                    } footer: {
                        Text("Adjust the exact date and time your journey began. Hour-level accuracy keeps early health milestones precise.")
                    }
                }
                if let s = settings {
                    Section("Appearance") {
                        Picker("Theme", selection: bind(\.appearancePreferenceRaw, on: s)) {
                            ForEach(AppearancePreference.allCases) { pref in
                                Text(pref.label).tag(pref.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Daily Reminder") {
                        Toggle("Enabled", isOn: bind(\.dailyReminderEnabled, on: s))
                        Stepper("Hour: \(s.dailyReminderHour):00", value: bind(\.dailyReminderHour, on: s), in: 0...23)
                    }
                    Section {
                        Stepper(value: bind(\.costPerDayCents, on: s), in: 0...20000, step: 100) {
                            HStack {
                                Text("Cost per day")
                                Spacer()
                                Text("$\(s.costPerDayCents / 100)")
                                    .foregroundStyle(Theme.textSecondary)
                                    .monospacedDigit()
                            }
                        }
                        Stepper(value: bind(\.caloriesPerDay, on: s), in: 0...3000, step: 50) {
                            HStack {
                                Text("Calories per day")
                                Spacer()
                                Text("\(s.caloriesPerDay) cal")
                                    .foregroundStyle(Theme.textSecondary)
                                    .monospacedDigit()
                            }
                        }
                    } header: {
                        Text("Cost & Calories")
                    } footer: {
                        Text("Used to estimate money and calories saved while you stay sober.")
                    }
                }
                Section("Developer") {
                    Button(subscriptions.isProSubscriber ? "Disable Bloom+ override" : "Enable Bloom+ override") {
                        subscriptions.setLocalOverride(isPro: !subscriptions.isProSubscriber)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onChange(of: settings?.dailyReminderHour) { _, _ in rescheduleReminder() }
            .onChange(of: settings?.dailyReminderEnabled) { _, _ in rescheduleReminder() }
        }
    }

    private func startDateBinding(_ journey: SobrietyJourney) -> Binding<Date> {
        Binding(
            get: { journey.startDate },
            set: {
                SobrietyService(context: context).updateStartDate($0)
                WidgetSnapshotPump.push(context: context)
            }
        )
    }

    private func bind<Value>(_ keyPath: ReferenceWritableKeyPath<UserSettings, Value>, on s: UserSettings) -> Binding<Value> {
        Binding(
            get: { s[keyPath: keyPath] },
            set: {
                s[keyPath: keyPath] = $0
                try? context.save()
            }
        )
    }

    private func rescheduleReminder() {
        guard let s = settings else { return }
        Task {
            if s.dailyReminderEnabled {
                await NotificationService.scheduleDailyReminder(hour: s.dailyReminderHour)
            } else {
                await NotificationService.cancelDailyReminder()
            }
        }
    }
}
