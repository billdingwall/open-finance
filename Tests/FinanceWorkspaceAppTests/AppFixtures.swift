import Foundation
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// Shared temp-dir fixture workspace for the app-layer tests (mirrors the Kit tests' pattern,
// but through public Kit API only). Small, hand-verifiable data.

struct AppFixture {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fwa-fixture-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        for folder in ["Accounts", "Accounts/transactions", "Budget", "Savings",
                       "Investments", "Investments/benchmarks", "Taxes", "Taxes/archive"] {
            try? FileManager.default.createDirectory(
                at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
    }

    func write(_ relativePath: String, _ header: String, _ rows: [String]) {
        let content = (["# schema_version: 1", header] + rows).joined(separator: "\n") + "\n"
        let url = root.appendingPathComponent(relativePath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(content.utf8).write(to: url)
    }

    func cleanup() { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    /// A small but complete workspace: two account groups (personal + business), a savings
    /// account, transactions incl. a multi-entry paycheck, a budget with one category, a goal,
    /// and one asset with a trade + price.
    static func standard() -> AppFixture {
        let fixture = AppFixture()
        fixture.write("Accounts/accounts.csv",
                      "account_id,display_name,institution,account_group,account_type,status,account_group_id",
                      ["A1,Checking,Bank,personal,checking,active,G1",
                       "A2,Savings,Bank,savings,savings,active,G1",
                       "B1,Studio,Bank,business,checking,active,G2"])
        fixture.write("Accounts/account-groups.csv", "account_group_id,name,group_type",
                      ["G1,Household,personal", "G2,Studio LLC,business"])
        fixture.write("Accounts/transactions/2026-06.csv",
                      "transaction_id,account_id,date,amount,type,category_id,savings_goal_id,group_id,group_role,liability_id",
                      ["T1,A1,2026-06-01,5000,standard,,,GRP1,gross,",
                       "T2,A1,2026-06-01,-1000,standard,,,GRP1,withholding,",
                       "T3,A1,2026-06-01,4000,standard,,,GRP1,net,",
                       "T4,A1,2026-06-05,-200,standard,C1,,,,",
                       "T5,A2,2026-06-10,300,standard,,SG1,,,",
                       "T6,B1,2026-06-15,2000,standard,,,,,"])
        fixture.write("Budget/categories.csv",
                      "category_id,name,parent_category_id,default_budget_behavior",
                      ["C1,Groceries,,discretionary"])
        fixture.write("Budget/budgets.csv", "budget_id,name,account_group_ids,account_ids",
                      ["BUD1,Household,G1,"])
        fixture.write("Budget/budget-allocations.csv",
                      "allocation_id,budget_id,category_id,period,planned_amount",
                      ["AL1,BUD1,C1,2026-06,250"])
        fixture.write("Savings/goals.csv",
                      "goal_id,name,target_amount,target_date,monthly_target,source_account_id,status,linked_note_id",
                      ["SG1,Emergency fund,10000,,500,A2,active,"])
        fixture.write("Investments/assets.csv",
                      "asset_id,ticker,name,security_class,account_id,sleeve_id,currency",
                      ["AS1,VTI,Total Market,etf,B1,,USD"])
        fixture.write("Investments/prices.csv", "price_id,asset_id,date,close",
                      ["P1,AS1,2026-06-27,100"])
        fixture.write("Taxes/settings.csv", "key,value",
                      ["filing_status,single", "tax_year,2026", "default_currency,USD", "timezone,UTC"])
        return fixture
    }

    /// Recursive path → content snapshot for the read-only guarantee (SC-005).
    func contentSnapshot() -> [String: Data] {
        var out: [String: Data] = [:]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                out[url.path] = try? Data(contentsOf: url)
            }
        }
        return out
    }
}
