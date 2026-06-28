import Foundation

// T011 — Investments domain models. Portfolio → Sleeve → Asset. Trades fold into the unified ledger.

public struct Asset: Codable, Equatable, Sendable, Identifiable {
    public var assetId: String
    public var ticker: String?
    public var name: String
    public var currentValue: Decimal?
    public var securityClass: String?
    public var id: String { assetId }

    public init(assetId: String, ticker: String? = nil, name: String,
                currentValue: Decimal? = nil, securityClass: String? = nil) {
        self.assetId = assetId
        self.ticker = ticker
        self.name = name
        self.currentValue = currentValue
        self.securityClass = securityClass
    }
}

/// Investment trade view (sourced from `type = trade` rows in the unified ledger).
public struct Trade: Codable, Equatable, Sendable, Identifiable {
    public var tradeId: String
    public var accountId: String
    public var assetId: String
    public var date: Date
    public var quantity: Decimal
    public var price: Decimal
    public var id: String { tradeId }

    public init(tradeId: String, accountId: String, assetId: String, date: Date,
                quantity: Decimal, price: Decimal) {
        self.tradeId = tradeId
        self.accountId = accountId
        self.assetId = assetId
        self.date = date
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
    public var id: String { portfolioId }

    public init(portfolioId: String, name: String, accountId: String? = nil) {
        self.portfolioId = portfolioId
        self.name = name
        self.accountId = accountId
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
