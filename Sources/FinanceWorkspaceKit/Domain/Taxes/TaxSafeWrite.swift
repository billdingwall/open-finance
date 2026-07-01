import Foundation

// US3 — the two stateful tax actions (standard-adjustment seed, year-close archive) reuse the Phase-1
// safe-write primitives: timestamped backup → sync-coordinated atomic apply → repair-log entry
// (constitution P-IV/P-VII). Never reimplements safe-write logic (CLAUDE.md rule).

enum TaxSafeWrite {
    private static let logPath = ".finance-meta/logs/repair-log.csv"

    /// Write `content` to `relativePath`, backing up any existing file first and logging the action.
    static func write(_ content: String, to relativePath: String, in workspaceURL: URL,
                      actionKind: String) throws {
        let url = workspaceURL.appendingPathComponent(relativePath)
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        var backupName: String?
        if fm.fileExists(atPath: url.path) {
            let backups = BackupService(backupsDir: workspaceURL.appendingPathComponent(".finance-meta/backups"))
            backupName = try backups.backup(url).lastPathComponent
        }
        try FileCoordinatorService().coordinatedWrite(url) { try Data(content.utf8).write(to: $0, options: .atomic) }
        try appendLog(workspaceURL: workspaceURL, targetFile: relativePath, actionKind: actionKind, backupPath: backupName)
    }

    private static func appendLog(workspaceURL: URL, targetFile: String, actionKind: String, backupPath: String?) throws {
        let url = workspaceURL.appendingPathComponent(logPath)
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let iso = ISO8601DateFormatter()
        let line = [iso.string(from: Date()), targetFile, actionKind, backupPath ?? "", "applied"].joined(separator: ",")
        if fm.fileExists(atPath: url.path) {
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            try Data((existing + line + "\n").utf8).write(to: url, options: .atomic)
        } else {
            let header = "# schema_version: 1\ntimestamp,target_file,action_kind,backup_path,result\n"
            try Data((header + line + "\n").utf8).write(to: url, options: .atomic)
        }
    }
}
