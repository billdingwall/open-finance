# Workspace Structure and File Specifications

> Extracted from `docs/technical-design.md` in Round 7 (2026-06-24). The overview file
> (`technical-design.md`) links here for workspace structure, file classification, and all
> CSV/Markdown file specs. All schema names reflect the Round 6 renames.

---

## 1. Workspace folder structure

```text
Finance/
  Workspace.md
  .finance-meta/                         # synced support data — manifest is NOT here (device-local, R8)
    schemas/
      account.schema.json
      account-group.schema.json
      transaction.schema.json
      assets.schema.json
      liabilities.schema.json
      portfolios.schema.json
      tax-adjustments.schema.json
      tax-estimates.schema.json
      tax-documents.schema.json
      markdown-note.schema.json
    backups/
    logs/
      repair-log.csv
      import-log.csv
  Accounts/
    accounts.csv
    account-groups.csv
    liabilities.csv
    account-rules.csv
    transactions/
      2026-01.csv
      2026-02.csv
  Budget/
    categories.csv
    budgets.csv
    budget-allocations.csv
  Savings/
    goals.csv
    progress.csv
  Investments/
    assets.csv
    prices.csv
    dividends.csv
    tax-lots.csv
    portfolios.csv
    sleeves.csv
    sleeve-targets.csv
    benchmarks/
      sp500.csv
  Taxes/
    estimated-payments.csv
    settings.csv
    tax-adjustments.csv
    estimates.csv
    documents.csv
    archive/
      2025-tax-adjustments.csv
      2025-estimated-payments.csv
    yearly/
      2026-tax-notes.md
      2026-prep-checklist.md
  Notes/
    monthly/
      2026-01-review.md
      2026-02-review.md
    strategy/
      ips.md
      tax-strategy.md
      business-strategy.md
```

### Folder design rules

- Folder path is the first classifier.
- Filename is the second classifier.
- Front matter or schema metadata is the third classifier.
- `.finance-meta/` is app-managed support data, but not the source of truth for finance content. It holds only `schemas/`, `backups/`, and `logs/`. The **manifest is device-local** (`~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`), kept out of the synced container as a regenerable cache (R8 — see `docs/technical-design.md §9`). The `.finance-meta/` subtree is excluded from the file index.
- Backups live inside `.finance-meta/backups/` and use timestamped copies.
- `Accounts/accounts.csv` is the unified master account registry for all account types, including investment accounts. Investment-specific metadata (tax treatment, performance tracking) is stored as optional columns in this file. There is no separate `Investments/accounts.csv`.
- `Personal/rules.csv` is not included in v1. Budget rules and recurring-rule automation are deferred post-MVP.

---

## 2. File classification rules

### CSV classification

CSV files are classified by:
1. Folder path.
2. Filename.
3. Required headers.
4. Optional schema version marker.

### Markdown classification

Markdown files are classified by:
1. Folder path.
2. Front matter `type`.
3. Front matter `period`, `account_group_id`, `account_ids`, `sleeve_id`, `tax_year`, or tags.

### Supported file types

Use Uniform Type Identifiers for file handling and file import/export boundaries.

Recommended UTType handling:
- CSV: `public.comma-separated-values-text` where available via system type mappings.
- Markdown: custom or mapped plain text/markdown type depending on platform availability.
- JSON: internal metadata only.
- Plain text fallback for unsupported note content.
- xlsx (`com.microsoft.excel.xlsx`): V2 only. At the parsing layer boundary, xlsx files will be converted to CSV-equivalent row dictionaries before reaching domain engines, preserving the plain-files contract and keeping the canonical source of truth in CSV.

---

## 3. File specifications

> **schema_version convention (Round 8):** every managed CSV begins with a leading
> comment row `# schema_version: N` (line 1); `CSVParserService` strips leading `#`
> comment lines. If absent, the registry's current version is assumed and the file is
> flagged for repair.
>
> **Schemas as source of truth (Round 8):** these specs are authored as
> machine-readable JSON schemas in `.finance-meta/schemas/` (one per file type),
> driving `CSVSchemaRegistry`, `ValidationEngine`, bootstrap templates, and migrations.
> The display-name ↔ enum mappings and required/optional flags below are encoded there.

### 3.1 Workspace.md

Purpose:
- Workspace identity and human-readable description.
- Initial onboarding summary.
- Manual notes about the workspace.

Recommended front matter:
```md
***
type: workspace
workspace_id: finance-main
schema_version: 1
created_at: 2026-05-10T10:00:00Z
default_currency: USD
timezone: America/Denver
***
```

### 3.2 Unified transactions CSV

Path:
`Accounts/transactions/YYYY-MM.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| transaction_id | string | Stable unique ID (unique per row) |
| group_id | string | Optional — shared across the entries of a multi-entry transaction (transfers, paycheck splits). A connector, **not** a primary key. Generalizes the former `transfer_group`. |
| group_role | enum | Optional — `leg`, `gross`, `net`, `withholding` |
| date | date | ISO 8601 date |
| account_id | string | Links to account |
| type | enum | `income`, `expense`, `transfer`, `trade`, `credit` |
| merchant | string | Raw merchant / payer (pre-normalization) |
| source_id | string | Optional — normalized issuer (Transaction-source) |
| description | string | User-facing text |
| amount | decimal | Signed: negative = debit (money out), positive = credit (money in) |
| direction | enum | debit, credit — redundant with sign but kept for readability and import mapping |
| category_id | string | Normalized category |
| subcategory_id | string | Optional |
| sending_asset_id | string | Optional — the asset value is drawn from |
| receiving_asset_id | string | Optional — the asset value is added to |
| liability_id | string | Optional — the liability this entry settles or draws on |
| savings_goal_id | string | Optional |
| deductible | boolean | Flag for tax module inclusion (Schedule C / business-expense) |
| tags | string | Optional — pipe-delimited tag list |
| notes | string | Optional |
| source_file | string | Optional provenance |
| source_row | integer | Optional provenance |
| trade_type | enum | Optional — populated only when `type = trade` (`buy`, `sell`) |
| quantity | decimal | Optional — trade rows |
| price | decimal | Optional — trade rows |
| fees | decimal | Optional — trade rows |
| lot_id | string | Optional — trade rows |
| ticker | string | Optional — trade rows |
| sleeve_id | string | Optional — trade rows |

Behavior:
- Must support import from external CSV then normalization into canonical monthly files.
- Amount sign convention (locked): negative = debit (money out of account), positive = credit (money into account). This applies to all transaction file types. The `direction` column is redundant with the sign but retained to simplify import column mapping from external sources.
- During import normalization, if a source file uses the opposite convention, the `CSVNormalizer` must flip the sign before writing to the canonical file.
- `transaction_id` must remain stable across recategorizations.
- **Multi-entry transactions** share a `group_id` while each row keeps a unique `transaction_id`. Transfers and liability payments must net to zero across the group; paycheck gross/net splits carry exactly one `gross` and one `net` row and reconcile `net = gross − Σ(withholding)` (see `data-pipelines.md §1`). The `credit` type records a loan / line-of-credit draw-down (cash received, a liability increased).
- **Investment buys/sells are recorded here** as `type = trade` rows (with `sending_asset_id`/`receiving_asset_id` and the optional trade columns), absorbing the former `Investments/transactions.csv`.

### 3.3 Unified categories CSV

Path:
`Budget/categories.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| category_id | string | |
| category_group_id | string | Flat grouping label (was `group_id`) |
| parent_category_id | string | Optional — self-reference for sub-categories |
| name | string | |
| type | enum | |
| default_budget_behavior | enum | |
| sort_order | integer | Optional — display ordering |
| is_active | boolean | |
| tax_relevant | boolean | |
| account_group_id | string | Optional — links category to an account-group (was `entity_id`) |
| tax_group | string | Optional — maps category to Schedule C/tax lines |

Notes:
- Seed with default category groups aligned to common card and personal finance reporting patterns.
- Support user-editable category naming without changing IDs.

### 3.4 Budgets (definition + allocations)

A budget is a **named, scoped** definition with category **allocations** as its lines.

**`Budget/budgets.csv`** — budget definitions:

| Column | Type | Notes |
|---|---|---|
| budget_id | string | Stable key |
| name | string | e.g. "Household", "Consulting LLC" |
| timeframe | enum | monthly (v1), weekly, annual |
| start_date | date | |
| end_date | date | Optional |
| account_group_ids | string | Pipe-delimited account-groups this budget monitors |
| account_ids | string | Optional — pipe-delimited individual-account overrides/additions |
| is_active | boolean | |

**`Budget/budget-allocations.csv`** — the lines of a budget:

| Column | Type | Notes |
|---|---|---|
| allocation_id | string | Stable key |
| budget_id | string | → budgets.csv |
| category_id | string | → categories.csv |
| type | enum | spending, savings |
| amount | decimal | Planned amount (was `planned_amount`) |
| rollover_amount | decimal | Optional (was `rollover_policy`) |
| period | yyyy-mm | |
| priority | enum | Optional |

If only one budget ships in MVP, seed a single default `budget_id` so existing allocation lines stay backward-compatible.

### 3.5 Savings goals CSV

Path:
`Savings/goals.csv`

Required columns:

| Column | Type |
|---|---|
| goal_id | string |
| name | string |
| target_amount | decimal |
| target_date | date |
| monthly_target | decimal |
| source_account_id | string |
| status | enum |
| linked_note_id | string |

`status` enum values: `active | archived` (Round 8). `completed` is **derived** from
progress ≥ target (not a stored value); `paused` is not in v1.

Optional:
- sleeve_id
- priority
- auto_fund_from_budget

Goal lifecycle in v1 is the minimal `active | archived`: archived goals are excluded
from active views (satisfies the S&I active/archived tabs). This resolves `[FIX-S7]`
and reverses the earlier "lifecycle is V2 / no status column" note.

Budget-to-goal funding is linked **solely** via the `savings_goal_id` column on the
unified transaction ledger (`[FIX-S4]`). There is no separate
`Budget/savings-goal-contributions.csv` — it was removed to avoid duplicating
derivable data.

### 3.6 Savings progress CSV

Path:
`Savings/progress.csv`

Purpose:
- Optional imported snapshots or manually maintained progress history.

Required columns:

| Column | Type |
|---|---|
| goal_id | string |
| as_of_date | date |
| balance | decimal |
| contributed_mtd | decimal |
| contributed_ytd | decimal |

### 3.7 Investment accounts

Investment accounts are stored in `Accounts/accounts.csv` (spec §3.21), the unified master registry. There is no separate `Investments/accounts.csv` file. Investment-specific metadata is carried as optional columns in the master registry (see §3.21). This file type and path are removed from the workspace structure.

### 3.8 Assets CSV  *(was Holdings)*

Path:
`Investments/assets.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| asset_id | string | Was `holding_id` |
| account_id | string | → accounts.csv |
| name | string | Human label |
| asset_class | enum | Broad kind: `cash`, `equity`, `crypto`, `real-estate` |
| security_class | enum | Optional — finer security classification (equity, bond, REIT, ETF…) |
| ticker | string | Optional when `asset_class ≠ equity` |
| quantity | decimal | |
| cost_basis | decimal | |
| current_value | decimal | Derived from prices × quantity (was `market_value`) |
| sleeve_id | string | Optional — → sleeves.csv |
| sector | string | |
| as_of_date | date | Supports "edited directly" snapshots |

### 3.9 Reserved (Absorbed into Unified Transactions)

Investment buys/sells are recorded in the unified transactions ledger (§3.2) as `type = trade` rows. The former `Investments/transactions.csv` is removed; the schema migration moves its rows into the monthly ledger.

### 3.10 Prices CSV

Path:
`Investments/prices.csv`

Required columns:

| Column | Type |
|---|---|
| ticker | string |
| date | date |
| close | decimal |

### 3.11 S&P 500 benchmark CSV

Path:
`Investments/benchmarks/sp500.csv`

Required columns:

| Column | Type |
|---|---|
| date | date |
| close | decimal |
| source | string |

This file enables comparison views for short-, medium-, and long-term performance.

### 3.12 Sleeves CSV

Path:
`Investments/sleeves.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| sleeve_id | string | |
| portfolio_id | string | → portfolios.csv (re-parents the sleeve) |
| name | string | |
| goal | string | Optional |
| target_allocation_percentage | decimal | Sleeve's target share of the portfolio |
| monthly_contribution_target | decimal | |
| benchmark_id | string | |
| linked_note_id | string | |

The free-text `strategy` column moves to `Portfolio.strategy` (§3.26).

### 3.13 Sleeve targets CSV

Path:
`Investments/sleeve-targets.csv`

Required columns:

| Column | Type |
|---|---|
| sleeve_id | string |
| ticker | string |
| target_weight | decimal |
| min_weight | decimal |
| max_weight | decimal |

### 3.14 Account-groups CSV  *(was Customizable entities/themes)*

Path:
`Accounts/account-groups.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| account_group_id | string | Unique key (was `entity_id`) |
| display_name | string | User-visible name |
| description | string | Optional |
| legal_name | string | Legal business name (optional) |
| group_type | enum | `personal`, `employment`, `business`, `custom` (was `entity_type`) |
| tax_id_hint | string | Tax ID / EIN (optional) |
| is_active | boolean | Status flag |

### 3.15 Reserved (Absorbed into Unified Transactions)

### 3.16 Reserved (Absorbed into Unified Categories)

### 3.17 Reserved (Absorbed into Unified Budgets)

### 3.18 Tax settings CSV

Path:
`Taxes/settings.csv`

Required columns:

| Column | Type |
|---|---|
| key | string |
| value | string |
| tax_year | integer |

### 3.19 Estimated payments CSV

Path:
`Taxes/estimated-payments.csv`

Required columns:

| Column | Type |
|---|---|
| payment_id | string |
| tax_year | integer |
| quarter | integer |
| due_date | date |
| amount | decimal |
| paid_date | date |
| jurisdiction | enum |

### 3.20 Markdown note files

Markdown files should use YAML front matter for structured linking.

Recommended front matter:
```md
***
type: monthly-review
note_id: note-2026-05-review
period: 2026-05
account_group_ids: [consulting-llc]
account_ids: [checking-main, brokerage-main]
goal_ids: [house-down-payment]
sleeve_ids: [core-growth]
tax_year: 2026
tags: [monthly-close, taxes]
schema_version: 1
***
```

Supported note `type` values:
- workspace
- monthly-review
- strategy
- tax-note
- annual-prep-checklist
- business-review
- savings-plan
- sleeve-strategy

### 3.21 Accounts registry CSV

Path:
`Accounts/accounts.csv`

Purpose: Master account registry covering all account type groups. This is the workspace-level source of truth for all accounts referenced across personal transactions, business transactions, and investment holdings.

Required columns:

| Column | Type | Notes |
|---|---|---|
| account_id | string | Stable unique ID referenced across all transaction files |
| display_name | string | User-visible name |
| institution | string | Bank, brokerage, employer, etc. |
| account_group | enum | employment, business, credit_card, investment, savings, checking, loan (high-level classification; distinct from the Account-group object / `account_group_id`). **Display-name ↔ enum mapping (`[FIX-S9]`, encoded in the JSON schema):** "Everyday Banking" → `checking`, "Credit Cards" → `credit_card`, "Loans & Debt" → `loan`, "Savings" → `savings`, "Investments" → `investment`, "Employment" → `employment`, "Business" → `business`. |
| account_type | string | Specific type within group (e.g. roth_ira, hysa, mortgage) |
| status | enum | draft, active, frozen, closed (canonical lifecycle) |
| is_active | boolean | Derived (`status == active`); retained for backward compatibility |
| current_balance | decimal | Derived from the transaction ledger; cached for display |
| available_balance | decimal | Derived from the transaction ledger; cached for display |
| tax_relevant | boolean | Flag for tax module inclusion |
| tax_year_opened | integer | Optional |
| account_group_id | string | Required — links account to an account-group in Accounts/account-groups.csv (was `entity_id`) |
| tax_treatment | string | Optional — investment accounts only (e.g. taxable, roth_ira, traditional_ira, hsa) |
| performance_tracking | boolean | Optional — investment accounts only; enables portfolio projection |
| notes | string | Optional |

Notes:
- All account types, including investment accounts, are stored in this single file. Investment-specific columns (`tax_treatment`, `performance_tracking`) are optional and apply only to rows with `account_group: investment`.
- On workspace bootstrap, seed six starter accounts: personal bank, personal credit card, business bank, business credit card, savings, and investment (see `docs/technical-design.md §21` bootstrap decision).

### 3.22 Account rules CSV

Path:
`Accounts/account-rules.csv`

Purpose: Account-level income and expense estimates used to project expected cash flow per account (e.g. expected paycheck, recurring loan payment, scheduled transfer).

Required columns:

| Column | Type | Notes |
|---|---|---|
| rule_id | string | |
| account_id | string | References Accounts/accounts.csv |
| rule_type | enum | income_estimate, expense_estimate, recurring |
| description | string | |
| amount | decimal | |
| frequency | enum | monthly, biweekly, weekly, quarterly, annual |
| start_date | date | |
| end_date | date | Optional |
| category_id | string | Optional |
| is_active | boolean | |

### 3.23 Tax-adjustments CSV  *(was Tax deductions)*

Path:
`Taxes/tax-adjustments.csv`

Purpose: Tracks expected and confirmed tax adjustments (deductions, credits, and liabilities) for the current tax year.

Required columns:

| Column | Type | Notes |
|---|---|---|
| tax_adjustment_id | string | Was `deduction_id` |
| tax_year | integer | |
| adjustment_type | enum | standard, above_the_line, itemized, business-expense, credit, liability (`business-expense` is the rename of `schedule_c`) |
| name | string | e.g. "HSA Contribution", "Home Office", "Mortgage Interest" (was `deduction_name`) |
| estimated_amount | decimal | |
| confirmed_amount | decimal | Optional — updated at filing time |
| account_group_id | string | Optional — links business items to an account-group (was `entity_id`) |
| account_id | string | Optional — links to source account |
| transaction_id | string | Optional — the transaction it applies to |
| category_id | string | Optional — the category it applies to |
| asset_id | string | Optional — the asset it applies to |
| liability_id | string | Optional — the liability it applies to |
| receipt_path | string | Optional — path to a supporting document |
| notes | string | Optional |
| status | enum | estimated, confirmed, not_applicable |

Notes:
- The standard adjustment row should be seeded by the app on workspace bootstrap using the filing status from `Taxes/settings.csv` and the applicable tax year amount.
- `business-expense` rows for a given `account_group_id` are surfaced in the Business module as well as the Tax module.

### 3.24 Tax archive files

Path pattern:
`Taxes/archive/YYYY-tax-adjustments.csv`
`Taxes/archive/YYYY-estimated-payments.csv`
(Archives written before the Round 6 rename retain their original `YYYY-deductions.csv` name.)

Purpose: Prior-year snapshots written when a tax year is closed. Schema mirrors the active-year files. The presence of an archive file for a given year signals that the year is closed for editing.

Archive files are read-only after creation. The app should warn before any write to an archived year.

### 3.25 Liabilities CSV

Path:
`Accounts/liabilities.csv`

Purpose: Debt positions (loans, mortgages, credit lines) held within accounts, modeled as a first-class peer of Asset.

| Column | Type | Notes |
|---|---|---|
| liability_id | string | Stable key |
| account_id | string | → accounts.csv |
| name | string | |
| liability_type | enum | credit-card, loan, mortgage |
| principal_balance | decimal | Derived from the transaction ledger |
| interest_rate | decimal | |
| credit_limit | decimal | Optional — credit-card / line-of-credit |
| minimum_payment | decimal | Optional |
| due_date | date | Optional |

### 3.26 Portfolios CSV

Path:
`Investments/portfolios.csv`

Purpose: Parent container grouping sleeves; the asset-side scope parallel to a Budget.

| Column | Type | Notes |
|---|---|---|
| portfolio_id | string | Stable key |
| name | string | |
| description | string | Optional |
| strategy | string | Optional — the free text formerly on a sleeve |
| goal | string | Optional |
| timeframe | string | Optional |
| type | enum | retirement, brokerage, crypto, savings |
| account_group_ids | string | Optional — pipe-delimited account-groups this portfolio tracks |

### 3.27 Tax estimates CSV

Path:
`Taxes/estimates.csv`

Purpose: A year's projected tax liability — distinct from logged estimated payments (§3.19).

| Column | Type | Notes |
|---|---|---|
| estimate_id | string | Stable key |
| fiscal_year | integer | |
| estimated_income | decimal | |
| estimated_deductions | decimal | |
| projected_liability | decimal | |
| target_safe_harbor | decimal | Optional |

### 3.28 Tax documents CSV

Path:
`Taxes/documents.csv`

Purpose: Registry of tax documents (W-2, 1099, 1098, receipts) linked to adjustments and a fiscal year.

| Column | Type | Notes |
|---|---|---|
| document_id | string | Stable key |
| name | string | |
| file_path | string | Path/URL to the stored document |
| tax_year | integer | |
| type | enum | income-form, deduction-receipt, prior-return, other |
