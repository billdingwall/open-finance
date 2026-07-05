import SwiftUI
import FinanceWorkspaceKit

// T046 — budget history (FR-022): month-over-month variance across a selectable trailing
// range. The range is a session selection (clarify Q1).

struct BudgetHistoryView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                HStack(alignment: .firstTextBaseline) {
                    PageTitleActionsView(title: "Budget history", breadcrumbs: ["Budget", "History"])
                    Picker("Range", selection: $state.selections.budgetHistoryMonths) {
                        Text("3 months").tag(3)
                        Text("6 months").tag(6)
                        Text("12 months").tag(12)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .labelsHidden()
                }
                if let projections = state.projections {
                    let viewModel = BudgetViewModel(projections: projections)
                    let months = viewModel.history(months: state.selections.budgetHistoryMonths)
                    if months.isEmpty {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "clock.arrow.circlepath", title: "No budget history",
                            message: "Months with budget allocations appear here."))
                    } else {
                        PanelView(title: "Variance by month", subtitle: "actual − planned") {
                            BarChartView(points: months.map {
                                BarPoint(label: Format.monthName($0.period), value: $0.variance)
                            }, signStyle: .variance)
                        }
                        PanelView(title: "Months") {
                            DataTableView(
                                columns: [
                                    TableColumnSpec(id: "period", title: "Month"),
                                    TableColumnSpec(id: "planned", title: "Planned", alignment: .trailing),
                                    TableColumnSpec(id: "actual", title: "Actual", alignment: .trailing),
                                    TableColumnSpec(id: "variance", title: "Variance", alignment: .trailing),
                                ],
                                rows: months.map { month in
                                    TableRowModel(id: month.period, cells: [
                                        .text(Format.monthName(month.period)),
                                        .money(month.planned), .money(month.actual),
                                        .variance(month.variance),
                                    ])
                                })
                                .frame(height: DataTableView.idealHeight(rows: months.count, max: 320))
                        }
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }
}

struct BudgetHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetHistoryView().environment(AppState()).frame(width: 980, height: 640)
            .preferredColorScheme(.light).previewDisplayName("History — light")
        BudgetHistoryView().environment(AppState()).frame(width: 980, height: 640)
            .preferredColorScheme(.dark).previewDisplayName("History — dark")
    }
}
