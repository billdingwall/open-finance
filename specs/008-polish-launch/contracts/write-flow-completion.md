# Contract: Write-Flow Completion (US2)

Finishing the Phase-6 write UI. Engines exist and are unit-tested; these are the UI ⇄ engine contracts.

## Multi-entry group editor (FR-005 · OOS-16)

**`TransactionGroupEditor` (SwiftUI) ⇄ `WriteService` group plan / `MultiEntry`**

- Author N leg rows sharing one generated `group_id`; each leg = date (same **month** for all legs),
  account, amount (sign-aware), `group_role` (e.g. gross / withholding / net; from / to).
- Live reconciliation indicator: transfers net to zero; `net = gross − Σ withholding`. **Apply
  disabled until balanced.**
- On apply → one `WritePlan` with N `RowDiff`s in **one `FileChange`** (single monthly file) → normal
  preview → backup → atomic apply → re-index. All legs written or none.
- Ledger surfaces (`LedgerTableView`, `AccountGroupDetailView`): edit/delete a group row → resolve
  `group_id` → load **all** legs into the editor / delete them **as a group** (never a single leg).

**Guarantees**: unbalanced group cannot apply; whole group is atomic; no cross-month/cross-file group.

## Reassignment picker (FR-006 · OOS-17)

**`ReassignmentPickerView` (SwiftUI) ⇄ `ReferenceScanner`**

- On delete of a referenced entity, render one picker **per referencing collection**
  (`ReferenceScanner.referencesTo`), options = `reassignTargets` (excluding the deleted id).
- "Leave unlinked" offered **only** when the column is nullable; list-valued FKs offer
  replace-in-list / remove-from-list.
- **Apply blocked** until every group has a choice; the reassignment target may not be the deleted row.
- Delete + all reassignments remain **one atomic `WritePlan`** (already built) — replaces the current
  first-available-target default with the user's pick.

**Guarantees**: no orphaned row (SC-002); atomic across all affected files.

## Budget Markdown export (FR-007 · OOS-18)

**`BudgetOverviewView` ⇄ `ExportService.budgetSummaryMarkdown`**

- "Export summary (Markdown)" → `fileExporter`/save panel → write via `ExportService.write` (rejects
  workspace-internal destinations). Output: period header + category breakdown.

**Guarantees**: writes outside the workspace only; no workspace mutation.

## Typed entity forms (FR-008 · OOS-13)

**`EntityEditForms` control map ⇄ `CSVSchemaRegistry`**

- Control per (file, column): grouped `Picker` for parent references (account-group/category parent,
  target account); sign-aware amount field (money in/out); enum `Picker` for enumerated columns
  (values from `CSVSchemaRegistry`, not hardcoded). Unmapped columns keep the labelled text field.
- Submit path unchanged: `finishEditForm` → `WritePlanBuilder.add/edit` → `WritePreviewView`.

**Guarantees**: one safe-write submit path; enum options are schema-sourced.

## `transactions.description` column (FR-009 · OOS-15)

**Schema + `ImportMapper`**

- `description` optional column registered in `transactions.schema.json` + `CSVSchemaRegistry`;
  **absent-safe** (old files parse; no `schema_version` bump; no migration).
- Import maps a source memo/payee column into `description`; duplicate key = **date + amount +
  description within target account** (fallback date + amount + account when absent).

**Guarantees**: additive/backward-compatible; imported memos retained.
