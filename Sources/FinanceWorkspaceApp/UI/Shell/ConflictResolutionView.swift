import SwiftUI
import FinanceWorkspaceKit

// 008 US3 T031 — the pick-a-version conflict surface (FR-012). Lists every workspace file with
// unresolved `NSFileVersion` conflicts; per file the user explicitly chooses keep-mine /
// keep-iCloud / keep-both (never auto-merged, P-IV). Keep-both preserves the other version as a
// "(conflicted copy)" sibling so no full version is ever lost. Entry points: the header sync
// chip when a conflict is detected (T032) and any time via this sheet. DESIGN.md "modal-form";
// status-chip semantics for the per-file state; tokens only.

struct ConflictResolutionView: View {
    @Environment(AppState.self) private var state
    @State private var conflicts: [ConflictedFile] = []
    @State private var resolving: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                OverlineLabel(text: "Resolve sync conflicts")
                Text("iCloud found more than one version of these files. Pick which to keep — "
                     + "\u{201C}keep both\u{201D} saves the other version as a conflicted copy "
                     + "beside the original, so nothing is lost.")
                    .font(DS.Fonts.caption)
                    .foregroundStyle(DS.Colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().overlay(DS.Colors.borderSoft)

            if conflicts.isEmpty {
                EmptyStateView(model: EmptyStateModel(
                    systemImage: "checkmark.icloud",
                    title: "No conflicts",
                    message: "Every workspace file has a single current version."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(conflicts) { file in fileRow(file) }
                    }
                    .padding(16)
                }
            }

            Divider().overlay(DS.Colors.borderSoft)
            HStack {
                Spacer()
                Button("Done") { state.showingConflicts = false }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 520, height: 440)
        .onAppear { conflicts = state.scanConflicts() }
    }

    private func fileRow(_ file: ConflictedFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StatusChip(kind: .err, label: "Conflict")
                Text(file.relativePath).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                Spacer()
            }
            ForEach(Array(file.others.enumerated()), id: \.offset) { _, other in
                Text("Other version from \(other.device)"
                     + (other.modified.map { " — \(Format.date($0))" } ?? ""))
                    .font(DS.Fonts.caption)
                    .foregroundStyle(DS.Colors.muted)
            }
            HStack(spacing: 8) {
                choiceButton("Keep mine", file: file, choice: .keepMine)
                choiceButton("Keep iCloud", file: file, choice: .keepiCloud)
                choiceButton("Keep both", file: file, choice: .keepBoth)
                if resolving == file.relativePath { ProgressView().controlSize(.small) }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.borderSoft, lineWidth: 1))
    }

    private func choiceButton(_ title: String, file: ConflictedFile, choice: ConflictChoice) -> some View {
        Button(title) {
            resolving = file.relativePath
            Task {
                await state.resolveConflict(relativePath: file.relativePath, choice: choice)
                conflicts = state.scanConflicts()
                resolving = nil
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(resolving != nil)
    }
}

struct ConflictResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        ConflictResolutionView().environment(AppState())
            .preferredColorScheme(.light).previewDisplayName("Conflicts — light")
        ConflictResolutionView().environment(AppState())
            .preferredColorScheme(.dark).previewDisplayName("Conflicts — dark")
    }
}
