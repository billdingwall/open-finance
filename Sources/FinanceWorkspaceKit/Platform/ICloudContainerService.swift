import Foundation

// T037 — v1 iCloud provider. Resolves the app-owned ubiquity container, exposes availability,
// and maps per-file sync state from the OS. Runtime requires the entitlement + a signed app;
// the state mapping (SyncStateMapper) is unit-tested independently.

public final class ICloudContainerService: CloudStorageProvider, @unchecked Sendable {

    public let containerIdentifier: String   // e.g. iCloud.com.<org>.OpenFinance

    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
    }

    public var providerKind: WorkspaceProviderKind { .iCloud }

    private var signedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)
    }

    public var isAvailable: Bool { signedIn && containerURL != nil }

    public var syncState: SyncState {
        SyncStateMapper.workspaceState(signedIn: signedIn, containerAvailable: containerURL != nil)
    }

    public func resolveWorkspaceURL() async throws -> URL {
        guard signedIn else { throw WorkspaceResolutionError.notSignedIn }
        guard let base = containerURL else { throw WorkspaceResolutionError.containerUnavailable }
        return base.appendingPathComponent("Documents/Finance", isDirectory: true)
    }

    public func syncState(for fileURL: URL) -> FileSyncState {
        let keys: Set<URLResourceKey> = [
            .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemIsUploadingKey, .ubiquitousItemHasUnresolvedConflictsKey,
        ]
        guard let values = try? fileURL.resourceValues(forKeys: keys) else { return .available }

        let status: SyncStateMapper.DownloadingStatus
        switch values.ubiquitousItemDownloadingStatus {
        case .some(.notDownloaded): status = .notDownloaded
        case .some(.downloaded):    status = .downloaded
        case .some(.current):       status = .current
        default:                    status = .current
        }
        let item = SyncStateMapper.ItemStatus(
            isDownloading: values.ubiquitousItemIsDownloading ?? false,
            isUploading: values.ubiquitousItemIsUploading ?? false,
            downloadingStatus: status,
            hasUnresolvedConflicts: values.ubiquitousItemHasUnresolvedConflicts ?? false)
        return SyncStateMapper.fileState(item)
    }

    /// Ask iCloud to start materialising a not-yet-downloaded file (FR-012, "File missing locally").
    public func startDownloading(_ fileURL: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
    }
}
