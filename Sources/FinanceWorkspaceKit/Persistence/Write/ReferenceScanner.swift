import Foundation

// Phase 6 (007) T033 (US4) — the reference graph behind delete-with-reassign (FR-019–022, SC-005).
// The FK edge map is derived from the shipped schemas (research D3): every non-primary-key
// `*_id`/`*_ids` column that points at a deletable collection. Deleting a row surfaces all
// referencing rows grouped by collection+column; reassignment offers same-collection targets.

public struct ReferenceScanner: Sendable {

    /// One foreign-key edge: rows of `childSubtype` reference a parent via `column`.
    struct FKEdge: Sendable {
        let childSubtype: String
        let column: String
        let isList: Bool          // `|`-delimited multi-value column (budgets scope)
        init(_ childSubtype: String, _ column: String, isList: Bool = false) {
            self.childSubtype = childSubtype; self.column = column; self.isList = isList
        }
    }

    /// The polymorphic tax-adjustment link (a single `linked_id`, any parent kind — research D3).
    private static let taxLink = FKEdge("tax-adjustments", "linked_id")

    /// Delete-target parent kind (its file-type key) → referencing edges.
    static let edges: [String: [FKEdge]] = [
        "registry": [                                   // accounts
            FKEdge("transactions", "account_id"), FKEdge("liabilities", "account_id"),
            FKEdge("account-rules", "account_id"), FKEdge("assets", "account_id"),
            FKEdge("portfolios", "account_id"), FKEdge("goals", "source_account_id"),
            FKEdge("budgets", "account_ids", isList: true), taxLink,
        ],
        "account-groups": [
            FKEdge("registry", "account_group_id"),
            FKEdge("budgets", "account_group_ids", isList: true), taxLink,
        ],
        "categories": [
            FKEdge("transactions", "category_id"), FKEdge("budget-allocations", "category_id"),
            FKEdge("account-rules", "category_id"), FKEdge("categories", "parent_category_id"), taxLink,
        ],
        "goals": [
            FKEdge("transactions", "savings_goal_id"), FKEdge("savings-progress", "goal_id"), taxLink,
        ],
        "assets": [
            FKEdge("transactions", "sending_asset_id"), FKEdge("transactions", "receiving_asset_id"),
            FKEdge("prices", "asset_id"), FKEdge("dividends", "asset_id"), FKEdge("tax-lots", "asset_id"),
        ],
        "liabilities": [FKEdge("transactions", "liability_id"), taxLink],
        "portfolios": [FKEdge("sleeves", "portfolio_id")],
        "sleeves": [FKEdge("assets", "sleeve_id"), FKEdge("sleeve-targets", "sleeve_id")],
        "budgets": [FKEdge("budget-allocations", "budget_id")],
    ]

    /// The primary-key column for each deletable parent kind.
    static let idColumns: [String: String] = [
        "registry": "account_id", "account-groups": "account_group_id", "categories": "category_id",
        "goals": "goal_id", "assets": "asset_id", "liabilities": "liability_id",
        "portfolios": "portfolio_id", "sleeves": "sleeve_id", "budgets": "budget_id",
    ]

    private let context: WorkspaceContext
    private let registry: CSVSchemaRegistry?

    public init(context: WorkspaceContext) {
        self.context = context
        self.registry = try? CSVSchemaRegistry()
    }

    /// All rows referencing `id` in the parent collection `parentSubtype`, grouped by
    /// referencing collection + column. Empty groups are omitted.
    public func referencesTo(id: String, parentSubtype: String) -> [ReferenceGroup] {
        var groups: [ReferenceGroup] = []
        for edge in Self.edges[parentSubtype] ?? [] {
            var rows: [RowRef] = []
            for record in context.records(ofType: edge.childSubtype) {
                guard let raw = record.fields[edge.column]?.raw, !raw.isEmpty else { continue }
                let matches = edge.isList
                    ? raw.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.contains(id)
                    : raw == id
                if matches {
                    rows.append(RowRef(relativePath: record.sourceFile, rowRef: record.sourceRow))
                }
            }
            guard !rows.isEmpty else { continue }
            let required = registry?.schema(forSubtype: edge.childSubtype)?.columns[edge.column]?.required ?? false
            groups.append(ReferenceGroup(collection: edge.childSubtype, column: edge.column,
                                         rows: rows, nullable: edge.isList || !required, isList: edge.isList))
        }
        return groups
    }

    /// Valid reassignment targets for a delete: other ids in the parent collection, minus the
    /// deletion set (FR-022). List columns additionally always allow "remove" (handled in the UI).
    public func reassignTargets(parentSubtype: String, excluding deleted: Set<String>) -> [String] {
        guard let idColumn = Self.idColumns[parentSubtype] else { return [] }
        let ids = context.identifierSet(fileTypeKey: parentSubtype, column: idColumn)
            .subtracting(deleted)
        // Accounts and account-groups list in the canonical display order (spec 010 FR-008);
        // other collections keep the alphabetical default.
        let canonical: [String]
        switch parentSubtype {
        case "registry": canonical = context.accounts.map(\.accountId)
        case "account-groups": canonical = context.accountGroups.map(\.accountGroupId)
        default: return ids.sorted()
        }
        let ordered = canonical.filter(ids.contains)
        return ordered + ids.subtracting(ordered).sorted()
    }
}
