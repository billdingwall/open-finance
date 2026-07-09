import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// 008 US4 T038 (App half) — the last-known-valid guarantee (FR-016): when a re-index fails, the
// previous snapshot stays visible (`phase` stays `.ready`), the staleness is surfaced via
// `reindexError` (the header chip shows "Stale", never "Synced"), and a subsequent good build
// clears it. Plus the T035 cache contract: an unchanged workspace reuses domain projections.

@MainActor
@Suite struct ReliabilityTests {

    @Test func failedReindexServesLastKnownValidSnapshot() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let state = AppState()
        state.fileWatchingEnabled = false   // no FSEvents streams in the test process
        state.workspaceURL = fixture.root
        state.syncState = .available
        await state.reindex()
        #expect(state.phase == .ready)
        let snapshot = try #require(state.projections)

        // Break the next build: point at a nonexistent workspace and re-index.
        state.workspaceURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)/Finance")
        await state.reindex()

        #expect(state.phase == .ready)                       // never regresses to failed
        #expect(state.reindexError != nil)                   // staleness is surfaced
        #expect(state.projections?.builtAt == snapshot.builtAt)   // the old snapshot survives

        // Recovery: a good build clears the stale flag and swaps a fresh snapshot in.
        state.workspaceURL = fixture.root
        await state.reindex()
        #expect(state.reindexError == nil)
        #expect(state.projections?.builtAt != snapshot.builtAt)
    }

    @Test func unchangedWorkspaceReusesCachedDomainProjections() async throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let keys1 = ProjectionStore.domainKeys(workspaceURL: fixture.root, asOf: Date())
        let first = try ProjectionStore.buildCachedSync(
            workspaceURL: fixture.root, asOf: Date(), previous: nil, previousKeys: nil)
        // Same bytes on disk → same keys → the engine outputs are carried forward.
        let second = try ProjectionStore.buildCachedSync(
            workspaceURL: fixture.root, asOf: Date(),
            previous: first.snapshot, previousKeys: first.keys)
        #expect(second.keys == keys1)
        #expect(second.snapshot.accounts == first.snapshot.accounts)

        // Touch a savings file → savings invalidates, accounts does not.
        fixture.write("Savings/goals.csv",
                      "goal_id,name,target_amount,target_date,monthly_target,source_account_id,status,linked_note_id",
                      ["SG1,Emergency fund,12000,,500,A2,active,"])
        let third = try ProjectionStore.buildCachedSync(
            workspaceURL: fixture.root, asOf: Date(),
            previous: second.snapshot, previousKeys: second.keys)
        #expect(third.keys.savings != second.keys.savings)
        #expect(third.keys.accounts == second.keys.accounts)
        #expect(third.snapshot.goals.first?.targetAmount == 12000)
    }
}
