import SwiftUI
import FinanceWorkspaceKit

// Spec 010 (UV-1) — sidebar reorder entry points. A reorder applies optimistically (< 100ms,
// SC-001), persists through the standard safe-write path (gate → drift → backup → atomic apply;
// no preview sheet per the constitution v1.1.2 direct-manipulation carve-out), then re-indexes so
// the canonical file-derived order confirms the optimistic one. Refusal/failure rolls the visible
// order back and surfaces the standard write error. Single-flight: one reorder write at a time.

@MainActor
extension AppState {

    // MARK: - Display order (optimistic overlay over the projection order)

    /// The sidebar's group order: the optimistic overlay while a reorder write settles, else the
    /// canonical projection order (which the Kit accessors already sort — research R3).
    var orderedGroups: [AccountGroupProjection] {
        let groups = projections?.accounts.groups ?? []
        guard let order = optimisticGroupOrder else { return groups }
        return Self.applied(order: order, to: groups, id: \.accountGroupId)
    }

    /// A group's account order, with the optimistic overlay while a reorder write settles.
    func orderedAccountIds(in group: AccountGroupProjection) -> [String] {
        guard let order = optimisticAccountOrder?[group.accountGroupId] else { return group.accountIds }
        return Self.applied(order: order, to: group.accountIds, id: \.self)
    }

    /// Reorder `items` by `order`; items missing from `order` keep their relative position after
    /// the ordered ones (mirrors the Kit's explicit-first-then-default rule).
    static func applied<T>(order: [String], to items: [T], id: KeyPath<T, String>) -> [T] {
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        return items.enumerated().sorted {
            (position[$0.element[keyPath: id]] ?? order.count + $0.offset, $0.offset)
                < (position[$1.element[keyPath: id]] ?? order.count + $1.offset, $1.offset)
        }.map(\.element)
    }

    // MARK: - Reorder entry points (drag `.onMove` + context-menu Move up/down)

    /// Move groups within the sidebar (FR-001). `.onMove` signature.
    func reorderGroups(fromOffsets: IndexSet, toOffset: Int) {
        var ids = orderedGroups.map(\.accountGroupId)
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        applyReorder(orderedIds: ids, keyColumn: "account_group_id",
                     relativePath: "Accounts/account-groups.csv",
                     optimistic: { self.optimisticGroupOrder = ids })
    }

    /// Move accounts within one group (FR-002) — the per-group `ForEach` makes cross-group drops
    /// structurally impossible. `.onMove` signature.
    func reorderAccounts(in group: AccountGroupProjection, fromOffsets: IndexSet, toOffset: Int) {
        var ids = orderedAccountIds(in: group)
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        applyReorder(orderedIds: ids, keyColumn: "account_id",
                     relativePath: "Accounts/accounts.csv",
                     optimistic: { self.optimisticAccountOrder = [group.accountGroupId: ids] })
    }

    /// Context-menu "Move up"/"Move down" for a group row (FR-009 keyboard/VoiceOver path).
    func moveGroup(_ groupId: String, by delta: Int) {
        let ids = orderedGroups.map(\.accountGroupId)
        guard let from = ids.firstIndex(of: groupId) else { return }
        let to = from + delta
        guard ids.indices.contains(to) else { return }
        reorderGroups(fromOffsets: IndexSet(integer: from), toOffset: delta > 0 ? to + 1 : to)
    }

    /// Context-menu "Move up"/"Move down" for an account row within its group (FR-009).
    func moveAccount(_ accountId: String, in group: AccountGroupProjection, by delta: Int) {
        let ids = orderedAccountIds(in: group)
        guard let from = ids.firstIndex(of: accountId) else { return }
        let to = from + delta
        guard ids.indices.contains(to) else { return }
        reorderAccounts(in: group, fromOffsets: IndexSet(integer: from), toOffset: delta > 0 ? to + 1 : to)
    }

    // MARK: - Persistence (shared pipeline)

    /// Guard-check + optimistic apply + async persistence. The optimistic overlay is set
    /// synchronously (< 100ms visible update, SC-001); the safe write settles in the background.
    func applyReorder(orderedIds: [String], keyColumn: String, relativePath: String,
                      optimistic: () -> Void) {
        // Single-flight + gate: refuse with the standard feedback, visible order unchanged.
        guard !reorderInFlight else {
            writeError = "A reorder is already being saved — try again in a moment."
            return
        }
        guard writesEnabled, pendingWrite == nil else {
            writeError = writeGateReason ?? "Writing is unavailable right now."
            return
        }
        optimistic()
        reorderInFlight = true                             // latch before the async hop
        Task { @MainActor in
            await self.persistReorder(orderedIds: orderedIds, keyColumn: keyColumn,
                                      relativePath: relativePath)
        }
    }

    /// The persistence half: plan → drift baseline → safe-write apply → re-index. Awaitable so
    /// tests can drive it deterministically. Always releases the single-flight latch and drops
    /// the optimistic overlay — on success the re-indexed file order takes over seamlessly; on
    /// refusal/failure dropping the overlay IS the rollback to the last file-derived order.
    func persistReorder(orderedIds: [String], keyColumn: String, relativePath: String) async {
        defer {
            reorderInFlight = false
            optimisticGroupOrder = nil
            optimisticAccountOrder = nil
        }
        guard let workspaceURL, let text = readWorkspaceFile(relativePath) else { return }
        do {
            let plan = try ReorderPlanBuilder.plan(orderedIds: orderedIds, keyColumn: keyColumn,
                                                   in: relativePath, fileText: text)
            guard let change = plan.changes.first,
                  !(change.rowDiffs.isEmpty && change.headerChange == nil) else { return }   // no-op
            let service = WriteService(workspaceURL: workspaceURL)
            let stamped = service.preview(plan)            // drift baseline; no preview UI (v1.1.2)
            _ = try service.apply(stamped, workspaceState: syncState, fileStates: [:])
            writeError = nil
            await reindex()
            pruneBackups()
        } catch {
            writeError = String(describing: error)
            Diagnostics.workspace.error("reorder failed: \(String(describing: error), privacy: .public)")
        }
    }
}
