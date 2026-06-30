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
        [
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
                ["adj-standard,standard,0.00,\(taxYear),estimated,"]),
            "Taxes/estimated-payments.csv": csv(
                "payment_id,tax_year,quarter,amount,paid"),
        ]
    }

    public static func currentTaxYear(now: Date = Date()) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: now)
    }
}
