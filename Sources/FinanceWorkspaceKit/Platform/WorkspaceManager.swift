import Foundation

// T023/T025 — Resolve the workspace via the active provider, provision on first run,
// validate required paths, and remember/restore the last active workspace.

/// Snapshot of workspace state exposed to the UI.
public struct WorkspaceState: Sendable, Equatable {
    public var workspace: Workspace?
    public var availability: WorkspaceAvailability
    public var missingPaths: [String]
    public var didProvision: Bool

    public init(workspace: Workspace?, availability: WorkspaceAvailability,
                missingPaths: [String], didProvision: Bool) {
        self.workspace = workspace
        self.availability = availability
        self.missingPaths = missingPaths
        self.didProvision = didProvision
    }
}

// UserDefaults is thread-safe; the provider and provisioner are Sendable.
public struct WorkspaceManager: @unchecked Sendable {
    public static let lastWorkspaceDefaultsKey = "openfinance.lastWorkspacePath"

    private let provider: any CloudStorageProvider
    private let defaults: UserDefaults
    private let provisioner = WorkspaceProvisioner()

    public init(provider: any CloudStorageProvider, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
    }

    /// Resolve → (optionally provision) → validate. Persists the resolved path as the last workspace.
    public func openWorkspace(provisionIfMissing: Bool = true) async throws -> WorkspaceState {
        guard provider.isAvailable else {
            return WorkspaceState(workspace: nil, availability: providerUnavailability(),
                                  missingPaths: [], didProvision: false)
        }

        let url = try await provider.resolveWorkspaceURL()
        var didProvision = false
        if provisionIfMissing {
            let outcome = try provisioner.provision(at: url)
            didProvision = outcome.didCreateAnything
            if didProvision {
                Diagnostics.workspace.info(
                    "Provisioned workspace: \(outcome.createdFolders.count) folders, \(outcome.createdFiles.count) files")
            }
        }

        let missing = validateRequiredPaths(at: url)
        let availability: WorkspaceAvailability = missing.isEmpty ? .available : .missing
        if !missing.isEmpty {
            Diagnostics.workspace.error("Workspace missing required paths: \(missing.joined(separator: ", "), privacy: .public)")
        }

        defaults.set(url.path, forKey: Self.lastWorkspaceDefaultsKey)

        let workspace = Workspace(
            id: WorkspaceLayout.workspaceId,
            rootURL: url,
            provider: provider.providerKind,
            requiredPaths: WorkspaceLayout.requiredFolders + WorkspaceLayout.requiredFiles,
            availability: availability)

        return WorkspaceState(workspace: workspace, availability: availability,
                              missingPaths: missing, didProvision: didProvision)
    }

    /// Required folders + files that are absent (FR-005). Empty == complete.
    public func validateRequiredPaths(at url: URL) -> [String] {
        let fm = FileManager.default
        let all = WorkspaceLayout.requiredFolders + WorkspaceLayout.requiredFiles
        return all.filter { !fm.fileExists(atPath: url.appendingPathComponent($0).path) }
    }

    public func lastWorkspacePath() -> String? {
        defaults.string(forKey: Self.lastWorkspaceDefaultsKey)
    }

    private func providerUnavailability() -> WorkspaceAvailability {
        switch provider.syncState {
        case .notSignedIn: return .notSignedIn
        case .containerUnavailable: return .containerUnavailable
        default: return .containerUnavailable
        }
    }
}
