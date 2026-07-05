import SwiftUI

// T022 — KPI card (FR-008, DESIGN `.kpi-card`): overline label + 22px tabular value + optional
// pos/neg/flat delta + secondary line. The WHOLE card is the tap target → its module route
// (constitution P-V). Typed engine states render as designed muted text, never zeros.

struct KPICardModel: Identifiable {
    var id: String
    var overline: String
    var value: String
    var secondary: String?
    var delta: Delta?
    var typedState: String?            // e.g. "rate not set" / "data not available"
    var route: Route

    /// Trailing footnote (e.g. the stored estimated rate).
    var footnote: String?
}

struct KPICardView: View {
    @Environment(AppState.self) private var state
    let model: KPICardModel

    var body: some View {
        Button {
            state.router.navigate(to: model.route)
        } label: {
            VStack(alignment: .leading, spacing: DS.Metrics.unit) {
                OverlineLabel(text: model.overline)
                if let typedState = model.typedState {
                    Text(typedState)
                        .font(DS.Fonts.body)
                        .foregroundStyle(DS.Colors.muted)
                        .padding(.vertical, 6)
                } else {
                    Text(model.value)
                        .font(DS.Fonts.kpiValue)
                        .foregroundStyle(DS.Colors.ink1)
                }
                HStack(spacing: 6) {
                    if let delta = model.delta {
                        Text(delta.text)
                            .font(DS.Fonts.captionNumeric)
                            .foregroundStyle(deltaColor(delta))
                    }
                    if let secondary = model.secondary {
                        Text(secondary)
                            .font(DS.Fonts.captionNumeric)
                            .foregroundStyle(DS.Colors.muted)
                    }
                }
                if let footnote = model.footnote {
                    Text(footnote).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.normal))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.overline): \(model.typedState ?? model.value). Opens its module.")
    }

    private func deltaColor(_ delta: Delta) -> Color {
        switch delta {
        case .pos: return DS.Colors.pos
        case .neg: return DS.Colors.neg
        case .flat: return DS.Colors.muted
        }
    }
}

struct KPICardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: DS.Metrics.kpiGridGap) {
            KPICardView(model: KPICardModel(
                id: "budget", overline: "Budget", value: "$4,000.00",
                secondary: "spent $1,720.45", delta: .pos("+$120.00"), route: .budget(.overview)))
            KPICardView(model: KPICardModel(
                id: "investments", overline: "Investments", value: "—",
                typedState: TypedStateText.rateNotSet, route: .savingsInvestments(.portfolio)))
        }
        .environment(AppState())
        .padding().frame(width: 560)
        .preferredColorScheme(.light).previewDisplayName("KPI — light")

        KPICardView(model: KPICardModel(
            id: "taxes", overline: "Taxes", value: "$268.50",
            secondary: "paid $1,500.00", delta: .neg("-$45.00"), route: .taxes(.currentYear)))
            .environment(AppState())
            .padding().frame(width: 280)
            .preferredColorScheme(.dark).previewDisplayName("KPI — dark")
    }
}
