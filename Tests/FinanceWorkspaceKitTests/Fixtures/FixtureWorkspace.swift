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
}
