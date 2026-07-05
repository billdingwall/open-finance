import SwiftUI
import FinanceWorkspaceKit

// T058 — the full-width tax-prep checklist (FR-029): complete / incomplete / missing item
// states from TaxPrepEngine, a source link per item (opens the source inspector), and
// educational content per step.

struct TaxPrepChecklistView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                if let projections = state.projections {
                    let viewModel = TaxesViewModel(projections: projections)
                    let year = viewModel.year(state.selections.taxYear)
                    PageTitleActionsView(title: "Tax prep checklist — \(String(year))",
                                         breadcrumbs: ["Taxes", "Prep checklist"])
                    ForEach(viewModel.checklist(year: year)) { entry in
                        checklistPanel(entry)
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func checklistPanel(_ entry: TaxesViewModel.ChecklistItem) -> some View {
        PanelView(title: entry.item.kind.rawValue, subtitle: entry.item.detail) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.education)
                    .font(DS.Fonts.body).foregroundStyle(DS.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    state.inspect(SourceRef(filePath: entry.sourcePath, provenance: .imported))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text").font(.system(size: 10))
                        Text(entry.sourcePath).font(DS.Fonts.captionNumeric)
                    }
                    .foregroundStyle(DS.Colors.accentInk)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open the source in the inspector")
            }
        } actions: {
            stateChip(entry.item.state)
        }
    }

    private func stateChip(_ itemState: PrepItem.State) -> some View {
        switch itemState {
        case .complete: return StatusChip(kind: .ok, label: "complete")
        case .incomplete: return StatusChip(kind: .warn, label: "incomplete")
        case .missing: return StatusChip(kind: .err, label: "missing")
        }
    }
}

struct TaxPrepChecklistView_Previews: PreviewProvider {
    static var previews: some View {
        TaxPrepChecklistView().environment(AppState()).frame(width: 980, height: 700)
            .preferredColorScheme(.light).previewDisplayName("Checklist — light")
        TaxPrepChecklistView().environment(AppState()).frame(width: 980, height: 700)
            .preferredColorScheme(.dark).previewDisplayName("Checklist — dark")
    }
}
