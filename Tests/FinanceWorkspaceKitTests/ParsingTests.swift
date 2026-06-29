import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T009 / SC-001 — a provisioned workspace parses into typed records with provenance, zero warnings.

@Suite struct ParsingTests {

    private func provisionedWorkspace() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-parse-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        try WorkspaceProvisioner().provision(at: ws)
        return ws
    }

    @Test func provisionedWorkspaceParsesCleanly() throws {
        let ws = try provisionedWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        let context = try WorkspaceParser().parse(workspaceURL: ws)

        // Every seeded CSV is recognized and parsed; the Workspace.md note is parsed.
        #expect(context.parseResults.count >= 12)
        #expect(context.notes.contains { $0.noteType == "workspace" })

        // SC-001: a clean workspace yields zero parse warnings.
        #expect(context.allWarnings.isEmpty, "unexpected warnings: \(context.allWarnings)")

        // Every typed record carries source provenance (Principle V).
        for result in context.parseResults {
            for record in result.records {
                #expect(!record.sourceFile.isEmpty)
                #expect(record.sourceRow >= 1)
            }
        }

        // The six seed accounts parse with typed, valid fields.
        let accounts = context.records(ofType: "registry")
        #expect(accounts.count == 6)
        #expect(accounts.allSatisfy { !$0.hasInvalidField })
        #expect(accounts.first?.fields["account_id"]?.isValid == true)
    }

    @Test func registryClassifiesSeededFileTypes() throws {
        let registry = try CSVSchemaRegistry()
        #expect(registry.schema(forRelativePath: "Accounts/accounts.csv") != nil)
        #expect(registry.schema(forRelativePath: "Budget/categories.csv") != nil)
        #expect(registry.schema(forRelativePath: "Accounts/transactions/2026-05.csv")?.fileTypeKey == "transactions")
        #expect(registry.schema(forRelativePath: "Nope/unknown.csv") == nil)
    }
}
