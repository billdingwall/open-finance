# Feature Specification: Manual Re-ordering of Accounts & Account Groups (UV-1)

**Feature Branch**: `010-reorder-and-delete`
**Created**: 2026-07-09
**Status**: Draft
**Input**: User description: "Manual re-ordering of accounts & account groups in the sidebar (backlog UV-1): drag-reorder groups and the accounts within them in NavigationSidebarView; persist as optional sort_order columns on accounts.csv/account-groups.csv (plain-files-first, additive/non-breaking); reorder writes via the safe-write path; absent values keep today's default order; card grids mirror sidebar order"

## Clarifications

### Session 2026-07-09

- Q: Should drag-reorder writes show the modal write-preview sheet or apply immediately? → A: No preview — drag applies immediately with timestamped backup + atomic write + full write gating; the gesture's live visual feedback is the preview, and re-dragging reverts.
- Q: Which surfaces follow the user-defined order? → A: All surfaces — the canonical order is applied once where projections are built, so every list of accounts/groups app-wide (sidebar, card grids, dropdowns, pickers) shows the same order.
- Q: Should reordering support system Undo (⌘Z)? → A: No — re-dragging (or context-menu Move up/down) is the revert path; timestamped backups cover recovery. ⌘Z undo is out of scope for this feature.

### Session 2026-07-10

- Q: What are the measurable latency targets for a reorder? → A: Visible reorder within 100ms of drop; the safe write (backup + atomic apply) completes within 1s on a typical workspace.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reorder account groups in the sidebar (Priority: P1)

A user with several account groups (e.g., Everyday, Savings, Investments, Business) wants the
groups they check most often at the top of the sidebar. They drag a group to a new position in
the sidebar's Account groups section, the list reflects the new order immediately, and the order
survives quitting and relaunching the app — because it is recorded in the workspace's own files,
it also follows them to any other device opening the same workspace.

**Why this priority**: Group order is the most visible ordering in the app — it drives the
sidebar, and the sidebar drives daily navigation. Today's fixed alphabetical-by-identifier order
forces users to scan past groups they rarely use. This is the core of the backlog item and is
independently shippable.

**Independent Test**: With a workspace containing 3+ account groups, drag one group to a new
sidebar position; confirm the sidebar updates, the order persists across app relaunch, and the
workspace file for account groups records the new order in a plain, human-readable way.

**Acceptance Scenarios**:

1. **Given** a workspace with groups displayed in default order, **When** the user drags a group
   to a new position in the sidebar, **Then** the sidebar shows the new order immediately and the
   new order is persisted to the account-groups file via a safe write (timestamped backup +
   atomic apply).
2. **Given** a user has reordered groups, **When** they quit and relaunch the app, **Then** the
   groups appear in the user's chosen order.
3. **Given** a workspace whose account-groups file has no ordering values (e.g., created before
   this feature), **When** the app opens it, **Then** groups appear in today's default order and
   the file is not modified until the user actually reorders something.
4. **Given** writes are currently blocked (workspace syncing or read-only), **When** the user
   attempts to drag a group, **Then** the reorder is refused with the same feedback pattern as
   other blocked writes, and the displayed order is unchanged.

---

### User Story 2 - Reorder accounts within a group (Priority: P2)

A user wants their primary checking account listed before a rarely-used secondary account inside
the same group. They drag an account to a new position within its group in the sidebar; the order
updates, persists, and travels with the workspace.

**Why this priority**: Same value as US1 one level down the hierarchy. Depends on the same
persistence mechanism, but is separately testable and separately useful — a user who only
reorders accounts inside one group still gets value.

**Independent Test**: With a group containing 3+ accounts, drag an account to a new position
within the group; confirm sidebar order, persistence across relaunch, and the plain-file record.

**Acceptance Scenarios**:

1. **Given** a group with multiple accounts, **When** the user drags an account to a new position
   within that group, **Then** the sidebar shows the new order immediately and the accounts file
   records it via a safe write.
2. **Given** an account being dragged, **When** the user attempts to drop it into a *different*
   group, **Then** the drop is not accepted — reordering never changes an account's group
   membership (group re-assignment stays in the edit flow).
3. **Given** a group where only some accounts have ordering values (e.g., a new account was added
   after the user last reordered), **Then** ordered accounts appear first in their chosen order
   and unordered accounts follow in today's default order.

---

### User Story 3 - Card grids mirror sidebar order (Priority: P3)

A user who has arranged groups and accounts in the sidebar sees the same order everywhere those
entities are listed as cards or rows — the Accounts module's group cards and per-group account
lists follow the sidebar's order, so the app feels like one coherent arrangement rather than two
competing ones.

**Why this priority**: Consistency polish on top of US1/US2. Valuable, but the persistence and
sidebar interaction must exist first; if this slips, the sidebar ordering alone still delivers
the core value.

**Independent Test**: After reordering groups and accounts in the sidebar, open the Accounts
module and confirm group cards and account rows render in the same order.

**Acceptance Scenarios**:

1. **Given** a user-defined group order, **When** the Accounts module renders group cards/sections,
   **Then** they appear in the same order as the sidebar.
2. **Given** a user-defined account order within a group, **When** that group's accounts are
   listed in the Accounts module, **Then** they appear in the same order as the sidebar.
3. **Given** a user-defined order, **When** accounts or groups appear in any picker or edit-form
   dropdown elsewhere in the app, **Then** they appear in the same canonical order.

---

### Edge Cases

- **Duplicate ordering values** (e.g., a user hand-edits the CSV and gives two groups the same
  value): the app renders deterministically — ties break by today's default order — and no error
  is raised; the next in-app reorder rewrites clean, unique values.
- **Non-numeric or negative ordering values** from hand edits: treated as absent (default order)
  for that row; surfaced as a validation *warning*, never an error that blocks loading.
- **New entity created after ordering exists**: appears after all explicitly ordered entities, in
  default order relative to other unordered entities, until the user reorders again.
- **Entity deleted or reassigned**: remaining ordering values keep working; gaps in the sequence
  are harmless and are compacted on the next reorder write.
- **Reorder attempted while a write is already pending/previewing**: refused with the standard
  busy/blocked feedback; the visible order never gets ahead of what was actually persisted.
- **External change to order while the app is open** (e.g., sync delivers a reordered file):
  the next workspace rescan reflects the file's order — files remain the source of truth.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to reorder account groups by dragging them within the sidebar's
  Account groups section.
- **FR-002**: Users MUST be able to reorder accounts by dragging them within their own group in
  the sidebar; a drag MUST NOT move an account into a different group.
- **FR-003**: The chosen order MUST be persisted as an optional, additive ordering column on the
  workspace's account-groups and accounts files — existing workspaces without the column MUST
  load unchanged, and files written by this feature MUST remain readable by tools that ignore
  the new column (non-breaking).
- **FR-004**: Every reorder persistence MUST go through the established safe-write path
  (timestamped backup + atomic apply) and MUST respect the same write gating as other writes
  (blocked while the workspace is syncing, read-only, or otherwise refused). Reorder writes
  MUST apply immediately on drop — no modal preview sheet; the drag's live visual feedback is
  the confirmation, and re-dragging reverts.
- **FR-005**: Entities without an ordering value MUST render in today's default order; when
  explicit and absent values coexist, explicitly ordered entities come first, followed by
  unordered entities in default order.
- **FR-006**: A reorder write MUST assign explicit, unique ordering values to every entity in the
  affected scope (all groups, or all accounts of the affected group), so the resulting file is
  self-describing.
- **FR-007**: Invalid ordering values encountered in files (duplicates, non-numeric, negative)
  MUST degrade gracefully per the Edge Cases above and MUST NOT block workspace loading.
- **FR-008**: Every surface that lists account groups or accounts — the Accounts module's card
  grids and per-group listings, pickers, edit-form dropdowns, and any other enumeration — MUST
  render in the same canonical order as the sidebar (order applied once at the projection level,
  not per-view).
- **FR-009**: Users MUST have a pointer-free way to reorder (e.g., context-menu "Move up"/"Move
  down" on groups and accounts) so the feature is fully keyboard/VoiceOver accessible.
- **FR-010**: The reordered arrangement MUST survive app relaunch and workspace rescans, and MUST
  be visible on any device that opens the same workspace files.

### Key Entities

- **Account Group**: the sidebar's top-level grouping of accounts; gains an optional ordering
  attribute controlling its position among groups.
- **Account**: a member of exactly one group; gains an optional ordering attribute controlling
  its position *within* its group (ordering is meaningful only relative to siblings).
- **Ordering value**: an optional per-row attribute in the workspace's plain files; absent means
  "use default order"; written values are unique within their scope.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can move a group or account to a new position in a single drag gesture (or
  two context-menu actions). The visible order updates within 100ms of the drop, the safe write
  completes within 1s on a typical workspace, and the persisted order survives relaunch 100% of
  the time.
- **SC-002**: 100% of pre-existing workspaces (no ordering column) open with byte-identical files
  and unchanged visible order — zero migration required.
- **SC-003**: Every reorder leaves a timestamped backup of the modified file, and an interrupted
  write never produces a partially reordered or corrupted file (atomicity verified by test).
- **SC-004**: Sidebar, Accounts-module, and picker/dropdown orderings agree in 100% of rendered
  states after any sequence of reorders — no surface anywhere shows a competing order.
- **SC-005**: A hand-edited file with duplicate or invalid ordering values still loads with a
  deterministic order and at most a warning — never a load failure.

## Doc Amendments Required *(carry into plan & tasks as explicit tasks)*

Reviewed against the guiding docs on 2026-07-10. The following amendments are part of this
feature's delivery — `/speckit-plan` MUST emit each as an explicit task:

- **DA-001 — Architecture CSV specs** (`docs/architecture/containers-and-budgets.md`): add the
  optional `sort_order` column to §3.21 `accounts.csv` and §3.14 `account-groups.csv`, mirroring
  the existing §3.3 `categories.csv` wording (`sort_order | integer | Optional — display
  ordering`) — reuse that column name/type/semantics exactly; do not invent a new convention.
- **DA-002 — PRD amendment** (`docs/product-requirements.md` + Changelog): the PRD has no
  user-defined-ordering concept; add a short section covering manual ordering of account groups
  and accounts (per the Growth process, promotion includes the amendment).
- **DA-003 — Roadmap promotion** (`docs/product-roadmap.md` Growth → Readying table): add rows
  for UV-1 (and UV-2, same branch) with branch/spec `010-reorder-and-delete`; on merge, move to
  Delivered and close the backlog rows.
- **DA-004 — DESIGN.md pattern first** (+ Changelog entry): DESIGN.md contains no drag-reorder /
  list-reorder pattern. Before any sidebar UI work, add the pattern — drag affordance,
  drop-indicator treatment, context-menu "Move up"/"Move down" fallback, motion timing — and
  clear the `design-adherence` gate. This task MUST precede UI implementation tasks.

Additional plan-phase notes from the doc review:

- No code parses `sort_order` today — the categories column is documented but inert. UV-1 is the
  first consumer; define the parsing/ordering convention so categories can later adopt it
  (category reordering itself stays out of scope).
- The no-modal-preview decision (Clarifications, 2026-07-09) is compliant under the
  **constitution v1.1.2 direct-manipulation carve-out** (PATCH amended 2026-07-10, resolving
  `/speckit-analyze` finding C1) — live drag feedback satisfies the preview requirement; backup,
  atomicity, gating, and reversibility constraints unchanged.
- No `docs/technical-design.md §21` locked decision touches ordering; no conflicts found.

## Assumptions

- **Default order** today is identifier-sorted (groups by group id, accounts by account id within
  group); "absent values keep today's default order" is interpreted against that behavior.
- **Reordering is workspace-wide, not per-device**: order lives in the shared files, so all
  devices see the same arrangement. No device-local ordering is kept.
- **Scope is groups + accounts only**: sidebar module sections (Overview, Budget, …) and other
  entity lists (categories, goals) are not reorderable in this feature.
- **PRD/schema amendment required**: the ordering column is not yet in the PRD or the
  `docs/architecture/` CSV specs — see **Doc Amendments Required** above (DA-001…DA-004) for the
  explicit task list.
- **Cross-group account moves stay out of scope**: changing an account's group remains an edit-
  form operation (and relates to UV-2 / reassignment flows), not a drag operation.
- **System Undo (⌘Z) is out of scope**: re-dragging or context-menu Move up/down reverts an
  unwanted reorder, and every write leaves a timestamped backup. Formal undo-stack integration
  can be a follow-up backlog item if missed in practice.
