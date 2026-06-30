import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T021 / FR-009a — parse/normalization warnings are lifted into ValidationResult as file-level
// issues, so there is a single unified issue stream.

@Suite struct UnifiedIssueStreamTests {

    @Test func parseWarningsAppearAsFileLevelValidationIssues() throws {
        let schema = try #require(try CSVSchemaRegistry().schema(forSubtype: "transactions"))
        let csv = """
        # schema_version: 1
        transaction_id,account_id,date,amount
        t1,a1,NOPE,bad
        """
        let parseResult = CSVParserService().parse(text: csv,
            relativePath: "Accounts/transactions/2026-05.csv", schema: schema)

        // A real provisioned workspace as the URL so FileRules doesn't fire spuriously.
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-unified-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        try WorkspaceProvisioner().provision(at: ws)

        let context = WorkspaceContext(workspaceURL: ws, parseResults: [parseResult], notes: [])
        let result = ValidationEngine().validate(context)

        // The invalid date and decimal surfaced at parse time appear in the unified stream.
        #expect(result.issues.contains { $0.ruleId == "VAL-FILE-006" && $0.tier == .file })  // bad date
        #expect(result.issues.contains { $0.ruleId == "VAL-FILE-007" && $0.tier == .file })  // bad decimal
        // Lifted issues carry the source location from the parse warning.
        let dateIssue = try #require(result.issues.first { $0.ruleId == "VAL-FILE-006" })
        #expect(dateIssue.filePath == "Accounts/transactions/2026-05.csv")
        #expect(dateIssue.rowRef == 1)
        #expect(dateIssue.column == "date")
    }
}
