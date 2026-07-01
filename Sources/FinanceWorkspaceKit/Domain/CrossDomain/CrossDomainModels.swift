import Foundation

// T013 — NoteDocument + cross-domain projection model definitions (types only in Phase 1;
// populated by engines in Phase 3+).

public enum NoteType: String, Codable, Sendable, CaseIterable {
    case workspace, monthlyReview = "monthly-review", strategy
    case taxNote = "tax-note", annualPrepChecklist = "annual-prep-checklist"
    case businessReview = "business-review", savingsPlan = "savings-plan"
    case sleeveStrategy = "sleeve-strategy"
}

/// In v1, Markdown files are parsed for front-matter metadata only (body rendering is V2).
public struct NoteDocument: Codable, Equatable, Sendable, Identifiable {
    public var noteId: String
    public var type: NoteType
    public var path: String
    public var period: String?
    public var linkedAccountIds: [String]
    public var linkedSleeveIds: [String]
    public var taxYear: Int?
    public var createdAt: Date?
    public var id: String { noteId }

    public init(noteId: String, type: NoteType, path: String, period: String? = nil,
                linkedAccountIds: [String] = [], linkedSleeveIds: [String] = [],
                taxYear: Int? = nil, createdAt: Date? = nil) {
        self.noteId = noteId
        self.type = type
        self.path = path
        self.period = period
        self.linkedAccountIds = linkedAccountIds
        self.linkedSleeveIds = linkedSleeveIds
        self.taxYear = taxYear
        self.createdAt = createdAt
    }
}

// MARK: - Cross-domain projections (definitions only)

public struct AccountSummaryCard: Codable, Equatable, Sendable, Identifiable {
    public var accountId: String
    public var displayName: String
    public var accountGroup: AccountGroupClass
    public var monthlyInflow: Decimal
    public var ytdNetIncome: Decimal
    public var currentBalance: Decimal
    /// True when the monthly figures were projected from account rules (no txns this month — FR-006).
    public var isProjected: Bool
    public var id: String { accountId }

    public init(accountId: String, displayName: String, accountGroup: AccountGroupClass,
                monthlyInflow: Decimal, ytdNetIncome: Decimal, currentBalance: Decimal,
                isProjected: Bool = false) {
        self.accountId = accountId
        self.displayName = displayName
        self.accountGroup = accountGroup
        self.monthlyInflow = monthlyInflow
        self.ytdNetIncome = ytdNetIncome
        self.currentBalance = currentBalance
        self.isProjected = isProjected
    }
}

/// A stored (not derived) estimated rate; `.rateNotSet` when the source field is absent (FR-024a).
public enum RateState: Codable, Equatable, Sendable {
    case value(Decimal)
    case rateNotSet
}

public struct OverviewSummaryCard: Codable, Equatable, Sendable, Identifiable {
    public enum State: String, Codable, Sendable { case available, dataNotAvailable }
    public var kind: String          // "budget" | "savings" | "investments" | "business" | "taxes"
    public var state: State
    public var value: Decimal?       // primary value
    public var secondaryValue: Decimal?
    public var estimatedRate: RateState?   // investments/savings only (FR-024a)
    public var id: String { kind }
    public init(kind: String, state: State = .dataNotAvailable, value: Decimal? = nil,
                secondaryValue: Decimal? = nil, estimatedRate: RateState? = nil) {
        self.kind = kind; self.state = state; self.value = value
        self.secondaryValue = secondaryValue; self.estimatedRate = estimatedRate
    }

    /// A typed "data not available" card for a stub domain (Phase 3 — FR-017).
    public static func unavailable(_ kind: String) -> OverviewSummaryCard {
        OverviewSummaryCard(kind: kind, state: .dataNotAvailable)
    }
}

/// Portfolio realized gains → tax engine input (FR-023).
public struct PortfolioTaxLink: Equatable, Sendable {
    public var taxYear: Int
    public var shortTermGainLoss: Decimal
    public var longTermGainLoss: Decimal
    public init(taxYear: Int, shortTermGainLoss: Decimal, longTermGainLoss: Decimal) {
        self.taxYear = taxYear; self.shortTermGainLoss = shortTermGainLoss; self.longTermGainLoss = longTermGainLoss
    }
}

/// Business-expense (Schedule C) adjustment → owning account-group (FR-023).
public struct ScheduleCLink: Equatable, Sendable, Identifiable {
    public var taxAdjustmentId: String
    public var accountGroupId: String
    public var amount: Decimal
    public var id: String { taxAdjustmentId }
    public init(taxAdjustmentId: String, accountGroupId: String, amount: Decimal) {
        self.taxAdjustmentId = taxAdjustmentId; self.accountGroupId = accountGroupId; self.amount = amount
    }
}

/// The composed Overview dashboard feed (FR-016/018/019).
public struct OverviewDashboard: Sendable, Equatable {
    public var asOfMonth: String
    public var cards: [OverviewSummaryCard]            // exactly 5: budget, savings, investments, business, taxes
    public var monthOverMonth: [MonthlySnapshot]       // trailing 6 populated months, gaps skipped
    public var issues: [ValidationIssue]
    public init(asOfMonth: String, cards: [OverviewSummaryCard], monthOverMonth: [MonthlySnapshot],
                issues: [ValidationIssue]) {
        self.asOfMonth = asOfMonth
        self.cards = cards
        self.monthOverMonth = monthOverMonth
        self.issues = issues
    }
}

public struct MonthlySnapshot: Codable, Equatable, Sendable {
    public var period: String
    public var netIncome: Decimal
    public init(period: String, netIncome: Decimal) { self.period = period; self.netIncome = netIncome }
}

public struct GoalFundingLink: Codable, Equatable, Sendable {
    public var goalId: String
    public var transactionId: String
    public init(goalId: String, transactionId: String) { self.goalId = goalId; self.transactionId = transactionId }
}

public struct SleeveFundingLink: Codable, Equatable, Sendable {
    public var sleeveId: String
    public var transactionId: String
    public init(sleeveId: String, transactionId: String) { self.sleeveId = sleeveId; self.transactionId = transactionId }
}

// TaxPrepSummary and TaxDeductionSummary now live in Domain/Taxes/TaxModels.swift (US3), superseding
// the Phase-3 stubs that were here.

public struct BusinessMonthlySummary: Codable, Equatable, Sendable {
    public var accountGroupId: String
    public var period: String
    public var netIncome: Decimal
    public init(accountGroupId: String, period: String, netIncome: Decimal) {
        self.accountGroupId = accountGroupId; self.period = period; self.netIncome = netIncome
    }
}
