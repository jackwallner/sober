import SwiftData
import SwiftUI

/// What happens the morning after.
///
/// The old flow was a destructive alert with a Reset button, which framed a
/// slip as data loss and gave the user a straightforward reason to lie to the
/// app or delete it. This sheet does the same bookkeeping while making the
/// three things that survive explicit and visible *before* the user commits:
/// the tree keeps most of its growth, the longest streak stands, and every
/// sober day ever logged is still counted.
struct SlipSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Current streak, passed in so the preview can name what the tree keeps
    /// without re-deriving it.
    let currentStreakDays: Int
    var onRecorded: () -> Void = {}

    @State private var day = DateHelpers.startOfDay()
    @State private var note = ""
    @State private var recorded: SlipRecorder.Outcome?

    private var earliestSelectable: Date {
        DateHelpers.daysAgo(max(0, currentStreakDays - 1))
    }

    /// What the tree will inherit if they log it. Computed from the same
    /// function that does the real work, so the promise and the behaviour
    /// cannot drift apart.
    private var previewCarryover: Int {
        let state = GardenService(context: context).current()
        let had = GardenService.treeDays(streakDays: currentStreakDays, carryover: state.carryoverDays)
        return min(364, Int(Double(had) * GardenService.slipCarryoverFraction))
    }

    var body: some View {
        NavigationStack {
            if let recorded {
                confirmation(recorded)
            } else {
                form
            }
        }
    }

    private var form: some View {
        List {
            Section {
                Text("It's okay. A slip is part of a lot of journeys, and logging it keeps the rest of your record honest.")
                    .font(Theme.body())
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.vertical, Theme.Space.xs)
            }

            Section("When") {
                DatePicker(
                    "Day",
                    selection: $day,
                    in: earliestSelectable...DateHelpers.startOfDay(),
                    displayedComponents: .date
                )
            }

            Section("Anything you want to remember") {
                TextField("What was going on?", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                keepRow("leaf.fill", "Your tree keeps \(previewCarryover) day\(previewCarryover == 1 ? "" : "s") of growth")
                keepRow("flag.fill", "Your longest streak still stands")
                keepRow("calendar", "Every sober day you've logged still counts")
            } header: {
                Text("What you keep")
            } footer: {
                Text("Your day counter restarts the day after the slip, so the days since then are still counted.")
            }

            Section {
                Button {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    recorded = SlipRecorder.record(
                        on: day,
                        note: trimmed.isEmpty ? nil : trimmed,
                        context: context
                    )
                    onRecorded()
                } label: {
                    Text("Log it and keep going")
                        .font(Theme.body(weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(Theme.brandPrimary)
            }
        }
        .listStyle(.insetGrouped)
        .themedScrollBackground()
        .navigationTitle("Log a slip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func keepRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 28)
            Text(text)
                .font(Theme.subhead())
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func confirmation(_ outcome: SlipRecorder.Outcome) -> some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.brandPrimary)
            Text("Logged. You're still on the journey.")
                .font(Theme.title())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(outcome.carryoverDays > 0
                 ? "Your counter starts again, but your tree kept \(outcome.carryoverDays) day\(outcome.carryoverDays == 1 ? "" : "s") of growth from the \(outcome.previousStreakDays)-day run behind it."
                 : "Your counter starts again. Everything you've logged is still counted.")
                .font(Theme.body())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(Theme.body(weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
