import SwiftUI
import FinanceWorkspaceKit

// Surfaces workspace-health signals the shell would otherwise compute but never show:
// a pre-R6 migration prompt (never auto-migrates — constitution "detect and prompt"), a
// missing-required-paths notice, the first-run provisioning confirmation, and a failed-reindex
// warning (the prior snapshot stays visible but is stale). One strip above the module content.

struct WorkspaceNoticeBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            if state.needsR6Migration {
                notice(.warn, icon: "arrow.triangle.2.circlepath",
                       "Pre-R6 workspace detected. Review and run it explicitly "
                           + "(migrate-r6) — it is never applied automatically.")
            }
            if !state.missingPaths.isEmpty {
                notice(.warn, icon: "exclamationmark.triangle",
                       "Missing required paths: \(state.missingPaths.joined(separator: ", "))")
            }
            if let reindexError = state.reindexError {
                notice(.err, icon: "arrow.clockwise",
                       "Re-index failed — showing the last good data. \(reindexError)")
            }
            if state.didProvision {
                notice(.info, icon: "sparkles", "Provisioned a new workspace on first launch.")
            }
        }
    }

    private func notice(_ kind: StatusKind, icon: String, _ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(kind.color)
            Text(message).font(DS.Fonts.caption).foregroundStyle(DS.Colors.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Metrics.contentPaddingH)
        .padding(.vertical, 6)
        .background(kind.softColor)
        .overlay(alignment: .bottom) { Divider().overlay(DS.Colors.borderSoft) }
    }
}
