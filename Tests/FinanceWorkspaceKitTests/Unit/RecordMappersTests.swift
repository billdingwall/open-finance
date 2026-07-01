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

    // MARK: Phase 4 mappers

    @Test func mapsInvestmentEntities() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Investments/assets.csv", FixtureWorkspace.assetHeader, [
            "as-1,VTI,Total Market,ETF,acc-investment,USD",
            ",no-id,name,ETF,acc-investment,USD",                  // invalid: missing asset_id → nil
        ])
        fx.write("Investments/prices.csv", FixtureWorkspace.priceHeader, [
            "p1,as-1,2026-06-01,250.00", "p2,as-1,2026-06-15,260.00"])
        fx.write("Investments/dividends.csv", FixtureWorkspace.dividendHeader, ["d1,as-1,2026-06-10,12.50"])
        fx.write("Investments/portfolios.csv", FixtureWorkspace.portfolioHeader, [
            "pf-1,Core,acc-investment,0.07"])
        fx.write("Investments/sleeves.csv", FixtureWorkspace.sleeveHeader, ["sl-1,pf-1,Equity"])
        fx.write("Investments/sleeve-targets.csv", FixtureWorkspace.sleeveTargetHeader, ["t1,sl-1,0.60"])
        fx.write("Investments/benchmarks/sp500.csv", FixtureWorkspace.benchmarkHeader, [
            "2026-06-01,5000.00", "2026-06-15,5100.00"])
        let ctx = try fx.parse()

        #expect(ctx.assets.count == 1)                             // invalid row dropped
        #expect(ctx.assets.first?.ticker == "VTI")
        #expect(ctx.pricesByAsset["as-1"]?.count == 2)
        #expect(ctx.dividends.first?.amount == Decimal(string: "12.50"))
        #expect(ctx.portfolios.first?.expectedReturnRate == Decimal(string: "0.07"))   // optional column read
        #expect(ctx.sleeveTargets.first?.targetWeight == Decimal(string: "0.60"))
        #expect(ctx.benchmarkSeries.count == 2 && ctx.benchmarkSeries.first!.date < ctx.benchmarkSeries.last!.date)
    }

    @Test func mapsTradesFromLedgerWithSideResolvedAsset() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("tr1", "acc-investment", "2026-06-02", "-2500.00", asset: "as-1", side: "buy", qty: "10", price: "250"),
            FixtureWorkspace.trade("tr2", "acc-investment", "2026-06-20", "1300.00", asset: "as-1", side: "sell", qty: "5", price: "260"),
        ])
        let ctx = try fx.parse()
        #expect(ctx.trades.count == 2)
        let buy = try #require(ctx.trades.first)
        #expect(buy.tradeType == .buy && buy.assetId == "as-1" && buy.quantity == 10)
        #expect(ctx.trades.last?.tradeType == .sell)
    }

    @Test func mapsTaxAndSavingsProgressEntities() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Savings/goals.csv", FixtureWorkspace.goalHeader, [
            "g1,Emergency,10000,,500,acc-savings,active,"])
        fx.write("Savings/progress.csv", FixtureWorkspace.progressHeader, [
            "pr1,g1,2026-05-31,3000", "pr2,g1,2026-06-30,3500"])
        fx.write("Taxes/tax-adjustments.csv", FixtureWorkspace.taxAdjHeader, [
            "adj-standard,standard,15750.00,2026,estimated,"])
        fx.write("Taxes/estimates.csv", FixtureWorkspace.taxEstimateHeader, ["e1,2026,90000,12000,"])
        fx.write("Taxes/documents.csv", FixtureWorkspace.taxDocHeader, ["doc1,2026,W-2,Employer,"])
        fx.write("Taxes/estimated-payments.csv", FixtureWorkspace.estPaymentHeader, ["pay1,2026,2,3000,true"])
        let ctx = try fx.parse()

        #expect(ctx.latestProgressByGoal["g1"]?.balance == 3500)   // latest snapshot wins
        #expect(ctx.taxAdjustments.first?.adjustmentType == .standard)
        #expect(ctx.taxEstimates.first?.grossIncome == 90000)
        #expect(ctx.taxEstimates.first?.estimatedReturn == nil)     // blank optional → nil
        #expect(ctx.taxDocuments.first?.kind == "W-2")
        #expect(ctx.estimatedPayments.first?.paid == true)
    }
}
