import Foundation

// US1 (T012-T015) — read-only investment holdings projection. Positions come from FIFO-open lots
// (FIFOLots) valued at the last close on-or-before the as-of date; sleeve allocation/drift from
// asset→sleeve membership vs sleeve-targets; dividend totals from dividends.csv. Never writes.
// Degrades to `.priceUnavailable` when an asset has no price (FR-005/007/008/009).

public struct PortfolioEngine: Sendable {
    public init() {}

    public func holdings(_ context: WorkspaceContext, asOf: Date,
                         scope: HoldingsProjection.Scope = .aggregate) -> HoldingsProjection {
        let assetsById = Dictionary(context.assets.map { ($0.assetId, $0) }, uniquingKeysWith: { a, _ in a })
        let pricesByAsset = context.pricesByAsset

        // Scope → the set of accounts in play (nil = all).
        let accountFilter: String? = { if case let .account(id) = scope { return id }; return nil }()

        // Trades grouped by asset, restricted to the scope's account when set.
        let scopedTrades = context.trades.filter { accountFilter == nil || $0.accountId == accountFilter }
        let tradesByAsset = Dictionary(grouping: scopedTrades, by: \.assetId)

        var positions: [Position] = []
        for (assetId, trades) in tradesByAsset {
            let (open, _) = FIFOLots.resolve(trades: trades, asOf: asOf)
            let quantity = open.reduce(Decimal(0)) { $0 + $1.remainingQuantity }
            guard quantity > 0 else { continue }                       // fully sold → not a holding
            let costBasis = open.reduce(Decimal(0)) { $0 + $1.costBasis }
            let asset = assetsById[assetId]
            let value: ValueState
            let unrealized: ValueState
            if let close = PeriodMath.lastValueOnOrBefore(pricesByAsset[assetId] ?? [], date: asOf,
                                                          dateOf: \.date, valueOf: \.close) {
                let mv = quantity * close
                value = .value(mv)
                unrealized = .value(mv - costBasis)
            } else {
                value = .priceUnavailable
                unrealized = .priceUnavailable
            }
            positions.append(Position(assetId: assetId, ticker: asset?.ticker, accountId: asset?.accountId,
                                      sleeveId: asset?.sleeveId, quantity: quantity, costBasis: costBasis,
                                      currentValue: value, unrealizedGainLoss: unrealized))
        }
        positions.sort { $0.assetId < $1.assetId }

        let totalMarketValue = positions.compactMap { $0.currentValue.decimal }.reduce(0, +)
        let sleeveAllocations = buildSleeveAllocations(context, positions: positions, total: totalMarketValue)
        let (byAsset, byAccount) = dividendTotals(context, asOf: asOf, assetsById: assetsById, accountFilter: accountFilter)

        return HoldingsProjection(scope: scope, positions: positions, sleeveAllocations: sleeveAllocations,
                                  dividendTotalsByAsset: byAsset, dividendTotalsByAccount: byAccount,
                                  totalMarketValue: totalMarketValue)
    }

    // MARK: - Sleeve allocation & drift (FR-007)

    private func buildSleeveAllocations(_ context: WorkspaceContext, positions: [Position],
                                        total: Decimal) -> [SleeveAllocation] {
        guard total > 0 else { return [] }
        let sleevesById = Dictionary(context.sleeves.map { ($0.sleeveId, $0) }, uniquingKeysWith: { a, _ in a })
        let targetsBySleeve = Dictionary(context.sleeveTargets.map { ($0.sleeveId, $0.targetWeight) },
                                         uniquingKeysWith: { a, _ in a })
        var mvBySleeve: [String: Decimal] = [:]
        for position in positions {
            guard let sleeveId = position.sleeveId, let mv = position.currentValue.decimal else { continue }
            mvBySleeve[sleeveId, default: 0] += mv
        }
        return mvBySleeve.map { sleeveId, mv in
            let actual = mv / total
            let target = targetsBySleeve[sleeveId]
            return SleeveAllocation(sleeveId: sleeveId, name: sleevesById[sleeveId]?.name ?? sleeveId,
                                    marketValue: mv, actualWeight: actual, targetWeight: target,
                                    drift: target.map { actual - $0 })
        }.sorted { $0.sleeveId < $1.sleeveId }
    }

    // MARK: - Dividends (FR-008)

    private func dividendTotals(_ context: WorkspaceContext, asOf: Date, assetsById: [String: Asset],
                                accountFilter: String?) -> (byAsset: [String: Decimal], byAccount: [String: Decimal]) {
        var byAsset: [String: Decimal] = [:]
        var byAccount: [String: Decimal] = [:]
        for dividend in context.dividends where dividend.date <= asOf {
            let account = assetsById[dividend.assetId]?.accountId
            if let accountFilter, account != accountFilter { continue }
            byAsset[dividend.assetId, default: 0] += dividend.amount
            if let account { byAccount[account, default: 0] += dividend.amount }
        }
        return (byAsset, byAccount)
    }
}
