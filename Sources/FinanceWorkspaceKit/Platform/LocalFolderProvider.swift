import Foundation

// T015 — DEBUG-default provider: a plain local folder, no iCloud / entitlement / signing.
// FSEvents-based watching is added in US2 (FileWatcherService).

public struct LocalFolderProvider: CloudStorageProvider {
    public let root: URL

    /// Default development root: ~/Finance-Dev
    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Finance-Dev")
    }

    public init(root: URL = LocalFolderProvider.defaultRoot) {
        self.root = root
    }

    public var isAvailable: Bool { true }

    /// A local folder is always "available" — the iCloud-only states do not arise here.
    public var syncState: SyncState { .available }

    public func resolveWorkspaceURL() async throws -> URL {
        root.appendingPathComponent("Finance", isDirectory: true)
    }

    public func syncState(for fileURL: URL) -> FileSyncState { .available }
}
