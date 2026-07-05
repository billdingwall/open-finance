# Contract — UI Write Flows (`FinanceWorkspaceApp/UI/`)

SwiftUI surfaces that build a `WritePlan` and hand it to `WriteService`. They hold **zero** finance
logic and **zero** file I/O beyond calling the write engine. Every new/changed view clears the
`design-adherence` gate and uses `DesignSystem` tokens.

## WritePreviewView (shared)
Presents any `WritePlan` before apply.

- Renders: intent title, per-`FileChange` target path, before/after `RowDiff` rows, referencing rows
  + reassignment summary (delete), and the backup destination folder.
- Actions: **Apply** (calls `WriteService.apply`, then triggers `ProjectionStore` re-index +
  re-validate) and **Cancel** (no-op; nothing written) (FR-006, US1-AC2/AC3).
- On `driftDetected` from apply: re-fetch and re-present the plan against current file content (D8).
- Apply is disabled with the `WriteGate` reason when the target file/workspace is not writable
  (FR-005).

## EntityEditForms
Per-entity add/edit forms (account group, account, liability, account rule, category, budget,
allocation, savings goal, asset, portfolio, sleeve, tax-adjustment).

- Exposes only canonical input fields; derived values are display-only (FR-011).
- **Placement (FR-010)**: right-panel entities present Edit/Delete at the `.editForm` surface bottom
  (`DetailPaneView`); the dedicated-screen entity (Account) edits via local page actions with Delete
  inside the edit flow.
- Submit → build `WritePlan` → `WritePreviewView`.
- ⌘N opens the add-form for the **active module's primary entity** (FR-030a, clarify Q3).

## ReassignmentPickerView
Shown inside a delete preview when references exist.

- One picker per `ReferenceGroup`; options are `reassignTargets(...)`; "Leave unlinked" appears only
  when `group.nullable` (FR-020).
- Blocks Apply until every group has a choice; rejects a target in the deletion set (FR-021/FR-022).

## ImportView (two-step)
1. `fileImporter` → external CSV; show auto-detected `ColumnMapping` table (editable) + sign-convention
   control + **target-account picker** (required, single account).
2. Preview `ImportBatch` grouped by destination month; duplicates flagged with per-row include/exclude
   (default excluded); unmapped-required blocks step 1→2; unparseable rows listed read-only.
   Apply → `ImportMapper.writePlan` → `WriteService.apply` → re-index.

## TransactionGroupEditor (multi-entry)
- Authors N entries sharing a generated `group_id`; live reconciliation indicator (transfers net to
  zero; `net = gross − Σ withholding`).
- Apply blocked until reconciled (US3-AC1); edit/delete operate on the whole group; produces a
  single-`FileChange` `WritePlan` (atomic, FR-017).

## Repair apply wiring
- `OverviewIssuesTableView` / `DetailPaneView`: "Preview Repair" → `RepairService.plan()` diff
  (existing `RepairPreviewSurface`); **Apply Repair** (⇧⌘R) → `RepairService.apply()` → re-index +
  re-validate so the issue clears (FR-023/026). Manual-only issues show guidance, no apply (FR-025).

## Close Tax Year wiring
- `CurrentTaxYearView`: "Close Tax Year" → preview of the archive write → confirm → `TaxPrepEngine`
  year-close via `TaxSafeWrite` (existing) → re-index; the closed year becomes read-only (FR-011a).

## Command / gate contract → see `commands.md`.

## View-model tests (macOS CI)
- WritePreview VM: apply calls engine + triggers re-index; cancel is a no-op; drift → re-preview.
- Import VM: required-unmapped blocks advance; duplicate rows default excluded; target account required.
- Reassignment VM: apply blocked until all groups chosen; self-deleted target rejected.
- Multi-entry VM: unbalanced blocks apply; whole-group delete.
