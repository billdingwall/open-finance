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
        assetWithoutAccountIssues(context) + tradeWithoutAssetIssues(context) + groupBalanceIssues(context)
    }

    /// VAL-DOMAIN-003 — asset without an owning account.
    private static func assetWithoutAccountIssues(_ context: WorkspaceContext) -> [ValidationIssue] {
        guard let rule = RuleCatalog.rule("VAL-DOMAIN-003") else { return [] }
        var issues: [ValidationIssue] = []
        for asset in context.records(ofType: "assets") where string(asset, "account_id").isEmpty {
            issues.append(rule.makeIssue(file: asset.sourceFile, row: asset.sourceRow,
                                         column: "account_id", detail: "asset has no owning account_id"))
        }
        return issues
    }

    /// VAL-DOMAIN-004 — a trade transaction with neither a sending nor a receiving asset.
    private static func tradeWithoutAssetIssues(_ context: WorkspaceContext) -> [ValidationIssue] {
        guard let rule = RuleCatalog.rule("VAL-DOMAIN-004") else { return [] }
        var issues: [ValidationIssue] = []
        for txn in context.records(ofType: "transactions") {
            guard case let .string(type)? = txn.fields["type"]?.typed, type == "trade" else { continue }
            if string(txn, "sending_asset_id").isEmpty && string(txn, "receiving_asset_id").isEmpty {
                issues.append(rule.makeIssue(file: txn.sourceFile, row: txn.sourceRow,
                                             detail: "trade has neither a sending nor a receiving asset"))
            }
        }
        return issues
    }

    /// VAL-DOMAIN-005 (balanced groups net to zero) + VAL-DOMAIN-006 (gross/net reconciliation).
    private static func groupBalanceIssues(_ context: WorkspaceContext) -> [ValidationIssue] {
        var groups: [String: [GroupRow]] = [:]
        for record in context.records(ofType: "transactions") {
            guard case let .string(groupID)? = record.fields["group_id"]?.typed, !groupID.isEmpty,
                  case let .decimal(amount)? = record.fields["amount"]?.typed else { continue }
            var role: String?
            if case let .string(value)? = record.fields["group_role"]?.typed, !value.isEmpty { role = value }
            groups[groupID, default: []].append(
                GroupRow(amount: amount, role: role, file: record.sourceFile, row: record.sourceRow))
        }

        return groups.flatMap { groupID, rows -> [ValidationIssue] in
            let roles = Set(rows.compactMap(\.role))
            return roles.contains("gross") || roles.contains("net")
                ? grossNetIssues(groupID: groupID, rows: rows)
                : balancedGroupIssues(groupID: groupID, rows: rows)
        }
    }

    private static func grossNetIssues(groupID: String, rows: [GroupRow]) -> [ValidationIssue] {
        guard let rule = RuleCatalog.rule("VAL-DOMAIN-006"), let anchor = rows.first else { return [] }
        let gross = rows.filter { $0.role == "gross" }
        let net = rows.filter { $0.role == "net" }
        let withholding = rows.filter { $0.role == "withholding" }
        guard gross.count == 1, net.count == 1 else {
            return [rule.makeIssue(file: anchor.file, row: anchor.row,
                                   detail: "group '\(groupID)' must have exactly one gross and one net row")]
        }
        let expectedNet = abs(gross[0].amount) - withholding.reduce(Decimal(0)) { $0 + abs($1.amount) }
        guard abs(net[0].amount) != expectedNet else { return [] }
        return [rule.makeIssue(file: anchor.file, row: anchor.row,
                               detail: "group '\(groupID)': net \(net[0].amount) != gross − Σwithholding (\(expectedNet))")]
    }

    private static func balancedGroupIssues(groupID: String, rows: [GroupRow]) -> [ValidationIssue] {
        guard let rule = RuleCatalog.rule("VAL-DOMAIN-005"), let anchor = rows.first else { return [] }
        let sum = rows.reduce(Decimal(0)) { $0 + $1.amount }
        guard sum != 0 else { return [] }
        return [rule.makeIssue(file: anchor.file, row: anchor.row,
                               detail: "group '\(groupID)' nets to \(sum), expected 0")]
    }

    private static func abs(_ value: Decimal) -> Decimal { value < 0 ? -value : value }

    private static func string(_ record: ParsedRecord, _ column: String) -> String {
        if case let .string(value)? = record.fields[column]?.typed { return value }
        return ""
    }
}
