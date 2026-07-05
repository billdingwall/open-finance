import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T056 — Taxes mapping: both deduction totals surfaced (never auto-committed), Schedule C →
// business-group links, checklist state mapping with source links, and closed-year read-only
// archive discovery.

@Suite struct TaxesViewModelTests {

    private func makeViewModel() throws -> (TaxesViewModel, AppFixture) {
        let fixture = AppFixture.standard()
        fixture.write("Taxes/tax-adjustments.csv",
                      "tax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id",
                      ["ADJ1,standard,15000,2026,confirmed,",
                       "ADJ2,schedule_a,4000,2026,estimated,",
                       "ADJ3,schedule_c,1200,2026,estimated,G2"])
        fixture.write("Taxes/estimated-payments.csv", "payment_id,tax_year,quarter,amount,paid",
                      ["EP1,2026,1,500,true", "EP2,2026,2,500,false"])
        fixture.write("Taxes/archive/2024-tax-adjustments.csv",
                      "tax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id",
                      ["OLD1,standard,13850,2024,confirmed,"])
        let snapshot = try ProjectionStore.buildSync(
            workspaceURL: fixture.root, asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)
        return (TaxesViewModel(projections: snapshot), fixture)
    }

    @Test func bothDeductionTotalsSurfaceWithRecommendationFlag() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let summary = viewModel.deductions(year: viewModel.defaultYear)

        // Both totals present for display; the flag is the engine's, display-only (FR-028).
        #expect(summary.standardTotal > 0)
        #expect(summary.itemizedTotal > 0)
        #expect(summary.recommended == (summary.standardTotal >= summary.itemizedTotal
                                            ? .standard : .itemized))
    }

    @Test func scheduleCLinksResolveToBusinessGroups() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let links = viewModel.scheduleCLinks(year: viewModel.defaultYear)
        #expect(links.contains { $0.accountGroupId == "G2" && $0.amount == 1200 })
        // The reconciliation rows expose divergence against the ledger.
        let summary = viewModel.deductions(year: viewModel.defaultYear)
        #expect(summary.businessExpenseByGroup.contains { $0.accountGroupId == "G2" })
    }

    @Test func paymentsCarryPaidDueStatus() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let payments = viewModel.paymentRows(year: viewModel.defaultYear)
        #expect(payments.map(\.quarter) == [1, 2])
        #expect(payments[0].paid == true)
        #expect(payments[1].paid == false)
    }

    @Test func checklistItemsCarryStateSourceAndEducation() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let items = viewModel.checklist(year: viewModel.defaultYear)
        #expect(items.count == 4)                                  // fixed v1 set
        #expect(items.allSatisfy { !$0.sourcePath.isEmpty && !$0.education.isEmpty })
    }

    @Test func archiveIsDiscoveredReadOnly() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        #expect(viewModel.closedYears == [2024])
        let files = viewModel.archiveFiles(year: 2024)
        #expect(files.count == 1)
        #expect(files.first?.contents.contains("OLD1") == true)   // raw preview, not re-derived
    }

    @Test func sessionYearRerunsEnginesOverTheSameContext() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let current = viewModel.taxProjection(year: 2026)
        let closed = viewModel.taxProjection(year: 2024)

        #expect(current.taxYear == 2026)
        #expect(closed.taxYear == 2024)
        #expect(closed.accounts.isEmpty)                           // no 2024 activity in fixture
    }
}
