# Open Finance — v1 Product Roadmap

**Project**: Personal Finance Workspace for macOS
**Scope**: v1 as defined in `docs/product-requirements.md` and `docs/technical-design.md`
**Architecture reference**: File layer → Parsing layer → Domain layer → Projection layer → Presentation layer
**Last updated**: 2026-06-10

---

## Out of Scope for v1

The following are explicitly excluded from this roadmap. Any work that touches these areas requires
a PRD amendment before proceeding.

| Item | Deferred to |
|---|---|
| Notes viewer and editor | V2 |
| Issues management standalone view | V2 |
| Files explorer | V2 |
| Budget rules and recurring automation | Post-MVP |
| Bank account sync | V2 |
| Brokerage API integration | V2 |
| Real-time market data | V2 |
| OCR ingestion of PDFs | V2 |
| Tax return filing engine | V2 |
| Multi-workspace / multi-user support | V2 |
| AI-driven analysis or recommendations | V2 |
| Alternative cloud storage providers (Google Drive, Dropbox, local folder) | V2 |
| xlsx and other spreadsheet format ingestion and export | V2 |
| Savings goal lifecycle states (active/archived) — flat goal list in v1 | V2 |
| Dedicated sleeves screen — sleeve table lives on the Portfolio overview in v1 | V2 |
| Dedicated benchmark screen — heat map is a holdings table view toggle in v1 | V2 |
| Dedicated deductions screen — deductions content lives within Current Tax Year in v1 | V2 |
| Contextual filter bar / filter chips on module screens | V2 |

Inline period/account selection that a screen intrinsically needs stays in v1; only the dedicated filter-bar surface is deferred.

Estimated payments and gains & income are **not** out of scope — their functionality stays in v1,
surfaced within the Current Tax Year view rather than on dedicated screens.

---

## Phase Dependencies Overview

```
Phase 1: Foundation & Architecture
    ↓ (workspace + iCloud layer required)
Phase 2: Parsing, Validation & Infrastructure
    ↓ (typed domain records required)
Phase 3: Domain Layer I — Accounts, Budget & Overview
    ↓ (master account registry required by all other modules)
Phase 4: Domain Layer II — Savings, Investments & Tax
    ↓ (all domain engines required for full projections)
Phase 5: Presentation Layer — App Shell & Module Views
    ↓ (views and write flows are parallel once shell is stable)
Phase 6: Write Flows, Repair & Export
    ↓
Phase 7: Polish & Launch Readiness
```

---

## Phase 1: Foundation & Architecture

**Goal**: Establish the Xcode project, iCloud workspace management, file indexing infrastructure,
and core internal data models. Nothing is visible to users yet — this phase builds the floor that
every subsequent layer stands on.

**⚠️ Critical dependency**: All later phases depend on `WorkspaceManager` and `FileIndexService`
being stable. Do not advance to Phase 2 until the workspace URL resolves reliably in both iCloud
and local-fallback modes.

### Product Tasks

- [x] Lock the Phase 1 architectural decisions documented in `docs/technical-design.md §21` ✓ 2026-06-10
  - Unified `Accounts/accounts.csv` — no separate `Investments/accounts.csv`
  - Savings/ and Investments/ stay as separate folders at the file level
  - One `Taxes/deductions.csv` with `deduction_type` column
  - Tax year-close is an explicit in-app action only
  - Right detail pane is closed by default globally, no per-section exceptions
  - iCloud container identifier: `OpenFinance`
  - Bootstrap seeds: personal bank, personal credit card, business bank, business credit card, savings, investment
- [ ] Finalize iCloud entitlement strategy for development and distribution (container: `OpenFinance`)
- [ ] Document the 7 required iCloud sync states and define how each surfaces in the UI:
  Available, Not signed in, Container unavailable, Syncing, Local copy stale, File missing locally,
  Conflict detected
- [ ] Define the complete workspace folder structure and file naming conventions (confirm against
  `docs/technical-design.md §6`)
- [ ] Document workspace bootstrap behavior: full sequence — folders created, seed files written,
  six starter accounts written to `Accounts/accounts.csv`, manifest created
- [ ] Define the `.finance-meta/manifest.json` shape and update contract

### Design Tasks

- [ ] Design the first-launch onboarding flow: workspace creation, iCloud availability states,
  and fallback when iCloud is unavailable
- [ ] Design workspace sync status indicators: persistent status bar element, per-file sync badge
  (available, syncing, missing, conflict)
- [ ] Design the loading/indexing state: what the user sees between launch and when projections
  are ready
- [ ] Spec the global app shell skeleton: window chrome, menu bar commands, toolbar layout, and
  empty navigation state

### Development Tasks

#### Xcode Project Setup
- [ ] Create `FinanceWorkspaceApp` Xcode project targeting macOS with SwiftUI lifecycle
- [ ] Configure iCloud entitlement (`com.apple.developer.ubiquity-container-identifiers`) and
  capabilities
- [ ] Establish module folder structure: `App/`, `Platform/`, `Parsing/`, `Domain/`, `Validation/`,
  `Persistence/`, `UI/Shared/`, `Scripts/`
- [ ] Set up `SwiftLint` and code style configuration
- [ ] Configure unit test target and basic test infrastructure

#### Platform Layer
- [ ] `CloudStorageProvider` protocol — define minimum interface: `resolveWorkspaceURL() async throws -> URL`, observable `syncState`, `isAvailable: Bool`; all storage backends conform to this protocol; `ICloudContainerService` is the v1 implementation
- [ ] `ICloudContainerService` — conforms to `CloudStorageProvider`; resolve ubiquity container URL, expose availability state enum,
  provide diagnostics for missing entitlements or nil container
- [ ] `WorkspaceManager` — resolve workspace URL via the active `CloudStorageProvider`, create initial directory
  tree from templates, restore last active workspace path from `UserDefaults`, validate minimum
  required paths, expose `WorkspaceState` observable to UI
- [ ] `BackupService` — create timestamped copies of files before any write or repair, manage
  backup rotation in `.finance-meta/backups/`
- [ ] `FileCoordinatorService` — wrap `NSFileCoordinator` for coordinated reads and writes around
  iCloud documents

#### File Indexing
- [ ] `FileIndexService` — recursively scan `.csv` and `.md` files, classify by folder path and
  filename, compute SHA-256 content hashes, detect additions/deletions/changes against prior manifest,
  emit `FileChangeEvent` notifications
- [ ] `FileWatcherService` — use `DispatchSource` or `NSFilePresenter` to observe workspace
  directory for file system events, debounce rapid changes, trigger incremental re-index
- [ ] `ManifestStore` — read/write `.finance-meta/manifest.json`, maintain last-indexed snapshot,
  cache classification results and validation status per file

#### Core Data Models
- [ ] Define `Workspace`, `FileRecord`, `SyncStatus` models in `Platform/`
- [ ] Define `ValidationIssue`, `RepairAction` models in `Validation/`
- [ ] Define canonical entity models for all domains in `Domain/`:
  `Account`, `AccountRule`, `AccountEstimate`, `UnifiedTransaction`, `Category`,
  `BudgetPlan`, `SavingsGoal`, `SavingsProgress`, `InvestmentAccount`, `Holding`, `Trade`,
  `PricePoint`, `BenchmarkPeriod`, `PortfolioSleeve`, `SleeveTarget`, `OwnerDistribution`,
  `EstimatedPayment`, `DeductionRecord`, `TaxArchiveYear`, `NoteDocument`
- [ ] Define cross-domain projection models:
  `AccountSummaryCard`, `OverviewSummaryCard`, `MonthlySnapshot`, `GoalFundingLink`,
  `SleeveFundingLink`, `TaxPrepSummary`, `TaxDeductionSummary`

#### Developer Script
- [ ] `bootstrap-workspace.swift` — create standard folder tree, write seed CSV/Markdown
  templates with correct headers and `schema_version: 1`, seed standard deduction row in
  `Taxes/deductions.csv` from filing status, create manifest, write default categories in
  `Budget/categories.csv`

### Milestone 1
> **Foundation complete.** The app launches, resolves the iCloud workspace, creates the initial
> folder structure on first run, scans and hashes all files in the workspace, and persists the
> manifest. All core data models are defined. iCloud sync states are correctly detected and
> exposed. Developer bootstrap script produces a valid, scannable workspace.

---

## Phase 2: Parsing, Validation & Infrastructure

**Goal**: Build the full Parsing layer and Validation engine so that raw files on disk become
typed domain records. This is the prerequisite for every domain engine in Phase 3 and 4.

**⚠️ Critical dependency**: Domain engines in Phase 3 are blocked until `CSVParserService`,
`CSVSchemaRegistry`, and `ValidationEngine` are complete and tested against real fixture files.

### Product Tasks

- [ ] Finalize and document all 24 CSV file specifications (schemas, required vs optional columns,
  enum value sets) — reference `docs/technical-design.md §8`
- [ ] Define the complete validation rule catalog across three tiers:
  - File-level: missing required file, invalid CSV header, bad date, bad decimal, invalid enum
  - Cross-file: unknown account/category/entity/sleeve/goal reference, duplicate transaction ID
  - Domain: budget period without rows, holding without account, trade without valid ticker
- [ ] For each validation issue, classify: error vs warning vs info, and repairable vs manual-only
- [x] Document amount sign conventions ✓ 2026-06-10 — negative = debit (money out), positive = credit (money in); applies to all transaction file types; `CSVNormalizer` flips signs from external sources during import
- [x] Define `schema_version` migration policy ✓ 2026-06-10 — breaking change = any modification to a column or front matter field in use; repair path = migration script shipped with the release (`Scripts/migrate-{file-type}-v{old}-to-v{new}.swift`); `RepairService` detects version mismatches and prompts user to run script

### Design Tasks

- [ ] Design the validation issue card: icon/color by severity, affected file path, issue
  description, remediation hint, repair vs manual badge
- [ ] Design the repair preview panel: diff-style before/after view of affected rows, backup
  confirmation, apply/cancel actions
- [ ] Design the indexing progress state: file count, hash progress, any classification warnings
  surfaced during scan

### Development Tasks

#### CSV Parsing
- [ ] `CSVParserService` — parse raw CSV into `[String: String]` row dictionaries, map and
  normalize column headers (case-insensitive, trim whitespace), enforce strict schema against
  registered schemas, attach `source_file` and `source_row` provenance to each parsed record,
  produce typed `CSVParseResult` with records and warnings
- [ ] `CSVSchemaRegistry` — register expected column definitions (name, type, required/optional,
  enum values) for all 24 file types; support `schema_version` lookup; expose schema for each
  file type by domain + subtype key
- [ ] `CSVNormalizer` — normalize raw string values to Swift types: ISO 8601 dates, `Decimal`
  amounts, `Bool`, enum cases; produce typed `NormalizationError` for invalid values

#### Markdown Parsing
- [ ] `FrontMatterParser` — extract YAML front matter block between `---` delimiters, parse into
  `[String: Any]` dictionary, handle missing or malformed front matter gracefully
- [ ] `MarkdownParserService` — read `.md` file, extract front matter, extract body content,
  classify note type from `type` field and folder path, produce typed `NoteDocument` with linked
  entity IDs, period, account IDs, sleeve IDs, and tax year

#### Validation Engine
- [ ] `RuleCatalog` — define all validation rules as value types with: rule ID, tier (file/
  cross-file/domain), severity (error/warning/info), repair classification (auto/manual/none),
  and a pure validation function `(WorkspaceContext) -> [ValidationIssue]`
- [ ] `ValidationEngine` — run full validation pass against a parsed workspace: per-file rules,
  cross-file reference checks, domain logic checks; produce `ValidationResult` with grouped issues
  by severity; mark each issue with its repair classification
- [ ] `RepairService` — implement auto-repairable fixes: inject missing optional columns with
  empty defaults, normalize header casing to canonical form, create missing seed files from
  templates, create missing required folders; always call `BackupService` before writing;
  log every repair to `.finance-meta/logs/repair-log.csv`

#### Persistence
- [ ] `SettingsStore` — read/write `Taxes/settings.csv` (filing status, tax year, default
  currency, timezone); expose typed `WorkspaceSettings` observable

#### Developer Scripts
- [ ] `validate-workspace.swift` — scan workspace, run full validation pass, print grouped issue
  summary to stdout, optionally write JSON report
- [ ] `repair-workspace.swift` — apply known auto-repairable fixes with `--dry-run` and
  `--apply` modes, write backup log

### Milestone 2
> **Parsing complete.** Every supported CSV and Markdown file type can be parsed into typed
> domain records. The validation engine detects and classifies all defined issue types.
> Auto-repairable fixes can be applied with preview. Fixture files for all 24 file types exist
> and pass parsing cleanly.

---

## Phase 3: Domain Layer I — Accounts, Budget & Overview

**Goal**: Build the three domain engines that are most foundational to the rest of the app.
`AccountEngine` establishes the master account registry that every other module references.
`BudgetEngine` drives the primary personal finance view. `OverviewEngine` produces the cross-domain
dashboard projection.

**⚠️ Critical dependency**: `AccountEngine` must be complete before Phase 4 begins.
`Investments/accounts.csv`, `Business/entities.csv`, and all transaction files reference
`account_id` from the master registry — downstream engines validate these references.

### Product Tasks

- [ ] Finalize the 7-group account type taxonomy and define all sub-types for each group
  (reference `docs/product-requirements.md §5`)
- [ ] Define default personal budget category set: group names, category names, default budget
  behavior (fixed/discretionary/savings/investment/transfer), and `tax_relevant` flag for each
- [ ] Finalize the customizable account entities/themes taxonomy (personal, employment, business, custom)
- [ ] Document the 3-month trailing average calculation: what to display when fewer than 3 months
  of transaction history are available (show partial average with a data-sufficiency indicator,
  not zero or blank)
- [ ] Define the 5 Overview KPI card specifications in detail:
  - Budget card: current month income vs estimated spending
  - Savings card: total savings balance, monthly contributions, estimated rate
  - Investments card: total investment value, monthly contributions, estimated rate
  - Business card: YTD net income for business entities/themes
  - Taxes card: estimated return, gross income, taxes paid
- [ ] Define month-over-month panel data requirements: which periods to show, how to handle
  missing months gracefully
- [ ] Document YTD net income formula: `gross_income − total_expenses − taxes_paid` per account,
  and define what qualifies as each term per account group

### Design Tasks

- [ ] **Accounts overview**: card grid layout, card anatomy (institution name, account type badge,
  monthly cash inflow, YTD net income figure), aggregate header row
- [ ] **Per-account detail**: monthly gross vs expenses/tax chart, YTD figures, transaction list
  within account context, account rules panel
- [ ] **Budget overview**: pie chart component (fixed/discretionary/savings/investments as % of
  net income), category table with plan/actual/variance columns and 3-month trailing average column,
  period selector
- [ ] **Budget history**: month-over-month variance table or bar chart, period range selector
- [ ] **Overview dashboard**: 5 KPI card layout, month-over-month panel (sparkline or bar), Issues
  table (severity-grouped, inline repair action), empty state when no data is loaded
- [ ] Design empty states for all three modules (no accounts added, no transactions imported,
  no budget defined)

### Development Tasks

#### AccountEngine (`Domain/Accounts/`)
- [ ] `AccountModels` — define `Account` (master registry), `AccountRule`, `AccountEstimate`,
  `AccountSummaryCard`, `AccountDetailProjection`
- [ ] `AccountEngine` — build aggregate overview: iterate all accounts, compute monthly cash
  inflow per account from unified transaction files, compute YTD net income
  (gross − expenses − taxes), compute YTD cash inflow vs retained equity; build per-theme
  detail projections (personal, employment, business); apply account rules and estimates to project expected cash flow for accounts
  with no transactions in the current period; cross-reference unified transactions by `account_id`

#### BudgetEngine (`Domain/Budget/`)
- [ ] `BudgetModels` — define `PersonalTransaction`, `PersonalCategory`, `PersonalBudget`,
  `BudgetVarianceRow`, `BudgetMonthProjection`, `BudgetOverviewProjection`
- [ ] `BudgetEngine` — compute monthly totals for income, fixed expenses, discretionary,
  transfers, savings, investments; compute plan-vs-actual variance per category; compute 3-month
  trailing average per category (handle fewer than 3 months with partial average flag); compute
  pie chart percentages of fixed/discretionary/savings/investments as share of net monthly income;
  support savings-goal contributions as a first-class budget output linked to `GoalFundingLink`

#### OverviewEngine (`Domain/CrossDomain/`)
- [ ] `LinkingEngine` — build `GoalFundingLink` (budget contributions → savings goals),
  `SleeveFundingLink` (investment contributions → sleeves); resolve cross-domain relationships
  from all parsed domain records
- [ ] `OverviewEngine` — compose `OverviewSummaryCard` set from AccountEngine, BudgetEngine,
  PortfolioEngine (stub), TaxEngine (stub); produce month-over-month
  panel data; aggregate validation issues for Overview issue table

### Milestone 3
> **Core domain engines functional.** Accounts module projects aggregate and per-account views
> from real files. Budget module produces plan-vs-actual with 3-month trailing averages from
> transaction files. Overview engine composes cross-domain KPI cards (with stubs for engines
> not yet built). Cross-domain links between budget contributions and goals are established.

---

## Phase 4: Domain Layer II — Savings, Investments & Tax

**Goal**: Build the remaining domain engine groups. These can be developed largely in
parallel once Phase 3 is complete, as they share only the master account registry.

### Product Tasks

#### Savings & Investments
- [ ] Define progress calculation rules for savings goals: how balance is derived when no explicit
  progress snapshot exists (derive from transaction history vs require manual snapshot entry)
- [ ] Define portfolio allocation calculation: market value by sleeve, target weight vs actual
  weight, drift threshold for visual alert
- [ ] Define the 8 benchmark comparison periods (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) precisely:
  calendar-day anchoring, handling of weekends/market-closed days, % growth formula
  (simple return vs CAGR for multi-year periods)
- [ ] Define sector performance weighting against S&P 500: how sector weights are derived from
  holdings, what benchmark sector data is required, what happens when sector data is missing
- [ ] Document the S&P 500 benchmark CSV import process: expected source, column format, how
  to handle gaps in price history

#### Taxes

The tax module presents three screens in v1: Current Tax Year (with estimated payments, gains &
income, and deductions inline), Prep Checklist, and Tax Archive.

- [ ] Document standard deduction seeding: amount by filing status for current and prior tax
  years, source of amounts (hardcode per year vs derive from settings)
- [ ] Define Schedule C cross-reference rules: map business categories to deduction
  line items, QBI calculation approach (simplified estimate vs full calculation)
- [ ] Define the tax prep checklist: enumerate all required inputs (W-2 data, 1099s, estimated
  payments, deduction confirmations) and define what triggers each item as "missing" or
  "unresolved"
- [ ] Define the tax year-close flow: what data is archived, when the archive is written, and
  what the "year is closed" indicator shows in the UI

### Design Tasks

#### Savings & Investments
- [ ] **Goals overview**: goal card anatomy (name, target amount, current balance, progress bar,
  monthly contribution, time-to-goal estimate); single flat list — no active/archived grouping
- [ ] **Portfolio overview**: holdings table as the primary surface (columns, account selector,
  allocation donut as supporting element) with a standard ⇄ heat-map view toggle; heat-map mode
  covers 8 time periods × N accounts, color scale for positive/negative % growth, S&P 500
  comparison row, sector performance section; sleeve table appended at the bottom (target vs
  actual weights, drift indicator, contribution target, linked strategy note)
- [ ] Empty states: no goals created, no holdings imported, no price data available

#### Taxes
- [ ] **Current tax year**: YTD taxable income panel, taxes paid vs owed comparison, effective rate
  per account table; estimated payments section (quarterly schedule, paid vs due status); gains &
  income section (realized gain/loss, dividends, interest); deductions section (standard vs
  itemized comparison, above-the-line, Schedule A, Schedule C linked to business themes/entities,
  taxable income minus deductibles projection); no prep checklist on this screen
- [ ] **Tax prep checklist**: full-width focal screen — checklist item anatomy, missing/unresolved
  indicators, source links, and educational content explaining each tax-prep step
- [ ] **Tax archive**: prior-year read-only archive selector

### Development Tasks

#### SavingsGoalEngine (`Domain/Savings/`)
- [ ] `SavingsGoalEngine` — compute goal progress from `SavingsProgress` snapshots or derive
  from transaction history; compute gap to target and months-to-goal at current contribution rate;
  resolve `GoalFundingLink` to monthly budget contribution rows; produce `GoalProgressProjection`
  per goal; no goal lifecycle states — every goal in `goals.csv` is active, no status branching

#### PortfolioEngine + BenchmarkEngine (`Domain/Investments/`)
- [ ] `PortfolioEngine` — compute position values from `Holding` × `PricePoint` (latest
  available price); compute cost basis, unrealized gain/loss, allocation per sleeve; build
  aggregate and account-level holdings views; resolve tax lots from `Trade` history; compute
  dividend income totals from `Dividend` records; compare actual sleeve weights to `SleeveTarget`
  and compute drift
- [ ] `BenchmarkEngine` — load S&P 500 price series from `benchmarks/sp500.csv`; compute %
  growth for each `BenchmarkPeriod` (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) using calendar-anchored date
  lookups; compute the same periods for each portfolio account; produce heat map data model
  (`BenchmarkPeriod` × account); compute sector performance weights from holdings and compare to
  benchmark sector weights

#### TaxEngine + TaxPrepEngine + DeductionEngine
- [ ] `TaxEngine` — compute YTD taxable income per account from income transaction records;
  compute taxes paid from `EstimatedPayment` records; derive effective tax rate per account
  (taxes paid / gross income); compute realized gain/loss from `Trade` + lot records; aggregate
  dividend and interest income from `Dividend` and transaction records
- [ ] `DeductionEngine` — manage `DeductionRecord` CRUD; seed standard deduction row on first
  access using `WorkspaceSettings.filingStatus` and `taxYear`; compute taxable income minus
  deductibles; cross-reference Schedule C deductions with `AccountEngine` for entity-level
  expense totals; produce `TaxDeductionSummary` with all deduction categories
- [ ] `TaxPrepEngine` — evaluate tax prep checklist items against available data; classify each
  item as complete, incomplete, or missing; detect unresolved issues from `ValidationIssue` records
  tagged as tax-relevant; manage `TaxArchiveYear` read/write (write on year-close action, enforce
  read-only thereafter)

#### CrossDomain Completion
- [ ] Complete `LinkingEngine` — add portfolio-to-tax links (realized gains → tax engine),
  business entity tax links (Schedule C categories → deduction engine); update `OverviewEngine`
  to consume real projections from all engines (remove stubs from Phase 3)

### Milestone 4
> **All domain engines functional.** Every module can produce complete projections from fixture
> data. Cross-domain links are live: budget contributions feed goals, portfolio gains feed tax
> summaries, business entity expenses feed Schedule C deductions. Overview engine composites all five
> KPI cards from real data.

---

## Phase 5: Presentation Layer — App Shell & All Module Views

**Goal**: Build the complete SwiftUI presentation layer. The app shell ships first; module
views can be developed in parallel once the shell and navigation state are stable.

**⚠️ Critical dependency**: `AppState` and `AppRouter` must be stable before any module view
is connected. Module views are blocked on their respective domain engines from Phase 3/4.

### Product Tasks

- [ ] Write acceptance criteria for each module view against PRD functional requirements
- [ ] Define filter states: which filters appear per section, default state, persistence scope
  (session-only vs persisted), and interaction with the detail pane
- [ ] Define the traceability interaction: what tapping a KPI does, what tapping a detail row
  does, how the source file inspector appears and what it shows
- [ ] Define the collapsible right pane interaction spec: trigger (click, keyboard shortcut,
  selection-driven auto-open), animation, width, and content rules per context
- [ ] Document all macOS menu bar commands and their keyboard shortcuts
  (reference `docs/technical-design.md §17`)

### Design Tasks

#### App Shell
- [ ] Finalize `NavigationSplitView` three-column layout spec: sidebar width, column collapse
  behavior, minimum window size
- [ ] Design left sidebar: section headers, expandable/collapsible groups, nested entity links,
  active/selected state, empty group state
- [ ] Design the context header: title, breadcrumb, quick actions (Import, Add, Export),
  sync status badge, issue count badge
- [ ] Design the right detail pane: slide-over width, close button, all supported surfaces
  (inspector, source file preview, source row detail, validation issue detail, repair preview,
  edit form)
- [ ] Design shared component library: data table (sortable, filterable), KPI card, chart
  components (pie chart, sparkline, bar chart, heat map table), period selector, filter bar,
  empty state template, loading skeleton

#### Module Views
- [ ] Finalize Overview dashboard wireframe (updated post Round 1 — see `docs/_refinement/`)
- [ ] Finalize app-shell wireframe (Round 5: Overview is the default landing via the sidebar
  header; issues chip in the global header; local-actions on the page-title line; no filter bar)
- [ ] Finalize Accounts views wireframe (new — account-group screen with individual-account
  cards + inline ledger, no sub-tabs; dedicated per-account screen with transactions table)
- [ ] Finalize Budget updated wireframe (pie chart + trailing averages + 50/50 Spend Mix /
  Spending Variance panels)
- [ ] All chart visuals designed for a real charting implementation (Swift Charts), not
  placeholder SVGs
- [ ] Finalize Savings & Investments unified wireframe
- [ ] Finalize Taxes updated wireframe (deductions view, per-account rates)

### Development Tasks

#### App Shell
- [ ] `FinanceWorkspaceApp` — define `WindowGroup` scene, main menu commands (`NSApplication`
  delegate or `.commands` modifier), app-level keyboard shortcuts
- [ ] `AppState` — `@Observable` root state object holding workspace state, indexing state,
  active module selection, navigation path, detail pane open/closed state; **Overview is the
  default selection on launch**
- [ ] `AppRouter` — manage navigation selection for `NavigationSplitView`, encode/decode deep
  link state (domain + group/account selection), handle programmatic navigation from KPI links;
  the sidebar header ("Finance Dashboard") navigates to the Overview dashboard
- [ ] `NavigationSidebarView` — left sidebar with expandable section groups, nested account-
  group/account/goal/sleeve links, active selection highlight, keyboard navigation; **no
  Overview nav row** (Overview is reached via the header); Accounts nested group is labelled
  "Account groups" with a "New group" action
- [ ] Global top header — issues-count chip immediately left of the sync-status chip; per-view
  local-actions row rendered on the page-title line (right-aligned)
- [ ] `DetailPaneView` — collapsible slide-over container with all supported surface types,
  open/close animation, closed by default; edit and delete actions at the bottom for
  right-panel objects

#### Shared UI Components (`UI/Shared/`)
- [ ] `KPICardView` — reusable card with title, primary value, secondary value, trend indicator,
  tap target → navigation action
- [ ] `DataTableView` — sortable/filterable table with column definitions, row selection,
  traceability tap target per row
- [ ] `PieChartView` — configurable donut/pie with legend, labels, percentage display (Swift Charts)
- [ ] `SparklineView` — small in-line trend line for month-over-month panels (Swift Charts)
- [ ] `HeatMapTableView` — benchmark comparison table with period columns, color-scaled cells,
  benchmark comparison row (Swift Charts)
- [ ] `PeriodSelectorView` — month/quarter/year selector with previous/next navigation
- [ ] ~~`FilterBarView` — composable filter chips~~ **(deferred to V2 — filter bar removed from v1)**
- [ ] `EmptyStateView` — configurable empty state with icon, title, message, and optional CTA
- [ ] `SourceInspectorView` — shows file path, row number, last modified date, raw field values
  for a selected record; "Open in Finder" and "Open in Editor" actions
- [ ] `ValueProvenanceLabel` — inline label distinguishing imported / derived / repaired /
  user-edited values

#### Overview Module (`UI/Overview/`)
- [ ] `OverviewView` — 5 KPI card grid (no filters), month-over-month panel, inline issues table;
  each KPI card navigates to its module on tap
- [ ] `OverviewIssuesTableView` — validation issues grouped by severity, repairable badge,
  "Preview Repair" action per repairable issue

#### Accounts Module (`UI/Accounts/`)
- [ ] `AccountsView` — card grid of all accounts with aggregate header; grouped by account
  group; account cards tap → per-account screen
- [ ] `AccountGroupDetailView` — account-group screen with an individual-account card section
  above the transaction ledger (no sub-tabs); for business groups, P&L summary + monthly
  net-income chart with the ledger inline below it, category budgets, linked notes
- [ ] `AccountDetailView` — per-account screen: transactions table, monthly gross vs expenses/tax
  chart, YTD net income; Import, Add, Edit, Delete actions; account rules and estimates panel;
  edit in local actions, delete inside the edit flow

#### Budget Module (`UI/Budget/`)
- [ ] `BudgetOverviewView` — pie chart, Spend Mix / Spending Variance panels at 50/50, category
  table with plan/actual/variance/trailing-average, period selector; tap category → filtered
  transaction view
- [ ] `BudgetHistoryView` — month-over-month variance view, period range selector
- [ ] `BudgetCategoriesView` — category and subcategory management, manual create/edit forms

#### Savings & Investments Module (`UI/SavingsInvestments/`)
- [ ] `SavingsInvestmentsView` — top-level view with Overview, Goals, and Portfolio sub-navigation
- [ ] `GoalsListView` — flat list of goal cards with progress bar (no active/archived grouping),
  tap → goal detail
- [ ] `GoalDetailView` — progress history chart, funding source links, monthly contribution
  tracker, source traceability
- [ ] `PortfolioView` — holdings table as the primary surface with a standard ⇄ heat-map view
  toggle (heat map: 8 periods × accounts, S&P 500 comparison row, sector performance section);
  allocation donut and account selector as supporting elements; sleeve table at the bottom
  (target vs actual weights, contribution target, drift indicator)
- [ ] `HoldingDetailView` — security detail, tax lot drill-down, trade history, dividend summary

#### Taxes Module (`UI/Taxes/`)
- [ ] `CurrentTaxYearView` — YTD taxable income, taxes paid vs owed, effective rate per account
  table; estimated payments section (quarterly schedule, paid/due status); gains & income section
  (realized gain/loss, dividends, interest); deductions section (standard vs itemized,
  above-the-line, Schedule A, Schedule C linked to business themes/entities, taxable income
  projection); no prep checklist
- [ ] `TaxPrepChecklistView` — full-width checklist with complete/incomplete/missing item states,
  source links, and educational content per step
- [ ] `TaxArchiveView` — prior-year read-only archive selector, archived deductions and payments

### Milestone 5
> **Fully navigable app.** All v1 module views are built and connected to real domain engine
> projections. The right detail pane works across all contexts. Traceability links are live
> (KPI → detail → source inspector). The app is demoed end-to-end against a fixture workspace.

---

## Phase 6: Write Flows, Repair & Export

**Goal**: Make the app writable. Users can add accounts, import transactions, manage budget
categories and goals, track deductions, and trigger guided repairs. All writes are atomic,
backed up, and previewable.

### Product Tasks

- [ ] Define the write scope for v1: explicitly document which entities support structured editing
  (accounts, categories, goals, deductions, account rules) vs which are import-only (transactions,
  holdings, trades, prices)
- [ ] Write the write flow UX spec: steps from user intent → preview → backup confirmation →
  apply → re-index; what "preview" must show for each entity type
- [ ] Define backup naming convention and retention policy (how many backups to keep before
  auto-pruning)
- [ ] Define the import CSV flow: user selects external CSV → app maps columns to canonical schema
  → user reviews mapping → app writes to monthly canonical file → re-index triggered
- [ ] Document export format requirements: what columns are included in exported CSVs, what
  metadata is included in exported Markdown summaries

### Design Tasks

- [ ] **Add Account form**: account type picker (grouped by account group), name, institution,
  tax metadata fields, submit/cancel
- [ ] **Import CSV flow**: file picker, column-mapping table, validation summary, confirm/cancel
- [ ] **Add/Edit transaction form**: date, amount, category picker, merchant, notes, account
  selector
- [ ] **Add/Edit savings goal form**: name, target amount, target date, monthly contribution
  target, linked account, status
- [ ] **Add/Edit deduction form**: deduction type picker, name, estimated amount, account/entity
  link, status
- [ ] **Write preview panel**: before/after row diff, affected file path, backup location,
  apply button
- [ ] **Repair preview panel**: issue description, fix description, diff-style preview,
  backup confirmation, apply/cancel
- [ ] Export confirmation dialog: format picker (CSV/Markdown), file name, destination

### Development Tasks

#### Write Infrastructure
- [ ] `WritePlanBuilder` — given a user edit intent, construct a `WritePlan` specifying target
  file, rows to modify/append, derived values, backup path; enforce that every plan references a
  backup before applying
- [ ] `AtomicFileWriter` — write changes to a temp file, validate output, rename atomically;
  on failure leave original file untouched
- [ ] Update `BackupService` to produce named backups tied to write plan IDs for audit trail

#### Structured Write Flows (per entity)
Every user-addable object supports **add / edit / delete** (review functionality #6).
- [ ] Add/edit/delete `Account` and `AccountGroup` → writes to `Accounts/accounts.csv` / `Accounts/entities.csv`
- [ ] Import CSV transactions → column mapper → appends to `Accounts/transactions/YYYY-MM.csv`
- [ ] Add/edit/delete `Transaction` inline → writes to correct monthly file
- [ ] Add/edit/delete `Category` / `BudgetPlan` rows
- [ ] Add/edit/delete `SavingsGoal`
- [ ] Add/edit/delete holdings/assets → writes to `Investments/holdings.csv`
- [ ] Add/edit/delete `DeductionRecord` → writes to `Taxes/deductions.csv`
- [ ] Add/edit/delete `AccountRule` → writes to `Accounts/account-rules.csv`
- [ ] Delete-with-reference-check: write preview lists referencing rows and blocks/warns per the
  chosen default before applying (TDD §15)
- [ ] Edit/delete UI placement convention: right-panel objects show edit/delete at the panel
  bottom; dedicated-screen objects edit via local actions with delete inside edit
- [ ] Tax year-close action → writes archive files, marks year as closed in settings

#### Repair Flows
- [ ] Wire `RepairService` auto-repair actions through the UI: issue → preview → confirm → apply
- [ ] Repair preview integration in `OverviewIssuesTableView` and `DetailPaneView`
- [ ] Post-repair re-index and re-validation trigger

#### Export
- [ ] `ExportService` — export filtered table as CSV with source provenance columns; export
  monthly budget summary as Markdown with period header and category breakdown
- [ ] "Export Current View" menu command → opens save panel → calls `ExportService`
- [ ] `export-summary.swift` script — CLI equivalent of the export function

#### Developer Script
- [ ] `import-csv.swift` — CLI tool to ingest an external CSV, map to canonical schema,
  split by month into canonical files

### Milestone 6
> **App is writable.** Users can add accounts, import transactions, manage goals and deductions,
> and trigger guided repairs. All writes are atomic, backed up, and confirmed by preview.
> Export works for CSV tables and Markdown summaries. Import CSV flow handles real bank/brokerage
> export formats.

---

## Phase 7: Polish & Launch Readiness

**Goal**: Production-quality reliability, performance, accessibility, and macOS native behavior.
No new features — this phase hardens everything built in phases 1–6.

### Product Tasks

- [ ] Write the complete validation fixture suite: one valid and one invalid file per file type,
  covering all repairable and manual-only issue types
- [ ] Define performance acceptance criteria: initial indexing time for a realistic dataset
  (12 months × unified transactions × 3 entities), UI frame rate during re-index,
  time-to-first-projection on cold launch
- [ ] Write the first-launch onboarding acceptance test: empty iCloud container → bootstrap →
  all required files created → workspace validates cleanly
- [ ] Document any known limitations or workarounds for iCloud availability edge cases to include
  in release notes

### Design Tasks

- [ ] Accessibility audit: VoiceOver labels for all interactive elements, keyboard focus order
  review, color contrast pass against WCAG AA
- [ ] Dark mode audit: all custom colors, chart palettes, and status indicators tested in dark mode
- [ ] Responsive layout audit: test at minimum and comfortable window sizes, verify sidebar
  collapse behavior
- [ ] Final iconography pass: all section icons, status icons, issue severity icons, account
  group icons consistent and at correct scale
- [ ] Onboarding polish: first-launch empty state, workspace creation success confirmation,
  guided "add your first account" prompt

### Development Tasks

#### Performance
- [ ] Profile initial indexing on a realistic fixture workspace; optimize hash computation and
  manifest write to stay under perceived threshold
- [ ] Implement projection caching in each domain engine: cache last result keyed by file hashes;
  invalidate only affected domains when `FileWatcherService` fires
- [ ] Move all parsing and validation off the main thread; ensure UI remains responsive during
  full re-index
- [ ] Debounce `FileWatcherService` events to prevent thrashing during bulk file imports
- [ ] Lazy-load module views so cold launch does not block on all domain engines simultaneously

#### Reliability
- [ ] Ensure all domain engines handle sparse data gracefully: missing months, empty files,
  partially-filled optional columns — no crashes, sensible empty-state projections
- [ ] Implement last-known-valid projection persistence: cache the last successful projection
  for each module in `.finance-meta/`; serve it while re-indexing is in progress
- [ ] Add iCloud conflict detection and surface `Conflict detected` sync state in UI with
  guidance to resolve

#### Native Behavior
- [ ] Full keyboard navigation: `Tab` / `Shift+Tab` across sidebar → main panel → detail pane;
  arrow keys within tables; `Return` to open detail; `Escape` to close detail pane
- [ ] Implement all macOS menu commands: New Workspace, Open Workspace, Reindex Workspace,
  Validate Workspace, Repair Selected Issue, Open Source File, Reveal in Finder, Export Current
  View, Toggle Inspector, Open Backup Folder
- [ ] `NSUserActivity` / Handoff: encode navigation state so window restoration after relaunch
  returns to the same view and selection
- [ ] Register UTType declarations for `.csv` and `.md` for drag-and-drop import

#### Hardening
- [ ] Comprehensive unit tests for all domain engines against fixture data
- [ ] Integration tests for the full read flow: bootstrap → index → parse → validate → project
- [ ] Integration test for each write flow: intent → preview → backup → apply → re-index →
  re-validate
- [ ] Integration test for each auto-repair flow
- [ ] Test against realistic personal finance dataset: 12 months transactions, 3 investment
  accounts, 2 business themes/entities, full deduction set

#### Developer Script
- [ ] `fixture-generate.swift` — generate a realistic fixture workspace for QA and development
  (seeded with synthetic but plausible data for all file types)
- [ ] `backup-prune.swift` — prune old backups from `.finance-meta/backups/` beyond retention
  limit

### Milestone 7 — Launch Readiness
> **v1 complete.** The app is stable, performant, accessible, and handles all iCloud edge cases
> gracefully. All domain engines pass their integration test suites against realistic fixture data.
> All write and repair flows are tested end-to-end. The app is ready for internal beta or
> TestFlight distribution.

---

## Summary Table

| Phase | Focus | Key Deliverable | Prerequisite |
|---|---|---|---|
| 1 | Foundation & Architecture | Workspace resolves, files indexed, models defined | — |
| 2 | Parsing & Validation | All file types parsed, validation engine live | Phase 1 |
| 3 | Domain I — Accounts, Budget, Overview | Core projections, master account registry | Phase 2 |
| 4 | Domain II — S&I, Tax | All domain engines functional | Phase 3 (AccountEngine) |
| 5 | Presentation — Shell & All Views | Full UI connected to domain projections | Phase 3 + 4 |
| 6 | Write Flows, Repair & Export | App is writable, repair is guided | Phase 5 |
| 7 | Polish & Launch Readiness | Performance, accessibility, test coverage | Phase 6 |

---

## Open Decisions (Pre-Build)

All Phase 1 architectural decisions have been locked as of 2026-06-10. See `docs/technical-design.md §21` for the full locked-decision record.

| Decision | Resolution |
|---|---|
| `CloudStorageProvider` protocol surface | Minimum surface confirmed: `resolveWorkspaceURL()`, `syncState`, `isAvailable`. Conflict resolution stays iCloud-specific. |
| Master registry vs investment accounts | Unified `Accounts/accounts.csv` with optional investment columns. No separate `Investments/accounts.csv`. |
| Savings/ and Investments/ folder separation | Keep separate at the file level. |
| Deductions file structure | One `Taxes/deductions.csv` with `deduction_type` column. |
| Tax year-close trigger | Explicit in-app "Close Tax Year" action only. |
| Right pane default-closed scope | Global — closed by default, opens on main-panel interaction, no section exceptions. |
| iCloud container identifier | `OpenFinance` |
| Workspace bootstrap seed accounts | Personal bank, personal credit card, business bank, business credit card, savings, investment |
| Default delete behavior when an object is referenced | **Open** — block / cascade-warn / reassign; pick before Phase 6 delete flows (see `docs/_notes/object-model-audit.md` G7) |

---

## Changelog

> The roadmap participates in the same round-numbered refinement loop as the PRD and technical
> design. Rounds are global across all three docs; see `docs/_refinement/r{N}-*` for the source
> review and per-doc update plans.

### Round 5 — 2026-06-15
Source: `docs/_refinement/r5-review.md` (third prototype review — functional details); update plan `docs/_refinement/r5-update-product-roadmap.md`

- Out of Scope: added contextual filter bar (→ V2)
- Phase 5 App Shell: Overview is the default landing screen via the sidebar header ("Finance
  Dashboard"), not a nav item; issues chip moved to the global header; local-actions row moved to
  the page-title line; FilterBarView deferred to V2
- Phase 5 Accounts: `AccountGroupDetailView` shows individual-account cards + inline ledger (no
  sub-tabs); `AccountDetailView` is the per-account screen reached by tapping account cards
- Phase 5 Budget: Spend Mix / Spending Variance panels set to 50/50
- Phase 5: chart components implemented on Swift Charts (real charts, not placeholder SVGs)
- Phase 6: every user-addable entity now supports delete (with a delete-with-reference-check
  rule) in addition to add/edit; added the edit/delete UI placement convention
- Open Decisions: added default delete-on-reference behavior
- Deeper Budget⇄Strategy object model deferred to a future round (`docs/_notes/object-model-audit.md`)

### Baseline — 2026-06-11
- Roadmap authored reflecting all decisions through Round 3 (prototype review Round 1, the
  multi-cloud direction of Round 2, and the sidebar-and-locks direction of Round 3). These rounds
  are baked into the initial phase plan rather than applied as per-round deltas, so there are no
  `r1`–`r3` roadmap update plans.

### Round 4 — 2026-06-12
Source: `docs/_refinement/r4-review.md` (second prototype review); update plan `docs/_refinement/r4-update-product-roadmap.md`

- Out of Scope: added goal lifecycle states (active/archived), dedicated sleeves screen, dedicated
  benchmark screen, and dedicated deductions screen as V2 items; noted that estimated payments and
  gains & income stay in v1, surfaced within Current Tax Year
- Phase 4 Product (Taxes): added the three-screen consolidation note (Current Tax Year, Prep
  Checklist, Tax Archive)
- Phase 4 Design: replaced the separate Assets / Benchmark heat map / Sleeve detail tasks with a
  single holdings-focal Portfolio overview task (standard ⇄ heat-map toggle, sleeve table at
  bottom); merged Tax overview, Deductions, and Estimated payments design tasks into one Current
  tax year task; expanded the prep checklist task to a full-width educational screen
- Phase 4 Dev: `SavingsGoalEngine` noted as having no goal lifecycle states (no status branching)
- Phase 5: `AssetsView`, `SleeveDetailView`, and `BenchmarkView` replaced by a single
  `PortfolioView`; `TaxOverviewView`, `TaxDeductionsView`, and `EstimatedPaymentsView` replaced by
  a single `CurrentTaxYearView`; `GoalsListView` is a flat list; fixed stale `SavingsInvestmentsView`
  sub-navigation (now Overview, Goals, Portfolio)
