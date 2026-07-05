import SwiftUI
import Charts

// T024 — the marks-based charts on Swift Charts (FR-010, chart-styling rules): single-accent
// series, restrained accent-derived ramp for categorical pies, pos/neg for signed values,
// tabular axis labels, `chart-wrap` heights (tall 230 / short 140), empty state per chart.

struct PieSlice: Identifiable {
    var id: String { label }
    var label: String
    var value: Decimal
}

struct SparkPoint: Identifiable {
    var id: String { period }
    var period: String
    var value: Decimal
}

struct BarPoint: Identifiable {
    var id: String { label }
    var label: String
    var value: Decimal
}

/// Restrained categorical ramp derived from the single brand accent (no rainbows).
enum ChartPalette {
    static func ramp(_ count: Int) -> [Color] {
        let steps: [Double] = [1.0, 0.75, 0.55, 0.4, 0.28, 0.18]
        return (0..<max(count, 1)).map { DS.Colors.accent.opacity(steps[$0 % steps.count]) }
    }
}

// MARK: - Donut / pie (`SectorMark`)

struct PieChartView: View {
    let slices: [PieSlice]
    var height: CGFloat = DS.Metrics.chartTall

    var body: some View {
        if slices.isEmpty || slices.allSatisfy({ $0.value == 0 }) {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "chart.pie", title: "No data",
                message: "Nothing to chart for this period."))
                .frame(height: height)
        } else {
            let colors = ChartPalette.ramp(slices.count)
            VStack(spacing: 8) {
                Chart(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    SectorMark(
                        angle: .value("Amount", abs(NSDecimalNumber(decimal: slice.value).doubleValue)),
                        innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(colors[index])
                        .cornerRadius(2)
                }
                .chartLegend(.hidden)
                legend(colors: colors)
            }
            .frame(height: height)
            .accessibilityLabel("Pie chart with \(slices.count) segments")
        }
    }

    private func legend(colors: [Color]) -> some View {
        let total = slices.reduce(Decimal(0)) { $0 + abs($1.value) }
        return HStack(spacing: 10) {
            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(colors[index]).frame(width: 8, height: 8)
                    Text(slice.label).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                    Text(total > 0 ? Format.percent(abs(slice.value) / total, digits: 0) : "—")
                        .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.ink3)
                }
            }
        }
    }
}

// MARK: - Sparkline (`LineMark`, short wrap)

struct SparklineView: View {
    let points: [SparkPoint]
    var height: CGFloat = DS.Metrics.chartShort

    var body: some View {
        if points.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "chart.xyaxis.line", title: "No history",
                message: "Populated months appear here."))
                .frame(height: height)
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Period", point.period),
                    y: .value("Value", NSDecimalNumber(decimal: point.value).doubleValue))
                    .foregroundStyle(DS.Colors.accent)
                    .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Period", point.period),
                    y: .value("Value", NSDecimalNumber(decimal: point.value).doubleValue))
                    .foregroundStyle(DS.Colors.accent)
                    .symbolSize(18)
            }
            .chartXAxis { axisMarks() }
            .chartYAxis { yAxisMarks() }
            .frame(height: height)
            .accessibilityLabel("Trend over \(points.count) periods")
        }
    }
}

// MARK: - Bar chart (`BarMark`, pos/neg for signed series)

struct BarChartView: View {
    /// How signed bars are colored.
    enum SignStyle {
        case none                 // single accent series
        case gainLoss             // positive = gain (green), negative = loss (red)
        case variance             // positive = overspend (red), negative = under (green)
    }

    let points: [BarPoint]
    var signStyle: SignStyle = .none
    var height: CGFloat = DS.Metrics.chartShort

    var body: some View {
        if points.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "chart.bar", title: "No data",
                message: "Populated months appear here."))
                .frame(height: height)
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("Label", point.label),
                    y: .value("Value", NSDecimalNumber(decimal: point.value).doubleValue))
                    .foregroundStyle(barColor(point.value))
                    .cornerRadius(2)
            }
            .chartXAxis { axisMarks() }
            .chartYAxis { yAxisMarks() }
            .frame(height: height)
            .accessibilityLabel("Bar chart with \(points.count) bars")
        }
    }

    private func barColor(_ value: Decimal) -> Color {
        switch signStyle {
        case .none: return DS.Colors.accent
        case .gainLoss: return value < 0 ? DS.Colors.neg : DS.Colors.pos
        case .variance: return value > 0 ? DS.Colors.neg : DS.Colors.pos
        }
    }
}

// MARK: - Grouped bars (`BarMark` + position(by:), accent-derived ramp)

struct GroupedBarPoint: Identifiable {
    var id: String { "\(label)-\(series)" }
    var label: String
    var series: String
    var value: Decimal
}

/// Categorical grouped bars (e.g. gross / expenses / taxes per month) on the restrained
/// accent ramp — no rainbow, no saturated primaries.
struct GroupedBarChartView: View {
    let points: [GroupedBarPoint]
    var height: CGFloat = DS.Metrics.chartTall

    private var seriesNames: [String] {
        var seen: [String] = []
        for point in points where !seen.contains(point.series) { seen.append(point.series) }
        return seen
    }

    var body: some View {
        if points.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "chart.bar", title: "No data",
                message: "Populated months appear here."))
                .frame(height: height)
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("Label", point.label),
                    y: .value("Value", NSDecimalNumber(decimal: point.value).doubleValue))
                    .position(by: .value("Series", point.series))
                    .foregroundStyle(by: .value("Series", point.series))
                    .cornerRadius(2)
            }
            .chartForegroundStyleScale(domain: seriesNames, range: ChartPalette.ramp(seriesNames.count))
            .chartXAxis { axisMarks() }
            .chartYAxis { yAxisMarks() }
            .chartLegend(position: .bottom, spacing: 6)
            .frame(height: height)
            .accessibilityLabel("Grouped bar chart, \(seriesNames.joined(separator: ", "))")
        }
    }
}

// MARK: - Shared axis styling (muted tabular labels, soft gridlines)

private func axisMarks() -> some AxisContent {
    AxisMarks { _ in
        AxisValueLabel()
            .font(DS.Fonts.captionNumeric)
            .foregroundStyle(DS.Colors.muted)
    }
}

private func yAxisMarks() -> some AxisContent {
    AxisMarks { _ in
        AxisGridLine().foregroundStyle(DS.Colors.borderSoft)
        AxisValueLabel()
            .font(DS.Fonts.captionNumeric)
            .foregroundStyle(DS.Colors.muted)
    }
}

struct Charts_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DS.Metrics.panelGap) {
            PieChartView(slices: [
                PieSlice(label: "Fixed", value: 1800), PieSlice(label: "Discretionary", value: 950),
                PieSlice(label: "Savings", value: 500), PieSlice(label: "Investments", value: 400)])
            SparklineView(points: (1...6).map { SparkPoint(period: "2026-0\($0)", value: Decimal(2000 + $0 * 80)) })
            BarChartView(points: [
                BarPoint(label: "Apr", value: 1200), BarPoint(label: "May", value: -300),
                BarPoint(label: "Jun", value: 900)], signStyle: .gainLoss)
        }
        .padding().frame(width: 560)
        .preferredColorScheme(.light).previewDisplayName("Charts — light")

        SparklineView(points: (1...6).map { SparkPoint(period: "2026-0\($0)", value: Decimal(2000 + $0 * 80)) })
            .padding().frame(width: 560)
            .preferredColorScheme(.dark).previewDisplayName("Charts — dark")
    }
}
