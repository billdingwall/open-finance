import Testing
import Foundation
@testable import FinanceWorkspaceKit

// US4 (T037) — BenchmarkEngine: simple return ≤1Y, CAGR for 3Y/5Y, calendar anchoring with
// last-close-on-or-before, and .insufficientHistory when the anchor predates the series (SC-004).

@Suite struct BenchmarkEngineTests {

    private func asOf(_ s: String) -> Date {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)!
    }

    private func heat() throws -> HeatMap {
        let fx = FixtureWorkspace()
        fx.write("Investments/benchmarks/sp500.csv", FixtureWorkspace.benchmarkHeader, [
            "2022-06-30,100.00",   // series start
            "2023-06-30,120.00",
            "2025-06-30,180.00",
            "2026-06-30,200.00"])
        let ctx = try fx.parse(); fx.cleanup()
        return BenchmarkEngine().heatMap(ctx, asOf: asOf("2026-06-30"))
    }

    private func cell(_ row: HeatMapRow, _ w: BenchmarkWindow) -> GrowthState {
        row.cells.first { $0.window == w }!.growth
    }

    @Test func simpleForOneYearCagrForMultiYear() throws {
        let benchmark = try heat().benchmark

        // 1Y: simple (200 − 180)/180 ≈ 0.1111.
        if case let .simple(v) = cell(benchmark, .oneYear) {
            #expect(v > Decimal(string: "0.11")! && v < Decimal(string: "0.112")!)
        } else { Issue.record("1Y should be simple") }

        // 3Y: CAGR (200/120)^(1/3) − 1 ≈ 0.1856.
        if case let .cagr(v) = cell(benchmark, .threeYear) {
            #expect(v > Decimal(string: "0.18")! && v < Decimal(string: "0.19")!)
        } else { Issue.record("3Y should be CAGR") }
    }

    @Test func insufficientHistoryWhenAnchorPredatesSeries() throws {
        // 5Y anchor (2021-06-30) predates the 2022-06-30 series start.
        #expect(cell(try heat().benchmark, .fiveYear) == .insufficientHistory)
    }
}
