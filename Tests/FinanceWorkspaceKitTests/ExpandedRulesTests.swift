import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Coverage for the second wave of rule predicates (T023/T024/T025):
// VAL-FILE-002 unknown file type, VAL-FILE-003 invalid ledger name, VAL-CROSS-011 orphan note link,
// VAL-DOMAIN-003 asset without account, VAL-DOMAIN-004 trade without asset.

@Suite struct ExpandedRulesTests {

    private func provisioned() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-rules2-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        try WorkspaceProvisioner().provision(at: ws)
        return ws
    }

    @Test func expandedRulesFire() throws {
        let ws = try provisioned()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        func write(_ rel: String, _ content: String) throws {
            try Data(content.utf8).write(to: ws.appendingPathComponent(rel))
        }
        try write("Budget/random.csv", "# schema_version: 1\nfoo,bar\n1,2\n")
        try write("Accounts/transactions/may.csv",
                  "# schema_version: 1\ntransaction_id,account_id,date,amount\nt1,acc-savings,2026-05-01,-1.00\n")
        try write("Investments/assets.csv",
                  "# schema_version: 1\nasset_id,ticker,name,security_class,account_id\na-1,AAPL,Apple,equity,\n")
        try write("Accounts/transactions/2026-06.csv",
                  "# schema_version: 1\ntransaction_id,account_id,date,amount,type,sending_asset_id,receiving_asset_id\ntr-1,acc-investment,2026-06-02,0.00,trade,,\n")
        try write("Notes/monthly/2026-06.md", "---\ntype: monthly\naccount_ids: [ghost-acct]\n---\nnote\n")

        let result = ValidationEngine().validate(try WorkspaceParser().parse(workspaceURL: ws))
        func has(_ id: String) -> Bool { result.issues.contains { $0.ruleId == id } }

        #expect(has("VAL-FILE-002"))    // unknown file type
        #expect(has("VAL-FILE-003"))    // invalid monthly ledger name
        #expect(has("VAL-CROSS-011"))   // orphan note link
        #expect(has("VAL-DOMAIN-003"))  // asset without account
        #expect(has("VAL-DOMAIN-004"))  // trade without asset
    }

    @Test func validMonthlyNameAccepted() {
        #expect(FileRules.isValidMonthlyName("2026-05.csv"))
        #expect(!FileRules.isValidMonthlyName("may.csv"))
        #expect(!FileRules.isValidMonthlyName("2026-13.csv"))
    }
}
