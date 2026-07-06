import SwiftUI
import FinanceWorkspaceKit

// T039 — the all-accounts card grid (FR-017): aggregate net-worth header (assets +
// liabilities surfaced), accounts grouped by account group, card tap → per-account screen,
// group header tap → group screen.

struct AccountsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                PageTitleActionsView(
                    title: "Accounts", breadcrumbs: ["Accounts"],
                    actions: [.write("Import", systemImage: "square.and.arrow.down", state: state) { state.showingImport = true },
                              .write("Add", systemImage: "plus", state: state) { state.addAccount() }])
                if let projections = state.projections {
                    let viewModel = AccountsViewModel(projections: projections)
                    AggregateHeaderView(header: viewModel.header)
                    if viewModel.groupSections.isEmpty {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "building.columns", title: "No accounts yet",
                            message: "Accounts appear once Accounts/accounts.csv has rows.",
                            ctaTitle: "Add account",
                            ctaEnabled: state.writesEnabled,
                            ctaAction: { state.addAccount() },
                            ctaDisabledReason: state.writeGateReason))
                    } else {
                        ForEach(viewModel.groupSections) { section in
                            groupSection(section)
                        }
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func groupSection(_ section: AccountsViewModel.GroupSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                state.router.navigate(to: .accountGroup(section.group.accountGroupId))
            } label: {
                HStack(spacing: 6) {
                    Text(section.name).font(DS.Fonts.section).foregroundStyle(DS.Colors.ink1)
                    if section.group.groupType == .business {
                        TagView(kind: .info, label: "business")
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(DS.Colors.muted)
                    Spacer()
                    Text("YTD net \(Format.money(section.group.ytdNetIncome))")
                        .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: DS.Metrics.kpiGridGap)],
                      spacing: DS.Metrics.kpiGridGap) {
                ForEach(section.cards) { card in
                    AccountCardView(card: card)
                }
            }
        }
    }
}

/// The aggregate net-worth header (Round 6 — assets and liabilities both surfaced).
private struct AggregateHeaderView: View {
    let header: AccountsViewModel.AggregateHeader

    var body: some View {
        PanelView(title: "All accounts", subtitle: "net-worth view") {
            HStack(spacing: DS.Metrics.contentPaddingH) {
                FigureView(label: "Assets", value: header.assets)
                FigureView(label: "Liabilities", value: header.liabilities, sign: .liability)
                HStack(spacing: 4) {
                    FigureView(label: "Net worth", value: header.netWorth)
                    ValueProvenanceLabel(provenance: .derived)
                }
                Divider().frame(height: 28).overlay(DS.Colors.borderSoft)
                FigureView(label: "Monthly inflow", value: header.monthlyInflow)
                FigureView(label: "YTD net income", value: header.ytdNetIncome)
                FigureView(label: "Retained equity", value: header.retainedEquity)
                Spacer()
            }
        }
    }
}

/// One account card — the whole card is the tap target → the per-account screen.
struct AccountCardView: View {
    @Environment(AppState.self) private var state
    let card: AccountSummaryCard

    var body: some View {
        Button {
            state.router.navigate(to: .account(card.accountId))
        } label: {
            VStack(alignment: .leading, spacing: DS.Metrics.unit) {
                HStack {
                    OverlineLabel(text: card.displayName)
                    Spacer()
                    if card.isProjected {
                        TagView(kind: .info, label: "projected")
                            .help("Monthly inflow projected from account rules (no transactions this month)")
                    }
                }
                Text(Format.money(card.currentBalance))
                    .font(DS.Fonts.kpiValue)
                    .foregroundStyle(card.currentBalance < 0 ? DS.Colors.neg : DS.Colors.ink1)
                HStack(spacing: 8) {
                    Text("+\(Format.money(card.monthlyInflow))/mo")
                        .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                    Text("YTD \(Format.money(card.ytdNetIncome))")
                        .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.normal))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.displayName), balance \(Format.money(card.currentBalance)). Opens account.")
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView().environment(AppState()).frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Accounts — light")
        AccountsView().environment(AppState()).frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Accounts — dark")
    }
}
