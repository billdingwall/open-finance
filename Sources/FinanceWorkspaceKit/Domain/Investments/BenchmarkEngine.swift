import Foundation

// US4 (T034-T035) — read-only benchmark heat map. For each of the 8 windows: simple return (≤1Y) or
// CAGR (3Y/5Y) from calendar-anchored, last-close-on-or-before values, for the S&P 500 series and for
// each portfolio account's value series (reusing PortfolioEngine valuation as-of a date). Anchors
// predating the available history report .insufficientHistory. Sector weights from priced holdings.
// (No benchmark sector data ships, so sector-vs-benchmark comparison is out of scope — FR-010..013.)

public struct BenchmarkEngine: Sendable {
    public init() {}

    public func heatMap(_ context: WorkspaceContext, asOf: Date) -> HeatMap {
        let series = context.benchmarkSeries                          // sorted ascending
        let seriesStart = series.first?.date
        let benchmarkRow = HeatMapRow(label: "S&P 500", cells: BenchmarkWindow.allCases.map { window in
            BenchmarkCell(window: window, growth: growth(
                window: window, asOf: asOf, seriesStart: seriesStart,
                valueAt: { PeriodMath.lastValueOnOrBefore(series, date: $0, dateOf: \.date, valueOf: \.close) }))
        })

        // Portfolio accounts: those referenced by a portfolio, else any account holding assets.
        let portfolioAccounts = context.portfolios.compactMap(\.accountId)
        let holdingAccounts = Set(context.trades.map(\.accountId))
        let accountIds = (portfolioAccounts.isEmpty ? Array(holdingAccounts) : portfolioAccounts).sorted()

        let engine = PortfolioEngine()
        let tradesByAccount = Dictionary(grouping: context.trades, by: \.accountId)
        let accountRows: [HeatMapRow] = accountIds.map { accountId in
            let firstTrade = tradesByAccount[accountId]?.map(\.date).min()
            let cells = BenchmarkWindow.allCases.map { window in
                BenchmarkCell(window: window, growth: growth(
                    window: window, asOf: asOf, seriesStart: firstTrade,
                    valueAt: { date in
                        let mv = engine.holdings(context, asOf: date, scope: .account(accountId)).totalMarketValue
                        return mv > 0 ? mv : nil
                    }))
            }
            return HeatMapRow(label: accountId, cells: cells)
        }

        return HeatMap(benchmark: benchmarkRow, accounts: accountRows, sectorWeights: sectorWeights(context, asOf: asOf))
    }

    /// Growth for one window from a value-at-date closure; simple ≤1Y, CAGR for 3Y/5Y.
    private func growth(window: BenchmarkWindow, asOf: Date, seriesStart: Date?,
                        valueAt: (Date) -> Decimal?) -> GrowthState {
        guard let start = PeriodMath.windowStart(window, asOf: asOf) else { return .insufficientHistory }
        if let seriesStart, start < seriesStart { return .insufficientHistory }   // anchor predates history
        guard let begin = valueAt(start), let end = valueAt(asOf), begin > 0 else { return .insufficientHistory }
        if PeriodMath.isMultiYear(window) {
            return PeriodMath.cagr(begin: begin, end: end, years: PeriodMath.years(for: window)).map(GrowthState.cagr)
                ?? .insufficientHistory
        }
        return PeriodMath.simpleReturn(begin: begin, end: end).map(GrowthState.simple) ?? .insufficientHistory
    }

    /// Portfolio sector weights from priced holdings (sector = asset `security_class`).
    private func sectorWeights(_ context: WorkspaceContext, asOf: Date) -> [SectorWeight] {
        let holdings = PortfolioEngine().holdings(context, asOf: asOf, scope: .aggregate)
        guard holdings.totalMarketValue > 0 else { return [] }
        let assetsById = Dictionary(context.assets.map { ($0.assetId, $0) }, uniquingKeysWith: { first, _ in first })
        var mvBySector: [String: Decimal] = [:]
        for position in holdings.positions {
            guard let mv = position.currentValue.decimal else { continue }
            let sector = assetsById[position.assetId]?.securityClass ?? "unclassified"
            mvBySector[sector, default: 0] += mv
        }
        return mvBySector.map { SectorWeight(sector: $0.key, weight: $0.value / holdings.totalMarketValue) }
            .sorted { $0.sector < $1.sector }
    }
}
