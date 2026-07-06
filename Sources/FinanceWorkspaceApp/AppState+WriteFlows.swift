import SwiftUI
import FinanceWorkspaceKit

// Phase 6 (007) — the write-flow behaviour on AppState (kept in an extension to keep the root state
// type focused). Every mutation routes through the safe-write preview → apply path; nothing here
// reimplements backup/coordination (that lives in the Kit `WriteService`).

@MainActor
extension AppState {

    // MARK: - Write preview / apply

    /// Whether the target file(s) of the pending write are writable right now (sync gate, FR-005).
    var writeBlockReason: String? {
        guard let plan = pendingWrite else { return nil }
        for change in plan.changes {
            let decision = WriteGate.evaluate(workspaceState: syncState, fileState: .available)
            if !decision.allowed { return decision.reason ?? "Writing is unavailable for \(change.relativePath)." }
        }
        return nil
    }

    /// Why writes are unavailable right now (no workspace / sync gate), or nil when writing is
    /// allowed. Drives the disabled state + tooltip of every top-level write affordance (008 FR-003).
    var writeGateReason: String? {
        guard workspaceURL != nil else { return "Open a workspace to make changes." }
        let decision = WriteGate.evaluate(workspaceState: syncState, fileState: .available)
        return decision.allowed ? nil : (decision.reason ?? "Writing is paused while the workspace syncs.")
    }

    /// Whether the visible write actions (Import / Add / Edit) are enabled right now (008 FR-001/003).
    var writesEnabled: Bool { writeGateReason == nil }

    /// Stamp the plan with current file hashes (drift baseline) and open the write-preview sheet.
    func presentWrite(_ plan: WritePlan) {
        guard let workspaceURL else { return }
        pendingWrite = WriteService(workspaceURL: workspaceURL).preview(plan)
        writeError = nil
    }

    func cancelWrite() {
        pendingWrite = nil
        writeError = nil
    }

    /// Apply the pending plan through the safe-write path, then re-index + re-validate (FR-008)
    /// and prune backups beyond the retention policy (008 FR-025).
    func applyPendingWrite() async {
        guard let plan = pendingWrite, let workspaceURL else { return }
        do {
            _ = try WriteService(workspaceURL: workspaceURL).apply(plan, workspaceState: syncState, fileStates: [:])
            pendingWrite = nil
            writeError = nil
            await reindex()
            pruneBackups()
        } catch {
            writeError = String(describing: error)
            Diagnostics.workspace.error("write failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Prune `.finance-meta/backups/` beyond the retention policy (008 FR-025) — called after each
    /// successful write and once on launch. Best-effort: a prune failure never blocks the app.
    func pruneBackups() {
        guard let workspaceURL else { return }
        let dir = workspaceURL.appendingPathComponent(".finance-meta/backups", isDirectory: true)
        _ = try? BackupPruneService(backupsDir: dir).prune()
    }

    // MARK: - Structured add/edit/delete (US1)

    /// Open the add form for a target file, seeding a fresh id in `idColumn`.
    func presentAdd(relativePath: String, title: String, idColumn: String, idPrefix: String) {
        guard let text = readWorkspaceFile(relativePath),
              let header = CSVRowSerializer.header(of: text) else { return }
        var fields = Dictionary(uniqueKeysWithValues: header.map { ($0, "") })
        fields[idColumn] = idPrefix + UUID().uuidString.prefix(8).lowercased()
        editForm = EntityEditContext(title: title, relativePath: relativePath, columns: header,
                                     idColumn: idColumn, fields: fields, rowRef: nil, before: nil,
                                     fileText: text)
    }

    /// Open the edit form for the row a source reference points at.
    func presentEdit(_ ref: SourceRef) {
        guard let row = ref.rowNumber, let text = readWorkspaceFile(ref.filePath),
              let header = CSVRowSerializer.header(of: text),
              let before = dataLine(in: text, rowRef: row) else { return }
        let cells = CSVLine.fields(before)
        var fields: [String: String] = [:]
        for (index, column) in header.enumerated() { fields[column] = index < cells.count ? cells[index] : "" }
        editForm = EntityEditContext(title: "Edit", relativePath: ref.filePath, columns: header,
                                     idColumn: header.first ?? "id", fields: fields, rowRef: row,
                                     before: before, fileText: text)
    }

    /// Open the edit form for the row in `relativePath` whose first (id) column equals `id`.
    /// Lets a dedicated screen edit its own entity without carrying a `SourceRef` (008 FR-002).
    func presentEditEntity(relativePath: String, id: String) {
        guard let text = readWorkspaceFile(relativePath),
              let row = Self.dataRowNumber(of: id, in: text) else { return }
        presentEdit(SourceRef(filePath: relativePath, rowNumber: row, provenance: .userEdited))
    }

    // Per-entity add/edit entry points — the single place the file/id-column/prefix map lives, so
    // the ⌘N command, the page-title actions, the sidebar, and empty-state CTAs all agree (FR-001).
    func addAccount() {
        presentAdd(relativePath: "Accounts/accounts.csv", title: "New account",
                   idColumn: "account_id", idPrefix: "acct-")
    }
    func addAccountGroup() {
        presentAdd(relativePath: "Accounts/account-groups.csv", title: "New account group",
                   idColumn: "account_group_id", idPrefix: "grp-")
    }
    func addCategory() {
        presentAdd(relativePath: "Budget/categories.csv", title: "New category",
                   idColumn: "category_id", idPrefix: "cat-")
    }
    func addGoal() {
        presentAdd(relativePath: "Savings/goals.csv", title: "New savings goal",
                   idColumn: "goal_id", idPrefix: "goal-")
    }
    func addBudget() {
        presentAdd(relativePath: "Budget/budgets.csv", title: "New budget",
                   idColumn: "budget_id", idPrefix: "bgt-")
    }
    func addTaxAdjustment() {
        presentAdd(relativePath: "Taxes/tax-adjustments.csv", title: "New tax adjustment",
                   idColumn: "tax_adjustment_id", idPrefix: "adj-")
    }

    func editAccount(_ id: String) { presentEditEntity(relativePath: "Accounts/accounts.csv", id: id) }
    func editAccountGroup(_ id: String) { presentEditEntity(relativePath: "Accounts/account-groups.csv", id: id) }
    func editCategory(_ id: String) { presentEditEntity(relativePath: "Budget/categories.csv", id: id) }
    func editGoal(_ id: String) { presentEditEntity(relativePath: "Savings/goals.csv", id: id) }

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

        let target = scanner.reassignTargets(parentSubtype: subtype, excluding: [deletedId]).first
        var diffsByFile: [String: [WriteRowDiff]] = [ref.filePath: [
            WriteRowDiff(rowRef: row, kind: .delete(before: before)),
        ]]
        for group in groups {
            for referencing in group.rows {
                if let modify = reassignDiff(group: group, at: referencing, deletedId: deletedId, target: target) {
                    diffsByFile[referencing.relativePath, default: []].append(modify)
                }
            }
        }
        let changes = diffsByFile.map { FileChange(relativePath: $0.key, expectedHash: nil, rowDiffs: $0.value) }
        presentWrite(WritePlan(intent: .delete, changes: changes, references: groups))
    }

    /// Build the modify diff that reassigns one referencing row away from the deleted id.
    private func reassignDiff(group: ReferenceGroup, at referencing: RowRef,
                              deletedId: String, target: String?) -> WriteRowDiff? {
        guard let refText = readWorkspaceFile(referencing.relativePath),
              let refHeader = CSVRowSerializer.header(of: refText),
              let refLine = dataLine(in: refText, rowRef: referencing.rowRef),
              let colIndex = refHeader.firstIndex(of: group.column) else { return nil }
        var refCells = CSVLine.fields(refLine)
        while refCells.count < refHeader.count { refCells.append("") }
        refCells[colIndex] = reassignedValue(current: refCells[colIndex], deletedId: deletedId,
                                             target: target ?? "", unlink: group.nullable && target == nil,
                                             isList: group.isList)
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

    /// Called by the form on submit: build the add/edit plan and hand off to the write preview.
    func finishEditForm(context: EntityEditContext, fields: [String: String]) {
        let plan: WritePlan
        if let rowRef = context.rowRef, let before = context.before {
            plan = WritePlanBuilder.edit(fields: fields, rowRef: rowRef, before: before,
                                         in: context.relativePath, fileText: context.fileText)
        } else {
            plan = WritePlanBuilder.add(fields: fields, to: context.relativePath, fileText: context.fileText)
        }
        editForm = nil
        // Hop to the next runloop so the form sheet fully dismisses before the preview sheet opens.
        Task { @MainActor in self.presentWrite(plan) }
    }

    // MARK: - ⌘N add-record (context-sensitive, FR-030a)

    /// Whether the active module has a primary object the ⌘N action can add.
    var activeModuleHasAddTarget: Bool {
        switch route.parentModule {
        case .accounts, .budget, .savingsInvestments, .taxes: return true
        default: return false
        }
    }

    /// Add a new record of the active module's primary object type.
    func presentAddForActiveModule() {
        switch route.parentModule {
        case .accounts: addAccount()
        case .budget: addCategory()
        case .savingsInvestments: addGoal()
        case .taxes: addTaxAdjustment()
        default: break   // Overview has no primary add target.
        }
    }

    // MARK: - Repair apply (US5, FR-023/026)

    /// Whether the current detail-pane selection is an auto-repairable issue.
    var hasRepairableSelection: Bool {
        if case .issueDetail(let issue) = detailPane.surface { return issue.repairClass == .auto }
        if case .repairPreview = detailPane.surface { return true }
        return false
    }

    /// Apply the deterministic auto-repairs, then re-index + re-validate so resolved issues clear.
    func applyRepair() async {
        guard let workspaceURL else { return }
        do {
            _ = try RepairService().apply(workspaceURL: workspaceURL)
            await reindex()
            detailPane.isPresented = false
        } catch {
            writeError = String(describing: error)
            Diagnostics.workspace.error("repair apply failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Close Tax Year (FR-011a)

    /// Archive the given tax year via the existing safe-write engine, then re-index.
    func closeTaxYear(_ year: Int) async {
        guard let workspaceURL else { return }
        do {
            if !TaxPrepEngine().isYearClosed(workspaceURL: workspaceURL, year: year) {
                _ = try TaxPrepEngine().archiveYear(workspaceURL: workspaceURL, year: year)
            }
            await reindex()
        } catch {
            writeError = String(describing: error)
            Diagnostics.workspace.error("year-close failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Import (US2)

    /// Turn a confirmed import batch into an append plan and open the write preview.
    func applyImport(batch: ImportBatch, mapping: ColumnMapping) {
        let plan = ImportMapper().writePlan(from: batch) { self.monthlyLedgerHeader($0) }
        presentWrite(plan)
    }

    /// The canonical header for a monthly ledger file: the existing file's header, or — for a
    /// brand-new month — a seed that includes `description` (008 US2) and the multi-entry
    /// `group_id`/`group_role` columns so grouped writes link correctly.
    func monthlyLedgerHeader(_ month: String) -> [String] {
        let rel = "Accounts/transactions/\(month).csv"
        if let text = readWorkspaceFile(rel), let header = CSVRowSerializer.header(of: text) { return header }
        return ["transaction_id", "account_id", "date", "amount", "description", "type",
                "category_id", "group_id", "group_role"]
    }

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

    // MARK: - Export (US6, FR-027)

    /// The active module's primary file, exported by ⌘E.
    private var activeExportFile: String? {
        switch route.parentModule {
        case .accounts: return "Accounts/accounts.csv"
        case .budget: return "Budget/categories.csv"
        case .savingsInvestments: return "Savings/goals.csv"
        case .taxes: return "Taxes/tax-adjustments.csv"
        default: return nil
        }
    }

    /// Build a CSV of the active module's primary file with source-provenance columns.
    func exportCurrentViewCSV() -> (suggestedName: String, text: String)? {
        guard let rel = activeExportFile, let text = readWorkspaceFile(rel),
              let header = CSVRowSerializer.header(of: text) else { return nil }
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") { lines.removeLast() }
        var start = 0
        while start < lines.count && lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("#") { start += 1 }
        let dataLines = Array(lines.dropFirst(start + 1))       // skip comments + header
        var rows: [[String: String]] = []
        var provenance: [(file: String, row: Int)] = []
        for (offset, line) in dataLines.enumerated() {
            let cells = CSVLine.fields(line)
            var row: [String: String] = [:]
            for (columnIndex, column) in header.enumerated() where columnIndex < cells.count {
                row[column] = cells[columnIndex]
            }
            rows.append(row)
            provenance.append((file: rel, row: offset + 1))
        }
        let csv = ExportService().csv(rows: rows, columns: header, provenance: provenance)
        return ((rel as NSString).lastPathComponent, csv)
    }

    /// Write exported text to a user-chosen destination (never inside the workspace).
    func writeExport(_ text: String, to destination: URL) {
        do {
            try ExportService().write(text, to: destination, workspaceURL: workspaceURL)
        } catch {
            writeError = String(describing: error)
        }
    }

    // MARK: - File helpers

    func readWorkspaceFile(_ relativePath: String) -> String? {
        guard let workspaceURL else { return nil }
        return try? String(contentsOf: workspaceURL.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// The raw data-row line at a 1-based index (skipping leading `#` comments and the header).
    func dataLine(in fileText: String, rowRef: Int) -> String? {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var start = 0
        while start < lines.count && lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("#") { start += 1 }
        let index = start + 1 + (rowRef - 1)   // + header
        guard index >= 0 && index < lines.count else { return nil }
        return lines[index]
    }

    /// The 1-based data-row index (skipping leading `#` comments + the header) whose first field
    /// equals `id` — the inverse of `dataLine(in:rowRef:)`, used to edit an entity by its id.
    static func dataRowNumber(of id: String, in fileText: String) -> Int? {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var start = 0
        while start < lines.count && lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("#") { start += 1 }
        let dataLines = lines.dropFirst(start + 1)   // skip the header row
        for (offset, line) in dataLines.enumerated() where CSVLine.fields(line).first == id {
            return offset + 1
        }
        return nil
    }
}
