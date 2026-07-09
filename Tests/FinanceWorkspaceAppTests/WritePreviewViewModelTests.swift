import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// 008 T014 (US1) — the write-preview flow on AppState: apply triggers a re-index, cancel is a
// no-op on disk, and on-disk drift between preview and apply is refused with a re-previewable
// error (never silently overwritten — D8 / FR-004).

@MainActor
@Suite struct WritePreviewViewModelTests {

    /// A ready AppState over a temp fixture workspace (no provider/openWorkspace involved).
    private func makeState(_ fixture: AppFixture) async -> AppState {
        let state = AppState()
        state.fileWatchingEnabled = false   // no FSEvents streams in the test process
        state.workspaceURL = fixture.root
        state.syncState = .available
        await state.reindex()
        return state
    }

    private func groupAddPlan(_ state: AppState, id: String) -> WritePlan? {
        guard let text = state.readWorkspaceFile("Accounts/account-groups.csv") else { return nil }
        let fields = ["account_group_id": id, "name": "Added Group", "group_type": "custom"]
        return WritePlanBuilder.add(fields: fields, to: "Accounts/account-groups.csv", fileText: text)
    }

    @Test func applyAppendsRowAndReindexes() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let plan = try #require(groupAddPlan(state, id: "G9"))

        state.presentWrite(plan)
        #expect(state.pendingWrite != nil)
        // preview stamped a drift baseline for the touched file
        #expect(state.pendingWrite?.changes.first?.expectedHash != nil)

        await state.applyPendingWrite()
        #expect(state.writeError == nil)
        #expect(state.pendingWrite == nil)

        let text = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))
        #expect(text.contains("G9"))
        // apply re-indexed: the new group is in the fresh projections snapshot
        #expect(state.projections?.context.accountGroups.contains { $0.accountGroupId == "G9" } == true)
    }

    @Test func cancelIsANoOpOnDisk() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let before = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))

        let plan = try #require(groupAddPlan(state, id: "G9"))
        state.presentWrite(plan)
        state.cancelWrite()

        #expect(state.pendingWrite == nil)
        #expect(state.writeError == nil)
        let after = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))
        #expect(after == before)
    }

    @Test func driftBetweenPreviewAndApplyIsRefusedThenRepreviewSucceeds() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        let plan = try #require(groupAddPlan(state, id: "G9"))
        state.presentWrite(plan)                       // stamps the drift baseline

        // External edit after preview → the stamped hash no longer matches.
        fixture.write("Accounts/account-groups.csv", "account_group_id,name,group_type",
                      ["G1,Household,personal", "G2,Studio LLC,business", "GX,External,custom"])

        await state.applyPendingWrite()
        #expect(state.writeError?.contains("driftDetected") == true)
        #expect(state.pendingWrite != nil)             // plan retained for re-preview
        let text = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))
        #expect(!text.contains("G9"))                  // nothing was written

        // Re-preview against the current bytes → apply succeeds.
        let fresh = try #require(groupAddPlan(state, id: "G9"))
        state.presentWrite(fresh)
        await state.applyPendingWrite()
        #expect(state.writeError == nil)
        let after = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))
        #expect(after.contains("G9") && after.contains("GX"))
    }
}
