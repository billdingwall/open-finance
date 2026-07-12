import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// Spec 010 UV-1, T016/T019 — the AppState reorder flow: persistence + projection refresh,
// gate/single-flight refusal with unchanged order (rollback), pre-write state preservation on
// failure, and the US2 scope rules (only the affected group's rows are stamped).

@MainActor
@Suite struct ReorderFlowTests {

    /// A state with the standard fixture workspace open and projections built.
    private func makeState(_ fixture: AppFixture) async -> AppState {
        let state = AppState()
        state.fileWatchingEnabled = false   // no FSEvents streams in the test process
        state.workspaceURL = fixture.root
        state.syncState = .available
        await state.reindex()
        return state
    }

    @Test func groupReorderPersistsGapOfTenAndRefreshesProjections() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        #expect(state.orderedGroups.map(\.accountGroupId) == ["G1", "G2"])

        await state.persistReorder(orderedIds: ["G2", "G1"], keyColumn: "account_group_id",
                                   relativePath: "Accounts/account-groups.csv")

        // File proof: header extended, whole scope stamped gap-of-10 in the new order.
        let text = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))
        #expect(text.contains("account_group_id,name,group_type,sort_order"))
        #expect(text.contains("G2,Studio LLC,business,10"))
        #expect(text.contains("G1,Household,personal,20"))
        // Projection proof: the refreshed snapshot shows the new canonical order everywhere.
        #expect(state.orderedGroups.map(\.accountGroupId) == ["G2", "G1"])
        #expect(state.projections?.context.accountGroups.map(\.accountGroupId) == ["G2", "G1"])
        // A timestamped backup of the pre-write file exists.
        let backups = fixture.root.appendingPathComponent(".finance-meta/backups")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backups.path)) ?? []
        #expect(names.contains { $0.hasPrefix("account-groups.csv.") })
    }

    @Test func gateBlockedReorderIsRefusedWithUnchangedOrder() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let before = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))

        state.syncState = .syncing   // gate closes
        state.applyReorder(orderedIds: ["G2", "G1"], keyColumn: "account_group_id",
                           relativePath: "Accounts/account-groups.csv",
                           optimistic: { state.optimisticGroupOrder = ["G2", "G1"] })

        // Refused synchronously: reasoned feedback, no optimistic overlay, file untouched.
        #expect(state.writeError?.isEmpty == false)
        #expect(state.optimisticGroupOrder == nil)
        #expect(!state.reorderInFlight)
        #expect(state.orderedGroups.map(\.accountGroupId) == ["G1", "G2"])
        #expect(state.readWorkspaceFile("Accounts/account-groups.csv") == before)
    }

    @Test func secondReorderRefusedWhileOneIsInFlight() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        state.reorderInFlight = true    // a reorder write is settling
        state.applyReorder(orderedIds: ["G2", "G1"], keyColumn: "account_group_id",
                           relativePath: "Accounts/account-groups.csv",
                           optimistic: { state.optimisticGroupOrder = ["G2", "G1"] })

        #expect(state.writeError?.isEmpty == false)      // standard busy feedback
        #expect(state.optimisticGroupOrder == nil)       // visible order unchanged
        #expect(state.orderedGroups.map(\.accountGroupId) == ["G1", "G2"])
    }

    @Test func failedWriteRollsBackAndLeavesPreWriteState() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let before = try #require(state.readWorkspaceFile("Accounts/account-groups.csv"))

        // The workspace gate closes between the guard check and the apply (worst case).
        state.syncState = .syncing
        await state.persistReorder(orderedIds: ["G2", "G1"], keyColumn: "account_group_id",
                                   relativePath: "Accounts/account-groups.csv")

        #expect(state.writeError?.isEmpty == false)
        #expect(state.optimisticGroupOrder == nil)       // rollback to file-derived order
        #expect(!state.reorderInFlight)
        #expect(state.readWorkspaceFile("Accounts/account-groups.csv") == before)  // pre-write state
        #expect(state.orderedGroups.map(\.accountGroupId) == ["G1", "G2"])
    }

    // MARK: - US2: accounts within one group

    @Test func accountReorderStampsOnlyTheAffectedGroup() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let g1 = try #require(state.orderedGroups.first { $0.accountGroupId == "G1" })
        #expect(state.orderedAccountIds(in: g1) == ["A1", "A2"])

        await state.persistReorder(orderedIds: ["A2", "A1"], keyColumn: "account_id",
                                   relativePath: "Accounts/accounts.csv")

        let text = try #require(state.readWorkspaceFile("Accounts/accounts.csv"))
        // G1's rows stamped in the new order; G2's row padded but unstamped.
        #expect(text.contains("A2,Savings,Bank,savings,savings,active,G1,10"))
        #expect(text.contains("A1,Checking,Bank,checking,checking,active,G1,20"))
        #expect(text.contains("B1,Studio,Bank,business,checking,active,G2,\n"))
        // Refreshed projections mirror the new order within G1 (mixed rule: unordered after).
        let g1After = try #require(state.orderedGroups.first { $0.accountGroupId == "G1" })
        #expect(state.orderedAccountIds(in: g1After) == ["A2", "A1"])
    }

    @Test func mixedOrderedAndUnorderedAccountsRenderOrderedFirst() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        // Hand-stamp only A2; A1 stays unordered → ordered-first-then-default (US2-AS3).
        fixture.write("Accounts/accounts.csv",
                      "account_id,display_name,institution,account_group,account_type,status,account_group_id,sort_order",
                      ["A1,Checking,Bank,checking,checking,active,G1,",
                       "A2,Savings,Bank,savings,savings,active,G1,10",
                       "B1,Studio,Bank,business,checking,active,G2,"])
        let state = await makeState(fixture)
        let g1 = try #require(state.orderedGroups.first { $0.accountGroupId == "G1" })
        #expect(state.orderedAccountIds(in: g1) == ["A2", "A1"])
    }
}
