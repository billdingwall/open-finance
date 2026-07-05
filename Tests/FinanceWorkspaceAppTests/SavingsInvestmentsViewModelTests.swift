import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T049 — S&I mapping: typed price/history states, heat-map passthrough, sleeve drift, and
// goal funding-link resolution to traceable rows.

@Suite struct SavingsInvestmentsViewModelTests {

    /// Standard fixture + a buy trade, a priced + an unpriced asset, sleeves/targets, a short
    /// S&P series, and a goal progress snapshot.
    private func makeViewModel() throws -> (SavingsInvestmentsViewModel, AppFixture) {
        let fixture = AppFixture.standard()
        fixture.write("Investments/assets.csv",
                      "asset_id,ticker,name,security_class,account_id,sleeve_id,currency",
                      ["AS1,VTI,Total Market,etf,B1,SL1,USD",
                       "AS2,MYST,Mystery Fund,etf,B1,SL1,USD"])       // no price row → typed state
        fixture.write("Accounts/transactions/2026-04.csv",
                      "transaction_id,account_id,date,amount,type,category_id,savings_goal_id,"
                          + "group_id,group_role,liability_id,sending_asset_id,receiving_asset_id,"
                          + "trade_type,quantity,price",
                      ["TR1,B1,2026-04-10,-900,trade,,,,,,,AS1,buy,10,90",
                       "TR2,B1,2026-04-11,-500,trade,,,,,,,AS2,buy,5,100"])
        fixture.write("Investments/portfolios.csv", "portfolio_id,name,account_id,expected_return_rate",
                      ["PF1,Core,B1,"])
        fixture.write("Investments/sleeves.csv", "sleeve_id,portfolio_id,name", ["SL1,PF1,Equities"])
        fixture.write("Investments/sleeve-targets.csv", "target_id,sleeve_id,target_weight",
                      ["ST1,SL1,0.8"])
        fixture.write("Investments/benchmarks/sp500.csv", "date,close",
                      ["2026-06-26,5000", "2026-06-29,5050"])
        fixture.write("Savings/progress.csv", "progress_id,goal_id,as_of,balance",
                      ["PR1,SG1,2026-06-15,2500"])
        let snapshot = try ProjectionStore.buildSync(
            workspaceURL: fixture.root, asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)
        return (SavingsInvestmentsViewModel(projections: snapshot), fixture)
    }

    @Test func unpricedAssetRendersTypedStateNeverZero() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let rows = viewModel.holdingsRows(viewModel.holdings(accountId: nil))
        let mystery = try #require(rows.first { $0.id == "AS2" })

        #expect(mystery.cells[3].text == TypedStateText.priceUnavailable)
        #expect(mystery.cells[4].text == TypedStateText.priceUnavailable)
        // The priced asset carries a real value.
        let priced = try #require(rows.first { $0.id == "AS1" })
        #expect(priced.cells[3].text != TypedStateText.priceUnavailable)
    }

    @Test func heatMapPassesThroughWithInsufficientHistoryCells() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let model = viewModel.heatMapModel
        #expect(model.rows.first?.isBenchmark == true)             // S&P row first, separated
        #expect(model.windows.count == 8)
        // A 2-point series cannot resolve the long windows → typed nil cells, never zeros.
        let benchmarkCells = try #require(model.rows.first?.cells)
        #expect(benchmarkCells.contains { $0.growth == nil })
    }

    @Test func sleeveDriftPassesThrough() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let holdings = viewModel.holdings(accountId: nil)
        let sleeve = try #require(holdings.sleeveAllocations.first)

        #expect(sleeve.targetWeight == 0.8)
        #expect(sleeve.drift == sleeve.actualWeight - 0.8)         // engine's drift, untouched
        #expect(viewModel.sleeveRows(holdings).first?.cells.count == 5)
    }

    @Test func goalFundingLinksResolveToTraceableRows() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let goal = try #require(viewModel.goal("SG1"))
        let funding = viewModel.fundingTransactions(goal)

        #expect(funding.contains { $0.transactionId == "T5" })     // the goal-tagged row
        #expect(funding.allSatisfy { $0.sourceRef != nil })        // P-V
        // Snapshot anchors the balance (clarify: snapshot wins).
        #expect(goal.currentBalance == 2500)
        #expect(goal.balanceSource == .snapshot)
    }

    @Test func holdingDetailResolvesFIFOLotsAndProvenance() throws {
        let (viewModel, fixture) = try makeViewModel()
        defer { fixture.cleanup() }

        let detail = try #require(viewModel.holdingDetail("AS1"))
        #expect(detail.openLots.count == 1)
        #expect(detail.openLots.first?.costBasis == 900)
        #expect(viewModel.tradeSourceRef(tradeId: "TR1") != nil)   // ledger provenance
    }
}
