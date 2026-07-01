import Testing
import Foundation
@testable import FinanceWorkspaceKit

// US1 (T017) — PortfolioEngine holdings: FIFO basis, valuation, price-unavailable, sleeve drift,
// dividends. SC-002 (positions reconcile) / SC-003 (drift; priced actual weights sum to 100%).

@Suite struct PortfolioEngineTests {

    private func asOf(_ s: String) -> Date {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)!
    }

    private func fixture() -> FixtureWorkspace {
        let fx = FixtureWorkspace()
        fx.write("Investments/assets.csv", FixtureWorkspace.assetHeader, [
            "as-1,VTI,Total Market,etf,acc-investment,sl-eq,USD",
            "as-2,BND,Total Bond,etf,acc-investment,sl-bond,USD",
            "as-3,XYZ,No Price,equity,acc-investment,sl-eq,USD"])
        fx.write("Investments/prices.csv", FixtureWorkspace.priceHeader, [
            "p1,as-1,2026-06-15,250.00", "p2,as-1,2026-06-29,260.00", "p3,as-2,2026-06-29,72.00"])
        fx.write("Investments/dividends.csv", FixtureWorkspace.dividendHeader, [
            "d1,as-1,2026-06-10,12.50", "d2,as-2,2026-06-12,5.00"])
        fx.write("Investments/sleeves.csv", FixtureWorkspace.sleeveHeader, ["sl-eq,pf-1,Equity", "sl-bond,pf-1,Bonds"])
        fx.write("Investments/sleeve-targets.csv", FixtureWorkspace.sleeveTargetHeader, ["t1,sl-eq,0.60", "t2,sl-bond,0.40"])
        fx.write("Accounts/transactions/2025-01.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("tr1", "acc-investment", "2025-01-10", "-2000.00", asset: "as-1", side: "buy", qty: "10", price: "200")])
        fx.write("Accounts/transactions/2026-05.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("tr2", "acc-investment", "2026-05-01", "-1200.00", asset: "as-1", side: "buy", qty: "5", price: "240"),
            FixtureWorkspace.trade("tr5", "acc-investment", "2026-05-02", "-300.00", asset: "as-3", side: "buy", qty: "3", price: "100"),
            FixtureWorkspace.trade("tr6", "acc-investment", "2026-05-02", "-1400.00", asset: "as-2", side: "buy", qty: "20", price: "70")])
        fx.write("Accounts/transactions/2026-06.csv", FixtureWorkspace.tradeHeader, [
            FixtureWorkspace.trade("tr3", "acc-investment", "2026-06-20", "1300.00", asset: "as-1", side: "sell", qty: "5", price: "260")])
        return fx
    }

    @Test func fifoBasisValuationAndPriceUnavailable() throws {
        let fx = fixture(); defer { fx.cleanup() }
        let holdings = PortfolioEngine().holdings(try fx.parse(), asOf: asOf("2026-06-30"))
        let byId = Dictionary(holdings.positions.map { ($0.assetId, $0) }, uniquingKeysWith: { a, _ in a })

        // as-1: sold 5 of oldest 10@200 lot → 5@200 + 5@240 = 10 sh, basis 2200; value 10×260=2600.
        let a1 = try #require(byId["as-1"])
        #expect(a1.quantity == 10)
        #expect(a1.costBasis == Decimal(2200))
        #expect(a1.currentValue == .value(Decimal(2600)))
        #expect(a1.unrealizedGainLoss == .value(Decimal(400)))
        // as-3: no price → unavailable.
        #expect(byId["as-3"]?.currentValue == .priceUnavailable)
        #expect(holdings.totalMarketValue == Decimal(4040))   // 2600 + 1440 (as-3 excluded)
    }

    @Test func sleeveDriftAndPricedWeightsSumToOne() throws {
        let fx = fixture(); defer { fx.cleanup() }
        let holdings = PortfolioEngine().holdings(try fx.parse(), asOf: asOf("2026-06-30"))
        let bySleeve = Dictionary(holdings.sleeveAllocations.map { ($0.sleeveId, $0) }, uniquingKeysWith: { a, _ in a })

        // sl-eq holds only as-1 priced (as-3 unpriced excluded): 2600/4040; sl-bond 1440/4040.
        let eq = try #require(bySleeve["sl-eq"]); let bond = try #require(bySleeve["sl-bond"])
        #expect(eq.marketValue == Decimal(2600))
        #expect(bond.marketValue == Decimal(1440))
        #expect((eq.actualWeight + bond.actualWeight) == Decimal(1))     // priced weights sum to 100%
        let eqDrift = try #require(eq.drift)
        #expect(eqDrift > Decimal(string: "0.04")! && eqDrift < Decimal(string: "0.05")!)  // ≈ +4.4%
    }

    @Test func dividendTotals() throws {
        let fx = fixture(); defer { fx.cleanup() }
        let holdings = PortfolioEngine().holdings(try fx.parse(), asOf: asOf("2026-06-30"))
        #expect(holdings.dividendTotalsByAsset["as-1"] == Decimal(string: "12.50"))
        #expect(holdings.dividendTotalsByAccount["acc-investment"] == Decimal(string: "17.50"))
    }
}
