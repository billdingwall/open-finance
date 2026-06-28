import Foundation

// T041 — Manual conflict resolution (FR-014). v1 never auto-merges. The user chooses
// keep mine / keep iCloud / keep both. The resolution *plan* is pure and testable; the
// NSFileVersion application is code-only (needs a real conflict at runtime).

public enum ConflictChoice: String, Sendable, CaseIterable {
    case keepMine
    case keepiCloud
    case keepBoth
}

public struct ConflictResolutionPlan: Sendable, Equatable {
    public var keepCurrent: Bool        // keep the local current version as the file
    public var promoteOther: Bool       // promote the other (iCloud) version to be current
    public var preserveOtherAsCopy: Bool // keep the other version as a "(conflicted copy)" sibling
    public var markResolved: Bool       // mark all conflict versions resolved

    public init(keepCurrent: Bool, promoteOther: Bool, preserveOtherAsCopy: Bool, markResolved: Bool = true) {
        self.keepCurrent = keepCurrent
        self.promoteOther = promoteOther
        self.preserveOtherAsCopy = preserveOtherAsCopy
        self.markResolved = markResolved
    }

    /// No data is lost when at least one full version is retained (and for keepBoth, both are).
    public var preservesData: Bool { keepCurrent || promoteOther || preserveOtherAsCopy }
}

public enum ConflictResolver {

    public static func plan(for choice: ConflictChoice) -> ConflictResolutionPlan {
        switch choice {
        case .keepMine:
            return ConflictResolutionPlan(keepCurrent: true, promoteOther: false, preserveOtherAsCopy: false)
        case .keepiCloud:
            return ConflictResolutionPlan(keepCurrent: false, promoteOther: true, preserveOtherAsCopy: false)
        case .keepBoth:
            return ConflictResolutionPlan(keepCurrent: true, promoteOther: false, preserveOtherAsCopy: true)
        }
    }

    /// Sibling URL for a preserved conflicting copy, e.g. accounts (conflicted copy 1).csv
    public static func conflictedCopyURL(for url: URL, index: Int) -> URL {
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        let name = ext.isEmpty ? "\(stem) (conflicted copy \(index + 1))"
                               : "\(stem) (conflicted copy \(index + 1)).\(ext)"
        return url.deletingLastPathComponent().appendingPathComponent(name)
    }

    /// Apply the choice using NSFileVersion. Code-only: requires real unresolved conflict versions.
    public static func apply(_ choice: ConflictChoice, at url: URL) throws {
        let plan = plan(for: choice)
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []

        if plan.preserveOtherAsCopy {
            for (i, version) in conflicts.enumerated() {
                _ = try version.replaceItem(at: conflictedCopyURL(for: url, index: i), options: [])
            }
        }
        if plan.promoteOther, let latest = conflicts.max(by: {
            ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
        }) {
            _ = try latest.replaceItem(at: url, options: [])
        }
        if plan.markResolved {
            for version in conflicts { version.isResolved = true }
            try NSFileVersion.removeOtherVersionsOfItem(at: url)
        }
        Diagnostics.sync.info("Resolved conflict at \(url.lastPathComponent, privacy: .public) via \(choice.rawValue, privacy: .public)")
    }
}
