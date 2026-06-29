import Foundation

// T037 — One-time R6 migration for pre-R6 (prototype-era) workspaces. Detect-and-prompt (clarify
// Q5): callers detect, preview, then apply with confirmation — never silent. Renames the three
// legacy files/columns and folds the separate investment ledger into the unified monthly ledger as
// `type = trade` rows. Every modified/removed file is backed up. A no-op on an R6-native workspace.

public struct MigrationService: Sendable {

    public struct Plan: Sendable, Equatable {
        public var steps: [String]
        public var isNoOp: Bool { steps.isEmpty }
        public init(steps: [String]) { self.steps = steps }
    }

    private struct RenameSpec { let oldFile: String; let newFile: String; let columns: [String: String] }

    private static let renames: [RenameSpec] = [
        .init(oldFile: "Accounts/entities.csv", newFile: "Accounts/account-groups.csv",
              columns: ["entity_id": "account_group_id", "entity_type": "group_type"]),
        .init(oldFile: "Investments/holdings.csv", newFile: "Investments/assets.csv",
              columns: ["holding_id": "asset_id", "market_value": "current_value"]),
        .init(oldFile: "Taxes/deductions.csv", newFile: "Taxes/tax-adjustments.csv",
              columns: ["deduction_id": "tax_adjustment_id", "deduction_type": "adjustment_type"]),
    ]
    // Column-only renames applied in place (no file rename).
    private static let inPlaceRenames: [(file: String, columns: [String: String])] = [
        ("Accounts/accounts.csv", ["entity_id": "account_group_id"]),
    ]
    private static let investmentLedger = "Investments/transactions.csv"

    private let coordinator: FileCoordinatorService

    public init(coordinator: FileCoordinatorService = FileCoordinatorService()) {
        self.coordinator = coordinator
    }

    // MARK: - Detect / preview

    /// True when any pre-R6 artifact is present.
    public func isPreR6(workspaceURL: URL) -> Bool {
        let fm = FileManager.default
        let legacy = Self.renames.map(\.oldFile) + [Self.investmentLedger]
        if legacy.contains(where: { fm.fileExists(atPath: workspaceURL.appendingPathComponent($0).path) }) {
            return true
        }
        // accounts.csv still using the legacy entity_id column.
        return Self.hasLegacyColumn(workspaceURL: workspaceURL)
    }

    public func plan(workspaceURL: URL) -> Plan {
        let fm = FileManager.default
        var steps: [String] = []
        for spec in Self.renames where fm.fileExists(atPath: workspaceURL.appendingPathComponent(spec.oldFile).path) {
            steps.append("rename \(spec.oldFile) → \(spec.newFile) (columns: \(spec.columns.map { "\($0)→\($1)" }.sorted().joined(separator: ", ")))")
        }
        if Self.hasLegacyColumn(workspaceURL: workspaceURL) {
            steps.append("rename column entity_id → account_group_id in Accounts/accounts.csv")
        }
        let ledger = workspaceURL.appendingPathComponent(Self.investmentLedger)
        if fm.fileExists(atPath: ledger.path),
           let text = try? String(contentsOf: ledger, encoding: .utf8) {
            let rows = CSVParserService.tokenize(CSVParserService.stripLeadingComments(text).body).filter { !($0.count == 1 && $0[0].isEmpty) }
            let dataCount = max(0, rows.count - 1)
            steps.append("fold \(dataCount) row(s) from \(Self.investmentLedger) into the unified ledger as type=trade")
        }
        return Plan(steps: steps)
    }

    // MARK: - Apply

    @discardableResult
    public func apply(workspaceURL: URL) throws -> Plan {
        let plan = plan(workspaceURL: workspaceURL)
        guard !plan.isNoOp else { return plan }
        let fm = FileManager.default
        let backups = BackupService(backupsDir: workspaceURL.appendingPathComponent(".finance-meta/backups"))

        // 1. File + column renames.
        for spec in Self.renames {
            let old = workspaceURL.appendingPathComponent(spec.oldFile)
            guard fm.fileExists(atPath: old.path) else { continue }
            let text = try String(contentsOf: old, encoding: .utf8)
            try backups.backup(old)
            let renamed = Self.renameHeaderColumns(text: text, map: spec.columns)
            let new = workspaceURL.appendingPathComponent(spec.newFile)
            try fm.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
            try coordinator.coordinatedWrite(new) { try Data(renamed.utf8).write(to: $0, options: .atomic) }
            try fm.removeItem(at: old)
        }

        // 2. In-place column renames.
        for entry in Self.inPlaceRenames {
            let url = workspaceURL.appendingPathComponent(entry.file)
            guard fm.fileExists(atPath: url.path) else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            guard Self.headerContainsAny(text: text, columns: Array(entry.columns.keys)) else { continue }
            try backups.backup(url)
            let renamed = Self.renameHeaderColumns(text: text, map: entry.columns)
            try coordinator.coordinatedWrite(url) { try Data(renamed.utf8).write(to: $0, options: .atomic) }
        }

        // 3. Fold the investment ledger into the unified monthly ledger as type=trade rows.
        try foldInvestmentLedger(workspaceURL: workspaceURL, backups: backups)

        return plan
    }

    private func foldInvestmentLedger(workspaceURL: URL, backups: BackupService) throws {
        let fm = FileManager.default
        let ledger = workspaceURL.appendingPathComponent(Self.investmentLedger)
        guard fm.fileExists(atPath: ledger.path) else { return }
        let text = try String(contentsOf: ledger, encoding: .utf8)
        let rows = CSVParserService.tokenize(CSVParserService.stripLeadingComments(text).body)
            .filter { !($0.count == 1 && $0[0].isEmpty) }
        guard let header = rows.first else { return }
        let idx = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) })

        func value(_ row: [String], _ col: String) -> String {
            guard let i = idx[col], i < row.count else { return "" }
            return row[i]
        }

        // Group folded rows by month (YYYY-MM from the date column).
        let unifiedHeader = "transaction_id,account_id,date,amount,type,receiving_asset_id"
        var byMonth: [String: [String]] = [:]
        for row in rows.dropFirst() {
            let date = value(row, "date")
            let month = String(date.prefix(7))   // YYYY-MM
            guard month.count == 7 else { continue }
            let unified = [value(row, "transaction_id"), value(row, "account_id"), date,
                           value(row, "amount"), "trade", value(row, "asset_id")]
                .map(RepairService.csvEscape).joined(separator: ",")
            byMonth[month, default: []].append(unified)
        }

        for (month, dataRows) in byMonth {
            let monthURL = workspaceURL.appendingPathComponent("Accounts/transactions/\(month).csv")
            if fm.fileExists(atPath: monthURL.path) {
                try backups.backup(monthURL)
                let existing = try String(contentsOf: monthURL, encoding: .utf8)
                let combined = existing.hasSuffix("\n") ? existing : existing + "\n"
                try coordinator.coordinatedWrite(monthURL) {
                    try Data((combined + dataRows.joined(separator: "\n") + "\n").utf8).write(to: $0, options: .atomic)
                }
            } else {
                let content = "# schema_version: 1\n\(unifiedHeader)\n" + dataRows.joined(separator: "\n") + "\n"
                try fm.createDirectory(at: monthURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try coordinator.coordinatedWrite(monthURL) { try Data(content.utf8).write(to: $0, options: .atomic) }
            }
        }

        // The legacy ledger is folded in — back it up and remove it.
        try backups.backup(ledger)
        try fm.removeItem(at: ledger)
    }

    // MARK: - Helpers

    private static func hasLegacyColumn(workspaceURL: URL) -> Bool {
        let url = workspaceURL.appendingPathComponent("Accounts/accounts.csv")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return headerContainsAny(text: text, columns: ["entity_id"])
    }

    private static func headerContainsAny(text: String, columns: [String]) -> Bool {
        let lines = text.components(separatedBy: "\n")
        guard let header = lines.first(where: {
            let t = $0.trimmingCharacters(in: .whitespaces); return !t.hasPrefix("#") && !t.isEmpty
        }) else { return false }
        let cells = Set((CSVParserService.tokenize(header).first ?? []).map { $0.trimmingCharacters(in: .whitespaces) })
        return columns.contains { cells.contains($0) }
    }

    static func renameHeaderColumns(text: String, map: [String: String]) -> String {
        var lines = text.components(separatedBy: "\n")
        guard let hi = lines.firstIndex(where: {
            let t = $0.trimmingCharacters(in: .whitespaces); return !t.hasPrefix("#") && !t.isEmpty
        }) else { return text }
        var cells = CSVParserService.tokenize(lines[hi]).first ?? []
        for i in cells.indices {
            let key = cells[i].trimmingCharacters(in: .whitespaces)
            if let renamed = map[key] { cells[i] = renamed }
        }
        lines[hi] = cells.map(RepairService.csvEscape).joined(separator: ",")
        return lines.joined(separator: "\n")
    }
}
