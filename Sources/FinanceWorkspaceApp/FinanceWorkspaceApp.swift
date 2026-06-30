import SwiftUI
import FinanceWorkspaceKit

enum AppConfig {
    // Reverse-DNS, iCloud.-prefixed ubiquity container identifier (must match the entitlement).
    static let iCloudContainerIdentifier = "iCloud.app.openfinance.FinanceWorkspace"
}

// T020 — Minimal app shell + active-provider selection (FR-021, FR-024, FR-025).
// DEBUG defaults to LocalFolderProvider so the app runs with no iCloud.
// Release wires ICloudContainerService once it lands in US3.

@MainActor
@Observable
final class AppState {
    var availability: WorkspaceAvailability = .available
    var syncState: SyncState = .available
    var workspaceURL: URL?
    var didProvision = false
    var missingPaths: [String] = []
    var needsR6Migration = false
    var lastError: String?

    let provider: any CloudStorageProvider
    private let manager: WorkspaceManager

    init() {
        #if DEBUG
        provider = LocalFolderProvider()
        #else
        provider = ICloudContainerService(containerIdentifier: AppConfig.iCloudContainerIdentifier)
        #endif
        manager = WorkspaceManager(provider: provider)
    }

    /// Resolve + provision-on-first-run + validate (FR-002/004/005/024).
    func openWorkspace() async {
        do {
            let state = try await manager.openWorkspace()
            workspaceURL = state.workspace?.rootURL
            availability = state.availability
            syncState = provider.syncState
            didProvision = state.didProvision
            missingPaths = state.missingPaths
            // T038 — detect-and-prompt: surface a pre-R6 workspace; never auto-migrate (clarify Q5).
            if let url = workspaceURL { needsR6Migration = MigrationService().isPreR6(workspaceURL: url) }
        } catch {
            lastError = String(describing: error)
            availability = .containerUnavailable
            Diagnostics.workspace.error("openWorkspace failed: \(self.lastError ?? "", privacy: .public)")
        }
    }
}

@main
struct FinanceWorkspaceApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup("Finance Dashboard") {
            ContentView()
                .environment(state)
                .task { await state.openWorkspace() }
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finance Workspace").font(.title2).bold()
            LabeledContent("Availability", value: state.availability.rawValue)
            LabeledContent("Sync state", value: state.syncState.rawValue)
            LabeledContent("Workspace", value: state.workspaceURL?.path ?? "—")
            if state.didProvision {
                Text("Provisioned a new workspace on first launch.").font(.caption).foregroundStyle(.secondary)
            }
            if !state.missingPaths.isEmpty {
                Text("Missing: \(state.missingPaths.joined(separator: ", "))").font(.caption).foregroundStyle(.orange)
            }
            if state.needsR6Migration {
                Text("Pre-R6 workspace detected — migration available. Review and run it "
                     + "explicitly (migrate-r6); it is never applied automatically.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let err = state.lastError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 200)
    }
}
