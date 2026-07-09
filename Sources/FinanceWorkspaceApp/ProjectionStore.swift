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
        try buildCachedSync(workspaceURL: workspaceURL, asOf: asOf, previous: nil, previousKeys: nil).snapshot
    }

    // MARK: - Per-domain projection cache (008 US4 T035)

    /// Per-domain invalidation keys — a stat digest (path · size · mtime) of each domain's input
    /// files. Cheap to compute (no byte reads); a matching key means the domain's inputs are
    /// byte-identical for engine purposes, so the previous projection is carried forward. The
    /// unified ledger feeds every domain, so it is its own key mixed into each dependency set.
    /// This is an in-memory cache only — projections stay regenerable from files (P-II).
    struct DomainKeys: Sendable, Equatable {
        var transactions = ""   // Accounts/transactions/**
        var accounts = ""       // Accounts/** (minus transactions/)
        var budget = ""         // Budget/**
        var savings = ""        // Savings/**
        var investments = ""    // Investments/**
        var taxes = ""          // Taxes/**
        /// Engine outputs are `asOf`-dependent; reuse only within the same calendar day.
        var day = ""
    }

    /// Cache-aware build: reparses the workspace (the context must always be current) but skips
    /// engine recomputation for domains whose inputs are unchanged since `previousKeys`, carrying
    /// the previous snapshot's projections forward. Cross-domain dependencies are honored
    /// conservatively (e.g. the tax group also invalidates on accounts/budget changes — Schedule C
    /// cross-references). The dashboard always recomputes: it is cheap given the sub-projections
    /// and aggregates validation issues, which any file change can alter.
    static func buildCached(workspaceURL: URL, asOf: Date = Date(),
                            previous: WorkspaceProjections?, previousKeys: DomainKeys?)
        async throws -> (snapshot: WorkspaceProjections, keys: DomainKeys) {
        try buildCachedSync(workspaceURL: workspaceURL, asOf: asOf,
                            previous: previous, previousKeys: previousKeys)
    }

    /// Thrown when the workspace root has vanished (unmounted / evicted / deleted). Parsing a
    /// missing tree would otherwise yield an EMPTY context and silently blank the whole UI —
    /// throwing instead keeps the last-known-valid snapshot visible with the "Stale" chip (FR-016).
    struct WorkspaceMissing: Error, CustomStringConvertible {
        let path: String
        var description: String { "workspace root missing at \(path)" }
    }

    static func buildCachedSync(workspaceURL: URL, asOf: Date,
                                previous: WorkspaceProjections?, previousKeys: DomainKeys?)
        throws -> (snapshot: WorkspaceProjections, keys: DomainKeys) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw WorkspaceMissing(path: workspaceURL.path)
        }
        let keys = domainKeys(workspaceURL: workspaceURL, asOf: asOf)
        let context = try WorkspaceParser().parse(workspaceURL: workspaceURL)
        let settings = (try? SettingsStore().read(workspaceURL: workspaceURL)) ?? .defaults()

        // A domain is reusable when its full dependency set (incl. the shared ledger + day) is
        // unchanged AND a previous snapshot with the same settings exists.
        func fresh(_ dependencyKeys: (DomainKeys) -> [String]) -> Bool {
            guard let previous, let previousKeys, previous.settings == settings,
                  previousKeys.day == keys.day else { return false }
            return dependencyKeys(previousKeys) == dependencyKeys(keys)
        }

        let accountsFresh = fresh { [$0.accounts, $0.transactions] }
        let savingsFresh = fresh { [$0.savings, $0.accounts, $0.transactions] }
        let investmentsFresh = fresh { [$0.investments, $0.transactions] }
        let taxesFresh = fresh { [$0.taxes, $0.transactions, $0.accounts, $0.budget, $0.investments] }

        // Compute the cross-domain sub-projections once (reusing cached ones), then hand them to
        // OverviewEngine so the dashboard doesn't re-run the engines (FR-036, review finding 7).
        let accounts = accountsFresh ? previous!.accounts
            : AccountEngine().overview(context, asOf: asOf, settings: settings)
        let goals = savingsFresh ? previous!.goals
            : SavingsGoalEngine().projectGoals(context, asOf: asOf)
        let holdings = investmentsFresh ? previous!.holdings
            : PortfolioEngine().holdings(context, asOf: asOf, scope: .aggregate)
        let heatMap = investmentsFresh ? previous!.heatMap
            : BenchmarkEngine().heatMap(context, asOf: asOf)
        let tax = taxesFresh ? previous!.tax
            : TaxEngine().project(context, taxYear: settings.taxYear)
        let deductions = taxesFresh ? previous!.deductions
            : TaxAdjustmentEngine().deductionSummary(context, settings: settings)
        let estimate = taxesFresh ? previous!.taxEstimate
            : TaxAdjustmentEngine().taxEstimate(context, settings: settings)
        let prep = taxesFresh ? previous!.prep
            : TaxPrepEngine().prepSummary(context, settings: settings)

        let dashboard = OverviewEngine().dashboard(
            context, asOf: asOf, settings: settings,
            accounts: accounts, aggregateHoldings: holdings, taxEstimate: estimate)

        let snapshot = WorkspaceProjections(
            builtAt: Date(), asOf: asOf, workspaceURL: workspaceURL, settings: settings,
            context: context, dashboard: dashboard, accounts: accounts, goals: goals,
            holdings: holdings, heatMap: heatMap, tax: tax, deductions: deductions,
            taxEstimate: estimate, prep: prep,
            closedTaxYears: closedYears(workspaceURL: workspaceURL))
        return (snapshot, keys)
    }

    /// Stat digests per domain path group (skipping the app-managed `.finance-meta/`).
    /// Symlinks are resolved on BOTH sides — /tmp vs /private/tmp style aliases otherwise make
    /// every relative path (and so every key) empty, which would wrongly mark all domains fresh.
    static func domainKeys(workspaceURL: URL, asOf: Date) -> DomainKeys {
        var keys = DomainKeys()
        var parts: [String: [String]] = [:]
        let base = workspaceURL.resolvingSymlinksInPath()
        let keysOf: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let enumerator = FileManager.default.enumerator(at: base,
                                                        includingPropertiesForKeys: Array(keysOf))
        while let url = enumerator?.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: keysOf),
                  values.isRegularFile == true else { continue }
            let rel = url.resolvingSymlinksInPath().path
                .replacingOccurrences(of: base.path + "/", with: "")
            guard !rel.hasPrefix(".finance-meta"), let group = Self.domainGroup(for: rel) else { continue }
            let stamp = "\(rel)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
            parts[group, default: []].append(stamp)
        }
        func digest(_ group: String) -> String { (parts[group] ?? []).sorted().joined(separator: ";") }
        keys.transactions = digest("transactions")
        keys.accounts = digest("accounts")
        keys.budget = digest("budget")
        keys.savings = digest("savings")
        keys.investments = digest("investments")
        keys.taxes = digest("taxes")
        keys.day = ISO8601DateFormatter().string(from: asOf).prefix(10).description
        return keys
    }

    private static func domainGroup(for rel: String) -> String? {
        if rel.hasPrefix("Accounts/transactions/") { return "transactions" }
        if rel.hasPrefix("Accounts/") { return "accounts" }
        if rel.hasPrefix("Budget/") { return "budget" }
        if rel.hasPrefix("Savings/") { return "savings" }
        if rel.hasPrefix("Investments/") { return "investments" }
        if rel.hasPrefix("Taxes/") { return "taxes" }
        return nil
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
