import Foundation
import FinanceWorkspaceKit

// T043 — Budget presentation mapper (FR-021/022): the session period drives BudgetEngine
// re-runs over the snapshot's one consistent context (read-only). Pie slices, panel models,
// category rows, drill-down filters, and the history series all pass engine figures through
// untouched (FR-031).

struct BudgetViewModel {
    let projections: WorkspaceProjections

    var defaultBudget: Budget? { projections.context.budgets.first }
    var currentPeriod: String { projections.accounts.asOfMonth }

    /// The engine projection for a (session-scoped) period; nil period = current month.
    func overview(period: String?) -> BudgetOverviewProjection? {
        guard let budget = defaultBudget else { return nil }
        return BudgetEngine().overview(
            budgetId: budget.budgetId, period: period ?? currentPeriod,
            in: projections.context, asOf: projections.asOf)
    }

    // MARK: - Pie (category share of actual spend for the period)

    func pieSlices(_ projection: BudgetOverviewProjection) -> [PieSlice] {
        projection.rows
            .filter { $0.actual != 0 }
            .map { PieSlice(label: $0.categoryName, value: abs($0.actual)) }
    }

    // MARK: - Spend mix & variance panels (50/50)

    struct MixRow: Identifiable {
        var label: String
        var pct: Decimal
        var id: String { label }
    }

    func spendMixRows(_ projection: BudgetOverviewProjection) -> [MixRow] {
        [MixRow(label: "Fixed", pct: projection.spendMix.fixedPct),
         MixRow(label: "Discretionary", pct: projection.spendMix.discretionaryPct),
         MixRow(label: "Savings", pct: projection.spendMix.savingsPct),
         MixRow(label: "Investments", pct: projection.spendMix.investmentPct)]
    }

    /// Variance rows ordered worst-first (largest overspend on top).
    func varianceRows(_ projection: BudgetOverviewProjection) -> [BudgetVarianceRow] {
        projection.rows.sorted { $0.variance > $1.variance }
    }

    // MARK: - Category table

    func tableRows(_ projection: BudgetOverviewProjection) -> [TableRowModel] {
        projection.rows.map { row in
            TableRowModel(id: row.categoryId, cells: [
                .text(row.categoryName),
                .muted(row.behavior.rawValue),
                .money(row.planned),
                .money(row.actual),
                .variance(row.variance),
                CellValue(text: row.trailingAverage.value.map(Format.money) ?? row.trailingAverage.label,
                          style: row.trailingAverage.isPartial ? .muted : .numeric,
                          sortKey: .number(row.trailingAverage.value ?? 0)),
            ])
        }
    }

    // MARK: - Drill-down (category + period filtered transactions)

    func drillDownEntries(categoryId: String, period: String?) -> [LedgerEntry] {
        let target = period ?? currentPeriod
        let rows = projections.context.transactions.filter { txn in
            txn.categoryId == categoryId && PeriodMath.month(txn.date) == target
        }
        return LedgerEntry.entries(from: rows, categoryNames: categoryNames)
    }

    func categoryName(_ categoryId: String) -> String {
        categoryNames[categoryId] ?? categoryId
    }

    // MARK: - History (MoM variance over a range)

    struct HistoryMonth: Identifiable {
        var period: String
        var planned: Decimal
        var actual: Decimal
        var variance: Decimal { actual - planned }
        var id: String { period }
    }

    /// Engine-projected totals per trailing month (skips months with no allocations).
    func history(months: Int) -> [HistoryMonth] {
        guard let budget = defaultBudget else { return [] }
        return PeriodMath.trailingMonths(endingAt: projections.asOf, count: months)
            .compactMap { period in
                guard let projection = BudgetEngine().overview(
                    budgetId: budget.budgetId, period: period,
                    in: projections.context, asOf: projections.asOf),
                    !projection.rows.isEmpty else { return nil }
                let planned = projection.rows.reduce(Decimal(0)) { $0 + $1.planned }
                let actual = projection.rows.reduce(Decimal(0)) { $0 + $1.actual }
                return HistoryMonth(period: period, planned: planned, actual: actual)
            }
    }

    // MARK: - Categories view

    struct CategoryNode: Identifiable {
        var category: FinanceWorkspaceKit.Category
        var children: [FinanceWorkspaceKit.Category]
        var id: String { category.categoryId }
    }

    var categoryTree: [CategoryNode] {
        let all = projections.context.categories
        let roots = all.filter { $0.parentCategoryId == nil }
        return roots.map { root in
            CategoryNode(category: root, children: all.filter { $0.parentCategoryId == root.categoryId })
        }
    }

    var categoryNames: [String: String] { projections.categoryNames }
}
