import SwiftUI
import FinanceWorkspaceKit

// Delete flows on AppState (split from AppState+WriteFlows.swift for file-length hygiene,
// spec 011). Delete is a first-class structured write (technical design §13): reference scan →
// reassignment picker → ONE atomic delete+reassignment plan → the standard write preview.
// Both entry points — the detail pane and the edit form (spec 011 UV-2) — share `requestDelete`.

@MainActor
extension AppState {

    /// Build a delete plan for the row a source reference points at, scanning for referencing rows
    /// and expanding the delete + reassignments into one atomic plan (FR-019–022, SC-005).
    func requestDelete(_ ref: SourceRef) {
        guard let row = ref.rowNumber, let text = readWorkspaceFile(ref.filePath),
              let before = dataLine(in: text, rowRef: row) else { return }
        let deletedId = CSVLine.fields(before).first ?? ""
        let simpleDelete = WritePlanBuilder.delete(rowRef: row, before: before, in: ref.filePath)
        guard let subtype = Self.parentSubtype(forFile: ref.filePath),
              let context = projections?.context else { return presentWrite(simpleDelete) }

        let scanner = ReferenceScanner(context: context)
        let groups = scanner.referencesTo(id: deletedId, parentSubtype: subtype)
        guard !groups.isEmpty else { return presentWrite(simpleDelete) }

        // Referenced object → the user chooses each collection's new target (T022 / OOS-17);
        // the previous first-available-target default is gone.
        pendingReassignment = ReassignmentModel(
            ref: ref, rowRef: row, before: before, deletedId: deletedId, groups: groups,
            targets: scanner.reassignTargets(parentSubtype: subtype, excluding: [deletedId]))
    }

    /// Build the atomic delete + reassignment plan from the picker's confirmed choices and hand
    /// it to the standard write preview (T022). One plan; the delete and every FK repoint apply
    /// together or not at all.
    func applyReassignments(_ model: ReassignmentModel) {
        guard model.canApply else { return }
        var diffsByFile: [String: [WriteRowDiff]] = [model.ref.filePath: [
            WriteRowDiff(rowRef: model.rowRef, kind: .delete(before: model.before)),
        ]]
        for reassignment in model.reassignments {
            for referencing in reassignment.group.rows {
                if let modify = reassignDiff(group: reassignment.group, at: referencing,
                                             deletedId: model.deletedId, target: reassignment.target) {
                    diffsByFile[referencing.relativePath, default: []].append(modify)
                }
            }
        }
        let changes = diffsByFile.map { FileChange(relativePath: $0.key, expectedHash: nil, rowDiffs: $0.value) }
        let plan = WritePlan(intent: .delete, changes: changes,
                             references: model.groups, reassignments: model.reassignments)
        pendingReassignment = nil
        Task { @MainActor in self.presentWrite(plan) }
    }

    /// Build the modify diff that reassigns one referencing row away from the deleted id.
    private func reassignDiff(group: ReferenceGroup, at referencing: RowRef,
                              deletedId: String, target: Reassignment.Target) -> WriteRowDiff? {
        guard let refText = readWorkspaceFile(referencing.relativePath),
              let refHeader = CSVRowSerializer.header(of: refText),
              let refLine = dataLine(in: refText, rowRef: referencing.rowRef),
              let colIndex = refHeader.firstIndex(of: group.column) else { return nil }
        var refCells = CSVLine.fields(refLine)
        while refCells.count < refHeader.count { refCells.append("") }
        let newValue: String
        switch target {
        case .unlink:
            newValue = reassignedValue(current: refCells[colIndex], deletedId: deletedId,
                                       target: "", unlink: true, isList: group.isList)
        case .reassign(let id):
            newValue = reassignedValue(current: refCells[colIndex], deletedId: deletedId,
                                       target: id, unlink: false, isList: group.isList)
        }
        refCells[colIndex] = newValue
        let after = refCells.map { CSVRowSerializer.escape($0) }.joined(separator: ",")
        return WriteRowDiff(rowRef: referencing.rowRef, kind: .modify(before: refLine, after: after))
    }

    /// New value for a referencing cell: replace/remove the deleted id (list) or repoint/clear it.
    private func reassignedValue(current: String, deletedId: String, target: String,
                                 unlink: Bool, isList: Bool) -> String {
        if isList {
            var members = current.split(separator: "|").map(String.init)
            members.removeAll { $0 == deletedId }
            if !unlink, !target.isEmpty, !members.contains(target) { members.append(target) }
            return members.joined(separator: "|")
        }
        return unlink ? "" : target
    }

    /// Map a workspace file to the `ReferenceScanner` parent-collection key.
    static func parentSubtype(forFile path: String) -> String? {
        switch path {
        case "Accounts/accounts.csv": return "registry"
        case "Accounts/account-groups.csv": return "account-groups"
        case "Accounts/liabilities.csv": return "liabilities"
        case "Budget/categories.csv": return "categories"
        case "Budget/budgets.csv": return "budgets"
        case "Savings/goals.csv": return "goals"
        case "Investments/assets.csv": return "assets"
        case "Investments/portfolios.csv": return "portfolios"
        case "Investments/sleeves.csv": return "sleeves"
        default: return nil
        }
    }

    /// Delete the entity being edited, from inside its edit form (spec 011 UV-2). Closes the
    /// form and enters the IDENTICAL pipeline as a detail-pane delete — the same `requestDelete`
    /// call, so reference scanning, the reassignment picker, atomicity, and the full write
    /// preview are inherited unchanged (SC-002/SC-004; deletes keep preview-before-apply — the
    /// v1.1.2 direct-manipulation carve-out does not cover destructive flows). The pipeline
    /// re-reads the file, so unsaved form edits are discarded and the preview shows the on-disk
    /// row. No-op in add mode (nothing exists to delete).
    func requestDeleteFromEditForm(_ context: EntityEditContext) {
        guard let rowRef = context.rowRef else { return }   // add mode
        editForm = nil
        let ref = SourceRef(filePath: context.relativePath, rowNumber: rowRef, provenance: .userEdited)
        // Core delete stays synchronous (analyze M1) so tests can assert pendingWrite/
        // pendingReassignment deterministically; only the sheet-dismiss-then-present hop, if
        // SwiftUI needs one, belongs in the view layer, not here.
        requestDelete(ref)
    }
}
