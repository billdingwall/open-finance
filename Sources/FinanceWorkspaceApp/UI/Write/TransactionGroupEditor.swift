import SwiftUI
import FinanceWorkspaceKit

// Phase 7 (008) US2 T018/T019 — the multi-entry transaction group editor (FR-005 · OOS-16).
// Authors a paycheck as one atomic group (gross → withholdings → net), all legs in ONE monthly
// file, with a live reconciliation indicator; Apply is blocked until net == gross − Σ withholding.
// When `state.groupEditorLegs` is set the editor opens in whole-group EDIT mode: the legs prefill
// the form and Save re-authors the group in place (same group_id, one atomic delete+add
// FileChange — T019). The write runs through the existing safe-write preview → backup → atomic
// apply path (MultiEntry.plan / AppState.presentGroupRewrite).
//
// Transfers (balanced debit/credit) are a follow-up: the shipped MultiEntryLeg.Role enum has no
// credit/debit case, so a transfer would emit a schema-invalid group_role — deferred to a small
// additive engine change. DESIGN.md "modal-form · stacked modal-field · add/edit flows".

struct TransactionGroupEditor: View {
    @Environment(AppState.self) private var state

    @State private var month: String = Self.currentMonth()
    @State private var accountId: String = ""
    @State private var gross: String = ""
    @State private var net: String = ""
    @State private var withholdings: [Withholding] = [Withholding(label: "Federal tax", amount: "")]

    private struct Withholding: Identifiable, Equatable {
        let id = UUID()
        var label: String
        var amount: String
    }

    private var isEditing: Bool { state.groupEditorLegs != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                OverlineLabel(text: isEditing ? "Edit paycheck group" : "New paycheck group")
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().overlay(DS.Colors.borderSoft)

            Form {
                Section {
                    LabeledContent("Month") {
                        TextField("YYYY-MM", text: $month).textFieldStyle(.roundedBorder).font(DS.Fonts.body)
                    }
                    LabeledContent("Account id") {
                        TextField("account_id", text: $accountId).textFieldStyle(.roundedBorder).font(DS.Fonts.body)
                    }
                }
                Section("Gross") {
                    amountField("Gross pay", text: $gross)
                }
                Section("Withholdings") {
                    ForEach($withholdings) { $item in
                        HStack(spacing: 8) {
                            TextField("Label", text: $item.label).textFieldStyle(.roundedBorder)
                            amountField("0.00", text: $item.amount)
                            Button(role: .destructive) { withholdings.removeAll { $0.id == item.id } }
                                label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.plain).foregroundStyle(DS.Colors.muted)
                        }
                    }
                    Button("Add withholding", systemImage: "plus") {
                        withholdings.append(Withholding(label: "", amount: ""))
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                Section("Net") {
                    amountField("Net pay", text: $net)
                }
            }
            .formStyle(.grouped)
            .font(DS.Fonts.body)

            Divider().overlay(DS.Colors.borderSoft)
            reconciliationBar
            Divider().overlay(DS.Colors.borderSoft)
            HStack {
                Spacer()
                Button("Cancel") {
                    state.groupEditorLegs = nil
                    state.showingGroupEditor = false
                }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save group…" : "Add group…") { apply() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canApply)
            }
            .padding(12)
        }
        .frame(width: 500, height: 620)
        .onAppear { prefillFromEditingLegs() }
    }

    /// EDIT mode — seed the form from the existing group's legs (paycheck shape).
    private func prefillFromEditingLegs() {
        guard let legs = state.groupEditorLegs, let file = legs.first?.sourceFile,
              let legMonth = AppState.ledgerMonth(of: file) else { return }
        month = legMonth
        accountId = legs.first?.accountId ?? ""
        if let grossLeg = legs.first(where: { $0.groupRole == .gross }) {
            gross = NSDecimalNumber(decimal: abs(grossLeg.amount)).stringValue
        }
        if let netLeg = legs.first(where: { $0.groupRole == .net }) {
            net = NSDecimalNumber(decimal: abs(netLeg.amount)).stringValue
        }
        let held = legs.filter { $0.groupRole == .withholding }
        if !held.isEmpty {
            withholdings = held.map {
                Withholding(label: "Withholding",
                            amount: NSDecimalNumber(decimal: abs($0.amount)).stringValue)
            }
        }
    }

    // MARK: - Reconciliation

    private var reconciliationBar: some View {
        HStack(spacing: 6) {
            Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isBalanced ? DS.Colors.pos : DS.Colors.warn)
            if isBalanced {
                Text("Balanced — net = gross − withholdings").font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                Text("Off by \(Format.money(offBy)) — net must equal gross − withholdings")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var grossValue: Decimal { Decimal(string: gross) ?? 0 }
    private var netValue: Decimal { Decimal(string: net) ?? 0 }
    private var withheldTotal: Decimal { withholdings.reduce(Decimal.zero) { $0 + (Decimal(string: $1.amount) ?? 0) } }
    private var offBy: Decimal { netValue - (grossValue - withheldTotal) }
    private var isBalanced: Bool { offBy == 0 && grossValue > 0 }
    private var canApply: Bool {
        isBalanced && !accountId.trimmingCharacters(in: .whitespaces).isEmpty && Self.isMonth(month)
    }

    // MARK: - Apply

    private func apply() {
        let date = "\(month)-01"
        var legs: [MultiEntryLeg] = []
        legs.append(leg(role: .gross, magnitude: grossValue, signed: grossValue, date: date, memo: "Gross pay"))
        for item in withholdings {
            let amount = Decimal(string: item.amount) ?? 0
            guard amount > 0 else { continue }
            legs.append(leg(role: .withholding, magnitude: amount, signed: -amount, date: date,
                            memo: item.label.isEmpty ? "Withholding" : item.label))
        }
        legs.append(leg(role: .net, magnitude: netValue, signed: netValue, date: date, memo: "Net pay"))
        if let old = state.groupEditorLegs {
            state.presentGroupRewrite(kind: .grossNet, month: month, legs: legs, replacing: old)
        } else {
            state.presentGroupWrite(kind: .grossNet, month: month, legs: legs)
        }
    }

    private func abs(_ value: Decimal) -> Decimal { value < 0 ? -value : value }

    private func leg(role: MultiEntryLeg.Role, magnitude: Decimal, signed: Decimal,
                     date: String, memo: String) -> MultiEntryLeg {
        MultiEntryLeg(role: role, amount: magnitude, fields: [
            "transaction_id": "tx-" + UUID().uuidString.prefix(8).lowercased(),
            "account_id": accountId,
            "date": date,
            "amount": NSDecimalNumber(decimal: signed).stringValue,
            "description": memo,
            "type": "standard",
        ])
    }

    private func amountField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.roundedBorder)
            .font(DS.Fonts.bodyNumeric)
            .multilineTextAlignment(.trailing)
    }

    // MARK: - Helpers

    private static func currentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"; formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
    private static func isMonth(_ value: String) -> Bool {
        value.count == 7 && value.dropFirst(4).first == "-" && Int(value.prefix(4)) != nil
    }
}
