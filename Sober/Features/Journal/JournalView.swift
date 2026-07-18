import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var showCompose = false
    @State private var selectedEntry: JournalEntry?

    /// Free users get one real entry before the gate — a locked door you've
    /// never walked through is much harder to pay for than one you have.
    private var canCompose: Bool {
        subscriptions.isProSubscriber || entries.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Prompt of the day") {
                    promptRow
                }

                Section("Entries") {
                    if entries.isEmpty {
                        Text(subscriptions.isProSubscriber
                             ? "No entries yet. Use the pencil to write your first."
                             : "No entries yet. Your first entry is free — use the pencil to write it.")
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
                        if canCompose { showCompose = true }
                        else { requestSubsequentLockedFeaturePitch(.journal) }
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
            .onAppear {
                guard !subscriptions.isProSubscriber else { return }
                let visits = TrialSubsequentPitchGate.incrementPersistedCount(key: AppGroup.journalTabVisitCountKey)
                Task {
                    await evaluateUsageBasedTrialPitch(
                        subscriptions,
                        intent: .journal,
                        usageCount: visits,
                        delay: 2
                    )
                }
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
                if canCompose { showCompose = true }
                else { requestSubsequentLockedFeaturePitch(.journal) }
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
    @State private var isEditing = false
    @State private var editedText = ""

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

                    if isEditing {
                        TextEditor(text: $editedText)
                            .font(Theme.body())
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text(entry.text)
                            .font(Theme.body())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.background)
            .navigationTitle(entry.kind == .freeform ? "Free Write" : "Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                entry.text = trimmed
                                try? context.save()
                            }
                            isEditing = false
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Button(role: .destructive) {
                            context.delete(entry)
                            try? context.save()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete entry")

                        if !isEditing {
                            Button {
                                editedText = entry.text
                                isEditing = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel("Edit entry")
                        }
                    }
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
