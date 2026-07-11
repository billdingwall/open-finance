import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// Spec 011 UV-2, T004–T007 — the edit-form delete entry point. The load-bearing property is
// PARITY (SC-002): `requestDeleteFromEditForm` calls the same `requestDelete` the detail pane
// uses, so every assertion here compares the two entry points or verifies the inherited
// pipeline behavior (preview, atomicity, byte-identity on cancel, apply-time gating, FR-008
// route resolution).

@MainActor
@Suite struct DeleteInEditFormTests {

    private func makeState(_ fixture: AppFixture) async -> AppState {
        let state = AppState()
        state.fileWatchingEnabled = false
        state.workspaceURL = fixture.root
        state.syncState = .available
        await state.reindex()
        return state
    }

    /// Drive the form entry point and drain the sheet-sequencing hop it schedules.
    private func deleteViaForm(_ state: AppState, file: String, id: String) async {
        state.presentEditEntity(relativePath: file, id: id)
        guard let context = state.editForm else { Issue.record("edit form did not open"); return }
        state.requestDeleteFromEditForm(context)
        for _ in 0..<4 { await Task.yield() }   // drain the runloop hop
    }

    // MARK: - T004 (US1): clean delete parity, add-mode, cancel byte-identity, apply

    @Test func formEntryPointBuildsTheSamePlanAsTheDetailPane() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }

        // Detail-pane entry point on account A2 (no referencing rows in the standard fixture).
        let paneState = await makeState(fixture)
        let text = try #require(paneState.readWorkspaceFile("Accounts/accounts.csv"))
        let row = try #require(AppState.dataRowNumber(of: "A2", in: text))
        paneState.requestDelete(SourceRef(filePath: "Accounts/accounts.csv", rowNumber: row,
                                          provenance: .userEdited))
        let paneWrite = paneState.pendingWrite

        // Form entry point on the same row.
        let formState = await makeState(fixture)
        await deleteViaForm(formState, file: "Accounts/accounts.csv", id: "A2")

        #expect(formState.editForm == nil)                       // the form closed
        let formWrite = try #require(formState.pendingWrite)
        #expect(formWrite.intent == .delete)
        // Identical plan shape from both entry points (SC-002): same file, same row diffs.
        #expect(formWrite.changes.map(\.relativePath) == paneWrite?.changes.map(\.relativePath))
        #expect(formWrite.changes.flatMap(\.rowDiffs) == paneWrite?.changes.flatMap(\.rowDiffs))
    }

    @Test func addModeIsANoOp() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        state.addAccount()                                        // rowRef == nil ⇒ add mode
        let context = try #require(state.editForm)
        state.requestDeleteFromEditForm(context)
        for _ in 0..<4 { await Task.yield() }

        #expect(state.editForm != nil)                            // form stays open
        #expect(state.pendingWrite == nil)
        #expect(state.pendingReassignment == nil)
    }

    @Test func cancellingThePreviewLeavesFilesByteIdentical() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let snapshot = fixture.contentSnapshot()

        await deleteViaForm(state, file: "Accounts/accounts.csv", id: "A2")
        #expect(state.pendingWrite != nil)
        state.cancelWrite()

        #expect(fixture.contentSnapshot() == snapshot)            // SC-003
    }

    @Test func confirmedDeleteRemovesRowCreatesBackupAndDropsEntity() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        await deleteViaForm(state, file: "Accounts/accounts.csv", id: "A2")
        #expect(state.pendingWrite != nil)
        await state.applyPendingWrite()

        let text = try #require(state.readWorkspaceFile("Accounts/accounts.csv"))
        #expect(!text.contains("A2,"))                            // row gone
        let backups = fixture.root.appendingPathComponent(".finance-meta/backups")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backups.path)) ?? []
        #expect(names.contains { $0.hasPrefix("accounts.csv.") }) // timestamped backup
        // FR-007: refreshed projections drop the entity everywhere.
        #expect(state.projections?.context.accounts.map(\.accountId).contains("A2") == false)
    }

    // MARK: - T005 (US2): referenced deletes inherit the reassignment flow

    @Test func referencedDeleteOpensTheSamePickerModelAsTheDetailPane() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }

        // Category C1 is referenced by transaction T4 and allocation AL1 in the fixture.
        let paneState = await makeState(fixture)
        let text = try #require(paneState.readWorkspaceFile("Budget/categories.csv"))
        let row = try #require(AppState.dataRowNumber(of: "C1", in: text))
        paneState.requestDelete(SourceRef(filePath: "Budget/categories.csv", rowNumber: row,
                                          provenance: .userEdited))
        let paneModel = paneState.pendingReassignment

        let formState = await makeState(fixture)
        await deleteViaForm(formState, file: "Budget/categories.csv", id: "C1")

        let formModel = try #require(formState.pendingReassignment)
        #expect(formState.pendingWrite == nil)                    // picker first, not a bare plan
        #expect(formModel.deletedId == "C1")
        // Identical reference groups from both entry points (SC-002).
        #expect(formModel.groups == paneModel?.groups)
        #expect(formModel.targets == paneModel?.targets)
    }

    @Test func groupWithAccountsYieldsReassignOnlyReferences() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        await deleteViaForm(state, file: "Accounts/account-groups.csv", id: "G1")

        let model = try #require(state.pendingReassignment)
        // Accounts reference their group via a REQUIRED column: reassign-only (FR-006).
        let registryGroup = try #require(model.groups.first { $0.collection == "registry" })
        #expect(!registryGroup.nullable)
        #expect(registryGroup.rows.count == 2)                    // A1 + A2 live in G1
    }

    @Test func cancellingThePickerLeavesFilesByteIdentical() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)
        let snapshot = fixture.contentSnapshot()

        await deleteViaForm(state, file: "Budget/categories.csv", id: "C1")
        #expect(state.pendingReassignment != nil)
        state.pendingReassignment = nil                           // the picker's Cancel path

        #expect(fixture.contentSnapshot() == snapshot)            // SC-003
    }

    // MARK: - T006 (US3): inherited apply-time gating + the whitelist

    @Test func gatedApplyRefusesAndLeavesFilesUntouched() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        // Parity (analyze I1): the preview still OPENS while syncing — same as the detail pane;
        // gating bites at apply, exactly like every other write.
        await deleteViaForm(state, file: "Accounts/accounts.csv", id: "A2")
        #expect(state.pendingWrite != nil)
        let snapshot = fixture.contentSnapshot()

        state.syncState = .syncing
        await state.applyPendingWrite()

        #expect(state.writeError?.isEmpty == false)               // reasoned refusal (SC-005)
        #expect(fixture.contentSnapshot() == snapshot)            // files untouched
    }

    @Test func whitelistCoversExactlyTheThreeEntityFiles() {
        #expect(EntityEditForm.deletableFiles == [
            "Accounts/accounts.csv", "Accounts/account-groups.csv", "Budget/categories.csv",
        ])
        #expect(!EntityEditForm.deletableFiles.contains("Savings/goals.csv"))
    }

    // MARK: - T007 (FR-008): post-delete route resolution

    @Test func deletingTheCurrentlyRoutedEntityResolvesToNearestValidContext() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = await makeState(fixture)

        state.route = .account("A2")                              // on the entity's own screen
        await deleteViaForm(state, file: "Accounts/accounts.csv", id: "A2")
        await state.applyPendingWrite()                           // applies + reindexes

        #expect(state.route != .account("A2"))                    // never a dead route
    }
}
