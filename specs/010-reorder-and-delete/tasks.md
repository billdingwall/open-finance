# Tasks: Manual Re-ordering of Accounts & Account Groups (UV-1)

**Input**: Design documents from `/specs/010-reorder-and-delete/`
**Prerequisites**: plan.md, spec.md, research.md (R1–R7), data-model.md, contracts/, quickstart.md

**Tests**: Included — the spec's success criteria demand them explicitly (SC-003 "atomicity
verified by test", SC-005 degradation, SC-001 perf budget) and quickstart.md names the suites.

**Organization**: Doc amendments (spec DA-001…DA-004) form Setup; the persistence + canonical-
order core is Foundational (every story depends on it); then one phase per user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 (reorder groups), US2 (reorder accounts in group), US3 (all surfaces mirror)

## Path Conventions

Swift Package layout per plan.md: `Sources/FinanceWorkspaceKit/`, `Sources/FinanceWorkspaceApp/`,
`Tests/`, guiding docs at `docs/` + `DESIGN.md`.

---

## Phase 1: Setup — doc amendments (spec DA-001…DA-004)

**Purpose**: land the guiding-doc changes the feature is contractually tied to. **T001 (DA-004)
gates every UI task** — the design-adherence gate cannot pass without the pattern existing.

- [X] T001 Implement spec DA-004 — add the **list drag-reorder pattern** to `DESIGN.md` (Components table row +
      Do's/Don'ts note + Changelog entry): drag affordance on sidebar rows, system drop
      indicator, context-menu "Move up"/"Move down" fallback, disabled-while-gated treatment
      matching the "New group" affordance, drop-settle in the 80–120ms motion tier. Then run
      `/design-adherence` against the planned `NavigationSidebarView` change.
- [X] T002 [P] Implement spec DA-001 — amend `docs/architecture/containers-and-budgets.md`: add
      `sort_order | integer | Optional — display ordering` to §3.21 (accounts.csv, note scope =
      within `account_group_id`) and §3.14 (account-groups.csv), mirroring the §3.3 categories
      wording exactly.
- [X] T003 [P] Implement spec DA-002 — amend `docs/product-requirements.md` (+ Changelog entry): add the
      user-defined manual ordering concept for account groups and accounts (sidebar drag +
      context menu, plain-file `sort_order` persistence, default-order fallback, all surfaces
      share the canonical order).
- [X] T004 [P] Implement spec DA-003 — amend `docs/product-roadmap.md`: add UV-1 and UV-2 rows to the
      **Growth → Readying** table (Branch/spec = `010-reorder-and-delete`, status = in build);
      note the on-merge obligation (move to Delivered, close backlog rows).

**Checkpoint**: docs agree with the spec; design gate cleared for the sidebar change.

---

## Phase 2: Foundational — schema, models, canonical order (blocks all stories)

**Purpose**: the `sort_order` column exists end-to-end (schema → parse → model → accessor →
engine) and the canonical composite order `(sortOrder ?? Int.max, defaultKey)` is applied once
at the `WorkspaceContext` accessor choke point (research R3). No UI yet.

**⚠️ CRITICAL**: no user-story phase can begin until this phase is complete.

- [X] T005 [P] Add optional integer `sort_order` column to
      `Sources/FinanceWorkspaceKit/Resources/Schemas/accounts.schema.json` (no `schema_version`
      bump — research R1).
- [X] T006 [P] Add optional integer `sort_order` column to
      `Sources/FinanceWorkspaceKit/Resources/Schemas/account-groups.schema.json` (no bump).
- [X] T007 Add `sortOrder: Int?` to `Account` and `AccountGroup` (trailing optional init
      parameters, default `nil`) in
      `Sources/FinanceWorkspaceKit/Domain/Accounts/AccountModels.swift`.
- [X] T008 Map `sort_order` → `sortOrder` in `RecordMappers.account` and
      `RecordMappers.accountGroup`, and sort the `WorkspaceContext.accounts` /
      `WorkspaceContext.accountGroups` accessors by the composite key
      `(sortOrder ?? Int.max, id)` in
      `Sources/FinanceWorkspaceKit/Domain/Mapping/RecordMappers.swift` (data-model.md; invalid
      values already normalize to `nil` with a warning — research R7; depends on T007).
- [X] T009 Preserve accessor order in `AccountEngine`
      (`Sources/FinanceWorkspaceKit/Domain/Accounts/AccountEngine.swift`): group projections
      iterate groups in accessor order (replace `byGroup.keys.sorted()` at ~line 205) and
      `accountIds` keeps accessor order within each group (replace `.sorted()` at ~line 226)
      (depends on T008).
- [X] T010 Implement the reorder plan builder in the Kit: given a target file, the ordered IDs,
      and the current parsed rows, emit a `WritePlan` (intent `.edit`) with one
      `WriteRowDiff.modify` per row whose `sort_order` changes, stamping gap-of-10 values
      (`10, 20, 30, …`) across the whole scope and touching **no other cell** — new
      `Sources/FinanceWorkspaceKit/Persistence/Write/ReorderPlanBuilder.swift` reusing
      `WritePlanBuilder`/`CSVRowSerializer` (research R5; depends on T008).
- [X] T011 [P] Kit unit tests for ordering + degradation in
      `Tests/FinanceWorkspaceKitTests/Unit/SortOrderTests.swift`: composite-key accessor order
      (explicit first, unordered after in ID order), duplicate values tie-break
      deterministically, non-integer/negative → `nil` + warning (never an error), engine
      projections preserve accessor order, and orphan group IDs (present in `accounts.csv` but
      absent from `account-groups.csv`) sort after all known groups in ID order (SC-004, SC-005;
      depends on T008–T009).
- [X] T012 [P] Kit unit tests for the reorder plan in
      `Tests/FinanceWorkspaceKitTests/Unit/ReorderPlanTests.swift`: gap-of-10 stamping of the
      full scope on first reorder, compaction on re-reorder, only-`sort_order`-cell diffs,
      account scope limited to one group's rows, round-trip (apply plan via `WriteService` to a
      temp workspace → reparse → same order; atomicity per SC-003; depends on T010).

**Checkpoint**: `swift build` + Kit tests green; canonical order works end-to-end from file to
projection with no UI.

---

## Phase 3: User Story 1 — Reorder account groups in the sidebar (Priority: P1) 🎯 MVP

**Goal**: drag a group to a new sidebar position (or context-menu Move up/down); order applies
< 100ms, persists via safe write ≤ 1s, survives relaunch, blocked cleanly while writes are gated.

**Independent Test**: quickstart.md steps 1–2 — drag a group in a fixture workspace, confirm
sidebar + relaunch + `account-groups.csv` gap-of-10 values + timestamped backup.

### Implementation for User Story 1

- [X] T013 [US1] Add the reorder entry point to AppState — new
      `Sources/FinanceWorkspaceApp/AppState+Reorder.swift`: `reorderGroups(moving:to:)` computes
      the new ID order, applies it optimistically to the displayed projections, builds the plan
      via `ReorderPlanBuilder`, applies through the existing `WriteService.apply` path (gate +
      backup + atomic + drift), rolls back the optimistic order and surfaces the standard
      write-error on refusal/failure, then triggers the standard projection refresh. Enforce
      **single-flight**: while a reorder write is in flight (or any write is pending/previewing),
      further reorders are refused with the standard busy feedback (spec Edge Cases; research
      R5/R6; contracts/reorder-interaction.md rules 1, 4, 6).
- [X] T014 [US1] Restructure the Account-groups section of
      `Sources/FinanceWorkspaceApp/UI/Shell/NavigationSidebarView.swift` into nested `ForEach`es
      (outer = groups, inner = that group's accounts) preserving current rows, tags, counts, and
      the "New group" affordance (research R4 — prerequisite for `.onMove`; requires T001
      design gate).
- [X] T015 [US1] Wire group reordering in `NavigationSidebarView.swift`: `.onMove` on the outer
      groups `ForEach` → `state.reorderGroups`, `.moveDisabled(!state.writesEnabled)`, and
      context-menu "Move up"/"Move down" items on group rows (disabled with
      `state.writeGateReason` help text when gated) calling the same entry point (FR-001,
      FR-009; depends on T013, T014).
- [X] T016 [P] [US1] App tests in
      `Tests/FinanceWorkspaceAppTests/ReorderFlowTests.swift`: `reorderGroups` persists
      gap-of-10 values and refreshed projections show the new order; gate-blocked reorder is
      refused with unchanged order (rollback); a failed write leaves the file untouched
      (pre-write state) — reuse `AppFixtures` (US1 acceptance scenarios 1–4; depends on T013).

**Checkpoint**: US1 fully functional — groups reorder, persist, survive relaunch, refuse cleanly
when gated. Ship-able MVP.

---

## Phase 4: User Story 2 — Reorder accounts within a group (Priority: P2)

**Goal**: drag an account to a new position inside its own group; cross-group drops are
structurally impossible; only the affected group's rows get stamped.

**Independent Test**: quickstart.md step 3 — drag an account within a group, attempt a
cross-group drop (refused), check `accounts.csv` scope-limited `sort_order`.

### Implementation for User Story 2

- [X] T017 [US2] Add `reorderAccounts(in:moving:to:)` to
      `Sources/FinanceWorkspaceApp/AppState+Reorder.swift`: same optimistic-apply → plan →
      safe-write → rollback pipeline against `Accounts/accounts.csv`, scope = the group's
      accounts only (FR-002, FR-006; depends on T013's shared plumbing).
- [X] T018 [US2] Wire account reordering in
      `Sources/FinanceWorkspaceApp/UI/Shell/NavigationSidebarView.swift`: `.onMove` on each
      group's inner accounts `ForEach` → `state.reorderAccounts(in:…)` (the per-group `ForEach`
      structurally prevents cross-group drops — US2-AS2), `.moveDisabled` gating, and
      context-menu Move up/down on account rows (depends on T015, T017).
- [X] T019 [P] [US2] Extend `Tests/FinanceWorkspaceAppTests/ReorderFlowTests.swift`: within-group
      reorder stamps only that group's rows (other groups' accounts keep no/old `sort_order`);
      mixed state renders ordered-first-then-default (US2 acceptance scenarios 1 & 3; depends on
      T017).

**Checkpoint**: US1 + US2 work independently; sidebar reordering complete.

---

## Phase 5: User Story 3 — Every surface mirrors the canonical order (Priority: P3)

**Goal**: card grids, per-group listings, pickers, and edit-form dropdowns all render in the
canonical order — structurally guaranteed by the Phase-2 accessor sort, so this phase is
**audit + fix + prove**, not new plumbing.

**Independent Test**: quickstart.md step 4 — after reordering, Accounts module cards/rows and
any picker/dropdown match the sidebar.

### Implementation for User Story 3

- [X] T020 [US3] Audit every view/picker that enumerates accounts or groups for local re-sorting
      or direct dictionary iteration that bypasses accessor order — first `ls
      Sources/FinanceWorkspaceApp/UI/` and sweep the **actual** module directories (expected:
      `UI/Accounts/`, `UI/Write/EntityEditForms.swift`, `UI/Write/ReassignmentPickerView.swift`,
      `UI/Write/ImportView.swift`, `UI/Write/TransactionGroupEditor.swift`, the Overview module
      views; names unverified — trust the listing, not this list) — and fix any offender to
      consume projection/accessor order (FR-008; depends on Phase 2).
- [X] T021 [P] [US3] Add order-agreement tests in
      `Tests/FinanceWorkspaceAppTests/OrderMirroringTests.swift`: with a reordered fixture
      workspace, assert `AccountEngine` projections, picker option lists, and edit-form dropdown
      sources all equal the accessor order (SC-004; depends on T020).

**Checkpoint**: no surface anywhere can show a competing order.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T022 [P] Perf test in `Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift`:
      reorder plan build + safe-write apply completes ≤ 1s on the perf fixture workspace
      (SC-001; depends on T010).
- [X] T023 [P] Byte-identical regression test in
      `Tests/FinanceWorkspaceKitTests/Unit/SortOrderTests.swift`: bootstrapping + scanning a
      workspace that was never reordered leaves `accounts.csv`/`account-groups.csv` without a
      `sort_order` column and byte-identical (SC-002).
- [ ] T024 Run the full quickstart.md manual walkthrough (steps 1–8) against a fixture workspace
      via `swift run FinanceWorkspaceApp`; fix anything surfaced. This walkthrough is the manual
      verification of SC-001's <100ms visible-reorder half (the ≤1s write half is automated in
      T022). **Status 2026-07-10**: the automatable subset ran green (bootstrap → hand-stamped
      `sort_order` flips `accounts-overview` group order; `validate-workspace` 0 warnings); the
      in-app drag pass is codified as test-plans.md **Flow 11** and awaits a human at the GUI.
- [X] T025 [P] Update `docs/test-plans.md`: add the sidebar-reorder user flow (drag + context
      menu + gating + hand-edit tolerance) to the manual flows and testability status.
- [X] T026 Close out per CLAUDE.md "On spec completion": add any consciously skipped items from
      this spec to `docs/product-backlog.md` (Source = spec 010 + task), and verify
      `swiftlint --strict` + `swift build` are clean before push.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup/docs)**: T002–T004 immediately, in parallel; T001 immediately (required
  before T014/T015/T018 — the UI tasks).
- **Phase 2 (Foundational)**: independent of Phase 1 except no UI; T005/T006 parallel → T007 →
  T008 → T009/T010 → T011/T012. **Blocks all user stories.**
- **Phase 3 (US1)**: after Phase 2 + T001. T013 → T014 → T015; T016 after T013.
- **Phase 4 (US2)**: after US1's T013/T014 (shared plumbing + structure). T017 → T018; T019
  after T017.
- **Phase 5 (US3)**: after Phase 2 only (can run parallel to US1/US2 — different files, except
  confirm no overlap on `EntityEditForms.swift` with concurrent work).
- **Phase 6 (Polish)**: T022/T023 anytime after Phase 2; T024–T026 last.

### User Story Dependencies

- **US1 (P1)**: Foundational + T001 only — the MVP.
- **US2 (P2)**: builds on US1's sidebar restructure (T014) and AppState plumbing (T013).
- **US3 (P3)**: Foundational only; independent of US1/US2 (order is projection-level).

### Parallel Opportunities

- T002 + T003 + T004 (doc amendments) alongside T005 + T006 (schemas).
- T011 + T012 (Kit test files) together.
- T016, T019, T021, T022, T023 (distinct test files) in parallel once their dependencies land.
- Phase 5 (US3 audit) in parallel with Phases 3–4 by a second contributor.

---

## Parallel Example: kickoff

```bash
# Wave 1 (all parallel): T001, T002, T003, T004, T005, T006
# Wave 2: T007 → T008 → T009 + T010
# Wave 3 (parallel): T011, T012 — foundation proven; start T013 (US1)
```

---

## Implementation Strategy

**MVP first**: Phases 1+2, then US1 only (T013–T016) → validate via quickstart steps 1–2 →
US1 alone is a demonstrable, ship-able increment (groups reorder + persist). Then US2 (small,
reuses everything), then the US3 audit, then polish. Commit after each task or logical group
(`/speckit-git-commit`); stop at any checkpoint to validate.

**Test counts**: 26 tasks — Setup 4 · Foundational 8 · US1 4 · US2 3 · US3 2 · Polish 5.
