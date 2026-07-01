import Testing
import Foundation
@testable import FinanceWorkspaceKit

// US5 (T041) — SavingsGoalEngine: snapshot vs ledger balance, months-to-goal + "n/a",
// archived exclusion, derived-complete.

@Suite struct SavingsGoalEngineTests {

    private func asOf(_ s: String) -> Date {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)!
    }

    private func parse() throws -> WorkspaceContext {
        let fx = FixtureWorkspace()
        fx.write("Savings/goals.csv", FixtureWorkspace.goalHeader, [
            "g1,Emergency,10000,,500,acc-savings,active,",
            "g2,Vacation,3000,,,acc-savings,active,",
            "g4,Funded,1000,,,acc-savings,active,",
            "g3,Old,500,,,acc-savings,archived,"])
        fx.write("Savings/progress.csv", FixtureWorkspace.progressHeader, [
            "pr1,g1,2026-06-30,6000",
            "pr4,g4,2026-06-30,1200"])              // g4 balance ≥ target → complete
        // g2 has no snapshot → ledger-derived from tagged contributions (500/mo × 3 = 1500)
        fx.write("Accounts/transactions/2026-04.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("c1", "acc-savings", "2026-04-05", "500", type: "standard", category: "cat-goals", goal: "g2")])
        fx.write("Accounts/transactions/2026-05.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("c2", "acc-savings", "2026-05-05", "500", type: "standard", category: "cat-goals", goal: "g2")])
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("c3", "acc-savings", "2026-06-05", "500", type: "standard", category: "cat-goals", goal: "g2")])
        let ctx = try fx.parse(); fx.cleanup(); return ctx
    }

    @Test func snapshotAndLedgerBalancesWithMonthsToGoal() throws {
        let goals = SavingsGoalEngine().projectGoals(try parse(), asOf: asOf("2026-06-30"))
        let byId = Dictionary(goals.map { ($0.goalId, $0) }, uniquingKeysWith: { a, _ in a })

        let g1 = try #require(byId["g1"])
        #expect(g1.currentBalance == Decimal(6000) && g1.balanceSource == .snapshot)
        #expect(g1.gapToTarget == Decimal(4000))
        #expect(g1.monthsToGoal == nil)                       // no tagged contributions → rate 0 → n/a

        let g2 = try #require(byId["g2"])
        #expect(g2.currentBalance == Decimal(1500) && g2.balanceSource == .ledgerDerived)
        #expect(g2.trailingContributionRate.value == Decimal(500))
        #expect(g2.monthsToGoal == 3)                         // ceil(1500 / 500)
    }

    @Test func archivedExcludedAndCompleteDerived() throws {
        let goals = SavingsGoalEngine().projectGoals(try parse(), asOf: asOf("2026-06-30"))
        #expect(!goals.contains { $0.goalId == "g3" })        // archived excluded
        #expect(goals.first { $0.goalId == "g4" }?.isCompleteDerived == true)
    }
}
