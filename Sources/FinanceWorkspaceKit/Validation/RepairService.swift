import Foundation

// T030 — Deterministic, previewable, backed-up auto-repair. Wired in this phase: create missing
// required folder and create missing required seed file (the constitution's headline self-healing
// repairs). Every apply is idempotent and logged to .finance-meta/logs/repair-log.csv. Manual-only
// issues are never touched. CSV-rewriting repairs (header-casing, optional-column injection,
// blank-field normalization) are catalog-known and pending.

public struct RepairService: Sendable {

    private static let logPath = ".finance-meta/logs/repair-log.csv"
    private let coordinator: FileCoordinatorService

    public init(coordinator: FileCoordinatorService = FileCoordinatorService()) {
        self.coordinator = coordinator
    }

    // MARK: - Preview

    /// Scan for auto-repairable conditions and build a preview plan. Writes nothing (FR-013).
    public func plan(workspaceURL: URL, taxYear: Int = WorkspaceLayout.currentTaxYear()) -> RepairPlan {
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

        return RepairPlan(actions: actions, diffs: diffs)
    }

    // MARK: - Apply

    /// Apply the auto-repairs. Backs up before any modify, writes atomically, logs every action,
    /// and is idempotent (a second apply finds nothing to do).
    @discardableResult
    public func apply(workspaceURL: URL, taxYear: Int = WorkspaceLayout.currentTaxYear()) throws -> [RepairLogEntry] {
        let fm = FileManager.default
        let plan = plan(workspaceURL: workspaceURL, taxYear: taxYear)
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

            case .normalizeHeader, .injectOptionalColumn:
                // CSV-rewriting repairs are pending; never silently applied.
                entries.append(.init(timestamp: Date(), targetFile: action.preview, actionKind: "\(action.kind)",
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
}
