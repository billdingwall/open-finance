
---

# Personal Finance Workspace for macOS
## Technical Design Document

## 1. Purpose

This document translates the product requirements into implementation and design requirements for a native macOS application that uses CSV and Markdown files stored in iCloud Drive as the source of truth.

The app is not the owner of the data model in the database sense. Instead, it discovers files, validates them, normalizes them into internal read models, and presents personal budgeting, savings goals, portfolio management, small business finance, and tax workflows through a structured interface.

## 2. Design goals

### Primary goals

- Keep CSV and Markdown as canonical storage.
- Make the app a trustworthy interface over plain files.
- Support personal, portfolio, business, and tax workflows in one connected workspace.
- Provide safe structured writes, file repair, and source traceability.
- Keep the architecture modular enough for rapid prototyping and later automation.
- Design the storage layer behind a provider protocol so that iCloud, Google Drive, Dropbox, and local-folder modes can be added as independent backends in V2 without changing the parsing or domain layers.

### Non-goals

- No hidden primary database in v1.
- No bank sync or brokerage sync in v1.
- No tax filing engine in v1.
- No AI-driven financial analysis in v1.

## 3. System overview

The system should use a **plain-files source of truth** plus an **internal normalized read model**. The app reads CSV and Markdown from an iCloud-backed workspace, parses and validates them, builds domain models, and then derives projections for dashboards, tables, reports, and inspectors.

### Core architecture layers

1. **Storage layer**  
   iCloud workspace resolution, file access, file coordination, backups, sync state.

2. **Indexing layer**  
   File scan, file manifest, change detection, sync hints, hash tracking.

3. **Parsing layer**  
   CSV parsing, Markdown front matter parsing, schema detection, validation results.

4. **Domain layer**  
   Accounts, budget, savings, investments, business, tax, notes, and cross-domain linking.

5. **Projection layer**  
   Overview cards, monthly summaries, benchmark comparisons, issue dashboards, drill-down views.

6. **Presentation layer**  
   SwiftUI views, inspectors, forms, tables, contextual filters, charts, and commands.

## 4. Information architecture

The app should use a three-column `NavigationSplitView` layout, but the left panel should be dedicated to navigation rather than shared with filters. `NavigationSplitView` is intended for two- or three-column interfaces where selections in leading columns control presentations in later columns, which aligns well with a finance workspace that needs stable navigation and deep drill-down views. [web:64]

This layout also fits a macOS productivity workflow because the navigation model can stay stable while filters, tables, and detail views change with the currently selected context. SwiftUI’s document-based app patterns and Observation-based state model support this kind of multi-pane structure with state that updates predictably as selections change. [web:22][web:33][web:34]

### Primary navigation

The left sidebar is the primary navigation surface for the app. It should contain stable top-level sections and allow nested links for specific entities, accounts, goals, sleeves, reports, and saved views.

Top-level navigation (v1):
- Accounts
- Budget
- Savings & Investments
- Taxes
- Settings

The Overview dashboard is the **default screen** on launch. It is reached via the sidebar header (the workspace title, displayed as "Finance Dashboard"), not a dedicated nav item.

Deferred to V2:
- Notes
- Issues
- Files

### Left sidebar structure

The left sidebar is static and should only support expandable groups under the relevant top-level section when specified. The sidebar is for navigation only, not for temporary or view-specific filters.

Examples:
- **Accounts**
  - Overview
  - Account groups (user-customizable, loaded from `Accounts/account-groups.csv`):
    - Personal Accounts (Personal)
    - Place of Employment (Employment)
    - Consulting LLC (Business)
    - Freelance (Business)
    - Rental LLC (Business)
- **Budget**
  - Overview
  - Budget history
  - Categories
- **Savings & Investments**
  - Overview
  - Goals
  - Portfolio
- **Taxes**
  - Current tax year
  - Prep checklist
  - Tax archive
- **Notes** *(V2)*
  - Monthly reviews
  - Strategy notes
  - Business notes
  - Tax notes
- **Issues** *(V2)*
  - All issues
  - Repairable
  - Manual review

The Account groups group under Accounts is the primary example of data-driven nested links — items are populated from `Accounts/account-groups.csv` rather than hardcoded. (The account-facing term is "group", not "entity"; the model-level rename `entities.csv`→`account-groups.csv` / `entity_id`→`account_group_id` was applied in Round 6 — see `docs/_refinement/r6-update-technical-design.md`.) The local "New group" action creates a new account group. Other sections may add group- or item-specific links under their parent section using the same pattern. These data-driven links are part of the fixed sidebar structure, not view-specific filters.

### App shell

#### Left sidebar

Primary navigation only:
- Top-level domains
- Nested entity links
- Nested note groups

#### Main panel

The center panel becomes the primary working area for the currently selected navigation item. It should contain the contextual header and the main content view.

Main-panel structure:
1. **Context header**
   - Selected view title, with the **local actions row on the same line as the title, right-aligned** within the main column
   - Breadcrumb or parent context

2. **Content surface**
   - Table
   - Card grid
   - Chart area
   - Summary rows
   - List view
   - Empty state
   - Validation state

Module screens have **no general filter bar** in v1; the contextual filter surface (period/date/account/group/sleeve/goal/category/severity/search/saved-view selectors) is deferred to V2. A screen shows period or account selection inline only where it is intrinsic to that screen.

Sync status and issue status are global: they live in the **top header** (issue-count chip immediately left of the sync-status chip), not in the per-view context header.

The **Overview dashboard has no filters**. It is a fixed read-only dashboard and is the default landing screen.

#### Right detail pane

The right pane is the detail and inspector surface. It is **collapsible and closed by default**. It opens as a slide-over rather than a persistent split, so it does not compete with the main content surface when not in use. Pane width should be fixed or lightly constrained.

It should show the selected row, summary, note, file preview, source lineage, validation details, or repair preview.

Supported detail surfaces:
- Inspector
- Source file preview
- Source row details
- Markdown note preview
- Validation issue details
- Repair preview
- Edit form

### Navigation behavior

- Top-level navigation changes the active domain.
- Nested links change the selected group or scoped view within that domain.
- The sidebar should preserve expansion state for nested groups.
- The right panel should update based on selection, not navigation alone.
- Deep links should be representable as domain plus nested group or account selection. (A general filter-state surface is deferred to V2.)
- The app should support keyboard navigation across sidebar, main panel, and detail inspector.

### Global interaction patterns

- Every KPI links to a filtered detail table in the main panel.
- Every detail row links to a source file and source row in the right panel.
- Every source file can be opened externally in Finder or the default editor.
- Every repair action requires preview and confirmation.
- Every write flow shows target file, rows affected, and backup behavior.

## 5. Workspace and iCloud model

### Workspace strategy

Support two workspace modes:
1. **Default v1 mode:** app-owned iCloud ubiquity container.
2. **Advanced mode:** user-selected iCloud Drive folder.

Recommendation: implement app-owned container first because Apple’s ubiquity container pathing is more predictable and is the native document-store model for app-managed files.

### Storage provider abstraction

In v1 the only supported backend is iCloud via the app-owned ubiquity container. The storage layer must be built around a `CloudStorageProvider` protocol so that alternative backends — Google Drive, Dropbox, local folder — can be added in V2 without restructuring workspace management, parsing, or domain logic.

`ICloudContainerService` is the v1 conforming implementation. `WorkspaceManager` resolves the workspace URL through the active provider rather than calling iCloud APIs directly.

Minimum protocol surface:
```swift
protocol CloudStorageProvider {
    var syncState: SyncState { get }
    var isAvailable: Bool { get }
    func resolveWorkspaceURL() async throws -> URL
}
```

Providers planned for V2:
- Google Drive (via Drive File Stream or Files API)
- Dropbox (via Dropbox SDK)
- Local folder (for users who manage sync externally)

### Workspace resolution

Primary path pattern:
```swift
FileManager.default
  .url(forUbiquityContainerIdentifier: "OpenFinance")?
  .appendingPathComponent("Documents")
  .appendingPathComponent("Finance")
```

The container identifier is `OpenFinance`. This must match the `com.apple.developer.ubiquity-container-identifiers` entitlement value in the Xcode project.

### Sync considerations

iCloud availability may vary by account state and entitlement setup, and container access can fail or return nil when configuration or account state is wrong. The app must surface this explicitly instead of assuming the workspace is always available.

Required sync states:
- Available
- Not signed into iCloud
- Container unavailable
- Syncing
- Local copy stale
- File missing locally
- Conflict detected

## 6. Workspace folder structure

```text
Finance/
  Workspace.md
  .finance-meta/
    manifest.json
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
    savings-goal-contributions.csv
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
- `.finance-meta/` is app-managed support data, but not the source of truth for finance content.
- Backups live inside `.finance-meta/backups/` and use timestamped copies.
- `Accounts/accounts.csv` is the unified master account registry for all account types, including investment accounts. Investment-specific metadata (tax treatment, performance tracking) is stored as optional columns in this file. There is no separate `Investments/accounts.csv`.
- `Personal/rules.csv` is not included in v1. Budget rules and recurring-rule automation are deferred post-MVP.

## 7. File classification rules

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

## 8. File specifications

### 8.1 Workspace.md

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

### 8.2 Unified transactions CSV

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
- **Multi-entry transactions** share a `group_id` while each row keeps a unique `transaction_id`. Transfers and liability payments must net to zero across the group; paycheck gross/net splits carry exactly one `gross` and one `net` row and reconcile `net = gross − Σ(withholding)` (see §15). The `credit` type records a loan / line-of-credit draw-down (cash received, a liability increased).
- **Investment buys/sells are recorded here** as `type = trade` rows (with `sending_asset_id`/`receiving_asset_id` and the optional trade columns), absorbing the former `Investments/transactions.csv` (§8.9).

### 8.3 Unified categories CSV

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

### 8.4 Budgets (definition + allocations)

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

### 8.5 Savings goals CSV

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
| linked_note_id | string |

Optional:
- sleeve_id
- priority
- auto_fund_from_budget

Goal lifecycle states (active/archived) are V2. In v1 every row in `goals.csv` is an active goal; the user adds and removes rows directly. No `status` column is read or written.

### 8.6 Savings progress CSV

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

### 8.7 Investment accounts

Investment accounts are stored in `Accounts/accounts.csv` (spec 8.21), the unified master registry. There is no separate `Investments/accounts.csv` file. Investment-specific metadata is carried as optional columns in the master registry (see §8.21). This file type and path are removed from the workspace structure.

### 8.8 Assets CSV  *(was Holdings)*

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

### 8.9 Reserved (Absorbed into Unified Transactions)

Investment buys/sells are recorded in the unified transactions ledger (§8.2) as `type = trade` rows, carrying the optional `trade_type`, `quantity`, `price`, `fees`, `lot_id`, `ticker`, and `sleeve_id` columns alongside `sending_asset_id`/`receiving_asset_id`. The former `Investments/transactions.csv` is removed; the schema migration moves its rows into the monthly ledger.

### 8.10 Prices CSV

Path:
`Investments/prices.csv`

Required columns:

| Column | Type |
|---|---|
| ticker | string |
| date | date |
| close | decimal |

### 8.11 S&P 500 benchmark CSV

Path:
`Investments/benchmarks/sp500.csv`

Required columns:

| Column | Type |
|---|---|
| date | date |
| close | decimal |
| source | string |

This file enables comparison views for short-, medium-, and long-term performance.

### 8.12 Sleeves CSV

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

The free-text `strategy` column moves to `Portfolio.strategy` (§8.26).

### 8.13 Sleeve targets CSV

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

### 8.14 Account-groups CSV  *(was Customizable entities/themes)*

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

### 8.15 Reserved (Absorbed into Unified Transactions)

### 8.16 Reserved (Absorbed into Unified Categories)

### 8.17 Reserved (Absorbed into Unified Budgets)

### 8.18 Tax settings CSV

Path:
`Taxes/settings.csv`

Required columns:

| Column | Type |
|---|---|
| key | string |
| value | string |
| tax_year | integer |

### 8.19 Estimated payments CSV

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

### 8.20 Markdown note files

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

### 8.21 Accounts registry CSV

Path:
`Accounts/accounts.csv`

Purpose: Master account registry covering all account type groups. This is the workspace-level source of truth for all accounts referenced across personal transactions, business transactions, and investment holdings.

Required columns:

| Column | Type | Notes |
|---|---|---|
| account_id | string | Stable unique ID referenced across all transaction files |
| display_name | string | User-visible name |
| institution | string | Bank, brokerage, employer, etc. |
| account_group | enum | employment, business, credit_card, investment, savings, checking, loan (high-level classification; distinct from the Account-group object / `account_group_id`) |
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
- On workspace bootstrap, seed six starter accounts: personal bank, personal credit card, business bank, business credit card, savings, and investment (see §21 bootstrap decision).

### 8.22 Account rules CSV

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

### 8.23 Tax-adjustments CSV  *(was Tax deductions)*

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

### 8.24 Tax archive files

Path pattern:
`Taxes/archive/YYYY-tax-adjustments.csv`
`Taxes/archive/YYYY-estimated-payments.csv`
(Archives written before the Round 6 rename retain their original `YYYY-deductions.csv` name.)

Purpose: Prior-year snapshots written when a tax year is closed. Schema mirrors the active-year files. The presence of an archive file for a given year signals that the year is closed for editing.

Archive files are read-only after creation. The app should warn before any write to an archived year.

### 8.25 Liabilities CSV

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

### 8.26 Portfolios CSV

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

### 8.27 Tax estimates CSV

Path:
`Taxes/estimates.csv`

Purpose: A year's projected tax liability — distinct from logged estimated payments (§8.19).

| Column | Type | Notes |
|---|---|---|
| estimate_id | string | Stable key |
| fiscal_year | integer | |
| estimated_income | decimal | |
| estimated_deductions | decimal | |
| projected_liability | decimal | |
| target_safe_harbor | decimal | Optional |

### 8.28 Tax documents CSV

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

## 9. Metadata model

Each file should have machine-readable metadata at one of three levels:
- path metadata
- filename metadata
- in-file metadata

### Required metadata attributes

| Attribute | Applies to | Purpose |
|---|---|---|
| schema_version | CSV, Markdown | Validation and migration. Increment on any breaking change. |
| domain | All | budget, savings, investments, business, taxes, notes |
| subtype | All | transactions, goals, note, budget, prices, etc. |
| period | Monthly files | Time grouping |
| account_group_id | Account-group-scoped files | Account-group ownership (was `entity_id`) |
| account_id | Account-specific files | Source scoping |
| account_group | Account files, transaction files | Group-level classification for account type routing |
| created_at | Markdown preferred | Audit trail |
| updated_at | Optional | UI freshness |
| source | Optional | Imported origin |

### Schema version migration policy

A **breaking change** is any modification to a CSV column or Markdown front matter field that is currently in use — including: renaming a column, removing a column, changing a column's type or enum values, or adding a required column to an existing file type.

Adding a new optional column is **not** a breaking change.

When a breaking change is introduced:
- The `schema_version` integer in that file type's schema definition is incremented.
- A migration script is supplied as part of the release that introduces the change.
- Migration scripts live in `Scripts/` and follow the naming convention `migrate-{file-type}-v{old}-to-v{new}.swift`.
- The `RepairService` detects version mismatches during validation and prompts the user to run the applicable migration script. It does not auto-migrate breaking changes.
- After migration, the `schema_version` header value in the affected CSV files is updated to the new version.

### App-managed manifest

Path:
`.finance-meta/manifest.json`

Purpose:
- current workspace snapshot
- file discovery cache
- file classification results
- hash and modified-date tracking
- last validation results summary

Suggested shape:
```json
{
  "workspace_id": "finance-main",
  "last_indexed_at": "2026-05-10T11:00:00Z",
  "files": [
    {
      "path": "Personal/transactions/2026-05.csv",
      "domain": "personal",
      "subtype": "transactions",
      "schema_version": 1,
      "hash": "sha256:...",
      "modified_at": "2026-05-10T10:55:00Z",
      "validation_status": "warning"
    }
  ]
}
```

## 10. Internal data model

Canonical entities:
- Workspace
- FileRecord
- ValidationIssue
- RepairAction
- Account
- Liability
- AccountRule
- AccountEstimate
- PersonalTransaction
- PersonalCategory
- PersonalBudget
- BudgetAllocation
- SavingsGoal
- SavingsProgress
- Asset
- Trade
- PricePoint
- BenchmarkPeriod
- Portfolio
- PortfolioSleeve
- SleeveTarget
- BusinessEntity
- BusinessTransaction
- BusinessBudget
- EstimatedPayment
- TaxAdjustment
- TaxEstimate
- TaxDocument
- TaxArchiveYear
- NoteDocument

Notes:
- `Account` is the master registry entity (all account groups, including investment). Investment-specific fields (`tax_treatment`, `performance_tracking`) are optional properties on `Account`, not a separate `InvestmentAccount` type. The `PortfolioEngine` filters to `account_group: investment` rows when building portfolio projections.
- `BenchmarkPeriod` models the discrete comparison windows (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) used in the benchmark heat map.

Cross-domain entities:
- AccountSummaryCard
- MonthlySnapshot
- GoalFundingLink
- SleeveFundingLink
- TaxPrepSummary
- TaxDeductionSummary
- BusinessMonthlySummary
- OverviewSummaryCard

## 11. Application architecture

### Recommended stack

- SwiftUI for macOS UI and scene management.
- Swift Charts for all chart rendering (pie/donut, sparklines, holdings heat map, monthly net-income, portfolio). Charts use real charting, not hand-authored placeholder SVGs; the prototype uses a real charting library as the equivalent.
- Observation for app state and model updates.
- Foundation `FileManager` for workspace access.
- `NSFileCoordinator` for coordinated reads and writes where needed around iCloud documents.
- Uniform Type Identifiers for file-type declaration and import/export boundaries.

### Module layout

```text
FinanceWorkspaceApp/
  App/
    FinanceWorkspaceApp.swift
    AppRouter.swift
    AppState.swift
  Platform/
    WorkspaceManager.swift
    CloudStorageProvider.swift       (protocol)
    ICloudContainerService.swift     (v1 CloudStorageProvider implementation)
    FileIndexService.swift
    FileWatcherService.swift
    BackupService.swift
    FileCoordinatorService.swift
  Parsing/
    CSV/
      CSVParserService.swift
      CSVSchemaRegistry.swift
      CSVNormalizer.swift
    Markdown/
      MarkdownParserService.swift
      FrontMatterParser.swift
  Domain/
    Accounts/
      AccountEngine.swift
      AccountModels.swift
    Budget/
      BudgetEngine.swift
      BudgetModels.swift
    Savings/
      SavingsGoalEngine.swift
    Investments/
      PortfolioEngine.swift
      BenchmarkEngine.swift
    Business/
      BusinessEngine.swift
    Taxes/
      TaxEngine.swift
      TaxPrepEngine.swift
      TaxAdjustmentEngine.swift
    CrossDomain/
      LinkingEngine.swift
      OverviewEngine.swift
  Validation/
    ValidationEngine.swift
    RuleCatalog.swift
    RepairService.swift
  Persistence/
    ManifestStore.swift
    SettingsStore.swift
  UI/
    Overview/
    Accounts/
    Budget/
    SavingsInvestments/
    Business/
    Taxes/
    Notes/          (V2)
    Issues/         (V2)
    Files/          (V2)
    Shared/
  Scripts/
    bootstrap-workspace.swift
    validate-workspace.swift
    repair-workspace.swift
    import-csv.swift
    export-summary.swift
```

## 12. Service responsibilities

### CloudStorageProvider (protocol)
- defines the minimum interface all storage backends must implement: `resolveWorkspaceURL()`, `syncState`, `isAvailable`
- `ICloudContainerService` is the v1 conforming implementation
- additional backends (Google Drive, Dropbox, local folder) conform to this protocol in V2

### WorkspaceManager
- resolve workspace URL via the active `CloudStorageProvider`
- create initial directory tree
- restore last active workspace
- validate minimum required paths
- expose workspace state to UI

### ICloudContainerService
- conforms to `CloudStorageProvider`
- resolve ubiquity container
- expose availability state
- provide diagnostics for missing entitlements or unavailable container

### FileIndexService
- recursively scan `.csv` and `.md`
- classify files
- compute hashes
- update manifest
- emit change events

### FileWatcherService
- observe file changes
- debounce rescans
- notify dependent projections

### CSVParserService
- parse raw CSV
- map headers
- enforce schema
- normalize types
- attach source provenance

### MarkdownParserService
- parse front matter
- extract body
- validate note types and links

### ValidationEngine
- run per-file validation
- run cross-file reference validation
- run domain logic validation
- classify issues as error, warning, info
- classify issues as repairable or manual

### RepairService
- create missing files from templates
- normalize headers
- inject missing optional columns
- regenerate manifest
- create backup before every write

### Domain engines
- `AccountEngine`: aggregate account overview (all accounts, monthly inflow, YTD net income, cash inflow vs retained equity); account-group grouping (personal, employment, business, custom); per-group detail screen (individual-account cards, business P&L with inline ledger, paycheck/stock details, personal net worth & cash flow trends); per-account detail screen (monthly gross vs expenses/tax, YTD net income, transactions table); derives account balances and `Liability.principal_balance` from the ledger; account rule and estimate projections; resolves multi-entry transaction groups; cross-references all unified transactions and investment records
- `BudgetEngine`: budget totals, category variance, 3-month trailing averages, contribution planning; resolves each Budget's scope (account-groups/accounts) over its allocations
- `SavingsGoalEngine`: goal progress, target gap, funding schedule. No goal lifecycle states in v1 — every goal in `goals.csv` is active; the engine does not branch on status
- `PortfolioEngine`: assets, the Portfolio container and its sleeves, allocation, performance; reads investment trades as `type = trade` rows from the unified ledger
- `BenchmarkEngine`: S&P comparison windows across D/W/M/3M/6M/1Y/3Y/5Y periods, sector performance weighting
- `TaxEngine`: realized gains, estimated payments, income summary, per-account effective rate
- `TaxPrepEngine`: prep checklist, missing input detection, tax archive read/write, year-close flow
- `TaxAdjustmentEngine` (was `DeductionEngine`): tax-adjustment record management (deductions, credits, liabilities); standard-adjustment seeding from filing status and tax year; business-expense cross-reference with AccountEngine; tax-estimate projections; tax-document registry; taxable income minus adjustments projection
- `LinkingEngine`: connect budget-to-goal, portfolio-to-tax, account-to-all-modules

## 13. Read, write, and repair flows

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
2. App builds a write plan. For a delete, it runs a **reference check** (see §15) and includes referencing rows in the plan. A **multi-entry transaction group** (transfer or paycheck split) is written, edited, or deleted as a single atomic unit — all rows sharing a `group_id` move together, and the group must pass its balance/reconciliation check (§15) before write.
3. App previews target file and affected rows (and referencing rows on delete).
4. App creates timestamped backup.
5. App writes changes atomically.
6. App re-indexes affected files.
7. App re-validates and refreshes projections.

**Edit/delete UI placement convention:**
- Objects whose detail opens in the **right panel** — edit and delete actions live at the **bottom of the right panel**.
- Objects with their **own dedicated screen** (e.g. an individual account) — **edit** is in the local screen actions; **delete** is offered inside the edit flow.

### Repair flow

1. Validation marks issue as repairable.
2. App shows repair preview.
3. User confirms.
4. Backup created.
5. Repair applied.
6. Manifest refreshed.
7. Validation rerun.
8. Repair logged.

## 14. Scripts and developer tooling

Because the source of truth is file-based, the project should include scripts for workspace management and testing outside the UI. This also matches a local project-folder workflow well.

### Required scripts

#### `bootstrap-workspace`
Purpose:
- create standard folder tree
- create seed CSV/Markdown templates
- create manifest
- create default categories and budgets
- seed six starter accounts in `Accounts/accounts.csv`: personal bank, personal credit card, business bank, business credit card, savings, investment

CLI example:
```bash
swift Scripts/bootstrap-workspace.swift --workspace ~/Library/Mobile\ Documents/.../Documents/Finance
```

#### `validate-workspace`
Purpose:
- scan workspace
- run schema validation
- print issue summary
- optionally write JSON report

CLI example:
```bash
swift Scripts/validate-workspace.swift --workspace <path> --format json
```

#### `repair-workspace`
Purpose:
- apply known low-risk fixes
- create missing files
- normalize headers
- write backup log

CLI example:
```bash
swift Scripts/repair-workspace.swift --workspace <path> --apply
```

#### `import-csv`
Purpose:
- ingest external CSV
- map to canonical schema
- split into monthly canonical files

#### `export-summary`
Purpose:
- export app-derived monthly or yearly summaries back to CSV or Markdown

### Optional scripts

- `benchmark-import`
- `note-link-audit`
- `schema-migrate`
- `backup-prune`
- `fixture-generate`

## 15. Validation rules

### File-level validation
- missing required file
- unknown file type
- invalid file name
- duplicate monthly file
- invalid CSV header
- invalid date
- invalid decimal
- missing required front matter
- invalid enum value

### Cross-file validation
- unknown category reference
- unknown account-group reference
- unknown account reference
- unknown asset reference
- unknown liability reference
- unknown portfolio reference
- unknown sleeve reference
- unknown goal reference
- missing benchmark data
- duplicate transaction ID
- orphan note link
- **delete with reference check**: before deleting a row, resolve inbound references (e.g. an account group referenced by accounts; an account referenced by transactions/holdings; a category referenced by transactions). The write preview must list referencing rows and block or warn per the chosen default. (Default behavior — block vs. cascade-warn vs. reassign — is an open decision tracked in `docs/_notes/object-model-audit.md` G7; pick before implementing Phase 6 delete flows.)

### Domain validation
- budget period without budget rows
- goal contribution without goal
- asset without account
- trade without a sending or receiving asset
- multi-entry transfer group that does not net to zero (`SUM(amount) WHERE group_id = X ≠ 0`)
- gross/net group that does not reconcile (`net ≠ gross − Σ(withholding)`, or not exactly one `gross` and one `net` row)
- tax payment outside tax year
- business transaction with unknown account-group

### Repairable issue types
- missing optional column
- header casing mismatch
- missing seed file
- missing folder
- blank optional field normalization

### Manual-only issue types
- conflicting IDs
- ambiguous category remap
- impossible date repair
- duplicated but divergent transactions
- broken business entity linkage

## 16. UI requirements by section

### Overview
No filters. Fixed read-only dashboard.

Must show:
- KPI cards: monthly cash flow (Budget), total savings balance (Savings), total investment value (Investments), YTD net income (Business), estimated return (Taxes)
- Month-over-month panel: budget cash flow trend, savings & investments totals trend
- Issues table: validation issues surfaced inline, grouped by severity with repairable badge

### Accounts
The all-accounts overview must show:
- Card grid: grouped by customizable account group (Personal Accounts, Place of Employment, Business Groups) showing institution, type, monthly cash inflow, YTD net income. Account cards are clickable and open the per-account screen.
- Aggregate header: total monthly cash inflow, YTD net income, total active accounts across the workspace

Account-group detail screens (one screen per group, no sub-tabs) must show:
- An individual-accounts card section (the same account card as the all-accounts grid) above the transaction ledger
- **Business group**: monthly P&L-style summary (income, fixed expenses, discretionary, net income) with the monthly net-income chart, the transaction ledger **inline below the net-income chart**, expense category view, category budgets, and linked group notes/monthly reviews.
- **Employment group**: Payroll deposits, HSA/FSA benefits, employer stock vests (ESPP/RSU).
- **Personal group**: Net worth and cash flow trends, personal savings goals link.

Per-account detail screen (reached by selecting an account card) must show:
- Transactions table for the account; monthly gross income vs expenses/tax, YTD net income
- Transaction import, add, edit, and delete within account context
- Account rules and estimates view
- Edit in local screen actions; delete inside the edit flow (per §13 convention)

### Budget
Must show:
- Pie chart: breakdown of fixed expenses, discretionary, savings, investments as % of monthly net income
- Spend Mix and Spending Variance panels at an equal 50/50 split (neither dominant nor cut off)
- Monthly totals with plan-vs-actual variance per category
- 3-month trailing average per category (show partial average when fewer than 3 months available)
- Category and subcategory management with manual create and edit
- Category group totals
- Transaction ledger per period
- Contribution-to-goals summary

### Savings & Investments

**Goals** must show:
- Goal cards with progress bar, target amount, current balance, monthly contribution
- Monthly funding status per goal
- Goal-to-budget contribution links
- Linked transactions and notes per goal
- A single flat goal list — no active/archived grouping (goal lifecycle states are V2)

**Portfolio** must show:
- Holdings table as the primary surface (account-level and aggregate)
- Holdings table view toggle: standard holdings table ⇄ heat map table showing % growth per period (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) — this replaces the dedicated benchmark view
- S&P 500 % growth comparison per account (Brokerage, Savings, IRA) and sector performance weighted against S&P 500, presented within the heat-map mode
- Account allocation view
- Tax-lot drill-down
- Sleeve table appended at the bottom: sleeve list with strategy description, monthly contribution target, target vs actual weights, drift indicator, linked strategy notes

### Taxes

**Current tax year** must show:
- YTD taxable income, taxes paid vs taxes owed, effective rate per account
- Estimated payment schedule by quarter and year (no separate Estimated Payments screen)
- Realized gain/loss summary and income summary — dividends, interest (no separate Gains & Income screen)
- Deductions view: standard vs itemized comparison, above-the-line deductions, Schedule C items linked to business entities (no separate Deductions screen)
- Taxable income minus deductibles projection
- Business tax-prep summary derived from categorized business expenses

It must NOT show the prep checklist — the checklist lives on its own screen.

**Prep checklist** must show:
- The prep checklist as the full-width, focal content of the screen — no competing elements
- Educational content explaining each tax-prep step to the user
- Complete, incomplete, and missing-input states
- Source links for each checklist item

**Tax archive** must show:
- Prior-year read-only archive selector
- Archived deductions and estimated payment history per closed year

### Notes *(V2)*
Must show:
- Note list
- Linked-entity context
- Front matter inspector
- Preview mode
- Source file path

### Issues *(V2)*
Must show:
- Grouped issues
- Severity
- Repairable badge
- Affected files
- Repair preview

## 17. Commands and menus

Recommended macOS commands:
- New Workspace
- Open Workspace
- Reindex Workspace
- Validate Workspace
- Repair Selected Issue
- Open Source File
- Reveal in Finder
- Export Current View
- Toggle Inspector
- Open Backup Folder

## 18. Performance and caching

- Keep canonical data in files, not in a hidden DB.
- Maintain an in-memory projection cache for UI speed.
- Optionally persist non-authoritative cache artifacts in `.finance-meta/manifest.json`.
- Re-scan incrementally based on hash and modified date.
- Debounce watcher-triggered refreshes.

## 19. Security and safety

- Do not mutate files silently.
- Do not auto-apply repairs without preview.
- Backup before every write or repair.
- Track every repair in `.finance-meta/logs/repair-log.csv`.
- Mark app-generated files clearly in front matter or seed comments.

## 20. Rapid prototype order

1. Workspace bootstrap and indexing
2. CSV and Markdown parsing
3. Overview projections (default landing dashboard, no filters, issues table inline; issues chip in the global header)
4. Accounts module (master registry, account-group screens with individual-account cards and inline ledger — no sub-tabs, dedicated per-account screen, account rules)
5. Budget module (pie chart overview, category management, 3-month trailing averages)
6. Savings & Investments (flat goal list; holdings-focal portfolio with heat-map toggle and sleeve table)
7. Business group reporting
8. Tax module (consolidated current-year view with payments, gains/income, and deductions inline; per-account rates; full-width prep checklist screen; archive)
9. Structured write flows
10. Repair workflows
11. Notes viewer *(V2)*
12. Issues management view *(V2)*

Rationale for order: Accounts is built before other modules because personal, business, and investment transaction files all reference `account_id` from the master registry. Having it early keeps subsequent module builds cleaner.

## 21. Decisions to lock before build

### Locked by PRD

These decisions are settled and should not be reopened for v1:

- **App-owned iCloud container first** ✓ — single workspace, app-owned ubiquity container
- **Single workspace first** ✓
- **Strict canonical CSV schemas first** ✓
- **Deterministic repair only** ✓ — no speculative or guided migration flows in v1
- **Notes deferred to V2** ✓
- **Issues standalone view deferred to V2** ✓ — issues surfaced in Overview table
- **Budget rules and automation deferred post-MVP** ✓
- **Benchmark import manual in v1** ✓

### Locked — 2026-06-10

- **CloudStorageProvider protocol surface** ✓ — Minimum surface confirmed: `resolveWorkspaceURL() async throws -> URL`, observable `syncState`, `isAvailable: Bool`. The protocol exposes the storage connection status for display in the app settings. Sync-conflict resolution is iCloud-specific and stays on `ICloudContainerService`, not on the protocol.

- **Accounts master registry — unified file** ✓ — `Accounts/accounts.csv` is the single master registry for all account types including investment accounts. Investment-specific metadata (tax treatment, performance tracking) is stored as optional columns in the master file. `Investments/accounts.csv` (spec 8.7) is removed. Budget, Savings & Investments, and Taxes modules use the master registry as their base and add domain-specific views and calculations on top.

- **Savings/ and Investments/ folder separation** ✓ — Keep as separate folders at the file level. The UI presents them as a unified module; the file layer keeps them separate.

- **Deductions → Tax-adjustments file** ✓ — *(Superseded in Round 6.)* The former single `Taxes/deductions.csv` / `deduction_type` is renamed to `Taxes/tax-adjustments.csv` / `adjustment_type`, with the union enum `standard, above_the_line, itemized, business-expense, credit, liability` (`schedule_c` → `business-expense`). Tax-adjustment is now a first-class object that can link to a transaction, category, asset, liability, account, or account-group. See the Round 6 lock block below.

- **Tax year-close trigger — explicit in-app action** ✓ — Tax archive files are written only when the user explicitly triggers "Close Tax Year" in the app. No automatic rollover in v1.

- **Right panel default state — global closed** ✓ — Right pane is closed by default across all sections. It opens when the user interacts with content in the main panel (selection, KPI tap, row inspection). No section-specific auto-open exceptions in v1.

- **iCloud container identifier** ✓ — Container is identified as `OpenFinance`.

- **Workspace bootstrap seed accounts** ✓ — On first launch, bootstrap seeds six starter accounts in `Accounts/accounts.csv`: personal bank account, personal credit card, business bank account, business credit card, savings account, and investment account.

### Locked — 2026-06-10 (Phase 2)

- **Amount sign convention** ✓ — Negative = debit (money out), positive = credit (money in). Applies consistently across all transaction file types. The `direction` column is retained alongside the sign for import mapping readability. The `CSVNormalizer` flips signs from source files that use the opposite convention during import.

- **`schema_version` migration policy** ✓ — A breaking change is any modification to a CSV column or Markdown front matter field currently in use (rename, remove, type change, enum change, or new required column). Adding an optional column is not breaking. Breaking changes increment `schema_version` and require a migration script (`Scripts/migrate-{file-type}-v{old}-to-v{new}.swift`) shipped with the release. The `RepairService` detects version mismatches and prompts the user to run the script; it does not auto-migrate breaking changes.

### Locked — 2026-06-23 (Round 6 — object model)

- **Storage names aligned to object names** ✓ — `entities.csv`→`account-groups.csv` (`entity_id`→`account_group_id`, `entity_type`→`group_type`), `holdings.csv`→`assets.csv` (`holding_id`→`asset_id`, `market_value`→`current_value`), `deductions.csv`→`tax-adjustments.csv` (`deduction_id`→`tax_adjustment_id`, `deduction_type`→`adjustment_type`). These are breaking renames; a one-time, preview-able migration script performs them and bumps `schema_version`.
- **Liability is a first-class object** ✓ — New `Accounts/liabilities.csv` (peer of Asset). An account can hold both an asset and a liability (e.g. a mortgage account holds the property and the loan). Debt fields live on Liability, not as columns on Account. Reverses the earlier "fold debt into account columns" idea.
- **Portfolio is the investment container** ✓ — New `Investments/portfolios.csv`; sleeves re-parent under `portfolio_id`. Adopted instead of the r5-audit "Strategy" container. Group nesting (`parent_group_id`) is **not** adopted in v1.
- **Multi-entry transactions** ✓ — A shared `group_id` (with `group_role`) links the rows of a transfer or paycheck split; `group_id` is a connector, not a primary key. Transfers net to zero; gross/net splits reconcile `net = gross − Σ(withholding)`.
- **Investment trades fold into the unified ledger** ✓ — Recorded as `type = trade` rows in `Accounts/transactions/YYYY-MM.csv`; `Investments/transactions.csv` (§8.9) is removed/absorbed.
- **Account two-tier classification retained** ✓ — Keep `account_group` (enum) + `account_type`; `status` (draft/active/frozen/closed) is the canonical lifecycle field with `is_active` derived.
- **Open** — default delete-on-reference behavior (block / cascade-warn / reassign) is still to be picked before Phase 6 delete flows.

## 22. Recommended implementation stance

Build v1 as:
- app-owned iCloud workspace first
- strict schema first
- single workspace first
- read-mostly with structured writes
- deterministic repair only
- native SwiftUI interface with Observation-based state

That is the lowest-risk architecture for a macOS app whose source of truth is plain files in iCloud Drive, and it fits a Mac-native, project-folder-oriented workflow well.

## 23. Wireframes

#### App shell
![App Shell wireframe](01-app-shell.svg)
Left sidebar with collapsible navigation sections that open and close independently.
> **Outdated (Round 5):** Overview is now the default landing screen reached via the sidebar header ("Finance Dashboard"), not a nav item; the issues chip moves to the global header (left of sync status); the local-actions row moves onto the page-title line (right-aligned); no contextual filter bar. Needs a new wireframe.

#### Accounts
![Accounts wireframe] *(not yet produced)*
> **New (Round 5):** Account-group screen with an individual-account card section above an inline transaction ledger (no sub-tabs); a dedicated per-account screen with a transactions table; "Account groups" / "Personal Accounts" labels. Needs a new wireframe.

#### Overview dashboard
![Overview wireframe](02-overview.svg)
> **Outdated (Round 1):** Monthly Snapshots and Annual Snapshots views removed. Issues table is now surfaced inline here. Needs a new wireframe.

#### Personal budget overview
![Personal Budget wireframe](03-personal-budget.svg)
> **Outdated (Round 1):** Rules section removed. Pie chart overview added. 3-month trailing averages added. Needs a new wireframe.

#### Savings Goals
![Savings Goals wireframe](04-savings-goals.svg)
> **Outdated (Rounds 1, 4):** Savings Goals is now part of the unified Savings & Investments module. Active/archived states removed — goals are a flat list. Needs to be replaced by a combined wireframe.

#### Investments
![Investments wireframe](05-investments.svg)
> **Outdated (Rounds 1, 4):** Investments is now part of the unified Savings & Investments module. Holdings table is now the primary surface; the benchmark heat map is a holdings table view toggle; the sleeve table moves to the bottom of the Portfolio overview. Needs to be replaced by a combined wireframe.

#### Business
![Business wireframe](06-business.svg)

#### Taxes
![Taxes wireframe](07-taxes.svg)
> **Outdated (Rounds 1, 4):** Deductions view, per-account tax summary, and tax archive not represented. Estimated payments and gains & income are now merged into Current Tax Year; the prep checklist is its own full-width screen. Needs a new wireframe.

#### Notes
![Notes wireframe](08-notes.svg)
> **Deferred to V2.**

#### Issues
![Issues wireframe](09-issues.svg)
> **Deferred to V2** as a standalone view. Issues are surfaced in the Overview table in v1.

---

#### Wireframes needed (not yet produced)

- `accounts-overview.svg` — Accounts card grid and per-account detail view
- `budget-updated.svg` — Budget pie chart overview with trailing averages
- `overview-updated.svg` — Revised Overview with Issues table inline
- `portfolio-overview.svg` — Holdings-focal Portfolio with standard ⇄ heat-map toggle and sleeve table at bottom (replaces `savings-investments.svg`)
- `taxes-current-year.svg` — Consolidated Current Tax Year with payments, gains/income, and deductions inline (replaces `taxes-updated.svg`)
- `taxes-prep-checklist.svg` — Full-width prep checklist with educational content

## 24. Changelog

### Round 6 — 2026-06-23
Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & IA); update plan `docs/_refinement/r6-update-technical-design.md`

- §6/§8: renamed `entities.csv`→`account-groups.csv` (`entity_id`→`account_group_id`, `entity_type`→`group_type`), `holdings.csv`→`assets.csv` (`holding_id`→`asset_id`, `market_value`→`current_value`, `asset_class` redefined + new `security_class`), `deductions.csv`→`tax-adjustments.csv` (`deduction_id`→`tax_adjustment_id`, `deduction_type`→`adjustment_type` union enum)
- §6/§8: added `Accounts/liabilities.csv` (Liability), `Investments/portfolios.csv` (Portfolio), `Taxes/estimates.csv` (Tax-estimate), `Taxes/documents.csv` (Tax-document)
- §8.2: transactions gained `type`, `group_id` (generalized from `transfer_group`), `group_role`, `sending_asset_id`/`receiving_asset_id`/`liability_id`, `source_id`, `tags`, and optional trade columns; investment trades fold in as `type = trade` rows
- §8.4: budgets split into a Budget definition (scope) + Budget-allocation lines
- §8.9: `Investments/transactions.csv` reserved/absorbed into the unified ledger
- §8.12: sleeves re-parented under portfolios (`portfolio_id`), +`goal`/+`target_allocation_percentage`
- §8.21: accounts `entity_id`→`account_group_id`, +`status` lifecycle (`is_active` derived), +derived `current_balance`/`available_balance`; two-tier `account_group`+`account_type` retained
- §8.3: categories `entity_id`→`account_group_id`, +`parent_category_id`, +`sort_order`, `group_id`→`category_group_id`
- §9/§10/§12/§13/§15: metadata key renamed; data model + engines updated (liability balances, Portfolio container, `TaxAdjustmentEngine`); multi-entry group write + validation rules added
- §21: reopened the deductions-file decision; added the Round 6 lock block (storage-name alignment, first-class Liability, Portfolio container, multi-entry, trades-in-unified-ledger, two-tier account classification)
- Overrides the r5 object-model audit where they differ (`account_group_id` not `group_id`, Portfolio not Strategy, `asset_class` not `asset_kind`, no group nesting) — r6-review takes priority; delete-on-reference behavior remains open

### Round 5 — 2026-06-15
Source: `docs/_refinement/r5-review.md` (third prototype review — functional details); update plan `docs/_refinement/r5-update-technical-design.md`

- §4: Overview removed as a nav item — it is the default landing screen reached via the sidebar header ("Finance Dashboard"); removed the Contextual filters block (filter bar → V2); issues count moved to a global header chip left of sync status; local-actions row moved onto the page-title line (right-aligned); account labels "themes/entities" → "account groups", "Personal Assets" → "Personal Accounts", "New entity" → "New group"
- §11: Added Swift Charts as the charting dependency; charts are real charts, not placeholder SVGs
- §13: Delete is now a first-class structured write for all user-addable objects; added the edit/delete UI placement convention (right-panel bottom vs. dedicated-screen edit flow)
- §15: Added a delete-with-reference-check write rule
- §16: Accounts — account-group screens show an individual-accounts card section and (business) ledger inline below the net-income chart; sub-tabs removed; new per-account detail screen; Budget — Spend Mix / Spending Variance panels set to 50/50; per-screen filter bar removed
- §20/§23: Noted dashboard-default + per-account screen + real charts; flagged app-shell and added Accounts wireframes
- No CSV file specs changed; deeper object-model work (entity→group rename, nesting, Budget/Strategy containers, asset kinds) deferred — see `docs/_notes/object-model-audit.md`

### Round 4 — 2026-06-12
Source: `docs/_refinement/r4-review.md` (second prototype review); update plan `docs/_refinement/r4-update-technical-design.md`

- §4: Savings & Investments sidebar reduced to Overview, Goals, Portfolio (Assets removed — holdings live inside the Portfolio view); Taxes sidebar confirmed already trimmed (Round 3)
- §8.5: Removed `status` column from `Savings/goals.csv`; goal active/archived lifecycle deferred to V2 with explanatory note
- §10: Removed stray `InvestmentAccount` from the canonical entity list (Round 3 leftover — the entity was already folded into `Account`)
- §12: `SavingsGoalEngine` noted as having no goal lifecycle states — no status branching in v1
- §16: Restructured Savings & Investments — holdings table is the primary Portfolio surface; benchmark heat map is now a holdings table view toggle; sleeve table appended at the bottom of the Portfolio view; removed the standalone Assets and sleeve-only Portfolio subsections; Goals shows a flat list
- §16: Taxes — Estimated payments, Gains & income, and Deductions confirmed inline within Current tax year with explicit no-separate-screen notes; added "must NOT show the prep checklist" to Current tax year; Prep checklist rewritten as a full-width focal screen with educational content
- §20: Reworded prototype order to fold removed screens into parent steps
- §23: Flagged Savings Goals, Investments, and Taxes wireframes as outdated (Round 4); replaced two planned wireframes and added `taxes-prep-checklist.svg` to the needed list
- No CSV file specs removed — sleeves (§8.12/§8.13), benchmark (§8.11), and estimated payments (§8.19) all retained; only presentation surfaces changed

### Round 3 — 2026-06-10
Source: User direction — sidebar navigation structure refinement; user decision — locked all Phase 1 open architectural decisions before build starts.

- §4 (initial): Clarified sidebar definition: static, expandable groups only where specified; removed "Dashboard" sub-item from Overview (now a leaf item); renamed "All accounts" → "Overview" and "Themes & Entities" → "Themes / entities" under Accounts; removed "Specific account links" and "Specific category links"; replaced Savings & Investments nested Goals/Portfolio structure with flat items (Overview, Goals, Assets, Categories); simplified Taxes to three items (Current tax year, Prep checklist, Tax archive), removing Estimated payments, Gains & income, and Deductions as sidebar navigation items
- §4 (audit resolution): Added data-driven links note explaining the Themes / entities pattern; added "Portfolio" back to Savings & Investments sidebar for sleeve navigation; removed "Workspace root", "Nested saved views", and "Nested report links" from App shell Left sidebar abstract list; removed "Business" from the module-sections filter note (Business is a theme type, not a top-level section); removed undefined "Categories" item from Savings & Investments sidebar (deferred — category and tag systems for Budget and S&I to be considered together)
- §5: Updated workspace resolution path to use confirmed iCloud container identifier `OpenFinance`; updated code example
- §6: Removed `Investments/accounts.csv` from folder tree; updated folder design rule to reflect unified master registry
- §8.7: Removed separate `Investments/accounts.csv` spec; replaced with note redirecting to unified `Accounts/accounts.csv`
- §8.21: Added optional investment-specific columns (`tax_treatment`, `performance_tracking`) to master accounts registry; updated bootstrap note to list six seed accounts
- §10: Updated `Account` entity note to remove `InvestmentAccount` as a separate type; investment-specific fields are optional properties on `Account`
- §8.2: Clarified `amount` column note with locked sign convention; updated behavior note with normalization rule for import
- §9: Updated `schema_version` metadata attribute description; added "Schema version migration policy" subsection
- §14: Updated `bootstrap-workspace` purpose to list six seed accounts
- §16: Restructured Savings & Investments requirements under nav item headings (Goals, Assets, Portfolio) — sleeve content explicitly assigned to Portfolio; restructured Taxes requirements under nav item headings (Current tax year, Prep checklist, Tax archive) — Estimated payments, Gains & income, and Deductions explicitly placed within Current tax year
- §21: Locked all six previously-open Phase 1 decisions; added iCloud container identifier and workspace bootstrap seed accounts as additional locked decisions; added Phase 2 locked section with amount sign convention and schema_version migration policy

### Round 2 — 2026-06-09
Source: User direction — future-proofing for multi-cloud and additional file formats.

- §2: Added storage provider abstraction as a primary design goal
- §5: Added "Storage provider abstraction" subsection with `CloudStorageProvider` protocol shape and V2 provider list (Google Drive, Dropbox, local folder)
- §7: Added xlsx UTType note with V2 designation and CSV-boundary conversion strategy
- §11: Added `CloudStorageProvider.swift` (protocol) to Platform module layout; annotated `ICloudContainerService` as v1 conforming implementation
- §12: Added `CloudStorageProvider` protocol service entry; updated `WorkspaceManager` and `ICloudContainerService` descriptions to reflect protocol relationship
- §21: Added `CloudStorageProvider` protocol surface as a new open decision

### Round 1 — 2026-06-08
Source: `docs/product-requirements.md` (post Round 1 updates), `docs/_refinement/r1-update-technical-design.md`

- §3: Added accounts to domain layer list
- §4: Updated primary navigation (Accounts added, Savings Goals + Investments → Savings & Investments, Rules removed, Monthly/Annual Snapshots removed, Notes/Issues/Files marked V2); updated sidebar nested structure; added right panel collapsibility spec; added Overview no-filters policy
- §6: Added `Accounts/` folder with `accounts.csv` and `account-rules.csv`; removed `Personal/rules.csv`; added `Taxes/deductions.csv` and `Taxes/archive/`; added `account.schema.json` and `tax-deductions.schema.json` to `.finance-meta/schemas/`; updated folder design rules
- §8: Added specs 8.21 (accounts registry), 8.22 (account rules), 8.23 (tax deductions), 8.24 (tax archive)
- §9: Added `account_group` to metadata attributes table
- §10: Added Account, AccountRule, AccountEstimate, BenchmarkPeriod, DeductionRecord, TaxArchiveYear to canonical entities; added AccountSummaryCard, TaxDeductionSummary to cross-domain entities; added notes on Account vs InvestmentAccount relationship
- §11: Added `Domain/Accounts/`; added `Domain/Taxes/DeductionEngine.swift`; renamed `UI/Savings/` + `UI/Investments/` → `UI/SavingsInvestments/`; added `UI/Accounts/`; added `UI/Files/` (V2); marked Notes/Issues/Files (V2)
- §12: Added AccountEngine description; expanded TaxEngine into TaxEngine + TaxPrepEngine + DeductionEngine with distinct responsibilities; updated BenchmarkEngine for heat map periods; updated LinkingEngine
- §16: Replaced all section requirements — Overview (KPI cards, no filters, inline issues), Accounts (new section), Budget (pie chart, trailing averages, no Rules), Savings & Investments (merged, benchmark heat map), Taxes (deductions, per-account rates, archive), Notes/Issues marked V2
- §20: Reordered prototype sequence — Accounts moved to step 4 (before Budget); Issues/Notes moved to end as V2 steps 11–12
- §21: Split into Locked and Open sections; locked 8 decisions from PRD; added 5 open questions for build-start decisions
- §23: Flagged outdated wireframes; added list of 5 needed wireframes
