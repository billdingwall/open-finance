import SwiftUI
import FinanceWorkspaceKit

// T050 — the unified S&I module (FR-023): Overview / Goals / Portfolio sub-navigation (no
// "Categories" — removed R3). The Overview sub-tab is a module summary composed from shared
// components: module-scoped KPI cards, a goals progress snapshot, and the allocation donut.

struct SavingsInvestmentsView: View {
    @Environment(AppState.self) private var state
    let subview: SISubview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                header
                if let projections = state.projections {
                    let viewModel = SavingsInvestmentsViewModel(projections: projections)
                    switch subview {
                    case .overview: overviewTab(viewModel)
                    case .goals: GoalsListView(viewModel: viewModel)
                    case .portfolio: PortfolioView(viewModel: viewModel)
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageTitleActionsView(
                title: "Savings & Investments",
                breadcrumbs: ["Savings & Investments", tabTitle],
                actions: subview == .goals ? [.writeStub("Add goal", systemImage: "plus")] : [])
            Picker("Section", selection: tabBinding) {
                Text("Overview").tag(SISubview.overview)
                Text("Goals").tag(SISubview.goals)
                Text("Portfolio").tag(SISubview.portfolio)
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .labelsHidden()
        }
    }

    private var tabTitle: String {
        switch subview {
        case .overview: return "Overview"
        case .goals: return "Goals"
        case .portfolio: return "Portfolio"
        }
    }

    private var tabBinding: Binding<SISubview> {
        Binding(get: { subview },
                set: { state.router.navigate(to: .savingsInvestments($0)) })
    }

    @ViewBuilder
    private func overviewTab(_ viewModel: SavingsInvestmentsViewModel) -> some View {
        HStack(alignment: .top, spacing: DS.Metrics.kpiGridGap) {
            ForEach(viewModel.summaryCards) { card in KPICardView(model: card) }
        }
        HStack(alignment: .top, spacing: DS.Metrics.panelGap) {
            PanelView(title: "Goals", subtitle: "\(viewModel.goals.count) active") {
                if viewModel.goals.isEmpty {
                    Text("No savings goals yet.").font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.goals) { goal in GoalCardView(goal: goal, compact: true) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            PanelView(title: "Allocation", subtitle: "by sleeve · market value") {
                PieChartView(slices: viewModel.allocationSlices(viewModel.holdings(accountId: nil)),
                             height: DS.Metrics.chartShort + 60)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SavingsInvestmentsView_Previews: PreviewProvider {
    static var previews: some View {
        SavingsInvestmentsView(subview: .overview).environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("S&I — light")
        SavingsInvestmentsView(subview: .overview).environment(AppState())
            .frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("S&I — dark")
    }
}
