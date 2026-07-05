import Foundation
import FinanceWorkspaceKit

// T007/T008 — the read-model snapshot and its builder (research D3). One immutable
// `WorkspaceProjections` value is built off the main actor (parse → engines → validation) and
// swapped into `AppState` in a single assignment, so views never mix stale and fresh data
// (FR-036). The store never writes to the workspace (FR-032); it is an in-memory, regenerable
// cache — never authoritative over file content (constitution P-I/II).

/// Where the app is in its load/reindex lifecycle.
enum LoadPhase: Equatable {
    case idle
    case indexing
    case ready
    case failed(String)
}

/// One immutable, consistent snapshot of every projection the UI renders.
struct WorkspaceProjections: Sendable {
    let builtAt: Date
    let asOf: Date
    let workspaceURL: URL
    let settings: WorkspaceSettings

    /// Retained for selector-driven engine re-runs (still read-only, one consistent parse).
    let context: WorkspaceContext

    let dashboard: OverviewDashboard
    let accounts: AccountsOverview
    let goals: [GoalProgressProjection]
    let holdings: HoldingsProjection
    let heatMap: HeatMap
    let tax: TaxEngine.Projection
    let deductions: TaxDeductionSummary
    let taxEstimate: TaxEstimateProjection
    let prep: TaxPrepSummary
    /// Closed tax years discovered from `Taxes/archive/` (read-only; parser excludes them).
    let closedTaxYears: [Int]

    var issues: [ValidationIssue] { dashboard.issues }
    var errorCount: Int { issues.filter { $0.severity == .error }.count }

    /// Category id → display name, derived once from the shared context (used by the Accounts
    /// and Budget ledgers so they can't disagree on a transaction's category label).
    var categoryNames: [String: String] {
        Dictionary(context.categories.map { ($0.categoryId, $0.name) },
                   uniquingKeysWith: { first, _ in first })
    }
}

/// Builds `WorkspaceProjections` snapshots. Pure reads; safe to run on any executor.
struct ProjectionStore: Sendable {

    /// Parse the workspace and run every engine into one consistent snapshot. `nonisolated async`
    /// so it already runs off the main actor under Swift 6 — no `Task.detached` needed; the
    /// caller assigns the result in one hop (atomic swap) and cancellation propagates normally.
    static func build(workspaceURL: URL, asOf: Date = Date()) async throws -> WorkspaceProjections {
        try buildSync(workspaceURL: workspaceURL, asOf: asOf)
    }

    static func buildSync(workspaceURL: URL, asOf: Date) throws -> WorkspaceProjections {
        let context = try WorkspaceParser().parse(workspaceURL: workspaceURL)
        let settings = (try? SettingsStore().read(workspaceURL: workspaceURL)) ?? .defaults()

        // Compute the cross-domain sub-projections once, then hand them to OverviewEngine so the
        // dashboard doesn't re-run AccountEngine / PortfolioEngine / TaxAdjustmentEngine (FR-036,
        // review finding 7 — this was ~2× work at index time).
        let accounts = AccountEngine().overview(context, asOf: asOf, settings: settings)
        let goals = SavingsGoalEngine().projectGoals(context, asOf: asOf)
        let holdings = PortfolioEngine().holdings(context, asOf: asOf, scope: .aggregate)
        let heatMap = BenchmarkEngine().heatMap(context, asOf: asOf)
        let tax = TaxEngine().project(context, taxYear: settings.taxYear)
        let deductions = TaxAdjustmentEngine().deductionSummary(context, settings: settings)
        let estimate = TaxAdjustmentEngine().taxEstimate(context, settings: settings)
        let prep = TaxPrepEngine().prepSummary(context, settings: settings)

        let dashboard = OverviewEngine().dashboard(
            context, asOf: asOf, settings: settings,
            accounts: accounts, aggregateHoldings: holdings, taxEstimate: estimate)

        return WorkspaceProjections(
            builtAt: Date(), asOf: asOf, workspaceURL: workspaceURL, settings: settings,
            context: context, dashboard: dashboard, accounts: accounts, goals: goals,
            holdings: holdings, heatMap: heatMap, tax: tax, deductions: deductions,
            taxEstimate: estimate, prep: prep,
            closedTaxYears: closedYears(workspaceURL: workspaceURL))
    }

    /// Closed years from `Taxes/archive/YYYY-*.csv` file names (a read-only directory scan —
    /// the parser deliberately skips archive contents).
    static func closedYears(workspaceURL: URL) -> [Int] {
        let archive = workspaceURL.appendingPathComponent("Taxes/archive")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: archive.path) else { return [] }
        let years = names.compactMap { name -> Int? in
            guard name.hasSuffix(".csv"), name.count > 4 else { return nil }
            return Int(name.prefix(4))
        }
        return Set(years).sorted(by: >)
    }
}
