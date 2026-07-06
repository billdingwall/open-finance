import SwiftUI
import FinanceWorkspaceKit

// T051 — goal detail (FR-024): progress history chart (snapshot balances), funding-source
// links resolved to traceable ledger rows, and the monthly contribution tracker (per-month
// sums of the engine's funding links, labeled derived).

struct GoalDetailView: View {
    @Environment(AppState.self) private var state
    let goalId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = SavingsInvestmentsViewModel(projections: projections)
                    if let goal = viewModel.goal(goalId) {
                        content(viewModel: viewModel, goal: goal)
                    } else {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "questionmark.circle", title: "Goal not found",
                            message: "This goal is no longer active."))
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    @ViewBuilder
    private func content(viewModel: SavingsInvestmentsViewModel, goal: GoalProgressProjection) -> some View {
        PageTitleActionsView(
            title: goal.name, breadcrumbs: ["Savings & Investments", "Goals", goal.name],
            actions: [.write("Edit", systemImage: "pencil", state: state) { state.editGoal(goalId) }])

        GoalCardView(goal: goal, compact: false)

        let history = viewModel.progressHistory(goalId)
        PanelView(title: "Progress history",
                  subtitle: history.isEmpty ? "no snapshots" : "\(history.count) snapshots") {
            SparklineView(points: history)
        }

        let contributions = viewModel.monthlyContributions(goal)
        PanelView(title: "Monthly contributions") {
            if contributions.isEmpty {
                Text("No goal-tagged contributions yet.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                HStack(spacing: 4) {
                    BarChartView(points: contributions.map {
                        BarPoint(label: Format.monthName($0.period), value: $0.amount)
                    })
                    ValueProvenanceLabel(provenance: .derived)
                }
            }
        }

        PanelView(title: "Funding sources",
                  subtitle: "goal-tagged ledger rows · every row traceable") {
            let rows = viewModel.fundingTransactions(goal)
            if rows.isEmpty {
                Text("Rows tagged with this goal's id appear here.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "date", title: "Date", width: 100),
                        TableColumnSpec(id: "account", title: "Account"),
                        TableColumnSpec(id: "amount", title: "Amount", alignment: .trailing),
                    ],
                    rows: rows.map { txn in
                        TableRowModel(id: txn.transactionId, cells: [
                            .text(Format.date(txn.date)),
                            .text(viewModel.accountName(txn.accountId)),
                            .money(txn.amount, signed: true),
                        ], sourceRef: txn.sourceRef)
                    },
                    onSelect: { row in
                        if let ref = row.sourceRef { state.inspect(ref) }
                    })
                    .frame(height: DataTableView.idealHeight(rows: rows.count, max: 260))
            }
        }
    }
}

struct GoalDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GoalDetailView(goalId: "SG1").environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Goal — light")
        GoalDetailView(goalId: "SG1").environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Goal — dark")
    }
}
