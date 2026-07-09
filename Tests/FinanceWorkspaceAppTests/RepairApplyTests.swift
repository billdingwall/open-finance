import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// 008 US6 T050 — repair-apply through the app state: applying the deterministic auto-repairs
// clears the issue after the re-validate that `applyRepair` triggers, and manual-only issues
// never offer an apply (the preview says so instead — FR-021/P-VII).

@MainActor
@Suite struct RepairApplyTests {

    private func makeState(_ root: URL) async -> AppState {
        let state = AppState()
        state.fileWatchingEnabled = false   // no FSEvents streams in the test process
        state.workspaceURL = root
        state.syncState = .available
        await state.reindex()
        return state
    }

    @Test func applyClearsRepairableIssueAfterRevalidate() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        // Damage: a missing required seed file is a repairable (createFile) condition.
        try FileManager.default.removeItem(
            at: fixture.root.appendingPathComponent("Budget/categories.csv"))

        let state = await makeState(fixture.root)
        let issuesBefore = state.projections?.issues ?? []
        #expect(issuesBefore.contains { $0.filePath.contains("categories") },
                "the damage must surface as an issue: \(issuesBefore.map(\.id))")

        await state.applyRepair()

        #expect(state.writeError == nil)
        #expect(FileManager.default.fileExists(
            atPath: fixture.root.appendingPathComponent("Budget/categories.csv").path))
        let issuesAfter = state.projections?.issues ?? []
        #expect(!issuesAfter.contains { $0.filePath.contains("categories") },
                "the applied repair must clear its issue after re-validate: \(issuesAfter.map(\.id))")
    }

    @Test func manualOnlyIssueOffersNoApply() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        // An unknown account reference is manual-only (error/manual — never auto-repaired).
        fixture.write("Accounts/transactions/2026-07.csv",
                      "transaction_id,account_id,date,amount,type,category_id,savings_goal_id,group_id,group_role,liability_id",
                      ["TX-GHOST,GHOST,2026-07-01,-10,standard,,,,,"])

        let state = await makeState(fixture.root)
        let issue = try #require(state.projections?.issues.first { $0.ruleId == "VAL-CROSS-003" })

        state.previewRepair(for: issue)
        guard case .repairPreview(let model)? = state.detailPane.surface else {
            Issue.record("expected a repair-preview surface")
            return
        }
        // Manual-only ⇒ the preview offers no diffs to apply and says so.
        #expect(model.diffs.isEmpty)
        #expect(model.actionDescriptions.contains { $0.contains("No auto-repair") })
    }
}
