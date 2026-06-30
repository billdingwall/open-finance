import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T034 — OverviewEngine + LinkingEngine: stub-card contract (SC-005), gap-skipping MoM panel
// (SC-006), issue aggregation (FR-019), and goal links (FR-015).

@Suite struct OverviewEngineTests {
    private let asOf = ISO8601DateFormatter().date(from: "2026-06-30T00:00:00Z")!
    private let settings = WorkspaceSettings(filingStatus: .single, taxYear: 2026,
                                             defaultCurrency: "USD", timezone: "UTC")

    private func gapMonthFixture() -> FixtureWorkspace {
        let fx = FixtureWorkspace()
        fx.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, [
            "grp-personal,Personal,personal", "grp-biz,Biz,business",
        ])
        fx.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader, [
            "chk,Everyday,,checking,personal,active,grp-personal",
            "sav,Savings,,savings,hysa,active,grp-personal",
            "biz,Biz,,business,llc,active,grp-biz",
        ])
        fx.write("Budget/budgets.csv", "budget_id,name,account_group_ids,account_ids",
                 ["bud,Household,grp-personal,"])
        fx.write("Budget/categories.csv",
                 "category_id,name,parent_category_id,category_group_id,default_budget_behavior,tax_relevant",
                 ["cat-salary,Salary,,grp-income,fixed,true", "cat-housing,Housing,,grp-essentials,fixed,false"])
        // April present, May MISSING (gap), June present.
        fx.write("Accounts/transactions/2026-04.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("a1", "chk", "2026-04-01", "4000.00", category: "cat-salary"),
            FixtureWorkspace.tx("a2", "chk", "2026-04-05", "-1000.00", category: "cat-housing"),
        ])
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("j1", "chk", "2026-06-01", "5000.00", category: "cat-salary"),
            FixtureWorkspace.tx("j2", "chk", "2026-06-03", "-1500.00", category: "cat-housing"),
            FixtureWorkspace.tx("s1", "sav", "2026-06-10", "500.00", goal: "goal-ef"),
            FixtureWorkspace.tx("b1", "biz", "2026-06-12", "2000.00"),
        ])
        return fx
    }

    @Test func stubCardsAreDataNotAvailable() throws {  // SC-005
        let fx = gapMonthFixture(); defer { fx.cleanup() }
        let dash = try OverviewEngine().dashboard(fx.parse(), asOf: asOf, settings: settings)
        #expect(dash.cards.count == 5)
        let investments = try #require(dash.cards.first { $0.kind == "investments" })
        let taxes = try #require(dash.cards.first { $0.kind == "taxes" })
        #expect(investments.state == .dataNotAvailable)
        #expect(investments.value == nil)
        #expect(taxes.state == .dataNotAvailable)
        // The three live cards carry values.
        #expect(dash.cards.first { $0.kind == "budget" }?.state == .available)
        #expect(dash.cards.first { $0.kind == "savings" }?.state == .available)
        #expect(dash.cards.first { $0.kind == "business" }?.value == Decimal(string: "2000.00"))
    }

    @Test func monthOverMonthSkipsGapMonths() throws {  // SC-006
        let fx = gapMonthFixture(); defer { fx.cleanup() }
        let dash = try OverviewEngine().dashboard(fx.parse(), asOf: asOf, settings: settings)
        let periods = dash.monthOverMonth.map(\.period)
        #expect(periods == ["2026-04", "2026-06"])   // May omitted, not zero-filled
        #expect(dash.monthOverMonth.first { $0.period == "2026-06" }?.netIncome == Decimal(string: "6000.00"))
    }

    @Test func goalLinksFromLedger() throws {  // FR-015
        let fx = gapMonthFixture(); defer { fx.cleanup() }
        let links = try LinkingEngine().goalLinks(in: fx.parse())
        #expect(links.contains { $0.goalId == "goal-ef" && $0.transactionId == "s1" })
    }
}
