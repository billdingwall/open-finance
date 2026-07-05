import SwiftUI

// A labelled money figure (overline + value) — the KPI-value atom shared by the Accounts
// aggregate header, per-account header, and the tax summary. One definition so the label/value
// treatment can't drift; the size and sign-coloring are explicit parameters (a dense figure row
// uses `.body`, a headline figure uses `.kpi`).

struct FigureView: View {
    /// Value size.
    enum Size { case kpi, body }
    /// How the value is colored.
    enum Sign {
        case none                 // always ink-1
        case liability            // negative = red (money owed), else ink-1
        case gainLoss             // negative = red, positive = green, zero = ink-1
    }

    let label: String
    let value: Decimal
    var size: Size = .kpi
    var sign: Sign = .none

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            OverlineLabel(text: label)
            Text(Format.money(value))
                .font(size == .kpi ? DS.Fonts.kpiValue : DS.Fonts.bodyNumeric)
                .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch sign {
        case .none: return DS.Colors.ink1
        case .liability: return value < 0 ? DS.Colors.neg : DS.Colors.ink1
        case .gainLoss: return value < 0 ? DS.Colors.neg : (value > 0 ? DS.Colors.pos : DS.Colors.ink1)
        }
    }
}
