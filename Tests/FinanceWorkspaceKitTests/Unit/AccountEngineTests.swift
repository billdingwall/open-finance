import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T018 — AccountEngine projections against fixtures. Verifies SC-002 (balance reconcile),
// SC-003 (YTD + transfers neutral), SC-008 (multi-employment), SC-010 (retained-equity split),
// and FR-006 (rule projection for an empty current month).

@Suite struct AccountEngineTests {
    private let asOf = ISO8601DateFormatter().date(from: "2026-06-30T00:00:00Z")!
    private let settings = WorkspaceSettings(filingStatus: .single, taxYear: 2026,
                                             defaultCurrency: "USD", timezone: "UTC")

    private func businessAndPaychecks() -> FixtureWorkspace {
        let fx = FixtureWorkspace()
        fx.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, [
            "grp-biz,Consulting,business",
            "grp-job1,Job One,employment",
            "grp-job2,Job Two,employment",
            "grp-personal,Personal,personal",
        ])
        fx.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader, [
            "biz-bank,Biz Checking,,business,llc,active,grp-biz",
            "emp1,Employer One,,employment,w2,active,grp-job1",
            "emp2,Employer Two,,employment,1099,active,grp-job2",
            "chk,Everyday,,checking,personal,active,grp-personal",
        ])
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("b1", "biz-bank", "2026-06-10", "10000.00", category: "cat-business-income"),
            // Two paychecks, one per employment account, both landing in those employment accounts.
            FixtureWorkspace.tx("j1g", "emp1", "2026-06-15", "5000.00", group: "g1", role: "gross"),
            FixtureWorkspace.tx("j1w", "emp1", "2026-06-15", "-1000.00", group: "g1", role: "withholding"),
            FixtureWorkspace.tx("j1n", "emp1", "2026-06-15", "4000.00", group: "g1", role: "net"),
            FixtureWorkspace.tx("j2g", "emp2", "2026-06-20", "3000.00", group: "g2", role: "gross"),
            FixtureWorkspace.tx("j2w", "emp2", "2026-06-20", "-600.00", group: "g2", role: "withholding"),
            FixtureWorkspace.tx("j2n", "emp2", "2026-06-20", "2400.00", group: "g2", role: "net"),
            // An internal transfer between personal and business — must be income/expense neutral.
            FixtureWorkspace.tx("t1", "chk", "2026-06-25", "-500.00", type: "transfer", group: "tr", role: "debit"),
            FixtureWorkspace.tx("t2", "biz-bank", "2026-06-25", "500.00", type: "transfer", group: "tr", role: "credit"),
        ])
        return fx
    }

    @Test func ytdNetIncomeWithholdingAndTransfersNeutral() throws {
        let fx = businessAndPaychecks(); defer { fx.cleanup() }
        let overview = try AccountEngine().overview(fx.parse(), asOf: asOf, settings: settings)

        let biz = try #require(overview.accounts.first { $0.accountId == "biz-bank" })
        #expect(biz.ytdNetIncome == Decimal(string: "10000.00"))   // transfer in (+500) is neutral

        // Employment accounts: gross − withholding (net legs excluded, no double count) — SC-003.
        let emp1 = try #require(overview.accounts.first { $0.accountId == "emp1" })
        #expect(emp1.ytdNetIncome == Decimal(string: "4000.00"))   // 5000 − 1000
        let emp2 = try #require(overview.accounts.first { $0.accountId == "emp2" })
        #expect(emp2.ytdNetIncome == Decimal(string: "2400.00"))   // 3000 − 600
    }

    @Test func retainedEquitySplitReconciles() throws {  // SC-010
        let fx = businessAndPaychecks(); defer { fx.cleanup() }
        let overview = try AccountEngine().overview(fx.parse(), asOf: asOf, settings: settings)
        #expect(overview.totalYTDRetainedEquity == Decimal(string: "10000.00"))   // business income retained
        #expect(overview.totalYTDPersonalInflow == Decimal(string: "8000.00"))    // 5000 + 3000 employment gross
        // personal inflow + retained == total non-transfer gross income
        #expect(overview.totalYTDPersonalInflow + overview.totalYTDRetainedEquity == Decimal(string: "18000.00"))
    }

    @Test func multipleEmploymentGroupsAggregate() throws {  // SC-008
        let fx = businessAndPaychecks(); defer { fx.cleanup() }
        let overview = try AccountEngine().overview(fx.parse(), asOf: asOf, settings: settings)
        let employmentNet = overview.groups
            .filter { $0.groupType == .employment }
            .reduce(Decimal(0)) { $0 + $1.ytdNetIncome }
        #expect(overview.groups.filter { $0.groupType == .employment }.count == 2)
        #expect(employmentNet == Decimal(string: "6400.00"))   // 4000 + 2400, no collision
    }

    @Test func balanceReconcilesToLedger() throws {  // SC-002
        let fx = businessAndPaychecks(); defer { fx.cleanup() }
        let overview = try AccountEngine().overview(fx.parse(), asOf: asOf, settings: settings)
        // Everyday only saw the −500 transfer leg.
        let chk = try #require(overview.accounts.first { $0.accountId == "chk" })
        #expect(chk.currentBalance == Decimal(string: "-500.00"))
        // emp1 cash = net leg only (gross/withholding excluded): +4000.
        let emp1 = try #require(overview.accounts.first { $0.accountId == "emp1" })
        #expect(emp1.currentBalance == Decimal(string: "4000.00"))
        // biz = 10000 income + 500 transfer in.
        let biz = try #require(overview.accounts.first { $0.accountId == "biz-bank" })
        #expect(biz.currentBalance == Decimal(string: "10500.00"))
    }

    @Test func emptyCurrentMonthUsesRuleProjection() throws {  // FR-006
        let fx = FixtureWorkspace(); defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, ["grp-personal,Personal,personal"])
        fx.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader,
                 ["chk,Everyday,,checking,personal,active,grp-personal"])
        fx.write("Accounts/account-rules.csv", "rule_id,account_id,rule_type,amount,frequency,is_active",
                 ["r1,chk,income_estimate,3000.00,monthly,true"])
        // no transactions at all → as-of month is empty
        let overview = try AccountEngine().overview(fx.parse(), asOf: asOf, settings: settings)
        let chk = try #require(overview.accounts.first { $0.accountId == "chk" })
        #expect(chk.isProjected)
        #expect(chk.monthlyInflow == Decimal(string: "3000.00"))
    }
}
