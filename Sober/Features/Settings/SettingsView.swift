import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionService.self) private var subscriptions
    @Query private var settingsRows: [UserSettings]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @State private var restoreMessage: String?
    @State private var isRestoring = false
    @State private var notificationsDenied = false

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
                            Button("Upgrade") { TrialOfferCoordinator.shared.request(.settings, policy: .explicitUpgrade) }
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
                                    ?? String(localized: "No active Bloom+ purchase found for this Apple ID.")
                            }
                        }
                    }
                    .disabled(isRestoring)
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(Theme.caption())
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
                    Section("Goal") {
                        NavigationLink {
                            GoalEditorView()
                        } label: {
                            HStack {
                                Text("Working toward")
                                Spacer()
                                Text(journey.goalDate.map { GoalProjection.shortDate($0) } ?? String(localized: "No goal"))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
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
                    Section {
                        Toggle("Enabled", isOn: bind(\.dailyReminderEnabled, on: s))
                        Stepper("Hour: \(CravingInsights.hourLabel(s.dailyReminderHour))", value: bind(\.dailyReminderHour, on: s), in: 0...23)
                        if s.dailyReminderEnabled && notificationsDenied {
                            Button {
                                openNotificationSettings()
                            } label: {
                                Label("Allow notifications in Settings", systemImage: "bell.slash.fill")
                            }
                        }
                    } header: {
                        Text("Daily Reminder")
                    } footer: {
                        if s.dailyReminderEnabled && notificationsDenied {
                            Text("Notifications are turned off for Sober, so the reminder can't be delivered. Tap above to enable them in the Settings app.")
                        }
                    }
                    Section {
                        Stepper(value: bind(\.costPerDayCents, on: s), in: 0...20000, step: 100) {
                            HStack {
                                Text("Cost per day")
                                Spacer()
                                Text(Double(s.costPerDayCents / 100).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0))))
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
                                 title: String(localized: "988 Suicide & Crisis Lifeline"),
                                 subtitle: String(localized: "Call or text 988 · 24/7 · US"))
                    resourceLink(url: "tel:18006624357",
                                 icon: "cross.case.fill",
                                 title: String(localized: "SAMHSA National Helpline"),
                                 subtitle: String(localized: "1-800-662-HELP · Free, confidential, 24/7"))
                    resourceLink(url: "https://findtreatment.gov",
                                 icon: "magnifyingglass",
                                 title: String(localized: "Find Treatment"),
                                 subtitle: "findtreatment.gov")
                } header: {
                    Text("If you need support")
                } footer: {
                    Text("Free, confidential help is available any time. Reaching out is a strength, not a setback.")
                }
                Section("Help") {
                    // One mail row for questions, ideas and problems, and a
                    // separate review row. No "Enjoying it?" gate in front of
                    // either (App Review 5.6.1).
                    resourceLink(url: "mailto:jackwallner+st@gmail.com?subject=Sober%20feedback",
                                 icon: "envelope.fill",
                                 title: String(localized: "Send Feedback"),
                                 subtitle: String(localized: "Questions, ideas, or trouble? Reach out."))
                    Button {
                        ReviewPromptTracker.markOpenedWriteReview()
                        UIApplication.shared.open(AppStoreReviewLinks.writeReviewURL)
                    } label: {
                        helpRow(icon: "star.fill", title: String(localized: "Rate Sober"), subtitle: String(localized: "On the App Store"))
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
            .onChange(of: settings?.dailyReminderHour) { _, _ in rescheduleReminder() }
            .onChange(of: settings?.dailyReminderEnabled) { _, _ in rescheduleReminder() }
            .onChange(of: settings?.madeCommitment) { _, _ in rescheduleReminder() }
            .task { await refreshNotificationStatus() }
            // Re-check when the user comes back from the Settings app so the
            // warning clears the moment they've granted permission.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshNotificationStatus() }
                }
            }
        }
    }

    private func refreshNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsDenied = (status == .denied)
    }

    private func openNotificationSettings() {
        let urlString = UIApplication.openNotificationSettingsURLString
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func helpRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Theme.body())
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
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
                        .font(Theme.body())
                        .foregroundStyle(Theme.brandPrimary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .foregroundStyle(Theme.textPrimary)
                        Text(subtitle)
                            .font(Theme.caption())
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
                // Keep the calendar in lockstep with the counter: backfill
                // sober check-ins for the (possibly earlier) journey range the
                // same way HomeView.onAppear does. Without this, an edited
                // start date desyncs the two until the next cold launch.
                CheckInService(context: context).fillJourney(
                    start: journey.startDate,
                    through: DateHelpers.daysAgo(1)
                )
                WidgetSnapshotPump.push(context: context)
            }
        )
    }

    private func bind<Value>(_ keyPath: ReferenceWritableKeyPath<UserSettings, Value>, on s: UserSettings) -> Binding<Value> {
        Binding(
            get: { s[keyPath: keyPath] },
            set: {
                s[keyPath: keyPath] = $0
                context.saveOrReport()
            }
        )
    }

    private func rescheduleReminder() {
        guard let s = settings else { return }
        let hour = s.dailyReminderHour
        let enabled = s.dailyReminderEnabled
        let committed = s.madeCommitment
        let streak = activeJourney.map { SobrietyService.daysSinceStart($0.startDate) } ?? 0
        Task {
            if enabled {
                // Turning the toggle on is the user asking for notifications,
                // so this is where we're allowed to raise the system prompt.
                // Everything else only schedules when permission already exists.
                await NotificationService.ensureAuthorized()
                await NotificationService.scheduleDailyReminder(hour: hour, committed: committed, streakDays: streak)
                if let next = AchievementCatalog.nextTimeMilestone(after: streak) {
                    await NotificationService.scheduleMilestoneEve(
                        currentDays: streak,
                        milestoneDays: next.dayThreshold,
                        milestoneTitle: next.title,
                        hour: hour
                    )
                }
                await NotificationService.scheduleLapseNudge(streakDays: streak)
            } else {
                await NotificationService.cancelDailyReminder()
                // Milestone/lapse nudges ride on this opt-in, so turning reminders
                // off has to silence everything, not just the daily one.
                NotificationService.cancelRetentionNudges()
            }
        }
    }
}
