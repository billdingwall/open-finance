import Foundation

// T011 — Investments domain models. Portfolio → Sleeve → Asset. Trades fold into the unified ledger.

public struct Asset: Codable, Equatable, Sendable, Identifiable {
    public var assetId: String
    public var ticker: String?
    public var name: String
    public var securityClass: String?      // maps `security_class`; doubles as the sector bucket
    public var accountId: String?          // owning account (Investments/assets.csv#account_id)
    public var currency: String?
    public var id: String { assetId }

    public init(assetId: String, ticker: String? = nil, name: String, securityClass: String? = nil,
                accountId: String? = nil, currency: String? = nil) {
        self.assetId = assetId
        self.ticker = ticker
        self.name = name
        self.securityClass = securityClass
        self.accountId = accountId
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
