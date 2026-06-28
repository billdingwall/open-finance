import Foundation

// T038 — Pure mapping from iCloud item attributes to the seven sync states (FR-012).
// Kept free of iCloud I/O so it is fully unit-testable without a ubiquity container.

public enum SyncStateMapper {

    public enum DownloadingStatus: Sendable, Equatable {
        case notDownloaded   // placeholder, not present locally
        case downloaded      // present but a newer version exists in iCloud
        case current         // present and up to date
    }

    /// The per-item iCloud attributes the mapping considers (from NSMetadataQuery / URL resource values).
    public struct ItemStatus: Sendable, Equatable {
        public var isDownloading: Bool
        public var isUploading: Bool
        public var downloadingStatus: DownloadingStatus
        public var hasUnresolvedConflicts: Bool

        public init(isDownloading: Bool = false, isUploading: Bool = false,
                    downloadingStatus: DownloadingStatus = .current,
                    hasUnresolvedConflicts: Bool = false) {
            self.isDownloading = isDownloading
            self.isUploading = isUploading
            self.downloadingStatus = downloadingStatus
            self.hasUnresolvedConflicts = hasUnresolvedConflicts
        }
    }

    /// Per-file sync state. Conflict takes precedence; then in-flight transfer; then local freshness.
    public static func fileState(_ s: ItemStatus) -> FileSyncState {
        if s.hasUnresolvedConflicts { return .conflictDetected }
        if s.isDownloading || s.isUploading { return .syncing }
        switch s.downloadingStatus {
        case .notDownloaded: return .fileMissingLocally
        case .downloaded:    return .localCopyStale
        case .current:       return .available
        }
    }

    /// Workspace-level state (precedes any per-file state).
    public static func workspaceState(signedIn: Bool, containerAvailable: Bool) -> SyncState {
        if !signedIn { return .notSignedIn }
        if !containerAvailable { return .containerUnavailable }
        return .available
    }
}
