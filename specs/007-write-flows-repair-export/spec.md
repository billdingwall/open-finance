# Feature Specification: Write Flows, Repair & Export

**Feature Branch**: `007-write-flows-repair-export`
**Created**: 2026-07-05
**Status**: Draft
**Input**: User description: "Phase 6 — Write Flows, Repair & Export. Make the app writable. Users can add/edit/delete accounts and account groups, manage budget categories/budgets/allocations, savings goals, tax adjustments, account rules, and assets/liabilities. Import external CSV transactions via a column-mapping flow that splits by month into canonical files. Add/edit/delete transactions inline (multi-entry groups written atomically). Trigger guided auto-repairs from the Overview issues table and detail pane. Export the current view as CSV (with provenance columns) and monthly budget summaries as Markdown. All writes are atomic, backed up before applying, and previewable. Delete-with-reference-check uses reassign. Build on the Phase 1 safe-write primitives — never reimplement safe-write logic."

## Overview

Through Phase 5 the app is **read-only**: it indexes, parses, validates, and projects a workspace of
CSV/Markdown files into fully navigable module views, but the user cannot change any data from inside
the app. Phase 6 makes the app **writable**. Every object a user can add can also be edited and
deleted; external bank/brokerage CSVs can be imported; deterministic validation issues can be
repaired with a preview; and the current view can be exported. Every mutation goes through one safe
path — preview → timestamped backup → atomic apply → re-index → re-validate — reusing the Phase 1
safe-write primitives rather than reimplementing them.

## Clarifications

### Session 2026-07-05

- Q: On import, how is each row's destination account (`account_id`) determined? → A: User selects a single target account for the entire import; every imported row gets that `account_id`.
- Q: How does import handle rows that appear to duplicate existing transactions? → A: Flag detected duplicates in the import preview; the user includes or excludes each (never silently dropped or blindly imported).
- Q: What does the "add new record" (⌘N) primary action create? → A: Context-sensitive — it adds a new record of the active module's primary object type (new account in Accounts, new goal in Savings, etc.).
- Q: Are portfolios and sleeves structured-editable in this phase? → A: Yes — portfolios and sleeves support add/edit/delete alongside assets and liabilities (per PRD §12).
- Q: Is the in-app "Close Tax Year" action in scope for this phase? → A: Yes — wire the year-close action (button → preview → archive write) through the safe-write path; the Phase 4 engine already performs the archive write.
- Q: Which fields determine an import duplicate? → A: Date + amount + description/merchant, matched within the chosen target account.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Structured object editing with safe writes (Priority: P1)

A user manages the objects that define their finances — account groups, accounts, budget categories,
budgets and allocations, savings goals, tax-adjustments, account rules, assets, and liabilities —
directly in the app. For each, they can add a new record, edit an existing one, or delete it. Before
anything is written, the app shows a preview of exactly what will change (target file, affected rows,
before/after values, and where the backup will be placed). The user confirms; the app backs up the
target file, writes the change atomically, and the affected views refresh.

**Why this priority**: This is the writable-app MVP. It delivers the core preview → backup → atomic
apply → refresh loop that every other write in this phase depends on. Once this works for even a
single object type, the app has crossed from read-only to writable and the safe-write path is proven
end-to-end.

**Independent Test**: Add a new savings goal, confirm the preview shows the target file and the new
row, apply, and verify the goal appears in the module view and a timestamped backup of the goals file
exists. Then edit its target amount and delete it, confirming a preview and backup at each step.

**Acceptance Scenarios**:

1. **Given** a workspace with a savings goal, **When** the user edits the goal's target amount and
   opens the preview, **Then** the preview shows the target file path, the changed row with old and
   new values, and the backup location — with nothing written until the user confirms.
2. **Given** a pending edit preview, **When** the user confirms, **Then** the app creates a
   timestamped backup, writes the change atomically, logs the write, and refreshes the affected view.
3. **Given** a pending edit preview, **When** the user cancels, **Then** no backup is created, no file
   is modified, and the workspace is unchanged.
4. **Given** an object whose detail opens in the right panel, **When** the user views it, **Then**
   edit and delete actions appear at the bottom of that panel; **Given** an object with its own
   dedicated screen, **Then** edit is in the screen's local actions and delete is inside the edit flow.
5. **Given** the target file is mid-sync or in a conflicted iCloud state, **When** the user attempts a
   write, **Then** the write is blocked with a clear reason and no change is made.

---

### User Story 2 - Import external CSV transactions (Priority: P2)

A user exports a CSV from their bank or brokerage and imports it into the app. They pick the file and
select the single target account the import belongs to; the app auto-detects a column mapping between
the external columns and the canonical transaction schema; the user reviews and adjusts the mapping
and confirms the sign convention; the app previews the parsed rows, then appends them to the correct
canonical monthly files (`YYYY-MM.csv`) under the chosen account, splitting a multi-month file across
months as needed. A backup is taken for every monthly file touched, and the
workspace re-indexes.

**Why this priority**: Importing transactions is the primary way month-over-month data enters the
workspace. Without it, the ledger cannot grow after bootstrap. It builds on the P1 safe-write path but
adds mapping and multi-file splitting.

**Independent Test**: Import a two-month bank CSV, map its columns, confirm, and verify the rows land
in the two correct monthly files with backups taken, provenance recorded, and re-index triggered.

**Acceptance Scenarios**:

1. **Given** an external CSV, **When** the user selects it for import, **Then** the app presents a
   column-mapping table pre-filled with auto-detected mappings to the canonical schema, which the user
   can adjust.
2. **Given** a confirmed mapping and sign convention, **When** the user previews, **Then** the app
   shows the parsed rows grouped by destination monthly file and flags any rows that fail
   normalization or validation before writing.
3. **Given** an import spanning multiple months, **When** the user applies, **Then** rows are appended
   to each correct `YYYY-MM.csv`, each touched file is backed up first, and the write is atomic per
   file.
4. **Given** a mapping that leaves a required canonical column unmapped, **When** the user tries to
   proceed, **Then** the app blocks the import and explains which required column is missing.

---

### User Story 3 - Multi-entry transaction editing (Priority: P2)

A user records transactions that are not single rows — a paycheck (gross → withholdings → net) or a
transfer, or a split mortgage payment (principal/interest) — as one grouped unit. The app presents a
multi-entry editor where all entries of the group are edited together, enforces the group's balance
or reconciliation rule, and writes, edits, or deletes every row sharing the group's connector as a
single atomic operation.

**Why this priority**: Multi-entry groups are the one transaction type that is structured-editable
(all other transaction entry is import-only). Paychecks and transfers are core to an accurate ledger,
and their all-or-nothing integrity is a safety requirement.

**Independent Test**: Create a paycheck group (gross income, tax withholding, net deposit), verify it
reconciles (`net = gross − Σ withholding`), apply, and confirm all rows are written together to the
correct monthly file; then delete the group and confirm all its rows are removed atomically.

**Acceptance Scenarios**:

1. **Given** a new paycheck group, **When** the entries do not reconcile, **Then** the editor blocks
   the write and explains the imbalance.
2. **Given** a balanced multi-entry group, **When** the user applies, **Then** all rows sharing the
   group connector are written atomically to the correct monthly file with a single backup and
   preview.
3. **Given** an existing multi-entry group, **When** the user edits one entry, **Then** the edit is
   presented and written as a change to the whole group, not a disconnected row.
4. **Given** an existing multi-entry group, **When** the user deletes it, **Then** every row sharing
   the connector is removed atomically — never a partial group.

---

### User Story 4 - Delete with reference reassignment (Priority: P3)

A user deletes an object that other rows reference — a budget category used by transactions, or an
account group that accounts belong to. Instead of silently orphaning or blocking, the app surfaces
every referencing row grouped by collection and asks the user to choose a reassignment target for
each collection (or "leave unlinked" where the reference is nullable). On confirm, the delete and all
reassignments are written as one atomic plan.

**Why this priority**: This protects referential integrity for destructive actions. It depends on the
delete path from P1 but adds the reference scan and reassignment picker, so it follows once basic
delete works.

**Independent Test**: Delete a category referenced by transactions, choose a reassignment category in
the preview, apply, and verify the category is gone, every referencing transaction now points to the
chosen category, and both changes were written atomically with backups.

**Acceptance Scenarios**:

1. **Given** a delete of a referenced object, **When** the user opens the delete preview, **Then** the
   app lists all referencing rows grouped by collection with a reassignment picker per collection.
2. **Given** a reassignment chosen for each referencing collection, **When** the user applies,
   **Then** the delete and all reassignments are written as a single atomic plan across all affected
   files with backups.
3. **Given** a nullable reference, **When** the user selects "leave unlinked", **Then** the
   referencing rows are cleared of the reference rather than reassigned.
4. **Given** a delete-with-references preview, **When** the user cancels, **Then** nothing is deleted
   and nothing is reassigned.

---

### User Story 5 - Guided repair of validation issues (Priority: P3)

A user sees validation issues in the Overview issues table and the detail pane. For each issue the
app has classified as auto-repairable, the user triggers a repair, reviews a diff-style preview of the
fix, confirms, and the app backs up, applies the deterministic repair, logs it, and re-indexes and
re-validates so the resolved issue disappears.

**Why this priority**: Repair turns the existing read-only validation surface into an actionable one.
It reuses the safe-write path and the existing repair service, so it layers cleanly onto P1.

**Independent Test**: Introduce a repairable issue (e.g. a missing optional column), trigger the
repair from the issues table, confirm the preview, apply, and verify the issue clears after
re-validation and a repair-log entry is written.

**Acceptance Scenarios**:

1. **Given** an auto-repairable issue, **When** the user selects "Preview Repair", **Then** the app
   shows a before/after preview of the fix and the backup location.
2. **Given** a repair preview, **When** the user confirms, **Then** the app backs up the file, applies
   the deterministic repair, logs it, and re-indexes and re-validates.
3. **Given** a manual-only issue, **When** the user views it, **Then** no auto-repair action is
   offered — only guidance.
4. **Given** an applied repair, **When** re-validation completes, **Then** the resolved issue no
   longer appears in the issues table.

---

### User Story 6 - Export current view (Priority: P4)

A user exports what they are looking at. From a table or ledger view they export a CSV that includes
source-provenance columns; from the Budget module they export a monthly budget summary as Markdown
with a period header and category breakdown. The app opens a save panel and writes the file to the
chosen destination.

**Why this priority**: Export is valuable for sharing and record-keeping but is not required for the
app to be writable, so it comes last in the phase.

**Independent Test**: From a filtered transactions table, export CSV and verify the file contains the
visible rows plus provenance columns; from the Budget overview, export the monthly summary and verify
the Markdown has the period header and category breakdown.

**Acceptance Scenarios**:

1. **Given** a tabular view, **When** the user exports it as CSV, **Then** the exported file contains
   the currently visible rows and includes source-file/source-row provenance columns.
2. **Given** the Budget overview for a period, **When** the user exports the monthly summary, **Then**
   a Markdown file is produced with a period header and a category breakdown.
3. **Given** an export action, **When** the user chooses a destination in the save panel, **Then** the
   file is written there and no workspace file is modified.

---

### Edge Cases

- **Write blocked by sync state**: any write (edit, import, repair, delete, multi-entry) is disabled
  while the target file or the workspace is syncing, downloading, stale, or conflicted; the user is
  told why and no change is made.
- **Backup failure**: if the timestamped backup cannot be created, the write is aborted before the
  target file is touched.
- **Atomic write failure**: if the atomic apply fails mid-write, the original file is left untouched
  and the user is informed.
- **Concurrent external change**: if a target file changed on disk since it was read into the preview,
  the app detects the drift and re-previews rather than overwriting blindly.
- **Import with unparseable rows**: rows that fail normalization are surfaced in the import preview and
  excluded (or block the import) rather than being written as malformed data.
- **Re-import of an overlapping date range**: rows matching existing transactions in the target account
  are flagged as duplicates in the preview; the user decides per row whether to include or exclude.
- **Multi-entry group that does not reconcile**: the group cannot be written until it balances.
- **Delete of an object with no references**: proceeds as a simple delete with preview and backup, no
  reassignment step.
- **Reassignment target itself deleted in the same plan**: the app prevents choosing a reassignment
  target that the same plan removes.
- **Export of an empty view**: produces a valid file with headers and no data rows.
- **Editing a derived/read-only value**: values the app derives (not stored as canonical input) are
  not offered as editable fields.

## Requirements *(mandatory)*

### Functional Requirements

**Safe-write foundation**

- **FR-001**: The system MUST route every mutation (add, edit, delete, import, repair) through a
  single safe-write path: preview → timestamped backup → atomic apply → re-index → re-validate.
- **FR-002**: The system MUST reuse the existing Phase 1 safe-write primitives
  (`BackupService`, `FileCoordinatorService`, `WriteGate`) and MUST NOT reimplement backup,
  file-coordination, or sync-gating logic.
- **FR-003**: The system MUST create a timestamped backup of every file a write plan touches before
  modifying it, and MUST abort the write if the backup cannot be created.
- **FR-004**: The system MUST apply file changes atomically (temp-file-then-rename on the same
  volume), leaving the original file untouched on failure.
- **FR-005**: The system MUST block any write while the target file or workspace is in a syncing,
  downloading, stale, or conflicted state, and MUST show the reason.
- **FR-006**: The system MUST show a write preview before applying — target file path, affected rows
  with before/after values, referencing rows on delete, and the backup location — and MUST make no
  change until the user confirms.
- **FR-007**: The system MUST record every write and repair to the workspace repair/write log.
- **FR-008**: The system MUST re-index and re-validate affected files after a successful write so
  views and the issues table reflect the new state.

**Structured object editing**

- **FR-009**: Users MUST be able to add, edit, and delete each of: account groups, accounts, budget
  categories, budgets, budget allocations, savings goals, tax-adjustments, account rules, assets,
  liabilities, portfolios, and sleeves — each writing to its canonical file.
- **FR-010**: The system MUST present edit/delete actions per the placement convention: objects whose
  detail opens in the right panel show edit and delete at the bottom of that panel; objects with a
  dedicated screen expose edit in the screen's local actions with delete inside the edit flow.
- **FR-011**: The system MUST only offer canonical input fields for editing and MUST NOT present
  derived values as editable.
- **FR-011a**: Users MUST be able to trigger the "Close Tax Year" action in-app, which previews and
  then writes the year's archive and marks the year closed through the safe-write path (reusing the
  Phase 4 year-close archive write; not reimplementing it). A closed year's archive is read-only
  thereafter.

**Transaction import & multi-entry editing**

- **FR-012**: Users MUST be able to import an external transaction CSV through a column-mapping flow
  that pre-fills auto-detected mappings to the canonical schema and lets the user adjust them.
- **FR-012a**: The system MUST require the user to select one target account for the whole import and
  MUST assign that account to every imported row (the source CSV is not expected to carry an account
  identifier).
- **FR-013**: The system MUST let the user declare/confirm the amount sign convention on import and
  MUST NOT silently flip signs.
- **FR-014**: The system MUST append imported rows to the correct canonical monthly file(s)
  (`Accounts/transactions/YYYY-MM.csv`), splitting a multi-month import across the right months.
- **FR-015**: The system MUST block an import whose mapping leaves a required canonical column
  unmapped, and MUST surface rows that fail normalization in the import preview.
- **FR-015a**: The system MUST detect imported rows that appear to duplicate existing transactions in
  the target account and flag them in the import preview, letting the user include or exclude each; it
  MUST NOT silently drop or blindly import a detected duplicate. A duplicate is a row matching an
  existing transaction on date, amount, and description/merchant within the chosen target account.
- **FR-016**: Users MUST be able to add, edit, and delete a multi-entry transaction group (transfer,
  paycheck gross/net split, principal/interest split) as a single unit through a multi-entry editor.
- **FR-017**: The system MUST enforce a multi-entry group's balance/reconciliation rule (transfers net
  to zero; `net = gross − Σ withholding`) before writing, and MUST write, edit, or delete all rows
  sharing the group connector atomically — never a partial group.
- **FR-018**: The system MUST treat single transaction rows, price points, and trades as import-only —
  no structured single-add flow other than the multi-entry transaction editor.

**Delete with reference reassignment**

- **FR-019**: On deleting a referenced object, the system MUST scan for and surface all referencing
  rows grouped by collection in the delete preview.
- **FR-020**: The system MUST present a reassignment picker per referencing collection, offering
  "leave unlinked" only where the reference is nullable.
- **FR-021**: The system MUST write the delete and all chosen reassignments as one atomic plan across
  all affected files, or cancel the entire operation — never a partial delete and never a silent
  orphan.
- **FR-022**: The system MUST prevent selecting a reassignment target that the same plan deletes.

**Repair**

- **FR-023**: Users MUST be able to trigger a guided repair for auto-repairable validation issues from
  the Overview issues table and the detail pane.
- **FR-024**: The system MUST show a diff-style repair preview and backup location, and apply only
  deterministic, previewable repairs on confirmation.
- **FR-025**: The system MUST NOT offer an auto-repair action for issues classified as manual-only.
- **FR-026**: After applying a repair the system MUST re-index and re-validate so resolved issues
  disappear from the issues table.

**Export**

- **FR-027**: Users MUST be able to export the current tabular/ledger view as a CSV that includes the
  visible rows and source-provenance columns.
- **FR-028**: Users MUST be able to export a monthly budget summary as Markdown with a period header
  and category breakdown.
- **FR-029**: Export MUST write only to a user-chosen destination via a save panel and MUST NOT modify
  any workspace file.

**Commands**

- **FR-030**: The system MUST enable the previously-disabled "Export Current View" (⌘E) and "Repair
  Selected Issue" (⇧⌘R) menu commands, and wire an "add new record" primary action, consistent with
  the documented command matrix.
- **FR-030a**: The "add new record" (⌘N) action MUST be context-sensitive to the active module,
  creating a new record of that module's primary object type (e.g. a new account in Accounts, a new
  goal in Savings & Investments), and MUST be disabled where no primary add target exists.

### Key Entities *(include if feature involves data)*

- **Write Plan**: A previewable, confirmable description of one mutation — target file(s), rows to
  add/modify/delete, derived values, referencing rows and their reassignments (for deletes), and the
  backup reference. Applied atomically as a unit.
- **Column Mapping**: The user-confirmed correspondence between an external CSV's columns and the
  canonical transaction schema, plus the declared sign convention, used to drive an import.
- **Import Batch**: The set of parsed, normalized rows from one import, grouped by destination monthly
  file, with per-row validation status.
- **Repair Action**: A deterministic, previewable fix for an auto-repairable validation issue,
  produced by the existing repair service and applied through the safe-write path.
- **Export Document**: A user-facing output file (CSV table with provenance columns, or Markdown
  budget summary) written outside the workspace to a chosen destination.
- **Reference Reassignment**: For a delete, the mapping from a referencing collection to its chosen
  new target (or "unlinked"), applied atomically with the delete.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every user-addable object type in scope (account groups, accounts, categories, budgets,
  allocations, goals, tax-adjustments, account rules, assets, liabilities, portfolios, sleeves) can be
  added, edited, and deleted from the app, each producing a preview and a backup before applying.
- **SC-002**: 100% of writes produce a timestamped backup before the target file is modified and a
  corresponding entry in the write/repair log.
- **SC-003**: No write ever leaves a partial result — every applied write plan (including multi-entry
  groups and delete-with-reassignment) is all-or-nothing, verified by the original files being intact
  after any induced failure.
- **SC-004**: A user can import a real multi-month bank/brokerage CSV, map its columns, and land the
  rows in the correct monthly files with no manual file editing.
- **SC-005**: Deleting a referenced object never orphans a referencing row — every referencing row is
  either reassigned to a user-chosen target or explicitly left unlinked where nullable.
- **SC-006**: Every auto-repairable issue shown in the issues table can be previewed and repaired
  in-app, and disappears from the table after re-validation.
- **SC-007**: A user can export the current tabular view as CSV (with provenance) and a monthly budget
  summary as Markdown without modifying any workspace file.
- **SC-008**: Writes are blocked with a clear reason whenever the target file or workspace is not
  fully synced, and no unsynced file is ever overwritten.

## Assumptions

- **Reuse over rebuild**: The safe-write primitives from Phase 1 (`BackupService`,
  `FileCoordinatorService`, `WriteGate`) and the existing `RepairService` and `MigrationService` are
  present and are reused; this phase adds the write-plan/preview, import, and export layers on top,
  not new backup or coordination logic.
- **Asset/liability scope**: "Assets and liabilities" refers to their canonical definition rows in
  `Investments/assets.csv` and `Accounts/liabilities.csv` (structured-editable). Price points and
  trade rows remain import-only, consistent with "holdings, trades, and prices are import-only".
- **Delete policy**: The reassign-on-reference policy is the locked Round 7 decision
  (`docs/product-requirements.md §12`, `docs/technical-design.md §21`); this phase implements it and
  does not reopen it.
- **Repair determinism**: Only deterministic, previewable auto-repairs are in scope (constitution
  P-VII); no speculative or guided migrations. Breaking-schema migrations remain shipped scripts, not
  in-app writes.
- **Export surfaces**: "Current view" export applies to tabular/ledger surfaces and the Budget monthly
  summary; a general export-everything feature is out of scope for this phase.
- **Backup retention**: Backup naming and rotation follow the existing `BackupService` behavior;
  automated backup pruning (`backup-prune`) is a Phase 7 concern and is out of scope here.
- **Out of scope (V2, unchanged)**: Budget rules/automation, bank/brokerage live sync, xlsx/other
  spreadsheet formats, and multi-workspace remain deferred and are not addressed by import/export here.
- **Platform**: Target hardware is Apple Silicon (M1+); write and re-index responsiveness criteria are
  assessed against that baseline.

## Dependencies

- **Phase 1 — Foundation**: `BackupService`, `FileCoordinatorService`, `WriteGate`, `ManifestStore`,
  `FileIndexService`/`FileWatcherService` for re-index after write.
- **Phase 2 — Parsing & Validation**: `CSVParserService`/`CSVSchemaRegistry`/`CSVNormalizer` for
  import mapping and write serialization; `ValidationEngine`/`RuleCatalog`/`RepairService` for
  reference checks, repair previews, and re-validation.
- **Phase 3–4 — Domain engines**: canonical entity/record mapping used to build and apply write plans
  for each object type.
- **Phase 5 — Presentation**: the app shell, detail pane, issues table, and module views that host the
  edit/delete actions, import flow, repair actions, and export commands.
