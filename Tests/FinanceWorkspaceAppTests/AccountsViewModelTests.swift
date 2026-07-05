import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T038 — Accounts mapping: engine figures pass through (no view-side computation beyond the
// labeled derived net-worth split), multi-entry ledger grouping (D7), and the business P&L
// section gate on `group_type`.

@Suite struct AccountsViewModelTests {

    private func makeViewModel() throws -> (AccountsViewModel, AppFixture) {
        let fixture = AppFixture.standard()
        let snapshot = try ProjectionStore.buildSync(
            workspaceURL: fixture.root, asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)
        return (AccountsViewModel(projections: snapshot), fixture)
    }

    @Test func headerTotalsPassThroughFromEngine() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        // Totals equal the engine's overview totals exactly (FR-031 — no recomputation).
        #expect(viewModel.header.monthlyInflow == viewModel.overview.totalMonthlyInflow)
        #expect(viewModel.header.ytdNetIncome == viewModel.overview.totalYTDNetIncome)
        #expect(viewModel.header.retainedEquity == viewModel.overview.totalYTDRetainedEquity)
        // Net worth is the sign-split of engine balances — assets + liabilities re-sum to it.
        #expect(viewModel.header.netWorth == viewModel.header.assets + viewModel.header.liabilities)
    }

    @Test func multiEntryPaycheckGroupsIntoOneEntry() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        guard let detail = viewModel.accountDetail("A1") else {
            Issue.record("account A1 missing"); return
        }
        let entries = viewModel.accountLedger(detail)
        let group = entries.first { $0.isGroup }

        #expect(group != nil)                          // GRP1 paycheck folded (FR-020)
        #expect(group?.legs.count == 3)                // gross / withholding / net
        #expect(group?.netAmount == 4000)              // the net leg, not the sum
        // Every leg stays individually traceable (P-V).
        #expect(group?.legs.allSatisfy { $0.sourceRef != nil } == true)
    }

    @Test func businessGroupCarriesPLSection() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let business = viewModel.groupProjection("G2")
        let personal = viewModel.groupProjection("G1")

        #expect(business?.groupType == .business)
        #expect(business?.businessPL != nil)           // P&L only for business groups (FR-018)
        #expect(personal?.businessPL == nil)
        #expect(viewModel.businessPLPoints(business!).isEmpty == false)
    }

    @Test func groupLedgerCoversOnlyGroupAccounts() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let entries = viewModel.groupLedger("G2")      // business group: only B1's row
        #expect(entries.count == 1)
        #expect(entries.first?.single?.accountId == "B1")
    }
}
