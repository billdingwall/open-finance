import Foundation

// T029 — LinkingEngine: cross-domain links from parsed records (FR-015).
// Goal links come from `savings_goal_id` on the ledger; sleeve links join a trade's received asset
// to that asset's sleeve (empty in Phase 3 — investments/trades arrive in Phase 4).

public struct LinkingEngine: Sendable {

    public init() {}

    /// Budget contribution → savings goal, for every ledger row carrying a `savings_goal_id`.
    public func goalLinks(in context: WorkspaceContext) -> [GoalFundingLink] {
        context.transactions.compactMap { tx in
            tx.savingsGoalId.map { GoalFundingLink(goalId: $0, transactionId: tx.transactionId) }
        }
    }

    /// Investment contribution → sleeve, via `receiving_asset_id` → `assets.sleeve_id`.
    public func sleeveLinks(in context: WorkspaceContext) -> [SleeveFundingLink] {
        let sleeveByAsset = assetSleeveLookup(context)
        guard !sleeveByAsset.isEmpty else { return [] }
        return context.transactions.compactMap { tx in
            guard let assetId = tx.receivingAssetId, let sleeveId = sleeveByAsset[assetId] else { return nil }
            return SleeveFundingLink(sleeveId: sleeveId, transactionId: tx.transactionId)
        }
    }

    private func assetSleeveLookup(_ context: WorkspaceContext) -> [String: String] {
        var out: [String: String] = [:]
        for record in context.records(ofType: "assets") {
            if case let .string(assetId)? = record.fields["asset_id"]?.typed,
               case let .string(sleeveId)? = record.fields["sleeve_id"]?.typed, !sleeveId.isEmpty {
                out[assetId] = sleeveId
            }
        }
        return out
    }
}
