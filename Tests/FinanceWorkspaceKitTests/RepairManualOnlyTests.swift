import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T028 / SC-005 — auto-repair never modifies a manual-only issue (e.g. an unknown account
// reference). Repair only touches the deterministic auto set.

@Suite struct RepairManualOnlyTests {

    @Test func manualOnlyDefectIsNeverModified() throws {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-repair-manual-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        try WorkspaceProvisioner().provision(at: ws)

        // A transactions file with an unknown account_id — a manual-only (error/manual) issue.
        let txnURL = ws.appendingPathComponent("Accounts/transactions/2026-05.csv")
        let content = """
        # schema_version: 1
        transaction_id,account_id,date,amount
        txn-1,GHOST-ACCT,2026-05-01,-10.00
        """
        try Data(content.utf8).write(to: txnURL)

        // Apply repair — nothing in the auto set targets this file.
        let entries = try RepairService().apply(workspaceURL: ws)
        #expect(entries.isEmpty)

        // The file is byte-for-byte unchanged.
        let after = try String(contentsOf: txnURL, encoding: .utf8)
        #expect(after == content)

        // The validation engine still reports it as a manual error (it is surfaced, not auto-fixed).
        let result = ValidationEngine().validate(try WorkspaceParser().parse(workspaceURL: ws))
        let issue = try #require(result.issues.first { $0.ruleId == "VAL-CROSS-003" })
        #expect(issue.repairClass == .manual)
    }
}
