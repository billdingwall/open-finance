import SwiftUI
import AppKit
import FinanceWorkspaceKit

// T028 — the source inspector (FR-012, constitution P-V): file path, row number, last-modified,
// raw field values, and working "Open in Finder" / "Open in Editor" actions. A missing source
// file renders an explicit state with both actions disabled (never a silent failure).

struct SourceInspectorView: View {
    @Environment(AppState.self) private var state
    let ref: SourceRef

    private var fileURL: URL? {
        state.projections.map { $0.workspaceURL.appendingPathComponent(ref.filePath) }
    }

    private var fileExists: Bool {
        fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    private var lastModified: Date? {
        guard let fileURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OverlineLabel(text: "Source")
            field("File", ref.filePath)
            field("Row", ref.rowNumber.map(String.init) ?? "—")
            field("Modified", lastModified.map(Format.date) ?? (fileExists ? "—" : "file missing"))
            HStack(spacing: 4) {
                OverlineLabel(text: "Provenance")
                ValueProvenanceLabel(provenance: ref.provenance)
            }

            if !ref.rawFields.isEmpty {
                OverlineLabel(text: "Raw fields")
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(ref.rawFields, id: \.name) { fieldPair in
                        HStack(alignment: .firstTextBaseline) {
                            Text(fieldPair.name).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                                .frame(width: 110, alignment: .leading)
                            Text(fieldPair.value).font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !fileExists {
                Text("The source file was moved or deleted since indexing.")
                    .font(DS.Fonts.caption).foregroundStyle(DS.Colors.warn)
            }

            HStack(spacing: 8) {
                Button("Open in Finder", systemImage: "folder") { revealInFinder() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!fileExists)
                Button("Open in Editor", systemImage: "square.and.pencil") { openInEditor() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!fileExists)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            OverlineLabel(text: label)
            Text(value).font(DS.Fonts.tableNumeric).foregroundStyle(DS.Colors.ink2)
                .textSelection(.enabled)
        }
    }

    private func revealInFinder() {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func openInEditor() {
        guard let fileURL else { return }
        NSWorkspace.shared.open(fileURL)
    }
}

/// Inline provenance tag (FR-013, constitution P-II): imported / derived / repaired /
/// user-edited. Red is reserved for money/severity, so user-edited uses the accent selection
/// semantics instead of a status color.
struct ValueProvenanceLabel: View {
    let provenance: Provenance

    var body: some View {
        Text(provenance.rawValue)
            .font(DS.Fonts.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
            .accessibilityLabel("Value provenance: \(provenance.rawValue)")
    }

    private var foreground: Color {
        switch provenance {
        case .imported: return DS.Colors.info
        case .derived: return DS.Colors.muted
        case .repaired: return DS.Colors.warn
        case .userEdited: return DS.Colors.accentInk
        }
    }

    private var background: Color {
        switch provenance {
        case .imported: return DS.Colors.infoSoft
        case .derived: return DS.Colors.surfaceSunken
        case .repaired: return DS.Colors.warnSoft
        case .userEdited: return DS.Colors.accentSoft
        }
    }
}

struct SourceInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        SourceInspectorView(ref: SourceRef(
            filePath: "Accounts/transactions/2026-06.csv", rowNumber: 12,
            rawFields: [("transaction_id", "T042"), ("amount", "-125.40")], provenance: .imported))
            .environment(AppState())
            .padding().frame(width: 380, height: 420)
            .preferredColorScheme(.light).previewDisplayName("Inspector — light")
        SourceInspectorView(ref: SourceRef(filePath: "Budget/categories.csv", provenance: .derived))
            .environment(AppState())
            .padding().frame(width: 380, height: 420)
            .preferredColorScheme(.dark).previewDisplayName("Inspector — dark")
    }
}
