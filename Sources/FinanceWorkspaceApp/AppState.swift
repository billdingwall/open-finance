import SwiftUI
import FinanceWorkspaceKit

// T013 — the @Observable root state (extracted from the Phase-1 diagnostic shell and extended
// per data-model.md). Owns workspace/provider state, the load phase, the projections snapshot,
// navigation, the detail pane, and the session-only selectors. Overview is the default
// selection on launch (FR-002). No API here mutates workspace files (FR-032).

enum AppConfig {
    // Reverse-DNS, iCloud.-prefixed ubiquity container identifier (must match the entitlement).
    static let iCloudContainerIdentifier = "iCloud.app.openfinance.FinanceWorkspace"
}

// MARK: - Detail pane state (FR-006)

/// A read-only dry-run repair preview (`RepairService.plan` output, presentation form).
struct RepairPreviewModel: Equatable {
    var issueRef: String
    var actionDescriptions: [String]
    var diffs: [RowDiff]
    var backupNote: String
}

/// The right-pane surfaces. `.editForm` exists for Phase 6 — unreachable in Phase 5 (write
/// affordances are visible but disabled, clarify Q3). Source-file / source-row surfaces were
/// folded into `.inspector` (they rendered identically); TaxArchiveView uses the
/// `SourceFilePreview` view directly.
enum DetailPaneSurface: Equatable {
    case inspector(SourceRef)
    case issueDetail(ValidationIssue)
    case repairPreview(RepairPreviewModel)
    case editForm(entityRef: String)
}

/// Closed by default, globally (locked decision); opens on main-panel selection.
struct DetailPaneState: Equatable {
    var isPresented = false
    var surface: DetailPaneSurface?

    mutating func present(_ surface: DetailPaneSurface) {
        self.surface = surface
        isPresented = true
    }
}

// MARK: - Session-only selectors (clarify Q1)

/// In-module selections; nil ⇒ "current/all". Reset on relaunch (never encoded into the
/// restoration payload).
struct SessionSelections: Equatable {
    var budgetPeriod: String?            // "YYYY-MM"
    var budgetHistoryMonths: Int = 6
    var portfolioAccountId: String?      // nil = all accounts
    var portfolioHeatMap = false         // standard ⇄ heat-map toggle
    var taxYear: Int?                    // nil = workspace settings year
}

// MARK: - Root state

@MainActor
@Observable
final class AppState {
    // Workspace/provider state (Phase 1 wiring, kept).
    var availability: WorkspaceAvailability = .available
    var syncState: SyncState = .available
    var workspaceURL: URL?
    var didProvision = false
    var missingPaths: [String] = []
    var needsR6Migration = false
    var lastError: String?

    // Phase 5 state.
    var phase: LoadPhase = .idle
    var projections: WorkspaceProjections?
    /// A re-index that failed while a prior snapshot is still shown — the views are stale but
    /// usable, so `phase` stays `.ready`; this signal makes the failure visible (not "Synced").
    var reindexError: String?
    var route: Route = .overview                 // Overview default (FR-002)
    var sidebarExpansion: Set<String> = ["accounts", "budget", "si", "taxes"]
    var detailPane = DetailPaneState()
    var selections = SessionSelections()

    // Phase 6 write flows: the plan awaiting confirmation drives the write-preview sheet.
    var pendingWrite: WritePlan?
    var writeError: String?
    // The entity add/edit form sheet (nil ⇒ closed).
    var editForm: EntityEditContext?
    // The CSV import sheet.
    var showingImport = false

    let provider: any CloudStorageProvider
    private let manager: WorkspaceManager

    var router: AppRouter { AppRouter(state: self) }

    init() {
        #if DEBUG
        provider = LocalFolderProvider()
        #else
        provider = ICloudContainerService(containerIdentifier: AppConfig.iCloudContainerIdentifier)
        #endif
        manager = WorkspaceManager(provider: provider)
    }

    /// Resolve + provision-on-first-run, then build the first projections snapshot.
    func openWorkspace() async {
        do {
            let state = try await manager.openWorkspace()
            workspaceURL = state.workspace?.rootURL
            availability = state.availability
            syncState = provider.syncState
            didProvision = state.didProvision
            missingPaths = state.missingPaths
            if let url = workspaceURL { needsR6Migration = MigrationService().isPreR6(workspaceURL: url) }
        } catch {
            lastError = String(describing: error)
            availability = .containerUnavailable
            phase = .failed(lastError ?? "workspace unavailable")
            Diagnostics.workspace.error("openWorkspace failed: \(self.lastError ?? "", privacy: .public)")
            return
        }
        await reindex()
    }

    /// Rebuild the snapshot (menu ⌘R / launch). The previous snapshot stays visible until the
    /// new one swaps in — one main-actor assignment, never mixed state (FR-036).
    func reindex() async {
        guard let workspaceURL else { return }
        phase = projections == nil ? .indexing : phase   // keep .ready during a re-index
        syncState = provider.syncState
        do {
            let snapshot = try await ProjectionStore.build(workspaceURL: workspaceURL)
            projections = snapshot                        // atomic swap
            phase = .ready
            reindexError = nil                            // a good build clears any prior failure
            route = AppRouter.resolve(route, in: snapshot) // drop stale entity selections
        } catch {
            lastError = String(describing: error)
            if projections == nil {
                phase = .failed(lastError ?? "index failed")
            } else {
                // Keep the still-valid snapshot visible, but surface that it is now stale.
                reindexError = lastError
            }
            Diagnostics.workspace.error("reindex failed: \(self.lastError ?? "", privacy: .public)")
        }
    }

    // MARK: - Selection → detail pane (read-only actions)

    /// Row selection opens the inspector surface (selection-driven, DESIGN.md contract).
    func inspect(_ ref: SourceRef) {
        detailPane.present(.inspector(ref))
    }

    func showIssue(_ issue: ValidationIssue) {
        detailPane.present(.issueDetail(issue))
    }

    /// Read-only repair preview scoped to ONE issue: `RepairService.plan` is a dry run —
    /// nothing is written and apply is deferred to Phase 6 (FR-016). `plan` builds `actions`
    /// and `diffs` in lockstep (one of each per repairable condition), so we pair them and keep
    /// only those matching this issue's rule id — preferring an exact file match. When nothing
    /// matches we say so, rather than showing every repair in the workspace.
    func previewRepair(for issue: ValidationIssue) {
        guard let workspaceURL else { return }
        do {
            let plan = try RepairService().plan(workspaceURL: workspaceURL)
            let pairs = Array(zip(plan.actions, plan.diffs))
            let sameRule = pairs.filter { $0.0.issueRef == issue.ruleId }
            let exactFile = sameRule.filter { $0.1.filePath == issue.filePath }
            let matched = exactFile.isEmpty ? sameRule : exactFile   // narrow to the file when possible

            guard !matched.isEmpty else {
                detailPane.present(.repairPreview(RepairPreviewModel(
                    issueRef: issue.id,
                    actionDescriptions: ["No auto-repair is available for this issue."],
                    diffs: [],
                    backupNote: "")))
                return
            }
            detailPane.present(.repairPreview(RepairPreviewModel(
                issueRef: issue.id,
                actionDescriptions: matched.map { "\($0.0.kind.rawValue): \($0.0.preview)" },
                diffs: matched.map(\.1),
                backupNote: "A timestamped backup is created before any apply (Phase 6).")))
        } catch {
            detailPane.present(.repairPreview(RepairPreviewModel(
                issueRef: issue.id,
                actionDescriptions: ["Repair preview unavailable: \(error)"],
                diffs: [],
                backupNote: "")))
        }
    }

    // MARK: - Write flows (Phase 6)

    /// Whether the target file(s) of the pending write are writable right now (sync gate, FR-005).
    /// Returns the first blocking reason, or nil when every touched file may be written.
    var writeBlockReason: String? {
        guard let plan = pendingWrite else { return nil }
        for change in plan.changes {
            let decision = WriteGate.evaluate(workspaceState: syncState, fileState: .available)
            if !decision.allowed { return decision.reason ?? "Writing is unavailable for \(change.relativePath)." }
        }
        return nil
    }

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

    /// Apply the pending plan through the safe-write path, then re-index + re-validate (FR-008).
    func applyPendingWrite() async {
        guard let plan = pendingWrite, let workspaceURL else { return }
        do {
            let service = WriteService(workspaceURL: workspaceURL)
            _ = try service.apply(plan, workspaceState: syncState, fileStates: [:])
            pendingWrite = nil
            writeError = nil
            await reindex()
        } catch {
            writeError = String(describing: error)
            Diagnostics.workspace.error("write failed: \(String(describing: error), privacy: .public)")
        }
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
        for (i, column) in header.enumerated() { fields[column] = i < cells.count ? cells[i] : "" }
        editForm = EntityEditContext(title: "Edit", relativePath: ref.filePath, columns: header,
                                     idColumn: header.first ?? "id", fields: fields, rowRef: row,
                                     before: before, fileText: text)
    }

    /// Build a delete plan for the row a source reference points at, scanning for referencing rows
    /// and expanding the delete + reassignments into one atomic plan (FR-019–022, SC-005). Rows that
    /// reference the deleted id are reassigned to the first available same-collection target, or
    /// unlinked/removed where the reference is nullable/list-valued. The preview shows every change.
    func requestDelete(_ ref: SourceRef) {
        guard let row = ref.rowNumber, let text = readWorkspaceFile(ref.filePath),
              let before = dataLine(in: text, rowRef: row),
              let header = CSVRowSerializer.header(of: text) else { return }
        // The deleted row's id (primary key = first column) and its collection.
        let cells = CSVLine.fields(before)
        let deletedId = cells.first ?? ""
        guard let subtype = Self.parentSubtype(forFile: ref.filePath),
              let context = projections?.context else {
            presentWrite(WritePlanBuilder.delete(rowRef: row, before: before, in: ref.filePath))
            return
        }
        _ = header
        let scanner = ReferenceScanner(context: context)
        let groups = scanner.referencesTo(id: deletedId, parentSubtype: subtype)
        guard !groups.isEmpty else {
            presentWrite(WritePlanBuilder.delete(rowRef: row, before: before, in: ref.filePath))
            return
        }
        // Default reassignment target: first available id that is not itself being deleted (FR-022).
        let target = scanner.reassignTargets(parentSubtype: subtype, excluding: [deletedId]).first

        // Assemble modify diffs for every referencing row, grouped by file, plus the delete.
        var diffsByFile: [String: [WriteRowDiff]] = [ref.filePath: [
            WriteRowDiff(rowRef: row, kind: .delete(before: before)),
        ]]
        for group in groups {
            for rowRef in group.rows {
                guard let refText = readWorkspaceFile(rowRef.relativePath),
                      let refHeader = CSVRowSerializer.header(of: refText),
                      let refLine = dataLine(in: refText, rowRef: rowRef.rowRef),
                      let colIndex = refHeader.firstIndex(of: group.column) else { continue }
                var refCells = CSVLine.fields(refLine)
                while refCells.count < refHeader.count { refCells.append("") }
                refCells[colIndex] = reassignedValue(current: refCells[colIndex], deletedId: deletedId,
                                                     target: group.nullable ? target ?? "" : target ?? "",
                                                     unlink: group.nullable && target == nil,
                                                     isList: group.isList)
                let after = refCells.enumerated().map { CSVRowSerializer.escape($1) }.joined(separator: ",")
                diffsByFile[rowRef.relativePath, default: []].append(
                    WriteRowDiff(rowRef: rowRef.rowRef, kind: .modify(before: refLine, after: after)))
            }
        }
        let changes = diffsByFile.map { FileChange(relativePath: $0.key, expectedHash: nil, rowDiffs: $0.value) }
        presentWrite(WritePlan(intent: .delete, changes: changes, references: groups))
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
        case .accounts:
            presentAdd(relativePath: "Accounts/accounts.csv", title: "New account",
                       idColumn: "account_id", idPrefix: "acct-")
        case .budget:
            presentAdd(relativePath: "Budget/categories.csv", title: "New category",
                       idColumn: "category_id", idPrefix: "cat-")
        case .savingsInvestments:
            presentAdd(relativePath: "Savings/goals.csv", title: "New savings goal",
                       idColumn: "goal_id", idPrefix: "goal-")
        case .taxes:
            presentAdd(relativePath: "Taxes/tax-adjustments.csv", title: "New tax adjustment",
                       idColumn: "tax_adjustment_id", idPrefix: "adj-")
        default:
            break   // Overview has no primary add target.
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
        let plan = ImportMapper().writePlan(from: batch) { month in
            let rel = "Accounts/transactions/\(month).csv"
            if let text = readWorkspaceFile(rel), let header = CSVRowSerializer.header(of: text) { return header }
            return ["transaction_id", "account_id", "date", "amount", "type"]   // header for a new month
        }
        presentWrite(plan)
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
        var i = 0
        while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("#") { i += 1 }
        let dataLines = Array(lines.dropFirst(i + 1))       // skip comments + header
        var rows: [[String: String]] = []
        var provenance: [(file: String, row: Int)] = []
        for (offset, line) in dataLines.enumerated() {
            let cells = CSVLine.fields(line)
            var row: [String: String] = [:]
            for (c, column) in header.enumerated() where c < cells.count { row[column] = cells[c] }
            rows.append(row)
            provenance.append((file: rel, row: offset + 1))
        }
        let csv = ExportService().csv(rows: rows, columns: header, provenance: provenance)
        return ((rel as NSString).lastPathComponent, csv)
    }

    /// Write exported text to a user-chosen destination (never inside the workspace).
    func writeExport(_ text: String, to destination: URL) {
        do { try ExportService().write(text, to: destination, workspaceURL: workspaceURL) }
        catch { writeError = String(describing: error) }
    }

    // MARK: - File helpers

    private func readWorkspaceFile(_ relativePath: String) -> String? {
        guard let workspaceURL else { return nil }
        return try? String(contentsOf: workspaceURL.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// The raw data-row line at a 1-based index (skipping leading `#` comments and the header).
    private func dataLine(in fileText: String, rowRef: Int) -> String? {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var i = 0
        while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("#") { i += 1 }
        let idx = i + 1 + (rowRef - 1)   // + header
        guard idx >= 0 && idx < lines.count else { return nil }
        return lines[idx]
    }
}
