import Testing
import Foundation
@testable import FinanceWorkspaceKit

// US2 (T022) — TaxEngine: per-account taxable income / taxes paid / effective rate, dividend
// aggregation, and FIFO realized gain/loss split short-/long-term (SC-005).

@Suite struct TaxEngineTests {

    private func parse() throws -> WorkspaceContext {
        let fx = FixtureWorkspace()
        // Paycheck group: gross +5000 (income) / withholding -1000 (taxes) / net -4000 (balancing).
        fx.write("Accounts/transactions/2026-03.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("pay1", "acc-personal-bank", "2026-03-15", "5000", type: "standard", category: "cat-salary", group: "gp1", role: "gross"),
            FixtureWorkspace.tx("wh1", "acc-personal-bank", "2026-03-15", "-1000", type: "standard", group: "gp1", role: "withholding"),
            FixtureWorkspace.tx("net1", "acc-personal-bank", "2026-03-15", "-4000", type: "standard", group: "gp1", role: "net")])
        // Long-term sale: buy 10@200 in 2025, sell 5@260 in 2026 (held > 1yr).
        fx.write("Accounts/transactions/2025-01.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("b1", "acc-investment", "2025-01-10", "-2000", asset: "as-1", side: "buy", qty: "10", price: "200")])
        // Short-term sale: buy 10@50 and sell 4@60 both in 2026 (held < 1yr).
        fx.write("Accounts/transactions/2026-01.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("b2", "acc-investment", "2026-01-05", "-500", asset: "as-2", side: "buy", qty: "10", price: "50")])
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("s1", "acc-investment", "2026-06-20", "1300", asset: "as-1", side: "sell", qty: "5", price: "260"),
            FixtureWorkspace.trade("s2", "acc-investment", "2026-06-10", "240", asset: "as-2", side: "sell", qty: "4", price: "60")])
        fx.write("Investments/assets.csv", FixtureWorkspace.assetHeader, [
            "as-1,VTI,Total Market,etf,acc-investment,,USD", "as-2,BND,Bond,etf,acc-investment,,USD"])
        fx.write("Investments/dividends.csv", FixtureWorkspace.dividendHeader, ["d1,as-1,2026-06-10,25.00"])
        let ctx = try fx.parse(); fx.cleanup(); return ctx
    }

    @Test func perAccountIncomeTaxesRateAndDividends() throws {
        let p = TaxEngine().project(try parse(), taxYear: 2026)
        let byId = Dictionary(p.accounts.map { ($0.accountId, $0) }, uniquingKeysWith: { a, _ in a })
        let bank = try #require(byId["acc-personal-bank"])
        #expect(bank.ytdTaxableIncome == Decimal(5000))       // gross only; net/withholding excluded
        #expect(bank.taxesPaid == Decimal(1000))              // withholding leg
        #expect(bank.effectiveRate == Decimal(string: "0.2"))
        #expect(byId["acc-investment"]?.dividendIncome == Decimal(25))
    }

    @Test func realizedGainsSplitShortAndLongTerm() throws {
        let summary = TaxEngine().realizedGains(try parse(), taxYear: 2026)
        // LT: 5×(260−200)=300; ST: 4×(60−50)=40.
        #expect(summary.longTermGainLoss == Decimal(300))
        #expect(summary.shortTermGainLoss == Decimal(40))
        #expect(summary.total == Decimal(340))
        #expect(summary.lots.count == 2)
    }
}
