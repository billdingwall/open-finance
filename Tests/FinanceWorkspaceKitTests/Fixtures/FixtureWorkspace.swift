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
}
