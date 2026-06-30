import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T025 — BudgetEngine: variance, partial trailing average (SC-004), spend-mix, scope, goals.

@Suite struct BudgetEngineTests {
    private let asOf = ISO8601DateFormatter().date(from: "2026-06-30T00:00:00Z")!

    private func budgetFixture() -> FixtureWorkspace {
        let fx = FixtureWorkspace()
        fx.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, ["grp-personal,Personal,personal"])
        fx.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader,
                 ["chk,Everyday,,checking,personal,active,grp-personal"])
        fx.write("Budget/categories.csv",
                 "category_id,name,parent_category_id,category_group_id,default_budget_behavior,tax_relevant", [
            "cat-salary,Salary,,grp-income,fixed,true",
            "cat-housing,Housing,,grp-essentials,fixed,false",
            "cat-dining,Dining,,grp-lifestyle,discretionary,false",
            "cat-emergency,Emergency,,grp-savings,savings,false",
        ])
        fx.write("Budget/budgets.csv", "budget_id,name,account_group_ids,account_ids",
                 ["bud-house,Household,grp-personal,"])
        fx.write("Budget/budget-allocations.csv", "allocation_id,budget_id,category_id,planned_amount,period", [
            "a1,bud-house,cat-housing,1500.00,2026-06",
            "a2,bud-house,cat-dining,400.00,2026-06",
            "a3,bud-house,cat-emergency,500.00,2026-06",
        ])
        fx.write("Accounts/transactions/2026-04.csv", FixtureWorkspace.txHeader,
                 [FixtureWorkspace.tx("d-apr", "chk", "2026-04-05", "-300.00", category: "cat-dining")])
        fx.write("Accounts/transactions/2026-05.csv", FixtureWorkspace.txHeader,
                 [FixtureWorkspace.tx("d-may", "chk", "2026-05-05", "-500.00", category: "cat-dining")])
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("inc", "chk", "2026-06-01", "5000.00", category: "cat-salary"),
            FixtureWorkspace.tx("h", "chk", "2026-06-03", "-1600.00", category: "cat-housing"),
            FixtureWorkspace.tx("d", "chk", "2026-06-10", "-450.00", category: "cat-dining"),
            FixtureWorkspace.tx("e", "chk", "2026-06-15", "-500.00", category: "cat-emergency", goal: "goal-ef"),
        ])
        return fx
    }

    @Test func varianceAndPartialTrailingAverage() throws {  // SC-004
        let fx = budgetFixture(); defer { fx.cleanup() }
        let proj = try #require(BudgetEngine().overview(budgetId: "bud-house", period: "2026-06",
                                                        in: fx.parse(), asOf: asOf))
        let dining = try #require(proj.rows.first { $0.categoryId == "cat-dining" })
        #expect(dining.actual == Decimal(string: "450.00"))
        #expect(dining.variance == Decimal(string: "50.00"))            // 450 − 400
        // Apr (300) + May (500), Mar has no data → partial average of 2 months, never zero.
        #expect(dining.trailingAverage.monthsAvailable == 2)
        #expect(dining.trailingAverage.isPartial)
        #expect(dining.trailingAverage.value == Decimal(string: "400.00"))

        let housing = try #require(proj.rows.first { $0.categoryId == "cat-housing" })
        #expect(housing.trailingAverage.monthsAvailable == 0)
        #expect(housing.trailingAverage.value == nil)                   // no prior data → nil, not zero
    }

    @Test func totalsSpendMixAndGoalContributions() throws {
        let fx = budgetFixture(); defer { fx.cleanup() }
        let proj = try #require(BudgetEngine().overview(budgetId: "bud-house", period: "2026-06",
                                                        in: fx.parse(), asOf: asOf))
        #expect(proj.totals.income == Decimal(string: "5000.00"))
        #expect(proj.totals.fixed == Decimal(string: "1600.00"))
        #expect(proj.totals.netMonthlyIncome == Decimal(string: "2950.00"))   // 5000 − 1600 − 450
        // spend-mix is a percentage of net monthly income.
        #expect(proj.spendMix.savingsPct > 16 && proj.spendMix.savingsPct < 17)  // 500/2950 ≈ 16.9%
        // goal contribution surfaced as a first-class output.
        #expect(proj.goalContributions.contains { $0.goalId == "goal-ef" && $0.amount == Decimal(string: "500.00") })
    }
}
