import SwiftData
import SwiftUI

/// What the goal question resolves to, shared by onboarding and Settings.
enum GoalChoice: Hashable {
    case preset(GoalPreset)
    case custom
    case none

    /// The stored date for this choice, or nil for no goal.
    func resolvedDate(start: Date, customDate: Date) -> Date? {
        switch self {
        case .preset(let preset): preset.date(from: start)
        case .custom: DateHelpers.startOfDay(customDate)
        case .none: nil
        }
    }

    /// The choice a stored goal reads back as.
    static func from(goal: Date?, start: Date) -> GoalChoice {
        guard let goal else { return .none }
        return GoalPreset.matching(goal: goal, start: start).map(GoalChoice.preset) ?? .custom
    }

    /// Earliest date the custom picker allows: tomorrow.
    static var earliestCustomDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay()) ?? .now
    }
}

/// Edits the active journey's goal. Changes apply as they are made, like every
/// other row in Settings, so there is no Save to forget.
struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]

    @State private var choice: GoalChoice = .none
    @State private var customDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var loaded = false

    private var journey: SobrietyJourney? { journeys.first { $0.isActive } }
    private var start: Date { journey?.startDate ?? .now }

    var body: some View {
        Form {
            Section {
                ForEach(GoalPreset.allCases.filter { $0.isAhead(start: start) }) { preset in
                    choiceRow(.preset(preset), title: preset.label, detail: GoalProjection.shortDate(preset.date(from: start)))
                }
                choiceRow(.custom, title: String(localized: "Pick a date"), detail: nil)
                if choice == .custom {
                    DatePicker("Goal date", selection: $customDate, in: GoalChoice.earliestCustomDate..., displayedComponents: [.date])
                }
                choiceRow(.none, title: String(localized: "No goal yet"), detail: nil)
            } footer: {
                Text("Home counts down to it. Bloom+ shows what you'll have kept and which milestones you'll have passed by then.")
            }
        }
        .themedScrollBackground()
        .navigationTitle("Your goal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: choice) { _, _ in save() }
        .onChange(of: customDate) { _, _ in if choice == .custom { save() } }
    }

    private func choiceRow(_ value: GoalChoice, title: String, detail: String?) -> some View {
        Button { choice = value } label: {
            HStack {
                Text(title).foregroundStyle(Theme.textPrimary)
                Spacer()
                if let detail {
                    Text(detail).foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "checkmark")
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(Theme.brandPrimary)
                    .opacity(choice == value ? 1 : 0)
            }
        }
        .accessibilityAddTraits(choice == value ? .isSelected : [])
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let goal = journey?.goalDate
        choice = GoalChoice.from(goal: goal, start: start)
        if case .custom = choice, let goal { customDate = goal }
    }

    private func save() {
        guard loaded else { return }
        SobrietyService(context: context).setGoal(choice.resolvedDate(start: start, customDate: customDate))
    }
}
