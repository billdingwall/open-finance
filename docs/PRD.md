# Personal Finance Workspace for macOS PRD

## Overview

This product is a native macOS finance application that uses a dedicated iCloud Drive folder as its system of record and presents budgeting, portfolio, small business accounting, and tax workflows through a desktop-native interface. Apple’s iCloud document storage model is built around app-accessible ubiquity containers, and SwiftUI supports document-based app patterns that fit file-centric workflows on macOS.[cite:21][cite:22]

The product treats CSV and Markdown files as durable, user-visible source files rather than hiding core data inside a proprietary database. Uniform Type Identifiers provide the platform-level framework for working with file types in Apple apps, which makes CSV and Markdown a practical foundation for a file-based architecture.[cite:43][cite:45]

## Product vision

Deliver a finance workspace that combines the transparency of plain files with the usability of a native desktop app.

The app should allow a user to:
- Store finance data in iCloud Drive.
- Inspect and edit selected data safely.
- View unified dashboards for cash flow, investments, small business accounting, and taxes.
- Trace every summary back to the source file and source row.
- Continue working directly in Finder, Numbers, Excel, or a text editor when needed.

## Problem statement

Personal finance workflows often fragment across spreadsheets, notes apps, brokerage dashboards, bookkeeping tools, and tax software, which makes it difficult to keep budgeting, portfolio management, small business accounting, and tax planning connected in one workflow. Finder and iCloud Drive already provide transparent file access on macOS, but they do not provide normalized finance-specific views, validation, file repair flows, or derived reporting.[cite:21][cite:22]

A file-first macOS app solves that gap by indexing structured CSV data and Markdown notes, validating schema quality, helping create missing required files, and projecting clean finance views over the top of those files.

## Goals

### Business goals

- Create a durable, user-trustworthy finance workspace.
- Avoid proprietary lock-in by keeping the source of truth in plain files.
- Reduce dependence on third-party sync APIs in the first release.
- Establish a strong desktop-native foundation before adding automation.

### User goals

- Create personal budget based on defined monthly income.
- Review budget performance by month.
- Create savings goals that can tie to monthly contributions outlined in the budget.
- Review monthly progress toward those goals.
- Create investment organizers for different portfolio sleeves to define strategy, monthly contributions, and target weights for each holding.
- Track holdings and performance of each investment in the near, middle, and long terms and compare to the S&P 500.
- Create small business entities to track income and expenses.
- Review business performance based on monthly net income.
- Import, organize, and review transactions for both personal spending and business-related spending.
- Monitor tax-relevant events and estimated payments.
- Write monthly and quarterly finance notes in Markdown.
- Understand where every number came from and where it is going.
- Understand how the different finance sections overlap.
- Understand what tax preparations need to be made each year.

### Non-goals

- Full accounting software.
- Brokerage syncing in the first release.
- Tax return filing.
- Mobile-first parity in v1.
- Multi-user collaboration in v1.
- AI model integrations to analyze performance.

## Target users

### Primary user

A Mac power user who prefers transparent local files, already uses iCloud Drive, and wants one native interface for budgeting, investing, small business accounting, and tax planning.

### Secondary user

A spreadsheet-driven personal finance user who wants better dashboards and validation without giving up ownership of source data.

## Product principles

- **Plain files first:** CSV and Markdown remain canonical.
- **Read model second:** the app builds normalized projections from file data.
- **Native over generic:** macOS conventions, keyboard support, and Finder compatibility come first.
- **Safe writes only:** structured edits should be constrained, validated, and reversible.
- **Traceability always:** users should be able to inspect the source behind aggregated values.
- **Cross-domain visibility:** personal, portfolio, business, and tax workflows should be connected rather than siloed.
- **Repair when safe:** the app should help create missing files and repair invalid files when the fix is deterministic, previewable, and low risk.

## Scope

### In scope for v1

- Single-workspace finance folder.
- iCloud Drive-backed storage.
- CSV ingestion for structured personal, investment, business, and tax records.
- Markdown ingestion for notes and reports.
- Account management with per-account income, expense, and tax summaries across a defined account type taxonomy.
- Budget, savings, investments, business, and tax summary views.
- Savings goals and investment portfolio in a unified Savings & Investments module.
- File validation and issue reporting surfaced in the Overview dashboard.
- Source traceability from summaries to files.
- Guided creation of missing required files.
- Guided low-risk repair of invalid files.
- Limited structured editing for low-risk entities.
- Imported benchmark support for S&P 500 comparison.

### Out of scope for v1

- Bank account sync.
- Brokerage API integration.
- OCR ingestion of PDFs.
- Real-time market data.
- Full tax filing workflows.
- Shared workspaces and collaboration.
- Arbitrary user-defined schemas without conventions.
- AI-driven analysis or recommendations.
- Notes viewer and editor (V2).
- Issues management view (V2).
- Files explorer view (V2).
- Budget rules and automation (post-MVP).

## User stories

### Workspace

- As a user, the app should create or open a finance workspace in iCloud Drive.
- As a user, the app should scan the workspace automatically on launch.
- As a user, the app should tell me whether files are available locally, syncing, missing, or invalid.
- As a user, if files are missing or invalid, the app should be able to create missing files and fix invalid files.

### Accounts

- As a user, the app should let me add accounts with a defined type (employment, business, credit card, investment, savings, checking, or loan).
- As a user, the app should show an aggregate accounts overview with a card for each account, total monthly cash inflow, YTD net income, and YTD cash inflow vs retained equity.
- As a user, the app should show a per-account view with monthly gross income vs expenses, YTD net income, and the ability to import, add, or edit transactions and account rules.

### Budget

- As a user, the app should show income, fixed expenses, discretionary spend, savings, investments, and budget variance by month.
- As a user, the app should let me inspect transactions by category, merchant, account, and period.
- As a user, the app should have default category definitions that align with standard credit card reporting categories and let me maintain category definitions and monthly budget targets.
- As a user, the budget overview should show a breakdown of fixed expenses, discretionary, savings, and investments as a percentage of monthly net income.

### Savings & Investments

- As a user, the app should let me create and manage savings goals with target amount, target date, monthly contribution, and status.
- As a user, the app should show monthly progress toward each savings goal.
- As a user, the app should show holdings, allocation, cost basis, dividends, and gain/loss summaries.
- As a user, the app should let me inspect transactions and tax lots behind each holding.
- As a user, the app should compare current allocation with target allocation per portfolio sleeve.
- As a user, the app should compare portfolio performance to the S&P 500 across defined time periods.

### Business

- As a user, the app should be able to manage budgets and monitor transactions for different small businesses and freelancing LLCs.
- As a user, the app should show income, fixed expenses, discretionary spend, and budget variance by month.
- As a user, the app should let me inspect transactions by category, merchant, account, and period.
- As a user, the app should have default category definitions that align with TurboTax-style expense reporting categories and let me maintain category definitions and monthly budget targets.

### Taxes

- As a user, the app should show YTD taxable income, taxes paid vs taxes owed, and effective rate per account.
- As a user, the app should summarize realized gains, dividend income, interest income, and estimated quarterly payments.
- As a user, the app should let me track expected deductions (standard, above-the-line, itemized, and Schedule C) and show taxable income minus deductibles.
- As a user, the app should provide a tax prep checklist for the current year.
- As a user, the app should trace tax outputs back to source transactions and lots.

### Export

- As a user, the app should export filtered tables as CSV.
- As a user, the app should export summary outputs as Markdown.

## Functional requirements

### 1. Workspace management

The app must support an app-owned iCloud storage location as the default workspace model. Apple’s iCloud document APIs expose app storage through ubiquity containers, and files placed in the `Documents` area of that container appear in iCloud Drive.[cite:21]

Requirements:
- Create a default finance workspace on first launch.
- Open an existing finance workspace.
- Validate folder structure.
- Persist the active workspace reference.
- Support a future extension for advanced user-selected folders.
- Create required missing files and folders from app templates.
- Offer guided repair flows for supported invalid file states.

### 2. File discovery and indexing

The app must recursively discover supported CSV and Markdown files and build a file manifest for the UI and domain layers.

Requirements:
- Detect file path, type, modified date, size, and content hash.
- Classify files by folder path, naming rules, and metadata.
- Detect additions, deletions, and changes.
- Re-index incrementally after file updates.
- Surface indexing progress and file health.
- Classify files by domain: budget, portfolio, business, taxes, and notes.

### 3. CSV ingestion

The app must parse CSV files into typed records with schema validation.

Requirements:
- Support strict column expectations per file type.
- Parse dates, decimals, identifiers, enums, and text safely.
- Produce warnings for extra or missing columns.
- Preserve row-level provenance for traceability.
- Support schema versioning.
- Support repair flows for known low-risk issues such as missing optional columns, header normalization, and regeneration of required template files.

### 4. Markdown ingestion

The app must parse Markdown files for notes, reports, and structured metadata. SwiftUI supports document-based app patterns on macOS, which fits a file-centric workflow with readable document views.[cite:22][cite:16]

Requirements:
- Read Markdown body content.
- Parse optional YAML front matter.
- Classify note type by front matter and path.
- Link notes to periods, business entities, accounts, portfolio sleeves, or tax years.
- Provide a readable native viewer in v1.

### 5. Accounts module

The Accounts module is the income and expense management layer for each taxable account in the workspace. It provides both an aggregate overview and per-account detail.

Account types supported:

| Group | Types |
|---|---|
| Employment | Payroll, HSA, FSA, employer stock plans (ESPP, RSU) |
| Business | Business checking, business savings, merchant/payment gateways, corporate credit cards, petty cash |
| Credit Cards | Rewards, travel, retail, balance transfer |
| Investments | Taxable brokerage, IRA/Roth IRA, robo-advisor, crypto, 529 |
| Savings | HYSA, traditional savings, CDs, money market, sinking funds |
| Everyday Banking | Personal/joint checking, cash management accounts |
| Loans & Debt | Mortgage, auto, student, personal, BNPL |

Requirements:
- Support adding accounts with type, name, and key tax metadata.
- Show an aggregate accounts overview: card per account, total monthly cash inflow, YTD net income (gross − expenses − tax), YTD cash inflow vs retained equity.
- Show a per-account view: monthly gross income vs expenses/tax, YTD net income, YTD cash inflow vs retained equity.
- Support import, add, and edit of transactions per account.
- Support account-level rules and estimates.

### 6. Budget module

Requirements:
- Show a budget overview with a pie chart of fixed expenses, discretionary spend, savings, and investments as a percentage of monthly net income.
- Show monthly totals for income, fixed expenses, discretionary expenses, transfers, savings, and investments.
- Show budget targets and variance by category with a 3-month trailing average per category.
- Support manual category and subcategory creation and editing.
- Support category-group definitions.
- Link monthly budget views to transaction history for plan-vs-actual comparison.
- Support monthly income planning as the basis for budget generation.
- Support savings-goal contributions as a first-class budget output.

### 7. Savings & Investments module

Savings goals and investment portfolio are presented as a unified module covering liquid savings, long-term goals, and investment accounts.

Requirements:
- Create and manage savings goals with target amount, target date, monthly contribution target, and status.
- Show monthly progress toward each savings goal.
- Link savings goals to budgeted monthly contributions.
- Show source traceability from contributions and balances back to transactions or budget entries.
- Show account-level and aggregate holdings.
- Compute position values from holdings and price files.
- Support trade history, lots, dividends, and cash.
- Show gain/loss summaries and allocation views.
- Support security-level drill-down with source records.
- Support portfolio sleeves with strategy notes, monthly contribution targets, and target weights per holding.
- Compare portfolio and sleeve performance to the S&P 500:
  - Totals vs S&P 500 (% growth) per account: Brokerage, Savings, IRA.
  - Performance table/heat map across periods: D, W, M, 3M, 6M, 1Y, 3Y, 5Y.
  - Sector performance weighted against S&P 500.

### 8. Business module

Requirements:
- Support multiple small business entities in one workspace.
- Track business income, fixed expenses, discretionary expenses, transfers, and owner distributions.
- Show monthly net income and budget variance by business entity.
- Support entity-specific category definitions and monthly budget targets.
- Include default business categories aligned with common tax-prep expense groupings.
- Support transaction review by category, merchant, account, and period.
- Link entity-level notes and monthly reviews.

### 9. Tax module

Requirements:
- Show YTD taxable income, taxes paid vs taxes owed, and effective rate per account.
- Summarize realized gains and losses.
- Track dividend and interest income.
- Display estimated payments by quarter and year.
- Support tracking of expected deductions:
  - Standard deduction (by filing status and tax year).
  - Above-the-line deductions: student loan interest, traditional IRA contributions, HSA contributions, educator expenses.
  - Itemized deductions (Schedule A): SALT, mortgage interest, medical expenses exceeding 7.5% AGI, charitable donations.
  - Self-employed deductions (Schedule C): QBI deduction, home office, vehicle expenses, self-employed health insurance premiums, retirement contributions (SEP IRA, SIMPLE IRA, Solo 401k), operating expenses.
- Show taxable income minus deductibles and estimated payment or return.
- Provide a tax prep checklist for the current year highlighting missing inputs and unresolved issues.
- Maintain a tax archive for prior-year deductions and estimated payment history.
- Show source traceability for all tax-relevant calculations.
- Surface business-related tax-prep summaries derived from categorized business expenses.

### 10. Validation and issues

Issues are surfaced in the Overview dashboard in v1 rather than as a standalone navigation section.

Requirements:
- Detect invalid schemas, bad dates, bad amounts, duplicate IDs, unknown references, and missing files.
- Group issues by severity.
- Provide clear remediation guidance.
- Allow export of issue lists for cleanup.
- Distinguish between issues that can be repaired automatically and those requiring manual review.
- Require preview and confirmation before applying fixes.

### 11. Traceability and inspection

Requirements:
- Every KPI and chart point must link to a filtered detail view.
- Every detail view must link to a source file and source row or note.
- The app must distinguish raw imported values from derived values.
- The app must show cross-domain relationships, such as budget contributions feeding savings goals, portfolio activity affecting tax summaries, and business expenses feeding tax-prep views.

### 12. Export

Requirements:
- Export filtered tables as CSV.
- Export monthly review summaries as Markdown.
- Export business summaries as CSV or Markdown.
- Preserve traceability context in exports where practical.

## Non-functional requirements

### Performance

- Initial indexing should feel fast on typical personal-finance and small-business datasets.
- Incremental refresh should avoid full rescans when possible.
- UI interactions should remain responsive during parsing and projection.

### Reliability

- Parsing failures in one file must not block unrelated modules.
- The app must preserve the last known valid projection when possible.
- Writes must be atomic and reversible.
- Repair actions must be previewable and recoverable.

### Transparency

- Users must always know which file produced a displayed value.
- File paths and timestamps must be visible in inspector views.
- The app should avoid hidden data mutation outside structured write flows.
- The app should clearly indicate whether a value is imported, derived, repaired, or user-edited.

### Native behavior

SwiftUI’s document-based app patterns and macOS file workflows make it a good fit for a desktop productivity tool centered on user-visible documents.[cite:22]

Requirements:
- Keyboard-friendly navigation.
- Sidebar-based information architecture.
- Right detail pane is collapsible and closed by default; it opens as a slide-over rather than a persistent split.
- Multi-window support as a later extension.
- Finder-compatible mental model.

### Data management

Without live sync, month-over-month continuity depends on user-imported transaction files. The app should minimize the friction of this workflow rather than assume continuous data availability. The UI should handle sparse or missing month data gracefully and never block other views when data for a specific period is absent.

## Information architecture

Recommended primary navigation:
- Overview
- Accounts
- Budget
- Savings & Investments
- Business
- Taxes
- Settings
- Notes *(V2)*
- Issues *(V2)*
- Files *(V2)*

Recommended shell:
- Left sidebar for primary navigation.
- Center pane for list, period, account, business entity, sleeve, goal, or report selection.
- Right detail pane for table, chart, note, or inspector. Collapsible and closed by default; opens as a slide-over panel.

## Data model

### Canonical file-based entities

| Domain | Entities |
|---|---|
| Accounts | Account, AccountType, AccountRule, AccountEstimate |
| Budget | Transaction, Category, BudgetPlan, BudgetContribution, Merchant |
| Savings & Investments | SavingsGoal, GoalContribution, GoalStatusSnapshot, Security, Trade, Lot, Position, Dividend, PricePoint, PortfolioSleeve, SleeveTarget, BenchmarkSeries, BenchmarkPeriod |
| Business | BusinessEntity, BusinessTransaction, BusinessCategory, BusinessBudgetPlan, OwnerDistribution |
| Taxes | TaxSetting, RealizedGain, IncomeEvent, EstimatedPayment, TaxPrepIssue, DeductionRecord, TaxArchiveYear |
| Notes | NoteDocument, MonthlyReview, StrategyNote |
| Platform | Workspace, FileRecord, ImportIssue, RepairAction, SchemaVersion, SyncStatus |

### Internal architecture model

The product should use a layered model:
1. File layer for discovery, metadata, and sync state.
2. Parsing layer for CSV and Markdown ingestion.
3. Domain layer for normalized finance and business entities.
4. Projection layer for dashboards, summaries, comparisons, and exports.

This layered approach separates file conventions from finance logic and keeps UI concerns independent from parsing concerns.

## Technical architecture

### Recommended app architecture

- Native macOS app in SwiftUI.
- MVVM for presentation logic.
- Domain services for finance, business, and tax calculations.
- Observation-based state management for modern SwiftUI data flow.
- File access through Foundation and iCloud document APIs.[cite:21]
- File-type handling through Uniform Type Identifiers.[cite:43][cite:45]

### Core modules

```text
App Shell
  Navigation
  Scenes
  Commands

Platform Layer
  WorkspaceManager
  iCloudContainerService
  FileIndexService
  FileWatcherService
  BackupService
  RepairService

Parsing Layer
  CSVParserService
  MarkdownParserService
  SchemaRegistry
  ValidationEngine

Domain Layer
  AccountEngine
  BudgetEngine
  SavingsGoalEngine
  PortfolioEngine
  BusinessEngine
  TaxEngine
  ReportingEngine
  CrossDomainLinkingEngine

Presentation Layer
  OverviewView
  AccountsView
  BudgetView
  SavingsInvestmentsView
  BusinessView
  TaxesView
  NotesView       (V2)
  IssuesView      (V2)
  FilesView       (V2)
```

## Changelog

### Round 1 — 2026-06-08
Sources: `docs/_reviews/round-1.md`, `docs/_reviews/Account types.md`, `docs/_reviews/Deduction types.md`

- Added Accounts module with 7-group account type taxonomy
- Merged Savings Goals + Investments → Savings & Investments module
- Expanded benchmark requirements: per-account S&P comparison, D/W/M/3M/6M/1Y/3Y/5Y heat map, sector performance
- Overhauled Budget module: pie chart overview, 3-month trailing averages, manual category/subcategory creation
- Deferred Budget Rules to post-MVP
- Expanded Tax module: full deduction taxonomy (Standard, Above-the-line, Schedule A, Schedule C, 2025 temps), per-account tax view, prep checklist, tax archive
- Simplified Overview dashboard: removed Monthly/Annual Snapshot views, Issues table surfaced here
- Deferred Notes, Issues, Files to V2
- Updated navigation from 9 items to 7 v1 items + 3 V2 items
- Added right detail pane collapsible behavior to native requirements
- Added Data management non-functional requirement (month-over-month without sync)
- Updated data model: added Account/AccountType/AccountRule/AccountEstimate, DeductionRecord, TaxArchiveYear, BenchmarkPeriod; removed Rule from Budget domain
