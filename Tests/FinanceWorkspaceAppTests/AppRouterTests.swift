import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T012 — Route ⇄ NSUserActivity payload round-trip for every case, stale-entity fallback,
// and the fixed KPI → route mapping (contracts/app-shell.md).

@Suite struct AppRouterTests {

    private static let allRoutes: [Route] = [
        .overview, .accounts,
        .accountGroup("G1"), .account("A1"),
        .budget(.overview), .budget(.history), .budget(.categories),
        .savingsInvestments(.overview), .savingsInvestments(.goals), .savingsInvestments(.portfolio),
        .goal("SG1"), .holding("AS1"),
        .taxes(.currentYear), .taxes(.prepChecklist), .taxes(.archive),
    ]

    @Test(arguments: allRoutes)
    func activityRoundTrip(route: Route) {
        let payload = RouteActivityCodec.encode(route, paneOpen: false)
        #expect(RouteActivityCodec.decode(payload) == route)
    }

    @Test func decodeRejectsUnknownVersionAndModule() {
        #expect(RouteActivityCodec.decode(["v": "999", "module": "overview"]) == nil)
        #expect(RouteActivityCodec.decode(["v": "1", "module": "nope"]) == nil)
        #expect(RouteActivityCodec.decode([:]) == nil)
    }

    @Test func staleEntityFallsBackToParentModule() throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let snapshot = try ProjectionStore.buildSync(
            workspaceURL: fixture.root, asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)

        // Live IDs resolve to themselves.
        #expect(AppRouter.resolve(.account("A1"), in: snapshot) == .account("A1"))
        #expect(AppRouter.resolve(.goal("SG1"), in: snapshot) == .goal("SG1"))
        // Stale IDs fall back to the parent module — never crash (data-model rule).
        #expect(AppRouter.resolve(.account("GONE"), in: snapshot) == .accounts)
        #expect(AppRouter.resolve(.accountGroup("GONE"), in: snapshot) == .accounts)
        #expect(AppRouter.resolve(.goal("GONE"), in: snapshot) == .savingsInvestments(.overview))
        #expect(AppRouter.resolve(.holding("GONE"), in: snapshot) == .savingsInvestments(.overview))
    }

    @Test func kpiMappingIsTheContractTable() throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let snapshot = try ProjectionStore.buildSync(
            workspaceURL: fixture.root, asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)

        #expect(AppRouter.route(forKPI: "budget", in: snapshot) == .budget(.overview))
        #expect(AppRouter.route(forKPI: "savings", in: snapshot) == .savingsInvestments(.goals))
        #expect(AppRouter.route(forKPI: "investments", in: snapshot) == .savingsInvestments(.portfolio))
        #expect(AppRouter.route(forKPI: "taxes", in: snapshot) == .taxes(.currentYear))
        // Exactly one business group in the fixture → its group screen.
        #expect(AppRouter.route(forKPI: "business", in: snapshot) == .accountGroup("G2"))
        // No snapshot → the safe default.
        #expect(AppRouter.route(forKPI: "business", in: nil) == .accounts)
    }
}
