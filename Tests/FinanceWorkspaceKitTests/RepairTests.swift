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

        let service = try RepairService()
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

    @Test func normalizesHeaderCasingWithBackupAndIsIdempotent() throws {
        let ws = try provisioned()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        let url = ws.appendingPathComponent("Accounts/account-groups.csv")
        try Data("# schema_version: 1\nACCOUNT_GROUP_ID,Name,GROUP_TYPE\ngrp-personal,Personal,personal\n".utf8)
            .write(to: url)

        let service = try RepairService()
        #expect(try service.plan(workspaceURL: ws).actions.contains { $0.kind == .normalizeHeader })

        let entries = try service.apply(workspaceURL: ws)
        let headerEntry = try #require(entries.first { $0.actionKind == "normalizeHeader" })
        #expect(headerEntry.result == .applied)
        #expect(headerEntry.backupPath != nil)   // existing file backed up before rewrite

        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines[1] == "account_group_id,name,group_type")
        #expect(lines[2] == "grp-personal,Personal,personal")   // data untouched

        // Idempotent — no header repair on a second pass.
        #expect(try service.plan(workspaceURL: ws).actions.filter { $0.kind == .normalizeHeader }.isEmpty)
    }
}
