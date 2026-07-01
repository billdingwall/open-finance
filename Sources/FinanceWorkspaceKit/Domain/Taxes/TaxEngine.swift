import Foundation

// US2 (T019-T020) — read-only tax read model for a tax year. Per-account YTD taxable income
// (positive standard income rows), taxes paid (ledger withholding legs), effective rate, dividend
// (dividends.csv) + interest (interest-categorized income) aggregation, and realized gain/loss from
// FIFO lots split short-/long-term (FR-014/015/016 / research R1/R7). Never writes.

public struct TaxEngine: Sendable {
    public init() {}

    public struct Projection: Sendable, Equatable {
        public var taxYear: Int
        public var accounts: [AccountTaxProjection]
        public var realized: RealizedGainSummary
    }

    public func project(_ context: WorkspaceContext, taxYear: Int) -> Projection {
        let inYear: (Date) -> Bool = { PeriodMath.calendarYear($0) == taxYear }

        // Interest categories (by name heuristic: contains "interest").
        let interestCategoryIds = Set(context.categories
            .filter { $0.name.lowercased().contains("interest") }
            .map { $0.categoryId })

        var grossByAccount: [String: Decimal] = [:]
        var interestByAccount: [String: Decimal] = [:]
        var withholdingByAccount: [String: Decimal] = [:]
        for tx in context.transactions where inYear(tx.date) {
            if tx.groupRole == .withholding {
                withholdingByAccount[tx.accountId, default: 0] += abs(tx.amount)
                continue
            }
            guard tx.type == .standard, tx.amount > 0 else { continue }   // income rows only
            grossByAccount[tx.accountId, default: 0] += tx.amount
            if let cat = tx.categoryId, interestCategoryIds.contains(cat) {
                interestByAccount[tx.accountId, default: 0] += tx.amount
            }
        }

        // Dividends per account (via asset → account).
        let accountByAsset = Dictionary(context.assets.compactMap { a in a.accountId.map { (a.assetId, $0) } },
                                        uniquingKeysWith: { a, _ in a })
        var dividendByAccount: [String: Decimal] = [:]
        for d in context.dividends where inYear(d.date) {
            if let account = accountByAsset[d.assetId] { dividendByAccount[account, default: 0] += d.amount }
        }

        let accountIds = Set(grossByAccount.keys)
            .union(withholdingByAccount.keys).union(dividendByAccount.keys).union(interestByAccount.keys)
        let accounts = accountIds.map { id -> AccountTaxProjection in
            let gross = grossByAccount[id] ?? 0
            let paid = withholdingByAccount[id] ?? 0
            return AccountTaxProjection(
                accountId: id, ytdTaxableIncome: gross, taxesPaid: paid,
                dividendIncome: dividendByAccount[id] ?? 0, interestIncome: interestByAccount[id] ?? 0,
                effectiveRate: gross > 0 ? paid / gross : nil)
        }.sorted { $0.accountId < $1.accountId }

        return Projection(taxYear: taxYear, accounts: accounts, realized: realizedGains(context, taxYear: taxYear))
    }

    /// FIFO realized gain/loss for the tax year, split short-/long-term by holding period.
    public func realizedGains(_ context: WorkspaceContext, taxYear: Int) -> RealizedGainSummary {
        let tradesByAsset = Dictionary(grouping: context.trades, by: \.assetId)
        var lots: [RealizedDisposal] = []
        for (_, trades) in tradesByAsset {
            let (_, realized) = FIFOLots.resolve(trades: trades)          // full history (no as-of cutoff)
            lots.append(contentsOf: realized.filter { PeriodMath.calendarYear($0.disposedDate) == taxYear })
        }
        lots.sort { $0.disposedDate < $1.disposedDate }
        let shortTerm = lots.filter { !$0.isLongTerm }.reduce(Decimal(0)) { $0 + $1.gainLoss }
        let longTerm = lots.filter { $0.isLongTerm }.reduce(Decimal(0)) { $0 + $1.gainLoss }
        return RealizedGainSummary(taxYear: taxYear, shortTermGainLoss: shortTerm,
                                   longTermGainLoss: longTerm, lots: lots)
    }
}
