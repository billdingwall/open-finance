import Foundation

// T011 — AccountEngine projection value types (data-model.md §B). All Sendable value types.

/// Gross / expenses / taxes / net for one month on one account (transfers excluded both sides).
public struct AccountMonthFigures: Codable, Equatable, Sendable {
    public var period: String          // "YYYY-MM"
    public var gross: Decimal
    public var expenses: Decimal
    public var taxesPaid: Decimal
    public var net: Decimal             // gross − expenses − taxesPaid

    public init(period: String, gross: Decimal, expenses: Decimal, taxesPaid: Decimal) {
        self.period = period
        self.gross = gross
        self.expenses = expenses
        self.taxesPaid = taxesPaid
        self.net = gross - expenses - taxesPaid
    }
}

/// Per-account-group detail. Business P&L populated only for `groupType == .business`.
public struct AccountGroupProjection: Codable, Equatable, Sendable, Identifiable {
    public var accountGroupId: String
    public var groupType: GroupType
    public var accountIds: [String]
    public var ytdNetIncome: Decimal
    public var ytdRetainedEquity: Decimal
    public var businessPL: [BusinessMonthlySummary]?
    public var id: String { accountGroupId }

    public init(accountGroupId: String, groupType: GroupType, accountIds: [String],
                ytdNetIncome: Decimal, ytdRetainedEquity: Decimal,
                businessPL: [BusinessMonthlySummary]? = nil) {
        self.accountGroupId = accountGroupId
        self.groupType = groupType
        self.accountIds = accountIds
        self.ytdNetIncome = ytdNetIncome
        self.ytdRetainedEquity = ytdRetainedEquity
        self.businessPL = businessPL
    }
}

/// Per-account detail screen feed (Phase 5).
public struct AccountDetailProjection: Codable, Equatable, Sendable, Identifiable {
    public var accountId: String
    public var monthly: [AccountMonthFigures]
    public var ytdNetIncome: Decimal
    public var currentBalance: Decimal
    public var liabilityPrincipal: Decimal?
    public var transactions: [UnifiedTransaction]
    public var id: String { accountId }

    public init(accountId: String, monthly: [AccountMonthFigures], ytdNetIncome: Decimal,
                currentBalance: Decimal, liabilityPrincipal: Decimal? = nil,
                transactions: [UnifiedTransaction]) {
        self.accountId = accountId
        self.monthly = monthly
        self.ytdNetIncome = ytdNetIncome
        self.currentBalance = currentBalance
        self.liabilityPrincipal = liabilityPrincipal
        self.transactions = transactions
    }
}

/// Aggregate Accounts overview — the AccountsView feed.
public struct AccountsOverview: Codable, Equatable, Sendable {
    public var asOfMonth: String
    public var taxYear: Int
    public var accounts: [AccountSummaryCard]
    public var groups: [AccountGroupProjection]
    public var totalMonthlyInflow: Decimal
    public var totalYTDNetIncome: Decimal
    public var totalYTDPersonalInflow: Decimal
    public var totalYTDRetainedEquity: Decimal

    public init(asOfMonth: String, taxYear: Int, accounts: [AccountSummaryCard],
                groups: [AccountGroupProjection], totalMonthlyInflow: Decimal,
                totalYTDNetIncome: Decimal, totalYTDPersonalInflow: Decimal,
                totalYTDRetainedEquity: Decimal) {
        self.asOfMonth = asOfMonth
        self.taxYear = taxYear
        self.accounts = accounts
        self.groups = groups
        self.totalMonthlyInflow = totalMonthlyInflow
        self.totalYTDNetIncome = totalYTDNetIncome
        self.totalYTDPersonalInflow = totalYTDPersonalInflow
        self.totalYTDRetainedEquity = totalYTDRetainedEquity
    }
}
