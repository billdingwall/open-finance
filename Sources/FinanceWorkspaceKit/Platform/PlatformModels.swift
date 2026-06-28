import Foundation

// T005 — Platform models (Workspace, FileRecord, SyncStatus, Manifest, FileChangeEvent).
// The manifest is a device-local, regenerable cache; it is never authoritative over file bytes.

/// Which storage backend resolved the workspace.
public enum WorkspaceProviderKind: String, Codable, Sendable, CaseIterable {
    case iCloud
    case localFolder
}

/// Workspace-level availability (distinct from per-file sync state).
public enum WorkspaceAvailability: String, Codable, Sendable, CaseIterable {
    case available
    case notSignedIn
    case containerUnavailable
    case missing          // resolved location exists but required paths absent
}

/// The seven workspace/file sync states (FR-012). Derived from NSMetadataQuery for iCloud.
public enum SyncState: String, Codable, Sendable, CaseIterable {
    case available
    case notSignedIn
    case containerUnavailable
    case syncing
    case localCopyStale
    case fileMissingLocally
    case conflictDetected
}

/// Per-file sync condition used by the write gate.
public typealias FileSyncState = SyncState

/// Domain classification for an indexed file (FR-007). `meta` = the root Workspace.md descriptor.
public enum FileDomain: String, Codable, Sendable, CaseIterable {
    case accounts, budget, savings, investments, taxes, notes, meta
}

/// Validation roll-up recorded per file in the manifest (populated in Phase 2).
public enum FileValidationStatus: String, Codable, Sendable, CaseIterable {
    case ok, warning, error, unvalidated
}

/// The user-owned `Finance/` file tree (the source of truth).
public struct Workspace: Codable, Equatable, Sendable, Identifiable {
    public var id: String          // workspace_id
    public var rootURL: URL
    public var provider: WorkspaceProviderKind
    public var requiredPaths: [String]
    public var availability: WorkspaceAvailability

    public init(id: String, rootURL: URL, provider: WorkspaceProviderKind,
                requiredPaths: [String], availability: WorkspaceAvailability) {
        self.id = id
        self.rootURL = rootURL
        self.provider = provider
        self.requiredPaths = requiredPaths
        self.availability = availability
    }
}

/// One indexed file. Never authoritative over the file bytes.
public struct FileRecord: Codable, Equatable, Sendable, Identifiable {
    public var path: String        // workspace-relative
    public var domain: FileDomain
    public var subtype: String
    public var schemaVersion: Int
    public var hash: String        // "sha256:<hex>"
    public var modifiedAt: Date
    public var byteSize: Int
    public var rowCount: Int
    public var lastIndexedAt: Date
    public var validationStatus: FileValidationStatus

    public var id: String { path }

    public init(path: String, domain: FileDomain, subtype: String, schemaVersion: Int,
                hash: String, modifiedAt: Date, byteSize: Int, rowCount: Int,
                lastIndexedAt: Date, validationStatus: FileValidationStatus = .unvalidated) {
        self.path = path
        self.domain = domain
        self.subtype = subtype
        self.schemaVersion = schemaVersion
        self.hash = hash
        self.modifiedAt = modifiedAt
        self.byteSize = byteSize
        self.rowCount = rowCount
        self.lastIndexedAt = lastIndexedAt
        self.validationStatus = validationStatus
    }
}

/// Device-local, regenerable index snapshot (Application Support; NOT synced). FR-011.
public struct Manifest: Codable, Equatable, Sendable {
    public var manifestSchemaVersion: Int
    public var appVersion: String
    public var workspaceId: String
    public var lastIndexedAt: Date
    public var files: [FileRecord]

    public init(manifestSchemaVersion: Int = 1, appVersion: String, workspaceId: String,
                lastIndexedAt: Date, files: [FileRecord]) {
        self.manifestSchemaVersion = manifestSchemaVersion
        self.appVersion = appVersion
        self.workspaceId = workspaceId
        self.lastIndexedAt = lastIndexedAt
        self.files = files
    }
}

/// Emitted by FileIndexService on each detected delta (FR-009). Transient, not persisted.
public struct FileChangeEvent: Equatable, Sendable {
    public enum Kind: String, Sendable { case added, changed, deleted }
    public var kind: Kind
    public var path: String
    public var fileRecord: FileRecord?   // nil for .deleted

    public init(kind: Kind, path: String, fileRecord: FileRecord?) {
        self.kind = kind
        self.path = path
        self.fileRecord = fileRecord
    }
}
