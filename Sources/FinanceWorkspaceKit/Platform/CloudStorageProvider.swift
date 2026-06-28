import Foundation

// T014 — The storage abstraction the rest of the app depends on instead of calling iCloud directly.

public enum WorkspaceResolutionError: Error, Sendable, Equatable {
    case notSignedIn
    case containerUnavailable
    case localFolderMissing
}

/// Minimum surface all storage backends implement (contracts/cloud-storage-provider.md).
public protocol CloudStorageProvider: Sendable {
    /// Whether the backend is usable right now.
    var isAvailable: Bool { get }
    /// Workspace-level sync state.
    var syncState: SyncState { get }
    /// Resolve the workspace root (…/Documents/Finance for iCloud; ~/Finance-Dev/Finance for local).
    func resolveWorkspaceURL() async throws -> URL
    /// Per-file sync state (drives the write gate).
    func syncState(for fileURL: URL) -> FileSyncState
}
