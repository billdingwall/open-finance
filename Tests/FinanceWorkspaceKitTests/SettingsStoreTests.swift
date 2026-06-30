import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T033 / SC-006 — settings round-trip: read typed; missing file → typed defaults; a change
// re-reads identically through a backed-up atomic write.

@Suite struct SettingsStoreTests {

    private func provisioned() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-settings-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        try WorkspaceProvisioner().provision(at: ws)
        return ws
    }

    @Test func readsSeededSettings() throws {
        let ws = try provisioned()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let settings = try SettingsStore().read(workspaceURL: ws)
        #expect(settings.filingStatus == .single)
        #expect(settings.defaultCurrency == "USD")
        #expect(settings.timezone == "UTC")
        #expect(settings.taxYear == WorkspaceLayout.currentTaxYear())
    }

    @Test func missingFileYieldsTypedDefaults() throws {
        let ws = try provisioned()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        try FileManager.default.removeItem(at: ws.appendingPathComponent("Taxes/settings.csv"))
        let settings = try SettingsStore().read(workspaceURL: ws)
        #expect(settings == WorkspaceSettings.defaults())
    }

    @Test func writeRoundTrips() throws {
        let ws = try provisioned()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let store = SettingsStore()

        var changed = try store.read(workspaceURL: ws)
        changed.filingStatus = .marriedFilingJointly
        changed.taxYear = 2030
        changed.defaultCurrency = "EUR"
        try store.write(changed, to: ws)

        let reread = try store.read(workspaceURL: ws)
        #expect(reread == changed)
        // The file still parses cleanly as a managed CSV (schema_version marker preserved).
        let text = try String(contentsOf: ws.appendingPathComponent("Taxes/settings.csv"), encoding: .utf8)
        #expect(text.hasPrefix("# schema_version: 1"))
    }
}
