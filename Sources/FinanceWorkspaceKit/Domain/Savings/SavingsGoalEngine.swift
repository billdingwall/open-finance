import Foundation

// US5 (T039) — read-only savings-goal projection. Balance is snapshot-anchored (latest
// SavingsProgress) else ledger-derived (goal-tagged contributions); months-to-goal uses the
// trailing-3-month contribution rate (FR-001..004 / research R4). Archived goals are excluded;
// `completed` is derived. Never writes.

public struct SavingsGoalEngine: Sendable {
    public init() {}

    public func projectGoals(_ context: WorkspaceContext, asOf: Date) -> [GoalProgressProjection] {
        let latestSnapshot = context.latestProgressByGoal
        // Goal-tagged contributions up to the as-of date, grouped by goal.
        let taggedByGoal = Dictionary(grouping: context.transactions.filter {
            $0.savingsGoalId != nil && $0.date <= asOf
        }, by: { $0.savingsGoalId! })

        return context.savingsGoals
            .filter { $0.status != .archived }
            .map { goal in
                let contributions = taggedByGoal[goal.goalId] ?? []

                let balance: Decimal
                let source: GoalProgressProjection.BalanceSource
                if let snapshot = latestSnapshot[goal.goalId] {
                    balance = snapshot.balance
                    source = .snapshot
                } else {
                    balance = contributions.reduce(Decimal(0)) { $0 + $1.amount }
                    source = .ledgerDerived
                }

                let gap = max(0, goal.targetAmount - balance)
                let rate = trailingRate(contributions, asOf: asOf)
                let monthsToGoal: Int? = {
                    guard gap > 0, let r = rate.value, r > 0 else { return gap <= 0 ? 0 : nil }
                    let months = NSDecimalNumber(decimal: gap).doubleValue / NSDecimalNumber(decimal: r).doubleValue
                    return Int(months.rounded(.up))
                }()

                let links = contributions.map { GoalFundingLink(goalId: goal.goalId, transactionId: $0.transactionId) }
                return GoalProgressProjection(
                    goalId: goal.goalId, name: goal.name, targetAmount: goal.targetAmount,
                    currentBalance: balance, balanceSource: source, gapToTarget: gap,
                    monthsToGoal: monthsToGoal, trailingContributionRate: rate,
                    isCompleteDerived: balance >= goal.targetAmount && goal.targetAmount > 0,
                    fundingLinks: links)
            }
            .sorted { $0.goalId < $1.goalId }
    }

    /// Mean monthly contribution over the trailing 3 months that actually have contributions
    /// (partial-aware, mirroring the BudgetEngine convention).
    private func trailingRate(_ contributions: [UnifiedTransaction], asOf: Date) -> TrailingAverage {
        let months = PeriodMath.trailingMonths(endingAt: asOf, count: 3)
        var byMonth: [String: Decimal] = [:]
        for tx in contributions {
            byMonth[PeriodMath.month(tx.date), default: 0] += tx.amount
        }
        let present = months.compactMap { byMonth[$0] }
        guard !present.isEmpty else { return TrailingAverage(value: nil, monthsAvailable: 0) }
        let total = present.reduce(Decimal(0), +)
        return TrailingAverage(value: total / Decimal(present.count), monthsAvailable: present.count)
    }
}
