import SwiftUI
import FinanceWorkspaceKit

// T040 — the account-group screen (FR-018): individual-account cards ABOVE the group's inline
// ledger, no sub-tabs (locked decision). Business groups add the P&L summary, monthly
// net-income chart (ledger inline below it), category budgets, and linked-note references
// (references only — Notes viewer is V2).

struct AccountGroupDetailView: View {
    @Environment(AppState.self) private var state
    let accountGroupId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = AccountsViewModel(projections: projections)
                    if let group = viewModel.groupProjection(accountGroupId) {
                        content(viewModel: viewModel, group: group)
                    } else {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "questionmark.folder", title: "Group not found",
                            message: "This account group is no longer in the registry."))
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    @ViewBuilder
    private func content(viewModel: AccountsViewModel, group: AccountGroupProjection) -> some View {
        let name = viewModel.groupName(accountGroupId)
        PageTitleActionsView(
            title: name, breadcrumbs: ["Accounts", name],
            actions: [.writeStub("Import", systemImage: "square.and.arrow.down"),
                      .writeStub("Add", systemImage: "plus")])

        // Account cards above the ledger (no sub-tabs).
        let cards = viewModel.groupSections.first { $0.id == accountGroupId }?.cards ?? []
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: DS.Metrics.kpiGridGap)],
                  spacing: DS.Metrics.kpiGridGap) {
            ForEach(cards) { card in AccountCardView(card: card) }
        }

        if group.groupType == .business {
            businessPanels(viewModel: viewModel, group: group)
        }

        PanelView(title: "Transactions", subtitle: "inline ledger · newest first") {
            LedgerTableView(entries: viewModel.groupLedger(accountGroupId))
        }

        if group.groupType == .business {
            notesPanel(viewModel: viewModel, group: group)
        }
    }

    @ViewBuilder
    private func businessPanels(viewModel: AccountsViewModel, group: AccountGroupProjection) -> some View {
        PanelView(title: "P&L summary",
                  subtitle: "YTD net \(Format.money(group.ytdNetIncome)) · retained equity \(Format.money(group.ytdRetainedEquity))") {
            BarChartView(points: viewModel.businessPLPoints(group), signStyle: .gainLoss,
                         height: DS.Metrics.chartShort)
        }

        let budgetRows = viewModel.categoryBudgetRows(group)
        if !budgetRows.isEmpty {
            PanelView(title: "Category budgets", subtitle: "current month · plan vs actual") {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "cat", title: "Category"),
                        TableColumnSpec(id: "plan", title: "Planned", alignment: .trailing),
                        TableColumnSpec(id: "actual", title: "Actual", alignment: .trailing),
                        TableColumnSpec(id: "var", title: "Variance", alignment: .trailing),
                    ],
                    rows: budgetRows.map { row in
                        TableRowModel(id: row.categoryId, cells: [
                            .text(row.categoryName), .money(row.planned),
                            .money(row.actual), .money(row.variance, signed: true),
                        ])
                    })
                    .frame(height: DataTableView.idealHeight(rows: budgetRows.count, max: 220))
            }
        }
    }

    @ViewBuilder
    private func notesPanel(viewModel: AccountsViewModel, group: AccountGroupProjection) -> some View {
        let notes = viewModel.linkedNotes(group)
        if !notes.isEmpty {
            PanelView(title: "Linked notes", subtitle: "references · viewer arrives in V2") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(notes, id: \.sourceFile) { note in
                        Button {
                            state.inspect(SourceRef(filePath: note.sourceFile, provenance: .imported))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text").foregroundStyle(DS.Colors.muted)
                                Text(note.sourceFile).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                                if let period = note.period {
                                    Text(period).font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct AccountGroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AccountGroupDetailView(accountGroupId: "G1").environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Group — light")
        AccountGroupDetailView(accountGroupId: "G2").environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Group — dark")
    }
}
