import Foundation

// T030-T032, T044 — OverviewEngine: composes the five KPI cards, the month-over-month panel, and the
// aggregated validation issues. All five are now live (Phase 4): Budget/Savings/Business from
// BudgetEngine/AccountEngine; Investments from PortfolioEngine; Taxes from TaxEngine/TaxAdjustmentEngine.
// The Investments/Savings estimated rate is a stored field → "rate not set" when absent (FR-024/024a).

public struct OverviewEngine: Sendable {

    private let accountEngine: AccountEngine
    private let budgetEngine: BudgetEngine
    private let portfolioEngine: PortfolioEngine
    private let taxEngine: TaxEngine
    private let taxAdjustmentEngine: TaxAdjustmentEngine

    public init(accountEngine: AccountEngine = .init(), budgetEngine: BudgetEngine = .init(),
                portfolioEngine: PortfolioEngine = .init(), taxEngine: TaxEngine = .init(),
                taxAdjustmentEngine: TaxAdjustmentEngine = .init()) {
        self.accountEngine = accountEngine
        self.budgetEngine = budgetEngine
        self.portfolioEngine = portfolioEngine
        self.taxEngine = taxEngine
        self.taxAdjustmentEngine = taxAdjustmentEngine
    }

    public func dashboard(_ context: WorkspaceContext, asOf: Date,
                          settings: WorkspaceSettings) -> OverviewDashboard {
        let overview = accountEngine.overview(context, asOf: asOf, settings: settings)
        let asOfMonth = PeriodMath.asOfMonth(asOf)

        let cards: [OverviewSummaryCard] = [
            budgetCard(context, asOf: asOf, asOfMonth: asOfMonth),
            savingsCard(context, overview: overview),
            investmentsCard(context, asOf: asOf),
            businessCard(overview),
            taxesCard(context, settings: settings),
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

    private func savingsCard(_ context: WorkspaceContext, overview: AccountsOverview) -> OverviewSummaryCard {
        let savings = overview.accounts.filter { $0.accountGroup == .savings }
        let balance = savings.reduce(Decimal(0)) { $0 + $1.currentBalance }
        let inflow = savings.reduce(Decimal(0)) { $0 + $1.monthlyInflow }
        // Estimated rate = a stored savings-account APY (first savings account carrying one).
        let savingsIds = Set(savings.map(\.accountId))
        let apy = context.accounts.first { savingsIds.contains($0.accountId) && $0.apy != nil }?.apy
        return OverviewSummaryCard(kind: "savings", state: .available, value: balance, secondaryValue: inflow,
                                   estimatedRate: apy.map(RateState.value) ?? .rateNotSet)
    }

    private func investmentsCard(_ context: WorkspaceContext, asOf: Date) -> OverviewSummaryCard {
        let holdings = portfolioEngine.holdings(context, asOf: asOf, scope: .aggregate)
        // Estimated rate = a stored portfolio expected-return rate (FR-024a); else "rate not set".
        let rate = context.portfolios.first { $0.expectedReturnRate != nil }?.expectedReturnRate
        return OverviewSummaryCard(kind: "investments", state: .available, value: holdings.totalMarketValue,
                                   estimatedRate: rate.map(RateState.value) ?? .rateNotSet)
    }

    private func businessCard(_ overview: AccountsOverview) -> OverviewSummaryCard {
        let net = overview.groups.filter { $0.groupType == .business }
            .reduce(Decimal(0)) { $0 + $1.ytdNetIncome }
        return OverviewSummaryCard(kind: "business", state: .available, value: net)
    }

    private func taxesCard(_ context: WorkspaceContext, settings: WorkspaceSettings) -> OverviewSummaryCard {
        let estimate = taxAdjustmentEngine.taxEstimate(context, settings: settings)
        // Primary = estimated return; secondary = taxes paid (FR-024).
        return OverviewSummaryCard(kind: "taxes", state: .available, value: estimate.estimatedReturn,
                                   secondaryValue: estimate.taxesPaid)
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
