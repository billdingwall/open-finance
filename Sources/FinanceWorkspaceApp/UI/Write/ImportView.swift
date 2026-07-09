import SwiftUI
import UniformTypeIdentifiers
import FinanceWorkspaceKit

// Phase 6 (007) US2 (T025) — the CSV import flow. Pick a file → confirm the auto-detected mapping,
// target account, and sign convention → preview month-grouped rows with duplicates flagged → apply
// through the safe-write path. DESIGN.md "modal-form"; tokens reused, no new type/colour.

struct ImportView: View {
    @Environment(AppState.self) private var state
    let onClose: () -> Void

    @State private var csvText: String?
    @State private var sourceColumns: [String] = []
    @State private var mapping = ColumnMapping(sourceColumns: [], map: [:])
    @State private var targetAccountId = ""
    @State private var flipped = false
    @State private var batch: ImportBatch?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { OverlineLabel(text: "Import transactions"); Spacer() }
                .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().overlay(DS.Colors.borderSoft)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if csvText == nil {
                        Button("Choose CSV…", systemImage: "doc.badge.plus") { pickFile() }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        mappingSection
                        if let batch { previewSection(batch) }
                    }
                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle")
                            .font(DS.Fonts.caption).foregroundStyle(DS.Colors.warn)
                    }
                }
                .padding(16)
            }

            Divider().overlay(DS.Colors.borderSoft)
            HStack {
                Spacer()
                Button("Cancel") { onClose() }.buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Import…", systemImage: "square.and.arrow.down") { apply() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(batch == nil || batch?.includedCount == 0)
            }
            .padding(12)
        }
        .frame(width: 560, height: 520)
        .onAppear { consumeDroppedFile() }
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OverlineLabel(text: "Mapping")
            ForEach(["date", "amount", "type"], id: \.self) { canonical in
                LabeledContent(canonical.capitalizedFirst) {
                    Picker("", selection: bindingForColumn(canonical)) {
                        Text("— none —").tag(String?.none)
                        ForEach(sourceColumns, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Map \(canonical) column")
                }
            }
            LabeledContent("Target account") {
                Picker("", selection: $targetAccountId) {
                    Text("— choose —").tag("")
                    ForEach(accountOptions, id: \.0) { Text($0.1).tag($0.0) }
                }
                .labelsHidden()
                .accessibilityLabel("Target account")
            }
            Toggle("Source uses the opposite sign convention", isOn: $flipped)
                .font(DS.Fonts.body)
            Button("Preview") { rebuildBatch() }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(targetAccountId.isEmpty)
        }
        .onChange(of: targetAccountId) { _, _ in batch = nil }
        .onChange(of: flipped) { _, _ in batch = nil }
    }

    private func previewSection(_ batch: ImportBatch) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            OverlineLabel(text: "Preview — \(batch.includedCount) rows to import")
            ForEach(batch.rowsByMonth.keys.sorted(), id: \.self) { month in
                let rows = batch.rowsByMonth[month] ?? []
                let dups = rows.filter(\.isDuplicate).count
                Text("\(month): \(rows.count) rows\(dups > 0 ? " · \(dups) likely duplicate(s) excluded" : "")")
                    .font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
            }
            if !batch.unparseable.isEmpty {
                Text("\(batch.unparseable.count) unparseable row(s) skipped.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.warn)
            }
        }
    }

    // MARK: - Actions

    private var accountOptions: [(String, String)] {
        (state.projections?.context.accounts ?? []).map { ($0.accountId, $0.displayName) }
    }

    private func bindingForColumn(_ canonical: String) -> Binding<String?> {
        Binding(get: { mapping.map[canonical] },
                set: { mapping.map[canonical] = $0; batch = nil })
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    /// Load a source CSV (file picker or a window drop — 008 US5 T043) and auto-detect mapping.
    private func load(_ url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        csvText = text
        let headerLine = text.components(separatedBy: "\n").first ?? ""
        sourceColumns = CSVLine.fields(headerLine).map { $0.trimmingCharacters(in: .whitespaces) }
        mapping = ImportMapper().autoDetect(sourceColumns: sourceColumns)
    }

    /// Consume a CSV dropped onto the window (the drop opens this sheet pre-loaded).
    private func consumeDroppedFile() {
        guard let url = state.droppedImportURL else { return }
        state.droppedImportURL = nil
        load(url)
    }

    private func rebuildBatch() {
        guard let csvText else { return }
        mapping.targetAccountId = targetAccountId
        mapping.signConvention = flipped ? .flipped : .negativeIsDebit
        do {
            batch = try ImportMapper().buildBatch(
                csv: csvText, mapping: mapping,
                existingTransactions: state.projections?.context.records(ofType: "transactions") ?? [])
            errorText = nil
        } catch ImportError.requiredColumnUnmapped(let missing) {
            errorText = "Map the required column(s): \(missing.joined(separator: ", "))."
            batch = nil
        } catch { errorText = String(describing: error); batch = nil }
    }

    private func apply() {
        guard let batch else { return }
        state.applyImport(batch: batch, mapping: mapping)
        onClose()
    }
}
