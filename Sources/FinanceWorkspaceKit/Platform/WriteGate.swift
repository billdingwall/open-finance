import Foundation

// T040 — Sync-first write gate (FR-013). A write is allowed only when the workspace is available
// AND the target file is locally available. Anything mid-sync defers the write.

public enum WriteGate {

    public struct Decision: Sendable, Equatable {
        public var allowed: Bool
        public var reason: String?
        public init(allowed: Bool, reason: String? = nil) {
            self.allowed = allowed
            self.reason = reason
        }
    }

    public static func evaluate(workspaceState: SyncState, fileState: FileSyncState) -> Decision {
        switch workspaceState {
        case .notSignedIn:          return Decision(allowed: false, reason: "Not signed into iCloud")
        case .containerUnavailable: return Decision(allowed: false, reason: "iCloud container unavailable")
        case .syncing:              return Decision(allowed: false, reason: "Workspace is syncing")
        default: break
        }
        switch fileState {
        case .available:
            return Decision(allowed: true)
        case .syncing, .fileMissingLocally:
            return Decision(allowed: false, reason: "File syncing — edits will be available shortly")
        case .localCopyStale:
            return Decision(allowed: false, reason: "Local copy is stale — waiting for the latest version")
        case .conflictDetected:
            return Decision(allowed: false, reason: "Resolve the file conflict before editing")
        case .notSignedIn, .containerUnavailable:
            return Decision(allowed: false, reason: "iCloud unavailable")
        }
    }

    public static func canWrite(workspaceState: SyncState, fileState: FileSyncState) -> Bool {
        evaluate(workspaceState: workspaceState, fileState: fileState).allowed
    }
}
