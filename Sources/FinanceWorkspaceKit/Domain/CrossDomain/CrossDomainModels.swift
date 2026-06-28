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

public struct AccountSummaryCard: Codable, Equatable, Sendable {
    public var accountId: String
    public var monthlyInflow: Decimal
    public var ytdNetIncome: Decimal
    public init(accountId: String, monthlyInflow: Decimal, ytdNetIncome: Decimal) {
        self.accountId = accountId; self.monthlyInflow = monthlyInflow; self.ytdNetIncome = ytdNetIncome
    }
}

public struct OverviewSummaryCard: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case available, dataNotAvailable }
    public var kind: String
    public var state: State
    public var value: Decimal?
    public init(kind: String, state: State = .dataNotAvailable, value: Decimal? = nil) {
        self.kind = kind; self.state = state; self.value = value
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

public struct TaxPrepSummary: Codable, Equatable, Sendable {
    public var taxYear: Int
    public var complete: Bool
    public init(taxYear: Int, complete: Bool) { self.taxYear = taxYear; self.complete = complete }
}

public struct TaxDeductionSummary: Codable, Equatable, Sendable {
    public var taxYear: Int
    public var totalAdjustments: Decimal
    public init(taxYear: Int, totalAdjustments: Decimal) { self.taxYear = taxYear; self.totalAdjustments = totalAdjustments }
}

public struct BusinessMonthlySummary: Codable, Equatable, Sendable {
    public var accountGroupId: String
    public var period: String
    public var netIncome: Decimal
    public init(accountGroupId: String, period: String, netIncome: Decimal) {
        self.accountGroupId = accountGroupId; self.period = period; self.netIncome = netIncome
    }
}
