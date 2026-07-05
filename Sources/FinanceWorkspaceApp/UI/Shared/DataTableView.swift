import SwiftUI

// T023 — the shared data table (FR-009, DESIGN `.tbl`): sticky uppercase header on
// surface-tint, 30px dense rows, right-aligned tabular numerics, click-to-sort columns,
// hover = surface-sunken, selected = accent-soft, and a per-row traceability target
// (row click → source inspector, constitution P-V).

struct TableColumnSpec: Identifiable {
    enum Alignment { case leading, trailing }
    var id: String
    var title: String
    var alignment: Alignment = .leading
    var width: CGFloat?
    var sortable = true
}

/// One cell: display text + semantic style. Money cells carry pos/neg meaning only.
struct CellValue {
    enum Style { case normal, numeric, pos, neg, muted }
    var text: String
    var style: Style = .normal
    /// Sort key (falls back to text).
    var sortKey: SortKey?

    static func money(_ value: Decimal, signed: Bool = false) -> CellValue {
        let style: Style = signed ? (value > 0 ? .pos : (value < 0 ? .neg : .numeric)) : .numeric
        return CellValue(text: Format.money(value), style: style, sortKey: .number(value))
    }
    /// A budget/plan variance (actual − planned): positive = OVERSPEND = red, negative = under = green.
    /// Distinct from `.money(signed:)` because here a positive number is bad, not a gain.
    static func variance(_ value: Decimal) -> CellValue {
        let style: Style = value > 0 ? .neg : (value < 0 ? .pos : .numeric)
        return CellValue(text: Format.money(value), style: style, sortKey: .number(value))
    }
    static func text(_ text: String) -> CellValue { CellValue(text: text, sortKey: .text(text)) }
    static func muted(_ text: String) -> CellValue { CellValue(text: text, style: .muted, sortKey: .text(text)) }
    static func number(_ value: Decimal, display: String) -> CellValue {
        CellValue(text: display, style: .numeric, sortKey: .number(value))
    }
}

enum SortKey: Comparable {
    case text(String)
    case number(Decimal)
    case date(Date)

    static func < (lhs: SortKey, rhs: SortKey) -> Bool {
        switch (lhs, rhs) {
        case let (.text(left), .text(right)): return left.localizedCompare(right) == .orderedAscending
        case let (.number(left), .number(right)): return left < right
        case let (.date(left), .date(right)): return left < right
        default: return false
        }
    }
}

struct TableRowModel: Identifiable {
    var id: String
    var cells: [CellValue]
    var sourceRef: SourceRef?
    var tag: (kind: StatusKind, label: String)?
}

struct DataTableView: View {
    /// The sticky header's contribution to the table's frame height (header row + divider slack).
    /// Kept next to `DS.Metrics.rowHeight` so the two can't drift; used by `idealHeight`.
    static let headerHeight: CGFloat = 30

    /// Ideal frame height for `rows` data rows plus the sticky header, capped at `maxHeight`.
    /// Replaces the `min(CGFloat(count) * rowHeight + 30, cap)` formula that was copy-pasted at
    /// every table site.
    static func idealHeight(rows: Int, max maxHeight: CGFloat) -> CGFloat {
        min(CGFloat(rows) * DS.Metrics.rowHeight + headerHeight, maxHeight)
    }

    let columns: [TableColumnSpec]
    let rows: [TableRowModel]
    var onSelect: ((TableRowModel) -> Void)?

    @State private var sortColumn: Int?
    @State private var sortAscending = true
    @State private var hoveredRow: String?
    @State private var selectedRow: String?

    private var sortedRows: [TableRowModel] {
        guard let sortColumn else { return rows }
        return rows.sorted { lhs, rhs in
            let left = lhs.cells.indices.contains(sortColumn) ? lhs.cells[sortColumn] : nil
            let right = rhs.cells.indices.contains(sortColumn) ? rhs.cells[sortColumn] : nil
            let lKey = left?.sortKey ?? .text(left?.text ?? "")
            let rKey = right?.sortKey ?? .text(right?.text ?? "")
            return sortAscending ? lKey < rKey : rKey < lKey
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                Section {
                    ForEach(sortedRows) { row in rowView(row) }
                } header: {
                    headerRow
                }
            }
        }
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.normal))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                Button {
                    guard column.sortable else { return }
                    if sortColumn == index { sortAscending.toggle() } else { sortColumn = index; sortAscending = true }
                } label: {
                    HStack(spacing: 2) {
                        Text(column.title.uppercased())
                            .font(DS.Fonts.tableHeader).tracking(0.4)
                            .foregroundStyle(DS.Colors.muted)
                        if sortColumn == index {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(DS.Colors.muted)
                        }
                    }
                    .frame(maxWidth: column.width ?? .infinity,
                           alignment: column.alignment == .trailing ? .trailing : .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(DS.Colors.surfaceTint)
        .overlay(alignment: .bottom) { Divider().overlay(DS.Colors.borderSoft) }
    }

    private func rowView(_ row: TableRowModel) -> some View {
        Button {
            selectedRow = row.id
            onSelect?(row)
        } label: {
            HStack(spacing: 8) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                    cellView(row.cells.indices.contains(index) ? row.cells[index] : CellValue(text: ""))
                        .frame(maxWidth: column.width ?? .infinity,
                               alignment: column.alignment == .trailing ? .trailing : .leading)
                }
                if let tag = row.tag {
                    TagView(kind: tag.kind, label: tag.label)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: DS.Metrics.rowHeight)
            .background(rowBackground(row))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Only the currently-hovered row may clear the highlight — guards against an
            // out-of-order onHover(false) from a row we already moved off of.
            if hovering {
                hoveredRow = row.id
            } else if hoveredRow == row.id {
                hoveredRow = nil
            }
        }
    }

    private func rowBackground(_ row: TableRowModel) -> Color {
        if selectedRow == row.id { return DS.Colors.accentSoft }
        if hoveredRow == row.id { return DS.Colors.surfaceSunken }
        return .clear
    }

    private func cellView(_ cell: CellValue) -> some View {
        Text(cell.text)
            .font(cell.style == .normal ? DS.Fonts.table : DS.Fonts.tableNumeric)
            .foregroundStyle(cellColor(cell.style))
            .lineLimit(1)
    }

    private func cellColor(_ style: CellValue.Style) -> Color {
        switch style {
        case .normal, .numeric: return DS.Colors.ink2
        case .pos: return DS.Colors.pos
        case .neg: return DS.Colors.neg
        case .muted: return DS.Colors.muted
        }
    }
}

struct DataTableView_Previews: PreviewProvider {
    static let columns = [
        TableColumnSpec(id: "date", title: "Date"),
        TableColumnSpec(id: "desc", title: "Category"),
        TableColumnSpec(id: "amount", title: "Amount", alignment: .trailing),
    ]
    static let rows = [
        TableRowModel(id: "1", cells: [.text("2026-06-01"), .text("Groceries"), .money(-125.40, signed: true)],
                      sourceRef: SourceRef(filePath: "Accounts/transactions/2026-06.csv", rowNumber: 1)),
        TableRowModel(id: "2", cells: [.text("2026-06-03"), .text("Paycheck"), .money(4000, signed: true)],
                      sourceRef: SourceRef(filePath: "Accounts/transactions/2026-06.csv", rowNumber: 2)),
    ]

    static var previews: some View {
        DataTableView(columns: columns, rows: rows)
            .padding().frame(width: 620, height: 220)
            .preferredColorScheme(.light).previewDisplayName("Table — light")
        DataTableView(columns: columns, rows: rows)
            .padding().frame(width: 620, height: 220)
            .preferredColorScheme(.dark).previewDisplayName("Table — dark")
    }
}
