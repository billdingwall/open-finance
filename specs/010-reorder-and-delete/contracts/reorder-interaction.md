# Contract: sidebar reorder interaction (UI)

The user-facing behavioral contract for `NavigationSidebarView` (and consumers of the canonical
order). DESIGN.md gains the corresponding pattern before UI work (spec DA-004).

## Affordances

| Surface | Gesture | Result |
|---|---|---|
| Sidebar › Account groups › group row | drag to new position among groups | groups reordered |
| Sidebar › group › account row | drag to new position **within the same group** | accounts reordered |
| Any of the above rows | context menu → "Move up" / "Move down" | single-step reorder (keyboard/VoiceOver path) |

## Rules

1. **Immediate apply, no preview sheet** — visible order updates < 100ms after drop; the safe
   write (backup + atomic apply) completes ≤ 1s on a typical workspace.
2. **Cross-group drops are structurally impossible** — an account drag cannot land in another
   group; group membership changes stay in the edit form.
3. **Write gating** — while writes are blocked (syncing, read-only, pending write), drag handles
   are disabled (`moveDisabled`) and context-menu items are disabled with the standard gate
   reason in the help/tooltip, matching the "New group" affordance pattern.
4. **Failure rollback** — if the persistence write is refused or fails, the optimistic order
   rolls back to the last file-derived order and the standard write-error surface is shown.
5. **Order propagation** — after a successful reorder, every surface listing groups/accounts
   (sidebar, Accounts module cards/lists, pickers, edit-form dropdowns) reflects the new order
   on its next render; no surface ever shows a competing order.
6. **External truth** — a rescan (sync change, manual refresh) re-derives order from the files;
   file content always wins over in-memory state.
7. **Motion** — per DESIGN.md motion rules: restrained, no decorative animation; the drop
   settle uses the standard 80–120ms transition tier.
