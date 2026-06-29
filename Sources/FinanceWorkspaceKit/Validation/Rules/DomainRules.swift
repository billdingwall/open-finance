import Foundation

// T025 — Domain logic rules. Wired in this phase: multi-entry group balance (VAL-DOMAIN-005)
// and gross/net reconciliation (VAL-DOMAIN-006). The remaining domain conditions
// (VAL-DOMAIN-001/002/003/004/007/008) are catalog metadata with predicates pending.

enum DomainRules {

    private struct GroupRow {
        let amount: Decimal
        let role: String?
        let file: String
        let row: Int
    }

    static func evaluate(_ context: WorkspaceContext) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // VAL-DOMAIN-003 — asset without an owning account.
        if let rule = RuleCatalog.rule("VAL-DOMAIN-003") {
            for asset in context.records(ofType: "assets") {
                let accountID: String
                if case let .string(value)? = asset.fields["account_id"]?.typed { accountID = value } else { accountID = "" }
                if accountID.isEmpty {
                    issues.append(rule.makeIssue(file: asset.sourceFile, row: asset.sourceRow,
                        column: "account_id", detail: "asset has no owning account_id"))
                }
            }
        }

        // VAL-DOMAIN-004 — a trade transaction with neither a sending nor a receiving asset.
        if let rule = RuleCatalog.rule("VAL-DOMAIN-004") {
            for txn in context.records(ofType: "transactions") {
                guard case let .string(type)? = txn.fields["type"]?.typed, type == "trade" else { continue }
                let sending = string(txn, "sending_asset_id")
                let receiving = string(txn, "receiving_asset_id")
                if sending.isEmpty && receiving.isEmpty {
                    issues.append(rule.makeIssue(file: txn.sourceFile, row: txn.sourceRow,
                        detail: "trade has neither a sending nor a receiving asset"))
                }
            }
        }

        // Group transaction rows by group_id.
        var groups: [String: [GroupRow]] = [:]
        for record in context.records(ofType: "transactions") {
            guard case let .string(groupID)? = record.fields["group_id"]?.typed, !groupID.isEmpty else { continue }
            guard case let .decimal(amount)? = record.fields["amount"]?.typed else { continue }
            let role: String?
            if case let .string(r)? = record.fields["group_role"]?.typed, !r.isEmpty { role = r } else { role = nil }
            groups[groupID, default: []].append(
                GroupRow(amount: amount, role: role, file: record.sourceFile, row: record.sourceRow))
        }

        for (groupID, rows) in groups {
            guard let anchor = rows.first else { continue }
            let roles = Set(rows.compactMap(\.role))
            let isGrossNet = roles.contains("gross") || roles.contains("net")

            if isGrossNet {
                guard let rule = RuleCatalog.rule("VAL-DOMAIN-006") else { continue }
                let gross = rows.filter { $0.role == "gross" }
                let net = rows.filter { $0.role == "net" }
                let withholding = rows.filter { $0.role == "withholding" }
                if gross.count != 1 || net.count != 1 {
                    issues.append(rule.makeIssue(file: anchor.file, row: anchor.row,
                        detail: "group '\(groupID)' must have exactly one gross and one net row"))
                    continue
                }
                let expectedNet = abs(gross[0].amount) - withholding.reduce(Decimal(0)) { $0 + abs($1.amount) }
                if abs(net[0].amount) != expectedNet {
                    issues.append(rule.makeIssue(file: anchor.file, row: anchor.row,
                        detail: "group '\(groupID)': net \(net[0].amount) != gross − Σwithholding (\(expectedNet))"))
                }
            } else {
                // Transfer / balanced group: rows must net to zero.
                guard let rule = RuleCatalog.rule("VAL-DOMAIN-005") else { continue }
                let sum = rows.reduce(Decimal(0)) { $0 + $1.amount }
                if sum != 0 {
                    issues.append(rule.makeIssue(file: anchor.file, row: anchor.row,
                        detail: "group '\(groupID)' nets to \(sum), expected 0"))
                }
            }
        }

        return issues
    }

    private static func abs(_ d: Decimal) -> Decimal { d < 0 ? -d : d }

    private static func string(_ record: ParsedRecord, _ column: String) -> String {
        if case let .string(value)? = record.fields[column]?.typed { return value }
        return ""
    }
}
