import Foundation

// Phase 7 (008) US6 T046 — backup retention. Bounds `.finance-meta/backups/` growth without losing
// the recent safety net (Constitution IV — safe writes; the backups exist so a write is reversible).
//
// Policy (spec FR-025, clarify 2026-07-06 "last 10 AND >30 days, whichever more conservative"):
// a backup is **pruned** when it is BOTH beyond the 10 most-recent for its source file AND older
// than 30 days — i.e. keep = (rank ≤ 10) OR (age ≤ 30d). This is the data-safe reading: the last 10
// backups of every file are always kept, and every backup < 30 days old is kept, so no recent
// safety net is ever dropped while old, superseded backups of churny files are reclaimed.
//
// Trigger: after each successful write and once on launch (single-process app → no write is in
// flight during a prune, so there is nothing to race; the just-written backup is among the newest
// and is retained by construction).

public struct BackupPruneService: Sendable {
    public let backupsDir: URL
    public let keepPerFile: Int
    public let maxAge: TimeInterval

    /// - Parameters:
    ///   - keepPerFile: always retain this many most-recent backups per source file (default 10).
    ///   - maxAge: always retain backups younger than this (default 30 days).
    public init(backupsDir: URL, keepPerFile: Int = 10, maxAge: TimeInterval = 30 * 24 * 60 * 60) {
        self.backupsDir = backupsDir
        self.keepPerFile = keepPerFile
        self.maxAge = maxAge
    }

    /// The prune decision, computed without touching the filesystem (unit-testable).
    public struct Plan: Sendable, Equatable {
        public let prune: [URL]
        public let keep: [URL]
    }

    /// One parsed backup: `<base>.<yyyyMMdd-HHmmss-SSS>.bak` → (base source name, timestamp).
    private struct Entry {
        let url: URL
        let base: String
        let date: Date
    }

    /// Compute which backups to prune. Pure: no filesystem mutation.
    public func plan(now: Date = Date()) throws -> Plan {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil)
        else { return Plan(prune: [], keep: []) }

        // Parse managed backups; ignore anything that isn't `*.<timestamp>.bak`.
        var entries: [Entry] = []
        for url in names {
            guard let entry = Self.parse(url) else { continue }
            entries.append(entry)
        }

        var prune: [URL] = []
        var keep: [URL] = []
        // Group by source file, newest first, then apply keep = (rank ≤ N) OR (age ≤ maxAge).
        for (_, group) in Dictionary(grouping: entries, by: \.base) {
            let sorted = group.sorted { $0.date > $1.date }
            for (rank, entry) in sorted.enumerated() {
                let withinRecent = rank < keepPerFile
                let withinAge = now.timeIntervalSince(entry.date) <= maxAge
                if withinRecent || withinAge { keep.append(entry.url) } else { prune.append(entry.url) }
            }
        }
        return Plan(prune: prune.sorted { $0.path < $1.path },
                    keep: keep.sorted { $0.path < $1.path })
    }

    /// Apply the prune, deleting the planned files. Returns the number removed.
    @discardableResult
    public func prune(now: Date = Date()) throws -> Int {
        let plan = try plan(now: now)
        let fm = FileManager.default
        var removed = 0
        for url in plan.prune where (try? fm.removeItem(at: url)) != nil { removed += 1 }
        return removed
    }

    /// Parse `<base>.<yyyyMMdd-HHmmss-SSS>.bak`. Returns nil for non-backup files.
    private static func parse(_ url: URL) -> Entry? {
        let name = url.lastPathComponent
        guard name.hasSuffix(".bak") else { return nil }
        let stem = String(name.dropLast(4))                 // strip ".bak"
        guard let dot = stem.lastIndex(of: ".") else { return nil }
        let stamp = String(stem[stem.index(after: dot)...])  // trailing timestamp component
        let base = String(stem[..<dot])                      // source filename (may contain dots)
        guard !base.isEmpty, let date = formatter.date(from: stamp) else { return nil }
        return Entry(url: url, base: base, date: date)
    }

    /// Mirror of `BackupService.timestamp()` so parse and produce agree.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
