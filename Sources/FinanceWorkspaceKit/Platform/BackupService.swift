import Foundation

// T018 — Timestamped backups before any write or repair (Constitution IV, FR-016).
// Exercised by write/repair flows in Phase 6; the primitive is established here.

public struct BackupService: Sendable {
    public let backupsDir: URL

    public init(backupsDir: URL) {
        self.backupsDir = backupsDir
    }

    /// Copy `fileURL` to a timestamped backup. Returns the backup URL (even if the source is absent,
    /// in which case nothing is copied — there is nothing to lose).
    @discardableResult
    public func backup(_ fileURL: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        let dest = backupsDir.appendingPathComponent("\(fileURL.lastPathComponent).\(Self.timestamp()).bak")
        if fm.fileExists(atPath: fileURL.path) {
            try fm.copyItem(at: fileURL, to: dest)
        }
        return dest
    }

    static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
