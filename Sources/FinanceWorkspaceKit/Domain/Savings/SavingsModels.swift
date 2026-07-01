import Foundation

// T010 — Savings domain models. Goal lifecycle is the minimal active|archived (v1, [FIX-S7]).

public enum SavingsGoalStatus: String, Codable, Sendable, CaseIterable {
    case active, archived
}

public struct SavingsGoal: Codable, Equatable, Sendable, Identifiable {
    public var goalId: String
    public var name: String
    public var targetAmount: Decimal
    public var targetDate: Date?
    public var monthlyTarget: Decimal?
    public var sourceAccountId: String?
    public var status: SavingsGoalStatus
    public var linkedNoteId: String?
    public var id: String { goalId }

    public init(goalId: String, name: String, targetAmount: Decimal, targetDate: Date? = nil,
                monthlyTarget: Decimal? = nil, sourceAccountId: String? = nil,
                status: SavingsGoalStatus = .active, linkedNoteId: String? = nil) {
        self.goalId = goalId
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.monthlyTarget = monthlyTarget
        self.sourceAccountId = sourceAccountId
        self.status = status
        self.linkedNoteId = linkedNoteId
    }
}

public struct SavingsProgress: Codable, Equatable, Sendable, Identifiable {
    public var progressId: String
    public var goalId: String
    public var asOf: Date
    public var balance: Decimal
    public var id: String { progressId }

    public init(progressId: String, goalId: String, asOf: Date, balance: Decimal) {
        self.progressId = progressId
        self.goalId = goalId
        self.asOf = asOf
        self.balance = balance
    }
}

// MARK: - Savings projection model (US5)

/// Per-goal progress projection (FR-001..004). Archived goals are excluded upstream;
/// `isCompleteDerived` is derived from progress ≥ target (no stored "completed" state).
public struct GoalProgressProjection: Equatable, Sendable, Identifiable {
    public enum BalanceSource: String, Equatable, Sendable { case snapshot, ledgerDerived }
    public var goalId: String
    public var name: String
    public var targetAmount: Decimal
    public var currentBalance: Decimal
    public var balanceSource: BalanceSource
    public var gapToTarget: Decimal
    public var monthsToGoal: Int?                // nil = "n/a" (rate ≤ 0 / unknown)
    public var trailingContributionRate: TrailingAverage
    public var isCompleteDerived: Bool
    public var fundingLinks: [GoalFundingLink]
    public var id: String { goalId }

    public init(goalId: String, name: String, targetAmount: Decimal, currentBalance: Decimal,
                balanceSource: BalanceSource, gapToTarget: Decimal, monthsToGoal: Int?,
                trailingContributionRate: TrailingAverage, isCompleteDerived: Bool,
                fundingLinks: [GoalFundingLink]) {
        self.goalId = goalId
        self.name = name
        self.targetAmount = targetAmount
        self.currentBalance = currentBalance
        self.balanceSource = balanceSource
        self.gapToTarget = gapToTarget
        self.monthsToGoal = monthsToGoal
        self.trailingContributionRate = trailingContributionRate
        self.isCompleteDerived = isCompleteDerived
        self.fundingLinks = fundingLinks
    }
}
