import SwiftUI
import FinanceWorkspaceKit

// T020 — Minimal app shell + active-provider selection (FR-021, FR-024, FR-025).
// DEBUG defaults to LocalFolderProvider so the app runs with no iCloud.
// Release wires ICloudContainerService once it lands in US3.

@MainActor
@Observable
final class AppState {
    var availability: WorkspaceAvailability = .available
    var syncState: SyncState = .available
    var workspaceURL: URL?
    var lastError: String?

    let provider: any CloudStorageProvider

    init() {
        #if DEBUG
        provider = LocalFolderProvider()
        #else
        // ICloudContainerService is wired here in US3; LocalFolderProvider is the safe default until then.
        provider = LocalFolderProvider()
        #endif
    }

    func resolveWorkspace() async {
        do {
            workspaceURL = try await provider.resolveWorkspaceURL()
            syncState = provider.syncState
            Diagnostics.workspace.info("Resolved workspace at \(self.workspaceURL?.path ?? "nil", privacy: .public)")
        } catch {
            lastError = String(describing: error)
            availability = .containerUnavailable
            Diagnostics.workspace.error("Workspace resolution failed: \(self.lastError ?? "", privacy: .public)")
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
                .task { await state.resolveWorkspace() }
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
            if let err = state.lastError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 200)
    }
}
