import SwiftUI
import FinanceWorkspaceKit

// T058 — the tax archive (FR-029): closed prior years, strictly read-only — archived
// adjustments/payments render as raw file previews (the parser deliberately excludes archive
// contents from the live read model), clearly marked with NO write affordances.

struct TaxArchiveView: View {
    @Environment(AppState.self) private var state
    @State private var selectedYear: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                PageTitleActionsView(title: "Tax archive", breadcrumbs: ["Taxes", "Archive"])
                if let projections = state.projections {
                    let viewModel = TaxesViewModel(projections: projections)
                    if viewModel.closedYears.isEmpty {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "archivebox", title: "No closed years",
                            message: "Years appear here after an explicit year-close writes "
                                + "Taxes/archive/YYYY-*.csv."))
                    } else {
                        yearPicker(viewModel)
                        let year = selectedYear ?? viewModel.closedYears.first!
                        ForEach(viewModel.archiveFiles(year: year)) { file in
                            archivePanel(file)
                        }
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func yearPicker(_ viewModel: TaxesViewModel) -> some View {
        HStack(spacing: 8) {
            Picker("Closed year", selection: Binding(
                get: { selectedYear ?? viewModel.closedYears.first! },
                set: { selectedYear = $0 })) {
                ForEach(viewModel.closedYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .frame(width: 120)
            TagView(kind: .warn, label: "read-only")
                .help("A closed year's archive files are read-only; no write affordances exist.")
            Spacer()
        }
    }

    private func archivePanel(_ file: TaxesViewModel.ArchiveFile) -> some View {
        PanelView(title: file.path, subtitle: "archived · read-only") {
            SourceFilePreview(path: file.path, contents: file.contents)
        } actions: {
            Button("Reveal in Finder", systemImage: "folder") {
                state.inspect(SourceRef(filePath: file.path, provenance: .imported))
            }
            .buttonStyle(GhostButtonStyle())
        }
    }
}

struct TaxArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        TaxArchiveView().environment(AppState()).frame(width: 980, height: 640)
            .preferredColorScheme(.light).previewDisplayName("Archive — light")
        TaxArchiveView().environment(AppState()).frame(width: 980, height: 640)
            .preferredColorScheme(.dark).previewDisplayName("Archive — dark")
    }
}
