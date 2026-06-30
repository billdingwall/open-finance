import Foundation

// T020-T023 — BudgetEngine: plan-vs-actual, trailing averages, spend-mix, goal contributions.
// Pure read model over a budget's resolved scope. Budget "income" is cash actually received (net
// legs / positive standalone) — distinct from AccountEngine's gross-income tax view; the
// informational gross/withholding paycheck legs are skipped here.

public struct BudgetEngine: Sendable {

    public init() {}

    public func overview(budgetId: String, period: String, in context: WorkspaceContext,
                         asOf: Date) -> BudgetOverviewProjection? {
        guard let budget = context.budgets.first(where: { $0.budgetId == budgetId }) else { return nil }
        let scope = resolveScope(budget, accounts: context.accounts)
        let txns = context.transactions
        let categories = context.categories
        let behavior = Dictionary(categories.map { ($0.categoryId, $0.defaultBudgetBehavior) },
                                  uniquingKeysWith: { first, _ in first })
        let name = Dictionary(categories.map { ($0.categoryId, $0.name) }, uniquingKeysWith: { first, _ in first })

        let totals = self.totals(period: period, scope: scope, txns: txns, behavior: behavior)
        let spendMix = self.spendMix(totals)

        // One variance row per allocation line of this budget for the period.
        let allocations = context.budgetAllocations.filter { $0.budgetId == budgetId && $0.period == period }
        let rows = allocations.map { alloc -> BudgetVarianceRow in
            let actual = categoryActual(categoryId: alloc.categoryId, period: period, scope: scope, txns: txns)
            return BudgetVarianceRow(
                categoryId: alloc.categoryId, categoryName: name[alloc.categoryId] ?? alloc.categoryId,
                behavior: behavior[alloc.categoryId] ?? .discretionary, planned: alloc.plannedAmount,
                actual: actual,
                trailingAverage: trailingAverage(categoryId: alloc.categoryId, endingBefore: period,
                                                 in: context, scope: scope))
        }

        return BudgetOverviewProjection(
            budgetId: budgetId, period: period, rows: rows, spendMix: spendMix, totals: totals,
            goalContributions: goalContributions(period: period, scope: scope, txns: txns))
    }

    /// Trailing average of a category's actuals over the up-to-3 months preceding `period`; partial
    /// when fewer than 3 of those months have data, never zero/blank for a category with ≥1 month.
    public func trailingAverage(categoryId: String, endingBefore period: String,
                                in context: WorkspaceContext) -> TrailingAverage {
        trailingAverage(categoryId: categoryId, endingBefore: period, in: context,
                        scope: nil)
    }

    // MARK: - Internals

    private func trailingAverage(categoryId: String, endingBefore period: String,
                                 in context: WorkspaceContext, scope: Set<String>?) -> TrailingAverage {
        let months = PeriodMath.previousMonths(before: period, count: 3)
        let txns = context.transactions
        let actuals = months.compactMap { month -> Decimal? in
            let value = categoryActual(categoryId: categoryId, period: month, scope: scope, txns: txns)
            // "has data" = at least one matching transaction that month.
            let hasData = txns.contains { tx in
                tx.categoryId == categoryId && PeriodMath.month(tx.date) == month
                    && (scope == nil || scope!.contains(tx.accountId))
            }
            return hasData ? value : nil
        }
        guard !actuals.isEmpty else { return TrailingAverage(value: nil, monthsAvailable: 0) }
        let sum = actuals.reduce(Decimal(0), +)
        return TrailingAverage(value: sum / Decimal(actuals.count), monthsAvailable: actuals.count)
    }

    private func resolveScope(_ budget: Budget, accounts: [Account]) -> Set<String> {
        let groupIds = Set(budget.accountGroupIds)
        var scope = Set(budget.accountIds)
        for account in accounts where groupIds.contains(account.accountGroupId) { scope.insert(account.accountId) }
        // An unscoped budget monitors every account.
        return scope.isEmpty ? Set(accounts.map(\.accountId)) : scope
    }

    /// Budget-relevant contribution of a row: skips informational paycheck legs and trades.
    private func inScopeBudgetRows(_ txns: [UnifiedTransaction], period: String,
                                   scope: Set<String>) -> [UnifiedTransaction] {
        txns.filter { tx in
            scope.contains(tx.accountId) && PeriodMath.month(tx.date) == period
                && tx.type != .trade && tx.groupRole != .gross && tx.groupRole != .withholding
        }
    }

    private func totals(period: String, scope: Set<String>, txns: [UnifiedTransaction],
                        behavior: [String: BudgetBehavior]) -> BudgetTotals {
        var income: Decimal = 0, fixed: Decimal = 0, discretionary: Decimal = 0
        var transfers: Decimal = 0, savings: Decimal = 0, investments: Decimal = 0
        for tx in inScopeBudgetRows(txns, period: period, scope: scope) {
            if tx.type == .transfer { transfers += abs(tx.amount); continue }
            if tx.amount > 0 { income += tx.amount; continue }
            let magnitude = abs(tx.amount)
            switch behavior[tx.categoryId ?? ""] ?? .discretionary {
            case .fixed: fixed += magnitude
            case .discretionary: discretionary += magnitude
            case .savings: savings += magnitude
            case .investment: investments += magnitude
            case .transfer: transfers += magnitude
            }
        }
        return BudgetTotals(income: income, fixed: fixed, discretionary: discretionary,
                            transfers: transfers, savings: savings, investments: investments)
    }

    private func spendMix(_ totals: BudgetTotals) -> SpendMix {
        let base = totals.netMonthlyIncome
        func pct(_ value: Decimal) -> Decimal { base == 0 ? 0 : (value / base) * 100 }
        return SpendMix(fixedPct: pct(totals.fixed), discretionaryPct: pct(totals.discretionary),
                        savingsPct: pct(totals.savings), investmentPct: pct(totals.investments))
    }

    /// Magnitude spent/received in a category for a period within scope (nil scope = all accounts).
    private func categoryActual(categoryId: String, period: String, scope: Set<String>?,
                                txns: [UnifiedTransaction]) -> Decimal {
        let total = txns.filter { tx in
            tx.categoryId == categoryId && PeriodMath.month(tx.date) == period
                && tx.type != .trade && tx.groupRole != .gross && tx.groupRole != .withholding
                && (scope == nil || scope!.contains(tx.accountId))
        }.reduce(Decimal(0)) { $0 + $1.amount }
        return abs(total)
    }

    private func goalContributions(period: String, scope: Set<String>,
                                   txns: [UnifiedTransaction]) -> [GoalContributionRow] {
        var byGoal: [String: Decimal] = [:]
        for tx in inScopeBudgetRows(txns, period: period, scope: scope) {
            guard let goalId = tx.savingsGoalId else { continue }
            byGoal[goalId, default: 0] += abs(tx.amount)
        }
        return byGoal.keys.sorted().map { GoalContributionRow(goalId: $0, period: period, amount: byGoal[$0] ?? 0) }
    }
}
