import Foundation

// T024 — Cross-file reference integrity. A generic reference-spec table drives the
// unknown-X-reference rules (VAL-CROSS-001..008); duplicate transaction ID is VAL-CROSS-010.
// NOTE: delete-with-reference is NOT a static rule here (clarify N1) — only the inbound-reference
// lookups it would use (WorkspaceContext.identifierSet / inboundReferences) are provided.

enum CrossFileRules {

    /// child file-type, FK column, parent file-type, parent id column, rule id, optional FK?
    private struct ReferenceSpec {
        let childType: String, fkColumn: String, parentType: String, parentColumn: String
        let ruleID: String, optional: Bool
    }

    private static let specs: [ReferenceSpec] = [
        .init(childType: "transactions", fkColumn: "account_id",
              parentType: "registry", parentColumn: "account_id", ruleID: "VAL-CROSS-003", optional: false),
        .init(childType: "transactions", fkColumn: "category_id",
              parentType: "categories", parentColumn: "category_id", ruleID: "VAL-CROSS-001", optional: true),
        .init(childType: "transactions", fkColumn: "savings_goal_id",
              parentType: "goals", parentColumn: "goal_id", ruleID: "VAL-CROSS-008", optional: true),
        .init(childType: "registry", fkColumn: "account_group_id",
              parentType: "account-groups", parentColumn: "account_group_id", ruleID: "VAL-CROSS-002", optional: false),
        .init(childType: "liabilities", fkColumn: "account_id",
              parentType: "registry", parentColumn: "account_id", ruleID: "VAL-CROSS-003", optional: false),
        .init(childType: "assets", fkColumn: "account_id",
              parentType: "registry", parentColumn: "account_id", ruleID: "VAL-CROSS-003", optional: true),
        .init(childType: "prices", fkColumn: "asset_id",
              parentType: "assets", parentColumn: "asset_id", ruleID: "VAL-CROSS-004", optional: false),
        .init(childType: "dividends", fkColumn: "asset_id",
              parentType: "assets", parentColumn: "asset_id", ruleID: "VAL-CROSS-004", optional: false),
        .init(childType: "tax-lots", fkColumn: "asset_id",
              parentType: "assets", parentColumn: "asset_id", ruleID: "VAL-CROSS-004", optional: false),
        .init(childType: "portfolios", fkColumn: "account_id",
              parentType: "registry", parentColumn: "account_id", ruleID: "VAL-CROSS-003", optional: true),
        .init(childType: "sleeves", fkColumn: "portfolio_id",
              parentType: "portfolios", parentColumn: "portfolio_id", ruleID: "VAL-CROSS-006", optional: false),
        .init(childType: "sleeve-targets", fkColumn: "sleeve_id",
              parentType: "sleeves", parentColumn: "sleeve_id", ruleID: "VAL-CROSS-007", optional: false),
        .init(childType: "progress", fkColumn: "goal_id",
              parentType: "goals", parentColumn: "goal_id", ruleID: "VAL-CROSS-008", optional: false),
        .init(childType: "budget-allocations", fkColumn: "category_id",
              parentType: "categories", parentColumn: "category_id", ruleID: "VAL-CROSS-001", optional: false),
    ]

    static func evaluate(_ context: WorkspaceContext) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Reference integrity.
        var idSetCache: [String: Set<String>] = [:]
        for spec in specs {
            guard let rule = RuleCatalog.rule(spec.ruleID) else { continue }
            let parentIDs = idSetCache[spec.parentType]
                ?? context.identifierSet(fileTypeKey: spec.parentType, column: spec.parentColumn)
            idSetCache[spec.parentType] = parentIDs

            for record in context.records(ofType: spec.childType) {
                guard case let .string(value)? = record.fields[spec.fkColumn]?.typed else { continue }
                if value.isEmpty { continue }
                if spec.optional && value.isEmpty { continue }
                if !parentIDs.contains(value) {
                    issues.append(rule.makeIssue(
                        file: record.sourceFile, row: record.sourceRow, column: spec.fkColumn,
                        detail: "\(spec.fkColumn) '\(value)' has no matching \(spec.parentColumn) in \(spec.parentType)"))
                }
            }
        }

        // Orphan note links (VAL-CROSS-011): a note's linked IDs that resolve to nothing.
        if let rule = RuleCatalog.rule("VAL-CROSS-011") {
            let accountIDs = idSetCache["registry"]
                ?? context.identifierSet(fileTypeKey: "registry", column: "account_id")
            let groupIDs = context.identifierSet(fileTypeKey: "account-groups", column: "account_group_id")
            let sleeveIDs = context.identifierSet(fileTypeKey: "sleeves", column: "sleeve_id")
            for note in context.notes {
                for id in note.linkedAccountIDs where !id.isEmpty && !accountIDs.contains(id) {
                    issues.append(rule.makeIssue(file: note.sourceFile, detail: "note links unknown account '\(id)'"))
                }
                for id in note.linkedEntityIDs where !id.isEmpty && !groupIDs.contains(id) {
                    issues.append(rule.makeIssue(file: note.sourceFile, detail: "note links unknown account-group '\(id)'"))
                }
                for id in note.linkedSleeveIDs where !id.isEmpty && !sleeveIDs.contains(id) {
                    issues.append(rule.makeIssue(file: note.sourceFile, detail: "note links unknown sleeve '\(id)'"))
                }
            }
        }

        // Duplicate transaction ID (VAL-CROSS-010).
        if let rule = RuleCatalog.rule("VAL-CROSS-010") {
            var seen = Set<String>()
            for record in context.records(ofType: "transactions") {
                guard case let .string(id)? = record.fields["transaction_id"]?.typed, !id.isEmpty else { continue }
                if seen.contains(id) {
                    issues.append(rule.makeIssue(
                        file: record.sourceFile, row: record.sourceRow, column: "transaction_id",
                        detail: "duplicate transaction_id '\(id)'"))
                } else {
                    seen.insert(id)
                }
            }
        }

        return issues
    }
}
