import SwiftUI

// A horizontal progress bar: accent fill over an accent-soft track. The fraction is clamped to
// 0...1 at BOTH ends — a negative fraction (e.g. an overdrawn goal balance) would otherwise
// produce a negative-width frame and a SwiftUI runtime warning.

struct ProgressBarView: View {
    /// 0…1; values outside are clamped.
    let fraction: Double
    var height: CGFloat = 6
    var cornerRadius: CGFloat = 3

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DS.Colors.accentSoft)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DS.Colors.accent)
                        .frame(width: proxy.size.width * clamped)
                }
        }
        .frame(height: height)
    }

    /// Convenience: build from a Decimal ratio (value / total), guarding total == 0.
    init(value: Decimal, total: Decimal, height: CGFloat = 6, cornerRadius: CGFloat = 3) {
        self.fraction = total > 0 ? NSDecimalNumber(decimal: value / total).doubleValue : 0
        self.height = height
        self.cornerRadius = cornerRadius
    }

    init(fraction: Double, height: CGFloat = 6, cornerRadius: CGFloat = 3) {
        self.fraction = fraction
        self.height = height
        self.cornerRadius = cornerRadius
    }
}
