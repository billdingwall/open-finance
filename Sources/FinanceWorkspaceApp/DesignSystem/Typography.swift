import SwiftUI

// T003 — DesignSystem type scale, mirrored from DESIGN.md `typography.scale`. SF Pro is the
// system font; sizes are the design-intent px values. Tabular numerals on every numeric style —
// misaligned digits in a finance table read as a bug.

extension DS {
    enum Fonts {
        /// 20/600 — one per screen, preceded by a breadcrumb.
        static let pageTitle = Font.system(size: 20, weight: .semibold)
        /// 22/600 tabular — KPI primary values.
        static let kpiValue = Font.system(size: 22, weight: .semibold).monospacedDigit()
        /// 15/600 — section headings.
        static let section = Font.system(size: 15, weight: .semibold)
        /// 12.5/600 — panel titles.
        static let panelTitle = Font.system(size: 12.5, weight: .semibold)
        /// 13/400 — body.
        static let body = Font.system(size: 13)
        /// 13/400 tabular — numeric body values.
        static let bodyNumeric = Font.system(size: 13).monospacedDigit()
        /// 12.5/400 — table cells; numeric cells get the tabular variant.
        static let table = Font.system(size: 12.5)
        static let tableNumeric = Font.system(size: 12.5).monospacedDigit()
        /// 10.5/600 uppercase — sticky table headers (component contract).
        static let tableHeader = Font.system(size: 10.5, weight: .semibold)
        /// 11/600 uppercase +0.04em — overline labels (KPI cards, panel section labels); muted.
        static let overline = Font.system(size: 11, weight: .semibold)
        /// 11/400 — captions, breadcrumbs.
        static let caption = Font.system(size: 11)
        static let captionNumeric = Font.system(size: 11).monospacedDigit()
    }
}

/// Overline treatment: 11/600, uppercase, +0.04em tracking, muted ink.
struct OverlineLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(DS.Fonts.overline)
            .tracking(0.44)
            .foregroundStyle(DS.Colors.muted)
    }
}
