import Testing
import Foundation
@testable import FinanceWorkspaceKit

@Suite struct SyncStateTests {

    // T035 / SC-005 — every one of the seven sync states is reachable and correctly mapped.
    @Test func allSevenStatesAreMapped() {
        // Workspace-level states.
        #expect(SyncStateMapper.workspaceState(signedIn: false, containerAvailable: false) == .notSignedIn)
        #expect(SyncStateMapper.workspaceState(signedIn: true, containerAvailable: false) == .containerUnavailable)
        #expect(SyncStateMapper.workspaceState(signedIn: true, containerAvailable: true) == .available)

        // Per-file states.
        #expect(SyncStateMapper.fileState(.init(hasUnresolvedConflicts: true)) == .conflictDetected)
        #expect(SyncStateMapper.fileState(.init(isDownloading: true)) == .syncing)
        #expect(SyncStateMapper.fileState(.init(isUploading: true)) == .syncing)
        #expect(SyncStateMapper.fileState(.init(downloadingStatus: .notDownloaded)) == .fileMissingLocally)
        #expect(SyncStateMapper.fileState(.init(downloadingStatus: .downloaded)) == .localCopyStale)
        #expect(SyncStateMapper.fileState(.init(downloadingStatus: .current)) == .available)

        // Conflict precedence over an in-flight transfer.
        #expect(SyncStateMapper.fileState(.init(isDownloading: true, hasUnresolvedConflicts: true)) == .conflictDetected)
    }

    // T035 / SC-005 / FR-013 — no write is allowed while anything is mid-sync.
    @Test func writeGateBlocksDuringSync() {
        // Only available+available permits a write.
        #expect(WriteGate.canWrite(workspaceState: .available, fileState: .available))

        // Workspace not ready blocks regardless of file.
        for ws in [SyncState.syncing, .notSignedIn, .containerUnavailable] {
            #expect(!WriteGate.canWrite(workspaceState: ws, fileState: .available), "ws \(ws) should block")
        }
        // File not ready blocks even when the workspace is available.
        for fs in [FileSyncState.syncing, .fileMissingLocally, .localCopyStale, .conflictDetected] {
            #expect(!WriteGate.canWrite(workspaceState: .available, fileState: fs), "file \(fs) should block")
        }

        // The block carries a user-facing reason.
        let decision = WriteGate.evaluate(workspaceState: .available, fileState: .syncing)
        #expect(decision.allowed == false)
        #expect(decision.reason != nil)
    }
}
