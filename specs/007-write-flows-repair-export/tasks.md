---
description: "Task list for Write Flows, Repair & Export (Phase 6)"
---

# Tasks: Write Flows, Repair & Export (Phase 6)

**Input**: Design documents from `specs/007-write-flows-repair-export/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (all present)

**Tests**: INCLUDED — the plan and contracts specify Swift Testing suites (contract + view-model)
that run in macOS CI. The CLT-only dev box runs `swift build`; `swift test` + `swiftlint --strict`
run in CI (per CLAUDE.md testing protocol).

**Organization**: Grouped by user story (US1–US6, priority order) so each is an independently
testable increment. The write-engine core is foundational (blocks every story).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US6; Setup/Foundational/Polish carry no story label
- All paths are repo-relative

## Path Conventions

- Write engine (Kit, CI-testable): `Sources/FinanceWorkspaceKit/Persistence/Write/`
- Write UI (App): `Sources/FinanceWorkspaceApp/UI/Write/` + edited Shell/module views
- Kit tests: `Tests/FinanceWorkspaceKitTests/`; App tests: `Tests/FinanceWorkspaceAppTests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the new source groups. No `Package.swift` change — `Write/` is a subdir of the
existing `FinanceWorkspaceKit` target and `UI/Write/` of the `FinanceWorkspaceApp` target.

- [ ] T001 Create the `Sources/FinanceWorkspaceKit/Persistence/Write/` group with empty
  `WritePlan.swift`, `CSVRowSerializer.swift`, `WriteService.swift`, `ReferenceScanner.swift`,
  `ImportMapper.swift`, `ExportService.swift` (file headers only)
- [ ] T002 [P] Create the `Sources/FinanceWorkspaceApp/UI/Write/` group with empty
  `WritePreviewView.swift`, `EntityEditForms.swift`, `ImportView.swift`, `TransactionGroupEditor.swift`,
  `ReassignmentPickerView.swift` (file headers only)
- [ ] T003 [P] Create test-suite stubs `Tests/FinanceWorkspaceKitTests/WriteEngineTests/` folder with
  empty `WriteServiceTests.swift`, `CSVRowSerializerTests.swift`, `ReferenceScannerTests.swift`,
  `ImportMapperTests.swift`, `ExportServiceTests.swift`, `MultiEntryWriteTests.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The single safe-write path (FR-001–FR-008) that every user story mutates through. Reuses
`BackupService`/`FileCoordinatorService`/`WriteGate`/`ManifestStore` — never reimplements them (FR-002).

**⚠️ CRITICAL**: No user story can begin until this phase is complete.

- [ ] T004 Define the write-engine value types (`WriteIntent`, `WritePlan`, `FileChange`, `RowDiff`,
  `ReferenceGroup`, `Reassignment`, `BackupReference`, `WriteResult`) per data-model.md in
  `Sources/FinanceWorkspaceKit/Persistence/Write/WritePlan.swift`
- [ ] T005 Implement `CSVRowSerializer.applyDiffs` — in-place row edit that preserves the leading
  `# schema_version: N` comment, schema column order, and byte-stability of untouched rows (S2/S4) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/CSVRowSerializer.swift`
- [ ] T006 Implement `WriteService.apply` — `WriteGate.evaluate` check (G3) → `ManifestStore` hash
  drift check (G4) → `BackupService.backup` every touched file (G1) → `FileCoordinatorService`
  atomic coordinated write per `FileChange` (G2) → append `repair-log.csv` entries (G5); plus
  `WriteService.preview` in `Sources/FinanceWorkspaceKit/Persistence/Write/WriteService.swift`
- [ ] T007 [P] Contract tests `WriteServiceTests` — backup-before-write (G1), atomic-failure-leaves-
  original (G2), sync-gate-block (G3), drift-throws (G4), log-appended (G5) against a temp workspace
  in `Tests/FinanceWorkspaceKitTests/WriteEngineTests/WriteServiceTests.swift`
- [ ] T008 [P] Contract tests `CSVRowSerializerTests` framework — empty-diff byte-stability (S2),
  schema order + comment-row preservation (S4) in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/CSVRowSerializerTests.swift`

**Checkpoint**: The safe-write path is proven end-to-end against a temp workspace — user stories can begin.

---

## Phase 3: User Story 1 — Structured object editing with safe writes (Priority: P1) 🎯 MVP

**Goal**: Add/edit/delete the 12 structured-editable entity types through preview → backup → atomic
apply → re-index, from the two documented placement points, plus the ⌘N add-record action and the
in-app Close-Tax-Year action.

**Independent Test**: Add a savings goal (preview shows target file + new row + backup; apply; goal
appears; backup exists), then edit its target amount and delete it — each with a preview and backup.

### Tests for User Story 1

- [ ] T009 [P] [US1] `CSVRowSerializer` round-trip + sign tests (S1/S3) across all 12 entity types in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/CSVRowSerializerTests.swift`
- [ ] T010 [P] [US1] WritePreview view-model tests — apply triggers re-index, cancel is a no-op,
  `driftDetected` → re-preview in `Tests/FinanceWorkspaceAppTests/WritePreviewViewModelTests.swift`

### Implementation for User Story 1

- [ ] T011 [US1] Implement `CSVRowSerializer.row` (entity → canonical row) for all write-target
  entities per the data-model entity→file map (the 12 entities + `SleeveTarget` for sleeve weights) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/CSVRowSerializer.swift`
- [ ] T012 [US1] Add per-intent `WritePlan` builders for simple add/edit/delete (no references yet) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/WritePlan.swift`
- [ ] T013 [P] [US1] Build the shared `WritePreviewView` (intent title, per-file target, before/after
  diff, backup location, Apply/Cancel; drift re-preview; `WriteGate`-reason disable) in
  `Sources/FinanceWorkspaceApp/UI/Write/WritePreviewView.swift`
- [ ] T014 [US1] Build `EntityEditForms` for the 11 right-panel entities (account group, category,
  budget, allocation, goal, asset, liability, portfolio, sleeve, tax-adjustment, account rule) —
  canonical fields only (FR-011); sleeve editing spans `sleeves.csv` + `sleeve-targets.csv`, and the
  tax-adjustment form writes the polymorphic `linked_id` — in
  `Sources/FinanceWorkspaceApp/UI/Write/EntityEditForms.swift`
- [ ] T015 [US1] Enable the `.editForm` surface + panel-bottom Edit/Delete in
  `Sources/FinanceWorkspaceApp/UI/Shell/DetailPaneView.swift` (FR-010 right-panel placement)
- [ ] T016 [US1] Wire Account add/edit (local actions) + delete-inside-edit on the dedicated screen in
  `Sources/FinanceWorkspaceApp/UI/Accounts/AccountDetailView.swift` and `.../AccountsView.swift`
- [ ] T017 [US1] Add the post-write re-index + re-validate hook (rebuild `ProjectionStore` snapshot,
  refresh issues) in `Sources/FinanceWorkspaceApp/AppState.swift`
- [ ] T018 [US1] Add the context-sensitive ⌘N add-record action (active-module primary entity;
  disabled where none) in `Sources/FinanceWorkspaceApp/UI/Shell/AppCommands.swift` + `AppState.swift`
- [ ] T019 [US1] Wire the in-app "Close Tax Year" action → `WritePreviewView` → existing
  `TaxPrepEngine`/`TaxSafeWrite` archive write → re-index (FR-011a) in
  `Sources/FinanceWorkspaceApp/UI/Taxes/CurrentTaxYearView.swift`

**Checkpoint**: The app is writable — all 12 entities add/edit/delete with preview+backup; year-close works. MVP.

---

## Phase 4: User Story 2 — Import external CSV transactions (Priority: P2)

**Goal**: Import a bank/brokerage CSV via column mapping into the correct canonical monthly files
under one chosen account, with duplicates flagged for per-row confirmation.

**Independent Test**: Import a 2-month bank CSV, map columns, pick the target account, confirm — rows
land in the two correct `YYYY-MM.csv` files with backups; duplicates were flagged in the preview.

### Tests for User Story 2

- [ ] T020 [P] [US2] `ImportMapperTests` — required-column block (I1), target-account stamp (I2),
  month-split (I3), duplicate flag on date+amount+description (I4), sign convention (I5),
  included-only plan (I6) in `Tests/FinanceWorkspaceKitTests/WriteEngineTests/ImportMapperTests.swift`
- [ ] T021 [P] [US2] Import view-model tests — required-unmapped blocks advance, duplicates default
  excluded, target account required in `Tests/FinanceWorkspaceAppTests/ImportViewModelTests.swift`

### Implementation for User Story 2

- [ ] T022 [US2] Implement `ImportMapper.autoDetect` + `buildBatch` (mapping, `CSVNormalizer` sign
  convention, month-split, single target-account stamp) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/ImportMapper.swift`
- [ ] T023 [US2] Add duplicate detection (date + amount + description/merchant within target account;
  default excluded) to `Sources/FinanceWorkspaceKit/Persistence/Write/ImportMapper.swift`
- [ ] T024 [US2] Implement `ImportMapper.writePlan` (append only included rows to monthly files, via
  `WriteService`) in `Sources/FinanceWorkspaceKit/Persistence/Write/ImportMapper.swift`
- [ ] T025 [US2] Build the two-step `ImportView` (`fileImporter` → editable mapping + sign control +
  required target-account picker → month-grouped preview with per-row duplicate toggles + unparseable
  list) in `Sources/FinanceWorkspaceApp/UI/Write/ImportView.swift`
- [ ] T026 [US2] Wire the Import action into the shell (menu/local action) + post-import re-index in
  `Sources/FinanceWorkspaceApp/UI/Shell/AppCommands.swift`; confirm no structured single-add form is
  exposed for single transactions, prices, or trades (FR-018 — import-only)

**Checkpoint**: A real multi-month CSV imports cleanly with dedup; US1 still works.

---

## Phase 5: User Story 3 — Multi-entry transaction editing (Priority: P2)

**Goal**: Author/edit/delete a paycheck/transfer/split as one atomic group that must reconcile before write.

**Independent Test**: Create a paycheck group (gross → withholding → net), see it reconcile, apply —
all legs written together; delete the group — all legs removed atomically.

### Tests for User Story 3

- [ ] T027 [P] [US3] `MultiEntryWriteTests` — unbalanced blocks apply, balanced group written
  atomically to one file, whole-group delete removes every leg in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/MultiEntryWriteTests.swift`

### Implementation for User Story 3

- [ ] T028 [US3] Add the multi-entry group `WritePlan` (N `RowDiff`s sharing a generated `group_id`
  in one `FileChange`) + reconciliation assertion (transfers net to zero; `net = gross − Σ
  withholding`) before apply in `Sources/FinanceWorkspaceKit/Persistence/Write/WriteService.swift`
- [ ] T029 [US3] Build `TransactionGroupEditor` (author N entries, live reconciliation indicator,
  apply blocked until balanced) in `Sources/FinanceWorkspaceApp/UI/Write/TransactionGroupEditor.swift`
- [ ] T030 [US3] Wire whole-group edit/delete from the ledger surfaces in
  `Sources/FinanceWorkspaceApp/UI/Shared/LedgerTableView.swift` and
  `Sources/FinanceWorkspaceApp/UI/Accounts/AccountGroupDetailView.swift`

**Checkpoint**: Paychecks/transfers write and delete atomically; US1–US2 unaffected.

---

## Phase 6: User Story 4 — Delete with reference reassignment (Priority: P3)

**Goal**: Deleting a referenced object surfaces referencing rows grouped by collection and writes the
delete + chosen reassignments as one atomic plan.

**Independent Test**: Delete a category used by transactions, choose a reassignment target, apply —
category gone, every referencing transaction repointed, both in one atomic plan with backups.

### Tests for User Story 4

- [ ] T031 [P] [US4] `ReferenceScannerTests` — full FK-edge coverage per research D3 (assert a goal
  delete finds `transactions.savings_goal_id`, an asset delete finds both transaction asset FKs, a
  category delete finds `budget-allocations.category_id`, and any linkable delete finds
  `tax-adjustments.linked_id`), nullable detection (R2), self-deleted target rejected (R3) in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/ReferenceScannerTests.swift`
- [ ] T032 [P] [US4] Reassignment view-model tests — apply blocked until every group has a choice,
  self-deleted target rejected in `Tests/FinanceWorkspaceAppTests/ReassignmentViewModelTests.swift`

### Implementation for User Story 4

- [ ] T033 [US4] Implement `ReferenceScanner` — schema-derived FK edge map (research D3 table:
  allocations→`category_id`; six transaction FKs incl. `savings_goal_id`/`sending_asset_id`/
  `receiving_asset_id`/`liability_id`; `sleeve-targets.sleeve_id`; and the **polymorphic**
  `tax-adjustments.linked_id` matched for any deleted parent id), `referencesTo`, `reassignTargets`
  (schema-driven nullable) in `Sources/FinanceWorkspaceKit/Persistence/Write/ReferenceScanner.swift`
- [ ] T034 [US4] Extend the delete `WritePlan` with `ReferenceGroup[]` + `Reassignment[]` written
  atomically across all affected files (FR-021/022) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/WritePlan.swift`
- [ ] T035 [US4] Build `ReassignmentPickerView` (one picker per group, "leave unlinked" only when
  nullable) and wire it into the delete preview in
  `Sources/FinanceWorkspaceApp/UI/Write/ReassignmentPickerView.swift`

**Checkpoint**: Referenced deletes never orphan a row; simple deletes (US1) still work.

---

## Phase 7: User Story 5 — Guided repair of validation issues (Priority: P3)

**Goal**: Preview and apply deterministic auto-repairs from the issues table / detail pane, then
re-validate so the resolved issue disappears.

**Independent Test**: Introduce a repairable issue (lower-case a header), Preview Repair, Apply
Repair (⇧⌘R) — issue clears after re-validation; a repair-log entry is written.

### Tests for User Story 5

- [ ] T036 [P] [US5] Repair-apply integration test — apply clears the issue after re-validate;
  manual-only issue offers no apply in `Tests/FinanceWorkspaceAppTests/RepairApplyTests.swift`

### Implementation for User Story 5

- [ ] T037 [US5] Wire `RepairService.plan()` preview → confirm → `RepairService.apply()` from **both**
  the Overview issues table (⇧⌘R) and the detail-pane repair surface (FR-023), reusing
  `RepairPreviewSurface`, in `Sources/FinanceWorkspaceApp/UI/Overview/OverviewIssuesTableView.swift`
  and `Sources/FinanceWorkspaceApp/UI/Shell/DetailPaneView.swift`
- [ ] T038 [US5] Trigger re-index + re-validate after apply so the resolved issue drops from the
  table/chip (FR-026) in `Sources/FinanceWorkspaceApp/AppState.swift`
- [ ] T039 [US5] Ensure manual-only issues render guidance with no apply affordance (FR-025) in
  `Sources/FinanceWorkspaceApp/UI/Shell/DetailPaneView.swift`

**Checkpoint**: Repairable issues are fixable in-app end-to-end; other stories unaffected.

---

## Phase 8: User Story 6 — Export current view (Priority: P4)

**Goal**: Export the current tabular view as CSV (with provenance) and the Budget month as Markdown,
to a user-chosen destination, touching no workspace file.

**Independent Test**: Export a transactions table → CSV has visible rows + `source_file`/`source_row`
columns; export the Budget monthly summary → Markdown has the period header + category breakdown.

### Tests for User Story 6

- [ ] T040 [P] [US6] `ExportServiceTests` — provenance columns (E1), Markdown header+table (E2),
  workspace-path rejected (E3), empty-view headers-only (E4) in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/ExportServiceTests.swift`

### Implementation for User Story 6

- [ ] T041 [US6] Implement `ExportService.csv` (+ `source_file`/`source_row` columns),
  `budgetSummaryMarkdown`, and `write` (reject workspace-internal destinations) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/ExportService.swift`
- [ ] T042 [US6] Wire "Export Current View" (⌘E) `fileExporter`/save panel for tabular/ledger views in
  `Sources/FinanceWorkspaceApp/UI/Shell/AppCommands.swift`
- [ ] T043 [US6] Add the Budget monthly-summary export action in
  `Sources/FinanceWorkspaceApp/UI/Budget/BudgetOverviewView.swift`

**Checkpoint**: Export works for tables and the budget summary; no workspace mutation.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [ ] T044 Finalize `CommandMatrix` (`exportCurrentView`, `repairSelectedIssue`, `newRecord`) and
  update `CommandMatrixTests` per contracts/commands.md in
  `Sources/FinanceWorkspaceApp/UI/Shell/AppCommands.swift` +
  `Tests/FinanceWorkspaceAppTests/CommandMatrixTests.swift`
- [ ] T045 [P] Apply runtime `WriteGate` gating (disable + inline reason) uniformly across every write
  affordance (edit/import/multi-entry/reassign/repair/year-close) — audit pass (FR-005/SC-008)
- [ ] T046 [P] Clear the `design-adherence` gate for all new/changed views (`WritePreviewView`,
  `EntityEditForms`, `ImportView`, `TransactionGroupEditor`, `ReassignmentPickerView`, edited module
  views); confirm `DesignSystem` tokens only
- [ ] T047 [P] Update `docs/out-of-scope-followups.md` with any Phase-6 items deferred during build
- [ ] T048 [P] Update `docs/test-plans.md` — mark the write/import/repair/export flows testable +
  add the manual user-flow steps (quickstart mapping)
- [ ] T049 Run `specs/007-write-flows-repair-export/quickstart.md` end-to-end against a temp workspace
- [ ] T050 Confirm CI green: `swift test` (all write-engine + VM suites) + `swiftlint --strict` +
  unsigned app-target build

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup — **BLOCKS all user stories** (the safe-write path).
- **User Stories (Phase 3–8)**: all depend on Foundational. US1 is the MVP. US2–US6 can then proceed
  in parallel or in priority order.
- **Polish (Phase 9)**: depends on the desired stories being complete.

### User Story Dependencies

- **US1 (P1)**: after Foundational. No dependency on other stories. Delivers the writable-app MVP.
- **US2 (P2)**: after Foundational. Reuses `WriteService`; independently testable.
- **US3 (P2)**: after Foundational. Extends `WriteService` with group reconciliation; independent.
- **US4 (P3)**: after Foundational. Adds `ReferenceScanner`; simple delete (US1) is its baseline but
  US4 is independently testable via a referenced-object delete.
- **US5 (P3)**: after Foundational. Reuses the existing `RepairService`; independent of US1–US4.
- **US6 (P4)**: after Foundational. `ExportService` is read-only; fully independent.

### Within Each User Story

- Tests are written first and must fail before implementation (Swift Testing; run in CI).
- Kit engine work before the App UI that consumes it.
- Core plan/serializer before the forms/preview.

### Parallel Opportunities

- Setup: T002, T003 in parallel with T001.
- Foundational: T007, T008 (tests) in parallel once T004–T006 land.
- Across stories: once Foundational completes, US2/US3/US4/US5/US6 engine work can run in parallel
  (different files) — US1 first for the MVP.
- Within a story, the `[P]` test tasks run in parallel with each other.

---

## Parallel Example: User Story 1

```bash
# Tests first (parallel):
Task: "T009 [US1] CSVRowSerializer round-trip + sign tests across 12 entities"
Task: "T010 [US1] WritePreview view-model tests (apply/cancel/drift)"

# Then engine + UI (T013 is a different file from T011/T012):
Task: "T011 [US1] CSVRowSerializer.row for 12 entities"
Task: "T013 [US1] WritePreviewView (shared)"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 Setup → Phase 2 Foundational (the safe-write path — CRITICAL).
2. Phase 3 US1 → **STOP and VALIDATE**: add/edit/delete an entity with preview+backup; year-close.
3. The app is now writable — demoable MVP.

### Incremental Delivery

1. Foundational → safe-write path proven.
2. US1 (writable MVP) → US2 (import) → US3 (multi-entry) → US4 (delete-reassign) → US5 (repair) →
   US6 (export). Each adds value without breaking the prior stories.
3. Polish (command matrix, gate audit, design gate, docs, quickstart, CI) last.

### Notes

- `[P]` = different files, no incomplete dependency.
- Every mutation flows through `WriteService` — never reimplement backup/coordination/logging (FR-002).
- No schema change in this phase → no migration.
- Commit after each task or logical group; stop at any checkpoint to validate a story independently.
