import SwiftUI
import FinanceWorkspaceKit

// T052 — the portfolio view (FR-025): holdings table as the PRIMARY surface with the
// standard ⇄ heat-map toggle (heat map: 8 windows × accounts, S&P 500 comparison row, sector
// performance section); allocation donut + account selector as supporting elements; sleeve
// table at the bottom (target vs actual weight + drift). Typed states render as designed.

struct PortfolioView: View {
    @Environment(AppState.self) private var state
    let viewModel: SavingsInvestmentsViewModel

    var body: some View {
        @Bindable var state = state
        let holdings = viewModel.holdings(accountId: state.selections.portfolioAccountId)

        VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
            controls(state: $state)

            if state.selections.portfolioHeatMap {
                heatMapSurface
            } else {
                holdingsSurface(holdings)
            }

            HStack(alignment: .top, spacing: DS.Metrics.panelGap) {
                PanelView(title: "Allocation", subtitle: "by sleeve · market value") {
                    PieChartView(slices: viewModel.allocationSlices(holdings),
                                 height: DS.Metrics.chartShort + 60)
                }
                .frame(maxWidth: .infinity)
                PanelView(title: "Total",
                          subtitle: "priced positions only") {
                    VStack(alignment: .leading, spacing: 4) {
                        OverlineLabel(text: "Market value")
                        Text(Format.money(holdings.totalMarketValue))
                            .font(DS.Fonts.kpiValue).foregroundStyle(DS.Colors.ink1)
                        Text("\(holdings.positions.count) holdings")
                            .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            sleevePanel(holdings)
        }
    }

    // MARK: - Controls (toggle + account selector)

    private func controls(state: Bindable<AppState>) -> some View {
        HStack(spacing: 10) {
            Picker("View", selection: state.selections.portfolioHeatMap) {
                Text("Holdings").tag(false)
                Text("Heat map").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .labelsHidden()

            Picker("Account", selection: state.selections.portfolioAccountId) {
                Text("All accounts").tag(String?.none)
                ForEach(viewModel.portfolioAccountIds, id: \.self) { accountId in
                    Text(viewModel.accountName(accountId)).tag(String?.some(accountId))
                }
            }
            .frame(width: 220)
            Spacer()
        }
    }

    // MARK: - Holdings (primary surface)

    private func holdingsSurface(_ holdings: HoldingsProjection) -> some View {
        PanelView(title: "Holdings",
                  subtitle: "tap a row for the security detail") {
            if holdings.positions.isEmpty {
                EmptyStateView(model: EmptyStateModel(
                    systemImage: "chart.line.uptrend.xyaxis", title: "No holdings",
                    message: "Positions appear once trades exist in the ledger."))
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "ticker", title: "Security"),
                        TableColumnSpec(id: "qty", title: "Qty", alignment: .trailing, width: 80),
                        TableColumnSpec(id: "basis", title: "Cost basis", alignment: .trailing),
                        TableColumnSpec(id: "value", title: "Value", alignment: .trailing),
                        TableColumnSpec(id: "unrealized", title: "Unrealized G/L", alignment: .trailing),
                    ],
                    rows: viewModel.holdingsRows(holdings),
                    onSelect: { row in state.router.navigate(to: .holding(row.id)) })
                    .frame(height: DataTableView.idealHeight(rows: holdings.positions.count, max: 340))
            }
        }
    }

    // MARK: - Heat map (toggle surface)

    @ViewBuilder private var heatMapSurface: some View {
        PanelView(title: "Benchmark heat map",
                  subtitle: "% growth · 8 windows · vs S&P 500 · 3Y/5Y annualized") {
            HeatMapTableView(model: viewModel.heatMapModel)
        }
        PanelView(title: "Sector performance", subtitle: "share of priced market value") {
            if viewModel.sectorRows.isEmpty {
                Text("Sectors appear when holdings carry a security class.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "sector", title: "Sector"),
                        TableColumnSpec(id: "weight", title: "Weight", alignment: .trailing),
                    ],
                    rows: viewModel.sectorRows)
                    .frame(height: DataTableView.idealHeight(rows: viewModel.sectorRows.count, max: 220))
            }
        }
    }

    // MARK: - Sleeves (bottom)

    private func sleevePanel(_ holdings: HoldingsProjection) -> some View {
        PanelView(title: "Sleeves", subtitle: "target vs actual weight · drift") {
            if holdings.sleeveAllocations.isEmpty {
                Text("Sleeve allocations appear once sleeves and targets are defined.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "sleeve", title: "Sleeve"),
                        TableColumnSpec(id: "value", title: "Value", alignment: .trailing),
                        TableColumnSpec(id: "actual", title: "Actual", alignment: .trailing),
                        TableColumnSpec(id: "target", title: "Target", alignment: .trailing),
                        TableColumnSpec(id: "drift", title: "Drift", alignment: .trailing),
                    ],
                    rows: viewModel.sleeveRows(holdings))
                    .frame(height: DataTableView.idealHeight(rows: holdings.sleeveAllocations.count, max: 220))
            }
        }
    }
}
