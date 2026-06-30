import Foundation

// T019 — BudgetEngine projection value types (data-model.md §C).

/// 3-month trailing average with a data-sufficiency signal (FR-012 / research R7).
public struct TrailingAverage: Codable, Equatable, Sendable {
    public var value: Decimal?       // nil only when monthsAvailable == 0
    public var monthsAvailable: Int  // 0…3
    public var isPartial: Bool       // monthsAvailable < 3

    public init(value: Decimal?, monthsAvailable: Int) {
        self.value = value
        self.monthsAvailable = monthsAvailable
        self.isPartial = monthsAvailable < 3
    }

    /// Phase-5 label, e.g. "avg of 1 mo" / "3-mo avg" / "—".
    public var label: String {
        switch monthsAvailable {
        case 0: return "—"
        case 3: return "3-mo avg"
        default: return "avg of \(monthsAvailable) mo"
        }
    }
}

/// Each behavior as a percentage of net monthly income (FR-013).
public struct SpendMix: Codable, Equatable, Sendable {
    public var fixedPct: Decimal
    public var discretionaryPct: Decimal
    public var savingsPct: Decimal
    public var investmentPct: Decimal
    public init(fixedPct: Decimal, discretionaryPct: Decimal, savingsPct: Decimal, investmentPct: Decimal) {
        self.fixedPct = fixedPct
        self.discretionaryPct = discretionaryPct
        self.savingsPct = savingsPct
        self.investmentPct = investmentPct
    }
}

public struct BudgetTotals: Codable, Equatable, Sendable {
    public var income: Decimal
    public var fixed: Decimal
    public var discretionary: Decimal
    public var transfers: Decimal
    public var savings: Decimal
    public var investments: Decimal
    public var netMonthlyIncome: Decimal   // income − (fixed + discretionary)
    public init(income: Decimal, fixed: Decimal, discretionary: Decimal, transfers: Decimal,
                savings: Decimal, investments: Decimal) {
        self.income = income
        self.fixed = fixed
        self.discretionary = discretionary
        self.transfers = transfers
        self.savings = savings
        self.investments = investments
        self.netMonthlyIncome = income - fixed - discretionary
    }
}

public struct BudgetVarianceRow: Codable, Equatable, Sendable, Identifiable {
    public var categoryId: String
    public var categoryName: String
    public var behavior: BudgetBehavior
    public var planned: Decimal
    public var actual: Decimal
    public var variance: Decimal        // actual − planned
    public var trailingAverage: TrailingAverage
    public var id: String { categoryId }

    public init(categoryId: String, categoryName: String, behavior: BudgetBehavior,
                planned: Decimal, actual: Decimal, trailingAverage: TrailingAverage) {
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.behavior = behavior
        self.planned = planned
        self.actual = actual
        self.variance = actual - planned
        self.trailingAverage = trailingAverage
    }
}

public struct GoalContributionRow: Codable, Equatable, Sendable {
    public var goalId: String
    public var period: String
    public var amount: Decimal
    public init(goalId: String, period: String, amount: Decimal) {
        self.goalId = goalId
        self.period = period
        self.amount = amount
    }
}

public struct BudgetOverviewProjection: Codable, Equatable, Sendable {
    public var budgetId: String
    public var period: String
    public var rows: [BudgetVarianceRow]
    public var spendMix: SpendMix
    public var totals: BudgetTotals
    public var goalContributions: [GoalContributionRow]
    public init(budgetId: String, period: String, rows: [BudgetVarianceRow], spendMix: SpendMix,
                totals: BudgetTotals, goalContributions: [GoalContributionRow]) {
        self.budgetId = budgetId
        self.period = period
        self.rows = rows
        self.spendMix = spendMix
        self.totals = totals
        self.goalContributions = goalContributions
    }
}
