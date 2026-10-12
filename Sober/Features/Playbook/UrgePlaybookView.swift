import SwiftUI

/// Bloom+: every trigger plan, one tap from Home or the end of a session.
struct UrgePlaybookView: View {
    @Environment(\.dismiss) private var dismiss
    /// Opens straight onto one plan when the user came from a session that
    /// named its trigger.
    var initialTrigger: UrgeTrigger?

    @State private var path: [UrgeTrigger] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(UrgePlaybookCatalog.all) { plan in
                        NavigationLink(value: plan.trigger) { planRow(plan) }
                    }
                } footer: {
                    Text("Ideas that help many people, not medical advice. If you need support, Settings lists free, confidential helplines.")
                }
            }
            .listStyle(.insetGrouped)
            .themedScrollBackground()
            .navigationTitle("Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UrgeTrigger.self) { trigger in
                UrgePlanView(plan: UrgePlaybookCatalog.plan(for: trigger))
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if let initialTrigger, path.isEmpty { path = [initialTrigger] }
        }
    }

    private func planRow(_ plan: UrgePlan) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: plan.icon)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(Theme.body(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(plan.situation)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One plan: numbered steps, then the line to say.
struct UrgePlanView: View {
    let plan: UrgePlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(plan.title)
                        .font(Theme.title())
                        .foregroundStyle(Theme.textPrimary)
                    Text(plan.situation)
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                            Text("\(index + 1)")
                                .font(Theme.subhead(weight: .bold))
                                .foregroundStyle(Theme.brandPrimary)
                                .frame(width: 20, alignment: .leading)
                            Text(step)
                                .font(Theme.body())
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ringTrack, lineWidth: 1))

                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(UrgePlaybookCatalog.scriptHeading.uppercased())
                        .font(Theme.caption(weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.brandPrimary)
                    Text("\u{201C}\(plan.script)\u{201D}")
                        .font(Theme.heading(weight: .medium).italic())
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("No reason owed. Say it once and change the subject.")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.brandPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
