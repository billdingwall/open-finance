import SwiftUI
import FinanceWorkspaceKit

// Phase 6 (007) T014 — structured add/edit forms for the row-based entities (account group, account,
// category, budget, allocation, goal, asset, liability, portfolio, sleeve, tax-adjustment, rule).
//
// Design note (deviation from research D10): rather than 12 bespoke SwiftUI forms, this is one
// header-driven `Form` that renders a labelled field per canonical column of the target file. The
// canonical column order comes from the file's own header (the JSON schema columns are unordered).
// This keeps every entity editable through the same safe-write path for v1; per-entity typed
// controls (pickers, sign-aware amounts) are a follow-up refinement. DESIGN.md "modal-form ·
// stacked modal-field (label + control) · add/edit flows".

/// Everything an edit form needs to render and to build its `WritePlan`.
struct EntityEditContext: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var relativePath: String
    var columns: [String]          // canonical order (from the file header)
    var idColumn: String
    var fields: [String: String]   // initial values
    var rowRef: Int?               // nil ⇒ add
    var before: String?            // the exact existing line (edit only), for a drift-safe diff
    var fileText: String           // current file contents (header + drift baseline)

    var isNew: Bool { rowRef == nil }
}

struct EntityEditForm: View {
    @Environment(AppState.self) private var state
    let context: EntityEditContext
    @State private var fields: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                OverlineLabel(text: context.title)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().overlay(DS.Colors.borderSoft)

            Form {
                ForEach(context.columns, id: \.self) { column in
                    LabeledContent(label(column)) {
                        TextField(column, text: binding(for: column))
                            .textFieldStyle(.roundedBorder)
                            .font(DS.Fonts.body)
                            // The primary key is system-owned: shown read-only so the row stays identifiable.
                            .disabled(column == context.idColumn)
                    }
                }
            }
            .formStyle(.grouped)

            Divider().overlay(DS.Colors.borderSoft)
            HStack {
                Spacer()
                Button("Cancel") { state.editForm = nil }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(context.isNew ? "Add…" : "Save…") {
                    state.finishEditForm(context: context, fields: fields)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 480, height: 520)
        .onAppear { if fields.isEmpty { fields = context.fields } }
    }

    private func binding(for column: String) -> Binding<String> {
        Binding(get: { fields[column] ?? "" }, set: { fields[column] = $0 })
    }

    /// "source_account_id" → "Source account id" for a friendlier label.
    private func label(_ column: String) -> String {
        column.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - CSV line parsing (quote-aware) — populate a form from an existing row.

enum CSVLine {
    /// Split one CSV line into fields, honoring double-quoted fields with escaped `""`.
    static func fields(_ line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character?
        func next() -> Character? { if let p = pending { pending = nil; return p }; return iterator.next() }
        while let ch = next() {
            if inQuotes {
                if ch == "\"" {
                    if let peek = iterator.next() {
                        if peek == "\"" { current.append("\"") } else { inQuotes = false; pending = peek }
                    } else { inQuotes = false }
                } else { current.append(ch) }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == "," {
                out.append(current); current = ""
            } else {
                current.append(ch)
            }
        }
        out.append(current)
        return out
    }
}
