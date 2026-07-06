import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 6 (007) T007 — WriteService safe-write guarantees (G1–G5) against a temp workspace.

@Suite struct WriteServiceTests {

    /// A temp workspace containing one goals file; caller cleans up.
    private func makeWorkspace() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-write-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        let goals = ws.appendingPathComponent("Savings/goals.csv")
        try FileManager.default.createDirectory(at: goals.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("""
        # schema_version: 1
        goal_id,name,target_amount
        goal-1,Emergency,10000
        """.utf8).write(to: goals)
        return ws
    }

    private func editPlan(_ ws: URL, service: WriteService) -> WritePlan {
        let change = FileChange(relativePath: "Savings/goals.csv", expectedHash: nil, rowDiffs: [
            WriteRowDiff(rowRef: 1, kind: .modify(before: "goal-1,Emergency,10000",
                                                  after: "goal-1,Emergency,12000")),
        ])
        return service.preview(WritePlan(intent: .edit, changes: [change]))
    }

    // G1 + happy path — backup taken before write; file updated; log written.
    @Test func applyBacksUpThenWritesAndLogs() throws {
        let ws = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let service = WriteService(workspaceURL: ws)

        let result = try service.apply(editPlan(ws, service: service),
                                       workspaceState: .available, fileStates: [:])

        // File updated.
        let text = try String(contentsOf: ws.appendingPathComponent("Savings/goals.csv"), encoding: .utf8)
        #expect(text.contains("goal-1,Emergency,12000"))
        // Backup exists.
        #expect(result.backups.count == 1)
        let backupDir = ws.appendingPathComponent(".finance-meta/backups")
        let backups = try FileManager.default.contentsOfDirectory(atPath: backupDir.path)
        #expect(backups.contains { $0.hasPrefix("goals.csv.") && $0.hasSuffix(".bak") })
        // Log written.
        let log = try String(contentsOf: ws.appendingPathComponent(".finance-meta/logs/repair-log.csv"), encoding: .utf8)
        #expect(log.contains("Savings/goals.csv,edit,"))
    }

    // G3 — a syncing workspace blocks the write; nothing changes.
    @Test func syncingWorkspaceBlocksWrite() throws {
        let ws = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let service = WriteService(workspaceURL: ws)
        let before = try String(contentsOf: ws.appendingPathComponent("Savings/goals.csv"), encoding: .utf8)

        #expect(throws: WriteError.self) {
            try service.apply(editPlan(ws, service: service), workspaceState: .syncing, fileStates: [:])
        }
        let after = try String(contentsOf: ws.appendingPathComponent("Savings/goals.csv"), encoding: .utf8)
        #expect(before == after)   // untouched
    }

    // G3 (per-file) — a conflicted target file blocks the write.
    @Test func conflictedFileBlocksWrite() throws {
        let ws = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let service = WriteService(workspaceURL: ws)
        #expect(throws: WriteError.self) {
            try service.apply(editPlan(ws, service: service),
                              workspaceState: .available,
                              fileStates: ["Savings/goals.csv": .conflictDetected])
        }
    }

    // G4 — a file that changed since preview is detected as drift and not overwritten.
    @Test func driftBetweenPreviewAndApplyIsRejected() throws {
        let ws = try FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-drift-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        let goals = ws.appendingPathComponent("Savings/goals.csv")
        try FileManager.default.createDirectory(at: goals.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("# schema_version: 1\ngoal_id,name,target_amount\ngoal-1,Emergency,10000".utf8).write(to: goals)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let service = WriteService(workspaceURL: ws)

        // Preview captures the current hash.
        let plan = service.preview(WritePlan(intent: .edit, changes: [
            FileChange(relativePath: "Savings/goals.csv", expectedHash: nil, rowDiffs: [
                WriteRowDiff(rowRef: 1, kind: .modify(before: "goal-1,Emergency,10000",
                                                      after: "goal-1,Emergency,12000")),
            ]),
        ]))
        // An external edit changes the file after preview.
        try Data("# schema_version: 1\ngoal_id,name,target_amount\ngoal-1,Emergency,99999".utf8).write(to: goals)

        #expect(throws: WriteError.self) {
            try service.apply(plan, workspaceState: .available, fileStates: [:])
        }
    }
}
