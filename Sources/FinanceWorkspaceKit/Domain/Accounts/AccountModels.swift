import Foundation

// T007 — Accounts domain models. Account is the single master registry struct
// (no InvestmentAccount subtype); investment fields live in optional InvestmentMetadata.

public enum AccountGroupClass: String, Codable, Sendable, CaseIterable {
    case employment, business, investment, savings, checking, loan
    case creditCard = "credit_card"
}

public enum AccountStatus: String, Codable, Sendable, CaseIterable {
    case draft, active, frozen, closed
}

public enum GroupType: String, Codable, Sendable, CaseIterable {
    case personal, employment, business, custom
}

/// Investment-specific metadata, present only on `account_group == .investment` rows.
public struct InvestmentMetadata: Codable, Equatable, Sendable {
    public var taxTreatment: String?
    public var performanceTracking: Bool?
    public init(taxTreatment: String? = nil, performanceTracking: Bool? = nil) {
        self.taxTreatment = taxTreatment
        self.performanceTracking = performanceTracking
    }
}

/// Master account registry entity (`Accounts/accounts.csv`).
public struct Account: Codable, Equatable, Sendable, Identifiable {
    public var accountId: String
    public var displayName: String
    public var institution: String
    public var accountGroup: AccountGroupClass
    public var accountType: String
    public var status: AccountStatus
    public var accountGroupId: String
    public var currentBalance: Decimal?          // derived/cached for display
    public var investment: InvestmentMetadata?

    public var id: String { accountId }
    public var isActive: Bool { status == .active }

    public init(accountId: String, displayName: String, institution: String,
                accountGroup: AccountGroupClass, accountType: String, status: AccountStatus,
                accountGroupId: String, currentBalance: Decimal? = nil,
                investment: InvestmentMetadata? = nil) {
        self.accountId = accountId
        self.displayName = displayName
        self.institution = institution
        self.accountGroup = accountGroup
        self.accountType = accountType
        self.status = status
        self.accountGroupId = accountGroupId
        self.currentBalance = currentBalance
        self.investment = investment
    }
}

/// First-class account-group object (`Accounts/account-groups.csv`).
public struct AccountGroup: Codable, Equatable, Sendable, Identifiable {
    public var accountGroupId: String
    public var name: String
    public var groupType: GroupType
    public var id: String { accountGroupId }

    public init(accountGroupId: String, name: String, groupType: GroupType) {
        self.accountGroupId = accountGroupId
        self.name = name
        self.groupType = groupType
    }
}

/// First-class peer of Asset, held within an account (`Accounts/liabilities.csv`).
public struct Liability: Codable, Equatable, Sendable, Identifiable {
    public var liabilityId: String
    public var accountId: String
    public var principalBalance: Decimal?        // derived from the ledger
    public var interestRate: Decimal?
    public var termMonths: Int?
    public var id: String { liabilityId }

    public init(liabilityId: String, accountId: String, principalBalance: Decimal? = nil,
                interestRate: Decimal? = nil, termMonths: Int? = nil) {
        self.liabilityId = liabilityId
        self.accountId = accountId
        self.principalBalance = principalBalance
        self.interestRate = interestRate
        self.termMonths = termMonths
    }
}

public struct AccountRule: Codable, Equatable, Sendable, Identifiable {
    public var ruleId: String
    public var accountId: String
    public var kind: String
    public var value: String
    public var id: String { ruleId }
    public init(ruleId: String, accountId: String, kind: String, value: String) {
        self.ruleId = ruleId; self.accountId = accountId; self.kind = kind; self.value = value
    }
}

public struct AccountEstimate: Codable, Equatable, Sendable, Identifiable {
    public var estimateId: String
    public var accountId: String
    public var metric: String
    public var amount: Decimal
    public var id: String { estimateId }
    public init(estimateId: String, accountId: String, metric: String, amount: Decimal) {
        self.estimateId = estimateId; self.accountId = accountId
        self.metric = metric; self.amount = amount
    }
}
