# Feature Specification: Delete Inside the Edit Modal (UV-2)

**Feature Branch**: `010-reorder-and-delete` *(shared with UV-1 — PM promotion 2026-07-10)*
**Created**: 2026-07-11
**Status**: Draft
**Input**: User description: "Delete inside the edit modal (backlog UV-2): accounts, account groups, and categories gain a destructive Delete action inside their edit form (EntityEditForm), per the locked R5 'delete inside the edit flow' convention — routed through requestDelete → ReferenceScanner → atomic delete+reassignment plan → write preview; never a bare row delete"

## Clarifications

### Session 2026-07-11

- Q: After a confirmed delete of the entity the user is currently viewing, where should the app navigate? → A: Nearest valid context — the account's group screen, or All accounts if the group also went away (the established stale-route fallback); never a dead screen.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Delete an entity from its edit form (Priority: P1)

A user opens the edit form for an account, account group, or category — the natural place they
manage that object — and decides it should not exist at all. Instead of cancelling, closing the
form, finding the object again, and hunting for a delete affordance elsewhere, they click a
clearly destructive **Delete** action inside the form itself. The standard delete pipeline takes
over: the form closes and the write preview shows exactly which file and row will be removed and
that a timestamped backup will be taken; the user confirms and the object is gone everywhere the
app lists it.

**Why this priority**: This is the whole feature — the locked "delete inside the edit flow"
convention (technical design §13 / R5) promised delete where the user already is, and the edit
modal is the one surface that still lacks it. The delete *pipeline* already exists and works
from the detail pane; only the entry point is missing.

**Independent Test**: Open the edit form for an unreferenced account, delete it via the form's
Delete action, confirm in the write preview; verify the row is gone from the file, a backup
exists, and no list in the app still shows the account.

**Acceptance Scenarios**:

1. **Given** an existing account/account group/category open in its edit form, **When** the user
   activates the form's Delete action, **Then** the form closes and the standard delete write
   preview opens showing the target file, the exact row to be removed, and the backup behavior —
   never an immediate, unpreviewed deletion.
2. **Given** the delete preview is confirmed, **When** the write applies, **Then** the row is
   removed via the safe-write path (timestamped backup + atomic apply), the app re-indexes, and
   the object disappears from every surface (sidebar, cards, tables, pickers).
3. **Given** the delete preview or the form itself is cancelled, **Then** nothing changes in any
   file and the object remains everywhere.
4. **Given** the form is in **add** mode (a new, not-yet-saved entity), **Then** no Delete action
   is present — there is nothing to delete.

---

### User Story 2 - Delete a referenced entity safely (Priority: P2)

A user deletes a category that transactions still point at, an account with ledger rows, or an
account group that still contains accounts. Instead of refusing, silently orphaning rows, or
dropping data, the delete flow surfaces every referencing collection and asks the user to choose,
per collection, where those references should go (reassign to another object, or unlink where
the reference is optional). The delete and all reassignments are then applied together as one
atomic change, shown in a single preview.

**Why this priority**: This is the R7-locked "delete-on-reference = reassign" behavior — it
already works when deleting from the detail pane, and the edit-modal entry point MUST inherit it
unchanged. Second priority only because it composes US1 with existing machinery.

**Independent Test**: From the edit form, delete a category referenced by transactions; verify
the reassignment picker lists the referencing rows, a target can be chosen, and the confirmed
preview applies delete + reassignments atomically (all or nothing).

**Acceptance Scenarios**:

1. **Given** an entity with referencing rows in other collections, **When** the user activates
   Delete in its edit form, **Then** the reassignment picker opens listing every referencing
   collection with row counts, exactly as it does for a detail-pane delete.
2. **Given** the user picks a target (or "leave unlinked" where the reference is optional) for
   each collection, **Then** one write preview shows the deletion and every reassignment
   together, and confirming applies them as a single atomic change — no silent drops, no
   partially applied state.
3. **Given** the user cancels the reassignment picker or the preview, **Then** no file changes.

---

### User Story 3 - The Delete action is honest about when it can act (Priority: P3)

The Delete action inside the form respects the same rules as every other write affordance: while
writes are blocked (workspace syncing, read-only, another write pending), it is disabled with
the standard gate reason shown; it is visually unmistakable as destructive; and it never appears
where it cannot act (add mode).

**Why this priority**: Consistency polish — the app's write affordances all behave this way
(disabled-with-reason, never silently inert), and a destructive action must meet the same bar.

**Independent Test**: Open an edit form while the workspace is syncing; the Delete action is
disabled and its tooltip explains why. Re-enable writes; the action becomes active.

**Acceptance Scenarios**:

1. **Given** writes are gated, **When** the edit form is open, **Then** the Delete action is
   disabled and carries the standard gate reason (tooltip/help), matching other write affordances.
2. **Given** the Delete action is shown, **Then** it is styled as destructive and separated from
   the form's Save/Cancel actions so it cannot be hit by accident.

---

### Edge Cases

- **Deleting an account group that still contains accounts**: accounts reference their group with
  a required reference — the reassignment picker MUST offer other groups as targets (no "unlink"
  for a required reference). If no other group exists, the delete cannot complete; the user is
  told to create/keep a group first rather than being allowed to orphan accounts.
- **Deleting the entity while its rows changed on disk** (sync delivered an edit between opening
  the form and confirming the delete): the standard drift protection refuses the write; the user
  re-opens and retries against current data.
- **Deleting an entity that a pending (unsaved) form edit modified**: Delete acts on the row as
  it exists on disk; unsaved form edits are discarded with the form — the preview always shows
  the actual on-disk row being removed.
- **Entity types other than the three named** (goals, budgets, tax adjustments…): their edit
  forms are out of scope for this feature; existing delete paths (detail pane) are untouched.
- **The reorder column** (`sort_order`, UV-1): deleting a row leaves the remaining values valid —
  gaps are harmless by the UV-1 contract; no renumbering is required as part of the delete.
- **Deleting the entity currently on screen**: after the delete applies, the app navigates to the
  nearest valid context (the deleted account's group screen; All accounts if the group is gone
  too) — never a dead or blank screen for a route whose entity no longer exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The edit forms for accounts, account groups, and categories MUST offer a Delete
  action when editing an existing entity, and MUST NOT offer it when creating a new one.
- **FR-002**: Activating Delete MUST route through the standard delete pipeline — reference scan,
  reassignment picker when references exist, atomic delete+reassignment plan, and the standard
  write preview — identically to a detail-pane delete of the same entity. A bare, unpreviewed row
  delete MUST NOT exist. *(Deletes keep the full preview; the UV-1/v1.1.2 direct-manipulation
  carve-out does not apply to destructive actions.)*
- **FR-003**: The delete write MUST use the safe-write path (timestamped backup + atomic apply +
  sync gating + drift detection), and a cancelled picker or preview MUST leave every file
  byte-identical.
- **FR-004**: The Delete action MUST honor write gating: disabled with the standard gate reason
  while writes are blocked, matching the app's other write affordances.
- **FR-005**: The Delete action MUST be visually destructive and separated from Save/Cancel per
  the design system's conventions for destructive actions.
- **FR-006**: Required references (e.g., an account's group) MUST only be reassignable — never
  unlinked; optional references MAY be left unlinked. (Unchanged R7 rule, inherited.)
- **FR-007**: After a confirmed delete, every surface listing the entity MUST reflect its removal
  on the next render (projection refresh), including pickers and dropdowns.
- **FR-008**: If the deleted entity was the one currently displayed, the app MUST navigate to
  the nearest valid context (e.g. the account's group screen, or All accounts if the group is
  also gone) — a route MUST never keep pointing at a deleted entity.

### Key Entities

- **Account / Account Group / Category**: the three user-addable entities whose edit forms gain
  the in-form Delete entry point; their file representations and reference rules are unchanged.
- **Referencing row**: any row in another collection pointing at the deleted entity; resolved
  per collection via reassignment or (optional references only) unlinking.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can delete an unreferenced entity from its edit form in ≤ 3 interactions
  (Delete → confirm preview), with the row removed, a timestamped backup created, and no surface
  still listing the entity.
- **SC-002**: Deleting a referenced entity from the edit form produces the identical
  picker → preview → atomic-apply behavior as the detail-pane delete of the same entity — zero
  behavioral divergence between the two entry points (verified by test against both paths).
- **SC-003**: 100% of cancels (form, picker, or preview) leave every workspace file
  byte-identical.
- **SC-004**: 0 unpreviewed deletions are possible from any code path introduced by this feature.
- **SC-005**: While writes are gated, the Delete action is disabled with a human-readable reason
  100% of the time (never silently inert, never active).

## Assumptions

- **Scope is exactly the three entity types** named in the backlog (accounts, account groups,
  categories). Other entities' edit forms may adopt the same pattern later; not in this feature.
- **The existing delete pipeline is reused unchanged** — reference scanning, the reassignment
  picker, atomic plan construction, and the write preview shipped in Phase 7/008 and are already
  tested; this feature adds an entry point, not new delete semantics.
- **No doc-schema changes**: deleting rows changes no file formats; no PRD/architecture
  amendment is required beyond the roadmap/backlog close-out on merge. The R5/§13 placement
  convention already names the edit flow as a delete location, so the PRD already sanctions it.
- **DESIGN.md**: the modal-form component contract likely needs a one-line destructive-action
  placement note (design gate will confirm); no new tokens — destructive styling uses the
  existing `err` semantic color.
