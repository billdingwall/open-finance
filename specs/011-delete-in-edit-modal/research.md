# Phase 0 Research: Delete Inside the Edit Modal (UV-2)

**Date**: 2026-07-11 · **Spec**: [spec.md](spec.md) · Findings from direct code inspection on
branch `010-reorder-and-delete`.

## R1 — The delete pipeline already exists end-to-end; only the entry point is missing

**Decision**: Reuse `AppState.requestDelete(_ ref: SourceRef)` verbatim
(`AppState+WriteFlows.swift:138`) — it already performs the reference scan
(`ReferenceScanner`), opens the reassignment picker when references exist
(`pendingReassignment` → `ReassignmentPickerView`), builds the atomic delete+reassignment plan
(`applyReassignments`), and hands everything to the standard write preview (`presentWrite`).
The detail pane calls exactly this (`DetailPaneView.swift:44`).

**Rationale**: SC-002 demands zero behavioral divergence between the two entry points — calling
the same function is the strongest possible guarantee. No new delete semantics are written.

**Alternatives considered**: a parallel delete path for forms — rejected outright (spec FR-002,
"never a bare row delete"; would have to re-implement scanning/atomicity and could drift).

## R2 — Bridging the form context to the pipeline

**Decision**: `EntityEditContext` already carries `relativePath` + `rowRef` (nil ⇒ add mode).
The Delete action closes the form and calls
`requestDelete(SourceRef(filePath: context.relativePath, rowNumber: context.rowRef, provenance: .userEdited))`
after a runloop hop — the exact pattern `finishEditForm` uses so one sheet fully dismisses
before the next (picker or preview) presents.

**Rationale**: `requestDelete` re-reads the file fresh (`readWorkspaceFile` → `dataLine`), so
the delete acts on the on-disk row — unsaved form edits are naturally discarded and the preview
shows the actual row being removed (spec edge case), and drift protection stays intact.

## R3 — Scope whitelist and add-mode suppression

**Decision**: The Delete action renders only when `!context.isNew` **and**
`context.relativePath` ∈ {`Accounts/accounts.csv`, `Accounts/account-groups.csv`,
`Budget/categories.csv`} — a small constant on the form (the generic `EntityEditForm` also
serves goals/budgets/assets/… which are out of scope per the spec).

**Rationale**: spec FR-001 names exactly three entity types; `isNew` covers US1-AS4. Note
`AppState.parentSubtype(forFile:)` already maps all three paths, so reference scanning works for
each.

## R4 — Destructive styling and gating

**Decision**: Leading-aligned in the form's footer (opposite Save/Cancel — FR-005 separation),
`Button(role: .destructive)` with the existing `err` semantic token for the label tint,
`SecondaryButtonStyle` chrome (matches the detail pane's Edit/Delete pair). Disabled with
`state.writeGateReason` help text when `!state.writesEnabled` (FR-004 / SC-005), mirroring the
sidebar "New group" affordance treatment.

**Rationale**: native-first (`role: .destructive` gives system semantics incl. VoiceOver),
single-accent rule preserved — red stays reserved for money/severity/destruction. DESIGN.md's
`modal-form` row doesn't yet mention a destructive action placement → a one-line amendment +
Changelog entry ships with the feature (DA-011-1, gated before the UI task).

**No preview exemption**: deletes keep the full preview-before-apply; the constitution v1.1.2
direct-manipulation carve-out explicitly excludes form/destructive flows.
