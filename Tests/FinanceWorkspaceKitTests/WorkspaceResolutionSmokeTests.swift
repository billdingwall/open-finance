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

    @Test func cloudDocsProviderResolvesOrFailsGracefully() async {
        let provider = CloudDocsProvider()
        #expect(provider.providerKind == .cloudDocs)
        #expect(CloudDocsProvider.cloudDocsRoot.path.hasSuffix("Library/Mobile Documents/com~apple~CloudDocs"))
        do {
            let url = try await provider.resolveWorkspaceURL()
            // …/com~apple~CloudDocs/OpenFinance/Finance
            #expect(url.lastPathComponent == "Finance")
            #expect(url.deletingLastPathComponent().lastPathComponent == "OpenFinance")
        } catch let error as WorkspaceResolutionError {
            // Expected when signed out / iCloud Drive disabled (CI) — typed, non-crashing.
            #expect(error == .notSignedIn || error == .containerUnavailable)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func cloudDocsPlaceholderURLMapsEvictedFiles() {
        let file = URL(fileURLWithPath: "/tmp/ws/Accounts/accounts.csv")
        let placeholder = CloudDocsProvider.placeholderURL(for: file)
        #expect(placeholder.lastPathComponent == ".accounts.csv.icloud")
        #expect(placeholder.deletingLastPathComponent().path == file.deletingLastPathComponent().path)
    }
}
