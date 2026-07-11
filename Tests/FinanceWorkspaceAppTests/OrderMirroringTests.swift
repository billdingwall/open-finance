import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// Spec 010 UV-1, T021 (US3 / SC-004) — every surface that enumerates accounts or account groups
// agrees with the canonical accessor order: engine projections, edit-form dropdown options, and
// delete-reassignment targets. With a reordered fixture no surface may show a competing order.

@MainActor
@Suite struct OrderMirroringTests {

    /// A workspace whose files carry an explicit user order that INVERTS the alphabetical one,
    /// so any surface that re-sorts by ID is caught immediately.
    private func reorderedFixture() -> AppFixture {
        let fixture = AppFixture.standard()
        fixture.write("Accounts/account-groups.csv", "account_group_id,name,group_type,sort_order",
                      ["G1,Household,personal,20", "G2,Studio LLC,business,10"])
        fixture.write("Accounts/accounts.csv",
                      "account_id,display_name,institution,account_group,account_type,status,account_group_id,sort_order",
                      ["A1,Checking,Bank,checking,checking,active,G1,20",
                       "A2,Savings,Bank,savings,savings,active,G1,10",
                       "B1,Studio,Bank,business,checking,active,G2,10"])
        return fixture
    }

    private func makeState(_ fixture: AppFixture) async -> AppState {
        let state = AppState()
        state.fileWatchingEnabled = false
        state.workspaceURL = fixture.root
        state.syncState = .available
        await state.reindex()
        return state
    }

    @Test func projectionsMirrorTheCanonicalOrder() async throws {
        let fixture = reorderedFixture()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let context = try #require(state.projections?.context)

        let canonicalGroups = context.accountGroups.map(\.accountGroupId)
        #expect(canonicalGroups == ["G2", "G1"])
        // Engine group projections == accessor order (sidebar + Accounts module cards).
        #expect(state.projections?.accounts.groups.map(\.accountGroupId) == canonicalGroups)
        // Account order within G1 == accessor order.
        let g1 = try #require(state.projections?.accounts.groups.first { $0.accountGroupId == "G1" })
        #expect(g1.accountIds == ["A2", "A1"])
        // The all-accounts card list == accessor order.
        #expect(state.projections?.accounts.accounts.map(\.accountId) ==
                context.accounts.map(\.accountId))
    }

    @Test func editFormDropdownsMirrorTheCanonicalOrder() async throws {
        let fixture = reorderedFixture()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let context = try #require(state.projections?.context)

        // The account-group dropdown options (e.g. the account edit form's parent picker).
        let groupOptions = EntityEditForm.orderedIds(
            fileTypeKey: "account-groups", context: context,
            ids: context.identifierSet(fileTypeKey: "account-groups", column: "account_group_id"))
        #expect(groupOptions == ["G2", "G1"])

        let accountOptions = EntityEditForm.orderedIds(
            fileTypeKey: "registry", context: context,
            ids: context.identifierSet(fileTypeKey: "registry", column: "account_id"))
        #expect(accountOptions == context.accounts.map(\.accountId))
    }

    @Test func reassignmentTargetsMirrorTheCanonicalOrder() async throws {
        let fixture = reorderedFixture()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let context = try #require(state.projections?.context)

        let scanner = ReferenceScanner(context: context)
        // Deleting nothing: the full target list follows the canonical group order.
        #expect(scanner.reassignTargets(parentSubtype: "account-groups", excluding: [])
                == ["G2", "G1"])
        // Excluding one keeps the remainder in canonical account order.
        let accounts = scanner.reassignTargets(parentSubtype: "registry", excluding: ["A2"])
        #expect(accounts == context.accounts.map(\.accountId).filter { $0 != "A2" })
    }
}
