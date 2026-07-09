import SwiftUI
import FinanceWorkspaceKit

// T013 — the @Observable root state (extracted from the Phase-1 diagnostic shell and extended
// per data-model.md). Owns workspace/provider state, the load phase, the projections snapshot,
// navigation, the detail pane, and the session-only selectors. Overview is the default
// selection on launch (FR-002). No API here mutates workspace files (FR-032).

enum AppConfig {
    // Reverse-DNS, iCloud.-prefixed ubiquity container identifier (must match the entitlement).
    static let iCloudContainerIdentifier = "iCloud.app.openfinance.FinanceWorkspace"
    // Set once the first-launch onboarding wizard has completed (or an existing workspace was found).
    static let onboardingCompleteKey = "openfinance.onboardingComplete"

    /// Storage-provider resolution ladder:
    ///   1. `OPENFINANCE_PROVIDER` env override (`icloud` | `clouddocs` | `local`) — dev/testing.
    ///   2. DEBUG → local folder (`~/Finance-Dev`), as always.
    ///   3. RELEASE → the entitled ubiquity container when this build carries the entitlement
    ///      (signed Xcode target); otherwise the user's iCloud Drive folder (`CloudDocsProvider`)
    ///      — the direct-download SwiftPM bundle has no entitlement, so the container URL is nil.
    static func makeProvider() -> any CloudStorageProvider {
        switch ProcessInfo.processInfo.environment["OPENFINANCE_PROVIDER"] {
        case "icloud":    return ICloudContainerService(containerIdentifier: iCloudContainerIdentifier)
        case "clouddocs": return CloudDocsProvider()
        case "local":     return LocalFolderProvider()
        default: break
        }
        #if DEBUG
        return LocalFolderProvider()
        #else
        if FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) != nil {
            return ICloudContainerService(containerIdentifier: iCloudContainerIdentifier)
        }
        return CloudDocsProvider()
        #endif
    }
}

// MARK: - Detail pane state (FR-006)

/// A read-only dry-run repair preview (`RepairService.plan` output, presentation form).
struct RepairPreviewModel: Equatable {
    var issueRef: String
    var actionDescriptions: [String]
    var diffs: [RowDiff]
    var backupNote: String
}

/// The right-pane surfaces. `.editForm` exists for Phase 6 — unreachable in Phase 5 (write
/// affordances are visible but disabled, clarify Q3). Source-file / source-row surfaces were
/// folded into `.inspector` (they rendered identically); TaxArchiveView uses the
/// `SourceFilePreview` view directly.
enum DetailPaneSurface: Equatable {
    case inspector(SourceRef)
    case issueDetail(ValidationIssue)
    case repairPreview(RepairPreviewModel)
    case editForm(entityRef: String)
}

/// Closed by default, globally (locked decision); opens on main-panel selection.
struct DetailPaneState: Equatable {
    var isPresented = false
    var surface: DetailPaneSurface?

    mutating func present(_ surface: DetailPaneSurface) {
        self.surface = surface
        isPresented = true
    }
}

// MARK: - Session-only selectors (clarify Q1)

/// In-module selections; nil ⇒ "current/all". Reset on relaunch (never encoded into the
/// restoration payload).
struct SessionSelections: Equatable {
    var budgetPeriod: String?            // "YYYY-MM"
    var budgetHistoryMonths: Int = 6
    var portfolioAccountId: String?      // nil = all accounts
    var portfolioHeatMap = false         // standard ⇄ heat-map toggle
    var taxYear: Int?                    // nil = workspace settings year
}

// MARK: - Root state

@MainActor
@Observable
final class AppState {
    // Workspace/provider state (Phase 1 wiring, kept).
    var availability: WorkspaceAvailability = .available
    var syncState: SyncState = .available
    var workspaceURL: URL?
    var didProvision = false
    var missingPaths: [String] = []
    var needsR6Migration = false
    var lastError: String?

    // Phase 5 state.
    var phase: LoadPhase = .idle
    var projections: WorkspaceProjections?
    /// A re-index that failed while a prior snapshot is still shown — the views are stale but
    /// usable, so `phase` stays `.ready`; this signal makes the failure visible (not "Synced").
    var reindexError: String?
    var route: Route = .overview                 // Overview default (FR-002)
    var sidebarExpansion: Set<String> = ["accounts", "budget", "si", "taxes"]
    var detailPane = DetailPaneState()
    var selections = SessionSelections()

    // Phase 6 write flows: the plan awaiting confirmation drives the write-preview sheet.
    var pendingWrite: WritePlan?
    var writeError: String?
    // The entity add/edit form sheet (nil ⇒ closed).
    var editForm: EntityEditContext?
    // The CSV import sheet.
    var showingImport = false
    // The multi-entry transaction group editor sheet (008 US2).
    var showingGroupEditor = false
    // Non-nil ⇒ the group editor opens in whole-group EDIT mode over these legs (008 US2 T019).
    var groupEditorLegs: [UnifiedTransaction]?
    // Non-nil ⇒ a delete found referencing rows; the picker sheet collects targets (008 US2 T022).
    var pendingReassignment: ReassignmentModel?
    // The pick-a-version conflict-resolution sheet (008 US3 T031/T032).
    var showingConflicts = false
    // A CSV dropped onto the window, consumed by ImportView on appear (008 US5 T043).
    var droppedImportURL: URL?
    // First-launch onboarding wizard (non-dismissable until complete — DESIGN.md onboarding-wizard).
    var showingOnboarding = false

    let provider: any CloudStorageProvider
    let manager: WorkspaceManager

    // Per-domain cache keys for the projection cache (008 US4 T035) — not UI state.
    @ObservationIgnored private var domainKeys: ProjectionStore.DomainKeys?
    // Debounced FSEvents watcher → re-index on external edits (008 US4 T036) — not UI state.
    @ObservationIgnored private var watcher: FileWatcherService?
    // Tests set false BEFORE reindex: FSEvents streams on soon-deleted temp dirs crash the
    // parallel test process; the app itself always watches.
    @ObservationIgnored var fileWatchingEnabled = true

    var router: AppRouter { AppRouter(state: self) }

    init() {
        provider = AppConfig.makeProvider()
        manager = WorkspaceManager(provider: provider)
    }

    /// Resolve + provision-on-first-run, then build the first projections snapshot.
    ///
    /// True first launch (no completed onboarding AND no existing workspace) hands off to the
    /// onboarding wizard instead of silently provisioning — Step 1 creates the workspace so the
    /// user sees where their files live and can recover from iCloud being unavailable.
    func openWorkspace() async {
        if await routeFirstLaunchToOnboarding() { return }
        do {
            let state = try await manager.openWorkspace()
            workspaceURL = state.workspace?.rootURL
            availability = state.availability
            syncState = provider.syncState
            didProvision = state.didProvision
            missingPaths = state.missingPaths
            if let url = workspaceURL { needsR6Migration = MigrationService().isPreR6(workspaceURL: url) }
        } catch {
            lastError = String(describing: error)
            availability = .containerUnavailable
            phase = .failed(lastError ?? "workspace unavailable")
            Diagnostics.workspace.error("openWorkspace failed: \(self.lastError ?? "", privacy: .public)")
            return
        }
        await reindex()
        pruneBackups()          // 008 FR-025 — prune backups beyond retention once on launch
    }

    /// Rebuild the snapshot (menu ⌘R / launch / watcher). The previous snapshot stays visible
    /// until the new one swaps in — one main-actor assignment, never mixed state (FR-036).
    /// Unchanged domains reuse their previous projections (hash-keyed cache, 008 US4 T035).
    func reindex() async {
        guard let workspaceURL else { return }
        phase = projections == nil ? .indexing : phase   // keep .ready during a re-index
        syncState = provider.syncState
        do {
            let result = try await ProjectionStore.buildCached(
                workspaceURL: workspaceURL, previous: projections, previousKeys: domainKeys)
            projections = result.snapshot                 // atomic swap
            domainKeys = result.keys
            phase = .ready
            reindexError = nil                            // a good build clears any prior failure
            route = AppRouter.resolve(route, in: result.snapshot) // drop stale entity selections
            startWatchingIfNeeded()
        } catch {
            lastError = String(describing: error)
            if projections == nil {
                phase = .failed(lastError ?? "index failed")
            } else {
                // Keep the still-valid snapshot visible, but surface that it is now stale.
                reindexError = lastError
            }
            Diagnostics.workspace.error("reindex failed: \(self.lastError ?? "", privacy: .public)")
        }
    }

    /// Watch the workspace for external edits and fold change bursts into ONE debounced re-index
    /// (008 US4 T036 — the debounce lives in `FileWatcherService`; `.finance-meta/` is filtered
    /// there too, so the app's own backups/logs never re-trigger). Idempotent.
    private func startWatchingIfNeeded() {
        guard fileWatchingEnabled, watcher == nil, let workspaceURL else { return }
        let service = FileWatcherService(workspaceRoot: workspaceURL) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.reindex() }
        }
        service.start()
        watcher = service
    }

    // MARK: - Selection → detail pane (read-only actions)

    /// Row selection opens the inspector surface (selection-driven, DESIGN.md contract).
    func inspect(_ ref: SourceRef) {
        detailPane.present(.inspector(ref))
    }

    func showIssue(_ issue: ValidationIssue) {
        detailPane.present(.issueDetail(issue))
    }

    /// Read-only repair preview scoped to ONE issue: `RepairService.plan` is a dry run —
    /// nothing is written and apply is deferred to Phase 6 (FR-016). `plan` builds `actions`
    /// and `diffs` in lockstep (one of each per repairable condition), so we pair them and keep
    /// only those matching this issue's rule id — preferring an exact file match. When nothing
    /// matches we say so, rather than showing every repair in the workspace.
    func previewRepair(for issue: ValidationIssue) {
        guard let workspaceURL else { return }
        do {
            let plan = try RepairService().plan(workspaceURL: workspaceURL)
            let pairs = Array(zip(plan.actions, plan.diffs))
            let sameRule = pairs.filter { $0.0.issueRef == issue.ruleId }
            let exactFile = sameRule.filter { $0.1.filePath == issue.filePath }
            let matched = exactFile.isEmpty ? sameRule : exactFile   // narrow to the file when possible

            guard !matched.isEmpty else {
                detailPane.present(.repairPreview(RepairPreviewModel(
                    issueRef: issue.id,
                    actionDescriptions: ["No auto-repair is available for this issue."],
                    diffs: [],
                    backupNote: "")))
                return
            }
            detailPane.present(.repairPreview(RepairPreviewModel(
                issueRef: issue.id,
                actionDescriptions: matched.map { "\($0.0.kind.rawValue): \($0.0.preview)" },
                diffs: matched.map(\.1),
                backupNote: "A timestamped backup is created before any apply (Phase 6).")))
        } catch {
            detailPane.present(.repairPreview(RepairPreviewModel(
                issueRef: issue.id,
                actionDescriptions: ["Repair preview unavailable: \(error)"],
                diffs: [],
                backupNote: "")))
        }
    }

}
