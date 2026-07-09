import Foundation
import CryptoKit

// Phase 6 (007) — the single safe-write path (FR-001–FR-008). Orchestrates:
//   WriteGate check (G3) → drift check (G4) → BackupService per touched file (G1) →
//   FileCoordinatorService atomic coordinated write (G2) → repair-log append (G5).
// It COMPOSES the Phase-1 primitives and never reimplements backup/coordination/logging (FR-002).

public struct WriteService: Sendable {

    private static let logPath = ".finance-meta/logs/repair-log.csv"

    private let workspaceURL: URL
    private let backups: BackupService
    private let coordinator: FileCoordinatorService

    public init(workspaceURL: URL,
                backups: BackupService? = nil,
                coordinator: FileCoordinatorService = FileCoordinatorService()) {
        self.workspaceURL = workspaceURL
        self.backups = backups ?? BackupService(
            backupsDir: workspaceURL.appendingPathComponent(".finance-meta/backups"))
        self.coordinator = coordinator
    }

    // MARK: - Preview

    /// Capture the current on-disk hash for each touched file so `apply` can detect drift (D8).
    /// Writes nothing.
    public func preview(_ plan: WritePlan) -> WritePlan {
        var stamped = plan
        stamped.changes = plan.changes.map { change in
            FileChange(relativePath: change.relativePath,
                       expectedHash: Self.hash(of: workspaceURL.appendingPathComponent(change.relativePath)),
                       rowDiffs: change.rowDiffs,
                       seedHeader: change.seedHeader)
        }
        return stamped
    }

    // MARK: - Apply

    /// Apply a plan atomically. Order matters: gate → drift → back up EVERY touched file → write.
    /// Any thrown error leaves not-yet-written files untouched; already-written files are restorable
    /// from their backups.
    @discardableResult
    public func apply(_ plan: WritePlan,
                      workspaceState: SyncState,
                      fileStates: [String: FileSyncState]) throws -> WriteResult {
        // G3 — sync gate: block before touching anything.
        for change in plan.changes {
            let fileState = fileStates[change.relativePath] ?? .available
            let decision = WriteGate.evaluate(workspaceState: workspaceState, fileState: fileState)
            if !decision.allowed {
                throw WriteError.syncGateBlocked(path: change.relativePath,
                                                 reason: decision.reason ?? "write not allowed")
            }
        }

        // G4 — drift: the file must match what preview saw.
        for change in plan.changes {
            let url = workspaceURL.appendingPathComponent(change.relativePath)
            let current = Self.hash(of: url)
            if let expected = change.expectedHash, expected != current {
                throw WriteError.driftDetected(path: change.relativePath)
            }
        }

        // G1 — back up every touched file before any modification.
        var backupRefs: [BackupReference] = []
        for change in plan.changes {
            let url = workspaceURL.appendingPathComponent(change.relativePath)
            do {
                let dest = try backups.backup(url)
                backupRefs.append(BackupReference(relativePath: change.relativePath,
                                                  backupName: dest.lastPathComponent))
            } catch {
                throw WriteError.backupFailed(path: change.relativePath)
            }
        }

        // G2 — atomic coordinated write of each file's new content.
        for change in plan.changes {
            let url = workspaceURL.appendingPathComponent(change.relativePath)
            var existing = (try? coordinator.coordinatedRead(url) { try String(contentsOf: $0, encoding: .utf8) }) ?? ""
            if existing.isEmpty, let header = change.seedHeader, !header.isEmpty {
                // Brand-new managed file: seed the schema comment + canonical header so the
                // created file is valid on its own (never headerless).
                existing = "# schema_version: 1\n" + header.joined(separator: ",") + "\n"
            }
            let updated = try CSVRowSerializer.applyDiffs(change.rowDiffs, to: existing,
                                                          relativePath: change.relativePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try coordinator.coordinatedWrite(url) { try Data(updated.utf8).write(to: $0, options: .atomic) }
        }

        // G5 — log every touched file.
        var logEntries: [String] = []
        for (change, backup) in zip(plan.changes, backupRefs) {
            let entry = try appendLog(targetFile: change.relativePath,
                                      actionKind: plan.intent.rawValue,
                                      backupName: backup.backupName)
            logEntries.append(entry)
        }

        return WriteResult(backups: backupRefs, touchedPaths: plan.touchedPaths, logEntries: logEntries)
    }

    // MARK: - Helpers

    /// SHA-256 of a file's bytes in the `sha256:<hex>` convention used by `FileIndexService`.
    /// Returns nil for a missing file (a fresh add has no prior content to drift against).
    static func hash(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private func appendLog(targetFile: String, actionKind: String, backupName: String) throws -> String {
        let url = workspaceURL.appendingPathComponent(Self.logPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let line = [ISO8601DateFormatter().string(from: Date()), targetFile, actionKind, backupName, "applied"]
            .joined(separator: ",")
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            try Data((existing + line + "\n").utf8).write(to: url, options: .atomic)
        } else {
            let header = "# schema_version: 1\ntimestamp,target_file,action_kind,backup_path,result\n"
            try Data((header + line + "\n").utf8).write(to: url, options: .atomic)
        }
        return line
    }
}
