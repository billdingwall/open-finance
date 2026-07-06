import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 7 (008) US6 T046 — BackupPruneService retention (last 10 + 30 days, whichever more
// conservative = keep if rank ≤ 10 OR age ≤ 30d) + race-safety of the newest backup.

@Suite struct BackupPruneTests {

    /// A temp backups dir; caller cleans up.
    private func makeBackupsDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-prune-\(UUID().uuidString)/backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Write an empty backup file named like `BackupService` produces: `<base>.<stamp>.bak`.
    @discardableResult
    private func writeBackup(_ dir: URL, base: String, at date: Date) throws -> URL {
        let url = dir.appendingPathComponent("\(base).\(Self.stampFormatter.string(from: date)).bak")
        try Data("x".utf8).write(to: url)
        return url
    }

    @Test func keepsNewestTenPerFileEvenWhenOld() throws {
        let dir = try makeBackupsDir()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        let old = Date(timeIntervalSinceNow: -100 * 24 * 3600)   // 100 days ago
        // 12 old backups of one file: 2 should prune (beyond newest 10 AND >30d), 10 kept.
        for i in 0..<12 {
            try writeBackup(dir, base: "accounts.csv", at: old.addingTimeInterval(Double(i)))
        }
        let plan = try BackupPruneService(backupsDir: dir).plan()
        #expect(plan.keep.count == 10)
        #expect(plan.prune.count == 2)
    }

    @Test func keepsRecentBackupsBeyondTen() throws {
        let dir = try makeBackupsDir()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        let now = Date()
        // 15 backups all from today: all < 30d, so none prune despite exceeding 10.
        for i in 0..<15 {
            try writeBackup(dir, base: "goals.csv", at: now.addingTimeInterval(Double(-i)))
        }
        let plan = try BackupPruneService(backupsDir: dir).plan(now: now)
        #expect(plan.prune.isEmpty)
        #expect(plan.keep.count == 15)
    }

    @Test func retentionIsPerSourceFile() throws {
        let dir = try makeBackupsDir()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        let old = Date(timeIntervalSinceNow: -100 * 24 * 3600)
        for i in 0..<11 { try writeBackup(dir, base: "accounts.csv", at: old.addingTimeInterval(Double(i))) }
        for i in 0..<11 { try writeBackup(dir, base: "goals.csv", at: old.addingTimeInterval(Double(i))) }
        let plan = try BackupPruneService(backupsDir: dir).plan()
        // Each file prunes exactly its 1 oldest-beyond-ten.
        #expect(plan.prune.count == 2)
        #expect(plan.keep.count == 20)
    }

    @Test func applyRemovesOnlyPlannedFiles() throws {
        let dir = try makeBackupsDir()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        let old = Date(timeIntervalSinceNow: -100 * 24 * 3600)
        for i in 0..<12 { try writeBackup(dir, base: "accounts.csv", at: old.addingTimeInterval(Double(i))) }
        let service = BackupPruneService(backupsDir: dir)
        let removed = try service.prune()
        #expect(removed == 2)
        let remaining = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        #expect(remaining.count == 10)
    }

    @Test func ignoresNonBackupFilesAndIsIdempotent() throws {
        let dir = try makeBackupsDir()
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        try Data("readme".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        let old = Date(timeIntervalSinceNow: -100 * 24 * 3600)
        for i in 0..<12 { try writeBackup(dir, base: "accounts.csv", at: old.addingTimeInterval(Double(i))) }
        let service = BackupPruneService(backupsDir: dir)
        #expect(try service.prune() == 2)
        #expect(try service.prune() == 0)   // idempotent
        // Non-backup file untouched.
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("notes.txt").path))
    }
}
