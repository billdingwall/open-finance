import SwiftUI
import FinanceWorkspaceKit

// T045/T046 — the Budget module (FR-021/022). BudgetModuleView routes the three subviews;
// the overview renders the category pie, Spend Mix / Spending Variance panels at 50/50, the
// category table (plan/actual/variance/3-mo trailing), a session-scoped period selector, and
// the category drill-down (filtered transactions with back navigation).

struct BudgetModuleView: View {
    let subview: BudgetSubview

    var body: some View {
        switch subview {
        case .overview: BudgetOverviewView()
        case .history: BudgetHistoryView()
        case .categories: BudgetCategoriesView()
        }
    }
}

struct BudgetOverviewView: View {
    @Environment(AppState.self) private var state
    @State private var drillDownCategory: String?

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = BudgetViewModel(projections: projections)
                    header(viewModel, period: $state.selections.budgetPeriod)
                    if let projection = viewModel.overview(period: state.selections.budgetPeriod) {
                        if let categoryId = drillDownCategory {
                            drillDown(viewModel, categoryId: categoryId,
                                      period: state.selections.budgetPeriod)
                        } else {
                            overviewBody(viewModel, projection: projection)
                        }
                    } else {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "chart.pie", title: "No budget",
                            message: "Budgets appear once Budget/budgets.csv has rows.",
                            ctaTitle: "Add budget",
                            ctaEnabled: state.writesEnabled,
                            ctaAction: { state.addBudget() },
                            ctaDisabledReason: state.writeGateReason))
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func header(_ viewModel: BudgetViewModel, period: Binding<String?>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PageTitleActionsView(title: "Budget", breadcrumbs: ["Budget", "Overview"])
            PeriodSelectorView(period: period, currentPeriod: viewModel.currentPeriod)
        }
    }

    @ViewBuilder
    private func overviewBody(_ viewModel: BudgetViewModel, projection: BudgetOverviewProjection) -> some View {
        PanelView(title: "Spending by category",
                  subtitle: "\(Format.monthName(projection.period)) · actuals") {
            PieChartView(slices: viewModel.pieSlices(projection))
        }

        // Spend Mix / Spending Variance at 50/50 (locked decision).
        HStack(alignment: .top, spacing: DS.Metrics.panelGap) {
            PanelView(title: "Spend mix", subtitle: "% of net monthly income") {
                spendMix(viewModel.spendMixRows(projection))
            }
            .frame(maxWidth: .infinity)
            PanelView(title: "Spending variance", subtitle: "actual − planned · worst first") {
                variance(viewModel.varianceRows(projection))
            }
            .frame(maxWidth: .infinity)
        }

        PanelView(title: "Categories",
                  subtitle: "plan vs actual · 3-mo trailing average") {
            DataTableView(
                columns: [
                    TableColumnSpec(id: "cat", title: "Category"),
                    TableColumnSpec(id: "behavior", title: "Behavior", width: 110),
                    TableColumnSpec(id: "planned", title: "Planned", alignment: .trailing),
                    TableColumnSpec(id: "actual", title: "Actual", alignment: .trailing),
                    TableColumnSpec(id: "variance", title: "Variance", alignment: .trailing),
                    TableColumnSpec(id: "trailing", title: "3-mo avg", alignment: .trailing),
                ],
                rows: viewModel.tableRows(projection),
                onSelect: { row in drillDownCategory = row.id })
                .frame(height: DataTableView.idealHeight(rows: projection.rows.count, max: 320))
        }
    }

    private func spendMix(_ rows: [BudgetViewModel.MixRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.label).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                        .frame(width: 100, alignment: .leading)
                    ProgressBarView(value: row.pct, total: 1, height: 8, cornerRadius: 2)
                    Text(Format.percent(row.pct, digits: 0))
                        .font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink3)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    private func variance(_ rows: [BudgetVarianceRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.prefix(6)) { row in
                HStack {
                    Text(row.categoryName).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                    Spacer()
                    Text(Format.money(row.variance))
                        .font(DS.Fonts.tableNumeric)
                        .foregroundStyle(row.variance > 0 ? DS.Colors.neg : DS.Colors.pos)
                        .help(row.variance > 0 ? "Over plan" : "Under plan")
                }
                .frame(height: 22)
            }
            if rows.isEmpty {
                Text("No allocations this period.").font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            }
        }
    }

    @ViewBuilder
    private func drillDown(_ viewModel: BudgetViewModel, categoryId: String, period: String?) -> some View {
        PanelView(title: viewModel.categoryName(categoryId),
                  subtitle: "transactions · \(Format.monthName(period ?? viewModel.currentPeriod))") {
            VStack(alignment: .leading, spacing: 10) {
                Button("← Back to budget") { drillDownCategory = nil }
                    .buttonStyle(GhostButtonStyle())
                LedgerTableView(entries: viewModel.drillDownEntries(
                    categoryId: categoryId, period: period))
            }
        }
    }
}

struct BudgetOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetOverviewView().environment(AppState()).frame(width: 980, height: 720)
            .preferredColorScheme(.light).previewDisplayName("Budget — light")
        BudgetOverviewView().environment(AppState()).frame(width: 980, height: 720)
            .preferredColorScheme(.dark).previewDisplayName("Budget — dark")
    }
}
