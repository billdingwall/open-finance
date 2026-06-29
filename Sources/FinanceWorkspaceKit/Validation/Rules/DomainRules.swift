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
}
