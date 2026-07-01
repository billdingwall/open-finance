import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T027 — a freshly bootstrapped workspace: canonical account types, six category groups,
// validates clean (SC-007), and produces non-empty accounts + budget projections (FR-022).

@Suite struct SeedDataTests {

    private func bootstrapped() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-seed-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        _ = try WorkspaceProvisioner().provision(at: ws)
        return ws
    }

    @Test func seedAccountTypesAreCanonical() throws {
        let ws = try bootstrapped(); defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let accounts = try WorkspaceParser().parse(workspaceURL: ws).accounts
        #expect(accounts.count == 6)
        for account in accounts {
            #expect(AccountTypeTaxonomy.isCanonical(account.accountType, for: account.accountGroup),
                    "\(account.accountType) not canonical for \(account.accountGroup.rawValue)")
        }
    }

    @Test func seedCategoriesCoverSixGroups() throws {  // SC-007
        let ws = try bootstrapped(); defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let groups = Set(try WorkspaceParser().parse(workspaceURL: ws).categories.compactMap(\.categoryGroupId))
        #expect(groups == ["grp-income", "grp-essentials", "grp-lifestyle", "grp-savings", "grp-investments", "grp-transfers"])
    }

    @Test func freshWorkspaceValidatesCleanAndProjects() throws {  // SC-007 / FR-022
        let ws = try bootstrapped(); defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let context = try WorkspaceParser().parse(workspaceURL: ws)
        #expect(!ValidationEngine().validate(context).hasErrors)

        let asOf = Date()
        let settings = try SettingsStore().read(workspaceURL: ws)
        #expect(!AccountEngine().overview(context, asOf: asOf, settings: settings).accounts.isEmpty)
        #expect(BudgetEngine().overview(budgetId: "bud-household", period: PeriodMath.asOfMonth(asOf),
                                        in: context, asOf: asOf) != nil)
    }

    // T048 / FR-025 — every Phase-4 engine returns well-formed empty/typed results on a fresh
    // (transaction-less) workspace — no crash, no nil, no misleading value.
    @Test func phase4EnginesDegradeGracefullyOnEmptyWorkspace() throws {
        let ws = try bootstrapped(); defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let context = try WorkspaceParser().parse(workspaceURL: ws)
        let asOf = Date()
        let settings = try SettingsStore().read(workspaceURL: ws)

        #expect(PortfolioEngine().holdings(context, asOf: asOf).positions.isEmpty)
        #expect(SavingsGoalEngine().projectGoals(context, asOf: asOf).isEmpty)
        #expect(TaxEngine().realizedGains(context, taxYear: settings.taxYear).total == 0)
        // Benchmark has no series → all windows report insufficient history (not a bogus 0%).
        let heat = BenchmarkEngine().heatMap(context, asOf: asOf)
        #expect(heat.benchmark.cells.allSatisfy { $0.growth == .insufficientHistory })
        // Overview composes five available cards even with no data.
        #expect(OverviewEngine().dashboard(context, asOf: asOf, settings: settings).cards.count == 5)
    }
}
