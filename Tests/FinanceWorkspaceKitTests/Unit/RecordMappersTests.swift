import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T009 — the ParsedRecord → typed-entity mapping seam: typed reads, nil-on-invalid-required,
// optional→nil, provenance carried.

@Suite struct RecordMappersTests {

    @Test func mapsAccountsAndGroupsFromParsedWorkspace() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader, [
            "acc-1,Checking,Bank,checking,personal,active,grp-personal",
            "acc-bad,Missing Group,,checking,personal,active,grp-personal",  // valid
            ",No ID,,checking,personal,active,grp-personal",                  // invalid: missing account_id
        ])
        fx.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, [
            "grp-personal,Personal,personal",
        ])
        let ctx = try fx.parse()

        // The row with a missing required account_id maps to nil (skipped); valid rows map.
        let accounts = ctx.accounts
        #expect(accounts.count == 2)
        #expect(accounts.contains { $0.accountId == "acc-1" && $0.accountGroup == .checking })
        #expect(ctx.accountGroups.first?.groupType == .personal)
    }

    @Test func mapsTransactionWithProvenanceAndOptionalNils() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/transactions/2026-05.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("t1", "acc-1", "2026-05-03", "1000.00", type: "standard", category: "cat-salary"),
        ])
        let ctx = try fx.parse()
        let tx = try #require(ctx.transactions.first)
        #expect(tx.amount == Decimal(string: "1000.00"))
        #expect(tx.type == .standard)
        #expect(tx.categoryId == "cat-salary")
        #expect(tx.savingsGoalId == nil)               // blank optional → nil
        #expect(tx.sourceFile?.isEmpty == false)        // provenance carried
        #expect((tx.sourceRow ?? 0) >= 1)
    }

    @Test func mapsAccountRuleWithFrequencyAndProjection() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-rules.csv",
                 "rule_id,account_id,rule_type,amount,frequency,is_active",
                 ["r1,acc-1,income_estimate,1300.00,biweekly,true"])
        let ctx = try fx.parse()
        let rule = try #require(ctx.accountRules.first)
        #expect(rule.ruleType == .incomeEstimate)
        #expect(rule.frequency == .biweekly)
        // 1300 * 26/12 ≈ 2816.67 monthly-equivalent, positive (income).
        let monthly = try #require(rule.monthlyProjection)
        #expect(monthly > Decimal(2816) && monthly < Decimal(2817))
    }
}
