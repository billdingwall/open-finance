import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T019 / SC-003 — a clean, valid workspace produces zero errors and zero false-positive warnings.

@Suite struct ValidationTests {

    @Test func cleanWorkspaceHasNoIssues() throws {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-valid-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        try WorkspaceProvisioner().provision(at: ws)

        let context = try WorkspaceParser().parse(workspaceURL: ws)
        let result = ValidationEngine().validate(context)

        #expect(result.errorCount == 0, "errors: \(result.bySeverity[.error] ?? [])")
        #expect(result.warningCount == 0, "warnings: \(result.bySeverity[.warning] ?? [])")
        #expect(result.issues.isEmpty)
        #expect(result.hasErrors == false)
    }
}
