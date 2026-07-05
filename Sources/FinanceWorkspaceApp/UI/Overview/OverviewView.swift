import SwiftUI
import FinanceWorkspaceKit

// T034 — the Overview dashboard (FR-015): default landing, 5-KPI grid (no filters), the
// month-over-month panel (gap-skipping 6-mo series), and the inline issues table. Each card
// navigates to its module on tap.

struct OverviewView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                PageTitleActionsView(title: "Overview")
                if let projections = state.projections {
                    let viewModel = OverviewViewModel(dashboard: projections.dashboard)
                    kpiGrid(viewModel, projections: projections)
                    PanelView(title: "Month over month",
                              subtitle: "net income · trailing 6 populated months") {
                        SparklineView(points: viewModel.momPoints)
                    }
                    PanelView(title: "Validation issues",
                              subtitle: viewModel.issueCount == 0 ? "workspace is clean"
                                                                  : "\(viewModel.issueCount) open") {
                        OverviewIssuesTableView(groups: viewModel.issueGroups)
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func kpiGrid(_ viewModel: OverviewViewModel, projections: WorkspaceProjections) -> some View {
        HStack(alignment: .top, spacing: DS.Metrics.kpiGridGap) {
            ForEach(viewModel.cards(projections: projections)) { card in
                KPICardView(model: card)
            }
        }
    }
}

// T035 — inline issues table (FR-016): grouped by severity, repairable badge, and a
// READ-ONLY "Preview Repair" per repairable issue (dry run → detail pane; apply is Phase 6).
struct OverviewIssuesTableView: View {
    @Environment(AppState.self) private var state
    let groups: [OverviewViewModel.IssueGroup]

    var body: some View {
        if groups.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "checkmark.seal", title: "No validation issues",
                message: "Every parsed file passed validation."))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(groups) { group in
                    OverlineLabel(text: "\(group.severity.rawValue)s (\(group.issues.count))")
                    ForEach(group.issues) { issue in
                        issueRow(issue)
                        Divider().overlay(DS.Colors.borderSoft)
                    }
                }
            }
        }
    }

    private func issueRow(_ issue: ValidationIssue) -> some View {
        HStack(spacing: 8) {
            StatusChip(kind: issue.statusKind, label: issue.ruleId)
            Button {
                state.showIssue(issue)
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(issue.message).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                        .lineLimit(1)
                    Text(issue.filePath + (issue.rowRef.map { ":\($0)" } ?? ""))
                        .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if issue.repairClass == .auto {
                TagView(kind: .info, label: "repairable")
                Button("Preview Repair") { state.previewRepair(for: issue) }
                    .buttonStyle(GhostButtonStyle())
                    .help("Dry-run preview — nothing is written (apply arrives in Phase 6)")
            }
        }
        .frame(minHeight: DS.Metrics.rowHeight)
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewView().environment(AppState()).frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Overview — light")
        OverviewView().environment(AppState()).frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Overview — dark")
    }
}
