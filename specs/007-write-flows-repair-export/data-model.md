# Data Model — Write Flows, Repair & Export (Phase 6)

Phase 6 adds **no canonical file schema** (no new columns, no `schema_version` bump — constitution
File Conventions). It introduces in-memory value types for the write engine and reuses the existing
typed entities (`Account`, `AccountGroup`, `Category`, `Budget`, `BudgetAllocation`, `SavingsGoal`,
`Asset`, `Liability`, `Portfolio`, `PortfolioSleeve`, `SleeveTarget`, `TaxAdjustment`,
`AccountRule`, `UnifiedTransaction`) as the payloads written by `CSVRowSerializer`.

## Write-engine types (`FinanceWorkspaceKit/Persistence/Write/`)

### WritePlan
The previewable, atomic unit for one mutation.

| Field | Type | Notes |
|---|---|---|
| `intent` | `WriteIntent` | `.add`/`.edit`/`.delete`/`.import`/`.repair`/`.closeTaxYear` (for logging + UI copy) |
| `changes` | `[FileChange]` | one per target file; applied in order, all-or-nothing |
| `references` | `[ReferenceGroup]` | delete only — referencing rows grouped by collection |
| `reassignments` | `[Reassignment]` | delete only — user's chosen target per reference group |
| `backup` | `BackupReference?` | filled at apply time (one per touched file) |

### FileChange
| Field | Type | Notes |
|---|---|---|
| `relativePath` | `String` | e.g. `Accounts/transactions/2026-06.csv` |
| `expectedHash` | `String?` | manifest SHA-256 captured at preview (drift check, D8) |
| `rowDiffs` | `[RowDiff]` | ordered edits within the file |

### RowDiff
| Field | Type | Notes |
|---|---|---|
| `rowRef` | `Int?` | source row (nil for `.add`) |
| `kind` | `.add(after)` / `.modify(before, after)` / `.delete(before)` | `before`/`after` are canonical CSV lines |
| `groupId` | `String?` | set for multi-entry rows moving together |

### ReferenceGroup
| Field | Type | Notes |
|---|---|---|
| `collection` | `String` | referencing collection (e.g. `transactions`) |
| `column` | `String` | FK column (e.g. `category_id`) |
| `rows` | `[RowRef]` | referencing rows (file + row) |
| `nullable` | `Bool` | from schema `required` set — enables "leave unlinked" |
| `isList` | `Bool` | list-valued FK (`budgets.account_ids`/`account_group_ids`) — reassign = replace/remove id within the list; removal always available |

### Reassignment
| Field | Type | Notes |
|---|---|---|
| `group` | `ReferenceGroup` | which references this resolves |
| `target` | `ReassignTarget` | `.reassign(id)` or `.unlink` (nullable only) |

Invariant: `target` id MUST NOT be in the plan's deletion set (FR-022).

### BackupReference
| Field | Type | Notes |
|---|---|---|
| `relativePath` | `String` | backed-up file |
| `backupName` | `String` | `<file>.<UTC-timestamp>.bak` in `.finance-meta/backups/` (from `BackupService`) |

### WriteResult
| Field | Type | Notes |
|---|---|---|
| `backups` | `[BackupReference]` | all backups taken |
| `touchedPaths` | `[String]` | files to re-index |
| `logEntries` | `[String]` | appended to `repair-log.csv` |

## Import types

### ColumnMapping
| Field | Type | Notes |
|---|---|---|
| `sourceColumns` | `[String]` | external CSV headers |
| `map` | `[String: String]` | canonical column → source column (user-confirmed) |
| `signConvention` | `.negativeIsDebit` / `.flipped` | declared, never silent (reuses `CSVNormalizer`) |
| `targetAccountId` | `String` | single account for the whole import (clarify Q1) |

Validation: every **required** canonical transaction column MUST be mapped (FR-015).

### ImportBatch
| Field | Type | Notes |
|---|---|---|
| `rowsByMonth` | `[String: [ImportRow]]` | keyed `YYYY-MM` (month-split) |
| `unparseable` | `[ImportRow]` | failed normalization — surfaced, not written |

### ImportRow
| Field | Type | Notes |
|---|---|---|
| `values` | `[String: String]` | normalized canonical values |
| `isDuplicate` | `Bool` | matches existing date+amount+description in target account (clarify Q2/Q3) |
| `included` | `Bool` | user toggle; duplicates default `false` |

## Export types

### ExportRequest
| Field | Type | Notes |
|---|---|---|
| `kind` | `.currentViewCSV` / `.budgetSummaryMarkdown` | |
| `rows` | `[[String: String]]` | for CSV — the visible rows |
| `provenance` | `[(sourceFile: String, sourceRow: Int)]` | appended as `source_file`,`source_row` columns |
| `period` | `String?` | for the Markdown budget summary |
| `destination` | `URL` | user-chosen (save panel); never inside the workspace |

## Entity → canonical file map (write targets)

| Entity | File | Key | Notes |
|---|---|---|---|
| AccountGroup | `Accounts/account-groups.csv` | `account_group_id` | referenced by accounts + `tax-adjustments.linked_id` |
| Account | `Accounts/accounts.csv` | `account_id` | master registry; dedicated-screen edit (accounts) |
| Liability | `Accounts/liabilities.csv` | `liability_id` | FK `account_id` |
| AccountRule | `Accounts/account-rules.csv` | `rule_id` | FK `account_id`, `category_id` |
| Category | `Budget/categories.csv` | `category_id` | self-FK `parent_category_id`, group `category_group_id` |
| Budget | `Budget/budgets.csv` | `budget_id` | scope on **list columns** `account_ids` / `account_group_ids` (comma-separated); allocations hold per-category amounts |
| BudgetAllocation | `Budget/budget-allocations.csv` | `allocation_id` | FK `budget_id`, `category_id` (per shipped schema — *not* account/group) |
| SavingsGoal | `Savings/goals.csv` | `goal_id` | flat list, no lifecycle; FK `source_account_id` |
| Asset | `Investments/assets.csv` | `asset_id` | FK `account_id`, `sleeve_id` (optional) |
| Portfolio | `Investments/portfolios.csv` | `portfolio_id` | container above sleeves; FK `account_id` |
| PortfolioSleeve | `Investments/sleeves.csv` | `sleeve_id` | FK `portfolio_id` |
| SleeveTarget | `Investments/sleeve-targets.csv` | `target_id` | FK `sleeve_id`; written when editing a sleeve's target weight/drift |
| TaxAdjustment | `Taxes/tax-adjustments.csv` | `tax_adjustment_id` | single **polymorphic** `linked_id` → txn/category/asset/liability/account/group (no type-discriminator column) |
| UnifiedTransaction (multi-entry only) | `Accounts/transactions/YYYY-MM.csv` | `transaction_id` | `group_id` connector; import-only otherwise; FKs `account_id, category_id, savings_goal_id, sending_asset_id, receiving_asset_id, liability_id` |
| TaxArchiveYear (year-close) | `Taxes/archive/<year>/…` | year | write-once via `TaxSafeWrite`; read-only after |

Sleeve editing spans two files: `Investments/sleeves.csv` (name, portfolio) and
`Investments/sleeve-targets.csv` (target weight). A sleeve add/edit/delete `WritePlan` may touch both.

Import-only (no structured single-add form): single transaction rows, `PricePoint` (prices),
`Trade`/`TaxLot`/`Dividend` rows. Multi-entry transaction groups are the sole structured transaction
write. The reference-edge map (research D3) is derived from the shipped schemas, not this prose.

## State transitions

- **Tax year**: `open → closed` via the in-app "Close Tax Year" action (FR-011a); a closed year's
  `Taxes/archive/<year>/` is read-only (parser already excludes it).
- **Draft write**: `preview (unwritten) → applied` or `→ cancelled (no-op)`; on drift detected at
  apply → `re-preview` (D8). No partial/intermediate persisted state.
