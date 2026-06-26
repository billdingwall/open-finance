# Contract — Workspace Layout (bootstrap output)

The folder tree `bootstrap-workspace` MUST produce on first run, and the structure `FileIndexService`
classifies against. Canonical detail: `docs/architecture/containers-and-budgets.md §1`. Every managed
CSV is written with its header row and a leading `# schema_version: 1` comment row.

```text
Finance/
  Workspace.md                         # front matter: workspace_id, schema_version, created_at
  .finance-meta/                       # synced support data (NO manifest here)
    schemas/                           # one JSON schema per managed file type (source of truth)
    backups/                           # timestamped pre-write copies
    logs/  repair-log.csv  import-log.csv
  Accounts/
    accounts.csv                       # master registry (+ 6 seed accounts)
    account-groups.csv
    liabilities.csv
    account-rules.csv
    transactions/                      # unified ledger, YYYY-MM.csv (BX- prefix for business rows)
  Budget/        categories.csv  budgets.csv  budget-allocations.csv
  Savings/       goals.csv  progress.csv
  Investments/   assets.csv  prices.csv  dividends.csv  tax-lots.csv
                 portfolios.csv  sleeves.csv  sleeve-targets.csv  benchmarks/sp500.csv
  Taxes/         estimated-payments.csv  settings.csv  tax-adjustments.csv  estimates.csv
                 documents.csv  archive/  yearly/
  Notes/         monthly/  strategy/
```

## Invariants

- **Manifest is NOT here** — it lives device-local in Application Support (see `manifest.schema.json`).
  `.finance-meta/` holds only `schemas/`, `backups/`, `logs/`.
- **Six seed accounts** in `Accounts/accounts.csv`: personal bank, personal credit card, business
  bank, business credit card, savings, investment.
- **Default categories** seeded in `Budget/categories.csv`; standard tax-adjustment row seeded in
  `Taxes/tax-adjustments.csv` from filing status.
- **Idempotent**: re-running bootstrap preserves existing files; only missing folders/seed files are
  created. Missing required folders are reported, never silently overwriting user content.
- **Classification**: folder path → filename → in-file metadata (three-tier).
- **Naming**: monthly ledger files match `YYYY-MM.csv`; no `Personal/` or `Business/` transaction
  folders.
