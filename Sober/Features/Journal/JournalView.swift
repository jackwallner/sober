import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var showCompose = false
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        NavigationStack {
            List {
                Section("Prompt of the day") {
                    promptRow
                }

                Section("Entries") {
                    if entries.isEmpty {
                        Text("No entries yet. Use the pencil to write your first.")
                            .font(Theme.subhead())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, Theme.Space.s)
                    } else {
                        ForEach(entries) { entry in
                            EntryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedEntry = entry }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .themedScrollBackground()
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if subscriptions.isProSubscriber { showCompose = true }
                        else { TrialOfferCoordinator.shared.request(.journal) }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New entry")
                }
            }
            .sheet(isPresented: $showCompose) { ComposeEntrySheet() }
            .sheet(item: $selectedEntry) { entry in
                JournalEntryDetailSheet(entry: entry)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
        try? context.save()
    }

    private var promptRow: some View {
        let prompt = JournalPromptCatalog.promptOfDay()
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(prompt.text)
                .font(Theme.body())
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if subscriptions.isProSubscriber { showCompose = true }
                else { TrialOfferCoordinator.shared.request(.journal) }
            } label: {
                Label("Write entry", systemImage: "square.and.pencil")
                    .font(Theme.subhead(weight: .semibold))
            }
            .buttonStyle(.borderless)
            .tint(Theme.brandPrimary)
            .padding(.top, 2)
        }
        .padding(.vertical, Theme.Space.xs)
    }
}

private struct JournalEntryDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: JournalEntry

    private var promptText: String? {
        guard let id = entry.promptID else { return nil }
        return JournalPromptCatalog.prompt(id: id)?.text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    HStack {
                        Text(DateHelpers.mediumDate(entry.createdAt))
                            .font(Theme.caption(weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if let feeling = entry.feeling {
                            Text(feeling.capitalized)
                                .font(Theme.caption(weight: .semibold))
                                .foregroundStyle(Theme.brandPrimary)
                        }
                    }

                    if let prompt = promptText {
                        Text(prompt)
                            .font(Theme.subhead(weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text(entry.text)
                        .font(Theme.body())
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.background)
            .navigationTitle(entry.kind == .freeform ? "Free Write" : "Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        context.delete(entry)
                        try? context.save()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete entry")
                }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(DateHelpers.mediumDate(entry.createdAt))
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let feeling = entry.feeling {
                    Text(feeling.capitalized)
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)
                }
            }
            Text(entry.text)
                .font(Theme.body())
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
    @State private var freeWrite: Bool = false
    @State private var prompt: JournalPrompt = JournalPromptCatalog.promptOfDay()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Free write", isOn: $freeWrite)
                    if !freeWrite {
                        Button {
                            // Avoid landing on the same prompt twice in a row.
                            prompt = JournalPromptCatalog.all.filter { $0.id != prompt.id }.randomElement() ?? prompt
                        } label: {
                            Label("Shuffle prompt", systemImage: "shuffle")
                        }
                    }
                }
                Section(freeWrite ? "Your entry" : prompt.text) {
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
            .themedScrollBackground()
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let entry = freeWrite
                            ? JournalEntry(promptID: nil, kind: .freeform, text: text, feeling: feeling)
                            : JournalEntry(promptID: prompt.id, kind: prompt.kind, text: text, feeling: feeling)
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
