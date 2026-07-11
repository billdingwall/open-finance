# Phase 0 Research: Manual Re-ordering of Accounts & Account Groups (UV-1)

**Date**: 2026-07-10 · **Spec**: [spec.md](spec.md)

All unknowns from the Technical Context are resolved below. Findings are from direct code
inspection on branch `010-reorder-and-delete` (post-PR-#23 main).

## R1 — Parser tolerance for the new `sort_order` column

**Decision**: Add `sort_order` (optional, integer) to the **bundled JSON schemas**
`Sources/FinanceWorkspaceKit/Resources/Schemas/accounts.schema.json` and
`account-groups.schema.json`. No `schema_version` bump, no migration.

**Rationale**: `CSVParserService.parse` maps header cells against the schema's column set; a
header not in the schema emits an `.unknownColumn` **warning** (never an error) and the column's
values are dropped (`CSVParserService.swift:57-62`). So:
- Old app versions reading a reordered workspace: harmless warning, data intact — the additive
  column is non-breaking exactly as the spec requires (SC-002/SC-005 hold).
- The new version must have the column in the bundled schema, or its own parser would warn and
  discard the values it just wrote.
- Constitution File & Schema Conventions: "Adding an optional column is not breaking" — no
  version bump or migration executable needed.

**Alternatives considered**: bumping `schema_version` to 2 + a migration — rejected, explicitly
unnecessary per the constitution for optional columns and would force a pointless migration on
every existing workspace.

**Note**: the bundled `categories.schema.json` does **not** contain `sort_order` even though the
architecture doc (§3.3) specs it — the doc precedent is code-inert today. UV-1 defines the live
convention; adding the column to the categories schema stays out of scope (recorded in spec).

## R2 — Today's default order (the "absent values" fallback)

**Decision**: Default order = lexicographic by stable ID — groups by `account_group_id`
(`AccountEngine.swift:205` sorts `byGroup.keys.sorted()`), accounts within a group by
`account_id` (`AccountEngine.swift:226` sorts `groupAccounts.map(\.accountId).sorted()`).
This is the documented tie-break/fallback everywhere the spec says "default order".

**Rationale**: matches shipped behavior exactly; deterministic; requires no data.

## R3 — Where the canonical order is applied ("all surfaces" clarification)

**Decision**: Apply ordering once at the **typed-accessor layer**:
`WorkspaceContext.accounts` and `WorkspaceContext.accountGroups`
(`RecordMappers.swift:231-232`) return arrays sorted by
`(sortOrder ?? Int.max, defaultKey)`. Downstream engines and views MUST preserve accessor
order instead of re-sorting by ID:
- `AccountEngine` group/account projections (`AccountEngine.swift:205, 226`) switch from
  `keys.sorted()` to the accessor's order.
- Views, pickers, and edit-form dropdowns already consume projections/accessors, so they inherit
  the order with no per-view work — this is what makes the "all surfaces" clarification cheap.

**Rationale**: single choke point (constitution II — read model derived from files); guarantees
SC-004 (no surface can disagree) structurally rather than by auditing every view.

**Alternatives considered**: sorting in each view (rejected: N places to drift), sorting in
`ProjectionStore` only (rejected: pickers that read `context` directly would bypass it).

## R4 — Sidebar drag-reorder mechanism

**Decision**: Restructure the sidebar's Account-groups `DisclosureGroup` content into **nested
`ForEach`es** (outer = groups, inner = that group's accounts) and use SwiftUI's native
**`.onMove`** on each `ForEach`, plus `.moveDisabled(!state.writesEnabled)` for write gating.
Context-menu "Move up" / "Move down" items on each row call the same reorder entry point
(FR-009 accessibility path).

**Rationale**: today `NavigationSidebarView.accountsSection` interleaves group rows and account
rows in a single `ForEach` body (`NavigationSidebarView.swift:65-71`), which cannot express
"move a group block" or "move within a group". Nested `ForEach` + `.onMove` is the native macOS
List reorder affordance (constitution III): system drag visuals, drop indicator, and VoiceOver
integration come free, and the per-group inner `ForEach` structurally prevents cross-group drops
(FR-002 / US2-AS2).

**Alternatives considered**: `.draggable`/`.dropDestination` with a custom `Transferable`
(rejected: re-implements what `onMove` gives natively; needed only for cross-container drags,
which are explicitly out of scope), AppKit `NSOutlineView` bridge (rejected: wholesale shell
rewrite for one affordance).

## R5 — Reorder persistence through the safe-write path

**Decision**: A reorder produces a standard **`WritePlan`** (intent `.edit`) with one
`WriteRowDiff.modify` per row whose `sort_order` cell changes, built via `WritePlanBuilder.edit`
against the target file (`Accounts/account-groups.csv` or `Accounts/accounts.csv`), and applied
through the existing **`WriteService.apply`** (WriteGate check → timestamped backup → atomic
rewrite → drift detection). A new `AppState` entry point (`applyReorder`, in the
`AppState+WriteFlows` family) performs plan-build + apply in one step **without** presenting the
preview sheet, then triggers the standard projection refresh.

The first reorder in a scope stamps **every** row in that scope with explicit unique values
(FR-006): integers `10, 20, 30, …` (gap-of-10, compacted on each reorder write) so hand editors
can insert between rows without renumbering.

**Rationale**: reuses `BackupService`/`WriteGate`/atomic apply untouched (CLAUDE.md: never
reimplement safe-write logic); the only deviation from other flows is skipping the preview *UI*,
which is the clarified product decision (Session 2026-07-09) — the plan/backup/gating machinery
is identical. Gap-of-10 respects Plain Files First (pleasant to hand-edit).

**Alternatives considered**: dense `1,2,3…` numbering (rejected: hostile to hand insertion);
fractional/lexicographic keys (rejected: over-engineering for ≤ dozens of rows, ugly in files).

**Constitution IV tension** (documented for the gate): Principle IV says every write flow shows
target file/rows/backup **before** applying. The clarified decision treats the drag's live
feedback as the preview; backup + atomicity + gating are unchanged. Justified in plan.md
Complexity Tracking — flagged for `/speckit-analyze`.

## R6 — Latency targets (SC-001: 100ms visible / 1s persisted)

**Decision**: The `.onMove` handler updates an optimistic in-memory order immediately
(< 100ms is inherent — no I/O on the render path), then persists asynchronously; on write
failure (gate refusal, drift) the optimistic order is rolled back to the last file-derived
projection and the standard write-error surface is shown. The 1s write budget is asserted by a
performance test against the existing perf fixture workspace (reuse
`Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift`).

**Rationale**: both files are small (dozens of rows); the existing harness already measures
parse/write cycles, so the test is cheap to add. Optimistic-apply-with-rollback keeps the
"visible order never gets ahead of persistence" edge case honest: the UI order is provisional
until the rescan confirms it, and rollback + error surfacing covers refusal.

## R7 — Validation of `sort_order` values (FR-007 / SC-005)

**Decision**: No new validation *rule* in the catalog. Invalid values (non-integer, negative)
are handled at the normalizer/mapper layer exactly like other optional typed columns — the value
maps to `nil` (default order) with the existing per-cell normalization warning. Duplicates are
resolved deterministically by the R3 sort's `defaultKey` tie-break; the next reorder write
rewrites clean values.

**Rationale**: the spec demands graceful degradation with at-most-a-warning; the existing
normalizer warning already provides it. A dedicated VAL- rule would join the six inert rules
(backlog SP-4) — adding catalog surface without user value.
