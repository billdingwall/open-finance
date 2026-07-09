import Testing
import Foundation
@testable import FinanceWorkspaceKit

// 008 US4 T034/T007 — the performance measurement harness (SC-002/003, clarify: cold-launch →
// first projection ≤ 2s; full re-index of the realistic 12-month fixture ≤ 5s, Apple Silicon).
// Measures the Kit pipeline that `ProjectionStore.buildSync` runs (parse → every engine →
// dashboard); the App layer adds only snapshot assembly + one main-actor assignment on top.
// Budgets are asserted so a perf regression fails CI, not just a dashboard.

@Suite struct PerformanceHarness {

    /// The realistic dataset from the spec: 12 months × ~120 ledger rows across checking,
    /// savings, business, and investment accounts (income, spend, goal deposits, trades).
    private func twelveMonthWorkspace() -> FixtureWorkspace {
        let fixture = FixtureWorkspace.full(month: "2026-01")
        for monthIndex in 1...12 {
            let month = String(format: "2026-%02d", monthIndex)
            var rows: [String] = []
            rows.append("P\(monthIndex)-1,A1,\(month)-01,5000,Salary,standard,,,PG\(monthIndex),gross,,,,,,")
            rows.append("P\(monthIndex)-2,A1,\(month)-01,-1000,Federal tax,standard,,,PG\(monthIndex),withholding,,,,,,")
            rows.append("P\(monthIndex)-3,A1,\(month)-01,4000,Net pay,standard,,,PG\(monthIndex),net,,,,,,")
            for day in 1...28 {
                let date = String(format: "%@-%02d", month, day)
                rows.append("S\(monthIndex)-\(day)a,A1,\(date),-42.50,Groceries,standard,CAT1,,,,,,,,,")
                rows.append("S\(monthIndex)-\(day)b,A1,\(date),-18.25,Dining,standard,CAT1,,,,,,,,,")
                rows.append("B\(monthIndex)-\(day),B1,\(date),150,Revenue,standard,,,,,,,,,,")
                rows.append("G\(monthIndex)-\(day),A2,\(date),25,Goal deposit,standard,,SG1,,,,,,,,")
            }
            rows.append("T\(monthIndex),I1,\(month)-15,-1000,Buy VTI,trade,,,,,,AS1,,buy,10,100")
            fixture.write("Accounts/transactions/\(month).csv", FixtureWorkspace.fullTxHeader, rows)
        }
        // A year of benchmark closes so the heat map has real windows to compute.
        let closes = (1...12).map { String(format: "2026-%02d-01,%d", $0, 4900 + $0 * 20) }
        fixture.write("Investments/benchmarks/sp500.csv", FixtureWorkspace.benchmarkHeader, closes)
        return fixture
    }

    /// The full read pipeline `ProjectionStore.buildSync` executes (kept in lockstep with it).
    private func runPipeline(_ workspaceURL: URL) throws {
        let context = try WorkspaceParser().parse(workspaceURL: workspaceURL)
        let settings = (try? SettingsStore().read(workspaceURL: workspaceURL)) ?? .defaults()
        let asOf = Date()
        let accounts = AccountEngine().overview(context, asOf: asOf, settings: settings)
        _ = SavingsGoalEngine().projectGoals(context, asOf: asOf)
        let holdings = PortfolioEngine().holdings(context, asOf: asOf, scope: .aggregate)
        _ = BenchmarkEngine().heatMap(context, asOf: asOf)
        _ = TaxEngine().project(context, taxYear: settings.taxYear)
        _ = TaxAdjustmentEngine().deductionSummary(context, settings: settings)
        let estimate = TaxAdjustmentEngine().taxEstimate(context, settings: settings)
        _ = TaxPrepEngine().prepSummary(context, settings: settings)
        _ = OverviewEngine().dashboard(context, asOf: asOf, settings: settings,
                                       accounts: accounts, aggregateHoldings: holdings,
                                       taxEstimate: estimate)
    }

    @Test func coldLaunchToFirstProjectionWithinTwoSeconds() throws {
        let fixture = twelveMonthWorkspace()
        defer { fixture.cleanup() }
        let clock = ContinuousClock()
        let elapsed = try clock.measure { try runPipeline(fixture.root) }
        #expect(elapsed < .seconds(2), "cold pipeline took \(elapsed) (budget 2s, SC-002)")
    }

    @Test func fullReindexWithinFiveSeconds() throws {
        let fixture = twelveMonthWorkspace()
        defer { fixture.cleanup() }
        try runPipeline(fixture.root)                  // warm (cold launch already measured above)
        let clock = ContinuousClock()
        let elapsed = try clock.measure { try runPipeline(fixture.root) }
        #expect(elapsed < .seconds(5), "re-index pipeline took \(elapsed) (budget 5s, SC-003)")
    }
}
