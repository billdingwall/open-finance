import SwiftUI
import FinanceWorkspaceKit

// T053 — holding detail (FR-026): security detail, FIFO tax-lot drill-down (open lots +
// realized disposals), trade history, and the dividend summary — every row traceable to its
// ledger source (tradeId == transactionId).

struct HoldingDetailView: View {
    @Environment(AppState.self) private var state
    let assetId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = SavingsInvestmentsViewModel(projections: projections)
                    if let detail = viewModel.holdingDetail(assetId) {
                        content(viewModel: viewModel, detail: detail)
                    } else {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "questionmark.circle", title: "Security not found",
                            message: "This asset is no longer in Investments/assets.csv."))
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    @ViewBuilder
    private func content(viewModel: SavingsInvestmentsViewModel,
                         detail: SavingsInvestmentsViewModel.HoldingDetail) -> some View {
        let title = detail.asset.ticker ?? detail.asset.assetId
        PageTitleActionsView(
            title: title,
            breadcrumbs: ["Savings & Investments", "Portfolio", title])

        securityPanel(detail)
        lotsPanel(viewModel: viewModel, detail: detail)
        tradesPanel(viewModel: viewModel, detail: detail)
        dividendsPanel(detail)
    }

    private func securityPanel(_ detail: SavingsInvestmentsViewModel.HoldingDetail) -> some View {
        PanelView(title: "Security", subtitle: detail.asset.name) {
            HStack(spacing: DS.Metrics.contentPaddingH) {
                labeled("Class", detail.asset.securityClass ?? "—")
                labeled("Account", detail.asset.accountId ?? "—")
                if let position = detail.position {
                    labeled("Quantity", Format.quantity(position.quantity))
                    labeled("Cost basis", Format.money(position.costBasis))
                    labeled("Value", valueText(position.currentValue))
                    labeled("Unrealized G/L", valueText(position.unrealizedGainLoss))
                } else {
                    labeled("Position", "fully sold / none open")
                }
                Spacer()
            }
        }
    }

    private func valueText(_ state: ValueState) -> String {
        switch state {
        case .value(let amount): return Format.money(amount)
        case .priceUnavailable: return TypedStateText.priceUnavailable
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            OverlineLabel(text: label)
            Text(value).font(DS.Fonts.bodyNumeric).foregroundStyle(DS.Colors.ink2)
        }
    }

    private func lotsPanel(viewModel: SavingsInvestmentsViewModel,
                           detail: SavingsInvestmentsViewModel.HoldingDetail) -> some View {
        PanelView(title: "Tax lots",
                  subtitle: "FIFO · \(detail.openLots.count) open · \(detail.disposals.count) realized") {
            VStack(alignment: .leading, spacing: 10) {
                if !detail.openLots.isEmpty {
                    OverlineLabel(text: "Open lots")
                    DataTableView(
                        columns: [
                            TableColumnSpec(id: "acq", title: "Acquired", width: 100),
                            TableColumnSpec(id: "qty", title: "Qty", alignment: .trailing),
                            TableColumnSpec(id: "unit", title: "Cost/unit", alignment: .trailing),
                            TableColumnSpec(id: "basis", title: "Basis", alignment: .trailing),
                        ],
                        rows: detail.openLots.enumerated().map { index, lot in
                            TableRowModel(id: "open-\(index)", cells: [
                                .text(Format.date(lot.acquiredDate)),
                                .number(lot.remainingQuantity, display: Format.quantity(lot.remainingQuantity)),
                                .money(lot.costPerUnit), .money(lot.costBasis),
                            ])
                        })
                        .frame(height: DataTableView.idealHeight(rows: detail.openLots.count, max: 200))
                }
                if !detail.disposals.isEmpty {
                    OverlineLabel(text: "Realized disposals")
                    DataTableView(
                        columns: [
                            TableColumnSpec(id: "acq", title: "Acquired", width: 100),
                            TableColumnSpec(id: "disp", title: "Disposed", width: 100),
                            TableColumnSpec(id: "qty", title: "Qty", alignment: .trailing),
                            TableColumnSpec(id: "gl", title: "Gain/loss", alignment: .trailing),
                            TableColumnSpec(id: "term", title: "Term", width: 70),
                        ],
                        rows: detail.disposals.enumerated().map { index, lot in
                            TableRowModel(id: "disp-\(index)", cells: [
                                .text(Format.date(lot.acquiredDate)),
                                .text(Format.date(lot.disposedDate)),
                                .number(lot.quantity, display: Format.quantity(lot.quantity)),
                                .money(lot.gainLoss, signed: true),
                                .muted(lot.isLongTerm ? "LT" : "ST"),
                            ])
                        })
                        .frame(height: DataTableView.idealHeight(rows: detail.disposals.count, max: 200))
                }
                if detail.openLots.isEmpty && detail.disposals.isEmpty {
                    Text("Lots appear once trades exist for this security.")
                        .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                }
            }
        }
    }

    private func tradesPanel(viewModel: SavingsInvestmentsViewModel,
                             detail: SavingsInvestmentsViewModel.HoldingDetail) -> some View {
        PanelView(title: "Trade history", subtitle: "\(detail.trades.count) trades · rows traceable") {
            if detail.trades.isEmpty {
                Text("No trades for this security.").font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "date", title: "Date", width: 100),
                        TableColumnSpec(id: "side", title: "Side", width: 60),
                        TableColumnSpec(id: "qty", title: "Qty", alignment: .trailing),
                        TableColumnSpec(id: "price", title: "Price", alignment: .trailing),
                    ],
                    rows: detail.trades.map { trade in
                        TableRowModel(id: trade.tradeId, cells: [
                            .text(Format.date(trade.date)),
                            .muted(trade.tradeType.rawValue),
                            .number(trade.quantity, display: Format.quantity(trade.quantity)),
                            .money(trade.price),
                        ], sourceRef: viewModel.tradeSourceRef(tradeId: trade.tradeId))
                    },
                    onSelect: { row in
                        if let ref = row.sourceRef { state.inspect(ref) }
                    })
                    .frame(height: DataTableView.idealHeight(rows: detail.trades.count, max: 240))
            }
        }
    }

    private func dividendsPanel(_ detail: SavingsInvestmentsViewModel.HoldingDetail) -> some View {
        PanelView(title: "Dividends", subtitle: "\(detail.dividends.count) payments") {
            if detail.dividends.isEmpty {
                Text("No dividends recorded in Investments/dividends.csv.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "date", title: "Date", width: 100),
                        TableColumnSpec(id: "amount", title: "Amount", alignment: .trailing),
                    ],
                    rows: detail.dividends.map { dividend in
                        TableRowModel(id: dividend.dividendId, cells: [
                            .text(Format.date(dividend.date)),
                            .money(dividend.amount),
                        ])
                    })
                    .frame(height: DataTableView.idealHeight(rows: detail.dividends.count, max: 200))
            }
        }
    }
}

struct HoldingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        HoldingDetailView(assetId: "AS1").environment(AppState())
            .frame(width: 980, height: 720)
            .preferredColorScheme(.light).previewDisplayName("Holding — light")
        HoldingDetailView(assetId: "AS1").environment(AppState())
            .frame(width: 980, height: 720)
            .preferredColorScheme(.dark).previewDisplayName("Holding — dark")
    }
}
