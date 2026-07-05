import SwiftUI
import FinanceWorkspaceKit

// T016 — the global top header (FR-005): issues-count chip immediately LEFT of the sync-status
// chip, both live from the current snapshot / provider state. Issues chip tap → Overview
// (the v1 home of issue visibility).

struct GlobalHeaderView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            issuesChip
            syncChip
        }
        .padding(.horizontal, DS.Metrics.contentPaddingH)
        .padding(.vertical, 8)
        .background(DS.Colors.surfaceRaised)
    }

    private var issuesChip: some View {
        Button {
            state.router.navigate(to: .overview)
        } label: {
            let issues = state.projections?.issues ?? []
            let errors = issues.filter { $0.severity == .error }.count
            StatusChip(
                kind: errors > 0 ? .err : (issues.isEmpty ? .ok : .warn),
                label: issues.isEmpty ? "No issues" : "Issues",
                count: issues.isEmpty ? nil : issues.count)
        }
        .buttonStyle(.plain)
        .help("Validation issues — view in Overview")
        .accessibilityLabel("\(state.projections?.issues.count ?? 0) validation issues")
    }

    private var syncChip: some View {
        let (kind, label): (StatusKind, String) = {
            // A failed re-index keeps the last good snapshot visible but the data is stale —
            // never show "Synced" in that case (see AppState.reindexError).
            if state.reindexError != nil { return (.err, "Stale") }
            switch state.phase {
            case .indexing: return (.info, "Indexing…")
            case .failed: return (.err, "Error")
            case .idle: return (.info, "Opening…")
            case .ready:
                switch state.syncState {
                case .available: return (.ok, "Synced")
                case .syncing: return (.info, "Syncing")
                case .localCopyStale, .fileMissingLocally: return (.warn, "Waiting for iCloud")
                case .notSignedIn, .containerUnavailable: return (.warn, "Offline")
                case .conflictDetected: return (.err, "Conflict")
                }
            }
        }()
        return StatusChip(kind: kind, label: label)
            .help("Workspace sync / indexing state")
    }
}

struct GlobalHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        GlobalHeaderView().environment(AppState()).frame(width: 700)
            .preferredColorScheme(.light).previewDisplayName("Header — light")
        GlobalHeaderView().environment(AppState()).frame(width: 700)
            .preferredColorScheme(.dark).previewDisplayName("Header — dark")
    }
}
