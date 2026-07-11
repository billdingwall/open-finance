# Tasks: Delete Inside the Edit Modal (UV-2)

**Input**: Design documents from `/specs/011-delete-in-edit-modal/`
**Prerequisites**: plan.md, spec.md (+ Clarifications 2026-07-11), research.md (R1–R4),
data-model.md, contracts/delete-in-edit-form.md, quickstart.md

**Tests**: Included — SC-002 ("zero behavioral divergence", verified by test against both
paths), SC-003 (cancel byte-identity), SC-005 (gating), and FR-008 (route resolution) all
demand assertions; quickstart.md names the suite.

**Organization**: One doc-gate task, one shared entry-point task, then one phase per user
story. Deliberately small — research R1: the delete pipeline exists; this feature adds an entry
point.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (delete from form), US2 (referenced delete parity), US3 (honest gating)

## Path Conventions

Swift Package layout per plan.md: `Sources/FinanceWorkspaceApp/`, `Tests/`, `DESIGN.md` at root.

---

## Phase 1: Setup — design-system gate (spec/plan DA-011-1)

**Purpose**: DESIGN.md must sanction the destructive action inside the modal form before any UI
work (non-negotiable design gate).

- [X] T001 Implement DA-011-1 — amend the `modal-form` component row in `DESIGN.md` (front-matter
      `components:` line + body Components table + Changelog entry): destructive Delete action
      placement — leading in the footer, visually separated from Cancel/Save (trailing), system
      destructive role + `err` semantic token, secondary-button chrome, disabled with the
      standard gate reason while writes are blocked. No new tokens. Then run `/design-adherence`
      against the planned `EntityEditForms.swift` change.

**Checkpoint**: design gate cleared for the form change.

---

## Phase 2: Foundational — the shared entry point

**Purpose**: the one bridge every story uses: form context → the existing delete pipeline.

**⚠️ CRITICAL**: blocks all user-story phases.

- [X] T002 Add `requestDeleteFromEditForm(_ context: EntityEditContext)` to
      `Sources/FinanceWorkspaceApp/AppState+WriteFlows.swift`: guard `context.rowRef != nil`,
      set `editForm = nil`, then call `requestDelete(SourceRef(filePath: context.relativePath,
      rowNumber: context.rowRef, provenance: .userEdited))` — the identical function the detail
      pane calls (research R1/R2; SC-002 holds by construction, SC-004: no new delete path
      exists). **Testable shape (analyze M1)**: keep the core synchronous — only the *sheet
      presentation* may hop the runloop (the `finishEditForm` `Task { @MainActor }` pattern),
      so tests can call the function and assert `pendingWrite`/`pendingReassignment`
      deterministically (the UV-1 `persistReorder` lesson).

**Checkpoint**: `swift build` green; the bridge exists with no UI yet.

---

## Phase 3: User Story 1 — Delete an entity from its edit form (Priority: P1) 🎯 MVP

**Goal**: the edit forms for accounts, account groups, and categories offer a destructive
Delete that routes into the standard preview; add mode and out-of-scope forms show nothing.

**Independent Test**: quickstart.md steps 1–2 — delete an unreferenced account from its form
via preview; confirm removal + backup; "New account" form shows no Delete.

### Implementation for User Story 1

- [X] T003 [US1] Add the Delete action to the form footer in
      `Sources/FinanceWorkspaceApp/UI/Write/EntityEditForms.swift`: leading-aligned in the
      existing footer HStack (before the `Spacer()`), `Button("Delete…", role: .destructive)`
      → `state.requestDeleteFromEditForm(context)`, `err`-token tint + `SecondaryButtonStyle`
      chrome; rendered only when `!context.isNew` **and** `context.relativePath` ∈
      {`Accounts/accounts.csv`, `Accounts/account-groups.csv`, `Budget/categories.csv`}
      (an internal — not private — whitelist constant so tests can reference it, analyze L1);
      disabled with `state.writeGateReason` help when `!state.writesEnabled` (FR-001, FR-004,
      FR-005; contracts rules 1–2, 7; requires T001 gate + T002).
- [X] T004 [US1] App tests (new `Tests/FinanceWorkspaceAppTests/DeleteInEditFormTests.swift`):
      `requestDeleteFromEditForm` on an unreferenced account produces the same `pendingWrite`
      plan as `requestDelete` from a detail-pane `SourceRef` for the same row (SC-002); add-mode
      context (`rowRef == nil`) is a no-op; cancelling the pending write leaves every workspace
      file byte-identical via `AppFixture.contentSnapshot()` (SC-003); confirmed apply removes
      the row + creates a backup + refreshed projections drop the entity (FR-007; reuse
      `AppFixtures` + the `ReorderFlowTests` state-setup pattern; depends on T002).

**Checkpoint**: US1 fully functional — deletable from the form with full preview semantics.

---

## Phase 4: User Story 2 — Referenced deletes inherit the reassignment flow (Priority: P2)

**Goal**: deleting a referenced entity from the form opens the same picker → atomic
delete+reassignment plan as the detail-pane path. No new implementation expected — this phase
**proves** the inheritance.

**Independent Test**: quickstart.md steps 3–4 — delete a used category from its form → picker →
atomic apply; group-with-accounts offers reassign-only.

### Implementation for User Story 2

- [X] T005 [US2] Extend `Tests/FinanceWorkspaceAppTests/DeleteInEditFormTests.swift`: deleting a
      category referenced by transactions from the form entry point populates
      `pendingReassignment` with the identical `ReferenceGroup`s as the detail-pane entry point
      (SC-002); deleting an account group that still contains accounts yields a non-nullable
      reference group (reassign-only, FR-006); confirming reassignments produces one atomic plan
      (delete + modifies in a single `WritePlan`); cancelling the picker leaves files
      byte-identical (SC-003; depends on T002; fix any divergence it exposes — none expected).

**Checkpoint**: both entry points provably identical for referenced deletes.

---

## Phase 5: User Story 3 — The Delete action is honest about when it can act (Priority: P3)

**Goal**: gate-disabled with reason, destructive styling, never present where it cannot act.
The implementation landed in T003; this phase asserts it.

**Independent Test**: quickstart.md step 6 — with writes blocked, the form's Delete is disabled
with the gate reason tooltip.

### Implementation for User Story 3

- [X] T006 [P] [US3] Extend `Tests/FinanceWorkspaceAppTests/DeleteInEditFormTests.swift`
      (rewritten per analyze I1 — the entry point must NOT add a gate guard the detail pane
      lacks, or SC-002 parity breaks): with `syncState = .syncing`, the preview still opens
      (parity) but `applyPendingWrite` refuses — `writeError` set, files byte-identical — the
      same inherited apply-time gating as every write; the *button-level* half of FR-004/SC-005
      is T003's disabled state. Plus the whitelist test: `Savings/goals.csv` is not in
      `EntityEditForm`'s whitelist constant; `Accounts/accounts.csv`,
      `Accounts/account-groups.csv`, `Budget/categories.csv` are (depends on T003).

**Checkpoint**: all three stories complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T007 [P] FR-008 route-resolution test in
      `Tests/FinanceWorkspaceAppTests/DeleteInEditFormTests.swift`: set
      `route = .account("A1")` (dedicated screen), delete A1 via the form entry point + apply +
      reindex → route resolves to the nearest valid context (`.accountGroup("G1")` or
      `.accounts` per `AppRouter.resolve`'s fallback); never still `.account("A1")` (spec
      Clarifications 2026-07-11; fix `AppRouter.resolve` only if the assertion exposes a gap).
- [ ] T008 Run the quickstart.md manual walkthrough (steps 1–7) via
      `swift run FinanceWorkspaceApp`; fix anything surfaced (the picker/preview interactions
      and destructive styling are the manual half). **Status 2026-07-11**: codified as
      test-plans.md **Flow 12**; needs a human at the GUI (relaunch the app — instances started
      before this build lack the button).
- [X] T009 Close out per CLAUDE.md "On spec completion": update `docs/test-plans.md` (extend the
      write-flow/testability notes with the in-form delete path), add any consciously skipped
      items to `docs/product-backlog.md` (Source = spec 011 + task), and verify
      `swift build` clean (SwiftLint runs in CI).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (T001)**: immediate; gates T003 only.
- **Phase 2 (T002)**: immediate; blocks T003–T007.
- **Phase 3 (US1)**: T003 after T001+T002; T004 after T002 (parallel with T003 — different files).
- **Phase 4 (US2)**: T005 after T002 (parallel with T003/T004 — test-only).
- **Phase 5 (US3)**: T006 after T003 (whitelist assertion needs the constant).
- **Phase 6**: T007 after T002; T008–T009 last.

### Parallel Opportunities

- T001 ∥ T002 at kickoff (different files).
- T003 ∥ T004 ∥ T005 once T002 lands (view vs. test file — same test file for T004/T005, so
  sequence those two if one author).
- T006 ∥ T007 after T003.

---

## Implementation Strategy

**MVP first**: T001 → T002 → T003 → T004 delivers US1 alone as a ship-able increment (delete an
unreferenced entity from its form). US2/US3 are then almost entirely proof (tests), which is the
point: the feature's risk lives in the entry point, not the pipeline. Commit after each phase;
stop at any checkpoint.

**Task counts**: 9 total — Setup 1 · Foundational 1 · US1 2 · US2 1 · US3 1 · Polish 3.
