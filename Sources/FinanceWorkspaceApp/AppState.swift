import SwiftUI
import FinanceWorkspaceKit

// T013 — the @Observable root state (extracted from the Phase-1 diagnostic shell and extended
// per data-model.md). Owns workspace/provider state, the load phase, the projections snapshot,
// navigation, the detail pane, and the session-only selectors. Overview is the default
// selection on launch (FR-002). No API here mutates workspace files (FR-032).

enum AppConfig {
    // Reverse-DNS, iCloud.-prefixed ubiquity container identifier (must match the entitlement).
    static let iCloudContainerIdentifier = "iCloud.app.openfinance.FinanceWorkspace"
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

    let provider: any CloudStorageProvider
    private let manager: WorkspaceManager

    var router: AppRouter { AppRouter(state: self) }

    init() {
        #if DEBUG
        provider = LocalFolderProvider()
        #else
        provider = ICloudContainerService(containerIdentifier: AppConfig.iCloudContainerIdentifier)
        #endif
        manager = WorkspaceManager(provider: provider)
    }

    /// Resolve + provision-on-first-run, then build the first projections snapshot.
    func openWorkspace() async {
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
    }

    /// Rebuild the snapshot (menu ⌘R / launch). The previous snapshot stays visible until the
    /// new one swaps in — one main-actor assignment, never mixed state (FR-036).
    func reindex() async {
        guard let workspaceURL else { return }
        phase = projections == nil ? .indexing : phase   // keep .ready during a re-index
        syncState = provider.syncState
        do {
            let snapshot = try await ProjectionStore.build(workspaceURL: workspaceURL)
            projections = snapshot                        // atomic swap
            phase = .ready
            reindexError = nil                            // a good build clears any prior failure
            route = AppRouter.resolve(route, in: snapshot) // drop stale entity selections
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
