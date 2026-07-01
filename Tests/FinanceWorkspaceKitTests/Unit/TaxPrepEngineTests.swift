import Testing
import Foundation
@testable import FinanceWorkspaceKit

// US3 (T032) — TaxPrepEngine: checklist states and the year-close archive (write-once, read-only)
// (SC-007).

@Suite struct TaxPrepEngineTests {

    private let settings = WorkspaceSettings(filingStatus: .single, taxYear: 2026, defaultCurrency: "USD", timezone: "UTC")

    private func makeWorkspace() -> FixtureWorkspace {
        let fx = FixtureWorkspace()
        fx.write("Taxes/documents.csv", FixtureWorkspace.taxDocHeader, ["doc1,2026,W-2,Employer,"])
        fx.write("Taxes/estimated-payments.csv", FixtureWorkspace.estPaymentHeader, [
            "p1,2026,1,3000,true", "p2,2026,2,3000,false"])   // one unpaid → incomplete
        fx.write("Taxes/tax-adjustments.csv", FixtureWorkspace.taxAdjHeader, [
            "adj-standard,standard,15750.00,2026,estimated,"]) // estimated → deductions incomplete
        return fx
    }

    @Test func checklistClassifiesEachItem() throws {
        let fx = makeWorkspace(); defer { fx.cleanup() }
        let summary = TaxPrepEngine().prepSummary(try fx.parse(), settings: settings)
        let byKind = Dictionary(summary.items.map { ($0.kind, $0.state) }, uniquingKeysWith: { a, _ in a })
        #expect(byKind[.w2Income] == .complete)               // W-2 doc present
        #expect(byKind[.form1099] == .missing)                // no 1099 doc
        #expect(byKind[.estimatedPayments] == .incomplete)    // one unpaid
        #expect(byKind[.deductionConfirmations] == .incomplete) // standard row still estimated
    }

    @Test func yearCloseWritesArchiveThenReadOnly() throws {
        let fx = makeWorkspace(); defer { fx.cleanup() }
        let engine = TaxPrepEngine()
        #expect(engine.isYearClosed(workspaceURL: fx.root, year: 2026) == false)

        let archive = try engine.archiveYear(workspaceURL: fx.root, year: 2026)
        #expect(archive.taxYear == 2026)
        #expect(engine.isYearClosed(workspaceURL: fx.root, year: 2026) == true)
        #expect(FileManager.default.fileExists(
            atPath: fx.root.appendingPathComponent("Taxes/archive/2026-tax-adjustments.csv").path))

        // A closed year is read-only — a second close throws.
        #expect(throws: TaxPrepEngine.ArchiveError.alreadyClosed(2026)) {
            _ = try engine.archiveYear(workspaceURL: fx.root, year: 2026)
        }
    }
}
