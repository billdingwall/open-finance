import Foundation

// T030 — Deterministic, previewable, backed-up auto-repair. Wired: create missing required folder,
// create missing seed file, and normalize header casing (a CSV-rewrite repair). Every apply is
// idempotent, backs up before modifying, and logs to .finance-meta/logs/repair-log.csv. Manual-only
// issues are never touched. Optional-column injection is intentionally deferred — proactively
// injecting every absent optional column would flag clean files (optional means optional); it needs
// a notion of "expected" optional columns first. Blank-field normalization likewise pending.

public struct RepairService: Sendable {

    private static let logPath = ".finance-meta/logs/repair-log.csv"
    private let coordinator: FileCoordinatorService
    private let registry: CSVSchemaRegistry

    public init(coordinator: FileCoordinatorService = FileCoordinatorService()) throws {
        self.coordinator = coordinator
        self.registry = try CSVSchemaRegistry()
    }

    // MARK: - Preview

    /// Scan for auto-repairable conditions and build a preview plan. Writes nothing (FR-013).
    public func plan(workspaceURL: URL, taxYear: Int = WorkspaceLayout.currentTaxYear()) throws -> RepairPlan {
        let fm = FileManager.default
        var actions: [RepairAction] = []
        var diffs: [RowDiff] = []

        // Missing required folders → createFolder.
        for folder in WorkspaceLayout.requiredFolders {
            let url = workspaceURL.appendingPathComponent(folder, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                actions.append(RepairAction(issueRef: "VAL-FILE-001", kind: .createFolder,
                                            preview: "create folder \(folder)"))
                diffs.append(RowDiff(filePath: folder, rowRef: nil, before: "(absent)", after: "(folder created)"))
            }
        }

        // Missing required seed files → createFile.
        let seeds = WorkspaceLayout.seedFiles(taxYear: taxYear)
        for file in WorkspaceLayout.requiredFiles {
            let url = workspaceURL.appendingPathComponent(file)
            if !fm.fileExists(atPath: url.path), let content = seeds[file] {
                actions.append(RepairAction(issueRef: "VAL-FILE-001", kind: .createFile,
                                            preview: "create seed file \(file)"))
                let firstLine = content.split(separator: "\n").first.map(String.init) ?? ""
                diffs.append(RowDiff(filePath: file, rowRef: nil, before: "(absent)",
                                     after: firstLine + " …"))
            }
        }

        // Normalize header casing on managed CSVs (a CSV-rewrite repair).
        for relativePath in WorkspaceParser.discover(in: workspaceURL) where relativePath.hasSuffix(".csv") {
            guard let schema = registry.schema(forRelativePath: relativePath) else { continue }
            let url = workspaceURL.appendingPathComponent(relativePath)
            guard let text = try? coordinator.coordinatedRead(url, { try String(contentsOf: $0, encoding: .utf8) }),
                  let fix = Self.headerCasingFix(text: text, schema: schema) else { continue }
            actions.append(RepairAction(issueRef: "VAL-FILE-012", kind: .normalizeHeader,
                                        preview: "normalize header casing \(relativePath)"))
            diffs.append(RowDiff(filePath: relativePath, rowRef: 0, before: fix.oldHeader, after: fix.newHeader))
        }

        return RepairPlan(actions: actions, diffs: diffs)
    }

    // MARK: - Apply

    /// Apply the auto-repairs. Backs up before any modify, writes atomically, logs every action,
    /// and is idempotent (a second apply finds nothing to do).
    @discardableResult
    public func apply(workspaceURL: URL, taxYear: Int = WorkspaceLayout.currentTaxYear()) throws -> [RepairLogEntry] {
        let fm = FileManager.default
        let plan = try plan(workspaceURL: workspaceURL, taxYear: taxYear)
        guard !plan.actions.isEmpty else { return [] }

        let seeds = WorkspaceLayout.seedFiles(taxYear: taxYear)
        var entries: [RepairLogEntry] = []

        for action in plan.actions {
            switch action.kind {
            case .createFolder:
                let folder = action.preview.replacingOccurrences(of: "create folder ", with: "")
                try fm.createDirectory(at: workspaceURL.appendingPathComponent(folder, isDirectory: true),
                                       withIntermediateDirectories: true)
                entries.append(.init(timestamp: Date(), targetFile: folder, actionKind: "createFolder",
                                     backupPath: nil, result: .applied))

            case .createFile:
                let file = action.preview.replacingOccurrences(of: "create seed file ", with: "")
                guard let content = seeds[file] else {
                    entries.append(.init(timestamp: Date(), targetFile: file, actionKind: "createFile",
                                         backupPath: nil, result: .failed))
                    continue
                }
                let url = workspaceURL.appendingPathComponent(file)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try coordinator.coordinatedWrite(url) { try Data(content.utf8).write(to: $0, options: .atomic) }
                entries.append(.init(timestamp: Date(), targetFile: file, actionKind: "createFile",
                                     backupPath: nil, result: .applied))

            case .normalizeHeader:
                let file = action.preview.replacingOccurrences(of: "normalize header casing ", with: "")
                let url = workspaceURL.appendingPathComponent(file)
                guard let schema = registry.schema(forRelativePath: file),
                      let text = try? coordinator.coordinatedRead(url, { try String(contentsOf: $0, encoding: .utf8) }),
                      let fix = Self.headerCasingFix(text: text, schema: schema) else {
                    entries.append(.init(timestamp: Date(), targetFile: file, actionKind: "normalizeHeader",
                                         backupPath: nil, result: .skipped))
                    continue
                }
                let backups = BackupService(backupsDir: workspaceURL.appendingPathComponent(".finance-meta/backups"))
                let backupURL = try backups.backup(url)
                try coordinator.coordinatedWrite(url) { try Data(fix.newText.utf8).write(to: $0, options: .atomic) }
                entries.append(.init(timestamp: Date(), targetFile: file, actionKind: "normalizeHeader",
                                     backupPath: backupURL.lastPathComponent, result: .applied))

            case .injectOptionalColumn:
                // Intentionally deferred (see type doc) — never silently applied.
                entries.append(.init(timestamp: Date(), targetFile: action.preview, actionKind: "injectOptionalColumn",
                                     backupPath: nil, result: .skipped))
            }
        }

        try appendLog(entries, workspaceURL: workspaceURL)
        return entries
    }

    // MARK: - Repair log

    private func appendLog(_ entries: [RepairLogEntry], workspaceURL: URL) throws {
        guard !entries.isEmpty else { return }
        let url = workspaceURL.appendingPathComponent(Self.logPath)
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let iso = ISO8601DateFormatter()
        var lines = entries.map { e in
            "\(iso.string(from: e.timestamp)),\(e.targetFile),\(e.actionKind),\(e.backupPath ?? ""),\(e.result.rawValue)"
        }
        if fm.fileExists(atPath: url.path) {
            let existing = try String(contentsOf: url, encoding: .utf8)
            try Data((existing + lines.joined(separator: "\n") + "\n").utf8).write(to: url, options: .atomic)
        } else {
            lines.insert("# schema_version: 1", at: 0)
            lines.insert("timestamp,target_file,action_kind,backup_path,result", at: 1)
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url, options: .atomic)
        }
    }

    // MARK: - Header casing repair

    struct HeaderFix: Sendable { let newText: String; let oldHeader: String; let newHeader: String }

    /// If the header has cells that map to a canonical column but differ in case/whitespace,
    /// return the file text with only the header line rewritten to canonical form (data untouched).
    static func headerCasingFix(text: String, schema: CSVSchema) -> HeaderFix? {
        var lines = text.components(separatedBy: "\n")
        guard let headerIdx = lines.firstIndex(where: {
            let t = $0.trimmingCharacters(in: .whitespaces); return !t.hasPrefix("#") && !t.isEmpty
        }) else { return nil }

        let oldHeader = lines[headerIdx]
        let cells = CSVParserService.tokenize(oldHeader).first ?? []
        let canonicalByLower = Dictionary(uniqueKeysWithValues: schema.columns.keys.map { ($0.lowercased(), $0) })

        var newCells = cells
        var changed = false
        for i in cells.indices {
            let key = cells[i].trimmingCharacters(in: .whitespaces).lowercased()
            if let canonical = canonicalByLower[key], cells[i] != canonical {
                newCells[i] = canonical
                changed = true
            }
        }
        guard changed else { return nil }

        lines[headerIdx] = newCells.map(csvEscape).joined(separator: ",")
        return HeaderFix(newText: lines.joined(separator: "\n"), oldHeader: oldHeader, newHeader: lines[headerIdx])
    }

    static func csvEscape(_ cell: String) -> String {
        if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
            return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return cell
    }
}
