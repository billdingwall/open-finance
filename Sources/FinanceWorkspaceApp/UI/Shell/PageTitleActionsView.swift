import SwiftUI

// T017 — breadcrumb (11px muted, above the title) + the page-title line with right-aligned
// local actions (FR-005). Write actions render visible but DISABLED until Phase 6 (clarify Q3).

/// A per-view local action on the page-title line. Phase-6 write actions ship disabled.
struct LocalAction: Identifiable {
    let id: String
    var title: String
    var systemImage: String
    var isEnabled = true
    var action: () -> Void = {}

    /// A visible-but-disabled Phase-6 write affordance.
    static func writeStub(_ title: String, systemImage: String) -> LocalAction {
        LocalAction(id: title, title: title, systemImage: systemImage, isEnabled: false)
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
                    // All page-title actions are secondary in v1; a primary variant returns with
                    // Phase 6's real write flows.
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!action.isEnabled)
                    .help(action.isEnabled ? action.title : "\(action.title) — available with write flows (Phase 6)")
                }
            }
        }
    }
}

struct PageTitleActionsView_Previews: PreviewProvider {
    static var previews: some View {
        PageTitleActionsView(
            title: "Accounts", breadcrumbs: ["Accounts", "Household"],
            actions: [.writeStub("Import", systemImage: "square.and.arrow.down"),
                      .writeStub("Add", systemImage: "plus")])
            .padding().frame(width: 700)
            .preferredColorScheme(.light).previewDisplayName("Title line — light")
        PageTitleActionsView(
            title: "Accounts", breadcrumbs: ["Accounts", "Household"],
            actions: [.writeStub("Add", systemImage: "plus")])
            .padding().frame(width: 700)
            .preferredColorScheme(.dark).previewDisplayName("Title line — dark")
    }
}
