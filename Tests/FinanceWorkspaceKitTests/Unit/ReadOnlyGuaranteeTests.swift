import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T035 — SC-009: a full projection run never writes to the workspace. Snapshot every file's bytes
// before and after running all three engines and assert nothing changed.

@Suite struct ReadOnlyGuaranteeTests {

    private func snapshot(_ root: URL) -> [String: Data] {
        var out: [String: Data] = [:]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            out[url.path] = try? Data(contentsOf: url)
        }
        return out
    }

    @Test func projectionsDoNotMutateWorkspace() throws {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-ro-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        _ = try WorkspaceProvisioner().provision(at: ws)
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        let before = snapshot(ws)
        let context = try WorkspaceParser().parse(workspaceURL: ws)
        let settings = try SettingsStore().read(workspaceURL: ws)
        let asOf = Date()

        _ = AccountEngine().overview(context, asOf: asOf, settings: settings)
        _ = BudgetEngine().overview(budgetId: "bud-household", period: PeriodMath.asOfMonth(asOf),
                                    in: context, asOf: asOf)
        _ = OverviewEngine().dashboard(context, asOf: asOf, settings: settings)
        _ = LinkingEngine().goalLinks(in: context)

        let after = snapshot(ws)
        #expect(before == after, "engines must not write to the workspace (SC-009)")
    }
}
