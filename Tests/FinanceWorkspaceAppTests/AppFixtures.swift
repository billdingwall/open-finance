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

    /// Write a file verbatim (no `# schema_version` prefix) — e.g. Workspace.md.
    func writeRaw(_ relativePath: String, _ content: String) {
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
        // Workspace.md is a required file; its absence is a workspace-level validation error.
        fixture.writeRaw("Workspace.md", "---\nworkspace_id: fixture\n---\n")
        // `account_group` is the account CLASS enum (checking/savings/business/…), NOT the
        // group's type; the account's group membership is `account_group_id`.
        fixture.write("Accounts/accounts.csv",
                      "account_id,display_name,institution,account_group,account_type,status,account_group_id",
                      ["A1,Checking,Bank,checking,checking,active,G1",
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

    /// `standard()` plus one valid row in **every remaining managed file type** (008 T009) —
    /// the shared base for the write view-model + repair-apply integration suites. Kept separate
    /// from `standard()` so its assertions stay stable.
    static func full() -> AppFixture {
        let fixture = standard()
        fixture.write("Accounts/account-rules.csv",
                      "rule_id,account_id,rule_type,description,amount,frequency,start_date,end_date,category_id,is_active,kind,value",
                      ["R1,A1,recurring,Rent,-1500,monthly,2026-01-01,,C1,true,,"])
        fixture.write("Accounts/liabilities.csv",
                      "liability_id,account_id,principal_balance,interest_rate,term_months",
                      ["L1,A1,15000,0.05,120"])
        fixture.write("Savings/progress.csv", "progress_id,goal_id,as_of,balance",
                      ["PR1,SG1,2026-06-15,2500"])
        fixture.write("Investments/dividends.csv", "dividend_id,asset_id,date,amount",
                      ["D1,AS1,2026-06-20,12.50"])
        fixture.write("Investments/tax-lots.csv", "lot_id,asset_id,acquired_date,quantity,cost_basis",
                      ["LOT1,AS1,2026-06-12,10,1000"])
        fixture.write("Investments/portfolios.csv", "portfolio_id,name,account_id,expected_return_rate",
                      ["PF1,Core,B1,0.07"])
        fixture.write("Investments/sleeves.csv", "sleeve_id,portfolio_id,name", ["SL1,PF1,US Equity"])
        fixture.write("Investments/sleeve-targets.csv", "target_id,sleeve_id,target_weight",
                      ["ST1,SL1,0.6"])
        fixture.write("Investments/benchmarks/sp500.csv", "date,close",
                      ["2026-06-01,5000", "2026-06-27,5100"])
        fixture.write("Taxes/tax-adjustments.csv",
                      "tax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id",
                      ["ADJ1,standard,15750,2026,estimated,"])
        fixture.write("Taxes/estimates.csv",
                      "estimate_id,tax_year,gross_income,taxes_paid,estimated_return",
                      ["E1,2026,60000,9000,"])
        fixture.write("Taxes/documents.csv", "document_id,tax_year,kind,label,linked_path",
                      ["DOC1,2026,w2,Employer W-2,"])
        fixture.write("Taxes/estimated-payments.csv", "payment_id,tax_year,quarter,amount,paid",
                      ["PAY1,2026,1,1500,true"])
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
