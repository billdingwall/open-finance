import SwiftUI

// T017 — breadcrumb (11px muted, above the title) + the page-title line with right-aligned
// local actions (FR-005). Write actions are live and sync-gated (008 US1); the only disabled
// state is a runtime WriteGate block, shown with its reason as a tooltip (FR-003).

/// A per-view local action on the page-title line.
struct LocalAction: Identifiable {
    let id: String
    var title: String
    var systemImage: String
    var isEnabled = true
    var disabledReason: String?
    var action: () -> Void = {}

    /// A live, sync-gated write affordance (Import / Add / Edit). Enabled unless the workspace
    /// sync state blocks writing, in which case `disabledReason` explains why (008 FR-001/003).
    @MainActor
    static func write(_ title: String, systemImage: String, state: AppState,
                      perform: @escaping () -> Void) -> LocalAction {
        LocalAction(id: title, title: title, systemImage: systemImage,
                    isEnabled: state.writesEnabled, disabledReason: state.writeGateReason,
                    action: perform)
    }
}

struct BreadcrumbView: View {
    let crumbs: [String]

    var body: some View {
        HStack(spacing: DS.Metrics.unit) {
            ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                if index > 0 {
                    Text("/").font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted2)
                }
                Text(crumb).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            }
        }
    }
}

/// Breadcrumb over the 20px page title, with right-aligned local actions.
struct PageTitleActionsView: View {
    let title: String
    var breadcrumbs: [String] = []
    var actions: [LocalAction] = []

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Metrics.unit) {
            if !breadcrumbs.isEmpty {
                BreadcrumbView(crumbs: breadcrumbs)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(DS.Fonts.pageTitle).foregroundStyle(DS.Colors.ink1)
                Spacer()
                ForEach(actions) { action in
                    Button {
                        action.action()
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    // All page-title actions are secondary in v1.
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!action.isEnabled)
                    .help(action.isEnabled ? action.title : (action.disabledReason ?? action.title))
                }
            }
        }
    }
}

struct PageTitleActionsView_Previews: PreviewProvider {
    static var previews: some View {
        PageTitleActionsView(
            title: "Accounts", breadcrumbs: ["Accounts", "Household"],
            actions: [LocalAction(id: "Import", title: "Import", systemImage: "square.and.arrow.down"),
                      LocalAction(id: "Add", title: "Add", systemImage: "plus")])
            .padding().frame(width: 700)
            .preferredColorScheme(.light).previewDisplayName("Title line — light")
        PageTitleActionsView(
            title: "Accounts", breadcrumbs: ["Accounts", "Household"],
            actions: [LocalAction(id: "Add", title: "Add", systemImage: "plus")])
            .padding().frame(width: 700)
            .preferredColorScheme(.dark).previewDisplayName("Title line — dark")
    }
}
