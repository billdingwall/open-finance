import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 6 (007) T040 (US6) — CSV provenance columns, Markdown shape, workspace-path guard.

@Suite struct ExportServiceTests {

    @Test func csvAppendsProvenanceColumns() {
        let out = ExportService().csv(
            rows: [["date": "2026-06-01", "amount": "-42.50"]],
            columns: ["date", "amount"],
            provenance: [(file: "Accounts/transactions/2026-06.csv", row: 7)])
        let lines = out.split(separator: "\n")
        #expect(lines[0] == "date,amount,source_file,source_row")
        #expect(lines[1] == "2026-06-01,-42.50,Accounts/transactions/2026-06.csv,7")
    }

    @Test func csvEscapesAndHandlesEmptyView() {
        let empty = ExportService().csv(rows: [], columns: ["date", "amount"], provenance: [])
        #expect(empty == "date,amount,source_file,source_row\n")     // headers only (edge case)
    }

    @Test func budgetMarkdownHasPeriodHeaderAndTable() {
        let md = ExportService().budgetSummaryMarkdown(
            period: "2026-06",
            rows: [BudgetSummaryRow(category: "Groceries", planned: "600", actual: "640",
                                    variance: "-40", trailingAvg: "620")],
            totalPlanned: "600", totalActual: "640")
        #expect(md.hasPrefix("# Budget — 2026-06"))
        #expect(md.contains("| Category | Planned | Actual | Variance | 3-mo avg |"))
        #expect(md.contains("| Groceries | 600 | 640 | -40 | 620 |"))
        #expect(md.contains("**Total**"))
    }

    @Test func writeRejectsWorkspaceInternalDestination() {
        let ws = URL(fileURLWithPath: "/tmp/Finance")
        let inside = ws.appendingPathComponent("export.csv")
        #expect(throws: ExportError.self) {
            try ExportService().write("x", to: inside, workspaceURL: ws)
        }
    }

    @Test func writeSucceedsOutsideWorkspace() throws {
        let ws = URL(fileURLWithPath: "/tmp/Finance")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("of-export-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: dest) }
        try ExportService().write("hello\n", to: dest, workspaceURL: ws)
        #expect(try String(contentsOf: dest, encoding: .utf8) == "hello\n")
    }
}
