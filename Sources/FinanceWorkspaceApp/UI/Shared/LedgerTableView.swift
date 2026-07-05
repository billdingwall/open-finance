import SwiftUI
import FinanceWorkspaceKit

// T030 — the unified-ledger table with multi-entry grouping (FR-020, research D7): rows
// sharing a `group_id` fold into one summary entry (net effect) with a disclosure to the
// constituent legs. Grouping is presentation-only; each leg stays individually traceable to
// its source file + row (P-V). The derived summary row is labeled `derived`.

struct LedgerEntry: Identifiable {
    var id: String
    var date: Date
    var title: String
    var netAmount: Decimal
    var categoryId: String?
    /// Multi-entry legs (empty for a plain single-row transaction).
    var legs: [UnifiedTransaction]
    /// The single transaction when not grouped.
    var single: UnifiedTransaction?

    var isGroup: Bool { !legs.isEmpty }

    /// Fold ledger rows into presentation entries: rows sharing a non-empty `group_id`
    /// become one summary entry; the net amount prefers the `net` leg, else sums the legs.
    static func entries(from transactions: [UnifiedTransaction],
                        categoryNames: [String: String] = [:]) -> [LedgerEntry] {
        var grouped: [String: [UnifiedTransaction]] = [:]
        var singles: [UnifiedTransaction] = []
        for txn in transactions {
            if let groupId = txn.groupId, !groupId.isEmpty {
                grouped[groupId, default: []].append(txn)
            } else {
                singles.append(txn)
            }
        }

        var entries = singles.map { txn in
            LedgerEntry(id: txn.transactionId, date: txn.date,
                        title: categoryNames[txn.categoryId ?? ""] ?? txn.categoryId ?? txn.type.rawValue,
                        netAmount: txn.amount, categoryId: txn.categoryId, legs: [], single: txn)
        }
        for (groupId, legs) in grouped {
            let sorted = legs.sorted { ($0.date, $0.transactionId) < ($1.date, $1.transactionId) }
            let net = sorted.first { $0.groupRole == .net }?.amount
                ?? sorted.reduce(Decimal(0)) { $0 + $1.amount }
            let roleTitle = sorted.contains { $0.groupRole == .gross } ? "Paycheck" : "Grouped entry"
            entries.append(LedgerEntry(
                id: "group-\(groupId)", date: sorted.first?.date ?? Date(),
                title: roleTitle, netAmount: net, categoryId: nil, legs: sorted, single: nil))
        }
        return entries.sorted { ($0.date, $0.id) > ($1.date, $1.id) }   // newest first
    }
}

struct LedgerTableView: View {
    @Environment(AppState.self) private var state
    let entries: [LedgerEntry]
    @State private var expanded: Set<String> = []

    var body: some View {
        if entries.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "list.bullet.rectangle", title: "No transactions",
                message: "Ledger rows for this account appear here."))
        } else {
            VStack(spacing: 0) {
                header
                ForEach(entries) { entry in
                    entryRow(entry)
                    if expanded.contains(entry.id) {
                        ForEach(entry.legs) { leg in legRow(leg) }
                    }
                    Divider().overlay(DS.Colors.borderSoft)
                }
            }
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
        }
    }

    private var header: some View {
        HStack {
            Text("DATE").frame(width: 90, alignment: .leading)
            Text("DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading)
            Text("AMOUNT").frame(width: 110, alignment: .trailing)
        }
        .font(DS.Fonts.tableHeader).foregroundStyle(DS.Colors.muted)
        .padding(.horizontal, 10).frame(height: 26)
        .background(DS.Colors.surfaceTint)
    }

    private func entryRow(_ entry: LedgerEntry) -> some View {
        Button {
            if entry.isGroup {
                if expanded.contains(entry.id) { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
            } else if let ref = entry.single?.sourceRef {
                state.inspect(ref)
            }
        } label: {
            HStack {
                Text(Format.date(entry.date)).font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink3)
                    .frame(width: 90, alignment: .leading)
                HStack(spacing: 6) {
                    if entry.isGroup {
                        Image(systemName: expanded.contains(entry.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold)).foregroundStyle(DS.Colors.muted)
                        Text(entry.title).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                        ValueProvenanceLabel(provenance: .derived)
                            .help("Summary row derived from \(entry.legs.count) legs")
                    } else {
                        Text(entry.title).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Format.money(entry.netAmount))
                    .font(DS.Fonts.tableNumeric)
                    .foregroundStyle(entry.netAmount < 0 ? DS.Colors.neg : DS.Colors.pos)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding(.horizontal, 10).frame(height: DS.Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func legRow(_ leg: UnifiedTransaction) -> some View {
        Button {
            if let ref = leg.sourceRef { state.inspect(ref) }
        } label: {
            HStack {
                Text("").frame(width: 90)
                Text(leg.groupRole?.rawValue ?? leg.type.rawValue)
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Format.money(leg.amount))
                    .font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink3)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding(.horizontal, 10).padding(.leading, 24)
            .frame(height: DS.Metrics.rowHeight - 6)
            .background(DS.Colors.surfaceSunken.opacity(0.6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LedgerTableView_Previews: PreviewProvider {
    static let legs = [
        UnifiedTransaction(transactionId: "T1", accountId: "A1", date: .now, amount: 5000,
                           groupId: "G", groupRole: .gross, sourceFile: "Accounts/transactions/2026-06.csv", sourceRow: 1),
        UnifiedTransaction(transactionId: "T2", accountId: "A1", date: .now, amount: -1000,
                           groupId: "G", groupRole: .withholding, sourceFile: "Accounts/transactions/2026-06.csv", sourceRow: 2),
        UnifiedTransaction(transactionId: "T3", accountId: "A1", date: .now, amount: 4000,
                           groupId: "G", groupRole: .net, sourceFile: "Accounts/transactions/2026-06.csv", sourceRow: 3),
        UnifiedTransaction(transactionId: "T4", accountId: "A1", date: .now, amount: -125.4,
                           categoryId: "C1", sourceFile: "Accounts/transactions/2026-06.csv", sourceRow: 4),
    ]

    static var previews: some View {
        LedgerTableView(entries: LedgerEntry.entries(from: legs, categoryNames: ["C1": "Groceries"]))
            .environment(AppState())
            .padding().frame(width: 640)
            .preferredColorScheme(.light).previewDisplayName("Ledger — light")
        LedgerTableView(entries: LedgerEntry.entries(from: legs))
            .environment(AppState())
            .padding().frame(width: 640)
            .preferredColorScheme(.dark).previewDisplayName("Ledger — dark")
    }
}
