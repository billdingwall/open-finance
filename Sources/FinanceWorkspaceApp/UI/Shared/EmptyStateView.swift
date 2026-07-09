import SwiftUI

// T027 — configurable empty state (glyph + title + one-line message + optional CTA) and the
// loading skeleton for projection-pending surfaces (FR-011). One empty state per data-less
// surface; CTAs that require writes ship disabled (clarify Q3).

struct EmptyStateModel {
    var systemImage: String
    var title: String
    var message: String
    var ctaTitle: String?
    var ctaEnabled = false
    var ctaAction: () -> Void = {}
    /// Why the CTA is disabled (sync gate), shown as its tooltip when `ctaEnabled` is false.
    var ctaDisabledReason: String?
}

struct EmptyStateView: View {
    let model: EmptyStateModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: model.systemImage)
                .font(.system(size: 28))
                .foregroundStyle(DS.Colors.muted)
            Text(model.title).font(DS.Fonts.section).foregroundStyle(DS.Colors.ink2)
            Text(model.message).font(DS.Fonts.body).foregroundStyle(DS.Colors.muted)
                .multilineTextAlignment(.center)
            if let cta = model.ctaTitle {
                Button(cta) { model.ctaAction() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!model.ctaEnabled)
                    .help(model.ctaEnabled ? cta : (model.ctaDisabledReason ?? cta))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(DS.Metrics.panelGap)
    }
}

/// Shimmering placeholder blocks while the first snapshot is indexing (SC-010).
struct LoadingSkeletonView: View {
    var rows = 3
    @State private var pulse = false

    var body: some View {
        VStack(spacing: DS.Metrics.kpiGridGap) {
            HStack(spacing: DS.Metrics.kpiGridGap) {
                ForEach(0..<5, id: \.self) { _ in block(height: 72) }
            }
            ForEach(0..<rows, id: \.self) { _ in block(height: DS.Metrics.chartShort) }
        }
        .opacity(pulse ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityLabel("Loading projections")
    }

    private func block(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.normal)
            .fill(DS.Colors.surfaceSunken)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "target", title: "No savings goals yet",
                message: "Goals appear here once Savings/goals.csv has rows.",
                ctaTitle: "Add goal"))
            LoadingSkeletonView()
        }
        .padding().frame(width: 700)
        .preferredColorScheme(.light).previewDisplayName("Empty + skeleton — light")
        EmptyStateView(model: EmptyStateModel(
            systemImage: "tray", title: "No data", message: "Nothing to show for this period."))
            .padding().frame(width: 500)
            .preferredColorScheme(.dark).previewDisplayName("Empty — dark")
    }
}
