import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T029 / FR-013 — preview mode produces a plan/diff but writes nothing.

@Suite struct RepairPreviewTests {

    @Test func previewProducesDiffAndWritesNothing() throws {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-repair-preview-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        try WorkspaceProvisioner().provision(at: ws)

        let fm = FileManager.default
        try fm.removeItem(at: ws.appendingPathComponent("Budget/categories.csv"))

        let plan = try RepairService().plan(workspaceURL: ws)
        #expect(!plan.actions.isEmpty)
        #expect(plan.requiresConfirmation)
        #expect(plan.diffs.contains { $0.filePath == "Budget/categories.csv" && $0.before == "(absent)" })

        // Preview wrote nothing — the file is still missing.
        #expect(!fm.fileExists(atPath: ws.appendingPathComponent("Budget/categories.csv").path))
    }
}
