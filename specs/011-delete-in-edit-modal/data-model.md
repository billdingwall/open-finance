# Data Model: Delete Inside the Edit Modal (UV-2)

**Date**: 2026-07-11 · **Spec**: [spec.md](spec.md) · **Research**: [research.md](research.md)

## File schema changes

**None.** Deleting rows changes no file format; no columns are added, no `schema_version` bump,
no migration, no PRD/architecture schema amendment. (The only doc change is a one-line DESIGN.md
`modal-form` note — see plan DA-011-1.)

## Swift model changes

**None to the Kit.** All value types involved already exist and are reused unchanged:

| Type | Role here | Change |
|---|---|---|
| `EntityEditContext` (App) | carries `relativePath` + `rowRef` (nil ⇒ add) — everything the Delete entry point needs | none |
| `SourceRef` (App) | the bridge into `requestDelete` | none |
| `ReferenceGroup` / `Reassignment` / `ReassignmentModel` | referenced-delete resolution | none |
| `WritePlan` (intent `.delete`) / `FileChange` / `WriteRowDiff.delete` | the atomic plan | none |

## Behavioral invariants (inherited, verified by test)

- A delete plan built from the edit-form entry point is **identical** to one built from the
  detail pane for the same entity (SC-002) — same function, same inputs.
- Required references (account → group) offer reassignment targets only; optional references
  additionally allow unlink (R7 rule, `ReferenceGroup.nullable`).
- Cancel at any stage (form, picker, preview) leaves every file byte-identical (SC-003).
- UV-1 interaction: remaining `sort_order` values stay valid after a delete — gaps are harmless
  per the UV-1 column contract; no renumbering occurs as part of a delete plan.

## UI state additions

**None to `AppState`.** The entry point composes existing state: `editForm = nil` →
`requestDelete(...)` → (`pendingReassignment` | `pendingWrite`). No new stored properties.
