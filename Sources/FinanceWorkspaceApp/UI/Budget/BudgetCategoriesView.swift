import SwiftUI
import FinanceWorkspaceKit

// T046 — categories & subcategories (FR-022): management list with live, sync-gated
// Add category / per-row Edit actions (008 US1).

struct BudgetCategoriesView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Metrics.panelGap) {
                PageTitleActionsView(
                    title: "Categories", breadcrumbs: ["Budget", "Categories"],
                    actions: [.write("Add category", systemImage: "plus", state: state) { state.addCategory() }])
                if let projections = state.projections {
                    let viewModel = BudgetViewModel(projections: projections)
                    if viewModel.categoryTree.isEmpty {
                        EmptyStateView(model: EmptyStateModel(
                            systemImage: "tag", title: "No categories",
                            message: "Categories appear once Budget/categories.csv has rows.",
                            ctaTitle: "Add category",
                            ctaEnabled: state.writesEnabled,
                            ctaAction: { state.addCategory() },
                            ctaDisabledReason: state.writeGateReason))
                    } else {
                        ForEach(viewModel.categoryTree) { node in
                            categoryPanel(node)
                        }
                    }
                } else {
                    LoadingSkeletonView()
                }
            }
            .moduleContentPadding()
        }
    }

    private func categoryPanel(_ node: BudgetViewModel.CategoryNode) -> some View {
        PanelView(title: node.category.name,
                  subtitle: node.children.isEmpty ? node.category.defaultBudgetBehavior.rawValue
                                                  : "\(node.children.count) subcategories") {
            VStack(alignment: .leading, spacing: 4) {
                categoryRow(node.category, isChild: false)
                ForEach(node.children) { child in
                    categoryRow(child, isChild: true)
                }
            }
        } actions: {
            Button("Edit", systemImage: "pencil") { state.editCategory(node.category.categoryId) }
                .buttonStyle(GhostButtonStyle()).disabled(!state.writesEnabled)
                .help(state.writesEnabled ? "Edit category" : (state.writeGateReason ?? "Edit category"))
        }
    }

    private func categoryRow(_ category: FinanceWorkspaceKit.Category, isChild: Bool) -> some View {
        HStack(spacing: 8) {
            Text(category.name).font(DS.Fonts.table).foregroundStyle(DS.Colors.ink2)
                .padding(.leading, isChild ? 16 : 0)
            TagView(kind: .info, label: category.defaultBudgetBehavior.rawValue)
            if category.taxRelevant {
                TagView(kind: .warn, label: "tax-relevant")
            }
            Spacer()
            Text(category.categoryId).font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
        }
        .frame(height: 24)
    }
}

struct BudgetCategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetCategoriesView().environment(AppState()).frame(width: 980, height: 640)
            .preferredColorScheme(.light).previewDisplayName("Categories — light")
        BudgetCategoriesView().environment(AppState()).frame(width: 980, height: 640)
            .preferredColorScheme(.dark).previewDisplayName("Categories — dark")
    }
}
