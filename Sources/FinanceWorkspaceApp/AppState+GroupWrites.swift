import SwiftUI
import FinanceWorkspaceKit

// Multi-entry transaction-group write behaviour on AppState (008 US2 — FR-005, T018/T019),
// split from AppState+WriteFlows for file-size hygiene. Group authoring, whole-group edit
// (atomic delete+add rewrite keeping the group_id), and whole-group delete — every path through
// the one WriteService safe-write pipeline.

@MainActor
extension AppState {

    // MARK: - Multi-entry transaction groups (008 US2 · FR-005)

    /// Build an atomic multi-entry group plan (all legs → one monthly file) and open the write
    /// preview. No-op when the group does not reconcile (the engine returns nil — never partial).
    func presentGroupWrite(kind: MultiEntryKind, month: String, legs: [MultiEntryLeg]) {
        let groupId = "grp-" + UUID().uuidString.prefix(8).lowercased()
        guard let plan = MultiEntry.plan(kind: kind, month: month, groupId: groupId,
                                         legs: legs, header: monthlyLedgerHeader(month)) else { return }
        showingGroupEditor = false
        Task { @MainActor in self.presentWrite(plan) }
    }

    // MARK: - Whole-group ledger operations (008 US2 T019)

    /// "2026-06" from "Accounts/transactions/2026-06.csv"; nil for non-ledger paths.
    static func ledgerMonth(of relativePath: String) -> String? {
        let prefix = "Accounts/transactions/"
        guard relativePath.hasPrefix(prefix), relativePath.hasSuffix(".csv") else { return nil }
        return String(relativePath.dropFirst(prefix.count).dropLast(4))
    }

    /// Delete every leg of a multi-entry group as ONE atomic plan. Refuses to build a partial
    /// plan — if any leg's row can't be resolved, nothing is presented (a group never splits).
    func requestGroupDelete(legs: [UnifiedTransaction]) {
        guard let file = legs.first?.sourceFile, let month = Self.ledgerMonth(of: file),
              let text = readWorkspaceFile(file) else { return }
        let rows: [(rowRef: Int, line: String)] = legs.compactMap { leg in
            guard leg.sourceFile == file, let row = leg.sourceRow,
                  let line = dataLine(in: text, rowRef: row) else { return nil }
            return (row, line)
        }
        guard rows.count == legs.count, !rows.isEmpty else { return }
        presentWrite(MultiEntry.deletePlan(month: month, groupRows: rows))
    }

    /// Open the group editor pre-filled with an existing group's legs (whole-group edit).
    func presentGroupEditor(editing legs: [UnifiedTransaction]) {
        groupEditorLegs = legs
        showingGroupEditor = true
    }

    /// Whole-group EDIT: one atomic `FileChange` that deletes the old legs and appends the
    /// re-authored group in the same monthly file. The group keeps its `group_id`; the engine
    /// reconciliation check still gates the re-authored legs (never a partial or unbalanced group).
    func presentGroupRewrite(kind: MultiEntryKind, month: String, legs: [MultiEntryLeg],
                             replacing old: [UnifiedTransaction]) {
        guard let file = old.first?.sourceFile, Self.ledgerMonth(of: file) == month,
              let text = readWorkspaceFile(file) else { return }
        let groupId = old.first?.groupId ?? ("grp-" + UUID().uuidString.prefix(8).lowercased())
        guard let addPlan = MultiEntry.plan(kind: kind, month: month, groupId: groupId,
                                            legs: legs, header: monthlyLedgerHeader(month)),
              let adds = addPlan.changes.first?.rowDiffs else { return }
        let deletes: [WriteRowDiff] = old.compactMap { leg in
            guard leg.sourceFile == file, let row = leg.sourceRow,
                  let line = dataLine(in: text, rowRef: row) else { return nil }
            return WriteRowDiff(rowRef: row, kind: .delete(before: line), groupId: groupId)
        }
        guard deletes.count == old.count else { return }
        let change = FileChange(relativePath: file, expectedHash: nil, rowDiffs: deletes + adds)
        groupEditorLegs = nil
        showingGroupEditor = false
        Task { @MainActor in self.presentWrite(WritePlan(intent: .edit, changes: [change])) }
    }
}
