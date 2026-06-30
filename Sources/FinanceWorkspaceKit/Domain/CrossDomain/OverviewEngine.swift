import Foundation

// T030-T032 — OverviewEngine: composes the five KPI cards, the month-over-month panel, and the
// aggregated validation issues. Budget/Savings/Business are live (from BudgetEngine/AccountEngine);
// Investments/Taxes return the typed "data not available" state because PortfolioEngine/TaxEngine
// are Phase-4 stubs (FR-016/017, locked stub contract in core-domain.md §3).

public struct OverviewEngine: Sendable {

    private let accountEngine: AccountEngine
    private let budgetEngine: BudgetEngine

    public init(accountEngine: AccountEngine = .init(), budgetEngine: BudgetEngine = .init()) {
        self.accountEngine = accountEngine
        self.budgetEngine = budgetEngine
    }

    public func dashboard(_ context: WorkspaceContext, asOf: Date,
                          settings: WorkspaceSettings) -> OverviewDashboard {
        let overview = accountEngine.overview(context, asOf: asOf, settings: settings)
        let asOfMonth = PeriodMath.asOfMonth(asOf)

        let cards: [OverviewSummaryCard] = [
            budgetCard(context, asOf: asOf, asOfMonth: asOfMonth),
            savingsCard(overview),
            OverviewSummaryCard.unavailable("investments"),  // PortfolioEngine → Phase 4
            businessCard(overview),
            OverviewSummaryCard.unavailable("taxes"),        // TaxEngine → Phase 4
        ]

        return OverviewDashboard(
            asOfMonth: asOfMonth, cards: cards,
            monthOverMonth: monthOverMonth(context, asOf: asOf),
            issues: ValidationEngine().validate(context).issues)
    }

    // MARK: - Cards

    private func budgetCard(_ context: WorkspaceContext, asOf: Date, asOfMonth: String) -> OverviewSummaryCard {
        guard let budget = context.budgets.first,
              let projection = budgetEngine.overview(budgetId: budget.budgetId, period: asOfMonth,
                                                     in: context, asOf: asOf) else {
            return .unavailable("budget")
        }
        // Current-month income vs estimated spending (fixed + discretionary).
        return OverviewSummaryCard(kind: "budget", state: .available, value: projection.totals.income,
                                   secondaryValue: projection.totals.fixed + projection.totals.discretionary)
    }

    private func savingsCard(_ overview: AccountsOverview) -> OverviewSummaryCard {
        let savings = overview.accounts.filter { $0.accountGroup == .savings }
        let balance = savings.reduce(Decimal(0)) { $0 + $1.currentBalance }
        let inflow = savings.reduce(Decimal(0)) { $0 + $1.monthlyInflow }
        return OverviewSummaryCard(kind: "savings", state: .available, value: balance, secondaryValue: inflow)
    }

    private func businessCard(_ overview: AccountsOverview) -> OverviewSummaryCard {
        let net = overview.groups.filter { $0.groupType == .business }
            .reduce(Decimal(0)) { $0 + $1.ytdNetIncome }
        return OverviewSummaryCard(kind: "business", state: .available, value: net)
    }

    // MARK: - Month-over-month (trailing 6 populated months, gaps skipped — FR-018)

    private func monthOverMonth(_ context: WorkspaceContext, asOf: Date) -> [MonthlySnapshot] {
        var netByMonth: [String: Decimal] = [:]
        var populated: Set<String> = []
        for tx in context.transactions {
            let period = PeriodMath.month(tx.date)
            populated.insert(period)
            switch AccountEngine.classify(tx) {
            case let .income(value): netByMonth[period, default: 0] += value
            case let .expense(value): netByMonth[period, default: 0] -= value
            case let .tax(value): netByMonth[period, default: 0] -= value
            case .none: break
            }
        }
        return PeriodMath.trailingMonths(endingAt: asOf, count: 6)
            .filter { populated.contains($0) }
            .map { MonthlySnapshot(period: $0, netIncome: netByMonth[$0] ?? 0) }
    }
}
