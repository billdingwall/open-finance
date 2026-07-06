import SwiftUI
import FinanceWorkspaceKit

// T041 — the per-account screen (FR-019): transactions ledger, monthly gross vs expenses/tax
// chart, YTD net income, and the rules & estimates panel. Import/Add/Edit are live sync-gated
// local actions (008 US1); delete is inside the edit flow.

struct AccountDetailView: View {
    @Environment(AppState.self) private var state
    let accountId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = AccountsViewModel(projections: projections)
                    if let detail = viewModel.accountDetail(accountId) {
                        content(viewModel: viewModel, detail: detail)
                    } else {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "questionmark.circle", title: "Account not found",
                            message: "This account is no longer in the registry."))
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    @ViewBuilder
    private func content(viewModel: AccountsViewModel, detail: AccountDetailProjection) -> some View {
        let name = viewModel.accountName(accountId)
        PageTitleActionsView(
            title: name, breadcrumbs: ["Accounts", name],
            actions: [.write("Import", systemImage: "square.and.arrow.down", state: state) { state.showingImport = true },
                      .write("Add", systemImage: "plus", state: state) { state.addAccount() },
                      .write("Edit", systemImage: "pencil", state: state) { state.editAccount(accountId) }])

        headerFigures(detail)

        PanelView(title: "Monthly gross vs expenses & taxes", subtitle: "per populated month") {
            GroupedBarChartView(points: viewModel.monthlySeries(detail))
        }

        PanelView(title: "Transactions", subtitle: "\(detail.transactions.count) rows · newest first") {
            LedgerTableView(entries: viewModel.accountLedger(detail))
        }

        rulesPanel(viewModel.rules(accountId))
    }

    private func headerFigures(_ detail: AccountDetailProjection) -> some View {
        PanelView(title: "Position") {
            HStack(spacing: DS.Metrics.contentPaddingH) {
                FigureView(label: "Balance", value: detail.currentBalance)
                FigureView(label: "YTD net income", value: detail.ytdNetIncome)
                if let principal = detail.liabilityPrincipal {
                    FigureView(label: "Liability principal", value: principal, sign: .liability)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func rulesPanel(_ rules: [AccountRule]) -> some View {
        PanelView(title: "Rules & estimates",
                  subtitle: rules.isEmpty ? "none configured" : "\(rules.count) active") {
            if rules.isEmpty {
                Text("Account rules (recurring amounts, projections) appear here.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "rule", title: "Rule"),
                        TableColumnSpec(id: "type", title: "Type"),
                        TableColumnSpec(id: "freq", title: "Frequency"),
                        TableColumnSpec(id: "amount", title: "Amount", alignment: .trailing),
                    ],
                    rows: rules.map { rule in
                        TableRowModel(id: rule.ruleId, cells: [
                            .text(rule.ruleId),
                            .muted(rule.ruleType?.rawValue ?? "—"),
                            .muted(rule.frequency?.rawValue ?? "—"),
                            rule.amount.map { CellValue.money($0) } ?? .muted("—"),
                        ], tag: rule.isActive ? nil : (kind: .warn, label: "inactive"))
                    })
                    .frame(height: DataTableView.idealHeight(rows: rules.count, max: 200))
            }
        }
    }
}

struct AccountDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AccountDetailView(accountId: "A1").environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Account — light")
        AccountDetailView(accountId: "A1").environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Account — dark")
    }
}
