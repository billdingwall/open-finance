import Foundation

// T012 — FIFO lot resolution from `type = trade` ledger rows (research R1). Buys open lots; sells
// consume the oldest open lots first, producing realized disposals (basis + holding period) and the
// remaining open lots (the current holdings). Shared by PortfolioEngine (open lots) and TaxEngine
// (realized gain/loss, split short-/long-term). Pure and deterministic.

public struct OpenLot: Equatable, Sendable {
    public var assetId: String
    public var acquiredDate: Date
    public var remainingQuantity: Decimal
    public var costPerUnit: Decimal
    public var costBasis: Decimal { remainingQuantity * costPerUnit }
}

public struct RealizedDisposal: Equatable, Sendable {
    public var assetId: String
    public var acquiredDate: Date
    public var disposedDate: Date
    public var quantity: Decimal
    public var proceeds: Decimal
    public var costBasis: Decimal
    public var gainLoss: Decimal { proceeds - costBasis }
    public var isLongTerm: Bool { PeriodMath.isLongTerm(acquired: acquiredDate, disposed: disposedDate) }
}

public enum FIFOLots {

    /// Resolve one asset's trades (any order) into remaining open lots + realized disposals.
    /// `asOf`, when set, ignores trades after that date (deterministic holdings as-of a date).
    public static func resolve(trades: [Trade], asOf: Date? = nil) -> (open: [OpenLot], realized: [RealizedDisposal]) {
        let ordered = trades
            .filter { trade in asOf.map { trade.date <= $0 } ?? true }
            .sorted { $0.date < $1.date }
        var open: [OpenLot] = []
        var realized: [RealizedDisposal] = []

        for trade in ordered {
            switch trade.tradeType {
            case .buy:
                open.append(OpenLot(assetId: trade.assetId, acquiredDate: trade.date,
                                    remainingQuantity: trade.quantity, costPerUnit: trade.price))
            case .sell:
                var toSell = trade.quantity
                while toSell > 0, let first = open.first {
                    let take = min(first.remainingQuantity, toSell)
                    realized.append(RealizedDisposal(
                        assetId: trade.assetId, acquiredDate: first.acquiredDate, disposedDate: trade.date,
                        quantity: take, proceeds: take * trade.price, costBasis: take * first.costPerUnit))
                    toSell -= take
                    if take >= first.remainingQuantity {
                        open.removeFirst()
                    } else {
                        open[0].remainingQuantity -= take
                    }
                }
                // Oversell (no lots left) is left unmatched rather than fabricating basis.
            }
        }
        return (open, realized)
    }
}
