import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// 008 T028 (US2) — the import flow's gating rules, tested at the model layer the view binds to:
// an unmapped required column refuses to build a batch (blocks advance), likely duplicates are
// default-excluded from the import, and the single target account scopes both row stamping and
// duplicate detection (choosing one is what makes the batch meaningful — FR-015/clarify Q1/Q2).

@Suite struct ImportViewModelTests {

    private func existingTransactions() throws -> [ParsedRecord] {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let context = try WorkspaceParser().parse(workspaceURL: fixture.root)
        return context.records(ofType: "transactions")
    }

    @Test func requiredUnmappedBlocksAdvance() throws {
        let existing = try existingTransactions()
        // `amount` mapped, `date` not — the view's Preview/Import stays blocked on this throw.
        let mapping = ColumnMapping(sourceColumns: ["Posted", "Value"],
                                    map: ["amount": "Value"], targetAccountId: "A1")
        #expect(throws: ImportError.requiredColumnUnmapped(["date"])) {
            _ = try ImportMapper().buildBatch(csv: "Posted,Value\n2026-06-05,-200\n",
                                              mapping: mapping, existingTransactions: existing)
        }
    }

    @Test func duplicatesAreDefaultExcluded() throws {
        let existing = try existingTransactions()
        // Fixture T4 = A1, 2026-06-05, -200 → same date+amount in the same account is a likely dup.
        let csv = "date,amount\n2026-06-05,-200\n2026-06-06,-42.50\n"
        let mapping = ColumnMapping(sourceColumns: ["date", "amount"],
                                    map: ["date": "date", "amount": "amount"],
                                    targetAccountId: "A1")
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: mapping,
                                                  existingTransactions: existing)
        let rows = batch.rowsByMonth["2026-06"] ?? []
        #expect(rows.count == 2)
        let dup = try #require(rows.first { $0.values["date"] == "2026-06-05" })
        #expect(dup.isDuplicate && !dup.included)          // flagged AND excluded by default
        let fresh = try #require(rows.first { $0.values["date"] == "2026-06-06" })
        #expect(!fresh.isDuplicate && fresh.included)
        #expect(batch.includedCount == 1)                  // only the fresh row imports
    }

    @Test func targetAccountScopesStampingAndDuplicates() throws {
        let existing = try existingTransactions()
        let csv = "date,amount\n2026-06-05,-200\n"
        // Same date+amount as A1's T4, but imported into A2 → NOT a duplicate there,
        // and every row is stamped with the chosen account (clarify Q1: one target account).
        let mapping = ColumnMapping(sourceColumns: ["date", "amount"],
                                    map: ["date": "date", "amount": "amount"],
                                    targetAccountId: "A2")
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: mapping,
                                                  existingTransactions: existing)
        let row = try #require(batch.rowsByMonth["2026-06"]?.first)
        #expect(row.values["account_id"] == "A2")
        #expect(!row.isDuplicate && row.included)
        #expect(batch.includedCount == 1)
    }
}
