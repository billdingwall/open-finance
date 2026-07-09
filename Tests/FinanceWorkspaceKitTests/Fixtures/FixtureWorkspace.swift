import Foundation
@testable import FinanceWorkspaceKit

// T010 — Shared in-temp-dir fixture workspaces for the Phase-3 engine tests. Each builder writes a
// small, hand-verifiable workspace and returns its URL; tests parse it with the real WorkspaceParser
// (the bundled schema registry is used, so no .finance-meta/schemas mirror is needed).

struct FixtureWorkspace {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-fixture-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        for folder in ["Accounts", "Accounts/transactions", "Budget", "Savings", "Taxes"] {
            try? FileManager.default.createDirectory(
                at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
    }

    /// Write a managed CSV (auto-prepends the `# schema_version: 1` comment row).
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

    func parse() throws -> WorkspaceContext { try WorkspaceParser().parse(workspaceURL: root) }

    func cleanup() { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    // Common headers
    static let txHeader =
        "transaction_id,account_id,date,amount,type,category_id,savings_goal_id,group_id,group_role,liability_id"
    static let acctHeader = "account_id,display_name,institution,account_group,account_type,status,account_group_id"
    static let groupHeader = "account_group_id,name,group_type"

    /// A transaction row helper.
    static func tx(_ id: String, _ account: String, _ date: String, _ amount: String,
                   type: String = "standard", category: String = "", goal: String = "",
                   group: String = "", role: String = "", liability: String = "") -> String {
        "\(id),\(account),\(date),\(amount),\(type),\(category),\(goal),\(group),\(role),\(liability)"
    }

    // MARK: Phase 4 — investment / savings / tax headers + builders

    static let tradeHeader =
        "transaction_id,account_id,date,amount,type,sending_asset_id,receiving_asset_id,trade_type,quantity,price"
    /// A `type = trade` ledger row. Buy → receiving_asset_id set; sell → sending_asset_id set.
    static func trade(_ id: String, _ account: String, _ date: String, _ amount: String,
                      asset: String, side: String, qty: String, price: String) -> String {
        let sending = side == "sell" ? asset : ""
        let receiving = side == "buy" ? asset : ""
        return "\(id),\(account),\(date),\(amount),trade,\(sending),\(receiving),\(side),\(qty),\(price)"
    }

    static let assetHeader = "asset_id,ticker,name,security_class,account_id,sleeve_id,currency"
    static let priceHeader = "price_id,asset_id,date,close"
    static let dividendHeader = "dividend_id,asset_id,date,amount"
    static let taxLotHeader = "lot_id,asset_id,acquired_date,quantity,cost_basis"
    static let portfolioHeader = "portfolio_id,name,account_id,expected_return_rate"
    static let sleeveHeader = "sleeve_id,portfolio_id,name"
    static let sleeveTargetHeader = "target_id,sleeve_id,target_weight"
    static let benchmarkHeader = "date,close"
    static let goalHeader =
        "goal_id,name,target_amount,target_date,monthly_target,source_account_id,status,linked_note_id"
    static let progressHeader = "progress_id,goal_id,as_of,balance"
    static let taxAdjHeader = "tax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id"
    static let taxEstimateHeader = "estimate_id,tax_year,gross_income,taxes_paid,estimated_return"
    static let taxDocHeader = "document_id,tax_year,kind,label,linked_path"
    static let estPaymentHeader = "payment_id,tax_year,quarter,amount,paid"
    static let settingsHeader = "key,value"

    // MARK: Phase 7 (008 T009) — every remaining managed file type

    static let ruleHeader =
        "rule_id,account_id,rule_type,description,amount,frequency,start_date,end_date,category_id,is_active,kind,value"
    static let liabilityHeader = "liability_id,account_id,principal_balance,interest_rate,term_months"
    static let categoryHeader =
        "category_id,name,parent_category_id,category_group_id,default_budget_behavior,tax_relevant"
    static let budgetHeader = "budget_id,name,account_group_ids,account_ids"
    static let allocationHeader = "allocation_id,budget_id,category_id,planned_amount,period"
    /// Canonical unified-ledger header incl. the optional Phase-7 `description` + trade columns.
    static let fullTxHeader = "transaction_id,account_id,date,amount,description,type,category_id,"
        + "savings_goal_id,group_id,group_role,sending_asset_id,receiving_asset_id,liability_id,"
        + "trade_type,quantity,price"

    /// A workspace seeding **one cross-referentially valid row in every managed file type** —
    /// the shared base for the US6 fixture matrix, the integration tests, and the App VM suites.
    static func full(month: String = "2026-06") -> FixtureWorkspace {
        let fixture = FixtureWorkspace()
        // Workspace.md is a required file; its absence is a workspace-level validation error.
        fixture.writeRaw("Workspace.md", "---\nworkspace_id: fixture\n---\n")
        fixture.write("Accounts/accounts.csv", acctHeader, [
            "A1,Checking,Bank,checking,personal,active,G1",
            "A2,Savings,Bank,savings,hysa,active,G1",
            "B1,Studio,Bank,business,llc,active,G2",
            "I1,Brokerage,Broker,investment,taxable,active,G1",
        ])
        fixture.write("Accounts/account-groups.csv", groupHeader,
                      ["G1,Household,personal", "G2,Studio LLC,business"])
        fixture.write("Accounts/account-rules.csv", ruleHeader,
                      ["R1,A1,recurring,Rent,-1500,monthly,2026-01-01,,CAT1,true,,"])
        fixture.write("Accounts/liabilities.csv", liabilityHeader, ["L1,A1,15000,0.05,120"])
        fixture.write("Accounts/transactions/\(month).csv", fullTxHeader, [
            "T1,A1,\(month)-01,5000,Salary,standard,,,GRP1,gross,,,,,,",
            "T2,A1,\(month)-01,-1000,Federal tax,standard,,,GRP1,withholding,,,,,,",
            "T3,A1,\(month)-01,4000,Net pay,standard,,,GRP1,net,,,,,,",
            "T4,A1,\(month)-05,-200,Groceries,standard,CAT1,,,,,,,,,",
            "T5,A2,\(month)-10,300,Goal deposit,standard,,SG1,,,,,,,,",
            "T6,I1,\(month)-12,-1000,Buy VTI,trade,,,,,,AS1,,buy,10,100",
        ])
        fixture.write("Budget/categories.csv", categoryHeader,
                      ["CAT1,Groceries,,CG1,discretionary,false"])
        fixture.write("Budget/budgets.csv", budgetHeader, ["BUD1,Household,G1,"])
        fixture.write("Budget/budget-allocations.csv", allocationHeader,
                      ["AL1,BUD1,CAT1,250,\(month)"])
        fixture.write("Savings/goals.csv", goalHeader,
                      ["SG1,Emergency fund,10000,,500,A2,active,"])
        fixture.write("Savings/progress.csv", progressHeader, ["PR1,SG1,\(month)-15,2500"])
        fixture.write("Investments/assets.csv", assetHeader,
                      ["AS1,VTI,Total Market,etf,I1,SL1,USD"])
        fixture.write("Investments/prices.csv", priceHeader, ["P1,AS1,\(month)-27,105"])
        fixture.write("Investments/dividends.csv", dividendHeader, ["D1,AS1,\(month)-20,12.50"])
        fixture.write("Investments/tax-lots.csv", taxLotHeader, ["LOT1,AS1,\(month)-12,10,1000"])
        fixture.write("Investments/portfolios.csv", portfolioHeader, ["PF1,Core,I1,0.07"])
        fixture.write("Investments/sleeves.csv", sleeveHeader, ["SL1,PF1,US Equity"])
        fixture.write("Investments/sleeve-targets.csv", sleeveTargetHeader, ["ST1,SL1,0.6"])
        fixture.write("Investments/benchmarks/sp500.csv", benchmarkHeader,
                      ["\(month)-01,5000", "\(month)-27,5100"])
        fixture.write("Taxes/settings.csv", settingsHeader,
                      ["filing_status,single", "tax_year,2026", "default_currency,USD", "timezone,UTC"])
        fixture.write("Taxes/tax-adjustments.csv", taxAdjHeader,
                      ["ADJ1,standard,15750,2026,estimated,"])
        fixture.write("Taxes/estimates.csv", taxEstimateHeader, ["E1,2026,60000,9000,"])
        fixture.write("Taxes/documents.csv", taxDocHeader, ["DOC1,2026,w2,Employer W-2,"])
        fixture.write("Taxes/estimated-payments.csv", estPaymentHeader, ["PAY1,2026,1,1500,true"])
        return fixture
    }
}
