import SwiftUI
import FinanceWorkspaceKit

// Phase 6 (007) T014 + Phase 7 (008) US2 T024 — structured add/edit forms for the row-based
// entities (account group, account, category, budget, allocation, goal, asset, liability,
// portfolio, sleeve, tax-adjustment, rule).
//
// One header-driven `Form` renders a control per canonical column of the target file — but the
// control is now TYPED (research D10, OOS-13): the bundled `CSVSchemaRegistry` column definition
// resolves each column to an enum picker (schema `values`), a parent-reference picker over the
// live workspace ids (schema `references`, e.g. `account_group_id` → account groups), a
// sign-aware amount field (decimal `amount`: debit/credit toggle + magnitude), a boolean toggle,
// or a plain/date text field. Unknown columns fall back to free text, so a schema round never
// breaks the form. DESIGN.md "modal-form · stacked modal-field (label + control) · add/edit flows".

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
    @State private var schema: CSVSchema?

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
                        control(for: column)
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
        .onAppear {
            if fields.isEmpty { fields = context.fields }
            schema = try? CSVSchemaRegistry().schema(forRelativePath: context.relativePath)
        }
    }

    // MARK: - Typed controls (008 US2 T024 / D10)

    /// Resolve the column's schema definition to the right control. Free text is the fallback,
    /// so columns unknown to the registry (or a missing schema) never block editing.
    @ViewBuilder private func control(for column: String) -> some View {
        let definition = schema?.columns[column]
        if column == context.idColumn {
            // The primary key is system-owned: read-only so the row stays identifiable.
            TextField(column, text: binding(for: column))
                .textFieldStyle(.roundedBorder).font(DS.Fonts.body)
                .disabled(true)
        } else if let values = definition?.values, definition?.type == .enumerated {
            enumPicker(column, values: values, required: definition?.required == true)
        } else if let reference = definition?.references {
            referencePicker(column, reference: reference, required: definition?.required == true)
        } else if definition?.type == .decimal {
            if column == "amount" {
                SignAwareAmountField(value: binding(for: column))
            } else {
                TextField(column, text: binding(for: column))
                    .textFieldStyle(.roundedBorder).font(DS.Fonts.bodyNumeric)
                    .multilineTextAlignment(.trailing)
            }
        } else if definition?.type == .boolean {
            Toggle("", isOn: booleanBinding(for: column)).labelsHidden().toggleStyle(.switch)
        } else if definition?.type == .date {
            TextField("YYYY-MM-DD", text: binding(for: column))
                .textFieldStyle(.roundedBorder).font(DS.Fonts.bodyNumeric)
        } else {
            TextField(column, text: binding(for: column))
                .textFieldStyle(.roundedBorder).font(DS.Fonts.body)
        }
    }

    /// Enum column → menu picker over the schema's permitted values ("—" when optional).
    private func enumPicker(_ column: String, values: [String], required: Bool) -> some View {
        Picker("", selection: binding(for: column)) {
            if !required { Text("—").tag("") }
            ForEach(values, id: \.self) {
                Text($0.replacingOccurrences(of: "_", with: " ")).tag($0)
            }
        }
        .labelsHidden().pickerStyle(.menu)
        .accessibilityLabel(label(column))
    }

    /// Reference column (schema `references: "<file>#<column>"`) → picker over the live ids of
    /// the parent collection, labelled with display names where the workspace knows them.
    private func referencePicker(_ column: String, reference: String, required: Bool) -> some View {
        let options = referenceOptions(reference)
        return Picker("", selection: binding(for: column)) {
            if !required { Text("—").tag("") }
            // Keep an unknown current value selectable rather than silently clearing it.
            if let current = fields[column], !current.isEmpty, !options.contains(where: { $0.id == current }) {
                Text(current).tag(current)
            }
            ForEach(options, id: \.id) { option in
                Text(option.name.isEmpty ? option.id : "\(option.name) (\(option.id))").tag(option.id)
            }
        }
        .labelsHidden().pickerStyle(.menu)
        .accessibilityLabel(label(column))
    }

    /// Live parent ids (+ display names for the common parents) from the current projections.
    private func referenceOptions(_ reference: String) -> [(id: String, name: String)] {
        guard let context = state.projections?.context else { return [] }
        let parts = reference.split(separator: "#")
        guard parts.count == 2 else { return [] }
        guard let parentSchema = try? CSVSchemaRegistry().schema(forRelativePath: String(parts[0])) else { return [] }
        let ids = context.identifierSet(fileTypeKey: parentSchema.fileTypeKey, column: String(parts[1]))
        let names = displayNames(fileTypeKey: parentSchema.fileTypeKey, context: context)
        return ids.sorted().map { (id: $0, name: names[$0] ?? "") }
    }

    private func displayNames(fileTypeKey: String, context: WorkspaceContext) -> [String: String] {
        switch fileTypeKey {
        case "registry":
            return Dictionary(uniqueKeysWithValues: context.accounts.map { ($0.accountId, $0.displayName) })
        case "account-groups":
            return Dictionary(uniqueKeysWithValues: context.accountGroups.map { ($0.accountGroupId, $0.name) })
        case "categories":
            return Dictionary(uniqueKeysWithValues: context.categories.map { ($0.categoryId, $0.name) })
        case "goals":
            return Dictionary(uniqueKeysWithValues: context.savingsGoals.map { ($0.goalId, $0.name) })
        default:
            return [:]
        }
    }

    private func binding(for column: String) -> Binding<String> {
        Binding(get: { fields[column] ?? "" }, set: { fields[column] = $0 })
    }

    private func booleanBinding(for column: String) -> Binding<Bool> {
        Binding(get: { (fields[column] ?? "").lowercased() == "true" },
                set: { fields[column] = $0 ? "true" : "false" })
    }

    /// "source_account_id" → "Source account id" for a friendlier label.
    private func label(_ column: String) -> String {
        column.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }
}

/// Sign-aware amount entry (008 T024): magnitude + an explicit money-in/money-out choice, writing
/// back the signed canonical value (negative = debit, the locked sign convention). Green/red is
/// reserved for money meaning — exactly this case (DESIGN.md).
struct SignAwareAmountField: View {
    @Binding var value: String

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: signBinding) {
                Text("Out −").tag(-1)
                Text("In +").tag(1)
            }
            .labelsHidden().pickerStyle(.segmented).frame(width: 110)
            TextField("0.00", text: magnitudeBinding)
                .textFieldStyle(.roundedBorder)
                .font(DS.Fonts.bodyNumeric)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(sign < 0 ? DS.Colors.neg : DS.Colors.pos)
        }
    }

    private var sign: Int { value.hasPrefix("-") ? -1 : 1 }

    private var signBinding: Binding<Int> {
        Binding(get: { sign },
                set: { newSign in
                    let magnitude = value.hasPrefix("-") ? String(value.dropFirst()) : value
                    value = magnitude.isEmpty ? magnitude : (newSign < 0 ? "-" + magnitude : magnitude)
                })
    }

    private var magnitudeBinding: Binding<String> {
        Binding(get: { value.hasPrefix("-") ? String(value.dropFirst()) : value },
                set: { newMagnitude in
                    let cleaned = newMagnitude.replacingOccurrences(of: "-", with: "")
                    value = cleaned.isEmpty ? "" : (sign < 0 ? "-" + cleaned : cleaned)
                })
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
        var result: [String] = []
        var field = ""
        var insideQuotes = false
        let chars = Array(line)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if insideQuotes {
                let isEscapedQuote = char == "\"" && index + 1 < chars.count && chars[index + 1] == "\""
                if isEscapedQuote {
                    field.append("\"")
                    index += 1
                } else if char == "\"" {
                    insideQuotes = false
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                insideQuotes = true
            } else if char == "," {
                result.append(field)
                field = ""
            } else {
                field.append(char)
            }
            index += 1
        }
        result.append(field)
        return result
    }
}
