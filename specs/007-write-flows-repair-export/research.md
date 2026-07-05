# Research — Write Flows, Repair & Export (Phase 6)

Phase 0 decisions resolving the plan-level unknowns. No spec-level `NEEDS CLARIFICATION` remained
after the two 2026-07-05 clarify sessions; the items below are implementation choices grounded in the
existing codebase (`BackupService`, `FileCoordinatorService`, `WriteGate`, `RepairService`,
`RecordMappers`, `TaxSafeWrite`, `ProjectionStore`) and the constitution.

---

## D1 — The `WritePlan` abstraction

**Decision**: A single `WritePlan` value type is the previewable, atomic unit for *every* mutation
(add/edit/delete/import/repair/year-close). It carries: an ordered list of `FileChange` (one per
target file), each holding `RowDiff[]` (`.add`/`.modify(before,after)`/`.delete`); optional
`ReferenceGroup[]` + chosen `Reassignment[]` for deletes; and a resolved backup reference filled in
at apply time. `WriteService.preview(_:)` returns it unwritten; `WriteService.apply(_:)` consumes it.

**Rationale**: One representation means preview UI, backup, atomic apply, and the log all read the
same structure — the safe-write contract (constitution P-IV) is the type, not scattered logic. It
generalizes the pattern `TaxSafeWrite` already hard-codes for two tax actions.

**Alternatives considered**: Per-entity bespoke write methods (rejected — duplicates backup/atomic/
log logic per entity, the exact anti-pattern CLAUDE.md forbids); reusing `RepairPlan` (rejected —
`RepairPlan` is repair-specific and has no reference/reassignment concept, though repair *apply*
still flows through `RepairService`, wrapped as a `WritePlan` for preview parity).

## D2 — CSV serialization fidelity (`CSVRowSerializer`)

**Decision**: The serializer is the inverse of `RecordMappers`: typed entity → `[String:String]`
row → canonical CSV line. It (a) preserves the leading `# schema_version: N` comment row, (b) emits
columns in the schema's registered order from `CSVSchemaRegistry` (never re-orders), (c) writes the
amount **sign convention** (negative = debit) unchanged, (d) leaves untouched columns of a modified
row byte-identical by editing only the changed row in place rather than rewriting from the parsed
model. Unchanged files round-trip byte-stably (`parse → serialize` is identity).

**Rationale**: Byte-stability protects diff-ability in Finder/git and prevents a write from
"touching" every row (SC-003, P-I portability). Schema-ordered columns keep files human-interpretable.

**Alternatives considered**: Full model→file re-serialization on every write (rejected — would
normalize/reformat untouched rows, producing noisy diffs and risking data loss on columns the model
doesn't round-trip); appending only (rejected — can't express edit/delete).

## D3 — Reference scan & reassignment (`ReferenceScanner`)

**Decision**: A declarative FK map (child collection + column → parent collection) drives the scan.
The edges are derived **directly from the shipped JSON schemas** (`Resources/Schemas/*.schema.json`),
grouped by the parent collection a delete targets:

| Delete target | Referencing (child.column) |
|---|---|
| `accounts` (`account_id`) | `transactions.account_id`, `liabilities.account_id`, `account-rules.account_id`, `assets.account_id`, `portfolios.account_id`, `tax-adjustments.linked_id` |
| `account-groups` (`account_group_id`) | `accounts.account_group_id`, `tax-adjustments.linked_id` |
| `categories` (`category_id`) | `transactions.category_id`, `budget-allocations.category_id`, `categories.parent_category_id` (self), `tax-adjustments.linked_id` |
| `goals` (`goal_id`) | `transactions.savings_goal_id`, `tax-adjustments.linked_id` |
| `assets` (`asset_id`) | `transactions.sending_asset_id`, `transactions.receiving_asset_id`, plus asset-owned import data (`prices.asset_id`, `dividends.asset_id`, `tax-lots.asset_id`) |
| `liabilities` (`liability_id`) | `transactions.liability_id`, `tax-adjustments.linked_id` |
| `portfolios` (`portfolio_id`) | `sleeves.portfolio_id` |
| `sleeves` (`sleeve_id`) | `assets.sleeve_id`, `sleeve-targets.sleeve_id` |
| `budgets` (`budget_id`) | `budget-allocations.budget_id` |

Two schema realities the map must honor: (1) **`budget-allocations` references `category_id`**
(and `budget_id`), *not* an account/group; (2) **`tax-adjustments.linked_id` is a single
*polymorphic* link** (no type-discriminator column) — so a delete of *any* linkable parent
(account, group, category, asset, liability) scans `tax-adjustments.linked_id` for a matching id.
`transactions` carries six FKs (`account_id, category_id, savings_goal_id, sending_asset_id,
receiving_asset_id, liability_id`); `group_id`/`group_role` are multi-entry connectors, not FKs.

On delete, the scanner returns `ReferenceGroup[]` (one per referencing collection+column with its
rows). Reassignment offers same-collection targets excluding the deletion set; "leave unlinked" is
offered only when the schema marks the column optional/nullable. A reassignment naming a target also
deleted in the plan is rejected (FR-022). Asset-owned import rows (prices/dividends/tax-lots) are
surfaced in the preview; where no meaningful reassignment target exists they are offered "leave
unlinked" (nullable) or cascade with the asset — never silently orphaned (SC-005).

**Rationale**: A single declarative edge map is testable and matches the locked reassign policy
(PRD §12, constitution P-VI). Deriving edges from the schemas (not prose) keeps the no-orphan
guarantee (SC-005) sound. Nullable detection comes straight from the JSON schema `required` set.

**Alternatives considered**: Per-entity hand-written reference checks (rejected — scattered, drift-
prone); blocking deletes on any reference (rejected — violates the locked reassign decision); a typed
tax-adjustment link column (rejected — the shipped schema uses one polymorphic `linked_id`).

## D4 — Import mapping, sign, month-split, duplicate flag (`ImportMapper`)

**Decision**: Auto-detect maps external headers to canonical columns by case-insensitive
synonym/substring matching (e.g. `Date|Posted → date`, `Amount|Debit/Credit → amount`,
`Description|Memo|Payee → description`). The user confirms/edits the mapping and declares the sign
convention (never silently flipped — reuses `CSVNormalizer`, R8 lock). Every imported row is stamped
with the single **user-selected target account** (clarify Q1). Rows are grouped into
`Accounts/transactions/YYYY-MM.csv` by their parsed date (multi-month split). A row is flagged a
**duplicate** when it matches an existing transaction in that account on **date + amount +
description/merchant** (clarify Q2/Q3); duplicates are shown in the preview with a per-row
include/exclude toggle, defaulting to excluded. Unmapped required columns block import; unparseable
rows surface in the preview.

**Rationale**: Matches all four clarifications exactly and reuses the existing normalizer + schema
registry. The looser-than-exact duplicate key (three fields, not all columns) catches real re-imports
while the user's per-row confirmation covers false positives.

**Alternatives considered**: Per-row account column (rejected — clarify Q1 chose single account);
auto-skip duplicates (rejected — clarify Q2 chose flag-and-confirm); ID-only dedup (rejected —
imported rows have no stable external ID; app assigns IDs on write).

## D5 — Multi-entry atomic group write (`TransactionGroupEditor` + `WriteService`)

**Decision**: A multi-entry group is authored as N `RowDiff`s sharing a generated `group_id` with
`group_role`s, all targeting one monthly file, inside a single `FileChange`. The reconciliation rule
(transfers net to zero; `net = gross − Σ withholding`) is checked in the editor **and** re-asserted
in `WriteService` before apply. Edit and delete operate on the whole group (all rows sharing the
`group_id`); a partial group is never emitted.

**Rationale**: `group_id` grouping already exists in the ledger (constitution File Conventions);
atomicity falls out of the single-`WritePlan`-apply guarantee (SC-003).

**Alternatives considered**: Row-by-row transaction editing (rejected — PRD §12 requires groups as a
unit; also risks orphaned legs).

## D6 — Repair-apply wiring

**Decision**: `RepairService.plan()`/`apply()` already exist and enforce auto/manual classification.
Phase 6 wires the UI: the Overview issues table and detail pane call `plan()` for the diff preview
(already shown as `RepairPreviewSurface`), and on confirm call `apply()`, then trigger a
`ProjectionStore` re-index + re-validate so the resolved issue drops out (FR-026). Repair preview is
presented through the same `WritePreviewView` shell for consistency, but the apply path stays inside
`RepairService` (it already backs up + logs).

**Rationale**: The repair backend is done; only presentation + re-validate remain. Reusing
`RepairService.apply()` honors "never reimplement safe-write" and keeps `repair-log.csv` uniform.

**Alternatives considered**: Re-expressing repairs as generic `WritePlan`s (rejected — `RepairService`
already encodes the deterministic repair set and logging; wrapping would duplicate it).

## D7 — Export formats (`ExportService`)

**Decision**: Two outputs. (1) **CSV of the current view**: the visible rows plus appended
`source_file` and `source_row` provenance columns, written via `fileExporter`/save panel. (2)
**Markdown budget summary** for a period: a `# Budget — YYYY-MM` header, a category table
(plan/actual/variance/trailing-average), and a totals line, from the existing `BudgetOverviewProjection`.
Empty views export headers with no data rows. Exports never touch workspace files (FR-029).

**Rationale**: Provenance columns satisfy P-V traceability in exported artifacts; Markdown summary
matches the roadmap Phase-6 export task and the prototype.

**Alternatives considered**: xlsx/other formats (out of scope, V2); exporting whole workspace
(rejected — "current view" scope per spec assumption).

## D8 — Concurrent external-change (drift) detection

**Decision**: `WritePlan` captures each target file's content hash (from `ManifestStore`, already
SHA-256 per file) at preview time. `WriteService.apply()` re-reads and compares before writing; on
mismatch it aborts and signals the UI to re-preview against current content rather than overwriting
(spec edge case). This is layered on top of, not instead of, the `WriteGate` sync-state check.

**Rationale**: The manifest already hashes every file; reusing it makes drift detection free and
regenerable (P-II). Re-preview (not silent overwrite, not hard block) matches the edge-case spec.

**Alternatives considered**: `NSFileVersion`/coordinator presenters only (rejected — heavier, and
iCloud conflict handling is already separate); ignoring drift (rejected — risks clobbering an
external edit).

## D9 — Command & gate wiring

**Decision**: Extend `CommandMatrix` with `exportCurrentView` (enabled when a view is exportable),
`repairSelectedIssue` (enabled when a repairable issue is selected), and `newRecord` (enabled when
the active module has a primary add target — clarify Q3/FR-030a). Enable the currently-disabled
Export/Repair menu items and bind ⌘N to the context-sensitive add. Every individual write affordance
is *additionally* gated at press time by `WriteGate.evaluate(workspaceState:fileState:)`, showing the
returned reason when blocked (FR-005).

**Rationale**: `CommandMatrix` is already the pure, unit-tested enable/disable seam; extending it
keeps menu logic testable. Double-gating (matrix + `WriteGate`) separates "is this action meaningful
here" from "is it safe right now".

**Alternatives considered**: Ad-hoc `.disabled()` per button (rejected — untestable, already being
replaced by `CommandMatrix`).

## D10 — Edit-form generation strategy

**Decision**: Hand-written SwiftUI forms per entity in `EntityEditForms.swift`, each producing a
typed entity that `CSVRowSerializer` writes — not a schema-driven generic form. Forms expose only
canonical input fields (FR-011); derived values are display-only. Placement follows the locked
convention (FR-010): right-panel entities edit/delete at the `.editForm` surface bottom;
dedicated-screen entities (accounts) edit via local actions with delete inside the edit flow.

**Rationale**: 12 entity types with distinct field sets and pickers (account-group pickers, category
parents, sign-aware amounts) are clearer and more native as explicit forms; a generic schema-driven
form would fight the design system and obscure validation. Volume is bounded and one-time.

**Alternatives considered**: Metadata-driven generic form engine (rejected — over-engineered for a
fixed v1 entity set, poor native feel, hard to satisfy `design-adherence` per field).

---

### Summary of decisions

| ID | Decision |
|----|----------|
| D1 | One `WritePlan` type is the atomic, previewable unit for all mutations |
| D2 | `CSVRowSerializer` = inverse of `RecordMappers`; byte-stable, schema-ordered, sign-preserving, in-place row edit |
| D3 | Schema-derived FK edge map drives `ReferenceScanner` (allocations→`category_id`; polymorphic `tax-adjustments.linked_id`; six transaction FKs; `sleeve-targets.sleeve_id`); nullable from schema; reject self-deleted reassign targets |
| D4 | `ImportMapper` auto-detect + confirmed sign + single target account + month-split + date/amount/description duplicate flag |
| D5 | Multi-entry group = shared `group_id` `RowDiff`s in one `FileChange`; reconcile before apply; whole-group edit/delete |
| D6 | Repair apply reuses `RepairService.plan()/apply()` + `ProjectionStore` re-index/re-validate |
| D7 | `ExportService`: current-view CSV with provenance columns; Markdown budget summary |
| D8 | Drift detection via `ManifestStore` hash captured at preview, re-checked at apply → re-preview |
| D9 | Extend `CommandMatrix` (export/repair/newRecord); double-gate every write with `WriteGate` |
| D10 | Hand-written per-entity SwiftUI edit forms; canonical fields only; locked placement convention |
