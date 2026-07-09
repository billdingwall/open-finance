import SwiftUI
import FinanceWorkspaceKit

// T015 — the left sidebar (FR-004): "Finance Dashboard" header → Overview (no Overview nav
// row — locked decision), expandable section groups with nested entity links, active
// accent-soft state, count badges, designed empty-group states, keyboard traversal (native
// List behavior).

struct NavigationSidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            header
            List(selection: sidebarSelection) {
                accountsSection
                budgetSection
                savingsInvestmentsSection
                taxesSection
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(
            min: DS.Metrics.sidebarWidth, ideal: DS.Metrics.sidebarWidth)
    }

    /// The sidebar header is the Overview link (FR-004); Overview has no nav row.
    private var header: some View {
        Button {
            state.router.navigate(to: .overview)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(DS.Colors.accent)
                Text("Finance Dashboard").font(DS.Fonts.section)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(state.route == .overview ? DS.Colors.accentSoft : .clear)
        .accessibilityLabel("Finance Dashboard — Overview")
    }

    private var sidebarSelection: Binding<Route?> {
        Binding(
            get: { state.route },
            set: { route in if let route { state.router.navigate(to: route) } })
    }

    // MARK: - Sections

    private var accountsSection: some View {
        Section {
            NavRow(title: "All accounts", count: state.projections?.accounts.accounts.count)
                .tag(Route.accounts)
            DisclosureGroup(isExpanded: expansion("accounts")) {
                let groups = state.projections?.accounts.groups ?? []
                if groups.isEmpty {
                    EmptyGroupRow(message: "No account groups yet")
                } else {
                    ForEach(groups) { group in
                        NavRow(title: groupName(group), count: group.accountIds.count)
                            .tag(Route.accountGroup(group.accountGroupId))
                        ForEach(group.accountIds, id: \.self) { accountId in
                            NavRow(title: accountName(accountId), indent: true)
                                .tag(Route.account(accountId))
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Account groups")
                    Spacer()
                    // Live, sync-gated write affordance (008 US1).
                    Button("New group", systemImage: "plus") { state.addAccountGroup() }
                        .labelStyle(.iconOnly).buttonStyle(.plain).disabled(!state.writesEnabled)
                        .help(state.writesEnabled ? "New group" : (state.writeGateReason ?? "New group"))
                }
            }
        } header: {
            Text("Accounts")
        }
    }

    private var budgetSection: some View {
        Section("Budget") {
            NavRow(title: "Overview").tag(Route.budget(.overview))
            NavRow(title: "History").tag(Route.budget(.history))
            NavRow(title: "Categories").tag(Route.budget(.categories))
        }
    }

    private var savingsInvestmentsSection: some View {
        Section("Savings & Investments") {
            NavRow(title: "Overview").tag(Route.savingsInvestments(.overview))
            DisclosureGroup(isExpanded: expansion("si")) {
                let goals = state.projections?.goals ?? []
                if goals.isEmpty {
                    EmptyGroupRow(message: "No savings goals yet")
                } else {
                    ForEach(goals) { goal in
                        NavRow(title: goal.name, indent: true).tag(Route.goal(goal.goalId))
                    }
                }
            } label: {
                NavRow(title: "Goals", count: state.projections?.goals.count)
            }
            NavRow(title: "Portfolio", count: state.projections?.holdings.positions.count)
                .tag(Route.savingsInvestments(.portfolio))
        }
    }

    private var taxesSection: some View {
        Section("Taxes") {
            NavRow(title: "Current year").tag(Route.taxes(.currentYear))
            NavRow(title: "Prep checklist").tag(Route.taxes(.prepChecklist))
            NavRow(title: "Archive", count: state.projections?.closedTaxYears.count)
                .tag(Route.taxes(.archive))
        }
    }

    // MARK: - Helpers

    private func expansion(_ key: String) -> Binding<Bool> {
        Binding(
            get: { state.sidebarExpansion.contains(key) },
            set: { expanded in
                if expanded { state.sidebarExpansion.insert(key) } else { state.sidebarExpansion.remove(key) }
            })
    }

    private func groupName(_ group: AccountGroupProjection) -> String {
        state.projections?.context.accountGroups
            .first { $0.accountGroupId == group.accountGroupId }?.name ?? group.accountGroupId
    }

    private func accountName(_ accountId: String) -> String {
        state.projections?.accounts.accounts.first { $0.accountId == accountId }?.displayName ?? accountId
    }
}

/// One sidebar row: title + optional right-aligned count badge (DESIGN `.nav-item`).
private struct NavRow: View {
    let title: String
    var count: Int?
    var indent = false

    var body: some View {
        HStack {
            Text(title).font(DS.Fonts.body).lineLimit(1)
            Spacer()
            if let count, count > 0 {
                Text("\(count)")
                    .font(DS.Fonts.captionNumeric)
                    .foregroundStyle(DS.Colors.muted)
            }
        }
        .padding(.leading, indent ? 12 : 0)
    }
}

/// Designed empty-group state (never a disappearing group — edge-case rule).
private struct EmptyGroupRow: View {
    let message: String
    var body: some View {
        Text(message)
            .font(DS.Fonts.caption)
            .foregroundStyle(DS.Colors.muted)
            .padding(.leading, 12)
    }
}

struct NavigationSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSidebarView().environment(AppState()).frame(width: 260, height: 600)
            .preferredColorScheme(.light).previewDisplayName("Sidebar — light")
        NavigationSidebarView().environment(AppState()).frame(width: 260, height: 600)
            .preferredColorScheme(.dark).previewDisplayName("Sidebar — dark")
    }
}
