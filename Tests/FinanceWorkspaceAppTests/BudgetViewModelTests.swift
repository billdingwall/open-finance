import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T044 — Budget mapping: period-driven engine re-run, trailing-average passthrough (incl.
// the partial label), and the category drill-down filter.

@Suite struct BudgetViewModelTests {

    private func makeViewModel() throws -> (BudgetViewModel, AppFixture) {
        let fixture = AppFixture.standard()
        // A second month so period switching has something to find.
        fixture.write("Accounts/transactions/2026-05.csv",
                      "transaction_id,account_id,date,amount,type,category_id,savings_goal_id,group_id,group_role,liability_id",
                      ["T7,A1,2026-05-05,-180,standard,C1,,,,"])
        fixture.write("Budget/budget-allocations.csv",
                      "allocation_id,budget_id,category_id,period,planned_amount",
                      ["AL1,BUD1,C1,2026-06,250", "AL2,BUD1,C1,2026-05,250"])
        let snapshot = try ProjectionStore.buildSync(
            workspaceURL: fixture.root, asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)
        return (BudgetViewModel(projections: snapshot), fixture)
    }

    @Test func periodSwitchRecomputesThroughTheEngine() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let june = viewModel.overview(period: nil)          // current month
        let may = viewModel.overview(period: "2026-05")

        #expect(june?.period == "2026-06")
        #expect(may?.period == "2026-05")
        // Values are the engine's, per period (T4 = −200 in June; T7 = −180 in May).
        #expect(june?.rows.first?.actual == 200)
        #expect(may?.rows.first?.actual == 180)
    }

    @Test func trailingAveragePassesThroughWithPartialLabel() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let projection = try #require(viewModel.overview(period: nil))
        let row = try #require(projection.rows.first)

        // One prior populated month → partial average, surfaced via the engine's own label.
        #expect(row.trailingAverage.isPartial)
        let cells = viewModel.tableRows(projection).first?.cells
        #expect(cells?.last?.style == .muted)               // partial renders muted, never blank
    }

    @Test func drillDownFiltersByCategoryAndPeriod() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let june = viewModel.drillDownEntries(categoryId: "C1", period: nil)
        let may = viewModel.drillDownEntries(categoryId: "C1", period: "2026-05")

        #expect(june.count == 1)
        #expect(june.first?.single?.transactionId == "T4")
        #expect(may.first?.single?.transactionId == "T7")
        // Rows stay traceable (P-V).
        #expect(june.first?.single?.sourceRef != nil)
    }

    @Test func historySkipsMonthsWithoutAllocations() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let history = viewModel.history(months: 6)
        #expect(history.map(\.period) == ["2026-05", "2026-06"])   // only allocated months
    }
}
