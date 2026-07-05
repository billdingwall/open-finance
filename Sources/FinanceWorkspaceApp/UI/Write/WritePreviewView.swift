import SwiftUI
import FinanceWorkspaceKit

// Phase 6 (007) T013 — the shared write-preview modal (FR-006). Every structured write (add/edit/
// delete/import/multi-entry/year-close) routes through here before applying: it shows the target
// file(s), a before/after row diff, and the backup destination, and applies only on confirm through
// `AppState.applyPendingWrite` (WriteService). DESIGN.md "modal-form · preview before write"; the
// diff styling mirrors `RepairPreviewSurface` (− neg / + pos monospaced on surface-sunken).

struct WritePreviewView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let plan = state.pendingWrite
        VStack(alignment: .leading, spacing: 0) {
            header(plan)
            Divider().overlay(DS.Colors.borderSoft)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let plan {
                        ForEach(Array(plan.changes.enumerated()), id: \.offset) { _, change in
                            fileChange(change)
                        }
                        Text("A timestamped backup of each file is created before anything is written, under .finance-meta/backups/.")
                            .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                    }
                    if let reason = state.writeBlockReason {
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .font(DS.Fonts.caption).foregroundStyle(DS.Colors.warn)
                    }
                    if let err = state.writeError {
                        Label("Write failed: \(err)", systemImage: "xmark.octagon")
                            .font(DS.Fonts.caption).foregroundStyle(DS.Colors.neg)
                    }
                }
                .padding(16)
            }

            Divider().overlay(DS.Colors.borderSoft)
            footer
        }
        .frame(width: 520, height: 440)
    }

    private func header(_ plan: WritePlan?) -> some View {
        HStack {
            OverlineLabel(text: plan.map { Self.intentTitle($0.intent) } ?? "Preview")
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder private func fileChange(_ change: FileChange) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(change.relativePath)
                .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted).textSelection(.enabled)
            ForEach(Array(change.rowDiffs.enumerated()), id: \.offset) { _, diff in
                diffRows(diff)
            }
        }
    }

    @ViewBuilder private func diffRows(_ diff: WriteRowDiff) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            switch diff.kind {
            case .add(let after):
                monoLine("+ \(after)", DS.Colors.pos)
            case .delete(let before):
                monoLine("− \(before)", DS.Colors.neg)
            case .modify(let before, let after):
                monoLine("− \(before)", DS.Colors.neg)
                monoLine("+ \(after)", DS.Colors.pos)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func monoLine(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(color)
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { state.cancelWrite() }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button("Apply", systemImage: "checkmark.circle") {
                Task { await state.applyPendingWrite() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(state.writeBlockReason != nil)
        }
        .padding(12)
    }

    static func intentTitle(_ intent: WriteIntent) -> String {
        switch intent {
        case .add: return "Add — preview"
        case .edit: return "Edit — preview"
        case .delete: return "Delete — preview"
        case .importCSV: return "Import — preview"
        case .repair: return "Repair — preview"
        case .closeTaxYear: return "Close tax year — preview"
        }
    }
}

struct WritePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let state = AppState()
        state.pendingWrite = WritePlan(intent: .edit, changes: [
            FileChange(relativePath: "Savings/goals.csv", expectedHash: nil, rowDiffs: [
                WriteRowDiff(rowRef: 2, kind: .modify(before: "goal-2,Vacation,5000,acct-2",
                                                     after: "goal-2,Vacation,6500,acct-2")),
            ]),
        ])
        return WritePreviewView().environment(state)
            .preferredColorScheme(.light).previewDisplayName("Write preview — light")
    }
}
