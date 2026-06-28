import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T044 / FR-023 — workspace resolution behaves correctly in BOTH provider modes:
// the local-folder provider resolves; the iCloud provider resolves or fails gracefully
// with a typed error when no container/identity is configured (e.g. CI / sandbox).

@Suite struct WorkspaceResolutionSmokeTests {

    @Test func localFolderProviderResolves() async throws {
        let url = try await LocalFolderProvider().resolveWorkspaceURL()
        #expect(url.lastPathComponent == "Finance")
        #expect(LocalFolderProvider().providerKind == .localFolder)
        #expect(LocalFolderProvider().isAvailable)
    }

    @Test func iCloudProviderResolvesOrFailsGracefully() async {
        let service = ICloudContainerService(containerIdentifier: "iCloud.app.openfinance.FinanceWorkspace")
        #expect(service.providerKind == .iCloud)
        do {
            let url = try await service.resolveWorkspaceURL()
            // If a real container is configured, the path ends in Finance.
            #expect(url.lastPathComponent == "Finance")
        } catch let error as WorkspaceResolutionError {
            // Expected when not signed in / no container (CI, sandbox) — a typed, non-crashing failure.
            #expect(error == .notSignedIn || error == .containerUnavailable)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
