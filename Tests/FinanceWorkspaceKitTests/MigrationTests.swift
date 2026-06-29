import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T035 / T036 / SC-008 — a synthetic pre-R6 workspace migrates losslessly; a re-run is a no-op.

@Suite struct MigrationTests {

    /// T036 — build a synthetic pre-R6 workspace (legacy names/columns + a separate inv ledger).
    private func preR6Workspace() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-migrate-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        let fm = FileManager.default
        for dir in ["Accounts/transactions", "Investments", "Taxes", ".finance-meta/backups"] {
            try fm.createDirectory(at: ws.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        func write(_ rel: String, _ s: String) throws { try Data(s.utf8).write(to: ws.appendingPathComponent(rel)) }
        try write("Accounts/accounts.csv",
                  "# schema_version: 1\naccount_id,display_name,account_group,account_type,status,entity_id\nacc-1,Checking,checking,personal,active,ent-1\n")
        try write("Accounts/entities.csv", "# schema_version: 1\nentity_id,name,entity_type\nent-1,Personal,personal\n")
        try write("Investments/holdings.csv", "# schema_version: 1\nholding_id,ticker,name,market_value\nh-1,AAPL,Apple,1000.00\n")
        try write("Taxes/deductions.csv", "# schema_version: 1\ndeduction_id,deduction_type,amount,tax_year\nded-1,standard,0.00,2026\n")
        try write("Investments/transactions.csv",
                  "# schema_version: 1\ntransaction_id,account_id,date,amount,asset_id\ninv-1,acc-1,2026-05-10,-500.00,h-1\ninv-2,acc-1,2026-06-11,-300.00,h-1\n")
        return ws
    }

    @Test func migratesPreR6Losslessly() throws {
        let ws = try preR6Workspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let fm = FileManager.default
        func exists(_ rel: String) -> Bool { fm.fileExists(atPath: ws.appendingPathComponent(rel).path) }

        let service = MigrationService()
        #expect(service.isPreR6(workspaceURL: ws))
        #expect(service.plan(workspaceURL: ws).steps.count == 5)

        try service.apply(workspaceURL: ws)

        // Files renamed; legacy names gone.
        #expect(exists("Accounts/account-groups.csv") && !exists("Accounts/entities.csv"))
        #expect(exists("Investments/assets.csv") && !exists("Investments/holdings.csv"))
        #expect(exists("Taxes/tax-adjustments.csv") && !exists("Taxes/deductions.csv"))
        #expect(!exists("Investments/transactions.csv"))

        // accounts.csv column renamed in place.
        let accounts = try String(contentsOf: ws.appendingPathComponent("Accounts/accounts.csv"), encoding: .utf8)
        #expect(accounts.contains("account_group_id"))
        #expect(!accounts.contains("entity_id"))

        // Investment rows folded into the unified monthly ledgers as type=trade.
        let may = try String(contentsOf: ws.appendingPathComponent("Accounts/transactions/2026-05.csv"), encoding: .utf8)
        #expect(may.contains("inv-1,acc-1,2026-05-10,-500.00,trade,h-1"))
        #expect(exists("Accounts/transactions/2026-06.csv"))

        // Idempotent: now R6-native, nothing to do.
        #expect(!service.isPreR6(workspaceURL: ws))
        #expect(service.plan(workspaceURL: ws).isNoOp)
    }
}
