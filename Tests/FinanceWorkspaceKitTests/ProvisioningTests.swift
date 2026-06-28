import Testing
import Foundation
@testable import FinanceWorkspaceKit

@Suite struct ProvisioningTests {

    private func tempWorkspace() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
    }

    // T021 / SC-001 — first-launch provisioning yields a complete workspace.
    @Test func firstLaunchProvisioningCreatesValidWorkspace() throws {
        let ws = tempWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        let outcome = try WorkspaceProvisioner().provision(at: ws)
        #expect(outcome.didCreateAnything)

        let fm = FileManager.default
        // Required folders + files all present.
        for path in WorkspaceLayout.requiredFolders + WorkspaceLayout.requiredFiles {
            #expect(fm.fileExists(atPath: ws.appendingPathComponent(path).path), "missing \(path)")
        }

        // Six seed accounts, each managed CSV carries the schema-version marker.
        let accounts = try String(contentsOf: ws.appendingPathComponent("Accounts/accounts.csv"), encoding: .utf8)
        #expect(accounts.hasPrefix("# schema_version: 1"))
        let dataRows = accounts.split(separator: "\n").filter { !$0.hasPrefix("#") }.dropFirst() // drop header
        #expect(dataRows.count == 6)
    }

    // T022 / SC-008 — provisioning is idempotent and never overwrites user edits.
    @Test func reprovisioningIsIdempotentAndPreservesEdits() throws {
        let ws = tempWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        let provisioner = WorkspaceProvisioner()
        _ = try provisioner.provision(at: ws)

        // User edits a seed file.
        let accountsURL = ws.appendingPathComponent("Accounts/accounts.csv")
        let edited = "# schema_version: 1\naccount_id\nmy-custom-account\n"
        try Data(edited.utf8).write(to: accountsURL)

        // Second provisioning creates nothing and leaves the edit intact.
        let outcome = try provisioner.provision(at: ws)
        #expect(!outcome.didCreateAnything)
        let after = try String(contentsOf: accountsURL, encoding: .utf8)
        #expect(after == edited)
    }

    // FR-005 — validateRequiredPaths reports exactly what is missing.
    @Test func validateReportsMissingPaths() throws {
        let ws = tempWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let manager = WorkspaceManager(provider: LocalFolderProvider(),
                                       defaults: UserDefaults(suiteName: "fw-test-\(UUID().uuidString)")!)
        // Nothing created yet → everything missing.
        #expect(!manager.validateRequiredPaths(at: ws).isEmpty)
        try WorkspaceProvisioner().provision(at: ws)
        #expect(manager.validateRequiredPaths(at: ws).isEmpty)
    }
}
