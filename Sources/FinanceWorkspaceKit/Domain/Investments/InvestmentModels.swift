import Foundation

// T011 — Investments domain models. Portfolio → Sleeve → Asset. Trades fold into the unified ledger.

public struct Asset: Codable, Equatable, Sendable, Identifiable {
    public var assetId: String
    public var ticker: String?
    public var name: String
    public var securityClass: String?      // maps `security_class`; doubles as the sector bucket
    public var accountId: String?          // owning account (Investments/assets.csv#account_id)
    public var sleeveId: String?           // optional sleeve membership (for allocation/drift)
    public var currency: String?
    public var id: String { assetId }

    public init(assetId: String, ticker: String? = nil, name: String, securityClass: String? = nil,
                accountId: String? = nil, sleeveId: String? = nil, currency: String? = nil) {
        self.assetId = assetId
        self.ticker = ticker
        self.name = name
        self.securityClass = securityClass
        self.accountId = accountId
        self.sleeveId = sleeveId
        self.currency = currency
    }
}

/// A dividend/interest distribution row (`Investments/dividends.csv`).
public struct Dividend: Codable, Equatable, Sendable, Identifiable {
    public var dividendId: String
    public var assetId: String
    public var date: Date
    public var amount: Decimal
    public var id: String { dividendId }

    public init(dividendId: String, assetId: String, date: Date, amount: Decimal) {
        self.dividendId = dividendId
        self.assetId = assetId
        self.date = date
        self.amount = amount
    }
}

/// An open cost-basis lot (`Investments/tax-lots.csv`) — the authoritative holdings/basis source,
/// since ledger `type = trade` rows carry no quantity/price (research R1, schema reality).
public struct TaxLot: Codable, Equatable, Sendable, Identifiable {
    public var lotId: String
    public var assetId: String
    public var acquiredDate: Date
    public var quantity: Decimal
    public var costBasis: Decimal          // total basis for the lot
    public var id: String { lotId }

    public init(lotId: String, assetId: String, acquiredDate: Date, quantity: Decimal, costBasis: Decimal) {
        self.lotId = lotId
        self.assetId = assetId
        self.acquiredDate = acquiredDate
        self.quantity = quantity
        self.costBasis = costBasis
    }
}

public enum TradeType: String, Codable, Sendable, CaseIterable {
    case buy, sell
}

/// Investment trade view (sourced from `type = trade` rows in the unified ledger, which carry the
/// optional `trade_type`/`quantity`/`price` columns and `sending`/`receiving_asset_id`).
public struct Trade: Codable, Equatable, Sendable, Identifiable {
    public var tradeId: String
    public var accountId: String
    public var assetId: String
    public var date: Date
    public var tradeType: TradeType
    public var quantity: Decimal
    public var price: Decimal
    public var id: String { tradeId }

    public init(tradeId: String, accountId: String, assetId: String, date: Date,
                tradeType: TradeType, quantity: Decimal, price: Decimal) {
        self.tradeId = tradeId
        self.accountId = accountId
        self.assetId = assetId
        self.date = date
        self.tradeType = tradeType
        self.quantity = quantity
        self.price = price
    }
}

public struct PricePoint: Codable, Equatable, Sendable, Identifiable {
    public var assetId: String
    public var date: Date
    public var close: Decimal
    public var id: String { "\(assetId)@\(date.timeIntervalSince1970)" }

    public init(assetId: String, date: Date, close: Decimal) {
        self.assetId = assetId
        self.date = date
        self.close = close
    }
}

/// One row of the S&P 500 benchmark series (`Investments/benchmarks/sp500.csv`).
public struct BenchmarkPoint: Codable, Equatable, Sendable {
    public var date: Date
    public var close: Decimal
    public init(date: Date, close: Decimal) { self.date = date; self.close = close }
}

/// Discrete benchmark comparison windows used in the heat map.
public enum BenchmarkWindow: String, Codable, Sendable, CaseIterable {
    case day = "D", week = "W", month = "M"
    case threeMonth = "3M", sixMonth = "6M"
    case oneYear = "1Y", threeYear = "3Y", fiveYear = "5Y"
}

public struct BenchmarkPeriod: Codable, Equatable, Sendable, Identifiable {
    public var window: BenchmarkWindow
    public var startDate: Date
    public var endDate: Date
    public var returnPct: Decimal?
    public var id: String { window.rawValue }

    public init(window: BenchmarkWindow, startDate: Date, endDate: Date, returnPct: Decimal? = nil) {
        self.window = window
        self.startDate = startDate
        self.endDate = endDate
        self.returnPct = returnPct
    }
}

public struct Portfolio: Codable, Equatable, Sendable, Identifiable {
    public var portfolioId: String
    public var name: String
    public var accountId: String?
    public var expectedReturnRate: Decimal?   // optional stored assumption (FR-024a); nil → "rate not set"
    public var id: String { portfolioId }

    public init(portfolioId: String, name: String, accountId: String? = nil,
                expectedReturnRate: Decimal? = nil) {
        self.portfolioId = portfolioId
        self.name = name
        self.accountId = accountId
        self.expectedReturnRate = expectedReturnRate
    }
}

public struct PortfolioSleeve: Codable, Equatable, Sendable, Identifiable {
    public var sleeveId: String
    public var portfolioId: String
    public var name: String
    public var id: String { sleeveId }

    public init(sleeveId: String, portfolioId: String, name: String) {
        self.sleeveId = sleeveId
        self.portfolioId = portfolioId
        self.name = name
    }
}

public struct SleeveTarget: Codable, Equatable, Sendable, Identifiable {
    public var sleeveId: String
    public var targetWeight: Decimal     // 0...1
    public var id: String { sleeveId }

    public init(sleeveId: String, targetWeight: Decimal) {
        self.sleeveId = sleeveId
        self.targetWeight = targetWeight
    }
}

// MARK: - Benchmark projection models (US4)

/// Growth over a window: simple (≤1Y), CAGR (3Y/5Y), or unknown for lack of history.
public enum GrowthState: Equatable, Sendable {
    case simple(Decimal)
    case cagr(Decimal)
    case insufficientHistory

    public var value: Decimal? {
        switch self { case let .simple(value), let .cagr(value): return value; case .insufficientHistory: return nil }
    }
}

public struct BenchmarkCell: Equatable, Sendable, Identifiable {
    public var window: BenchmarkWindow
    public var growth: GrowthState
    public var id: String { window.rawValue }
    public init(window: BenchmarkWindow, growth: GrowthState) { self.window = window; self.growth = growth }
}

/// One heat-map row (the S&P 500 benchmark, or a portfolio account) across all 8 windows.
public struct HeatMapRow: Equatable, Sendable, Identifiable {
    public var label: String
    public var cells: [BenchmarkCell]
    public var id: String { label }
    public init(label: String, cells: [BenchmarkCell]) { self.label = label; self.cells = cells }
}

/// Period × account heat map plus portfolio sector weights (FR-010/011/012/013).
public struct HeatMap: Equatable, Sendable {
    public var benchmark: HeatMapRow
    public var accounts: [HeatMapRow]
    public var sectorWeights: [SectorWeight]
    public init(benchmark: HeatMapRow, accounts: [HeatMapRow], sectorWeights: [SectorWeight]) {
        self.benchmark = benchmark; self.accounts = accounts; self.sectorWeights = sectorWeights
    }
}

public struct SectorWeight: Equatable, Sendable, Identifiable {
    public var sector: String
    public var weight: Decimal           // share of priced portfolio market value
    public var id: String { sector }
    public init(sector: String, weight: Decimal) { self.sector = sector; self.weight = weight }
}

// MARK: - Portfolio projection models (US1)

/// A derived money value that may be unknown because no price exists for the asset (FR-009).
public enum ValueState: Equatable, Sendable {
    case value(Decimal)
    case priceUnavailable

    public var decimal: Decimal? { if case let .value(amount) = self { return amount }; return nil }
}

/// A holding position, aggregated across FIFO-open lots for one asset.
public struct Position: Equatable, Sendable, Identifiable {
    public var assetId: String
    public var ticker: String?
    public var accountId: String?
    public var sleeveId: String?
    public var quantity: Decimal
    public var costBasis: Decimal
    public var currentValue: ValueState
    public var unrealizedGainLoss: ValueState
    public var id: String { assetId }

    public init(assetId: String, ticker: String?, accountId: String?, sleeveId: String?,
                quantity: Decimal, costBasis: Decimal,
                currentValue: ValueState, unrealizedGainLoss: ValueState) {
        self.assetId = assetId
        self.ticker = ticker
        self.accountId = accountId
        self.sleeveId = sleeveId
        self.quantity = quantity
        self.costBasis = costBasis
        self.currentValue = currentValue
        self.unrealizedGainLoss = unrealizedGainLoss
    }
}

/// A sleeve's actual vs target weight and drift (FR-007).
public struct SleeveAllocation: Equatable, Sendable, Identifiable {
    public var sleeveId: String
    public var name: String
    public var marketValue: Decimal
    public var actualWeight: Decimal          // share of the portfolio's priced market value
    public var targetWeight: Decimal?
    public var drift: Decimal?                 // actualWeight − targetWeight
    public var id: String { sleeveId }

    public init(sleeveId: String, name: String, marketValue: Decimal, actualWeight: Decimal,
                targetWeight: Decimal?, drift: Decimal?) {
        self.sleeveId = sleeveId
        self.name = name
        self.marketValue = marketValue
        self.actualWeight = actualWeight
        self.targetWeight = targetWeight
        self.drift = drift
    }
}

/// Aggregate or per-account holdings projection.
public struct HoldingsProjection: Equatable, Sendable {
    public enum Scope: Equatable, Sendable { case aggregate; case account(String) }
    public var scope: Scope
    public var positions: [Position]
    public var sleeveAllocations: [SleeveAllocation]
    public var dividendTotalsByAsset: [String: Decimal]
    public var dividendTotalsByAccount: [String: Decimal]
    public var totalMarketValue: Decimal       // sum of priced positions only

    public init(scope: Scope, positions: [Position], sleeveAllocations: [SleeveAllocation],
                dividendTotalsByAsset: [String: Decimal], dividendTotalsByAccount: [String: Decimal],
                totalMarketValue: Decimal) {
        self.scope = scope
        self.positions = positions
        self.sleeveAllocations = sleeveAllocations
        self.dividendTotalsByAsset = dividendTotalsByAsset
        self.dividendTotalsByAccount = dividendTotalsByAccount
        self.totalMarketValue = totalMarketValue
    }
}
