# Data Pipelines — Flows, Scripts, and Ingestion Diagrams

> Extracted from `docs/technical-design.md` in Round 7 (2026-06-24). The overview file
> (`technical-design.md`) links here for read/write/repair flows, developer scripts, and
> data ingestion pipeline documentation. Pipeline diagrams in §3 are new in Round 7 (gap A4).

---

## 1. Read, write, and repair flows

### Read flow

1. Resolve workspace URL.
2. Scan and classify files.
3. Parse files into typed records.
4. Validate records.
5. Build domain models.
6. Build projections for UI.
7. Render views with inspector links.

### Structured write flow

The write flow covers **add, edit, and delete** for every user-addable object (account groups, accounts, transactions, categories, goals, assets, liabilities, portfolios, sleeves, tax-adjustments, account rules, etc.).

1. User adds, edits, or deletes a supported object in UI.
2. App builds a write plan. For a delete, it runs a **reference check** (see `rulesets-and-taxes.md §1`) and includes referencing rows in the plan. A **multi-entry transaction group** (transfer or paycheck split) is written, edited, or deleted as a single atomic unit — all rows sharing a `group_id` move together, and the group must pass its balance/reconciliation check before write.
3. App previews target file and affected rows (and referencing rows on delete).
4. App creates timestamped backup.
5. App writes changes atomically (temp-file-then-rename; temp file must be on the same volume as the target).
6. App re-indexes affected files.
7. App re-validates and refreshes projections.

**Edit/delete UI placement convention:**
- Objects whose detail opens in the **right panel** — edit and delete actions live at the **bottom of the right panel**.
- Objects with their **own dedicated screen** (e.g. an individual account) — **edit** is in the local screen actions; **delete** is offered inside the edit flow.

**Delete-on-reference behavior: reassign** (locked Round 7) — When deleting a referenced object, the write flow must surface all referencing rows grouped by collection, present a per-collection reassignment picker (nullable references may be left unlinked), and write the delete plus all reassignments atomically. The user can cancel the entire operation. Full policy in `docs/architecture/rulesets-and-taxes.md §1` and `docs/product-requirements.md §12`.

### Repair flow

1. Validation marks issue as repairable.
2. App shows repair preview.
3. User confirms.
4. Backup created.
5. Repair applied.
6. Manifest refreshed.
7. Validation rerun.
8. Repair logged.

---

## 2. Scripts and developer tooling

Because the source of truth is file-based, the project should include scripts for workspace management and testing outside the UI.

### Required scripts

#### `bootstrap-workspace`
Purpose:
- Create standard folder tree.
- Create seed CSV/Markdown templates.
- Create manifest.
- Create default categories and budgets.
- Seed six starter accounts in `Accounts/accounts.csv`: personal bank, personal credit card, business bank, business credit card, savings, investment.

CLI example:
```bash
swift Scripts/bootstrap-workspace.swift --workspace ~/Library/Mobile\ Documents/.../Documents/Finance
```

#### `validate-workspace`
Purpose:
- Scan workspace.
- Run schema validation.
- Print issue summary.
- Optionally write JSON report.

CLI example:
```bash
swift Scripts/validate-workspace.swift --workspace <path> --format json
```

#### `repair-workspace`
Purpose:
- Apply known low-risk fixes.
- Create missing files.
- Normalize headers.
- Write backup log.

CLI example:
```bash
swift Scripts/repair-workspace.swift --workspace <path> --apply
```

#### `import-csv`
Purpose:
- Ingest external CSV.
- Map to canonical schema.
- Split into monthly canonical files.

#### `export-summary`
Purpose:
- Export app-derived monthly or yearly summaries back to CSV or Markdown.

### Optional scripts

- `benchmark-import`
- `note-link-audit`
- `migrate-r6` — one-time preview-able migration script that renames `entities.csv`→`account-groups.csv`, `holdings.csv`→`assets.csv`, `deductions.csv`→`tax-adjustments.csv`, updates FK column names, and folds `Investments/transactions.csv` into the unified monthly ledger. See `docs/product-roadmap.md` Phase 2.
- `schema-migrate`
- `backup-prune`
- `fixture-generate` — populates a local mock iCloud folder (e.g. `~/Finance-Dev/`) with a realistic dataset (12 months of transactions, accounts, etc.) for development and first-run onboarding.

---

## 3. Ingestion pipeline diagrams

This section documents how external data flows from a source file through parsing, normalization, and into the domain model. Added in Round 7 to address the gap identified in `docs/_notes/r6-gap-analysis.md`.

### 3.1 CSV import and normalization pipeline

```
External source file (bank export, brokerage CSV, etc.)
        │
        ▼
[User selects file via import flow]
        │
        ▼
CSVParserService
  - Read raw rows
  - Detect delimiter, encoding
  - Map source headers to canonical column names (column-mapping UI)
        │
        ▼
CSVNormalizer
  - Detect sign convention (user confirms or heuristic)
  - Flip signs if source uses opposite convention
  - Parse dates to ISO 8601
  - Parse amounts to Decimal
  - Assign source_file / source_row provenance
  - Generate stable transaction_id values
        │
        ▼
ValidationEngine (pre-write pass)
  - Validate required columns present
  - Validate no duplicate transaction_id within target month
  - Validate account_id references resolve in accounts.csv
  - Validate category_id references resolve in categories.csv
  - Surface any issues to user before writing
        │
        ▼
Write preview
  - Show target file: Accounts/transactions/YYYY-MM.csv
  - Show row count to be appended
  - Show any validation warnings
  - Show backup location
        │
        ▼ (user confirms)
BackupService
  - Timestamped backup of existing target file
        │
        ▼
Atomic write
  - Write to temp file on same volume
  - Rename temp → target (atomic)
        │
        ▼
FileIndexService
  - Update manifest (hash, modified date, row count)
        │
        ▼
Domain engines re-derive projections
  - AccountEngine re-derives account balances
  - BudgetEngine re-derives category actuals
  - TaxEngine re-derives income/gain summaries
  - OverviewEngine re-derives KPI cards
```

### 3.2 Balance derivation pipeline

After each write (import, add, edit, delete), account balances and liability balances are re-derived from the transaction ledger. There is no stored running balance — every balance is a projection.

```
Accounts/transactions/YYYY-MM.csv (all months)
        │
        ▼
AccountEngine
  - Filter rows by account_id
  - SUM(amount) WHERE account_id = X → current_balance (cached, not stored)
  - For liabilities: SUM(amount) WHERE liability_id = Y → principal_balance
  - For investment accounts: delegate to PortfolioEngine for asset values
        │
        ▼
AccountSummaryCard (projection)
  - monthly inflow = SUM(positive amounts, current month)
  - YTD net income = gross - expenses - taxes_paid (YTD)
  - current_balance cached in accounts.csv for display speed
```

### 3.3 Multi-entry transaction group write pipeline

```
User submits a multi-entry group (transfer or paycheck gross/net split)
        │
        ▼
Group validation (pre-write)
  - Transfer: SUM(amount) across all group rows must == 0
  - Paycheck split: exactly one "gross" row, one "net" row;
    net == gross - SUM(withholding rows)
  - All rows share the same group_id (connector, not PK)
        │
        ▼
Write preview
  - Show all rows in the group together
  - Show balance check result
  - Show backup location
        │
        ▼ (user confirms)
Atomic write
  - All rows written as a single atomic unit
  - If any row fails validation, the entire group is rejected
        │
        ▼
Re-index and re-derive (same as §3.1 write path)
```

### 3.4 File-watch re-index pipeline

```
FileWatcherService detects change in Finance/ folder
        │
        ▼
Debounce (short delay to coalesce rapid changes)
        │
        ▼
FileIndexService
  - Compare modified date and SHA-256 hash to manifest
  - If hash changed: re-parse affected file only (incremental, not full scan)
  - Update manifest entry
        │
        ▼
ValidationEngine
  - Re-run validation for affected file and its cross-file references
  - Emit updated issue list
        │
        ▼
Notify affected domain engines
  - Only engines that depend on the changed file are re-triggered
  - Projections cached by file hash; unchanged files use cached projections
        │
        ▼
UI refresh via Observation
```
