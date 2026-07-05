import SwiftUI
import FinanceWorkspaceKit

// T057 — the consolidated current-tax-year view (FR-027/028): YTD income, taxes paid vs owed
// (computed projection, stored overrides honored), effective-rate-per-account table, quarterly
// estimated payments (paid/due), gains & income (ST/LT split, dividends, interest), and the
// deductions section (both totals + recommended flag, Schedule C → business groups, taxable-
// income projection). No embedded prep checklist. Every figure is an ESTIMATE (V1 boundary).

struct TaxesModuleView: View {
    let subview: TaxSubview

    var body: some View {
        switch subview {
        case .currentYear: CurrentTaxYearView()
        case .prepChecklist: TaxPrepChecklistView()
        case .archive: TaxArchiveView()
        }
    }
}

struct CurrentTaxYearView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = TaxesViewModel(projections: projections)
                    let year = viewModel.year(state.selections.taxYear)
                    header(viewModel, year: year, selected: $state.selections.taxYear)
                    content(viewModel, year: year)
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func header(_ viewModel: TaxesViewModel, year: Int, selected: Binding<Int?>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PageTitleActionsView(title: "Taxes — \(String(year))",
                                 breadcrumbs: ["Taxes", "Current year"])
            Picker("Tax year", selection: selected) {
                Text(String(viewModel.defaultYear)).tag(Int?.none)
                ForEach(viewModel.closedYears, id: \.self) { closed in
                    Text(String(closed)).tag(Int?.some(closed))
                }
            }
            .frame(width: 120)
            .help("Session-scoped tax-year selection")
            TagView(kind: .info, label: "estimates")
                .help("The tax module estimates obligations; it is not a filing engine.")
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TaxesViewModel, year: Int) -> some View {
        let projection = viewModel.taxProjection(year: year)
        let totals = viewModel.totals(projection)
        let estimate = viewModel.estimate(year: year)

        summaryPanel(totals: totals, estimate: estimate)
        ratesPanel(viewModel, projection: projection)
        paymentsPanel(viewModel, year: year)
        gainsPanel(projection: projection, totals: totals)
        deductionsPanel(viewModel, year: year)
    }

    private func summaryPanel(totals: TaxesViewModel.Totals, estimate: TaxEstimateProjection) -> some View {
        PanelView(title: "Year to date",
                  subtitle: estimate.source == .stored ? "stored estimate override" : "computed estimate") {
            HStack(spacing: DS.Metrics.contentPaddingH) {
                figure("Taxable income", totals.ytdTaxableIncome)
                figure("Taxes paid", totals.taxesPaid)
                figure("Projected liability", estimate.projectedLiability)
                VStack(alignment: .leading, spacing: 2) {
                    OverlineLabel(text: estimate.estimatedReturn >= 0 ? "Est. refund" : "Est. owed")
                    Text(Format.money(abs(estimate.estimatedReturn)))
                        .font(DS.Fonts.kpiValue)
                        .foregroundStyle(estimate.estimatedReturn >= 0 ? DS.Colors.pos : DS.Colors.neg)
                }
                Spacer()
            }
        }
    }

    private func ratesPanel(_ viewModel: TaxesViewModel, projection: TaxEngine.Projection) -> some View {
        PanelView(title: "Effective rate per account", subtitle: "taxes paid ÷ gross income") {
            let rows = viewModel.effectiveRateRows(projection)
            if rows.isEmpty {
                Text("Accounts with taxable activity appear here.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                DataTableView(
                    columns: [
                        TableColumnSpec(id: "account", title: "Account"),
                        TableColumnSpec(id: "income", title: "Taxable income", alignment: .trailing),
                        TableColumnSpec(id: "paid", title: "Taxes paid", alignment: .trailing),
                        TableColumnSpec(id: "div", title: "Dividends", alignment: .trailing),
                        TableColumnSpec(id: "int", title: "Interest", alignment: .trailing),
                        TableColumnSpec(id: "rate", title: "Eff. rate", alignment: .trailing, width: 80),
                    ],
                    rows: rows)
                    .frame(height: DataTableView.idealHeight(rows: rows.count, max: 240))
            }
        }
    }

    private func paymentsPanel(_ viewModel: TaxesViewModel, year: Int) -> some View {
        PanelView(title: "Estimated payments", subtitle: "quarterly schedule") {
            let payments = viewModel.paymentRows(year: year)
            if payments.isEmpty {
                Text("Quarterly estimated payments appear once Taxes/estimates has rows.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            } else {
                HStack(spacing: DS.Metrics.kpiGridGap) {
                    ForEach(payments) { payment in
                        VStack(alignment: .leading, spacing: 4) {
                            OverlineLabel(text: "Q\(payment.quarter)")
                            Text(Format.money(payment.amount))
                                .font(DS.Fonts.bodyNumeric).foregroundStyle(DS.Colors.ink1)
                            StatusChip(kind: payment.paid ? .ok : .warn,
                                       label: payment.paid ? "paid" : "due")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Colors.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(DS.Colors.borderSoft, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func gainsPanel(projection: TaxEngine.Projection, totals: TaxesViewModel.Totals) -> some View {
        PanelView(title: "Gains & income", subtitle: "realized FIFO lots · split by holding period") {
            HStack(spacing: DS.Metrics.contentPaddingH) {
                signedFigure("Short-term G/L", projection.realized.shortTermGainLoss)
                signedFigure("Long-term G/L", projection.realized.longTermGainLoss)
                signedFigure("Total realized", projection.realized.total)
                Divider().frame(height: 28).overlay(DS.Colors.borderSoft)
                figure("Dividends", totals.dividends)
                figure("Interest", totals.interest)
                Spacer()
            }
        }
    }

    private func deductionsPanel(_ viewModel: TaxesViewModel, year: Int) -> some View {
        let summary = viewModel.deductions(year: year)
        return PanelView(title: "Deductions",
                         subtitle: "standard vs itemized · recommendation is display-only") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: DS.Metrics.kpiGridGap) {
                    deductionChoice("Standard", summary.standardTotal,
                                    recommended: summary.recommended == .standard)
                    deductionChoice("Itemized", summary.itemizedTotal,
                                    recommended: summary.recommended == .itemized)
                }
                HStack(spacing: DS.Metrics.contentPaddingH) {
                    figure("Above-the-line", summary.aboveTheLine)
                    figure("Schedule C", summary.scheduleC)
                    figure("QBI (≈20%)", summary.qbiDeduction)
                    figure("Taxable income after adj.", summary.taxableIncomeAfterAdjustments)
                    Spacer()
                }
                scheduleCSection(viewModel, summary: summary)
            }
        }
    }

    @ViewBuilder
    private func scheduleCSection(_ viewModel: TaxesViewModel, summary: TaxDeductionSummary) -> some View {
        if !summary.businessExpenseByGroup.isEmpty {
            OverlineLabel(text: "Schedule C · business groups")
            ForEach(summary.businessExpenseByGroup) { reconciliation in
                HStack(spacing: 8) {
                    Button {
                        state.router.navigate(to: .accountGroup(reconciliation.accountGroupId))
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.groupName(reconciliation.accountGroupId))
                                .font(DS.Fonts.table).foregroundStyle(DS.Colors.accentInk)
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 9)).foregroundStyle(DS.Colors.accentInk)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Text("claimed \(Format.money(reconciliation.claimed))")
                        .font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink3)
                    Text("ledger \(Format.money(reconciliation.ledgerTotal))")
                        .font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink3)
                    if reconciliation.divergence != 0 {
                        TagView(kind: .warn, label: "diverges \(Format.money(reconciliation.divergence))")
                    }
                    Spacer()
                }
                .frame(height: 24)
            }
        }
    }

    // MARK: - Small figures

    private func figure(_ label: String, _ value: Decimal) -> some View {
        FigureView(label: label, value: value, size: .body)
    }

    private func signedFigure(_ label: String, _ value: Decimal) -> some View {
        FigureView(label: label, value: value, size: .body, sign: .gainLoss)
    }

    private func deductionChoice(_ label: String, _ value: Decimal, recommended: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                OverlineLabel(text: label)
                if recommended { TagView(kind: .ok, label: "recommended") }
            }
            Text(Format.money(value)).font(DS.Fonts.kpiValue).foregroundStyle(DS.Colors.ink1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(recommended ? DS.Colors.accentSoft : DS.Colors.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: DS.Radius.normal))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal)
            .stroke(recommended ? DS.Colors.accentBorder : DS.Colors.border, lineWidth: 1))
    }
}

struct CurrentTaxYearView_Previews: PreviewProvider {
    static var previews: some View {
        CurrentTaxYearView().environment(AppState()).frame(width: 1000, height: 760)
            .preferredColorScheme(.light).previewDisplayName("Taxes — light")
        CurrentTaxYearView().environment(AppState()).frame(width: 1000, height: 760)
            .preferredColorScheme(.dark).previewDisplayName("Taxes — dark")
    }
}
