import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var showCompose = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    promptCard
                    ForEach(entries) { entry in
                        EntryRow(entry: entry)
                    }
                    if entries.isEmpty {
                        Text("No journal entries yet.")
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 24)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if subscriptions.isProSubscriber { showCompose = true }
                        else { showPaywall = true }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showCompose) { ComposeEntrySheet() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var promptCard: some View {
        let prompt = JournalPromptCatalog.promptOfDay()
        return VStack(alignment: .leading, spacing: 8) {
            Label("Prompt of the Day", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandPrimary)
            Text(prompt.text)
                .font(.title3.weight(.medium))
            Button {
                if subscriptions.isProSubscriber { showCompose = true }
                else { showPaywall = true }
            } label: {
                Label("New Entry", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandPrimary)
        }
        .padding()
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateHelpers.mediumDate(entry.createdAt))
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                if let feeling = entry.feeling {
                    Text(feeling).font(.caption.bold()).foregroundStyle(Theme.brandPrimary)
                }
            }
            Text(entry.text)
                .font(.body)
                .lineLimit(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

private struct ComposeEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var feeling: String = "good"

    var body: some View {
        NavigationStack {
            Form {
                let prompt = JournalPromptCatalog.promptOfDay()
                Section(prompt.text) {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                }
                Section("Feeling") {
                    Picker("Feeling", selection: $feeling) {
                        ForEach(["excellent", "good", "neutral", "tough", "rough"], id: \.self) {
                            Text($0.capitalized).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let prompt = JournalPromptCatalog.promptOfDay()
                        let entry = JournalEntry(promptID: prompt.id, kind: prompt.kind, text: text, feeling: feeling)
                        context.insert(entry)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
