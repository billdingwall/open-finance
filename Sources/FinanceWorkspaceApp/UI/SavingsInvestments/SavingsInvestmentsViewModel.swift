import Foundation
import FinanceWorkspaceKit

// T048 — Savings & Investments presentation mapper (FR-023–026): goals (flat list, engine
// projections), holdings with typed price states, allocation donut, sleeve drift, the heat-map
// grid (values pass through), and the holding detail's FIFO lots / trade history / dividends.
// The only arithmetic is presentation grouping (per-month contribution sums of the engine's
// funding links, labeled derived).

struct SavingsInvestmentsViewModel {
    let projections: WorkspaceProjections

    // MARK: - Goals (FR-024)

    var goals: [GoalProgressProjection] { projections.goals }

    func goal(_ goalId: String) -> GoalProgressProjection? {
        goals.first { $0.goalId == goalId }
    }

    /// Progress-history points for the goal's snapshots (engine-anchored balances).
    func progressHistory(_ goalId: String) -> [SparkPoint] {
        projections.context.savingsProgress
            .filter { $0.goalId == goalId }
            .sorted { $0.asOf < $1.asOf }
            .map { SparkPoint(period: Format.date($0.asOf), value: $0.balance) }
    }

    /// The funding-link transactions, resolved to traceable ledger rows.
    func fundingTransactions(_ goal: GoalProgressProjection) -> [UnifiedTransaction] {
        let ids = Set(goal.fundingLinks.map(\.transactionId))
        return projections.context.transactions
            .filter { ids.contains($0.transactionId) }
            .sorted { $0.date > $1.date }
    }

    struct MonthlyContribution: Identifiable {
        var period: String
        var amount: Decimal
        var id: String { period }
    }

    /// Per-month sums of the engine-identified funding rows (presentation grouping, derived).
    func monthlyContributions(_ goal: GoalProgressProjection) -> [MonthlyContribution] {
        let byMonth = Dictionary(grouping: fundingTransactions(goal)) { PeriodMath.month($0.date) }
        return byMonth.keys.sorted().map { period in
            MonthlyContribution(period: period,
                                amount: byMonth[period]!.reduce(Decimal(0)) { $0 + $1.amount })
        }
    }

    // MARK: - Portfolio (FR-025)

    /// Accounts that carry trades — the account-selector options.
    var portfolioAccountIds: [String] {
        Array(Set(projections.context.trades.map(\.accountId))).sorted()
    }

    func accountName(_ accountId: String) -> String {
        projections.accounts.accounts.first { $0.accountId == accountId }?.displayName ?? accountId
    }

    /// Holdings for the session scope (nil account = aggregate). Aggregate reuses the
    /// snapshot's projection; a selected account re-runs the engine over the same context.
    func holdings(accountId: String?) -> HoldingsProjection {
        guard let accountId else { return projections.holdings }
        return PortfolioEngine().holdings(projections.context, asOf: projections.asOf,
                                          scope: .account(accountId))
    }

    func holdingsRows(_ holdings: HoldingsProjection) -> [TableRowModel] {
        holdings.positions.map { position in
            let ledgerRef = tradeSourceRef(assetId: position.assetId)
            return TableRowModel(id: position.assetId, cells: [
                .text(position.ticker ?? position.assetId),
                .number(position.quantity, display: Format.quantity(position.quantity)),
                .money(position.costBasis),
                valueCell(position.currentValue, signed: false),
                valueCell(position.unrealizedGainLoss, signed: true),
            ], sourceRef: ledgerRef)
        }
    }

    private func valueCell(_ state: ValueState, signed: Bool) -> CellValue {
        switch state {
        case .value(let amount): return .money(amount, signed: signed)
        case .priceUnavailable:
            return CellValue(text: TypedStateText.priceUnavailable, style: .muted, sortKey: .number(0))
        }
    }

    func allocationSlices(_ holdings: HoldingsProjection) -> [PieSlice] {
        holdings.sleeveAllocations.map { PieSlice(label: $0.name, value: $0.marketValue) }
    }

    func sleeveRows(_ holdings: HoldingsProjection) -> [TableRowModel] {
        holdings.sleeveAllocations.map { sleeve in
            TableRowModel(id: sleeve.sleeveId, cells: [
                .text(sleeve.name),
                .money(sleeve.marketValue),
                .number(sleeve.actualWeight, display: Format.percent(sleeve.actualWeight)),
                sleeve.targetWeight.map { CellValue.number($0, display: Format.percent($0)) } ?? .muted("—"),
                sleeve.drift.map { drift in
                    CellValue(text: Format.signedPercent(drift),
                              style: abs(drift) > Decimal(0.05) ? (drift > 0 ? .pos : .neg) : .numeric,
                              sortKey: .number(drift))
                } ?? .muted("—"),
            ])
        }
    }

    var heatMapModel: HeatMapModel { HeatMapModel(heatMap: projections.heatMap) }

    var sectorRows: [TableRowModel] {
        projections.heatMap.sectorWeights.map { sector in
            TableRowModel(id: sector.sector, cells: [
                .text(sector.sector),
                .number(sector.weight, display: Format.percent(sector.weight)),
            ])
        }
    }

    // MARK: - Holding detail (FR-026)

    struct HoldingDetail {
        var asset: Asset
        var position: Position?
        var openLots: [OpenLot]
        var disposals: [RealizedDisposal]
        var trades: [Trade]
        var dividends: [Dividend]
    }

    func holdingDetail(_ assetId: String) -> HoldingDetail? {
        guard let asset = projections.context.assets.first(where: { $0.assetId == assetId }) else { return nil }
        let trades = projections.context.trades
            .filter { $0.assetId == assetId }
            .sorted { $0.date > $1.date }
        let (open, realized) = FIFOLots.resolve(trades: trades, asOf: projections.asOf)
        return HoldingDetail(
            asset: asset,
            position: projections.holdings.positions.first { $0.assetId == assetId },
            openLots: open, disposals: realized, trades: trades,
            dividends: projections.context.dividends
                .filter { $0.assetId == assetId }
                .sorted { $0.date > $1.date })
    }

    /// A trade's provenance via its underlying ledger row (tradeId == transactionId).
    func tradeSourceRef(tradeId: String) -> SourceRef? {
        projections.context.transactions.first { $0.transactionId == tradeId }?.sourceRef
    }

    /// The most recent trade row for an asset — the holdings row's traceability anchor.
    private func tradeSourceRef(assetId: String) -> SourceRef? {
        let latest = projections.context.trades
            .filter { $0.assetId == assetId }
            .max { $0.date < $1.date }
        return latest.flatMap { tradeSourceRef(tradeId: $0.tradeId) }
    }

    // MARK: - Module overview tab (contracts/module-views.md)

    var summaryCards: [KPICardModel] {
        let dashboard = OverviewViewModel(dashboard: projections.dashboard)
        return dashboard.cards(projections: projections).filter { $0.id == "savings" || $0.id == "investments" }
    }
}
