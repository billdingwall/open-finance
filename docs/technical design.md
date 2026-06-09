
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
- Overview
- Accounts
- Budget
- Savings & Investments
- Taxes
- Settings

Deferred to V2:
- Notes
- Issues
- Files

### Left sidebar structure

The left sidebar should support expandable groups under the relevant top-level section. The sidebar is for navigation only, not for temporary or view-specific filters.

Examples:
- **Overview**
  - Dashboard
- **Accounts**
  - All accounts
  - Themes & Entities (user-customizable, loaded from `Accounts/entities.csv`):
    - Personal Assets (Personal)
    - Place of Employment (Employment)
    - Consulting LLC (Business)
    - Freelance (Business)
    - Rental LLC (Business)
  - Specific account links
- **Budget**
  - Overview
  - Budget history
  - Categories
  - Specific category links
- **Savings & Investments**
  - Overview
  - Goals
    - Active goals
    - Archived goals
    - Specific goal links
  - Portfolio
    - Portfolio overview
    - Accounts
    - Sleeves
    - Holdings
    - Benchmarks
    - Specific account links
    - Specific sleeve links
- **Taxes**
  - Current tax year
  - Estimated payments
  - Gains & income
  - Deductions
  - Tax archive
  - Prep checklist
- **Notes** *(V2)*
  - Monthly reviews
  - Strategy notes
  - Business notes
  - Tax notes
- **Issues** *(V2)*
  - All issues
  - Repairable
  - Manual review

### App shell

#### Left sidebar

Primary navigation only:
- Workspace root
- Top-level domains
- Nested entity links
- Nested saved views
- Nested report links
- Nested note groups

#### Main panel

The center panel becomes the primary working area for the currently selected navigation item. It should contain the contextual header, contextual filters, and the main content view.

Main-panel structure:
1. **Context header**
   - Selected view title
   - Breadcrumb or parent context
   - Quick actions
   - Sync status
   - Issue status

2. **Contextual filters**
   - Period selector
   - Date range
   - Account selector
   - Business entity selector
   - Portfolio sleeve selector
   - Goal selector
   - Category selector
   - Severity selector
   - Search
   - Saved view selector

3. **Content surface**
   - Table
   - Card grid
   - Chart area
   - Summary rows
   - List view
   - Empty state
   - Validation state

Filters should always live in the main panel directly above or beside the content they affect. Filters should never be treated as global unless they are explicitly designed as workspace-wide state.

The **Overview section has no filters**. It is a fixed read-only dashboard. Filters apply only within module sections (Accounts, Budget, Savings & Investments, Business, Taxes).

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
- Nested links change the selected entity or scoped view within that domain.
- Filters do not live in the sidebar; they are scoped to the current main-panel view.
- The sidebar should preserve expansion state for nested groups.
- The main panel should preserve filter state per view when practical.
- The right panel should update based on selection, not navigation alone.
- Deep links should be representable as domain plus nested entity plus local filter state.
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

### Workspace resolution

Primary path pattern:
```swift
FileManager.default
  .url(forUbiquityContainerIdentifier: nil)?
  .appendingPathComponent("Documents")
  .appendingPathComponent("Finance")
```

This is the common way to construct a Documents path inside the app’s ubiquity container.

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
      transaction.schema.json
      holdings.schema.json
      tax-deductions.schema.json
      markdown-note.schema.json
    backups/
    logs/
      repair-log.csv
      import-log.csv
  Accounts/
    accounts.csv
    entities.csv
    account-rules.csv
    transactions/
      2026-01.csv
      2026-02.csv
  Budget/
    categories.csv
    budgets.csv
    savings-goal-contributions.csv
  Savings/
    goals.csv
    progress.csv
  Investments/
    accounts.csv
    holdings.csv
    transactions.csv
    prices.csv
    dividends.csv
    tax-lots.csv
    sleeves.csv
    sleeve-targets.csv
    benchmarks/
      sp500.csv
  Taxes/
    estimated-payments.csv
    settings.csv
    deductions.csv
    archive/
      2025-deductions.csv
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
- `Accounts/accounts.csv` is the master account registry for all account types. `Investments/accounts.csv` holds investment-specific metadata and links to the master registry via `account_id`.
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
3. Front matter `period`, `entity_id`, `account_ids`, `sleeve_id`, `tax_year`, or tags.

### Supported file types

Use Uniform Type Identifiers for file handling and file import/export boundaries.

Recommended UTType handling:
- CSV: `public.comma-separated-values-text` where available via system type mappings.
- Markdown: custom or mapped plain text/markdown type depending on platform availability.
- JSON: internal metadata only.
- Plain text fallback for unsupported note content.

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
| transaction_id | string | Stable unique ID |
| date | date | ISO 8601 date |
| account_id | string | Links to account |
| merchant | string | Raw merchant |
| description | string | User-facing text |
| amount | decimal | Signed |
| direction | enum | debit, credit |
| category_id | string | Normalized category |
| subcategory_id | string | Optional |
| transfer_group | string | Optional |
| savings_goal_id | string | Optional |
| deductible | boolean | Flag for tax module inclusion (Schedule C) |
| notes | string | Optional |
| source_file | string | Optional provenance |
| source_row | integer | Optional provenance |

Behavior:
- Must support import from external CSV then normalization into canonical monthly files.
- Amount sign rules must be documented and enforced.
- `transaction_id` must remain stable across recategorizations.

### 8.3 Unified categories CSV

Path:
`Budget/categories.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| category_id | string | |
| group_id | string | |
| name | string | |
| type | enum | |
| default_budget_behavior | enum | |
| is_active | boolean | |
| tax_relevant | boolean | |
| entity_id | string | Optional — links to a specific theme/entity |
| tax_group | string | Optional — maps category to Schedule C/tax lines |

Notes:
- Seed with default category groups aligned to common card and personal finance reporting patterns.
- Support user-editable category naming without changing IDs.

### 8.4 Unified budgets CSV

Path:
`Budget/budgets.csv`

Required columns:

| Column | Type |
|---|---|
| period | yyyy-mm |
| category_id | string |
| planned_amount | decimal |
| rollover_policy | enum |
| priority | enum |

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
| status | enum |
| linked_note_id | string |

Optional:
- sleeve_id
- priority
- auto_fund_from_budget

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

### 8.7 Investment accounts CSV

Path:
`Investments/accounts.csv`

Required columns:

| Column | Type |
|---|---|
| account_id | string |
| name | string |
| institution | string |
| account_type | enum |
| tax_treatment | enum |
| is_active | boolean |

### 8.8 Holdings CSV

Path:
`Investments/holdings.csv`

Required columns:

| Column | Type |
|---|---|
| holding_id | string |
| account_id | string |
| ticker | string |
| quantity | decimal |
| cost_basis | decimal |
| market_value | decimal |
| sleeve_id | string |
| asset_class | enum |
| sector | string |
| as_of_date | date |

### 8.9 Investment transactions CSV

Path:
`Investments/transactions.csv`

Required columns:

| Column | Type |
|---|---|
| trade_id | string |
| account_id | string |
| ticker | string |
| trade_date | date |
| trade_type | enum |
| quantity | decimal |
| price | decimal |
| fees | decimal |
| lot_id | string |
| sleeve_id | string |

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

| Column | Type |
|---|---|
| sleeve_id | string |
| name | string |
| strategy | string |
| monthly_contribution_target | decimal |
| benchmark_id | string |
| linked_note_id | string |

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

### 8.14 Customizable entities/themes CSV

Path:
`Accounts/entities.csv`

Required columns:

| Column | Type | Notes |
|---|---|---|
| entity_id | string | Unique entity key |
| display_name | string | User-visible name |
| legal_name | string | Legal business name (optional) |
| entity_type | enum | `personal`, `employment`, `business`, `custom` |
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
entity_ids: [consulting-llc]
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
| account_group | enum | employment, business, credit_card, investment, savings, checking, loan |
| account_type | string | Specific type within group (e.g. roth_ira, hysa, mortgage) |
| is_active | boolean | |
| tax_relevant | boolean | Flag for tax module inclusion |
| tax_year_opened | integer | Optional |
| entity_id | string | Required — links account to a theme/entity in Accounts/entities.csv |
| notes | string | Optional |

Notes:
- `Investments/accounts.csv` (spec 8.7) remains for investment-specific metadata (tax treatment, performance tracking). It references `account_id` from this master file.
- On workspace bootstrap, seed with any accounts present in `Investments/accounts.csv` to avoid requiring duplicate entry.

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

### 8.23 Tax deductions CSV

Path:
`Taxes/deductions.csv`

Purpose: Tracks expected and confirmed deductions for the current tax year. Supports all four deduction categories.

Required columns:

| Column | Type | Notes |
|---|---|---|
| deduction_id | string | |
| tax_year | integer | |
| deduction_type | enum | standard, above_the_line, itemized, schedule_c |
| deduction_name | string | e.g. "HSA Contribution", "Home Office", "Mortgage Interest" |
| estimated_amount | decimal | |
| confirmed_amount | decimal | Optional — updated at filing time |
| account_id | string | Optional — links to source account |
| entity_id | string | Optional — links Schedule C items to a BusinessEntity |
| notes | string | Optional |
| status | enum | estimated, confirmed, not_applicable |

Notes:
- The standard deduction row should be seeded by the app on workspace bootstrap using the filing status from `Taxes/settings.csv` and the applicable tax year amount.
- Schedule C rows for a given `entity_id` are surfaced in the Business module as well as the Tax module.

### 8.24 Tax archive files

Path pattern:
`Taxes/archive/YYYY-deductions.csv`
`Taxes/archive/YYYY-estimated-payments.csv`

Purpose: Prior-year snapshots written when a tax year is closed. Schema mirrors the active-year files. The presence of an archive file for a given year signals that the year is closed for editing.

Archive files are read-only after creation. The app should warn before any write to an archived year.

## 9. Metadata model

Each file should have machine-readable metadata at one of three levels:
- path metadata
- filename metadata
- in-file metadata

### Required metadata attributes

| Attribute | Applies to | Purpose |
|---|---|---|
| schema_version | CSV, Markdown | Validation and migration |
| domain | All | budget, savings, investments, business, taxes, notes |
| subtype | All | transactions, goals, note, budget, prices, etc. |
| period | Monthly files | Time grouping |
| entity_id | Business files | Entity ownership |
| account_id | Account-specific files | Source scoping |
| account_group | Account files, transaction files | Group-level classification for account type routing |
| created_at | Markdown preferred | Audit trail |
| updated_at | Optional | UI freshness |
| source | Optional | Imported origin |

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
- AccountRule
- AccountEstimate
- PersonalTransaction
- PersonalCategory
- PersonalBudget
- SavingsGoal
- SavingsProgress
- InvestmentAccount
- Holding
- Trade
- PricePoint
- BenchmarkPeriod
- PortfolioSleeve
- SleeveTarget
- BusinessEntity
- BusinessTransaction
- BusinessBudget
- EstimatedPayment
- DeductionRecord
- TaxArchiveYear
- NoteDocument

Notes:
- `Account` is the master registry entity (all account groups). `InvestmentAccount` extends it with investment-specific fields (tax treatment, performance metadata) and references `Account` via `account_id`.
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
    ICloudContainerService.swift
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
      DeductionEngine.swift
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

### WorkspaceManager
- resolve workspace URL
- create initial directory tree
- restore last active workspace
- validate minimum required paths
- expose workspace state to UI

### ICloudContainerService
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
- `AccountEngine`: aggregate account overview (all accounts, monthly inflow, YTD net income, cash inflow vs retained equity); theme/entity grouping (personal, employment, business, custom); per-theme detail dashboard (business P&L, paycheck/stock details, personal net worth & cash flow trends); per-account detail view (monthly gross vs expenses/tax, YTD net income); account rule and estimate projections; cross-references all unified transactions and investment records
- `BudgetEngine`: budget totals, category variance, 3-month trailing averages, contribution planning
- `SavingsGoalEngine`: goal progress, target gap, funding schedule
- `PortfolioEngine`: holdings, sleeves, allocation, performance
- `BenchmarkEngine`: S&P comparison windows across D/W/M/3M/6M/1Y/3Y/5Y periods, sector performance weighting
- `TaxEngine`: realized gains, estimated payments, income summary, per-account effective rate
- `TaxPrepEngine`: prep checklist, missing input detection, tax archive read/write, year-close flow
- `DeductionEngine`: deduction record management, standard deduction seeding from filing status and tax year, Schedule C cross-reference with AccountEngine, taxable income minus deductibles projection
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

1. User edits a supported entity in UI.
2. App builds a write plan.
3. App previews target file and affected rows.
4. App creates timestamped backup.
5. App writes changes atomically.
6. App re-indexes affected files.
7. App re-validates and refreshes projections.

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
- unknown entity reference
- unknown account reference
- unknown sleeve reference
- unknown goal reference
- missing benchmark data
- duplicate transaction ID
- orphan note link

### Domain validation
- budget period without budget rows
- goal contribution without goal
- holding without account
- trade without holding or valid ticker
- tax payment outside tax year
- business transaction with unknown entity

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
Must show:
- Card grid: grouped by customizable theme/entity (Personal Assets, Place of Employment, Business Entities) showing institution, type, monthly cash inflow, YTD net income
- Aggregate header: total monthly cash inflow, YTD net income, total active accounts across the workspace
- Theme-specific detail dashboards:
  - **Business Theme**: Entity selector, monthly P&L-style summary (income, fixed expenses, discretionary, net income), expense category view, transaction ledger, category budgets, and linked entity notes/monthly reviews.
  - **Employment Theme**: Payroll deposits, HSA/FSA benefits, employer stock vests (ESPP/RSU).
  - **Personal Theme**: Net worth and cash flow trends, personal savings goals link.
- Per-account detail: monthly gross income vs expenses/tax, YTD net income, transaction list
- Transaction import, add, and edit within account context
- Account rules and estimates view

### Budget
Must show:
- Pie chart: breakdown of fixed expenses, discretionary, savings, investments as % of monthly net income
- Monthly totals with plan-vs-actual variance per category
- 3-month trailing average per category (show partial average when fewer than 3 months available)
- Category and subcategory management with manual create and edit
- Category group totals
- Transaction ledger per period
- Contribution-to-goals summary

### Savings & Investments
Savings side must show:
- Goal cards with progress bar, target amount, current balance, monthly contribution
- Monthly funding status per goal
- Goal-to-budget contribution links
- Linked transactions and notes per goal

Investments side must show:
- Holdings table (account-level and aggregate)
- Sleeve views with target vs actual weights
- Benchmark heat map: % growth per period (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) per account
- S&P 500 % growth comparison per account (Brokerage, Savings, IRA)
- Sector performance weighted against S&P 500
- Account allocation view
- Tax-lot drill-down

### Taxes
Must show:
- YTD taxable income, taxes paid vs taxes owed, effective rate per account
- Estimated payment schedule by quarter and year
- Realized gain/loss summary
- Income summary (dividends, interest)
- Deductions view: standard vs itemized comparison, above-the-line deductions, Schedule C items linked to business entities
- Taxable income minus deductibles projection
- Tax prep checklist with missing-input warnings
- Tax archive for prior years (read-only after year is closed)
- Business tax-prep summary derived from categorized business expenses

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
3. Overview projections (simplified dashboard, no filters, issues table inline)
4. Accounts module (master registry, per-account views, account rules)
5. Budget module (pie chart overview, category management, 3-month trailing averages)
6. Savings & Investments (goals, portfolio, benchmark heat map)
7. Business entity reporting
8. Tax module (deductions, per-account rates, prep checklist, archive)
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

### Still open — decide before build starts

- **Accounts master registry vs investment accounts file:** `Accounts/accounts.csv` is the master registry for all account groups. `Investments/accounts.csv` holds investment-specific metadata. The relationship is: investment accounts file adds columns (tax treatment, etc.) to master registry records via `account_id`. Confirm this two-file model, or fold investment-specific columns into the master registry as optional fields.

- **Savings and Investments folder structure:** The UI merges Savings Goals and Investments into one module, but `Savings/` and `Investments/` remain as separate folders at the file level. Confirm this separation is intentional and won't confuse users who inspect the workspace in Finder.

- **Deductions file structure:** One unified `Taxes/deductions.csv` covering all deduction types (standard, above-the-line, itemized, Schedule C), distinguished by the `deduction_type` column. Alternatively, separate files per type. Unified file is simpler; separate files are easier to hand-edit. Decide before writing the DeductionEngine.

- **Tax year-close trigger:** Tax archive files are written when a year is closed. Should this be: (a) an explicit in-app "Close Tax Year" action; (b) triggered automatically when the year rolls over; or (c) both? The archive files are read-only after creation — the trigger determines when that lock takes effect.

- **Right panel default state per section:** PRD says closed by default globally. Confirm whether any section should open the panel automatically on first use (e.g. a repair preview flow might warrant it).

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

#### Overview dashboard
![Overview wireframe](02-overview.svg)
> **Outdated (Round 1):** Monthly Snapshots and Annual Snapshots views removed. Issues table is now surfaced inline here. Needs a new wireframe.

#### Personal budget overview
![Personal Budget wireframe](03-personal-budget.svg)
> **Outdated (Round 1):** Rules section removed. Pie chart overview added. 3-month trailing averages added. Needs a new wireframe.

#### Savings Goals
![Savings Goals wireframe](04-savings-goals.svg)
> **Outdated (Round 1):** Savings Goals is now part of the unified Savings & Investments module. Needs to be replaced by a combined wireframe.

#### Investments
![Investments wireframe](05-investments.svg)
> **Outdated (Round 1):** Investments is now part of the unified Savings & Investments module. Benchmark heat map (D/W/M/3M/6M/1Y/3Y/5Y) added. Needs to be replaced by a combined wireframe.

#### Business
![Business wireframe](06-business.svg)

#### Taxes
![Taxes wireframe](07-taxes.svg)
> **Outdated (Round 1):** Deductions view, per-account tax summary, and tax archive not represented. Needs a new wireframe.

#### Notes
![Notes wireframe](08-notes.svg)
> **Deferred to V2.**

#### Issues
![Issues wireframe](09-issues.svg)
> **Deferred to V2** as a standalone view. Issues are surfaced in the Overview table in v1.

---

#### Wireframes needed (not yet produced)

- `accounts-overview.svg` — Accounts card grid and per-account detail view
- `savings-investments.svg` — Unified Savings & Investments module
- `budget-updated.svg` — Budget pie chart overview with trailing averages
- `taxes-updated.svg` — Taxes with deductions view, per-account rates, tax archive
- `overview-updated.svg` — Revised Overview with Issues table inline

## 24. Changelog

### Round 1 — 2026-06-08
Source: `docs/PRD.md` (post Round 1 updates), `docs/_reviews/technical-design-update-plan.md`

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
