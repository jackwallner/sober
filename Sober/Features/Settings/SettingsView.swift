import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query private var settingsRows: [UserSettings]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @State private var showPaywall = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false

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
                    Button(isRestoring ? "Restoring…" : "Restore Purchases") {
                        restoreMessage = nil
                        isRestoring = true
                        Task {
                            defer { isRestoring = false }
                            await subscriptions.restorePurchases()
                            if !subscriptions.isProSubscriber {
                                restoreMessage = subscriptions.lastError
                                    ?? "No active Bloom+ purchase found for this Apple ID."
                            }
                        }
                    }
                    .disabled(isRestoring)
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let journey = activeJourney {
                    Section {
                        DatePicker(
                            "Start",
                            selection: startDateBinding(journey),
                            in: ...Date.now,
                            displayedComponents: [.date]
                        )
                    } header: {
                        Text("Sobriety Start")
                    } footer: {
                        Text("Adjust the date your journey began.")
                    }
                }
                if let s = settings {
                    Section {
                        Toggle("I'm committing to this", isOn: bind(\.madeCommitment, on: s))
                    } header: {
                        Text("Your pledge")
                    } footer: {
                        Text(s.madeCommitment
                             ? "Reminders are framed around your pledge."
                             : "Reminders stay neutral and pressure-free.")
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
                Section {
                    resourceLink(url: "tel:988",
                                 icon: "phone.fill",
                                 title: "988 Suicide & Crisis Lifeline",
                                 subtitle: "Call or text 988 · 24/7 · US")
                    resourceLink(url: "tel:18006624357",
                                 icon: "cross.case.fill",
                                 title: "SAMHSA National Helpline",
                                 subtitle: "1-800-662-HELP · Free, confidential, 24/7")
                    resourceLink(url: "https://findtreatment.gov",
                                 icon: "magnifyingglass",
                                 title: "Find Treatment",
                                 subtitle: "findtreatment.gov")
                } header: {
                    Text("If you need support")
                } footer: {
                    Text("Free, confidential help is available any time. Reaching out is a strength, not a setback.")
                }
                Section("Help") {
                    resourceLink(url: "tel:4257533411",
                                 icon: "bubble.left.and.text.bubble.right.fill",
                                 title: "Contact Support",
                                 subtitle: "Questions or trouble? Reach out.")
                    Button("Rate or Send Feedback") {
                        ReviewPromptCoordinator.shared.requestEnjoymentPrompt()
                    }
                }
                Section("Legal") {
                    Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
                    Link("Terms of Use (EULA)", destination: PaywallLinks.standardEULA)
                }
                #if DEBUG
                Section("Developer") {
                    Button(subscriptions.isProSubscriber ? "Disable Bloom+ override" : "Enable Bloom+ override") {
                        subscriptions.setLocalOverride(isPro: !subscriptions.isProSubscriber)
                    }
                }
                #endif
            }
            .themedScrollBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView(impressionId: "sober_settings_sheet")
            }
            .onChange(of: settings?.dailyReminderHour) { _, _ in rescheduleReminder() }
            .onChange(of: settings?.dailyReminderEnabled) { _, _ in rescheduleReminder() }
            .onChange(of: settings?.madeCommitment) { _, _ in rescheduleReminder() }
        }
    }

    /// A Form row that deep-links to a phone/web resource. Skips rendering if the
    /// URL is somehow malformed so a bad string can never crash the screen.
    @ViewBuilder
    private func resourceLink(url: String, icon: String, title: String, subtitle: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Theme.brandPrimary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .foregroundStyle(Theme.textPrimary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(title). \(subtitle)"))
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
        let hour = s.dailyReminderHour
        let enabled = s.dailyReminderEnabled
        let committed = s.madeCommitment
        Task {
            if enabled {
                await NotificationService.scheduleDailyReminder(hour: hour, committed: committed)
            } else {
                await NotificationService.cancelDailyReminder()
            }
        }
    }
}
