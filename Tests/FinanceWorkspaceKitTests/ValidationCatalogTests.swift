import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T020 / SC-003 — a defect-seeded workspace fires each rule with the correct id/tier/severity/
// repair class (one issue per condition).

@Suite struct ValidationCatalogTests {

    @Test func seededDefectsFireWithCorrectClassification() throws {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-catalog-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        try WorkspaceProvisioner().provision(at: ws)

        // One transactions file carrying: unknown account (CROSS-003), duplicate id (CROSS-010),
        // unknown category (CROSS-001), bad decimal (lifted FILE-007), unbalanced transfer (DOMAIN-005).
        let txns = """
        # schema_version: 1
        transaction_id,account_id,date,amount,type,category_id,group_id,group_role
        txn-1,acc-personal-bank,2026-05-01,-10.00,standard,cat-housing,,
        txn-1,GHOST-ACCT,2026-05-02,bad,standard,cat-nope,,
        txn-3,acc-savings,2026-05-03,100.00,transfer,,grpX,debit
        txn-4,acc-personal-bank,2026-05-03,-90.00,transfer,,grpX,credit
        """
        try Data(txns.utf8).write(to: ws.appendingPathComponent("Accounts/transactions/2026-05.csv"))

        let result = ValidationEngine().validate(try WorkspaceParser().parse(workspaceURL: ws))
        func issue(_ id: String) -> ValidationIssue? { result.issues.first { $0.ruleId == id } }

        let account = try #require(issue("VAL-CROSS-003"), "unknown-account rule did not fire")
        #expect(account.severity == .error)
        #expect(account.repairClass == .manual)
        #expect(account.tier == .crossFile)

        let duplicate = try #require(issue("VAL-CROSS-010"))
        #expect(duplicate.severity == .error)

        let unbalanced = try #require(issue("VAL-DOMAIN-005"))
        #expect(unbalanced.severity == .error)
        #expect(unbalanced.tier == .domain)

        let category = try #require(issue("VAL-CROSS-001"))
        #expect(category.severity == .warning)
        #expect(category.repairClass == .manual)

        let decimal = try #require(issue("VAL-FILE-007"))   // lifted parse warning
        #expect(decimal.severity == .warning)

        // Duplicate transaction id fires exactly once (for the second occurrence).
        #expect(result.issues.filter { $0.ruleId == "VAL-CROSS-010" }.count == 1)
    }
}
