import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T027 / SC-004 — a repairable defect is fixed, logged, and re-applying is a no-op (idempotent).

@Suite struct RepairTests {

    private func provisioned() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-repair-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        try WorkspaceProvisioner().provision(at: ws)
        return ws
    }

    @Test func createsMissingFileAndFolderLogsAndIsIdempotent() throws {
        let ws = try provisioned()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let fm = FileManager.default

        // Introduce repairable defects.
        try fm.removeItem(at: ws.appendingPathComponent("Savings"))
        try fm.removeItem(at: ws.appendingPathComponent("Budget/categories.csv"))

        let service = RepairService()
        let entries = try service.apply(workspaceURL: ws)

        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.result == .applied })
        #expect(fm.fileExists(atPath: ws.appendingPathComponent("Savings").path))
        #expect(fm.fileExists(atPath: ws.appendingPathComponent("Budget/categories.csv").path))

        // Repair log written.
        let log = try String(contentsOf: ws.appendingPathComponent(".finance-meta/logs/repair-log.csv"),
                             encoding: .utf8)
        #expect(log.contains("Budget/categories.csv,createFile,,applied"))

        // Idempotent: a second apply finds nothing.
        let again = try service.apply(workspaceURL: ws)
        #expect(again.isEmpty)
    }
}
