//
//  CustomDictionaryView.swift
//  fluid
//
//  Custom dictionary for correcting commonly misheard words.
//  Created: 2025-12-21
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CustomDictionaryView: View {
    @Environment(\.theme) private var theme
    @State private var entries: [SettingsStore.CustomDictionaryEntry] = SettingsStore.shared.customDictionaryEntries
    @State private var boostTerms: [ParakeetVocabularyStore.VocabularyConfig.Term] = []
    @State private var showAddSheet = false
    @State private var editingEntry: SettingsStore.CustomDictionaryEntry?
    @State private var showAddBoostSheet = false
    @State private var editingBoostTerm: EditableBoostTerm?

    @State private var boostStatusMessage = "Add custom words for better Parakeet recognition."
    @State private var boostHasError = false
    @State private var vocabBoostingEnabled: Bool = SettingsStore.shared.vocabularyBoostingEnabled
    @State private var isBoostingInfoPresented = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: self.theme.metrics.spacing.xl) {
                self.pageHeader

                VStack(alignment: .leading, spacing: self.theme.metrics.spacing.xxl) {
                    self.instantReplacementSection
                    self.aiPostProcessingSection
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(self.theme.metrics.spacing.xl)
        }
        .sheet(isPresented: self.$showAddSheet) {
            AddDictionaryEntrySheet(existingTriggers: self.allExistingTriggers()) { newEntry in
                self.entries.append(newEntry)
                self.saveEntries()
            }
        }
        .sheet(item: self.$editingEntry) { entry in
            EditDictionaryEntrySheet(
                entry: entry,
                existingTriggers: self.allExistingTriggers(excluding: entry.id)
            ) { updatedEntry in
                if let index = self.entries.firstIndex(where: { $0.id == updatedEntry.id }) {
                    self.entries[index] = updatedEntry
                    self.saveEntries()
                }
            }
        }
        .sheet(isPresented: self.$showAddBoostSheet) {
            AddBoostTermSheet(existingTerms: self.existingBoostTerms()) { newTerm in
                self.boostTerms.append(newTerm)
                self.saveBoostTerms()
            }
        }
        .sheet(item: self.$editingBoostTerm) { editable in
            EditBoostTermSheet(
                term: editable.term,
                existingTerms: self.existingBoostTerms(excludingIndex: editable.index)
            ) { updatedTerm in
                guard self.boostTerms.indices.contains(editable.index) else { return }
                self.boostTerms[editable.index] = updatedTerm
                self.saveBoostTerms()
            }
        }
        .onAppear {
            self.loadBoostTerms()
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: self.theme.metrics.spacing.md) {
            self.settingsIconTile(systemName: "text.book.closed.fill")

            VStack(alignment: .leading, spacing: 2) {
                Text("Custom Dictionary")
                    .font(self.theme.typography.title)
                Text("Correct recurring mistakes and teach the voice engine the words you use.")
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.theme.palette.secondaryText)
            }

            Spacer(minLength: self.theme.metrics.spacing.md)

            HStack(spacing: self.theme.metrics.spacing.sm) {
                Button(action: self.importDictionary) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .fluidButton(.compact, size: .compact)

                Button(action: self.exportDictionary) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .fluidButton(.compact, size: .compact)
            }
        }
    }

    private func settingsIconTile(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: self.theme.metrics.corners.md, style: .continuous)
                .fill(self.theme.palette.contentBackground.opacity(0.82))
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: self.theme.metrics.corners.md, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: self.theme.metrics.corners.md, style: .continuous)
                        .stroke(self.theme.palette.accent.opacity(0.35), lineWidth: 1)
                )

            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(self.theme.palette.accent)
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - Instant Replacement

    private var instantReplacementSection: some View {
        ThemedCard(style: .standard, hoverEffect: false) {
            VStack(alignment: .leading, spacing: self.theme.metrics.spacing.lg) {
                HStack(alignment: .center, spacing: self.theme.metrics.spacing.md) {
                    self.settingsIconTile(systemName: "arrow.left.arrow.right")

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Instant Replacement")
                                .font(self.theme.typography.sectionTitle)
                            if !self.entries.isEmpty {
                                Text("(\(self.entries.count))")
                                    .font(self.theme.typography.captionSmall)
                                    .foregroundStyle(self.theme.palette.tertiaryText)
                            }
                        }
                        Text("Replace phrases that are consistently transcribed incorrectly.")
                            .font(self.theme.typography.caption)
                            .foregroundStyle(self.theme.palette.secondaryText)
                    }

                    Spacer()

                    Button {
                        self.showAddSheet = true
                    } label: {
                        Label("Add Replacement", systemImage: "plus")
                    }
                    .fluidButton(.accent, size: .small)
                }

                if self.entries.isEmpty {
                    self.dictionaryEmptyState(
                        title: "No replacements yet",
                        detail: "Add a phrase and the text it should become."
                    ) {
                        self.showAddSheet = true
                    }
                } else {
                    self.entriesListView
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entriesListView: some View {
        VStack(spacing: self.theme.metrics.spacing.sm) {
            ForEach(self.entries) { entry in
                DictionaryEntryRow(
                    entry: entry,
                    onEdit: { self.editingEntry = entry },
                    onDelete: { self.deleteEntry(entry) }
                )
            }
        }
    }

    // MARK: - Custom Words

    private var aiPostProcessingSection: some View {
        ThemedCard(style: .standard, hoverEffect: false) {
            VStack(alignment: .leading, spacing: self.theme.metrics.spacing.lg) {
                HStack(alignment: .center, spacing: self.theme.metrics.spacing.md) {
                    self.settingsIconTile(systemName: "character.book.closed")

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Custom Words")
                                .font(self.theme.typography.sectionTitle)
                            if !self.boostTerms.isEmpty {
                                Text("(\(self.boostTerms.count))")
                                    .font(self.theme.typography.captionSmall)
                                    .foregroundStyle(self.theme.palette.tertiaryText)
                            }
                        }
                        Text("Help the Parakeet voice engine recognize names, products, and uncommon terms.")
                            .font(self.theme.typography.caption)
                            .foregroundStyle(self.theme.palette.secondaryText)
                    }

                    Spacer()

                    Toggle("Boosting", isOn: self.$vocabBoostingEnabled)
                        .font(self.theme.typography.captionStrong)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .help("Improve recognition of your custom words when using Parakeet.")
                        .onChange(of: self.vocabBoostingEnabled) { _, newValue in
                            SettingsStore.shared.vocabularyBoostingEnabled = newValue
                        }

                    Button {
                        self.isBoostingInfoPresented.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(SquareIconButtonStyle())
                    .help("About Vocabulary Boosting")
                    .popover(isPresented: self.$isBoostingInfoPresented, arrowEdge: .top) {
                        self.boostingInfoPopover
                    }

                    Button {
                        self.showAddBoostSheet = true
                    } label: {
                        Label("Add Word", systemImage: "plus")
                    }
                    .fluidButton(.accent, size: .small)
                }

                if self.boostTerms.isEmpty {
                    self.dictionaryEmptyState(
                        title: "No custom words yet",
                        detail: "Add a name or term that needs a little extra recognition help."
                    ) {
                        self.showAddBoostSheet = true
                    }
                } else {
                    VStack(spacing: self.theme.metrics.spacing.sm) {
                        ForEach(Array(self.boostTerms.enumerated()), id: \.offset) { index, term in
                            BoostTermRow(
                                term: term,
                                onEdit: {
                                    self.editingBoostTerm = EditableBoostTerm(index: index, term: term)
                                },
                                onDelete: {
                                    self.deleteBoostTerm(at: index)
                                }
                            )
                        }
                    }
                }

                if self.boostHasError {
                    Label(self.boostStatusMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(self.theme.typography.caption)
                        .foregroundStyle(self.theme.palette.warning)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var boostingInfoPopover: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "testtube.2")
                    .foregroundStyle(self.theme.palette.accent)
                Text("Vocabulary Boosting · Alpha")
                    .font(self.theme.typography.bodySmallStrong)
            }

            Text("Vocabulary Boosting is an experimental feature that helps Parakeet recognize your custom words.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.theme.palette.secondaryText)

            Text("If recognition gets worse, the model behaves unexpectedly, or you notice other issues after enabling it, turn Boosting off.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.theme.palette.secondaryText)
        }
        .padding(self.theme.metrics.spacing.lg)
        .frame(width: 310, alignment: .leading)
    }

    private func dictionaryEmptyState(
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: self.theme.metrics.spacing.sm) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(self.theme.palette.tertiaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(self.theme.typography.bodySmallStrong)
                Text(detail)
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.palette.secondaryText)
            }

            Spacer()

            Button("Add", action: action)
                .fluidButton(.compact, size: .compact)
        }
        .padding(self.theme.metrics.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: self.theme.metrics.corners.md, style: .continuous)
                .fill(self.theme.palette.contentBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: self.theme.metrics.corners.md, style: .continuous)
                        .stroke(self.theme.palette.cardBorder.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    private func saveEntries() {
        SettingsStore.shared.customDictionaryEntries = self.entries
        // Invalidate cached regex patterns so changes take effect immediately
        ASRService.invalidateDictionaryCache()
        NotificationCenter.default.post(name: .parakeetVocabularyDidChange, object: nil)
    }

    private func loadBoostTerms() {
        do {
            self.boostTerms = try ParakeetVocabularyStore.shared.loadUserBoostTerms()
            self.boostStatusMessage = "Loaded \(self.boostTerms.count) custom words."
            self.boostHasError = false
        } catch {
            self.boostTerms = []
            self.boostStatusMessage = "Couldn't load custom words: \(error.localizedDescription)"
            self.boostHasError = true
        }
    }

    private func saveBoostTerms() {
        do {
            try ParakeetVocabularyStore.shared.saveUserBoostTerms(self.boostTerms)
            self.boostStatusMessage = "Saved \(self.boostTerms.count) custom words."
            self.boostHasError = false
        } catch {
            self.boostStatusMessage = "Couldn't save custom words: \(error.localizedDescription)"
            self.boostHasError = true
        }
    }

    private func exportDictionary() {
        do {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = DictionaryTransferService.shared.suggestedFilename()

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let document = try DictionaryTransferService.shared.makeExportDocument()
            let data = try DictionaryTransferService.shared.encode(document)
            try data.write(to: url, options: .atomic)

            self.presentInfoAlert(
                title: "Dictionary Exported",
                message: "Saved \(document.replacements.count) replacement rules and \(document.customWords.count) custom words."
            )
        } catch {
            self.presentErrorAlert(title: "Dictionary Export Failed", message: error.localizedDescription)
        }
    }

    private func importDictionary() {
        do {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.json]

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let data = try Data(contentsOf: url)
            let document = try DictionaryTransferService.shared.decode(data)
            guard let mode = self.confirmDictionaryImport(document) else { return }

            let summary = try DictionaryTransferService.shared.restore(document, mode: mode)
            self.entries = SettingsStore.shared.customDictionaryEntries
            self.loadBoostTerms()

            self.presentInfoAlert(
                title: "Dictionary Imported",
                message: "Now using \(summary.replacementCount) replacement rules and \(summary.customWordCount) custom words."
            )
        } catch {
            self.presentErrorAlert(title: "Dictionary Import Failed", message: error.localizedDescription)
        }
    }

    private func confirmDictionaryImport(_ document: DictionaryTransferDocument) -> DictionaryTransferImportMode? {
        let confirm = NSAlert()
        confirm.messageText = "Import this dictionary?"
        confirm.informativeText = """
        Found \(document.replacements.count) replacement rules and \(document.customWords.count) custom words.

        Merge adds them to your current dictionary. Replace clears the current dictionary first.
        """
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Merge")
        confirm.addButton(withTitle: "Replace")
        confirm.addButton(withTitle: "Cancel")

        switch confirm.runModal() {
        case .alertFirstButtonReturn:
            return .merge
        case .alertSecondButtonReturn:
            return .replace
        default:
            return nil
        }
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func deleteBoostTerm(at index: Int) {
        guard self.boostTerms.indices.contains(index) else { return }
        self.boostTerms.remove(at: index)
        self.saveBoostTerms()
    }

    private func deleteEntry(_ entry: SettingsStore.CustomDictionaryEntry) {
        self.entries.removeAll { $0.id == entry.id }
        self.saveEntries()
    }

    /// Returns all existing trigger words for duplicate detection
    private func allExistingTriggers(excluding entryId: UUID? = nil) -> Set<String> {
        var triggers = Set<String>()
        for entry in self.entries where entry.id != entryId {
            for trigger in entry.triggers {
                triggers.insert(trigger.lowercased())
            }
        }
        return triggers
    }

    private func existingBoostTerms(excludingIndex: Int? = nil) -> Set<String> {
        var terms: Set<String> = []
        for (index, term) in self.boostTerms.enumerated() where index != excludingIndex {
            terms.insert(term.text.lowercased())
        }
        return terms
    }
}

private struct EditableBoostTerm: Identifiable {
    let id = UUID()
    let index: Int
    let term: ParakeetVocabularyStore.VocabularyConfig.Term
}

private enum BoostStrengthPreset: String, CaseIterable, Identifiable {
    case mild = "Mild"
    case balanced = "Balanced"
    case strong = "Strong"

    var id: String { self.rawValue }

    var weight: Float {
        switch self {
        case .mild: return 5.0
        case .balanced: return 10.0
        case .strong: return 13.0
        }
    }

    var hint: String {
        switch self {
        case .mild: return "Very light nudge with minimal impact."
        case .balanced: return "Best default for most names and product terms."
        case .strong: return "Use when this word should win more often in noisy audio."
        }
    }

    var badgeColor: Color {
        switch self {
        case .mild: return .blue
        case .balanced: return Color.fluidGreen
        case .strong: return .orange
        }
    }

    static func nearest(for weight: Float) -> Self {
        if weight < 8.5 { return .mild }
        if weight > 11.5 { return .strong }
        return .balanced
    }
}

// MARK: - Boost Term Row

struct BoostTermRow: View {
    let term: ParakeetVocabularyStore.VocabularyConfig.Term
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: self.theme.metrics.spacing.sm) {
            Text(self.term.text)
                .font(self.theme.typography.bodySmallStrong)

            Spacer()

            if let weight = self.term.weight {
                let strength = BoostStrengthPreset.nearest(for: weight)
                Text(strength.rawValue)
                    .font(self.theme.typography.bodySmallStrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(strength.badgeColor.opacity(0.25)))
                    .foregroundStyle(strength.badgeColor)
            }

            HStack(spacing: 2) {
                Button {
                    self.onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(SquareIconButtonStyle())
                .help("Configure \(self.term.text)")

                Button(role: .destructive) {
                    self.onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(SquareIconButtonStyle(foreground: .red, borderColor: .red))
                .help("Delete \(self.term.text)")
            }
        }
        .padding(.horizontal, self.theme.metrics.spacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(self.theme.palette.contentBackground.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(self.theme.palette.cardBorder.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

// MARK: - Add Boost Term Sheet

struct AddBoostTermSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingTerms: Set<String>
    let onSave: (ParakeetVocabularyStore.VocabularyConfig.Term) -> Void

    @State private var termText = ""
    @State private var strength: BoostStrengthPreset = .balanced

    private var normalizedTerm: String {
        self.termText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        self.existingTerms.contains(self.normalizedTerm.lowercased())
    }

    private var canSave: Bool {
        !self.normalizedTerm.isEmpty && !self.isDuplicate
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add Custom Word")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Word or Phrase")
                        .font(.subheadline.weight(.medium))
                    TextField("FluidVoice", text: self.$termText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { self.saveIfValid() }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Word Priority")
                        .font(.subheadline.weight(.medium))
                    Picker("Word Priority", selection: self.$strength) {
                        ForEach(BoostStrengthPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(self.strength.hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if self.isDuplicate {
                    Text("This term already exists.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Cancel") { self.dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save") { self.saveIfValid() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!self.canSave)
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 520)
        .frame(minHeight: 300, idealHeight: 340, maxHeight: 460)
        .onAppear {
            // Always start new entries at the recommended default.
            self.termText = ""
            self.strength = .balanced
        }
    }

    private func saveIfValid() {
        guard self.canSave else { return }
        self.onSave(
            ParakeetVocabularyStore.VocabularyConfig.Term(
                text: self.normalizedTerm,
                weight: self.strength.weight,
                aliases: []
            )
        )
        self.dismiss()
    }
}

// MARK: - Edit Boost Term Sheet

struct EditBoostTermSheet: View {
    @Environment(\.dismiss) private var dismiss

    let term: ParakeetVocabularyStore.VocabularyConfig.Term
    let existingTerms: Set<String>
    let onSave: (ParakeetVocabularyStore.VocabularyConfig.Term) -> Void

    @State private var termText = ""
    @State private var strength: BoostStrengthPreset = .balanced

    private var normalizedTerm: String {
        self.termText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        self.existingTerms.contains(self.normalizedTerm.lowercased())
    }

    private var canSave: Bool {
        !self.normalizedTerm.isEmpty && !self.isDuplicate
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit Custom Word")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Word or Phrase")
                        .font(.subheadline.weight(.medium))
                    TextField("FluidVoice", text: self.$termText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { self.saveIfValid() }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Word Priority")
                        .font(.subheadline.weight(.medium))
                    Picker("Word Priority", selection: self.$strength) {
                        ForEach(BoostStrengthPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(self.strength.hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if self.isDuplicate {
                    Text("This term already exists.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Cancel") { self.dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save") { self.saveIfValid() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!self.canSave)
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 520)
        .frame(minHeight: 300, idealHeight: 340, maxHeight: 460)
        .onAppear {
            self.termText = self.term.text
            self.strength = BoostStrengthPreset.nearest(for: self.term.weight ?? BoostStrengthPreset.balanced.weight)
        }
    }

    private func saveIfValid() {
        guard self.canSave else { return }
        self.onSave(
            ParakeetVocabularyStore.VocabularyConfig.Term(
                text: self.normalizedTerm,
                weight: self.strength.weight,
                aliases: self.term.aliases
            )
        )
        self.dismiss()
    }
}

// MARK: - Dictionary Entry Row

struct DictionaryEntryRow: View {
    let entry: SettingsStore.CustomDictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: self.theme.metrics.spacing.sm) {
            FlowLayout(spacing: 4) {
                ForEach(self.entry.triggers, id: \.self) { trigger in
                    Text(trigger)
                        .font(self.theme.typography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.theme.palette.tertiaryText)

            Text(self.entry.replacement)
                .font(self.theme.typography.bodySmallStrong)
                .foregroundStyle(self.theme.palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button {
                    self.onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(SquareIconButtonStyle())
                .help("Configure replacement")

                Button(role: .destructive) {
                    self.onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(SquareIconButtonStyle(foreground: .red, borderColor: .red))
                .help("Delete replacement")
            }
        }
        .padding(.horizontal, self.theme.metrics.spacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(self.theme.palette.contentBackground.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(self.theme.palette.cardBorder.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

// MARK: - Add Entry Sheet

struct AddDictionaryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let existingTriggers: Set<String>
    let onSave: (SettingsStore.CustomDictionaryEntry) -> Void

    @State private var triggersText = ""
    @State private var replacement = ""

    private var duplicateTriggers: [String] {
        self.parseTriggers().filter { self.existingTriggers.contains($0) }
    }

    private var canSave: Bool {
        !self.parseTriggers().isEmpty &&
            !self.replacement.trimmingCharacters(in: .whitespaces).isEmpty &&
            self.duplicateTriggers.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Add Dictionary Entry")
                    .font(.headline)
                Spacer()
                Button("Cancel") { self.dismiss() }
                    .buttonStyle(.bordered)
            }

            Divider()

            // Triggers input
            VStack(alignment: .leading, spacing: 6) {
                Text("Misheard Words (triggers)")
                    .font(.subheadline.weight(.medium))
                Text("Enter words separated by commas. These are what the transcription might hear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("fluid voice, fluid boys", text: self.$triggersText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { self.saveIfValid() }

                // Duplicate warning
                if !self.duplicateTriggers.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Duplicate triggers: \(self.duplicateTriggers.joined(separator: ", "))")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }
            }

            // Replacement input
            VStack(alignment: .leading, spacing: 6) {
                Text("Correct Spelling (replacement)")
                    .font(.subheadline.weight(.medium))
                Text("This is what will appear in the final transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("FluidVoice", text: self.$replacement)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { self.saveIfValid() }
            }

            Spacer()

            // Preview
            if !self.triggersText.isEmpty && !self.replacement.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(self.parseTriggers(), id: \.self) { trigger in
                            Text(trigger)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4).fill(
                                        self.duplicateTriggers.contains(trigger)
                                            ? AnyShapeStyle(Color.orange.opacity(0.3))
                                            : AnyShapeStyle(.quaternary)
                                    )
                                )
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(self.replacement)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(self.theme.palette.accent)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(self.theme.palette.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(self.theme.palette.cardBorder.opacity(0.5), lineWidth: 1)
                        )
                )
            }

            // Save button
            HStack {
                Spacer()
                Button("Add Entry") { self.saveIfValid() }
                    .buttonStyle(.borderedProminent)
                    .tint(self.theme.palette.accent)
                    .disabled(!self.canSave)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)
        .frame(minHeight: 350, idealHeight: 400, maxHeight: 450)
    }

    private func parseTriggers() -> [String] {
        self.triggersText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func saveIfValid() {
        guard self.canSave else { return }

        let entry = SettingsStore.CustomDictionaryEntry(
            triggers: self.parseTriggers(),
            replacement: self.replacement.trimmingCharacters(in: .whitespaces)
        )
        self.onSave(entry)
        self.dismiss()
    }
}

// MARK: - Edit Entry Sheet

struct EditDictionaryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let entry: SettingsStore.CustomDictionaryEntry
    let existingTriggers: Set<String>
    let onSave: (SettingsStore.CustomDictionaryEntry) -> Void

    @State private var triggersText = ""
    @State private var replacement = ""

    private var duplicateTriggers: [String] {
        self.parseTriggers().filter { self.existingTriggers.contains($0) }
    }

    private var canSave: Bool {
        !self.parseTriggers().isEmpty &&
            !self.replacement.trimmingCharacters(in: .whitespaces).isEmpty &&
            self.duplicateTriggers.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Edit Dictionary Entry")
                    .font(.headline)
                Spacer()
                Button("Cancel") { self.dismiss() }
                    .buttonStyle(.bordered)
            }

            Divider()

            // Triggers input
            VStack(alignment: .leading, spacing: 6) {
                Text("Misheard Words (triggers)")
                    .font(.subheadline.weight(.medium))
                Text("Enter words separated by commas. These are what the transcription might hear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("fluid voice, fluid boys", text: self.$triggersText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { self.saveIfValid() }

                // Duplicate warning
                if !self.duplicateTriggers.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Duplicate triggers: \(self.duplicateTriggers.joined(separator: ", "))")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }
            }

            // Replacement input
            VStack(alignment: .leading, spacing: 6) {
                Text("Correct Spelling (replacement)")
                    .font(.subheadline.weight(.medium))
                Text("This is what will appear in the final transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("FluidVoice", text: self.$replacement)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { self.saveIfValid() }
            }

            Spacer()

            // Preview
            if !self.triggersText.isEmpty && !self.replacement.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(self.parseTriggers(), id: \.self) { trigger in
                            Text(trigger)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4).fill(
                                        self.duplicateTriggers.contains(trigger)
                                            ? AnyShapeStyle(Color.orange.opacity(0.3))
                                            : AnyShapeStyle(.quaternary)
                                    )
                                )
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(self.replacement)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(self.theme.palette.accent)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(self.theme.palette.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(self.theme.palette.cardBorder.opacity(0.5), lineWidth: 1)
                        )
                )
            }

            // Save button
            HStack {
                Spacer()
                Button("Save Changes") { self.saveIfValid() }
                    .buttonStyle(.borderedProminent)
                    .tint(self.theme.palette.accent)
                    .disabled(!self.canSave)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)
        .frame(minHeight: 320, idealHeight: 380, maxHeight: 420)
        .onAppear {
            self.triggersText = self.entry.triggers.joined(separator: ", ")
            self.replacement = self.entry.replacement
        }
    }

    private func parseTriggers() -> [String] {
        self.triggersText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func saveIfValid() {
        guard self.canSave else { return }

        let updatedEntry = SettingsStore.CustomDictionaryEntry(
            id: self.entry.id,
            triggers: self.parseTriggers(),
            replacement: self.replacement.trimmingCharacters(in: .whitespaces)
        )
        self.onSave(updatedEntry)
        self.dismiss()
    }
}
