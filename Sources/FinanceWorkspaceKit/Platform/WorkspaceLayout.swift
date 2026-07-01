import Foundation

// Single source of truth for the standard workspace structure + seed content.
// Used by both WorkspaceProvisioner (app) and the bootstrap-workspace CLI (contracts/workspace-layout.md).
// Seed CSV headers mirror the .finance-meta/schemas/ JSON schemas.

public enum WorkspaceLayout {

    /// Standard folder tree (workspace-relative).
    public static let requiredFolders: [String] = [
        "Accounts", "Accounts/transactions",
        "Budget",
        "Savings",
        "Investments", "Investments/benchmarks",
        "Taxes", "Taxes/archive", "Taxes/yearly",
        "Notes", "Notes/monthly", "Notes/strategy",
        ".finance-meta", ".finance-meta/schemas", ".finance-meta/backups", ".finance-meta/logs",
    ]

    /// Files whose presence marks a complete, valid workspace.
    public static let requiredFiles: [String] = [
        "Workspace.md", "Accounts/accounts.csv", "Accounts/account-groups.csv", "Budget/categories.csv",
    ]

    public static let workspaceId = "finance-main"

    private static func csv(_ header: String, _ rows: [String] = []) -> String {
        (["# schema_version: 1", header] + rows).joined(separator: "\n") + "\n"
    }

    /// path → content for every seed file. Idempotent provisioning never overwrites existing files.
    public static func seedFiles(taxYear: Int, createdAt: Date = Date()) -> [String: String] {
        let standard = decimalString(standardDeduction(filingStatus: "single", taxYear: taxYear))
        return [
            "Workspace.md": """
            ---
            type: workspace
            workspace_id: \(workspaceId)
            schema_version: 1
            created_at: \(ISO8601DateFormatter().string(from: createdAt))
            ---

            Your Finance workspace. Files here are the source of truth and remain editable in Finder,
            Numbers, or any text editor.
            """,

            // Six locked seed accounts.
            "Accounts/accounts.csv": csv(
                "account_id,display_name,institution,account_group,account_type,status,account_group_id",
                ["acc-personal-bank,Personal Checking,,checking,personal,active,grp-personal",
                 "acc-personal-cc,Personal Credit Card,,credit_card,personal,active,grp-personal",
                 "acc-business-bank,Business Checking,,business,llc,active,grp-business",
                 "acc-business-cc,Business Credit Card,,credit_card,business,active,grp-business",
                 "acc-savings,Savings,,savings,standard,active,grp-personal",
                 "acc-investment,Investment,,investment,taxable,active,grp-personal"]),

            "Accounts/account-groups.csv": csv(
                "account_group_id,name,group_type",
                ["grp-personal,Personal Accounts,personal",
                 "grp-business,Business,business"]),

            "Accounts/liabilities.csv": csv(
                "liability_id,account_id,principal_balance,interest_rate,term_months"),
            "Accounts/account-rules.csv": csv(
                "rule_id,account_id,rule_type,description,amount,frequency,start_date,end_date,category_id,is_active"),

            // Default category set across six groups (Phase 3, FR-021 / contracts/seed-data.md §2).
            "Budget/categories.csv": csv(
                "category_id,name,parent_category_id,category_group_id,default_budget_behavior,tax_relevant",
                ["cat-salary,Salary,,grp-income,fixed,true",
                 "cat-business-income,Business Income,,grp-income,fixed,true",
                 "cat-housing,Housing,,grp-essentials,fixed,false",
                 "cat-groceries,Groceries,,grp-essentials,discretionary,false",
                 "cat-utilities,Utilities,,grp-essentials,fixed,false",
                 "cat-transport,Transport,,grp-essentials,discretionary,false",
                 "cat-insurance,Insurance,,grp-essentials,fixed,true",
                 "cat-dining,Dining,,grp-lifestyle,discretionary,false",
                 "cat-entertainment,Entertainment,,grp-lifestyle,discretionary,false",
                 "cat-shopping,Shopping,,grp-lifestyle,discretionary,false",
                 "cat-travel,Travel,,grp-lifestyle,discretionary,false",
                 "cat-emergency,Emergency Fund,,grp-savings,savings,false",
                 "cat-goals,Goal Savings,,grp-savings,savings,false",
                 "cat-retirement,Retirement,,grp-investments,investment,false",
                 "cat-brokerage,Brokerage,,grp-investments,investment,false",
                 "cat-transfers,Transfers,,grp-transfers,transfer,false"]),
            // A single default budget scoped to the personal account-group (architecture §3.4).
            "Budget/budgets.csv": csv(
                "budget_id,name,account_group_ids,account_ids",
                ["bud-household,Household,grp-personal,"]),
            "Budget/budget-allocations.csv": csv("allocation_id,budget_id,category_id,planned_amount,period"),

            "Savings/goals.csv": csv(
                "goal_id,name,target_amount,target_date,monthly_target,source_account_id,status,linked_note_id"),
            "Savings/progress.csv": csv("progress_id,goal_id,as_of,balance"),

            "Taxes/settings.csv": csv(
                "key,value",
                ["filing_status,single",
                 "tax_year,\(taxYear)",
                 "default_currency,USD",
                 "timezone,UTC"]),
            "Taxes/tax-adjustments.csv": csv(
                "tax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id",
                ["adj-standard,standard,\(standard),\(taxYear),estimated,"]),
            "Taxes/estimated-payments.csv": csv(
                "payment_id,tax_year,quarter,amount,paid"),
            "Taxes/estimates.csv": csv("estimate_id,tax_year,gross_income,taxes_paid,estimated_return"),
            "Taxes/documents.csv": csv("document_id,tax_year,kind,label,linked_path"),

            // Investments (Phase 4). Empty-but-valid; fixtures/imports populate them.
            "Investments/assets.csv": csv("asset_id,ticker,name,security_class,account_id,sleeve_id,currency"),
            "Investments/prices.csv": csv("price_id,asset_id,date,close"),
            "Investments/dividends.csv": csv("dividend_id,asset_id,date,amount"),
            "Investments/tax-lots.csv": csv("lot_id,asset_id,acquired_date,quantity,cost_basis"),
            "Investments/portfolios.csv": csv("portfolio_id,name,account_id,expected_return_rate"),
            "Investments/sleeves.csv": csv("sleeve_id,portfolio_id,name"),
            "Investments/sleeve-targets.csv": csv("target_id,sleeve_id,target_weight"),
            "Investments/benchmarks/sp500.csv": csv("date,close"),
        ]
    }

    private static func decimalString(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }

    // MARK: - Tax tables (hardcoded estimates; new tax years require a code update — research R3)
    // Values are simplified estimates for the tax module (constitution: "all tax figures are estimates").

    /// Standard deduction by filing status + tax year; falls back to the nearest known year.
    public static func standardDeduction(filingStatus: String, taxYear: Int) -> Decimal {
        let table: [Int: [String: Decimal]] = [
            2025: ["single": 15000, "married_filing_jointly": 30000,
                   "married_filing_separately": 15000, "head_of_household": 22500],
            2026: ["single": 15750, "married_filing_jointly": 31500,
                   "married_filing_separately": 15750, "head_of_household": 23625],
        ]
        let year = table[taxYear] ?? table[table.keys.max() ?? 2026] ?? [:]
        return year[filingStatus] ?? year["single"] ?? 0
    }

    /// Progressive brackets as (upperBound?, marginalRate) ascending; a nil upperBound is the top band.
    public static func taxBrackets(filingStatus: String, taxYear: Int) -> [(upperBound: Decimal?, rate: Decimal)] {
        // Single / MFJ estimate tables (2025-ish); other statuses fall back to single.
        let single: [(Decimal?, Decimal)] = [
            (11925, 0.10), (48475, 0.12), (103350, 0.22), (197300, 0.24),
            (250525, 0.32), (626350, 0.35), (nil, 0.37)]
        let mfj: [(Decimal?, Decimal)] = [
            (23850, 0.10), (96950, 0.12), (206700, 0.22), (394600, 0.24),
            (501050, 0.32), (751600, 0.35), (nil, 0.37)]
        let bands = filingStatus == "married_filing_jointly" ? mfj : single
        return bands.map { (upperBound: $0.0, rate: $0.1) }
    }

    public static func currentTaxYear(now: Date = Date()) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: now)
    }
}
