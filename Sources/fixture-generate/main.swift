import Foundation
import FinanceWorkspaceKit

// T019 — Populate a realistic local-folder workspace for development, first-run testing, and CI.
// Output must scan cleanly through FileIndexService.

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: fixture-generate --workspace <path> [--months N]\n".utf8))
    exit(2)
}

var workspacePath = LocalFolderProvider.defaultRoot.path
var months = 12
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": if let value = args.first { workspacePath = value; args.removeFirst() }
    case "--months": if let value = args.first, let parsed = Int(value) { months = parsed; args.removeFirst() }
    case "-h", "--help": usage()
    default: break
    }
}

let finance = URL(fileURLWithPath: workspacePath, isDirectory: true).appendingPathComponent("Finance", isDirectory: true)

func mkdir(_ url: URL) throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
func write(_ text: String, to url: URL) throws { try Data(text.utf8).write(to: url) }

func csv(_ header: String, _ rows: [String]) -> String {
    (["# schema_version: 1", header] + rows).joined(separator: "\n") + "\n"
}

do {
    // Create the full standard folder tree so a generated fixture is complete (matches bootstrap).
    for sub in WorkspaceLayout.requiredFolders {
        try mkdir(finance.appendingPathComponent(sub))
    }

    // Workspace descriptor (root, meta domain)
    try write("""
    ---
    type: workspace
    workspace_id: finance-dev
    schema_version: 1
    created_at: \(ISO8601DateFormatter().string(from: Date()))
    ---

    Development fixture workspace.
    """, to: finance.appendingPathComponent("Workspace.md"))

    // Six seed accounts
    let accounts = csv(
        "account_id,display_name,institution,account_group,account_type,status,account_group_id",
        ["acc-personal-bank,Everyday Checking,Acme Bank,checking,personal,active,grp-personal",
         "acc-personal-cc,Personal Card,Acme Bank,credit_card,personal,active,grp-personal",
         "acc-biz-bank,Business Checking,Acme Bank,business,llc,active,grp-business",
         "acc-biz-cc,Business Card,Acme Bank,credit_card,business,active,grp-business",
         "acc-savings,High-Yield Savings,Acme Bank,savings,hysa,active,grp-personal",
         "acc-investment,Brokerage,Acme Invest,investment,taxable,active,grp-personal"])
    try write(accounts, to: finance.appendingPathComponent("Accounts/accounts.csv"))

    try write(csv("account_group_id,name,group_type",
                  ["grp-personal,Personal Accounts,personal",
                   "grp-business,Consulting LLC,business"]),
              to: finance.appendingPathComponent("Accounts/account-groups.csv"))

    try write(csv("category_id,name,default_budget_behavior,tax_relevant",
                  ["cat-rent,Rent,fixed,false",
                   "cat-groceries,Groceries,discretionary,false",
                   "cat-income,Income,fixed,true"]),
              to: finance.appendingPathComponent("Budget/categories.csv"))

    // 12 (or N) monthly transaction files
    let cal = Calendar(identifier: .gregorian)
    let now = Date()
    for m in 0..<months {
        guard let monthDate = cal.date(byAdding: .month, value: -m, to: now) else { continue }
        let comps = cal.dateComponents([.year, .month], from: monthDate)
        let name = String(format: "%04d-%02d.csv", comps.year!, comps.month!)
        let dateStr = String(format: "%04d-%02d-15", comps.year!, comps.month!)
        let rows = [
            "txn-\(m)-1,acc-personal-bank,\(dateStr),3500.00,standard,cat-income,",
            "txn-\(m)-2,acc-personal-bank,\(dateStr),-1500.00,standard,cat-rent,",
            "txn-\(m)-3,acc-personal-cc,\(dateStr),-220.45,standard,cat-groceries,",
            "txn-\(m)-4,acc-savings,\(dateStr),500.00,standard,,goal-emergency"
        ]
        try write(csv("transaction_id,account_id,date,amount,type,category_id,savings_goal_id", rows),
                  to: finance.appendingPathComponent("Accounts/transactions/\(name)"))
    }

    try write(csv("goal_id,name,target_amount,target_date,monthly_target,source_account_id,status,linked_note_id",
                  ["goal-emergency,Emergency Fund,10000.00,2026-12-31,500.00,acc-savings,active,"]),
              to: finance.appendingPathComponent("Savings/goals.csv"))

    print("fixture-generate: wrote \(months)-month workspace to \(finance.path)")
} catch {
    FileHandle.standardError.write(Data("fixture-generate failed: \(error)\n".utf8))
    exit(1)
}
