import Foundation

// iCloud Drive folder provider for the direct-download (non-MAS) distribution. Targets a dedicated
// app folder inside the user's own iCloud Drive — ~/Library/Mobile Documents/com~apple~CloudDocs/
// OpenFinance/Finance — which syncs via fileproviderd WITHOUT the ubiquity-container entitlement or
// provisioned signing that `ICloudContainerService` requires. Trade-offs vs the container:
//   • no NSMetadataQuery ubiquitous scopes (needs the entitlement) — the FSEvents watcher path is
//     used instead, exactly like `LocalFolderProvider`;
//   • per-file sync state still works: files inside CloudDocs ARE ubiquitous items, so the same
//     URL-resource-key mapping applies, plus detection of evicted ".<name>.icloud" placeholders;
//   • the app must NOT be sandboxed for this path (the App Sandbox blocks Mobile Documents) — the
//     SwiftPM-bundled release uses this provider; the sandboxed/entitled Xcode target keeps the
//     container provider. First access triggers a one-time macOS Files-and-Folders consent prompt,
//     which onboarding Step 1 surfaces as a retryable failure state if declined.
// All reads/writes on top of this provider go through the existing Phase-1 safe-write primitives
// (FileCoordinatorService / BackupService / WriteService) — this type only resolves locations and
// reports state; it never bypasses them.

public struct CloudDocsProvider: CloudStorageProvider {

    /// The app's dedicated folder name inside iCloud Drive (visible to the user in Finder).
    public let appFolderName: String

    /// ~/Library/Mobile Documents/com~apple~CloudDocs — note the tilde-escaped container name;
    /// "com.apple.CloudDocs" (dots) does not exist on disk.
    public static var cloudDocsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    public init(appFolderName: String = "OpenFinance") {
        self.appFolderName = appFolderName
    }

    public var providerKind: WorkspaceProviderKind { .cloudDocs }

    /// Signed into iCloud at all? `ubiquityIdentityToken` needs no entitlement and is nil when
    /// signed out. iCloud *Drive* being enabled is what materialises the CloudDocs directory.
    private var signedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var cloudDocsAvailable: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: Self.cloudDocsRoot.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    public var isAvailable: Bool { signedIn && cloudDocsAvailable }

    public var syncState: SyncState {
        SyncStateMapper.workspaceState(signedIn: signedIn, containerAvailable: cloudDocsAvailable)
    }

    /// …/com~apple~CloudDocs/OpenFinance/Finance — same "Finance/" workspace-root convention as
    /// the other providers, so WorkspaceManager/Provisioner behave identically.
    public func resolveWorkspaceURL() async throws -> URL {
        guard signedIn else { throw WorkspaceResolutionError.notSignedIn }
        guard cloudDocsAvailable else { throw WorkspaceResolutionError.containerUnavailable }
        return Self.cloudDocsRoot
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
    }

    /// Create the dedicated app folder (and probe writability). The first touch of Mobile
    /// Documents triggers the macOS consent prompt; a denial surfaces here as a thrown error the
    /// onboarding failure state renders with a retry. Idempotent.
    @discardableResult
    public func ensureAppFolder() throws -> URL {
        guard signedIn else { throw WorkspaceResolutionError.notSignedIn }
        guard cloudDocsAvailable else { throw WorkspaceResolutionError.containerUnavailable }
        let folder = Self.cloudDocsRoot.appendingPathComponent(appFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Writability probe: creating the directory can succeed from cache while TCC denies file
        // writes — a zero-byte probe fails fast instead of failing later mid-bootstrap.
        let probe = folder.appendingPathComponent(".openfinance-probe")
        try Data().write(to: probe, options: .atomic)
        try? FileManager.default.removeItem(at: probe)
        return folder
    }

    // MARK: - Per-file sync state

    /// Evicted CloudDocs files are replaced on disk by a ".<name>.icloud" placeholder.
    static func placeholderURL(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).icloud")
    }

    /// Same resource-key mapping as the container provider (CloudDocs files are ubiquitous
    /// items), with an explicit dataless-placeholder check for evicted files.
    public func syncState(for fileURL: URL) -> FileSyncState {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path),
           fm.fileExists(atPath: Self.placeholderURL(for: fileURL).path) {
            return .fileMissingLocally
        }

        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemIsUploadingKey, .ubiquitousItemHasUnresolvedConflictsKey,
        ]
        guard let values = try? fileURL.resourceValues(forKeys: keys),
              values.isUbiquitousItem == true else {
            // Not (yet) a synced item — readable on disk means writable for our purposes.
            return .available
        }

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

    /// Ask fileproviderd to re-materialise an evicted file (mirrors the container provider).
    public func startDownloading(_ fileURL: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
    }
}
