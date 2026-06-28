import Foundation

// T030 — Read/write the device-local manifest. Stored in Application Support, OUTSIDE the synced
// workspace (FR-011). A missing or corrupt manifest returns nil so the caller rebuilds from scan.

public struct ManifestStore: @unchecked Sendable {
    public let containerRoot: URL   // …/Application Support/OpenFinance

    public static var defaultContainerRoot: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenFinance", isDirectory: true)
    }

    public init(containerRoot: URL = ManifestStore.defaultContainerRoot) {
        self.containerRoot = containerRoot
    }

    public func manifestURL(workspaceId: String) -> URL {
        containerRoot
            .appendingPathComponent(workspaceId, isDirectory: true)
            .appendingPathComponent("manifest.json")
    }

    /// Returns nil when the manifest is absent or corrupt — never throws, so a lost/garbage cache
    /// simply triggers a rebuild from the canonical files.
    public func load(workspaceId: String) -> Manifest? {
        let url = manifestURL(workspaceId: workspaceId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Manifest.self, from: data)
    }

    public func save(_ manifest: Manifest) throws {
        let dir = containerRoot.appendingPathComponent(manifest.workspaceId, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: dir.appendingPathComponent("manifest.json"))
    }
}
