import Foundation

// Phase 6 (007) US6 (T041) — export the current view. CSV carries source-provenance columns
// (P-V traceability); the Budget month exports a Markdown summary. Exports write only to a
// user-chosen destination and never touch a workspace file (FR-027/028/029).

public enum ExportError: Error, Sendable, Equatable { case destinationInsideWorkspace }

/// One preformatted category row for the Markdown budget summary.
public struct BudgetSummaryRow: Sendable, Equatable {
    public let category: String
    public let planned: String
    public let actual: String
    public let variance: String
    public let trailingAvg: String
    public init(category: String, planned: String, actual: String, variance: String, trailingAvg: String) {
        self.category = category; self.planned = planned; self.actual = actual
        self.variance = variance; self.trailingAvg = trailingAvg
    }
}

public struct ExportService: Sendable {
    public init() {}

    /// Render `rows` (each a canonical column→value dict) as CSV with the given column order,
    /// appending `source_file` and `source_row` provenance columns (FR-027).
    public func csv(rows: [[String: String]], columns: [String],
                    provenance: [(file: String, row: Int)]) -> String {
        let header = (columns + ["source_file", "source_row"]).joined(separator: ",")
        let lines = rows.enumerated().map { index, row -> String in
            var cells = columns.map { CSVRowSerializer.escape(row[$0] ?? "") }
            let prov = index < provenance.count ? provenance[index] : (file: "", row: 0)
            cells.append(CSVRowSerializer.escape(prov.file))
            cells.append(String(prov.row))
            return cells.joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n") + "\n"
    }

    /// A Markdown budget summary: period header + a category table + a totals line (FR-028).
    public func budgetSummaryMarkdown(period: String, rows: [BudgetSummaryRow],
                                      totalPlanned: String, totalActual: String) -> String {
        var out = "# Budget — \(period)\n\n"
        out += "| Category | Planned | Actual | Variance | 3-mo avg |\n"
        out += "|---|--:|--:|--:|--:|\n"
        for row in rows {
            out += "| \(row.category) | \(row.planned) | \(row.actual) | \(row.variance) | \(row.trailingAvg) |\n"
        }
        out += "| **Total** | **\(totalPlanned)** | **\(totalActual)** | | |\n"
        return out
    }

    /// Write exported text to a user-chosen destination. Rejects any path inside the workspace
    /// (FR-029). No workspace file is modified.
    public func write(_ text: String, to destination: URL, workspaceURL: URL?) throws {
        if let ws = workspaceURL,
           destination.standardizedFileURL.path.hasPrefix(ws.standardizedFileURL.path) {
            throw ExportError.destinationInsideWorkspace
        }
        try Data(text.utf8).write(to: destination, options: .atomic)
    }
}
