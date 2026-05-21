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
            List {
                Section("Prompt of the day") {
                    promptRow
                }

                Section("Entries") {
                    if entries.isEmpty {
                        Text("No entries yet. Use the pencil to write your first.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, Theme.Space.s)
                    } else {
                        ForEach(entries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if subscriptions.isProSubscriber { showCompose = true }
                        else { showPaywall = true }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New entry")
                }
            }
            .sheet(isPresented: $showCompose) { ComposeEntrySheet() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var promptRow: some View {
        let prompt = JournalPromptCatalog.promptOfDay()
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(prompt.text)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if subscriptions.isProSubscriber { showCompose = true }
                else { showPaywall = true }
            } label: {
                Label("Write entry", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .tint(Theme.brandPrimary)
            .padding(.top, 2)
        }
        .padding(.vertical, Theme.Space.xs)
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(DateHelpers.mediumDate(entry.createdAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let feeling = entry.feeling {
                    Text(feeling.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.brandPrimary)
                }
            }
            Text(entry.text)
                .font(.body)
                .lineLimit(4)
        }
        .padding(.vertical, Theme.Space.xs)
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
