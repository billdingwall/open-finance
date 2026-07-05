import SwiftUI
import FinanceWorkspaceKit

// T019 — the real app scene (replaces the Phase-1 diagnostic shell): three-column shell
// (sidebar / content / `.inspector` slide-over), §17 menu commands, `NSUserActivity`
// restoration (research D6), and the ProjectionStore bootstrap. Overview is the default
// landing (FR-002); minimum window per DESIGN.md.

@main
struct FinanceWorkspaceApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup("Finance Dashboard") {
            AppShellView()
                .environment(state)
                .task { await state.openWorkspace() }
                .userActivity(RouteActivityCodec.activityType) { activity in
                    activity.userInfo = RouteActivityCodec.encode(
                        state.route, paneOpen: state.detailPane.isPresented)
                    activity.becomeCurrent()
                }
                .onContinueUserActivity(RouteActivityCodec.activityType) { activity in
                    let payload = (activity.userInfo as? [String: String]) ?? [:]
                    if let route = RouteActivityCodec.decode(payload) {
                        state.router.navigate(to: route)
                    }
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands { AppCommands(state: state) }
    }
}

// MARK: - Shell

struct AppShellView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            NavigationSidebarView()
        } detail: {
            VStack(spacing: 0) {
                GlobalHeaderView()
                Divider().overlay(DS.Colors.borderSoft)
                WorkspaceNoticeBar()
                ModuleContainerView()
            }
            .background(DS.Colors.windowBg)
        }
        .inspector(isPresented: $state.detailPane.isPresented) {
            DetailPaneView()
                .inspectorColumnWidth(
                    min: DS.Metrics.detailPaneMin, ideal: DS.Metrics.detailPaneMin,
                    max: DS.Metrics.detailPaneMax)
        }
        .sheet(item: $state.editForm) { context in
            EntityEditForm(context: context)
        }
        .sheet(isPresented: Binding(
            get: { state.pendingWrite != nil },
            set: { if !$0 { state.cancelWrite() } })) {
            WritePreviewView()
        }
        .frame(minWidth: DS.Metrics.minWindowWidth, minHeight: DS.Metrics.minWindowHeight)
    }
}

/// Routes the content column. Module views land with US3–US7; until then each slot renders a
/// typed placeholder so the shell is independently testable (US1).
struct ModuleContainerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.phase {
            case .idle, .indexing:
                if state.projections == nil {
                    ScrollView { LoadingSkeletonView().moduleContentPadding() }
                } else {
                    routedContent
                }
            case .failed(let message):
                failedState(message)
            case .ready:
                routedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var routedContent: some View {
        switch state.route {
        case .overview:
            OverviewView()
        case .accounts:
            AccountsView()
        case .accountGroup(let id):
            AccountGroupDetailView(accountGroupId: id)
        case .account(let id):
            AccountDetailView(accountId: id)
        case .budget(let sub):
            BudgetModuleView(subview: sub)
        case .savingsInvestments(let sub):
            SavingsInvestmentsView(subview: sub)
        case .goal(let id):
            GoalDetailView(goalId: id)
        case .holding(let id):
            HoldingDetailView(assetId: id)
        case .taxes(let sub):
            TaxesModuleView(subview: sub)
        }
    }

    private func failedState(_ message: String) -> some View {
        ScrollView {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "exclamationmark.triangle",
                title: "Workspace unavailable",
                message: message))
                .moduleContentPadding()
        }
    }
}

// Light + dark previews (PreviewProvider form — the #Preview macro plugin needs full Xcode,
// which the CLT-only dev box lacks; CI and Xcode render these identically).
struct AppShellView_Previews: PreviewProvider {
    static var previews: some View {
        AppShellView().environment(AppState()).frame(width: 1100, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Shell — light")
        AppShellView().environment(AppState()).frame(width: 1100, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Shell — dark")
    }
}
