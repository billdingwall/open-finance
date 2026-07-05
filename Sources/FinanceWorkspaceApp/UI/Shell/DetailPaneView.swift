import SwiftUI
import FinanceWorkspaceKit

// T018 — the right detail pane content (FR-006, research D1). Hosted in `.inspector` (the
// native trailing slide-over), closed by default globally; opens on main-panel selection.
// Six surfaces; `.editForm` exists for Phase 6 and is unreachable while write actions are
// disabled. Edit/Delete sit at the bottom for entity surfaces — disabled (clarify Q3).

struct DetailPaneView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                OverlineLabel(text: title)
                Spacer()
                Button {
                    state.detailPane.isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Colors.muted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close (⌥⌘I toggles)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider().overlay(DS.Colors.borderSoft)

            ScrollView {
                surfaceBody
                    .padding(14)
            }

            if case .inspector(let ref) = state.detailPane.surface {
                Divider().overlay(DS.Colors.borderSoft)
                HStack {
                    // Edit/Delete at the panel bottom for right-panel objects (FR-010).
                    Button("Edit", systemImage: "pencil") { state.presentEdit(ref) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(ref.rowNumber == nil)
                        .help("Edit this record")
                    Button("Delete", systemImage: "trash") { state.requestDelete(ref) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(ref.rowNumber == nil)
                        .help("Delete this record")
                    Spacer()
                }
                .padding(10)
            }
        }
    }

    private var title: String {
        switch state.detailPane.surface {
        case .inspector: return "Inspector"
        case .issueDetail: return "Validation issue"
        case .repairPreview: return "Repair preview"
        case .editForm: return "Edit"
        case nil: return "Details"
        }
    }

    @ViewBuilder private var surfaceBody: some View {
        switch state.detailPane.surface {
        case .inspector(let ref):
            SourceInspectorView(ref: ref)
        case .issueDetail(let issue):
            IssueDetailSurface(issue: issue)
        case .repairPreview(let preview):
            RepairPreviewSurface(preview: preview)
        case .editForm(let entityRef):
            Text("Editing \(entityRef) arrives with write flows (Phase 6).")
                .font(DS.Fonts.body).foregroundStyle(DS.Colors.muted)
        case nil:
            EmptyStateView(model: EmptyStateModel(
                systemImage: "sidebar.right",
                title: "Nothing selected",
                message: "Select a row or issue to inspect its source."))
        }
    }
}

// MARK: - Small surfaces

/// Raw, read-only file preview (used by the tax archive and "Open Source File" contexts).
struct SourceFilePreview: View {
    let path: String
    let contents: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(path).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                .textSelection(.enabled)
            Text(contents)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Colors.ink2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(DS.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
}

private struct IssueDetailSurface: View {
    @Environment(AppState.self) private var state
    let issue: ValidationIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                StatusChip(kind: issue.statusKind, label: issue.severity.rawValue)
                if issue.repairClass == .auto {
                    TagView(kind: .info, label: "repairable")
                }
            }
            Text(issue.message).font(DS.Fonts.body).foregroundStyle(DS.Colors.ink2)
            OverlineLabel(text: "Rule")
            Text(issue.ruleId).font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink2)
            SourceInspectorView(ref: issue.sourceRef)
            if issue.repairClass == .auto {
                Button("Preview repair", systemImage: "wand.and.rays") {
                    state.previewRepair(for: issue)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RepairPreviewSurface: View {
    @Environment(AppState.self) private var state
    let preview: RepairPreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dry run — no files were modified.")
                .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            OverlineLabel(text: "Proposed actions")
            ForEach(Array(preview.actionDescriptions.enumerated()), id: \.offset) { _, action in
                Text(action).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
            }
            if !preview.diffs.isEmpty {
                OverlineLabel(text: "Row changes")
                ForEach(Array(preview.diffs.enumerated()), id: \.offset) { _, diff in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("− \(diff.before)").font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DS.Colors.neg)
                        Text("+ \(diff.after)").font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DS.Colors.pos)
                    }
                    .padding(6)
                    .background(DS.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
            if !preview.backupNote.isEmpty {
                Text(preview.backupNote).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            }
            // Apply the deterministic repair through the safe-write path (US5, FR-024/026).
            let repairable = !preview.diffs.isEmpty || preview.actionDescriptions.contains { !$0.hasPrefix("No auto-repair") }
            Button("Apply repair", systemImage: "checkmark.circle") {
                Task { await state.applyRepair() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!repairable)
            .help("Back up, apply the deterministic repair, then re-validate")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailPaneView_Previews: PreviewProvider {
    static var previews: some View {
        DetailPaneView().environment(AppState()).frame(width: 380, height: 500)
            .preferredColorScheme(.light).previewDisplayName("Pane — light")
        DetailPaneView().environment(AppState()).frame(width: 380, height: 500)
            .preferredColorScheme(.dark).previewDisplayName("Pane — dark")
    }
}
