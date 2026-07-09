import SwiftUI
import FinanceWorkspaceKit

// 008 US3 T031/T032 — manual pick-a-version conflict resolution (FR-012, P-IV: conflicts are
// resolved by explicit user choice over NSFileVersion, never auto-merged). The Kit's
// `ConflictResolver` owns the plan + application; this extension scans the workspace for files
// with unresolved conflict versions and applies the user's choice, then re-indexes. Real
// conflicts only arise on synced (iCloud) workspaces — on a local/dev workspace the scan is
// simply empty.

/// One file with unresolved iCloud conflict versions.
struct ConflictedFile: Identifiable, Equatable {
    struct OtherVersion: Equatable {
        var device: String
        var modified: Date?
    }
    let relativePath: String
    let others: [OtherVersion]
    var id: String { relativePath }
}

@MainActor
extension AppState {

    /// Scan managed files for unresolved `NSFileVersion` conflicts (on demand — cheap enough for
    /// a workspace-sized tree, and always current when the surface opens).
    func scanConflicts() -> [ConflictedFile] {
        guard let workspaceURL else { return [] }
        var found: [ConflictedFile] = []
        let enumerator = FileManager.default.enumerator(at: workspaceURL, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard ["csv", "md"].contains(url.pathExtension.lowercased()) else { continue }
            let rel = url.path.replacingOccurrences(of: workspaceURL.path + "/", with: "")
            guard !rel.hasPrefix(".finance-meta") else { continue }
            let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
            guard !versions.isEmpty else { continue }
            found.append(ConflictedFile(relativePath: rel, others: versions.map {
                ConflictedFile.OtherVersion(device: $0.localizedNameOfSavingComputer ?? "Another device",
                                            modified: $0.modificationDate)
            }))
        }
        return found.sorted { $0.relativePath < $1.relativePath }
    }

    /// Apply the user's explicit choice for one file, then re-index so projections reflect the
    /// surviving bytes. Keep-both preserves the other version as a "(conflicted copy)" sibling —
    /// no choice ever loses a full version (ConflictResolutionPlan.preservesData).
    func resolveConflict(relativePath: String, choice: ConflictChoice) async {
        guard let workspaceURL else { return }
        do {
            try ConflictResolver.apply(choice, at: workspaceURL.appendingPathComponent(relativePath))
            await reindex()
        } catch {
            lastError = String(describing: error)
            Diagnostics.sync.error("conflict resolution failed: \(String(describing: error), privacy: .public)")
        }
    }
}
