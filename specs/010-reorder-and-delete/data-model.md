# Data Model: Manual Re-ordering of Accounts & Account Groups (UV-1)

**Date**: 2026-07-10 · **Spec**: [spec.md](spec.md) · **Research**: [research.md](research.md)

## File schema changes (canonical, plain-files-first)

### `Accounts/accounts.csv` — add optional column

| Column | Type | Required | Notes |
|---|---|---|---|
| `sort_order` | integer | No | Display ordering **within the account's group** (scope = siblings sharing `account_group_id`). Absent → default order. Mirrors the `categories.csv` §3.3 wording. |

### `Accounts/account-groups.csv` — add optional column

| Column | Type | Required | Notes |
|---|---|---|---|
| `sort_order` | integer | No | Display ordering among all account groups. Absent → default order. |

- **No `schema_version` bump, no migration** — optional column is non-breaking (constitution
  File & Schema Conventions; research R1).
- Bundled schema JSONs updated in lockstep: `accounts.schema.json`, `account-groups.schema.json`
  (`Sources/FinanceWorkspaceKit/Resources/Schemas/`).
- Architecture doc §3.21 / §3.14 amended identically (spec DA-001).

## Value semantics

- **Written values**: gap-of-10 integers (`10, 20, 30, …`), unique within scope, re-stamped
  (compacted) on every reorder write in that scope (research R5). Every row in the affected
  scope receives an explicit value on first reorder (FR-006).
- **Read tolerance** (FR-007): non-integer / negative → `nil` (default order) + existing
  normalizer warning. Duplicates → deterministic tie-break by default key. Gaps → harmless.
- **Default order** (absent values): groups by `account_group_id` ascending; accounts by
  `account_id` ascending within group (research R2).
- **Composite sort key** (canonical, applied once — research R3):
  `(sortOrder ?? Int.max, defaultKey)` — explicitly ordered rows first, unordered rows after in
  default order (spec US2-AS3).

## Swift model changes

### `Account` (`Domain/Accounts/AccountModels.swift`)

| Field | Type | Change |
|---|---|---|
| `sortOrder` | `Int?` | **New** — optional, last position in initializer default `nil` |

### `AccountGroup` (`Domain/Accounts/AccountModels.swift`)

| Field | Type | Change |
|---|---|---|
| `sortOrder` | `Int?` | **New** — optional, initializer default `nil` |

### Mappers (`Domain/Mapping/RecordMappers.swift`)

- `RecordMappers.account` / `RecordMappers.accountGroup`: read `sort_order` → `Int?`.
- `WorkspaceContext.accounts` / `WorkspaceContext.accountGroups`: return sorted by the composite
  key. **This is the single ordering choke point** — engines/views preserve, never re-sort by ID.

### Engine order preservation (`Domain/Accounts/AccountEngine.swift`)

- Group projections: iterate groups in accessor order (replace `byGroup.keys.sorted()`).
- `accountIds` within a group projection: accessor order (replace `.sorted()`).
- No other engine sorts accounts/groups by ID for display (verified by inspection; a test
  asserts projection order == accessor order).
- **Orphan groups**: group IDs referenced by accounts but absent from `account-groups.csv` sort
  after all known groups, in default (ID) order — today's behavior for them is preserved; they
  are not reorderable until the group row exists.

## Relationships & invariants

- `sort_order` on an **account** is meaningful only relative to siblings with the same
  `account_group_id`; moving an account between groups (out of scope here — edit flow / UV-2
  territory) leaves its `sort_order` subject to the mixed-values rule in the new group.
- `sort_order` on a **group** is global across all groups.
- Reordering MUST NOT change any other cell — a reorder `WritePlan` contains only
  `WriteRowDiff.modify` diffs whose before/after differ solely in the `sort_order` cell.
- No state machine / lifecycle: the attribute is a plain optional value with no transitions.

## Write plan shape (reorder)

| Aspect | Value |
|---|---|
| Intent | `.edit` |
| Target file | `Accounts/account-groups.csv` (group move) or `Accounts/accounts.csv` (account move) |
| Diffs | one `modify` per row whose `sort_order` changes (first reorder: all rows in scope) |
| Gate | standard `WriteGate` (sync state, read-only) |
| Backup | standard timestamped backup, always |
| Preview UI | none (clarified 2026-07-09); plan is still constructed and logged like any write |
