import SwiftUI
import FinanceWorkspaceKit

// T025 — the benchmark heat-map table (FR-010, research D4, DESIGN `.heat-map-table`):
// a Grid with sticky row labels, the 8 benchmark windows as columns, the S&P 500 comparison
// row visually separated on top, pos/neg cell scale with intensity by magnitude, tabular %
// text in every cell, and typed "insufficient history" cells. Grid semantics (headers, cell
// text, row selection) — the color scale is the shared chart scale.

struct HeatCellModel: Identifiable {
    var id: String { window }
    var window: String                 // "D", "W", … "5Y"
    var growth: Decimal?               // nil = insufficient history
    var isCAGR = false
}

struct HeatRowModel: Identifiable {
    var id: String { label }
    var label: String
    var isBenchmark = false
    var cells: [HeatCellModel]
}

struct HeatMapModel {
    var rows: [HeatRowModel]           // benchmark first, then accounts
    var windows: [String]
}

extension HeatMapModel {
    /// Map the engine's `HeatMap` projection into the presentation grid (no math — the
    /// growth values pass through untouched).
    init(heatMap: HeatMap) {
        let windows = BenchmarkWindow.allCases.map(\.rawValue)
        func row(_ source: HeatMapRow, benchmark: Bool) -> HeatRowModel {
            HeatRowModel(label: source.label, isBenchmark: benchmark, cells: source.cells.map { cell in
                let isCAGR: Bool = { if case .cagr = cell.growth { return true }; return false }()
                return HeatCellModel(window: cell.window.rawValue, growth: cell.growth.value, isCAGR: isCAGR)
            })
        }
        self.init(
            rows: [row(heatMap.benchmark, benchmark: true)] + heatMap.accounts.map { row($0, benchmark: false) },
            windows: windows)
    }
}

struct HeatMapTableView: View {
    let model: HeatMapModel
    var onSelectRow: ((HeatRowModel) -> Void)?

    var body: some View {
        if model.rows.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "square.grid.3x3", title: "No benchmark data",
                message: "Add Investments/benchmarks/sp500.csv to compare periods."))
        } else {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                headerRow
                ForEach(model.rows) { row in
                    if row.isBenchmark {
                        gridRow(row)
                        Divider().gridCellUnsizedAxes(.horizontal).overlay(DS.Colors.borderStrong)
                    } else {
                        gridRow(row)
                    }
                }
            }
            .padding(8)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("").frame(minWidth: 120, alignment: .leading)
            ForEach(model.windows, id: \.self) { window in
                Text(window)
                    .font(DS.Fonts.tableHeader)
                    .foregroundStyle(DS.Colors.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func gridRow(_ row: HeatRowModel) -> some View {
        GridRow {
            Text(row.label)
                .font(row.isBenchmark ? DS.Fonts.panelTitle : DS.Fonts.table)
                .foregroundStyle(DS.Colors.ink2)
                .lineLimit(1)
                .frame(minWidth: 120, alignment: .leading)
            ForEach(row.cells) { cell in
                HeatCellView(cell: cell)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelectRow?(row) }
    }
}

/// One heat cell: pos/neg background with intensity by magnitude, tabular % text.
private struct HeatCellView: View {
    let cell: HeatCellModel

    var body: some View {
        Group {
            if let growth = cell.growth {
                Text(Format.signedPercent(growth))
                    .font(DS.Fonts.tableNumeric)
                    .foregroundStyle(DS.Colors.ink1)
                    .help(cell.isCAGR ? "Annualized (CAGR)" : "Cumulative return")
            } else {
                Text("—")
                    .font(DS.Fonts.tableNumeric)
                    .foregroundStyle(DS.Colors.muted2)
                    .help(TypedStateText.insufficientHistory)
            }
        }
        .frame(maxWidth: .infinity, minHeight: DS.Metrics.rowHeight - 4)
        .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.sm - 2))
    }

    private var background: Color {
        guard let growth = cell.growth else { return DS.Colors.surfaceSunken }
        // Intensity by magnitude: 0 → barely tinted; ≥25% → full soft scale.
        let magnitude = min(abs(NSDecimalNumber(decimal: growth).doubleValue) / 0.25, 1.0)
        let base = growth >= 0 ? DS.Colors.pos : DS.Colors.neg
        return base.opacity(0.08 + 0.32 * magnitude)
    }
}

struct HeatMapTableView_Previews: PreviewProvider {
    static func cells(_ values: [Decimal?]) -> [HeatCellModel] {
        zip(BenchmarkWindow.allCases.map(\.rawValue), values).map { window, value in
            HeatCellModel(window: window, growth: value, isCAGR: window == "3Y" || window == "5Y")
        }
    }

    static let model = HeatMapModel(rows: [
        HeatRowModel(label: "S&P 500", isBenchmark: true,
                     cells: cells([0.001, 0.004, 0.012, 0.03, 0.055, 0.11, 0.09, 0.08])),
        HeatRowModel(label: "Brokerage",
                     cells: cells([0.002, -0.003, 0.02, 0.04, 0.06, 0.13, nil, nil])),
        HeatRowModel(label: "Retirement",
                     cells: cells([0.0, 0.002, -0.01, 0.02, 0.05, 0.10, 0.085, nil])),
    ], windows: BenchmarkWindow.allCases.map(\.rawValue))

    static var previews: some View {
        HeatMapTableView(model: model)
            .padding().frame(width: 760)
            .preferredColorScheme(.light).previewDisplayName("Heat map — light")
        HeatMapTableView(model: model)
            .padding().frame(width: 760)
            .preferredColorScheme(.dark).previewDisplayName("Heat map — dark")
    }
}
